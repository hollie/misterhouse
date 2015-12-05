############################################################
#  Klier Home Automation - Voice Modem Support Files       #
#  Version 0.5 BETA                                        #
#  By: Brian J. Klier, N0QVC                               #
#  With Help from: Bruce Winter, KC0EQV                    #
#  E-Mail: klier@lakes.com                                 #
#  Webpage: http://www.faribault.k12.mn.us/brian           #
############################################################
# Category=Phone
#
# If you will be trying out this code, make sure:
#    * Baud Rate on Modem Port is set at 38400, records mode.
#    * You have a Voice Compatible Modem (Rockwell Chipset)
#    * Read Other Comments in this file
#    * To Let me know of any problems you may have (klier@lakes.com), or
#      post to MisterHouse list.
#    * To Change the hardcoded pathnames below accordingly:
#      (instead of C:/mh/code/klier/voice.r4 ... your path)
#
# To Do List
# - Feature to Delete Messages
# - Full Procedure to Retrieve Messages
# - Have a key to hit, enter a code, and run house commands using DTMF pad.
#
# New in Version 0.5 BETA
# - Added Command Line Utility (Thanks ??????????), from VoiceGuide program.
#
# New in Version 0.4 BETA
# - Finished Answering Machine (enough for testing anyways) - will start
#   outside testing on software.
#
# New in Version 0.3:
# - PRE DEVELOPMENT - Added Answer Procedure, with Answering Machine start
#
# New in Version 0.2:
# - PRE DEVELOPMENT - Added Sample Announcement Dialout
#
# New in Version 0.1:
# - PRE DEVELOPMENT - Proving Concept - Sent to Bruce for Review
#####################
# Declare Variables #
#####################
my ( $VoiceModemMode, $voxfile, $VoiceModemStatus, $SendVoiceFile );
my ( $DialNumber, $RingCount, $VoiceMsgCount );
$timer_waitforanswer = new Timer;    # Timer that Waits for an Answer
$timer_sendvoice     = new Timer;    # Send Voice Timer waits 2 seconds
                                     # before talking.
$timer_endvoice      = new Timer;    # End Voice Timer waits 2 seconds
                                     # before exiting talking mode.
$timer_stdwait       = new Timer;
$timer_stdwait2      = new Timer;
$timer_stdwait3      = new Timer;    # Used for wait to process .R4 > .WAV
$timer_afteranswer   = new Timer;    # Wait after Init in Answer Mode
$timer_afteranswer2  = new Timer;    # Wait after Answer in Answer Mode
$timer_afteranswer3  = new Timer;    # Wait after Init in Answer Mode
$timer_masterinact   = new Timer;    # Master Inactivity timer - after this
                                     # time, the modem will hangup.
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
if ( $Startup or $Reload ) {
    print_msg "Voice MODEM Interface has been Initialized...";
    print_log "Voice MODEM Interface has been Initialized...";
    if ( $VoiceMsgCount eq '' ) { $VoiceMsgCount = 0 }
    $RingCount        = 0;
    $VoiceModemMode   = "";
    $VoiceModemStatus = "";
}
##################################################################
# Main Procedures - Dependent on Secondary Procedures to Operate #
##################################################################
#DEBUG
#if ($New_Second) {
#    print_msg "VoiceModemMode=$VoiceModemMode   Status=$VoiceModemStatus";
#}
# -------------------------- Speak Number of Voice Messages Waiting
$v_msgs_waiting = new Voice_Cmd('How many voice messages do I have?');
if ( said $v_msgs_waiting) {
    speak "You have $VoiceMsgCount voice messages waiting.";
    run qq[vgconvrt -r42w\[C:\\mh\\data\\phone\\msg.r4\]];
    set $timer_stdwait3 5;    # Wait 5 Seconds,
}
if ( expired $timer_stdwait3) {
    set $timer_stdwait3 0;
    play( 'file' => 'C:\MH\DATA\PHONE\MSG.WAV' );    # Play Messages
}

# -------------------------- Answer Mode, and Accept Commands
$v_answer_mode = new Voice_Cmd('Answer Mode');

#if (said $v_answer_mode or $RingCount eq "4") {       # After 4 Rings,
if ( said $v_answer_mode) {
    $VoiceModemMode   = "answermode";
    $VoiceModemStatus = "";
    $RingCount        = 0;
    run_voice_cmd "Put MODEM in Voice Mode";         # Initialize MODEM
    set $timer_afteranswer 1;
}
if ( expired $timer_afteranswer) {                   # Wait a Sec aft Init
    set $timer_afteranswer 0;
    run_voice_cmd "Answer";                          # Answer the Phone
    set $timer_afteranswer2 1;
}
if ( expired $timer_afteranswer2) {                  # Wait a Sec aft Answer
    set $timer_afteranswer2 0;
    $SendVoiceFile = "c:/mh/code/klier/voice.r4";    # Voice File to Play
    run_voice_cmd "Send Voice Data";
    set $timer_masterinact 30;                       # 30 Seconds to Timeout
}
if ( $VoiceModemMode eq "answermode" and $VoiceModemStatus eq "donesendmsg" ) {
    run_voice_cmd "Beep";
    set $timer_afteranswer3 1;
}
if ( expired $timer_afteranswer3) {
    set $timer_afteranswer3 0;
    run_voice_cmd "Record a message";
}
if ( $VoiceModemMode eq "answermode" and $VoiceModemStatus eq "recorddone" ) {
    run_voice_cmd "Voice Hangup";
    set $timer_masterinact 0;                        # Reset Inact Timer
}
if ( $VoiceModemMode eq "answermode" and $VoiceModemStatus eq "1" ) {
    $VoiceModemStatus = "";
    print_log "VOICE ****** Command 1 ******";
    set $timer_masterinact 60;                       # Reset Inact Timer
}
if ( $VoiceModemMode eq "answermode" and $VoiceModemStatus eq "2" ) {
    $VoiceModemStatus = "";
    print_log "VOICE ****** Command 2 ******";
    set $timer_masterinact 60;                       # Reset Inact Timer
}
if ( $VoiceModemMode eq "answermode" and $VoiceModemStatus eq "3" ) {
    $VoiceModemStatus = "";
    print_log "VOICE ****** Command 3 ******";
    set $timer_masterinact 60;                       # Reset Inact Timer
}
if ( $VoiceModemMode eq "answermode" and $VoiceModemStatus eq "4" ) {
    $VoiceModemStatus = "";
    run_voice_cmd "Play Messages";
    print_log "VOICE ****** Command 4 - Playing Messages ******";
    set $timer_masterinact 60;                       # Reset Inact Timer
}
if ( $VoiceModemMode eq "answermode" and $VoiceModemStatus eq "5" ) {
    $VoiceModemStatus = "";
    print_log "VOICE ****** Command 5 ******";
    set $timer_masterinact 60;                       # Reset Inact Timer
}

# If Inactivity Counter is Exceeded,
if (    $VoiceModemMode eq "answermode"
    and expired $timer_masterinact
    and $VoiceModemStatus ne "record" )
{
    $VoiceModemMode = "disconanswer";
    $SendVoiceFile  = "c:/mh/code/klier/goodbye.r4";    # Voice File to Play
    run_voice_cmd "Send Voice Data";
}
if ( $VoiceModemMode eq "disconanswer" and $VoiceModemStatus eq "donesendmsg" )
{
    print_log "VOICE - Inactivity Timer Exceeded... Disconnecting...";
    run_voice_cmd "Voice Hangup";
    $VoiceModemStatus = "InactTimeOut";
    $VoiceModemMode   = "";
}

# -------------------------- Call and Deliver a Message
$v_deliver_message = new Voice_Cmd('Deliver Message');
if ( said $v_deliver_message) {
    $VoiceModemStatus = "";
    $VoiceModemMode   = "delivermsg";
    $DialNumber       = "3322505";                      # Number to Dial
    $SendVoiceFile    = "c:/mh/code/klier/voice.r4";    # Voice File to Play
    run_voice_cmd "Put MODEM in Voice Mode";
    set $timer_stdwait 1;                               # Wait a second
}
if ( expired $timer_stdwait) {                          # After a second,
    run_voice_cmd "Dial Number";    # Dial Number
    set $timer_waitforanswer 20;    # Wait 20 Sec. for pickup
}

# If we get connected to someone,
if ( $VoiceModemMode eq "delivermsg" and $VoiceModemStatus eq "Connect" ) {
    $VoiceModemStatus = "";
    set $timer_waitforanswer 0;     # Reset possibility of failing
    run_voice_cmd "Send Voice Data";
}

# If no one picks up the phone,
if ( $VoiceModemMode eq "delivermsg" and expired $timer_waitforanswer) {
    run_voice_cmd "Voice Hangup";
    print_log "VOICE - No Answer, Hungup";
    $VoiceModemStatus = "Failure";
    set $timer_waitforanswer 0;     # Reset possibility of failing
    $VoiceModemMode = "";
}

# If we get a Busy Signal,
if ( $VoiceModemMode eq "delivermsg" and $VoiceModemStatus eq "Remote Busy" ) {
    run_voice_cmd "Voice Hangup";
    print_log "VOICE - Line was Busy, Hungup";
    $VoiceModemStatus = "Failure";
    $VoiceModemMode   = "";
    set $timer_waitforanswer 0;     # Reset possibility of failing
}
if ( $VoiceModemMode eq "delivermsg" and $VoiceModemStatus eq "donesendmsg" ) {
    run_voice_cmd "Voice Hangup";
    print_log "VOICE - Message Delivered Successfully...";
    $VoiceModemStatus = "Success";
    $VoiceModemMode   = "";
}
########################
# Secondary Procedures #
########################
# -------------------------- Put MODEM in Voice Mode
$v_voice_mode = new Voice_Cmd('Put MODEM in Voice Mode');
if ( said $v_voice_mode) {

    #TL is the Volume Level - Default is 3F44 - Range 0000 to 7FFF
    #VRA=35 makes the modem wait for 3.5 sec. of silence after ringing stops - Default is 45
    #set $phone_modem 'ATE0#CLS=8#VBS=4S30=60#BDR=0#VSP=20#VSS=1#VLS=0#TL=5800#VRA=35';
    #Changed S30 (Disconnect Inact Timer) to 0
    set $phone_modem
      'ATE0#CLS=8#VBS=4S30=0#BDR=0#VSP=20#VSS=1#VLS=0#TL=5800#VRA=35';
    print_log "VOICE - MODEM is now in VOICE Mode";
}

# -------------------------- Beep
$v_voice_beep = new Voice_Cmd('Beep');
if ( said $v_voice_beep) {

    # AT#VTS sends out beeps - 1000 is the frequency, 3 is the duration
    set $phone_modem 'AT#VTS=[1000,1000,3]';
    print_log "VOICE - Test Beeps Sent";
}

# -------------------------- DTMF Send
$v_voice_dtmftest = new Voice_Cmd('DTMF Test 2 Send');
if ( said $v_voice_dtmftest) {
    set $phone_modem 'AT#VTS={2}';
    print_log "VOICE - Test DTMF Sent";
}

# -------------------------- Voice Hangup
$v_voice_hangup = new Voice_Cmd('Voice Hangup');
if ( said $v_voice_hangup) {
    set $phone_modem 'ATH';
    $VoiceModemStatus = "";
    $VoiceModemMode   = "";
    print_log "VOICE - MODEM is now OUT of VOICE Mode";
}

# -------------------------- Dial Number
$v_voice_dial = new Voice_Cmd('Dial Number');
if ( said $v_voice_dial) {
    $VoiceModemStatus = "Dialing";
    print_log "VOICE - Dialing $DialNumber...";
    $DialNumber = "ATDT" . $DialNumber;
    set $phone_modem $DialNumber;
}

# -------------------------- Answer Phone
$v_voice_answer = new Voice_Cmd('Answer');
if ( said $v_voice_answer) {
    $VoiceModemStatus = "Answered";
    set $phone_modem 'ATA';
    print_log "VOICE - Picked up line ... listening for tones...";
}

# -------------------------- Send Voice Data
$v_voice_send = new Voice_Cmd('Send Voice Data');
if ( said $v_voice_send) {
    set $phone_modem 'AT#VTX';
    set $timer_sendvoice 1;

    #select undef, undef, undef, .5 / 1000;             # Wait 1/2 sec.
    print_log "VOICE - Initial Voice Transmit Mode ... STANDBY";
}
if ( expired $timer_sendvoice) {

    # The VOX File is a Rockwell 4 bit ADPCM Encoded Sound file,
    # sampled at 7200 hz.  I used a program called "Vox Studio"
    # to convert a standard 11 KHz WAV file into the format.
    # Go to  http://www.xentec.be/download/download.htm
    # for a limited demo copy (up to 5 second sound files)
    $voxfile = file_read $SendVoiceFile;    # The File
    set $phone_modem $voxfile;              # Send 2 Modem
    set $timer_endvoice 1;                  # Wait 1 Sec
    print_log "VOICE - Voice File Sent";
}
if ( expired $timer_endvoice) {             # After 1 sec,
    set $phone_modem '';                  # Send END
    $VoiceModemStatus = 'donesendmsg';
    print_log "VOICE - Voice Transmit Mode Cleared";
}

# -------------------------- Record a Message
$v_record_msg = new Voice_Cmd('Record a message');
if ( said $v_record_msg) {
    print_log "VOICE - Recording message.";
    set $phone_modem 'AT#VRX';
    $VoiceModemStatus = 'record';
    my $file = "$config_parms{data_dir}/phone/msg.r4";
    open( VOX, ">>$file" ) or print "Error in opening file $file:$@\n";
    binmode VOX;

    # Change from record mode, so we ignore /n
    $Serial_Ports{serial2}{datatype} = 'raw';
}
if ( $VoiceModemStatus eq 'record' and $PhoneModemString ) {
    my $l = length $PhoneModemString;
    print "l=$l\n";

    # Look for close, busy, or dialtone
    if ( $PhoneModemString =~ /(.+)\x10[qbds\#](.*)/ ) {
        print VOX $1;
        close VOX;
        set $phone_modem "";    # Send command to stop recording
        $Serial_Ports{serial2}{data}     = $2;            # Store left over data
        $Serial_Ports{serial2}{datatype} = 'record';
        $VoiceModemStatus                = 'recorddone';
        print_log "VOICE - Message recorded.";
        print "\nVOICE - Message recorded.\n\n";
        $VoiceMsgCount = $VoiceMsgCount + 1;    # Increment Msg Counter
    }
    else {
        print VOX $PhoneModemString;
    }
}

# -------------------------- Play Received Messages
$v_play_messages = new Voice_Cmd('Play Messages');
if ( said $v_play_messages) {
    $SendVoiceFile = "c:/mh/data/phone/msg.r4";    # Voice File to Play
    run_voice_cmd "Send Voice Data";
}

# -------------------------- Analyze Incoming Text from MODEM
if ( substr( $PhoneModemString, 0, 4 ) eq 'RING' ) {
    $RingCount = $RingCount + 1;
}
if ( $Serial_Ports{serial2}{data} =~ /(\d)/ ) {
    $VoiceModemStatus = $1;
    print_log "VOICE - Detected Button $VoiceModemStatus pressed.";
    $Serial_Ports{serial2}{data} = "";
}
if ( $Serial_Ports{serial2}{data} =~ /(\*)/ ) {
    $VoiceModemStatus = $1;
    print_log "VOICE - Detected Button $VoiceModemStatus pressed.";
    $Serial_Ports{serial2}{data} = "";
}
if ( $Serial_Ports{serial2}{data} =~ /(\#)/ ) {
    $VoiceModemStatus = $1;
    print_log "VOICE - Detected Button $VoiceModemStatus pressed.";
    $Serial_Ports{serial2}{data} = "";
}
if ( $Serial_Ports{serial2}{data} =~ /b/ ) {
    $VoiceModemStatus = "Remote Busy";
    print_log "VOICE - Remote Busy.";
    $Serial_Ports{serial2}{data} = "";
}
if ( substr( $PhoneModemString, 0, 4 ) eq 'BUSY' ) {
    $VoiceModemStatus = "Remote Busy";
    print_log "VOICE - Remote Busy.";
}
if ( $Serial_Ports{serial2}{data} =~ /d/ ) {
    $VoiceModemStatus = "Dialtone";
    print_log "VOICE - Dial Tone Detected.";
    $Serial_Ports{serial2}{data} = "";
}
if ( $Serial_Ports{serial2}{data} =~ /r/ ) {
    $VoiceModemStatus = "Remote Ring";
    print_log "VOICE - Remote Ring.";
    $Serial_Ports{serial2}{data} = "";
}
if ( substr( $PhoneModemString, 0, 4 ) eq 'VCON' ) {
    $VoiceModemStatus = "Connect";
    print_log "VOICE - Connected to Remote.";
}
