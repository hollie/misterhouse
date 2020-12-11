#!/usr/bin/perl
# Authority: anyone

# Call with something like this:
#  <img name="pic" src="/bin/video_streamer.pl" onload="javascript:document.pic.src='/bin/video_streamer.pl';">

my $data;
open( F, "-|" ) or exec "/usr/bin/streamer -q -o /proc/self/fd/1 -f jpeg -j 75";
while (<F>) {
    $data .= $_;
    next;
}
print "Content-Type: image/jpeg\n\n" . $data;

