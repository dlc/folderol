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
        %$data
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

    Folderol::Logger->debug("Storing $url as " . $self->{ FETCHED_FEED });
    $self->fetcher->getstore($url, $self->{ FETCHED_FEED });
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

sub AUTOLOAD {
    my $self = shift;
   (my $attr = $AUTOLOAD) =~ s/.*:://;

   return $self->{ uc $attr } || "";
}

1;
