# Category=Media
# Authority: Family
# a routine that reads /scans for media files
#
# this is the standalone 'localhost part of the code

#
# This is the remote service on another box
#  it is used if the mhmedia_server is not localhost

# V0.01 - 0.14 -Pete Flaherty
#       - Various test and debug revs

# v0.15 - Pete Flaherty
#       - initial working release

#@
#@MisterHouse Media services backend data collection.<br>
#@ This module allows the mhmedia collection to search
#@ for media files on a local OR Remote media server. <br>
#@If the mhmedia_xine (player) has the media_server_host_port
#@ set to anything except 'localhost' the routines expect that
#@ there is a media data service running on the remote machine.<br>
#@
#@By design the search is performed on the player machine for all
#@file types supported buy the player. The search will start at the
#@ path defined in the media_file_path ini parameter, and recures all the sub directories.<br>
#@ The remote server can be tested by telnetting to the ipaddress
#@ on port 6790 (xine remote being on 6789) the argument 'search' and the
#@ path make up the command eg 'search /home/media'

sub mhmms_get_remote_list {

    my $cmd = shift;
    my @rtn = ();
    my ( $rtn, $data );
    my $pos = 0;
    my $EOL = "\015\012";

    # Get the method we need to use
    #  Either its a local listing or a remote one
    my $mediaserver = $config_parms{media_server_host_port};
    my ( $host, $port ) = split( /:/, $mediaserver );
    my $mediahost = $host . ":6790";

    my $mediapath = $config_parms{media_file_path};
    $mediapath = "" unless $config_parms{media_file_path};

    my $mediadata =
      new Socket_Item( undef, undef, $mediahost, 'mediadata', 'tcp' );

    start $mediadata ;    # open socket
                          # send data out
    set $mediadata $cmd;

    # This look a bit funny but the escape is inside
    while () {

        #select undef, undef, undef, .050; 	# Wait a while if needed
        $data = said_next $mediadata;    # get a string
        $pos  = $pos + 1;                # becuse we like counting entries
             # print "mhmms-list:$data\n";		# and seeind data sometimes
             #check to see if were done or the server is dead etc...
        last if ( $data eq "DONE" or $data eq '' or $data eq "\r\n" );

        #collect data into an aray
        push @rtn, "$data";

    }

    # OK were done so stop the socket and return the data
    stop $mediadata;
    return @rtn;
}

##################################################
# Get the local list if available
#  make it on the fly, this may cahuse MH to stutter
#  as we jump way out of the MH structure to
#  do our thing. We are careful to return back
#  before we resume MH looping
#

sub mhmms_get_local_list {
    my ( $cmd, $search_path ) = split( / /, shift @_ );

    #my $search_path = shift @_;
    #   $search_path = '/home/pjf/music' unless $search_path;

    print "mhmms: got $cmd $search_path\n";
    my $search_this = $search_path;
    my ( @files, @dirs, @retn );

    tr/A-Z/a-z/ for $cmd;
    my $args;
    my $buf;

    #break up teh arguments
    $buf  = $cmd;
    $args = $search_path;

    if ( $buf eq 'hello' ) {
        return "Hi\n";
    }

    elsif ( $buf eq 'search' ) {

        # be sure we start with cleared arrays
        print "Searching $args\n";
        @files = ();
        @dirs  = ();

        # print "Searching $args \n";
        my $search_this = $search_path;

        if ( $args ne '' ) { $search_this = $args; }
        @dirs = $search_this;

        # Because we move cwd around we need to get back
        my $CurrentDir = getcwd();

        #print " Program path $CurrentDir\n";

        @retn  = &mhmms_search($search_this);
        @files = ();
        @dirs  = ();
        chdir("$CurrentDir");
        return @retn;
    }

    # default case:
    else {
        return "Command Not recognized\n";
    }

}

sub mhmms_search {
    my $search_this = shift;

    #$search = "/home/pjf/music" ; #unless $search ;

    # this is where we search teh local drive for media
    # optionally we could accept a starting path to dive into

    print " Search started for $search_this\n";
    chdir($search_this) || die "Can Not Find \'$search_this'\n";

    my @retn = &mhmms_recurse_dirs($search_this);

    #print " \nRETURN >> @retn \n";
    return @retn;
}

sub mhmms_recurse_dirs {
    my @dirs = shift;
    my $search_this;
    my ( @files, @retn );
    print " Recursing dirs $search_this\n";
    for my $dirs (@dirs) {
        $search_this = "$dirs";
        my $last_search = $search_this;
        print "DIR >> $dirs \n";
        @files = &mhmms_get_dir($dirs);

        #my(@retn, @dirs) =
        &mhmms_ret_types( \@files, \@dirs, \@retn, $search_this );

        #@dirs=@$dirs;
        #@retn=@$retn;
        $search_this = $last_search;
    }
    return @retn;
}

sub mhmms_get_dir {
    my $search_this = shift;

    # get the directory listing
    #print "Reading Directory $search_this\n";
    opendir( DIRHANDLE, $search_this );
    my @files = readdir DIRHANDLE;
    closedir(DIRHANDLE);
    return @files;
}

sub mhmms_ret_types {
    my ( $files, $dirs, $retn, $search_this ) = @_;

    #my @retn = shift;
    #my @dirs = shift;
    #my @files = shift;

    my @search_types =
      qw( asf avi mov mp3 mp4 mpeg mpg ogg rma vob wav wma wmv );

    #print "Sorting ...$search_this\n";
    #   print "\n files @$files \n dirs @$dirs \n retn @$retn";

    #now sort through it and return valid types
    for my $afile ( sort @$files ) {
        next if ( $afile =~ /^\./ );    #no dor dirs
                                        #print "$afile \n";
        my $name = "";
        my $extn = "dir";
        ( $name, $extn ) = split( /\./, $afile );

        if ($extn) {
            ##print "extension $extn\n";
            # and save off the sub dirs for later
            for my $match (@search_types) {
                if ( $extn eq $match ) {

                    #print " found $search_this  $afile\n";
                    push @$retn, "$search_this//$afile \n";
                }
            }
        }
        else {
            # push the sub dirs onto the recurse stack
            push @$dirs, "$search_this/$name";
        }
    }
    return ( @$retn, @$dirs );
}

