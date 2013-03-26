package Folderol;

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
use vars qw($VERSION $COPYRIGHT $AUTHOR $AUTOLOAD);

$VERSION = "0.01";
$COPYRIGHT = 2013;
$AUTHOR = 'Darren Chamberlain <darren@cpan.org>';

use File::Spec::Functions qw(catfile);
use Folderol::Config;
use Folderol::DB;
use Folderol::Destination;
use Folderol::Feed;
use Folderol::Fetcher;
use Folderol::Logger;

# ----------------------------------------------------------------------
# new('/path/to/config.ini')
# ----------------------------------------------------------------------
sub new {
    my $class = shift;
    my $params = Folderol::Config->normalize(@_);
    my $self;

    # Set global log level
    Folderol::Logger->log_level($params->{ LOG_LEVEL });

    # Set up database
    my $db = Folderol::DB->new($params->{ DBNAME });

    $self = bless {
        DB => $db,
        %$params,
    } => $class;

    return $self;
}

# ----------------------------------------------------------------------
# feeds()
#
# Return a list of feeds, as defined in the config file
# ----------------------------------------------------------------------
sub feeds {
    my $self = shift;

    my @feeds = map {
        Folderol::Feed->new($_)
    } @{ $self->{ FEEDS } };

    return wantarray ? @feeds : \@feeds;
}

# ----------------------------------------------------------------------
# destinations()
#
# Returns a list of destinations: input -> output
# ----------------------------------------------------------------------
sub destinations {
    my $self = shift;
    my $input = $self->{ INPUT };
    my $output = $self->{ OUTPUT };
    my $tmap = $self->{ TEMPLATE_MAP };

    my @maps = map {
        my $out = $tmap->{ $_ };

        Folderol::Destination->new({
            SRC => catfile($input, $_),
            DEST => catfile($output, $out),
        })
    } keys %$tmap;

    return wantarray ? @maps : \@maps;
}


# ----------------------------------------------------------------------
# parse($feed)
# 
# Takes a Folderol::Feed object, and parses it, and saves the results in
# the database. If the feed was not already fetched, this handles it
# (although it might not, in the future)
# ----------------------------------------------------------------------
sub parse {
    my $self = shift;
    my $feed = shift;
    my $file;
    
    # Fetch the file if it's not alread been fetched
    unless ($file = $feed->fetched_file) {
        $feed->fetch($self->cache_dir);
        $file = $feed->fetched_file;
    }

    require XML::Feed;
    Folderol::Logger->debug("Parsing $file");
    my $p_feed = XML::Feed->parse($file);

    # Save the feed and the items in it
    my $feed_id = $self->db->save_feed({
        NAME     => $feed->name,
        URL      => $feed->url,
        TITLE    => $p_feed->title,
        ID       => $p_feed->id,
        LINK     => $p_feed->link,
        SELFLINK => $p_feed->self_link,
        MODIFIED => $p_feed->modified,
        TAGLINE  => $p_feed->tagline,
    });

    for my $entry ($feed->entries) {
        $self->db->save_entry({
            FEED     => $feed_id,
            TITLE    => $entry->title,
            LINK     => $entry->link,
            CONTENT  => $entry->content,
            SUMMARY  => $entry->summary,
            AUTHOR   => $entry->author,
            ID       => $entry->id,
            ISSUED   => $entry->issued,
            MODIFIED => $entry->modified,
        });
    }
}

# ----------------------------------------------------------------------
# help_message()
#
# Returns the help message
# ----------------------------------------------------------------------
sub help_message {
    my $class = shift;
    my $name = shift;

    return <<EOHELP;
$name - Fetch and Aggregate RSS and Atom feeds

Usage:

  \$ $name [-h] [-V] [-f] [-g] /path/to/config.ini

Parameters:

  -f    Fetch only
  -g    Generate only
  -h    This help
  -V    Print '$name v$VERSION' and exit

$name is Copyright (c) $COPYRIGHT by $AUTHOR.

EOHELP
}

# ----------------------------------------------------------------------
# AUTOLOAD - Make accessors easier. 
# ----------------------------------------------------------------------
sub AUTOLOAD {
    my $self = shift;
   (my $attr = $AUTOLOAD) =~ s/.*:://;

   return $self->{ uc $attr } || "";
}

1;
