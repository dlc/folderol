package Folderol::Fetcher;

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

use Config;
use File::Basename qw(dirname);
use File::Path qw(mkpath);
use File::Spec::Functions qw(catfile);
use Folderol::Logger;
use URI;

# ----------------------------------------------------------------------
# new()
#
# Creates a new fetcher. Relies on curl, so this will barf if it can't
# find curl. Note that get() and getstore() also work as class methods,
# in whcih case the curl-finding step is bypassed.
# ----------------------------------------------------------------------
sub new {
    my $class = shift;

    my $found = 0;
    for my $p (split $Config{'path_sep'}, $ENV{'PATH'}) {
        last if $found = -x catfile $p, "curl";
    }

    Folderol::Logger->fatal("Can't find curl in \$PATH")
        unless $found;

    bless { } => $class;
}

# ----------------------------------------------------------------------
# get($url)
#
# GETs $url and returns the contents. Follows redirects and ignores SSL.
# ----------------------------------------------------------------------
sub get {
    my $self = shift;
    my $url = shift || return;

    my @cmd = (qw(curl -sSLk --connect-timeout 20 -A), "Folderol/$Folderol::VERSION", $url);

    `@cmd`;
}

# ----------------------------------------------------------------------
# getstore($url, $file)
#
# GETs $url and stores the contents in $file. Follows redirects and
# ignores SSL. If $file exists, it tries to send a 304 by comparing
# timestamps.
# ----------------------------------------------------------------------
sub getstore {
    my $self = shift;
    my $url = shift || return;
    my $file = shift || return;
    my $dir = dirname($file);

    -d $dir || mkpath $dir;

    Folderol::Logger->debug("Storing $url as $file");
    my @cmd = (qw(curl -sfLk --connect-timeout 10 -o), $file);

    if (-r $file) {
        push @cmd, '-z', $file;
    }

    push @cmd, $url;

    0 == system(@cmd);
}

# ----------------------------------------------------------------------
# expand_link($url)
#
# Dereference $url, following redirects and stripping utm_ parameters
# ----------------------------------------------------------------------
sub expand_link {
    my $self = shift;
    my $url = shift || return;
    my $new_url = $url;

    my @cmd = (qw(curl -sSLkI --connect-timeout 20 -A), "Folderol/$Folderol::VERSION", $url);
    my @headers = `@cmd`;

    for my $h (@headers) {
        if ($h =~ /^Location:\s*(\S+)/i) {
            $new_url = "$1"
        }
    }

    return $self->strip_url_garbage($new_url);
}

# ----------------------------------------------------------------------
# strip_url_garbage($url)
#
# Strips out utm_ parameters from a URL
# ----------------------------------------------------------------------
sub strip_url_garbage {
    my $self = shift;
    my $url = shift || return;

    my $u = URI->new($url);
    my %q = $u->query_form;
    my %nq;

    for (keys %q) {
        next if /^utm_/;

        $nq{ $_ } = $q{ $_ };
    }

    $u->query_form(\%nq);

    return $u->canonical;
}

1;
