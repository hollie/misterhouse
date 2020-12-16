
=begin comment

Tasmota_HTTP_Item.pm

Basic Tasmota support using the HTTP interface rather than MQTT
Copyright (C) 2020 Jeff Siddall (jeff@siddall.name)
Last modified: 2020-12-15

This module currently supports Tasmota switch type devices but other devices
can be added with extra packages added

Requirements:

  The Tasmota device needs to be setup with a rule to send HTTP requests to MH
  if two-way communication is desired.  For example, a Sonoff Mini switch input
  can be sent to MH with the rule:
  Rule1 ON Power1#State DO WebSend [192.168.0.1:80] /SET;none?select_item=Kitchen_Light&select_state=%value% ENDON

Setup:

In your code define Tasmota_HTTP::Things in an MHT:

  TASMOTA_HTTP_SWITCH,   192.168.x.y,   Kitchen_Light,    Kitchen

Or in a code file:

 $Kitchen_Light = new Tasmota_HTTP::Switch("192.168.x.y");
 Where:
   192.168.x.y is the IPv4 address or hostname of the Tasmota device

 $Kitchen_Light->set(ON);

=cut

#=======================================================================================
#
# Generic Tasmota_HTTP::Item
#
#=======================================================================================

# The Tasmota_HTTP::Item is a base item for other real devices (see below)

package Tasmota_HTTP::Item;
use strict;
use parent 'Generic_Item';

# Item class constructor
sub new {
    my ( $class, $address ) = @_;

    # Call the parent class constructor to make sure all the important things are done
    my $self = new Generic_Item();
    bless $self, $class;

    # Additional Tasmota variables
    $self->{address}     = $address;
    $self->{output_name} = 'POWER1';
    $self->{ack}         = 0;
    $self->{last_http_status};

    return $self;
}

# Use HTTP get calls to set the Tasmota item, being sure to check that the set did not come
# from the device itself
sub set {
    my ( $self, $state, $set_by, $respond ) = @_;

    # Debug logging
    my $debug = $self->{debug} || $main::Debug{tasmota};

    # Determine whether the update came from the Tasmota device itself and convert states
    # and record the set as an ack
    if ( $set_by eq "web [$self->{address}]" ) {

        # Convert Tasmota states to MH states
        $state = $self->{tasmota_to_state}{$state};

        # If the current state is the same as the received state, and ack=0 then consider
        # this set an ack and do not update the state of the item
        if ( ( $state eq $self->{state} ) && ( $self->{ack} == 0 ) ) {
            &main::print_log("[Tasmota_HTTP::Item] DEBUG: Received ack from $self->{object_name} ($self->{address})") if $debug;
            $self->{ack} = 1;
        }
        else {
            &main::print_log("[Tasmota_HTTP::Item] DEBUG: Received set state to $state from $self->{object_name} ($self->{address})") if $debug;

            # Call the parent class set to make sure all the important things are done
            $self->SUPER::set( $state, $set_by, $respond );
        }

        # Only send an update to the device if the set did not come from the device to prevent
        # set loops
    }
    else {
        use LWP::UserAgent ();

        # Use a small timeout since devices are typically local and should respond quickly
        # 5 seconds should allow for 3 syn attempts plus another second to get a response
        my $ua = LWP::UserAgent->new( timeout => 5 );

        # Reset the ack flag
        $self->{ack} = 0;

        # Send the HTTP request
        my $response = $ua->get("http://$self->{address}/cm?cmnd=$self->{output_name}%20$self->{state_to_tasmota}{$state}");

        # Record the status of the last request
        $self->{last_http_status} = $response->status_line;

        # Log request failures
        if ( !$response->is_success ) {
            &main::print_log("[Tasmota_HTTP::Item] ERROR: Received HTTP response code $self->{last_http_status} from last command)");
        }

        # Call the parent class set to make sure all the important things are done
        $self->SUPER::set( $state, $set_by, $respond );
        &main::print_log("[Tasmota_HTTP::Item] DEBUG: Set $self->{object_name} state to $state") if $debug;
    }
}

#=======================================================================================
#
# Basic Tasmota_HTTP::Switch
#
#=======================================================================================

# To add table support, add these lines to the read_table_A.pl file:
# elsif ( $type eq "TASMOTA_HTTP_SWITCH" ) {
#     require Tasmota_HTTP_Item;
#     ( $address, $name, $grouplist ) = @item_info;
#     $object = "Tasmota_HTTP::Switch('$address')";
# }

package Tasmota_HTTP::Switch;
use strict;
use parent-norequire, 'Tasmota_HTTP::Item';

# Switch class constructor
sub new {
    my $class = shift;

    # Call the parent class constructor to make sure all the important things are done
    my $self = $class->SUPER::new(@_);

    # Additional switch variables
    # Add additional hash pairs (rows) to this variable to send other states to devices
    $self->{state_to_tasmota} = {
        "off" => "0",
        "on"  => "1",
    };

    # Add additional hash pairs (rows) to this variable to use other states from devices
    $self->{tasmota_to_state} = {
        "0" => "off",
        "1" => "on",
    };

    # Initialize states
    push( @{ $self->{states} }, keys( %{ $self->{state_to_tasmota} } ) );

    # Log the setup of the item
    &main::print_log("[Tasmota_HTTP::Switch] Created item with address $self->{address}");

    return $self;
}

# Perl modules need to return true
1;
