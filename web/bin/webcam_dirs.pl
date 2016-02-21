#
# Authority:family

# Seek and display the end directories that have images in them
#  we assume that this is where we have our image files and not above
#  the endpoints
#

#
#  v 0.10 - Pete Flaherty - first release
#

#default the camera dir in case we don't have one
my $camdir = $config_parms{wc_slide_dir};
$camdir = "/cameras" unless $config_parms{wc_slide_dir};

my $wcMax = $config_parms{wc_max};    # max cams
$wcMax = "4" unless $config_parms{wc_max};    # default it

my $wcx = "" unless $config_parms{wc_address_1};    # 1 ?

our $search_from = $config_parms{html_dir} . $config_parms{wc_slide_dir} . "/";
our $search_this = "";
our $thisDir;
our $base;
our $here;
my $sub_path = "";

my $html = "<HTML><HEAD>
 <!-- include var='$config_parms{html_style}' -->
</HEAD><BODY  VLINK='#CC00FF'>
<BASE TARGET='output'>";    # basic html page to the target
                            # setup our starting point
my @dirs    = $search_from; # Start with a simple array of One entry
my @endDirs = "";           # We fill this as we find the ending dirs

&recurse_dirs();            # Here we go off and find all the dirs !

@endDirs = sort @endDirs;   # Sort our entries because its easier to read

$html .=
  "<TABLE BORDER=2 BORDERCOLOR='#4169E1' BGCOLOR='#64 95 ED' ALIGN='center' NOWRAP>";

my $mycol = 1;              # table column counter

#my $columns =3;					#  and limits (width)
my $columns = $wcMax - 1;

$html .= "<TR>";

$wcx = 1;
for ( $wcx = 1; $wcx < $wcMax + 1; $wcx++ ) {
    my $wcThis = "wc_address_$wcx";
    my $wcData = "x" unless $config_parms{$wcThis};

    # check this wc setting for exist
    #Add this cameras settings into the string
    my $wcURL = $config_parms{$wcThis};
    my ( $wcURL, $wcDescr ) = split( /\,/, $wcURL );

    $html .= "<TH COLSPAN='2' NOWRAP>$wcx : $wcDescr</TH><TH></TH>"

}
$html .= "</TR>";

# Fromat into a Table for neatness in display
for my $endirs (@endDirs) {

    opendir( DIR, $endirs );    # we get the dir entries
    my @files = grep( /\.jpg$/, readdir(DIR) );
    closedir(DIR);
    my $numImages = @files;     # So we have a Count of files

    my ( $jnk, $theName ) = split( /\/\//,  $endirs );
    my ( $jnk, $myPath )  = split( /\/web/, $endirs );
    if ( ($theName) and ( $theName ne "images" ) ) {
        $html .=
            "<TD><a href='/bin/webcam_movie.pl?"
          . $myPath
          . "/' target='__blank'> "
          . $theName
          . " </a></TD><TD>("
          . $numImages
          . " Images)</TD>";
        if ( $mycol <= $columns ) { $html .= "<TD> </TD>"; }
        if ( $mycol > $columns ) { $html .= "</TR><TR>"; $mycol = 0; }
        $mycol++;
    }
}
$html .= "</TR>";
$html .= "</TABLE>";
$html .= "</BODY></HTML>";

return $html;

exit;

######################################################
sub recurse_dirs() {
    for my $dirs (@dirs) {
        if ( -d $dirs ) {    # we only care about dirs
            $search_this = "$dirs";    # where we are
            my $last_search = $search_this;    # and where we've been
            &get_dirs();                       # go find them
            $search_this = $last_search;       # and remember where we were
        }
    }
    return;
}

sub get_dirs {
    opendir( DIRHANDLE, $search_this );        # We collect the dir list
    my @files = readdir DIRHANDLE;
    closedir(DIRHANDLE);

    for my $files (@files) {

        # Here we have the subdir list for the $search_this directory

        next if ( $files =~ /^\./ );           # no dot dirs
        $thisDir = $search_this . "/" . $files;    # usable path
             # here we need to strip off everything up to and incl ./web/
        ( $base, $here ) = split( /\/web/, $thisDir );
        if ( -d $thisDir ) {

            # we need to see if we're at the end of the line
            my $Status = &test_for_dirs();    # use the quick check
            if ( $Status eq "end" ) {         # to see if were done on this one
                push @endDirs, "$thisDir";    #  yep save it to the display list
            }
            push @dirs, "$thisDir";           #and put on recurson stack
        }
    }
    return;
}

### Quick test for the end of a tree
#     we return end or Noend to indicate there are no more sub dirs
sub test_for_dirs {
    my $currTest = $thisDir;
    opendir( TESTHANDLE, $currTest );
    my @tst = readdir TESTHANDLE;
    closedir(TESETHANDLE);
    sort @tst;
    my $ret = "end";    # Assume its all over first then we'll test otherwise

    for my $tst (@tst) {
        my $tstDir = $thisDir . "/" . $tst;

        # if there is a directory (and its not a dot dir)
        if ( ( -d "$tstDir" ) and !( $tst =~ /^\.+/ ) ) {
            $ret = "Noend";    # We're not done
        }
    }
    return $ret;               # and we tell the caller the status
                               #  if were at the end of the dir chain or not
}
