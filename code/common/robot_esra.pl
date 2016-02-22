
# Category = Robot

#@ This code controls $180 Robodyssy ESRA robot head:
#@ <a href=http://www.robodyssey.com>robodyssey.com</a>.
#@ It has 5 servos (eye lid, eyes, lip top/bottom, and an optional neck) which are connected
#@ via the Mini SSC II serial servo controler: <a href=http://seetron.com>seetron.com</a>.
#@ Pictures and a movie of it in operation can be found
#@ at <a href=http://misterhouse.net/public/robot/>misterhouse.net/public/robot/</a>.
#@ Set the robot_esra_port parm to point to the serial port you are using.

use Servo_Item;
&Servo_Item::startup( 'esra', $config_parms{robot_esra_port} ) if $Startup;

$robot_lipt = new Servo_Item 'esra', 0;
$robot_lipb = new Servo_Item 'esra', 1;
$robot_eyes = new Servo_Item 'esra', 2;
$robot_lids = new Servo_Item 'esra', 3;
$robot_neck = new Servo_Item 'esra', 7;

my $robot_esra_states = '0,10,20,30,40,50,60,70,80,90,100';
my @robot_esra_states = split ',', $robot_esra_states;
my @robot_esra_servos =
  qw ($robot_lids $robot_eyes $robot_lipt $robot_lipb $robot_neck);

# Enable better web control by setting valid states
set_states $robot_lids @robot_esra_states;
set_states $robot_eyes @robot_esra_states;
set_states $robot_lipt @robot_esra_states;
set_states $robot_lipb @robot_esra_states;
set_states $robot_neck @robot_esra_states;

$robot_lids_v = new Voice_Cmd "Robot eyelid [$robot_esra_states]";
$robot_eyes_v = new Voice_Cmd "Robot eyes [$robot_esra_states]";
$robot_lipt_v = new Voice_Cmd "Robot lip top [$robot_esra_states]";
$robot_lipb_v = new Voice_Cmd "Robot lip bottom [$robot_esra_states]";
$robot_neck_v = new Voice_Cmd "Robot neck [$robot_esra_states]";

tie_items $robot_lids_v $robot_lids;
tie_items $robot_eyes_v $robot_eyes;
tie_items $robot_lipt_v $robot_lipt;
tie_items $robot_lipb_v $robot_lipb;
tie_items $robot_neck_v $robot_neck;

# Create Tk sliders
if ( $Reload and $MW ) {
    $Tk_objects{esra}{frame}->destroy if $Tk_objects{esra}{frame};
    $Tk_objects{esra}{frame} =
      $MW->Frame->pack(qw/-side bottom -fill both -expand 1/);
    $Tk_objects{esra}{lids} = &tk_scalebar_esra( $robot_lids, 0, 'Lids' );
    $Tk_objects{esra}{eyes} = &tk_scalebar_esra( $robot_eyes, 1, 'Eyes' );
    $Tk_objects{esra}{lipt} = &tk_scalebar_esra( $robot_lipt, 2, 'Lip - Top' );
    $Tk_objects{esra}{lipb} =
      &tk_scalebar_esra( $robot_lipb, 3, 'Lip - Bottom' );
    $Tk_objects{esra}{neck} = &tk_scalebar_esra( $robot_neck, 4, 'Neck' );
}

sub tk_scalebar_esra {
    my ( $object, $col, $label ) = @_;
    my $tk = $Tk_objects{esra}{frame}->Scale(
        -from         => 0,
        -to           => 100,
        -label        => $label,
        -width        => '10',
        -length       => '100',
        -showvalue    => '1',
        -tickinterval => '50',
        -orient       => 'horizontal',
        -variable     => \$$object{state},
        -command      => [ \&Servo_Item::set, $object ]
    );
    $tk->grid( -row => 0, -column => $col );
    return $tk;
}

$robot_seq1 = new Voice_Cmd "Robot test [start,stop]";

$robot_esra_timer1 = new Timer;
if ( $state = state_now $robot_seq1) {
    if ( $state eq 'start' ) {
        set $robot_esra_timer1 .01;
    }
    else {
        unset $robot_esra_timer1;
    }
}
if ( expired $robot_esra_timer1) {
    set $robot_esra_timer1 .05;

    #   for my $object (&list_objects_by_type2('Servo_Item')) {
    for my $servo (@robot_esra_servos) {
        my $object = &get_object_by_name($servo);
        set_inc $object 2;
    }
}

# Move face parts while speaking

$robot_esra_timer2 = new Timer;

&Speak_pre_add_hook( \&robot_esra_speak_hook ) if $Reload;

sub robot_esra_speak_hook {
    my %parms = @_;
    return if $parms{nolog};
    return if $parms{no_animate};
    return
      if $config_parms{robot_esra_speak_card}
      and $config_parms{robot_esra_speak_card} ne $parms{card};
    print "Robot esra speak hook: t=$Respond_Target parms=@_\n"
      if $Debug{robot};
    set $robot_esra_timer2 .01;
    $Misc{esra}{speaking_flag} = 1;
}

if ( expired $robot_esra_timer2) {
    if ( $Misc{esra}{speaking_flag} ) {
        for my $servo (@robot_esra_servos) {
            my $object = &get_object_by_name($servo);

            # If lids, blink instead
            if ( $servo eq '$robot_lids' ) {
                set_with_timer $robot_lids 0, .2, 45 if rand(1) < .1;
            }
            else {
                my $inc = int rand(20);
                my $dir = ( rand(1) < .5 ) ? -1 : 1;

                # Don't move the neck as often, or as far.
                if ( $servo eq '$robot_neck' ) {
                    next if rand(1) > .1;
                    set_inc $object $inc, $dir, 20, 80;
                }
                else {
                    set_inc $object $inc, $dir;
                }
            }
        }
        set $robot_esra_timer2 .10;
    }
    else {
        stop $robot_esra_timer2;
        set $robot_lipt 50;
        set $robot_lipb 50;
        set $robot_neck 50;
    }
}

if ( $New_Msecond_250 and $Misc{esra}{speaking_flag} ) {
    print '.';
    if (  !&Voice_Text::is_speaking( $config_parms{robot_esra_speak_card} )
        or $Misc{esra}{speaking_flag}++ > 120 )
    {
        print "*\n";
        $Misc{esra}{speaking_flag} = 0;
    }
}
