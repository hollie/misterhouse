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
	Steve Switzer (Pmatis)
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

#noloop=start
my $pa_delay       = $config_parms{pa_delay};
my $pa_clash_delay = $config_parms{pa_clash_delay};
my $pa_timer       = $config_parms{pa_timer};
$pa_clash_delay = 1   unless $pa_clash_delay;
$pa_delay       = 0.5 unless $pa_delay;
$pa_timer       = 60  unless $pa_timer;
$pactrl         = new PAobj();
$pactrl->set_delay($pa_delay);
$v_pa_test     = new Voice_Cmd('test pa');
$v_pa_speakers = new Voice_Cmd('speakers [on,off]');
$v_pa_speakers->set_info('Turn all the PA speakers on/off');

#noloop=stop

$pactrl->init() if $Startup or $Reload;

# Hooks to flag which rooms to turn on based on "rooms=" parm in speak command
if ($Reload) {
    print_log("PA: Hooking into speech events");
    &Speak_parms_add_hook( \&pa_parms_stub );
    &Speak_pre_add_hook( \&pa_control_stub );
    &Play_parms_add_hook( \&pa_parms_stub );
    &Play_pre_add_hook( \&pa_control_stub );
}
if ( said $v_pa_test) {
    my $state = $v_pa_test->{state};
    $v_pa_test->respond('app=pa Testing PA...');
    speak
      "nolog=1 rooms=all mode=unmuted volume=80 Hello. This is a PA system test.";

    #speak "nolog=1 rooms=downstairs mode=unmuted volume=100 Hi!";
}

# turn all speakers on/off
if ( said $v_pa_speakers) {
    my $state = $v_pa_speakers->{state};
    $v_pa_speakers->respond("app=pa Turning speakers $state...");
    $state = ( $state eq 'on' ) ? ON : OFF;
    print_log("PA: Turning speakers $state") if $Debug{pa};
    $pactrl->set( 'allspeakers', $state, 'unmuted' );
}

sub pa_parms_stub {
    my ($parms) = @_;
    my $mode = $parms->{mode};
    unless ($mode) {
        if ( defined $mode_mh ) {    # *** Outdated (?)
            $mode = state $mode_mh;
        }
        else {
            $mode = $Save{mode};
        }
    }
    $parms->{pa_mode} = $mode;
    return if $mode eq 'mute' or $mode eq 'offline';

    if ( $pactrl->active(1) ) {
        my $results  = $pactrl->prep_parms($parms);
        my %pa_zones = $pactrl->get_pa_zones();

        if ( defined $pa_zones{audrey} && $pa_zones{audrey} ne '' ) {
            print_log( "PA: audrey zone detected, hooking via web_hook. ("
                  . $pa_zones{audrey}
                  . ")" )
              if $Debug{pa};
            push( @{ $parms->{web_hook} }, \&pa_web_hook );
        }

        print_log("PA: parms_stub set results: $results") if $Debug{pa} >= 2;

    }
    else {
        #MH is already speaking, and other PA zones are already active. Delay speech.
        if ( $main::Debug{voice} ) {
            $parms->{clash_retry} = 0 unless $parms->{clash_retry};
            &print_log(
                "PA SPEECH CLASH($parms->{clash_retry}): Delaying speech call for "
                  . $parms->{text}
                  . "\n" )
              unless $parms->{clash_retry} lt 1;
            $parms->{clash_retry}++;    #To track how many loops are made
        }
        $parms->{nolog} = 1;    #To stop MH from logging the speech again

        my $parmstxt;
        my ( $pkey, $pval );
        while ( ( $pkey, $pval ) = each( %{$parms} ) ) {
            $parmstxt .= ', ' if $parmstxt;
            $parmstxt .= "$pkey => q($pval)";
        }
        &print_log("PA SPEECH CLASH Parameters: $parmstxt")
          if $main::Debug{voice} && $parms->{clash_retry} eq 0;
        &run_after_delay( $pa_clash_delay, "speak($parmstxt)" );

        $parms->{no_speak} = 1;    #To stop MH from speaking this time around
        return;
    }
    if ( $parms->{clash_retry} ) {
        &print_log("PA SPEECH CLASH: Resolved, continuing speech.");
    }
}

sub pa_control_stub {
    my (%parms) = @_;
    my @pazones;
    my $mode = $parms{pa_mode};
    return if $mode eq 'mute' or $mode eq 'offline';

    my $rooms = $parms{rooms};
    print_log("PA: control_stub: rooms=$rooms, mode=$mode") if $Debug{pa};
    my $results = $pactrl->audio_hook( ON, \%parms );
    print_log("PA: control_stub set results: $results") if $Debug{pa} >= 2;
    set $pa_speaker_timer $pa_timer if $results;
    return $results;
}

sub pa_web_hook {
    my (%parms) = @_;
    $pactrl->web_hook( \%parms );
}

#Turn off speakers when MH says it's done speaking/playing
if ( state_now $mh_speakers eq OFF ) {
    unset $pa_speaker_timer;
    print_log("PA: Turning speakers off") if $Debug{pa};
    $pactrl->audio_hook( OFF, 'normal' );
    $pactrl->active(0);
}

#Setup Fail-safe speaker shutoff
$pa_speaker_timer = new Timer;
set $pa_speaker_timer 60 if state_now $mh_speakers eq ON;
if ( expired $pa_speaker_timer) {
    print_log("PA: Timer expired. Forcing PA speakers off.") if $Debug{pa};
    set $mh_speakers OFF;
}

=begin comment
@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@

Example pa.mht file:

#
#Type Address	Name			Groups               		Serial   Type
#
PA,	AA,		kitchen,	all|default|mainfloor,		weeder, wdio
PA,	AB,		server,		all|basement,			weeder, wdio
PA,	AG,		master,		all|default|upstairs,		weeder2, wdio_old
PA,	B12,		garage,		all|outside,				, X10
PA,	objname,	living,		all|mainfloor,				, object
PA,	192.168.0.1,family,		all|mainfloor,				, xap
PA,	192.168.0.2,dining,		all|mainfloor,				, xpl
PA,	192.168.0.3,table,		all|mainfloor,				, audrey
#
PA,	Headphone:0:L,	mix1l,		all,					, amixer
PA,	Headphone:0:R,	mix1r,		all,					, amixer
PA,	Headphone:1,	mix2,		all,					, amixer
PA,	Headphone:1:R,	mix2r,		all,					, amixer


Type:        "PA", constant. This must be there.

Address:     Address or Object name.
             If Type is "object", then this should be an object name that can accept an ON or OFF
             For Weeder, 2 characters. First character is the weeder address, the second is the pin
               if the command to turn on the pin you want is: BHC, then the Address is: BC
             For X10, the X10 address of the (likely) relay device.
             For xAP, xPL and audrey, use the IP address or hostname of the target device.
             For amixer (Linux Only), use the alsa mixer name. My laptop has "Headphone" and
               "Headphone 1". This is really "Headphone,0" and "Headphone,1". They are also both
               stereo. Use : as a separator, and then add L or R to control the left or right
               channel. Omitting this causes BOTH channels to be turned on. There's several examples
               above.
             For "object", use the name of the object (without the $). You may use anything that
               responds ON and OFF set commands. Tested with and Insteon device.

Name:        Give a name to the pa zone, usually the room name. You use these in the
             speak and play commands with rooms=.

Groups:      "all" and "default" are required. "all" should not include speaker zones that
             you don't want to accidentally speak to. Some people have outside PA speakers,
             but rarely want to speak to them. You can create a custom group like "all_and_out"
             for those times when you want to speak to the outside speakers as well.
             "default" is a group that's used for times when speak or play is called without a
             rooms= parm. If no rooms are specified, all zones in the "default" group will be
             used.

Serial:      The name of the serial port that you use for communcating to the IO device.
             The default is "weeder". Note that this can be changed with an INI parm.

Other:       Optional. Sets the type of PA control. Defaults to 'wdio'. Available options are:
             wdio,wdio_old,X10,xpl,xap,audrey,amixer,object

@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
=begin Audrey Config

Exerpt from audreyspeak.pl

You must make certain modifications to your Audrey, as follows:

- Update the software and obtain root shell access capabilities (this
  should be available by using Bruce's CF card image or by following
  instructions available on the internet.)

- Open the Audrey's web server to outside http requests
  1) Start the "Root Shell"
  2) type: cd /config
  3) type: cp rm-apps rm-apps.copy
  4) type: vi rm-apps
     You'll be in the editor, editing the "rm-apps" file
     About the 14th line down is "rb,/kojak/kojak-slinger, -c -e -s -i 127.1"
     You need to delete the "-i 127.1" from the line.
     To do this, place the cursor under the space right after the "-s"
     Type the "x" key to start deleting from the line.
     The line should end up looking like this:
     "rb,/kojak/kojak-slinger, -c -e -s"
     If you need to start over type a colon to get to the vi command line
     At the colon prompt type "q!" and hit "enter" (this quits without saving)
     If it looks good then at the colon prompt type "wq" to save changes
     Now restart the Audrey by unplugging it, waiting 30 seconds and
     plugging it back in.

- Install playsound_noph and it's DLL
  1) Grab the zip file from http://www.planetwebb.com/audrey/
  2) Place playsound_noph    on the Audrey in /nto/photon/bin/
  3) Place soundfile_noph.so on the Audrey in /nto/photon/dll/

- Install mhspeak.shtml on the Audrey
  1) Start the "Root Shell"
  2) type: cd /data/XML
  3) type: ftp blah.com mhspeak.shtml

     The MHSPEAK.SHTML file placed on the Audrey should contain the following:

     <html>
     <head>
     <title>Shell</title>
     </head>
     <body>
     <!--#config cmdecho="OFF" -->
     <!--#exec cmd="playsound_noph $QUERY_STRING &" -->
     </body>
     </html>

=cut
