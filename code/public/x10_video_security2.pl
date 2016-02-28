
#scanCams.pl
#adapted from x10_video_security.pl (Mark A. Holm, feb2001);
#L. Foreman 16 June 2004

use File::Copy;

my $state;
my $v_state;
my $activeCam;
my $timeNow;

#define x10 cams;
$cam_skyCam    = new X10_Item('C13');
$cam_backYard  = new X10_Item('C14');
$cam_sideYard  = new X10_Item('C15');
$cam_frontYard = new X10_Item('C16');

#Define state capture variables;
$which_cam_on  = new Generic_Item;
$camera_status = new Generic_Item;

#Define state change timers;
$camera_scanTimer = new Timer;

$v_scanCams      = new Voice_Cmd("scan cameras");
$v_grab_camImage = new Voice_Cmd("grab camImage");

#Define file grabbed cam image will be written to;
# keep paths in single quotes for image file and webPath;
my $imageFile = 'c:/Misterhouse/mh/data/photos/conquerCam.jpg';

#Define path for copied and renamed grabbed camera image;
my $webPath = '//Wxserver/c/apache2/htdocs/WUW/House_images/';

$v_copyFiles = new Voice_Cmd("copy imageFiles");
$p_copyFiles = new Process_Item;

if ( ( ( not active $camera_scanTimer) or ( said $v_scanCams) ) ) {
    $timeNow = &time_date_stamp( 12, $Time );

    run_after_delay 5, "run_voice_cmd 'grab camImage'";

    #Turn off all cameras;
    set $cam_skyCam 'off'    if ( 'on' eq state $cam_skyCam);
    set $cam_backYard 'off'  if ( 'on' eq state $cam_backYard);
    set $cam_sideYard 'off'  if ( 'on' eq state $cam_sideYard);
    set $cam_frontYard 'off' if ( 'on' eq state $cam_frontYard);

    #Turn on next camera in list;
    if ( 'side' eq state $which_cam_on) {
        set $cam_backYard 'on';
        set $camera_scanTimer 30;
        set $which_cam_on 'back';
        $activeCam = 'backYard';
        $remark    = "Scanning cameras with Back Yard camera active\n";
        $timeNow   = &time_date_stamp( 12, $Time );

    }
    elsif ( 'back' eq state $which_cam_on) {
        set $cam_frontYard 'on';
        set $camera_scanTimer 30;
        set $which_cam_on 'front';
        $activeCam = 'frontYard';
        $remark    = "Scanning cameras with Front Yard camera active\n";
        $timeNow   = &time_date_stamp( 12, $Time );

    }
    elsif ( 'front' eq state $which_cam_on) {
        set $cam_skyCam 'on';
        set $camera_scanTimer 30;
        set $which_cam_on 'skyCam';
        $activeCam = 'skyCam';
        $remark    = "Scanning cameras with skyCam camera active\n";
        $timeNow   = &time_date_stamp( 12, $Time );
    }
    else {

        set $cam_sideYard 'on';
        set $camera_scanTimer 30;
        set $which_cam_on 'side';
        $activeCam = 'sideYard';
        $remark    = "Scanning cameras with Side Yard camera active\n";
        $timeNow   = &time_date_stamp( 12, $Time );

    }
}

if ( said $v_grab_camImage) {

    #  print "Starting image capture\n";
    $timeNow = &time_date_stamp( 12, $Time );

    my $sendKeyCmd = '\\ALT\\p\\ALT-\\';

    #Be sure ConquerCam is running at this point;
    if ( my $window = &sendkeys_find_window( 'ConquerCam', 'ConquerCam' ) ) {
        &SendKeys( $window, $sendKeyCmd, 100, 0 );
        $timeNow = &time_date_stamp( 12, $Time );

        run_after_delay 2, "copy('$imageFile', '$webPath$activeCam.jpg')";
        $timeNow = &time_date_stamp( 12, $Time );

        #   print "Copied $imageFile to webserver\n\n";
    }
}

