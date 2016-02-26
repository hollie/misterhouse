# Authority: anyone

# Author: Gaetan Lord  <email@gaetanlord.ca>
#$Id$
# Create buttons on-the-fly with GD module
# use blank image template, add icon and text
#
# This script has been created to complement web interface created by Ron Klinkien
# The main reason, is to provide user with an easy to use button creation interface
# My personal use, is to keep the same look and feel, but get icon written in french
# The script is embedded in html page, like the script button.pl
#
# HTML SYNTAX: <img src="/bin/button2.pl?text_you_want&icon.png" border="0">
# so, everywhere in html page, where you have the following syntax
# <img src="images/localweather.gif" alt='Local Weather' border=0>
# This could be replaced by
# <img src="/bin/button2.pl?meteo_locale&meteo.png" alt='Local Weather' border="0">
# this will create a 2 lines button, with meteo.png icon
#
# A maximum of 3 lines is permitted
# A new line is created by an underscore character "_"
#
# The script is expecting to find template and icon in the icons_dir defined in mh.ini
# Note: many directory could be appened by seperating them with ":"
# You will get better result if the icon are in PNG format to keep color accuracy
# but output button could be in jpeg
# Icon type could be JPEG PNG , sorry no GIF, it's unsupported by GD
#
# configuration in mh.private.ini
# template    point to a pattern image, all button will have the same look and feel
#             if none are provided, then a default one will be created (110x44 square)
#             all directory define by icons_dir will be search
# text_color  color of text written in then button
#             represent RGB value from 0-255 for each color
# min_x
# min_y       writable position x,y (upper left) inside the template area
# max_x
# max_y       writable position x,y (lower right) inside the template area
# button_type Define the output type of button, png or jpeg
# ttf         Full pathname of a TrueType font
#             libGD need to be compiled with truetype
# ttf_ptsize  define the pointsize of the ttf fonts
#icons_dir            = $config_parms{icons_dir}:/home/gaetan/web/icons
#button_template      = $config_parms{icons_dir}/blank_textbutton.png
#button_text_color    = 50,50,50
#button_min_x         = 4
#button_max_x         = 101
#button_min_y         = 2
#button_max_y         = 35
#button_button_type   = jpeg    # possible choice are png, jpeg
#button_ttf           = $config_parms{fonts_dir}/arialbd.ttf
#button_ttf_ptsize    = 8.0

unless ( $Info{module_GD} ) {
    return;    # This does not help ... will still get error in eval.
}

$^W = 0;       # Avoid redefined sub msgs
my $ScriptName       = "button2";
my $GenericTemplateX = 110;
my $GenericTemplateY = 44;
my $ButtonOK         = 1;

print "\n\n$ScriptName: Entering with [@ARGV]\n" if $Debug{$ScriptName};

my ( $Text, $IconName ) = @ARGV;
$Text = 'No_Text' unless $Text;    # To avoid errors
print "$ScriptName: Argument receive Text=$Text IconName=$IconName\n"
  if $Debug{$ScriptName};

# validating icon
my ( $Icon, $Name, $Type ) = ValidIcon($IconName);
print "$ScriptName: Icon info IconName=$Name type=$Type\n"
  if $Debug{$ScriptName};

my $ButtonType = $config_parms{button_button_type} || "png";

# defining cache file name
my $ImageFile = $Text . "_" . $Name;
$ImageFile =~ s/^\$//;    # Drop leading blank on object name
$ImageFile =~ s/ *$//;    # Drop trailing blanks
$ImageFile =~ s/ /_/g;    # Blanks in file names are nasty
$ImageFile = "/$ImageFile.$ButtonType";

print "$ScriptName: Cache file should be $config_parms{data_dir}/$ImageFile\n"
  if $Debug{$ScriptName};

# We hit the cache, so we give back the image and exit
if ( -f "$config_parms{html_alias_cache}/$ImageFile" ) {
    print
      "$ScriptName: Hit cached file $config_parms{html_alias_cache}/$ImageFile\n"
      if $Debug{$ScriptName};
    my $data = file_read("$config_parms{html_alias_cache}$ImageFile");
    return &mime_header( "/cache" . $ImageFile, 1, length $data ) . $data;
}
print "$ScriptName: Cache file not found\n" if $Debug{$ScriptName};

# determine transparent value
#my ( $TransparentR, $TransparentG, $TransparentB ) = GetTransparent();
#print "$ScriptName: Transparent value [$TransparentR,$TransparentG,$TransparentB]\n" if $Debug{$ScriptName};

# validating template
my $Template = $config_parms{button_template} || "NOTEMPLATE";
print "$ScriptName: Using template [$Template]\n" if $Debug{$ScriptName};

# open template file
my $GDTemplate = OpenImage( $Template, "TEMPLATE" );
print "$ScriptName: [$GDTemplate] receive from OpenImage for template\n"
  if $Debug{$ScriptName};

# open icon file
my $GDIcon = OpenImage( $Icon, "ICON" );
print "$ScriptName: [$GDIcon] receive from OpenImage for icon\n"
  if $Debug{$ScriptName};

# no cache file found, we create a new image and cache it
if ($GDTemplate) {

    my $UseTTF = 0;
    my $PTSize;
    my $FontUse;

    # define the width of the icon
    my ( $Twidth, $THeight ) = $GDTemplate->getBounds();

    my $WorkAreaMinX = $config_parms{button_min_x} || 3;
    my $WorkAreaMinY = $config_parms{button_min_y} || 3;
    print
      "$ScriptName: WorkAreaMinX=$WorkAreaMinX  WorkAreaMinY=$WorkAreaMinY\n"
      if $Debug{$ScriptName};

    my $WorkAreaMaxX = $config_parms{button_max_x} || $Twidth - 3;
    my $WorkAreaMaxY = $config_parms{button_max_y} || $THeight - 3;
    print
      "$ScriptName: WorkAreaMaxX=$WorkAreaMaxX  WorkAreaMaxY=$WorkAreaMaxY\n"
      if $Debug{$ScriptName};

    # copy icon over template, try to center in height
    my ( $IWidth, $IHeight ) = $GDIcon->getBounds();
    my $IconY =
      ( $WorkAreaMaxY - $WorkAreaMinY ) / 2 + $WorkAreaMinY - ( $IHeight / 2 );
    $GDTemplate->copy( $GDIcon, $WorkAreaMinX, $IconY, 0, 0, $IWidth,
        $IHeight );
    print "$ScriptName: Icon upper left [ $WorkAreaMinX, $IconY] \n"
      if $Debug{$ScriptName};

    my ( $TextR, $TextG, $TextB ) = GetTextColor();
    my $TextColor = $GDTemplate->colorClosest( $TextR, $TextG, $TextB );

    my $PosTextX = $WorkAreaMinX + $IWidth;

    # determine how many pixels available for text
    my $MaxTextPixelX = $WorkAreaMaxX - ( $IWidth + $WorkAreaMinX );
    my $MaxTextPixelY = $WorkAreaMaxY - $WorkAreaMinY;
    print
      "$ScriptName: Maximum Text pixels available X=$MaxTextPixelX Y=$MaxTextPixelY\n"
      if $Debug{$ScriptName};

    my @lines = split( '_', $Text );
    my $NumLines = $Text =~ tr/_/_/;
    $NumLines++;
    print "$ScriptName: $NumLines line of text [$Text]\n"
      if $Debug{$ScriptName};
    my $MaxChar = 0;
    my $Pos     = 0;
    while ( $Pos < scalar(@lines) ) {
        $MaxChar = (
              $MaxChar < length( $lines[$Pos] )
            ? $MaxChar = length( $lines[$Pos] )
            : $MaxChar
        );
        $lines[$Pos] = ucfirst( $lines[$Pos] );
        $Pos++;
    }
    print "$ScriptName: Maximum character per line $MaxChar\n"
      if $Debug{$ScriptName};
    my $CharPixelWidth = int( $MaxTextPixelX / $MaxChar );

    # validate ttf fonts
    if ( -f $config_parms{button_ttf} ) {
        $PTSize = $config_parms{button_ttf_ptsize} || 8.0;
        my @Bounds = GD::Image->stringTTF( "0,0,0", $config_parms{button_ttf},
            $PTSize, 0.0, 0, 0, "Nothing" );
        if ( scalar @Bounds == 0 ) {
            print "$ScriptName: Invalid TTF fonts $FontUse\n";
            print
              "$ScriptName:         maybe GD not configured for TTF, or invalid file\n";
            $ButtonOK = 0;
        }
        else {
            $UseTTF = 1;
        }
    }

    #$UseTTF=0;
    if ($UseTTF) {
        my @Bounds;
        my ( $x, $y, $nexty );
        $FontUse = $config_parms{button_ttf};
        $PTSize = $config_parms{button_ttf_ptsize} || 8.0;

        my $AllChar = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz";
        @Bounds =
          GD::Image->stringTTF( $TextColor, $FontUse, $PTSize, 0.0, 0, 0,
            $AllChar );
        my $FontHeight = $Bounds[7] - $Bounds[1];
        print
          "$ScriptName: text will be written with font $FontUse and PTSize $PTSize\n"
          if $Debug{$ScriptName};
        print "$ScriptName: Font height $FontHeight pixels\n"
          if $Debug{$ScriptName};

        # we need to find the maximum height of the fonts
        if ( $NumLines == 1 ) {

            #determine text position
            @Bounds =
              GD::Image->stringTTF( $TextColor, $FontUse, $PTSize, 0.0, 0, 0,
                $lines[0] );
            print "$ScriptName:        Bounds for line \"$lines[0]\" @Bounds\n"
              if $Debug{$ScriptName};
            $x = $WorkAreaMaxX - ( $Bounds[2] + 2 - $Bounds[0] );
            $y = $WorkAreaMaxY - 2;
            @Bounds =
              $GDTemplate->stringTTF( $TextColor, $FontUse, $PTSize, 0, $x, $y,
                $lines[0] );
            print "$ScriptName: Text location for line \"$lines[0]\" [$x,$y]\n"
              if $Debug{$ScriptName};
        }
        elsif ( $NumLines == 2 ) {
            @Bounds =
              GD::Image->stringTTF( $TextColor, $FontUse, $PTSize, 0.0, 0, 0,
                $lines[1] );
            print "$ScriptName:        Bounds for line \"$lines[1]\" @Bounds\n"
              if $Debug{$ScriptName};
            $x = $WorkAreaMaxX - ( $Bounds[2] + 2 - $Bounds[1] );
            $y = $WorkAreaMaxY - 2;
            my $nexty = $y + $Bounds[7] - 2;
            @Bounds =
              $GDTemplate->stringTTF( $TextColor, $FontUse, $PTSize, 0, $x, $y,
                $lines[1] );
            print "$ScriptName: Text location for line \"$lines[1]\" [$x,$y]\n"
              if $Debug{$ScriptName};

            @Bounds =
              GD::Image->stringTTF( $TextColor, $FontUse, $PTSize, 0.0, 0, 0,
                $lines[0] );
            print "$ScriptName:        Bounds for line \"$lines[0]\" @Bounds\n"
              if $Debug{$ScriptName};
            $x = $WorkAreaMaxX - ( $Bounds[2] + 2 - $Bounds[0] );
            $y = $nexty;
            @Bounds =
              $GDTemplate->stringTTF( $TextColor, $FontUse, $PTSize, 0, $x, $y,
                $lines[0] );
            print "$ScriptName: Text location for line \"$lines[0]\" [$x,$y]\n"
              if $Debug{$ScriptName};
        }
        else {
            @Bounds =
              GD::Image->stringTTF( $TextColor, $FontUse, $PTSize, 0.0, 0, 0,
                $lines[2] );
            print "$ScriptName:        Bounds for line \"$lines[2]\" @Bounds\n"
              if $Debug{$ScriptName};
            $x     = $WorkAreaMaxX - ( $Bounds[2] + 2 - $Bounds[0] );
            $y     = $WorkAreaMaxY - 2;
            $nexty = $y + ( $Bounds[7] ) - 2;
            @Bounds =
              $GDTemplate->stringTTF( $TextColor, $FontUse, $PTSize, 0, $x, $y,
                $lines[2] );
            print "$ScriptName: Text location for line \"$lines[2]\" [$x,$y]\n"
              if $Debug{$ScriptName};

            @Bounds =
              GD::Image->stringTTF( $TextColor, $FontUse, $PTSize, 0.0, 0, 0,
                $lines[1] );
            print "$ScriptName:        Bounds for line \"$lines[1]\" @Bounds\n"
              if $Debug{$ScriptName};
            $x     = $WorkAreaMaxX - ( $Bounds[2] + 2 - $Bounds[0] );
            $y     = $nexty;
            $nexty = $y + $Bounds[7] - 2;
            @Bounds =
              $GDTemplate->stringTTF( $TextColor, $FontUse, $PTSize, 0, $x, $y,
                $lines[1] );
            print "$ScriptName: Text location for line \"$lines[1]\" [$x,$y]\n"
              if $Debug{$ScriptName};

            @Bounds =
              GD::Image->stringTTF( $TextColor, $FontUse, $PTSize, 0.0, 0, 0,
                $lines[0] );
            print "$ScriptName:        Bounds for line \"$lines[0]\" @Bounds\n"
              if $Debug{$ScriptName};
            $x = $WorkAreaMaxX - ( $Bounds[2] + 2 - $Bounds[0] );
            $y = $nexty;
            @Bounds =
              $GDTemplate->stringTTF( $TextColor, $FontUse, $PTSize, 0, $x, $y,
                $lines[0] );
            print "$ScriptName: Text location for line \"$lines[0]\" [$x,$y]\n"
              if $Debug{$ScriptName};
        }

    }
    else {

        if ( $config_parms{button_ttf} ) {
            print(
                "$ScriptName: Invalid ttf font $config_parms{button_ttf}, use default GD font\n"
            );
            $ButtonOK = 0;
        }

        # all default font available
        # gdGiantFont, "GiantFont 9x15"
        # gdLargeFont, "LargeFont 8x16"
        # gdMediumBoldFont, "gdMediumBoldFont 7x13b"
        # gdSmallFont, "gdSmallFont 6x13"
        # gdTinyFont, "gdTinyFont 5x8"

        # we now calculate the optimal maximum width/char
        my $FontUse  = gdTinyFont;
        my $FontName = "gdTinyFont";
        if ( gdSmallFont->width <= $CharPixelWidth ) {
            $FontUse  = gdSmallFont;
            $FontName = "gdSmallFont";
        }
        my $FontWidth  = $FontUse->width;
        my $FontHeight = $FontUse->height - 2;

        print "$ScriptName: Text will be written with font $FontName\n"
          if $Debug{$ScriptName};
        print "$ScriptName: Font width=$FontWidth height=$FontHeight\n"
          if $Debug{$ScriptName};

        if ( $NumLines == 1 ) {
            my $x = $WorkAreaMaxX - ( length( $lines[0] ) * $FontWidth );
            my $y = $WorkAreaMaxY - $FontHeight - 1;
            $GDTemplate->string( $FontUse, $x, $y, ucfirst $lines[0],
                $TextColor );
            print "$ScriptName: Text location for line \"$lines[0]\" [$x,$y]\n"
              if $Debug{$ScriptName};
        }
        elsif ( $NumLines == 2 ) {
            my $x = $WorkAreaMaxX - ( length( $lines[1] ) * $FontWidth );
            my $y = $WorkAreaMaxY - $FontHeight - 1;
            $GDTemplate->string( $FontUse, $x, $y, ucfirst $lines[1],
                $TextColor );
            print "$ScriptName: Text location for line \"$lines[1]\" [$x,$y]\n"
              if $Debug{$ScriptName};

            $x = $WorkAreaMaxX - ( length( $lines[0] ) * $FontWidth );
            $y -= $FontHeight;
            $GDTemplate->string( $FontUse, $x, $y, ucfirst $lines[0],
                $TextColor );
            print "$ScriptName: Text location for line \"$lines[0]\" [$x,$y]\n"
              if $Debug{$ScriptName};
        }
        else {
            my $x = $WorkAreaMaxX - ( length( $lines[2] ) * $FontWidth );
            my $y = $WorkAreaMaxY - $FontHeight - 1;
            $GDTemplate->string( $FontUse, $x, $y, ucfirst $lines[2],
                $TextColor );
            print "$ScriptName: Text location for line \"$lines[2]\" [$x,$y]\n"
              if $Debug{$ScriptName};

            $x = $WorkAreaMaxX - ( length( $lines[1] ) * $FontWidth );
            $y -= $FontHeight;
            $GDTemplate->string( $FontUse, $x, $y, ucfirst $lines[1],
                $TextColor );
            print "$ScriptName: Text location for line \"$lines[1]\" [$x,$y]\n"
              if $Debug{$ScriptName};

            $x = $WorkAreaMaxX - ( length( $lines[0] ) * $FontWidth );
            $y -= $FontHeight;
            $GDTemplate->string( $FontUse, $x, $y, ucfirst $lines[0],
                $TextColor );
            print "$ScriptName: Text location for line \"$lines[0]\" [$x,$y]\n"
              if $Debug{$ScriptName};
        }
    }

    # Write out a copy to the cache

    if ( index( "JPG JPEG PNG XBM WMP XPM", uc($ButtonType) ) < 0 ) {
        print "$ScriptName: Invalid format type, can't produce $ImageFile\n";
        return;
    }
    my $ButtonFile = $GDTemplate->$ButtonType();
    if ($ButtonOK) {
        print
          "$ScriptName: Writing button to cache: $config_parms{html_alias_cache}/$ImageFile\n"
          if $Debug{$ScriptName};
        file_write( "$config_parms{html_alias_cache}/$ImageFile", $ButtonFile );
    }
    else {
        print
          "$ScriptName: Button $config_parms{html_alias_cache}/$ImageFile not written to cache\n";
    }

    return &mime_header( "/cache" . $ImageFile, 1, length $ButtonFile )
      . $ButtonFile;
}
else {
    print "$ScriptName: Error generating image\n";
    return;
}

1;

sub ValidIcon {

    print "$ScriptName: ValidIcon: with ARG received [@_]\n"
      if $Debug{$ScriptName};
    my $IconName = shift;
    print "$ScriptName: ValidIcon: icon Name [$IconName]\n"
      if $Debug{$ScriptName};

    # name could have 1 dot, to define type (icon.png)
    my $DotCount = $IconName =~ tr/././;
    if ( $DotCount > 1 ) {
        print
          "ValidIcon: Invalid icon name $IconName, no more than 1 dot (.) allow in name, using EmptyIcon.png\n";
        return ( "NOICON", "NOICON", "" );
    }

    # split name and type
    my ( $Name, $Type ) = split /\./, $IconName;
    print "$ScriptName: ValidIcon: Split icon name Name=[$Name]  Type=[$Type]\n"
      if $Debug{$ScriptName};

    if ( "$Type" eq "" ) {
        $Type = "png";
    }

    # is it a valid GD type
    if ( index( "JPG JPEG PNG XBM WMP XPM", uc($Type) ) < 0 ) {
        print
          "$ScriptName: ValidIcon: Invalid icon type [$Type], only JPG JPEG PNG XBM WMP XPM allowed\n";
        return ( "NOICON", "NOICON", "" );
    }

    my @dir = ( split /:/, $config_parms{icons_dir} );
    foreach (@dir) {
        if ( -f "$_/$IconName" ) {    # filename exist valid and greater than 0
            return ( "$_/$IconName", $Name, $Type );
        }
        elsif ( -f "$_/$Name" . ".png" ) {    # we are dealing with png
            return ( "$_/$Name" . ".png", $Name, "png" );
        }
        elsif ( -f "$_/$Name" . ".jpeg" ) {
            return ( "$_/$Name" . ".jpeg", $Name, "jpeg" );
        }
        elsif ( -f "$_/$Name" . ".jpg" ) {
            return ( "$_/$Name" . ".jpg", $Name, "jpg" );
        }
        elsif ( -f "$_/$Name" . ".xbm" ) {
            return ( "$_/$Name" . ".xbm", $Name, "xbm" );
        }
        elsif ( -f "$_/$Name" . ".xpm" ) {
            return ( "$_/$Name" . ".xpm", $Name, "xpm" );
        }
        elsif ( -f "$_/$Name" . ".wmp" ) {
            return ( "$_/$Name" . ".wmp", $Name, "wmp" );
        }
    }
    print "$ScriptName: ValidIcon: Invalid icon file $IconName, no icon use\n";
    return ( "NOICON", "NOICON", "" );
    1;
}

#sub GetTransparent {
#   my $TransparentStr = $config_parms{button_transparent_color} || "255,255,255";
#   return split ( ',', $TransparentStr );
#}

sub GetTextColor {
    my $ColorStr = $config_parms{button_text_color} || "50,50,50";
    return split( ',', $ColorStr );
}

# will open image with specific type
# if NOTEMPLATE, will create a default one
sub OpenImage {
    my $FileName  = shift;
    my $ImageType = shift;

    #  my ( $Name, $Type ) = split ( /\./, $FileName );
    my ( $Name, $Type ) = $FileName =~ /(.+)\.(\S+)/;
    my $TemplateObject;
    $FileName = FindFile( $FileName, $ImageType );

    print "$ScriptName: OpenImage: File=$FileName Name=$Name,Type=$Type\n"
      if $Debug{$ScriptName};
    if ( uc($Type) eq "PNG" ) {
        $TemplateObject = GD::Image->newFromPng($FileName);
    }
    elsif ( uc($Type) eq "JPG" ) {
        $TemplateObject = GD::Image->newFromJpeg($FileName);
    }
    elsif ( uc($Type) eq "JPEG" ) {
        $TemplateObject = GD::Image->newFromJpeg($FileName);
    }
    elsif ( uc($Type) eq "XBM" ) {
        $TemplateObject = GD::Image->newFromXbm($FileName);
    }
    elsif ( uc($Type) eq "WMP" ) {
        $TemplateObject = GD::Image->newFromWmp($FileName);
    }
    elsif ( uc($Type) eq "Xpm" ) {
        $TemplateObject = GD::Image->newFromXpm($FileName);
    }
    elsif ( $FileName eq "NOTEMPLATE" ) {

        # we have no template
        $TemplateObject =
          GD::Image->new( $GenericTemplateX, $GenericTemplateY );
        my $white = $TemplateObject->colorAllocate( 255, 255, 255 );
        my $black = $TemplateObject->colorAllocate( 0,   0,   0 );
        $TemplateObject->rectangle( 0, 0, $GenericTemplateX, $GenericTemplateY,
            $white );
        $TemplateObject->rectangle(
            1, 1,
            $GenericTemplateX - 1,
            $GenericTemplateY - 1, $black
        );
        $TemplateObject->rectangle(
            3, 3,
            $GenericTemplateX - 3,
            $GenericTemplateY - 3, $white
        );
        print
          "$ScriptName: Template file not defined in configuration file, will create a simple one\n";
        $ButtonOK = 0;
    }
    elsif ( $FileName eq "NOICON" ) {

        # define a 1 pixels icon
        my $XLength = 1;
        my $YLength = 1;
        $TemplateObject = GD::Image->new( $XLength, $YLength );
        my $white = $TemplateObject->colorAllocate( 255, 255, 255 );
        $TemplateObject->rectangle( 0, 0, $XLength, $YLength, $white );
        print "$ScriptName: OpenImage: Using simple icon (1 pixel)\n"
          if $Debug{$ScriptName};
        $ButtonOK = 0;
    }

    #my $Transparent = $TemplateObject->colorAllocate( $TransparentR, $TransparentG, $TransparentB );
    #$TemplateObject->transparent($Transparent);
    return $TemplateObject;

}

sub FindFile {
    my $FileName  = shift;
    my $ImageType = shift;
    if ( -f $FileName ) {
        print "$ScriptName: FindFile: Will use $FileName"
          if $Debug{$ScriptName};
        return $FileName;
    }
    my @Dir = split( /:/, $config_parms{icons_dir} );
    if ( scalar @Dir == 0 ) {
        print "$ScriptName: FindFile: $ImageType $FileName not found";
        return "NO$ImageType";
    }
    foreach my $Dirname (@Dir) {
        if ( -f "$Dirname/$FileName" ) {
            print "$ScriptName: FindFile: Will use $Dirname/$FileName"
              if $Debug{$ScriptName};
            return "$Dirname/$FileName";
        }
    }
    print
      "$ScriptName: FindFile: $ImageType $FileName not found in any icons dir";
    return "NO$ImageType";

}

#sub print_log {
#   print "@_\n";
#   1;
#}

#$Log: button2.pl,v $
#Revision 1.5  2005/05/22 18:13:08  winter
#*** empty log message ***
#
#Revision 1.4  2004/02/01 19:24:36  winter
# - 2.87 release
#
#Revision 1.2  2002/12/01 06:23:18  gaetan
#First release to public
#
