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
use ExtUtils::MakeMaker;

WriteMakefile(
    'NAME'          => 'Folderol',
    'AUTHOR'        => 'Darren Chamberlain <darren@cpan.org>',
    'ABSTRACT'      => 'Fetch and Aggregate RSS and Atom feeds',
    'VERSION_FROM'  => 'lib/Folderol.pm',
    'LICENSE'       => 'Perl',
    'EXE_FILES'     => [
        'bin/folderol',
    ],
    'PREREQ_PM'     => {
        'DBI',          => 1.0,
        'DBD::SQLite'   => 1.0,
        'XML::Feed'     => 0,
        'Template'      => 2.01,
    },
    'clean'         => {
        'FILES' => '$(DISTVNAME).tar$(SUFFIX) *.ppd'
    },
    'dist'          => {
        'PREOP' => 'perldoc -t TOML.pm > README',
    },
);
