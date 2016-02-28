
=begin Comment

From Ron Klinkien on 7/23/2001:

After downloading and trying several java/javascript webcam
tools and cam grab commands to no avail...I decided to take 
another aproach.

If you have a simple cli command (called grab here) 
to take a snapshot jpeg of your cam then do this:

Make a perl routine (called backgrab) to take the shot:

And you are done!

After the refresh of 120 seconds it simply calls &backgrab again and
displays the new snapshot in one go. 
(see webcab_ron.html for an example)

Sorry if you knew this already, but I find it rather cool. ;-)

Use with mh/web/public/webcam_ron.shml

=cut

sub backgrab {
    my $pid = fork;
    if ( defined $pid && $pid == 0 ) {
        exec qq[grab -type jpeg -width 320 -height 240 -output \
                /mh/web_my/cameras/captures/back_latest.jpg -quality 90 -settle 1];
        die 'cant exec backgrab';
    }
}
