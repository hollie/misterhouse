
# Category = Robot

#@ This code creates commands for controling the $80 RoboSapien Robot:
#@ <a href=http://www.robosapienonline.com>robosapienonline.com</a>.
#@ Currently setup to send IR signals via xAP (e.g. mh -> xAP -> xAP RedRat connector -> USB RedRat3 -> RoboSapien)
#@ RedRat3 IR codes for the RoboSapien are available at <a href=http://www.redrat.co.uk/IR_Data.aspx>redrat.co.uk</a>.
#@ Pictures and a movie of a hack to give it an external sound and power source
#@ can be found at <a href=http://misterhouse.net/public/robot/>misterhouse.net/public/robot/</a>.
#@ You can control the voice and sound card with a parm like this: speak_apps = robot => voice=Charles card=1/2 .

$robot = new IR_Item 'Robosapien', undef, 'xAP';

# Define commands by category and how long each one takes to run
my %robot_cmds1 = (
    right => {
        RightArmDown     => 1.0,
        RightArmIn       => 1.0,
        RightArmOut      => 1.0,
        RightArmUp       => 1.0,
        RightHandPickUp  => 3.5,
        RightHandSweep   => 3.0,
        RightHandThrow   => 3.5,
        RightHandThump   => 2.5,
        RightHandStrike1 => 3.5,
        RightHandStrike2 => 5.0,
        RightHandStrike3 => 3.5
    },
    left => {
        LeftArmDown     => 1.0,
        LeftArmIn       => 1.0,
        LeftArmOut      => 1.0,
        LeftArmUp       => 1.0,
        LeftHandPickUp  => 3.5,
        LeftHandSweep   => 3.0,
        LeftHandThrow   => 3.5,
        LeftHandThump   => 2.5,
        LeftHandStrike1 => 3.5,
        LeftHandStrike2 => 4.0,
        LeftHandStrike3 => 3.5
    },
    lean => {
        TiltBodyRight => 1.0,
        TiltBodyLeft  => 1.0,
        LeanBackward  => 1.0,
        LeanForward   => 1.0
    },
    walk => {
        WalkForward   => 0.0,
        WalkBackward  => 0.0,
        ForwardStep   => 2.0,
        BackwardStep  => 2.0,
        Bolldozer     => 6.0,
        TurnRight     => 0.0,
        TurnLeft      => 0.0,
        RightTurnStep => 3.5,
        LeftTurnStep  => 3.5
    },
    talk => {
        Burp     => 2.5,
        High5    => 5.0,
        Oops     => 4.0,
        Roar     => 3.5,
        TalkBack => 5.0,
        Whistle  => 4.5
    },
    demo    => { AllDemo => 132, DanceDemo => 43, Demo1 => 45, Demo2 => 43 },
    control => {
        Stop   => 0,
        Listen => 0.0,
        Reset  => 0.0,
        Sleep  => 0,
        WakeUp => 0
    },
    program => {
        RightProgram  => 0,
        RightExecute  => 0,
        LeftProgram   => 0,
        LeftExecture  => 0,
        SonicProgram  => 0,
        SonicExecute  => 0,
        MasterProgram => 0,
        MasterExecute => 0,
        PowerOff      => 0,
        ProgramPlay   => 0
    }
);

# Create other useful arrays
# noloop=start
my ( %robot_cmds2, %robot_cmds3, %robot_cmds4, %robot_cmds5 );
for my $cat ( sort keys %robot_cmds1 ) {
    $robot_cmds2{$cat} = join ',', sort keys %{ $robot_cmds1{$cat} };

    # Gather commands of various types
    for my $cmd ( keys %{ $robot_cmds1{$cat} } ) {
        $robot_cmds3{$cmd} = $robot_cmds1{$cat}{$cmd}
          if $robot_cmds1{$cat}{$cmd} > 0 and $robot_cmds1{$cat}{$cmd} <= 10;
        $robot_cmds4{$cmd} = $robot_cmds1{$cat}{$cmd}
          if $cat =~ /(lean|right|left)/ and $robot_cmds1{$cat}{$cmd} <= 3;
        $robot_cmds5{$cmd} = $robot_cmds1{$cat}{$cmd};
    }
}

# noloop=stop

# Create commands for all functions
$robot_right   = new Voice_Cmd "Robot right [$robot_cmds2{right}]";
$robot_left    = new Voice_Cmd "Robot left [$robot_cmds2{left}]";
$robot_lean    = new Voice_Cmd "Robot lean [$robot_cmds2{lean}]";
$robot_walk    = new Voice_Cmd "Robot walk [$robot_cmds2{walk}]";
$robot_talk    = new Voice_Cmd "Robot talk [$robot_cmds2{talk}]";
$robot_demo    = new Voice_Cmd "Robot demo [$robot_cmds2{demo}]";
$robot_control = new Voice_Cmd "Robot control [$robot_cmds2{control}]";
$robot_program = new Voice_Cmd "Robot program [$robot_cmds2{program}]";
$robot_right->tie_items($robot);
$robot_left->tie_items($robot);
$robot_lean->tie_items($robot);
$robot_walk->tie_items($robot);
$robot_talk->tie_items($robot);
$robot_demo->tie_items($robot);
$robot_control->tie_items($robot);
$robot_program->tie_items($robot);

# Create sequence commands
$robot_sequence1 = new Voice_Cmd
  'Robot sequence [pickup,tilt,strike,arms,step,talk,all,random,stop]';
$robot_timer1 = new Timer;

my @robot_sequence_cmds;
if ( $state = said $robot_sequence1) {
    if ( $state eq 'stop' ) {
        speak "app=robot Ok, robot sequence stopped";
        stop $robot_timer1;
    }
    else {
        speak "app=robot Starting robot $state sequence";
        if ( $state eq 'all' ) {
            @robot_sequence_cmds = sort keys %robot_cmds3;
        }
        elsif ( $state eq 'random' ) {
            @robot_sequence_cmds = keys %robot_cmds3;
            randomize_list @robot_sequence_cmds;
        }
        elsif ( $state eq 'pickup' ) {
            @robot_sequence_cmds =
              qw(RightHandPickUp LeftHandPickUp RightHandThrow LeftHandThrow Burp);
        }
        elsif ( $state eq 'tilt' ) {
            @robot_sequence_cmds =
              qw(TiltBodyRight LeanBackward TiltBodyLeft LeanForward Burp);
        }
        elsif ( $state eq 'strike' ) {
            @robot_sequence_cmds =
              qw(RightHandStrike1 LeftHandStrike1 RightHandStrike2
              LeftHandStrike2 RightHandStrike3 LeftHandStrike3
              RightHandSweep  LeftHandSweep Burp);
        }
        elsif ( $state eq 'arms' ) {
            @robot_sequence_cmds =
              qw(RightArmDown LeftArmDown RightArmIn LeftArmIn
              RightArmOut LeftArmOut RightArmUp LeftArmUp Burp);
        }
        elsif ( $state eq 'step' ) {
            @robot_sequence_cmds =
              qw (ForwardStep BackwardStep RightTurnStep LeftTurnStep Burp );
        }
        elsif ( $state eq 'talk' ) {
            @robot_sequence_cmds = qw (High5 Oops Roar TalkBack Whistle Burp);
        }

        set $robot_timer1 .1;
    }
}
if ( expired $robot_timer1) {
    if ( my $cmd = shift @robot_sequence_cmds ) {

        #       speak app => 'robot', no_animate => 1, text => $cmd;
        set $robot $cmd;
        set $robot_timer1 $robot_cmds5{$cmd};
        print_log "Sending $robot_cmds5{$cmd} second robot cmd: $cmd.";
    }
    else {
        #       speak "app=robot Robot sequence done";
    }
}

$robot_keepawake =
  new Voice_Cmd 'Set robot to [keepawake, letsleep, WakeUp, Sleep]';
$robot_timer2 = new Timer;

if ( $state = said $robot_keepawake) {
    if ( $state eq 'keepawake' ) {

        #       set $robot_timer2 5*60, 'set $robot "LeftArmIn"', -1;
        set $robot_timer2 5 * 60, 'set $robot "Stop"', -1;
        print_log 'Robot will be tickled every 5 minutes to keep him awake';
    }
    elsif ( $state eq 'letsleep' ) {
        stop $robot_timer2;
    }
    else {
        set $robot $state;
    }
}

# React to local and remote (xAP monitored) speech
$xap_monitor_robot = new xAP_Item;

if ( $state = state_now $xap_monitor_robot) {
    my $class = $$xap_monitor_robot{'xap-header'}{class};
    print "  - robot xap monitor: lc=$Loop_Count class=$class state=$state\n"
      if $Debug{robot} == 1;

    if ( $class eq 'xap-osd.display' ) {
        set $robot 'RightArmDown~1~RightArmUp';
    }
}

# Move random limbs while speaking

&Speak_pre_add_hook( \&robot_speak_chime ) if $Reload;

sub robot_speak_chime {
    my %parms = @_;
    return if $parms{nolog};
    return if $parms{no_animate};
    return
      if $config_parms{robot_robosapien_speak_card}
      and $config_parms{robot_robosapien_speak_card} ne $parms{card};
    print "db robot speak hook: t=$Respond_Target parms=@_\n" if $Debug{robot};
    set $robot_timer3 .1;
    $Misc{robosapien}{speaking_flag} = 1;
}

$robot_timer3 = new Timer;
if ( expired $robot_timer3) {

    # Pick a random movement
    my @cmds = keys %robot_cmds4;    # Short commands that don't walk

    #   my @cmds = keys %{$robot_cmds1{lean}};

    #   randomize_list @cmds;
    #   my $cmd = $cmds[0];
    my $cmd = $cmds[ int rand(@cmds) ];

    set $robot $cmd;
    print $Misc{robosapien}{speaking_flag};
    set $robot_timer3 $robot_cmds4{$cmd} if $Misc{robosapien}{speaking_flag};
    print_log "Sending $robot_cmds4{$cmd} second robot cmd: $cmd"
      if $Debug{robot};
}

if ( $New_Msecond_250 and $Misc{robosapien}{speaking_flag} ) {
    print '.';
    if ( !&Voice_Text::is_speaking( $config_parms{robot_robosapien_speak_card} )
        or $Misc{robosapien}{speaking_flag}++ > 120 )
    {
        print "*\n";
        $Misc{robosapien}{speaking_flag} = 0;
        stop $robot_timer3;
    }
}

$robot_song  = new Process_Item;
$robot_dance = new Voice_Cmd '[start,stop] robot dance';
if ( $state = state_now $robot_dance) {
    if ( $state eq 'stop' ) {
        stop $robot_song;
        stop $robot_timer1;
        stop $robot_speak_timer;
        set $robot 'Stop';
    }
    else {
        speak 'app=robot no_animate=1 Time to dance!';
        set $robot_song "mplay32.exe  /play /close m:/sounds/ymca.mid";
        start $robot_song;
        @robot_sequence_cmds =
          qw(DanceDemo BackwardStep Burp BackwardStep High5 Demo2 BackwardStep);
        set $robot_timer1 2;
        set $robot_speak_timer 4;
    }
}

# Speak random fun words while danceing
$robot_words =
  new File_Item "$config_parms{data_dir}/remarks/list_fun_words.txt";
$robot_speak_timer = new Timer;
if ( expired $robot_speak_timer) {
    speak
      app        => 'robot',
      no_animate => 1,
      no_chime   => 1,
      text       => read_random $robot_words;
    if (@robot_sequence_cmds) {
        set $robot_speak_timer 4;
    }
    else {
        stop $robot_song unless @robot_sequence_cmds;
        speak "app=robot I am tired of dancing.";
    }
}
