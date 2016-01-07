# Category = Audrey

#@ This module allows you to control your Audrey's screen, led lights,
#@ and play built-in sounds. These are more robust than other methods
#@ currently available. Audrey pre-configuration required, see code for
#@ instructions. Set mh.ini parm Audrey_IPs for your Audreys as follows:
#@
#@ Audrey_IPs=Kitchen-192.168.1.89,Bedroom-192.168.1.99

=begin comment

audrey_control.pl
 1.1 Bug fix - Tim Doyle 10/27/2002
 1.0 Original version by Tim Doyle <tim@greenscourt.com> - 10/26/2002

This MisterHouse script is built around the excellent trio of Audrey
utilities written and made available by James Mazrimas at
http://www.timemocksme.com/audrey/

Required pre-configuration:
 1. Remove the default restrictions in the Audrey web server.
 2. Place screen.shtml, led.shtml, and beep.shtml in the directory
    /data/XML/ on your Audrey.
 3. Place the files screen, led, and beep in the directory
    /nto/bin on your Audrey. Make them executable (chmod +x led, etc.)

Selected usage notes:

Audrey Screen Controller

"screen" is a utility to control and monitor the Audrey's LCD screen from the command line,
or remotely through the web server. Note that this program actually puts the Audrey into
and out of sleep mode, unlike calls to gpio. It can be used to go into sleep mode or wake
up at pre-set times by using cron, or by applications who's functionality depends on
knowing the state of the screen. This program uses the IPC system devised by 3Com to
control the LCD, and so it requires the built-in library called libkojak.so, which is
normally in /nto/lib.

http://YourAudreysIP/screen.shtml?0   (Go to sleep)
http://YourAudreysIP/screen.shtml?1   (Wake up)
http://YourAudreysIP/screen.shtml?t   (Toggle sleep mode)
http://YourAudreysIP/screen.shtml?p   (Print current state.  0 or 1 will show in the browser)

LED Controller

"led" is a quick utility to control the Audrey's mail and stylus LEDs from the command
line. Note that this program can control the two LEDs independently, unlike SetLEDState.
It can be useful for various applications to set either light to ON, FLASHING, or OFF
without affecting the other light, since this allows more information to be relayed at
a glance from across the room. The only requirement is that /kojak/ledmgr must be running
on the Audrey (this is a default driver).

led -t 1        -- turn on top LED
led -m 2        -- make mail LED flash
led -m 1 -t 2   -- turn mail LED on, flash top LED
led -m 0 -t 0   -- turn both LEDs off

http://YourAudreysIP/led.shtml?t1m2   (top LED on, mail LED flashing)
http://YourAudreysIP/led.shtml?t0     (top LED off, leaving mail flashing)
http://YourAudreysIP/led.shtml?m1     (mail LED to solid on)

Beep Utility

"beep" is a quick utility to play the Audrey's built-in short sound effects,
or customized sounds. The Audrey has a small library of clicks, chirps, and
beeps used by the various native applications. This utility is a very
lightweight way of playing those sound effects, without the need to launch
phplay or some other application. You can change which sounds are played by
overwriting the default sound effects with sounds of your own (see table below
for naming). The source code to implement this is very small, and can easily
be integrated into any application without the need to link to any kojak or
photon libraries. All that's required for this to work is to have the
/kojak/bleep resource manager running (check ps to make sure).

beep 0 Y   Play sound Y, where Y is from 0 to 18.  See below for names.
beep 1     Stop any playing sound effects.
beep 2     Disable any beep sound effects until re-enabled
beep 3     Enable beep sound effects.
beep 4 Y   Set sound volume to Y%, where Y is between 0 and 100.

Table of sounds playable with "beep 0 Y", where Y is one of the following:

0:   /tmp/snd/cancel-PCM.wav
1:   /tmp/snd/check-PCM.wav
2:   /tmp/snd/copy-PCM.wav
3:   /tmp/snd/cut-PCM.wav
4:   /tmp/snd/delete-PCM.wav
5:   /tmp/snd/help-PCM.wav
6:   /tmp/snd/major_high-PCM.wav
7:   /tmp/snd/menu_close-PCM.wav
8:   /tmp/snd/menu_open-PCM.wav
9:   /tmp/snd/minor_high-PCM.wav
10:  /tmp/snd/minor_low-PCM.wav
11:  /tmp/snd/paste-PCM.wav
12:  /tmp/snd/print-PCM.wav
13:  /tmp/snd/scroll_down_left-PCM.wav
14:  /tmp/snd/scroll_up_right-PCM.wav
15:  /tmp/snd/snapshot-PCM.wav
16:  /tmp/snd/warning-PCM.wav
17:  /tmp/snd/go_to_sleep-PCM.wav
18:  /tmp/snd/wake_up-PCM.wav

Note that when the resource manager starts up at Audrey startup, this
/tmp/snd directory is copied directly from /kojak/snd. You can replace
files in /tmp/snd without fear of permanently losing the original sounds.
However, your replacements will be overwritten each time Audrey reboots.
To permanently replace the sounds, put them in /kojak/snd with one of the
above names. (You might want to save off the original sound just in case).

http://YourAudreyIP/beep.shtml?0 2        (plays sound 2)
http://YourAudreyIP/beep.shtml?4 75       (turns volume to 75%)

=cut

# noloop=start
my ( %AudreyList, $Audip, $Audname, $AudreyChoices );
$AudreyChoices = '';
for ( split ',', $config_parms{Audrey_IPs} ) {
    ( $Audname, $Audip ) = /(.*)-(.*)/;
    $AudreyList{$Audname} = $Audip;
    $AudreyChoices .= $Audname . ',';
}

# noloop=stop

$v_audrey_select      = new Voice_Cmd("Select [$AudreyChoices] Audrey");
$v_audrey_screen      = new Voice_Cmd("Set Audrey [awake,asleep,toggle]");
$v_audrey_top_light   = new Voice_Cmd("Audrey top light [on,off,blinking]");
$v_audrey_mail_light  = new Voice_Cmd("Audrey mail light [on,off,blinking]");
$v_audrey_both_lights = new Voice_Cmd("Audrey lights both [on,off,blinking]");
$v_audrey_beeps      = new Voice_Cmd("Audrey beeps [enabled,disabled,stopped]");
$v_audrey_sound_play = new Voice_Cmd(
    "Play Audrey sound number [0,1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18]"
);
$v_audrey_volume = new Voice_Cmd(
    "Set Audrey volume to [1,10,20,25,30,40,50,60,70,75,80,90,100]");
$v_audrey_remote = new Voice_Cmd(
    "Push Audrey Button [browser,address_book,date_book,audrey_options,power_button,turn_knob_left,push_knob,turn_knob_right,mail,tab,enter]"
);
$v_audrey_sound_play_by_name = new Voice_Cmd(
    "Play Audrey sound [cancel,check,copy,cut,delete,help,major_high,menu_close,menu_open,minor_high,minor_low,paste,print,scroll_down,scroll_up,snapshot,warning,go_to_sleep,wake_up]"
);

if ( said $v_audrey_select) {
    my $state = $v_audrey_select->{state};
    $v_audrey_select->respond(
        "$state Audrey selected on IP $AudreyList{$state}");
    $Save{current_audrey} = $AudreyList{$state};
}

if ( said $v_audrey_screen) {
    my $state = $v_audrey_screen->{state};
    $v_audrey_screen->respond(
        "$Save{current_audrey} Audrey screen set to $state");
    $state = 0   if $state eq 'asleep';
    $state = 1   if $state eq 'awake';
    $state = "t" if $state eq 'toggle';
    get "http://$Save{current_audrey}/screen.shtml?$state";
}

if ( said $v_audrey_top_light) {
    my $state = $v_audrey_top_light->{state};
    $v_audrey_top_light->respond(
        "$Save{current_audrey} Audrey top light set to $state");
    $state = 0 if $state eq 'off';
    $state = 1 if $state eq 'on';
    $state = 2 if $state eq 'blinking';
    get "http://$Save{current_audrey}/led.shtml?t$state";
}

if ( said $v_audrey_mail_light) {
    my $state = $v_audrey_mail_light->{state};
    $v_audrey_mail_light->respond(
        "$Save{current_audrey} Audrey mail light set to $state");
    $state = 0 if $state eq 'off';
    $state = 1 if $state eq 'on';
    $state = 2 if $state eq 'blinking';
    get "http://$Save{current_audrey}/led.shtml?m$state";
}

if ( said $v_audrey_both_lights) {
    my $state = $v_audrey_both_lights->{state};
    $v_audrey_both_lights->respond(
        "Both $Save{current_audrey} Audrey lights set to $state");
    $state = 0 if $state eq 'off';
    $state = 1 if $state eq 'on';
    $state = 2 if $state eq 'blinking';
    $state = "t" . $state . "m" . $state;
    get "http://$Save{current_audrey}/led.shtml?$state";
}

if ( said $v_audrey_beeps) {
    my $state = $v_audrey_beeps->{state};
    $v_audrey_beeps->respond(
        "$Save{current_audrey} Audrey beeps set to $state");
    $state = 1 if $state eq 'stopped';
    $state = 2 if $state eq 'disabled';
    $state = 3 if $state eq 'enabled';
    get "http://$Save{current_audrey}/beep.shtml?$state";
}

if ( said $v_audrey_sound_play_by_name) {
    my $state = $v_audrey_sound_play_by_name->{state};
    $v_audrey_sound_play_by_name->respond(
        "Playing $Save{current_audrey} Audrey sound $state");
    $state = 0  if $state eq 'cancel';
    $state = 1  if $state eq 'check';
    $state = 2  if $state eq 'copy';
    $state = 3  if $state eq 'cut';
    $state = 4  if $state eq 'delete';
    $state = 5  if $state eq 'help';
    $state = 6  if $state eq 'major_high';
    $state = 7  if $state eq 'menu_close';
    $state = 8  if $state eq 'menu_open';
    $state = 9  if $state eq 'minor_high';
    $state = 10 if $state eq 'minor_low';
    $state = 11 if $state eq 'paste';
    $state = 12 if $state eq 'print';
    $state = 13 if $state eq 'scroll_down';
    $state = 14 if $state eq 'scroll_up';
    $state = 15 if $state eq 'snapshot';
    $state = 16 if $state eq 'warning';
    $state = 17 if $state eq 'go_to_sleep';
    $state = 18 if $state eq 'wake_up';
    get "http://$Save{current_audrey}/beep.shtml?0 $state";
}

if ( said $v_audrey_sound_play) {
    my $state = $v_audrey_sound_play->{state};
    $v_audrey_sound_play->respond(
        "Playing $Save{current_audrey} Audrey sound $state");
    get "http://$Save{current_audrey}/beep.shtml?0 $state";
}

if ( said $v_audrey_volume) {
    my $state = $v_audrey_volume->{state};
    $v_audrey_volume->respond(
        "Setting $Save{current_audrey} Audrey volume to $state");
    get "http://$Save{current_audrey}/volume.shtml?$state";
}

if ( said $v_audrey_remote) {
    my $state = $v_audrey_remote->{state};
    $v_audrey_remote->respond(
        "Pushing $Save{current_audrey} Audrey button $state");
    $state = '@BRW'  if $state eq 'browser';
    $state = '@ADR'  if $state eq 'address_book';
    $state = '@DAT'  if $state eq 'date_book';
    $state = '@OPT'  if $state eq 'audrey_options';
    $state = '@PWR'  if $state eq 'power_button';
    $state = '@KLF'  if $state eq 'turn_knob_left';
    $state = '@KPS'  if $state eq 'push_knob';
    $state = '@KRT'  if $state eq 'turn_knob_right';
    $state = '@MAIL' if $state eq 'mail';
    $state = '@TAB'  if $state eq 'tab';
    $state = '@ENT'  if $state eq 'enter';
    get "http://$Save{current_audrey}/fireKey.shtml?string=$state";
}

