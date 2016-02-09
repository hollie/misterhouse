#
# Create buttons with JPEG images generated on-the-fly using the GD module.
#
# For text buttons:  <img src="/bin/button.pl?<text you want>" border="0">
#     Example: <img src="/bin/button.pl?Close%20Garage%20Door" border="0">
#
# For item buttons:  <img src="/bin/button.pl?<item_name>&item&<item_state>" border="0">
#     Example: <img src="/bin/button.pl?$breakfast_nook_light&item&off" border="0">
#

$^W = 0;    # Avoid redefined sub msgs

# Authority: anyone

my ( $text, $type, $state, $bg_color, $file_name_only ) = @ARGV;

#print "db t=$text t=$type s=$state bg=$bg_color\n";

#my ($state, $x, $y) = $state_xy =~ /(\S+)\?(\d+),(\d+)/;

$state    = ''      unless $state;
$type     = ''      unless $type;
$bg_color = 'white' unless $bg_color;

unless ( $Info{module_GD} ) {
    return;
}

my $image_file = $text;
$image_file =~ s/^\$//;    # Drop leading $ on object name
$image_file =~ s/ *$//;    # Drop trailing blanks
$image_file .= "_$type"  if $type;
$image_file .= "_$state" if $state;
$image_file =~ s/ /_/g;    # Blanks in file names are nasty
$image_file = "/$image_file.jpg";

# Set to 1 if you'd like to disable the image cache. Normally you should
# not need to do this because it affects performance (MisterHouse needs
# to re-generate the button image every time). This is only useful if you
# are tweaking your button images and need new images re-generated every
# time the button generation script (this script) is called.
my $nocache = 0;

if ( -e "$config_parms{html_alias_cache}$image_file" && !$nocache ) {
    return "/cache" . $image_file if $file_name_only;

    #   print "Returning data from: $image_file\n";
    my $data = file_read "$config_parms{html_alias_cache}$image_file";
    return &mime_header( "/cache" . $image_file, 1, length $data ) . $data;
}

# Look for an icon
my ( $icon, $light );

if ( $type eq 'item' ) {
    my $object = &get_object_by_name($text);
    ($icon) = &http_get_local_file( &html_find_icon_image( $object, 'voice' ) );

    if (   ( $object->isa('X10_Item') and !$object->isa('X10_Appliance') )
        || $object->isa('Insteon::BaseLight')
        || $object->isa('EIB2_Item')
        || $text =~ /light|lite/i )
    {
        $light = 1;
    }
}
else {
    # Uncomment this to put in images into group, category icons.  Seem too small to be useful.
    #($icon) = &http_get_local_file(&html_find_icon_image($text, 'text'));
}

undef $icon if $icon and $icon !~ /.jpg$/i;    # GD does not do gifs :(
my $image_icon = GD::Image->newFromJpeg($icon) if $icon;

my $image;

if ( $image_icon or $type eq 'item' ) {

    # Template = blank_on/off/unk or blank_light_on/off/dim
    my $template = 'blank';
    $template .= '_light' if $light;
    if ( $state eq 'on' or $state eq 'off' ) {
        $template .= "_$state";
    }
    else {
        $template .= ($light) ? '_dim' : '';
    }
    $template = 'blank_textbutton' unless $type;
    $template .= "_$bg_color" if $bg_color and $bg_color ne 'white';

    # GD in 5.8 gives gray for white jpg??  Allow for png, which is still gray :(
    my $file = "$config_parms{html_dir}/graphics/$template.png";
    if ( -f $file ) {
        $image = GD::Image->newFromPng($file);
    }
    else {
        $file  = "$config_parms{html_dir}/graphics/$template.jpg";
        $image = GD::Image->newFromJpeg($file);
    }

    if ( $image_icon and $template !~ /_light/ ) {
        my ( $iw, $ih ) = $image_icon->getBounds();
        if ( $type eq 'item' ) {
            $image->copyResized( $image_icon, 7, 6, 0, 0, 40, 40, $iw, $ih );
        }
        else {
            $image->copyResized( $image_icon, 6, 7, 0, 0, 30, 30, $iw, $ih );
        }
    }

    my $color;
    if ( $state eq 'off' ) {
        $color = $image->colorClosest( 0, 0, 0 );
    }
    elsif ( $state eq 'on' ) {
        $color = $image->colorClosest( 255, 0, 0 );
    }
    else {
        $color = $image->colorClosest( 0, 0, 0 );

        #       $color = $image->colorClosest(30,30,30);
    }

    my @lines = split ' ', &pretty_object_name($text), 3;

    # Combine lines if they are short enough
    if ( length $lines[0] . $lines[1] < 12 ) {
        $lines[0] .= " $lines[1]";
        $lines[1] = $lines[2];
        $lines[2] = '';
    }
    if ( length $lines[1] . $lines[2] < 12 ) {
        $lines[1] .= " $lines[2]";
        $lines[2] = '';
    }

    # gdGiantFont, gdLargeFont, gdMediumBoldFont, gdSmallFont and gdTinyFont
    my ( $font, $x );
    if ($type) {
        $font = gdMediumBoldFont;
        $x    = 55;
    }
    else {
        $font = gdMediumBoldFont;

        #       $font = gdTinyFont;
        #       $font = gdSmallFont;
        $x = 35;
    }
    $image->string( $font, $x, 6,  ucfirst $lines[0], $color );
    $image->string( $font, $x, 18, ucfirst $lines[1], $color ) if $lines[1];
    $image->string( $font, $x, 30, ucfirst $lines[2], $color ) if $lines[2];

    unless ( $state eq 'on' or $state eq 'off' or $light ) {
        $x += 5;
        $color = $image->colorClosest( 255, 0, 0 );

        #       $color = $image->colorAllocate(0,0,0);
        $image->string( $font, $x, 30, '-> ' . ucfirst $state, $color );
    }

}
else {
    my $template = 'blank_textbutton';
    $template .= "_$bg_color" if $bg_color and $bg_color ne 'white';

    # GD in 5.8 gives gray for white jpg??  Allow for png
    my $file = "$config_parms{html_dir}/graphics/$template.png";
    if ( -f $file ) {
        $image = GD::Image->newFromPng($file);
    }
    else {
        $file  = "$config_parms{html_dir}/graphics/$template.jpg";
        $image = GD::Image->newFromJpeg($file);
    }

    # calculate size of image and text for offset

    my $textsize = length $text;
    my $font     = gdMediumBoldFont
      ;    # Choices: gdTinyFont, gdLargeFont, gdSmallFont, gdMediumBoldFont
    $font = gdTinyFont if $textsize > 14;

    my ( $imwidth, $imheight ) = $image->getBounds();
    my $ftwidth = ( $font->width );
    my $offset  = $imwidth - ( $ftwidth * $textsize );
    my $black   = $image->colorClosest( 50, 50, 50 );
    $image->string( $font, $offset / 2 - 3, 12, $text, $black );
}

# make the background transparent
my $white = $image->colorClosest( 255, 255, 255 );
$image->transparent($white);

# Write out a copy to the cache
print "Writing image to cache: $config_parms{html_alias_cache}$image_file\n";
my $jpeg = $image->jpeg;
file_write "$config_parms{html_alias_cache}$image_file", $jpeg;

return "/cache" . $image_file if $file_name_only;
return &mime_header( "/cache" . $image_file, 1, length $jpeg ) . $jpeg;
