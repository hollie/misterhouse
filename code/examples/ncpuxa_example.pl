# Category=ncpuxa

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
);

$TV = new IR_Item 'TV', '', 'ncpuxa', \%tvmap;

$v_tv_control = new Voice_Cmd(
    "tv [power,on,off,mute,vol+,vol-,ch+,ch-,video1,video2,video3,last,13]");

if ( $state = said $v_tv_control) {
    print_log "Setting TV to $state";
    set $TV $state;
}

my %ampmap = qw(
  ON	IRSlot130
  OFF	IRSlot31
  VOL+ 	IRSlot132
  VOL-	IRSlot133
  DVD	IRSlot134
  CD	IRSlot135
  TUNER	IRSlot136
  MUTE	IRSlot137
);

$AMP = new IR_Item 'AMP', '', 'ncpuxa', \%ampmap;

$v_amp_control = new Voice_Cmd("amp [on,off,mute,vol+,vol-,dvd,cd,tuner]");

if ( $state = said $v_amp_control) {
    print_log "Setting AMP to $state";
    set $AMP $state;
}

my %dvdmap = qw(
  POWER	IRSlot160
  CHAP+ 	IRSlot162
  CHAP-	IRSlot163
  PLAY	IRSlot30
  PAUSE	IRSlot165
);

$DVD = new IR_Item 'DVD', '', 'ncpuxa', \%dvdmap;

$v_dvd_control = new Voice_Cmd("dvd [power,play,pause,chap+,chap-]");

if ( $state = said $v_dvd_control) {
    print_log "Setting DVD to $state";
    set $DVD $state;
}

my %vcrmap = qw(
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
);

$VCR = new IR_Item 'VCR', '', 'ncpuxa', \%vcrmap;

$v_vcr_control =
  new Voice_Cmd("vcr [power,on,off,ch+,ch-,record,play,pause,stop,ff,rew]");

if ( $state = said $v_vcr_control) {
    print_log "Setting VCR to $state";
    set $VCR $state;
}

my %cdmap = qw(
  ON	IRSlot220
  OFF	IRSlot221
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
);

$CD = new IR_Item 'CD', '', 'ncpuxa', \%cdmap;

$v_cd_control =
  new Voice_Cmd("cd [power,on,off,play,stop,track+,track-,disc+,disc-,pause]");

if ( $state = said $v_cd_control) {
    print_log "Setting CD to $state";
    set $CD $state;
}

# Control X10

my $light_states = 'on,brighten,dim,off';
my $state;

$v_test_lights = new Voice_Cmd("All lights [$light_states]");
set $All_Lights $state if $state = said $v_test_lights;

# Setup movie mode if the DVD Play button is pushed
$dvdplay_button = new Serial_Item('IRSlot30');
if ( state_now $dvdplay_button) {
    my $remark = "You just pushed the DVD Play button";
    print_log "$remark";
    speak $remark;
    set $TV 'off,power,video1';
    set $AMP 'on,dvd';
    set $family_room '+95';
    set $family_room '-50';
}

# Power off everything if AMP Off button is pushed
$ampon_button = new Serial_Item('IRSlot31');
if ( state_now $ampon_button) {
    set $TV 'off';
    set $DVD 'power';
}

# Respond if the A2 button is pushed
$test_button = new Serial_Item('XA2');
if ( state_now $test_button) {
    my $remark = "You just pushed the A2 button";
    print_log "$remark";
    speak $remark;
}

if ( time_now("$Time_Sunset") ) {
    speak("It is after sunset, turning on porch light");
    set $porch 'on';
}

if ( time_now("$Time_Sunset + 1:00") ) {
    set $porch '-50';
}

if ( time_now("$Time_Sunrise") ) {
    set $porch 'off';
}

