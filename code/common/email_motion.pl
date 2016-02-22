
# Category = Photos

#@ Check incoming email for netcam pictures and extract the pictures to a web directory.
#@ Images in emails with a subject of 'Motion: xyz' are extracted to a /web/motion directory.
#@ Requires internet_mail.pl

# Motion detected on Garage at 8:47 PM on 3/18/2004

$p_email_motion = new Process_Item;
$v_email_motion = new Voice_Cmd 'Process email motion images';

# get_email_scan_file and $p_get_email are created by internet_mail.pl
if ( done_now $p_get_email and -e $get_email_scan_file ) {
    print "email_motion: checking $get_email_scan_file\n" if $Debug{email};
    my @msgs;
    for my $line ( file_read $get_email_scan_file) {
        print "email_motion: mail =$line\n" if $Debug{email};
        my ( $msg, $from, $to, $subject, $body ) =
          $line =~ /Msg: (\d+) From:(.+?) To:(.+?) Subject:(.+?) Body:(.+)/;
        if ( $subject =~ /^ *Motion\:? /i ) {
            print "email_motion: Found mail: $subject\n" if $Debug{email};
            push @msgs, $msg;
        }
    }

    # Read in picture emails in the background
    if (@msgs) {
        print_log "Reading email_motion msgs @msgs";
        set $p_email_motion
          qq[read_email -account bruce -msgnum "@msgs" -file "$config_parms{data_dir}/email_motion.txt"];
        start $p_email_motion;
    }
}

use MIME::Base64;

sub process_email_images {
    print "Processing motion images receieved by email\n" if $Debug{email};
    my @data = file_read "$config_parms{data_dir}/email_motion.txt";

    my $camera;
    while (@data) {
        my $r = shift @data;
        $camera = $1 if $r =~ /^ *Subject\: Motion\: (\S+)/;
        next
          unless $r =~ /^ *Content-Disposition/
          ;    # Assume this is the last record before the data
        print " - reading data for $r\n" if $Debug{email};
        shift @data;
        shift @data;    # Assume 2 blank blank header lines
        my $data;
        while (@data) {
            $r = shift @data;
            last if $r =~ /^ *$/;
            $data .= $r;
        }
        my $index = "email_motion_index_$camera";
        $Save{$index} = 1 if ++$Save{$index} > 100;
        my $member = $camera . sprintf "_%03d.jpg", $Save{$index};
        my $file = "$config_parms{data_dir}/web/motion/$member";
        print " - writing to $file\n" if $Debug{email};
        file_write $file, MIME::Base64::decode($data);
        copy "$config_parms{data_dir}/web/motion/latest1.jpg",
          "$config_parms{data_dir}/web/motion/latest2.jpg";
        copy $file, "$config_parms{data_dir}/web/motion/latest1.jpg";
    }
}

if ( said $v_email_motion) {
    $v_email_motion->respond('Processing email motion captures');
    &process_email_images();
}

&process_email_images() if done_now $p_email_motion;
