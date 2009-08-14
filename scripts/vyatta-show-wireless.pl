#! /usr/bin/perl
#
# Module: vyatta-show-wireless.pl
#
# **** License ****
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License version 2 as
# published by the Free Software Foundation.
#
# This program is distributed in the hope that it will be useful, but
# WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
# General Public License for more details.
#
# This code was originally developed by Vyatta, Inc.
# Portions created by Vyatta are Copyright (C) 2009 Vyatta, Inc.
# All Rights Reserved.
#
# Author: Stephen Hemminger
# Date: August 2009
# Description: Script to display bonding information
#
# **** End License ****

use lib "/opt/vyatta/share/perl5/";
use Getopt::Long;

use strict;
use warnings;

sub usage {
    print <<EOF;
Usage: $0 --brief
       $0 --show=<interface>
EOF
    exit 1;
}

# Make a hash of device names and current type (AP, station, ...)
sub get_device_map {
    my %wlans;

    open my $iwcmd, '-|'
	or exec qw(iw dev)
	or die "iw command failed: $!";

    my $name;
    while (<$iwcmd>) {
	my @fields = split;
	if ($fields[0] eq 'Interface') { $name = $fields[1]; }
	elsif ($fields[0] eq 'type')   { $wlans{$name} = $fields[1]; }
    }
    close $iwcmd;

    return \%wlans;
}

sub show_brief {
    my $wlans = get_device_map();

    my $format = "%-12s %-18s %-20s %-6s\n";
    printf $format, "Interface","Type","SSID","Channel";

    foreach my $intf (sort keys %$wlans) {
	# TODO convert to config names
	my $type = $$wlans{$intf};
	my ($ssid, $chan);

# TODO
	if ($type eq 'AP') {
	    ($ssid, $chan) = hostap_params($intf);
	} else {
	    $ssid = get_intf_ssid($intf);
	    $chan = get_intf_chan($intf);
	}

	printf $format, $intf, $type, $ssid, $chan;
    }
}

sub show_intf {
}

my ( $brief, $show );

GetOptions(
    'brief'	  => \$brief,
    'show=s'	  => \$show,
) or usage();


show_brief() if ($brief);
show_intf($show)  if ($show);




