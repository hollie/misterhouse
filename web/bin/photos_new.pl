# $Date$
# $Revision$

=begin comment

This file is called directly from the browser with:

  http://localhost:8080/bin/photos_new.pl

More info on creating the photo list can be found in mh/code/common/photo_index.pl

See mh/bin/mh.ini for the various photo_* parms

Example mh.ini parms:
  html_alias_photos     = $Pgm_Root/../photos
  photo_dirs   = /photos
  photo_index  = /misterhouse/data/photo_index.txt

=cut

use vars '@photos';    # This will be persistent across passes and code reloads
@photos = file_read $config_parms{photo_index} unless @photos;

# Set up defaults
my $time = $config_parms{photo_time};
$time = 60 unless defined $time;
$config_parms{photo_url} = '/ia5' unless $config_parms{photo_url};
my $images = "";
foreach (@photos) {
    my $file = $_;
    my $img  = $file;
    my @dirs = split( /,/, $config_parms{photo_dirs} );
    $file =~ s/ /%20/g;
    $file =~ s/\#/%23/g;
    $file =~ s/\'/%27/g;
    foreach (@dirs) {
        $img =~ s/$_//;
    }
    $img =~ m/(\/)?(.+)\.(\S+)/;
    $img = $2;
    $images .= <<eof;
<div class="imageElement">
	<h3>$img</h3>
	<p></p>
        <a href="$file" title="open image" class="open"></a>
        <img src="$file" class="full" />
        <img src="$file" class="thumbnail" />
</div>
eof
}

my $html = <<eof;
HTTP/1.0 200 OK
Server: MisterHouse
Content-type: text/html

<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Strict//EN" "http://www.w3.org/TR/xhtml1/DTD/xhtml1-strict.dtd">
<html>
	<head>
		<meta http-equiv="Content-Type" content="text/html; charset=iso-8859-1" />
		<title>Misterhouse image viewer</title>
		<link rel="stylesheet" href="/SmoothGallery/css/layout.css" type="text/css" media="screen" charset="utf-8" />
		<link rel="stylesheet" href="/SmoothGallery/css/jd.gallery.css" type="text/css" media="screen" charset="utf-8" />
		<script src="/SmoothGallery/scripts/mootools.v1.11.js" type="text/javascript"></script>
		<script src="/SmoothGallery/scripts/jd.gallery.js" type="text/javascript"></script>
	</head>
	<body>
		<div align="center"><h3><a href="$config_parms{'photo_url'}" target="_top" style="color:#FFFFFF; text-decoration: none;">Mister<span class="company">house</span></a> image viewer</h3></div>
		<script type="text/javascript">
			function startGallery() {
				var myGallery = new gallery(\$('myGallery'), {
					timed: true,
					delay: ${time}000,
					textShowCarousel: 'All Images'
				});
			}
			window.addEvent('domready',startGallery);
		</script>
		<div class="content">
			<div id="myGallery">
			$images
			</div>
		</div>
	</body>
</html>
eof
return $html;
