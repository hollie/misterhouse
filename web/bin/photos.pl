
=begin comment

Created from Dougs pictureframe.* files

This file is called directly from the browser with:

  http://localhost:8080/bin/photos.pl

More info on creating the photo list can be found in mh/code/common/photo_index.pl

See mh/bin/mh.ini for the various photo_* parms

Example mh.ini parms:
  html_alias_photos     = c:/pictures_small
  html_alias_photos_dad = c:/pictures_small/dad/Slides
  photo_dirs   = /photos,/photos_dad
  photo_index  = /misterhouse/data/photo_index.txt

=cut

my ( $i, $parm ) = @ARGV;
$parm = '' unless $parm;

use vars '@photos';    # This will be persistent across passes and code reloads
@photos = file_read $config_parms{photo_index} unless @photos;

# Set up defaults
my $time = $config_parms{photo_time};
$time = 60 unless defined $time;
$config_parms{photo_url} = '/ia5' unless $config_parms{photo_url};
my $background =
  ( $config_parms{photo_background} =~ /$Http{'User-Agent'}/ ) ? 1 : 0;

#$background = 1;
my $browser_size = &http_agent_size;

# Decide which picture to show

# If a non-digit photo requested, serve the default.
if ( !defined $i or $i !~ /^\d+$/ ) {
    $i = $Save{photo_index};
}

# If sync, and requested photo does not match up with the last
# photo served, then change the refresh time to sync up the 2 browsers
elsif (
    $parm eq 'sync'
    and !(
        $i == $Save{photo_index} + 1
        or ( $i == 0 and $Save{photo_index} == $#photos )
    )
  )
{
    $i = $Save{photo_index};
    my $time_diff = $Time - $Save{photo_index_time};
    if ( $time_diff > 5 and $time_diff < $time ) {
        $time = $time - $time_diff;
    }
    else {
        $Save{photo_index_time} = $Time;
    }

    #   print "dbx i=$i t=$time td=$time_diff\n";
}

# Serve requested photo and set time index
else {
    $Save{photo_index_time} = $Time;
}
$i = $#photos if $i > $#photos;    # In case new index is smaller

# Find previous and next indexes
my $i_p = ( $i == 0 )        ? $#photos : $i - 1;
my $i_n = ( $i >= $#photos ) ? 0        : $i + 1;
$Save{photo_index} = $i;

# Guess at a name for a bigger version of the photo
my $photo      = $photos[$i];
my $photo_name = $photo;

#use HTML::Entities;             # To translate characters like # and space
#$photo     = encode_entities $photo, ' #';
$photo =~ s/ /%20/g;
$photo =~ s/\#/%23/g;
$photo =~ s/\'/%27/g;
my $big_photo = $photo;

# change the big photo link to not include the filter if required

if ( my $filter = $config_parms{photo_filter} ) {
    $filter =~ s|\^||;
    my $tmp  = $big_photo;
    my $tmp2 = $photo_name;
    if ( $tmp =~ s/$filter// ) {
        $tmp2 =~ s/$filter//;
        my $realdir;
        ($realdir) = &http_get_local_file($tmp2);
        if ($realdir) {
            $big_photo  = $tmp;
            $photo_name = $tmp2;
        }
    }
}

# change the big photo link to point to the originals directory if it exists

my $next;
my @bigs = split /\s*,\s*/, $config_parms{photo_big_dirs};
foreach my $webdir ( split /\s*,\s*/, $config_parms{photo_dirs} ) {
    my $tmp  = $big_photo;
    my $tmp2 = $photo_name;
    if ( $tmp =~ s/^$webdir/$bigs[$next]/ ) {
        $tmp2 =~ s/$webdir/$bigs[$next]/;
        my $realdir;
        ($realdir) = &http_get_local_file($tmp2);
        if ($realdir) {
            $big_photo  = $tmp;
            $photo_name = $tmp2;
            last;
        }
    }
    $next++;
}

$photo_name = '...' . substr( $photo_name, -60 )
  if $browser_size < 800 and length $photo_name > 60;

# Set up refresh control
#$time = 10;
my $time2 = $time * 1000;

# This is simplier.
my $refresh =
  "<meta HTTP-EQUIV='Refresh' CONTENT='$time;URL=/bin/photos.pl?$i_n&sync'>";

# This can cause problems.   When the java timer expires
# to triggers a refresh on the Audrey, it will interrupt any other voyager browser activity
#my $refresh = qq|
#<script language="JavaScript">
#function doLoad()  { setTimeout( "refresh()", $time2 ); }
#function refresh() { window.location.href = "photos.pl?$i_n&sync"; }
#</script>
#|;

#    window.location.replace( "/bin/photos.pl?$i_n&sync" );

$refresh =~ s/&sync// if $config_parms{photo_nosync};
$refresh = ' ' if $parm eq 'pause' or $time == 0;

# Create header html with optional search
my $header = '';
$header =
  "<font size='3' color='#ff0000'><a href=/misc/photo_search.html>$i</a> :
<a href=$big_photo>$photo_name</a></font>" unless $config_parms{photo_no_title};
$header = "<form action='/bin/photo_search.pl'>
<input size=15 name='search' onChange='form.submit()'>
$header
</form>" unless $config_parms{photo_no_search};

my $border = 0;
if ( $parm eq 'help' ) {
    $border = 2;
    $photo  = '/graphics/photo_help.gif';
    $photo  = '/graphics/photo_help2.gif' if $browser_size > 640;
    $header = '';
}

# Now create the html.   Spec background with style sheet
# so we use no-repeat to avoid tile-ing on bigger browers
my $html = "<html><head>$refresh<title>MisterHouse Photo Viewer</title>";
if ($background) {
    $html .= "<style>\n<!--\n body {background: url($photo) no-repeat;\n";

    #   html .= "background-position: center\n";
    $html .= $config_parms{photo_back_style};
    $html .= "}\n--></style>\n";
}
$html .= "</head>\n";

#$html .= "<base target='_top'>\n";

# Audrey does not support layer clock on the status line
# so lets put on on the photo page
my $clock = ( $Http{'User-Agent'} eq 'Audrey' ) ? 1 : 0;
$clock = ( $config_parms{photo_no_clock} ) ? 0 : $clock;
my $clock_js = &file_read('../web/bin/clock1.js') if $clock;

# Show image as a background image with invisible links
my ( $width, $height, $height2 );

#$width, $height) = (200, 140);
#$width, $height) = (255, 155) if $browser_size > 640;
#$width, $height) = (150, 140);
( $width, $height ) = ( 150, 136 );
( $width, $height ) = ( 190, 155 ) if $browser_size > 640;
$height2 = ( $height - 30 );

if ($background) {

    if ($clock) {

        #        $html .= qq[<body background='$photo' onLoad='clock();doLoad()'> $clock_js];
        $html .= qq[<body background='$photo' onLoad='clock()'> $clock_js];
    }
    else {
        $html .= qq[<body background='$photo' >];

        #       $html .= qq[<body background='$photo' onload='doLoad()'>];
    }

    $html .= qq[
<table>
<tr><td colspan=4 align=left>
$header
</td></tr>
<tr>
<td><a href='javascript:history.go(-1)'>              <img src='/graphics/1pixel.gif' width='$width' height='$height' border=$border></a></td>
<td><a href='$config_parms{photo_url}' target='_top'> <img src='/graphics/1pixel.gif' width='$width' height='$height' border=$border></a></td>
<td><a href='$config_parms{html_file}'    target='_top'> <img src='/graphics/1pixel.gif' width='$width' height='$height' border=$border></a></td>
<td><a href='/clock/index.html'>                      <img src='/graphics/1pixel.gif' width='$width' height='$height' border=$border></a></td>
</tr><tr>
<td><a href='/bin/photos.pl?$i_p'>      <img src='/graphics/1pixel.gif' width='$width' height='$height' border=$border></a></td>
<td><a href='/bin/photos.pl?$i&help'>   <img src='/graphics/1pixel.gif' width='$width' height='$height' border=$border></a></td>
<td><a href='/bin/photos.pl?$i&help'>   <img src='/graphics/1pixel.gif' width='$width' height='$height' border=$border></a></td>
<td><a href='/bin/photos.pl?$i_n'>      <img src='/graphics/1pixel.gif' width='$width' height='$height' border=$border></a></td>
</tr><tr>
<td><a href='/misc/photos.shtml' target='_top'> <img src='/graphics/1pixel.gif' width='$width' height='$height' border=$border></a></td>
<td><a href='/bin/photos.pl?$i&pause'>          <img src='/graphics/1pixel.gif' width='$width' height='$height' border=$border></a></td>
<td><a href='/bin/photos.pl?$i&pause'>          <img src='/graphics/1pixel.gif' width='$width' height='$height' border=$border></a></td>
];

    if ($clock) {
        $html .= qq[
<td>
<table><tr>
<td><a href='/misc/photo_search.html'>          <img src='/graphics/1pixel.gif' width='$width' height='$height2' border=$border></a></td>
</tr><tr><td align='right'>
<form name=form><input type=button name=jclock value='hi there' style="font-size: 15"></form>
</td></tr>
</table>
</td>

</tr>
</table>
];
    }
    else {
        $html .= qq[
<td><a href='/misc/photo_search.html'>          <img src='/graphics/1pixel.gif' width='$width' height='$height' border=$border></a></td>
</tr>
</table>
];
    }
}
else {
    #   $html .= "<body onload='doLoad()'>
    $html .= "<body>
    <style>\n<!--\n body {background:  no-repeat;\n
       $config_parms{photo_back_style}
    }\n--></style>\n
<table align='center' width='95%' border='0' cellspacing='0' cellpadding='0'><tr>
<td colspan=6 align='center'>$header</td>
</tr><tr>
<td><a href='$config_parms{photo_url}' target='_top'>Main Menu</a></td>
<td><a href='$config_parms{html_file}' target='_top'>Menus</a></td>
<td><a href='/bin/photos.pl?$i_p'>Previous</a></td>
<td><a href='/bin/photos.pl?$i&pause'>Pause</a></td>
<td><a href='/bin/photos.pl?$i_n'>Next</a></td>
<td><a href='/misc/photo_search.html'>Search</a></td>
<td><a href='/clock/index.html' target='_top'>Clock</a></td>
</tr><tr>
<td colspan=6 align='center'><img src='$photo'></td>
</tr></table>";
}

return &html_page( '', $html . "</body></html>" );
