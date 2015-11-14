#
# Authority:Family

#
# MRU 20080114.1  ver 1.0 Pete Flaherty - pjf@cape.com, http://www.mraudrey.net
#
# Generic Data passing utility to make JavaScript variables that can be passed
#  to a script enabled page using <script src=http://mh:8080/bin/wc_settings.pl></script>
#  the returned data should be formatted as a script and usable in the page when placed
#  in the header of of the page.
#
# v 1.01 - Pete Flaherty - genericised parameters and we now start at camera 1 not 0
#                          updated ini parameter defaults to look for _1 v _0

#Referenc:
#Javascript output
# webCamRegisterCam("Driveway", "http://192.168.0.223/usr/yoics0.jpg", 1);
# ini parameters wc_address=ip.address,Description

#For HTML out
#<a href="cam0.shtml" target="camwin"><img src="http://192.168.0.223/usr/yoics0.jpg" width='176' height='144'></a>

#
# Parameters [[columns] [url-to-image]]
#	no args		Output is a javascript
#			the output is a javascript scriptlet with the camera parameters
#			set to create the webcam parameters set into the webCamRegister() function
#			as well as the refresh rate based on the number of cameras ( webCamUpdateInterval )
#
#	columns 	Output is a formatted html page with table
#			the number of columns to format the plain html pagees table to
#
#	url-to-image	output is a fully formatted html page with a fullscreen image(url)
#			for full html only page image viewing
#
#  if a url-to-image is passed the column formatting is disreguarded and not used
#
#

# Get the config parameter for each webcam
# We use the wc_address_x from 0 to wc_max - 1

# if we pass anything in output changes to html snippet
my $outmode = @ARGV[0];   # arg is number of columns to format to
my $arg2    = @ARGV[1];   # if we have a second arg it is the url for full frame
my ( $outimage, $rest ) = split / /, $arg2;    # because we may have extra stuff

my $html   = "<!-- $outmode @ARGV --> \n ";
my $across = 1;                                # how many across are we now ?

my $wcMax = $config_parms{wc_max};             # max cams
$wcMax = "4" unless $config_parms{wc_max};     # default it

my $wcx = "" unless $config_parms{wc_address_1};

my $wc_bg_color = $config_parms{wc_bg_color};
$wc_bg_color = '0x333366' unless $config_parms{wc_bg_color};

my $scriptlet = "<script>\n";                  #"";

$html .= "<table align='CENTER'><tr>";

# this is where we loop through all our camera entries
for ( $wcx = 1; $wcx < $wcMax + 1; $wcx++ ) {

    # check this wc setting for exist
    my $wcThis = "wc_address_$wcx";
    my $wcData = "x" unless $config_parms{$wcThis};

    if ( $wcData ne "x" ) {

        #Add this cameras settings into the string
        my $wcURL = $config_parms{$wcThis};
        my ( $wcURL, $wcDescr ) = split( /\,/, $wcURL );
        $scriptlet .=
          "webCamRegisterCam(\"" . $wcx . ": $wcDescr\", \"$wcURL\", $wcx); \n";

        $html .=
            "<td BGCOLOR='"
          . $wc_bg_color
          . "'><CENTER><a href='/bin/wc_settings.pl/?1&"
          . $wcURL
          . "' target='output'><img src='$wcURL' width='176' height='144'><br>$wcx: $wcDescr</a></CENTER></td>";

        # add some breaks so we can specify how many wide
        if ( ( $outmode - $across ) <= 0 ) {
            $html .= "</tr><tr>";
            $across = 0;
        }
        $across++;
    }

}
$html .= "</tr></table>";

$scriptlet .= "
if ( webCamUpdateInterval < ( ( webCamName.length -1 ) * .5) ){
     webCamUpdateInterval = ( ( webCamName.length -1 ) * .5 )
}
</script>
";

# make up our plain html page (refreshed @1 sec)
my $framed = "<html><head>
	    <!--#include var=" . $config_parms{html_style} . " -->
	    <meta http-equiv='refresh' content='1'>
	    <title>Live Camera View</title></head>
	    <body><target='output'>
	    <center>
	    <A href='/ia5/security/main.shtml'> <img src=$outimage onclick='back'></a><br>Image: $outimage
	    </center>
	    </body></html>
	    ";

if ( $outmode > 0 and !$outimage ) {
    return $html;
}
elsif ( !$outmode and !$outimage ) {
    return $scriptlet;
}
elsif ( $outmode and $outimage ) {
    return $framed;
}

