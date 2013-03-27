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

use File::Copy qw(copy);
use File::Spec::Functions qw(catfile);
use Folderol::Config;
use Folderol::DB;
use Folderol::Destination;
use Folderol::Feed;
use Folderol::Fetcher;
use Folderol::Logger;
use POSIX qw(strftime);

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
# static_files()
#
# Returns a list of static files to be copies input -> output
# ----------------------------------------------------------------------
sub static_files {
    my $self = shift;
    my $input = $self->{ INPUT };
    my $output = $self->{ OUTPUT };
    my $static = $self->{ COPY_FILES };

    my @files = map {
        Folderol::Destination->new({
            SRC => catfile($input, $_),
            DEST => $output,
        })
    } @$static;

    return wantarray ? @files : \@files;
}


# ----------------------------------------------------------------------
# parse($feed)
# 
# Takes a Folderol::Feed object, and parses it, and saves the results in
# the database.
# ----------------------------------------------------------------------
sub parse {
    my $self = shift;
    my $feed = shift;
    my $file = $feed->fetched_feed || return;

    my $p_feed = eval {
        require XML::Feed;
        Folderol::Logger->debug("Parsing $file");
        XML::Feed->parse($file);
    };

    if ($@ || ! $p_feed) {
        Folderol::Logger->error("Error parsing $file; skipping");
        return;
    }

    # Save the feed and the items in it
    my $feed_id = $self->db->save_feed({
        NAME     => ($feed->name or $p_feed->title),
        URL      => $feed->url,
        TITLE    => $p_feed->title,
        ID       => ($p_feed->id or $feed->url),
        LINK     => ($p_feed->link or $feed->url),
        SELFLINK => ($p_feed->self_link or undef),
        MODIFIED => ($p_feed->modified or today()),
        TAGLINE  => ($p_feed->tagline or undef),
        EXTRA    => $feed->extra_fields,
    });

    for my $entry ($p_feed->entries) {
        $self->db->save_entry(
            FEED     => $feed_id,
            TITLE    => $entry->title,
            LINK     => $entry->link,
            CONTENT  => ($entry->content->body or $entry->summary->body or $entry->title),
            SUMMARY  => ($entry->summary->body or undef),
            AUTHOR   => ($entry->author or undef),
            ID       => ($entry->id or $entry->link),
            DATE     => ($entry->issued or $entry->modified or today()),
        );
    }
}

# ----------------------------------------------------------------------
# process($destination)
#
# Process data for $destination (a Folderol::Destination object)
# ----------------------------------------------------------------------
sub process {
    my $self = shift;
    my $dest = shift || return;
    my $input = $dest->src;
    my $output = $dest->dest;
    my ($tt, $vars);

    require Template;
    $tt = Template->new($self->template_options);

    my @entries = $self->db->entries($self->items_per_page);
    my @channels = $self->db->channels;

    $vars = {
        site     => $self->top_level_variables,
        entries  => \@entries,
        channels => \@channels,
    };

    Folderol::Logger->info("Generating $output from $input");
    $tt->process($input, $vars, $output) || die $tt->error;
}

# ----------------------------------------------------------------------
# copy_static(destination)
# ----------------------------------------------------------------------
sub copy_static {
    my $self = shift;
    my $dest = shift || return;
    my $input = $dest->src;
    my $output = $dest->dest;

    Folderol::Logger->info("Copying $input to $output");
    copy($input, $output) or
        Folderol::Logger->error("Error copying $input to $output");
}

# ----------------------------------------------------------------------
# top_level_vars()
#
# Producea a hash of variables from $self, excluding specifically
# hidden things.
# ----------------------------------------------------------------------
sub top_level_variables {
    my $self = shift;
    my %vars = ();

    for my $k (keys %$self) {
        next if $k =~ /^_/;
        next if $k eq 'DBNAME';
        next if $k eq 'LOG_LEVEL';
        next if $k eq 'DB';
        next if $k eq 'LOG_LEVEL';
        next if $k eq 'CACHE_DIR';
        next if $k eq 'INPUT';
        next if $k eq 'OUTPUT';

        my $v = $self->{ $k };
        next if ref($v);

        $vars{ lc $k } = $v;
    }

    return \%vars;
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

  \$ $name [-h] [-V] [-f] [-g] /path/to/config.yaml

Parameters:

  -f    Fetch only
  -g    Generate pages only
  -h    This help
  -V    Print '$name v$VERSION' and exit

$name is Copyright (c) $COPYRIGHT by $AUTHOR.

EOHELP
}

# Helper function
sub today { strftime "%Y-%m-%dT%H:%M:%S", localtime time; }

# ----------------------------------------------------------------------
# AUTOLOAD - Make accessors easier. 
# ----------------------------------------------------------------------
sub AUTOLOAD {
    my $self = shift;
   (my $attr = $AUTOLOAD) =~ s/.*:://;

   return $self->{ uc $attr } || "";
}

1;
