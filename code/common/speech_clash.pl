# Category = MisterHouse

#@ On some systems, when two or more speech events are too close, only the first will be
#@ granted access to the audio device. The second and third may cause the PA relays to be
#@ set for their speech events, even though they cannot speak, and the first event hasn't
#@ finished. This may cause speech to start in one room, and finish speaking in another.
#@ This code creates a "queue" of speak calls, and runs them when "is_speaking()" is false.
#@ Seems to be necessary with Cepstral's Theta under Unix.

=begin comment
@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@

File:
	speech_clash.pl

Description:
	Resolves issues of two or more speech events trying to run overlapping

Author:
	Steve Switzer
	steve@switzerny.org

Date:
	April 24, 2004

License:
	This free software is licensed under the terms of the GNU public license.

Special Thanks to:
	Bruce Winter - MH, and much programming help

@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
=cut

my $sc_delay = $config_parms{speech_clash_delay};
$sc_delay = 2 unless $sc_delay;

sub speak_clash_stub {
    my ($ref) = @_;
    &print_log("Clash control stub called!") if $main::Debug{voice};
    if ( 1 == &Voice_Text::is_speaking() && $ref->{to_file} eq '' ) {
        if ( $main::Debug{voice} ) {
            $ref->{clash_retry} = 0 unless $ref->{clash_retry};
            $ref->{clash_retry}++;    #To track how many loops are made
            &print_log(
                "SPEECH_CLASH($ref->{clash_retry}): Delaying speech call for "
                  . $ref->{text}
                  . "\n" );
        }
        $ref->{nolog} = 1;            #To stop MH from logging the speech again
        delete( $ref->{web_hook} );
        delete( $ref->{audreySpeakRooms} );

        #Method One:
        my $parmstxt;
        my ( $pkey, $pval );

        while ( ( $pkey, $pval ) = each( %{$ref} ) ) {
            $parmstxt .= ', ' if $parmstxt;

            # WLA: quote the text, otherwise if the spoken text contains a ' character we
            # get an error message
            $parmstxt .= "$pkey => q($pval)";
        }
        &print_log("SPEECH_CLASH Parameters: $parmstxt") if $main::Debug{voice};
        &run_after_delay( $sc_delay, "speak(" . $parmstxt . ")" );

        #Method Two - Doesn't work :(
        #      run_after_delay $sc_delay, sub {&speak(%{$ref})}; #Doesn't work :(

        $ref->{no_speak} = 1;    #To stop MH from speaking this time around
        return;
    }

    if ( $ref->{clash_retry} ) {
        &print_log("SPEECH_CLASH: Resolved, continuing speech.")
          ;                      # if $main::Debug{voice};
        $is_speaking      = 0;
        $is_speaking_flag = 0;
    }
}
if ($Reload) {
    print_log("SPEECH_CLASH: Hooking into speech events");
    &Speak_parms_add_hook( \&speak_clash_stub );
}

=begin comment
@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
End of speech_clash.pl
@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
=cut
