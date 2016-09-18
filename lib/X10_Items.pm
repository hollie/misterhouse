# $Date$
# $Revision$

package X10_Item;

=head1 NAME

B<X10_Item> - This item is for controling X10 lamp modules and light switches. It is derived from Serial_Item and the strings it sends are like Serial Items, except an 'X' prefix is prepended to indicate an X10 command. The X strings are converted by one of the various X10 interfaces into the appropriate commands for that interface.

=head1 SYNOPSIS

X10 items can be created in the items.mht in the following manner:

  X10I, A1, Test_light, Bedroom, cm11, preset resume=80

If a single character is used (e.g. X10_Item 'D'), commands apply to all X10_Items with that house code. The 'on' and 'off' states are translated to ALL_ON and ALL_OFF commands for that house code. For example:

  $v_test_lights = new Voice_Cmd 'All lights [on,off]';
  $test_lights   = new X10_Item 'O';
  set $test_lights $state if $state = said $v_test_lights;

The toggle and various brightness commands can be sent to a house code only item. The command will be sent to each X10_Item defined with the same house code. This might produce undesired results, particularly when changing brightness levels. See the Group item for a better way to do that.

If you are using more than one X10 interface and you want to control an X10_Item with a specific interface, use the optional interface argument. For example, if you want to control the local module on a RF Transceiver, you can tell mh to use the RF CM17 interface, like this:

  $test_light = new X10_Item('A1', 'CM17');

The various brightness commands (60%, +20, -50%) all work even on dumb modules that only support on, off, dim, and brighten. X10_Item keeps track of changes it makes to the brightness level and converts any absolute brightness settings into relative changes. Since these dumb modules typically don't have two-way capability, the item will be out of sync if changes are made locally at the switch. Also, if the module was off, it will first be turned to full on, since the older modules can not be dimmed from an off state.

After doing one or more bright/dim/on/off commands, you can query the current brightness level of a device with the level method. For example:

  if ($state = state_now $pedestal_light) {
    my $level = level $pedestal_light;
    print_log "Pedestal light state=$state, level=$level"
  }

It is much better to use one the newer (more expensive) direct dim and two-way capable modules, such as the X10 LM14A lamp module. The X10_Item supports both the newer extended data dim commands used by the LM14 and Leviton switches (64 brightness levels), and the older preset dim commands used by PCS and Switchlinc switches (32 brightness levels).

Set the 3rd X10_Item parm to specify the option flags that correspond to your lamp module or switch. Valid flags are:

  'lm14'        - for X10 LM14, uses extended data dim commands, remembers dim level when off 
  'preset'      - same as lm14 
  'preset2'     - same as lm14 and preset, except send on after direct dims, required by some Leviton switches 
  'preset3'     - same as lm14 and preset, except uses older preset dim commands, for Switchlinc and PCS 
  'resume=##'   - module resumes from off at ## percent 
  'transmitter' - special case, see X10_Transmitter

Option flags are case insensitive. Separate multiple option flags with a space.

For example:

  $test_light2 = new X10_Item('O7', undef, 'preset resume=81');
  $v_test_light2 = new Voice_Cmd("Set test light to [on,off,bright,dim,5%,10%,20%,30%,40%,50%,60%,70%,80%,90%]");
  set $test_light2 $state if $state = said $v_test_light2;

If the newer extended data dim commands are to be used, then the brightness level is converted into a &P## command and passed to the X10 interface. You can also use them directly, using &P## (## = 1->64) as shown in this example:

  $test_light1 = new X10_Item('O7', 'CM11', 'LM14');
  $v_test_light1 = new Voice_Cmd("Set test light to [on,off,bright,dim,&P3,&P10,&P30,&P40,&P50,&P60]");
  set $test_light1 $state if $state = said $v_test_light1;

Note: not all of the X10 interfaces support this command.

The older direct dim method used the two Preset Dim X10 commands. The 32 brightness levels are sent by combining a house code with one of the two Preset Dim commands, using the following table:

  0  1  2  3  4  5  6  7  8  9 10 11 12 13 14 15   PRESET_DIM1
  M  N  O  P  C  D  A  B  E  F  G  H  K  L  I  J

  16 17 18 19 20 21 22 23 24 25 26 27 28 29 30 31  PRESET_DIM2
  M  N  O  P  C  D  A  B  E  F  G  H  K  L  I  J

Note: not all of the X10 interfaces support this command.

Since this item is inherits from Generic_Item, you can use the set_with_timer method. For example, this event will turn on a on a warning light to 20% for 5 seconds:

  set_with_timer $watchdog_light '20%', 5 if file_unchanged $watchdog_file;


=head1 DESCRIPTION

=head1 INHERITS

B<X10_Interface>

=head1 METHODS

=over

=cut

#use strict;
use X10_Interface;
use Serial_Item;
use Dummy_Interface;

my ( %items_by_house_code, %appliances_by_house_code, $sensorinit );

#&main::Reload_post_hook(\&X10_Item::reset, 1) if $Startup;

sub reset {

    #   print "\n\nRunning X10_Item reset\n\n\n";
    undef %items_by_house_code;
    undef %appliances_by_house_code;
    $sensorinit = 0;
}

@X10_Item::ISA = ('X10_Interface');

=item C<new('house code[unit number]' [, 'interface'|undef [, 'option flags']])>

house code[unit number] - The first argument is required and is either a house code by itself or a house code and unit number.  Note that the X10 unit code is numbered either 1->16 or 1->9,A->G.  For example device 16 in house code P could be P16 or PG

interface - Optional, specifies which X10 interface to use

option flags - Optional, specifies one or more module options (see below)

=cut

sub new {
    my ( $class, $id, $interface, $type ) = @_;

    #   my $self = {};
    #   $$self{state} = '';     # Only items with state defined are controlable from web interface
    my $self = $class->Generic_Item::new();

    bless $self, $class;

    #   print "\n\nWarning: duplicate ID codes on different X10_Item objects: id=$id\n\n" if $serial_item_by_id{$id};

    $self->{type} = $type;

    $self->set_interface( $interface, $id );

    # level variable stores current brightness level
    # undef means off, 100 is on
    restore_data $self ('level');    # Save brightness level between restarts

    # resume variable stores brightness level to use when on is sent
    # defaults to 100, 0 means set to previous level
    $self->{resume} = 100;
    my $set_resume;
    ( ($set_resume) = $self->{type} =~ /resume=(\d+)/i ) if $self->{type};
    $self->{resume} = $set_resume if defined $set_resume;
    restore_data $self ('resume');    # Save resume level between restarts

    if ($id) {
        my $hc = substr( $id, 0, 1 );
        push @{ $items_by_house_code{$hc} }, $self;

        # Allow for unit=9,10,11..16, instead of 9,A,B,C..G
        if ( $id =~ /^\S1(\d)$/ ) {
            $id = $hc . substr 'ABCDEFG', $1, 1;
        }
        $id                          = "X$id";
        $self->{x10_id}              = $id;
        $self->{interface}->{x10_id} = $id;

        # Setup house only codes:     e.g. XAO, XAP, XA+20
        #  - allow for all bright/dim commands so we can detect incoming signals
        if ( length($id) == 2 ) {
            $self->add( $id . 'O',              'on' );
            $self->add( $id . 'P',              'off' );
            $self->add( $id . 'L',              'brighten' );
            $self->add( $id . 'M',              'dim' );
            $self->add( $id . 'STATUS',         'status' );
            $self->add( $hc . 'O',              'all_lights_on' );
            $self->add( $hc . 'P',              'all_off' );
            $self->add( $hc . 'ALL_LIGHTS_OFF', 'all_lights_off' );
        }

        # Setup unit-command  codes:  e.g. XA1AJ, XA1AK, XA1+20
        # Note: The 0%->100% states are handled directly in Serial_Item.pm
        else {
            $self->add( $id . $hc . 'J',                         'on' );
            $self->add( $id . $hc . 'K',                         'off' );
            $self->add( $id . $hc . 'J' . $hc . 'J',             'double on' );
            $self->add( $id . $hc . 'K' . $hc . 'K',             'double off' );
            $self->add( $id . $hc . 'J' . $hc . 'J' . $hc . 'J', 'triple on' );
            $self->add( $id . $hc . 'K' . $hc . 'K' . $hc . 'K', 'triple off' );
            $self->add( $id . $hc . 'L',                         'brighten' );
            $self->add( $id . $hc . 'M',                         'dim' );
            $self->add( $id . $hc . 'STATUS',                    'status' );
            $self->add( $id . $hc . 'STATUS_ON',                 'status on' );
            $self->add( $id . $hc . 'STATUS_OFF',                'status off' );
            $self->add( $id,                                     'manual' )
              ; # Used in Group.pm.  This is what we get with a manual kepress, with on ON/OFF after it

            if ( $self->{type} and $self->{type} =~ /(preset3)/i ) {
                my @preset_dim_levels =
                  qw(M  N  O  P  C  D  A  B  E  F  G  H  K  L  I  J);

                # 0% is MPRESET_DIM1
                $self->add( $id . $preset_dim_levels[0] . 'PRESET_DIM1', "0%" );

                # 100% is JPRESET_DIM2
                $self->add( $id . $preset_dim_levels[15] . 'PRESET_DIM2',
                    "100%" );

                # 30 levels, 1% to 99%
                for ( my $percent = 1; $percent <= 99; $percent++ ) {
                    my $index = int( ( $percent - 1 ) * 30 / 99 ) + 1;
                    my $state2 = $id
                      . (
                        ( $index < 16 )
                        ? $preset_dim_levels[$index] . 'PRESET_DIM1'
                        : $preset_dim_levels[ $index - 16 ] . 'PRESET_DIM2'
                      );
                    $self->add( $state2, $percent . "%" );
                }
            }
        }
    }

    return $self;
}

sub add {
    my ( $self, $id, $state ) = @_;

    #print "X10Items->add called with self $self, id $id and state $state\n";
    #print "self not defined\n" if not defined $self;
    #print "interface not defined\n" if $self and not defined $self->{interface};

    if ( $$self{interface}->isa('Insteon_PLM')
      )    # not sure if this is ever needed
    {
        $self->{interface}->add_id_state( $id, $state );
    }
    else {
        $self->{interface}->add( $id, $state );
    }
    $self->SUPER::add( $id, $state );
}

# this sets the interface through which we will send X10 data when asked to do so
sub set_interface {
    my ( $self, $interface, $id ) = @_;
    my $localDebug       = 0;
    my $interface_object = eval( '$::' . $interface );

    # if an interface is specified, then we need to search through the
    # possible interface modules until we find one that will work with it
    if ($interface) {
        if ( X10_Interface->supports($interface) ) {
            print
              "[X10] for id $id, x10 interface supplied ($interface) and supported by X10_Interface\n"
              if $localDebug;
            $self->{interface} = new X10_Interface( undef, undef, $interface );
        }
        elsif ( Serial_Item->supports($interface) ) {
            print
              "[X10] for id $id, x10 interface supplied ($interface) and supported by Serial_Item\n"
              if $localDebug;
            $self->{interface} = new Serial_Item( undef, undef, $interface );
        }
        elsif ( defined $interface_object
            and $interface_object->isa('Insteon_PLM') )
        {
            print
              "[X10] for id $id, x10 interface supplied ($interface) and supported by an Insteon PLM\n"
              if $localDebug;
            $self->{interface} = $interface_object;
        }
        else {
            # we can't find a real interface, so use a Dummy_Interface
            print
              "[X10] warning, using dummy interface for id $id and supplied interface $interface\n"
              if $localDebug;
            $self->{interface} = new Dummy_Interface( $id, undef, $interface );
        }
    }
    else {
        # an interface wasn't specified, we'll use the first one that we find
        if ( $interface = X10_Interface->lookup_interface ) {
            print
              "[X10] for id $id, x10 interface not supplied, supported by X10_Interface $interface\n"
              if $localDebug;
            $self->{interface} = new X10_Interface( undef, undef, $interface );
        }
        elsif ( $interface = Serial_Item->lookup_interface ) {
            print
              "[X10] for id $id, x10 interface not supplied, supported by Serial_Item $interface\n"
              if $localDebug;
            $self->{interface} = new Serial_Item( undef, undef, $interface );
        }
        else {
            # we can't find a real interface, so use a Dummy_Interface
            print "[X10] warning, using dummy interface for id $id\n"
              if $localDebug;
            $self->{interface} = new Dummy_Interface($id);
        }
    }

    # tell our "generic" interface object the name of the actual interface to use
    # we could also call set_interface without an interface name but it would
    # just repeat the same search that we just did
    if ( $self->{interface}->can('set_interface') ) {
        $self->{interface}->set_interface($interface);
    }

    # Set a placeholder object name for our contained interface class
    # This is to provide a more friendly log message when X10 data is received
    # It starts with a '#' so that we can identify these contained objects in
    # code/common/mh_control.pl and suppress them if desired.
    $self->{interface}->{object_name} =
      '#' . ref( $self->{interface} ) . ' for ' . ref($self);
}

sub property_changed {
    my ( $self, $property, $new_value, $old_value ) = @_;

    #   print "x10 s=$self: property_changed: $property='$new_value' (was '$old_value')\n";
    if ( $property eq 'state' ) {
        &set_x10_level( $self, $new_value );
    }
}

=item C<set('state')>

Sets the item to the specified state

  'on'
  'off'
  'toggle'     - toggles between on and off
  'brighten'
  'dim'
  '+##'        - increase brightness by ## points
  '-##'        - decrease brightness by ## points
  '##%'        - set brightness to ## percent
  '+##%'       - increase brightness by ## percent
  '-##%'       - decrease brightness by ## percent
  'double on'  - on some modules this sets full brightness at ramp rate
  'double off' - on some modules this sets 0 brightness immediately
  'triple on'  - same as double on, but immediate
  'triple off' - same as double off
  'status'     - requests status from a two-way capable module
  'manual'     - sends house code and unit number without a command 

These states are rarely used and provided for special cases

  '&P##', 'PRESET_DIM1', 'PRESET_DIM2', 'ALL_LIGHTS_OFF', 'HAIL_REQUEST', 
  'HAIL_ACK', 'EXTENDED_CODE', 'EXTENDED_DATA', 'STATUS_ON', 'STATUS_OFF', 'Z##'

Note: not all states are supported by all lamp modules and X10 interfaces.

=cut

# Check for toggle data
sub set {
    my ( $self, $state, $set_by ) = @_;
    return if &main::check_for_tied_filters( $self, $state );

    my $level  = $$self{level};
    my $resume = $self->{resume};
    my ( $presetable, $lm14, $preset, $preset2, $preset3 );
    $lm14       = 1 if $self->{type} and ( $self->{type} =~ /\blm14\b/i );
    $preset     = 1 if $self->{type} and ( $self->{type} =~ /\bpreset\b/i );
    $preset2    = 1 if $self->{type} and ( $self->{type} =~ /\bpreset2\b/i );
    $preset3    = 1 if $self->{type} and ( $self->{type} =~ /\bpreset3\b/i );
    $presetable = 1 if $self->{type} and ( $self->{type} =~ /(lm14|preset)/i );

    # Turn light off if on or dim, turn on if off
    if ( $state eq 'toggle' ) {
        if ($level) {
            $state = 'off';
        }
        else {
            $state = 'on';
        }
        &main::print_log(
            "[X10] Toggling X10_Item object $self->{object_name} from $$self{state} to $state"
        ) if $main::Debug{x10};
    }

    # Make sure we do the right thing if light was off
    # Presetable modules can come on dimmed, so allow 0 + 20 = 20
    # Basic modules should be turned on first
    if (
        !defined $level
        and (  $state =~ /^\d+\%$/
            or $state =~ /^[-+]?\d+$/
            or $state =~ /^[-+]\d+\%$/ )
      )
    {
        if ($presetable) {
            $self->{level} = 0;
        }
        else {
            &set( $self, 'on' );
            &set_x10_level( $self, 'on' );
        }
    }

    # Convert +-dd% to +-dd by multiplying it by the current level
    if ( $state =~ /^([-+]\d+)\%$/ ) {
        my $change    = $1;
        my $level_now = $self->{level};
        $level_now = 100 unless defined $level_now;
        my $level_diff = int( $level_now * ( $change / 100 ) );

        # Round of to nearest 5 for dumb modules, since Serial Item rounds by 5
        $level_diff = 5 * int $level_diff / 5 unless $presetable;
        &main::print_log(
            "[X10] Changing light by $level_diff ($level_now * $change%)")
          if $main::config_parms{x10_errata} >= 3;
        $state = $level_diff;
    }

    # Allow for dd% light levels on older devices by monitoring current level
    if ( !$presetable and $state =~ /^(\d+)\%/ ) {
        my $level     = $1;
        my $level_now = $self->{level};
        $level_now = 100 unless defined $level_now;
        my $level_diff = $level - $level_now;

        # Round of to nearest 5 for dumb modules, since Serial Item rounds by 5
        $level_diff = 5 * int $level_diff / 5;
        &main::print_log(
            "[X10] Changing light by $level_diff ($level - $level_now)")
          if $main::config_parms{x10_errata} >= 3;
        $state = $level_diff;
    }

    $state = "+$state"
      if $state =~ /^\d+$/; # In case someone trys a state of 30 instead of +30.

    # Convert relative dims to direct dims for supported devices
    if ( $presetable and $state =~ /^([\+\-]?)(\d+)$/ ) {
        my $level = $$self{level};
        $level = 100
          unless
          defined $level;    # bright and dim from on or off will start at 100%
        $level += $state;
        $level = 0   if $level < 0;
        $level = 100 if $level > 100;
        $state = $level . '%';
    }

    # Send the command
    $self->SUPER::set( $state, $set_by );
    $set_by = $self if !defined $set_by;

    #Insteon PLM needs calling object, dont care about who originated
    if ( $self->{interface}->isa("Insteon_PLM") ) {
        $self->{interface}->set( $state, $self );
    }
    else {
        $self->{interface}->set( $state, $set_by );
    }

    # Some presetable devices, like the Leviton 6381, will remain addressed
    # after a preset command and will accept subsequent unrelated
    # commands unless they are set to ON.
    if ( $preset2 and $state =~ /^\d+\%$/ ) {
        &set( $self, 'on' );
    }

    # Set objects that match House Code commands
    if ( length( $self->{x10_id} ) == 2 ) {
        my $hc = substr $self->{x10_id}, 1;    # Drop the X prefix
        &set_by_housecode( $hc, $state );
    }
}

=item C<set_receive>

Update the state and level when X10 commands are received

=cut

sub set_receive {
    my ( $self, $state, $set_by ) = @_;

    &set_x10_level( $self, $state );
    $self->SUPER::set_receive( $state, $set_by );
    $self->{interface}->set_receive( $state, $set_by )
      unless $self->{interface}->isa('Insteon_PLM');
}

=item C<set_x10_level>

Recalculates state whenever state is changed

=cut

# Try to keep track of X10 brightness level
sub set_x10_level {
    my ( $self, $state ) = @_;
    return unless defined $state;

    my $level  = $$self{level};
    my $resume = $self->{resume};
    my ( $presetable, $lm14, $preset, $preset2, $preset3 );
    $lm14       = 1 if $self->{type} and ( $self->{type} =~ /\blm14\b/i );
    $preset     = 1 if $self->{type} and ( $self->{type} =~ /\bpreset\b/i );
    $preset2    = 1 if $self->{type} and ( $self->{type} =~ /\bpreset2\b/i );
    $preset3    = 1 if $self->{type} and ( $self->{type} =~ /\bpreset3\b/i );
    $presetable = 1 if $self->{type} and ( $self->{type} =~ /(lm14|preset)/i );

    # handle relative changes
    if (   $state =~ /^([\+\-]?)(\d+)$/
        or $state eq 'dim'
        or $state eq 'brighten' )
    {
        # dumb modules come on full if a dim or bright is sent
        $level = $resume if !$presetable and !defined $level;
        if ( $state eq 'dim' ) {
            $state = -5;
        }
        elsif ( $state eq 'brighten' ) {
            $state = 5;
        }
        $level += $state;
        $level = 0   if $level < 0;
        $level = 100 if $level > 100;
    }

    # handle direct changes
    elsif ( $state =~ /^(\d+)\%$/ ) {
        $level = $1;
    }

    # use resume=dd in type field if the module has set level
    elsif ( $state eq 'on' ) {
        if ( defined $level ) {

            # the Switchlincs change to resume level even if dimmed
            $level = $resume if $preset3;
        }
        else {
            # other modules only change if off
            $level = $resume;
        }
    }

    # handle off state
    elsif ($state eq 'off'
        or $state eq 'double off'
        or $state eq 'triple off ' )
    {
        my $set_resume;
        ( ($set_resume) = $self->{type} =~ /resume=(\d+)/i ) if $self->{type};
        if ( defined $set_resume ) {

            # resume=0 means resume at previous level
            if ( $set_resume == 0 ) {
                $self->{resume} = $level;
            }
            else {
                $self->{resume} = $set_resume;
            }
        }
        $level = undef;
    }
    elsif ( $state eq 'double on' or $state eq 'triple on' ) {
        $level = 100;
    }

    # on presetable switches, 0 brightness is same as off
    $level = undef if $level == 0 and $presetable;

    #   print "db setting level for $self $$self{object_name} state=$state level=$level\n";
    $$self{level} = $level;
}

# This returns the type variable
sub type {
    return $_[0]->{type};
}

# This returns the resume type variable
sub resume {
    return $_[0]->{resume};
}

=item C<level>

Returns the current brightness level of the item, 0->100

=cut

# This returns current brightness level ... see above
sub level {

    #   print "db2 l=$_[0]->{level} s=$_[0]->{state}\n";
    return $_[0]->{level};
}

sub state_level {
    my $state = $_[0]->{state};
    my $level = $_[0]->{level};
    if ( defined $level ) {
        $state = 'dim';
        $state = 'on' if $level == 100;
    }
    else {
        $state = 'off';
    }
    return $state;
}

sub set_by_housecode {
    my ( $hc, $state ) = @_;

    # change the $state variable to either "on" or "off".
    my $original_state = $state;
    if ( ( $state eq 'all_off' ) or ( $state eq 'all_lights_off' ) ) {
        $state = 'off';
    }
    if ( ( $state eq 'all_lights_on' ) ) { $state = 'on'; }

    print "[X10] Modifying non-appliance modules on $hc to state $state\n"
      if $main::Debug{x10};
    for my $object ( @{ $items_by_house_code{$hc} } ) {
        next if $object->{type} =~ /transmit/i;    # Do not set transmitters

        #       next if $object->isa('X10_Transmitter'); # This would work also
        print "[X10] Setting X10 House code $hc item $object to $state\n"
          if $main::Debug{x10};
        $object->set_receive( $state, 'housecode' );
    }

    # All lights on/off does not effect appliances
    if ( ( $state eq 'on' ) or ( $original_state eq 'all_lights_off' ) ) {
        print "[X10] $original_state does not affect appliance modules\n"
          if $main::Debug{x10};
        return;
    }

    print "[X10] Setting all appliance items on $hc to state $state\n"
      if $main::Debug{x10};
    for my $object ( @{ $appliances_by_house_code{$hc} } ) {
        print "[X10] Setting X10 House code $hc appliance $object to $state\n"
          if $main::Debug{x10};
        $object->set_receive( $state, 'housecode' );
    }

}

=back

=head1 INHERITED METHODS

=over

=item C<state>

Returns the last state that was received or sent

=item C<state_now>

Returns the state that was received or sent in the current pass

=back

=head1 INI PARAMETERS

NONE

=head1 AUTHOR

UNK

=head1 SEE ALSO

NONE

=head1 LICENSE

This program is free software; you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation; either version 2 of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more details.

You should have received a copy of the GNU General Public License along with this program; if not, write to the Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.

=cut

package X10_Appliance;

=head1 NAME

B<X10_Appliance>

=head1 DESCRIPTION

Same as X10_Item, except it has only has pre-defined states 'on' and 'off'

=head1 INHERITS

B<X10_Item>

=cut

@X10_Appliance::ISA = ('X10_Item');

sub new {
    my ( $class, $id, $interface ) = @_;

    #   my $self = {};
    my $self = $class->Generic_Item::new();
    $$self{state} = '';

    bless $self, $class;

    $self->set_interface( $interface, $id );

    #   print "\n\nWarning: duplicate ID codes on different X10_Appliance objects: id=$id\n\n" if $serial_item_by_id{$id};

    my $hc = substr( $id, 0, 1 );
    push @{ $appliances_by_house_code{$hc} }, $self;

    # Allow for unit=9,10,11..16, instead of 9,A,B,C..F
    if ( $id =~ /^\S1(\d)$/ ) {
        $id = $hc . substr 'ABCDEFG', $1, 1;
    }
    $id                          = "X$id";
    $self->{x10_id}              = $id;
    $self->{interface}->{x10_id} = $id;
    $self->{resume}              = 100;

    # level variable stores current brightness level
    # undef means off, 100 is on
    restore_data $self ('level');    # Save brightness level between restarts

    $self->add( $id . $hc . 'J',      'on' );
    $self->add( $id . $hc . 'K',      'off' );
    $self->add( $id,                  'manual' );
    $self->add( $id . $hc . 'STATUS', 'status' );

    return $self;
}

package X10_Transmitter;

=head1 NAME

B<X10_Transmitter>

=head1 SYNOPSIS

=head1 DESCRIPTION

Like an X10_Item, but will not be set by incoming X10 data. Simulates transmit only devices like keypads. Can be used in place of X10_Item if you have complicated code that might get into a loop because we are not ignoring incoming X10 data for transmit-only devices.

=head1 INHERITS

B<X10_Item>

=cut

@X10_Transmitter::ISA = ('X10_Item');

sub new {
    my ( $class, $id, $name, $type ) = @_;
    return &X10_Item::new( $class, $id, $name, 'transmitter' );
}

# This is used by X10_MR26.pm and X10_W800.pm, called by code/common/x10_rf_relay.pl
package X10_RF_Receiver;

@X10_RF_Receiver::ISA = ('Generic_Item');

package X10_Garage_Door;

=head1 NAME

B<X10_Garage_Door> - For the Stanley Garage Door status transmitter. 

=head1 INHERITS

B<X10_Item>

=cut

@X10_Garage_Door::ISA = ('X10_Item');

sub new {
    my ( $class, $id, $interface ) = @_;
    my $self = {};
    $$self{state} = '';

    bless $self, $class;

    $self->set_interface( $interface, $id );

    print
      "\n\nWarning: X10_Garage_Door object should not specify unit code; ignored\n\n"
      if length($id) > 1;
    my $hc = substr( $id, 0, 1 );
    $id = "X$hc" . 'Z';

    #   print "\n\nWarning: duplicate ID codes on different X10_Garage_Door objects: id=$id\n\n" if $serial_item_by_id{$id};
    $self->{x10_id} = $id;
    $self->{interface}->{x10_id} = $id;

    # Returned state is "bbbdccc"
    # "bbb" is 1=door enrolled, 0=enrolled, indexed by door # (i.e. 123)
    # "d" is door that caused transmission, numeric 1, 2, or 3
    # "ccc" is C=Closed, O=Open, indexed by door #

    $self->add( $id . '00001d', '0000CCC' )
      ;    # Only on initial power up of receiver; no doors enrolled.

    $self->add( $id . '01101d', '1001CCC' );
    $self->add( $id . '01111d', '1001OCC' );
    $self->add( $id . '01121d', '1001COC' );
    $self->add( $id . '01131d', '1001OOC' );
    $self->add( $id . '01141d', '1001CCO' );
    $self->add( $id . '01151d', '1001OCO' );
    $self->add( $id . '01161d', '1001COO' );
    $self->add( $id . '01171d', '1001OOO' );
    $self->add( $id . '01201d', '1002CCC' );
    $self->add( $id . '01211d', '1002OCC' );
    $self->add( $id . '01221d', '1002COC' );
    $self->add( $id . '01231d', '1002OOC' );
    $self->add( $id . '01241d', '1002CCO' );
    $self->add( $id . '01251d', '1002OCO' );
    $self->add( $id . '01261d', '1002COO' );
    $self->add( $id . '01271d', '1002OOO' );
    $self->add( $id . '01401d', '1003CCC' );
    $self->add( $id . '01411d', '1003OCC' );
    $self->add( $id . '01421d', '1003COC' );
    $self->add( $id . '01431d', '1003OOC' );
    $self->add( $id . '01441d', '1003CCO' );
    $self->add( $id . '01451d', '1003OCO' );
    $self->add( $id . '01461d', '1003COO' );
    $self->add( $id . '01471d', '1003OOO' );

    $self->add( $id . '02101d', '0101CCC' );
    $self->add( $id . '02111d', '0101OCC' );
    $self->add( $id . '02121d', '0101COC' );
    $self->add( $id . '02131d', '0101OOC' );
    $self->add( $id . '02141d', '0101CCO' );
    $self->add( $id . '02151d', '0101OCO' );
    $self->add( $id . '02161d', '0101COO' );
    $self->add( $id . '02171d', '0101OOO' );
    $self->add( $id . '02201d', '0102CCC' );
    $self->add( $id . '02211d', '0102OCC' );
    $self->add( $id . '02221d', '0102COC' );
    $self->add( $id . '02231d', '0102OOC' );
    $self->add( $id . '02241d', '0102CCO' );
    $self->add( $id . '02251d', '0102OCO' );
    $self->add( $id . '02261d', '0102COO' );
    $self->add( $id . '02271d', '0102OOO' );
    $self->add( $id . '02401d', '0103CCC' );
    $self->add( $id . '02411d', '0103OCC' );
    $self->add( $id . '02421d', '0103COC' );
    $self->add( $id . '02431d', '0103OOC' );
    $self->add( $id . '02441d', '0103CCO' );
    $self->add( $id . '02451d', '0103OCO' );
    $self->add( $id . '02461d', '0103COO' );
    $self->add( $id . '02471d', '0103OOO' );

    $self->add( $id . '03101d', '1101CCC' );
    $self->add( $id . '03111d', '1101OCC' );
    $self->add( $id . '03121d', '1101COC' );
    $self->add( $id . '03131d', '1101OOC' );
    $self->add( $id . '03141d', '1101CCO' );
    $self->add( $id . '03151d', '1101OCO' );
    $self->add( $id . '03161d', '1101COO' );
    $self->add( $id . '03171d', '1101OOO' );
    $self->add( $id . '03201d', '1102CCC' );
    $self->add( $id . '03211d', '1102OCC' );
    $self->add( $id . '03221d', '1102COC' );
    $self->add( $id . '03231d', '1102OOC' );
    $self->add( $id . '03241d', '1102CCO' );
    $self->add( $id . '03251d', '1102OCO' );
    $self->add( $id . '03261d', '1102COO' );
    $self->add( $id . '03271d', '1102OOO' );
    $self->add( $id . '03401d', '1103CCC' );
    $self->add( $id . '03411d', '1103OCC' );
    $self->add( $id . '03421d', '1103COC' );
    $self->add( $id . '03431d', '1103OOC' );
    $self->add( $id . '03441d', '1103CCO' );
    $self->add( $id . '03451d', '1103OCO' );
    $self->add( $id . '03461d', '1103COO' );
    $self->add( $id . '03471d', '1103OOO' );

    $self->add( $id . '04101d', '0011CCC' );
    $self->add( $id . '04111d', '0011OCC' );
    $self->add( $id . '04121d', '0011COC' );
    $self->add( $id . '04131d', '0011OOC' );
    $self->add( $id . '04141d', '0011CCO' );
    $self->add( $id . '04151d', '0011OCO' );
    $self->add( $id . '04161d', '0011COO' );
    $self->add( $id . '04171d', '0011OOO' );
    $self->add( $id . '04201d', '0012CCC' );
    $self->add( $id . '04211d', '0012OCC' );
    $self->add( $id . '04221d', '0012COC' );
    $self->add( $id . '04231d', '0012OOC' );
    $self->add( $id . '04241d', '0012CCO' );
    $self->add( $id . '04251d', '0012OCO' );
    $self->add( $id . '04261d', '0012COO' );
    $self->add( $id . '04271d', '0012OOO' );
    $self->add( $id . '04401d', '0013CCC' );
    $self->add( $id . '04411d', '0013OCC' );
    $self->add( $id . '04421d', '0013COC' );
    $self->add( $id . '04431d', '0013OOC' );
    $self->add( $id . '04441d', '0013CCO' );
    $self->add( $id . '04451d', '0013OCO' );
    $self->add( $id . '04461d', '0013COO' );
    $self->add( $id . '04471d', '0013OOO' );

    $self->add( $id . '05101d', '1011CCC' );
    $self->add( $id . '05111d', '1011OCC' );
    $self->add( $id . '05121d', '1011COC' );
    $self->add( $id . '05131d', '1011OOC' );
    $self->add( $id . '05141d', '1011CCO' );
    $self->add( $id . '05151d', '1011OCO' );
    $self->add( $id . '05161d', '1011COO' );
    $self->add( $id . '05171d', '1011OOO' );
    $self->add( $id . '05201d', '1012CCC' );
    $self->add( $id . '05211d', '1012OCC' );
    $self->add( $id . '05221d', '1012COC' );
    $self->add( $id . '05231d', '1012OOC' );
    $self->add( $id . '05241d', '1012CCO' );
    $self->add( $id . '05251d', '1012OCO' );
    $self->add( $id . '05261d', '1012COO' );
    $self->add( $id . '05271d', '1012OOO' );
    $self->add( $id . '05401d', '1013CCC' );
    $self->add( $id . '05411d', '1013OCC' );
    $self->add( $id . '05421d', '1013COC' );
    $self->add( $id . '05431d', '1013OOC' );
    $self->add( $id . '05441d', '1013CCO' );
    $self->add( $id . '05451d', '1013OCO' );
    $self->add( $id . '05461d', '1013COO' );
    $self->add( $id . '05471d', '1013OOO' );

    $self->add( $id . '06101d', '0111CCC' );
    $self->add( $id . '06111d', '0111OCC' );
    $self->add( $id . '06121d', '0111COC' );
    $self->add( $id . '06131d', '0111OOC' );
    $self->add( $id . '06141d', '0111CCO' );
    $self->add( $id . '06151d', '0111OCO' );
    $self->add( $id . '06161d', '0111COO' );
    $self->add( $id . '06171d', '0111OOO' );
    $self->add( $id . '06201d', '0112CCC' );
    $self->add( $id . '06211d', '0112OCC' );
    $self->add( $id . '06221d', '0112COC' );
    $self->add( $id . '06231d', '0112OOC' );
    $self->add( $id . '06241d', '0112CCO' );
    $self->add( $id . '06251d', '0112OCO' );
    $self->add( $id . '06261d', '0112COO' );
    $self->add( $id . '06271d', '0112OOO' );
    $self->add( $id . '06401d', '0113CCC' );
    $self->add( $id . '06411d', '0113OCC' );
    $self->add( $id . '06421d', '0113COC' );
    $self->add( $id . '06431d', '0113OOC' );
    $self->add( $id . '06441d', '0113CCO' );
    $self->add( $id . '06451d', '0113OCO' );
    $self->add( $id . '06461d', '0113COO' );
    $self->add( $id . '06471d', '0113OOO' );

    $self->add( $id . '07101d', '1111CCC' );
    $self->add( $id . '07111d', '1111OCC' );
    $self->add( $id . '07121d', '1111COC' );
    $self->add( $id . '07131d', '1111OOC' );
    $self->add( $id . '07141d', '1111CCO' );
    $self->add( $id . '07151d', '1111OCO' );
    $self->add( $id . '07161d', '1111COO' );
    $self->add( $id . '07171d', '1111OOO' );
    $self->add( $id . '07201d', '1112CCC' );
    $self->add( $id . '07211d', '1112OCC' );
    $self->add( $id . '07221d', '1112COC' );
    $self->add( $id . '07231d', '1112OOC' );
    $self->add( $id . '07241d', '1112CCO' );
    $self->add( $id . '07251d', '1112OCO' );
    $self->add( $id . '07261d', '1112COO' );
    $self->add( $id . '07271d', '1112OOO' );
    $self->add( $id . '07401d', '1113CCC' );
    $self->add( $id . '07411d', '1113OCC' );
    $self->add( $id . '07421d', '1113COC' );
    $self->add( $id . '07431d', '1113OOC' );
    $self->add( $id . '07441d', '1113CCO' );
    $self->add( $id . '07451d', '1113OCO' );
    $self->add( $id . '07461d', '1113COO' );
    $self->add( $id . '07471d', '1113OOO' );

    return $self;
}

=head1 SEE ALSO

See mh/code/public/Danal/Garage_Door.pl

=cut

package X10_IrrigationController;

=head1 NAME

B<X10_IrrigationController>

=head1 DESCRIPTION

For this sprinkler device: http://ourworld.compuserve.com/homepages/rciautomation/p6.htm which looks the same as the IrrMaster 4-zone sprinkler controller listed here: http://www.homecontrols.com/product.html?prodnum=HCLC4&id_hci=0920HC569027

=head1 INHERITS

B<X10_Item>

=cut

# More info at: http://ourworld.compuserve.com/homepages/rciautomation/p6.htm
# This looks the same as the IrrMaster 4-zone sprinkler controller
#  listed here: http://www.homecontrols.com/product.html?prodnum=HCLC4&id_hci=0920HC569027

@X10_IrrigationController::ISA          = ('X10_Item');
@X10_IrrigationController::Inherit::ISA = @ISA;

sub new {
    my ( $class, $id, $interface ) = @_;

    my $self = {};
    $$self{state} = '';

    bless $self, $class;

    $self->set_interface( $interface, $id );

    my $hc = substr( $id, 0, 1 );
    $self->{x10_hc} = $hc;

    $self->add( "X" . $hc . 'P', 'off' );

    $self->add( "X" . $hc . "1" . $hc . 'J', '1-on' );
    $self->add( "X" . $hc . "2" . $hc . 'J', '2-on' );
    $self->add( "X" . $hc . "3" . $hc . 'J', '3-on' );
    $self->add( "X" . $hc . "4" . $hc . 'J', '4-on' );
    $self->add( "X" . $hc . "5" . $hc . 'J', '5-on' );
    $self->add( "X" . $hc . "6" . $hc . 'J', '6-on' );
    $self->add( "X" . $hc . "7" . $hc . 'J', '7-on' );
    $self->add( "X" . $hc . "8" . $hc . 'J', '8-on' );
    $self->add( "X" . $hc . "9" . $hc . 'J', '9-on' );
    $self->add( "X" . $hc . "A" . $hc . 'J', '10-on' );
    $self->add( "X" . $hc . "B" . $hc . 'J', '11-on' );
    $self->add( "X" . $hc . "C" . $hc . 'J', '12-on' );
    $self->add( "X" . $hc . "D" . $hc . 'J', '13-on' );
    $self->add( "X" . $hc . "E" . $hc . 'J', '14-on' );
    $self->add( "X" . $hc . "F" . $hc . 'J', '15-on' );
    $self->add( "X" . $hc . "G" . $hc . 'J', '16-on' );

    $self->add( "X" . $hc . "1" . $hc . 'K', '1-off' );
    $self->add( "X" . $hc . "2" . $hc . 'K', '2-off' );
    $self->add( "X" . $hc . "3" . $hc . 'K', '3-off' );
    $self->add( "X" . $hc . "4" . $hc . 'K', '4-off' );
    $self->add( "X" . $hc . "5" . $hc . 'K', '5-off' );
    $self->add( "X" . $hc . "6" . $hc . 'K', '6-off' );
    $self->add( "X" . $hc . "7" . $hc . 'K', '7-off' );
    $self->add( "X" . $hc . "8" . $hc . 'K', '8-off' );
    $self->add( "X" . $hc . "9" . $hc . 'K', '9-off' );
    $self->add( "X" . $hc . "A" . $hc . 'K', '10-off' );
    $self->add( "X" . $hc . "B" . $hc . 'K', '11-off' );
    $self->add( "X" . $hc . "C" . $hc . 'K', '12-off' );
    $self->add( "X" . $hc . "D" . $hc . 'K', '13-off' );
    $self->add( "X" . $hc . "E" . $hc . 'K', '14-off' );
    $self->add( "X" . $hc . "F" . $hc . 'K', '15-off' );
    $self->add( "X" . $hc . "G" . $hc . 'K', '16-off' );

    $self->{zone_runtimes} =
      [ 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10 ];
    $self->{zone_runcount} = 0;
    $self->{zone_runnning} = 0;
    $self->{zone_delay}    = 10;
    $self->{timer}         = &Timer::new();

    return $self;
}

sub set_runtimes {
    my ($self) = shift @_;
    my $count = @_;

    if ( &Timer::active( $self->{timer} ) ) {
        print
          "X10_IrrigationController: skipping set_runtimes because of running timer\n"
          if $main::Debug{x10};
        return;
    }

    if ( $count < 1 ) {
        print
          "X10_IrrigationController: set_runtimes called without data, ignoring\n";
    }
    else {
        $self->{zone_runtimes} = [@_];
        $self->{zone_runcount} = $count;
        print "X10_IrrigationController: setting runtimes for $count zones\n"
          if $main::Debug{x10};
    }
}

sub set_rundelay {
    my ( $self, $rundelay ) = @_;

    if ( &Timer::active( $self->{timer} ) ) {
        print
          "X10_IrrigationController: skipping set_rundelay because of running timer\n"
          if $main::Debug{x10};
        return;
    }

    if ( $rundelay < 1 ) {
        print
          "X10_IrrigationController: set_rundelay called without data, ignoring\n";
    }
    else {
        $self->{zone_delay} = $rundelay;
        print "X10_IrrigationController: rundelay set to $rundelay second(s)\n"
          if $main::Debug{x10};
    }
}

sub set {
    my ( $self, $state ) = @_;

    if ( $state =~ /^(\w+):(.*)/ ) {
        $state = $1;

        if ( &Timer::active( $self->{timer} ) ) {
            print
              "X10_IrrigationController: skipping set_runtimes because of running timer\n"
              if $main::Debug{x10};
        }
        else {
            print
              "X10_IrrigationController set with times found: state=$1 times=$2\n"
              ;    # if $main::Debug{x10};
            return if &main::check_for_tied_filters( $self, $state );

            my @runtimes = split ',', $2;
            $self->set_runtimes(@runtimes);
        }
    }
    else {
        return if &main::check_for_tied_filters( $self, $state );
    }

    if ( lc($state) eq 'on' ) {
        if ( &Timer::active( $self->{timer} ) ) {
            print
              "X10_IrrigationController: skipping zone cascade because of running timer.\n"
              if $main::Debug{x10};
            return;
        }

        # Start a cascade
        $self->zone_cascade();
    }
    elsif ( lc($state) eq 'off' ) {

        # Kill any outstanding timer
        if ( &Timer::active( $self->{timer} ) ) {
            $self->{timer}->unset();
            print "X10_IrrigationController: zone_cascade aborted\n";
        }

        # Send all off to shutdown controller
        $self->all_zones_off();
    }
    else {
        # We don't special handle this command, pass it thru
        $self->X10_IrrigationController::Inherit::set($state);
    }
}

sub all_zones_off {
    my ($self) = @_;

    # Since the WGL Rain8 1-way sprinkler controller does not respond to the "All Off"
    # command we need to turn off the zone that is currently running to shutdown the
    # system.  We are tracking the currently running zone using the zone_running variable.
    if ( $main::config_parms{sprinkler_type} == "rain8_1w" ) {
        if (    $self->{zone_running} > 0
            and $self->{zone_running} <= $self->{zone_runcount} )
        {
            $self->X10_IrrigationController::Inherit::set(
                $self->{zone_running} . '-off' );
        }
    }

    $self->X10_IrrigationController::Inherit::set('off');
}

sub zone_cascade {
    my ( $self, $zone ) = @_;

    # Reuse timer for this object if it exists
    $self->{timer} = &Timer::new() unless $self->{timer};

    # Default to zone 1 (start of run)
    $zone = 1 if $zone eq undef;

    # Turn off last zone
    $self->X10_IrrigationController::Inherit::set( ( $zone - 1 ) . '-off' )
      unless $zone == 1;

    # Reset the current running zone and turn off all if starting from zone 1
    if ( $zone == 1 ) {
        $self->{zone_running} = 0;
        $self->all_zones_off();
    }

    print "Zone $zone of $self->{zone_runcount}\n" if $main::Debug{x10};

    # Print start message
    print "X10_IrrigationController: zone_cascade start\n" if ( $zone == 1 );

    # Print stop message
    print "X10_IrrigationController: zone_cascade complete\n"
      if ( $zone > $self->{zone_runcount} );

    # Make the objects state go complete if we are done
    &Generic_Item::set( $self, 'complete' )
      if ( $zone > $self->{zone_runcount} );

    # Stop now if we've run out of zones
    return if ( $zone > $self->{zone_runcount} );

    my $runtime = $self->{zone_runtimes}[ $zone - 1 ];
    if ( $runtime ne undef and $runtime > 0 ) {

        # Set a timer to turn it off and turn the next zone on
        my $sprinkler_timer = $self->{timer};
        my $object          = $self->{object_name};
        my $action = "$object->zone_delay($zone," . $runtime * 60 . ")";
        &Timer::set( $sprinkler_timer, $self->{zone_delay}, $action );
        print
          "X10_IrrigationController: Delaying zone $zone start for $self->{zone_delay} seconds\n"
          if $main::Debug{x10};
    }
    else {
        # Recursion is your friend
        zone_cascade( $self, $zone + 1 );
    }
    return;
}

sub zone_delay {
    my ( $self, $zone, $runtime ) = @_;

    # Turn the zone on
    $self->X10_IrrigationController::Inherit::set( $zone . '-on' );

    # Set a timer to turn it off and turn the next zone on
    my $sprinkler_timer = $self->{timer};
    my $object          = $self->{object_name};
    my $action          = "$object->zone_cascade(" . ( $zone + 1 ) . ")";
    &Timer::set( $sprinkler_timer, $runtime, $action );
    $self->{zone_running} = $zone;
    print "X10_IrrigationController: Running zone $zone for "
      . ( $runtime / 60 )
      . " minute(s)\n"
      if $main::Debug{x10};
    return;
}

=head1 SEE ALSO

More info at: http://ourworld.compuserve.com/homepages/rciautomation/p6.htm  This looks the same as the IrrMaster 4-zone sprinkler controller listed here: http://www.homecontrols.com/product.html?prodnum=HCLC4&id_hci=0920HC569027

=cut

package X10_Switchlinc;

=head1 NAME

B<X10_Switchlinc> - For the Switchlinc contrllers

=head1 SYNOPSIS

  # Just picked this device to use to send the clear
  $Office_Light_Torch->set("clear");
  # Send a command to each group member to make it listen
  $SwitchlincDisable->set("off");
  # Just picked this device item to send the command
  $Office_Light_Torch->set("disablex10transmit");

=head1 DESCRIPTION

Inherts all the functionality from X10_Item and adds the following states:

  'clear'
  'setramprate'
  'setonlevel'
  'addscenemembership'
  'deletescenemembership'
  'setsceneramprate'
  'disablex10transmit'
  'enablex10transmit'

Also sets the 'preset3' X10_Item option which causes the older Preset Dim commands to be used for setting the brightness level directly.

=head1 INHERITS

B<X10_Item>

=cut

@X10_Switchlinc::ISA = ('X10_Item');

sub new {
    my ( $class, $id, $interface, $type ) = @_;
    $type .= ' ' if $type;
    $type .= 'preset3';
    my $self = &X10_Item::new( $class, $id, $interface, $type );
    $id = $self->{x10_id};

    # This state group must be run separately in a sequence.  This makes using them more manual
    # then the state group listed below
    $self->add( 'XOGNGMGPGMG', 'clear' );
    $self->add( 'XOGPGNGMGMG', 'setramprate' );
    $self->add( 'XPGNGMGOGMG', 'setonlevel' );
    $self->add( 'XMGNGOGPG',   'addscenemembership' );
    $self->add( 'XOGPGMGNG',   'deletescenemembership' );
    $self->add( 'XNGOGPGMG',   'setsceneramprate' );
    $self->add( 'XMGNGPGOGPG', 'disablex10transmit' );
    $self->add( 'XOGMGNGPGPG', 'enablex10transmit' );

    # The following states are used by X10_Scene and avoid the set sequencing required by the above states
    # As a result, they are likely more safe and should be used in preference
    $self->add( ( 'XOGNGMGPGMG' . substr( $id, 1 ) . 'OGPGNGMGMG' ),
        'set ramp rate' );
    $self->add( 'XOGNGMGPGMG' . substr( $id, 1 ) . 'PGNGMGOGMG',
        'set on level' );

    #    $self-> add ('XOGNGMGPGMG' . substr($id, 1) . substr($id, 1, 1) . 'J' . 'MGNGOGPG',   'add to scene');
    $self->add( 'XOGNGMGPGMG' . substr( $id, 1 ) . 'MGNGOGPG', 'add to scene' );
    $self->add(
        'XOGNGMGPGMG'
          . substr( $id, 1 )
          . substr( $id, 1, 1 ) . 'J'
          . 'OGPGMGNG',
        'remove from scene'
    );
    $self->add( 'XOGNGMGPGMG' . substr( $id, 1 ) . 'NGOGPGMG',
        'set scene ramp rate' );
    $self->add(
        'X'
          . substr( $id, 1 )
          . substr( $id, 1, 1 ) . 'K'
          . 'OGNGMGPGMG'
          . substr( $id, 1 )
          . substr( $id, 1, 1 ) . 'J'
          . 'MGNGPGOGPG',
        'disable transmit'
    );
    $self->add(
        'X'
          . substr( $id, 1 )
          . substr( $id, 1, 1 ) . 'K'
          . 'OGNGMGPGMG'
          . substr( $id, 1 )
          . substr( $id, 1, 1 ) . 'J'
          . 'OGMGNGPGPG',
        'enable transmit'
    );

    # WARNING!! any Switchlinc, Appliancelinc, Lamplinc, Keypadlinc, Relaylinc that are plugged in
    # or active will receive the following commands and also be locked out (per Smarthome docs)
    $self->add( 'XMGOGPGNGPG', 'disable programming' );
    $self->add( 'XNGMGOGPGPG', 'enable programming' );

    return $self;
}

=head1 SEE ALSO

See the <a href="http://www.smarthome.com/manuals/2380_web.pdf>Switchlinc 2380 manual</a> for more information.

=cut

package X10_Keypadlinc;

@X10_Keypadlinc::ISA = ('X10_Item');

sub new {
    my ( $class, $id, $interface, $type ) = @_;
    my $self = &X10_Switchlinc::new( $class, $id, $interface, $type );

    return $self;
}

package X10_Lamplinc;

@X10_Lamplinc::ISA = ('X10_Item');

sub new {
    my ( $class, $id, $interface, $type ) = @_;
    my $self = &X10_Switchlinc::new( $class, $id, $interface, $type );

    return $self;
}

package X10_Relaylinc;

@X10_Relaylinc::ISA = ('X10_Item');

sub new {
    my ( $class, $id, $interface, $type ) = @_;
    my $self = &X10_Switchlinc::new( $class, $id, $interface, $type );

    $self->add(
        'XOGNGMGPGMG'
          . substr( $id, 1 )
          . substr( $id, 1, 1 ) . 'J'
          . 'PGOGMGNGOG',
        'lamp mode'
    );
    $self->add(
        'XOGNGMGPGMG'
          . substr( $id, 1 )
          . substr( $id, 1, 1 ) . 'J'
          . 'PGNGOGMGOG',
        'appliance mode'
    );

    return $self;
}

package X10_Appliancelinc;

@X10_Appliancelinc::ISA = ('X10_Item');

@preset_dim_levels = qw(M  N  O  P  C  D  A  B  E  F  G  H  K  L  I  J);

sub new {
    my ( $class, $id, $interface ) = @_;
    my $self = {};
    $$self{state} = '';
    bless $self, $class;
    $self->set_interface( $interface, $id );
    my $hc = substr( $id, 0, 1 );
    push @{ $appliances_by_house_code{$hc} }, $self;

    # Allow for unit=9,10,11..16, instead of 9,A,B,C..F
    if ( $id =~ /^\S1(\d)$/ ) {
        $id = $hc . substr 'ABCDEFG', $1, 1;
    }
    $id                          = "X$id";
    $self->{x10_id}              = $id;
    $self->{interface}->{x10_id} = $id;

    $self->add(
        'XOGNGMGPGMG'
          . substr( $id, 1 )
          . substr( $id, 1, 1 ) . 'J'
          . 'MGNGOGPG',
        'add to scene'
    );
    $self->add(
        'XOGNGMGPGMG'
          . substr( $id, 1 )
          . substr( $id, 1, 1 ) . 'J'
          . 'OGPGMGNG',
        'remove from scene'
    );
    $self->add(
        'X'
          . substr( $id, 1 )
          . substr( $id, 1, 1 ) . 'K'
          . 'OGNGMGPGMG'
          . substr( $id, 1 )
          . substr( $id, 1, 1 ) . 'J'
          . 'MGNGPGOGPG',
        'disable transmit'
    );
    $self->add(
        'X'
          . substr( $id, 1 )
          . substr( $id, 1, 1 ) . 'K'
          . 'OGNGMGPGMG'
          . substr( $id, 1 )
          . substr( $id, 1, 1 ) . 'J'
          . 'OGMGNGPGPG',
        'enable transmit'
    );

    $self->add( $id . $hc . 'J',      'on' );
    $self->add( $id . $hc . 'K',      'off' );
    $self->add( $id,                  'manual' );
    $self->add( $id . $hc . 'STATUS', 'status' );

    #1-way (receive only for these two)
    # off is MPRESET_DIM1
    $self->add( $id . $preset_dim_levels[0] . 'PRESET_DIM1', "status_off" );

    # on is JPRESET_DIM2
    $self->add( $id . $preset_dim_levels[15] . 'PRESET_DIM2', "status_on" );

    return $self;
}

package X10_TempLinc;

=head1 NAME

B<X10_TempLinc>

=head1 SYNOPSIS

  $Garage_TempLinc = new X10_TempLinc('P')

  request current temperature
  $Garage_TempLinc->set(STATUS);

  handle temperature changes as reported by the sensor
  if (state_now $Garage_TempLinc)
  {
    speak "The temperature in the garage is now $Garage_TempLinc->{state}";
  }

=head1 DESCRIPTION

This is smarthome.com part number 1625 it can be setup to request temperature with the STATUS state, or automatically send out temperature change it uses the same temperature translation that the RCS bi-directional thermostat uses.  It should use its own house code because it needs unit codes 11-16 to be used to received the preset_dim commands for temperature degrees.  However, in theory, (I haen't ried it yet), you could used the same house code with unit codes 1-10 if absolutely needed.

=head1 INHERITS

B<X10_Item>

=cut

@X10_TempLinc::ISA = ('X10_Item');

sub new {
    my ( $class, $id, $interface ) = @_;
    my $self = {};
    $$self{state} = '';
    bless $self, $class;
    $self->set_interface( $interface, $id );

    #  print "\n\nWarning: duplicate ID codes on different TempLinc objects: id=$id\n\n" if $serial_item_by_id{$id};
    my $hc = substr( $id, 0, 1 );
    push @{ $TempLinc_by_house_code{$hc} }, $self;
    $id                          = "X$id";
    $self->{x10_id}              = $id;
    $self->{interface}->{x10_id} = $id;

    # request temperature is standalone outside the loop
    # manually added a unit code here as it would not work with out one, Serial_Item expects this
    # when parsing the x10 commands.  I used '1' as the unit code as this is dedicated to a single house code.
    $self->add( $id . '1' . $hc . 'STATUS', 'status' );

    my $i = 0;

    # looping through to setup the recognized states for the object
    for my $hc (qw(M N O P C D A B E F G H K L I J)) {

        #  unit 1,2,3,9 -> send setpoint -> unused for TempLinc sensor, cannot do a setpoint
        # unit 4 -> send command -> unused for TempLinc sensor cannot send commands
        # unit 5 -> request status -> only Request Temp is allowed and doing this outside of loop
        # unit 6 -> report status -> unused for TempLinc sensor, no status to report
        # unit 10 -> echo responses -> unused for TempLinc sensor,no response to echo
        # unit 11,12,13,14,15,16 -> report temperature -> something we can use with the TempLinc
        $self->add( $id . 'B' . $hc . 'PRESET_DIM1', -60 + $i . " degrees " );
        $self->add( $id . 'B' . $hc . 'PRESET_DIM2', -44 + $i . " degrees " );
        $self->add( $id . 'C' . $hc . 'PRESET_DIM1', -28 + $i . " degrees " );
        $self->add( $id . 'C' . $hc . 'PRESET_DIM2', -12 + $i . " degrees " );
        $self->add( $id . 'D' . $hc . 'PRESET_DIM1', 4 + $i . " degrees " );
        $self->add( $id . 'D' . $hc . 'PRESET_DIM2', 20 + $i . " degrees " );
        $self->add( $id . 'E' . $hc . 'PRESET_DIM1', 36 + $i . " degrees " );
        $self->add( $id . 'E' . $hc . 'PRESET_DIM2', 52 + $i . " degrees " );
        $self->add( $id . 'F' . $hc . 'PRESET_DIM1', 68 + $i . " degrees " );
        $self->add( $id . 'F' . $hc . 'PRESET_DIM2', 84 + $i . " degrees " );
        $self->add( $id . 'G' . $hc . 'PRESET_DIM1', 100 + $i . " degrees " );
        $self->add( $id . 'G' . $hc . 'PRESET_DIM2', 116 + $i . " degrees " );

        $i++;
    }

    return $self;
}

#  Ote themostate from Ouellet Canada
package X10_Ote;

=head1 NAME

B<X10_Ote> - Supports the OTE X10 themostat from Ouellet Canada.

=head1 INHERITS

B<X10_Item>

=cut

@X10_Ote::ISA = ('X10_Item');

sub new {
    my ( $class, $id, $interface ) = @_;
    my $self = {};
    $$self{state} = '';
    bless $self, $class;
    $self->set_interface( $interface, $id );
    my $hc = substr( $id, 0, 1 );
    push @{ $ote_by_house_code{$hc} }, $self;
    $id                          = "X$id";
    $self->{x10_id}              = $id;
    $self->{interface}->{x10_id} = $id;
    $self->add( $id . $hc . 'J',                           'eco' );
    $self->add( $id . $hc . 'K',                           'normal' );
    $self->add( $id . $hc . 'J' . $hc . '+5',              'plus' );
    $self->add( $id . $hc . 'J' . $hc . '-5',              'moins' );
    $self->add( $id . $hc . 'J' . $hc . '+5' . $hc . '+5', 'plus2' );
    $self->add( $id . $hc . 'J' . $hc . '-5' . $hc . '-5', 'moins2' );
    $self->add( $id . $hc . 'J' . $hc . '+5' . $hc . '+5' . $hc . 'L',
        'plus3' );
    $self->add( $id . $hc . 'J' . $hc . '-5' . $hc . '-5' . $hc . 'M',
        'moins3' );
    $self->add( $id . $hc . 'J',  'off' );
    $self->add( $id . $hc . 'K',  'on' );
    $self->add( $id . $hc . '+5', 'brighten' );
    $self->add( $id . $hc . '-5', 'dim' );
    $self->add( $id . $hc . 'M',  'C+1' );
    $self->add( $id . $hc . 'N',  'C-1' );
    $self->add( $id . $hc . 'L',  'JN' );
    $self->add( $id,              'manual' );
    return $self;
}

## Todo:
##      + make the countdown time configurable per sensor
##      + make the action configurable per sensor

package X10_Sensor;

=head1 NAME

B<X10_Sensor>

=head1 SYNOPSIS

  $sensor_hall = new X10_Sensor('A4', 'sensor_hall', 'MS13');
  $work_room_motion = new X10_Sensor('CA', 'work_room_motion', 'motion');
  $work_room_bright = new X10_Sensor('CB', 'work_room_bright', 'brightness');

.mht table examples:

  X10MS,      XA2AJ,  sensor_bathroom,       Sensors|Upstairs
  X10MS,       A4,    sensor_hall,           Sensors|Downstairs,  MS13

  X10MS,      CA,    work_room_motion,       Sensors|Motion_Sensors,      Motion
  X10MS,      CB,    work_room_brightness,   Sensors|Brighness_Sensors,   Brightness
  X10MS,      CA,    work_room_sensors,      Sensors,                  MS13    # This detects both motion and brightness

With MS13 specified, it will return states named motion,still,light, and dark. With Motion specified, it will return only the motion and still states. With Brightness specified, it will return only the light and dark states. In all cases, methods light and dark will return the current light/dark state.

Examples:

  set_with_timer  $light1 ON, 600 if $work_room_motion eq 'motion';

  speak 'It is dark downstairs' if dark $sensor_downstairs;

Without the MS13 or Brightness type, the light/dark codes will be ignored.

=head1 DESCRIPTION

Do you have any of those handy little X10 MS12A battery-powered motion sensors? Here's your answer - use the X10_Sensor instead of the Serial_Item when you define it, and your house will notice when your sensor hasn't been tripped in 24 hours, allowing you to check on the batteries.

If you have an sensor that detects and sends codes for daytime and nighttime (light and dark levels), pass in a optional type MS13, Motion, or Brightness. For the id, you can use the 2 character, or 5 character X10 code.

=head1 INHERITS

B<X10_Item>

=cut

@X10_Sensor::ISA = ('X10_Item');

sub init {
    &::print_log("[X10_Sensor] Calling Serial_match_add_hook");
    &::Serial_match_add_hook( \&X10_Sensor::sensorhook );
    $sensorinit = 1;
}

# Note: name is require, as $self->{object_name} is not
# set yet on startup :(
sub new {
##    my ($class, $id, $name, $type) = @_;
##    my $self = X10_Item->new();
    my ( $class, $id, $name, $type, $interface ) = @_;
    print
      "[X10_Sensor] class=$class, id=$id, name=$name, interface=$interface\n"
      if $main::Debug{x10};
    my $self = X10_Item->new( $id, $interface, $type );

    $$self{state} = '';
    bless $self, $class;

    &X10_Sensor::init() unless $sensorinit;

    &X10_Sensor::add( $self, $id, $name, $type );

    restore_data $self ('dark');    # Save dark flag between restarts

    return $self;
}

sub add {
    my ( $self, $id, $name, $type ) = @_;

    $name = $id unless $name;
    $self->{name} = $name;

    # Allow for unit=9,10,11..16, instead of 9,A,B,C..F
    if ( $id =~ /^X?(\S)1(\d)/i ) {
        $id = $1 . substr 'ABCDEFG', $2, 1;
    }

    # Allow for A1 and XA1AJ
    if ( length $id < 3 ) {
        my $hc = substr $id, 0, 1;
        $id = 'X' . $id . $hc . 'J';
    }

    &::print_log(
        "[X10_Sensor] Adding X10_Sensor timer for $id, name=$name type=$type")
      if $main::Debug{x10_sensor};

    #24 hour countdown Timer
    $self->{battery_timer} = new Timer;
    $self->{battery_timer}->set(
        ( $main::config_parms{MS13_Battery_timer} )
        ? $main::config_parms{MS13_Battery_timer}
        : 24 * 60 * 60,
        (
            ( $main::config_parms{MS13_Battery_action} )
            ? $main::config_parms{MS13_Battery_action}
            : "print_log"
          )
          . " \"rooms=all Battery timer for $name expired\"",
        7
    );

    my ( $hc, $id1 ) = $id =~ /X(\S)(\S+)(\S)\S/i;
    my $id2                   = $id1;
    my ($motion_detector)     = 1;
    my ($brightness_detector) = 0;

    #   print $name, "type=$type id=$id hc=$hc id1=$id1 X$hc${id1}${hc}J \n";

    if ( $type and $type =~ /brightness/i ) {
        $motion_detector     = 0;
        $brightness_detector = 1;
    }
    if ( $type and $type =~ /motion/i ) {
        $motion_detector     = 1;
        $brightness_detector = 0;
    }
    if ( $type and $type =~ /ms13/i ) {
        $motion_detector     = 1;
        $brightness_detector = 1;
        $id2++;
        $id2 = 'A' if $id2 eq '10';
        $id2 = '1' if $id2 eq 'H';
    }
    if ( $motion_detector == 1 ) {

        #&Serial_Item::add($self, "X$hc${id1}${hc}J", 'motion');
        #&Serial_Item::add($self, "X$hc${id1}${hc}K", 'still');
        &X10_Item::add( $self, "X$hc${id1}${hc}J", 'motion' );
        &X10_Item::add( $self, "X$hc${id1}${hc}K", 'still' );
    }
    if ($brightness_detector) {

        #&Serial_Item::add($self, "X$hc${id2}${hc}K", 'light');
        #&Serial_Item::add($self, "X$hc${id2}${hc}J", 'dark');
        &X10_Item::add( $self, "X$hc${id2}${hc}K", 'light' );
        &X10_Item::add( $self, "X$hc${id2}${hc}J", 'dark' );
    }
    return;
}

sub sensorhook {
    my ( $ref, $state, $data ) = @_;

    #   print "dbx1 x10_sensor hook ref=$ref name=$state item=$data\n";

    # Match only on this item's events
    return unless $ref->{state_by_id}{$data};

    # Make sure this is a X10_Sensor item
    return unless $ref->{battery_timer};

    ( $ref->{dark} = 0 ) if $state eq 'light';
    ( $ref->{dark} = 1 ) if $state eq 'dark';

    &::print_log("X10_Sensor::sensorhook: resetting $ref->{name}")
      if $main::Debug{x10_sensor};

    # If I received something from this battery-powered transmitter, the battery
    # must still be good, so reset the countdown timer $main::config_parms{MS13_Battery_timer} hours
    # default is 24 more hours if not specified:
    $ref->{battery_timer}->set(
        ( $main::config_parms{MS13_Battery_timer} )
        ? $main::config_parms{MS13_Battery_timer}
        : 24 * 60 * 60,
        (
            ( $main::config_parms{MS13_Battery_action} )
            ? $main::config_parms{MS13_Battery_action}
            : "print_log"
          )
          . " \"rooms=all Battery timer for $ref->{name} expired\"",
        7
    );
}

sub light {
    return !$_[0]->{dark};
}

sub dark {
    return $_[0]->{dark};
}

=head1 AUTHOR

Ingo Dean

=cut

package X10_Scenemaster;

@X10_Scenemaster::ISA = ('X10_Item');

@preset_dim_levels = qw(M  N  O  P  C  D  A  B  E  F  G  H  K  L  I  J);

sub new {
    my $self         = &X10_Item::new(@_);
    my $id           = $self->{x10_id};
    my ($house_code) = $id =~ /^X(.)/;

    $self->add(
        $id . $id . $id . $id . $id . $id . $id . $id . $house_code . 'O',
        'attention' );

    # 0% is MPRESET_DIM1
    $self->add( $id . $preset_dim_levels[0] . 'PRESET_DIM1', "0%" );

    # 100% is JPRESET_DIM2
    $self->add( $id . $preset_dim_levels[15] . 'PRESET_DIM2', "100%" );

    # 30 levels, 1% to 99%
    for ( my $percent = 1; $percent <= 99; $percent++ ) {
        my $index = int( ( $percent - 1 ) * 30 / 99 ) + 1;
        my $state2 = $id
          . (
            ( $index < 16 )
            ? $preset_dim_levels[$index] . 'PRESET_DIM1'
            : $preset_dim_levels[ $index - 16 ] . 'PRESET_DIM2'
          );
        $self->add( $state2, $percent . "%" );
    }

    $self->{type} = 'preset';

    return $self;
}

package X10_Scenemaster_Controller;

@X10_Scenemaster_Controller::ISA = ('X10_Item');

sub new {
    my $self = &X10_Item::new(@_);
    my $id   = $self->{x10_id};

    $self->add( $id . '1',                         '1' );
    $self->add( $id . '2',                         '2' );
    $self->add( $id . '3',                         '3' );
    $self->add( $id . '4',                         '4' );
    $self->add( $id . '5',                         '5' );
    $self->add( $id . '6',                         '6' );
    $self->add( $id . '7',                         '7' );
    $self->add( $id . '8',                         '8' );
    $self->add( $id . '9',                         '9' );
    $self->add( $id . 'A',                         '10' );
    $self->add( $id . 'B',                         '11' );
    $self->add( $id . 'C',                         '12' );
    $self->add( $id . 'D',                         '13' );
    $self->add( $id . 'E',                         '14' );
    $self->add( $id . 'F',                         '15' );
    $self->add( $id . 'G',                         '16' );
    $self->add( $id . 'O',                         'Enter' );
    $self->add( $id . 'P',                         'Esc' );
    $self->add( $id . 'O' . $id . 'O' . $id . 'O', 'Programming Complete' );

    $self->{no_log} = 1;

    return $self;
}

package X10_Scenemaster_Advanced_Controller;

@X10_Scenemaster_Advanced_Controller::ISA = ('X10_Item');

=begin comment

Per house code.

=cut

sub new {
    my $self = &X10_Item::new(@_);
    my $id   = $self->{x10_id};

    $self->add( $id . '1', 'soft start' );
    $self->add( $id . '2', 'all lights on' );
    $self->add( $id . '3', 'all lights off' );
    $self->add( $id . '4', 'all units off' );
    $self->add( $id . '5', 'universal all lights on' );
    $self->add( $id . '6', 'universal all lights off' );
    $self->add( $id . '7', 'universal all units off' );
    $self->add( $id . '8', 'master scene enabled' );
    $self->add( $id . '9', 'receive level' );
    $self->add( $id . 'A', 'remote access' );
    $self->add( $id . 'B', 'dimming setting' );

    $self->{no_log} = 1;
    return $self;
}

package X10_Camera;

@X10_Camera::ISA = ('X10_Appliance');

sub new {
    my $self       = &X10_Appliance::new(@_);
    my $id         = $self->{x10_id};
    my $house_code = substr( $id, 1, 1 );
    my $unit_code;
    my $unit_codes = '123456789ABCDEFG';
    if ( $id =~ /[A-P](\d\d)/i ) {
        if ( $1 <= 16 and $1 > 0 ) {
            $unit_code = substr( $unit_codes, $1 - 1, 1 );
            $id = $house_code . $unit_code;
        }
        else {
            warn 'Invalid unit code';
        }
    }
    else {
        $unit_code = substr( $id, 2, 1 );
    }

    my $unit_code_index =
      ( $unit_code =~ /\d/ ) ? $unit_code : ord($unit_code) - 55;
    my $offset =
      ( int( ( $unit_code_index - 1 ) / 4 ) * 4 ) + 1;   # start of camera group

    for ( 0 .. 3 ) {
        my $i = substr( $unit_codes, $_ + $offset - 1, 1 );
        $self->add( $house_code . $i . $house_code . 'J', 'off' )
          if $i ne $unit_code;
    }
}

# This supports the 6 button remotes that have two 'on' buttons and two off
# buttons and a dim and brighten button.  The "$id" parameter should be set to
# the X10 code of the top left button, which on my version of the remote is
# labelled "On 1".
#
# E.g. $remote=new X10_6ButtonRemote('N11');
#
# valid states are '1-on', '1-off', '2-on', '2-off', 'brighten' and 'dim'

package X10_6ButtonRemote;

@X10_6ButtonRemote::ISA = ('X10_Item');

sub new {
    my ( $class, $id, $interface, $type ) = @_;

    if ( $id eq '' ) {
        warn
          'X10_6ButtonRemote You need to specify the X10 code of the first button e.g. H12';
    }

    my $self = X10_Item->new( undef, $interface, $type );
    bless $self, $class;

    my ( $hc, $unit ) = $id =~ /^([A-P])(\d+)/;

    if ( $unit < 1 or $unit > 16 ) {
        warn 'Invalid unit code $id';
    }

    my $unitcodes = '123456789ABCDEFG';

    my $unitcode = substr( $unitcodes, $unit - 1, 1 );

    $self->add( 'X' . $hc . $unitcode . $hc . 'J',   '1-on' );
    $self->add( 'X' . $hc . $unitcode . $hc . 'K',   '1-off' );
    $self->add( 'X' . $hc . $unitcode . $hc . '+10', 'brighten' );
    $self->add( 'X' . $hc . $unitcode . $hc . '-10', 'dim' );
    $unit++;
    $unitcode = substr( $unitcodes, $unit - 1, 1 );
    $self->add( 'X' . $hc . $unitcode . $hc . 'J',   '2-on' );
    $self->add( 'X' . $hc . $unitcode . $hc . 'K',   '2-off' );
    $self->add( 'X' . $hc . $unitcode . $hc . '+10', 'brighten' );
    $self->add( 'X' . $hc . $unitcode . $hc . '-10', 'dim' );
    return $self;
}

return 1;
