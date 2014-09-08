
=begin comment

This xAP application monitors bluetooth connections, so we can 
detect when a cell phone (and thus people) enter and leave a house.

Requirements:
  - Linux and Perl
  - Install perl module Inline::C:          http://search.cpan.org/dist/Inline
  - Install the bluez libs and utils from:  http://www.bluez.org/download.html

Derived from Jon Allen's xscreensaver.pl:
    http://perl.jonallen.info/projects/bluetooth

For Nokia phones, you can find the mac address by dialing: *#2820#
On windows, you can click on Properties on the phone as listed in the 
'Devices in range' option under 'My Bluetooth Places'.

=cut

use strict;
use IO::Socket::INET;
$|++;

my ( $address, $name, $bt_threshold ) = @ARGV
  or die "Missing the phone mac address\n";

printf "Will monitor bluetooth stats for address=%s name=%s device=%s\n",
  $address, $name, devname($address);

# Setup constants
my ( $bt_debug, $bt_linger );
$bt_debug     = $ENV{bt_debug};
$bt_linger    = $ENV{bt_linger};
$bt_threshold = $ENV{bt_threshold} unless defined $bt_threshold;

$bt_debug = 0 unless $bt_debug;
$bt_linger = 3
  unless
  $bt_linger;  # No. of measurements above/below threshold before changing state
$bt_threshold = 1 unless defined $bt_threshold;

my $XAP_PORT       = 3639;
my $XAP_GUID       = 'FF123400';
my $XAP_ME         = 'mhouse';
my $XAP_SOURCE     = 'mh';
my $XAP_INSTANCE   = 'xAP-bluetooth';
my $MAXLEN         = 1500;              # Max size of a UDP packet
my $HBEAT_INTERVAL = 120;               # Send every 2 minutes

# Create a broadcast socket for sending data
my $xap_send = new IO::Socket::INET->new(
    PeerPort  => $XAP_PORT,
    Proto     => 'udp',
    PeerAddr  => inet_ntoa(INADDR_BROADCAST),
    Broadcast => 1
) or die "Could not create xap sender\n";

# If a hub is not active, bind directly for listening
my $xap_listen = new IO::Socket::INET->new(
    LocalAddr => inet_ntoa(INADDR_ANY),
    LocalPort => $XAP_PORT,
    Proto     => 'udp',
    Broadcast => 1
);

if ($xap_listen) {
    print "No hub active.  Listening on broadcast socket",
      $xap_listen->sockport(), "\n";
}
else {
    # Hub is active.  Loop until we find an available port
    print "Hub is active, search for free relay port\n";
    for my $p ( $XAP_PORT .. $XAP_PORT + 100 ) {
        $XAP_PORT = $p;
        last
          if $xap_listen = new IO::Socket::INET->new(
            LocalAddr => 'localhost',
            LocalPort => $p,
            Proto     => 'udp'
          );
    }
    die "Could not create xap listener\n" unless $xap_listen;
    print "Listening on relay socket ", $xap_listen->sockport(), "\n";
}

&send_heartbeat;

# Do the loop
while (1) {
    if ( -e '/tmp/xAP-bluetooth.exit' ) {
        print "Exiting\n";
        exit;
    }
    select undef, undef, undef, 1.0;    # Sleep a bit
    my $time = time;
    &send_heartbeat if !( $time % $HBEAT_INTERVAL );
    if ( !( $time % 2 ) ) {
        my $status = &get_bt_status($address);
        &send_xap_data( $address, $name, $status ) if $status;
    }

    # Check for incoming xap traffic ... not needed here.
    my $rin = '';
    vec( $rin, $xap_listen->fileno(), 1 ) = 1;
    if ( select( $rin, undef, undef, 0 ) ) {
        my $xap_rx_msg;
        recv( $xap_listen, $xap_rx_msg, $MAXLEN, 0 ) or die "recv: $!";

        #       print "\n------------- Incoming message -------------\n$xap_rx_msg\n";
    }
}

sub send_heartbeat {
    print "Sending heartbeat on port ", $xap_send->peerport, "\n" if $bt_debug;
    print $xap_send
      "xap-hbeat\n{\nv=12\nhop=1\nuid=$XAP_GUID\nclass=xap-hbeat.alive\n"
      . "source=$XAP_ME.$XAP_SOURCE.$XAP_INSTANCE\ninterval=$HBEAT_INTERVAL\nport=$XAP_PORT\npid=$$\n}\n";
}

sub send_xap_data {
    my ( $address, $name, $status ) = @_;
    print "\nSending address=$address status=$status\n";
    my $msg =
      "xap-header\n{\nv=12\nhop=1\nuid=$XAP_GUID\nsource=$XAP_ME.$XAP_SOURCE.$XAP_INSTANCE\n";
    $msg .= "class=xap-bt.status\n}\nxap-bt.status\n{\n";
    $msg .= "address=$address\nname=$name\nstatus=$status\n}\n";
    print $xap_send $msg;
}

my ( $state, @bt_stack );

sub get_bt_status {

    my ($address) = @_;

    unless ($state) {
        $state    = 'far';
        @bt_stack = ();
    }

    # Trim the stack
    while ( @bt_stack >= $bt_linger ) {
        shift @bt_stack;
    }

    print '-' if $bt_debug;
    my $current_rssi = read_rssi($address);
    print '.' if $bt_debug;
    $current_rssi = -20 if $current_rssi eq '';

    push @bt_stack, $current_rssi;

    printf "[%s] a=%s, n=%s, s=%s, t=%s, l=%s, s=%s, stack=@bt_stack\n",
      scalar localtime,
      $address, $name, $current_rssi, $bt_threshold, $bt_linger, $state
      if $bt_debug;

    # Check if we need to change state
    if ( $state eq 'far' ) {
        for my $measurement (@bt_stack) {
            return undef if $measurement <= $bt_threshold;
        }
        $state = 'near';
    }
    elsif ( $state eq 'near' ) {
        for my $measurement (@bt_stack) {
            return undef if $measurement > $bt_threshold;
        }
        $state = 'far';
    }

    # Ignore startup state
    return ( @bt_stack < $bt_linger ) ? undef : $state;

}

#-------------------------------------------------------------------

# This part is the Inline C code interface to the bluez library.

# C code adapted from hcitool.c
# Copyright (C) 2000-2001 Qualcomm Incorporated
# Written 2000,2001 by Maxim Krasnyansky <maxk@qualcomm.com>
# http://bluez.sourceforge.net
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License version 2 as
# published by the Free Software Foundation;

use Inline C => Config => MYEXTLIB => '/usr/lib/libbluetooth.so';
use Inline C => <<EOT;

#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <string.h>
#include <signal.h>
#include <fcntl.h>
#include <errno.h>
#include <ctype.h>

#include <termios.h>
#include <fcntl.h>
#include <getopt.h>
#include <sys/ioctl.h>
#include <sys/socket.h>
#include <asm/types.h>
#include <netinet/in.h>

#include <bluetooth/bluetooth.h>
#include <bluetooth/hci.h>
#include <bluetooth/hci_lib.h>

SV* devname(char* address) {
  bdaddr_t bdaddr;
  char name[248];
  int dd;

  str2ba(address, &bdaddr);

  int dev_id;
  dev_id = hci_get_route(&bdaddr);
  if (dev_id < 0) {
    printf("Device not available\\n");
    return (newSVpvf(""));
  }
  
  dd = hci_open_dev(dev_id);
  if (dd < 0) {
    printf("HCI device open failed\\n");
    return (newSVpvf(""));
  }

  if (hci_read_remote_name(dd, &bdaddr, sizeof(name), name,25000) != 0) {
    close(dd);
    printf("Could not find device %s\\n",address);
    return (newSVpvf(""));
  }

  close(dd);
  return (newSVpvf("%s",name));
}


static int find_conn(int s, int dev_id, long arg)
{
	struct hci_conn_list_req *cl;
	struct hci_conn_info *ci;
	int i;

	if (!(cl = malloc(10 * sizeof(*ci) + sizeof(*cl)))) {
		perror("Can't allocate memory");
		exit(1);
	}
	cl->dev_id = dev_id;
	cl->conn_num = 10;
	ci = cl->conn_info;

	if (ioctl(s, HCIGETCONNLIST, (void*)cl)) {
		perror("Can't get connection list");
		exit(1);
	}

	for (i=0; i < cl->conn_num; i++, ci++)
		if (!bacmp((bdaddr_t *)arg, &ci->bdaddr))
			return 1;
	return 0;
}


SV* read_rssi(char* address) {
  int cc = 0;
  int dd;
  int dev_id;
  uint16_t handle;
  struct hci_conn_info_req *cr;
  struct hci_request rq;
  read_rssi_rp rp;
  bdaddr_t bdaddr;
  
  str2ba(address, &bdaddr);
  
  dev_id = hci_for_each_dev(HCI_UP, find_conn, (long) &bdaddr);
  if (dev_id < 0) {
    dev_id = hci_get_route(&bdaddr);
    cc = 1;
  }
  if (dev_id < 0) {
    printf("Device not available\\n");
    return (newSVpvf(""));
  }
  
  dd = hci_open_dev(dev_id);
  if (dd < 0) {
    printf("Cannot open device\\n");
    return (newSVpvf(""));
  }
  
  if (cc) {
    if (hci_create_connection(dd, &bdaddr, 0x0008 | 0x0010, 0, 0, &handle, 25000) < 0) {
//    printf("Can not create connection\\n");
      close(dd);
      return (newSVpvf(""));
    }
  }
  
  cr = malloc(sizeof(*cr) + sizeof(struct hci_conn_info));
  if (!cr) {
    printf("Could not allocate memory\\n");
    return (newSVpvf(""));
  }
    
  bacpy(&cr->bdaddr, &bdaddr);
  cr->type = ACL_LINK;
  if (ioctl(dd, HCIGETCONNINFO, (unsigned long) cr) < 0) {
    printf("Get connection info failed\\n");
    return (newSVpvf(""));
  }
  
  memset(&rq, 0, sizeof(rq));
  rq.ogf    = OGF_STATUS_PARAM;
  rq.ocf    = OCF_READ_RSSI;
  rq.cparam = &cr->conn_info->handle;
  rq.clen   = 2;
  rq.rparam = &rp;
  rq.rlen   = READ_RSSI_RP_SIZE;
  
  if (hci_send_req(dd, &rq, 100) < 0) {
//  printf("Read RSSI failed\\n");
    return (newSVpvf(""));
  }
  
  if (rp.status) {
//  printf("Read RSSI returned (error) status 0x%2.2X\\n", rp.status);
    return (newSVpvf(""));
  }
  
  if (cc) {
    hci_disconnect(dd, handle, 0x13, 10000);
  }
  
  close(dd);
  free(cr);
  return (newSVpvf("%d",rp.rssi));
}

EOT

#-------------------------------------------------------------------
