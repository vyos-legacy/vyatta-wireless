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
# Portions created by Vyatta are Copyright (C) 2007 Vyatta, Inc.
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

my $hw_mode = $config->returnValue('mode');
my $chan = $config->returnValue('channel');
my $country = $config->returnValue('country');

print "# Hostapd configuration\n";
print "interface=$wlan\n";
print "driver=nl80211\n";

print "logger_syslog=-1";
print "logger_syslog_level=3";	# TOD make configurable

print "ssid=$ssid\n";
print "channel=$chan\n" if $chan;

if ($country) {
    print "country_code=$country\n";
    print "ieee80211d=1\n";	# TODO make optional?
}

if ( $hw_mode eq 'n' ) {
    print "hw_mode=g\n";
    print "ieee80211n=1\n" 
} else {
    print "hw_mode=$hw_mode\n";
}

print"dump_file=/var/log/vyatta/hostapd.$wlan\n";
# TODO do we need this?
#my $gid = getgrnam('vyatta-cfg');
#if ($gid) {
#    print "ctrl_interface=/var/run/vyatta/hostapd/$wlan\n";
#    print "ctrl_interface_group=$gid\n";
#}

print "ignore_broadcast_ssid=1\n"
  if ( $config->exists('disable-broadcast-ssid') );

my $descript = $config->returnValue('description');
print "device_name=$descript\n" if $descript;

# TODO allow configuring ACL
print "macaddr_acl=0\n";

$config->setLevel("interface wireless $wlan security");
if ( $config->exists('wep') ) {
    my $key = getValue($config, 'wep key');

    # TODO allow open/shared to be configured
    print <<EOF
auth_algs=2
wep_key_len_broadcast=5
wep_key_len_unicast=5
wep_default_key=0
wep_key0=$key
EOF
} elsif ( $config->exists('wpa') ) {
    my $phrase = $config->returnValue("passphrase");
    my @radius = $config->listNodes("radius-server");

    # By default, use both WPA and WPA2
    print "wpa=3\nwpa_pairwise=TKIP CCMP\n";

    if ($phrase) {
        print "auth_algs=1\nwpa_passphrase=$phrase\nwpa_key_mgmt=WPA-PSK\n";
    }
    elsif (@radius) {
        print "ieee8021x=1\nwpa_key_mgmt=WPA-EAP\n";

        # TODO figure out how to prioritize server for primary
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
