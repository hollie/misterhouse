#
# Authority:Family

#
# MRU 20040212.1  ver 1.0 Pete Flaherty - pjf@cape.com, http://www.mraudrey.net
#
# Generic Data passing utility to make JavaScript variables that can be passed
#  to a script enabled pate using <script src=http://mh:8080/bin/mp3_applet_data.pl></script>
#  the returned data should be formatted as a script and usable in the page when placed
#  in the header of of the page.
#
# This can be slow if player is down, so don't do it too often
my $ref = &mp3_get_playlist();
$Save{NowPlaying} = ${$ref}[ &mp3_get_playlist_pos() ] if $ref;

# mm:ss/mm:ss (xx%)  - elapsed/full
my $mptimestr = &mp3_get_output_timestr();

#print "mptime str is $mptimestr \n";

my $mprunning = &mp3_running();

my $mpserver = $config_parms{mp3_stream_server_port};
$mpserver = "localhost:8888" unless $mpserver;

my ( $mpelapse, $mprest ) = split( /\//, $mptimestr );
my ( $mpmin,    $mpsec )  = split( /:/,  $mpelapse );
$mpelapse = ( $mpmin * 60 ) + $mpsec;

my $mpisrun = &mp3_playing();

my ( $mptime, $mpperct ) = split( / /, $mprest );
( $mpmin, $mpsec ) = split( /:/, $mptime );
$mptime = ( $mpmin * 60 ) + $mpsec;

my $mplayJs = "";
$mplayJs .= "NowPlaying = \"$Save{NowPlaying}\";\n";
$mplayJs .= "ElapsedTime = '$mpelapse';\n";
$mplayJs .= "PlayTime = '$mptime';\n";
$mplayJs .= "RAW = '$mptimestr [$mpisrun]';\n";
$mplayJs .= "Running = '$mpisrun';\n";
$mplayJs .= "StreamSvr = '$mpserver';\n";

# print "db mp3_applet: $mplayJs\n";

return $mplayJs;
