# $Date: 2009-03-28 17:03:58 +1300 (Sat, 28 Mar 2009) $
# $Revision: 1644 $

# Authority: anyone

=begin comment

This file is called from /slideshow/ with:

  http://localhost:8080/bin/photos_slideshow_css.pl

and is responsible for generating the css needed to show the photo album with correct picture frames.

More info on creating the photo list can be found in mh/code/common/photo_index.pl
Example mh.ini parms:
  photo_size = 1024x768

=cut

$config_parms{photo_size} =~ m/(\d+)[x|X](\d+)/;
my $width  = $1 . "px";
my $height = $2 . "px";

my $css = <<eof;
HTTP/1.0 200 OK
Server: MisterHouse
Content-type: text/css

#show {
	z-index: 5;
	border: 1px solid #000;
	width: $width;
	height: $height;
}

.slideshow-images {
	height: $height;
	width: $width;
}

/* Overriding the default Slideshow thumbnails for the vertical presentation */ 
.slideshow-thumbnails {
	height: 100%;
	left: auto;
	right: -80px;
	top: 0;
	width: 70px;
}
.slideshow-thumbnails ul {
	height: 100%;
	width: 70px;
}
eof
return $css;
