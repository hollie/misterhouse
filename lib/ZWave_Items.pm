
=begin comment

From David Satterfield <david_misterhouse@yahoo.com>

ZWave Interface for Leviton RZC0P serial interface

This module was shamelessly adapted from all the existing code
Thanks for the starting point everybody.

Use these mh.ini parameters to enable this code:
ZWave_RZC0P_serial_port = /dev/ttyS6

Then add an entry to your .mht file like this:

 Item Type    Zwave ID   name   groups  interface polling_interval 2way(1 or 0) resume_level (if dimmer)

The def below is a dimmer,  id is 4, group All_Lights, interface of ZWave_RZC0P,
poll interval of 30 seconds, says it is 2way, and resume to 76%
ZWAVE_LIGHT,  004,        office_lamp, All_Lights, ZWave_RZC0P, 30, 1, 76

This def is a switch example, id 1, group All_Switches, interface of ZWave_RZC0P,
poll interval of 7 seconds, not 2way. No resume level because switches are on/off only.
ZWAVE_APPLIANCE, 001, den_light5, All_Switches, ZWave_RZC0P, 7,0

=cut

package ZWave_Item;
@ZWave_Item::ISA = ('Generic_Item');

my %items_by_id;

sub set {
    my ( $self, $state, $set_by ) = @_;

    my $set_enter_time = &::gettimeofday();    # track the time in sub
    &::print_log(
        "ZWave_Item: Setting $self->{object_name} to $state, time=$set_enter_time"
    );
    return if &main::check_for_tied_filters( $self, $state );

    $self->{set_by} = $set_by;

    #    print "self:$self id:$self->{zwave_id} state:$state setby:$set_by\n";
    $self->processSetData($state);

    my $set_exit_time = &::gettimeofday();
    my $set_time      = $set_exit_time - $set_enter_time;

    #    if ($set_time > 2) { &report("Was in Zwave Set Routine for $set_time seconds\n",1); }
    #    &::print_log("Was in Zwave Set Routine for $set_time seconds, sb:$setby name:$self->{object_name}, state:$state");

    $self->SUPER::set( $state, $set_by );

}

# this really is just a stub right now... doesn't know how to deal
# with anything but Leviton interface
sub set_interface {
    my ( $self, $interface, $id, $type ) = @_;
    if ( !$interface_created ) {
        $zwave_rzc0p_interface = new ZWave_RZC0P;
        $interface_created     = 1;
    }

    $self->{interface} = $zwave_rzc0p_interface;

    # register the item with the interface
    $zwave_rzc0p_interface->add_id($self);
}

# used to add states
sub add {
    my ( $self, $id, $state ) = @_;

    $state = $id unless defined $state;
    $$self{state_by_id}{$id}    = $state if defined $id;
    $$self{id_by_state}{$state} = $id    if defined $state;

    push( @{ $$self{states} }, $state );
    push( @{ $items_by_id{$id} }, $self ) if $id;
}

# This returns current brightness level
sub level {
    return $_[0]->{level};
}

sub mode {
    return $_[0]->{mode};
}

sub toggle_mode {
    my ( $self, $state, $setby ) = @_;
    if ( $self->{mode} =~ 'manual' ) {
        print "mode is manual, changing to auto\n";
        $_[0]->{mode} = 'auto';
    }

    elsif ( $state eq 'on' ) {
        print "mode is auto, changing to manual_on\n";
        $_[0]->{mode} = 'manual_on';
    }

    elsif ( $state eq 'off' ) {
        print "mode is auto, changing to manual_off\n";
        $_[0]->{mode} = 'manual_off';
    }

    else {
        print "mode is $mode, state is $state, don't know what to do\n";
    }

    return $_[0]->{mode};
}

sub set_mode {
    print "got here set mode\n";
    my ( $self, $mode, $set_by ) = @_;

    &::print_log("ZWave_Item: Setting Mode of $self->{object_name} to $mode");

    $self->{mode_set_by} = $set_by;

    $self->SUPER::set_mode( $mode, $set_by );

    return $_[0]->{mode};
}

sub desired_level {

    #    print "desired level is $_[0]->{desired_level}\n";
    return $_[0]->{desired_level};
}

sub desired_state {

    #    print "desired state is $_[0]->{desired_state}\n";
    return $_[0]->{desired_state};
}

# This returns the type variable
sub type {
    return $_[0]->{type};
}

# This sets the resume level for an ON command
sub set_resume {
    my ( $self, $resume ) = @_;
    $self->{resume} = $resume;
}

# this sub converts a level from 0-255 to a state
# 0 = off
# 99 or greater = on
# 1-98 = dim
sub level_to_state {

    my ( $self, $level ) = @_;

    #    print "level to state: level is $level\n";

    &::print_log("ZWave_Items: level is not a number") unless $level =~ /^\d+$/;

    my $state;
    $state = 'off' if ( $level == 0 );
    $state = 'dim' if ( $level > 0 );
    $state = 'on'  if ( $level >= 99 );

    #    print "level_to_state: converted state is $state, level was $level\n";
    return $state;
}

sub update_item_state {
    my ( $self, $level ) = @_;

    #    &::print_log("Update item state: update $self->{zwave_id} to level $level");
    #    &::print_log("Update item state: set_pend:$self->{set_pending}, bp_pend:$self->{button_press_pending}");

    $id = $self->{zwave_id};

    my $old_level = $self->{level};
    my $old_state = $self->{state};

    &::print_log("Error?: old level is invalid???\n")
      if ( not defined $old_level and !$::Startup );
    &::print_log("Error?: old state is invalid???\n")
      if ( not defined $old_state and !$::Startup );

    # if we have a set and no manual activity
    if ( $self->{set_pending} ) {
        if ( ( !( $level == $self->{desired_level} ) )
            and !$self->{button_press_pending} )
        {
            &::print_log(
                "ERROR: got a level for $self->{object_name} that is not what was set. Got $level wanted $self->{desired_level}\n\n"
            );
            $self->{bad_sets}++;
            $self->{set_pending} = 0;
        }
        else {
            #	    &::print_log( "Yahoo: got a level that is what was set. Got $level wanted $self->{desired_level}\n");
            $self->{set_pending} = 0;
        }
    }    # set pending

    if ( !( $level == $old_level ) || ( not defined $old_level ) ) {

        #	&::print_log ("ZWave Item: Update to level needed, changing $id from $old_level to $level");

        $self->{level} = $level;
        $self->{state} = $self->level_to_state($level);
    }

    # set the desired state/level to the returned state on a restart
    $self->{desired_state} = $self->{state}
      if ( not defined $self->{desired_state} );
    $self->{desired_level} = $self->{level}
      if ( not defined $self->{desired_level} );
    $self->{last_update_time} = &::gettimeofday();
    $self->{update_adjust}    = 0;                   # clear any adjusts

    # if button pushed, go to manual mode
    if ( $self->{button_press_pending} ) {

        my $mode;
        $mode = 'manual_on'  if ( $level >= 99 );
        $mode = 'manual_dim' if ( ( $level < 99 ) and ( $level != 0 ) );
        $mode = 'manual_off' if ( $level == 0 );

        $self->set_mode( $mode, 'button_press' );

        $self->{manual_time} = &::gettimeofday();

        &::print_log("Set to mode $mode, level was $level");
        $self->{desired_state} = $self->{state};
        $self->{desired_level} = $self->{level};

        #call set
        &::print_log("calling set with $self->{desired_state}");
        $self->SUPER::set( $self->{state}, 'update' );

        $self->{button_press_pending} = 0;
    }

}

package ZWave_Light_Item;

#use strict;
use Light_Item;

@ZWave_Light_Item::ISA = ('ZWave_Item');

my $interface_created = 0;

sub new {
    my ( $class, $id, $interface, $update_rate, $instant_update, $resume ) = @_;

    #    print "id:$id if:$interface ur:$update_rate\n";

    my $self = $class->Generic_Item::new();

    bless $self, $class;

    $interface = 'RZC0P' unless defined $interface;
    my $type = 'ZWAVE_LIGHT';
    $update_rate = '5' unless defined $update_rate;
    $instant_update = $instant_update ? 1 : 0;

    if ($resume) {

        #	print "have resume level of $resume\n";
        $self->{resume} = $resume;
    }

    if ( $update_rate == -1 ) {
        print "Item $id will not be polled for updates\n";
    }

    $self->{type}       = $type;
    $self->{zwave_id}   = $id;
    $self->{bad_sets}   = 0;
    $self->{total_sets} = 0;

    $self->{mode} = 'auto';

    $self->{update_rate} = $update_rate;    # sets how often the item is polled
    $self->{update_deferral_count} = 0;     # how many times update was deferred
    $self->{instant_update} = $instant_update;

    $self->set_interface( $interface, $id, $type )
      ;                                     # associate item with interface

    $self->add( N . $id . 'L' . '99', 'on' );
    $self->add( N . $id . 'L' . '99', '100%' );
    $self->add( N . $id . 'L' . '80', '80%' );
    $self->add( N . $id . 'L' . '60', '60%' );
    $self->add( N . $id . 'L' . '40', '40%' );
    $self->add( N . $id . 'L' . '20', '20%' );
    $self->add( N . $id . 'L' . '10', '10%' );
    $self->add( N . $id . 'L' . '99', '+100%' );
    $self->add( N . $id . 'L' . '80', '+80%' );
    $self->add( N . $id . 'L' . '60', '+60%' );
    $self->add( N . $id . 'L' . '40', '+40%' );
    $self->add( N . $id . 'L' . '20', '+20%' );
    $self->add( N . $id . 'L' . '10', '+10%' );
    $self->add( N . $id . 'L' . '80', '-80%' );
    $self->add( N . $id . 'L' . '60', '-60%' );
    $self->add( N . $id . 'L' . '40', '-40%' );
    $self->add( N . $id . 'L' . '20', '-20%' );
    $self->add( N . $id . 'L' . '10', '-10%' );
    $self->add( N . $id . 'L' . '5',  '-5%' );
    $self->add( N . $id . 'L' . '99', '+100' );
    $self->add( N . $id . 'L' . '80', '+80' );
    $self->add( N . $id . 'L' . '60', '+60' );
    $self->add( N . $id . 'L' . '40', '+40' );
    $self->add( N . $id . 'L' . '20', '+20' );
    $self->add( N . $id . 'L' . '10', '+10' );
    $self->add( N . $id . 'L' . '80', '-100' );
    $self->add( N . $id . 'L' . '80', '-80' );
    $self->add( N . $id . 'L' . '60', '-60' );
    $self->add( N . $id . 'L' . '40', '-40' );
    $self->add( N . $id . 'L' . '20', '-20' );
    $self->add( N . $id . 'L' . '10', '-10' );
    $self->add( N . $id . 'L' . '5',  '-5%' );
    $self->add( N . $id . 'L' . '0',  'off' );
    $self->add('status');
    $self->add('brighten');
    $self->add('dim');
    $self->add('manual');

    $self->{set_open_loop} = 1
      ; # means we can set the state before it is confirmed by a query of the device (faster)

    #    foreach $key (%{$self}) {
    #	print "key $key\n";
    #    }

    return $self;
}

sub processSetData {
    my ( $self, $state ) = @_;

    my $name = $self->get_object_name();
    &::print_log("ZWave Light:self:$self name:$name state:$state\n")
      if $::config_parms{rzc0p_errata} >= 4;

    $state =~ s/%2B/+/;    # web replaces "+" with "%2B", so we fix it here

    #    print "state now:$state\n";

    # Check for toggle state
    if ( $state eq 'toggle' ) {
        if ( $$self{state} eq 'on' ) {
            $state = 'off';
        }
        elsif ( $$self{state} eq 'off' ) {
            $state = 'on';
        }
        else {
            &::print_log(
                "Can't toggle unless state is on or off), state=$$self{state}")
              if $::config_parms{rzc0p_errata} >= 1;
        }
    }

    if ( $state =~ /brighten/ ) { $state = '+10'; }
    if ( $state =~ /dim/ )      { $state = '-10'; }

    $state = &convert_percents( $self, $state )
      if ( $state =~ /^[\+\-]*\d+/ );    # it's a number

    my $data;

    if ( $state =~ /(\d+)/ ) {           # set to absolute percent
        my $level = $1;
        $self->{total_sets}++;
        $data = '>N' . $self->{zwave_id} . 'L' . $level;
        $self->{interface}->send_zwave_data( $self, $data, 1, 0, 1, 0 );

        #	$self->{desired_state} = $self->level_to_state($level) if  $self->{set_open_loop};
        $self->{desired_state} = $self->level_to_state($level);

        #	$self->{desired_level} = $level if  $self->{set_open_loop};
        $self->{desired_level} = $level;
        $self->{set_confirmed} = 0;
        $self->{set_pending}   = 1;

        # go get the state
        $self->{interface}
          ->send_zwave_data( $self, '>?N' . $self->{zwave_id}, 1, 1, 0, 0 );
    }

    elsif ( $state eq 'off' ) {
        $self->{total_sets}++;
        $data = '>N' . $self->{zwave_id} . 'OF';
        $self->{interface}->send_zwave_data( $self, $data, 1, 0, 1, 0 );
        $state = 'off';

        #	$self->{desired_state} = 'off' if $self->{set_open_loop};
        $self->{desired_state} = 'off';
        $self->{set_confirmed} = 0;
        $self->{set_pending}   = 1;

        #	$self->{desired_level} = 0 if $self->{set_open_loop};
        $self->{desired_level} = 0;

        # queue the status command
        $self->{interface}
          ->send_zwave_data( $self, '>?N' . $self->{zwave_id}, 1, 1, 0, 0 );
    }

    elsif ( $state eq 'on' ) {
        $self->{total_sets}++;

        #	$data = '>N' . $self->{zwave_id} . 'ON';
        if ( $self->{resume} ) {
            &::print_log(
                "setting $self->{object_name} to resume level of $self->{resume}"
            );
            $data = '>N' . $self->{zwave_id} . 'L' . $self->{resume};
            $self->{desired_level} = $self->{resume};
        }
        else {
            &::print_log(
                "No resume level for $self->{object_name}, setting to 99");
            $data = '>N' . $self->{zwave_id} . 'L99';
            $self->{desired_level} = '099';
        }

        $self->{interface}->send_zwave_data( $self, $data, 1, 0, 1, 0 );
        $self->{set_confirmed} = 0;
        $self->{set_pending}   = 1;

        # On commands are not open loop since we can't predict the answer
        #	$self->{state} = 'on' if $self->{set_open_loop};
        # fix this should be resume level
        #	$self->{level} = 99 if $self->{set_open_loop};
        # force the status command to complete now
        $self->{interface}
          ->send_zwave_data( $self, '>?N' . $self->{zwave_id}, 1, 1, 0, 1 );
    }
    else {
        &::print_log("ZWave Light Error: Unrecognized incoming state $state\n")
          if $::config_parms{rzc0p_errata} >= 1;
    }
}

# this sub converts all the formats (+-##%, ##%, +-##)
# to a decimal val between 0-100
sub convert_percents {

    my ( $self, $data ) = @_;

    # percent relative to current value, convert those to absolute value
    my $desired_level_now = $self->{desired_level};

    #    print "converting percents, data:$data desired level now:$desired_level_now\n";

    $data =~ /^([\-\+]*\d+)/;
    my $amount = $1;

    #    print "amount is $amount\n";

    # this type of percent is relative to the current value
    if ( $data =~ /^([\-\+]*\d+)\%/ ) {    # its a percent

        # '+/-##%'  - increase/decrease brightness by ## percent
        if ( $data =~ /^[\+\-]/ ) {

            #	    print "relative percentage $amount to be added to current value\n";

            my $level_diff = int( $desired_level_now * ( $amount / 100 ) );
            &main::print_log(
                "Relative percent: Changing light by $level_diff ($level_now * $amount%)"
            );
            $data = $desired_level_now + $level_diff;
        }
        else {    # '##%'        - set brightness to ## percent

            #	    print "absolute percent of $amount\n";
            $data = $amount;
        }
    }    # it's a percent

    # it's not a percent, must be +- abs
    # '-##' - decrease brightness by ## points
    # '+##' - increase brightness by ## points
    else {
        #	print "absolute percent $amount to be added to current value of $desired_level_now\n";
        $data = $desired_level_now + $amount;
    }

    # fixup any level overflows,
    $data = 0  if $data < 0;
    $data = 99 if $data > 99;

    #    print "final answer: $data\n";
    return $data;
}

sub state_level {

    #    print "state level called\n";
    my $state = $_[0]->{state};
    my $level = $_[0]->{level};
    if ( !defined $state or !( $state eq 'on' or $state eq 'off' ) ) {
        if ( defined $level and $level =~ /^\d+$/ ) {
            $state = $level;
        }
    }
    return $state;
}

package ZWave_Appliance_Item;

@ZWave_Appliance_Item::ISA = ('ZWave_Item');

sub new {

    my ( $class, $id, $interface, $update_rate, $instant_update ) = @_;

    my $self = $class->Generic_Item::new();

    bless $self, $class;

    #    print "creating new ZWave Appliance item $id, int:$interface, type:$type, upd:$update_rate\n";

    $interface   = 'RZC0P'           unless defined $interface;
    $type        = 'ZWAVE_APPLIANCE' unless defined $type;
    $update_rate = '5'               unless defined $update_rate;
    $instant_update = $instant_update ? 1 : 0;

    $self->{type}                  = $type;
    $self->{zwave_id}              = $id;
    $self->{update_rate}           = $update_rate;
    $self->{update_deferral_count} = 0;
    $self->{instant_update}        = $instant_update;

    $self->set_interface( $interface, $id, $type );
    $self->{set_open_loop} = 1;
    $self->{bad_sets}      = 0;
    $self->{total_sets}    = 0;

    $self->{mode} = 'auto';

    $self->add('on');
    $self->add('off');
    $self->add('status');

    return $self;
}

sub processSetData {
    my ( $self, $data ) = @_;

    #    &::print_log("Zwave_appliance: Processing data $data");

    $data = lc $data;

    # Check for toggle data
    if ( $data eq 'toggle' ) {
        if ( $$self{state} eq 'on' ) {
            $data = 'off';
        }
        elsif ( $$self{state} eq 'off' ) {
            $data = 'on';
        }
        else {
            &::print_log(
                "Zwave_appliance: Can't toggle state that's not off/on");
        }
    }

    elsif ( $data eq 'off' ) {
        $data = '>N' . $self->{zwave_id} . 'OF';
        $self->{interface}->send_zwave_data( $self, $data, 1, 0, 1, 0 );

        #	print "turning $self->{zwave_id} OFF\n";
        #	$self->{state} = 'off' if $self->{set_open_loop};
        #	$self->{level} = 0 if $self->{set_open_loop};

        $self->{desired_state} = 'off';
        $self->{set_confirmed} = 0;
        $self->{set_pending}   = 1;

        #	$self->{desired_level} = 0 if $self->{set_open_loop};
        $self->{desired_level} = 0;
        $self->{total_sets}++;
    }

    elsif ( $data eq 'on' ) {
        $data = '>N' . $self->{zwave_id} . 'ON';
        $self->{interface}->send_zwave_data( $self, $data, 1, 0, 1, 0 );

        #	print "turning $self->{zwave_id} ON\n";
        #	$self->{state} = 'on' if $self->{set_open_loop};
        #	$self->{level} = 255 if $self->{set_open_loop};
        $self->{desired_state} = 'on';
        $self->{set_confirmed} = 0;
        $self->{set_pending}   = 1;

        #	$self->{desired_level} = 255 if $self->{set_open_loop};
        $self->{desired_level} = 255;
        $self->{total_sets}++;
    }

    elsif ( $data eq 'status' ) {    # we always get status on any command...
    }

    else { &::print_log("ZWave_Appliance: got unsupported command $data\n"); }

    # get the status of the operation
    $self->{interface}
      ->send_zwave_data( $self, '>?N' . $self->{zwave_id}, 1, 1, 0, 0 );
}

return 1;

# =========== Revision History ==============
# Revision 1.0  -- 10/26/2007 -- David Satterfield
# - First Release
#
# Revision 1.1  -- 12/28/2007 -- David Satterfield
# - Added Resume Function
# Revision 1.2  -- 1/3/2008 -- David Satterfield
# - Fixed sending of Resume Value
#
#
