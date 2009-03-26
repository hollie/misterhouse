# $Date$
# $Revision$

# Authority: anyone

=begin comment

This file is called from /slideshow/ with:

  http://localhost:8080/bin/photos_slideshow.pl

and is responsible for generating the javascript needed to show the photo album.

More info on creating the photo list can be found in mh/code/common/photo_index.pl

See mh/bin/mh.ini for the various photo_* parms

Example mh.ini parms:
  html_alias_photos     = $Pgm_Root/../photos
  photo_dirs   = /photos
  photo_index  = /misterhouse/data/photo_index.txt
  photo_effect = push

Acceptable effects are kenburns, push, fold, flash and none.
=cut

use vars '@photos';             # This will be persistent across passes and code reloads
@photos = file_read $config_parms{photo_index} unless @photos;

# Set up defaults
my $time = $config_parms{photo_time};
$time = 60 unless defined $time;
my $effect = $config_parms{photo_effect};
$effect = "none" unless defined $effect;
my $images = "";
foreach (@photos){
	my $file = $_;
	my $img = $file;
	my @dirs = split(/,/, $config_parms{photo_dirs});
	$file     =~  s/ /%20/g;
	$file     =~  s/\#/%23/g;
	$file     =~  s/\'/%27/g;
	$file	  =~  s/\/photos//g;
	foreach (@dirs){
		$img =~ s/$_//;
	}
	$img =~ m/(\/)?(.+)\.(\S+)/;
	$img = $2;
	$images .= <<eof;
	'$file': { caption: '$img' },
eof
}

$images =~ s/\},$/}/;

my $sseffect="var myShow = new Slideshow";
if ($effect eq 'flash'){
	$sseffect.=".Flash";
} elsif ($effect eq 'fold'){
	$sseffect.=".Fold";
} elsif ($effect eq 'push'){
	$sseffect.=".Push";
} elsif ($effect eq 'kenburns') {
	$sseffect.=".KenBurns";
} 
$sseffect.="('show', data, { captions: true, controller: true, delay: ${time}000, duration: 1000, height: 480, hu: '$config_parms{photo_big_dirs}', thumbnails: true, width: 640 });";

my $js = <<eof;
HTTP/1.0 200 OK
Server: MisterHouse
Content-type: application/x-javascript

window.addEvent('domready', function(){
    var data = {
$images
    };
    $sseffect
});

eof
return $js;
