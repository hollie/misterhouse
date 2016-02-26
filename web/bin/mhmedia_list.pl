#H
# Get available media files and present a page
#
#
# v0.15 - Pete Flaherty
#	- initial working release
#

# Get the method we need to use
#  Either its a local listing or a remote one
my $mediaserver = $config_parms{media_server_host_port};
my ( $host, $port ) = split( /:/, $mediaserver );
my $mediahost = $host . ":6790";

my $mediapath = $config_parms{media_file_path};
$mediapath = "" unless $config_parms{media_file_path};

# we'll assume if this is set to localhost we're running on this machine
# else we setup to ask the servers machine about available files
my $dataMode = '';
if ( $host eq 'localhost' ) {
    $dataMode = 'local';
}

my @rtn  = ();
my $html = "<html><head><title>Mister Media</title></head><body>";

my $cmd = "search $mediapath";

# We're running Remotely ...so...
if ( $dataMode ne 'local' ) {
    print "Getting remote media Files\n";
    @rtn = &mhmms_get_remote_list($cmd);
}
else {
    # Call the mhmms-local search routine client
    my $cmd = "search $mediapath";
    @rtn = &mhmms_get_local_list($cmd);
}

#### common
# now format the output into an html page
foreach my $FILESPEC (@rtn) {
    $FILESPEC =~ s/\s*$//;    #remove trailing whitespace if there
                              #print " files processing $FILESPEC\n";
    my ( $path, $file ) = split( /\/\//, $FILESPEC );

    $html = $html . "
    <a href='/sub?mhmedia_queue(file:/$FILESPEC)' target='action')>[Queue]</a> 
    <a href='/sub?mhmedia_play(file:/$FILESPEC)' target='action'>[Play]</a> $file<br>";

}

$html = $html . "</body></html>";

#$state = $state . "DATA is here";

return $html;

# Now we have the list (alabit bare of detail)

