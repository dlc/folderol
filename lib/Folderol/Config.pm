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

# ----------------------------------------------------------------------
# defaults()
# 
# Returns a hash of default parameters
# ----------------------------------------------------------------------
sub defaults {
    return (
        NAME                => '',
        LINK                => '',
        INPUT               => '',
        OUTPUT              => '',
        CACHE_DIR           => '/tmp',
        LOG_LEVEL           => 'ERROR',
        OWNER_NAME          => '',
        OWNER_EMAIL         => '',
        ITEMS_PER_PAGE      => 100,
        DBNAME              => glob("~/.folderol.db"),
        GENERATOR           => "Folderol",
        GENERATOR_VERSION   => $Folderol::VERSION,
        GENERATOR_URI       => "https://github.com/dlc/folderol",
        TEMPLATE_MAP        => { },
        TEMPLATE_OPTIONS    => {
            ABSOLUTE => 1,
        },
    );
}

# ----------------------------------------------------------------------
# normalize(%data)
#
# Normalizes configuration data, and ensures sane defaults.
# ----------------------------------------------------------------------
sub normalize {
    my $class = shift;
    my $params = (@_ && ref($_[0]) eq 'HASH') ? shift : { @_ };
    my $new = { defaults() };

    for my $param (keys %$params) {
        if (lc($param) eq 'template_options') {
            for my $topt (keys %{ $params->{ $param } }) {
                my $val = $params->{ $param }->{ $topt };
                if (lc($val) eq 'true') {
                    $val = 1;
                }
                elsif (lc($val) eq 'false') {
                    $val = 0;
                }

                $new->{ TEMPLATE_OPTIONS }->{ uc $topt } = $val;
            }
        }
        else {
            $new->{ uc $param } = $params->{ $param };
        }
    }

    return $new;
}

1;
