#!/usr/bin/perl
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

package Vyatta::Wireless:Hostapd;

use strict;
use warnings;

use lib "/opt/vyatta/share/perl5/";
use Vyatta::Config;
use Vyatta::Misc;

my $debug = $ENV{'DEBUG'};
# map of fields to pull and if required
sub new {
    my ( $that, $name ) = @_;
    my $class = ref($that) || $that;
    my $self = { };
    $self->{name} = $name;

    my $config = new Vyatta::Config;
    $config->setLevel("interface wireless $name");

    foreach my $field (qw(ssid hw_mode security)) {
	my $value = $config->returnValue($field);
	die "wireless $name: $field is not defined (required)\n"
	    unless $value;
	$self->{$field} = $value;
    }
    $self->{disable_broadcast} = $config->exists();

    foreach my $field (qw(key passphrase descriptio)) {
	$self->{$field} = $config->returnValue($field);
    }

    return bless $self, $class;
}    

sub print_cfg {
    my $self = shift

    print "# Hostapd configuration\n"
    print "interface=", $self->{name}, "\n";
    print "driver=nl80211\n";
    print "hw_mode=",$self->{hw_mode},"\n";
    print "ieee80211n=1\n" if ($self->{hw_mode} eq 'n');

    # TODO do we need this?
    my $gid = getgrnam('vyatta-cfg');
    if ($gid) {
	print "ctrl_interface=/var/run/vyatta/hostapd/$wlan\n";
	print "ctrl_interface_group=$grp\n";
    }
    print "device_name=$name\n" if $name;
    printf "ignore_broadcast_ssid=%d\n", $self->{disable_broadcast};

    # TODO allow configuring ACL
    print "macaddr_acl=0\n";

    if ($self->{security} eq 'open') {
	print "auth_algs=1\n";
	print "wpa=0\n";
    } elsif ($self->{security} eq 'wep') {
	my $key = $self->{key};
	die "Missing WEP key for $wlan\n" unless $key;

	print "auth_algs=2\n";
	print "wep_key_len_broadcast=5\nwep_key_len_unicast=5\n";
	print "wep_default_key=0\nwep_key0=$key\n";
    } elsif ($self->{security} eq 'wpa') {
	my $phrase = $cfg->returnValue("passphrase");
	die "Missing passphrase for $wlan\n" unless $phrase;

	print "auth_algs=1\nwpa=3\nwpa_passphrase=$phrase\n";
	print "wpa_key_mgmt=WPA-PSK\nwpa_pairwise=TKIP\nrsn_pairwise=CCMP\n";
    } else {
	die "Unsupported security option: ", $self->{security};
    }
}

1;
