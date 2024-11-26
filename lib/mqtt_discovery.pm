# ------------------------------------------------------------------------------

=begin comment
    @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@

    =head1 B<mqtt_Discovery> B<mqtt_DiscoveredItem>

    Dave Neudoerffer <dave@neudoerffer.com>

    =head2 SYNOPSIS

    An MQTT discover module for Misterhouse.
    Full documentation in mqtt_items.pm.

    Uses existing interface class in mqtt.pm.
    Uses mqtt_BaseRemoteItem from mqtt_items.pm.
    It does not use the mqtt_Item class in mqtt.pm.

    =head2 DESCRIPTION

    Misterhouse MQTT discovery for use with many MQTT services.

    MQTT website: http://mqtt.org/
    MQTT Test service: http//test.mosquitto.org/ (test.mosquitto.org port 1883)

File:
    mqtt_Discovery.pm

Description:
    Author(s):
    Dave Neudoerffer <dave@neudoerffer.com>

    See mqtt_items.pm for full documentation.

License:
    This free software is licensed under the terms of the GNU public license.

Usage:

Notes:
    @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@

=cut

# ------------------------------------------------------------------------------
# ------------------------------------------------------------------------------

package mqtt_DiscoveredItem;

use strict;

use JSON qw( decode_json encode_json );   
use mqtt_items;

@mqtt_DiscoveredItem::ISA = ( 'mqtt_BaseRemoteItem' );


=item C<new(mqtt_discovery_object, name, discovery_topic, discovery_msg)>

    Crease a mqtt_BaseRemoteItem based on the discovery_topic and discovery_msg

=cut

sub new {   #### mqtt_DiscoveredItem
    my ( $class, $disc_obj, $name, $disc_topic, $disc_msg ) = @_;
    my $obj;
    my $obj_name;
    my $interface = $disc_obj->{interface};
    my $device_name;
    my $self;
    my $short_disc_topic;
    my $mqtt_type;
    my $disc_prefix;
    my $disc_type;
    my $node_id;
    my $device_id;


    if( $disc_topic =~ m|.*/.*| ) {
	($disc_prefix, $disc_type, $node_id, $device_id) = $disc_topic =~ m|^(.*)/([^/]*)/([^/]+)/([^/]+)/config$|;
	if( $disc_prefix ) {
	    $short_disc_topic = "$disc_type/$node_id/$device_id/config";
	} else {
	    ($disc_prefix, $disc_type, $device_id) = $disc_topic =~ m|^(.*)/([^/]+)/([^/]+)/config$|;
	    if( !$disc_prefix ) {
		$disc_obj->error( "UNRECOGNIZED DISCOVERY MESSAGE -- can't parse: $disc_topic" );
		return;
	    }
	    $short_disc_topic = "$disc_type/$device_id/config";
	}
    } elsif( $disc_topic ) {
	$disc_type = $disc_topic;
	$short_disc_topic = '';
    } else {
	$disc_obj->error( "UNRECOGNIZED DISCOVERY MESSAGE -- discovery topic not valid: $disc_topic" );
	return;
    }

    my $disc_info;
    eval{ $disc_info = decode_json( $disc_msg ) };
    if( !$disc_info ) {
	$disc_obj->error( "UNRECOGNIZED DISCOVERY MESSAGE -- payload not json: $disc_topic -- M:'$disc_msg'" );
	return;
    }

    &mqtt_BaseItem::normalize_discovery_info( $disc_info );

    $disc_obj->debug( 3, "processing discovery message payload:\n" . &mqtt_BaseItem::dump( undef, $disc_info, 3 ) );

    # map discovery type to mqtt object type
    if( $disc_type eq 'light' ) {
	if( $disc_info->{schema} eq 'template' ) {
	    $disc_obj->log( "Discovery schema 'template' not supported for mqtt light $disc_info->{name}" );
	} else {
	    $mqtt_type = $disc_type;
	}
    } elsif( grep( /^${disc_type}$/, ('light', 'switch', 'binary_sensor', 'sensor', 'scene', 'select', 'text', 'number') ) ) {
	$mqtt_type = $disc_type;
    } else {
	$disc_obj->debug( 1, "UNRECOGNIZED DISCOVERY TYPE: $disc_type" );
    }

    # Set the listentopics list to all discovery parms that end with _topic
    #
    my @listentopics = ();
    foreach my $disc_parm ( keys %{$disc_info} ) {
	if( $disc_parm =~ /^.*_topic$/ ) {
	    push @listentopics, $disc_info->{$disc_parm};
	}
    }
    if( $#listentopics < 0 ) {
	$disc_obj->error( "UNRECOGNIZED DISCOVERY MESSAGE -- no listen topic: M:'$disc_msg" );
	return;
    } 

    # Check for objects that already exist -- for example, if they were persisted in a .mht file
    my $found = 0;
    my $unique_id = $disc_info->{unique_id}  ||  $device_id;
    for $obj ( @{ $interface->{objects} } ) {
	if( $obj->{disc_info}->{unique_id} eq $unique_id ) {
	    if( $obj->{is_local} ) {
		$disc_obj->debug( 1, "Ignoring discovery message received for local object: " . $obj->{local_item}->get_object_name );
	    } else {
		if( !$obj->{disc_topic} ) {
		    # object explicitly declared
		    $disc_obj->debug( 1, "Discovery message received for unique_id:($unique_id) for object that was explicitly created: " . $obj->get_object_name );
		} else {
		    $disc_obj->debug( 1, "Discovery message received for unique_id:($unique_id) for object that already exists: " . $obj->get_object_name );
		    # Update the discover message so that if discovered items are written out, they get the new ones
		    $obj->{disc_msg} = $disc_msg;
		    $obj->{disc_topic} = $short_disc_topic;
		}
	    }
	    $found = 1;
	} else {
	    my $attr;
	    if( $disc_info->{name} ) {
		$attr = 'name';
	    } else {
		$attr = 'object_id';
	    }
	    if( $obj->{disc_info}->{$attr} eq $disc_info->{$attr} ) {
		$found = 1;
		if( $obj->{discoverable}  ||  $obj->{mqtt_dynamic} ) {
		    # Note that Home Assistant matches discovery objects up based on friendly name -- report error on duplicate friendly names
		    $disc_obj->error( "Discovery message received for friendly_name ($disc_info->{$attr}) that already exists" );
		} else {
		    $disc_obj->debug( 1, "Discovery message received for friendly_name ($disc_info->{$attr}) that has already been locally declared -- ignoring" );
		}
	    }
	}
    }
    if( $found ) {
	return;
    }

    # create local MH object
    $obj_name = 'mqttd_';
    if( $node_id ) {
	#  $node_id helps to identify the device
	$obj_name .= "${node_id}_";
    }
    if( $disc_info->{name} ) {
	$obj_name .= $disc_info->{name};
    } else {
	$obj_name .= $device_id;
    }
    $obj_name =~ s/[^\w]/_/g;
    $obj = ::get_object_by_name( $obj_name );
    if( $obj ) {
	$disc_obj->error( "Trying to create object that already exists: $obj_name" );
	return;
    } 

    # If we don't support the type, don't listen for changes
    if( !$mqtt_type ) {
	@listentopics = ();
    }

    $self = new mqtt_BaseRemoteItem( $interface, $obj_name, $disc_type, \@listentopics, 0 );

    bless $self, $class;

    $self->{disc_info}	= $disc_info;
    $self->{disc_topic} = $short_disc_topic;
    $self->{disc_prefix} = $disc_prefix;
    $self->{disc_msg}	= $disc_msg;
    $self->{disc_obj}	= $disc_obj;
    if( $short_disc_topic ) {
	$self->{discovered} = 1;
    } else {
	$self->{discovered} = 0;
    }

    $self->debug( 1, "New mqtt_DiscoveredItem( \$$disc_obj->{mqtt_name}, '$name', '$disc_topic', '$disc_msg' )" );

    $self->debug( 3, "DiscoveryItem created: \n" . $self->dump( $self, 3 ) );

    # We may need flags to deal with XML, JSON or Text
    return $self;
}


# -[ Fini - mqtt_DiscoveredItem ]---------------------------------------------------------

# ------------------------------------------------------------------------------

package mqtt_Discovery;

use strict;

use JSON qw( decode_json encode_json );   

@mqtt_Discovery::ISA = ( 'mqtt_BaseItem' );

=item C<new(mqtt_interface, name, discovery_topic, create_discovered_objs)>

    Creates a MQTT Discovery object that will handle mqtt discovery messages and create local objects.
    Then use class function write_discovered_items to write them out to a .mht file.

=cut

sub new {  ### mqtt_Discovery
    my ( $class, $interface, $name, $discovery_prefix, $action ) = @_;

    if( $discovery_prefix  &&  !$action ) {
	$action = 'both';
    }
    if( !$interface ) {
	&mqtt::error( undef, "mqtt_Discovery must specify interface" );
    }
    if( !grep( /^${action}$/, ('publish', 'subscribe', 'both', 'none') ) ) {
	$interface->error( "Invalid discovery action specified '$action'" );
    }

    $interface->debug( 1, "New mqtt_Discovery( $interface->{instance}, '$name', '$discovery_prefix', '$action' )" );

    my $listentopics = [];
    if( $action eq 'publish'  ||  $action eq 'both' ) {
	$interface->{discovery_publish_prefix} = $discovery_prefix;
    }
    if( $action eq 'subscribe'  ||  $action eq 'both' ) {
	$listentopics = "${discovery_prefix}/#";
    }

    my $self = new mqtt_BaseItem( $interface, $name, 'discovery', $listentopics, 0 );

    bless $self, $class;

    return $self;
}

=item C<receive_mqtt_message( mqtt_topic, mqtt_message, mqtt_retained)>
=cut

sub receive_mqtt_message {
    my ( $self, $mqtt_topic, $mqtt_msg, $mqtt_retained ) = @_;
    my $obj_name;
    my $obj;
    my $interface = $self->{interface};

    if( !$mqtt_msg ) {
	$self->debug( 2, "INGNORING DISCOVERY CLEAN MESSAGE: $mqtt_topic -- M:'$mqtt_msg'" );
	return;
    }

    $obj = new mqtt_DiscoveredItem( $self, undef, $mqtt_topic, $mqtt_msg );

    if( $obj ) {
	my $obj_name = $obj->{mqtt_name};
	$obj->{category} = "MQTT Discovered Items";
	$obj->{filename} = "mqtt_discovery";
	$obj->{object_name} = "\$$obj_name";
	$obj->{mqtt_dynamic} = 1;
	&main::register_object_by_name("\$$obj_name",$obj);
	&mqtt::write_discovered_items();     # incase of autoupdate on the discovered items file
    }
}


########################################################################
# These next subs have been moved to mqtt class...
# Stubs are left here for backwards compatibility
########################################################################


sub write_discovered_items {
    my ($outfilename, $autoupdate) = @_;

    &mqtt::write_discovered_items( $outfilename, $autoupdate );
}

sub publish_discovery_data {
    my ($self) = @_;

    return $self->{interface}->publish_discovery_data();
}



# -[ Fini - mqtt_Discovery ]---------------------------------------------------------

# -[ Fini ]---------------------------------------------------------------------
1;

