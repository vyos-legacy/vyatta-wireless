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

my ( $brief, $show_intf );
my ( $list_phy, $list_chan, $list_mode);

sub usage {
    print <<EOF;
Usage: $0 --brief
       $0 --show=<interface>
       $0 --list-phy
       $0 --list-chan=<interface>
       $0 --list-mode=<interface>
EOF
    exit 1;
}

# get list of available phyX on system
sub get_phy {
    open my $iwcmd, '-|'
	or exec qw(iw phy)
	or die "iw command failed: $!";
    
    my @phys;
    while (<$iwcmd>) {
	chomp;
	my ( $tag, $phy ) = split;
	next unless ( $tag eq 'Wiphy');
	push @phys, $phy;
    }
    close $iwcmd;
    return @phys;
}

# get list of channels available by device
sub get_chan {
    my $phy = shift;
    my @args = ('iw', 'phy', $phy, 'info');

    open my $iwcmd, '-|'
	or exec @args
	or die "iw command failed: $!";

    my @chans;
    while (<$iwcmd>) {
	next unless /Frequencies:/;

	while (<$iwcmd>) {
	    next if m/\(disabled\)/;
	    last unless m/\* \d+ MHz \[(\d+)\]/;
	    push @chans, $1;
	}
	last;
    }
    close $iwcmd;
    return @chans;
}


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

sub get_intf_ssid {
    
}

sub get_intf_chan {
}


sub show_brief {
    my $format = "%-12s %-18s %-20s %-6s\n";
    printf $format, "Interface","Type","SSID","Channel";

    my $wlans = get_device_map();

    foreach my $intf (sort keys %$wlans) {
	# TODO convert to config names
	my $type = $$wlans{$intf};
	my $ssid = get_intf_ssid($intf);
	my $chan = get_intf_chan($intf);

	printf $format, $intf, $type, $ssid, $chan;
    }
}

GetOptions(
    'brief'	  => \$brief,
    'show=s'	  => \$show_intf,

    'list-phy'	  => \$list_phy,
    'list-chan=s' => \$list_chan,
) or usage();

show_brief()		if $brief;

print join(' ',get_phy()), "\n" 	if $list_phy;
print join(' ', get_chan(@_)), "\n"	if $list_chan;
