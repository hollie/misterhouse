############################################################
#  Klier Home Automation - Voice Modem Support Files       #
#  Version 0.2 Pre-Development                             #
#  By: Brian J. Klier, N0QVC                               #
#  E-Mail: klier@lakes.com                                 #
#  Webpage: http://www.faribault.k12.mn.us/brian           #
############################################################

# Category=Phone
# New in Version 0.2:
# - Added Sample Announcement Dialout
#
# New in Version 0.1:
# - PRE DEVELOPMENT - Proving Concept - Sent to Bruce for Review

#####################
# Declare Variables #
#####################

my ($VoiceModemMode, $voxfile, $VoiceModemStatus, $SendVoiceFile);
my ($DialNumber, $DisplayListVoice);

$timer_waitforanswer = new Timer;   # Timer that Waits for an Answer
$timer_sendvoice = new Timer;       # Send Voice Timer waits 2 seconds
                                    # before talking.
$timer_endvoice = new Timer;        # End Voice Timer waits 2 seconds
                                    # before exiting talking mode.
$timer_stdwait = new Timer;

##########################################################################
# ***** Following lines included in calllog.pl, not needed here. *****
#
#$phone_modem = new Serial_Item ('AT#CID=1','init','serial2');
# Re-start the port, if it is not in use
#if ($New_Minute and is_stopped $phone_modem and is_available $phone_modem) {
#    start $phone_modem;
#    set $phone_modem 'init';
#    print_msg "MODEM Reinitialized...";
#    print_log "MODEM Reinitialized...";
#}
#
##########################################################################

# -------------------------- Display Startup Greeting

if ($Startup or $Reload) {
    print_msg "Voice MODEM Interface has been Initialized...";
    print_log "Voice MODEM Interface has been Initialized...";
}

##################################################################
# Main Procedures - Dependent on Secondary Procedures to Operate #
##################################################################

#DEBUG
#if ($New_Second) {
#    print_msg "VoiceModemMode=$VoiceModemMode   Status=$VoiceModemStatus";
#}

# -------------------------- Call and Deliver a Message

$v_deliver_message = new Voice_Cmd('Deliver Message');
if (said $v_deliver_message) {
    $VoiceModemStatus = "";
    $VoiceModemMode = "delivermsg";
#   $DialNumber = "2881030";                          # Number to Dial
    $DialNumber = "12";                          # Number to Dial
#   $SendVoiceFile = "c:/mh/code/klier/voice.vox";    # Voice File to Play
    $SendVoiceFile = "e:/misterhouse/data/phone/sounds/voice.vox"; 
    run_voice_cmd "Put MODEM in Voice Mode";
    set $timer_stdwait 1;                             # Wait a second
}

if (expired $timer_stdwait) {                         # After a second,
    run_voice_cmd "Dial Number";                      # Dial Number
    set $timer_waitforanswer 20;                      # Wait 20 Sec. for pickup
}

# If we get connected to someone,
if ($VoiceModemMode eq "delivermsg" and $VoiceModemStatus eq "Connect") {
    $VoiceModemStatus = "";
    set $timer_waitforanswer 0;    # Reset possibility of failing
    run_voice_cmd "Send Voice Data";
}

# If no one picks up the phone,
if ($VoiceModemMode eq "delivermsg" and expired $timer_waitforanswer) {
    run_voice_cmd "Voice Hangup";
    print_log "VOICE - No Answer, Hungup";
    $VoiceModemStatus = "Failure";
    set $timer_waitforanswer 0;    # Reset possibility of failing
    $VoiceModemMode = "";
}

# If we get a Busy Signal,
if ($VoiceModemMode eq "delivermsg" and $VoiceModemStatus eq "Remote Busy") {
    run_voice_cmd "Voice Hangup";
    print_log "VOICE - Line was Busy, Hungup";
    $VoiceModemStatus = "Failure";
    $VoiceModemMode = "";
    set $timer_waitforanswer 0;    # Reset possibility of failing
}

if ($VoiceModemMode eq "delivermsg" and $VoiceModemStatus eq "donesendmsg") {
    run_voice_cmd "Voice Hangup";
    print_log "VOICE - Message Delivered Successfully...";
    $VoiceModemStatus = "Success";
    $VoiceModemMode = "";
}

########################
# Secondary Procedures #
########################

# -------------------------- Put MODEM in Voice Mode

$v_voice_mode = new Voice_Cmd('Put MODEM in Voice Mode');
if (said $v_voice_mode) {
    #TL is the Volume Level - Default is 3F44 - Range 0000 to 7FFF
    #VRA=35 makes the modem wait for 4.5 sec. of silence after ringing stops - Default is 45
#   set $phone_modem 'ATE0#CLS=8#VBS=4S30=60#BDR=0#VSP=20#VSS=1#VLS=0#TL=5800#VRA=30';
# AT#VLS=6 - speakerphone mode
    set $phone_modem 'ATE0#CLS=8#VBS=4S30=60#BDR=0#VSP=20#VSS=1#VLS=0';
    print_log "VOICE - MODEM is now in VOICE Mode";
}

# -------------------------- Beep

$v_voice_beep = new Voice_Cmd('Beep');
if (said $v_voice_beep) {
    # AT#VTS sends out beeps - 1000 is the frequency, 3 is the duration
    set $phone_modem 'AT#VTS=[1000,1000,3]#VTS=[1500,1500,3]#VTS=[1000,1000,3]';
    print_log "VOICE - Test Beeps Sent";
}

# -------------------------- DTMF Send

$v_voice_dtmftest = new Voice_Cmd('DTMF Test 2 Send');
if (said $v_voice_dtmftest) {
    set $phone_modem 'AT#VTS={2}';
    print_log "VOICE - Test DTMF Sent";
}

# -------------------------- Voice Hangup

$v_voice_hangup = new Voice_Cmd('Voice Hangup');
if (said $v_voice_hangup) {
    set $phone_modem 'ATH';
    $VoiceModemStatus = "";
    $VoiceModemMode = "";
    print_log "VOICE - MODEM is now OUT of VOICE Mode";
}

# -------------------------- Dial Number

$v_voice_dial = new Voice_Cmd('Dial Number');
if (said $v_voice_dial) {
    $VoiceModemStatus = "Dialing";
    print_log "VOICE - Dialing $DialNumber...";
    $DialNumber = "ATDT" . $DialNumber;
    set $phone_modem $DialNumber;
}

# -------------------------- Answer Phone

$v_voice_answer = new Voice_Cmd('Answer');
if (said $v_voice_answer) {
    $VoiceModemStatus = "Answered";
    set $phone_modem 'ATA';
    print_log "VOICE - Picked up line ... listening for tones...";
}

# -------------------------- Send Voice Data

$v_voice_send = new Voice_Cmd('Send Voice Data');
if (said $v_voice_send) {
    set $phone_modem 'AT#VTX';
    set $timer_sendvoice 1;
    #select undef, undef, undef, .5 / 1000;             # Wait 1/2 sec.
    print_log "VOICE - Initial Voice Transmit Mode ... STANDBY";
}

if (expired $timer_sendvoice) {
    # The VOX File is a Rockwell 4 bit ADPCM Encoded Sound file,
    # sampled at 7200 hz.  I used a program called "Vox Studio"
    # to convert a standard 11 KHz WAV file into the format.
    # Go to  http://www.xentec.be/download/download.htm
    # for a limited demo copy (up to 5 second sound files)

    print "Reading $SendVoiceFile\n";
#   $voxfile = file_read $SendVoiceFile;                  # The File
#   set $phone_modem $voxfile;                            # Send 2 Modem
    speak "1. Hello from the winter house.  The house just blew up";
    print "1 setting speaker volume\n";
    set $phone_modem 'AT#SPK=1,5,3';
#    print "1 setting speaker volume\n";
    set $phone_modem 'AT#VLS=6';
    print "2 setting speaker volume\n";
    set $phone_modem 'AT#VTL=7FFF';
    print "3 setting speaker volume\n";
    speak "2. Hello from the winter house.  The house just blew up";
    set $timer_endvoice 12;                                # Wait 1 Sec
    print_log "VOICE - Voice File Sent";
}

if (expired $timer_endvoice) {                            # After 1 sec,
    set $phone_modem '';                                # Send END
    $VoiceModemStatus = 'donesendmsg';
    print_log "VOICE - Voice Transmit Mode Cleared";
}

# -------------------------- Analyze Incoming Text from MODEM

if (substr($PhoneModemString, 0, 2) eq 'b') {
    $VoiceModemStatus = "Remote Busy";
    print_log "VOICE - Remote Busy.";
}

if (substr($PhoneModemString, 0, 4) eq 'BUSY') {
    $VoiceModemStatus = "Remote Busy";
    print_log "VOICE - Remote Busy.";
}

if (substr($PhoneModemString, 0, 2) eq 'd') {
    $VoiceModemStatus = "Dialtone";
    print_log "VOICE - Dial Tone Detected.";
}

if (substr($PhoneModemString, 0, 2) eq 'r') {
    $VoiceModemStatus = "Remote Ring";
    print_log "VOICE - Remote Ring.";
}

if (substr($PhoneModemString, 0, 4) eq 'VCON') {
    $VoiceModemStatus = "Connect";
    print_log "VOICE - Connected to Remote.";
}

#print "db pmodem=$PhoneModemString.\n" if $PhoneModemString;
#print "db phone=$Serial_Ports{serial_modem}{data}\n" if $Serial_Ports{serial_modem}{data};

                                # Look for a 2 character phone keypad press
                                # hex 10 is the ^P <del> character
if ($Serial_Ports{serial_modem}{data} =~ /\x10(\S)/) {
    print "db phone keypad: $1,$Serial_Ports{serial_modem}{data}.\n";
}

if ($Serial_Ports{serial_modem}{data} =~ /\x10(\d)\x10(\d)/) {
    my $phone_command = $1 . $2;
    speak $phone_command;
    print "Phone button: $phone_command\n";
    $Serial_Ports{serial_modem}{data} = '';
    if ($phone_command eq '10') {
        run_voice_cmd 'What time is it';
    }
    elsif ($phone_command eq '11') {
        run_voice_cmd 'When will the sun set';
    }
    else {
        speak "Unknown command";
    }
}

$v_record_msg = new Voice_Cmd('Record a message');
if (said $v_record_msg) {
    print_log "VOICE - Recording message.";
    set $phone_modem 'AT#VRX';
    $VoiceModemStatus = 'record';    
    my $file = "$config_parms{data_dir}/phone/msg.vox";
    open (VOX, ">$file") or print "Error in opening file $file:$@\n";
    binmode VOX;
                                # Change from record mode, so we ignore /n
    $Serial_Ports{serial_modem}{datatype} = 'raw';
}

if ($VoiceModemStatus eq 'record' and $PhoneModemString) {
    my $l = length $PhoneModemString;
    print "l=$l\n";
                                # Look for close, busy, or dialtone
    if ($PhoneModemString =~ /(.+)\x10[qbds\#](.*)/) {
        print VOX $1;
        close VOX;
        $Serial_Ports{serial_modem}{data} = $2; # Store left over data
        $Serial_Ports{serial_modem}{datatype} = 'record';
        $VoiceModemStatus = '';
        print_log "VOICE - Message recorded.";
        print "\nVOICE - Message recorded.\n\n";
        set $phone_modem "ATA\n\n"; # Force it to stop recording ??
    }
    else {
        print VOX $PhoneModemString;
    }
}

