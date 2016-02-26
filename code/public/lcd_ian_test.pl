
=begin comment

From Ian Davidson  on 03/2001:
 
I saw earlier Bruce mention any code that might be useful to others. Attached
is a slightly modified lcdproc.pl. It enables you to test your menu files just
using the MH main screen and the computer keyboard. Use the up, down, left,
right keys to navigate. The 0 key on the keypad is the enter key and the Ctrl
key is the exit button. You can adjust the script for different sizes but it
is currently set to my 16 x 2 LCD module. You do not need an LCD to try this,
on the MH screen it will list exactly what you will see on an LCD with line 1,
line 2 labelled accordingly.

My project is
is a two way wireless remote to use with MH. It has a 16 x 2 LCD and 16
buttons. I wanted something I could use anywhere in and around the house to
control MH. I also wanted to use the rf link on MH for other things at a later
date. i.e. a weather station sending data back by RF, Ibuttons interfaced to a
PIC sending data back by RF, no long cables and the remote, weather station,
and ibuttons would all be able to share one com port.

I have it working now but I may have to rewrite some of the RF protocol to
enable it to handle weak signals better. If anyone is interested then just
post to the group and I'll go into more detail.

=cut

# The numeric entries are for using computer keyboard arrows
# My keypad:  nmlk ihgf XduE
%lcd_keymap = (
    2  => 'up',
    8  => 'down',
    4  => 'left',
    6  => 'right',
    1  => 'exit',
    5  => 'enter',
    B  => 'exit',
    E  => 'enter',
    38 => 'up',
    40 => 'down',
    37 => 'left',
    39 => 'right',
    17 => 'exit',
    96 => 'enter'
);

# These are the LCD display sizes (e.g. 2x16 characters)
$lcd_data{dy_max} = 2 - 1;
$lcd_data{dx_max} = 16 - 1;

$lcd_keypad = new Generic_Item(undef);

my ( $lcd_header, $lcd_footer, $key_is, $line_pos );
$lcd_header = "UUUUU" . chr(16);
$lcd_footer = chr(16) . chr(16);

#$lcdproc = new  Serial_Item(undef, undef, 'serial2');

if ($Reread) {
    my $data;
    $data = $lcd_header . "LCD Initialised" . $lcd_footer;

    #set $lcdproc $data;
}

$keypad = new Serial_Item( 'UUUUUA1', '1', 'serial2' );
$keypad->add( 'UUUUUA2', '2', 'serial2' );
$keypad->add( 'UUUUUA3', '3', 'serial2' );
$keypad->add( 'UUUUUA4', '4', 'serial2' );
$keypad->add( 'UUUUUA5', '5', 'serial2' );
$keypad->add( 'UUUUUA6', '6', 'serial2' );
$keypad->add( 'UUUUUA7', '7', 'serial2' );
$keypad->add( 'UUUUUA8', '8', 'serial2' );
$keypad->add( 'UUUUUA9', '9', 'serial2' );
$keypad->add( 'UUUUUA0', '0', 'serial2' );
$keypad->add( 'UUUUUA*', 'B', 'serial2' );
$keypad->add( 'UUUUUA#', 'E', 'serial2' );

if ( $state = said $keypad) {
    if ( $state =~ /UUUUUA/ ) {
        $key_is = substr( $', 0, 1 );
        $key_is = "B" if $key_is eq "*";
        $key_is = "E" if $key_is eq "#";

        #set $lcd_keypad $key_is;
        #print "incoming=$key_is \n";
    }
}

# If refresh, send new data to the display
my @lcd_data_prev;
if ( $lcd_data{refresh} ) {
    $lcd_data{refresh} = 0;

    # Send only changed lines
    my ( $data, $line );
    for my $i ( 0 .. $lcd_data{dy_max} ) {
        my $j = $i + 1;
        $line = $lcd_data{display_override}[$i];
        $line = $lcd_data{display}[$i] unless $line;
        $line =~ s/\n.*//s;    # Use only the first line of data
        $line_pos = chr(254) . chr(1) . chr(254) . chr(128) if $j == 1;
        $line_pos = chr(254) . chr(192) if $j == 2;
        $data .= "$lcd_header" . "$line_pos" . "{$line}" . "$lcd_footer"
          unless $line eq $lcd_data_prev[$i];
        $lcd_data_prev[$i] = $line;
        print "Line $j - {$line}\n";
    }
    if ($data) {

        #set $lcdproc $data;
    }

    #   print "lcdproc data=$data\n";
}

# Displayed delayed last response text
if ( $Menus{last_response_loop} and $Menus{last_response_loop} <= $Loop_Count )
{
    $Menus{last_response_loop} = 0;
    &menu_lcd_display( &last_response, $Menus{last_response_menu} );
}

# Navigate using the cursor keys
if ( $state = state_now $lcd_keypad or $state = $Keyboard ) {

    #print "lcd key=$state\n";
    &menu_lcd_navigate($state);
}
