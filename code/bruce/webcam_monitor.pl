
#@ Monitor webcam image files

#y $webcam_dir = '/Program Files/beausoft/ncwpro/';
my $webcam_dir     = 'p:/Program Files/beausoft/wcwpro/';
my @webcam_cameras = qw(Garage1 Driveway);

$webcam_garage   = new Generic_Item;
$webcam_driveway = new Generic_Item;

if ( new_second 2 ) {
    for my $camera (@webcam_cameras) {

        # Note, need to enable mail to function to get lastalm.  lastpic is always updated.
        #       my $file = "$webcam_dir/$camera/lastpic.jpg";
        my $file = "$webcam_dir/$camera/lastalm.jpg";

        # Ignore small, corrupted files
        if ( file_changed $file and ( file_size $file) > 7500 ) {

            #           print_log "Camera motion: $camera";

            my $index = "webcam_index_$camera";
            $Save{$index} = 1 if ++$Save{$index} > 500;
            my $member = $camera . sprintf "__%03d.jpg", $Save{$index};
            my $file2 = "$config_parms{data_dir}/web/motion/$member";

            copy $file,
              "$config_parms{data_dir}/web/motion/${camera}_Latest.jpg";
            copy $file, $file2;

            # These can be monitored from other code files (e.g. motion monitoring)
            set $webcam_garage $file2   if $camera eq 'Garage1';
            set $webcam_driveway $file2 if $camera eq 'Driveway';

        }
    }
}

# Make sure we are not waiting on the confirm box
# - Note:  WaitForAnyWindow leaks memory :(   So don't to  too often
my $window_webcam;

if ( 0 and new_minute 15 ) {
    if ( &WaitForAnyWindow( 'confirm', \$window_webcam, 1, 1 ) ) {
        print "found confirm window w=$window_webcam\n";

        #       &SendKeys($window_webcam, '\\alt+y', 1, 500);
        &SendKeys( $window_webcam, '\\ret\\ret\\ret\\ret\\ret', 1, 500 );
    }
    if ( &WaitForAnyWindow( 'Watcher Pro', \$window_webcam, 1, 1 ) ) {

        #        print_msg "found confirm window2 w=$window_webcam";
        &SendKeys( $window_webcam, '\\ret\\ret', 1, 500 );
    }
}
