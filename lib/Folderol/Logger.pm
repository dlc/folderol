package Folderol::Logger;

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

{
    my $log_level = ERROR();

    sub log_level {
        my $class = shift;

        if (my $level = shift) {
            $level = uc $level;
            if ($level eq 'DEBUG') {
                $log_level = DEBUG()
            }
            elsif ($level eq 'INFO') {
                $log_level = INFO()
            }
            elsif ($level eq 'ERROR') {
                $log_level = ERROR()
            }
            else {
                $log_level = ERROR();
            }
        }

        return $log_level;
    }
}

sub debug {
    my $class = shift;

    if ($class->log_level >= DEBUG()) {
        $class->_log($_[0]);
    }
}

sub info {
    my $class = shift;

    if ($class->log_level >= INFO()) {
        $class->_log($_[0]);
    }
}

sub error {
    my $class = shift;

    if ($class->log_level >= ERROR()) {
        $class->_log($_[0]);
    }
}

sub fatal {
    my $class = shift;

    local $\;
    die "$_[0]\n";
}

sub _log {
    shift;
    local $\;
    print "$_[0]\n";
}

sub DEBUG { 10 }
sub INFO  { 5  }
sub ERROR { 1  }

1;
