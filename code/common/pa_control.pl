# Category = MisterHouse

#@ Allows the rooms= speak and play parm to target specific rooms via a weeder relay or X10 controled PA system.
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
my $pa_port	= $config_parms{pa_port};
my $pa_delay	= $config_parms{pa_delay};
my $pa_type	= $config_parms{pa_type};
my $pa_timer	= $config_parms{pa_timer};
$pa_port	= 'weeder'	unless $pa_port;
$pa_delay	= 0.5		unless $pa_delay;
$pa_type	= 'wdio'	unless $pa_type;
$pa_timer	= 60		unless $pa_timer;

#Make 'default' group if it wasn't created in a .MHT file first
# No, in order to allow for a real default, we must require a real default.
#$pa_default = new Group unless &::get_object_by_name("pa_default");

$v_pa_test = new Voice_Cmd('test pa');
if ($state = said $v_pa_test) {
    #speak "nolog=1 rooms=all mode=unmuted volume=100 Hello. This is a PA system test.";
    speak "nolog=1 rooms=downstairs mode=unmuted volume=100 Hi!";
}

$v_pa_speakers = new  Voice_Cmd('speakers [on,off]');
$v_pa_speakers-> set_info('Turn all the PA speakers on/off');

# turn all speakers on/off
if ($state = said $v_pa_speakers) {
    $state = ($state eq 'on') ? ON : OFF;
    $pactrl->set('allspeakers',$state,'unmuted');
}

$pactrl = new PAobj($pa_type,$pa_port);
$pactrl->set_delay($pa_delay);

$pactrl->init() if $Startup or $Reload;
#set $mh_speakers OFF if $Startup;

# Stuff to flag which rooms to turn on based on "rooms=" parm in speak command 
&Speak_pre_add_hook(\&pa_control_stub) if $Reload;
&Play_pre_add_hook (\&pa_control_stub) if $Reload;

sub pa_control_stub {
    my (%parms) = @_;
    my @pazones;
    my $mode = $parms{mode};
    unless ($mode) {
        if (defined $mode_mh) {
            $mode = state $mode_mh;
        } else {
            $mode = $Save{mode};
        }
    }
    return if $mode eq 'mute' or $mode eq 'offline';

    my $rooms = $parms{rooms};
    #print "pa_stub db: rooms=$rooms, mode=$mode\n";

    my $results = $pactrl->set($rooms,ON,$mode);
    #print "PA set results: $results\n";
    set $pa_speaker_timer $pa_timer if $results;
}

          #Turn off speakers when MH says it's done speaking/playing
if (state_now $mh_speakers eq OFF) {
    unset $pa_speaker_timer;
    $pactrl->set('allspeakers',OFF,'normal');
}

          #Setup Fail-safe speaker shutoff
$pa_speaker_timer = new Timer;
set $pa_speaker_timer 60 if state_now $mh_speakers eq ON;
if (expired $pa_speaker_timer) {
#print "Timer expired\n";
    set $mh_speakers OFF;
    #$pactrl->set('allspeakers',OFF,'normal');
}

=begin comment
@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@

Example pa.mht file:

#
# Type    Address   Name           Groups               Serial Name          Other
#

PA,	AA,	kitchen,	all|default|mainfloor,		weeder, wdio
PA,	AB,	server,		all|basement,			weeder, wdio
PA,	AG,	master,		all|default|upstairs,		weeder, wdio


Type:        "PA", constant. This must be there.

Address:     2 characters. First character is the weeder address, the second is the pin
             if the command to turn on the pin you want is: BHC, then the Address is: BC

Name:        Give a name to the pa zone, usually the room name. You use these in the
             speak and play commands with rooms=.

Groups:      "all" and "default" are required. "all" should not include speaker zones that
             you don't want to accidentally speak to. Some people have outside PA speakers,
             but rarely want to speak to them. You can create a custom group like "all_and_out"
             for those times when you want to speak to the outside speakers as well.
             "default" is a group that's used for times when speak or play is called without a
             rooms= parm. If no rooms are specified, all zones in the "default" group will be
             used.

Serial Name: The name of the serial port that you use for communcating to the IO device.
             The default is "weeder". Note that this can be changed with an INI parm.

Other:       Optional. Sets the type of PA control. Defaults to 'wdio'. Available options are:
             wdio,wdio_old,X10

@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
=cut
