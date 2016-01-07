
=begin comment

Post from Krik Bauer on 10/2004:

> We do a lot of entertaining (especially from Nov through Dec)
and I have a
> lot of the house automated with X10, Audio, etc... through MisterHouse
> (THANKS!!!!). However, I want things to work differently when we are
> entertaining (for example keeping lights on longer as we tend
to keep the
> party going until late at night).

Here is what I have... the major code is below, but I also use
party_mode for:
   - Influencing my HVAC settings
   - Preventing certain lights from turning on/off automatically
(this object
     is used along with the occupancy/predictive lighting code)
         my $only_without_party_mode = new Light_Restriction_Item();
         $only_without_party_mode->attach_object($party_mode, 'disabled');
         $$only_without_party_mode{object_name} =
'only_without_party_mode';

# My .mth entry for the switch (which also shows status of mode)
X10I,       N6,     party_mode_switch

=cut

$party_mode = new Generic_Item;
$party_mode->set_states( 'enabled', 'disabled' ) if $Reload;

$cmd_party_mode = new Voice_Cmd 'Party Mode';
$cmd_party_mode->set_info('Turn on party mode.');
if ( said $cmd_party_mode) {
    set $party_mode 'enabled';
}

$cmd_no_party_mode = new Voice_Cmd 'No Party Mode';
$cmd_no_party_mode->set_info('Turn off party mode.');
if ( said $cmd_no_party_mode) {
    set $party_mode 'disabled';
}

sub PartyLightsOn {
    set $kitchen_lights ON;
    set $kitchen_table_light ON;
    set $fr_lamp ON;
    set $dr_fan_light ON;
    set $fr_track_lighting '50%';
    set $party_mode_switch ON;
    set $lr_curio_cabinet ON;
    set $hutch_light ON;
    set $front_porch_lights ON;
    set $back_landscape ON;
    set $front_landscape ON;
}

# Turns rest of lights on when it gets darker out
if ( time_now("$Time_Sunset - 0:30") ) {
    if ( state $party_mode eq 'enabled' ) {
        &PartyLightsOn();
    }
}

if ( $state = state_now $party_mode) {
    if ( $state eq 'enabled' ) {
        speak(
            'rooms'      => 'kitchen',
            'importance' => 'important',
            'text'       => 'Party Mode Enabled'
        );
        set $kitchen_lights ON;
        set $kitchen_table_light ON;
        if ( time_greater_than("$Time_Sunset - 0:30") ) {
            &PartyLightsOn();
        }
        set $party_mode_switch ON;
    }
    elsif ( $state eq 'disabled' ) {
        speak(
            'rooms'      => 'kitchen',
            'importance' => 'important',
            'text'       => 'Party Mode Disabled'
        );
        set $kitchen_lights OFF;
        set $dr_fan_light OFF;
        set $fr_track_lighting OFF;
        set $party_mode_switch OFF;
        set $lr_curio_cabinet OFF;
        set $hutch_light OFF;
        set $back_landscape OFF;
        &Check_Front_Porch_Lights();
    }
}

if ( $state = state_now $party_mode_switch) {
    if ( get_set_by $party_mode_switch eq 'serial' ) {
        if ( $state eq ON ) {
            set $party_mode 'enabled';
        }
        elsif ( $state eq OFF ) {
            set $party_mode 'disabled';
        }
    }
}
