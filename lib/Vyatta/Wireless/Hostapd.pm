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

package Vyatta::Wireless::Hostapd;

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
    $self->{disable_broadcast} = $config->exists('disable-broadcast-ssid');
    $self->{description}       = $config->returnValue('description');
    
    my @security = ( "auth_algs=1" );
    if ($config->exists("security")) {
	@security = get_security($name, $config);
    } 
    $self->{security} = \@security;

    return bless $self, $class;
}    

sub get_security {
    my ($name, $config) = @_;
    $config->setLevel("interface wireless $name security");

    if ($config->exists('wep')) {
	return wep_config ($name, $config);
    } elsif ($config->exists('wpa')) {
	return wpa_config ($name, $config);
    } else {
	die "wireless $name: security defined but missing wpa or wep\n";
    }
}

sub wep_config {
    my ($name, $config) = @_;
    my $key = $config->returnValue("wep key");
    die "wireless $name: missing WEP key\n" unless $key;
	    
    # TODO allow open/shared to be configured
    return ("auth_algs=2", 
	    "wep_key_len_broadcast=5",
	    "wep_key_len_unicast=5",
	    "wep_default_key=0",
	    "wep_key0=$key");
}
	
sub wpa_config {
    my ($name, $config) = @_;
    my $phrase = $config->returnValue("wpa passphrase");
    my @radius = $config->listNodes("wpa radius-server");

    # By default, use both WPA and WPA2
    my @lines = ("wpa=3" , "wpa_pairwise=TKIP CCMP" );
    if ($phrase) {
	push @lines, ( "auth_algs=1",
		       "wpa_passphrase=$phrase",
		       "wpa_key_mgmt=WPA-PSK" );
    } elsif (@radius) {
	push @lines, ("ieee8021x=1",
		      "wpa_key_mgmt=WPA-EAP");

	# TODO figure out how to prioritize server for primary
	my $first = 1;
	foreach my $server (@radius) {
	    $config->setLevel("interface wireless $name"
			      . "security wpa radius-server $server");
	    my $port = $config->returnValue("port");
	    my $secret = $config->returnValue("secret");
	    push @lines, ("auth_server_addr=$server",
			  "auth_server_port=$port",
			  "auth_server_shared_secret=$secret");
	    if ($first) {
		push @lines, ("acct_server_addr=$server",
			      "acct_server_port=$port",
			      "acct_server_shared_secret=$secret");;
		$first = undef;
	    }
	}
    } else {
	die "wireless $name: securit wpa but no server or key\n";
    }
    return @lines;
}

sub print_cfg {
    my $self = shift;
    my $wlan = $self->{name};

    print "# Hostapd configuration\n";
    print "interface=$wlan\n";
    print "driver=nl80211\n";
    print "hw_mode=",$self->{hw_mode},"\n";
    print "ieee80211n=1\n" if ($self->{hw_mode} eq 'n');

    # TODO do we need this?
    my $gid = getgrnam('vyatta-cfg');
    if ($gid) {
	print "ctrl_interface=/var/run/vyatta/hostapd/$wlan\n";
	print "ctrl_interface_group=$gid\n";
    }

    my $descript = $self->{description};
    print "device_name=$wlan\n" if $descript;
    printf "ignore_broadcast_ssid=%d\n", $self->{disable_broadcast};

    # TODO allow configuring ACL
    print "macaddr_acl=0\n";

    my @lines = @$self->{security};
    print join("\n", @lines);
}

1;
