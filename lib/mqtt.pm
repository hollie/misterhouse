# ------------------------------------------------------------------------------

=begin comment
    @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@

    =head1 B<MQTT_Device>

    Neil Cherry <ncherry@linuxha.com>

    =head2 SYNOPSIS

    A MQTT Interface and Item module for Misterhouse

    =head2 DESCRIPTION

    Misterhouse MQTT interface for use with any MQTT service

    MQTT website: http://mqtt.org/
    MQTT Test service: http//test.mosquitto.org/ (test.mosquitto.org port 1883)

File:
    mqtt.pm

Description:
    This is the base interface class for Message Queue Telemetry Transport
    (MQTT)

    For more information about the MQTT protocol:
        http://mqtt.org

    Author(s):
    Neil Cherry <ncherry@linuxha.com> 

    Based loosely on the UPMPIM.pm and SqueezeCLI.pm code
    - Jason Sharpee (UPB)
    - Lieven Hollevoet (SqueezeCLI)

License:
    This free software is licensed under the terms of the GNU public license.

Usage:

    .mht file:

        # MQTT stuff
        CODE, require mqtt; #noloop
        #
        CODE, $mqtt_1 = new mqtt('mqtt_1', '127.0.0.1', 1883, 'home/ha/#', "", "", 121);
        CODE, $mqtt_2 = new mqtt('mqtt_2', 'test.mosquitto.org', 1883, 'home/test/#', "", "", 122);
        CODE, $mqtt_3 = new mqtt('mqtt_3', '127.0.0.1', 1883, 'home/network/#', "", "", 122); #noloop
        #
        CODE, $CR_Temp = new mqtt_Item($mqtt_1, "home/ha/text/x10/1");
        CODE, $M2_Temp = new mqtt_Item($mqtt_2, "test.mosquitto.org/test/x10/1");
        CODE, $M3_Temp = new mqtt_Item($mqtt_3, "home/network/test/x10/1");
        #
        CODE, $CR_Temp->set("On");
        CODE, $M2_Temp->set("Off");
        CODE, $M3_Temp->set("On");

    and my mqtt.pl in my code dir:

        #
        if ($New_Minute and !($Minute % 30)) {
            my $state = ('on' eq state $M2_Temp) ? 'off' : 'on';
            set $M2_Temp $state;
            my $remark = "M2 Light set to $state";
            &print_log( "$remark" );
        }

    CLI generation of a command to the CR_Temp

        mosquitto_pub -d -h test.mosquitto.org -q 0 -t test.mosquitto.org/test/x10/1 -m "Off"

Example initialization:

    $myMQTT = new mqtt("MQTT",<host>,<port>,<topic>,<user>,<password>,<keepalive>);

Notes:
    - 

    Special Thanks to:
    Bruce Winter - MH
    Jason Sharpee - MH UPB pkg
    Lieven Hollevoet - SqueezeCLI.pm

    @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@

    =head2 B<Notes:>

    The test.mosquitto.org server listens on ports 1883, 8883, 8884 and
    8885. Port 1883 is the standard unencrypted MQTT port and can be used
    with any MQTT client. Ports 8883 and 8884 use certificate based
    SSL/TLS encryption (TLSv1.2, TLSv1.1 or TLSv1.0) and require client
    support to connect.

    Web sockets are not supported here in MH

    Topics (examples)
        #
        ha/#
        ha/house/livingroom/lamp
        ha/weather/temp
        ha/weather/windspeed

    For now we'll use the wildcard. I'll think about a rewrite later without the
    wild card support. I don't recommend using the '#' if the MQTT is test.mqtt.org
    Rather pick something a bit more unique like /username/ha/# and play from there

    Because of the wildcard it probably makes sense to support multiple mqtt
    connections on 1 or more servers. This would allow for:

        home/ha/x10/#
        home/ha/z-wave/#
        home/ha/zigbee/#

    instead of:

        home/#

    or

        #

    Which could cover things like this:

        home/email/...
        home/statistics/...
        offsite/...

    and just about everything else on this server too. :-)

    If you're using a home mqtt server then this might not be such as issue.
    Give this command a try and see the amount of traffic generated:

        mosquitto_sub -d -h test.mosquitto.org -t "#"

    The intial device needs some kind of way to tell that it's still connected
    to the MQTT server (MQTT Ping comes to mind).

    =head2 INHERITS

    B<NONE>

    =head2 METHODS

    =over

    =item B<UnDoc>

    =item B<ToDo>

    There are a number of things that need to be done. There is a lack of error
    checking and connectivity checks and restoration. I'm sure there are a huge
    number of features that need to be added.

    @FIXME: Topic handling needs work, if the same host:port is used the first
            instance (same socket) is used but this causes issues and at
            reconnect we need to resubscribe. There is no way to do that now
            (we'll need to resubscribe all the same socket related subscriptions)
    @FIXME: We're really not checking for ConnAck or SubAck.
    @FIXME: No SSL
    @FIXME: Lots of error checking needs to be done
    @FIXME: Use of uninitialized value
    @TODO:  Callbacks to handle decoding of the tiopic messages
    @TODO:  Analog device and string device handling

=cut

# ------------------------------------------------------------------------------
use constant { TRUE => 1, FALSE => 0 };

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

eval "use bytes";    # Not on all installs, so eval to avoid errors

# Need to share this with the outside world
my $msg_id = 1;

my %MQTT_Data;

# $main::Debug{mqtt} = 0;

# ------------------------------------------------------------------------------
sub dump() {
    &main::print_log( "*** mqtt Dumper (MQTT_Data):\n" . Dumper( \%MQTT_Data ) . "***" );
}

sub log {
    my ($self, $str) = @_;
    &main::print_log( 'MQTT: '. $str );
}

sub debug {
    my( $self, $level, $str ) = @_;
    if( $main::Debug{mqtt} >= $level ) {
	$level = 'D' if $level == 0;
	&main::print_log( "MQTT D$level: $str" );
    }
}

sub error {
    my ($self, $str, $level ) = @_;
    &main::print_log( "MQTT ERROR: $str" );
}

# ------------------------------------------------------------------------------

=item <mqtt_connect()>
=cut

sub mqtt_connect() {
    my ($self) = @_;

    $self->debug( 1, "mqtt_connect Socket ($$self{host}:$$self{port},$$self{keep_alive_timer}) ");

    ### 1) open a socket (host, port and keepalive
    my $socket = IO::Socket::INET->new(
        PeerAddr => $self->{host} . ':' . $self->{port},
        Timeout => 2,
        # Timeout  => $self->{keep_alive_timer},
    );

    # Can't use this at this time
    # $socket = new main::Socket_Item(undef, undef, "$host:$port", $instance);

    if ( !defined($socket) ) {
        if ($$self{recon_timer}->inactive) {
            $self->debug( 1, "mqtt connection for $$self{instance} failed, I will try to reconnect in 20 seconds");
            my $inst = $$self{instance};
            $$self{recon_timer}->set( 20, sub { $MQTT_Data{$inst}{self}->mqtt_connect() } );
            return;
        }
    }

    $self->{socket}            = $socket;
    $self->{got_ping_response} = 1;
    $self->{next_ping}         = $self->{keep_alive_timer};
    $self->{buf}	       = '';

    # --------------------------------------------------------------------------
    ### 2) Send MQTT_CONNECT
    # 20-12-2020 added registration of mqtt Last Will and Testament if defined in mh.ini
    $self->send_mqtt_msg(
        message_type     => MQTT_CONNECT,
        keep_alive_timer => $self->{keep_alive_timer},
	user_name	 => $self->{user_name},
	password	 => $self->{password},
	will_topic	 => $::config_parms{mqtt_LWT_topic},
	will_message	 => $::config_parms{mqtt_LWT_payload}
    );

    ### 3) Check for ACK or fail
    $self->debug( 1, "Socket check ($$self{keep_alive_timer}) [ $! ]: " . ( $self->isConnected() ? "Connected" : "Failed" ) );

    my $msg = $self->read_mqtt_msg_timeout();
    if ( !$msg ) {
        $self->error("mqtt $$self{instance} No ConnAck ");

        #exit 1;
        return;
    }

    # We should actually get a SubAck but who is checking (yes, I know I should)
    $self->debug( 1, "$$self{instance} Received: " . $msg->string );

    ### 4) Send a subscribe '#' (we'll have many of these, one for each device)
    ###    I don't know if this is a good idea or not but that's what I intend to do for now
    $self->send_mqtt_msg(
        message_type => MQTT_SUBSCRIBE,
        message_id   => $msg_id++,
        topics       => [ map { [ $_ => MQTT_QOS_AT_MOST_ONCE ] } $self->{topic} ]
    );

    ### 5) Check for ACK or fail
    $msg = $self->read_mqtt_msg_timeout();
    if( !$msg ) {
        $self->log( "$$self{instance} Received: " . "No SubAck" );
    }
    if ( $main::Debug{mqtt} ) {
        my $s =
          defined( $$msg{string} )
          ? "($$msg{string})"
          : '(--No $$msg{string}--)';
        ###
        ### IF we're not getting $$msg{string} then what are we getting ?
        ###
        $self->log( "$$self{instance} Sub 1 Received: " . "$s" );    # @FIXME: Use of uninitialized value
    }

    ### 6) check for data
    $self->debug( 1, "$$self{instance} Initializing MQTT connection ...");
}

# ------------------------------------------------------------------------------

=item C<isConnected()>
=cut

sub isConnected {
    my ($self) = @_;
    unless ( defined($$self{socket} ) ) { return 0 }
    return $$self{socket}->connected;
}

# ------------------------------------------------------------------------------

=item C<isNotConnected()>
=cut

sub isNotConnected {
    my ($self) = @_;
    unless ( defined($$self{socket} ) ) { return 1 }
    return !$$self{socket}->connected;
}

# ------------------------------------------------------------------------------

=item C<new()>

    Used to send commands to the interface.

=cut

sub new {
    my ( $class, $instance, $host, $port, $topic, $user, $password, $keep_alive_timer ) = @_;
    my $self;

    if( !defined( $main::Debug{mqtt} ) ) {
	$main::Debug{mqtt} = 0;
    }

    # 20-12-2020 edit to enable MH to monitor all mqtt topics especially for wildcards e.g. LWT
    $topic		= $topic    || $::config_parms{mqtt_topic}	|| '#';
    $host		= $host	    || $::config_parms{mqtt_host}	|| '127.0.0.1';
    $port		= $port	    || $::config_parms{mqtt_port}	|| 1883;
    $user		= $user	    || $::config_parms{mqtt_username}	|| '';
    $password		= $password || $::config_parms{mqtt_password}	|| '';

    $keep_alive_timer = 120 if !defined( $keep_alive_timer );    # retain a provided 0
   
    # If we have already created a socket and have an existing instance then
    # return the existing instance. MQTT doesn't like having 2 sockets to the
    # same server and will close the old socket.
    # But what should I do about the new topic. I'll need to subscribe to the
    # topic before returning the existing instance
    foreach my $inst ( keys %MQTT_Data ) {
        if ( "$MQTT_Data{$inst}{self}{host}" eq "$host" ) {
            if ( "$MQTT_Data{$inst}{self}{port}" eq "$port" ) {

                # subscribe to the topic if it doesn't already exist
                if ( "$MQTT_Data{$inst}{self}{topic}" ne "$topic" ) {

                    # Old, existing instace with the same host and port info
                    $self = $MQTT_Data{$inst}{self};

                    # Subscribe to the new topic
                    send_mqtt_msg(
                        $self,
                        message_type => MQTT_SUBSCRIBE,
                        message_id   => $msg_id++,
                        topics       => [ map { [ $_ => MQTT_QOS_AT_MOST_ONCE ] } $topic ]
                    );

                    ### 5) Check for ACK or fail
                    $self->{buf} = '';
		    my $msg = $self->read_mqtt_msg();
		    if( !$msg ) {
			$self->log( "$$self{instance} Received: " . "No SubAck" );
		    } else {
			$self->debug( 1, "$inst Sub 2 Received: " . $msg->string );
		    }
                }

                # This is the little messages that appear when MH starts
                &mqtt::log( undef, "Reusing $inst (instead of $instance) on $host:$port $topic");

                ###
                ### Ran into an issue doing it this way, it renames the object to the last
                ### object name it encounters :(
                ### I guess what I need to to create a new object but copy everything from the
                ### previous one
                ###
                return $MQTT_Data{$inst}{self};
            }
        }
    }

    $self = {};

    $$self{state}		= 'off';
    $$self{said}		= '';
    $$self{state_now}		= 'off';

    $self->{command_stack}	= [];
    $self->{retained_topics}	= {};

    $$self{instance}		= $instance;
    $$self{recon_timer}		= ::Timer::new();
    $$self{host}		= $host;
    $$self{port}		= $port;
    $$self{topic}		= $topic;
    $$self{user_name}		= $user;
    $$self{password}		= $password;
    $$self{keep_alive_timer}	= $keep_alive_timer;

    $$self{next_ping}		= 0;
    $$self{got_ping_response}	= 1; 

    bless $self, $class;

    # This is the little messages that appear when MH starts
    $self->log("Creating $instance on $host:$port $topic");

    $self->set_states( "off", "on" );

    $MQTT_Data{$instance}{self} = $self;

    $self->debug(1, "Opening MQTT ($instance) connection to $$self{host}/$$self{port}/$$self{topic}");
    $self->debug(1, "    Host       = $$self{host}");
    $self->debug(1, "    Port       = $$self{port}");
    $self->debug(1, "    Topic      = $$self{topic}");
    $self->debug(1, "    User       = $$self{user_name}");
    $self->debug(1, "    Password   = $$self{password}");
    $self->debug(1, "    Keep Alive = $$self{keep_alive_timer}");

    ### ------------------------------------------------------------------------
    $self->mqtt_connect();

    unless ($self) { 
    	$self->error("\n***\n*** Hmm, this is not good!, can't find myself\n***\n");
    	return;
    }

    # Hey what happens when we fail ?
    #$MQTT_Data{$instance}{self} = $self;
    if ( 1 == scalar( keys %MQTT_Data ) ) {    # Add hooks on first call only
        $self->log("added MQTT check_for_data ...");
        &::MainLoop_pre_add_hook( \&mqtt::check_for_data, 1 );
    }
    else {
        #$self->log("already added MQTT poll ..." . scalar(keys %MQTT_Data) );
        #$self->log("already added MQTT poll ... but that's okay" );
        #exit 1;
    }

    $self->set( 'on', $self );
    return $self;
}


# ------------------------------------------------------------------------------
# Handle device I/O: Read and write messages on the bus

=item C<check_for_data()>

    Called at the start of every loop. This checks for new data.

=cut

my @outqueue = ();    # Queue of messages to be sent
my $check_for_data_first = 1;

sub check_for_data {
    if( $check_for_data_first ) {
	$check_for_data_first = 0;
	mqtt->log( "now checking for new data" );
    }
    foreach my $inst ( keys %MQTT_Data ) {
        my $self = $MQTT_Data{$inst}{self};

        ### MQTT stuff below

        # Check for connectivity
        if ( $self->isNotConnected() ) {
            ###
            ### This needs a lot of work
            ###
            ### @FIXME: failed connection
            if ( 'off' ne $self->{state} ) {

		if ($$self{recon_timer}->inactive) {
            		$self->log("$inst connection failed ($$self{host}/$$self{port}/$$self{topic}), I will try to reconnect in 20 seconds");
            		$$self{recon_timer}->set(20, sub { $MQTT_Data{$inst}{self}->mqtt_connect() });
		}

                # check the state to see if it's off already

                $self->set( 'off', $self );
            }

            # Skip if we're not connected
            next;
        }

        # This one doesn't block
        my $msg = $self->read_mqtt_msg();

        ### -[ Input ]----------------------------------------------------------

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
            if ( $msg->message_type == MQTT_PUBLISH ) {
                ###
                ### Someone published something, deal with it
                ###
		$self->debug( 1, "$inst Rcv'd: R:$$msg{retain} T:'$$msg{topic}' M:'$$msg{message}'"  );
		# $self->debug( 1, "$inst Rcv'd: S:'" . $msg->string . "'", 3 );

                ###
                ### So we want the topic and the message
                ### $msg->topic   = address or identifier of the device
                ### $msg->message = is the value of the device
                ###
                ### We also need the instance to know who set the obj
                ###
                $self->parse_data_to_obj( $msg, $inst, $self );

            }
            elsif ( $msg->message_type == MQTT_PINGRESP ) {
                $$self{got_ping_response} = 1;
                $self->debug( 2, "$inst check_for_data Ping rcvd" );
                $self->debug( 3, "Ping msg: " . Dumper( $msg ) );
            }
            else {
                # "$msg->string"
                # Net::MQTT::Message::SubAck=HASH(0x2da94e0)->string
                $self->debug( 1, "$inst check_for_data UNHANDLED MQTT MESSAGE Received: " . Dumper( $msg ) );
            }
        }

        ### -[ Output ]---------------------------------------------------------

=begin comment
	# This is where we need to check for outgoing
	# I think we're writing directly at the moment, So I probably won't need
	# this. Not sure which is better
	if ($#outqueue >= 0) {
	    my $mref = shift @outqueue;

	    ###
	    ### Okay this is the other hard part
	    ### 
	    #send_mqtt_msg($mref));
	    $self->debug( 1, "$inst check_for_data send_mqtt_msg $mref ");
	}
=cut

        ### -[ Ping ]-----------------------------------------------------------

        ###
        ### We need to deal with the mqtt ping for each socket, not 1 ping for all
        ###
        # Ping check
        if ( Time::HiRes::time > $$self{next_ping} ) {
            ###
            ### We've exceeded the ping time
            ###
            $self->log("$inst read_mqtt_msg Ping Response timeout.")
              unless ( $$self{got_ping_response} );
            ###
            ### This has confused me, I'm not certain if I should put it back in or not
            ### I'll need to sit down a put together a state table and review this
            ###
            # return unless ($$self{got_ping_response});

            $self->debug( 2, "$inst read_mqtt_msg Ping Request" );
            send_mqtt_msg( $self, message_type => MQTT_PINGREQ );
            $$self{got_ping_response} = 0;
        }
    }    # End of foreach $socket
}

# ------------------------------------------------------------------------------

=item C<(send_mqtt_msg)>
=cut

sub send_mqtt_msg {
    my ( $self, %p_objects ) = @_;

    my $msg = Net::MQTT::Message->new(%p_objects);
    $msg = $msg->bytes;

    # print( "writing to mqtt socket '$msg'\n" );
    # syswrite ?
    syswrite $$self{socket}, $msg, length $msg;

    # Reset the next_ping timer (we sent something so we don't need another ping
    # until now+keep_alive_timer
    $$self{next_ping} = Time::HiRes::time + $$self{keep_alive_timer};
}

# ------------------------------------------------------------------------------

=item C<read_mqtt_msg()>
=cut

sub read_mqtt_msg {
    my $self = shift;

    my $select  = IO::Select->new( $$self{socket} );
    my $timeout = $$self{next_ping} - Time::HiRes::time;

    do {
        ###
        ### I really need to sit down and figure this out
        ###
        my $mqtt = Net::MQTT::Message->new_from_bytes( $self->{buf}, 1 );
        #
        # I am a little confused by this
        #
	if( defined $mqtt ) {
	    # print( "read_mqtt_msg $self->{instance} returning a message -- remaining buffer '$self->{buf}'\n" );
	    return $mqtt;
	}

        ### very short wait
        ### Return if there is no data
        $select->can_read(0.1) || return;

        #
        $timeout = $$self{next_ping} - Time::HiRes::time;

        # can return undef (error) or 0 bytes (eof)
        my $bytes = sysread $$self{socket}, $self->{buf}, 2048, length $self->{buf};

        # We get no bytes if there is an error or the socket has closed
        unless ($bytes) {
	    my $inst = $$self{instance};
            if ($$self{recon_timer}->inactive) {
		 $self->log( "$$self{instance}: read_mqtt_msg Socket closed " . ( defined $bytes ? 'gracefully ' : "with error [ $! ]" ) );
		 $self->log( "This could be caused by sending an ill formed mqtt message, and the broker closed the socket" );
		 $self->log( "instance $$self{instance} will try to reconnect in 20 seconds");
		 $$self{recon_timer}->set(20, sub { $MQTT_Data{$inst}{self}->mqtt_connect() });
	    }

            # Not a permanent solution just a way to keep debugging
            #$self->debug( "1, deleting $$self{instance}\n" . Dumper( \$self ) );
            #delete( $MQTT_Data{ $$self{instance} } );

            return;
        }
    } while ( $timeout > 0 );
}

# ------------------------------------------------------------------------------

=item C<read_mqtt_msg_timeout()>
=cut

sub read_mqtt_msg_timeout {
    my $self = shift;

    my $select  = IO::Select->new( $$self{socket} );
    my $timeout = $$self{next_ping} - Time::HiRes::time;

    do {
        my $mqtt = Net::MQTT::Message->new_from_bytes( $self->{buf}, 1 );

        return $mqtt if ( defined $mqtt );

        ###
        ### This is where it waits (blocking)
        ###
        $select->can_read($timeout) || return;

        #
        $timeout = $$self{next_ping} - Time::HiRes::time;

        # can return undef (error) or 0 bytes (eof)
        my $bytes = sysread $$self{socket}, $self->{buf}, 2048, length $self->{buf};

        # We get no bytes if there is an error or the socket has closed
        unless ($bytes) {
            $self->log( "$$self{instance}: read_mqtt_msg Socket closed " . ( defined $bytes ? 'gracefully ' : "with error [ $! ]" ) );

            # Not a permanent solution just a way to keep debugging
            $self->debug( 1, "deleting $$self{instance}\n" . Dumper( \$self ) );
            delete( $MQTT_Data{ $$self{instance} } );

            return;
        }
    } while ( $timeout > 0 );
}

# ------------------------------------------------------------------------------

=item C<set()>
=cut

sub set {
    my ( $self, $msg, $set_by ) = @_;

    if ( $main::Debug{mqtt} ) {
        my $xStr = defined($msg) ? "($msg)" : "undefined message";
        $xStr .= defined($set_by) ? ", ($set_by)" : ", undefined set_by, Obj: ";
        $xStr .= defined( $$self{object_name} ) ? ", $$self{object_name}" : ", undefined object_name";    # @FIXME: Use of uninitialized value

        $self->debug( 1, "mqtt set $$self{instance}: [$xStr]");
        $self->debug( 1,
            $self->isa('mqtt')
            ? "mqtt set $$self{instance}: isa mqtt"
            : "mqtt set $$self{instance}: is nota mqtt"
        );
    }

    return unless ($msg);

    if ( $self->isa('mqtt') ) {

        # I really want to use this to allow the user to manually
        # connect and disconnect the socket

        #
        $self->SUPER::set( $msg, $set_by ) if defined $msg;
    }
    else {
        ###
        ### Okay here is the hard part
        ### I need the instance socket, the obj's topic and message
        ### in order to send the message
        ###
        $$self{instance}->pub_msg(
            message_type => MQTT_PUBLISH,
            retain       => $$self{retain},
            topic        => $$self{topic},
            message      => $msg
        );
    }
}

# ------------------------------------------------------------------------------

=item C<(pub_msg())>
=cut

###
### We're writing direct but that's okay as it's not like we're waiting on a
### serial port where things can really get backed up (Hmm, are we blocking on
### a write?)
###
sub pub_msg {
    my ( $self, %p_objects ) = @_;

    # Check for connectivity
    if ( $self->isNotConnected() ) {

        # First say something
        $self->error("$$self{instance} is not connected -- publish failed to $p_objects{topic}");

        # Then do something (reconnect)

        # Skip if we're not connected
        return;
    }
    $self->debug( 1, "$$self{instance} Pub: R:$p_objects{retain} T:'$p_objects{topic}' M:'$p_objects{message}'" );

    $self->send_mqtt_msg(%p_objects);
}

# ------------------------------------------------------------------------------

=item C<(add)>
=cut

sub add {
    my ( $self, @p_objects ) = @_;

    my @l_objects;

    for my $l_object (@p_objects) {
        if ( $l_object->isa('Group_Item') ) {
            @l_objects = $$l_object{members};
            for my $obj (@l_objects) {
                $self->add($obj);
            }
        }
        else {
            $self->add_item($l_object);
        }
    }
}

# ------------------------------------------------------------------------------

=item C<(add_item)>
=cut

sub add_item {
    my ( $self, $p_object ) = @_;

    push @{ $$self{objects} }, $p_object;

    return $p_object;
}

# ------------------------------------------------------------------------------

=item C<(remove_all_items)>
=cut

sub remove_all_items {
    my ($self) = @_;

    $self->log("mqtt remove_all_items()");

=begin comment
    if (ref $$self{objects}) {
	foreach (@{$$self{objects}}) {
	    #        $_->untie_items($self);
	}
    }
=cut

    delete $self->{objects};
}

# ------------------------------------------------------------------------------

=item C<(add_item_if_not_present)>
=cut

sub add_item_if_not_present {
    my ( $self, $p_object ) = @_;

    if ( ref $$self{objects} ) {
        foreach ( @{ $$self{objects} } ) {
            if ( $_ eq $p_object ) {
                return 0;
            }
        }
    }
    $self->add_item($p_object);
    return 1;
}

# ------------------------------------------------------------------------------

=item C<(remove_item)>
=cut

sub remove_item {
    my ( $self, $p_object ) = @_;

    if ( ref $$self{objects} ) {
        for ( my $i = 0; $i < scalar( @{ $$self{objects} } ); $i++ ) {
            if ( $$self{objects}->[$i] eq $p_object ) {
                splice @{ $$self{objects} }, $i, 1;

                #           $p_object->untie_items($self);
                return 1;
            }
        }
    }
    return 0;
}

# ------------------------------------------------------------------------------

=item C<parse_data_to_obj()>
    Take the data and parse it to the MH obj()

    $msg = bless( {
                    'topic' => 'home/ha/test/x10/1',
                    'remaining' => '',
                    'retain' => 1,
                    'dup' => 0,
                    'message_type' => 3,
                    'qos' => 0,
                    'message' => 'deprecated also'
                  },
                 'Net::MQTT::Message::Publish'
              );

=cut

sub parse_data_to_obj {
    my ( $self, $msg, $p_setby ) = @_;

    $self->debug( 3, "Msg object: " . Dumper( $msg ) );

    if( !$msg->{message} ) {
	# cleanup message -- ignore
	return;
    }

    # 20-12-2020 added support for wildcard mqtt devices e.g. in items.mht
    # MQTT_DEVICE, MQTT_test_wildcard, , mqtt_1, tele/+/LWT
    # or for a multilevel wildcard
    # MQTT_DEVICE, MQTT_test_multi_wildcard, , mqtt_1, tele/#
    # NOTE, use of multi level wildcards can consume a lot of CPU
    # it also exits the loop if it finds a match for speed when there is a large number of mqtt devices

    my ( @split_incoming, @split_device, $counter, $device_topic, $message_handled );
    #
    $message_handled = 0;
    for my $obj ( @{ $$self{objects} } ) {
	# 2021/2/4 -- added support for a mqtt object to listen for a list of topics
	my @topiclist;
	if( ref $obj->{topic} eq 'ARRAY' ) {
	    @topiclist = @{$obj->{topic}};
	} else {
	    @topiclist = ( $obj->{topic} );
	}
        for $device_topic (@topiclist) {
	    # check if this mqtt device is a wildcard, and if so replace the wildcard characters
	    # with the incoming message topic pieces
	    if (   index( $device_topic, "\+" ) >= 0
		|| index( $device_topic, "\#" ) >= 0 )
	    {
		@split_incoming = split( "/", $msg->{topic} );
		@split_device   = split( "/", $device_topic );
		$counter        = 0;
		foreach (@split_device) {
		    if ( $split_device[$counter] eq "+"  &&  defined $split_incoming[$counter] ) {
			$device_topic =~ s/\+/$split_incoming[$counter]/;
		    }
		    if ( $split_device[$counter] eq "#" ) {
			$device_topic = substr( $device_topic, 0, index( $device_topic, "#" ) ) . substr( $$msg{topic}, index( $device_topic, "#" ) );
			last;
		    }
		    $counter++;
		}
	    }
    
	    # the edited device topic is now ready to compare with the incoming message topic
	    if ( $device_topic eq $msg->{topic} ) {
		if( $obj->can( 'receive_mqtt_message' ) ) {
		    $obj->receive_mqtt_message( $msg->{topic}, $msg->{message}, $msg->{retain} );
		} else {
		    $obj->{mqtt_retained} = $msg->{retain};
		    $obj->{set_by_topic} = $msg->{topic};
		    $obj->set( $msg->{message}, $self );
		}
		$message_handled = 1;
    
		# Note that multiple objects may listen for same topic and distinguish based on payload - must keep looping
		# last;
	    }
	}
    }
    if( !$message_handled ) {
	$self->debug( 2, "UNHANDLED MESSAGE $$msg{topic} -- $$msg{message}" );
    }
    if( $msg->{retain} ) {
	# this is a retained message from the mqtt broker -- record it so if we want to clean up the retained messages in the broker, we can
	$self->debug( 2, "ADDED RETAINED TOPIC $$msg{topic}" );
	$self->{retained_topics}->{$$msg{topic}} = $message_handled;
    }
}

# ------------------------------------------------------------------------------

=item C<(get_interface_list())>
=cut

sub get_interface_list {
    my @interfaces;

    for my $inst (keys %MQTT_Data) {
	push @interfaces, $MQTT_Data{$inst}{self};
    }
    return ( @interfaces );
}

# ------------------------------------------------------------------------------

=item C<(cleanup_retained_topics( @pattern_list ))>

Over time, retained messages accumulate in the broker.  When objects change names
or are removed from your setup, the retained messages remain.

This function is used to delete retained topics from the broker.  It will
publish an empty message to all retained topics matching a pattern in the
pattern list that misterhouse has received from this broker.

=cut

sub cleanup_retained_topics {
    my ($self, @topic_pattern_list) = @_;
    my $clean_count;
    my $ignore_count;

    if( scalar(@topic_pattern_list) == 0 ) {
	mqtt::error( "cleanup_retained_topics -- must specify pattern" );
	return;
    }
    $self->debug( 2, "cleanup topic pattern list: @topic_pattern_list" );
    $clean_count = 0;
    $ignore_count = 0;
    for my $topic ( keys %{$self->{retained_topics}} ) {
	my $match = 0;
	for my $topic_pattern (@topic_pattern_list) {
	    if( $topic_pattern ) {
		if( $topic =~ m|^${topic_pattern}| ) {
		    $match = 1;
		}
	    }
	}
	if( $match ) {
	    ++$clean_count;
	    $self->pub_msg( 
		message_type => MQTT_PUBLISH,
		retain       => 1,
		topic        => $topic,
		message      => ''
	    );
	    delete $self->{retained_topics}->{$topic};
	} else {
	    ++$ignore_count;
	    $self->debug( 2, "'$topic' being ignored for cleanup" );
	}
    }
    $self->log( "Cleanup unhandled topics for $self->{instance} complete:  $clean_count cleaned, $ignore_count ignored" );
}


=item C<(list_retained_topics())>

This function will list all retained topics received by misterhouse, and some
indication as to whether the topic was handled by some defined object.

=cut

sub list_retained_topics {
    foreach my $interface ( &get_interface_list() ) {
	for my $topic ( keys %{$interface->{retained_topics}} ) {
	    my $handled = $interface->{retained_topics}->{$topic};
	    $interface->log( "$$interface{instance} retained topic: ($handled) $topic" );
	}
    }
}


# ------------------------------------------------------------------------------


=item C<(publish_mqtt_message( topic, message, retain ))>

Publish an mqtt message.

=cut

sub publish_mqtt_message {
    my ($self, $topic, $msg, $retain ) = @_;

    $retain = 0 if !defined($retain);
    $self->pub_msg( 
	message_type => MQTT_PUBLISH,
	retain       => $retain,
	topic        => $topic,
	message      => $msg
    );
}

# ------------------------------------------------------------------------------

=item C<(broadcast_mqtt_message( topic, message, retain ))>

Broadcast an mqtt message to all defined brokers.

=cut

sub broadcast_mqtt_message {
    my ($topic, $msg, $retain ) = @_;
    my @instances;

    $retain = 0 if !defined($retain);
    (@instances) = (keys %MQTT_Data);
    foreach my $inst ( @instances ) {
        my $self = $MQTT_Data{$inst}{self};
	$self->publish_mqtt_message( $topic, $msg, $retain );
    }
}

# -[ Fini - mqtt ]--------------------------------------------------------------

package mqtt_Item;

use strict;

use Net::MQTT::Constants qw/:all/;

use Data::Dumper;

@mqtt_Item::ISA = ( 'Generic_Item', "mqtt" );

=item C<new(name, interface, topic, retain, qos)>

    Creates a MQTT Item/object. The following parameter are required:

    =over

    =item name: the name of the object seen in Misterhouse 

    =item interface: the parent (mqtt) object that holds the connection info.

    =item interface: the topic that is used to update the object state and/or control a mqtt device

    =back

    The following parameters are optional

    =over

    =item retain

    =item qos

    =back

    $msg = bless( { 'topic' => 'home/ha/test/x10/1',
    'remaining' => '',
    'retain' => 1,
    'dup' => 0,
    'message_type' => 3,
    'qos' => 0,
    'message' => 'deprecated also'
},
    'Net::MQTT::Message::Publish'
    );
=cut

sub new {
    my ( $class, $instance, $topic, $qos, $retain ) = @_;

    my $self = new Generic_Item();

    bless $self, $class;

    $self->interface($instance) if defined $instance;

    $$self{topic}   = $topic;
    $$self{message} = '';
    $$self{retain}  = $retain || 0;
    $$self{QOS}     = $qos    || 0;

    $$self{instance}->add($self);

    # We may need flags to deal with XML, JSON or Text
    return $self;
}

=item C<interface(name, interface, topic, retain, qos)>
=cut

sub interface {
    my ( $self, $p_instance ) = @_;

    $$self{instance} = $p_instance if defined $p_instance;

    return $$self{instance};
}

=item C<set(name, interface, topic, retain, qos)>
=cut

sub set {
    my ( $self, $msg, $p_setby, $p_response ) = @_;

    # prevent reciprocal sets that can occur because of this method's state
    # propogation
    # FIXME: Use of uninitialized value in string eq at /home/njc/dev/mh/bin/../lib/mqtt.pm line 752
    #return if (ref $p_setby and $p_setby->can('get_set_by') and
    #	       $p_setby->{set_by} eq $self);

    if ( defined($p_setby) && $p_setby eq $self->interface() ) {
        ###
        ### Incoming (MQTT to MH)
        ###
        $self->debug( 1, "mqtt_Item nom to MQTT to MH " . $self->get_object_name() . "::set($msg, $p_setby)" );
    }
    else {
        ###
        ### Outgoing (MH to MQTT)
        ###
	if ( defined( $self->get_object_name() ) ) {
	    $self->debug( 1, "mqtt_Item nom to MH to MQTT (" . $self->get_object_name() . ") no p_setby ::set($msg, $p_setby)" );
	}
	else {
	    $self->debug( 1, "mqtt_Item nom to MH to MQTT () no p_setby ::set($msg, $p_setby)" );
	}
        ###
        ### I need the instance socket, the obj's topic and message
        ### in order to send the message
        ###
        $$self{instance}->pub_msg(
            message_type => MQTT_PUBLISH,
            retain       => $$self{retain},
            topic        => $$self{topic},
            message      => $msg
        );
    }

    $self->SUPER::set( $msg, $p_setby, $p_response ) if defined $msg;
}

# -[ Fini - mqtt_Item ]---------------------------------------------------------

# -[ Fini ]---------------------------------------------------------------------
1;

=begin comment
The set_by has me currently puzzled, I'm not sure of it's purpose

The state, state_now and said aren't exactly helping much either ;-)

03/24/15 10:19:49 AM *** mqtt mqtt set mqtt_1: [(on), (web [192.168.24.232])]
03/24/15 10:19:49 AM *** mqtt mqtt set mqtt_1:
$VAR1 = \bless( {
                   'states' => [
                                 'off',
                                 'on'
                               ],
                   'state_now' => '',
                   'state' => '',
                   'objects' => [
                                  bless( {
                                           'legacy_target' => undef,
                                           'tied_objects' => {},
                                           'states' => [
                                                         'off',
                                                         'on'
                                                       ],
                                           'QOS' => 0,
                                           'state_changed' => undef,
                                           'set_by' => undef,
                                           'state_prev' => 'x1xon',
                                           'set_time' => '1427120068',
                                           'state_now' => undef,
                                           'state' => 'x1xon',
                                           'target' => '',
                                           'setby_next_pass' => [],
                                           'state_next_pass' => [],
                                           'state_log' => [
                                                            '03/20/15 02:51:04 PM x1xon set_by=$mqtt_3',
                                                            '03/20/15 01:15:50 PM x1xon set_by=$mqtt_1',
                                                            '03/20/15 01:15:00 PM x1xon set_by=$mqtt_1',
                                                            '03/20/15 01:01:35 PM on set_by=$mqtt_1',
                                                          ],
                                           'category' => 'Other',
                                           'topic' => 'home/ha/text/x10/1',
                                           'said' => undef,
                                           'retain' => 0,
                                           'tied_events' => {},
                                           'change_pass' => 1,
                                           'target_next_pass' => [],
                                           'instance' => ${$VAR1},
                                           'message' => '',
                                           'filename' => 'CapeCod_table',
                                           'object_name' => '$CR_Temp'
                                         }, 'mqtt_Item' ),
                                  bless( {
                                           'legacy_target' => undef,
                                           'tied_objects' => {},
                                           'states' => [
                                                         'off',
                                                         'on'
                                                       ],
                                           'QOS' => 0,
                                           'state_changed' => undef,
                                           'set_by' => ${$VAR1},
                                           'state_prev' => 'x1xon',
                                           'set_time' => 1427206784,
                                           'state_now' => undef,
                                           'state' => 'x1xon',
                                           'target' => '',
                                           'setby_next_pass' => [],
                                           'state_next_pass' => [],
                                           'state_log' => [
                                                            '03/24/15 10:19:44 AM x1xon set_by=$mqtt_3',
                                                            '03/24/15 10:18:08 AM x1xon set_by=$mqtt_3',
                                                            '03/24/15 10:15:54 AM x1xon set_by=$mqtt_3',
                                                            '03/24/15 10:12:59 AM x1xon set_by=$mqtt_3',
                                                            '03/24/15 10:10:10 AM x1xon set_by=$mqtt_3',
                                                            '03/24/15 08:22:51 AM x1xon set_by=$mqtt_3',
                                                            '03/23/15 11:08:48 AM x1xon set_by=$mqtt_3',
                                                            '03/20/15 02:51:02 PM x1xon set_by='
                                                          ],
                                           'category' => 'Other',
                                           'topic' => 'home/network/test/x10/1',
                                           'said' => undef,
                                           'retain' => 0,
                                           'tied_events' => {},
                                           'change_pass' => 9,
                                           'target_next_pass' => [],
                                           'instance' => ${$VAR1},
                                           'message' => '',
                                           'filename' => 'CapeCod_table',
                                           'object_name' => '$M3_Temp'
                                         }, 'mqtt_Item' )
                                ],
                   'command_stack' => [],
                   'category' => 'Other',
                   'topic' => 'home/ha/#',
                   'got_ping_response' => 1,
                   'said' => '',
                   'instance' => 'mqtt_1',
                   'port' => 1883,
                   'keep_alive_timer' => 121,
                   'host' => '127.0.0.1',
                   'socket' => bless( \*Symbol::GEN6, 'IO::Socket::INET' ),
                   'filename' => 'CapeCod_table',
                   'next_ping' => '1427206904.98476',
                   'object_name' => '$mqtt_3'
                 }, 'mqtt' );

--------------------------------------------------------------------------------
=cut
