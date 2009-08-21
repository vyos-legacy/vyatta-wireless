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
# Description: Script to display bonding information
#
# **** End License ****

use lib "/opt/vyatta/share/perl5/";
use Getopt::Long;
use Vyatta::Config;
use Vyatta::Interface;

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

# Only modes valid on command line are listed
# access-point mode is controlled by hostapd, not here.
my %mode2iw = (
    'adhoc'		=> 'IBSS',
    'station'		=> 'managed',
#    'wds'		=> 'wds',
    'monitor'		=> 'monitor',
    'mesh' 		=> 'mesh point',
);

# Convert from device (wlan0) to underlying phy (phy0)
# This is gross, no other API for getting the info
sub get_phy {
    my $intf = shift;

    my $link = readlink ("/sys/class/net/$intf/phy80211");
    return $1 if ( $link  =~ m#/(phy\d+)$# );
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

sub check_chan {
    my ($dev, $ch) = @_;
    my $match = grep { $ch eq $_ } get_chan($dev);
    die "Channel $ch is not availabe for $dev\n" unless ($match > 0);
}

sub list_type {
    print join(' ', get_type(@_)), "\n";
}

sub check_type {
    my ($dev, $type) = @_;
    my $match = grep { $type eq $_ } get_type($dev);
    die "Type $type is not a available for $dev\n" unless ($match > 0);
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

    system("iw phy $phy interface add $wlan type $iwmode") == 0
	or die "wireless $wlan: device create failed\n";
}

sub delete_dev {
    my $name = shift;

    exec 'iw', 'dev', $name, 'del';
    die "Could not exec iw: $!";
}

sub config_wpa {
    my ($intf, $ssid) = @_;
    my $logname = "/var/log/vyatta/wpa_supplicant/$intf";
    my $cfgname = "/var/run/vyatta/wpa_supplicant/$intf";
    my $config = new Vyatta::Config;
    $config->setLevel("interfaces wireless $intf security");

    open my $cfg, '>', $cfgname
	or die "Can't open $cfgname:$!\n";

    print {$cfg} "# WPA supplicant config\n";
    print {$cfg} "network={\n";
    print {$cfg} "ssid=\"$ssid\"\n";
    print {$cfg} "scan_ssid=1\n" if ($config->exists('disable-broadcast'));

    if ($config->exists('wep')) {
	print {$cfg} "key_mgmt=NONE\n";

	my @keys = $config->listNodes('wep key');
	for (my $i = 0; $i < $#keys; ++$i) {
	    print {$cfg} "wep_key$i=$keys[$i]\n";
	}
    } elsif ($config->exists('wpa')) {
	my $psk = $config->returnValue('wpa passphrase');
	if ($psk) {
	    print {$cfg} "psk=\"$psk\"\n";
	} else {
	    die "WPA-EAP client not supported yet\n";
	}
    }
    close $cfg
	or die "Write error on $cfgname: $!";

    system("wpa_supplicant -i $intf -c $cfgname -f $logname -B") == 0
	    or die "can't start wpa_supplicant: $!";
}

sub config_station {
    my $name = shift;
    my $intf = new Vyatta::Interface($name);
    die "Unknown interface name $name" unless $intf;

    my $cfg = new Vyatta::Config;
    $cfg->setLevel("interfaces wireless $name");
    my $ssid = $cfg->returnValue('ssid');
    die "wireless interface $name : SSID not set" unless $ssid;

    if ($intf->flags() & IFF_UP) {
	system("ip link set $name down") == 0
	    or die "ip command failed: $!";
    }

    my $type = $cfg->returnValue('type');
    if ($type) {
	system ("iw dev $name set type $type") == 0
	    or die "iw set type command failed: $!";
    }

    my $chan = $cfg->returnValue('channel');
    if ($chan) {
	system ("iw dev $name set channel $chan") == 0
	    or die "iw set channel command failed: $!";
    }

    config_wpa ($name, $ssid) if ($cfg->exists('security'));

    exec 'ip', 'link', 'set', $name, 'up'
	or die "exec of ip link set up failed: $!";
}

my $dev;
my ( $list_type, $check_type, $list_chan, $check_chan, $config_station );
my ( $create_dev, $delete_dev );

GetOptions(
    'dev=s'		  => \$dev,
    'list-type'   	  => \$list_type,
    'check-type=s'	  => \$check_type,
    'config'		  => \$config_station,

    'list-chan'		  => \$list_chan,
    'check-chan=s'	  => \$check_chan,

    'create'		  => \$create_dev,
    'delete'		  => \$delete_dev,
) or usage();

die "Missing device argument\n" unless $dev;

list_chan($dev) 		if $list_chan;
check_chan($dev, $check_chan)	if $check_chan;

list_type($dev)			if $list_type;
check_type($dev, $check_type)	if $check_type;

create_dev($dev)		if $create_dev;
delete_dev($dev)		if $delete_dev;

config_station($dev)		if $config_station;

