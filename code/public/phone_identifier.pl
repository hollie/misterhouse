# Category=Phone

use Telephony_Interface;
use CID_Lookup;
use CID_Log;
use CID_Announce;
use Telephony_Identifier;

my $identifier =
  new Telephony_Identifier( 'Identifier', $config_parms{identifier_port} );

$cid_lookup = new CID_Lookup($identifier);
$cid_log    = new CID_Log($cid_lookup);
$cid_announce =
  new CID_Announce( $cid_lookup, 'Call from $name. Phone call is from $name' );

#$dtmf_item      = new Telephony_DTMF($identifier);

$identifier_init = new Voice_Cmd('Init the Identifier CallerID');
if ( $state = state_now $identifier_init) {
    $identifier->init();
}

# for testing
if (0) {
    $cid_interface_test =
      new Voice_Cmd('Test callerid [onhook,ring,answer,offhook,cid,o,o2]');
    if ( defined( $state = state_now $cid_interface_test) ) {
        set_test $identifier '+2,0,001'
          if $state eq 'onhook';    #On Hook, idle  (hangup)
        set_test $identifier '+2,1,001' if $state eq 'ring';    #ring start
        set_test $identifier '+2,3,001'
          if $state eq 'answer';    #Incoming call answered on line 1
        set_test $identifier '+2,4,001'
          if $state eq 'offhook';    #offhook outgoing
        set_test $identifier '+1,5851234567,Identifier test,001'
          if $state eq 'cid';
        set_test $identifier '+1,9543441234,O,001' if $state eq 'o';
        set_test $identifier '+4,O,001'            if $state eq 'o2';
    }
}

# Allow for user specified hooks
$cid_lookup->tie_event( 'cid_handler($state, $object)',  'cid' )     if $Reload;
$identifier->tie_event( 'hook_handler($state, $object)', 'offhook' ) if $Reload;
$identifier->tie_event( 'hook_handler($state, $object)', 'onhook' )  if $Reload;
$identifier->tie_event( 'ring_handler($state, $object)', 'ring' )    if $Reload;

sub cid_handler {
    my ( $p_state, $p_setby ) = @_;

    return unless $p_state eq 'cid';

    print_log "CID handler: "
      . $p_setby->cid_name() . ' '
      . $p_setby->cid_number();

    my_cid_handler();

    my $msg = "\n\nPhone Call on $Time_Date";
    $msg .= "\nLine: " . $p_setby->address();
    $msg .= "\nFirst: " . $p_setby->first() unless $p_setby->first() eq /OUT/;
    $msg .= "\nMiddle: " . $p_setby->middle() if $p_setby->middle();
    $msg .= "\nLast: " . $p_setby->last() unless $p_setby->last() eq /OF/;
    $msg .= "\nName: " . $p_setby->cid_name();
    $msg .= "\nType: " . $p_setby->cid_type();
    $msg .= "\nCat: " . $p_setby->category();
    $msg .= "\nNumber: " . $p_setby->number();

    #$msg .= "\nArea: "   . $p_setby->areacode();
    #$msg .= "\nPref: "   . $p_setby->prefix();
    #$msg .= "\nSuff: "   . $p_setby->suffix();
    $msg .= "\nCity: " . $p_setby->city()       if $p_setby->city();
    $msg .= "\nState: " . $p_setby->cid_state() if $p_setby->state();
    display
      text        => $msg,
      time        => 0,
      title       => 'CallerID log',
      width       => 37,
      height      => 30,
      window_name => 'CallerID',
      append      => 'top',
      font        => 'fixed';
}

my $phone_count;
my $isReject;
$timer_hangup = new Timer;

#$timer_reset = new Timer;

#$identifier->tie_event('$kitchen_light->set_with_timer(ON,1)','ring');

#if (said $identifier 'ring') {
#	print "[RING]\n";
#}

#if (said $identifier 'cid') {
sub my_cid_handler {
    my ( $cid_name, $cid_number, $caller, $fnumber );
    $cid_name   = $identifier->cid_name();
    $cid_number = $identifier->cid_number();
    $fnumber    = $cid_lookup->formated_number();
    $caller     = $cid_lookup->cid_name();

    print "[CID] Name:$cid_name ($caller) . Num:$cid_number\n";

    if ( $identifier->cid_number() eq '5855551212' and !$Save{at_home} ) {

        #	    set $TX10 'Setback Off';
        #       set $TX10 '72 degrees' if $Date_Now eq 'Fri, Mar 28';
        print_log("hvac setback now off per cell phone");

        #		my $msg = "Setback is now OFF. Current temp=$Analog{temp_computer_room}";
        #		send_alpha_page ($msg);
    }
    elsif (
            $Save{telemarketHangup}
        and $cid_lookup->category ne 'friend'
        and (  $cid_lookup->category eq 'reject'
            or $cid_number eq 'OUT OF AREA'
            or $cid_name eq 'OUT OF AREA'
            or $identifier->cid_type() =~ /^[UP]$/ )
      )
    {

        $isReject = 1;

        #print_log "$caller ($PhoneName,$identifier->cid_number()) is calling, and matches the telemarketeer profile";
        speak "Hanging up on a phone salesman";

        #answer and then hangup in 5 secs
        &Serial_Item::send_serial_data( $config_parms{callerid_name}, 'ATA' );

        #set_test $identifier 'ATA';
        set $timer_hangup 5, sub {
            &Serial_Item::send_serial_data( $config_parms{callerid_name},
                'ATH' );
        };
    }
    elsif (!$Save{at_home}
        and $cid_lookup->category ne 'reject'
        and $cid_name ne 'OUT OF AREA'
        and $cid_number ne 'OUT OF AREA' )
    {

        my $msg = "mh:$cid_name ($fnumber)";
        send_alpha_page($msg);

        open( CID, ">$config_parms{html_dir}/mh_craig/cid.html" ); # web display
        print CID
          "<html><META HTTP-EQUIV='refresh' content='60;URL=/mh_craig/index.html'> <body bgcolor=black><br><br><br><br><br><br>";
        print CID "<center><table><TR><TD><font face=arial size=7 color=lime>";
        print CID
          "$caller <br>$cid_name <br>$fnumber <br>$Date_Now <br>$Time_Now <br>";
        print CID "</td></tr></table></center>  </body></html>";
        close CID;

        open( CID, ">$config_parms{html_dir}/mh_craig/cidsmall.html" )
          ;                                                        # web display
        print CID "<html><body bgcolor=black><br>";
        print CID
          "<center><table><TR><TD><font face=arial size=5 color=lime><b>";
        print CID
          "$caller <br>$cid_name $fnumber <br><br>$Date_Now at $Time_Now <br>";
        print CID "</td></tr></table></center>  </body></html>";
        close CID;
    }

    $phone_count++;
    open( CALL_LOG, ">>$config_parms{data_dir}/phone/recentcalls.log" )
      ;                                                            # Log it
    print CALL_LOG "$Date_Now`$Time_Now`"
      . $cid_lookup->cid_name() . "`"
      . $identifier->cid_number() . "\n";
    close CALL_LOG;
}

sub ring_handler {
    my ( $p_state, $p_setby ) = @_;

    my $rings = $p_setby->ring_count();
    print "ring_handler: rings:$rings\n" if $Debug{phone};

    return unless $rings == 1;

    print "muting on ring 1\n";
    handle_mute(ON);
}

sub hook_handler {
    my ( $p_state, $p_setby ) = @_;

    # mute/unmute the TV/Stereo when phone is used
    if ( $p_state eq 'onhook' ) {
        print "hook_handler:onhook\n" if $Debug{phone};
        handle_mute(OFF);
    }
    else {
        print "hook_handler:offhook\n" if $Debug{phone};
        handle_mute(ON);

        #speak (card => 2,
        #	text => "hello this is misterhouse speaking to the person calling");
    }
}

$v_phone_lastcaller = new Voice_Cmd('Show Recent Call Log');
if ( said $v_phone_lastcaller) {
    my ( @CALL_LOGlines, $CALL_LOGTempLine, $RejLogTempLine );
    my ($NumofCalls);
    my ( $PhoneDateLog, $PhoneTimeLog, $PhoneNameLog, $PhoneNumberLog );
    my ( $last, $first, $middle, $areacode, $local_number, $caller );

    open( CALL_LOG, "$config_parms{data_dir}/phone/recentcalls.log" )
      ;    # Open for input
    @CALL_LOGlines = <CALL_LOG>;    # Open array and
                                    # read in data
    close CALL_LOG;                 # Close the file

    print_log "Announced Recent Callers.";

    $NumofCalls = 0;

    foreach $CALL_LOGTempLine (@CALL_LOGlines) {
        $NumofCalls++;
        chomp $CALL_LOGTempLine;
        ( $PhoneDateLog, $PhoneTimeLog, $PhoneNameLog, $PhoneNumberLog ) =
          ( split( '`', $CALL_LOGTempLine ) )[ 0, 1, 2, 3 ];

        $PhoneNumberLog =~ s/^$config_parms{local_area_code}(.+)/$1/s;

        #if ((length($PhoneNumberLog) == 7)) {$PhoneNumberLog = substr($PhoneNumberLog, 0, 3) . "." . substr($PhoneNumberLog, 3, 4)};
        #if ((length($PhoneNumberLog) == 10)) {$PhoneNumberLog = substr($PhoneNumberLog, 0, 3) . "." . substr($PhoneNumberLog, 3, 3) . "." . substr($PhoneNumberLog, 6, 4)};
        $PhoneNumberLog =~ s/([0-9])/$1 /g;

        $PhoneNumberLog = '' if $PhoneNumberLog eq 'OUT OF AREA';

        if (    $PhoneNameLog eq 'OUT OF AREA'
            and $PhoneDateLog ne $Date_Now
            and $PhoneNumberLog eq '' )
        {
            speak
              "At $PhoneTimeLog on $PhoneDateLog, an unidentified party called.";
        }
        elsif ( $PhoneNameLog eq 'OUT OF AREA'
            and $PhoneDateLog eq $Date_Now
            and $PhoneNumberLog eq '' )
        {
            speak "At $PhoneTimeLog, an unidentified party called.";
        }
        elsif ( $PhoneNameLog eq 'OUT OF AREA'
            and $PhoneDateLog ne $Date_Now
            and $PhoneNumberLog ne '' )
        {
            speak
              "At $PhoneTimeLog on $PhoneDateLog, an unidentified party called. Call back at $PhoneNumberLog.";
        }
        elsif ( $PhoneNameLog eq 'OUT OF AREA'
            and $PhoneDateLog eq $Date_Now
            and $PhoneNumberLog ne '' )
        {
            speak
              "At $PhoneTimeLog, an unidentified party called. Call back at $PhoneNumberLog.";
        }
        elsif ( $PhoneNameLog eq 'PRIVATE'
            and $PhoneDateLog ne $Date_Now
            and $PhoneNumberLog ne '' )
        {
            speak "At $PhoneTimeLog on $PhoneDateLog, a private party called.";
        }
        elsif ( $PhoneNameLog eq 'PRIVATE'
            and $PhoneDateLog eq $Date_Now
            and $PhoneNumberLog ne '' )
        {
            speak "At $PhoneTimeLog, a private party called.";
        }
        elsif ( $PhoneNameLog ne 'OUT OF AREA' and $PhoneDateLog ne $Date_Now )
        {
            speak
              "At $PhoneTimeLog on $PhoneDateLog, $PhoneNameLog called. Call back at $PhoneNumberLog.";
        }
        elsif ( $PhoneNameLog ne 'OUT OF AREA' and $PhoneDateLog eq $Date_Now )
        {
            speak
              "At $PhoneTimeLog, $PhoneNameLog called. Call back at $PhoneNumberLog.";
        }
    }
    speak "$NumofCalls total calls." if $NumofCalls;

    #run_voice_cmd 'Clear Recent Call Log';
}

$v_phone_clearlog = new Voice_Cmd('Clear Recent Call Log');
if ( said $v_phone_clearlog) {
    open( CALL_LOG, ">$config_parms{data_dir}/phone/recentcalls.log" )
      ;    # CLEAR Log
    close CALL_LOG;
    print_log "Recent Call Log Cleared.";

    #speak "Call Log Cleared.";
}

if ( $Tk_results{'Phone Search'} ) {
    print_log "Searching for $Tk_results{'Phone Search'}";

    # Search data logged from incoming caller id data.
    my ( $count1, $count2, %results ) =
      &search_dbm( "$config_parms{data_dir}/phone/callerid.dbm",
        $Save{phone_search} );

    # Also search in array created from mh.ini caller_id_file data
    while ( my ( $key, $value ) = each %Caller_ID::name_by_number ) {
        if (   $key =~ /$Save{phone_search}/i
            or $value =~ /$Save{phone_search}/i )
        {
            $value =
              &read_dbm( "$config_parms{data_dir}/phone/callerid.dbm", $key )
              ;    # Use dbm data for consistency
            $results{$key} = $value;
        }
    }
    $count2 = keys %results;   # Reset count, in case Caller_ID search found any

    if ($count2) {
        my $results;
        for ( sort keys %results ) {
            my ( $cid_number, $cid_date, $cid_name ) =
              $results{$_} =~ /(\S+) (.+) name=(.+)/;
            $cid_name = $Caller_ID::name_by_number{$_}
              if $Caller_ID::name_by_number{$_};
            $results .= sprintf( "%13s calls=%3s last=%26s %s\n",
                $_, $cid_number, $cid_date, $cid_name );
        }

        #       map {$results .= "   $_: $results{$_}\n\n"} sort keys %results;
        display "Results:  $count2 out of $count1 records matched\n\n"
          . $results, 120, 'Phone Search Results', 'systemfixed';
    }
    else {
        display "\n      No match found\n", 5, 'Phone Search Results';
    }

    #   run qq[get_tv_info -times all -dates "$Save{tv_days}" -keys "$Save{tv_search}"];
    #   set_watch $f_tv_file;
    undef $Tk_results{'Phone Search'};
}

# Show phone logs
$v_phone_log = new Voice_Cmd('Show the phone log');
if ( said $v_phone_log) {
    print "running display_callers\n";
    undef @ARGV;

    # Much faster to 'do' than to 'run'
    do "$Pgm_Path/display_callers";
}

if ($New_Month) {

    speak "Backing up phone logs" unless $Save{sleeping_parents};

    my $dbm_file = "$config_parms{data_dir}/data/phone/callerid.dbm";
    $dbm_file =~ s|/|\\|g if $OS_win;    # System calls need dos pathnames :(

    print_log "Backing up phone log to logs $dbm_file.$Year_Month_Now";

    copy( "$dbm_file", "$dbm_file.$Year_Month_Now" )
      or print_log "Error in phone dbm copy 1: $!";

    # dbm_copy will delete any bad entries (those with binary characters) from the file.
    system("dbm_copy $dbm_file");
    copy( "$dbm_file.backup", "$dbm_file" )
      or print_log "Error in phone dbm copy 2: $!";

}
