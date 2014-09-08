# Category = Photos

#@ This script allows a digital camera to be automatically downloaded by MH.
#@ Uses gphoto2, linux only.

=begin comment

gphoto2.pl 

04/19/2004 Created by Jim Duda (jim@duda.tzo.com)

This script allows a digital camera to be automatically downloaded by MH.
This script operates on Unix only, no MS Windows support.

Features: 

- Automatically downloads digital images from camera to unix directory.
- Automatically erases digital images from camera after download complete.

Requirements:

- misterhouse: http://www.misterhouse.net
- gphoto2: http://www.gphoto.org 
- digital camera :)

Setup:

Install and configure all the above software.  Copy the following scripts into your misterhouse 
code directory.   

mh/code/public/gphoto2.pl

Set the following parameters in your private mh.ini file.  

gphoto2_dir=/bigdisk/images           # optional, defaults to "$config_parms{data_dir}/photos"
gphoto2_automatic = 0/1

Restart misterhouse, browse to http://localhost:8080/mh4, and click on Digital Camera.  

You should start my using the manual method.  Set gphoto2_automatic = 0 in mh.ini
file, then use the detect, download, and erase web or voice commands.  Once you
are convinced it's all working, set gphoto2_automatic = 1 in mh.ihi.  

When configured for gphoto2_automatic mode, the script will check the camera
status every minute and automatically download and erase the files from the
camera without any human intervention required.  The script dumps the files
into a directory named according to the current date.  The images from the
camera will have unique names.  

Problems: 

Be careful when using multiple cameras.  This script assumes the filenames
from the camera will be unique.  This may not be true with multiple cameras.
You may need to adjust the script to handle this to avoid overwriting the
same names.

It's only been tested with one camera, Cannon S230.

=cut

my $gphoto2_dir = "$config_parms{data_dir}/photos";
my ( $gphoto2_state, $dir, $gphoto2_camera_cnt, $gphoto2_old_disk_cnt,
    $gphoto2_new_disk_cnt, $gphoto2_file );

if ($Reload) {
    $gphoto2_dir = "$config_parms{gphoto2_dir}" if "$config_parms{gphoto2_dir}";
    mkdir "$gphoto2_dir", 0777 unless -d "$gphoto2_dir";
    chmod 0777, "$gphoto2_dir";
    $gphoto2_camera_cnt = 0;
    $gphoto2_file       = "$config_parms{data_dir}/gphoto2_data";
    $gphoto2_state      = 'idle';
}

$p_gphoto2 = new Process_Item;

$v_gphoto2 = new Voice_Cmd '[detect, download, erase] digital camera';

# Process the results of the last run of gphoto2
if ( done_now $p_gphoto2) {

    # The --auto-detect command will return at least 3 lines
    # when there is a camera attached, only 2 lines of no camera attached.
    # The 2 lines represent the header display.
    if ( $gphoto2_state eq 'auto' ) {
        my $i = 0;
        open( FILE, "$gphoto2_file" )
          || print "Error in opening gphoto file $gphoto2_file";
        while (<FILE>) {
            $i++;
        }
        close(FILE);
        if ( $i > 2 ) {
            $gphoto2_state = 'detect';
        }
        else {
            $gphoto2_state = 'idle';
        }
    }

    # The --list-files command returns the number of images on the camera
    elsif ( $gphoto2_state eq 'detect' ) {
        $gphoto2_camera_cnt = 0;
        open( FILE, "$gphoto2_file" )
          || print "Error in opening gphoto file $gphoto2_file";
        while (<FILE>) {
            if (/There is one file in folder/) {
                $gphoto2_camera_cnt++;
            }
            if (/There are (\d*) files in folder/) {
                $gphoto2_camera_cnt += $1;
            }
        }
        close(FILE);
        if ( $config_parms{gphoto2_automatic} ) {
            if ( $gphoto2_camera_cnt > 0 ) {
                $gphoto2_state = 'download';
                speak( text =>
                      "I found $gphoto2_camera_cnt digital camera images for download"
                );
            }
            else {
                $gphoto2_state = 'idle';
            }
        }
        else {
            print_log "gphoto detect: $gphoto2_camera_cnt images found";
            speak( text =>
                  "I found $gphoto2_camera_cnt digital camera images for download"
            );
        }
    }

    # download complete, verify new files match images in camera
    elsif ( $gphoto2_state eq 'download' ) {
        opendir( DIR, $dir )
          or print "Error in opening photo directory $dir: $!\n";
        $gphoto2_new_disk_cnt = 0;
        while ( my $file = readdir(DIR) ) {
            next if ( $file =~ /^\./ );
            $gphoto2_new_disk_cnt++;
        }
        close DIR;
        $gphoto2_new_disk_cnt -= $gphoto2_old_disk_cnt;
        if ( $gphoto2_new_disk_cnt == $gphoto2_camera_cnt ) {
            print_log
              "$gphoto2_new_disk_cnt images successfully downloaded from digital camera";
            speak( text =>
                  "$gphoto2_new_disk_cnt images successfully downloaded from digital camera"
            );
            if ( $config_parms{gphoto2_automatic} ) {
                $gphoto2_state = 'erase';
            }
        }
        else {
            print_log
              "photo download failed, only $gphoto2_new_disk_cnt of $gphoto2_camera_cnt images downloaded from digital camera";
            speak( text =>
                  "photo download failed, only $gphoto2_new_disk_cnt of $gphoto2_camera_cnt images downloaded from digital camera"
            );
            if ( $config_parms{gphoto2_automatic} ) {
                $gphoto2_state = 'idle';
            }
        }
    }

    # erase is now complete, let's clean up our state
    elsif ( $gphoto2_state eq 'erase' ) {
        print_log
          "$gphoto2_camera_cnt images successfully erased from digital camera";
        speak( text =>
              "$gphoto2_camera_cnt images successfully erased from digital camera"
        );
        if ( $config_parms{gphoto2_automatic} ) {
            $gphoto2_state = 'idle';
        }
        $gphoto2_camera_cnt = 0;
    }
}

# Schedule next run of the ghoto2 application
elsif ( done $p_gphoto2) {

    # automatic camera detection each minute
    if ( $config_parms{gphoto2_automatic} ) {
        if ( $gphoto2_state eq 'idle' && $New_Minute ) {
            $gphoto2_state = 'auto';
        }
    }

    # web or speech activation
    elsif ( !defined( $gphoto2_state = said $v_gphoto2) ) {
        $gphoto2_state = 'idle';
    }

    # detect the number of images on the camera
    if ( $gphoto2_state eq 'auto' ) {
        set_output $p_gphoto2 "$gphoto2_file";
        set $p_gphoto2 "gphoto2 --auto-detect";
        start $p_gphoto2;
    }

    # detect the number of images on the camera
    elsif ( $gphoto2_state eq 'detect' ) {
        set_output $p_gphoto2 "$gphoto2_file";
        set $p_gphoto2 "gphoto2 --list-files";
        start $p_gphoto2;
    }

    # download photos from attached camera
    elsif ( $gphoto2_state eq 'download' ) {
        if ( $gphoto2_camera_cnt != 0 ) {
            $dir = time_date_stamp(11);
            $dir =~ s/\//-/g;
            $dir =~ s/ /-/g;
            $dir =~ s/\:/-/g;
            $dir = $gphoto2_dir . "/" . $dir;
            mkdir "$dir", 0777 unless -d "$dir";
            print_log "gphoto2: download $dir";

            # how many files in the current directory now?  We want to compare
            # the file counts before and after download to insure we downloaded
            # the expected count in order to verify the download was successful
            opendir( DIR, $dir )
              or print "Error in opening photo directory $dir: $!\n";
            $gphoto2_old_disk_cnt = 0;
            while ( my $file = readdir(DIR) ) {
                next if ( $file =~ /^\./ );
                $gphoto2_old_disk_cnt++;
            }
            close DIR;

            # doit
            set $p_gphoto2 "gphoto2 --filename $dir/%f.%C --get-all-files";
            start $p_gphoto2;
        }
        else {
            print_log "gphoto download: no images detected for download";
            speak( text =>
                  "sorry, no digital camera images detected for download" );
        }
    }

    # erase photos from attached camera which have been downloaded
    elsif ( $gphoto2_state eq 'erase' ) {
        if ( $gphoto2_camera_cnt == 0 ) {
            print_log "gphoto erase: no images to erase";
            speak( text => "sorry, no digital camera images to erase" );
        }
        elsif ( $gphoto2_new_disk_cnt == $gphoto2_camera_cnt ) {
            set $p_gphoto2 "gphoto2 --delete-all-files --recurse";
            start $p_gphoto2;
        }
        else {
            print_log "digital camera erase disabled, last download failed";
            speak( text =>
                  "sorry, digital camera erase disabled, last download failed"
            );
        }
    }
}
