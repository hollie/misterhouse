
# Category = Photos

#@ Check incoming email for netcam pictures and extract the pictures to a web directory.
#@ Images in emails with a subject of 'Motion: xyz' are extracted to a /web/motion directory.
#@ Requires internet_mail.pl

# Motion detected on Garage at 8:47 PM on 3/18/2004

$email_motion_p = new Process_Item;

                                # get_email_scan_file and $p_get_email are created by internet_mail.pl
if (done_now $p_get_email and -e $get_email_scan_file) {
    print "email_motion: checking $get_email_scan_file\n" if $Debug{email};
    my @msgs;
    for my $line (file_read $get_email_scan_file) {
	print "email_motion: mail=$line\n" if $Debug{email};
        my ($msg, $from, $to, $subject, $body) = $line =~ /Msg: (\d+) From:(.+?) To:(.+?) Subject:(.+?) Body:(.+)/;
        if ($subject =~ /^Motion /i ) {
            push @msgs, $msg;
        }
    }
                                # Read in picture emails in the background
    if (@msgs) {
        print_log "Reading email_motion msgs @msgs";
        set $email_motion_p qq[read_email -account bruce -msgnum "@msgs" -file "$config_parms{data_dir}/email_motion.txt"];
        start $email_motion_p;
    }
}

$email_motion_v = new Voice_Cmd 'Test email motion';

use MIME::Base64; 
if (done_now $email_motion_p or said $email_motion_v) {
    print "Processing email_motion images\n";
    my @data  = file_read "$config_parms{data_dir}/email_motion.txt";

    my $camera;
    while (@data) {
        my $r = shift @data;
        $camera = $1 if $r =~ /^ *Subject\: Motion\: (\S+)/;
        next unless $r =~ /^ *Content-Disposition/; # Assume this is the last record before the data
        print " - reading data for $r\n";
        shift @data; shift @data;  # Assume 2 blank blank header lines
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
        print " - writing to $file\n";
        file_write $file, MIME::Base64::decode($data);
        copy "$config_parms{data_dir}/web/motion/latest1.jpg", "$config_parms{data_dir}/web/motion/latest2.jpg";
        copy $file, "$config_parms{data_dir}/web/motion/latest1.jpg";
    }
}
