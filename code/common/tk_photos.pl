# Category = Photos

#@ This script displays a fullscreen photo slideshow on the local monitor.
#@ It is particularly nice if your computer is hooked up to a TV.

=begin comment

For a web browser option, see mh/web/misc/photos.shtml

More info on creating the photo list can be found
in mh/code/test/photo_index.pl

See mh/bin/mh.ini for the various photo_* parms

03/30/2002 Created by David Norwood and Bruce Winter

=cut

use Tk;

#noloop=start
my_use "Tk::JPEG";             # Optional, in case it is not installed
my_use "Tk::CursorControl";    # Ditto

$v_photo_slideshow =
  new Voice_Cmd('[Start,Stop,Next,Previous] the photo slideshow');

$t_photo_slideshow = new Timer;
$p_photo_slideshow = new Process_Item;

use vars '@photos';            # This will be persistent across code reloads
@photos = file_read $config_parms{photo_index} unless @photos;
$config_parms{photo_time} = 60 unless defined $config_parms{photo_time};

my ( $mw_photo, $mw_photo_label, $mw_photo_image, $mw_cursor );
my $photo_temp_file = "$config_parms{data_dir}/mh_temp.tk_photo.jpg";

#noloop=stop

if ( said $v_photo_slideshow) {
    my $state = $v_photo_slideshow->{state};

    if ( $state eq 'Start' ) {
        $v_photo_slideshow->respond('app=photos Starting the slideshow...');

        # Create a full screen, frameless window
        unless ($MW) {
            $MW = MainWindow->new;
            $MW->geometry('0x0+0+0');
        }
        eval '$mw_cursor = $MW->CursorControl';   # Initialise the CursorControl
        $mw_photo = $MW->Toplevel( -bg => "black" );
        $mw_photo->overrideredirect(1);
        geometry $mw_photo $MW->screenwidth . "x" . $MW->screenheight . "+0+0";

        $mw_photo->bind( "<q>",
            sub { run_voice_cmd 'Stop the photo slideshow' } );    # *** !
        $mw_photo->bind( "<n>", sub { &photo_change('next') } );
        $mw_photo->bind( "<p>", sub { &photo_change('previous') } );
        eval
          '$mw_cursor-> hide($mw_photo)'; # Hide the mouse cursor on this window

        $mw_photo_label = $mw_photo->Label( -border => 0 )
          ->pack( -anchor => 'center', -expand => 1 );
        &photo_change('next');

    }
    elsif ( $state eq 'Stop' ) {
        $v_photo_slideshow->respond('app=photos Stopping the slideshow...');
        eval '$mw_cursor-> show($mw_photo)';    # Show the cursor
            #   $MW             -> destroy  if $MW and ! $config_parms{tk};
        $mw_photo->destroy      if $mw_photo;
        $mw_photo_image->delete if $mw_photo_image;
        undef $mw_cursor;
        undef $mw_photo_image;
        undef $mw_photo;
        unset $t_photo_slideshow;
    }
    elsif ( $state eq 'Next' ) {
        $v_photo_slideshow->respond('app=photos Next slide.');
        &photo_change('next');
    }
    elsif ( $state eq 'Previous' ) {
        $v_photo_slideshow->respond('app=photos Previous slide.');
        &photo_change('previous');
    }
}

&photo_change('next') if expired $t_photo_slideshow;

sub photo_change {
    my ($mode) = @_;
    return unless $mw_photo;    # If mh restarted, timer will still trigger

    my $i = $Save{photo_index};
    ( $mode eq 'previous' ) ? $i-- : $i++;
    $i = 0        if $i > $#photos;
    $i = $#photos if $i < 0;
    $Save{photo_index} = $i;

    # Find real path to the photo
    my ($jpeg) = &http_get_local_file( $photos[$i] );

    # Optionally resize the photo to full screen
    # Do it with a process, as it can take seconds
    if ( $config_parms{photo_resize} ) {
        my $size = $MW->screenwidth . "x" . $MW->screenheight;
        set $p_photo_slideshow
          qq|image_resize --size "$size" --file_in "$jpeg" --file_out "$photo_temp_file"|;
        start $p_photo_slideshow;
    }

    # This on-the-fly resize option causes mh to pause
    elsif (0) {

        #       use Image::Magick;
        my $img = new Image::Magick;
        my $rc;
        warn($rc) if $rc = $img->Read($jpeg);

        # This step takes 1-2 seconds
        warn($rc) if $rc = $img->Scale( -geometry => '1280x1024' );
        warn($rc) if $rc = $img->Write($photo_temp_file);
        &photo_insert($photo_temp_file);
    }
    else {
        &photo_insert($jpeg);
    }

}

&photo_insert($photo_temp_file) if done_now $p_photo_slideshow;

sub photo_insert {
    my ($jpeg) = @_;

    # Use delete on photo (destroy does not free up the memory?)
    #   $mw_photo_image -> destroy if $mw_photo_image;
    $mw_photo_image->delete if $mw_photo_image;

    $mw_photo_image = $mw_photo->Photo( -file => $jpeg );

    # This step takes 1-2 seconds for large images :(
    $mw_photo_label->configure( -image => $mw_photo_image );

    # Sync up with web based photo viewers
    my $time      = $config_parms{photo_time};
    my $time_diff = $Time - $Save{photo_index_time};
    if ( $time_diff > 5 and $time_diff < $time - 5 ) {
        $time = $time - $time_diff;
    }
    else {
        $Save{photo_index_time} = $Time;
    }
    set $t_photo_slideshow $time;
}
