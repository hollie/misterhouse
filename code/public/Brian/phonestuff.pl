############################################################
#  Klier Home Automation - Caller ID Module for Rockwell   #
#  Version 2.2 Release                                     #
#  By: Brian J. Klier, N0QVC                               #
#  Thanks for the mucho help from: Bruce Winter            #
#  E-Mail: klier@lakes.com                                 #
#  Webpage: http://www.faribault.k12.mn.us/brian           #
############################################################

# Category=Phone

# Declare Variables

use vars
  qw($CompPhoneNumber $PhoneName $PhoneNumber $PhoneTime $PhoneDate $PhoneNumberSpoken);

# Set Variables used by my custom code to match the callerid.pl

$PhoneName   = $cid_item->name();
$PhoneNumber = $cid_item->number();
$PhoneTime   = localtime( $cid_item->{set_time} );

# IF Phone Rings, play a wave file.

if ( state_now $cid_interface1 eq 'ring' ) {
    play( 'file' => 'c:\mh\sounds\st-ring230.wav' );

    #set $TV 'mute';
}

# Page my phone if there's a new call

if ( $CompPhoneNumber ne $PhoneNumber ) {
    if ( state $current_away_mode eq 'away' ) {
        $page_email = "Call from $PhoneName - $PhoneNumber - $PhoneTime";
    }
    $CompPhoneNumber = $PhoneNumber;
}
