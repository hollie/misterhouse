############################################################
#  Klier Home Automation - Caller ID Module for Rockwell   #
#  Version 2.1a Release                                    #
#  By: Brian J. Klier, N0QVC                               #
#  Thanks for the mucho help from: Bruce Winter            #
#  E-Mail: klier@lakes.com                                 #
#  Webpage: http://www.faribault.k12.mn.us/brian           #
############################################################

# Category=Phone

# Modem Caller ID Information looks like the following
# DATE = 990305
# TIME = 1351
# NMBR = 5073336399
# NAME = KLIER BRIAN J

# Declare Variables
use vars qw($PhoneName $PhoneNumber $PhoneTime $PhoneDate);

my ( $PhoneModemString, $NameDone,   $NumberDone, $i,        $j );
my ( @rejloglines,      $NumofCalls, $callerba,   $callerbn, $PhoneNumberz );
my ( @callloglines, $CallLogTempLine, $RejLogTempLine );
my ( $PhoneDateLog, $PhoneTimeLog, $PhoneNameLog, $PhoneNumberLog );
my ( $last, $first, $middle, $areacode, $local_number, $caller );

$phone_modem =
  new Serial_Item( 'ATE1V1X4&C1&D2S0=0+VCID=1', 'init', 'serial3' );
$timer_hangup = new Timer;

#-----> Provide PalmPad Controller Access for some Items
$request_phone_stuff = new X10_Item('A6');

# Web Interface Commands

$v_phone_lastcaller = new Voice_Cmd('Show Recent Call Log');
if ( ( said $v_phone_lastcaller) || ( state_now $request_phone_stuff eq 'on' ) )
{
    open( CALLLOG, "$config_parms{data_dir}/calllog.log" );    # Open for input
    @callloglines = <CALLLOG>;                                 # Open array and
                                                               # read in data
    close CALLLOG;                                             # Close the file

    print_log "Announced Recent Callers.";

    $NumofCalls = 0;

    foreach $CallLogTempLine (@callloglines) {
        $NumofCalls = $NumofCalls + 1;
        ( $PhoneDateLog, $PhoneTimeLog, $PhoneNameLog, $PhoneNumberLog ) =
          ( split( '`', $CallLogTempLine ) )[ 0, 1, 2, 3 ];
        if ( $PhoneNameLog eq 'Out of the Area' and $PhoneDateLog ne $Date_Now )
        {
            speak
              "At $PhoneTimeLog on $PhoneDateLog, an unidentified party called.";
        }
        if ( $PhoneNameLog eq 'Out of the Area' and $PhoneDateLog eq $Date_Now )
        {
            speak "At $PhoneTimeLog, an unidentified party called.";
        }
        if ( $PhoneNameLog ne 'Out of the Area' and $PhoneDateLog ne $Date_Now )
        {
            speak
              "At $PhoneTimeLog on $PhoneDateLog, $PhoneNameLog called. Call back at $PhoneNumberLog.";
        }
        if ( $PhoneNameLog ne 'Out of the Area' and $PhoneDateLog eq $Date_Now )
        {
            speak
              "At $PhoneTimeLog, $PhoneNameLog called. Call back at $PhoneNumberLog.";
        }
    }
    speak "$NumofCalls total calls.";
}

$v_phone_clearlog = new Voice_Cmd('Clear Recent Call Log');
if ( ( said $v_phone_clearlog) || ( state_now $request_phone_stuff eq 'off' ) )
{
    open( CALLLOG, ">$config_parms{data_dir}/calllog.log" );    # CLEAR Log
    close CALLLOG;
    print_log "Call Log Cleared.";
    speak "Call Log Cleared.";
}

#$v_phone_log = new Voice_Cmd('Run Display Callers');
#if (said $v_phone_log) {
#    print_log "Running Display Callers...";
#    undef @ARGV;
#    do "$Pgm_Path/display_callers";
#    print_log "Done.";
#}

# Set MODEM Init Strings on Startup

if ( $Startup or $Reload ) {
    set $phone_modem 'init';    # Initialize MODEM

    open( REJLOG, "$config_parms{data_dir}/rejlog.log" );    # Open for input
    @rejloglines = <REJLOG>;                                 # Open array and
                                                             # read in data
    close REJLOG;                                            # Close the file

    print_msg "Caller ID Interface has been Initialized...";
    print_log "Caller ID Interface has been Initialized...";
}

# Timer Information for Phone Hangup (Reject List)

if ( expired $timer_hangup) {
    set $phone_modem 'ATH';
    set $timer_hangup 0;
}

# Display Incoming Serial Data

if ( $PhoneModemString = said $phone_modem) {
    print_msg "PHONE: $PhoneModemString";

    #if (substr($PhoneModemString, 0, 4) eq 'RING') {
    #run_voice_cmd "Stop Music";
    #run_voice_cmd "Set mp3 player to Stop";
    #set $boombox_bedroom 'off';
    #}

    if ( substr( $PhoneModemString, 0, 4 ) eq 'NAME' ) {
        $NameDone = "yes";
        $PhoneName = ( substr( $PhoneModemString, 7, 15 ) );
    }

    if ( substr( $PhoneModemString, 0, 4 ) eq 'NMBR' ) {

        # Switch name strings so first last, not last first.
        # Use only the 1st two blank delimited fields, as the 3rd, 4th are usually just initials or incomplete
        # Last First M
        # Last M First

        ( $last, $first, $middle ) = ( split( ' ', $PhoneName ) )[ 0, 1, 2 ];
        $first = ucfirst( lc($first) );
        $first = ucfirst( lc($middle) )
          if length($first) == 1;    # Last M First format
        $last = ucfirst( lc($last) );

        $NumberDone   = "yes";
        $PhoneNumber  = ( substr( $PhoneModemString, 7, 10 ) );
        $areacode     = ( substr( $PhoneNumber, 0, 3 ) );
        $local_number = ( substr( $PhoneNumber, 3, 7 ) );
        $PhoneNumberz = $PhoneNumber;
        $PhoneNumberz =~ s/\s//;
        if ( $callerbn = $Caller_ID::name_by_number{$PhoneNumberz} ) {
            $caller = $callerbn;
        }
        else {
            $caller = "$first $last";
        }

        if ( $PhoneNumber eq "O" ) {
            $PhoneNumber  = "";
            $areacode     = "";
            $local_number = "";
        }
    }

    if ( substr( $PhoneModemString, 0, 13 ) eq 'MESG = 08014F' ) {
        $NameDone   = "yes";
        $NumberDone = "yes";
        $PhoneName  = "Out of the Area";
        $caller     = "Out of the Area";
    }

    if ( $NumberDone eq "yes" and $NameDone eq "yes" ) {
        $NumberDone = 0;
        $NameDone   = 0;
        $PhoneDate  = $Date_Now;
        $PhoneTime  = $Time_Now;
        run_voice_cmd "Set mp3 player to Stop";

        # Log the data for use by display_callers

        logit( "$Pgm_Path/../data/phone/logs/callerid.$Year_Month_Now.log",
            "$PhoneNumber $PhoneName" );
        logit_dbm( "$Pgm_Path/../data/phone/callerid.dbm",
            $PhoneNumber, "$Time_Now $Date_Now $Year name=$PhoneName" );

        # Check to see if callers phone number is in reject table.  If so,
        # let them have it.

        foreach $RejLogTempLine (@rejloglines) {
            if ( substr( $RejLogTempLine, 0, 10 ) eq $PhoneNumber ) {
                print_log "$PhoneName is calling, and is in reject list!";
                speak "$PhoneName is calling, and is in reject list!";
                set $phone_modem 'ATA';
                set $timer_hangup 5;
            }
        }

        # If the incoming area code is the same, drop it from being spoken.

        if ( $areacode eq $config_parms{local_area_code} ) {
            $PhoneNumber = $local_number;
        }

        # Put pauses in between area code, exchange, and number for
        # announce reasons

        if ( length( $PhoneNumber == 7 ) ) {
            $PhoneNumber =
              substr( $PhoneNumber, 0, 3 ) . "." . substr( $PhoneNumber, 3, 4 );
        }
        if ( length( $PhoneNumber == 10 ) ) {
            $PhoneNumber =
                substr( $PhoneNumber, 0, 3 ) . "."
              . substr( $PhoneNumber, 3, 3 ) . "."
              . substr( $PhoneNumber, 6, 4 );
        }

        # Put Spaces in the Phone Number for Announce Reasons

        $j = '';
        for ( $i = 0; $i != ( length($PhoneNumber) ); ++$i ) {
            $j = $j . substr( $PhoneNumber, $i, 1 );
            $j = $j . " ";
        }

        $PhoneNumber = $j;

        # Log the data in a special file to announce from Palmpad

        open( CALLLOG, ">>$config_parms{data_dir}/calllog.log" );    # Log it
        print CALLLOG "$PhoneDate`$PhoneTime`$caller`$PhoneNumber\n";
        close CALLLOG;

        unless ( $areacode eq $config_parms{local_area_code} or !$areacode ) {
            if ( $Caller_ID::state_by_areacode{$areacode} ) {
                $callerba .= " from $Caller_ID::state_by_areacode{$areacode}";
            }
            else {
                $callerba .= " from area code $areacode";
            }
        }

        if ( $PhoneName eq "Out of the Area" ) {
            print_msg "PHONE: Caller's Identification not available.";
            speak "Caller's Identification not available.";
        }
        else {
            print_msg "PHONE: $caller is calling. Number is $PhoneNumber.";
            speak "$caller is calling $callerba. Number is $PhoneNumber.";
        }
    }
}

# Monthly Phone Log Backup

if ($New_Month) {
    my $dbm_file = "$Pgm_Path\\..\\data\\phone\\callerid.dbm";
    print_log "Backing up Phone Log to logs\\$dbm_file.$Year_Month_Now";

    copy( "$dbm_file.dir", "$dbm_file.$Year_Month_Now.dir" )
      or print_log "Error in phone dbm copy 1: $!";
    copy( "$dbm_file.pag", "$dbm_file.$Year_Month_Now.pag" )
      or print_log "Error in phone dbm copy 2: $!";

    # dbm_copy will delete any bad entries (those with binary characters) from the file.

    system("dbm_copy $dbm_file");
    copy( "$dbm_file.backup.dir", "$dbm_file.dir" )
      or print_log "Error in phone dbm copy 3: $!";
    copy( "$dbm_file.backup.pag", "$dbm_file.pag" )
      or print_log "Error in phone dbm copy 4: $!";
}

# Example on how to start and stop a serial port
$v_port_control1 = new Voice_Cmd("[Start,Stop] Serial Port Monitoring");
if ( $state = said $v_port_control1) {
    print_log "Serial Port now in $state position.";
    ( $state eq 'start' ) ? start $phone_modem : stop $phone_modem;
}

# Re-start the port, if it is not in use
if ( $New_Minute and is_stopped $phone_modem and is_available $phone_modem) {
    start $phone_modem;
    $callerba = "";
    set $phone_modem 'init';
    print_msg "MODEM Reinitialized...";
    print_log "MODEM Reinitialized...";
}
