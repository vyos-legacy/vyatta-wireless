#!/usr/bin/perl

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
# A copy of the GNU General Public License is available as
# `/usr/share/common-licenses/GPL' in the Debian GNU/Linux distribution
# or on the World Wide Web at `http://www.gnu.org/copyleft/gpl.html'.
# You can also obtain it by writing to the Free Software Foundation,
# Free Software Foundation, Inc., 51 Franklin St, Fifth Floor, Boston,
# MA 02110-1301, USA.
#
# This code was originally developed by Vyatta, Inc.
# Portions created by Vyatta are Copyright (C) 2009 Vyatta, Inc.
# All Rights Reserved.
#
# Author: Stephen Hemminger
# Date: August 2009
# Description: Script to setup hostapd configuration
#
# **** End License ****
#

use strict;
use warnings;

use lib "/opt/vyatta/share/perl5/";
use Vyatta::Config;
use Vyatta::Misc;

my %wpa_mode = (
    'wpa'	=> 1,
    'wpa2'	=> 2,
    'both'	=> 3,
);


# Generate a hostapd.conf file based on Vyatta config
die "Usage: $0 wlanX\n"
  unless ( $#ARGV eq 0 && $ARGV[0] =~ /^wlan\d+$/ );

my $wlan   = $ARGV[0];
my $config = new Vyatta::Config;
my $level  = "interfaces wireless $wlan";
$config->setLevel($level);

# Mandatory value
my $ssid = $config->returnValue('ssid');
die "$level : missing SSID\n" unless $ssid;

my $hostap_dir = "/var/run/hostapd";
mkdir $hostap_dir
    unless (-d $hostap_dir);

my $cfg_name = "$hostap_dir/$wlan.cfg";
open (my $cfg, '>', $cfg_name)
    or die "Can't create $cfg_name: $!\n";

select $cfg;

print "# Hostapd configuration\n";
print "interface=$wlan\n";
print "driver=nl80211\n";

my $bridge = $config->returnValue('bridge-group bridge');
print "bridge=$bridge\n"  if $bridge;

# Levels (minimum value for logged events):
#  0 = verbose debugging
#  1 = debugging
#  2 = informational messages
#  3 = notification
#  4 = warning
my $debug = $config->exists('debug') ? 2 : 0;
print "logger_syslog=-1\n";
print "logger_syslog_level=$debug\n";

print "logger_stdout=-1\n";
print "logger_stdout_level=4\n";

print "ssid=$ssid\n";

my $chan = $config->returnValue('channel');
print "channel=$chan\n" if $chan;

my $country = $config->returnValue('country');
if ($country) {
    print "country_code=$country\n";
    print "ieee80211d=1\n";	# TODO make optional?
}

my $hw_mode = $config->returnValue('mode');
if ( $hw_mode eq 'n' ) {
    print "hw_mode=g\n";
    print "ieee80211n=1\n"
} else {
    print "hw_mode=$hw_mode\n";
}

print "dump_file=/tmp/hostapd.$wlan\n";

# TODO do we need this?
#my $gid = getgrnam('vyatta-cfg');
#if ($gid) {
#    print "ctrl_interface=/var/run/hostapd/$wlan\n";
#    print "ctrl_interface_group=$gid\n";
#}

print "ignore_broadcast_ssid=1\n"
  if ( $config->exists('disable-broadcast-ssid') );

my $descript = $config->returnValue('description');
print "device_name=$descript\n" if $descript;

# TODO allow configuring ACL
print "macaddr_acl=0\n";

$config->setLevel("$level security");

if ( $config->exists('wep') ) {
    my @keys = $config->returnValues('wep key');

    die "Missing WEP keys\n" unless @keys;

    # TODO allow open/shared to be configured
    print "auth_algs=2\nwep_key_len_broadcast=5\nwep_key_len_unicast=5\n";

    # TODO allow chosing default key
    print "wep_default_key=0\n";

    for (my $i = 0; $i <= $#keys; $i++) {
	print "wep_key$i=$keys[$i]\n";
    }

} elsif ( $config->exists('wpa') ) {
    $config->setLevel("$level security wpa");
    my $phrase = $config->returnValue('passphrase');
    my @radius = $config->listNodes('radius-server');

    my $wpa_type = $config->returnValue('mode');
    print "wpa=", $wpa_mode{$wpa_type}, "\n";

    my @cipher = $config->returnValues('cipher');

    if ( $wpa_type eq 'wpa' ) {    
        @cipher = ( 'TKIP', 'CCMP' )
	    unless (@cipher);
    } elsif ( $wpa_type eq 'both' ) {
        @cipher = ( 'CCMP', 'TKIP' )
            unless (@cipher);
    }
    if ( $wpa_type eq 'wpa2' ) {
        @cipher = ( 'CCMP' )
            unless (@cipher);
        print "rsn_pairwise=",join(' ',@cipher), "\n";
    } else {
        print "wpa_pairwise=",join(' ',@cipher), "\n";
    }

    if ($phrase) {
        print "auth_algs=1\nwpa_passphrase=$phrase\nwpa_key_mgmt=WPA-PSK\n";
    } elsif (@radius) {
	# What about integrated EAP server in hostapd?
        print "ieee8021x=1\nwpa_key_mgmt=WPA-EAP\n";

        # TODO figure out how to prioritize server for primary
	$config->setLevel("$level security wpa radius-server");
        foreach my $server (@radius) {
            my $port   = $config->returnValue("$server port");
            my $secret = $config->returnValue("$server secret");
            print "auth_server_addr=$server\n";
            print "auth_server_port=$port\n";
            print "auth_server_shared_secret=$secret\n";

            if ( $config->exists("$server accounting") ) {
                print "acct_server_addr=$server\n";
                print "acct_server_port=$port\n";
                print "acct_server_shared_secret=$secret\n";
            }
        }
    } else {
        die "wireless $wlan: security wpa but no server or key\n";
    }
} else {
    # Open system
    print "auth_algs=1\n";
}

select STDOUT;
close $cfg;
exit 0;
