
=begin comment
@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@

xPL_Plugwise.pm - xPL support for the xPL Plugwise schema

Info:

 xPL-perl website:
   http://www.xpl-perl.org.uk/ by Beanz
   
 xPL-plugwise module:
   Originally written by Jfn (http://www.domoticaforum.eu/topic.asp?TOPIC_ID=2939)
   
   Until Jfn adds the required updates to the code or Beanz adds the code to xpl-perl
   a modified copy of the code that works together with this module can be found here:
     https://hasy.googlecode.com/svn/trunk/misterhouse/xplplugwise
     
Usage:

 In your items.mht, add the plugwise gateway and plugwise items like this:
 
   XPL_PLUGWISEGATEWAY, bnz-plugwise.servername, plugwise_gateway, Gateways
   XPL_PLUGWISE, 469ABC, desklight, plugwise_gateway, Lights

 Then in your code do something like:
   
   # Request the state of the plugwise devices
   if ($Reload) {
     $plugwise_gateway->request_stat();
   }
   
   # Switch on the desklight if it is getting dark
   if (<condition_that_needs_to_be_met>) {
     $desklight->set("ON");
   }

Todo:

  * Let an experience misterhouse coder review the module
  * Add support for parsing the power consumption reports from the circles
  * Add support for auto_set_on, so that a circle is only enabled once if e.g. 
    it is dark outside. This would mean that the circle can be enabled when it's 
    getting dark, but that it stays off if the user switches it off while it is still
    dark.
  * Cleanup xPL_PlugwiseGateway code, it still contains remainders of 
    the xPL_LightinGateway code
  * When all code is cleaned up and tested, mail it to the mhouse list for inclusion SVN
    
License:
  This free software is licensed under the terms of the GNU public license.

Authors:
  Lieven Hollevoet  lieven@lika.be

Credits:
  This code is heavily based on the xPL_Lighting module by 
   Gregg Liming   gregg@limings.net

@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
=cut

use strict;

package xPL_PlugwiseGateway;

@xPL_PlugwiseGateway::ISA = ('xPL_Item');

sub new {
    my ( $class, $source ) = @_;
    my $self = $class->SUPER::new($source);
    $self->SUPER::class_name('plugwise.*');
    @{ $$self{'valve_id_list'} } = ();
    @{ $$self{'queue_id_list'} } = ();
    $self->restore_data('preferred_network_id');    # keep track

    return $self;
}

sub preferred_network_id {
    my ($self) = @_;
    return $$self{preferred_network_id};
}

sub device_id_list {
    my ($self) = @_;
    return @{ $$self{device_id_list} };
}

sub request_stat {
    my ($self) = @_;

    for my $circle ( $self->find_members('xPL_Plugwise') ) {
        if ($circle) {
            my $name = $circle->get_object_name();
            &::print_log(
                "[xPL_PlugwiseGateway] Requesting state for $name over xPL")
              if $main::Debug{xpl_plugwise};
            $circle->request_stat();

            #sleep(1);
        }
    }
}

# Not sure what to do with this sub, as the gateway is merely a collector for the device ID's
sub default_setstate {
    my ( $self, $state, $substate, $set_by ) = @_;
    if ( $set_by =~ /^xpl/i ) {
    }
    else {
        &::print_log(
            "[xPL_PlugwiseGateway] WARN: Gateway state may not be explicitely set.  Ignoring."
        ) if $main::Debug{xpl_plugwise};

        # return a -1 if not changed by xpl so that state is not revised until receipt of gateinfo
        return -1;
    }
}

# Basically, ignore all messages directed to the gateway
sub ignore_message {
    my ( $self, $p_data ) = @_;
    my $ignore_message = 1;

    # Might add a filter here if required

    return $ignore_message;
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

    if ( ref $$self{objects} ) {
        foreach ( @{ $$self{objects} } ) {

            #        $_->untie_items($self);
        }
    }
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

                #           $p_object->untie_items($self);
                return 1;
            }
        }
    }
    return 0;
}

sub is_member {
    my ( $self, $p_object ) = @_;

    my @l_objects = @{ $$self{objects} };
    for my $l_object (@l_objects) {
        if ( $l_object eq $p_object ) {
            return 1;
        }
    }
    return 0;
}

sub find_members {
    my ( $self, $p_type ) = @_;

    my @l_found;
    my @l_objects = @{ $$self{objects} };
    for my $l_object (@l_objects) {
        if ( $l_object->isa($p_type) ) {
            push @l_found, $l_object;
        }
    }
    return @l_found;
}

package xPL_Plugwise;

@xPL_Plugwise::ISA = ('xPL_Item');

sub new {
    my ( $class, $id, $gateway ) = @_;
    my $self = $class->SUPER::new( $gateway->source );
    $$self{gateway} = $gateway;
    $gateway->add_item_if_not_present($self);
    $self->SUPER::class_name('plugwise.bas*');
    $$self{id}            = $id;
    $$self{state_monitor} = "plugwise.basic : onoff";
    $self->SUPER::device_monitor("device=$id") if $id;

    # remap the state values to on and off
    $self->tie_value_convertor( 'level',
        '($section =~ /^plugwise.basic/ and $value eq "off") ? "off" : "$value"'
    );

    $self->addStates( 'on', 'off' );

    return $self;
}

sub request_stat {
    my ($self) = @_;
    $self->SUPER::send_cmnd( 'plugwise.basic' => { 'command' => 'status' } );
}

sub id {
    my ($self) = @_;
    return $$self{id};
}

sub addStates {
    my $self = shift;
    push( @{ $$self{states} }, @_ ) unless $self->{displayonly};
}

sub ignore_message {
    my ( $self, $p_data ) = @_;
    my $ignore_msg = 0;
    if (
        !(
            (
                defined( $$p_data{'plugwise.basic'} )
                and $$p_data{'plugwise.basic'}{'device'} eq $self->id
            )
        )
      )
    {
        $ignore_msg = 1;
    }
    return $ignore_msg;
}

sub default_setstate {
    my ( $self, $state, $substate, $set_by ) = @_;

    #&::print_log("[xPL_Plugwise] setstate: $state");

    if ( $set_by =~ /^xpl/i ) {
        if ( $$self{changed} =~ /plugwise\.basic/ ) {
            &::print_log( "[xPL_Plugwise] "
                  . $self->get_object_name
                  . " state is $state" )
              if $main::Debug{xpl_plugwise};

            # TO-DO: process all of the other pertinent attributes available
            return -1
              if $self->state eq
              $state;    # don't propagate state unless it has changed
        }
    }
    else {

        my $cmnd = ( $state =~ /^off/i ) ? 'off' : 'on';

        return -1
          if ( $self->state eq $state )
          ;              # Don't propagate state unless it has changed.
        &::print_log( "[xPL_Plugwise] Request "
              . $self->get_object_name
              . " turn "
              . $cmnd )
          if $main::Debug{xpl_plugwise};
        my $cmd_block;
        $$cmd_block{'command'} = $cmnd;
        $$cmd_block{'device'}  = $self->id;
        $self->SUPER::send_cmnd( 'plugwise.basic', $cmd_block );
        return;
    }

}

1;
