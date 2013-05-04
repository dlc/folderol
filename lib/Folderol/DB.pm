package Folderol::DB;

# ----------------------------------------------------------------------
# Copyright (C) 2013 Darren Chamberlain <darren@cpan.org>
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License as
# published by the Free Software Foundation; version 2.
#
# This program is distributed in the hope that it will be useful, but
# WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
# General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA
# 02111-1301 USA
# ----------------------------------------------------------------------

use strict;

use DBI;
use DBD::SQLite;
use File::Spec::Functions qw(canonpath);
use Folderol::Logger;

# ----------------------------------------------------------------------
# new('/path/to/folderol.db')
#
# Instantiates a new SQLite db handle, creating the schema if necessary.
# ----------------------------------------------------------------------
sub new {
    my $class = shift;
    my $dbname = shift;

    # Normalize path; IME sqlite does odd things with non-canonical paths
    $dbname = canonpath($dbname);

    my $exists = -f $dbname;
    my $db = DBI->connect("dbi:SQLite:dbname=$dbname")
        || Folderol::Logger->fatal("Can't connect to database '$dbname': $DBI::errstr");

    # Create the schema if it doesn't already exist
    unless ($exists) {
        Folderol::Logger->info("Creating database schema in $dbname");
        for my $cr ($class->create) {
            $db->do($cr);
        }
    }

    bless {
        DB => $db,
        DBNAME => $dbname,
    } => $class;
}

sub db {
    my $self = shift;
    return $self->{ DB };
}

sub err {
    my $self = shift;
    return $self->db->err;
}

# ----------------------------------------------------------------------
# save_feed(\%feed_data);
#
# Saves (or updates) information about a specific feed. Returns the
# primary key that represents this feed.
# ----------------------------------------------------------------------
sub save_feed {
    my $self = shift;
    my $data = (@_ && ref($_[0]) eq 'HASH') ? shift : { @_ };
    my $db = $self->db;
    my ($sql, $feed_id, @bind);

    my $name     = $data->{'NAME'};
    my $url      = $data->{'URL'};
    my $title    = $data->{'TITLE'};
    my $id       = $data->{'ID'};
    my $link     = $data->{'LINK'};
    my $selflink = $data->{'SELFLINK'};
    my @modified = $data->{'MODIFIED'} ? ($data->{'MODIFIED'}) : ();
    my $tagline  = $data->{'TAGLINE'};
    my $extra    = $data->{'EXTRA'} || '';

    Folderol::Logger->debug("Saving feed '$name'");

    $sql = "SELECT feed AS feed_id FROM feed WHERE url = ?";
    if ($feed_id = $db->selectrow_array($sql, undef, $url)) {
        # Feed exists; UPDATE
        $sql = "UPDATE feed
                   SET name = ?, url = ?, title = ?, id = ?, link = ?,
                       selflink = ?, "
                   . (@modified ? "modified = ?, " : "")
                   . "tagline = ?, extra = ?
                 WHERE feed = ?";
        $db->do($sql, undef, $name, $url, $title, $id, $link,
                $selflink, @modified, $tagline, $extra, $feed_id)
            || Folderol::Logger->fatal($db->errstr);
    }
    else {
        # Feed doesn't exist; INSERT
        $sql = "INSERT INTO feed
                (name, url, title, id, link, selflink, modified, tagline, extra)
                VALUES
                (?, ?, ?, ?, ?, ?, ?, ?, ?)";
        $db->do($sql, undef, $name, $url, $title, $id,
                $link, $selflink, $modified[0], $tagline, $extra)
            || Folderol::Logger->fatal($db->errstr);
    }

    $sql = "SELECT feed AS feed_id FROM feed WHERE url = ?";
    $db->selectrow_array($sql, undef, $url);
}

# ----------------------------------------------------------------------
# save_entry($feed_id, \%entry_data)
# 
# Saves (or updates) information about a specific entry, associated with
# a specific feed (indicated by $feed_id). $feed_id should come from
# calling save_feed(), for consistency.
# ----------------------------------------------------------------------
sub save_entry {
    my $self = shift;
    my $data = (@_ && ref($_[0]) eq 'HASH') ? shift : { @_ };
    my $db = $self->db;
    my $sql;

    my $feed     = $data->{'FEED'};
    my $title    = $data->{'TITLE'};
    my $link     = $data->{'LINK'};
    my $content  = $data->{'CONTENT'};
    my $summary  = $data->{'SUMMARY'};
    my $id       = $data->{'ID'};
    my $date     = $data->{'DATE'};
    my $author   = $data->{'AUTHOR'};

    return unless ($title and $link);

    if (my $id = $db->selectrow_array("SELECT entry FROM entry WHERE link = ?", undef, $link)) {
        $db->do("UPDATE entry
                    SET feed = ?, title = ?, link = ?, content = ?,
                        summary = ?, id = ?, author = ?
                WHERE entry = ?", undef,
                $feed, $title, $link, $content, $summary, $id, $author, $id)
            || Folderol::Logger->fatal($db->errstr);
    }

    else {
        my $sql = "INSERT INTO entry (feed, title, link, content, "
            . "summary, id, date, author) VALUES (?, ?, ?, ?, ?, ?, ?, ?)";
        my @bind = ($feed, $title, $link, $content, $summary, $id, $date, $author);

        $db->do($sql, undef, @bind) || Folderol::Logger->fatal($db->errstr);
    }
}

# ----------------------------------------------------------------------
# entries($num)
#
# Return the $num latest entries, as an array, sorted by issued date
# descendingly.
# ----------------------------------------------------------------------
sub entries {
    my $self = shift;
    my $num = shift || 10;
    my $db = $self->db;
    my @entries;

    my $sth = $db->prepare("
        SELECT e.title AS entry_title,
               e.link AS entry_link,
               e.content AS entry_content,
               e.summary AS entry_summary,
               e.author AS entry_auth,
               e.id as entry_id,
               e.date as entry_date,
               f.url AS feed_url,
               f.name AS feed_name,
               f.title AS feed_title,
               f.id AS feed_id,
               f.link AS feed_link,
               f.selflink as feed_selflink,
               f.modified AS feed_modified,
               f.tagline AS feed_tagline,
               f.extra AS feed_extra
          FROM entry e, feed f
         WHERE f.feed = e.feed
      ORDER BY e.date desc
         LIMIT $num
    ");

    $sth->execute;
    while (my $row = $sth->fetchrow_hashref) {
        my $e = { channel => { } };
        for my $key (keys %$row) {
            my ($table, $field) = split /_/, $key;
            if ("feed" eq $table) {

                if ("extra" eq $field) {
                    $e->{ channel } = {
                        %{ $e->{ channel } },
                        %{ explode_extras($row->{ $key }) }
                    };
                }
                else {
                    $e->{ channel }->{ $field } = $row->{ $key };
                }
            }
            else {
                $e->{ $field } = $row->{ $key };
            }
        }

        push @entries, $e;
    }
    $sth->finish;

    return wantarray ? @entries : \@entries;
}

# ----------------------------------------------------------------------
# channels()
#
# Get a list of all the defined channels
# ----------------------------------------------------------------------
sub channels {
    my $self = shift;
    my $db = $self->db;
    my @channels;

    my $sth = $db->prepare("
        SELECT url, name, title, id, link, selflink, modified, tagline, extra
          FROM feed
         ORDER BY name desc");

    $sth->execute;
    while (my $row = $sth->fetchrow_hashref) {
        $row->{'extra'} = explode_extras(delete $row->{'extra'});

        push @channels, $row;
    }
    $sth->finish;

    return wantarray ? @channels : \@channels;
}

sub explode_extras {
    my $raw_extra = shift || "";

    my %extra = map {
        my ($n, $v) = /^(\S+?)=(\S+)$/;
        $n =~ s/^'//; $n =~ s/'$//;
        $v =~ s/^'//; $v =~ s/'$//;

        ($n, $v);
    } split /\s+/, $raw_extra;

    return \%extra;
}

# ----------------------------------------------------------------------
# DESTROY
# 
# Ensure that the db handle is correctly closed on exit
# ----------------------------------------------------------------------
sub DESTROY {
    my $self = shift;
    $self->{ DB }->disconnect
        if $self->{ DB };
}

# ----------------------------------------------------------------------
# create()
#
# Returns an array of SQL statements to execute, to create the database.
# ----------------------------------------------------------------------
sub create {
    my $class = shift;
    return (
        # Elements in the feed table:
        # * feed is main key (incrementing int)
        # * url is the URL entered
        # * title is the title the user provides in the config
        # * id is the <id> element in the feed
        # * link is the website url of the site which the feed syndicates
        # * selflink is the actual URL of the feed (usually, but not
        #   necessarily, the same as url)
        # * modified is the last modified time of the feed; defaults to
        #   NOW (http://alvinalexander.com/android/sqlite-default-datetime-field-current-time-now)
        # * tagline is the feed's description
        # * extra is any additional bits the user provides in the config: tags, etc
        'CREATE TABLE feed (feed INTEGER PRIMARY KEY, url, name, title, id, link, selflink, modified DATETIME DEFAULT CURRENT_TIMESTAMP, tagline, extra)',

        # Elements of the entry table:
        # * entry is the main key (incrementing int)
        # * feed is a fk to the feed table
        # * title is the entry <title>
        # * link is the entry <link>
        # * content is the entry <content> or <description>
        # * summary is the entry <summary>
        # * author is the entry <author>, reformatted as plain text
        # * id is the entry <id> or <guid>
        # * date is the entry <pubDate> or <issued> (not lastmod)
        'CREATE TABLE entry (entry INTEGER PRIMARY KEY, feed, title, link, content, summary, author, id, date DATETIME DEFAULT CURRENT_TIMESTAMP)',
    );
}

1;
