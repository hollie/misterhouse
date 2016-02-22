
=head1 B<Display_Alpha>

=head2 SYNOPSIS

Parameters:

  mode - transition or special animation (see %modes and %special_modes)
  color - text colot (see %colors)
  font - small,large or fancy
  fontsize - set to wide to double the number of fonts to 6
  position - middle, top, bottom, fill or left seems to make no difference on Beta Brites
  image - name of a BMP file* in ../data/alpha/images
  imageposition - left or right
  speed - usually best to use the default (slowest), makes little difference on Beta Brite
  wait - Set to 1 to buffer the message (buffered sequence is sent to the sign on the next message without the wait flag)

Examples:

  &display(device=>'alpha', wait=>1, speed=>'slowest', text=>'You have mail!', app=>'mail', mode=>'hold',image=>'mail');
  &display(device=>'alpha', wait=>1, text=>'Dog has left the yard!', app=>'dog' color=>'red', mode=>'runninganimal');
  &display(device=>'alpha', text=>"Now playing in the den: $Save{now_playing}", app=>'music', image=>'cd', rooms='den');

Note in the last line the presence of the rooms parameter and the abscence of the wait parameter.  This sends the entire sequence to the den sign.  Any room parameters defined by previous messages in the sequence are discarded.  The last message sent in a sequence defines the rooms that receive the message.  Consider this example:

  &display(device=>'alpha', wait=>1, speed=>'slowest', text=>'You have mail.', color=>'green', mode=>'hold',image=>'mail');
  &display(device=>'alpha', wait=>1, text=>'Dog has left the yard!', app=>'dog' color=>'red', mode=>'runninganimal');
  &display(device=>'alpha', text=>"Now playing in the den: $Save{den_now_playing}.", app=>'music', image=>'cd');

Note that the rooms parameter is removed from the last line.  This sequence will go to the rooms associated with the music application (or the default sign if none are defined.)  In most cases it will be clearer to override the rooms parameter on the last message (as in the first example.)  Also note that display_alpha is not called directly as it would bypass app parameter processing

* Use standard 16 color bitmaps and realize that a one-to-one mapping is impossible, at least not on an eight color (nine counting black) Beta Brite.  Most models are 7 x 80 pixels.

NOTE: Known issue (at least on older signs) - 2 bitmaps in a sequence will not display the second (1, 3, 4, 5+ in a sequence works fine) This is not a Misterhouse issue as it shows up at the command prompt with a stand-alone script.  Also note that each bitmap file counts once, regardless of how many times it is referenced in the sequence (each file is sent to the sign once.)

=head2 DESCRIPTION

Use this module to send text to the Alpha LED signs using a serial port.  Signs are available from:

  http://www.ams-i.com/
  http://alpha-american.com/

I picked up the Alpha 213C (a.k.a. BetaBrite, 2" x 30", 14 character) from the local Sam's Club for $150.  It displays in multiple colors, in either scrolling or fixed text.  SamsClub.com only lists a bigger version, but info on BetaBrite I have can be seen here:

  http://www.betabrite.com/Pages/betabrite.htm

The Alpha protocol is documented in its entirety here:

  http://www.ams-i.com/Pages/97088061.htm

Some Beta Brite PERL examples can be found here:

  http://dens-site.net/betabrite/betabrite.htm

=head2 INHERITS

B<NONE>

=head2 METHODS

=over

=item B<UnDoc>

=cut

use strict;
use IO::File;    # Added for BMP import

package Display_Alpha;

my @room_names;

sub startup {

    # Open a port for each room
    for my $port_room ( split ',', $::config_parms{Display_Alpha_port} ) {
        my ( $port, $room ) = $port_room =~ /(\S+) *=> *(\S+)/;

        my $type;

        if ($room) {
            $room = lc $room;
            $type = $::config_parms{"Display_Alpha_type_$room"};
        }
        else {
            $type = $::config_parms{Display_Alpha_type};
            $port = $port_room;
            $room = 'default';
        }
        print
          "Opening Display_Alpha port: pr=$port_room port=$port room=$room\n"
          if $::Debug{display_alpha};
        push @room_names, $room;

        if ( $type and $type eq 'old' ) {
            &::serial_port_create( "Display_Alpha_$room", $port, 9600, undef,
                undef, undef, "even", 7, 2 );
        }
        else {
            &::serial_port_create( "Display_Alpha_$room", $port, 9600 );
        }

    }
    &::Exit_add_hook(
        sub {
            &main::display_alpha(
                text  => 'I am shut down',
                color => 'yellow',
                mode  => 'thankyou'
            );
        },
        1
    );
}

my @messages;
my @images;
my @image_names;
my %image_addresses;    # by name

my %bitmaps;            # converted image data by filename

my $INIT   = "\0\0\0\0\0\0\x01Z00\x02";
my $FINISH = "\004";

my %positions = (
    middle => "\x20",
    top    => "\x22",
    bottom => "\x26",
    fill   => "\x30",
    left   => "\x31",
    right  => "\x32"
);

# positions have little effect on single-row Beta Brite signs

my %modes = (
    rotate    => "\x61",
    hold      => "\x62",
    flash     => "\x63",
    rollup    => "\x65",
    rolldown  => "\x66",
    rollleft  => "\x67",
    rollright => "\x68",
    wipeup    => "\x69",
    wipedown  => "\x6A",
    wipeleft  => "\x6B",
    wiperight => "\x6C",
    rollup2   => "\x6D",
    special   => "\x6E",
    auto      => "\x6F",
    wipein2   => "\x70",
    wipeout2  => "\x71",
    wipein    => "\x72",
    wipeout   => "\x73",
    rotates   => "\x74",
    explode   => "\x75",
    clock     => "\x76"
);

# last two modes are Alpha 3.0 (won't work with older signs)

my %special_modes = (
    sparkle           => "\x31",
    twinkle           => "\x30",
    snow              => "\x32",
    interlock         => "\x33",
    switch            => "\x34",
    slide             => "\x35",
    spray             => "\x36",
    starburst         => "\x37",
    welcome           => "\x38",
    slotmachine       => "\x39",
    newsflash         => "\x3A",
    trumpet           => "\x3B",
    cyclecolors       => "\x43",
    thankyou          => "\x53",
    nosmoking         => "\x55",
    dontdrinkanddrive => "\x56",
    runninganimal     => "\x57",
    fireworks         => "\x58",
    turbocar          => "\x59",
    cherrybomb        => "\x5A"
);

# cyclecolors, trumpet and newsflash do not work on older Beta Brite signs

my %colors = (
    red       => "\x31",
    green     => "\x32",
    amber     => "\x33",
    darkred   => "\x34",
    darkgreen => "\x35",
    brown     => "\x36",
    orange    => "\x37",
    yellow    => "\x38",
    rainbow1  => "\x39",
    rainbow2  => "\x41",
    mix       => "\x42",
    auto      => "\x43",
    off       => "\x30"
);

my %fonts = ( small => "\x31", large => "\x33", fancy => "\x35" );

my %speeds = (
    fast    => "\x18",
    faster  => "\x19",
    slow    => "\x17",
    slower  => "\x16",
    slowest => "\x15"
);

my %beta_brite_colors = (
    '000000' => '0',
    '800000' => '4',
    '008000' => '5',
    '800080' => '6',
    'FF0000' => '1',
    '00FF00' => '2',
    'FFFF00' => '8',
    '808000' => '3',
    'FF00FF' => '7',
    '0000FF' => '0',
    '00FFFF' => '2',
    'C0C0C0' => '6',
    FFFFFF   => '8',
    '008080' => '2',
    '808080' => '6',
    '000080' => '0',
    '4000FF' => '6'
);

sub set_message_memory {
    my (%parms) = @_;
    my ( $message, $address );

    if ( !$parms{message} ) {
        ( $message, $address ) = @_;
    }
    else {
        $message = $parms{message};
        $address = $parms{address};
    }

    $address = "A" unless $address;
    my $result;
    my $size = 0;

    $size = length($message);

    $result = $address . 'AU' . uc( sprintf( "%04x", $size ) ) . 'FFFE';

    return $result;

}

sub image_dimensions {
    my $image = shift;
    my ( $height, $width );
    my @rows = split( "\r", $image );

    $height = $#rows + 1;
    $width  = length( $rows[0] );

    return ( $height, $width );
}

sub set_image_memory {
    my (%parms) = @_;
    my ( $image, $address, $height, $width );

    if ( !$parms{image} ) {
        ( $image, $address ) = @_;
    }
    else {
        $image   = $parms{image};
        $address = $parms{address};
    }

    ( $height, $width ) = &image_dimensions($image);

    return
      $address . 'DU'
      . uc( sprintf( "%02x", $height ) . sprintf( "%02x", $width ) ) . '4000';

}

sub image {
    my (%parms) = @_;
    my ( $image, $address, $height, $width );

    if ( !$parms{image} ) {
        ( $image, $address ) = @_;
    }
    else {
        $image   = $parms{image};
        $address = $parms{address};
    }

    ( $height, $width ) = &image_dimensions($image);

    print "Address: $address height: $height width: $width\n"
      if $::Debug{display_alpha};

    return (
        uc( sprintf( "%02x", $height ) . sprintf( "%02x", $width ) ) . $image );

}

sub special_function {
    "E@_";
}

sub image_header {
    my $address = shift;
    $address = 'A' unless $address;
    "I$address";
}

sub header {
    my $address = shift;
    $address = 'A' unless $address;
    "A$address\x1b";
}

sub message {
    my (%parms) = @_;

    my (
        $message,  $color, $mode,    $position, $font,
        $fontsize, $speed, $address, $image,    $imageposition
    );
    my $special;

    if ( !$parms{text} ) {
        (
            $message,       $color,    $mode,  $position,
            $font,          $fontsize, $speed, $image,
            $imageposition, $address
        ) = @_;
    }
    else {
        $message       = $parms{text};
        $color         = $parms{color};
        $mode          = $parms{mode};
        $position      = $parms{position};
        $address       = $parms{address};
        $font          = $parms{font};
        $image         = $parms{image};
        $speed         = $parms{speed};
        $imageposition = $parms{imageposition};
        $fontsize      = $parms{fontsize};
    }

    if ($mode) {
        if ( !$modes{$mode} ) {
            if ( $special_modes{$mode} ) {
                $special = 1;
            }
            else {
                $mode = undef;    #unknown mode
            }
        }
    }
    $mode          = 'hold' unless $mode;
    $imageposition = 'left' unless $imageposition;
    $position = 'middle' if !$position or !$positions{$position};
    $address = "A" unless $address;
    my $result = $positions{$position}
      . ( ($special) ? ( "\x6E" . $special_modes{$mode} ) : $modes{$mode} );
    $result .= "\x1c" . $colors{$color} if $color    and $colors{$color};
    $result .= "\x1a" . $fonts{$font}   if $font     and $fonts{$font};
    $result .= "\x12"                   if $fontsize and $fontsize eq 'wide';
    $result .= $speeds{$speed}          if $speed    and $speeds{$speed};

    if ($image) {
        print "Embedding image: $image\n" if $::Debug{display_alpha};
        $result .= "\x14" . $image if $imageposition eq 'left';
    }
    $result .= $message;
    if ($image) {
        $result .= "\x14" . $image if $imageposition eq 'right';
    }
    return $result;
}

sub main::display_alpha {
    my (%parms) = @_;
    my %message_parms;
    my (
        $text,  $mode,           $color, $font, $position,
        $image, $image_position, $rooms, $wait
    );
    my @rooms;
    my $image_address;

    if ( $parms{text} ) {
        $text           = $parms{text};
        $color          = $parms{color};
        $font           = $parms{font};
        $mode           = $parms{mode};
        $position       = $parms{position};
        $wait           = $parms{wait};
        $image          = $parms{image};
        $rooms          = $parms{rooms};
        $image_position = $parms{imageposition};
    }
    else {
        (
            $text,  $mode,           $color, $font, $position,
            $image, $image_position, $rooms, $wait
        ) = @_;
    }

    $message_parms{text}          = $text;
    $message_parms{color}         = $color;
    $message_parms{mode}          = $mode;
    $message_parms{font}          = $font;
    $message_parms{position}      = $position;
    $message_parms{imageposition} = $image_position;

    my $image_name = $image;    #save name for cache key

    if ( $image and $image !~ /\r/ ) {    #invalid Beta Brite DOT

        #	    my $image_file = "$::config_parms{data_dir}/alpha/images/$image.bmp";
        my $image_file = $::Pgm_Root . "/data/alpha/images/$image.bmp";
        if ( -e $image_file )
        {    # look for Windows Bitmap (Todo: add XBM support)
            if ( !&::file_changed($image_file) and $bitmaps{$image} ) {  #cached
                $image = $bitmaps{$image};
            }
            else {
                my %info        = &GetBMPInfo($image_file);
                my @picture     = @{ $info{picture} };
                my @color_table = @{ $info{color_table} };
                $image = '';
                print "\n" if $::Debug{display_alpha};
                for my $i ( 0 .. $#picture ) {
                    for my $j ( 0 .. $#{ $picture[$i] } ) {
                        if (
                            defined $beta_brite_colors{
                                uc( @color_table[ $picture[$i][$j] ] ) } )
                        {
                            $image .= $beta_brite_colors{
                                uc( @color_table[ $picture[$i][$j] ] ) };
                        }
                        else {    # unmapped color, turn LED off
                            $image .= $beta_brite_colors{'000000'};
                        }
                        print $picture[$i][$j] if $::Debug{display_alpha};
                    }
                    $image .= "\r";
                    print "\n" if $::Debug{display_alpha};
                }
                $bitmaps{$image_name} = $image;    #cache bitmap data
            }
        }
        else {
            warn "Display_Alpha:Missing bitmap image: $image";
            $image = undef;
        }
    }

    if ($image) {
        if ( defined $image_addresses{$image_name} ) {
            $image_address = $image_addresses{$image_name};
        }
        else {
            push @images,      $image;
            push @image_names, $image_name;
            $image_address = 65 + $#images;
            $image_addresses{$image_name} = $image_address;
        }
        $message_parms{image} = chr($image_address);
    }

    # push text to sequence
    push @messages, &message(%message_parms);

    # rooms=all or allandout, etc. used by some speak apps make no sense in display mapping scheme
    # room = port name and the default is to send to all rooms

    $rooms = undef if $rooms and $rooms =~ /^all/i;

    @rooms = split ',', $rooms if $rooms;

    if ( !$wait or $#messages > 93 ) {    # last in sequence or sign memory full
        &send_sequence(@rooms);
    }
}

sub send {
    my ( $data, $room ) = @_;

    print "Display_Alpha: room=$room parms=@_ data=$data\n"
      if $::Debug{display_alpha};

    if (    $::Serial_Ports{"Display_Alpha_$room"}
        and $::Serial_Ports{"Display_Alpha_$room"}{object} )
    {
        $::Serial_Ports{"Display_Alpha_$room"}{object}->write($data);
    }
    else {
        if (    $::Serial_Ports{"Display_Alpha_$room"}
            and $::Serial_Ports{"Display_Alpha_$room"}{object} )
        {
            $::Serial_Ports{"Display_Alpha_default"}{object}->write($data);
            warn
              "Invalid alphanumeric display port: $room.  Data sent to default port\n";
        }
        else {
            warn "Invalid alphanumeric display port: $room.\n";
        }
    }
}

sub send_sequence {
    my @rooms = @_;
    my $address;
    my $run_sequence;

    @rooms = @room_names
      unless @rooms; # populated on init, contains 'default' if no rooms defined
    for my $room (@rooms) {

        # Set memory

        $address = 32;    # 32-126, except 48 (20H-7EH, except 30H)
        &send( $INIT,                     $room );
        &send( &special_function("\x24"), $room );
        for (@messages) {
            &send(
                &set_message_memory(
                    message => $_,
                    address => chr( $address++ )
                ),
                $room
            );
            $address++ if $address == 48;
        }
        $address = 65;
        for (@images) {
            print "Setting image: $address\n" if $::Debug{display_alpha};

            &send(
                &set_image_memory( image => $_, address => chr( $address++ ) ),
                $room
            );
        }
        &send( $FINISH, $room );

        # Send images and messages

        $address = 65;
        for (@images) {
            print "Sending image: $address\n" if $::Debug{display_alpha};
            &send( $INIT,                          $room );
            &send( &image_header( chr($address) ), $room );
            &send( &image( image => $_, address => $address++ ), $room );
            &send( $FINISH, $room );
        }
        $address = 32;
        for (@messages) {
            &send( $INIT,                        $room );
            &send( &header( chr( $address++ ) ), $room );
            &send( $_,                           $room );
            &send( $FINISH,                      $room );
            $address++ if $address == 48;
        }

        # Set run sequence

        &send( $INIT,                     $room );
        &send( &special_function("\x2e"), $room );
        $address      = 32;
        $run_sequence = '';
        for (@messages) {
            $run_sequence .= chr( $address++ );
            $address++ if $address == 48;
        }
        &send( "TU$run_sequence", $room );
        &send( $FINISH,           $room );

    }

    # reset sequence

    @messages        = qw();
    @images          = qw();
    @image_names     = qw();
    %image_addresses = qw();
}

sub BMPRead ($$) {
    my ( $fh, $len ) = @_;
    my $retval;
    my $buf;

    sysread( $fh, $buf, $len );
    return $buf;
    return $retval;
}

sub GetBMPInfo ($) {
    my %comments = ();
    my $filename = shift;
    my $fh       = new IO::File;
    my $temp     = 0;
    my ( $len, $listlength, $pos, $buf );

    return if !-r $filename or !-f _;
    return if !open( $fh, $filename );
    binmode($fh);

    #Test for Bitmap

    return if BMPRead( $fh, 2 ) ne 'BM';

    print "Bitmap file: $filename\n" if $::Debug{display_alpha};

    # Get size

    my $size = ord( BMPRead( $fh, 1 ) );
    $size += 256 * ord( BMPRead( $fh, 1 ) );
    $size += 256 * ord( BMPRead( $fh, 1 ) );
    $size += 256 * ord( BMPRead( $fh, 1 ) );

    print "File size: $size\n" if $::Debug{display_alpha};

    # Check for invalid bits

    return if ord( BMPRead( $fh, 1 ) );
    return if ord( BMPRead( $fh, 1 ) );
    return if ord( BMPRead( $fh, 1 ) );
    return if ord( BMPRead( $fh, 1 ) );

    my $offset = ord( BMPRead( $fh, 1 ) );
    $offset += 256 * ord( BMPRead( $fh, 1 ) );
    $offset += 256 * ord( BMPRead( $fh, 1 ) );
    $offset += 256 * ord( BMPRead( $fh, 1 ) );

    print "Data offset: $offset\n" if $::Debug{display_alpha};

    BMPRead( $fh, 4 );

    my $width = ord( BMPRead( $fh, 1 ) );
    $width += 256 * ord( BMPRead( $fh, 1 ) );
    $width += 256 * ord( BMPRead( $fh, 1 ) );
    $width += 256 * ord( BMPRead( $fh, 1 ) );

    print "Width: $width\n" if $::Debug{display_alpha};

    my $height = ord( BMPRead( $fh, 1 ) );
    $height += 256 * ord( BMPRead( $fh, 1 ) );
    $height += 256 * ord( BMPRead( $fh, 1 ) );
    $height += 256 * ord( BMPRead( $fh, 1 ) );

    print "Height: $height\n" if $::Debug{display_alpha};

    BMPRead( $fh, 2 );    # skip planes (must be zero)

    my $bitsperpixel = ord( BMPRead( $fh, 1 ) );
    $bitsperpixel += 256 * ord( BMPRead( $fh, 1 ) );

    print "Bits per pixel: $bitsperpixel\n" if $::Debug{display_alpha};

    my $compressed = ord( BMPRead( $fh, 1 ) );
    $compressed += 256 * ord( BMPRead( $fh, 1 ) );
    $compressed += 256 * ord( BMPRead( $fh, 1 ) );
    $compressed += 256 * ord( BMPRead( $fh, 1 ) );

    if ( $::Debug{display_alpha} ) {
        print(
            (
                  ($compressed)
                ? ( 'Compression method: ' . $compressed )
                : "Uncompressed"
            )
            . "\n"
        );
    }

    my $data_size = ord( BMPRead( $fh, 1 ) );
    $data_size += 256 * ord( BMPRead( $fh, 1 ) );
    $data_size += 256 * ord( BMPRead( $fh, 1 ) );
    $data_size += 256 * ord( BMPRead( $fh, 1 ) );

    unless ($data_size) {
        $data_size =
          $size - $offset;    #file size minus header size equals data size
    }

    print "Data size: $data_size\n" if $::Debug{display_alpha};

    BMPRead( $fh, 4 );        # skip pels
    BMPRead( $fh, 4 );        # skip pels

    my $colors = ord( BMPRead( $fh, 1 ) );
    $colors += 256 * ord( BMPRead( $fh, 1 ) );
    $colors += 256 * ord( BMPRead( $fh, 1 ) );
    $colors += 256 * ord( BMPRead( $fh, 1 ) );

    $colors = 2**$bitsperpixel unless $colors;    #calculate if missing

    print "Colors: $colors\n" if $::Debug{display_alpha};

    BMPRead( $fh, 4 );    # skip "important" colors (don't care)

    my $color_table;
    my @color_table;

    if ( $bitsperpixel == 4 or $bitsperpixel == 8 )
    { #16-color bitmap has 16 * 4 byte color table (colors take up four bytes each)

        for my $i ( 1 .. 2**$bitsperpixel ) {
            my $blue  = unpack( 'H2', BMPRead( $fh, 1 ) );
            my $green = unpack( 'H2', BMPRead( $fh, 1 ) );
            my $red   = unpack( 'H2', BMPRead( $fh, 1 ) );
            BMPRead( $fh, 1 );    #skip reserved byte (last in quad)
            my $hex_color = "$red$green$blue";
            push @color_table, $hex_color;
            print "Color #$i: " . uc($hex_color) . "\n"
              if $::Debug{display_alpha};
        }

    }
    else {
        print "No color table\n" if $::Debug{display_alpha};
    }

    my $bytes_per_row;

    if ( $bitsperpixel == 4 or $bitsperpixel == 8 ) {
        $bytes_per_row = int( ( $bitsperpixel * $width ) / 8 );
        if ( $width % 2 and $bitsperpixel == 4 ) {
            $bytes_per_row++;    # odd width uses extra byte for last column
        }
    }

    if ( $bytes_per_row % 4 ) {    # align on word boundary if not already
        $bytes_per_row += ( 4 - $bytes_per_row % 4 );
    }

    print "Bytes per row: $bytes_per_row\n" if $::Debug{display_alpha};

    my @picture;    # array of row array references (PERL 2D array)
    for my $row ( 1 .. $height ) {
        my $column = 1;
        my $pixel  = 1;
        my @picture_row;
        while ( $column <= $bytes_per_row ) {
            my $data = BMPRead( $fh, 1 );
            if ( $bitsperpixel == 8 ) {
                push @picture_row, $data if $column <= $width;
            }
            else {
                push @picture_row, int( ord($data) / 16 ) if $pixel <= $width;
                $pixel++;
                push @picture_row, ord($data) % 16 if $pixel <= $width;
                $pixel++;
            }
            $column++;
        }
        unshift @picture, [@picture_row];
    }

    $comments{picture}     = [@picture];
    $comments{size}        = $size;
    $comments{colors}      = $colors;
    $comments{color_table} = [@color_table];
    return %comments;
}

1;

=back

=head2 INI PARAMETERS

Use these mh.ini parameters to enable this code:

 Display_Alpha_module = Display_Alpha
 Display_Alpha_port   = COM1

If you have an older Beta Brite, include:

 Display_Alpha_type   = old

If you have more than one display, point to the ports, and the rooms they are in, with this format:

 Display_Alpha_port   = COM1=>living, COM2=>bedroom

Then use the display room= parm to pick the room.  If room is not used, it goes to all displays.

Use the device parameter of the display function to direct text and/or graphics to the display.

 display device => 'alpha', mode => 'hold', color => 'amber', text => $Time_Now;
 display device => 'alpha', mode => 'rotate', color => 'green', text => $Weather{Summary};
 display "device=alpha $caller";

The easiest method to maintain schemes of colors, modes, graphics, fonts, etc. is with the application display parameters:

 display_apps = control => color=amber mode=scrolldown, error => color=red mode=cherrybomb

=head2 AUTHOR

UNK

=head2 SEE ALSO

More examples can be found in mh/code/bruce/display_alpha.pl

=head2 LICENSE

This program is free software; you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation; either version 2 of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more details.

You should have received a copy of the GNU General Public License along with this program; if not, write to the Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.

=cut

