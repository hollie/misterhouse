# Category = X10

#@ This module controls an X10 switched battery charger.

=begin comment

 On the first press of A16on, B2 switchs on for 7 hours, on the second press
 it increases the duration to 14 hours, at the third press to 21 hours.
 each press gets a spoken prompt of the charge time.
 Pressing A16off cancels the charge timer, with a cancellation voice prompt.
 At the end of the charge period B2 is switched off, with a voice prompt.

 Many thanks to Amauri Viguera, Bruce Winter and Trey Hilyard for their
help.

=cut

$charger_command = new X10_Appliance 'A16';
$charger_device  = new X10_Appliance 'B2';

hidden $charger_device 1;
my $charger_hours;

if ( $state = state_now $charger_command) {
    if ( $state eq ON ) {
        $charger_hours += 7;
        if ( $charger_hours <= 21 ) {
            set_with_timer $charger_device ON, $charger_hours * 60 * 60;
            speak "Battery charger has been set for $charger_hours hours";
        }
    }
    if ( $state eq OFF ) {
        set $charger_device OFF;
        $charger_hours = 0;
        speak 'Battery charger cycle has been cancelled';
    }
}

# extra bit needed to reset the hours and give a voice prompt

if ( $state = state_now $charger_device) {
    if ( $state eq OFF and $charger_hours > 0 ) {
        $charger_hours = 0;
        speak 'Battery charger cycle has ended';
    }
}
