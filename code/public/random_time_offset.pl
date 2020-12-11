#
# Random Time Offset
# (C) 2002 Jeff Siddall
# jeff@thesiddalls.net
#
# This script generates random time offsets for all keys in the hash
# %Random_Time.  The hash should contains pairs of variables and offset times.
# Values are relative (+/-X:XX format) and can be directly appended to an
# absolute value in a time_now function.
# This script runs once a day and whenever MH is in startup.
#
# For example, add a declaration like this in the script that contains your
# time_now calls:
#
# my %Random_Time =
# (
#    Living_Room_Lights_On => 0,
#    Living_Room_Lights_Off => 0
# );
#
# Then use a test like this in your script:
#
# if (time_now "$Time_Sunset $Random_Time{\"Living_Room_Lights_On\"}")
# {
#    set $Living_Room_Lights ON;
# }

# Variance sets the range of randomness, in minutes (range = +/- $Random_Variance/2)
my $Random_Variance = 30;
my $Random_Number   = 0;
my $Random_Value    = '0:00';

if ( ($New_Day) || ($Startup) ) {
    print_log "Random Time Offset: Generating new random time offsets...";
    for ( keys %Random_Time ) {

        # Generate a random number
        $Random_Number =
          ( int( rand($Random_Variance) ) - ( $Random_Variance / 2 ) );

        # Decide on the formatting prefix required for proper offset
        if ( $Random_Number > 9 ) {
            $Random_Value = '+0:';
        }
        elsif ( $Random_Number >= 0 ) {
            $Random_Value = '+0:0';
        }
        elsif ( $Random_Number < -9 ) {
            $Random_Value = '-0:';
        }
        elsif ( $Random_Number < 0 ) {
            $Random_Value = '-0:0';
        }

        # Append the actual number to the formatting prefix
        $Random_Time{"$_"} = $Random_Value . abs($Random_Number);
        print_log "$_ offset is $Random_Time{\"$_\"}";
    }
}
