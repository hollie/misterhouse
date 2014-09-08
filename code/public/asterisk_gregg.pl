# Category=Phone

use Telephony_Interface;
use CID_Lookup;
use CID_Log;
use CID_Announce1;
use CID_Server;
use Telephony_xAP;
use xAP_Items;

#@ Intercepts and processes xap events: outgoing.callcomplete for DTMF
#@ and incoming callwithcid for CID

# Note: Telephony_xAP "maps" the extension and line info from the originating
# xAP source message using the ini vars: phone_line_names and phone_line_extensions.
# My entries are as follows:
# phone_line_names = gregg_desk\.* => Gregg-Business
## note the use of regex to allow all the lines that can connect to gregg_desk
## extension to be mapped to Gregg-Business.  That's actually wrong since
## I do call out on the home line.  So, a better example would be
# phone_line_names = gregg_desk.nufone => Gregg-Business, gregg_desk.voipjet => Gregg-Business,
#      gregg_desk.home => Home
#
# phone_extension_names = gregg_desk => Gregg-Desk
#

# create the meteor xAP listener
# Background: CID.Meteor is the original xAP message schema designed around the Meteor device
# Because telephony has evolved, a new schema, CTI, will eventually replace it.
# Telephony xAP attempts to support both as well as does axc (Asterisk xAP Connector)
# Note: the use of '>:>' as a xAP source filter says to listen for all messages from all
# endpoints.  It is likely that this will need to change to something like
# '>:gregg_desk.*' to differentiate which extension is ringing. This will definitely
# be the case once on-/off-hook state tracking is added to Telephony_xAP
$gregg_meteor_item = new xAP_Item( 'CID.Meteor', '>:gregg_desk.*' );
$guest_meteor_item = new xAP_Item( 'CID.Meteor', '>:guest.*' );

# create the CTI xAP listener
$gregg_cti_item = new xAP_Item( 'CTI.*', '>:gregg_desk.*' );
$guest_cti_item = new xAP_Item( 'CTI.*', '>:gues.*' );

# create the CTI2 xAP listener
# sigh... CTI2 only exists because the CTI folks have not yet adopted the
# concept of voicemail message counts.  Hopefully, this will change
# and CTI2 can go away.
$vm_cti2_item = new xAP_Item( 'CTI2.*', '>:vm.default.*' );

# create the asterisk telephony item instance
# It is the "glue" that extracts useful info out of the xAP objects related to
# telephony info.  Note the use of the pound noloop.  I probably ought to
# just support a constructor that handles an array of xAP objects rather than
# the add_xap_item syntax.
$gregg_tel_item = new Telephony_xAP($gregg_cti_item);
$gregg_tel_item->add_xap_item($gregg_meteor_item);    #noloop

#$ast_tel_item->add_xap_item($xap_cti2_item); #noloop
$guest_tel_item = new Telephony_xAP($guest_cti_item);
$guest_tel_item->add_xap_item($guest_meteor_item);    #noloop

# declare the call_type for $ast_tel_item statically since Telephony_xAP doesn't (yet) support dynamic detection
# call_type is used by the outbound call logs
$gregg_tel_item->call_type('POTS');
$guest_tel_item->call_type('POTS');

# create the asterisk MWI item instance
$vm_mwi_item = new MWI_xAP($vm_cti2_item);

# create the net callerid item instance - since we can use the call waiting feature
# which * doesn't support for FXO lines
$ncid_tel_item = new Telephony_Interface(
    $config_parms{callerid_name},
    $config_parms{callerid_port},
    $config_parms{callerid_type}
);

# create the lookup object so that inbound and outbound numbers can be converted
# add both telephony interface items to it
# Note: it will become important that I add event filters once I setup multiple
# Telephony_xAP objects that might get the same intercepted inbound call.  Otherwise,
# we'd get multiple announcements and logged entries.  I'll probably implement
# some mechanism of tracking those calls w/ a timer and just reset the
# object state to something that won't trigger downstream events
$cid_look = new CID_Lookup($gregg_tel_item);
$cid_look->add($ncid_tel_item);     #noloop
$cid_look->add($guest_tel_item);    #noloop

# create the logger to get both in and outbound info (note: outbound info isn't available
#  from the ncid.  That's the reason that I use axc to monitor outbound calls for the house (pstn)
#  but use ncid for pstn inbound
$cid_logger = new CID_Log($cid_look);

# create the announce object.  Note that I use a variant of the original.
# CID_Announce1 ISA CID_Announce and only includes an override of the parse function
# that generates the $format1 string.  This is because I don't want to hear
# location info derived from area code.  Instead just speak the number if not in
# my phone.callerid.list and/or if the callername includes the words "call" in it
# (which is virtually call cell calls and many businesses)
$cid_announce =
  new CID_Announce1( $cid_look, 'Call from $format1 on $address' );

# tie OSD logic to a cid lookup state change
# This is used to display CID info on my squeezebox.  Note that it uses
# a different format than is spoken--which is quite deliberate
$cid_look->tie_event('osd_hook($cid_look)');    #noloop

$vm_mwi_item->tie_event('mwi_hook($vm_mwi_item)');            #noloop
$gregg_tel_item->tie_event('onoff_hook($gregg_tel_item)');    #noloop

my $gregg_vm_new = $Save{'gregg_vm_new'} if $Reload;
$gregg_vm_new = 0 unless $gregg_vm_new;

sub mwi_hook {
    my ($mwi_item) = @_;
    if ( defined($mwi_item) ) {
        my $changed_mwi = $mwi_item->mwi_changed;
        if ( defined($changed_mwi) ) {

            # mailbox names are consistent w/ asterisk's <mailbox>@<vmcontext>
            #   naming conventions
            if ( $$changed_mwi{mailbox} eq '01@default' ) {
                $gregg_vm_new = $$changed_mwi{newmessages};
                $Save{'gregg_vm_new'} = $gregg_vm_new;
            }
        }
    }
}

# if new messages exist, display an OSD message every minute
if ( $New_Minute && $gregg_vm_new ) {
    &display_vm_info('Gregg');
}

sub display_vm_info {
    my ($username) = @_;
    my $vm_msg = "$username has $gregg_vm_new new vm message(s)";

    # display the message for 15 seconds
    &xAP::send( 'xPL', 'slimdev-slimserv.squeezebox',
        'osd.basic' => { command => 'write', delay => 15, text => $vm_msg } );
}

sub onoff_hook {
    my ($tel_item) = @_;
    if ( defined($tel_item) ) {
        if ( $tel_item->state_now =~ /^cid/i ) {
            print "gregg desk cid hook\n";
        }
        elsif ( $tel_item->state_now =~ /^onhook/i ) {
            &xAP::send(
                'xPL',
                'xplmedia-client.basementdesk',
                'media.basic' => { command => 'mute', state => 'OFF' }
            );
        }
        elsif ( $tel_item->state_now =~ /^offhook/i ) {
            &xAP::send(
                'xPL',
                'xplmedia-client.basementdesk',
                'media.basic' => { command => 'mute', state => 'ON' }
            );
        }
    }
    else {
        print "Warning - no tel_item passed to onoff_hook hook";
    }
}

sub osd_hook {
    my ($cid_lookup) = @_;

    if ( defined $cid_lookup && ( $cid_lookup->state() =~ /^cid/i ) ) {
        my $osd_format;
        $osd_format = $cid_lookup->cid_name();
        my $display_time;

        # set the default display time to 30 secs (for callers that we know)
        $display_time = 30;
        if ( ( $osd_format =~ /CALL/i or lc $osd_format =~ /unknown/i )
            and $cid_lookup->formated_number() )
        {
            # any callerid info that is unuseful like "unknown" or "ohio call" or "cellular call"
            # we'll instead display their phone number--which is *much* more useful
            $osd_format = $cid_lookup->formated_number();

            # and, display it longer since we may be dialing it back (or attempting to recall)
            $display_time = 60;
        }
        my $line;
        $line = $cid_lookup->address();
        my $line2 = $osd_format . " on " . $line;
        $osd_format = "\\n" . $osd_format . " on " . $line;
        &xAP::send(
            'xPL',
            'slimdev-slimserv.squeezebox',
            'osd.basic' => {
                command => 'write',
                delay   => $display_time,
                text    => $osd_format
            }
        );
        &xAP::send(
            'xPL',
            'xplmedia-client.basementdesk',
            'osd.basic' => {
                command => 'write',
                delay   => $display_time,
                text    => $osd_format
            }
        );
    }
}
