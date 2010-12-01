#! /usr/bin/perl

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
#
# **** End License ****

use lib "/opt/vyatta/share/perl5/";
use Getopt::Long;

use strict;
use warnings;

my $IW = "sudo /usr/sbin/iw";

sub usage {
    print <<EOF;
Usage: $0 --brief
       $0 --show=<interface>
       $0 --scan=<interface>
EOF
    exit 1;
}

# Make a hash of device names and current type (AP, station, ...)
sub get_device_map {
    my %wlans;

    open my $iwcmd, '-|', "$IW dev"
      or die "$IW dev failed: $!";

    my $name;
    while (<$iwcmd>) {
        my @fields = split;
        if ( $fields[0] eq 'Interface' ) { $name = $fields[1]; }
        elsif ( $fields[0] eq 'type' ) { $wlans{$name} = $fields[1]; }
    }
    close $iwcmd;

    return \%wlans;
}

sub show_intf {
    my $intf   = shift;
    my $format = "%-18s %-12s %-10s %-10s  %-10s %-10s\n";
    printf $format, "Station", "Signal",
      "RX: bytes", "packets", "TX: bytes", "packets";

    open my $iwcmd, '-|', "$IW dev $intf station dump"
      or die "$IW station dump failed: $!";

    # Station 00:1d:e0:30:26:3f (on wlan0)
    #	inactive time:	5356 ms
    #	rx bytes:	6399
    #	rx packets:	85
    #	tx bytes:	4433
    #	tx packets:	32
    #	signal:  	-57 dBm
    #	tx bitrate:	1.0 MBit/s
    my ( $station, $signal, $rxbytes, $rxpkts, $txbytes, $txpkts );
    while (<$iwcmd>) {
        my @fields = split;
        if ( $fields[0] eq 'Station' ) {
            $station = $fields[1];
        }
        elsif ( $fields[0] eq 'signal:' ) {
            $signal = $fields[1];
        }
        elsif ( $fields[0] eq 'rx' ) {
            if ( $fields[1] eq 'bytes:' ) {
                $rxbytes = $fields[2];
            }
            elsif ( $fields[1] eq 'packets:' ) {
                $rxpkts = $fields[2];
            }
        }
        elsif ( $fields[0] eq 'tx' ) {
            if ( $fields[1] eq 'bytes:' ) {
                $txbytes = $fields[2];
            }
            elsif ( $fields[1] eq 'packets:' ) {
                $txpkts = $fields[2];
            }
            elsif ( $fields[1] eq 'bitrate:' ) {
                printf $format, $station, $signal,
                  $rxbytes, $rxpkts, $txbytes, $txpkts;
            }
        }
    }
    close $iwcmd;
}

sub hostap_params {
    my $intf    = shift;
    my $cfgfile = "/var/run/hostapd/$intf.cfg";

    open my $hcfg, '<', $cfgfile
      or die "missing hostap config file $cfgfile:$!";

    my ( $ssid, $chan );

    while (<$hcfg>) {
        chomp;
        if (m/^ssid=(.*)$/) {
            $ssid = $1;
        }
        elsif (m/^channel=(\d+)$/) {
            $chan = $1;
        }
    }
    close $hcfg;

    return ( $ssid, $chan );
}

my %param_func = ( 'AP' => \&hostap_params, );

sub show_brief {
    my $wlans  = get_device_map();
    my $format = "%-12s %-18s %-20s %-6s\n";
    printf $format, "Interface", "Type", "SSID", "Channel";

    foreach my $intf ( sort keys %$wlans ) {

        # TODO convert to config names
        my $type       = $$wlans{$intf};
        my $get_params = $param_func{$type};

        my $ssid = '-';
        my $chan = '?';
        ( $ssid, $chan ) = $get_params->($intf) if $get_params;

        printf $format, $intf, $type, $ssid, $chan;
    }
}

# TODO - decode mode (a,b,g,n) from rate table
#      - decode wpa, wpa2, wep from cipher output
#      - sort by signal? or ssid?
sub scan_intf {
    my $intf   = shift;
    my $format = "%-18s %-20s %-4s %-6s\n";
    printf $format, "Address", "SSID", "Chan", "Signal (dbm)";

    open my $iwcmd, '-|', "$IW dev $intf scan"
	or die "$IW scan failed: $!";

    # BSS 00:22:3f:b5:68:d6 (on wlan0)
    # 	TSF: 13925242600192 usec (161d, 04:07:22)
    # 	freq: 2412
    # 	beacon interval: 100
    # 	capability: ESS Privacy ShortSlotTime (0x0411)
    # 	signal: -77.00 dBm
    #	SSID: Jbridge2
    #	Supported rates: 1.0* 2.0* 5.5* 11.0* 18.0 24.0 36.0 54.0 
    #	DS Paramater set: channel 11
    # ...
    my ($ssid, $mac, $signal, $chan);
    while (<$iwcmd>) {
	if (/^BSS ([0-9a-fA-F:]+)/) { 
	    if ($mac) {
		printf $format, $mac, $ssid, $chan, $signal;
		$chan = undef;
		$signal = undef;
		$ssid = undef;
	    }
	    $mac = $1;
	}
	elsif (/^\s*SSID: (.*)$/)        { $ssid = $1; }
	elsif (/^\s*signal: ([-0-9]+)/) { $signal = $1; }
	elsif (/ channel (\d+)/)         { $chan = $1 }
    }
    close $iwcmd;

    printf $format, $mac, $ssid, $chan, $signal
	if $mac;
}

my ( $brief, $show, $scan );

GetOptions(
    'brief'  => \$brief,
    'show=s' => \$show,
    'scan=s' => \$scan,
) or usage();

show_brief() if ($brief);
show_intf($show) if ($show);
scan_intf($scan) if ($scan);
