# ------------------------------------------------------------------------------

=begin comment
    @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@

    =head1 B<GarageDoor_Item>


    =head2 SYNOPSIS

    A generic module to attach sensors and relays to control a garage door. Can accept
    two sensors for gaining an opening and closing state, used by some animations

File:
    GarageDoor_Item.pm


Author(s):

    H Plato

Usage:

    $garagedoor        = new GarageDoor_Item($control, $sensor1, [$sensor2]);

    $sensor should return a state of open or closed. If the sensor is an on or off, it can be mapped
    
    $garagedoor->map_state("sensor1", "open", "on");
    $garagedoor->map_state("sensor1", "closed", "off");
    
    Sensor Logic for 2 sensor system:
    
    $sensor1 = open &  $sensor2 = closed                         : state = opening
    $sensor1 = open &  $sensor2 = open                           : state = open
    $sensor1 = open &  $sensor2 = closed & previous state = open : state = closing
    $sensor1 = closed & sensor2 = closed                         : state = closed

    $control is just turned 'on' to toggle a state change. If the actual on/off state needs to be passed
    this can be overridden:
    
    $garagedoor->control_state(1);
     - this will send open or closed to the relay
    
    If the relay needs a different state to activate, it can be mapped. If it's a toggle, this can be set by
    
    $garagedoor->map_state("control", "on", "toggle");

  
Notes:

Issues:

=cut

# ------------------------------------------------------------------------------
package GarageDoor_Item;


@GarageDoor_Item::ISA = ('Generic_Item');


sub new {
    my ( $class, $control, $sensor1, $sensor2 ) = @_;
    my $self = new Generic_Item();
    bless $self, $class;
    $self->{control} = 0;
    $self->{sensor1} = 0;
    $self->{sensor2} = 0;
    $self->{debug}   = 0;
    #Add in a few data elements to make creating a MQTT for HA integration easier
    $self->{mqttlocalitem}->{base_type} = 'cover';
    $self->{mqttlocalitem}->{device_class} = 'garage';
    
    $self->{map}->{sensor1}->{open} = "open";
    $self->{map}->{sensor1}->{closed} = "closed";
    $self->{map}->{sensor2}->{open} = "open";
    $self->{map}->{sensor2}->{closed} = "closed";
    $self->{map}->{control}->{on} = "on";
    
    @{ $$self{states} } = ( 'open', 'closed' );

    if (defined $control) {
        $self->{control_object} = $control;
        $control->{garage_item} = $self;
        $self->{control} = 1;
        $self->{control_state} = 0;
    } else {
        main::print_log( "[GarageDoor] WARNING, no control object specified. Door cannot be opened or closed" );
    }
     if (defined $sensor1) {
        $self->{sensor1_object} = $sensor1;
        $sensor1->{garage_item} = $self;
        $self->{sensor1} = 1;
        $sensor1->tie_event( '&GarageDoor_Item::sensor_event( $object, $state);' );
    } else {
        main::print_log( "[GarageDoor] WARNING, no sensor1 object specified. Door state cannot be determined" );
    }  
     if (defined $sensor2) {
        $self->{sensor2_object} = $sensor2;
        $sensor2->{garage_item} = $self;
        $self->{sensor2} = 1;
        $sensor2->tie_event( '&GarageDoor_Item::sensor_event( $object, $state);' );
    } else {
        main::print_log( "[GarageDoor] INFO, no sensor2 object specified. Door state will be just open and closed" );
    }  


    return $self;
}

sub sensor_event {
    my ($obj, $state) = @_;
    my $self = $obj->{garage_item};
    my $newstate = "";


    if ($self->{sensor2}) {
        if (($self->{sensor1_object}->state() eq $self->{map}->{sensor1}->{open}) and ($self->{sensor2_object}->state() eq $self->{map}->{sensor2}->{open})) {
            $newstate = "open";
        } elsif (( $self->{sensor1_object}->state() eq $self->{map}->{sensor1}->{closed}) and ( $self->{sensor2_object}->state() eq $self->{map}->{sensor2}->{closed})) {
            $newstate = "closed";
            
        } elsif (( $self->{sensor1_object}->state() eq $self->{map}->{sensor1}->{open}) and ( $self->{sensor2_object}->state() eq $self->{map}->{sensor2}->{closed})) {
            if ($self->state() eq "closed") {
                $newstate = "opening";
            } else {
                $newstate = "closing";
            }
        }
    } else {
       $newstate = $self->{sensor1_object}->state(); 
    }
    $self->set($newstate,"sensor") unless ($newstate eq $self->state()); #avoid duplication if a sensor resets
}


sub map_state {
    my ($self, $sensor, $state, $mapped) = @_;

    $self->{map}->{$sensor}->{$state} = "$mapped";
}

sub control_state {
    my ($self, $value) = @_;
    $self->{control_state} = $value;
}


sub set {
    my ( $self, $p_state, $p_setby ) = @_;

    if ( $p_setby eq 'sensor' ) {
        $self->SUPER::set($p_state, "sensor");
    }
    else {
        if ( $self->{control} ) {
            if ( $self->{control_state} ) {
                $self->{control_object}->set($p_state,$p_setby);
            } else {
                 $self->{control_object}->set($self->{map}->{control}->{on},$p_setby);           
            }
        } else { 
            main::print_log( "[GarageDoor] ERROR, set called on garage_door, but no control object assigned" );
        }
    }
}

