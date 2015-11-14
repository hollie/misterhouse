# Category=Voice

#@ Use this to control the ViaVoice VR engine (currently Linux only)

# Don't do anything if we are using non-viavoice vr engine
return unless $config_parms{voice_cmd} eq 'viavoice';

# A do nothing test voice command
$v_viavoice_hello = new Voice_Cmd("[hi there,how are you]");
$v_viavoice_hello->set_info('A dummy little test command');

# Create the viavoice control phrases
$v_viavoice_awake = new Voice_Cmd(
    $config_parms{viavoice_awake_phrase},
    $config_parms{viavoice_awake_response},
    0, 'mh_activate'
);
$v_viavoice_asleep = new Voice_Cmd(
    $config_parms{viavoice_asleep_phrase},
    $config_parms{viavoice_asleep_response}
);
$v_viavoice_off = new Voice_Cmd( $config_parms{viavoice_off_phrase},
    'you want the microphone off', 1 );

# Monitor the Tk button
my ( $tk_vr_mode, $tk_vr_mode_prev );
$tk_vr_mode = $tk_vr_mode_prev = $Save{vr_mode} if $Reload;
&tk_radiobutton(
    'VR Mode', \$tk_vr_mode,
    [ 'awake', 'asleep', 'off' ],
    [ 'Awake', 'Asleep', 'Off' ]
);

#print "db $vr_mode_prev\n";
if ( $tk_vr_mode_prev ne $tk_vr_mode ) {
    $tk_vr_mode_prev = $tk_vr_mode;
    if ( $tk_vr_mode eq 'awake' ) {
        set $v_viavoice_awake 1;
    }
    elsif ( $tk_vr_mode eq 'asleep' ) {
        set $v_viavoice_asleep 1;
    }
    else {
        set $v_viavoice_off 1;
    }
}

# Set mode on startup and reload
if ($Reload) {
    if ( $Save{vr_mode} eq 'awake' ) {
        set $v_viavoice_awake 1;
    }
    elsif ( $Save{vr_mode} eq 'asleep' ) {
        set $v_viavoice_asleep 1;
    }
    elsif ( $Save{vr_mode} eq 'off' ) {
        set $v_viavoice_off 1;
    }
    print_log "Viavoice set to $Save{vr_mode}";
}

# This is the code that flips between voice modes
$viavoice_awake_timer = new Timer;
if ( said $v_viavoice_awake) {
    if ( $Save{vr_mode} eq 'awake' and !$Reload ) {
        speak "I am already awake";
    }
    else {
        print_log "VR mode set to awake";
        &Voice_Cmd::disablevocab('mh_activate');
        &Voice_Cmd::enablevocab('mh');
        &Voice_Cmd::disablevocab('mh_words');
        &Voice_Cmd::mic('on');
        $Save{vr_mode} = 'awake';
        set $viavoice_awake_timer $config_parms{viavoice_awake_time}
          if $config_parms{viavoice_awake_time};
    }
    $Save{vr_mode} = 'awake';
    $tk_vr_mode = $tk_vr_mode_prev = $Save{vr_mode};
}
if ( said $v_viavoice_asleep) {
    print_log "VR mode set to asleep";
    &Voice_Cmd::disablevocab('mh');
    &Voice_Cmd::enablevocab('mh_activate');
    &Voice_Cmd::disablevocab('mh_words');
    &Voice_Cmd::mic('on');
    $Save{vr_mode} = 'asleep';
    $tk_vr_mode = $tk_vr_mode_prev = $Save{vr_mode};
}

if ( said $v_viavoice_off) {
    print_log "VR mode set to off";
    &Voice_Cmd::mic('off');
    $Save{vr_mode} = 'off';
    $tk_vr_mode = $tk_vr_mode_prev = $Save{vr_mode};
}

# Reset the timer so we stay in awake mode if VR is active
if (    $Save{vr_mode} eq 'awake'
    and &Voice_Cmd::said_this_pass
    and $config_parms{viavoice_awake_time} )
{
    set $viavoice_awake_timer $config_parms{viavoice_awake_time};
}

# Go to asleep mode if no command have ben heard recently
if ( expired $viavoice_awake_timer and $Save{vr_mode} eq 'awake' ) {
    print_log "viavoice active mode timed out";
    set $v_viavoice_asleep 1;
    speak $config_parms{viavoice_timeout_response};
}

# Create a command search menu with all the Voice_Cmd words
# noloop=start
my $voice_word_list = join( ',', &Voice_Cmd::word_list )
  if $config_parms{voice_cmd} eq 'viavoice';
$voice_word_list = 'no words listed' unless $voice_word_list;
$v_command_search = new Voice_Cmd( 'find a command', 'what words?' );
print "db viavoice word list: $voice_word_list\n";
$v_command_words =
  new Voice_Cmd( "[$voice_word_list,do it]", '', 0, 'mh_words' );
set_icon $v_command_words 'none';

# noloop=stop

#$v_viavoice_alphabet = new Voice_Cmd('[a,b,done]', '', 0, 'mh_spell');
#$v_viavoice_alphabet = new Voice_Cmd('[a,b,c,d,e,f,g,h,i,j,k,l,m,n,o,p,q,u,r,s,t,u,v,w,x,y,z,0,1,2,3,4,5,6,7,8,9,done]', '', 0, 'mh_spell');

my $viavoice_cmd;
if ( said $v_command_search) {
    print_log "VR mode set to spell it mode";
    &Voice_Cmd::disablevocab('mh');
    &Voice_Cmd::enablevocab('mh_words');
    undef $viavoice_cmd;
    $Save{vr_mode} = 'list';
}

if ( $state = said $v_command_words) {
    print "db vvs=$state.\n";
    if ( $state eq 'do it' ) {
        my @list  = &list_voice_cmds_match($viavoice_cmd);
        my $count = @list;
        speak "Found $count matching commands for $viavoice_cmd";
        my ( $text, $i );
        if ( $count < 4 ) {
            for (@list) {
                $i++;
                $text .= "$i, $_. ";
            }
        }
        speak $text;
        display
          join( "\n - ", "$count matching commands for $viavoice_cmd", @list );
        &Voice_Cmd::disablevocab('mh_words');
        &Voice_Cmd::enablevocab('mh');
        $Save{vr_mode} = 'awake';
    }
    else {
        speak "heard $state";
        $viavoice_cmd .= ' ' . $state;
    }
}
