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
    $dbname =~ tr!/!/!s;

    my $exists = -f $dbname;
    my $db = DBI->connect("dbi:SQLite:dbname=$dbname");

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
    my $modified = $data->{'MODIFIED'};
    my $tagline  = $data->{'TAGLINE'};

    Folderol::Logger->debug("Saving feed '$name'");

    $sql = "SELECT feed AS feed_id FROM feed WHERE url = ?";
    if ($feed_id = $db->selectrow_array($sql, undef, $url)) {
        # Feed exists; UPDATE
        $sql = "UPDATE feed
                   SET name = ?, url = ?, title = ?, id = ?,
                       link = ?, selflink = ?, modified = ?, tagline = ?
                 WHERE feed = ?";
        $db->do($sql, undef, $name, $url, $title, $id,
                $link, $selflink, $modified, $tagline, $feed_id) || die $db->errstr;
    }
    else {
        # Feed doesn't exist; INSERT
        $sql = "INSERT INTO feed
                (name, url, title, id, link, selflink, modified, tagline)
                VALUES
                (?, ?, ?, ?, ?, ?, ?, ?)";
        $db->do($sql, undef, $name, $url, $title, $id,
                $link, $selflink, $modified, $tagline) || die $db->errstr;
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
    
    $db->do("DELETE FROM entry WHERE link = ?", undef, $link);
    $db->do("INSERT INTO entry
             (feed, title, link, content, summary, id, date, author)
             VALUES
             (?, ?, ?, ?, ?, ?, ?, ?)", undef,
             $feed, $title, $link, $content, $summary, $id, $date, $author)
        || die $db->errstr;
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
               f.tagline AS feed_tagline
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
                $e->{ channel }->{ $field } = $row->{ $key };
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
        'CREATE TABLE feed (feed INTEGER PRIMARY KEY, url, name, title, id, link, selflink, modified, tagline)',
        'CREATE TABLE entry (entry INTEGER PRIMARY KEY, feed, title, link, content, summary, author, id, date)',
    );
}

1;
