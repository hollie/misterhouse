# ------------------------------------------------------------------------------
=begin comment
@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@

File:
        MQTT.pm

Description:
    This is the base interface class for Message Queue Telemetry Transport
    (MQTT)

    For more information about the MQTT protocol:
        http://mqtt.org

Author(s):
    Neil Cherry <ncherry@linuxha.com> 

    Based loosely on the UPMPIM.pm code
        - Jason Sharpee

License:
    This free software is licensed under the terms of the GNU public license.

Usage:
        Use these mh.ini parameters to enable this code:

        mqtt_host=test.mosquitto.org
        mqtt_server_port=1883
        mqtt_port=1883
        mqtt_topic=home/#
        mqtt_user=user                  (optional)
        mqtt_password=password          (optional)
        mqtt_keepalive=120              (optional)

Notes:
    - 

Special Thanks to:
    Bruce Winter - MH
    Jason Sharpee - MH UPB pkg

@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@

=head1 B<MQTT_Device>

Neil Cherry <ncherry@linuxha.com>

=head2 SYNOPSIS

NONE

=head2 DESCRIPTION

Misterhouse MQTT interface for use with any MQTT service

MQTT website: http://mqtt.org/

Notes:

Need:
MQTT Device
    test.mosquitto.org
    1883
or
    mozart.uucp
    1883

The test.mosquitto.org server listens on ports 1883, 8883, 8884 and
8885. Port 1883 is the standard unencrypted MQTT port and can be used
with any MQTT client. Ports 8883 and 8884 use certificate based
SSL/TLS encryption (TLSv1.2, TLSv1.1 or TLSv1.0) and require client
support to connect.

Web sockets are not supported here in MH

MQTT Item Pub (WO)
    Device
    'topic'

MQTT Item Sub (RO)
    Device
    'topic'

Topics (examples)
    #
    /ha/#
    /ha/house/livingroom/lamp/
    /ha/weather/temp
    /ha/weather/windspeed/

For now we'll use the wildcard. I don't recommend using the '#' if the
MQTT is test.mqtt.org Rather pick something a bit more unique like
    /username/ha/# 
and play from there

Because of the wildcard it probably makes sense to support multiple mqtt
connections. This would allow for:

    home/ha/x10/#
    home/ha/z-wave/#
    home/ha/zigbee/#

instead of:

    #

Which could cover things like this:

    home/email/...
    home/statistics/...
    offsite/...

If you're using a home mqtt then this might not be such as issue.

The intial device needs some kind of way to tell that it's still connected to
the MQTT server (MQTT Ping comes to mind).

=head2 INHERITS

B<NONE>

=head2 METHODS

=over

=item B<UnDoc>

=cut
# ------------------------------------------------------------------------------
package mqtt;

@mqtt::ISA = ('Generic_Item');

use strict;
use warnings;

use Net::MQTT::Constants qw/:all/;
use Net::MQTT::Message;

use IO::Select;
use IO::Socket::INET;

use Time::HiRes;

use Data::Dumper;

eval "use bytes";  # Not on all installs, so eval to avoid errors

# Need to share this with the outside world
my $verbose           = 5;
my $buf               = '';
my $got_ping_response = 1;
my $next_ping;

my $keep_alive_timer  = 120;

my $socket;

my $msg_id = 1;

my %MQTT_Data;

# Configuration variables
my $started;        # True if running already

# Configuration variables

#
# mqtt_server_port = 
# loads mqtt.pm
# calls ${module}::${type}_startup($instance)
#  mqtt::server_startup(mqtt)
#
=item C<server_startup()>

Called by the MH main script as a result of defining a server port in the ini file.

=cut
sub server_startup {
    my ($instance) = @_; # mqtt, mqtt_1, etc.

    # Don't start this instance twice

    #
    my $host      = "127.0.0.1";
    my $port      = 8883;
    my $topic     = "home/ha/#";

    &main::print_log("*** MQTT Instance $instance"."_host");
    ###
    ### For now we'll only worry about 1 instance
    ###
    $host      = $::config_parms{$instance . "_host"};
    $port      = $::config_parms{$instance . "_server_port"}; # Yes a bit weird
    $topic     = $::config_parms{$instance . "_topic"};
    $topic     =~ s/"//g;

    $keep_alive_timer = $::config_parms{$instance . "_keepalive"};

    &main::print_log("*** Opening MQTT ($instance) connection to $host/$port/$topic");
    &main::print_log("*** $host");
    &main::print_log("*** $port");
    &main::print_log("*** $topic");
    &main::print_log("*** $keep_alive_timer");

    ### ------------------------------------------------------------------------
    ### 1) open a socket (host, port and keepalive
    $socket = IO::Socket::INET->new(PeerAddr => $host . ':' . $port,
    				    Timeout  => 240, );

    return if(!defined($socket));
    $MQTT_Data{$instance}{'socket'}            = $socket;
    $MQTT_Data{$instance}{'got_ping_response'} = 1; # Why 1?
    $MQTT_Data{$instance}{'next_ping'}         = 0; #

    # --------------------------------------------------------------------------
    # We're good to here (socket is connected)

    ### 2) Send MQTT_CONNECT
    send_mqtt_msg($socket, message_type => MQTT_CONNECT, keep_alive_timer => $keep_alive_timer);

    # Bur when we get here, poof, socket is closed
    ### 3) Check for ACK or fail

    &main::print_log("*** NJC Socket check ($keep_alive_timer) [$!]: " . ($socket->connected ? "Connected" : "Failed"));
    my $msg = read_mqtt_msg_timeout($socket, $buf);
    if(!$msg) {
	&main::print_log ("XXX NJC No ConnAck ");
        exit 1;
	return;
    }

    &main::print_log ("*** NJC Received: " . $msg->string . "\n") if ($verbose >= 2);

    ### 4) Send a subscribe '#' (we'll have many of these, one for each device)
    ###    I don't know if this is a good idea or not but that's what I intend to do for now
    send_mqtt_msg($socket, message_type => MQTT_SUBSCRIBE,
                 message_id => $msg_id++,
                 topics => [ map { [ $_ => MQTT_QOS_AT_MOST_ONCE ] } $topic ]);

    ### 5) Check for ACK or fail$msg = read_mqtt_msg($socket, $buf) or die "No SubAck\n";
    print 'Received: ', $msg->string, "\n" if ($verbose >= 2);

    ### 6) check for data
    &main::print_log ("*** NJC Initializing MQTT connection ...");

    #return ;

    if (1 == scalar(keys %MQTT_Data)) {  # Add hooks on first call only
	&main::print_log ("*** NJC added MQTT poll ...");
        &::MainLoop_pre_add_hook(\&mqtt::check_for_data, 1);
    } else {
	&main::print_log ("*** NJC already added MQTT poll ..." . scalar(keys %MQTT_Data) );
	&main::print_log ("*** NJC already added MQTT poll ... but that's okay" );
	#exit 1;
    }
    ### 6a) publish a hello to our initial subscription
    ### 6b) check for ping response (hmmm, need to thing about this)
}
# ------------------------------------------------------------------------------
# Handle device I/O: Read and write messages on the bus
=item C<check_for_data()>

Called at the start of every loop. This checks either the serial or server port
for new data.  If data is found, the data is broken down into individual
messages and sent to C<GetStatusType> to be parsed.  The message is then 
compared to the previous data received if this is a duplicate message it is 
logged and ignored.  If this is a new message it is sent to C<CheckCmd>.

03/13/15 11:15:14 AM *** NJC read_mqtt_msg Receive buffer: 
  30 1d 00 0c 68 6f 6d 65 2f 68 61 2f 74 65 73 74  0...home/ha/test
  64 65 70 72 65 63 61 74 65 64 20 61 6c 73 6f     deprecated also
03/13/15 11:15:14 AM *** NJC rcv'd: Publish/at-most-once home/ha/test 
  64 65 70 72 65 63 61 74 65 64 20 61 6c 73 6f     deprecated also

We see this every $keep_alive_timeout seconds
03/13/15 11:17:08 AM *** NJC read_mqtt_msg Receive buffer: 
  d0 00                                            ..
03/13/15 11:17:08 AM *** NJC Received: PingResp/at-most-once

=cut
my @outqueue = (); # Queue of messages to be sent
my $count = 0; # Number of passes since last message sent

sub check_for_data {
    foreach my $inst (keys %MQTT_Data) {
	my $socket = $MQTT_Data{$inst}{'socket'};
	my $self   = $MQTT_Data{$inst}{self};
	### MQTT stuff below

	# This one doesn't block
	my $msg = read_mqtt_msg($socket, $buf);

	if ($msg) {
	    ###
	    ### Okay this is the hard part
	    ### For now I'm only worried about data that fits into 1 read
	    ###
	    ### I've got a message, I think it has
	    ###     $msg->topic
	    ###     $msg->message
	    ### I need to map this into the user device
	    ### the top is the address, the message the value
	    ###
	    if ($msg->message_type == MQTT_PUBLISH) {
		&main::print_log ("*** NJC check_for_data R: Dumper: " . Dumper($msg));
		###
		### Someone published something, deal with it
		###
		if ($verbose == 0) {
		    &main::print_log ("*** NJC check_for_data rcv'd: T:" . $msg->topic, ", M:", $msg->message);
		} else {
		    &main::print_log ("*** NJC check_for_data rcv'd: T:" . $msg->topic, ", M:", $msg->message);
		    &main::print_log ("*** NJC check_for_data rcv'd: S:" . $msg->string . ",");
		}

		#main::print_log("$port_name got: [$::Serial_Ports{$port_name}{data_record}]");
		#$MQTT_Data{$instance}{'obj'}->_parse_data_to_obj($msg);
		#$self->parse_data_to_obj($msg);

		###
		### So we want the topic and the message
		### topic   = address or identifier of the device
		### message = is the value of the device
		###
		### For now let's not get too fancy
		### $self->{$msg->topic}->{message}   = $msg->message
		### $self->{$msg->topic}->{timestamp} = timestamp
		###
	    } elsif ($msg->message_type == MQTT_PINGRESP) {
		$got_ping_response = 1;
		&main::print_log ('*** NJC check_for_data Ping rcvd: ' . $msg->string) if ($verbose >= 3);
	    } else {
		&main::print_log ("*** NJC check_for_data Received: $msg->string") if ($verbose >= 2);
	    }
	}

	# This is where we need to check for outgoing
	# Check for output
	if ($#outqueue >= 0) {
	    my $mref = shift @outqueue;

	    ###
	    ### Okay this is the other hard part
	    ### 
	    #send_mqtt_msg($mref));
	    &main::print_log ("*** NJC check_for_data send_mqtt_msg $mref ");
	}

    } # End of foreach $socket

    ###
    ### We need to deal with the pint for each socket, not 1 ping for all
    ###
    # Ping check
    if (Time::HiRes::time > $next_ping) {
        &main::print_log ("*** NJC read_mqtt_msg Ping Response timeout.") unless ($got_ping_response);
        return unless ($got_ping_response);
        send_mqtt_msg($socket, message_type => MQTT_PINGREQ);
    }
}
# ------------------------------------------------------------------------------
=item C<()>
=cut
sub send_mqtt_msg {
    my $socket = shift;

    my $msg = Net::MQTT::Message->new(@_);
    $msg = $msg->bytes;

    # syswrite ?
    syswrite $socket, $msg, length $msg;
    $next_ping = Time::HiRes::time + $keep_alive_timer;
}
# ------------------------------------------------------------------------------
=item C<read_mqtt_msg()>
=cut
sub read_mqtt_msg {
    my $socket = shift;
    my $select = IO::Select->new($socket);
    my $timeout = $next_ping - Time::HiRes::time;

    do {
	###
	### I really need to sit down and figure this out
	### 
	my $mqtt = Net::MQTT::Message->new_from_bytes($_[0], 1);

	#&main::print_log ("*** NJC read_mqtt_msg n " . $_[0]);

	#print "0";
	#&main::print_log ("*** NJC read_mqtt_msg 0");
	return $mqtt if (defined $mqtt);

	#print "1";
	#&main::print_log ("*** NJC read_mqtt_msg 1");
	### very short wait
	### Return if there is no data
	$select->can_read(0.1) || return;

	#print "2";
	#&main::print_log ("*** NJC read_mqtt_msg 2");
	$timeout  = $next_ping - Time::HiRes::time;

	#print "3";
	#&main::print_log ("*** NJC read_mqtt_msg 3");
	# Sysread ? sysread FILEHANDLE,SCALAR,LENGTH,OFFSET
	my $bytes = sysread $socket, $_[0], 2048, length $_[0];

	#print "4";
	#&main::print_log ("*** NJC read_mqtt_msg 4");

	unless ($bytes) {
	    &main::print_log ("*** NJC read_mqtt_msg Socket closed " . (defined $bytes ? 'gracefully' : 'error'));
	    return;
	}

	#&main::print_log ("*** NJC read_mqtt_msg Receive buffer: " . dump_string($_[0])) if ($verbose >= 3);
    } while ($timeout > 0);

    #&main::print_log ("*** NJC read_mqtt_msg 5");
    return;
}

# ------------------------------------------------------------------------------
=item C<read_mqtt_msg_timeout()>
=cut
sub read_mqtt_msg_timeout {
  my $socket = shift;
  &main::print_log ("*** NJC read_mqtt_msg_timeout Socket " . ($socket->connected ? "Connected" : "Failed"));
  my $select  = IO::Select->new($socket);
  my $timeout = $next_ping - Time::HiRes::time;

  do {
    my $mqtt = Net::MQTT::Message->new_from_bytes($_[0], 1);

    #&main::print_log ("*** NJC read_mqtt_msg n " . $_[0]);

    #print "0";
    #&main::print_log ("*** NJC read_mqtt_msg 0");
    return $mqtt if (defined $mqtt);

    #print "1";
    &main::print_log ("*** NJC read_mqtt_msg 1 ($timeout)");
    ### This is where it waits (blocking)
    ###
    $select->can_read($timeout) || return;

    #print "2";
    #&main::print_log ("*** NJC read_mqtt_msg 2");
    $timeout  = $next_ping - Time::HiRes::time;

    #print "3";
    #&main::print_log ("*** NJC read_mqtt_msg 3");
    # Sysread ? sysread FILEHANDLE,SCALAR,LENGTH,OFFSET
    my $bytes = sysread $socket, $_[0], 2048, length $_[0];

    &main::print_log ("*** NJC sysread Socket " . ($socket->connected ? "Connected" : "Failed"));

    #print "4";
    #&main::print_log ("*** NJC read_mqtt_msg 4");

    unless ($bytes) {
          &main::print_log ("*** NJC read_mqtt_msg Socket closed " . (defined $bytes ? 'gracefully' : 'error') . " ($timeout)($!)");
	  return;
    }

    &main::print_log ("*** NJC read_mqtt_msg Receive buffer: " . dump_string($_[0])) if ($verbose >= 3);
  } while ($timeout > 0);

  #&main::print_log ("*** NJC read_mqtt_msg 5");
  return;
}
# ------------------------------------------------------------------------------
=item C<read_mqtt_msg_timeout()>
=cut
sub set {
    my ($self, $state, $set_by) = @_;

}
# ------------------------------------------------------------------------------
=begin comment
=item C<new()>

Used to send commands to the interface.
=cut
sub new {
   bless $self, $class;

   return $self;
}
# ------------------------------------------------------------------------------
=item C<parse_data_to_obj()>
Take the data and parse it to the MH obj()

$msg = bless( { 'topic' => 'home/ha/test/x10/A1',
                'remaining' => '',
                'retain' => 1,
                'dup' => 0,
                'message_type' => 3,
                'qos' => 0,
                'message' => 'A1AON'
              },
              'Net::MQTT::Message::Publish'
);

=cut
sub parse_data_to_obj {
    my ($self, $msg) = @_;

    for my $obj (@{$$self{objects}}) {
	$obj->set($msg,$self);
    }
}
# -[ Fini ]---------------------------------------------------------------------

return 1;
