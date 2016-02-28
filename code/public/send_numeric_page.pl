# Send numeric pages

# Author:  Jeff Zwickel  (jeffz1@usa.net)
# Version: 1.0
# Date:    May 25, 1999

# The following routines enable a numeric page to be sent using a standard modem with Mister House
# See the usage information below for details
# Desired enhancements:
#    Queue pages if the modem is busy
#    Check modem port status for conflict with other processes
#    Use paging company feedback tones if possible to confirm message delivery

### Test routines ########################################
# A "123" will be sent to the pager accessed via 555-1212 and the custom message will be spoken and logged
$v_page_jeff = new Voice_Cmd('Page Jeff to come home');
&send_page( "123", "555-1212", "Paging Jeff: Please come home" )
  if said $v_page_jeff;

# A default page will be sent - using the sample code, this will send "555-3434" to the same pager as above
$v_page_default = new Voice_Cmd('Send default page');
&send_page( "", "", "" ) if said $v_page_default;

# A page of "555-3434*999 will be sent to the default pager.  A custom voice/print message is provided.
# Note that most numeric pagers will display this message as "5553434-999"
$v_page_call_home = new Voice_Cmd('Page Jeff to call home now');
&send_page( "555-3434*999", "", "Paging Jeff: call home as soon as possible" )
  if said $v_page_call_home;
###########################################################

# A timer and a state variable are needed to control the modem hang-up
$serial_out = new Serial_Item( undef, undef, 'serial1' )
  ;    # Needs to match setting in .ini file
$pager_timer = new Timer();
my $modem_mode = "idle";

# Assemble and send the pager command
# Usage:
#   send_page (Message_to_transmit, Pager_phone_number, Text/voice_message)
#              if the Message_to_transmit is left blank, the default message provided below will be used
#              if the Pager_phone_number is left blank, the default number provided below will be used
#              if the Text/voice_message is left blank, the Pager_phone_number and Message_to_tranmit will be used
sub send_page {
    if ( $modem_mode ne "idle" ) {
        speak "Modem busy - Please retry your page again later";
    }
    else {
        my ( $pager_msg, $pager_num, $print_msg ) = @_;
        my $pager_command = "";
        $pager_num = "555-1212"
          if $pager_num eq "";    ### provide default pager number here
        $pager_msg = "555-3434"
          if $pager_msg eq "";    ### provide default message here
        $print_msg = "Paging " . $pager_num . " with " . $pager_msg
          if $print_msg eq "";
        print_log
          "Sending page to $pager_num with message $pager_msg, Print string is $print_msg\n";
        speak("$print_msg");
        $modem_mode = "paging";
        ### ensure that the correct key to send the page is specified below.  Most paging services use a "#"
        $pager_command = "ATDT" . $pager_num . ",," . $pager_msg . "#;";
        set $pager_timer 20
          ; ### 20 seconds works for local paging, 800 services may require more
        set $serial_out $pager_command;

        #       print "Page command is $pager_command\n";  ### Uncomment line for debugging
    }
}

# Hang up the phone after the page has been sent.
# It would be nice to trigger this off the phone line status,
# but modems will not recognize most paging company tones.
if ( $modem_mode eq "paging" && inactive $pager_timer) {
    set $serial_out "ATH";
    $modem_mode = "idle";
    print_log "Page complete";
}
