
$^W = 0;                        # Avoid redefined sub msgs

# Create jpeg buttons on-the-fly with GD module
# For text buttons:  <img src="/bin/button.pl?text you want" border="0">
# For item buttons:  <img src="/bin/button.pl?item_name&item&item_state" border="0">

# Authority: anyone

my ($text, $type, $bg_color) = @ARGV;

#print "db v6 t=$text  s=$type bg=$bg_color\n";

#my ($state, $x, $y) = $state_xy =~ /(\S+)\?(\d+),(\d+)/;

$bg_color = 'white' unless $bg_color;

unless ($Info{module_GD}) {
    return;
}

my $image_file = $text;
$image_file =~ s/^\$//;           # Drop leading $ on object name
$image_file =~ s/ *$//;           # Drop trailing blanks
$image_file =~ s/ /_/g;           # Blanks in file names are nasty
$image_file = "/cache/$image_file.jpg";


my $nocache = 0;
#$nocache = 1;
##if (-e "$config_parms{data_dir}$image_file" or $nocache) {
##    return $image_file if $file_name_only;
##   print "Returning data from: $image_file\n";
##    my $data = file_read "$config_parms{data_dir}$image_file";
##    return &mime_header($image_file, 1, length $data) . $data;
##}

                                # Look for an icon
my ($icon, $light);

    my $object = &get_object_by_name($text);
#    ($icon) = &http_get_local_file(&html_find_icon_image($object, 'voice'));
#   $light = 1 if $text =~ /light/i or $text =~ /lite/i;
#    $light = 1 if $object->isa('X10_Item') and !$object->isa('X10_Appliance');

my $graphic_dir = "./../web/graphics";
$graphic_dir = $config_parms{html_alias_graphics} if defined $config_parms{html_alias_graphics};

if ($type eq 'door') {
#	$icon = './../web/graphics/icon_door.jpg';
	$icon = $graphic_dir . '/icon_door.jpg';
	}
elsif ($type eq 'motion') {
	$icon = $graphic_dir . '/icon_motion.jpg';
	}
elsif ($type eq 'brightness') {
	$icon = $graphic_dir . '/icon_motion.jpg';
	}
elsif ($type eq 'water') {
	$icon = $graphic_dir . '/icon_water.jpg';
	}


#my $tmp1 = &html_find_icon_image($object,'voice');
my $state = $object->state;

undef $icon if $icon and $icon !~ /.jpg$/i;  # GD does not do gifs :(

die "Cannot find source graphic file!" unless (-f $icon);

print "graphic file = $icon\n";

my $image_icon = GD::Image->newFromJpeg($icon) if $icon;

my $image;

    # Template = blank_on/off/unk or blank_light_on/off/dim
    my $template  = 'blank_sens';
    $template .= "_$bg_color" if $bg_color and $bg_color ne 'white';

    # GD in 5.8 gives gray for white jpg??  Allow for png, which is still gray :(
    my $file = "$config_parms{html_dir}/graphics/$template.png";
    $file  = "$config_parms{html_alias_graphics}/$template.png" if defined $config_parms{html_alias_graphics}; 

    if (-f $file) {
        $image = GD::Image->newFromPng($file);
    }
    else {
        $file  = "$config_parms{html_dir}/graphics/$template.jpg";
	$file  = "$config_parms{html_alias_graphics}/$template.jpg" if defined $config_parms{html_alias_graphics}; 
	die "Cannot find source template file!" unless (-f $file);
        $image = GD::Image->newFromJpeg($file);
    }

    if ($image_icon and $template !~ /_light/) {
        my ($iw, $ih) = $image_icon->getBounds();
        $image->copyResized($image_icon, 7, 6, 0, 0, 40, 40, $iw, $ih);
    }

    my $color;

  # Filter out starting keyword Sensor
    my $filter = &pretty_object_name($text);
       $filter =~ s/^sensor//i;

    my @lines = split ' ', $filter, 3;

  # Combine lines if they are short enough
    if (length $lines[0] . $lines[1] < 12) {
        $lines[0] .= " $lines[1]";
        $lines[1]  = $lines[2];
        $lines[2]  = '';
    }
    if (length $lines[1] . $lines[2] < 12) {
        $lines[1] .= " $lines[2]";
        $lines[2]  = '';
    }

                 # gdGiantFont, gdLargeFont, gdMediumBoldFont, gdSmallFont and gdTinyFont
    my ($font, $x);
        $x = 50;
        $font = gdMediumBoldFont;
#       $font = gdTinyFont;
#       $font = gdSmallFont;

    $image->string($font, $x ,   6, ucfirst $lines[0], $color);
    $image->string($font, $x ,  18, ucfirst $lines[1], $color) if $lines[1];
    $image->string($font, $x ,  30, ucfirst $lines[2], $color) if $lines[2];

my $sname;
    if ($type eq 'door') {
       $x += 45;
	if (($state eq 'on') or ($state eq 'open')) {
		$sname = "Open";
		$color = $image->colorClosest(255,0,0);
		}
	else {
		$sname = "Closed";
		$color = $image->colorClosest(0,0,0);
		}
        $image->string($font, $x ,  30, ucfirst $sname, $color);
}
    elsif ($type eq 'motion') {
        $x += 45;
	if ($state eq 'motion') {
		$color = $image->colorClosest(255,0,0);
		}
	else {
		$color = $image->colorClosest(0,0,0);
		}
        $image->string($font, $x ,  30, ucfirst $state, $color);
}
    elsif ($type eq 'brightness') {
        $x += 45;
	if ($state eq 'light') {
		$color = $image->colorClosest(255,0,0);
		}
	else {
		$color = $image->colorClosest(0,0,0);
		}
        $image->string($font, $x ,  30, ucfirst $state, $color);
}

    elsif ($type eq 'water') {
        $x += 65;
	if ($state eq 'on') {
		$sname = "Wet";
		$color = $image->colorClosest(255,0,0);
		}
	else {
		$sname = "Dry";
		$color = $image->colorClosest(0,0,0);
		}
        $image->string($font, $x,  30, ucfirst $sname, $color);
}


                                # make the background transparent
my $white = $image->colorClosest(255,255,255);
$image->transparent($white);

                                # Write out a copy to the cache
print "Writing image to cache: $config_parms{data_dir}$image_file\n";
my $jpeg = $image->jpeg;
file_write "$config_parms{data_dir}$image_file", $jpeg;

return &mime_header($image_file, 1, length $jpeg) . $jpeg;
