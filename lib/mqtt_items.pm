# ------------------------------------------------------------------------------


=begin comment
    @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@

    =head1 B<mqtt_BaseItem>
    =head1     B<mqtt_LocalItem>
    =head1     B<mqtt_BaseRemoteItem>
    =head1         B<mqtt_RemoteItem> B<mqtt_InstMqttItem> B<mqtt_DiscoveredItem>
    =head1 B<mqtt_Discovery>

    Dave Neudoerffer <dave@neudoerffer.com>

    =head2 SYNOPSIS

    An MQTT Items module for Misterhouse.
    Uses existing interface class in mqtt.pm.
    It does not use the mqtt_Item class in mqtt.pm.

    Can be used together with mqtt_discovery.pm to publish and process
    Home Assistant format discovery messages.

    =head2 DESCRIPTION

    Misterhouse MQTT items for use with many MQTT services.

    Home Assistant format discovery message processing.

    MQTT website: http://mqtt.org/
    MQTT Test service: http//test.mosquitto.org/ (test.mosquitto.org port 1883)

File:
    mqtt_items.pm
    mqtt_discovery.pm

Description:
    This is a misterhouse style items interface for MQTT devices

    For more information about the MQTT protocol:
        http://mqtt.org

    Author(s):
    Dave Neudoerffer <dave@neudoerffer.com>

    MQTT (mqtt.pm)
    --------------
    This module uses mqtt.pm to create an object that communicates to the mqtt server.

    There are several generic functions in this module that will do things to/with
    all of the objects that are created for that mqtt server.


    MQTT Items (mqtt_items.pm)
    --------------------------

    There are several MQTT item types implemented in this module (see below).

    Each item can handle both commands and state messages to/from MQTT devices.
    LWT messages can also be handled for remote items.

    There are several classes implemented in mqtt_items.pm:

    mqtt_BaseItem:
         - is the base class.

	mqtt_LocalItem:
	    - implements an mqtt mh item that is tied to a local item
	    - when the local item changes state, this mqtt item will send mqtt state_topic messages
	    - it will also listen for mqtt command_topic messages and set the state of the local item,
	      if the set of the local item is successful, the mqtt item will send out the state_topic message
	    - a LocalItem can be associated with a specific broker, in which case it will
	      listen only to that broker for commands and will send state messages only to
	      that broker
	    - if there is no broker specified, then the LocalItem will listen to all brokers
	      for command messages, and broadcast state messages to all brokers
	    - can publish HA discovery info -- a fairly simple discovery language is
	      used that is based on the insteon-mqtt project

	mqtt_BaseRemoteItem:
	    - implements a base class mh item that both sends commands to and
	      receives state messages from a remote device that directly sends mqtt messages
	    - a BaseRemoteItem is always associated with a specific mqtt broker
	    - when set is called, will send command_topic messages to change the state of a device
	        - local state will not change until state_topic message is received unless
		  the item is marked as optimistic or does not have a state_topic
	    - will listen for state_topic messages with stata changes
	    - will also listen for last will and testiment (LWT) messages reporting
	      when a device goes offline

	    mqtt_RemoteItem
	        - implements a statically defined mh item for mqtt devices
		- it is intended to work with Tasmota, IOT4 and ESPurna devices,
		  BUT, I have a very limited set of devices to test with
		    - currently implements switch, light, sensor, binary-sensor
		    - I only have Tasmota switches, and with tuya convert broken,
		      I am not able to setup other Tasmota devices
		      (not into soldering at this point)
		- Remote devices can also be discovered using the gear in mqtt_discovery.pm
		  eliminating the need to statically define them, but you need to
		  turn discovery on on your device (eg. Tasmota: SetOption19 1)
		  -- note that the Tasmota discovery gear is not being developed anymore...
		- can publish HA discovery info -- a simpler discovery message
		  than the discontinued Tasmota discovery mentioned above

	    mqtt_InstMqttItem
	        - implements a statically defined mh item for Insteon devices managed
		  by insteon-mqtt OR another instance of MisterHouse (since the MH published
		  MQTT messages are based on insteon-mqtt).  You could also use discovered items
		  for this purpose.
		- see https://github.com/TD22057/insteon-mqtt
		- can publish HA discovery info, as insteon-mqtt does not implement discovery yet
    

    Discovery (mqtt_discovery.pm):
    -----------------------------

    This module implements MQTT discovery.  Both publishing discovery information for locally
    defined devices, as well as receiving discovery information from mqtt devices and from other
    mqtt sources -- like home assistant.

    The discovery definitions are based on the Home Assistant Discovery info:
        https://www.home-assistant.io/docs/mqtt/discovery

    There are several uses for mqtt discovery in MH:
        - discover mqtt devices without having to statically define them in .mht files
	- publish discovery information for locally defined devices.  This has multiple
	  uses as well:
	    - share device information with another MH instance
	    - publish device information to Home Assistant.  This could be
	      for environments where both are running, or used when
	      transitioning one way or the other.


    There are 2 classes implemented in mqtt_discovery.pm:

	mqtt_DiscoveredItem:
	    This class extends the mqtt_BaseRemoteItem class and implements
	    a mh item from a mqtt discovery message.
	    It has been built to handle 2 types of discovery messages:
		1. discovery messages as published by the below discovery
		   class primarily for mqtt_LocalItems, but discovery info
		   for RemoteItems and InstMqttItems can also be published.
		   This allows easy sharing of device definitions between MH instances,
		   and also allows Home Assistant to know about MH items.
		2. discovery messages published by remote devices.
		   It handles some Tasmota, IOT4 discovery messages published
		   when Tasmota SetOption19 is set to 1, or HASS discovery turned on
		   on the IOT4 device.  I don't have any ESPurna devices so I don't
		   know about discovery for those devices.
		   - it handles switch, light, sensor and binary-sensor
		   - so far the handling of discovery messages is somewhat limited due
		     to my very limited set of these devices
		   - I have implemented these devices based on HomeAssistant documentation
		     for discovery and information on blakaddr.com
		   - In order to implement this properly, we would need a templating engine in perl

	    You can move one of the items from the file written out by write_discovered_items, or
	    you could hand code an item of this type using a full discovery message.  When you are
	    hand declaring an mqtt item using this format, change the discovery_topic to just
	    the discovery_type -- that will internally mark it so that it is not written out
	    next time write_discovered_items is called.
	
	mqtt_Discovery:
	     This class has 2 functions.  The discovery_action parameter defines which ones
	     it does -- publish, subscribe, both, none.

	     Subscribe:
	         - it defines a single mqtt_BaseItem that that listens for mqtt discovery messages
	           based on an mqtt wildcard
		 - creates mqtt_DiscoveredItems based on the discovery information that is received
		 - you can then write out these items to a .mht file using the mqtt::write_discovered_items class function
		     - note that the discovered items will not appear as fully referencable MH items
		       until you restart MH once.
	     Publish:
	         - this class will setup publishing of discovery information for mqtt_LocalItems and
	           even for any of the mqtt_BaseRemoteItems if they are created with the discovery flag set
	         - this last part is useful if you have an mqtt device somewhere whose discovery
		   info is not great, or doesn't publish discovery info



License:
    This free software is licensed under the terms of the GNU public license.

Usage:

    .mht file:
	###################################################
	# Broker record creates object to connect to mqtt server
	###################################################

	# MQTT_BROKER,	name,	   subscribe topic,	host/ip,	port,	user,	pwd,	keepalive
	MQTT_BROKER,	mqtt_1,	   ,			localhost,	1883,	,	,	121

	###################################################
	# Use of Discovery functionality is optional
	# - discovery topic prefix is used for publishing discovery info
	#     - it can be blank which means no discovery info will be published
	#     - the most common use is to publish discovery info to home assistant,
	#       the home assistant default discovery topic is 'homeassistant'
	###################################################

	# MQTT_DISCOVERY,   obj name,		discovery prefix,   broker,	publish|subscribe|both (default both)
	MQTT_DISCOVERY,	    mqtt_discovery1,	homeassistant,	    mqtt_1,	both


	###################################################
	# Different Item types for different types of MQTT functionality
	#
	# TopicPattern should be of the form "<node_id>/<mqtt name>/+".
	#    - It is best to use the same <node_id> for all items, but not necessary
	#    - It helps identify your own discovery messages in a large mqtt system
	###################################################

	# Used to define mqtt items as published by insteon-mqtt project or as published
	# by another instance of MisterHouse which has defined MQTT_LOCALITEMs.
	#
	# MQTT_INSTMQTT,    name,		groups,		broker, type,		topicpattern,				    discoverable    Friendly Name
	MQTT_INSTMQTT,	    bootroom_switch,	Lights,		mqtt_1, switch,		insteon/bootroom/+,			    1,		    Bootroom Light

	# Define a Tasmota item.  Note that the topicpattern must be in the order that the device will
	# send.  This is configured in the Tasmota MQTT configuration. 
	#
	# MQTT_REMOTEITEM,  name,		groups,		broker, type,		topicpattern,				    discoverable    Friendly Name
	MQTT_REMOTEITEM,    tas_outdoor_plug,	,		mqtt_1, switch,		tasmota_outdoor_plug/+/+,		    0,		    Tasmota Outdoor Plug


        # Say you have a local INSTEON item  (could be any kind of misterhouse item)
	INSTEON_SWITCHLINC, 52.9E.DD,		shed_light,	Lights|Outside
	#
        # Then you can create an mqtt item to publish its state and receive mqtt commands.
	# TopicPattern should be of the form "<node_id>/<mqtt name>/+".
	# *** This can be used to publish local MH items to Home Assistant.
	#
	# MQTT_LOCALITEM,   name,		local item,	broker, type,		topicpattern,				    discoverable    Friendly Name
	MQTT_LOCALITEM,	    bootroom_switch,	shed_light,	mqtt_1, switch,		insteon/bootroom/+,			    1,		    Bootroom Light
	#


	
    .mht generated file:

	# Discovery items are generated by the write_discovered_items function.
	# You would not normally code these by hand.
	#
	# But if you want to move an item to your regular .mht file, change the discovery_topic to just
	# the discovery_type.  That then will override any discovered item with the same unique_id,
	# and will not be written out with write_discovered_items.
	#
	# You could code one of these items by hand. This would also allow you to declare a remote
	# mqtt item using the full discovery message format.
	#
	# MQTT_DISCOVEREDITEM,	name,			    discovery_obj,	discovery_topic/discovery_type,			    discovery_message
	MQTT_DISCOVEREDITEM,	mqtt_tasmota_outdoor_plug,  mqtt_discovery,	 homeassistant/switch/877407_RL_1/config,   {"name":"Tasmota Outside Plug","cmd_t":"~cmnd/POWER","stat_t":"~tele/STATE","val_tpl":"{{value_json.POWER}}","pl_off":"OFF","pl_on":"ON","avty_t":"~tele/LWT","pl_avail":"Online","pl_not_avail":"Offline","uniq_id":"877407_RL_1","device":{"identifiers":["877407"],"connections":[["mac","D8:F1:5B:87:74:07"]]},"~":"tasmota_outdoor_plug/"}


    and misterhouse user code:

        #
	if( $bootroom_switch->{state_now} ) {
	    &print_log( "Bootroom light set " . $bootroom_switch->state );
	}

	#
	if( new_minute(10) ) {
	    # this will turn on the light by sending an mqtt command
	    $bootroom_switch->set( 'toggle' );

	    # as the insteon light is toggled with this command, an mqtt state message will be published
	    $shed_light->set( 'toggle' );

	}

	# this will publish mqtt discovery messages for all discoverable items
	$mqtt_1->publish_discovery_data();

	# this will publish current state messages for all local items
	$mqtt_1->publish_current_states();

	# this will write a .mht file with data for all discovered items
	&mqtt::write_discovered_items( "$config_parms{data_dir}/mqtt_discovered_items.mht" );

    CLI generation of a command to the CR_Temp

	TODO:  find a command that works to turn on the $shed_light
        mosquitto_pub -d -h test.mosquitto.org -q 0 -t test.mosquitto.org/test/x10/1 -m "Off"

Notes:
    @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@

    Special Thanks to:
    Neil Cherry -- original implementer of misterhouse MQTT support
    Giles Godard-Brown -- MQTT and Tasmota support

    This code has been developed using the insteon-mqtt public project and
    using HomeAssistant and using Tasmota devices.

    @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@

    =head2 B<Notes:>

    I believe most people using MQTT are running their own mqtt
    server.  Typically mosquitto.

    If you are using a higher traffic mosquitto server, then you
    will want to qualify topics more.  That would require configuring
    your Tasmota devices to have a qualified prefix.

    Discovery:
    For discovery, there are a lot of device types out there and a lot of different
    discovery message formats.  I have handled common device types in this code,
    but it can be extended to handle many more. I have only been able to implement
    Tasmota switches and a rough implementation of Tasmota Dimmers based on zapping
    a device I have to think that it is a dimmer.

    =head2 INHERITS

    B<NONE>

    =head2 METHODS

    =over

    =item B<UnDoc>

    =item B<ToDo>

    @TODO:
        1. Add more Tasmota types

=cut

# ------------------------------------------------------------------------------

package mqtt_BaseItem;

use strict;

use JSON qw( decode_json encode_json );     #
use Data::Dumper;

@mqtt_BaseItem::ISA = ( 'Generic_Item' );



=item C<new(mqtt_interface, name, type, state_topic, command_topic, listen_topic, discoverable, friendly_name )>

    Creates an MQTT Base Item.

    Note: This function does not setup the {disc_info} structure.  That is left up to the child classes.

=cut

sub new {   ### mqtt_BaseItem
    my ( $class, $interface, $mqtt_name, $type, $listentopics, $discoverable ) = @_;

    my $self = new Generic_Item();

    bless $self, $class;

    $self->{interface}		    = $interface;
    $self->{mqtt_name}		    = $mqtt_name;
    $self->{mqtt_type}		    = $type;
    $self->{discoverable}	    = $discoverable;
    $self->{topic}		    = $listentopics;
    $self->{disc_type}		    = $type;

#     if( !grep( /^$type$/, ('light', 'switch', 'binary_sensor', 'sensor', 'scene', 'select') ) ) {
# 	$self->error( "UNKNOWN DEVICE TYPE: '$self->{mqtt_name}':$self->{mqtt_type}" );
# 	return;
#     }

    if( $self->{mqtt_type} eq 'scene' ) {
	$self->{disc_type} = 'switch';
    }

    if( $self->{interface} ) {
	$self->{interface}->add( $self );
    } else {
	foreach $interface ( &mqtt::get_interface_list() ) {
	    $interface->add( $self );
	}
    }

    return $self;
}

sub log {
    my( $self, $str ) = @_;
    $self->{interface}->log( $str );
}

sub error {
    my( $self, $str ) = @_;
    $self->{interface}->error( $str );
}

sub debug {
    my( $self, $level, $str ) = @_;
    if( $self->debuglevel( $level, 'mqtt' ) ) {
	$self->{interface}->log( $str, "[MQTT D$level]: " );
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

=item C<level(p_level)>

Stores and returns the objects current on_level as a percentage. If p_level 
is ON and the device has a defined local_onlevel, the local_onlevel is stored 
as the numeric level in memory.

Returns [0-100]

=cut

sub level {
    my ( $self, $p_level ) = @_;
    #
    # This is really only valid for light type, but it doesn't hurt for other types
    #
    if ( defined $p_level ) {
        my $level = undef;
        if ( $p_level eq 'on' ) {

            # set the level based on any locally defined on level
            $level = $self->local_onlevel if $self->can('local_onlevel');

            # set to 100 if a local on level is not defined
            $level = 100 unless defined($level);
        }
        elsif ( $p_level eq 'off' ) {
            $level = 0;
        }
        elsif ( $p_level =~ /^([1]?[0-9]?[0-9])%?$/ ) {
            if ( $1 < 1 ) {
                $level = 0;
            }
            else {
                $level = $1;
            }
        }
        $$self{level} = $level if defined $level;
    }
    return $$self{level};

}


sub transmit_mqtt_message {
    my( $self, $topic, $msg, $retain ) = @_;

    if( !$topic ) {
	$self->error( $self->get_object_name . " attempting to publish empty topic -- ignoring" );
	return;
    }
    if( $self->{interface} ) {
	$self->{interface}->publish_mqtt_message( $topic, $msg, $retain );
    } else {
	&mqtt::broadcast_mqtt_message( $topic, $msg, $retain );
    }
}

sub process_template {
    my( $self, $template, $value_json, $value ) = @_;

    if( $template ) {
	$template =~ s/ //g;
	$template =~ s/^\{\{value_json\.([a-zA-Z\-_]*)\}\}/\$value_json->\{\1\}/;
	$template =~ s/^\{\{value_json\[\\?\'?([a-zA-Z\-_]*)\\?\'?\]\}\}/\$value_json->\{\1\}/;
	if( $template !~ /^\$/ ) {
	    $self->error( "unable to process template $template" );
	    return;
	}
	$self->debug( 2, "fishing template value out of json with '\$value = $template'" );
	eval "\$value = $template";
	if( $@  || !$value_json ) {
	    $self->error( "Error '$@' applying template '$template' to payload:'$value'" );
	}
    }
    return $value;
}

sub decode_mqtt_payload {
    my( $self, $topic, $payload, $retained ) = @_;
    my $msg;
    my $unset_value = 'unset_value_987654123';
    my $value_json;
    my $value;
    my $brightness;
    my $value_on;
    my $value_off;

    $msg = $unset_value;
    if( $topic eq $self->{disc_info}->{state_topic} ) {
	$value_on = $self->{disc_info}->{state_on};
	$value_off = $self->{disc_info}->{state_off};
    }
    $value_on = $self->{disc_info}->{payload_on} if !defined $value_on;
    $value_off = $self->{disc_info}->{payload_off} if !defined $value_off;
    $value_on = 'ON' if !defined $value_on;
    $value_off = 'OFF' if !defined $value_off;

    if( $payload =~ /^\s*{/ ) {
	eval{ $value_json = decode_json( $payload ) };
	if( $@  || !$value_json ) {
	    $self->error( "Error '$@' decoding JSON: $payload" );
	    return;
	}
	$self->debug( 3, "json payload decoded to: \n" . Dumper( $value_json ) );
    }

    ####
    # Note that the state_topic and the brightness_state_topic can be the same, and likely are!
    ####

    if( $topic eq $self->{disc_info}->{state_topic} ) {
	$value = $self->process_template( $self->{disc_info}->{state_value_template} || $self->{disc_info}->{value_template}, $value_json, $payload );
    }
    if( $topic eq $self->{disc_info}->{brightness_state_topic} ) {
	$brightness = $self->process_template( $self->{disc_info}->{brightness_value_template}, $value_json, $payload );
	my $brightness_scale = $self->{disc_info}->{brightness_scale} || 255;
	$brightness = int( $brightness * 100 / $brightness_scale ) . '%';
    }
    if( $topic eq $self->{disc_info}->{command_topic} ) {
	$value = $payload;
    }
    $self->debug( 3, "payload '$payload' decoded to: '$value'" );

    # if( $$self{mqtt_type} eq 'binary_sensor'  ||  $$self{mqtt_type} eq 'sensor' ) {
    #	if( $retained ) {
    #	    $self->debug( 1, "Retained message ignored for $$self{mqtt_type}:$$self{mqtt_name} device" );
    #	    return;
    #	}
    # }

    if( $$self{mqtt_type} eq 'light'  ) {
	if( $self->{disc_info}->{schema} eq 'json' ) {
	    if( $value_json ) {
		$self->debug( 3, "Decoded state:$value_json->{state} brightness:$value_json->{brightness}" );
		if( $value_json->{state} eq $value_on ) {
		    if( $value_json->{brightness} ) {
			my $brightness_scale = $self->{disc_info}->{brightness_scale} || 255;
			$msg = int( $value_json->{brightness} * 100 / $brightness_scale ) . '%';
		    } else {
			$msg = 'on';
		    }
		} elsif( $value_json->{state} eq $value_off ) {
		    $msg = 'off';
		}
	    }
	} else {
	    if( $value eq $value_off ) {
		$msg = 'off';
	    } elsif( $brightness ) {
		$msg = $brightness;
	    } elsif( $value eq $value_on ) {
		$msg = 'on';
	    }
	}
    } elsif( $$self{mqtt_type} eq 'switch'
    ||       $$self{mqtt_type} eq 'scene'
    ) {
	$msg = 'on' if $value eq $value_on;
	$msg = 'off' if $value eq $value_off;
    } elsif( $$self{mqtt_type} eq 'binary_sensor' ) {
	if( $value eq $value_on ) {
	    $msg = 'on';
	    if( $self->{disc_info}->{off_delay} ) {
		$msg .= "~$self->{disc_info}->{off_delay}~off";
	    }
	} elsif( $value eq $value_off ) {
	    if( !$self->{disc_info}->{off_delay} ) {
		$msg = 'off';
	    } else {
		# ignore off command if {off_delay} is set -- item will be set off by above set timer
		return;
	    }
	}
    } elsif( $$self{mqtt_type} eq 'sensor' ) {
        $msg = $value;
    } elsif( $$self{mqtt_type} eq 'select' ) {
        $msg = $value;
    } elsif( $$self{mqtt_type} eq 'text' ) {
        $msg = $value;
    } elsif( $$self{mqtt_type} eq 'number' ) {
        $msg = $value;
    } elsif( $$self{mqtt_type} eq 'cover' ) {
        $msg = $value;
    } else {
	$self->debug( 2, "Unknown object type '$$self{mqtt_type}' on object '$$self{topic}'" );
	$msg = $value_json;
    }
    if( $msg eq $unset_value ) {
        $self->error( "Unable to decode mqtt message for $$self{mqtt_name} type:$$self{mqtt_type} message:'$payload'" );
	# $self->error( Dumper( $self ) );
	$msg = undef;
    }
    return $msg;
}

sub encode_mqtt_payload {
    my( $self, $setval, $topic ) = @_;
    my $payload;
    my $value;
    my $brightness;
    my $brightness_scale;
    my $value_on;
    my $value_off;

    $payload = undef;
    if( $topic eq $self->{disc_info}->{state_topic} ) {
	$value_on = $self->{disc_info}->{state_on};
	$value_off = $self->{disc_info}->{state_off};
    }
    $value_on = $self->{disc_info}->{payload_on} if !defined $value_on;
    $value_off = $self->{disc_info}->{payload_off} if !defined $value_off;
    $value_on = 'ON' if !defined $value_on;
    $value_off = 'OFF' if !defined $value_off;

    $brightness_scale = $self->{disc_info}->{brightness_scale} || 255;
    my $level;
    if( $self->{mqtt_type} eq 'light' ) {
	($level) = $setval =~ /^([1]?[0-9]?[0-9])%?$/;
    }
    if( $self->{mqtt_type} eq 'sensor'
    ||  $self->{mqtt_type} eq 'select'
    ||  $self->{mqtt_type} eq 'text'
    ||  $self->{mqtt_type} eq 'number'
    ||  $self->{mqtt_type} eq 'cover'
    ) {
	$payload = $setval;
	return $payload;
    }

    # on/off/level type
    if( $level ) {
	if ( $level < 1 ) {
	    $level = 0;
	    $value = $value_off;
	} else {
	    $value = $value_on;
	}
	$brightness = int( ( $level * $brightness_scale / 100 ) + .5 );
    } elsif( $setval eq 'on' ) {
	$value = $value_on;
	$brightness = $brightness_scale;
    } elsif( $setval eq 'off' ) {
	$value = $value_off;
	$brightness = 0;
    } else {
	$self->error( "Unknown set value '$setval' for on/off/level mqtt type" );
	return;
    }

    if( $self->{mqtt_type} eq 'light' ) {
	if( $self->{disc_info}->{schema} eq 'json' ) {
	    $payload = "{ \"state\" : \"$value\", \"brightness\" : $brightness }";
	} else {
	    if( $topic eq $self->{disc_info}->{command_topic} ) {
		$payload = $value;
	    } elsif( $topic eq $self->{disc_info}->{brightness_command_topic} ) {
		$payload = $brightness;
	    }
	}
    } elsif( $self->{mqtt_type} eq 'switch' 
    ||       $self->{mqtt_type} eq 'binary_sensor'
    ||       $self->{mqtt_type} eq 'scene'
    ) {
	$payload = $value;
    } else {
	$self->error( "Unknown object type '$$self{mqtt_type}' on object '$$self{mqtt_name}'" );
    }
    return $payload;
}

my $short_name_map = {
    'act_t' =>               'action_topic',
    'act_tpl' =>             'action_template',
    'atype' =>               'automation_type',
    'aux_cmd_t' =>           'aux_command_topic',
    'aux_stat_tpl' =>        'aux_state_template',
    'aux_stat_t' =>          'aux_state_topic',
    'avty' =>                'availability',
    'avty_t' =>              'availability_topic',
    'away_mode_cmd_t' =>     'away_mode_command_topic',
    'away_mode_stat_tpl' =>  'away_mode_state_template',
    'away_mode_stat_t' =>    'away_mode_state_topic',
    'b_tpl' =>               'blue_template',
    'bri_cmd_t' =>           'brightness_command_topic',
    'bri_scl' =>             'brightness_scale',
    'bri_stat_t' =>          'brightness_state_topic',
    'bri_tpl' =>             'brightness_template',
    'bri_val_tpl' =>         'brightness_value_template',
    'clr_temp_cmd_tpl' =>    'color_temp_command_template',
    'bat_lev_t' =>           'battery_level_topic',
    'bat_lev_tpl' =>         'battery_level_template',
    'chrg_t' =>              'charging_topic',
    'chrg_tpl' =>            'charging_template',
    'clr_temp_cmd_t' =>      'color_temp_command_topic',
    'clr_temp_stat_t' =>     'color_temp_state_topic',
    'clr_temp_tpl' =>        'color_temp_template',
    'clr_temp_val_tpl' =>    'color_temp_value_template',
    'cln_t' =>               'cleaning_topic',
    'cln_tpl' =>             'cleaning_template',
    'cmd_off_tpl' =>         'command_off_template',
    'cmd_on_tpl' =>          'command_on_template',
    'cmd_t' =>               'command_topic',
    'cmd_tpl' =>             'command_template',
    'cod_arm_req' =>         'code_arm_required',
    'cod_dis_req' =>         'code_disarm_required',
    'curr_temp_t' =>         'current_temperature_topic',
    'curr_temp_tpl' =>       'current_temperature_template',
    'dev' =>                 'device',
    'dev_cla' =>             'device_class',
    'dock_t' =>              'docked_topic',
    'dock_tpl' =>            'docked_template',
    'err_t' =>               'error_topic',
    'err_tpl' =>             'error_template',
    'fanspd_t' =>            'fan_speed_topic',
    'fanspd_tpl' =>          'fan_speed_template',
    'fanspd_lst' =>          'fan_speed_list',
    'flsh_tlng' =>           'flash_time_long',
    'flsh_tsht' =>           'flash_time_short',
    'fx_cmd_t' =>            'effect_command_topic',
    'fx_list' =>             'effect_list',
    'fx_stat_t' =>           'effect_state_topic',
    'fx_tpl' =>              'effect_template',
    'fx_val_tpl' =>          'effect_value_template',
    'exp_aft' =>             'expire_after',
    'fan_mode_cmd_t' =>      'fan_mode_command_topic',
    'fan_mode_stat_tpl' =>   'fan_mode_state_template',
    'fan_mode_stat_t' =>     'fan_mode_state_topic',
    'frc_upd' =>             'force_update',
    'g_tpl' =>               'green_template',
    'hold_cmd_t' =>          'hold_command_topic',
    'hold_stat_tpl' =>       'hold_state_template',
    'hold_stat_t' =>         'hold_state_topic',
    'hs_cmd_t' =>            'hs_command_topic',
    'hs_stat_t' =>           'hs_state_topic',
    'hs_val_tpl' =>          'hs_value_template',
    'ic' =>                  'icon',
    'init' =>                'initial',
    'json_attr_t' =>         'json_attributes_topic',
    'json_attr_tpl' =>       'json_attributes_template',
    'max_mirs' =>            'max_mireds',
    'min_mirs' =>            'min_mireds',
    'max_temp' =>            'max_temp',
    'min_temp' =>            'min_temp',
    'mode_cmd_t' =>          'mode_command_topic',
    'mode_stat_tpl' =>       'mode_state_template',
    'mode_stat_t' =>         'mode_state_topic',
    'name' =>                'name',
    'off_dly' =>             'off_delay',
    'on_cmd_type' =>         'on_command_type',
    'opt' =>                 'optimistic',
    'osc_cmd_t' =>           'oscillation_command_topic',
    'osc_stat_t' =>          'oscillation_state_topic',
    'osc_val_tpl' =>         'oscillation_value_template',
    'pl' =>                  'payload',
    'pl_arm_away' =>         'payload_arm_away',
    'pl_arm_home' =>         'payload_arm_home',
    'pl_arm_custom_b' =>     'payload_arm_custom_bypass',
    'pl_arm_nite' =>         'payload_arm_night',
    'pl_avail' =>            'payload_available',
    'pl_cln_sp' =>           'payload_clean_spot',
    'pl_cls' =>              'payload_close',
    'pl_disarm' =>           'payload_disarm',
    'pl_hi_spd' =>           'payload_high_speed',
    'pl_home' =>             'payload_home',
    'pl_lock' =>             'payload_lock',
    'pl_loc' =>              'payload_locate',
    'pl_lo_spd' =>           'payload_low_speed',
    'pl_med_spd' =>          'payload_medium_speed',
    'pl_not_avail' =>        'payload_not_available',
    'pl_not_home' =>         'payload_not_home',
    'pl_off' =>              'payload_off',
    'pl_off_spd' =>          'payload_off_speed',
    'pl_on' =>               'payload_on',
    'pl_open' =>             'payload_open',
    'pl_osc_off' =>          'payload_oscillation_off',
    'pl_osc_on' =>           'payload_oscillation_on',
    'pl_paus' =>             'payload_pause',
    'pl_stop' =>             'payload_stop',
    'pl_strt' =>             'payload_start',
    'pl_stpa' =>             'payload_start_pause',
    'pl_ret' =>              'payload_return_to_base',
    'pl_toff' =>             'payload_turn_off',
    'pl_ton' =>              'payload_turn_on',
    'pl_unlk' =>             'payload_unlock',
    'pos_clsd' =>            'position_closed',
    'pos_open' =>            'position_open',
    'pow_cmd_t' =>           'power_command_topic',
    'pow_stat_t' =>          'power_state_topic',
    'pow_stat_tpl' =>        'power_state_template',
    'r_tpl' =>               'red_template',
    'ret' =>                 'retain',
    'rgb_cmd_tpl' =>         'rgb_command_template',
    'rgb_cmd_t' =>           'rgb_command_topic',
    'rgb_stat_t' =>          'rgb_state_topic',
    'rgb_val_tpl' =>         'rgb_value_template',
    'send_cmd_t' =>          'send_command_topic',
    'send_if_off' =>         'send_if_off',
    'set_fan_spd_t' =>       'set_fan_speed_topic',
    'set_pos_tpl' =>         'set_position_template',
    'set_pos_t' =>           'set_position_topic',
    'pos_t' =>               'position_topic',
    'spd_cmd_t' =>           'speed_command_topic',
    'spd_stat_t' =>          'speed_state_topic',
    'spd_val_tpl' =>         'speed_value_template',
    'spds' =>                'speeds',
    'src_type' =>            'source_type',
    'stat_clsd' =>           'state_closed',
    'stat_closing' =>        'state_closing',
    'stat_off' =>            'state_off',
    'stat_on' =>             'state_on',
    'stat_open' =>           'state_open',
    'stat_opening' =>        'state_opening',
    'stat_locked' =>         'state_locked',
    'stat_unlocked' =>       'state_unlocked',
    'stat_t' =>              'state_topic',
    'stat_tpl' =>            'state_template',
    'stat_val_tpl' =>        'state_value_template',
    'stype' =>               'subtype',
    'sup_feat' =>            'supported_features',
    'swing_mode_cmd_t' =>    'swing_mode_command_topic',
    'swing_mode_stat_tpl' => 'swing_mode_state_template',
    'swing_mode_stat_t' =>   'swing_mode_state_topic',
    'temp_cmd_t' =>          'temperature_command_topic',
    'temp_hi_cmd_t' =>       'temperature_high_command_topic',
    'temp_hi_stat_tpl' =>    'temperature_high_state_template',
    'temp_hi_stat_t' =>      'temperature_high_state_topic',
    'temp_lo_cmd_t' =>       'temperature_low_command_topic',
    'temp_lo_stat_tpl' =>    'temperature_low_state_template',
    'temp_lo_stat_t' =>      'temperature_low_state_topic',
    'temp_stat_tpl' =>       'temperature_state_template',
    'temp_stat_t' =>         'temperature_state_topic',
    'temp_unit' =>           'temperature_unit',
    'tilt_clsd_val' =>       'tilt_closed_value',
    'tilt_cmd_t' =>          'tilt_command_topic',
    'tilt_inv_stat' =>       'tilt_invert_state',
    'tilt_max' =>            'tilt_max',
    'tilt_min' =>            'tilt_min',
    'tilt_opnd_val' =>       'tilt_opened_value',
    'tilt_opt' =>            'tilt_optimistic',
    'tilt_status_t' =>       'tilt_status_topic',
    'tilt_status_tpl' =>     'tilt_status_template',
    't' =>                   'topic',
    'uniq_id' =>             'unique_id',
    'unit_of_meas' =>        'unit_of_measurement',
    'val_tpl' =>             'value_template',
    'whit_val_cmd_t' =>      'white_value_command_topic',
    'whit_val_scl' =>        'white_value_scale',
    'whit_val_stat_t' =>     'white_value_state_topic',
    'whit_val_tpl' =>        'white_value_template',
    'xy_cmd_t' =>            'xy_command_topic',
    'xy_stat_t' =>           'xy_state_topic',
    'xy_val_tpl' =>          'xy_value_template',
};

sub normalize_discovery_info {
    my( $disc_info ) = @_;

    # convert short forms to long forms, replace any ~
    my $topic_subst = $disc_info->{'~'};
    delete $disc_info->{'~'};
    foreach my $disc_parm ( keys %{$disc_info} ) {
	my $longname = $short_name_map->{$disc_parm};
	if( $longname  &&  $longname ne $disc_parm ) {
	    $disc_info->{$longname} = $disc_info->{$disc_parm};
	    delete $disc_info->{$disc_parm};
	    $disc_parm = $longname;
	}
	if( $topic_subst  &&  $disc_parm =~ /^.*_topic$/ ) {
	    $disc_info->{$disc_parm} =~ s/^~/$topic_subst/;
	    $disc_info->{$disc_parm} =~ s/~$/$topic_subst/;
	}
    }
}

sub create_discovery_message {
    my( $self ) = @_;

    #############
    # Create discovery message, will only be published if $self->{discoverable} is true
    #############

    &mqtt_BaseItem::normalize_discovery_info( $self->{disc_info} );

    my $msg = {};
    my $discovery_node_id;

    my $disc_topic;
    my $disc_msg;

    # Note that the discovery topic prefix will be added by the mqtt_Discovery object
    # when the discovery messages are published
    if( $self->{node_id} ) {
         $disc_topic = "$self->{disc_type}/$self->{node_id}/$self->{disc_info}->{unique_id}/config";
    } else {
         $disc_topic = "$self->{disc_type}/$self->{disc_info}->{unique_id}/config";
    }
    my $json_obj = JSON->new->allow_nonref(1);
    $disc_msg = $json_obj->encode( $self->{disc_info} );

    $self->{disc_topic} = $disc_topic;
    $self->{disc_msg} = $disc_msg;

    $self->publish_discovery_message();
}

sub publish_discovery_message {
    my ($self) = @_;
    my $topic;
    my $msg;
    my $interface;

    $interface = $self->{interface};
    if( !$self->{interface}->isConnected() ) {
	$self->error( "Unable to publish discovery data -- $interface->{instance} not connected" );
	return 0;
    }
    if( !$self->{interface}->{discovery_publish_prefix} ) {
	return 0;
    }
    if( !$self->{discoverable} ) {
	$self->debug( 2, "Non-discoverable object skipped: ".  $self->{mqtt_name} );
	return 0;
    }
    if( $self->{mqtt_type} eq 'discovery' ) {
	return 0;
    }

    my ($topic, $msg) = ($self->{disc_topic}, $self->{disc_msg});
    if( $topic  &&  $msg ) {
	$topic = "$self->{interface}->{discovery_publish_prefix}/$topic";
	$self->debug( 2, "Publishing discovery message T:'$topic'   M:'$msg'" );
	$self->transmit_mqtt_message( $topic, $msg, 1 );
	return 1;
    }
    return 0;
}

# -[ Fini - mqtt_BaseItem ]---------------------------------------------------------


# ------------------------------------------------------------------------------

package mqtt_LocalItem;

use strict;

use Data::Dumper;
use Hash::Merge;

@mqtt_LocalItem::ISA = ( 'mqtt_BaseItem' );


=item C<new(mqtt_interface, name, type, local_object, topic_prefix, discoverable, friendly_name)>

    Creates a MQTT Local Item/object that will publish state information of the local object and respond to mqtt commands for the object

=cut

sub new {     ### mqtt_LocalItem
    my ( $class, $interface, $name, $type, $local_object, $topicpattern, $discoverable, $friendly_name ) = @_;

    my ($base_type, $device_class) = $type =~ m/^([^:]*):?(.*)$/;

    #auto populate type and class if the object has these elements embedded, but don't override explicitly set definitions
    $base_type = $local_object->{mqttlocalitem}->{base_type} if ((defined $local_object->{mqttlocalitem}->{base_type} ) and (!$type));
    $device_class = $local_object->{mqttlocalitem}->{device_class} if ((defined $local_object->{mqttlocalitem}->{device_class} ) and (!$device_class));
       
    if( !grep( /^$base_type$/, ('light','switch','binary_sensor', 'sensor', 'scene', 'select', 'text', 'number', 'cover' ) ) ) {
	$interface->error( "Invalid mqtt type '$type'" );
	return;
    }

    if( $local_object  &&  !ref $local_object ) {
	$interface->error( "Invalid local object: $local_object" );
	return;
    }

    my (@topic_parts) = split( "/", $topicpattern, 2 );
    my $node_id = $topic_parts[0];
    my $mqtt_name = ($topic_parts[1] =~ s"/[+#]?$""r);	# Remove trailing slash and wildcard, if present.
    my $topic_prefix = "$node_id/$mqtt_name";
    my $listen_topic;
    if( $#topic_parts == 1 ) {
	$listen_topic = "$topic_prefix/+";
    } else {
	$listen_topic = $topicpattern;
    }
    if( !$mqtt_name ) {
	$interface->error( "Invalid topic pattern '$topicpattern' on object '$name'" );
	return;
    }

    my $self = new mqtt_BaseItem( $interface, $mqtt_name, $base_type, $listen_topic, $discoverable );
    return
      if !$self;

    bless $self, $class;

    $self->{node_id} = $node_id;
    $self->debug( 1, "New mqtt_LocalItem( $interface->{instance}, '$mqtt_name', '$type', '$local_object', '$topicpattern', $discoverable, '$friendly_name' )" );
    $self->debug( 1,"Base_type=[$base_type] Device_Class=[$device_class]");

    $self->{disc_info} = {};
    if( !$friendly_name ) {
	$friendly_name = $self->{mqtt_name};
	$friendly_name =~ s/_/ /g;
    }
    $self->{disc_info}->{name} = $friendly_name;
    $self->{disc_info}->{state_topic} = "$topic_prefix/state";
    if( $base_type eq 'light' ) {
	$self->{disc_info}->{command_topic} = "$topic_prefix/level";
	$self->{disc_info}->{schema} = 'json';
	$self->{disc_info}->{brightness} = "true";
	$self->{disc_info}->{brightness_scale} = 100;
    } elsif( $base_type eq 'switch' ) {
	$self->{disc_info}->{command_topic} = "$topic_prefix/set";
	} elsif( $base_type eq 'cover' ) {
	$self->{disc_info}->{command_topic} = "$topic_prefix/set";
	if( $device_class ) {
	    $self->{disc_info}->{device_class} = $device_class;
	}
    } elsif( $base_type eq 'scene' ) {
	$self->{disc_info}->{command_topic} = "$topic_prefix/set";
	delete $self->{disc_info}->{state_topic};
    } elsif( $base_type eq 'binary_sensor' ) {
	if( $device_class ) {
	    $self->{disc_info}->{device_class} = $device_class;
	}
    } elsif( $base_type eq 'sensor' ) {
	if( $device_class ) {
	    $self->{disc_info}->{device_class} = $device_class;
	}
	if( $device_class eq 'temperature' ) {
	    $self->{disc_info}->{unit_of_measurement} = 'C';
	}
    } elsif( $base_type eq 'select' ) {
	$self->{disc_info}->{command_topic} = "$topic_prefix/set";
	if( $local_object ) {
	    my @state_list = $local_object->get_states();
	    $self->{disc_info}->{options} = \@state_list;
	}
    } elsif( $base_type eq 'text' ) {
	$self->{disc_info}->{command_topic} = "$topic_prefix/set";
    } elsif( $base_type eq 'number' ) {
	$self->{disc_info}->{command_topic} = "$topic_prefix/set";
    }

    $self->{is_local} = 1;

    if( $local_object ) {
	# Tie mqtt object to local_object so state changes are sent to mqtt broker
	$local_object->tie_items($self);
	$local_object->{mqtt_Local_Item} = $self;
	$self->{local_item} = $local_object;
    }

    if( $self->{local_item}  &&  $self->{local_item}->{device_id} ) {
	$self->{disc_info}->{unique_id} = $self->{node_id} . '_' . $self->{local_item}->{device_id};
	if( $self->{local_item}->{m_group} ) {
	    $self->{disc_info}->{unique_id} .= $self->{local_item}->{m_group};
	}
    } else {
	$self->{disc_info}->{unique_id} = $self->{node_id} . '_' . $self->{mqtt_name};
	$self->{disc_info}->{unique_id} =~ s/ /_/g;
    }

    # $self->create_discovery_message();


    # my $d = Data::Dumper->new( [$self] );
    # $d->Maxdepth( 3 );
    # $self->debug( 3, "locale item created: \n" . $d->Dump );


    # We may need flags to deal with XML, JSON or Text
    return $self;
}

sub add_discovery_info {
    my ($self,$extra_disc_info) = @_;

    my $merger = Hash::Merge->new( 'RIGHT_PRECEDENT' );
    $self->{disc_info} = $merger->merge( $self->{disc_info}, $extra_disc_info );

#    foreach my $key (keys %{$extra_disc_info}) {
#	if( exists $extra_disc_info  &&  ref $extra_disc_info->{$key} eq 'HASH' ) {
#	    if( !exists $self->{disc_info}->{$key} ) {
#		$self->{disc_info}->{$key} = {};
#	    }
#	    for my $key2 (keys %{$extra_disc_info->{
#
#	if( exists $self->{disc_info}->{$key} ) {
#	    $self->log( "Overriding $key in discovery info for: $self->{object_name}" );
#	}
#	$self->{disc_info}->{$key} = $extra_disc_info->{$key};
#    }
}

=item C<receive_mqtt_message( topic, message, retained )>
    Process received mqtt message
=cut

sub receive_mqtt_message {
    my ( $self, $topic, $message, $retained ) = @_;
    my $obj_name;

    ###
    ### Incoming (MQTT to MH) message for LocalItem
    ###
    # Local objects only subscribe to the command topic, all mqtt state messages are ignored
    # When an mqtt command comes in, the local object is set
    # If the local object set is successful, it will set the mqtt tied object
    # The mqtt object will then send out the state message

    if( $self->{local_item} ) {
	$obj_name = $self->{local_item}->get_object_name();
    } else {
	$obj_name = $self->get_object_name();
    }
    if( $topic eq $self->{disc_info}->{state_topic} ) {
	$self->debug( 2, "LocalItem $obj_name ignoring state topic message" );
    } elsif( $topic eq $self->{disc_info}->{command_topic} ) {
	if( $retained ) {
	    # command messages should never be retained, but just in case...
	    $self->log( "LocalItem received retained command message -- ignoring" );
	    return;
	}
	my $setval = $self->decode_mqtt_payload( $topic, $message, $retained );
	if( defined $setval ) {
	    $self->debug( 1, "LocalItem MQTT to MH setting $obj_name::set($setval) based on received message '$message'" );
	    if( $self->{local_item} ) {
		$self->{local_item}->set( $setval, 'mqtt' );
	    } else {
		$self->SUPER::set( $setval, 'mqtt' );
	    }
	}
    } else {
        $self->debug( 2, "LocalItem unhandled message T:'$topic'  M:'$message'" );
    }
}

=item C<set(state, p_setby, p_response)>
    Handle local set call
=cut

sub set {    ### LocalItem
    my ( $self, $setval, $p_setby, $p_response ) = @_;
    my $obj_name;

    # This is a locally called set($setval) -- either by the tied local_item or directly called on the object if there is no tied item

    return if &main::check_for_tied_filters( $self, $setval );

    if( $self->{local_item} ) {
	$obj_name = $self->{local_item}->get_object_name();
    } else {
	$obj_name = $self->get_object_name();
    }

    if( $self->{local_item}  &&  $p_setby ne $self->{local_item} ) {
	$self->error( "LocalItem $obj_name set($setval) called by other than tied local item -- $p_setby" );
	return;
    }

    ###
    ### Outgoing MH to MQTT for LocalItem
    ###
    my $topic = $self->{disc_info}->{state_topic};
    my $payload = $self->encode_mqtt_payload( $setval, $topic );
    if( $topic && defined ($payload)  ) {
	# Note that outgoing state messages are marked to be retained, so that any client can get the latest state info
	# when it starts up
	$self->debug( 1, "MH to MQTT LocalItem ${obj_name} set($setval) publishing state message '$payload' to mqtt" );
	$self->{has_published_state} = 1;
	$self->transmit_mqtt_message( $topic, $payload, 1 );
    }

    if( !$self->{local_item} ) {
	$self->SUPER::set( $setval, $p_setby );
    }
}

sub publish_state {
    my( $self, $only_unpublished ) = @_;
    my $msg;
    my $msg_txt;
    my $hass_type;
    my $obj_id;

    if( !$only_unpublished  ||  !$self->{has_published_state} ) {
	my $local_item;
	if( $self->{local_item} ) {
	    $local_item = $self->{local_item};
	} else {
	    $local_item = $self;
	}
	my $current_state = $local_item->state;
	my $self_name = $local_item->get_object_name();
	if( defined $current_state ) {
	    if( !$local_item->can('is_responder') || $local_item->is_responder ) {
		$self->debug( 1, "setting local object $self_name to current_state: $current_state" );
		$local_item->set( $current_state );
	    } else {
		$self->debug( 1, "object $self_name is not a responder" );
	    }
	} else {
	    $self->debug( 1, "object $self_name has no state" );
	}
    }
}


=item C<(publish_current_states( only_unpublished ))>
    Class function to publish the current states of all local mqtt objects for all mqtt servers

    This function has been replaced by publish_current_states() on the mqtt object
=cut

sub publish_current_states {
    my( $only_unpublished ) = @_;

    &mqtt::log( undef, "Publishing current state data for local objects" );
    foreach my $interface ( &mqtt::get_interface_list() ) {
	$interface->publish_current_states( $only_unpublished );
    }
}

# -[ Fini - mqtt_LocalItem ]---------------------------------------------------------

# ------------------------------------------------------------------------------

package mqtt_BaseRemoteItem;

use strict;

use JSON qw( decode_json encode_json );     #
use Data::Dumper;

@mqtt_BaseRemoteItem::ISA = ( 'mqtt_BaseItem' );


=item C<new(mqtt_interface, name, type, listentopic, discoverable )>

    Creates a base MQTT Remote Item.
    This function does not setup the {disc_info} structure.  That is left up to the child classes.

=cut

sub new {   ### mqtt_BaseRemoteItem
    my ( $class, $interface, $mqtt_name, $type, $listentopics, $discoverable ) = @_;

    my $self = new mqtt_BaseItem( $interface, $mqtt_name, $type, $listentopics, $discoverable );

    if( $self->{mqtt_type} eq 'light' ) {
	$self->set_states( "off", "20%", "40%", "50%", "60%", "80%", "on", "offline" );
    } elsif( $self->{mqtt_type} eq 'binary_sensor' ) {
	$self->set_states( "off", "on", "offline" );
    } elsif( $self->{mqtt_type} eq 'sensor' ) {
    } elsif( $self->{mqtt_type} eq 'switch' ) {
	$self->set_states( "off", "on", "offline" );
    } elsif( $self->{mqtt_type} eq 'scene' ) {
	$self->set_states( "off", "on", "offline" );
    }

    bless $self, $class;

    return $self;
}


=item C<receive_mqtt_message( topic, message, retained)>
=cut

sub receive_mqtt_message {
    my ( $self, $topic, $message, $retained ) = @_;
    my $p_setby;
    my $p_response;
    my $setval;

    ###
    ### Incoming MQTT to MH message for InstMqttItem
    ###
    ### Note that a light object seems to be a superset of a switch so I think
    ### we can handle the message without testing the mqtt type...
    ###

    $self->debug( 2, "remote item $self->{object_name} received message R:$retained T:$topic  M:$message" );

    if( $topic eq $self->{disc_info}->{command_topic} 
    ||  $topic eq $self->{disc_info}->{brightness_command_topic}
    ||  $topic eq $self->{disc_info}->{color_temp_command_topic}
    ||  $topic eq $self->{disc_info}->{effect_command_topic}
    ||  $topic eq $self->{disc_info}->{hs_command_topic}
    ||  $topic eq $self->{disc_info}->{rgb_command_topic}
    ||  $topic eq $self->{disc_info}->{white_value_command_topic}
    ||  $topic eq $self->{disc_info}->{xy_command_topic}
    ) {
	$self->debug( 2, "remote item $self->{object_name} ignoring command topic message T:'$topic'" );
	return;
    }


    if( $topic eq $self->{disc_info}->{state_topic} 
    ||  $topic eq $self->{disc_info}->{brightness_state_topic}
    ) {
	if( $self->{disc_info}->{optimistic} eq 'true'  &&  $self->{pending_state} ) {
	    $self->debug( 2, "BaseRemoteItem $self->{object_name} ignored state message because device is optimistic" );
	    $self->{pending_state}    = undef;
	    $self->{pending_setby}    = undef;
	    $self->{pending_response} = undef;
	} else {
	    if( $retained ) {
		$p_setby = 'mqtt [retained]';
	    } elsif( $self->{pending_state} ) {
		$setval = $self->{pending_state};
		$p_setby = $self->{pending_setby};
		$p_response = $self->{pending_response};
		$self->{pending_state}    = undef;
		$self->{pending_setby}    = undef;
		$self->{pending_response} = undef;
		$self->debug( 2, "Pending $self->{object_name}-->set( $setval, $p_setby, $p_response ) cleared" );
	    } else {
		$p_setby = 'mqtt';
	    }
	    $setval = $self->decode_mqtt_payload( $topic, $message, $retained );
	    if( ref $setval ) {
		$self->{state_obj} = $setval;
		$setval = undef;
	    }
	    if( $setval ) {
		$self->debug( 1, "remote item MQTT to MH $$self{mqtt_name} set($setval, '$p_setby')" );
		$self->level( $setval ) if $self->can( 'level' );
		$self->SUPER::set( $setval, $p_setby, $p_response );
	    }
	}
	return;
    }
    if( $topic eq $self->{disc_info}->{availability_topic} ) {
	if( $retained ) {
	    $p_setby = 'mqtt [retained]';
	} else {
	    $p_setby = 'mqtt';
	}
	if( $message eq $self->{disc_info}->{payload_available} ) {
	    if( !$retained ) {
		$self->log( "$self->{object_name} now available" );
	    }
	} elsif( $message eq $self->{disc_info}->{payload_not_available} ) {
	    $self->log( "$self->{mqtt_name} is not available" );
	    $self->SUPER::set( $message, $p_setby );
	} else {
	    $self->error( "$self->{object_name} received unrecognized availability message: $message" );
	}
	return;
    }

    $self->debug( 2, "BaseRemoteItem unhandled message T:'$topic'  M:'$message'" );
}

sub transmit_topic {
    my ($self, $topicname, $setval) = @_;

    my $obj_name = $self->get_object_name;
    my $topic = $self->{disc_info}->{$topicname};
    if( !$topic ) {
	$self->debug( 2, "BaseRemoteItem $obj_name does not have topic:$topicname -- not publishing" );
	return;
    }
    my $payload = $self->encode_mqtt_payload( $setval, $topic );
    if( defined $payload ) {
	$self->debug( 1, "MH to MQTT BaseRemoteItem $obj_name::set($setval) publishing command '$payload' to mqtt" );
	$self->transmit_mqtt_message( $topic, $payload, 0 );
    }
}


=item C<set(state, p_setby, p_response)>
    Handle local set calls
=cut

sub set {    ### BaseRemoteItem
    my ( $self, $setval, $p_setby, $p_response ) = @_;

    print( "BaseRemoteItem set($setval, $p_setby) called\n" ) if $main::Debug{set};
    return if &main::check_for_tied_filters( $self, $setval );
    print( "BaseRemoteItem set($setval, $p_setby) passed filters\n" ) if $main::Debug{set};

    # Override any set_with_timer requests
    if ( $$self{set_timer} ) {
	print( $self->get_object_name . " unsetting timer\n" ) if $main::Debug{set};
        &Timer::unset( $$self{set_timer} );
        delete $$self{set_timer};
    }

    ###
    ### Outgoing MH to MQTT for BaseRemoteItem
    ###

    if( $self->{mqtt_type} eq 'light'  &&  $self->{disc_info}->{schema} ne 'json' ) {
	if( !$self->{disc_info}->{on_command_type}
	||  $self->{disc_info}->{on_command_type} eq 'last'
	) {
	    $self->transmit_topic( 'brightness_command_topic', $setval );
	    $self->transmit_topic( 'command_topic', $setval );
	} elsif( $self->{disc_info}->{on_command_type} eq 'first' ) {
	    $self->transmit_topic( 'command_topic', $setval );
	    $self->transmit_topic( 'brightness_command_topic', $setval );
	} elsif( $self->{disc_info}->{on_command_type} eq 'brightness' ) {
	    $self->transmit_topic( 'brightness_command_topic', $setval );
	}
    } else {
	$self->transmit_topic( 'command_topic', $setval );
    }

    $self->{pending_state}    = $setval;
    $self->{pending_setby}    = $p_setby;
    $self->{pending_response} = $p_response;
    if( $self->{disc_info}->{optimistic} eq 'true') {
	$self->level( $setval ) if $self->can( 'level' );
	$self->SUPER::set( $setval, $p_setby, $p_response );
    } else {
	$self->debug( 2, "Pending $self->{object_name}-->set( $setval, $p_setby, $p_response )" );
    }
}

=item C<set_with_timer(state, time, return_state, addition_return_states)>
    Handle local set_with_timer calls

    NOTE:  This timer functionality is required here because the Generic_Item timer
           is reset by Generic_Item set calls, and the set call for the Generic_Item
	   in this case is delayed until the state response is received from the mqtt device.
=cut

sub set_with_timer {
    my ( $self, $state, $time, $return_state, $additional_return_states ) = @_;
    return if &main::check_for_tied_filters( $self, $state );

    $self->set($state) unless $state eq '';

    return unless $time;

    my $state_change = ( $state eq 'off' ) ? 'on' : 'off';
    $state_change = $return_state if defined $return_state;
    $state_change = $self->{state}
      if $return_state and lc $return_state eq 'previous';

    $state_change .= ';' . $additional_return_states
      if $additional_return_states;

    $$self{set_timer} = &Timer::new() unless $$self{set_timer};
    my $object_name = $self->{object_name};
    my $action      = "$object_name->set('$state_change')";
    $$self{set_timer}->set( $time, $action );
}


# -[ Fini - mqtt_BaseRemoteItem ]---------------------------------------------------------

# ------------------------------------------------------------------------------

package mqtt_RemoteItem;

use strict;

use Data::Dumper;

@mqtt_RemoteItem::ISA = ( 'mqtt_BaseRemoteItem' );


=item C<new(mqtt_interface, name, type, topicpattern, discoverable, friendly_name)>

    Creates a MQTT RemoteItem/object that will mirror the state of the object, and send commands to it.

=cut

sub make_topic {
    my ( $topicpattern, @parms ) = @_;

    my (@topic_parts) = split( "/", $topicpattern );
    my $wildcard_count = 0;
    for( my $i=0; $i <= $#topic_parts; $i += 1 ) {
	my $part = $topic_parts[$i];
	if( $part eq '+' ) {
	    $topic_parts[$i] = $parms[$wildcard_count];
	    $wildcard_count += 1;
	}
    }
    return join( '/', @topic_parts );
}

sub new {      ### mqtt_RemoteItem
    my ( $class, $interface, $type, $topicpattern, $discoverable, $friendly_name ) = @_;

    my ($base_type, $device_class) = $type =~ m/^([^:]*):?(.*)$/;

    if( !grep( /$base_type/, ('light','switch','sensor','binary_sensor','cover') ) ) {
	$interface->error( "Invalid InstMqttItem type '$type'" );
	return;
    }

    my $mqtt_name;
    my (@topic_parts) = split( "/", $topicpattern );
    my $wildcard_count = 0;
    for( my $i=0; $i <= $#topic_parts; $i += 1 ) {
	my $part = $topic_parts[$i];
	if( grep( /^$part$/, ('tele', 'stat', 'cmnd') ) ) {
	    $topic_parts[$i] = '+';
	} elsif( $part eq '+' ) {
	    $wildcard_count += 1;
	} else {
	    $mqtt_name = $part;
	}
    }
    if( !$mqtt_name ) {
	$interface->error( "Unrecognized topic pattern '$topicpattern' for device '$friendly_name'" );
    }

    my $listen_topic = join( '/', @topic_parts );

    my $self = new mqtt_BaseRemoteItem( $interface, $mqtt_name, $base_type, $listen_topic, $discoverable );

    return
      if !$self;

    bless $self, $class;

    $self->debug( 1, "New mqtt_RemoteItem( $interface->{instance}, '$mqtt_name', '$type', '$topicpattern', $discoverable, '$friendly_name' )" );

    $self->{discovered} = 0;

    $self->{disc_info} = {};
    if( !$friendly_name ) {
	$friendly_name = $self->{mqtt_name};
	$friendly_name =~ s/_/ /g;
    }
    $self->{disc_info}->{name} = $friendly_name;
    if( $wildcard_count == 2 ) {
	$self->{disc_info}->{availability_topic} = make_topic( $listen_topic, 'tele', 'LWT' );
	$self->{disc_info}->{payload_available} = 'Online';
	$self->{disc_info}->{payload_not_available} = 'Offline';
    }
    if( $base_type eq 'switch' ) {
	if( $wildcard_count != 2 ) {
	    $self->error( "Don't know how to create switch topics for '$friendly_name'" );
	}
	$self->{disc_info}->{command_topic} = make_topic( $listen_topic, 'cmnd', 'POWER' );
	$self->{disc_info}->{state_topic} = make_topic( $listen_topic, 'stat', 'POWER' );
    } elsif( $base_type eq 'light' ) {
	if( $wildcard_count != 2 ) {
	    $self->error( "Don't know how to create light topics for '$friendly_name'" );
	}
	$self->{disc_info}->{command_topic} = make_topic( $listen_topic, 'cmnd', 'POWER' );
	$self->{disc_info}->{state_topic} = make_topic( $listen_topic, 'tele', 'STATE' );
	$self->{disc_info}->{state_value_template} = '{{value_json.POWER}}';
	$self->{disc_info}->{brightness_state_topic} = make_topic( $listen_topic, 'tele', 'STATE' );
	$self->{disc_info}->{brightness_value_template} = '{{value_json.Dimmer}}';
	$self->{disc_info}->{brightness_scale} = 100;
	$self->{disc_info}->{brightness_command_topic} = make_topic( $listen_topic, 'cmnd', 'Dimmer' );
	$self->{disc_info}->{on_command_type} = 'brightness';
    } elsif( $base_type eq 'binary_sensor' ) {
	# Motion sensor config as defined here: https://blakadder.com/pir-in-tasmota/
	$self->{disc_info}->{state_topic} = make_topic( $listen_topic, 'tele', 'MOTION' );
	$self->{disc_info}->{payload_on} = 1;
	$self->{disc_info}->{device_class} = $device_class;
	$self->{disc_info}->{force_update} = 'true';
	$self->{disc_info}->{off_delay} = 30;
    } elsif( $base_type eq 'sensor' ) {
	$self->{disc_info}->{state_topic} = make_topic( $listen_topic, 'tele', 'STATE' );
	$self->{disc_info}->{device_class} = $device_class;
	$self->{disc_info}->{force_update} = 'true';
    } else {
	$self->error( "TasmotaItem type '$type' not supported yet" );
	return;
    }
    $self->{disc_info}->{unique_id} = 'tasmota_' . $self->{mqtt_name};
    $self->{disc_info}->{unique_id} =~ s/ /_/g;

    # $self->create_discovery_message();

    # We may need flags to deal with XML, JSON or Text
    return $self;
}

# -[ Fini - mqtt_RemoteItem ]---------------------------------------------------------

# ------------------------------------------------------------------------------

package mqtt_InstMqttItem;

use strict;

use Data::Dumper;

@mqtt_InstMqttItem::ISA = ( 'mqtt_BaseRemoteItem' );


=item C<new(mqtt_interface, name, type, topicpattern, discoverable, friendly_name)>

    Creates a MQTT BaseRemoteItem/object that will mirror the state of the object, and send commands to it.

=cut

sub new {      ### mqtt_InstMqttItem
    my ( $class, $interface, $type, $topicpattern, $discoverable, $friendly_name ) = @_;

    my ($base_type, $device_class) = $type =~ m/^([^:]*):?(.*)$/;

    if( !grep( /$base_type/, ('light','switch','binary_sensor','sensor','scene', 'cover' ) ) ) {
	$interface->error( "Invalid InstMqttItem type '$type'" );
	return;
    }

    my (@topic_parts) = split( "/", $topicpattern );
    my $node_id = $topic_parts[0];
    my $mqtt_name = $topic_parts[1];
    my $topic_prefix = "$node_id/$mqtt_name";
    if( !$mqtt_name ) {
	$interface->error( "Unrecognized topic pattern '$topicpattern' for device '$friendly_name'" );
    }
    my $listen_topic = "$topic_prefix/+"; 

    my $self = new mqtt_BaseRemoteItem( $interface, $mqtt_name, $base_type, $listen_topic, $discoverable );

    return
      if !$self;

    bless $self, $class;

    $self->debug( 1, "New mqtt_InstMqttItem( $interface->{instance}, '$mqtt_name', '$type', '$topicpattern', $discoverable, '$friendly_name' )" );

    $self->{node_id} = $node_id;
    $self->{discovered} = 0;


    $self->{disc_info} = {};
    if( !$friendly_name ) {
	$friendly_name = $self->{mqtt_name};
	$friendly_name =~ s/_/ /g;
    }
    $self->{disc_info}->{name} = $friendly_name;
    if( $base_type eq 'scene' ) {
	$self->{disc_info}->{command_topic} = "$node_id/modem/scene";
	$self->{disc_info}->{optimistic} = 'true';
	$self->{disc_info}->{payload_on} =  "{ \"cmd\" : \"ON\", \"name\" : \"$mqtt_name\" }";
	$self->{disc_info}->{payload_off} =  "{ \"cmd\" : \"OFF\", \"name\" : \"$mqtt_name\" }";
    } else {
	$self->{disc_info}->{state_topic} = "$topic_prefix/state";
	$self->{disc_info}->{command_topic} = "$topic_prefix/set";
	if( $base_type eq 'light' ) {
	    $self->{disc_info}->{command_topic} = "$topic_prefix/level";
	    $self->{disc_info}->{schema} = 'json';
	    $self->{disc_info}->{brightness} = "true";
	    $self->{disc_info}->{brightness_scale} = 100;
	} elsif( $base_type eq 'binary_sensor' ) {
	    $self->{disc_info}->{device_class} = $device_class;
	} elsif( $base_type eq 'sensor' ) {
	    $self->{disc_info}->{device_class} = $device_class;
	}
    }
    $self->{disc_info}->{unique_id} = $self->{mqtt_name};
    $self->{disc_info}->{unique_id} =~ s/ /_/g;

    # $self->create_discovery_message();


    # $self->debug( 1, "InstMqttItem created: \n" . Dumper( $self ) );

    # We may need flags to deal with XML, JSON or Text
    return $self;
}

# -[ Fini - mqtt_InstMqttItem ]---------------------------------------------------------



# -[ Fini ]---------------------------------------------------------------------
1;

