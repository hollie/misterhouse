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
use Data::Dumper;
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


    my ($disc_prefix, $disc_type, $realm, $device_id) = $disc_topic =~ m|^(.*)/([^/]*)/([^/]+)/([^/]+)/config$|;
    if( $disc_prefix ) {
	$short_disc_topic = "$disc_type/$realm/$device_id/config";
    } else {
	($disc_prefix, $disc_type, $device_id) = $disc_topic =~ m|^(.*)/([^/]+)/([^/]+)/config$|;
	if( !$disc_prefix ) {
	    $disc_obj->error( "UNRECOGNIZED DISCOVERY MESSAGE -- can't parse: $disc_topic" );
	    return;
	}
	$short_disc_topic = "$disc_type/$device_id/config";
    }

    my $disc_info;
    eval{ $disc_info = decode_json( $disc_msg ) };
    if( !$disc_info ) {
	$disc_obj->error( "UNRECOGNIZED DISCOVERY MESSAGE -- payload not json: $disc_topic -- M:'$disc_msg'" );
	return;
    }

    &mqtt_BaseItem::normalize_discovery_info( $disc_info );

    $disc_obj->debug( 3, "processing discovery message payload:\n" . Dumper($disc_info) );

    # map discovery type to mqtt object type
    if( $disc_type eq 'light' ) {
	if( $disc_info->{schema} eq 'template' ) {
	    $disc_obj->log( "Discovery schema 'template' not supported" );
	    return;
	}
    } elsif( $disc_type eq 'binary_sensor' ) {
    } elsif( $disc_type eq 'sensor' ) {
    } elsif( $disc_type eq 'switch' ) {
    } elsif( $disc_type eq 'multi_switch' ) {
    } else {
	$disc_obj->log( "UNRECOGNIZED DISCOVERY TYPE: $disc_type" );
	return;
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
	$disc_obj->error( "UNRECOGNIZED DISCOVERY MESSAGE -- no topic: $disc_topic -- M:'$disc_msg" );
	return;
    } 

    # Check for objects that already exist -- for example, if they were persisted in a .mht file
    my $found = 0;
    my $unique_id = $disc_info->{unique_id}  ||  $device_id;
    for $obj ( @{ $interface->{objects} } ) {
	if( $obj->{disc_info}->{unique_id} eq $unique_id ) {
	    if( $obj->{local_item} ) {
		$disc_obj->debug( 1, "Ignoring discovery message received for local object: " . $obj->{local_item}->get_object_name );
	    } else {
		if( $short_disc_topic eq $obj->{disc_topic} ) {
		    $disc_obj->debug( 1, "Discovery message received for unique_id:($unique_id) for object that already exists: " . $obj->get_object_name );
		    # Update the discover message so that if discovered items are written out, they get the new ones
		    $obj->{disc_msg} = $disc_msg;
		} else {
		    $disc_obj->error( "Discovery message received for unique_id:$unique_id, but topics don't match" );
		}
	    }
	    $found = 1;
	} elsif( $obj->{disc_info}->{name} eq $disc_info->{name} ) {
	    # Note that Home Assistant matches discovery objects up based on friendly name -- report error on duplicate friendly names
	    $disc_obj->error( "Discovery message received for friendly_name ($disc_info->{name}) that already exists" );
	    $found = 1;
	}
    }
    if( $found ) {
	return;
    }

    # create local MH object
    $obj_name = 'mqttd_';
    if( $realm ) {
	#  $realm helps to identify the device
	$obj_name .= "${realm}_";
    }
    if( $disc_info->{name} ) {
	$obj_name .= $disc_info->{name};
    } else {
	$obj_name .= $device_id;
    }
    $obj_name =~ s/ /_/g;
    $obj = ::get_object_by_name( $obj_name );
    if( $obj ) {
	$disc_obj->error( "Trying to create object that already exists: $obj_name" );
	return;
    } 

    $self = new mqtt_BaseRemoteItem( $interface, $obj_name, $disc_type, \@listentopics, 0 );

    bless $self, $class;

    $self->{disc_info}	= $disc_info;
    $self->{disc_topic} = $short_disc_topic;
    $self->{disc_prefix} = $disc_prefix;
    $self->{disc_msg}	= $disc_msg;
    $self->{disc_obj}	= $disc_obj;
    $self->{discovered} = 1;

    $obj_name = $disc_obj->get_object_name;
    $self->debug( 1, "New mqtt_DiscoveredItem( $obj_name, '$name', '$disc_topic', '$disc_msg' )" );

    my $d = Data::Dumper->new( [$self] );
    $d->Maxdepth( 3 );
    $self->debug( 3, "DiscoveryItem created: \n" . $d->Dump );

    # We may need flags to deal with XML, JSON or Text
    return $self;
}


# -[ Fini - mqtt_DiscoveredItem ]---------------------------------------------------------

# ------------------------------------------------------------------------------

package mqtt_Discovery;

use strict;

use JSON qw( decode_json encode_json );   
use Data::Dumper;

my $discovered_items_filename;

=item C<new(name, mqtt_interface, topic, retain, qos)>

    Creates a MQTT Discovery object that will handle mqtt discovery messages and create local objects.
    Then use class function write_discovered_items to write them out to a .mht file.
    Use publish_discovery_data to publish MQTT discovery messages for all discoverable items.

=cut

sub new {  ### mqtt_Discovery
    my ( $class, $interface, $name, $discovery_topic ) = @_;

    my $self = {};

    bless $self, $class;

    # $self->{debug} = 3;

    $self->{interface}	    = $interface;
    $self->{object_name}    = $name;
    $self->{mqtt_type}	    = 'discovery';
    $self->{discoverable}   = 0;
    $self->{discovery_topic} = $discovery_topic;
    $self->{topic}	    = "${discovery_topic}/#";

    if( $self->{interface} ) {
	$self->{interface}->add( $self );
    } else {
	foreach $interface ( &mqtt::get_interface_list() ) {
	    $interface->add( $self );
	}
    }

    $self->debug( 1, "New mqtt_Discovery( $interface->{instance}, '$name', '$discovery_topic' )" );

    return $self;
}

sub get_object_name {
    my( $self ) = @_;
    return $self->{object_name};
}

sub log {
    my( $self, $str ) = @_;
    &main::print_log( 'MQTTDisc: '. $str );
}

sub error {
    my( $self, $str ) = @_;
    &main::print_log( "MQTTDisc ERROR: $str" );
}

sub debug {
    my( $self, $level, $str ) = @_;
    my $objname;
    $objname = lc $self->get_object_name() if $self;
    if( $main::Debug{'mqtt'} >= $level  ||  ($objname && $main::Debug{$objname} >= $level) ) {
	&main::print_log( "MQTTDisc D$level: $str" );
    }
}

sub set_object_debug {
    my( $self, $level ) = @_;
    my $objname = lc $self->get_object_name();
    $level = 1 if !defined $level;
    $main::Debug{$objname} = $level;
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
	&main::register_object_by_name("\$$obj_name",$obj);
	if( $discovered_items_filename ) {
	    &write_discovered_items( $discovered_items_filename );
	}
    }
}


######
# These next subs could be in the mqtt class... but I wanted to keep the discovery functions together
######


=item C<write_discovered_items(filename, autoupdate)>

    Writes out all mqtt items that have been discovered to a .mqt file.
    Note that this includes items that were created locally as discovered
    items in a .mht file as well as newly discovered items.
    If autoupdate is true, the file will be updated with each new discovery message.

=cut

sub write_discovered_items {
    my ($outfilename, $autoupdate) = @_;
    my $interface;
    my $f;
    my @sorted_list;
    
    &debug( undef, 1, "Writing discovered items to '$outfilename'" );
    if( defined $autoupdate ) {
	if( $autoupdate ) {
	    $discovered_items_filename = $outfilename;
	} else {
	    $discovered_items_filename = undef;
	}
    }
    if( !open( $f, "> ${outfilename}" ) ) {
	&mqtt::error( "Unable to open discovery target file '${outfilename}" );
	return;
    }
    print {$f} "Format = A\n\n";
    foreach my $interface ( &mqtt::get_interface_list() ) {
	@sorted_list = sort { $a->get_object_name() cmp $b->get_object_name() } @{$interface->{objects}};
	for my $obj ( @sorted_list ) {
	    if( $obj->{discovered} ) {
		my $obj_name = $obj->get_object_name;
		my $disc_obj_name = $obj->{disc_obj}->get_object_name;
		my $disc_topic = "$obj->{disc_prefix}/$obj->{disc_topic}";
		$obj_name =~ s/^\$//;
		$disc_obj_name =~ s/^\$//;
		print {$f} "MQTT_DISCOVEREDITEM, $obj_name, $disc_obj_name, $disc_topic, $obj->{disc_msg}\n";
	    }
	}
    }
    close( $f );
}

=item C<(publish_discovery_data())>
=cut

sub publish_discovery_data {
    my ($self) = @_;
    my $obj;
    my $interface;
    my $topic;
    my $msg;

    $interface = $self->{interface};
    if( !$interface->isConnected ) {
	$self->error( "Unable to publish discovery data -- $interface->{instance} not connected" );
	return 0;
    }
    $self->log( "Publishing discovery data" );
    for my $obj ( @{ $$interface{objects} } ) {
	if( !$obj->{discoverable} ) {
	    $self->debug( 1, "Non-discoverable object skipped: ".  $obj->get_object_name );
	} else {
	    my ($topic, $msg) = ($obj->{disc_topic}, $obj->{disc_msg});
            if( $topic ) {
		$topic = "$self->{discovery_topic}/$topic";
		$self->debug( 1, "Publishing discovery message T:'$topic'   M:'$msg'" );
		$obj->transmit_mqtt_message( $topic, $msg, 1 );
	    }
	}
    }
    return 1;
}


# -[ Fini - mqtt_Discovery ]---------------------------------------------------------

# -[ Fini ]---------------------------------------------------------------------
1;

