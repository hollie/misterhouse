# Category=Phone

# Add these entries to your mh.ini file:
#  serial_gsm_port=COM3  
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
    mh 1        (turn on living_corenr_light)

 The action_sms also check who the sender is before it allows an action to
be done. get_gsm translate numbers to names.

=cut


my ($gsm_mode, $gsm_message, $gsm_header);

$timer_waitforanswer = new Timer;   # Timer that Waits for an Answer

$gsm = new Serial_Item ('AT&FE1V1+CMGF=1', 'init', 'serial_gsm');
if ($Reload) {
	$gsm_mode = "init";
    set $gsm 'init';               # Initialize MODEM
#    &wait_ok;
#    print_log "GSM has been Initialized...";
}

&read_all;

#   SMS to Roger
$sms_roger   = new Generic_Item;
$sms_roger  -> set_authority('anyone');
&tk_entry('SMS to Roger', $sms_roger);
if ($state = state_now $sms_roger) {
	&send_sms ("0705944780", $state);
}

#   SMS to Anna
$sms_anna   = new Generic_Item;
$sms_anna  -> set_authority('anyone');
&tk_entry('SMS to Anna ', $sms_anna);
if ($state = state_now $sms_anna) {
	&send_sms ("0706071650", $state);
}

#   SMS to MisterHouse
$sms_mh   = new Generic_Item;
$sms_mh  -> set_authority('anyone');
&tk_entry('SMS to Misterhouse', $sms_mh);
if ($state = state_now $sms_mh) {
	&send_sms ("0703809627", $state);
}

#	List SMS Messages
$v_sms_list = new  Voice_Cmd('List SMS Messages');
if (said $v_sms_list) {
	$gsm_mode = "list";
    set $gsm "AT+CMGL=4\r";
    print_log "Reading SMS List" if $main::config_parms{debug} eq 'sms';
}


sub read_all {
	my $gsm_in;
	if ($gsm_in = said $gsm) {
		if ($gsm_in =~ /^AT/) {
			print_log "SMS: AT command trapped ($gsm_in)" if $main::config_parms{debug} eq 'sms';
		} elsif ($gsm_in =~ /^OK/ and $gsm_mode eq "init") {
			print_log "GSM has been Initialized";
			$gsm_mode = "";
			run_voice_cmd("List SMS Messages");			# Read any pending messages at init
		} elsif ($gsm_in =~ /^OK/ and $gsm_mode eq "send") {
			print_log "SMS Message Sent (OK)" if $main::config_parms{debug} eq 'sms';
			$gsm_mode = "";
		} elsif ($gsm_in =~ /^ERROR/ and $gsm_mode eq "list") {		# List Empty
			$gsm_mode = "";
		} elsif ($gsm_in =~ /^OK/ and $gsm_mode eq "list") {
			print_log "SMS List completed" if $main::config_parms{debug} eq 'sms';
			$gsm_mode = "";
		} elsif ($gsm_in =~ /^\+CMGS: /) {
			$gsm_in =~ s/^\+CMGS: //g;
			print_log "SMS Message $gsm_in sent";
		} elsif ($gsm_in =~ /^\+CMTI/) {				# New message received
			run_voice_cmd("List SMS Messages");			# Read any pending messages at init
		} elsif ($gsm_in =~ /^\+CMGL/) {
 			print_log "SMS Message Recieved: $gsm_in" if $main::config_parms{debug} eq 'sms';
			$gsm_header = $gsm_in;
			$gsm_mode = "message";
		} elsif ($gsm_mode eq "message") {
 			print_log "SMS Message: $gsm_in" if $main::config_parms{debug} eq 'sms';
			&action_sms ($gsm_header, $gsm_in);
			$gsm_mode = "list";
		} elsif ($gsm_in =~ /^\>/) {					# Remove > lines during send
		} elsif ($gsm_in =~ /^OK/) {					# Remove extra OK
		} elsif ($gsm_in eq "\r") {						# Remove empty lines
		} else {
			print_log "SMS Message not trapped: $gsm_in";
		}
	}
}

sub action_sms {
	my ($header, $message) = @_;
 	my ($sms_nbr, $sms_status, $sms_from, $sms_date) = split (",", $header);
	$sms_nbr =~ s/^\+CMGL: //;
	$sms_status =~ s/\"//g;
	$sms_from =~ s/\"//g;
# 	print ".$sms_nbr.";
	my $name = &get_gsm ($sms_from);
	print_log "SMS from $name: $message";
	if ($message =~ /^mh /i and $name =~ /Roger|Anna|MisterHouse/) {
		$message =~ s/^mh //ig;
		print_log "SMS Command to mh received: $message";
		if ($message eq "1") {
			set $living_corner_light ON;
		} elsif ($message eq "2") {
			set $living_corner_light OFF;
		} else {
			print_log "SMS Command to mh received in Error";
		}	
	}
    set $gsm "AT+CMGD=$sms_nbr\r";
# 	print "AT+CMGD=$sms_nbr\n";
}
	
sub get_gsm {
	my ($number) = @_;
	my $name;
	if ($number eq "+46705944780") {
		$name = "Roger";
	} elsif ($number eq "+46706071650") {
		$name = "Anna";
	} elsif ($number eq "+46703809627") {
		$name = "MisterHouse";
	} elsif ($number eq "133") {
		$name = "Voicemail";
	} else {
		$name = $number;
	}
	return $name;
}

sub send_sms {
 	my ($number, $message) = @_;
 	my $gsm_response;
#    set $gsm 'init';               # Initialize MODEM
	$gsm_mode = "send";
 	print_log "Sending SMS to $number: $message";
    set $gsm "AT+CMGS=\"$number\"\r";
    print_log "Part 1 - Sending number = $number" if $main::config_parms{debug} eq 'sms';

	sleep 1;
	set $gsm "$message\cZ";
	print_log "Part 2 - Sending message = $message" if $main::config_parms{debug} eq 'sms';
	
#    set $timer_waitforanswer 10;
#    do {
#		$gsm_response = said $gsm;
#   		if ($gsm_response =~ /OK/) {
#    		print_log "Part 3 - DONE";
#    	}
#	} until (expired $timer_waitforanswer or $gsm_response =~ /OK/);
}
