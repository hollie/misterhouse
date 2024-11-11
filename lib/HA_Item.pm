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
        *** IMPORTANT *** :         OR
	*** IMPORTANT *** : You can collect multiple entities into a single MH object
	*** IMPORTANT *** :    - use one or more patterns to match HA entity names, separated by |
	*** IMPORTANT *** :    - simple patterns can include a '*' at the end -- will match a prefix. attr name
	*** IMPORTANT *** :      will be the suffix
	*** IMPORTANT *** :      or 
	*** IMPORTANT *** :    - use a full regex -- if you bracket a portion, it will be the attr name
	*** IMPORTANT *** :    - eg. ecowitt_weather_(.*) will match ecowitt_weather_current_temperature and the
	*** IMPORTANT *** :      the attribute name will be current_temperature
            - light:  on, off and brightness
                    :rgb_color : for setting an RGB value
                    :hs_color  : for setting hue and saturation
                    :effect    : for setting a lighting effect
            - fan: on, off and speed (%)
            - cover: open,stop,close
                    :digital : for allowing granular setpoints
            - lock: lock, unlock
            - switch: on,off
            - number: well, a number. Since MH doesn't allow text entry through the web interface, you should set_states(x,y,z) in usercode if the webUI is used for control
            - sensor: usually a number value, not settable
            - binary_sensor: an on/off value, the type of sensor should be detected, but can be overriden if needed by declaring a subytpe. Supported device classes:
                    : battery,battery_charging,co,cold,connectivity,door,garage_door,gas,heat,light,lock,moisture,motion,moving,occupancy
                    : opening,plug,power,presence,problem,running,safety,smoke,sound,tamper,update,vibration,window
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
	- options
	    - delay_between_messages=n
		- system will wait n seconds after the response from one message before the
		  next message is sent
		- OpenSprinkler is the only device we have seen to date that needs this
        - ha_perform_action can be used to generically perform an action on an entity
            - this can be used for 2 different things:
                1. you can treat complex HA entities as a single MH item, and use
                   this function to perform the various actions on the HA entity
                2. if the MH code doesn't implement all of the HA entity actions, or there
                   are custom actions on the entity, then you can call them with this function
            eg. $thermostat->ha_perform_action( 'set_preset_mode', {preset_mode=>'away'} );
	- ha_perform_action also exists on the HA_Server class
	    - this can be used to perform actions that are not entity actions
	    eg. $hasrv->ha_perform_action( 'notify.mobile_app_my_phone', {title=>'HA notification', message=>'test message'} );
	    - or add this to items.mht for controlling HA actions, like an RF fan controlled by a broadlink item:
	    GENERIC,   fan_light,
	    CODE, $fan_light -> tie_event('$hasrv->ha_perform_action( "remote.rm4pro.send_command", {device => "Fan", command=> "Light"})');
	    CODE, $fan_light -> set_states ("on","off");
    

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
        homeassistant_no_labels = 1 # disable using Friendly_Name to create web object labels


    .mht file:

        # HA_SERVER,    obj name,       address,        keepalive,      api_key   
        HA_SERVER,      ha_house,       10.3.1.20:8123, 10,             XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX

        #HA_ITEM,       object_name,            domain[:subtype],   ha_entity,                  ha_server,  groups, options
        HA_ITEM,        shed_counter_pots,      light,              shed_counter_pots,          ha_house
        HA_ITEM,        water,                  switch,             house_water_socket,         ha_house
        HA_ITEM,        thermostat,             climate,            family_room_thermostat,     ha_house
        HA_ITEM,        ecowitt_weather,        sensor,             hp2551bu_pro_v1_7_6_*|ecowitt_cottage_weather_*, ha_house
        HA_ITEM,        led_strip,              light:rgb,          yeelight_012342,    ha_house, , no_duplicate_states

    currently the only option is no_duplicate_states to prevent polled devices (like iot class) to update itself constantly with the current state

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

    &main::print_log( $str );
    return $str;
}

sub debug {
    my( $self, $level, $str ) = @_;
    if( $self->debuglevel( $level, 'ha_server' ) ) {
        $self->log( $str, "[HA_Server D$level]: " );
    }
}

sub error {
    my ($self, $str, $level ) = @_;
    $str = &HA_Server::log( $self, $str, "[HA_Server ERROR]: " );
}

sub dump {
    my( $self, $obj, $maxdepth ) = @_;
    $obj = $obj || "undef";
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

    if( !defined $main::Debug{ha_server} ) {
        $main::Debug{ha_server} = 0;
    }

    $address            = $address  || $::config_parms{homeassistant_address}   || 'localhost:8123';
    $api_key            = $api_key  || $::config_parms{homeassistant_api_key};
    $keep_alive_timer   = $keep_alive_timer                                     || '10';
    $keep_alive_timer += 0;

    foreach my $ha_server (values %HA_Server_List) {
	if( $ha_server->{ip_address} eq $address ) {
	    $self = $ha_server;
	}
    }

    if( $self ) {
	$self->log( "Existing HA Server $self->{name} found for $address -- reusing" );
	$self->remove_all_items();
	@{ $self->{unhandled_entities} } = ();
	if( !$self->{authenticated} ) {
	    $self->disconnect();
	} else {
	    $self->request_entity_states();
	}
    } else {
	$self = {};
	bless $self, $class;
	$self->log( "creating HA Server $name on $address" );

	&::MainLoop_pre_add_hook( \&HA_Server::check_for_data, 1, $self );
	&::Reload_post_add_hook( \&HA_Server::generate_voice_commands, 1, $self );

	$HA_Server_List{$name}	    = $self;
	$self->{connected}	    = 0;
	$self->{authenticated}	    = 0;
	$self->{state}              = 'off';
	$self->{said}               = '';
	$self->{state_now}          = 'off';
    
	$self->{ip_address}         = $address;
	$self->{keep_alive_timer}   = $keep_alive_timer;
	$self->{reconnect_timer}    = 10;
	$self->{next_id}            = 20;
	$self->{subscribe_id}       = 0;
	$self->{api_key}            = $api_key;
	$self->{max_payload_size}   = $::config_parms{homeassistant_max_payload_size} || 2000000; #2M default Payload size
	$self->{init_v_cmd}         = 0;
	$self->{recon_timer}        = ::Timer::new();
    
	$self->{next_ping}          = 0;
	$self->{got_ping_response}  = 1;
	$self->{ping_missed_count}  = 0;

	@{ $self->{unhandled_entities} } = ();
	@{ $self->{objects} }	    = ();
    }

    $self->{name}		= $name;

    $self->connect();

    return $self;
}


sub connect {
    my ($self) = @_;

    if( $self->{connected} ) {
	return;
    }

    if( !$self->{socket_item} ) {
	$self->{socket_item} = new Socket_Item( undef, undef, $self->{ip_address}, $self->{name}, 'tcp', 'raw' );
    }

    if( $self->{socket_item}->connected() ) {
	$self->error( "connect called on $self->{name} when socket already connected" );
	return;
    }

    if( !$self->{socket_item}->start() ) {
        $self->log( "Unable to connect socket to $self->{ip_address} ... trying again in $self->{reconnect_timer}s" );
        if ($self->{recon_timer}->inactive) {
            $self->{recon_timer}->set($self->{reconnect_timer}, sub { &HA_Server::connect( $self ) });
        }
        return;
    } else {
        $self->log( "$self->{name} connected to HomeAssistant server at $self->{ip_address}" );
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
    $self->{connected} = 1;
}

=item C<disconnect()>

    Disconnect the websocket connection from an HA_Server object to the Home Assistant server.

=cut

sub disconnect {
    my ($self) = @_;

    if( !$self->{socket_item}  ||  !$self->{socket_item}->active() ) {
	$self->log( "$self->{name} has disconnected -- cleaning up" );
    } else {
	$self->log( "$self->{name} disconnecting and cleaning up" );
	if( $self->{ws_client} ) {
	    $self->{ws_client}->disconnect();
	}
	$self->{socket_item}->stop();
    }
    delete $self->{ws_client};
    $self->{ws_client} = undef;
    $self->{connected} = 0;
    $self->{authenticated} = 0;
}
 

sub check_for_data {
    my ($self) = @_;
    my $ha_data;

    if( $self->{socket_item} ) {
        if( $self->{socket_item}->active_now()  &&  $self->{socket_item}->inactive_now() ) {
	    $self->log( "server '$self->{name}' bounced -- probably a reload -- ignoring" );
	} elsif( $self->{socket_item}->active_now() ) {
            $self->log( "server '$self->{name}' started" );
        } elsif( $self->{socket_item}->inactive_now() ) {
	    # On reload, this state comes after the fact
            $self->log( "'$self->{name}' socket closed -- reconnecting in 5 seconds" );
	    $self->disconnect();
	    if ($self->{recon_timer}->inactive) {
		$self->{recon_timer}->set($self->{reconnect_timer}, sub { &HA_Server::connect( $self ) });
	    }
            return;
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
     
    if( &::new_second($self->{keep_alive_timer})
    and $self->{authenticated}
    and $self->{socket_item} and $self->{socket_item}->active()
    and $self->{ws_client}
    ) {
        $self->{ws_client}->write( '{"id":' . ++$self->{next_id} . ', "type":"ping"}' );
        $self->debug(3, "Sent ping to HA" );
    }
}


sub ha_process_write {
    my ($self, $data) = @_;
    my $msgid;

    if( $data->{type} ne 'auth' ) {
	$data->{id} = $msgid = ++$self->{next_id};
    }
    $data = encode_json( $data );
    if( !$self->{socket_item}->active() ) {
	$self->error( "$self->{name} doing write, but socket is disconnected" );
        return;
    }
    $self->debug( 1, "sending data to ha: $data" );
    $self->{ws_client}->write( $data );
    return $msgid;
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
        $self->error( "parsing json from homeassistant: $@  \n    JSON text: [$json_text]" );
        return;
    }
    if( !$data_obj ) {
        $self->error( "Unable to decode json: $data" );
        return;
    }
    if( $data_obj->{type} eq 'pong' ) {
        $self->debug( 3, "Received pong from HA" );
        return;
    } elsif( $data_obj->{type} eq 'event'  &&  $data_obj->{id} == $self->{subscribe_id} ) {
        $self->parse_data_to_obj( $data_obj->{event}->{data}->{new_state}, "ha_server" );
        return;
    } elsif( $data_obj->{type} eq 'auth_required' ) {
        my $ha_msg = {};
	$ha_msg->{type} = "auth";
	$ha_msg->{access_token} = $self->{api_key};
        $self->ha_process_write( $ha_msg );
        return;
    } elsif( $data_obj->{type} eq 'auth_ok' ) {
        my $ha_msg = {};
	$self->{authenticated} = 1;
        $self->log( "$self->{name} authenticated to HomeAssistant server" );
        $ha_msg->{type} = 'subscribe_events';
        $ha_msg->{event_type} = 'state_changed';
        $self->{subscribe_id} = $self->ha_process_write( $ha_msg );
	$self->request_entity_states();
        return;
    } elsif( $data_obj->{type} eq 'auth_invalid' ) {
	$self->{authenticated} = 0;
        $self->error( "Authentication invalid: " . $self->dump($data_obj) );
	$self->disconnect();
	return;
    } elsif( $data_obj->{type} eq 'result'  &&  $data_obj->{id} == $self->{getstates_id} ) {
        if( $data_obj->{success} ) {
            $self->debug( 1, "Received success on getstates request $data_obj->{id}" );
	    $self->process_entity_states( $data_obj );
        } else {
            $self->error( "Received FAILURE on getstates request $data_obj->{id}: " . $self->dump( $data_obj ) );
        }
	return;
    } elsif( $data_obj->{type} eq 'result' ) {
        $self->process_result( $data_obj );
	return;
    }
}

=item C<ha_perform_action(action_name, action_data_hash )>

    Will send a message to HA to perform an action 'domain.action_name' passing in the
    kwargs parameters specified in action_data_hash.

=cut
sub ha_perform_action {
    my ($self, $action, $action_data) = @_;
    my $ha_msg = {};
    my $entity_id;
    my $action_name;
    my $domain;

    $ha_msg->{type} = 'call_service';
    ($domain, $entity_id, $action_name) = $action =~ /^([^\.]+)\.([^\.]+)\.([^\.]+)$/;
    if( $entity_id ) {
	$entity_id = "$domain.$entity_id";
    } else {
	($domain, $action_name) = $action =~ /^([^\.]+)\.([^\.]+)$/;
	if( $domain ) {
	    $entity_id = undef;
	} else {
	    $self->error( "Invalid action specified: $action" );
	    return;
	}
    }
    $ha_msg->{domain} = $domain;
    if( $entity_id ) {
	$ha_msg->{target} = {};
	$ha_msg->{target}->{entity_id} = $entity_id;
    }
    $ha_msg->{service} = $action_name;
    if( defined( $action_data )  &&  keys %$action_data) {
        $ha_msg->{service_data} = $action_data;
    }

    $self->ha_process_write( $ha_msg );
}

# This function is provided for backwards compatibility
sub ha_call_service {
    my ($self, $action, $action_data) = @_;
    return $self->ha_perform_action( $action, $action_data );
}

sub set_object_state {
    my ( $self, $obj, $cmd, $p_setby ) = @_;

    if( $obj->debuglevel( 3, 'ha_server' ) ) {
	$obj->debug( 3, "handled event for $obj->{object_name} set by $p_setby to: ". $obj->dump($cmd, 3) );
    }
    $obj->process_ha_message( $cmd, $p_setby );
    if( $p_setby eq "ha_server_init" ) {
	$obj->{ha_init} = 1;
	my $no_label = 0;
	if (defined $::config_parms{homeassistant_no_labels}) {
	    $no_label = $::config_parms{homeassistant_no_labels};
	}
	if (defined ( $obj->{ha_state}->{attributes}->{friendly_name}) and ($no_label == 0)) { 
	    my $subtype = $obj->{subtype};
	    $subtype =~ tr/_/ /;
	    $subtype = "" if (lc $subtype eq "digital");
	    my $label = $obj->{ha_state}->{attributes}->{friendly_name};
	    $label .= " " . $subtype if ($subtype);
	    $obj->set_label($label,1);
	}
	
    }
}

sub parse_data_to_obj {
    my ( $self, $cmd, $p_setby ) = @_;
    my $handled = 0;

    if( $self->debuglevel( 3, 'ha_server' ) ) {
	$self->debug( 3, "Msg object: " . $self->dump( $cmd, 3 ) );
    } else {
	$self->debug( 2, "Msg object: entity_id: $cmd->{entity_id}   state: $cmd->{state}" );
    }

    my ($cmd_domain,$cmd_entity) = split( '\.', $cmd->{entity_id} );
    for my $obj ( @{ $self->{objects} } ) {
	if( $cmd->{entity_id} eq $obj->{entity_id} ) {
	    $self->set_object_state( $obj, $cmd, $p_setby );
	    $handled = 1;
	} else {
	    for my $pattern (@{$obj->{entity_patterns}}) {
		my ($attr_name) = $cmd_entity =~ m/^$pattern$/;
		$attr_name = 0 unless (defined $attr_name);
		if( $attr_name eq 1 ) {
		    $attr_name = $cmd_entity;
		}
		if( $attr_name ) {
                    # $obj->{attr}->{$attr_name} = $cmd->{state};
                    # $self->debug( 1, "handled event for $obj->{object_name} -- attr $attr_name set to $cmd->{state}" );
                    if( $p_setby eq "ha_server_init" ) {
                        $obj->{ha_init} = 1;
                    }
		    if( !$obj->{subitems}->{$attr_name} ) {
			$obj->debug( 1, "creating subitem '${cmd_domain}.${cmd_entity}'" );
			my $subitem = new HA_Item( $cmd_domain, $cmd_entity, $obj->{ha_server}, '' );
			&main::register_object_by_name('$' . $attr_name,$subitem);
			$subitem->{category} = "Dynamic";
			$subitem->{filename} = "HA_Item";
			$subitem->{object_name} = '$' . $attr_name;
			$subitem->set_parent( $obj );
			$obj->{subitems}->{$attr_name} = $subitem;
			$self->set_object_state( $obj->{subitems}->{$attr_name}, $cmd, $p_setby );
			$handled = 1;
		    }
                }
            }
        }
    }
    if( !$handled ) {
        $self->debug( 2, "unhandled event $cmd->{entity_id} ($cmd->{state})" );
    }
    return $handled;
}

sub process_result {
    my ( $self, $result ) = @_;
    my $handled = 0;

    $self->debug( 3, "Processing result on HA request: " . $self->dump( $result, 3 ) );
    if( $result->{success} ) {
	$self->debug( 1, "Received success on request $result->{id}" );
    } else {
	$self->error( "Received FAILURE on request $result->{id}: " . $self->dump( $result ) );
    }

    for my $obj ( @{ $self->{objects} } ) {
	if( $obj->{msg_trk}->{pending_msgid} eq $result->{id} ) {
	    if( $obj->{msg_trk}->{delay_between_messages} ) {
		$obj->debug( 2, "Setting delay send timer on $obj->{object_name} to $obj->{msg_trk}->{delay_between_messages}s" );
		$obj->{msg_trk}->{msg_delay_timer}->stop();
		$obj->{msg_trk}->{msg_delay_timer}->set($obj->{msg_trk}->{delay_between_messages}, sub { $obj->ha_send_message() });
		last;
	    } else {
		$obj->ha_send_message();
	    }
	}
    }
}

sub request_entity_states {
    my ( $self ) = @_;
    my $ha_msg = {};

    $ha_msg->{type} = 'get_states';
    $self->{getstates_id} = $self->ha_process_write( $ha_msg );
}

sub process_entity_states {
    my ( $self, $cmd ) = @_;

    $self->debug( 1, "Processing response for get entity states" );
    $self->debug( 3, "Entity states response: \n" . $self->dump( $cmd ) );
    foreach my $state_obj (@{$cmd->{result}}) {
        if( !$self->parse_data_to_obj( $state_obj, "ha_server_init" ) ) {
            push @{ $self->{unhandled_entities} }, $state_obj->{entity_id};
        }
    }
    # check that all ha_item objects had an initial state
    for my $obj ( @{ $self->{objects} } ) {
        if( !$obj->{ha_init} ) {
            $self->log( "no HomeAssistant initial state for HA_Item object $obj->{object_name} entity_id:$obj->{entity_id}" );
        }
    }
}

sub generate_voice_commands {
    my ($self) = @_;

    if ($self->{init_v_cmd} == 0) {
        my $object_string;
        my $object_name = $self->get_object_name;
        $self->{init_v_cmd} = 1;
        $self->log( "Generating Voice commands for HA Server $object_name" );

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
    $command =~ tr/_/-/; ## underscores in Voice_cmds cause them not to work.

    my $objects = "[";    
    my %seen;
    for my $obj ( @{ $self->{objects} } ) {
	next if $seen{$obj->{object_name}}++; #remove duplicate entity names
	$objects .= $obj->{object_name} . ",";
    }
    chop $objects if (length($objects) > 1);
    $objects .= "]";
    $objects =~ s/\$//g;
    $objects =~ tr/_/-/; ## underscores in Voice_cmds cause them not to work.
    
    #a bit of a kludge to pass along the voice command option, get the said value from the voice command.
    my %voice_cmds = (
        'List [all,active,inactive] ' . $command . ' objects to the print log'   => $self->get_object_name . '->print_object_list(SAID)',
        'Print ' . $objects. ' on ' . $command . ' attributes to the print log'             => $self->get_object_name . '->print_object_attrs(SAID)',
    );

    return \%voice_cmds;
}


sub print_object_list {
    my ($self,$cmd) = @_; 

    $self->log( "Showing $cmd entities known by $self->{name}" );
 
    my @active_entities = ();
    my @inactive_entities = ();
    
    my %seen;
    for my $obj ( @{ $self->{objects} } ) {
	next if $seen{$obj->{entity_id}}++; #remove duplicate entity names
	push (@active_entities, $obj->{entity_id});
    }
        
    @inactive_entities = @{$self->{unhandled_entities}};
    
    if ($cmd eq 'active' or $cmd eq 'all') {
        for my $i (@active_entities) {
            $self->log( "Active: $i");
        }
    }
    if ($cmd eq 'inactive' or $cmd eq 'all') {
        for my $i (@inactive_entities) {
            $self->log( "Inactive: $i");
        }
    }
}

sub print_object_attrs {
    my ($self,$obj) = @_;

    $obj =~ tr/-/_/;
    $self->log( "Showing details for object $obj" );
    $self->log( "-----------------------------");
    my $object = main::get_object_by_name($obj);
    $self->log( "Entity = " . $object->{entity_id}) if ( $object->{entity_id});
    $self->log( "Subtype = " . $object->{subtype}) if ( $object->{subtype});
    if( $object->{ha_state}  &&  $object->{ha_state}->{attributes} ) {
	$self->log( "Showing HA entity attributes: \n" . $self->dump( $object->{ha_state}->{attributes}) );
    }
    if( $object->{subitems} ) {
	# $self->log( "Showing collected entity values in attr: \n" . $self->dump( $object->{attr} ) );
	my $str='';
	for my $attr_name ( sort keys %{$object->{subitems}} ) {
	    $str .= "   $attr_name: $object->{subitems}->{$attr_name}->{entity_id}: " . $object->{subitems}->{$attr_name}->state() . "\n";
	}
	$self->log( "Showing sub-item values: \n$str" );
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

    push @{ $self->{objects} }, $p_object;

    return $p_object;
}

sub remove_all_items {
    my ($self) = @_;

    $self->log("remove_all_items()");
    delete $self->{objects};
}

sub add_item_if_not_present {
    my ( $self, $p_object ) = @_;

    if ( ref $self->{objects} ) {
        foreach ( @{ $self->{objects} } ) {
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

    if ( ref $self->{objects} ) {
        for ( my $i = 0; $i < scalar( @{ $self->{objects} } ); $i++ ) {
            if ( $self->{objects}->[$i] eq $p_object ) {
                splice @{ $self->{objects} }, $i, 1;
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
    $obj = $obj || "undef";
    $maxdepth = $maxdepth || 2;
    my $dumper = Data::Dumper->new( [$obj] );
    $dumper->Maxdepth( $maxdepth );
    return $dumper->Dump();
}

=item C<new(HA_Item, domain, entity, ha_server )>

    Creates a HA_Item object that mirrors domain.entity in the HomeAssistant server ha_server.

    domain:     the HA domain of the entity
    entity:     the HA entity name
    ha_server:  the HA_Server object connected to the Home Assistant server

=cut

sub new {
    my ($class, $fulldomain, $entity, $ha_server, $options ) = @_;
    my $self = new Generic_Item();
    bless $self, $class;

    if( !$ha_server ) {
	&HA_Server::error( undef, "No homeassistant server set" );
        return;
    }
    $self->{ha_server} = $ha_server;
    my ($domain,$subtype) = split /:/, $fulldomain;
    $subtype = "" unless $subtype;
    $self->{domain} = $domain;
    $self->{subtype} = $subtype;    
    $self->{duplicate_states} = 1;
    $self->{unavailable_count} = 0;
    $self->{msg_trk} = {};
    $self->{msg_trk}->{response_check_delay} = 5;
    @{$self->{msg_trk}->{pending_msg_queue}} = ();
    $self->{msg_trk}->{pending_msgid} = 0;
    $self->{msg_trk}->{delay_between_messages} = 0;

    if (defined $options) {
	my @option_list = split( '\|', $options );
	foreach my $option (@option_list) {
	    if( $option eq 'no_duplicate_states' ) {
		$self->{duplicate_states} = 0;
	    } elsif( my ($delay) = $option =~ m/delay_between_messages\s*\=\s*(\d+)/ ) {
		$self->{msg_trk}->{delay_between_messages} = $delay;
		$self->{msg_trk}->{response_check_delay} += $delay;
	    } else {
		$self->error( "Invalid HA_Item option: '$option'. HA_Item entity $entity NOT created" );
		return;
	    }
	}
        $self->debug( 1, "New HA_Item ( $class, $domain, $entity, $subtype, [$options] )" );
    } else {
        $self->debug( 1, "New HA_Item ( $class, $domain, $entity, $subtype, [no options] )" );
    }
    # $self->{attr} = {};
    $self->{subitems} = {};
    if( $domain eq 'switch' ) {
        $self->set_states( "off", "on" );
    } elsif( $domain eq 'light' ) {
        if ($self->{subtype} eq "rgb_color") {
            $self->set_states("rgb");
        } elsif ($self->{subtype} eq "effect") {
           # placeholder in case we need to do something. States are set dynamically when the object is set      
        } else {
            $self->set_states( "off", "10%", "20%", "30%", "40%", "50%", "60%", "70%", "80%", "90%", "on" );
        }
    } elsif( $domain eq 'cover' ) {
        if (lc $self->{subtype} eq "digital") {
            $self->set_states( "closed", "10%", "20%", "30%", "40%", "50%", "60%", "70%", "80%", "90%", "open" );
        } else {
            $self->set_states( "closed", "stop", "open" );
        }
    } elsif( $domain eq 'lock' ) {
        $self->set_states( "unlocked", "locked" );      
    } elsif( $domain eq 'fan' ) {
        # placeholder in case we need to do something. States are set dynamically when the object is set      
    } elsif( $domain eq 'climate' ) {
    } elsif( $domain eq 'sensor'  ||  $domain eq 'binary_sensor' ) {
    } elsif( $domain eq 'select'  ||  $domain eq 'input_select' ) {
    } elsif( $domain eq 'text'    ||  $domain eq 'input_text' ) {
    } elsif( $domain eq 'number'  ||  $domain eq 'input_number' ) {
        
    } else {
        $self->error( "Invalid type for HA_Item -- '$domain'" );
        return;
    }

    my @patterns = split( '\|', $entity );
    if( scalar @patterns == 0 ) {
	@patterns = $entity;
    }
    my $entity_name = undef;
    for my $pattern (@patterns) {
	if( $pattern !~ m/\*/  &&  !$entity_name) {
	    $entity_name = $pattern;
	    next;
	} elsif( $pattern =~ m/^[^\*]*[^\.]\*$/ ) {
	    $pattern = substr( $pattern, 0, length($pattern)-1 ) . '(.*)';
	} 
	my $regex = eval { qr/$pattern/ };
	if( $@ ) {
	    $self->error( "invalid pattern $pattern: $@  --  Item not created" );
	    return;
	}
	push @{$self->{entity_patterns}}, $pattern;
    }
    if( !$entity_name ) {
	$entity_name = $self->{entity_patterns}[0];
    }

    $self->{entity} = $entity_name;
    $self->{entity_id} = "${domain}.${entity_name}";

    if( $self->{entity_patterns} ) {
	$self->debug( 1, "$self->{entity_id} patterns: " . join( '|', @{$self->{entity_patterns}}) );
    }

    $self->{msg_trk}->{msg_response_timer} = ::Timer::new();
    $self->{msg_trk}->{msg_delay_timer}	= ::Timer::new();
    $self->{ha_server}->add( $self );

    return $self;
}

sub set_parent {
    my( $self, $parent_item ) = @_;

    $self->{parent_item} = $parent_item;
    $self->{msg_trk} = $parent_item->{msg_trk};
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

    $self->debug( 2, "$self->{object_name} set by $p_setby to: $setval" );

    if( lc $self->{state} eq lc $setval ) {
	# If the state is set to its current value, HA will not send back a state change
	# call SUPER:set at this point to reflect the set call
	$self->{ha_current_setparms} = undef;
	$self->level( $setval ) if $self->can( 'level' );
	$self->SUPER::set( $setval, $p_setby, $p_response );
    } else {
	my $setparms = {};
	$setparms->{mh_pending_setby} = $p_setby;
	$setparms->{mh_pending_response} = $p_response;
	$setparms->{value} = $setval;
	$self->{ha_current_setparms} = $setparms;
    }
    if( $self->{domain} eq 'select'  ||  $self->{domain} eq 'input_select' ) {
	$self->ha_set_select( $setval );
    } elsif( $self->{domain} eq 'climate' ) {
	$self->ha_set_climate( $setval );
    } else {
	$self->ha_set_state( $setval );
    }
    $self->{ha_current_setparms} = undef;
}

sub set_mh_state {
    my ($self, $state, $p_setby, $p_response ) = @_;

    if( ($self->{duplicate_states} == 0) and ( lc( $self->state() ) eq lc( $state )) ) {
	$self->debug( 1, "Duplicate state $state ignored on $self->{object_name}" );
	return;
    }
    $self->SUPER::set( $state, $p_setby, $p_response );
}

=item C<process_ha_message(cmd, p_setby )>

    Process a message from HA, and set the local item to the corresponding value.
    This may be a state change message initiated by us sending a message to HA, or
    it may have been initiated in HA.

=cut
sub process_ha_message {
    my ( $self, $cmd, $p_setby ) = @_;
    my $p_response;

    # The cmd is an object representing the json new_state

    my $new_state = $cmd;
    $self->{ha_state} = $cmd;
    if( ref $self->{ha_pending_setparms} ) {
	$p_setby = $self->{ha_pending_setparms}->{mh_pending_setby};
	$p_response = $self->{ha_pending_setparms}->{mh_pending_response};
    }
    delete $self->{ha_pending_setparms};
    if( !$self->{msg_trk}->{delay_between_messages} ) {
	$self->ha_send_message();
    }

    if( $new_state->{state} eq 'unavailable' ) {
	$self->debug( 1, "received 'unavailable' value for $self->{object_name}" );
	$self->{unavailable_count} += 1;
	if( $self->{unavailable_count} < 3 ) {
	    return;
	}
    } else {
	$self->{unavailable_count} = 0;
    }
    
    if( $self->{domain} eq 'switch'
    ||  $self->{domain} eq 'lock'
    ||  $self->{domain} eq 'sensor'
    ||  $self->{domain} eq 'number'  ||  $self->{domain} eq 'input_number'
    ||  $self->{domain} eq 'text'    ||  $self->{domain} eq 'input_text'
    ) {
	$self->debug( 1, "$self->{domain} event for $self->{object_name} set to $new_state->{state}" );
	$self->set_mh_state( $new_state->{state}, $p_setby, $p_response );
    } elsif( $self->{domain} eq 'binary_sensor' ) {
	if( (defined $p_setby) && ($p_setby eq 'ha_server_init') ) {
	    if( defined ( $self->{ha_state}->{attributes}->{device_class}) ) {
		$self->debug( 1, "Found a device class for a binary sensor: $self->{ha_state}->{attributes}->{device_class} ");
		if( ($self->{subtype})  and  ($self->{subtype} ne $self->{ha_state}->{attributes}->{device_class}) ) {
		    $self->log( "WARNING: device class found ($self->{ha_state}->{attributes}->{device_class}), but object has a hardcoded subtype ($self->{subtype}) in object defintion. Not setting device class $self->{ha_state}->{attributes}->{device_class}" );
		} else {
		    $self->{subtype} = $self->{ha_state}->{attributes}->{device_class};
		}
	    }
	}
        if( $self->{subtype} ) {
            my $map_state = $self->get_binary_sensor_mapped_state(lc $self->{subtype},$new_state->{state});
            $self->debug( 1, "binary_sensor $self->{subtype} mapped event for $self->{object_name} set to $new_state->{state} (mapped to $map_state)" );
 	    $self->set_mh_state( $map_state, $p_setby, $p_response );
 	} else {
	    $self->debug( 1, "binary_sensor unmapped event for $self->{object_name} set to $new_state->{state}" );
	    $self->set_mh_state( $new_state->{state}, $p_setby, $p_response );
	}             
    } elsif( $self->{domain} eq 'cover' ) {
	my $level = $new_state->{state};
	if (lc $self->{subtype} eq "digital") {
	    if( $new_state->{attributes}->{current_position} ) {
		$level = $new_state->{attributes}->{current_position}; # * 100 / 255;
		$level .= "%";
	    }
	}    
	$level = "open" if ($level eq "100%");
	$level = "closed" if ($level eq "0%");
	$self->debug( 1, "cover:$self->{subtype} event for $self->{object_name} set to $level" );
	$self->set_mh_state( $level, $p_setby, $p_response );
    } elsif( $self->{domain} eq 'select'  ||  $self->{domain} eq 'input_select' ) {
	$self->debug( 1, "$self->{domain} event for $self->{object_name} set to $new_state->{state}" );
	$self->set_mh_state( $new_state->{state}, $p_setby, $p_response );
	if( $p_setby  &&  $p_setby eq 'ha_server_init' ) {
	    $self->set_states( @{$new_state->{attributes}->{options}},"override=1" );
	}
    } elsif( $self->{domain} eq 'fan' ) {
	my $level = $new_state->{state};
	if( $new_state->{state} eq 'on' ){
	    $level = $new_state->{attributes}->{percentage} . "%" if( $new_state->{attributes}->{percentage} );
	    $level = "off" if ($level eq "0%");
	}    
	$self->debug( 1, "fan event for $self->{object_name} set to $new_state->{state} ($level)" );
	$self->set_mh_state( $level, $p_setby, $p_response );
	if( $p_setby  &&  $p_setby eq 'ha_server_init' ) {
	    #percentage_step gives the number of speed steps for the fan
	    if (defined $new_state->{attributes}->{percentage_step}) {
		my @states = ();
		push @states, "off";
		for ($i = $new_state->{attributes}->{percentage_step}; $i < 100; $i = $i + $new_state->{attributes}->{percentage_step}) {
		next if ($i >96);
		push @states,int($i) . "%";
	    }
	    push @states, "100%","on";
		$self->set_states( @states,"override=1" );
	    } else {
		$self->set_states( "on", "off","override=1" );
	    }
	}
    } elsif( $self->{domain} eq 'light' ) {
	if (lc $self->{subtype} eq "rgb_color" || lc $self->{subtype} eq "hs_color") {
	    if( $new_state->{attributes}  &&  ref $new_state->{attributes}->{$self->{subtype}} ) {
		#shouldn't join, but rgb is an array so for now create a string
		my $string = join ',', @{$new_state->{attributes}->{ $self->{subtype} }}; 
		$self->debug( 1, "handled subtype $self->{subtype} event for $self->{object_name} set to $string" );
		$self->set_mh_state( $string, $p_setby, $p_response );
	    } else {
		$self->debug( 1, "got light state for $self->{object_name} but no rgb_color or hs_color attribute" );
	    }
	} elsif (lc $self->{subtype} eq "effect") {
	    # update the set_states based on the effects_list array
	    $self->debug( 1, "effect_list [" . join (',',@{$new_state->{attributes}->{effect_list}}) . "]" );
	    #override=1 is a way to bypass the returnif $main::reload in Generic Item set_state
	    $self->set_states(@{$new_state->{attributes}->{effect_list}},"override=1");
	    #the if clause prevents the state from disspearing if the aurora turns off.
	    $self->set_mh_state( $setval->{attributes}->{effect}, $p_setby, $p_response ) if ($setval->{attributes}->{effect});
	} else {    
	    my $level = $new_state->{state};
	    if( $new_state->{state} eq 'on' ){
		if( $new_state->{attributes}->{brightness} ) {
		    $level = int( $new_state->{attributes}->{brightness} * 100 / 255 + .5);
		    $level .= '%';
		}
	    }    
	    $self->debug( 1, "light event for $self->{object_name} set to $level" );
	    $self->set_mh_state( $level, $p_setby, $p_response );
	}
    } elsif( $self->{domain} eq 'climate' ) {
	my $state;
	foreach my $attrname (keys %{$new_state->{attributes}} ) {
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
	if( $self->{subtype} ) {
	    $self->debug( 1, "climate $self->{object_name} set: $state" );
	} else {
	    $self->debug( 1, "climate $self->{object_name} default object set: $state" );
	}
	if( $p_setby  &&  $p_setby eq 'ha_server_init' ) {
	    if( $self->{subtype} eq 'hvac_mode' ) {
		$self->set_states( @{$new_state->{attributes}->{hvac_modes}},"override=1" );
	    } elsif( $self->{subtype} eq 'fan_mode' ) {
		$self->set_states( @{$new_state->{attributes}->{fan_modes}},"override=1" );
	    } elsif( $self->{subtype} eq 'preset_mode' ) {
		$self->set_states( @{$new_state->{attributes}->{preset_modes}},"override=1" );
	    }
	}
	$self->set_mh_state( $state, $p_setby, $p_response );
    }
}

=item C<ha_perform_action(action_name, action_data_hash )>

    Will send a message to HA to perform the action 'action_name' on the entity passing in the
    kwargs parameters specified in action_data_hash.
    This will cause a state change to be sent to the HA entity mirrored by the item.
    Local state will not be changed until the state_change event is received back from the HA server.

=cut
sub ha_perform_action {
    my ($self, $action, $action_data) = @_;
    my $ha_msg = {};
    my $entity_id;
    my $action_name;
    my $domain;

    $ha_msg->{type} = 'call_service';
    ($domain, $entity_id, $action_name) = $action =~ /^([^\.]+)\.([^\.]+)\.([^\.]+)$/;
    if( $entity_id ) {
	$entity_id = "$domain.$entity_id";
    } else {
	($domain, $action_name) = $action =~ /^([^\.]+)\.([^\.]+)$/;
	if( $domain ) {
	    $entity_id = undef;
	} else {
	    $entity_id = $self->{entity_id};
	    $action_name = $action;
	    $domain = $self->{domain};
	}
    }
    $ha_msg->{domain} = $domain;
    if( $entity_id ) {
	$ha_msg->{target} = {};
	$ha_msg->{target}->{entity_id} = $entity_id;
    }
    $ha_msg->{service} = $action_name;
    if( defined( $action_data )  &&  keys %$action_data) {
        $ha_msg->{service_data} = $action_data;
    }

    $self->ha_send_message( $ha_msg );
}

# This function is provided for backwards compatibility
sub ha_call_service {
    my ($self, $action, $action_data) = @_;
    return $self->ha_perform_action( $action, $action_data );
}

sub ha_send_message {
    my ($self, $ha_msg) = @_;

    if( $ha_msg ) {
	$ha_msg->{ha_setparms} = $self->{ha_current_setparms};
	push @{$self->{msg_trk}->{pending_msg_queue}}, $ha_msg;
	if( $self->{msg_trk}->{pending_msgid} ) {
	    $self->debug( 1, "message to HA queued" );
	    return;
	}
    } else {
	$self->{msg_trk}->{pending_msgid} = 0;
    }
    $ha_msg = shift @{$self->{msg_trk}->{pending_msg_queue}};
    if( !$ha_msg ) {
	return;
    }
    $self->{ha_pending_setparms} = $ha_msg->{ha_setparms};
    delete $ha_msg->{ha_setparms};

    $self->{msg_trk}->{pending_msgid} = $self->{ha_server}->ha_process_write( $ha_msg );
    $self->debug( 2, "sent command to HA: " . $self->dump( $ha_msg ) );
    $self->{msg_trk}->{msg_response_timer}->stop();
    $self->{msg_trk}->{msg_response_timer}->set($self->{msg_trk}->{response_check_delay}, sub { &HA_Item::ha_check_message( $self, $ha_msg ) });
}

sub ha_check_message {
    my ($self, $ha_msg) = @_;
    if( $self->{msg_trk}->{pending_msgid} == $ha_msg->{id} ) {
	$self->error( "$self->{object_name} message $ha_msg->{id} for entity '$ha_msg->{target}->{entity_id}' --  response timer expired, sending next message" );
	$self->ha_send_message();
    }
}

sub ha_set_select {
    my ($self, $mode) = @_;
    my $cmd;
    my $action;
    my $action_data = {};

    $action = 'select_option';
    $action_data->{option} = $mode;
    $self->ha_perform_action( $action, $action_data );
}

sub ha_set_climate {
    my ($self, $setval) = @_;
    my $action_data = {};
    my $action;

    if( $self->{subtype} eq 'onoff' ) {
        if( lc $setval eq 'turn_on' || lc $setval eq 'on' ) {
            $action = 'turn_on';
        } elsif( lc $setval eq 'turn_off' ||  lc $setval eq 'off' ) {
            $action = 'turn_off';
        } elsif( lc $setval eq 'toggle' ) {
            $action = 'toggle';
        }
    } elsif( $self->{subtype} eq 'target_temp_low' ) {
        $action_data->{target_temp_low} = $setval;
        $action_data->{target_temp_high} = $self->{ha_state}->{attributes}->{target_temp_high};
    } elsif( $self->{subtype} eq 'target_temp_high' ) {
        $action_data->{target_temp_high} = $setval;
        $action_data->{target_temp_low} = $self->{ha_state}->{attributes}->{target_temp_low};
    } else {
        my $action_name = $self->{subtype};
        if( !action_name ) {
            $action_name = 'hvac_mode';
        }
        $action = "set_${action_name}";
        $action_data->{$action_name} = $setval;
    }
    $self->ha_perform_action( $action, $action_data );
}

sub ha_set_state {
    my ($self, $mode) = @_;
    my $cmd;
    my $action;
    my $action_data = {};
	$self->debug( 1, "ha_set_state. Setting $self->{object_name} to $mode" );
    
    $action = $mode;
    my ($numval) = $mode =~ /^([1-9]?[0-9]?[0-9])%?$/;
    if( defined $numval ) {
        if (lc $self->{domain} eq 'light') {
	    if( $numval == 0 ) {
		$action = 'turn_off';
	    } else {
		$action = 'turn_on';
		$action_data->{brightness_pct} = $numval;
	    }
        } elsif (lc $self->{domain} eq 'cover') {
            $action = 'set_cover_position';
            $action_data->{position} = $numval;
        } elsif (lc $self->{domain} eq 'fan') {
            $action = 'set_percentage';
            $action_data->{percentage} = $numval;
	    } elsif ( lc $self->{domain} eq 'number'  ||  lc $self->{domain} eq 'input_number' ) {
            $action = 'set_value';
            $action_data->{value} = $numval;
        } else {
	    $self->error( "Numeric value set for domain that doesn't handle numbers" );
	}
    } elsif( lc $mode eq 'on' ) {
        $action = 'turn_on';
    } elsif( lc $mode eq 'toggle' ) {
        $action = 'toggle';
    } elsif( lc $mode eq 'off' ) {
        $action = 'turn_off';
    } elsif( lc $mode eq 'open' ) {
        if (lc $self->{domain} eq 'lock') {
            $action = 'open';
        } else {
            $action = 'open_cover';
        }
    } elsif( lc $mode eq 'up' ) {
        $action = 'open_cover';
    } elsif( lc $mode eq 'down' ) {
        $action = 'close_cover';
    } elsif( lc $mode eq 'closed' ) {
        $action = 'close_cover';
    } elsif( lc $mode eq 'stop' ) {
        $action = 'stop_cover';
    } elsif( lc $mode eq 'locked' ) {
        $action = 'lock';
    } elsif( lc $mode eq 'unlocked' ) {
        $action = 'unlock';
    } elsif( lc $mode =~ /\d+,\d+,\d+/ && $self->{subtype} eq 'rgb_color') {
        $action = 'turn_on';
        @{$action_data->{rgb_color}} = split /,/, $mode;
    } elsif( lc $mode =~ /\d+,\d+/ && $self->{subtype} eq 'hs_color') {
        $action = 'turn_on';
        @{$action_data->{hs_color}} = split /,/, $mode;
    }  elsif(  $self->{subtype} eq 'effect') {
        $action = 'turn_on';
        $action_data->{effect} = $mode;
    }          
    $self->ha_perform_action( $action, $action_data );
}

sub get_binary_sensor_mapped_state {
    my ($self, $class, $state) = @_;
    my %map_table;
    $map_table{battery}{on} = "low";
    $map_table{battery}{off} = "normal";
    $map_table{battery_charging}{on} = "charging";
    $map_table{battery_charging}{off} = "not charging";
    $map_table{co}{on} = "detected";
    $map_table{co}{off} = "clear";
    $map_table{cold}{on} = "cold";
    $map_table{cold}{off} = "normal";
    $map_table{connectivity}{on} = "connected";
    $map_table{connectivity}{off} = "disconnected";
    $map_table{door}{on} = "open";
    $map_table{door}{off} = "closed";
    $map_table{garage_door}{on} = "open";
    $map_table{garage_door}{off} = "closed";
    $map_table{gas}{on} = "detected";
    $map_table{gas}{off} = "clear";
    $map_table{heat}{on} = "hot";
    $map_table{heat}{off} = "normal";
    $map_table{light}{on} = "light";
    $map_table{light}{off} = "dark";
    $map_table{lock}{on} = "open";
    $map_table{lock}{off} = "closed";
    $map_table{moisture}{on} = "wet";
    $map_table{moisture}{off} = "dry";
    $map_table{motion}{on} = "motion";
    $map_table{motion}{off} = "still";
    $map_table{moving}{on} = "moving";
    $map_table{moving}{off} = "stopped";
    $map_table{occupancy}{on} = "occupied";
    $map_table{occupancy}{off} = "empty";
    $map_table{opening}{on} = "open";
    $map_table{opening}{off} = "closed";
    $map_table{plug}{on} = "connected";
    $map_table{plug}{off} = "disconnected";
    $map_table{power}{on} = "power";
    $map_table{power}{off} = "no power";
    $map_table{presence}{on} = "home";
    $map_table{presence}{off} = "away";
    $map_table{problem}{on} = "problem";
    $map_table{problem}{off} = "ok";
    $map_table{running}{on} = "running";
    $map_table{running}{off} = "not running";
    $map_table{safety}{on} = "unsafe";
    $map_table{safety}{off} = "safe";
    $map_table{smoke}{on} = "detected";
    $map_table{smoke}{off} = "clear";
    $map_table{sound}{on} = "detected";
    $map_table{sound}{off} = "clear";
    $map_table{tamper}{on} = "detected";
    $map_table{tamper}{off} = "clear";
    $map_table{update}{on} = "update available";
    $map_table{update}{off} = "up-to-date";
    $map_table{vibration}{on} = "detected";
    $map_table{vibration}{off} = "clear";
    $map_table{window}{on} = "open";
    $map_table{window}{off} = "closed";
    if (defined $map_table{$class}{$state}) {
        return $map_table{$class}{$state};
    } else {
        return $state;
    }
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

=item C<get_attr(name_of_attribute)>

Returns the state of an attribute inside a mulit-entity object

=cut

sub get_attr {
    my ($self,$attr) = @_;
    
    if( !$self->{subitems}->{$attr} ) {
	$self->error("get_attr called on non-existant attribute [$attr]" );
	return;
    }
    return $self->{subitems}->{$attr}->state();
}

=item C<set_attr(name_of_attribute, setval, setby, response)>

Returns the state of an attribute inside a mulit-entity object

=cut

sub set_attr {
    my ( $self, $attr, $setval, $p_setby, $p_response ) = @_;

    if( !$self->{subitems}->{$attr} ) {
	$self->error("set_attr called on non-existant attribute [$attr]" );
	return;
    }
    $self->{subitems}->{$attr}->set( $setval, $p_setby, $p_response );
}

=item C<get_state_override()>

Override the default behaviour of the current state being unselectable in IA7

=cut

sub get_state_override {
    my ($self) = @_;
    my $return = 0;
    $return = 1 if (lc $self->{domain} eq "cover");
    
    return $return;
}
=item C<get_state_override()>

Fetch specific information about an HA entity. For example, a light that has an effects list would be
my @effects = $object->get_entity_attributes('effects_list');
Specifying no attribute will return a hash with everything. The attributes can be seen by using the voice_cmd in the web interface

=cut
sub get_entity_attributes {
    my ($self,$attr) = @_;
    $self->debug( 2, Dumper $self->{ha_state}->{attributes});
    if (defined $attr) {
        if (defined $self->{ha_state}->{attributes}->{$attr}) {
            $self->debug( 1, "get_entity_attributes: attr=$attr. value=" . $self->{ha_state}->{attributes}->{$attr} .". return type is: [" . ref(\$self->{ha_state}->{attributes}->{$attr}) . " " . ref($self->{ha_state}->{attributes}->{$attr}) . "]");
            if (ref($self->{ha_state}->{attributes}->{$attr}) eq "ARRAY") {
                return  @{$self->{ha_state}->{attributes}->{$attr}};
            } elsif (ref(\$self->{ha_state}->{attributes}->{$attr}) eq "SCALAR") {
                return  $self->{ha_state}->{attributes}->{$attr};
            } elsif (ref(\$self->{ha_state}->{attributes}->{$attr}) eq "HASH") {
                return  $self->{ha_state}->{attributes}->{$attr};
            } else {
        	$self->error("get_entity_attributes unknown variable reference: " . ref($self->{ha_state}->{attributes}->{$attr}));
        	return;
            }            
        } else {
       	    $self->error("get_entity_attributes called on non-existant attribute [$attr]" );
        }
    
    } else {
        $self->debug( 1, "get_entity_attributes: return all: return type is: [" . ref(\$self->{ha_state}->{attributes}) . " " . ref($self->{ha_state}->{attributes}) . "]");
        return $self->{ha_state}->{attributes} ;
    }

}
# -[ Fini - HA_Item ]---------------------------------------------------------

1;
