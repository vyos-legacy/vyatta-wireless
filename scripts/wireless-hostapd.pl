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
use Switch;

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

# Mandatory values
my $ssid = $config->returnValue('ssid');
die "$level : missing SSID\n" unless $ssid;
my $country = $config->returnValue('country');
die "$level : missing country\n" unless $country;

my $hostap_dir = "/var/run/hostapd";
mkdir $hostap_dir
    unless (-d $hostap_dir);

my $cfg_name = "$hostap_dir/$wlan.cfg";
open (my $cfg, '>', $cfg_name)
    or die "Can't create $cfg_name: $!\n";

select $cfg;

# hostapd config file header
print "# Hostapd configuration for $wlan\n";

# hostapd option: device_name=<char[32]>
my $descript = $config->returnValue('description');
print "device_name=$descript\n" if $descript;

# hostapd option: interface=<string>
# hostapd option: driver=[nl80211|none|hostap]
print "interface=$wlan\n";
print "driver=nl80211\n";

# hostapd option: bridge=<string>
# hostapd option: wds_sta=[0|1]
my $bridge = $config->returnValue('bridge-group bridge');
print "bridge=$bridge\n"  if $bridge;
if ($bridge) {
    print "bridge=$bridge\n";
    print "wds_sta=1\n";
}

# hostapd options: logger_syslog, logger_syslog_level, logger_stdout, logger_stdout_level
# Levels (minimum value for logged events):
#  0 = verbose debugging
#  1 = debugging
#  2 = informational messages
#  3 = notification
#  4 = warning
my $debug = $config->exists('debug') ? 1 : 0;
print "logger_syslog=-1\n";
print "logger_syslog_level=$debug\n";
print "logger_stdout=-1\n";
print "logger_stdout_level=4\n";

# hostapd option: ssid=<string>
print "ssid=$ssid\n";

# hostapd option: channel=[0,1-14,34-173]
my $chan = $config->returnValue('channel');
print "channel=$chan\n" if $chan;

# hostapd option: country_code=[US|EU|JP|DE|UK|...]
if ($country) {
    print "country_code=$country\n";
    print "ieee80211d=1\n";	# Mandatory to comply with regulatory domains.
}

# hostapd option: hw_mode=[a|b|g|ad]
my $hw_mode = $config->returnValue('mode');
if ( $hw_mode eq 'n' ) {
    print "hw_mode=g\n";
    print "ieee80211n=1\n";
} elsif ( $hw_mode eq 'ac' ) {
    print "hw_mode=a\n";
    print "ieee80211n=1\n";
    print "ieee80211h=1\n";
    print "ieee80211ac=1\n";
} else {
    print "hw_mode=$hw_mode\n";
}

# hostapd option: ieee80211w=[0|1|2]
my $ieee80211w = $config->returnValue("mgmt-frame-protection");
if ($ieee80211w) {
    switch($ieee80211w) {
        case "disabled"    { print "ieee80211w=0\n" }
        case "optional"    { print "ieee80211w=1\n" }
        case "required"    { print "ieee80211w=2\n" }
        else               { die "mgmt-frame-protection: Illegal argument\n" }
    }
}

# hostapd option: ignore_broadcast_ssid=[0|1|2]
print "ignore_broadcast_ssid=1\n"
  if ( $config->exists('disable-broadcast-ssid') );

# hostapd option: macaddr_acl=[0|1|2]
# hostapd option: accept_mac_file=<string>
# hostapd option: deny_mac_file=<string>
# TODO allow configuring ACL
print "macaddr_acl=0\n";
#accept_mac_file=/config/hostapd.accept
#deny_mac_file=/config/hostapd.deny

# hostapd option: wep_key[0-3]=[<quoted_string>|<unquoted_hex_digits>]
# hostapd option: wep_default_key=[0-3]
# hostapd option: wep_key_len_broadcast=[5|13]
# hostapd option: wep_key_len_unicast=[5|13]
# hostapd option: auth_algs=[1|2|3]
# hostapd option: wpa=[0-3]
# hostapd option: rsn_pairwise=[TKIP|CCMP|TKIP CCMP]
# hostapd option: wpa_pairwise=[TKIP|CCMP|TKIP CCMP]
# hostapd option: wpa_passphrase=[<unquoted_hex_digits[64]>|<char[8-63]>]
# hostapd option: wpa_key_mgmt=<string>
# hostapd option: ieee8021x=[0|1]
# hostapd option: auth_server_addr=<ip>
# hostapd option: auth_server_port=[1-65535]
# hostapd option: auth_server_shared_secret=<string>
# hostapd option: acct_server_addr=<ip>
# hostapd option: acct_server_port=[1-65535]
# hostapd option: acct_server_shared_secret=<string>
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

$config->setLevel($level);
# Other yet unspecified hostapd options may be entered here.
my @hostapd_options = $config->returnValues("hostapd-option");
if (@hostapd_options > 0) {
    foreach my $line (@hostapd_options) {
        print "$line\n";
    }
}

# uncondifional further settings
print "tx_queue_data3_aifs=7\n";
print "tx_queue_data3_cwmin=15\n";
print "tx_queue_data3_cwmax=1023\n";
print "tx_queue_data3_burst=0\n";
print "tx_queue_data2_aifs=3\n";
print "tx_queue_data2_cwmin=15\n";
print "tx_queue_data2_cwmax=63\n";
print "tx_queue_data2_burst=0\n";
print "tx_queue_data1_aifs=1\n";
print "tx_queue_data1_cwmin=7\n";
print "tx_queue_data1_cwmax=15\n";
print "tx_queue_data1_burst=3.0\n";
print "tx_queue_data0_aifs=1\n";
print "tx_queue_data0_cwmin=3\n";
print "tx_queue_data0_cwmax=7\n";
print "tx_queue_data0_burst=1.5\n";
print "wmm_enabled=1\n";
print "wme_enabled=1\n";
print "uapsd_advertisement_enabled=1\n";
print "wmm_ac_bk_cwmin=4\n";
print "wmm_ac_bk_cwmax=10\n";
print "wmm_ac_bk_aifs=7\n";
print "wmm_ac_bk_txop_limit=0\n";
print "wmm_ac_bk_acm=0\n";
print "wmm_ac_be_aifs=3\n";
print "wmm_ac_be_cwmin=4\n";
print "wmm_ac_be_cwmax=10\n";
print "wmm_ac_be_txop_limit=0\n";
print "wmm_ac_be_acm=0\n";
print "wmm_ac_vi_aifs=2\n";
print "wmm_ac_vi_cwmin=3\n";
print "wmm_ac_vi_cwmax=4\n";
print "wmm_ac_vi_txop_limit=94\n";
print "wmm_ac_vi_acm=0\n";
print "wmm_ac_vo_aifs=2\n";
print "wmm_ac_vo_cwmin=2\n";
print "wmm_ac_vo_cwmax=3\n";
print "wmm_ac_vo_txop_limit=47\n";
print "wmm_ac_vo_acm=0\n";



select STDOUT;
close $cfg;
exit 0;
