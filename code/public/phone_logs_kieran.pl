
$v_phone_summarize = new Voice_Cmd('[Summarize,Itemize] Recent Call Log');
if ( $state = said $v_phone_summarize) {
    open( CALLLOG, "$config_parms{code_dir}/data/phone/logs/calllog.log" )
      ;    # Open for input
    @callloglines = <CALLLOG>;    # Open array and
                                  # read in data
    close CALLLOG;                # Close the file
    my ( $FirstPhoneLogDate, $LastPhoneLogDate, %CallerKeys, $Summary_Message,
        $key );

    $NumofCalls = 0;

    print_log "Summarized Recent Callers.";

    foreach $CallLogTempLine (@callloglines) {
        $NumofCalls = 1 + $#callloglines;

        ( $PhoneDateLog, $PhoneTimeLog, $PhoneNameLog, $PhoneNumberLog ) =
          ( split( '`', $CallLogTempLine ) )[ 0, 1, 2, 3 ];
        $PhoneNameLog =~ s/^ ?//;
        $PhoneNameLog =~ s/^O$/ Unknown Name Unknown Number/;
        $FirstPhoneLogDate = $PhoneDateLog unless $FirstPhoneLogDate;

        $LastPhoneLogDate = $PhoneDateLog;
        #
        #       $CallerKeys{$PhoneNameLog} += $CallerKeys{$PhoneNameLog} ? 1 : 0;
        if ( $CallerKeys{$PhoneNameLog} > 0 ) {
            $CallerKeys{$PhoneNameLog} += 1;
        }
        else {
            $CallerKeys{$PhoneNameLog} = 1;
        }
    }
    $Summary_Message =
      "The Recent Call Log contains $NumofCalls entries between $FirstPhoneLogDate and $LastPhoneLogDate.\n\n";

    foreach $key ( sort keys %CallerKeys ) {
        $Summary_Message .=
          plural( $CallerKeys{$key}, 'call' ) . " from $key.\n"
          if ( $state eq 'Itemize' );
    }

    speak $Summary_Message ;
}

=comment


###################################
# SAMPLE OUTPUT
###################################

05/27/2001 12:20:30 PM Running: Summarize Recent Call Log
05/27/2001 12:20:30 PM Summarized Recent Callers.
normal: The Recent Call Log contains 32 entries between Friday, May 25th
and Sunday, May 27th.

1 call from  Unknown Name Unknown Number.
1 call from Corp Ggls.

=cut

