# $Date$
# $Revision$

# Authority: anyone

=begin comment

	Useful for generating thumbnails for Slideshows

	Todo: Add caching so that thumbnails arn't generated everytime a page is loaded.

	Requires GD and Image::Resize
=cut


use Image::Resize;
my $url;
foreach my $argnum (0 .. $#ARGV) {
   $url .= "$ARGV[$argnum] ";
}
unless ($url =~ m/^\//){
	$url = "/".$url;
}
chop($url);
$url = $config_parms{html_alias_photos} .$url;
my $image = Image::Resize->new($url);
my $gd = $image->resize(50, 50);
return $gd->jpeg();
