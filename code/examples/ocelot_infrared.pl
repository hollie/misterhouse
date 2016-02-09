
=begin comment 

By David Norwood, dnorwood2@yahoo.com	

This is how I use the infrared capabilities of the Ocelot. 

=cut

if ($Reload) {
    $Included_HTML{CD} = '<!--#include file="/david/cds.shtml"-->';
    $Included_HTML{TV} = '<!--#include file="/tv/index.html"-->';
}

# Category=TV

# Sending IR with the CPU-XA or Ocelot

my %tvmap = qw(
  POWER	IRSlot100
  ON	IRSlot101
  OFF 	IRSlot102
  CH+	IRSlot103
  CH- 	IRSlot104
  VOL+ 	IRSlot105
  VOL-	IRSlot106
  VIDEO1	IRSlot107
  VIDEO2	IRSlot108
  VIDEO3	IRSlot109
  0	IRSlot110
  1	IRSlot111
  2	IRSlot112
  3	IRSlot113
  4	IRSlot114
  5	IRSlot115
  6	IRSlot116
  7	IRSlot117
  8	IRSlot118
  9	IRSlot119
  LAST	IRSlot120
  MUTE	IRSlot121
  DISPLAY	IRSlot122
  ENTER	IRSlot123
);

$TV = new IR_Item 'TV', 'addEnter', 'ncpuxa', \%tvmap;

my $tv_controls       = 'power,vol+,vol-,ch+,ch-,display,last';
my $tv_local_channels = '2,4,5,7,9,11,13,14';
my %tv_cable_channels = (
    'TLC', 69, 'Discovery', 67, 'Comedy', 62, 'VH1', 38,
    'CNN', 46, 'Animal',    68, 'Food',   55,
);

my $tv_states =
    $tv_controls . ','
  . $tv_local_channels . ','
  . join(
    ',',
    (
        sort { $tv_cable_channels{$a} <=> $tv_cable_channels{$b} }
          keys %tv_cable_channels
    )
  );

set_states $TV split ',', $tv_states;
$v_tv_control = new Voice_Cmd("tv [$tv_states]");

&tk_entry( 'TV key', \$Save{ir_key} );

&tk_entry( 'My TV search', \$Save{tv_search} );
if ( $state = $Tk_results{'My TV search'} ) {
    run qq[get_tv_info -times all -early_am 0-5:30 -dates +7 -keys "$state"];

    #       set_watch $f_tv_file;
    undef $Tk_results{'My TV search'};
}

if ( ( $state = said $v_tv_control) || ( $state = $Tk_results{'TV key'} ) ) {
    print_log "Setting TV to $state";
    $state = $tv_cable_channels{$state} if $tv_cable_channels{$state};
    if ( $state eq "vol-" ) {
        set $TV "vol-";
        set $TV "vol-";
        set $TV "vol-";
        set $TV "vol-";
    }
    if ( $state eq "vol+" ) {
        set $TV "vol+";
        set $TV "vol+";
        set $TV "vol+";
    }
    if ( $state eq "service" ) {
        set $TV "display,5,vol+,on";
    }
    if ( $state eq "save" ) {
        set $TV "mute,enter";
    }
    if ( $state > 76 ) {
        set $TV "video3";
        set $VCR $state;
    }
    else {
        set $TV $state;
    }
    undef $Tk_results{'TV key'};
}

# Category=DVD

my %ampmap = qw(
  ON	IRSlot130
  OFF	IRSlot31
  VOL+ 	IRSlot132
  VOL-	IRSlot133
  DVD	IRSlot134
  CD	IRSlot135
  TUNER	IRSlot136
  MUTE	IRSlot137
  TAPE	IRSlot138
  CH+	IRSlot139
  CH-	IRSlot140
  TV	IRSlot141
  VCR	IRSlot142
);

$AMP = new IR_Item 'AMP', '', 'ncpuxa', \%ampmap;

$v_amp_control =
  new Voice_Cmd("amp [on,off,mute,vol+,vol-,dvd,cd,tv,vcr,tape]");

if ( $state = said $v_amp_control) {
    print_log "Setting AMP to $state";
    set $AMP $state;
    if ( $state eq "on" ) {
        set $TV "on";
        set $AMP "dvd";
        set $TV "video1";
    }
    if ( $state eq "off" ) {
        set $TV "off";
    }
}

$v_tvdvd_control = new Voice_Cmd("tv control [power,video1]");

if ( $state = said $v_tvdvd_control) {
    print_log "Setting TV to $state";
    set $TV $state;
}

my %dvdmap = qw(
  POWER	IRSlot161
  CHAP+ 	IRSlot162
  CHAP-	IRSlot163
  PLAY	IRSlot30
  SELECT	IRSlot30
  PAUSE	IRSlot165
  STOP	IRSlot166
  MENU	IRSlot167
  UP	IRSlot168
  DOWN	IRSlot169
  LEFT	IRSlot170
  RIGHT	IRSlot171
  REW	IRSlot172
  FF	IRSlot173
);

$DVD = new IR_Item 'DVD', '', 'ncpuxa', \%dvdmap;

$v_dvd_control = new Voice_Cmd(
    "dvd [power,play,pause,stop,chap+,chap-,menu,up,down,left,right,select,rew,ff]"
);

if ( $state = said $v_dvd_control) {
    print_log "Setting DVD to $state";
    set $DVD $state;
}

# Category=VCR

my %vcrmap = qw(
  POWER	IRSlot190
  ON	IRSlot190
  OFF	IRSlot191
  CH+ 	IRSlot192
  CH-	IRSlot193
  PLAY	IRSlot194
  PAUSE	IRSlot195
  RECORD	IRSlot196
  STOP	IRSlot197
  REW	IRSlot198
  FF	IRSlot199
  0	IRSlot200
  1	IRSlot201
  2	IRSlot202
  3	IRSlot203
  4	IRSlot204
  5	IRSlot205
  6	IRSlot206
  7	IRSlot207
  8	IRSlot208
  9	IRSlot209
  CABLE	IRSlot210
  V0	IRSlot211
  V4	IRSlot212
);

$VCR = new IR_Item 'VCR', '', 'ncpuxa', \%vcrmap;

$v_vcr_control = new Voice_Cmd(
    "vcr [power,cable,v4,video2,video3,mute,vol+,vol-,ch+,ch-,record,play,pause,stop,ff,rew]"
);

if ( $state = said $v_vcr_control) {
    print_log "Setting VCR to $state";
    set $TV "video3" if $state eq "play";
    set $VCR "v0"    if $state eq "v4";
    if (   $state eq "video2"
        || $state eq "video3"
        || $state eq "mute"
        || $state eq "vol+"
        || $state eq "vol-" )
    {
        set $TV $state;
    }
    else {
        set $VCR $state;
    }
}

# Category=CD

my %cdmap = qw(
  ON	IRSlot220
  OFF	IRSlot220
  TRACK+ 	IRSlot222
  TRACK-	IRSlot223
  PLAY	IRSlot224
  PAUSE	IRSlot225
  ENTER	IRSlot226
  DISC+ 	IRSlot227
  DISC-	IRSlot228
  STOP	IRSlot229
  0	IRSlot230
  1	IRSlot231
  2	IRSlot232
  3	IRSlot233
  4	IRSlot234
  5	IRSlot235
  6	IRSlot236
  7	IRSlot237
  8	IRSlot238
  9	IRSlot239
  DISC	IRSlot240
);

$CD = new IR_Item 'CD', '', 'ncpuxa', \%cdmap;

$v_cd_control = new Voice_Cmd(
    "cd control [on,off,play,stop,next track,previous track,next disc,previous disc,pause]"
);

if ( $state = said $v_cd_control) {
    $state = "disc+"  if $state eq 'next disc';
    $state = "disc-"  if $state eq 'previous disc';
    $state = "track+" if $state eq 'next track';
    $state = "track-" if $state eq 'previous track';
    print_log "Setting CD to $state";
    if ( $state eq 'on' ) {
        set $AMP "on,delay,cd";
    }
    elsif ( $state eq 'off' ) {
        set $AMP "off";
    }
    set $CD $state;
}

$v_cdvol_control = new Voice_Cmd("cd volume [down,up,mute]");

if ( $state = said $v_cdvol_control) {
    $state = "vol-" if $state eq 'down';
    $state = "vol+" if $state eq 'up';
    print_log "Setting AMP to $state";
    set $AMP $state;
}

$cdjuke = new Generic_Item();

if ( my $data = state_now $cdjuke) {
    set $CD "disc,$data,enter";
}

# Category=Lights

# Control X10

my $light_states = 'on,brighten,dim,off';
my $state;

$theater = new Serial_Item( "XA4A9AJA-50", 'on' );
$theater->add( "XA4A9A+13", 'brighten' );
$theater->add( "XA4A9A-13", 'dim' );
$theater->add( "XA4A9AK",   'off' );

$v_theater = new Voice_Cmd("Theater lighting[$light_states]");
set $theater $state if $state = said $v_theater;

# Setup movie mode if the DVD Play button is pushed
$dvdplay_button = new Serial_Item('IRSlot30');
$dvdplay_timer  = new Timer;
if ( state_now $dvdplay_button and inactive $dvdplay_timer) {
    my $remark = "You just pushed the DVD Play button";
    print_log "$remark";

    #    speak $remark;
    set $TV 'on';
    set $AMP 'on';
    set $TV 'video1';
    set $AMP 'dvd';
    set $family_room '+50' if $Dark;
    set $family_room '-50' if $Dark;
    set $dvdplay_timer 2 * 60 * 60;
}

# Power off everything if AMP Off button is pushed
$ampon_button = new Serial_Item('IRSlot31');
if ( state_now $ampon_button) {

    #    set $TV 'off';
    #    set $DVD 'power';
}

