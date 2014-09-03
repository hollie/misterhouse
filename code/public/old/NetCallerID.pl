#
# My thanks to Brian Klier's CallLog where I got most of this code
#
# The NetCallerID is a device that looks and works like a regular CallerID device
# with a LCD screen. Except that it has a serial cable for connecting to the computer.
#
# It comes with software that wil generate a pop up when you are connected to the internet via the modem
# but that software is not needed for MisterHouse.
#
# the NetCallerID must be the first device the outside line goes through if possible.
# in order for the Call Waiting CallerID stuff to work, the NetCallerID must
# realize the line is in use and send a request to get the data.
#
# make sure you have the following lines match the serial device you connect the NetCallerID.
# in your mh.private.ini
#
# serial4_port=com4  #port teh NetCallerID is connected
# serial4_baudrate=4800  #the netCAllerID only seems to work t 4800
#
# this is what the data looks like coming out of the NetCallerID device
# ###DATE06182106...NMBR7045551212...NAMESPAULDING TIMOT+++
#
# The device was purchased from http://www.cyberguys.com
#
# Also see mh/code/bruce/phone_netcallid.pl for another example.
#

#
# Category = Phone

# define variables
use vars qw($PhoneName $PhoneNumber $PhoneTime $PhoneDate);
my ( $NameDone, $NumberDone );
my ( $callerbn, $PhoneNumberz );
my (
    $PhoneDateLog,   $PhoneTimeLog, $PhoneNameLog,
    $PhoneNumberLog, @callloglines, $CallLogTempLine
);
my ( $last, $first, $middle, $areacode, $local_number, $caller );
my $Num_Of_Calls = 0;

$NetCallerID = new Serial_Item( undef, undef, 'serial5' );
if ( my $NetCaller = said $NetCallerID) {
    print "$NetCaller\n";
    ( $PhoneNumber, $PhoneName ) =
      $NetCaller =~ /^.+\.NMBR(\d+)\.{3}NAME(.+)\+{3}$/;
    print "Name = $PhoneName, Number = $PhoneNumber\n"
      ;    # make sure I am getting what I think I want.
    $NumberDone = "yes";
    $NameDone   = "yes";

    ( $last, $first, $middle ) = ( split( ' ', $PhoneName ) )[ 0, 1, 2 ];
    $first = ucfirst( lc($first) );
    $first = ucfirst( lc($middle) )
      if length($first) == 1;    # Last M First format
    $last = ucfirst( lc($last) );

    $areacode     = ( substr( $PhoneNumber, 0, 3 ) );
    $local_number = ( substr( $PhoneNumber, 3, 7 ) );
    $PhoneNumberz =
        substr( $PhoneNumber, 0, 3 ) . "-"
      . substr( $PhoneNumber, 3, 3 ) . "-"
      . substr( $PhoneNumber, 6, 4 );

    # if there is no caller id info, you get the following data from the NetCallerID
    # I don't know what shows up if teh caller is a private number
    #   "###DATE06191942...NMBR...NAME-UNKNOWN CALLER-+++";
    #
    # the $PhoneName and the $PhoneNumber data will be empty

    if ( !$PhoneName ) {
        $PhoneNumber  = "";
        $areacode     = "";
        $local_number = "";
        $caller       = "Out of the Area";
        $PhoneName    = "Out of the Area";
        $last         = "Out of the Area";
    }
}

if ( $NumberDone eq "yes" and $NameDone eq "yes" ) {
    $NumberDone = 0;
    $NameDone   = 0;
    $Num_Of_Calls++;    # increment number of callers

    # get current date and time for logging
    $PhoneDate = $Date_Now;
    $PhoneTime = $Time_Now;

    # check the caller_ID list to see if there is a match
    if ( $callerbn = $Caller_ID::name_by_number{$PhoneNumberz} ) {
        $caller = $callerbn;
    }
    else {
        #      $caller = "$first $last";
        $caller = "$last"
          ; #The last name is typically the only complete  name you will get, depending on the length of the person's name
            # print_msg "caller name = $caller, last name = $last";
    }

    # Log the data for use by display_callers
    logit( "$config_parms{data_dir}/phone/logs/callerid.$Year_Month_Now.log",
        "$PhoneNumber $PhoneName" );
    logit_dbm( "$config_parms{data_dir}/phone/callerid.dbm",
        $PhoneNumber, "$Time_Now $Date_Now $Year name=$PhoneName" );

    # If the incoming area code is the same, drop it from being spoken.
    if ( $areacode eq $config_parms{local_area_code} ) {
        $PhoneNumber = $local_number;
    }

    # Put pauses in between area code, exchange, and number for
    # announce reasons
    if ( length($PhoneNumber) == 7 ) {
        $PhoneNumber =
          substr( $PhoneNumber, 0, 3 ) . "." . substr( $PhoneNumber, 3, 4 );
    }
    if ( length($PhoneNumber) == 10 ) {
        $PhoneNumber =
            substr( $PhoneNumber, 0, 3 ) . "."
          . substr( $PhoneNumber, 3, 3 ) . "."
          . substr( $PhoneNumber, 6, 4 );
    }

    # Log the data in a special file to announce from Palmpad
    # I haven't implimented the other end of this yet
    open( CALLLOG, ">>$config_parms{code_dir}/calllog.log" );
    print( CALLLOG "$PhoneDate\t$PhoneTime\t$caller\t$PhoneNumber\n" );
    close CALLLOG;

    if ( $caller eq "Out of the Area" ) {

        #      print_msg "PHONE: Caller's Identification not available.";
        speak "Caller's Identification not available.";
    }
    else {
        #      print_msg "PHONE: $caller is calling. Number is $PhoneNumber.";
        speak "$caller is calling. Number is $PhoneNumber.";

        # add the ability to send email with the caller info
    }
}

# Monthly Phone Log Backup
if ($New_Month) {
    my $dbm_file = "$config_parms{data_dir}/phone/callerid.dbm";
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

