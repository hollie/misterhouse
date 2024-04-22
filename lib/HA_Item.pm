# ------------------------------------------------------------------------------


=begin comment
    @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@

    =head1 B<HA_Server>
    =head1 B<HA_Item>

    Dave Neudoerffer <dave@neudoerffer.com>

    =head2 SYNOPSIS

    A HomeAssistant (HA) Items module for Misterhouse.
    Uses HA web socket interface.


    =head2 DESCRIPTION

    Misterhouse items class for control of HomeAssistant Entities

    Processes the HomeAssistant entity states response on startup.

    HA web socket doc:  https://developers.home-assistant.io/docs/api/websocket/

File:
    HA_Item.pm

Description:
    This is a misterhouse style items interface for HomeAssistant entities

    Author(s):
    Dave Neudoerffer <dave@neudoerffer.com>
    H Plato

    HA Items (HA_Item.pm)
    --------------------------

    There are several HA entity types implemented in this module (see below).

    Each MH item can handle both commands and state messages to/from MQTT devices.

    There are two classes implemented in HA_Item.pm:

    HA_Server:
         - this class connects to and manages the connection to HomeAssistant server
         - it uses a Socket_Item to manage the tcp/ip connection
         - it uses perl module Protocol::WebSocket::Client to manage the websocket
         - if the socket drops, reconnects will be attempted every 10s until connection successful
         - sends a ping request every <keep_alive_timer> seconds -- default 10s
         - this object requires a HomeAssistant Long Lived Access Token
            - aquire in HomeAssistant UI
            - go to your profile under your user name lower left corner
            - create token
            - *** Make sure you copy the whole thing
         - sends entity state request on startup and processes states for all devices

    HA_Item
        - implements an MH item that is tied to a HA entity on the specified HA Server
        - state changes from HA are monitored and reflected in the mh item state
        - the full HA state object is saved in {ha_state}
        - when the MH item is set locally, a state change is sent to HA
            - state is not reflected locally until the state change is received back from HA
        *** IMPORTANT *** : not all HA Entity types are supported.
        *** IMPORTANT *** : To mimic the MH 'one object one state' approach, subtypes are used in the domain based on HA attributes
            - light:  on, off and brightness
                    :rgb_color : for setting an RGB value
            - cover: open,close
            - lock: lock, unlock
            - switch: on,off
            - sensor, binary_sensor:
                - can group multiple sensors into a single MH item -- populates $item->{attr} hash
                - use one or more patterns to match HA entity names, separated by |
                - currently only pattern supported is entity_prefix_* (text with a '*' at the end)
            - climate:
                    (settable subtypes)
                    :hvac_mode              # hvac mode
                    :onoff
                    :preset_mode
                    :fan_mode
                    :temperature            # setpoint for non-(auto/heatcool) hvac mode
                    :target_temp_low        # heat setpoint
                    :target_temp_high       # cool setpoint
                    :humidity               # humidity setpoint
                    :swing_mode

                    (sensor only subtypes)
                    :current_temperature    # sensor only
                    :current_humidity       # sensor only
                    ...
                - populates $thermostat->{ha_state} with thermostat set value that includes {attributes} hash 
                  which includes thermostat attributes like setpoints, temperatures, mode, presets etc.
                    - can use any of these attributes as subtype for MH object
                - can use settable subtypes for modifications
                    eg.  $thermostat_preset_mode->set( "home" );
                    eg.  $thermostat_target_temp_low->set( 72 );
        - ha_call_service can be used to generically call a service on an entity
            - this can be used for 2 different things:
                1. you can treat complex HA entities as a single MH item, and use
                   this function to call the various services on the HA entity
                2. if the MH code doesn't implement all of the HA entity services, or there
                   are custom services on the entity, then you can call them with this function
            eg. $thermostat->ha_call_service( 'set_preset_mode', {preset_mode=>'away'} );

    

    Discovery:
    ----------

    The HA_Server object will send out an HA entity state query on connection.
    The response is processed for all entities that have had a local MH item defined.

    There are voice commands ceated to list HA entites -- handled, unhandled or all


    Publishing MH items to HA:
    --------------------------

    You can achieve the opposite direction, publishing MH items to HA, by using MQTT.


License:
    This free software is licensed under the terms of the GNU public license.

Usage:

    config parms:
        homeassistant_address=
        homeassistant_api_key=


    .mht file:

        # HA_SERVER,    obj name,       address,        keepalive,      api_key   
        HA_SERVER,      ha_house,       10.3.1.20:8123, 10,             XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX

        #HA_ITEM,       object_name,            domain[:subtype],   ha_entity,                  ha_server
        HA_ITEM,        shed_counter_pots,      light,              shed_counter_pots,          ha_house
        HA_ITEM,        water,                  switch,             house_water_socket,         ha_house
        HA_ITEM,        thermostat,             climate,            family_room_thermostat,     ha_house
        HA_ITEM,        ecowitt_weather,        sensor,             hp2551bu_pro_v1_7_6_*|ecowitt_cottage_weather_*, ha_house
        HA_ITEM,        led_strip,              light:rgb,          yeelight_012342,    ha_house



    and misterhouse user code:

        require HA_Item;

        $ha_house = new HA_Server( 'ha_house', '10.2.1.20:8123', '10', 'xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx' );
        $ha_house = new HA_Server( 'ha_house' );  # address and api_key from .ini file

        $water = new HA_Item( 'switch', 'house_water_socket', $ha_house );

        #
        if( state_changed $water ) {
            &print_log( "Bootroom light set " . $bootroom_switch->state_changed() );
        }

        #
        if( new_minute(10) ) {
            # this will toggle the light by sending a HA message
            $shed_counter_lights->set( 'toggle' );
        }

    publishing MH items to HA:

	Put these at the top of the items.mht file:
	
	MQTT_BROKER,	<mh-mqtt-broker-object>, ,  <broker-ip>
	MQTT_DISCOVERY,<mh-mqtt-discovery-object>,  <discovery_prefix>, <mh-mqtt-broker-object>, <discovery_action>
	
	For each MH object to synchronize, create a MQTT Local Item
	MQTT_LOCALITEM, <mh-mqtt-object>, <mh-object-to-sync>, <mh-mqtt-broker-object>, <ha object type>,  <node-id>/<mh-object-to-sync>/+, <discoverable>, <Friendly Name>
	
	ie
	MQTT_BROKER,	mqtt1, ,    10.0.0.8
	MQTT_DISCOVERY, mqtt_disc_mqtt1,    homeassistant, mqtt1, publish
	
	INSTEON_SWITCHLINC,     AA.BB.CC,    entry_light,    All_Lights
	MQTT_LOCALITEM, entry_light_mqtt, entry_light, mqtt1, light,    mh/entry_light/+, 1, Entry Light

	See mqtt_items.pm for more documentation.

Notes:
    @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@

    References:
        https://developers.home-assistant.io/docs/api/rest
        https://developers.home-assistant.io/docs/api/websocket

    @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@

    =head2 B<Notes:>

    This processing receives all events from HomeAssistant.  It is fairly efficient
    at weeding out the none relevant events.  I have not seen any network load caused
    by volume.  It is likely most efficient to have MH and HA running on the same machine.

    =head2 INHERITS

    B<NONE>

    =head2 METHODS

    =over

    =item B<UnDoc>

    =item B<ToDo>

    There are a number of things that need to be done.
    - the pattern needs to be made to be a regexp
    - may need a timeout if haven't received a pong in a certain time and force reconnect
    - support more HA entity domains


=cut

# ------------------------------------------------------------------------------
package HA_Server;

use warnings;
# use strict;

@HA_Server::ISA = ('Generic_Item');

use Protocol::WebSocket::Client;

use JSON qw( decode_json encode_json );   
use Encode qw(decode encode);

use Data::Dumper;

my %HA_Server_List;

sub break_long_str {
    my ($self, $str, $prefix, $maxlength) = @_;
    my $result;

    $result = '';
    $str = $str || '';
    while( length( $str ) > $maxlength ) {
        my $l = 0;
        my $i;
        for( $i=0; $i<length($str) && $l<$maxlength; ++$i,++$l ) {
            if( substr( $str, $i, 1 ) eq "\n" ) {
                $l = 0;
            }
        }
        $result .= $prefix;
        $result .= substr( $str, 0, $i );
        $str = substr( $str, $i );
        $prefix = '....  ';
    }
    if( $str ) {
        $result .= $prefix;
        $result .= $str;
    }
    return $result;
}

sub log {
    my ($self, $str, $prefix) = @_;

    if( !defined( $prefix ) ) {
        $prefix = '[HA_Server]: ';
    }
    $str = $self->break_long_str( $str, $prefix, 300 );

    print $str . "\n";
    &main::print_log( $str );
}

sub debug {
    my( $self, $level, $str ) = @_;
    if( $main::Debug{ha_server} >= $level ) {
        $level = 'D' if $level == 0;
        $self->log( $str, "[HA_Server D$level]: " );
    }
}

sub error {
    my ($self, $str, $level ) = @_;
    &HA_Server::log( $self, $str, "[HA_Server ERROR]: " );
}

sub dump {
    my( $self, $obj, $maxdepth ) = @_;
    $obj = $obj || $self;
    $maxdepth = $maxdepth || 2;
    my $dumper = Data::Dumper->new( [$obj] );
    $dumper->Maxdepth( $maxdepth );
    return $dumper->Dump();
}


# ------------------------------------------------------------------------------

=item C<new(ha_server, name, address, keep_alive_timer, api_key )>

    Creates a HA_Server object that captures the connection to a single HomeAssistant server.

    name:               object name of the ha_server
    address:            tcp/ip address and port of the HA server
    keep_alive_timer:   how long between ping requests to HA server (default 10s)
    api_key:            long lived token obtained from HA server 

=cut

sub new {
    my ( $class, $name, $address, $keep_alive_timer, $api_key ) = @_;
    my $self;

    print "creating HA Server $name on $address\n";

    if( !defined $main::Debug{ha_server} ) {
        $main::Debug{ha_server} = 0;
        # $main::Debug{ha_server} = 2;
    }

    $address            = $address  || $::config_parms{homeassistant_address}   || 'localhost:8123';
    $api_key            = $api_key  || $::config_parms{homeassistant_api_key};
    $keep_alive_timer   = $keep_alive_timer                                     || '10';
    $keep_alive_timer += 0;

    $self = {};

    bless $self, $class;

    $$self{state}               = 'off';
    $$self{said}                = '';
    $$self{state_now}           = 'off';

    $self->{ip_address}         = $address;
    $self->{keep_alive_timer}   = $keep_alive_timer;
    $self->{reconnect_timer}    = 10;
    $self->{next_id}            = 20;
    $self->{subscribe_id}       = 0;
    $self->{api_key}            = $api_key;
    $self->{max_payload_size}   = $::config_parms{homeassistant_max_payload_size} || 2000000; #2M default Payload size
    $self->{init_v_cmd}         = 0;

    $self->{next_ping}          = 0;
    $self->{got_ping_response}  = 1;
    $self->{ping_missed_count}  = 0;

    $self->{recon_timer}        = ::Timer::new();

    $self->{name} = $name;


    $self->log("Creating $name on $$self{ip_address}");


    $HA_Server_List{$self->{name}} = $self;

    &::MainLoop_pre_add_hook( \&HA_Server::check_for_data, 1, $self );
    &::Reload_post_add_hook( \&HA_Server::restore_entity_states, 1, $self );
    &::Reload_post_add_hook( \&HA_Server::generate_voice_commands, 1, $self );

    $self->connect();
    return $self;
}


sub connect {
    my ($self) = @_;

    $self->{socket_item} = new Socket_Item( undef, undef, $self->{ip_address}, $self->{name}, 'tcp', 'raw' );

    if( !$self->{socket_item}->start() ) {
        $self->log( "Unable to connect socket to $self->{ip_address} ... trying again in $self->{reconnect_timer}s" );
        if ($self->{recon_timer}->inactive) {
            $self->{recon_timer}->set($self->{reconnect_timer}, sub { &HA_Server::connect( $self ) });
        }
        return;
    } else {
        $self->log( "Connected to HomeAssistant server at $self->{ip_address}" );
    }

    my $ws_client = Protocol::WebSocket::Client->new(url => 'ws://' . $self->{ip_address} . '/api/websocket' );
    
    $ws_client->{ha_server} = $self;
    $self->{ws_client} = $ws_client;

    $ws_client->on(
        write => sub {
            my ($client,$buf) = @_;
            my $self = $client->{ha_server};
     
            if( $self->{socket_item} ) {
                $self->{socket_item}->set( $buf );
            }
        }
    );
    $ws_client->on(
        read => sub {
            my ($client,$buf) = @_;
            my $self = $client->{ha_server};
     
            $self->ha_process_read( $buf );
        }
    );
    $ws_client->on(
        error => sub {
            my ($client,$buf) = @_;
            my $self = $client->{ha_server};
     
            $self->error( "ha_server received error: $buf" );
        }
    );
    $ws_client->{frame_buffer}->{max_payload_size} = $self->{max_payload_size}; 

    $self->{ws_client}->connect();
}

sub check_for_data {
    my ($self) = @_;
    my $ha_data;

    if( $self->{socket_item} ) {
        if( $self->{socket_item}->active_now() ) {
            $self->debug( 1, "Homeassistant server started" );
        }
        if( $self->{socket_item}->inactive_now() ) {
            $self->debug( 1, "Homeassistant server close" );
            $self->disconnect();
            $self->connect();
            next;
        }
    }
    
    # Parses incoming data and on every frame calls on_read
    if( $self->{socket_item}  and  $ha_data = $self->{socket_item}->said() ) {
        # print "Received data from home assistant:\n     $ha_data\n";
        eval { $self->{ws_client}->read( $ha_data ); };

        if ($@) {
            print "[HA_Item] ERROR when reading WebSocket $@\n";
            return ('0');
        }
    }
     
    if( &::new_second($self->{keep_alive_time}) and  $self->{ws_client} ) {
        $self->{ws_client}->write( '{"id":' . ++$self->{next_id} . ', "type":"ping"}' );
    }
}

sub ha_process_write {
    my ($self, $data) = @_;

    if( ref $data ) {
        $data = encode_json( $data );
    }
    if( !$self->{socket_item}->active() ) {
        return;
    }
    $self->debug( 1, "sending data to ha: $data" );
    $self->{ws_client}->write( $data );
}

sub ha_process_read {
    my ($self, $data) = @_;
    my $data_obj;
    my $json_text;

    # print "ha_server received: \n    ";
    # print $data . "\n";

    $json_text = encode( "UTF-8", $data );
    eval {$data_obj = JSON->new->utf8->decode( $json_text )};
    if( $@ ) {
        $self->error( "parsing json from homeassistant: $@  [$json_text]" );
        print "Error parsing json from homeassistant: $@\n";
        print "   [$json_text]\n";
        return;
    }
    if( !$data_obj ) {
        $self->error( "Unable to decode json: $data" );
        return;
    }
    if( $data_obj->{type} eq 'pong' ) {
        $self->debug( 3, "Received pong from HA" );
        return;
    }
    if( $data_obj->{type} eq 'event'  &&  $data_obj->{id} == $self->{subscribe_id} ) {
        $self->parse_data_to_obj( $data_obj->{event}->{data}->{new_state}, "ha_server" );
        return;
    } elsif( $data_obj->{type} eq 'auth_required' ) {
        my $auth_message = "{ \"type\": \"auth\", \"access_token\": \"$$self{api_key}\" }";
        $self->ha_process_write( $auth_message );
        return;
    } elsif( $data_obj->{type} eq 'auth_ok' ) {
        my $subscribe;
        $self->log( "Authenticated to HomeAssistant server" );
        $self->{subscribe_id} = ++$self->{next_id};
        $subscribe->{id} = $self->{subscribe_id};
        $subscribe->{type} = 'subscribe_events';
        $subscribe->{event_type} = 'state_changed';
        $self->ha_process_write( $subscribe );
        my $getstates;
        $self->{getstates_id} = ++$self->{next_id};
        $getstates->{id} = $self->{getstates_id};
        $getstates->{type} = 'get_states';
        $self->ha_process_write( $getstates );
        return;
    } elsif( $data_obj->{type} eq 'auth_invalid' ) {
        $self->error( "Authentication invalid: " . $self->dump($data_obj) );
    } elsif( $data_obj->{type} eq 'result' ) {
        if( $data_obj->{success} ) {
            $self->debug( 1, "Received success on request $data_obj->{id}" );
            if( $data_obj->{id} == $self->{getstates_id} ) {
                $self->process_entity_states( $data_obj );
            }
            return;
        } else {
            $self->error( "Received FAILURE on request $data_obj->{id}: " . $self->dump( $data_obj ) );
        }
    }
}

sub parse_data_to_obj {
    my ( $self, $cmd, $p_setby ) = @_;
    my $handled = 0;

    $self->debug( 2, "Msg object: " . $self->dump( $cmd, 3 ) );

    my ($cmd_domain,$cmd_entity) = split( '\.', $cmd->{entity_id} );
    for my $obj ( @{ $self->{objects} } ) {
        if( $obj->{entity_prefixes} ) {
            for my $prefix (@{$obj->{entity_prefixes}}) {
                if( $prefix eq substr($cmd_entity,0,length($prefix)) ) {
                    my $attr_name = substr($cmd_entity,length($prefix));
                    $obj->{attr}->{$attr_name} = $cmd->{state};
                    $self->debug( 1, "handled event for $obj->{object_name} -- attr $attr_name set to $cmd->{state}" );
                    # $obj->set( 'toggle', undef );
                    if( $p_setby eq "ha_server_init" ) {
                        $obj->{ha_init} = 1;
                    }
                    $handled = 1;
                }
            }
        } elsif( $cmd->{entity_id} eq $obj->{entity_id} ) {
            $obj->set( $cmd, $p_setby );
            if( $p_setby eq "ha_server_init" ) {
                $obj->{ha_init} = 1;
            }
            $handled = 1;
        }
    }
    if( !$handled ) {
        $self->debug( 1, "unhandled event $cmd->{entity_id} ($cmd->{state})" );
    }
    return $handled;
}

sub process_entity_states {
    my ( $self, $cmd ) = @_;

    # print "Entity states response: \n" . $self->dump( $cmd );
    foreach my $state_obj (@{$cmd->{result}}) {
        if( !$self->parse_data_to_obj( $state_obj, "ha_server_init" ) ) {
            push @{ $$self{unhandled_entities} }, $state_obj->{entity_id};
        }
    }
    # check that all ha_item objects had an initial state
    for my $obj ( @{ $self->{objects} } ) {
        if( !$obj->{ha_init} ) {
            $self->log( "no HomeAssistant initial state for HA_Item object $obj->{object_name} entity_id:$obj->{entity_id}" );
        }
    }
}

sub restore_entity_states {
    my ($self) = @_;

    for my $obj ( @{ $self->{objects} } ) {
        if( $obj->{ha_states}  &&  substr($obj->{ha_states},0,1) eq "'" ) {
            $obj->debug( 1, "Restoring states on $obj->{object_name} to $obj->{ha_states}" );
            eval '$obj->set_states( ' . $obj->{ha_states} . ');';
        }
    }
}

sub generate_voice_commands {
    my ($self) = @_;

    if ($self->{init_v_cmd} == 0) {
        my $object_string;
        my $object_name = $self->get_object_name;
        $self->{init_v_cmd} = 1;
        &main::print_log("Generating Voice commands for HA Server $object_name");

        my $voice_cmds = $self->get_voice_cmds();
        my $i          = 1;
        foreach my $cmd ( keys %$voice_cmds ) {

            #get object name to use as part of variable in voice command
            my $object_name_v = $object_name . '_' . $i . '_v';
            $object_string .= "use vars '${object_name}_${i}_v';\n";

            #Initialize the voice command with all of the possible device commands
            $object_string .= $object_name . "_" . $i . "_v  = new Voice_Cmd '$cmd';\n";

            #Tie the proper routine to each voice command
            my $tie_event = $voice_cmds->{$cmd};
            $tie_event =~ s/\(SAID\)$/($object_name_v->said\(\)\)/ if ($tie_event =~ m/\(SAID\)$/);
            $object_string .= $object_name . "_" . $i . "_v -> tie_event('" . $tie_event . "');\n\n";    #, '$command $cmd');\n\n";

            #Add this object to the list of HA Server Voice Commands on the Web Interface
            $object_string .= ::store_object_data( $object_name_v, 'Voice_Cmd', 'HA_Server', 'Controller_commands' );
            $i++;
        }
        #Evaluate the resulting object generating string
        package main;
        eval $object_string;
        print "Error in generating Voice Commands for HA Server: $@\n" if $@;

        package HA_Server;
    }
}

sub get_voice_cmds {
    my ($self) = @_;
    my $command = $self->get_object_name;
    $command =~ s/^\$//;
    $command =~ tr/_/ /; ## underscores in Voice_cmds cause them not to work.

    my $objects = "[";    
    my %seen;
    for my $obj ( @{ $ha_server->{objects} } ) {
	next if $seen{$obj->{object_name}}++; #remove duplicate entity names
	$objects .= $obj->{object_name} . ",";
    }
    chop $objects if (length($objects) > 1);
    $objects .= "]";
    $objects =~ s/\$//g;
    $objects =~ tr/_/ /; ## underscores in Voice_cmds cause them not to work.
    
    #a bit of a kludge to pass along the voice command option, get the said value from the voice command.
    my %voice_cmds = (
        'List [all,active,inactive] ' . $command . ' objects to the print log'   => $self->get_object_name . '->print_object_list(SAID)',
        'Print ' . $objects. ' ' . $command . ' attributes to the print log'             => $self->get_object_name . '->print_object_attrs(SAID)',
    );

    return \%voice_cmds;
}


sub print_object_list {
    my ($self,$cmd) = @_; 
    main::print_log("[HA_Server]: Showing $cmd entities known by $self->{name}");
 
    my @active_entities = ();
    my @inactive_entities = ();
    
    #should be replaced with just this instance.
    foreach my $ha_server ( values %HA_Server_List ) {
        my %seen;
        for my $obj ( @{ $ha_server->{objects} } ) {
            next if $seen{$obj->{entity_id}}++; #remove duplicate entity names
            push (@active_entities, $obj->{entity_id});
        }
    }
        
    @inactive_entities = @{$self->{unhandled_entities}};
    
    if ($cmd eq 'active' or $cmd eq 'all') {
        for my $i (@active_entities) {
            main::print_log("[HA_Server]: Active: $i");
        }
    }
    if ($cmd eq 'inactive' or $cmd eq 'all') {
        for my $i (@inactive_entities) {
            main::print_log("[HA_Server]: Inactive: $i");
        }
    }
}

sub print_object_attrs {
    my ($self,$obj) = @_;
    $obj =~ tr/ /_/;
    main::print_log("[HA_Server]: Showing details for object $obj");
    main::print_log("[HA_Server]: -----------------------------");
    my $object = main::get_object_by_name($obj);
    main::print_log("[HA_Server]: Entity = " . $object->{ha_state}->{entity_id}) if ( $object->{ha_state}->{entity_id});
    main::print_log("[HA_Server]: Subtype = " . $object->{subtype}) if ( $object->{subtype});

    main::print_log("[HA_Server]: Showing attribute raw data:");
    print Dumper $object->{ha_state}->{attributes};
}  


=item C<disconnect()>

    Disconnect the websocket connection from an HA_Server object to the Home Assistant server.

=cut

sub disconnect {
    my ($self) = @_;

    if( $self->{ws_client} ) {
        $self->{ws_client}->disconnect();
        delete $self->{ws_client};
    }
    if( $self->{socket_item}  &&  $self->{socket_item}->active() ) {
        $self->{socket_item}->stop();
    }
}
 

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


sub add_item {
    my ( $self, $p_object ) = @_;

    push @{ $$self{objects} }, $p_object;

    return $p_object;
}

sub remove_all_items {
    my ($self) = @_;

    $self->log("remove_all_items()");
    delete $self->{objects};
}

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

sub remove_item {
    my ( $self, $p_object ) = @_;

    if ( ref $$self{objects} ) {
        for ( my $i = 0; $i < scalar( @{ $$self{objects} } ); $i++ ) {
            if ( $$self{objects}->[$i] eq $p_object ) {
                splice @{ $$self{objects} }, $i, 1;
                return 1;
            }
        }
    }
    return 0;
}
# -------------End of HA_Server-------------------------------------------------


package HA_Item;

use warnings;

@HA_Item::ISA = ('Generic_Item');

use JSON qw( decode_json encode_json );   

use Data::Dumper;

=item C<new(HA_Item, domain, entity, ha_server )>

    Creates a HA_Item object that mirrors domain.entity in the HomeAssistant server ha_server.

    domain:     the HA domain of the entity
    entity:     the HA entity name
    ha_server:  the HA_Server object connected to the Home Assistant server

=cut

sub new {
    my ($class, $fulldomain, $entity, $ha_server ) = @_;
    my $self = new Generic_Item();
    bless $self, $class;

    if( !$ha_server ) {
        $self->error( "No homeassistant server set" );
        return;
    }
    $self->{ha_server} = $ha_server;
    my ($domain,$subtype) = split /:/, $fulldomain;
    $subtype = "" unless $subtype;
    $self->{domain} = $domain;
    $self->{subtype} = $subtype;    
    $self->debug( 1, "New HA_Item ( $class, $domain, $entity, $subtype )" );

    if( $domain eq 'switch' ) {
        $self->set_states( "off", "on" );
    } elsif( $domain eq 'light' ) {
        $self->set_states( "off", "20%", "40%", "50%", "60%", "80%", "on" ) unless (lc $self->{subtype} eq "rgb_color");
        if ($self->{subtype} eq "rgb_color") {
            $self->set_states("rgb");
        } else {
            $self->set_states( "off", "20%", "40%", "50%", "60%", "80%", "on" );
        }
    } elsif( $domain eq 'cover' ) {
        $self->set_states( "open", "closed" );
    } elsif( $domain eq 'lock' ) {
        $self->set_states( "unlocked", "locked" );      
    } elsif( $domain eq 'climate' ) {
    } elsif( $domain eq 'sensor'  ||  $domain eq 'binary_sensor' ) {
        $self->{attr} = {};
    } elsif( $domain eq 'select' ) {
    } else {
        $self->error( "Invalid type for HA_Item -- '$domain'" );
        return;
    }

    my @prefixes = split( '\|', $entity );
    if( $#prefixes  ||  substr( $entity, length($entity)-1, 1 ) eq '*' ) {
        if( $#prefixes == 0 ) {
            @prefixes = ($entity);
        }
        for my $prefix (@prefixes) {
            if( substr( $prefix, length($prefix)-1, 1 ) eq '*' ) {
                $prefix = substr( $prefix, 0, length($prefix)-1 );
            }
            push @{$self->{entity_prefixes}}, $prefix;
        }
        $self->debug( 1, "${domain}.${entity} prefixes: " . join( '|', @{$self->{entity_prefixes}}) );
    }

    $self->{entity} = $entity;
    $self->{entity_id} = "${domain}.${entity}";

    $self->{ha_server}->add( $self );

    $self->restore_data( 'ha_states' );

    return $self;
}

sub log {
    my( $self, $str ) = @_;
    $self->{ha_server}->log( $str, "[HA_Item]:" );
}

sub error {
    my( $self, $str ) = @_;
    $self->{ha_server}->error( $str );
}

sub debug {
    my( $self, $level, $str ) = @_;
    if( $self->debuglevel( $level, 'ha_server' ) ) {
        $self->{ha_server}->log( $str, "[HA_Item D$level]: " );
    }
}

sub dump {
    my( $self, $obj, $maxdepth ) = @_;
    $obj = $obj || $self;
    $maxdepth = $maxdepth || 2;
    my $dumper = Data::Dumper->new( [$obj] );
    $dumper->Maxdepth( $maxdepth );
    return $dumper->Dump();
}


=item C<set_object_debug( level )>

Turns on debugging for the object, sets debug level.

=cut

sub set_object_debug {
    my( $self, $level ) = @_;
    my $objname = lc $self->get_object_name();
    $level = 1 if !defined $level;
    $main::Debug{$objname} = $level;
}

=item C<set(setval, p_setby, p_response )>

    Sets the value of the HA_Item to setval -- p_setby and p_response standard MH parms.
    This will cause a state change to be sent to the HA entity mirrored by the item.
    Local state will not be changed until the state_change event is received back from the HA server.

=cut
sub set {
    my ( $self, $setval, $p_setby, $p_response ) = @_;

    if( $p_setby =~ /ha_server*/ ) {
        # This is home assistant sending a state change via websocket
        # This state change may or may not have been initiated by us
        # This is sent as an object representing the json new_state
        $self->debug( 2, "$self->{object_name} set by $p_setby to: ". $self->dump($setval, 3) );

        my $new_state = $setval;
        $self->{ha_state} = $setval;
        if( $self->{domain} eq 'switch'
        ||  $self->{domain} eq 'cover'
        ||  $self->{domain} eq 'lock'
        ||  $self->{domain} eq 'sensor'
        ||  $self->{domain} eq 'binary_sensor'
        ) {
            $self->debug( 1, "$self->{domain} event for $self->{object_name} set to $new_state->{state}" );
            $self->SUPER::set( $new_state->{state}, $p_setby, $p_response );
        } elsif( $self->{domain} eq 'select' ) {
            $self->debug( 1, "$self->{domain} event for $self->{object_name} set to $new_state->{state}" );
            $self->SUPER::set( $new_state->{state}, $p_setby, $p_response );
            if( $p_setby eq 'ha_server_init' ) {
                $self->{ha_states} = $self->restore_states_string( $new_state->{attributes}->{options} );
            }
        } elsif( $self->{domain} eq 'light' ) {
            if (lc $self->{subtype} eq "rgb_color") {
                if( $new_state->{attributes}  &&  ref $new_state->{attributes}->{$self->{subtype}} ) {
                    #shouldn't join, but rgb is an array so for now create a string
                    my $string = join ',', @{$new_state->{attributes}->{ $self->{subtype} }}; 
                    $self->debug( 1, "handled subtype $self->{subtype} event for $self->{object_name} set to $string" );
                    $self->SUPER::set( $string, $p_setby, $p_response );
                } else {
                    $self->debug( 1, "got light state for $self->{object_name} but no rgb_color attribute" );
                }
            } else {    
                my $level = $new_state->{state};
                if( $new_state->{state} eq 'on' ){
                    if( $new_state->{attributes}->{brightness} ) {
                        $level = $new_state->{attributes}->{brightness} * 100 / 255;
                    }
                }    
                $self->debug( 1, "light event for $self->{object_name} set to $level" );
                $self->SUPER::set( $level, $p_setby, $p_response );
            }
        } elsif( $self->{domain} eq 'climate' ) {
            my $state;
            foreach my $attrname (keys %{$new_state->{attributes}} ) {
                # $self->{attr}->{$attrname} = $new_state->{attributes}->{$attrname};
                if( $self->{subtype} eq $attrname ) {
                    $state = $new_state->{attributes}->{$attrname};
                }
            }
            if( !$state  &&  (!$self->{subtype}  ||  $self->{subtype} eq 'hvac_mode' ) ) {
                $state = $new_state->{state};
            }
            if( !$state  &&  $self->{subtype} ) {
                $self->error( "climate state message did not contain state for $self->{object_name}" );
                return;
            }
            # $self->debug( 1, "climate attributes set: " . $self->dump($self->{attr}) );
            if( $self->{subtype} ) {
                $self->debug( 1, "climate $self->{object_name} set: $state" );
            } else {
                $self->debug( 1, "climate $self->{object_name} default object set: $state" );
            }
            if( $p_setby eq 'ha_server_init' ) {
                if( $self->{subtype} eq 'hvac_mode' ) {
                    $self->{ha_states} = $self->restore_states_string( $new_state->{attributes}->{hvac_modes} );
                } elsif( $self->{subtype} eq 'fan_mode' ) {
                    $self->{ha_states} = $self->restore_states_string( $new_state->{attributes}->{fan_modes} );
                } elsif( $self->{subtype} eq 'preset_mode' ) {
                    $self->{ha_states} = $self->restore_states_string( $new_state->{attributes}->{preset_modes} );
                }
            }
            $self->SUPER::set( $state, $p_setby, $p_response );
        }
    } else {
        # Item has been set locally -- use HA WebSocket to change state
        $self->debug( 2, "$self->{object_name} set by $p_setby to: $setval" );

        if( $self->{domain} eq 'select' ) {
            $self->ha_set_select( $setval );
        } elsif( $self->{domain} eq 'climate' ) {
            $self->ha_set_climate( $setval );
        } else {
            $self->ha_set_state( $setval );
        }
    }
}

sub restore_states_string {
    my ($self, $state_list) = @_;
    if( !$state_list  ||  $#{@$state_list} == 0 ) {
        return;
    }
    my $state_list_str = "'" . join("','", @{$state_list}) . "'";
    return $state_list_str;
}

=item C<ha_call_service(service_name, service_data_hash )>

    Will send a message to HA to run the service 'service_name' passing in the
    kwargs parameters specified in service_data_hash.
    This will cause a state change to be sent to the HA entity mirrored by the item.
    Local state will not be changed until the state_change event is received back from the HA server.

=cut
sub ha_call_service {
    my ($self, $service, $service_data) = @_;
    my $ha_msg = {};

    $ha_msg->{id} = ++$self->{ha_server}->{next_id};
    $ha_msg->{type} = 'call_service';
    $ha_msg->{domain} = $self->{domain};
    $ha_msg->{target} = {};
    $ha_msg->{target}->{entity_id} = $self->{entity_id};
    $ha_msg->{service} = $service;
    if( defined( $service_data )  &&  keys %$service_data) {
        $ha_msg->{service_data} = $service_data;
    }

    $self->debug( 2, "sending command to HA: " . $self->dump( $ha_msg ) );
    $self->{ha_server}->ha_process_write( $ha_msg );
}

sub ha_set_select {
    my ($self, $mode) = @_;
    my $cmd;
    my $service;
    my $service_data = {};

    $service = 'select_option';
    $service_data->{option} = $mode;
    $self->ha_call_service( $service, $service_data );
}

sub ha_set_climate {
    my ($self, $setval) = @_;
    my $service_data = {};
    my $service;

    if( $self->{subtype} eq 'onoff' ) {
        if( lc $setval eq 'turn_on' || lc $setval eq 'on' ) {
            $service = 'turn_on';
        } elsif( lc $setval eq 'turn_off' ||  lc $setval eq 'off' ) {
            $service = 'turn_off';
        } elsif( lc $setval eq 'toggle' ) {
            $service = 'toggle';
        }
    } elsif( $self->{subtype} eq 'target_temp_low' ) {
        $service_data->{target_temp_low} = $setval;
        $service_data->{target_temp_high} = $self->{ha_state}->{attributes}->{target_temp_high};
    } elsif( $self->{subtype} eq 'target_temp_high' ) {
        $service_data->{target_temp_high} = $setval;
        $service_data->{target_temp_low} = $self->{ha_state}->{attributes}->{target_temp_low};
    } else {
        my $service_name = $self->{subtype};
        if( !service_name ) {
            $service_name = 'hvac_mode';
        }
        $service = "set_${service_name}";
        $service_data->{$service_name} = $setval;
    }
    $self->ha_call_service( $service, $service_data );
}

sub ha_set_state {
    my ($self, $mode) = @_;
    my $cmd;
    my $service;
    my $service_data = {};

    $service = $mode;
    my ($numval) = $mode =~ /^([1-9]?[0-9]?[0-9])%?$/;
    if( $numval ) {
        $service = 'turn_on';
        $service_data->{brightness_pct} = $numval;
    } elsif( lc $mode eq 'on' ) {
        $service = 'turn_on';
    } elsif( lc $mode eq 'toggle' ) {
        $service = 'toggle';
    } elsif( lc $mode eq 'off' ) {
        $service = 'turn_off';
    } elsif( lc $mode eq 'open' ) {
        if (lc $self->{domain} eq 'lock') {
            $service = 'open';
        } else {
            $service = 'open_cover';
        }
    } elsif( lc $mode eq 'close' ) {
        $service = 'close_cover';
    } elsif( lc $mode eq 'locked' ) {
        $service = 'lock';
    } elsif( lc $mode eq 'unlocked' ) {
        $service = 'unlock';
    } elsif( lc $mode =~ /\d+,\d+,\d+/ && $self->{subtype} eq 'rgb_color') {
        $service = 'turn_on';
        @{$service_data->{rgb_color}} = split /,/, $mode;
    }          
    $self->ha_call_service( $service, $service_data );
}


=item C<is_dimmable()>

Returns whether object is dimmable.

=cut

sub is_dimmable {
    my ( $self ) = @_;
    if( $self->{mqtt_type} eq 'light' ) {
        return 1;
    }
    return 0;
}

=item C<get_rgb()>

Returns a list of rgb attributes.
Needed for the IA7 UI Sliders to show up.

=cut

sub get_rgb {
    my ($self) = @_;
    if (lc $self->{subtype} eq "rgb_color") {
        return split /,/, $self->state();
    } else {
        return (undef, undef, undef);
    }
}


# -[ Fini - HA_Item ]---------------------------------------------------------

1;
