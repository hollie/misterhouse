
=begin comment

This is my .mht entry: 

X10MS,  F3,     Kitchen_Motion,         Hidden,                 MS13
#X10A,   F4,     Kitchen_Darkness,       Hidden

The second line here (F4) is not required, but I left it here to alert me
that F4 was being used with F3 by the MS13 defined in the line above.

=cut

my $Kitchen_Motion_state;
if ( $state = state_now $Kitchen_Motion) {
    if ( $Kitchen_Motion_state ne $state ) {
        if ( $state eq 'motion' ) {
            speak "Someone's in the Kitchen.";
            $Kitchen_Motion_state = $state;
        }
        if ( $state eq 'still' ) {
            speak "The Kitchen is quiet.";
            $Kitchen_Motion_state = $state;
        }
        if ( $state eq 'dark' ) {
            speak "The Kitchen is dark.";
            $Kitchen_Darkness_state = $state;
        }
        if ( $state eq 'light' ) {
            speak "The Kitchen is lit.";
            $Kitchen_Darkness_state = $state;
        }
    }
}

# Here is an example if quering the dark/light state

speak 'It is dark  in the kitchen' if $New_Hour and dark $Kitchen_Motion;
speak 'It is light in the kitchen' if $New_Hour and light $Kitchen_Motion;
