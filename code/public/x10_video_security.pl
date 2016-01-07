# Category=Surveillance

#
# Voice Controller Video Security System
#
# Mark A. Holm - February 2001
#
# Assumptions
# 1. We don't care about motion stopped states (Motion detector timed out) when
#	recording, since the VCR commander times out after 5 minutes and the
#	cameras will drop back to scan mode.
# 2. Cameras are all Xcam2 and X10 controlled.
# 3. Front Porch lights always on, back porch light motion controlled due to
#    amount of light it casts into our bedroom.
# 4. You must have both a CM11 and a CM17 to control both Cameras and VCR Commander.
# 5. Socket Rockets don't have timers!
#
# Futures
# 1. Web Controls?
# 2. Table based location definitions?
#
# By Adding a Belkin USB VideoBus II cable to the system and a Second Video
# receiver, you can use Webcam32 from Surveyor Corp to put the current images
# from the system onto a web page.

#
# Global Variables
#my $state;
#my $v_state;

#
# Define all Active Devices
#

#
# Define all received signals via serial
$Camera_Motion = new Serial_Item( 'XA5AJ', 'Back Porch On' );
$Camera_Motion->add( 'XA5AK', 'Back Porch Off' );
$Camera_Motion->add( 'XA6AJ', 'Front Porch On' );
$Camera_Motion->add( 'XA6AK', 'Front Porch Off' );
$Camera_Motion->add( 'XA7AJ', 'Side Drive On' );
$Camera_Motion->add( 'XA7AK', 'Side Drive Off' );
$Camera_Motion->add( 'XA8AJ', 'Side Yard On' );
$Camera_Motion->add( 'XA8AK', 'Side Yard Off' );
$Pad_Back_Porch_Light = new Serial_Item( 'XA9AJ', 'Back Porch Light On' );
$Pad_Back_Porch_Light->add( 'XA9AK', 'Back Porch Light Off' );

#
# Lights and appliances
$Back_Porch_Light      = new X10_Item( 'A9', 'CM17' );
$Back_Porch_Light_Post = new X10_Item( 'A9', 'CM11' );
$VCR_Commander         = new X10_Item( 'D1', 'CM17' );

#
# Cameras
$Camera_Back_Porch  = new X10_Item( 'C5', 'CM11' );
$Camera_Front_Porch = new X10_Item( 'C6', 'CM11' );
$Camera_Side_Drive  = new X10_Item( 'C7', 'CM11' );
$Camera_Side_Yard   = new X10_Item( 'C8', 'CM11' );

#
# State Capture variables for Lights and Appliances
$Which_Camera_On = new Generic_Item;
$Camera_Status   = new Generic_Item;

#
# Define state change timers so we don't get multiple announcements
$Back_Porch_Light_Timer_On     = new Timer;
$Back_Porch_Light_Timer_Off    = new Timer;
$Back_Porch_Light_Time_Timer   = new Timer;
$Camera_Back_Porch_Timer       = new Timer;
$Camera_Front_Porch_Timer      = new Timer;
$Camera_Side_Drive_Timer       = new Timer;
$Camera_Side_Yard_Timer        = new Timer;
$Camera_Back_Porch_Cont_Timer  = new Timer;
$Camera_Front_Porch_Cont_Timer = new Timer;
$Camera_Side_Drive_Cont_Timer  = new Timer;
$Camera_Side_Yard_Cont_Timer   = new Timer;
$Camera_Scan_Timer             = new Timer;
$VCR_Commander_Timer           = new Timer;

#
# Define Voice Commands
$v_Back_Porch_Light = new Voice_Cmd "Turn Back Porch Lights [on,off]";
$v_Back_Porch_Light_Timer =
  new Voice_Cmd "Turn Back Porch Lights off in [1,5,10,30,60] minutes";
$v_Surv_Item_Query = new Voice_Cmd "How long is [Back Porch Light,Camera] on?";
$v_Which_Camera    = new Voice_Cmd "Which camera is on";
$v_Show_Camera =
  new Voice_Cmd "Show [Back Porch,Front Porch,Side Drive,Side Yard]";
$v_Record_Camera =
  new Voice_Cmd "Record [Back Porch,Front Porch,Side Drive,Side Yard]";
$v_Camera_Status = new Voice_Cmd "What is the status of the Cameras";
$v_Scan_Camera   = new Voice_Cmd "Scan Cameras";

#
# Check each motion detector for change of state
if (   ( my $state = state_now $Camera_Motion)
    or ( my $v_state = said $v_Record_Camera) )
{
    my $Switch = substr $state, -2;
    if ( $Switch eq 'On' or said $v_Record_Camera) {
        my $remark = "";
        set $Camera_Back_Porch 'off'
          if ( 'on' eq state $Camera_Back_Porch
            and ( 'Back Porch' ne $v_state and 'Back Porch On' ne $state ) );
        set $Camera_Front_Porch 'off'
          if ( 'on' eq state $Camera_Front_Porch
            and ( 'Front Porch' ne $v_state and 'Front Porch On' ne $state ) );
        set $Camera_Side_Drive 'off'
          if ( 'on' eq state $Camera_Side_Drive
            and ( 'Side Drive' ne $v_state and 'Side Drive On' ne $state ) );
        set $Camera_Side_Yard 'off'
          if ( 'on' eq state $Camera_Side_Yard
            and ( 'Side Yard' ne $v_state and 'Side Yard On' ne $state ) );
        set $VCR_Commander 'on';
        if ( ( 'Back Porch On' eq $state ) or ( 'Back Porch' eq $v_state ) ) {
            set $Camera_Back_Porch 'on' if ( 'off' eq state $Camera_Back_Porch);
            if (
                (
                        time_greater_than "$Time_Sunset"
                    and time_less_than "11:59 PM"
                )
                or (    time_greater_than "12:00 AM"
                    and time_less_than "$Time_Sunrise" )
              )
            {
                set $Back_Porch_Light 'on';
                set $Back_Porch_Light_Post 'on';
                set $Back_Porch_Light_Time_Timer 600;
            }
            if ( not active $Camera_Back_Porch_Timer) {
                if ( 'Back Porch' eq $v_state ) {
                    $remark =
                      "Requested re cord of Back Porch. Turning on VCR and Camera.";
                }
                else {
                    $remark =
                      "Motion on Back Porch. Turning on VCR and Camera.";
                }
            }
            else {
                if ( not active $Camera_Back_Porch_Cont_Timer) {
                    $remark = "Motion continueing on Back Porch.";
                }
            }
            set $Camera_Back_Porch_Timer 600;
            set $Camera_Back_Porch_Cont_Timer 300
              if ( not active $Camera_Back_Porch_Cont_Timer);
            unset $Camera_Front_Porch_Timer;
            unset $Camera_Side_Drive_Timer;
            unset $Camera_Side_Yard_Timer;
            set $Which_Camera_On 'BP';
            set $Camera_Status "Currently recording Back Porch.";
        }
        elsif (( 'Front Porch On' eq $state )
            or ( 'Front Porch' eq $v_state ) )
        {
            set $Camera_Front_Porch 'on';
            if ( not active $Camera_Front_Porch_Timer) {
                if ( 'Front Porch' eq $v_state ) {
                    $remark =
                      "Requested re cord of Front Porch. Turning on VCR and Camera.";
                }
                else {
                    $remark =
                      "Motion on Front Porch. Turning on VCR and Camera.";
                }
            }
            else {
                if ( not active $Camera_Front_Porch_Cont_Timer) {
                    $remark = "Motion continueing on Front Porch.";
                }
            }
            set $Camera_Front_Porch_Timer 600;
            set $Camera_Front_Porch_Cont_Timer 300
              if ( not active $Camera_Front_Porch_Cont_Timer);
            unset $Camera_Back_Porch_Timer;
            unset $Camera_Side_Drive_Timer;
            unset $Camera_Side_Yard_Timer;
            set $Which_Camera_On 'FP';
            set $Camera_Status "Currently recording Front Porch.";
        }
        elsif ( ( 'Side Drive On' eq $state ) or ( 'Side Drive' eq $v_state ) )
        {
            set $Camera_Side_Drive 'on';
            if ( not active $Camera_Side_Drive_Timer) {
                if ( 'Side Drive' eq $v_state ) {
                    $remark =
                      "Requested re cord of Side Drive. Turning on VCR and Camera.";
                }
                else {
                    $remark =
                      "Motion in Side Drive. Turning on VCR and Camera.";
                }
            }
            else {
                if ( not active $Camera_Side_Drive_Cont_Timer) {
                    $remark = "Motion continueing in Side Drive.";
                }
            }
            set $Camera_Side_Drive_Timer 600;
            set $Camera_Side_Drive_Cont_Timer 300
              if ( not active $Camera_Side_Drive_Cont_Timer);
            unset $Camera_Back_Porch_Timer;
            unset $Camera_Front_Porch_Timer;
            unset $Camera_Side_Yard_Timer;
            set $Which_Camera_On 'SD';
            set $Camera_Status "Currently recording Side Drive.";
        }
        elsif ( ( 'Side Yard On' eq $state ) or ( 'Side Yard' eq $v_state ) ) {
            set $Camera_Side_Yard 'on';
            if ( not active $Camera_Side_Yard_Timer) {
                if ( 'Side Yard' eq $v_state ) {
                    $remark =
                      "Requested re cord of Side Yard. Turning on VCR and Camera.";
                }
                else {
                    $remark = "Motion in Side Yard. Turning on VCR and Camera.";
                }
            }
            else {
                if ( not active $Camera_Side_Yard_Cont_Timer) {
                    $remark = "Motion continueing in Side yard.";
                }
            }
            set $Camera_Side_Yard_Timer 600;
            set $Camera_Side_Yard_Cont_Timer 300
              if ( not active $Camera_Side_Yard_Cont_Timer);
            unset $Camera_Back_Porch_Timer;
            unset $Camera_Front_Porch_Timer;
            unset $Camera_Side_Drive_Timer;
            set $Which_Camera_On 'SY';
            set $Camera_Status "Currently recording Side Yard.";
        }
        #
        # Eliminate the unspeakable phrase
        if ( "" ne "$remark" ) {
            print_log "$remark";
            speak $remark;
        }
    }
}

#
# Set state of VCR_Commander to off when everything is idle
#  so State tables are correct at least sometimes
if (    not active $Camera_Back_Porch_Timer
    and not active $Camera_Front_Porch_Timer
    and not active $Camera_Side_Yard_Timer
    and not active $Camera_Side_Drive_Timer
    and expired $VCR_Commander_Timer)
{
    #
    # Only check it every 5 minutes
    set $VCR_Commander_Timer 600;
    set $VCR_Commander 'off';
}

#
# Show camera on request
if ( my $v_state = state_now $v_Show_Camera) {
    my $remark = "Invalid camera request";
    #
    # You must turn off cameras before turning on the next one
    #  'off' is apparently seen by all cameras!
    set $Camera_Back_Porch 'off'
      if ( 'on' eq state $Camera_Back_Porch and 'Back Porch' ne $v_state );
    set $Camera_Front_Porch 'off'
      if ( 'on' eq state $Camera_Front_Porch and 'Front Porch' ne $v_state );
    set $Camera_Side_Drive 'off'
      if ( 'on' eq state $Camera_Side_Drive and 'Side Drive' ne $v_state );
    set $Camera_Side_Yard 'off'
      if ( 'on' eq state $Camera_Side_Yard and 'Side Yard' ne $v_state );
    #
    # Set timers up
    set $Camera_Scan_Timer 600;
    unset $Camera_Front_Porch_Timer;
    unset $Camera_Side_Drive_Timer;
    unset $Camera_Side_Yard_Timer;
    unset $Camera_Back_Porch_Timer;
    #
    # Do requested Camera
    if ( 'Back Porch' eq $v_state ) {
        set $Camera_Back_Porch 'on';
        set $Which_Camera_On 'BP';
        $remark = "Viewing Back Porch. Scan re zooms in 10 minutes.";
        set $Camera_Status "Currently viewing Back Porch.";
    }
    elsif ( 'Front Porch' eq $v_state ) {
        set $Camera_Front_Porch 'on';
        set $Which_Camera_On 'FP';
        $remark = "Viewing Front Porch. Scan re zooms in 10 minutes.";
        set $Camera_Status "Currently viewing Front Porch.";
    }
    elsif ( 'Side Yard' eq $state ) {
        set $Camera_Side_Yard 'on';
        set $Which_Camera_On 'SY';
        $remark = "Viewing Side Yard. Scan re zooms in 10 minutes.";
        set $Camera_Status "Currently viewing Side Yard.";
    }
    elsif ( 'Side Drive' eq $state ) {
        set $Camera_Side_Drive 'on';
        set $Which_Camera_On 'SD';
        $remark = "Viewing Side Drive. Scan re zooms in 10 minutes.";
        set $Camera_Status "Currently viewing Side Drive.";
    }
    #
    # Tell them what you did
    print_log "$remark";
    speak $remark;
}

#
# Scan Camera's when Idle
if (
    (
            ( not active $Camera_Back_Porch_Timer)
        and ( not active $Camera_Front_Porch_Timer)
        and ( not active $Camera_Side_Drive_Timer)
        and ( not active $Camera_Side_Yard_Timer)
        and ( not active $Camera_Scan_Timer)
    )
    or ( said $v_Scan_Camera)
  )
{

    my $remark = "Scanning Cameras and have lost current state";
    #
    # Turn off all cameras first
    set $Camera_Back_Porch 'off'  if ( 'on' eq state $Camera_Back_Porch);
    set $Camera_Front_Porch 'off' if ( 'on' eq state $Camera_Front_Porch);
    set $Camera_Side_Drive 'off'  if ( 'on' eq state $Camera_Side_Drive);
    set $Camera_Side_Yard 'off'   if ( 'on' eq state $Camera_Side_Yard);
    #
    # Turn on next camera in the list
    if ( 'SD' eq state $Which_Camera_On) {
        set $Camera_Back_Porch 'on';
        set $Camera_Scan_Timer 120;
        set $Which_Camera_On 'BP';
        $remark = "Currently scanning cameras and Back Porch is visible.";
    }
    elsif ( 'SY' eq state $Which_Camera_On) {
        set $Camera_Front_Porch 'on';
        set $Camera_Scan_Timer 120;
        set $Which_Camera_On 'FP';
        $remark = "Currently scanning cameras and Front Porch is visible.";
    }
    elsif ( 'FP' eq state $Which_Camera_On) {
        set $Camera_Side_Drive 'on';
        set $Camera_Scan_Timer 120;
        set $Which_Camera_On 'SD';
        $remark = "Currently scanning cameras and Side Drive is visible.";
    }
    else {
        set $Camera_Side_Yard 'on';
        set $Camera_Scan_Timer 120;
        set $Which_Camera_On 'SY';
        $remark = "Currently scanning cameras and Side Yard is visible.";
    }
    #
    # Log what was just done
    set $Camera_Status $remark;
    print_log $remark;
}

#
# Camera Queries

#
# Which camera is showing?
if ( said $v_Which_Camera) {
    my $remark = "";
    $remark = "Back Porch"  if ( 'on' eq state $Camera_Back_Porch);
    $remark = "Front Porch" if ( 'on' eq state $Camera_Front_Porch);
    $remark = "Side Yard"   if ( 'on' eq state $Camera_Side_Yard);
    $remark = "Side Drive"  if ( 'on' eq state $Camera_Side_Drive);
    print $remark;
    if ( "" eq "$remark" ) {
        $remark = "There are no cameras on at this time.";
    }
    else {
        $remark = "The " . $remark . " Camera is on now.";
    }
    print_log $remark;
    speak $remark;
}

#
# Overall Status
if ( said $v_Camera_Status) {
    speak state $Camera_Status;
}

#
# Change Light States

#
# Back Porch
if (   ( my $state = state_now $Pad_Back_Porch_Light)
    or ( my $v_state = said $v_Back_Porch_Light) )
{
    my $remark = "Huh?";
    if (    ( ( $state eq 'Back Porch Light On' ) or ( $v_state eq 'on' ) )
        and ( not active $Back_Porch_Light_Timer_On) )
    {
        set $Back_Porch_Light 'on';
        set $Back_Porch_Light_Post 'on';
        set $Back_Porch_Light_Time_Timer 600;
        $remark = "Turned on Back Porch Light.";
        set $Back_Porch_Light_Timer_On 10;
    }
    if (    ( ( $state eq 'Back Porch Light Off' ) or ( $v_state eq 'off' ) )
        and ( not active $Back_Porch_Light_Timer_Off) )
    {
        set $Back_Porch_Light 'off';
        set $Back_Porch_Light_Post 'off';
        $remark = "Turned off Back Porch Light.";
        set $Back_Porch_Light_Timer_Off 10;
    }
    print_log "$remark";
    speak $remark;
}

#
# Query Light on time
if ( my $state = state_now $v_Surv_Item_Query) {
    my $seconds = 0;
    my $Item    = "";
    if ( 'Back Porch Light' eq $state ) {
        $Item    = 'Back Porch Light';
        $seconds = seconds_remaining $Back_Porch_Light_Time_Timer;
    }
    elsif ( 'Camera' eq $state ) {
        $seconds = seconds_remaining $Camera_Scan_Timer;
        if ( 'BP' eq state $Which_Camera_On) {
            $Item    = 'Back Porch Camera';
            $seconds = seconds_remaining $Camera_Back_Porch_Timer
              if ( active $Camera_Back_Porch_Timer);
        }
        elsif ( 'FP' eq state $Which_Camera_On) {
            $Item    = 'Front Porch Camera';
            $seconds = seconds_remaining $Camera_Front_Porch_Timer
              if ( active $Camera_Front_Porch_Timer);
        }
        elsif ( 'SD' eq state $Which_Camera_On) {
            $Item    = 'Side Drive Camera';
            $seconds = seconds_remaining $Camera_Side_Drive_Timer
              if ( active $Camera_Side_Drive_Timer);
        }
        elsif ( 'SY' eq state $Which_Camera_On) {
            $Item    = 'Side Yard Camera';
            $seconds = seconds_remaining $Camera_Side_Yard_Timer
              if ( active $Camera_Side_Yard_Timer);
        }
    }
    my $minutes = int( $seconds / 60 );
    $seconds = $seconds % 60;
    my $remark = "The $Item is on for $minutes minute";
    $remark .= "s" if $minutes gt 1;
    $remark .= " and $seconds seconds.";
    print_log "$remark";
    speak $remark;
}

#
# Same with timed shut off
if ( my $state = said $v_Back_Porch_Light_Timer) {
    set $Back_Porch_Light 'on';
    set $Back_Porch_Light_Post 'on';
    set $Back_Porch_Light_Time_Timer $state * 60;
    my $remark = "The Back Porch Light will turn off in " . $state . " minute";
    $remark .= "s" if $state gt 1;
    $remark .= ".";
    print_log "$remark";
    speak $remark;
}

#
# Shut the light off if the timer runs out
set $Back_Porch_Light 'off'
  if ( 'on' eq state $Back_Porch_Light
    and expired $Back_Porch_Light_Time_Timer);
set $Back_Porch_Light_Post 'off'
  if ( 'on' eq state $Back_Porch_Light_Post
    and expired $Back_Porch_Light_Time_Timer);

