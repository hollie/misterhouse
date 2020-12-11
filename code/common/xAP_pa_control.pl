# Category = MisterHouse

#@ Allows the rooms= speak and play parm to target specific rooms via a xAP/xPL client PA system.
#@ See comment at the end of this file for example .mht entries.

=begin comment
@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@

File:
	pa_control.pl

Description:
	Centralized control of various PA zone types.

Author:
	Steve Switzer
	steve@switzerny.org

License:
	This free software is licensed under the terms of the GNU public license.

Requires:
        PAobj.pm from the lib directory
        pa.mht, or other mht file listing all of your PA zones. See end of file for ezample

Special Thanks to:
	Bruce Winter - MH
	Jason Sharpee - Example Perl Modules to "steal",learn from. :)
        Ross Towbin - Providing me with code snippets for "setting weeder with more than 8 ports"

@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
=cut

use PAobj;

$xapctrl = new PAobj( 'xap', 'xap' );
$xplctrl = new PAobj( 'xpl', 'xpl' );

$xapctrl->init() if $Reload;
$xplctrl->init() if $Reload;

# Stuff to flag which rooms to turn on based on "rooms=" parm in speak command
&Speak_pre_add_hook( \&xap_pa_control_stub ) if $Reload;
&Play_pre_add_hook( \&xap_pa_control_stub )  if $Reload;

sub xap_pa_control_stub {
    my (%parms) = @_;

    return unless $parms{text};

    my @pazones;
    my $mode = $parms{mode};
    unless ($mode) {
        if ( defined $mode_mh ) {
            $mode = state $mode_mh;
        }
        else {
            $mode = $Save{mode};
        }
    }
    return if $mode eq 'mute' or $mode eq 'offline';

    my $rooms = $parms{rooms};

    #print "pa_stub db: rooms=$rooms, mode=$mode\n";

    my $msg = $parms{text};
    $xapctrl->set_xap( $rooms, $mode, %parms );
    $xplctrl->set_xpl( $rooms, $mode, %parms );
}

=begin comment
@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@

Example pa.mht file:

#
# Type    Target   		Name           Groups               	ClassName          Protocol
#

PA,	mhouse.festival.client1,office,		all|basement,			tts.speak, xap
PA,	tony-tts.castor,	office2,	all|default|upstairs,		tts.basic, xpl


Type:        "PA", constant. This must be there.

Address:     The "target" of the xAP or xPL message.  Normally, this is a registered xAP or
	     xPL client app and therefore has a specific address.

Name:        Give a name to the pa zone, usually the room name. You use these in the
             speak and play commands with rooms=.

Groups:      "all" and "default" are required. "all" should not include speaker zones that
             you don't want to accidentally speak to. Some people have outside PA speakers,
             but rarely want to speak to them. You can create a custom group like "all_and_out"
             for those times when you want to speak to the outside speakers as well.
             "default" is a group that's used for times when speak or play is called without a
             rooms= parm. If no rooms are specified, all zones in the "default" group will be
             used.

Class Name: The name of the serial port that you use for communicating with the IO device.
             The default is "weeder". Note that this default can be changed with an INI parm.

		# *** What INI parm?


Protocol:    either "xap" or "xpl"--depending upon which protocol is used by the target device

@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
=cut
