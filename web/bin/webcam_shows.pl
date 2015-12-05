#
# Athority:Family

#
# Dynamic Webcam slideshow (movie) maker for webcam sub-dirs
#
# V0.00	Pete Flaherty	Initial concept release

#default the camera dir in case we don't have one
my $camdir = $config_parms{wc_slide_dir};
$camdir = "/cameras/cams" unless $config_parms{wc_slide_dir};

my $wcMax = $config_parms{wc_max};    # max cams
$wcMax = "4" unless $config_parms{wc_max};    # default it

my $wcx = "" unless $config_parms{wc_address_1};    # 1 ?

# Get the list of directories in the camera directory
my $abs_dir =
  $config_parms{html_dir} . "/" . $config_parms{wc_slide_dir} . "/cams";
opendir( DIR, $abs_dir );
my @files = grep { !/\.$/ && -d "$abs_dir/$_" } readdir(DIR);    #readdir(DIR);
closedir(DIR);

# Sort em for neatness
@files = sort(@files);

my $bgcolor = "#333366";

my $webdir =
  $config_parms{wc_slide_dir} . $config_parms{wc_slide_dir} . "/cams/";
my $html =
  "<!-- Dynmically Generated List for $config_parms{wc_slide_dir} -->\n";
$html .= "<TABLE BORDER=0 CELLSPACING=0 CELLPADDING=3>\n";

# make the links to the movie files ...

my $wcx = 1;
foreach $file (@files) {

    my $cam_dir = $abs_dir . "/" . $file;
    opendir( DIR, $cam_dir );
    my @files = grep( /\.jpg$/, readdir(DIR) );

    # my @files = grep{ !/\.jpg$/ && -f "$cam_dir/$_"} readdir(DIR); #readdir(DIR);
    closedir(DIR);

    @files = sort (@files);

    my $num_images = @files;

    my $wcThis = "wc_address_$wcx";
    my $wcData = "x" unless $config_parms{$wcThis};

    # check this wc setting for exist
    #Add this cameras settings into the string
    my $wcURL = $config_parms{$wcThis};
    my ( $wcURL, $wcDescr ) = split( /\,/, $wcURL );
    my $currDir =
      "/bin/webcam_movie.pl?" . $config_parms{wc_slide_dir} . "/cams/" . $file;
    my $href = "<a href='" . $currDir . "' target='_blank' >";

    $html .= "<TR><TD WIDTH=50>  </TD>\n";
    $html .=
        "<TD BGCOLOR='$bgcolor' ALIGN='center'>"
      . $href
      . "<img SRC='/graphics/icons/security1.png'>
    		 </a></td>";

    $html .=
        "<TD BGCOLOR='$bgcolor' ALIGN='center'>"
      . $href . "#"
      . $wcx . " "
      . $wcDescr . "<BR>"
      . $num_images
      . " images <br>"
      . "</a></td>";

    # my  $last_image = $files[$num_images - 1] ;
    my ( $last_image, $jnk ) = split /\-/, $files[ $num_images - 1 ];
    if ($last_image) {
        $jnk =
            substr( $last_image, 0, 4 ) . "/"
          . substr( $last_image, 4,  2 ) . "/"
          . substr( $last_image, 6,  2 ) . " "
          . substr( $last_image, 8,  2 ) . ":"
          . substr( $last_image, 10, 2 ) . ":"
          . substr( $last_image, 12, 2 ) . " "
          . substr( $last_image, 14 );

        #$last_image = sprintf ('%04s/2%02s%02d%02d%02d%02d%02d',$last_image, $last_image);
    }
    else { $jnk = "None"; }
    $html .=
        "<TD BGCOLOR='$bgcolor' ALIGN='center'>"
      . $href
      . " Last Image <br>" . " "
      . $jnk
      . "</a></td>";

    $html .=
        "<TD BGCOLOR='$bgcolor' ALIGN='center'>"
      . $href
      . "<IMG SRC='/graphics/movie.gif'>
    		 </a></td>";

    $html .= "</TR>\n";
    $wcx++;
}

$html .= "</TABLE>";

return $html;

