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
# Description: Script to setup wpa_supplicant configuration
#
# **** End License ****
#

use strict;
use warnings;

use lib "/opt/vyatta/share/perl5/";
use Vyatta::Config;
use Vyatta::Misc;

# Generate a wpa_supplicant.conf file based on Vyatta config
die "Usage: $0 wlanX\n"
  unless ( $#ARGV eq 0 && $ARGV[0] =~ /^wlan\d+$/ );

my $wlan   = $ARGV[0];
my $config = new Vyatta::Config;
my $level  = "interfaces wireless $wlan";
$config->setLevel($level);

# Mandatory value
my $ssid = $config->returnValue('ssid');
die "$level : missing SSID\n" unless $ssid;

my $wpa_dir = "/var/run/wpa_supplicant";
mkdir $wpa_dir
    unless (-d $wpa_dir);

my $wpa_cfg_name = "$wpa_dir/$wlan.cfg";
open (my $wpa_cfg, '>', $wpa_cfg_name)
    or die "Can't create $wpa_cfg_name: $!\n";

select $wpa_cfg;

# TODO support multiple ssid's / networks
print "# WPA supplicant config\n";
print "network={\n";
print "    ssid=\"$ssid\"\n";
print "    scan_ssid=1\n" if ($config->exists('disable-broadcast'));

$config->setLevel("$level security");

if ($config->exists('wep')) {
    print "    key_mgmt=NONE\n";

    my @keys = $config->returnValues('wep key');
    for (my $i = 0; $i <= $#keys; ++$i) {
	print "    wep_key$i=$keys[$i]\n";
    }
} elsif ($config->exists('wpa')) {
    my $psk = $config->returnValue('wpa passphrase');
    if ($psk) {
	print "    psk=\"$psk\"\n";
    } else {
	die "WPA-EAP client not supported yet\n";
    }
} else {
    print "    key_mgmt=NONE\n";
}
print "}\n";

select STDOUT;
close $wpa_cfg;
exit 0;

