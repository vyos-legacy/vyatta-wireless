#! /usr/bin/perl
#
# Module: vyatta-wireless.pl
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
use Vyatta::Config;

use strict;
use warnings;

my %iw2mode = (
    'IBSS'	=> 'adhoc',
    'managed'	=> 'station',
    'AP'	=> 'access-point',
#    'AP/VLAN'	=> 'vlan-access-point',
#    'WDS'	=> 'wds',
    'monitor'	=> 'monitor',
    'mesh point' => 'mesh',
);

my %mode2iw = (
    'adhoc'		=> 'IBSS',
    'station'		=> 'managed',
    'access-point'	=> '__ap',
#    'vlan-access-point'	=> '__ap_vlan',
#    'wds'		=> 'wds',
    'monitor'		=> 'monitor',
    'mesh' 		=> 'mesh point',
);

sub get_phy {
    my $intf = shift;
    my $config = new Vyatta::Config;
    $config->setLevel("interfaces wireless $intf");

    return $config->returnValue("physical-device");
}

# get list of channels available by device
sub get_chan {
    my $intf = shift;
    my $phy = get_phy($intf);
    exit 0 unless $phy;

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

# get list of supported types: AP, ...
sub get_type {
    my $intf = shift;
    my $phy = get_phy($intf);
    exit 0 unless $phy;

    my @args = ('iw', 'phy', $phy, 'info');

    open my $iwcmd, '-|'
	or exec @args
	or die "iw command failed: $!";

    my @types;
    while (<$iwcmd>) {
	next unless /Supported interface modes:/;
	while (<$iwcmd>) {
	    last unless m/\* (.+)$/;
	    my $t = $iw2mode{$1};

	    # skip unknown/unused types
	    push @types, $t if $t;
	}
	last;
    }
    close $iwcmd;

    return @types;
}


sub usage {
    print <<EOF;
Usage: $0 --dev=<interface> show-type
       $0 --dev=<interface> show-chan
EOF
    exit 1;
}

sub list_chan {
    print join(' ', get_chan(@_)), "\n";
}

sub list_type {
    print join(' ', get_type(@_)), "\n";
}

sub check_type {
    my ($dev, $type) = @_;
    my $match = grep { $type eq $_ } get_type($dev);
    die "$type is not a known type for $dev\n" unless ($match > 0);
}

sub set_type {
    my ($dev, $t) = @_;
    my $type = $mode2iw{$t};
    die "$t is not a known type\n" unless $type;

    exec 'sudo', 'iw', 'dev',  $dev, 'set', 'type', $type;
    die "exec iw failed: $!";
}

sub create_dev {
    my $wlan = shift;
    my $cfg = new Vyatta::Config;

    $cfg->setLevel("wireless interface");
    die "No configuration fore $wlan\n" unless $cfg->exists($wlan);

    $cfg->setLevel("wireless interface $wlan");
    my $phy = $cfg->returnValue('physical-device');
    die "wireless $wlan: you must specify physical-device\n" unless $phy;

    my $mode = $cfg->returnValue('mode');
    die "wireless $wlan: you must specify mode\n" unless $mode;
    
    my $iwmode = $mode2iw{$mode};
    die "wireless $wlan: unknown mode $mode\n" unless $iwmode;

    system("sudo iw phy $phy interface add $wlan type $iwmode") == 0
	or die "wireless $wlan: device create failed\n";
}

sub delete_dev {
    my $name = shift;

    exec 'sudo', 'iw', 'dev', $name, 'del';
    die "Could not exec iw: $!";
}

sub hostap_config {
    my $name = shift;
    my $hostap = new Vyatta::Wireless::Hostap($name);

    $hostap->print_cfg();
}

my $dev;
my ( $list_type, $check_type, $list_chan, $check_chan, $set_type );
my ( $create_dev, $delete_dev, $hostap );

GetOptions(
    'dev=s'		  => \$dev,
    'list-type'   	  => \$list_type,
    'check-type=s'	  => \$check_type,
    'set-type=s'	  => \$set_type,

    'list-chan'		  => \$list_chan,
    'check-chan=s'	  => \$check_chan,

    'create'		  => \$create_dev,
    'delete'		  => \$delete_dev,
    'hostap'		  => \$hostap,
) or usage();

die "Missing device argument\n" unless $dev;

list_chan($dev) 		if $list_chan;
check_chan($dev, $check_chan)	if $check_chan;

list_type($dev)			if $list_type;
check_type($dev, $check_type)	if $check_type;
set_type($dev, $set_type)	if $set_type;

create_dev($dev)		if $create_dev;
delete_dev($dev)		if $delete_dev;
hostap_config($dev)		if $hostap;
