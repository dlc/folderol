package Folderol::Config;

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
use constant FEEDS => "FEEDS";

use Folderol::Logger;

# ----------------------------------------------------------------------
# defaults()
# 
# Returns a hash of default parameters
# ----------------------------------------------------------------------
sub defaults {
    return (
        'NAME'          => '',
        'LINK'          => '',
        'INPUT'         => '',
        'OUTPUT'        => '',
        'CACHE_DIR'     => '/tmp',
        'LOG_LEVEL'     => 'ERROR',
        'DBNAME'        => glob("~/.folderol.db"),
        'TEMPLATE MAP'  => { },
    );
}

# ----------------------------------------------------------------------
# parsefile('/path/to/file.ini')
# ----------------------------------------------------------------------
sub parsefile {
    my $class = shift;
    my $file = shift;
    my %data = $class->defaults();

    if (open my $fh, $file) {
        my $cur = '';

        while (defined(my $line = <$fh>)) {
            $line =~ s/\s*[;#].*$//;    # Kill comments and trailing spaces
            $line =~ s/^\s*//;          # Kill leading spaces

            next unless $line =~ /./;   # Skip empty lines

            # Start new section
            if ($line =~ /^\[(.+)\]$/) {
                my $section = "$1";
                
                if ($section =~ m!^https?://!) {
                    $cur = FEEDS;

                    $data{ $cur } ||= [ ];

                    push @{ $data{ $cur } }, {
                        URL => $section,
                    }
                }

                else {
                    $cur = uc "$1";
                    $data{ $cur } ||= { };
                }

            }

            # name = value settings
            elsif ($line =~ /^(\S+)\s*=\s*(.+)$/) {
                my $key = "$1";
                my $val = "$2";

                if ($cur) {
                    if (FEEDS eq $cur) {
                        $data{ $cur }->[ -1 ]->{ uc $key } = $val;
                    }
                    else {
                        $data{ $cur }->{ $key } = $val;
                    }
                }
                else {
                    $data{ uc $key } = $val;
                }
            }

        }
    }
    else {
        Folderol::Logger->fatal("Cannot open or parse config file '$file'");
    }

    return %data;
}

1;
