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

# ----------------------------------------------------------------------
# save_feed(\%feed_data);
#
# Saves (or updates) information about a specific feed. Returns the
# primary key that represents this feed.
# ----------------------------------------------------------------------
sub save_feed {
    my $self = shift;
    my $data = (@_ && ref($_[0]) eq 'HASH') ? shift : { @_ };

    my $name     = $data->{'NAME'};
    my $url      = $data->{'URL'};
    my $title    = $data->{'TITLE'};
    my $id       = $data->{'id'};
    my $link     = $data->{'LINK'};
    my $selflink = $data->{'SELFLINK'};
    my $modified = $data->{'MODIFIED'};
    my $tagline  = $data->{'TAGLINE'};

    Folderol::Logger->debug("Saving feed $name");

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

    my $feed     = $data->{'FEED'};
    my $title    = $data->{'TITLE'};
    my $link     = $data->{'LINK'};
    my $content  = $data->{'CONTENT'};
    my $summary  = $data->{'SUMMARY'};
    my $id       = $data->{'id'};
    my $issued   = $data->{'ISSUED'};
    my $modified = $data->{'MODIFIED'};

    Folderol::Logger->debug("Saving entry $title");
    

}

# ----------------------------------------------------------------------
# create()
#
# Returns an array of SQL statements to execute, to create the database.
# ----------------------------------------------------------------------
sub create {
    my $class = shift;
    return (
        'CREATE TABLE feed (feed INTEGER PRIMARY KEY, url, name, title, id, link, self_link, modified, tagline)',
        'CREATE TABLE entry (entry INTEGER PRIMARY KEY, feed, title, link, content, summary, author, id, issued, modified)',
    );
}

1;
