# Category=Phone

# Add these entries to your mh.ini file:
#  serial_gsm_port=COMx
#  serial_gsm_baudrate=9600
#  serial_gsm_handshake=none

=begin comment

From Roger Bille on 09/2001

 I have a quick and dirty perl script that I have used to play with SMS. It
is using a GSM modem (phone without keyboard and display but with a RS232
connector) but should work with any phone that has built in modem functions
and support the special AT+ commands for SMS. I think most Nokia phones
support it.

 The action_sms section is the place where you can get mh to do somthing. My
program only support 2 messages:

    mh 0        (turn off living_corner_light)
    mh 1        (turn on living_corner_light)

 The action_sms also check who the sender is before it allows an action to
be done. get_gsm translate numbers to names.

From Gianni Veloce on 11/2004.

Roger's code helped as a starting point for me, being definitely not a PERL 
guy. I added/changed some pieces of code (marked by GV comment) to make it  
work with my NOKIA phones.
The code was tested with 6110 and DAU9P cable using Nokia Data Suite 3.0 as 
6110 does not provide a hardware modem. Then tested also with 7110 and DLR3 
cable (no Data Suite needed as 7110 has a hardware modem in it.In this sence 
7110 can be used by Linux users, 6110 cannot.
This code has been used for CADDX alarm integration with SMS alerts. 
Finally, I apologize for using my nickname: Gianni Veloce. I used to be a race 
car driver when I was young and I really miss these times...

=cut

my ( $gsm_mode, $gsm_message, $gsm_header );

$timer_waitforanswer = new Timer;    # Timer that Waits for an Answer

$gsm =
  new Serial_Item( 'AT&FE1V1+CMGF=1;+CNMI=2,1,0,0,0', 'init', 'serial_gsm' )
  ;                                  # GV-enabled phone's TE mode
if ($Reload) {
    $gsm_mode = "init";
    set $gsm 'init';                 # Initialize MODEM

    #    &wait_ok;
    #    print_log "GSM has been Initialized...";
}

&read_all;

#   SMS to Julie
$sms_Julie = new Generic_Item;
$sms_Julie->set_authority('anyone');
&tk_entry( 'SMS to Julie', $sms_Julie );
if ( $state = state_now $sms_Julie) {
    &send_sms( "+39456789012", $state );
}

#   SMS to Kostas
$sms_Kostas = new Generic_Item;
$sms_Kostas->set_authority('anyone');
&tk_entry( 'SMS to Kostas', $sms_Kostas );
if ( $state = state_now $sms_Kostas) {
    &send_sms( "+391234567890", $state );
}

#   SMS to MisterHouse
$sms_mh = new Generic_Item;
$sms_mh->set_authority('anyone');
&tk_entry( 'SMS to Misterhouse', $sms_mh );
if ( $state = state_now $sms_mh) {
    &send_sms( "+391703809627", $state );
}

#	List SMS Messages
$v_sms_list = new Voice_Cmd('List SMS Messages');
if ( said $v_sms_list) {
    $gsm_mode = "list";
    set $gsm "AT+CMGL=\"REC UNREAD\"\r";   # GV-substituted =4 with "REC UNREAD"
    print_log "Reading SMS List" if $main::config_parms{debug} eq 'sms';
}

sub read_all {
    my $gsm_in;
    if ( $gsm_in = said $gsm) {
        if ( $gsm_in =~ /^AT/ ) {
            print_log "SMS: AT command trapped ($gsm_in)"
              if $main::config_parms{debug} eq 'sms';
        }
        elsif ( $gsm_in =~ /^OK/ and $gsm_mode eq "init" ) {
            print_log "GSM has been Initialized";
            $gsm_mode = "";
            run_voice_cmd("List SMS Messages")
              ;    # Read any pending messages at init
        }
        elsif ( $gsm_in =~ /^OK/ and $gsm_mode eq "send" ) {
            print_log "SMS Message Sent (OK)"
              if $main::config_parms{debug} eq 'sms';
            $gsm_mode = "";
        }
        elsif ( $gsm_in =~ /^ERROR/ and $gsm_mode eq "list" ) {    # List Empty
            $gsm_mode = "";
        }
        elsif ( $gsm_in =~ /^OK/ and $gsm_mode eq "list" ) {
            print_log "SMS List completed"
              if $main::config_parms{debug} eq 'sms';
            $gsm_mode = "";
        }
        elsif ( $gsm_in =~ /^\+CMGS: / ) {
            $gsm_in =~ s/^\+CMGS: //g;
            print_log "SMS Message $gsm_in sent";
        }
        elsif ( $gsm_in =~ /^\+CMTI/ ) {    # New message received
            run_voice_cmd("List SMS Messages")
              ;                             # Read any pending messages at init
        }
        elsif ( $gsm_in =~ /^\+CMGL/ ) {
            print_log "SMS Message Recieved: $gsm_in"
              if $main::config_parms{debug} eq 'sms';
            $gsm_header = $gsm_in;
            $gsm_mode   = "message";
        }
        elsif ( $gsm_mode eq "message" ) {
            print_log "SMS Message: $gsm_in"
              if $main::config_parms{debug} eq 'sms';
            &action_sms( $gsm_header, $gsm_in );
            $gsm_mode = "list";
        }
        elsif ( $gsm_in =~ /^\>/ ) {    # Remove > lines during send
        }
        elsif ( $gsm_in =~ /^OK/ ) {    # Remove extra OK
        }
        elsif ( $gsm_in eq "\r" ) {     # Remove empty lines
        }
        else {
            print_log "SMS Message not trapped: $gsm_in";
        }
    }
}

sub action_sms {
    my ( $header, $message ) = @_;
    my ( $sms_nbr, $sms_status, $sms_from, $sms_date ) = split( ",", $header );
    $sms_nbr =~ s/^\+CMGL: //;
    $sms_status =~ s/\"//g;
    $sms_from =~ s/\"//g;

    # 	print ".$sms_nbr.";
    my $name = &get_gsm($sms_from);
    print_log "SMS from $name: $message";

    #	if ($message =~ /^mh /i and $name =~ /Roger|Anna|MisterHouse/) {    # GV-Deleted
    if ( $message =~ /^mh /i and $name =~ /Julie|Kostas|MisterHouse/ )
    {    # GV-Added my numbers
        $message =~ s/^mh //ig;
        print_log "SMS Command to mh received: $message";
        if ( $message eq "1" ) {

            # 			set $living_corner_light ON;    		# GV-deleted
            print_log
              "Received ON (1) Command";    # GV-added (your command(s) here)
        }
        elsif ( $message eq "2" ) {

            # 			set $living_corner_light OFF;  	 	# GV-deleted
            print_log
              "Received OFF (0) Command";    # GV-added (your command(s) here)
        }
        elsif ( $message eq "T" ) {
            print_log "Received TEST (T) Command"; # GV-added an auto-reply test
            send_sms( $sms_from, "TEST OK" );      # GV-added an auto-reply test
        }
        else {
            print_log "SMS Command to mh received in Error";
        }
    }
    set $gsm "AT+CMGD=$sms_nbr\r";
    print_log "deleting msg $sms_nbr";             #   GV-added

    # 	print "AT+CMGD=$sms_nbr\n";
}

sub get_gsm {
    my ($number) = @_;
    my $name;
    if ( $number eq "+391234567890" ) {            # GV-my numbers
        $name = "Kostas";
    }
    elsif ( $number eq "+393456789012" ) {         # GV-my numbers
        $name = "Julie";
    }
    elsif ( $number eq "+391703809627" ) {
        $name = "MisterHouse";
    }
    elsif ( $number eq "133" ) {
        $name = "Voicemail";
    }
    else {
        $name = $number;
    }
    return $name;
}

sub send_sms {
    my ( $number, $message ) = @_;
    my $gsm_response;

    #    set $gsm 'init';               # Initialize MODEM
    $gsm_mode = "send";
    print_log "Sending SMS to $number: $message";
    set $gsm "AT+CMGS=\"$number\"\r";
    print_log "Part 1 - Sending number = $number"
      if $main::config_parms{debug} eq 'sms';

    sleep 1;
    set $gsm "$message\cZ";
    print_log "Part 2 - Sending message = $message"
      if $main::config_parms{debug} eq 'sms';

    #    set $timer_waitforanswer 10;
    #    do {
    #		$gsm_response = said $gsm;
    #   		if ($gsm_response =~ /OK/) {
    #    		print_log "Part 3 - DONE";
    #    	}
    #	} until (expired $timer_waitforanswer or $gsm_response =~ /OK/);
}
