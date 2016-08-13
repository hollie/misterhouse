######################
# Interface Package #
######################

=head1 B<MySensors::Interface>

=head2 SYNOPSIS

Usage

The current version supports ethernet and serial gateways.

The interface must be defined with 3 parameters: a type (serial or ethernet),
an address (/dev/tty or an IP address:TCP port number) and a name used to
easily identify the interface.

Note that in MySensors terms the interface used here is an interface to a
MySensors gateway.

The node must be defined with 3 parameters: a node ID, name and gateway
object.

The sensors must also be defined with 3 parameters: a sensor ID, name and
node object.

Debugging information can be enabled by setting:
debug=MySensors

in a Misterhouse INI file.

In user code:

    $basement_gateway = new MySensors::Interface(serial, "/dev/ttyACM0", "Basement Gateway");
    $media_room_gateway = new MySensors::Interface(ethernet, "192.168.0.22:5003", "Media Room Gateway");

    $bedroom_node = new MySensors::Node(1, "Bedroom Node", $media_room_gateway);

    $bedroom_motion = new MySensors::Motion(1, "Bedroom Motion", $bedroom_node);
    if (state_now($bedroom_motion) eq ON) { print_log "Motion detected in the bedroom" };

=head2 DESCRIPTION

Class implementation of a MySensors interface.  For details see:
https://mysensors.readthedocs.io/en/latest/protocol.html

Gateway message format is:
<node-id>;<child-sensor-id>;<message-type>;<ack>;<sub-type>;<payload>\n

Maximum payload is 25 bytes

Note that in MySensor terms the interface is known as a gateway, the sensor
radio is known as a node and the sensors themselves are known as children. 

Last updated for MySensors release 2.0
Last modified: 2016-08-12

Known Limitations:
1. The current implementation does not distinguish SET/REQ and treats them all
as SET
2. The current implementaton handles only a small number of the most common
sensor types.  More may be added in the future.
3. The current implementation does not distinguish SET/REQ subtypes which
means any sensor that sends multiple subtypes will behave unpredictably.
4. The current implementation assumes all subtypes are read/write.  This may
cause problems if an input is written to.  For example, writing to most input
pins will enable/disable the internal pullup resistor.  While this may be
desirable in some cases it could result in unexpected behavior. 
5. Very little error trapping is done so errors in configuration or
incompatible sensor implementations could cause unpredictable behavior or even
crash Misterhouse.
6. The current implementation does not use ACKs
7. The current implementation does not handle units (or requests for units)
8. The current implementation does not attempt to reconnect any port or socket
disconnection

=head2 INHERITS

L<Generic_Item|Generic_Item>

=head2 METHODS

=over

=cut

package MySensors::Interface;

use parent 'Generic_Item';

use strict;

# API details as of release 2.0
# For more information see: https://www.mysensors.org/download/serial_api_20
our @types = ( 'presentation', 'set', 'req', 'internal', 'stream' );

# Define names of presentations
our @presentations = (
    'S_DOOR',                  'S_MOTION',
    'S_SMOKE',                 'S_LIGHT',
    'S_DIMMER',                'S_COVER',
    'S_TEMP',                  'S_HUM',
    'S_BARO',                  'S_WIND',
    'S_RAIN',                  'S_UV',
    'S_WEIGHT',                'S_POWER',
    'S_HEATER',                'S_DISTANCE',
    'S_LIGHT_LEVEL',           'S_ARDUINO_NODE',
    'S_ARDUINO_REPEATER_NODE', 'S_LOCK',
    'S_IR',                    'S_WATER',
    'S_AIR_QUALITY',           'S_CUSTOM',
    'S_DUST',                  'S_SCENE_CONTROLLER',
    'S_RGB_LIGHT',             'S_RGBW_LIGHT',
    'S_COLOR_SENSOR',          'S_HVAC',
    'S_MULTIMETER',            'S_SPRINKLER',
    'S_WATER_LEAK',            'S_SOUND',
    'S_VIBRATION',             'S_MOISTURE',
    'S_INFO',                  'S_GAS',
    'S_GPS',                   'S_WATER_QUALITY'
);

# Define names for the set/req subtypes
our @setreq = (
    'V_TEMP',               'V_HUM',
    'V_STATUS',             'V_PERCENTAGE',
    'V_PRESSURE',           'V_FORECAST',
    'V_RAIN',               'V_RAINRATE',
    'V_WIND',               'V_GUST',
    'V_DIRECTION',          'V_UV',
    'V_WEIGHT',             'V_DISTANCE',
    'V_IMPEDANCE',          'V_ARMED',
    'V_TRIPPED',            'V_WATT',
    'V_KWH',                'V_SCENE_ON',
    'V_SCENE_OFF',          'V_HVAC_FLOW_STATE',
    'V_HVAC_SPEED',         'V_LIGHT_LEVEL',
    'V_VAR1',               'V_VAR2',
    'V_VAR3',               'V_VAR4',
    'V_VAR5',               'V_UP',
    'V_DOWN',               'V_STOP',
    'V_IR_SEND',            'V_IR_RECEIVE',
    'V_FLOW',               'V_VOLUME',
    'V_LOCK_STATUS',        'V_LEVEL',
    'V_VOLTAGE',            'V_CURRENT',
    'V_RGB',                'V_RGBW',
    'V_ID',                 'V_UNIT_PREFIX',
    'V_HVAC_SETPOINT_COOL', 'V_HVAC_SETPOINT_HEAT',
    'V_HVAC_FLOW_MODE',     'V_TEXT',
    'V_CUSTOM',             'V_POSITION',
    'V_IR_RECORD',          'V_PH',
    'V_ORP',                'V_EC',
    'V_VAR',                'V_VA',
    'V_POWER_FACTOR'
);

# Define names for the internals
our @internals = (
    'I_BATTERY_LEVEL',        'I_TIME',
    'I_VERSION',              'I_ID_REQUEST',
    'I_ID_RESPONSE',          'I_INCLUSION_MODE',
    'I_CONFIG',               'I_FIND_PARENT',
    'I_FIND_PARENT_RESPONSE', 'I_LOG_MESSAGE',
    'I_CHILDREN',             'I_SKETCH_NAME',
    'I_SKETCH_VERSION',       'I_REBOOT',
    'I_GATEWAY_READY',        'I_REQUEST_SIGNING',
    'I_GET_NONCE',            'I_GET_NONCE_RESPONSE',
    'I_HEARTBEAT',            'I_PRESENTATION',
    'I_DISCOVER',             'I_DISCOVER_RESPONSE',
    'I_HEARTBEAT_RESPONSE',   'I_LOCKED',
    'I_PING',                 'I_PONG',
    'I_REGISTRATION_REQUEST', 'I_REGISTRATION_RESPONSE',
    'I_DEBUG'
);

=item C<new()>

Instantiates a new interface.

=cut

sub new {
    my ( $class, $type, $address, $name ) = @_;
    my $self = {};
    bless $self, $class;

    $$self{type}    = $type;
    $$self{address} = $address;
    $$self{name}    = $name;

    # Also create the hash to store the node objects reachable from this gateway so we know what they are when we receive a message for them.
    # Note that each sensor needs to be added to the sensors hash of the node also to track the sensors attached to that node.
    $$self{nodes} = {};

    if ( $type =~ /ethernet/i ) {

        # Note that socket will contain a reference to the IO::Socket object
        $$self{"socket"} = $self->create_socket( $address, $name );
    }
    elsif ( $type =~ /serial/i ) {

        # Note that serial will contain the name of the MH serial object
        $$self{"serial"} = $self->create_serial( $address, $name );
    }

    # Also add a hook to the main loop to check for gateway messages
    &main::MainLoop_pre_add_hook( sub { $self->loop() }, 'persistent' );

    return $self;
}

=item C<add_node()>

Adds a new node to a gateway.

Returns zero for success or the failed node_id otherwise.

=cut

sub add_node {
    my ( $self, $node_id, $node ) = @_;

    if ( exists $$self{nodes}{$node_id} ) {
        &::print_log(
            "[MySensors] ERROR: $$self{name} tried to add new node \"$$node{name}\" (ID: $node_id) but a node \"$$self{nodes}{$node_id}{name} (ID: $node_id) already exists!"
        );
        return $node_id;
    }
    else {
        &::print_log(
            "[MySensors] INFO: $$self{name} added node \"$$node{name}\" (ID: $node_id)"
        );
        $$self{nodes}{$node_id} = $node;
    }

    return 0;
}

=item C<create_socket()>

Creates a socket to the Ethernet gateway.

=cut

sub create_socket {
    my ( $self, $address, $name ) = @_;
    print $name . "_socket\n";

    # By default suport only TCP gateways.  UDP could be added in the future
    my $socket =
      new Socket_Item( undef, undef, $address, $name . "_socket", 'tcp',
        'raw' );
    start $socket;

    return $socket;
}

=item C<create_serial()>

Creates a serial port to the serial gateway.

Returns the name of the serial port.

=cut

sub create_serial {
    my ( $self, $address ) = @_;

    # Setup the name and break character of the serial port
    my $name  = $$self{name} . "_serial";
    my $break = $name . "break";
    $main::config_parms{$break} = '\n';

    &main::serial_port_create( $name, $address, 115200, 'none' );
    die "[MySensors] ERROR: $$self{name} can't open gateway port $address: $!\n"
      unless $main::Serial_Ports{$name}{object};

    return $name;
}

=item C<get_serial_data()>

Gets new messages from the MySensors gateway.

Returns the message (if available) or null if there is no data.

=cut

sub get_serial_data {
    my ( $self, $serial ) = @_;

    &::check_for_generic_serial_data($serial);
    my $data = $::Serial_Ports{$serial}{data_record};
    if ($data) {
        $::Serial_Ports{$serial}{data_record} = undef;
        &::print_log("[MySensors] DEBUG: $$self{name} received message: $data")
          if $::Debug{mysensors};
    }

    return $data;
}

=item C<get_socket_data()>

Gets new messages from the MySensors gateway.

Returns the message (if available) or null if there is no data.

=cut

sub get_socket_data {
    my ( $self, $socket ) = @_;

    my $data = said $socket;

    # Strip off the trailing newline
    chomp $data;
    if ($data) {
        &::print_log("[MySensors] DEBUG: $$self{name} received message: $data")
          if $::Debug{mysensors};
    }

    return $data;
}

=item C<loop()>

Attaches to the main Misterhouse loop to check for gateway activity on each pass

=cut

sub loop {
    my ($self) = @_;
    my $data;

    # On each pass check for new data
    if ( $$self{type} =~ /ethernet/i ) {
        $data = $self->get_socket_data( $$self{"socket"} );
    }
    elsif ( $$self{type} =~ /serial/i ) {
        $data = $self->get_serial_data( $$self{"serial"} );
    }

    # If there is data then parse it
    if ($data) {
        $self->parse_message($data);
    }

    return 0;
}

=item C<parse_message()>

Parse a MySensors message received from a gateway

=cut

sub parse_message {
    my ( $self, $message ) = @_;

    # Standard API messages are 6 values separated by semicolons

    if ( $message =~ /(\d{1,3});(\d{1,3});(\d{1,3});([01]);(\d{1,3});*(.*)/ ) {
        my ( $node_id, $child_id, $type, $ack, $subtype, $data ) =
          ( $1, $2, $3, $4, $5, $6 );

        # Handle presentation (type 0)  messages
        if ( $type == 0 ) {
            &::print_log(
                "[MySensors] INFO: $$self{name} recieved presentation for $$self{nodes}{$node_id}{name} (ID: $node_id) $$self{nodes}{$node_id}{sensors}{$child_id}{name} (ID: $child_id) subtype $subtype ($presentations[$subtype]) data $data"
            );

            # Handle set/req (type 1, 2) messages
            # Note: these two types are not currently distinguished and both are treated as SET requests!
        }
        elsif ( ( $type == 1 ) || ( $type == 2 ) ) {
            if ( exists( $$self{nodes}{$node_id}{sensors}{$child_id} ) ) {
                &::print_log(
                    "[MySensors] INFO: $$self{name} received set message for $$self{nodes}{$node_id}{name} (ID: $node_id) $$self{nodes}{$node_id}{sensors}{$child_id}{name} (ID: $child_id) to "
                      . $$self{nodes}{$node_id}{sensors}{$child_id}
                      ->convert_data_to_state($data)
                      . " ($data)" );
                $$self{nodes}{$node_id}{sensors}{$child_id}->set_receive($data);
            }
            else {
                &::print_log(
                    "[MySensors] WARN: $$self{name} recieved unrecognized set/req: node=$node_id, child=$child_id, subtype=$subtype ($setreq[$subtype]), data=$data"
                );
            }

            # Handle internal (type 3) messages
        }
        elsif ( $type == 3 ) {

            # Handle gateway messages (node 0, child 255)
            if ( ( $node_id == 0 ) && ( $child_id == 255 ) ) {

                # Don't print SANCHK messages as they just clutter the logs
                if ( $data ne 'TSP:SANCHK:OK' ) {
                    &::print_log(
                        "[MySensors] INFO: $$self{name} received $internals[$subtype]: $data"
                    );
                }

                # Handle requests for node ID (subtype 3)
            }
            elsif (( $node_id == 255 )
                && ( $child_id == 255 )
                && ( $subtype == 3 ) )
            {
                if ( !exists $::Save{MySensors_next_node_id} ) {
                    $::Save{MySensors_next_node_id} = 1;
                }

                my $next_id = $::Save{MySensors_next_node_id};
                &::print_log(
                    "[MySensors] INFO: $$self{name} recieved node ID request.  Assigned node ID $next_id."
                );

                $self->send_message( 255, 255, 3, 0, 4, $next_id );

                # Increment the next node ID
                $::Save{MySensors_next_node_id} = $next_id + 1;

                # Otherwise we don't know about this type of internal message
            }
            else {
                &::print_log(
                    "[MySensors] WARN: $$self{name} recieved unrecognized internal: node=$node_id, child=$child_id, subtype=$subtype ($internals[$subtype]), data=$data"
                );
            }

            # Handle stream (type 4) messages
        }
        elsif ( $type == 4 ) {
            &::print_log(
                "[MySensors] WARN: $$self{name} recieved stream message (unsupported): node=$node_id, child=$child_id, subtype=$subtype, data=$data"
            );

            # Any other message is unrecognized
        }
        else {
            &::print_log(
                "[MySensors] ERROR: $$self{name} recieved unrecognized message: node=$node_id, child=$child_id, type=$type, subtype=$subtype, data=$data"
            );
        }

        # If gateway debug is enabled in the Arduino then other non-standard messages may be received
    }
    else {
        &::print_log(
            "[MySensors] DEBUG: $$self{name} received Arduino debug message: $message"
        ) if $::Debug{mysensors};
    }
}

=item C<send_message()>

Send a MySensors message to the gateway

=cut

sub send_message {
    my ( $self, $node_id, $child_id, $type, $ack, $subtype, $data ) = @_;

    # Standard API messages are 6 values separated by semicolons
    my $message = "$node_id;$child_id;$type;$ack;$subtype;$data\n";

    if ( $$self{type} =~ /ethernet/i ) {

        # Note that socket will contain a reference to the Misterhouse Socket_Item object
        $$self{socket}->set($message);
    }
    elsif ( $$self{type} =~ /serial/i ) {

        # Note that serial will contain the name of the Misterhouse serial object
        $::Serial_Ports{ $$self{serial} }{object}->write($message);
    }

    &::print_log("[MySensors] DEBUG: $$self{name} sent message: $message")
      if $::Debug{mysensors};

    return 0;
}

################
# Node Package #
################

# Note that the nodes are also Generic_Items not MySensors::Interfaces.  This
# is similar to the Insteon design but not X10.

package MySensors::Node;

use strict;

use parent 'Generic_Item';

=item C<new()>

Instantiates a new node.

=cut

sub new {
    my $class = shift;
    my ( $node_id, $name, $gateway ) = @_;

    # Instantiate as a Generic_Item first
    my $self = $class->SUPER::new(@_);

    $$self{node_id} = $node_id;
    $$self{name}    = $name;
    $$self{gateway} = $gateway;

    # Push this node information to the gateway
    $gateway->MySensors::Interface::add_node( $node_id, $self );

    # Also create the hash to store the sensor objects reachable from this node so we know what they are when we receive a message for them.
    $$self{sensors} = {};
    return $self;
}

=item C<add_sensor()>

Adds a new child sensor to a node.

Returns zero for success or the failed child_id otherwise.

=cut

sub add_sensor {
    my ( $self, $child_id, $sensor ) = @_;

    if ( exists $$self{sensor}{$child_id} ) {
        &::print_log(
            "[MySensors] ERROR: $$self{gateway}{name} tried to add new sensor $child_id to node $$self{name} (ID $$self{node_idname}) but a child $child_id already exists!"
        );
        return $child_id;
    }
    else {
        &::print_log(
            "[MySensors] INFO: $$self{gateway}{name} added $$sensor{name} (ID: $child_id) to $$self{name} (ID $$self{node_id})"
        );
        $$self{sensors}{$child_id} = $sensor;
    }

    return 0;
}

##################
# Sensor Package #
##################

# All varieties of sensors are children of the MySensors::Sensor

package MySensors::Sensor;

use strict;

use parent 'Generic_Item';

=item C<new()>

Instantiates a new sensor.

=cut

sub new {
    my $class = shift;
    my ( $child_id, $name, $node ) = @_;

    # Instantiate as a Generic_Item first
    my $self = $class->SUPER::new(@_);

    $$self{name} = $name;

    $$self{child_id} = $child_id;
    $$self{node}     = $node;

    # Push this sensor information to the node
    $node->MySensors::Node::add_sensor( $child_id, $self );

    return $self;
}

=item C<set_states()>

Sets the appropriate states for the sensor item

Returns 0.

=cut

sub set_states {
    my ($self) = @_;

    # Each sensor device should have valid states stored in the keys of the state_to_data hash
    if ( keys %{ $$self{state_to_data} } ) {
        $self->SUPER::set_states( keys %{ $$self{state_to_data} } );
    }
    else {
        &::print_log(
            "[MySensors] ERROR: $$self{gateway}{name} Could not find valid states for node $$self{node}{node_id} sensor $$self{child_id}!  This is likely a bug in the sensor package."
        );
    }

    return 0;
}

=item C<convert_data_to_state([data])>

Converts MySensors data into a Misterhouse state when receiving a message from
the interface.

Returns state or null if no conversion was found.

=cut

sub convert_data_to_state {
    my ( $self, $data ) = @_;
    my $state = '';

    # Each sensor device with predefined states should have two hashes mapping misterhouse state to data and data to state
    if ( exists $$self{data_to_state}{$data} ) {
        $state = $$self{data_to_state}{$data};

        # Some sensors return numerical values and for these the state and data are the same
    }
    elsif (( $$self{type} == 0 )
        || ( $$self{type} == 1 )
        || ( $$self{type} == 3 ) )
    {
        $state = $data;
    }

    return $state;
}

=item C<convert_state_to_data([state])>

Converts a misterhouse state into MySensors data when sending a message to
the interface.

Returns data or null if no conversion was found.

=cut

sub convert_state_to_data {
    my ( $self, $state ) = @_;
    my $data = '';

    # Each sensor device should have two hashes mapping misterhouse state to data and data to state
    if ( exists $$self{state_to_data}{$state} ) {
        $data = $$self{state_to_data}{$state};

        # Some sensors return numerical values and for these the state and data are the same
    }
    elsif (( $$self{type} == 0 )
        || ( $$self{type} == 1 )
        || ( $$self{type} == 3 ) )
    {
        $data = $state;
    }

    return $data;
}

=item C<type([type])>

Used to store and return the associated type of a sensor.

Type is an 8 bit integer value defined in the API here:
https://www.mysensors.org/download/serial_api_15

Type is called by each individual child sensor

If provided, stores type as the sensor's type.

Returns type.

=cut

sub type {
    my ( $self, $type ) = @_;

    $$self{type} = $type;

    return $type;
}

=item C<set([state], [set_by], [respond])>

Used to update the state of an object when an update is received from the
interface or update the state and send a message to the interface when set by
anything else.

Returns state.

=cut

sub set {
    my ( $self, $state, $set_by, $respond ) = @_;

    # Check if the set_by is not the interface, in which case the message needs to be sent first
    if ( $$self{node}{gateway} != $set_by ) {

        # Find the data that corresponds to the state for this device
        my $data = $self->convert_state_to_data($state);

        # Make sure $data isn't null.  Null means valid data isn't present for this state.
        if ( $data ne '' ) {

            # By default send the first (primary) subtype and use type 1 (SET) without ACK
            $$self{node}{gateway}->send_message( $$self{node}{node_id},
                $$self{child_id}, 1, 0, $$self{subtypes}[0], $data );
        }
        else {
            &::print_log(
                "[MySensors] ERROR: $$self{node}{gateway}{name} cannot find state \"$state\" for $$self{node}{name} (ID: $$self{node}{node_id}) $$self{name} (ID: $$self{child_id}).  Was the correct type of sensor used?"
            );
        }
    }

    # Now call the Generic_Item set method to update the object and trigger state_now etc.
    $self->SUPER::set( $state, $set_by, $respond );

    return $state;
}

=item C<set_receive([data])>

Used to update the state of an object when a state update is received from the
interface.

Returns state

=cut

sub set_receive {
    my ( $self, $data ) = @_;

    # This is called only by the interface to update the state of a sensor based on a received message.
    # Find the data that corresponds to the state for this device
    my $state = $self->convert_data_to_state($data);

    # Make sure $state isn't null.  Null means valid state isn't present for this data (ex: incorrect sensor type used).
    if ( $state ne '' ) {
        $self->set( $state, $$self{node}{gateway} );
    }
    else {
        &::print_log(
            "[MySensors] ERROR: $$self{node}{gateway}{name} cannot find state \"$state\" for data \"$data\" for $$self{node}{name} (ID: $$self{node}{node_id}) $$self{name} (ID: $$self{child_id}).  Was the correct type of sensor used?"
        );
    }

    return $state;
}

################
# Door Package #
################

package MySensors::Door;

use strict;

use parent-norequire, 'MySensors::Sensor';

=item C<new()>

Instantiates a new door/window sensor.

=cut

sub new {
    my $class = shift;

    # Instantiate as a MySensors::Sensor first
    my $self = $class->SUPER::new(@_);

    # Door is presentation type 0
    $$self{type} = 0;

    # Door type sensors use the V_TRIPPED and V_ARMED subtypes
    $$self{subtypes} = [ 16, 15 ];

    # Also define the data to state and state to data mappings
    $$self{data_to_state} = { 0        => 'closed', 1        => 'opened' };
    $$self{state_to_data} = { 'closed' => 0,        'opened' => 1 };

    # Add the states to the item
    $self->set_states();

    return $self;
}

#########################
# Motion Sensor Package #
#########################

package MySensors::Motion;

use strict;

use parent-norequire, 'MySensors::Sensor';

=item C<new()>

Instantiates a new motion sensor.

=cut

sub new {
    my $class = shift;

    # Instantiate as a MySensors::Sensor first
    my $self = $class->SUPER::new(@_);

    # Motion sensors are presentation type 1
    $$self{type} = 1;

    # Motion sensors use the V_TRIPPED and V_ARMED subtypes
    $$self{subtypes} = [ 16, 15 ];

    # Also define the data to state and state to data mappings
    $$self{data_to_state} = { 0       => 'still', 1        => 'motion' };
    $$self{state_to_data} = { 'still' => 0,       'motion' => 1 };

    # Add the states to the item
    $self->set_states();

    return $self;
}

#################
# Light Package #
#################

package MySensors::Light;

use strict;

use parent-norequire, 'MySensors::Sensor';

=item C<new()>

Instantiates a new light.

=cut

sub new {
    my $class = shift;

    # Instantiate as a MySensors::Sensor first
    my $self = $class->SUPER::new(@_);

    # Lights and binary are presentation type 3
    $$self{type} = 3;

    # Light and binary type sensors use the V_STATUS and V_WATT subtypes
    $$self{subtypes} = [ 2, 17 ];

    # Also define the data to state and state to data mappings
    $$self{data_to_state} = { 0     => 'off', 1    => 'on' };
    $$self{state_to_data} = { 'off' => 0,     'on' => 1 };

    # Add the states to the item
    $self->set_states();

    return $self;
}

##################
# Binary Package #
##################

package MySensors::Binary;

use strict;

use parent-norequire, 'MySensors::Sensor';

=item C<new()>

Instantiates a new binary sensor.  This is an alias for a light.

=cut

sub new {
    my $class = shift;

    # Instantiate as a MySensors::Sensor first
    my $self = $class->SUPER::new(@_);

    # Lights and binary are presentation type 3
    $$self{type} = 3;

    # Light and binary type sensors use the V_STATUS and V_WATT subtypes
    $$self{subtypes} = [ 2, 17 ];

    # Also define the data to state and state to data mappings
    $$self{data_to_state} = { 0     => 'off', 1    => 'on' };
    $$self{state_to_data} = { 'off' => 0,     'on' => 1 };

    # Add the states to the item
    $self->set_states();

    return $self;
}

#######################
# Temperature Package #
#######################

package MySensors::Temperature;

use strict;

use parent-norequire, 'MySensors::Sensor';

=item C<new()>

Instantiates a new temperature sensor.

=cut

sub new {
    my $class = shift;

    # Instantiate as a MySensors::Sensor first
    my $self = $class->SUPER::new(@_);

    # Temperature are presentation type 6
    $$self{type} = 6;

    # Temperature type sensors use the V_TEMP and V_ID subtypes
    $$self{subtypes} = [ 0, 42 ];

    # Note: there are no predefined states or state mappings for temperature sensors

    return $self;
}

####################
# Humidity Package #
####################

package MySensors::Humidity;

use strict;

use parent-norequire, 'MySensors::Sensor';

=item C<new()>

Instantiates a new humidity sensor.

=cut

sub new {
    my $class = shift;

    # Instantiate as a MySensors::Sensor first
    my $self = $class->SUPER::new(@_);

    # Humidity are presentation type 7
    $$self{type} = 7;

    # Humidity type sensors use the V_HUM subtype
    $$self{subtypes} = [1];

    # Note: there are no predefined states or state mappings for temperature sensors

    return $self;
}

=head2 AUTHOR

Jeff Siddall (news@siddall.name)

=head2 LICENSE

This program is free software; you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation; either version 2 of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more details.

You should have received a copy of the GNU General Public License along with this program; if not, write to the Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.

=cut

