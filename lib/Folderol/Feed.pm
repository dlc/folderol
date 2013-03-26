package Folderol::Feed;

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
use vars qw($AUTOLOAD);

use File::Spec::Functions qw(catfile);
use Folderol::Fetcher;
use Folderol::Logger;

# ----------------------------------------------------------------------
# new(\%data)
# ----------------------------------------------------------------------
sub new {
    my $class = shift;
    my $data = shift;

    bless {
        FETCHER => Folderol::Fetcher->new,
        FETCHED_FEED => undef,
        map { uc($_) => $data->{ $_ } } keys %$data
    } => $class;
}

# ----------------------------------------------------------------------
# fetch($dest_dir)
#
# Fetches the contents of $self->url into $dest_dir. Uses $self->canon_name
# to canonicalize the file name.
# ----------------------------------------------------------------------
sub fetch {
    my $self = shift;
    my $cdir = shift;
    my $url = $self->url;
    my $file = $self->canon_name($url);
    $self->{ FETCHED_FEED } = catfile($cdir, $file);

    $self->fetcher->getstore($url, $self->{ FETCHED_FEED });
}

# ----------------------------------------------------------------------
# url()
#
# Returns link to the resource
# ----------------------------------------------------------------------
sub url {
    my $self = shift;
    return $self->{ URL } || $self->{ LINK };
}

# ----------------------------------------------------------------------
# canon_name($url)
#
# Canonicalized and makes filesystem-safe a URI, for use as a file name.
# ----------------------------------------------------------------------
sub canon_name {
    my $self = shift;
    my $str = shift;

    $str =~ s!^https?://!!;
    $str =~ s!/!,!g;
    $str =~ s![:\?&=]!_!g;
    $str =~ tr/_/_/s;

    return $str;
}

# ----------------------------------------------------------------------
# extra_fields()
#
# Returns a properly-formatted list of extra fields for the feed, all
# of whcih come from the yaml
# ----------------------------------------------------------------------
sub extra_fields {
    my $self = shift;
    my %vars = ();

    for my $k (keys %$self) {
        next if $k =~ /^_/;
        next if $k eq 'FETCHER';
        next if $k eq 'FETCHED_FEED';
        next if $k eq 'LINK';
        next if $k eq 'URL';
        next if $k eq 'NAME';

        my $v = $self->{ $k };
        next if ref($v);

        $vars{ lc $k } = $v;
    }

    return join " ",
        map {
            my $n = $_;             $n =~ s/\s//g;
            my $v = $vars{ $_ };    $v =~ s/'//g;
            
            "$n='$v'";
        } keys %vars;
}

sub AUTOLOAD {
    my $self = shift;
   (my $attr = $AUTOLOAD) =~ s/.*:://;

   return $self->{ uc $attr } || "";
}

1;
