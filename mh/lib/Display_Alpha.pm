=begin comment

Use this module to send text to the Alpha LED signs using a serial port.  Signs are available from:

  http://www.ams-i.com/
  http://alpha-american.com/

I picked up the Alpha 213C (a.k.a. BetaBrite, 2" x 30", 14 character) from the local Sam's Club for $150.
It displays in multiple colors, in either scrolling or fixed text.
SamsClub.com only lists a bigger version, but info on BetaBrite I have can be seen here:

   http://www.betabrite.com/Pages/betabrite.htm

The Alpha protocol is documented here:
  http://www.ams-i.com/Pages/97088061.htm
  http://dens-site.net/betabrite/betabrite.htm

Use these mh.ini parameters to enable this code:

 Display_Alpha_module = Display_Alpha
 Display_Alpha_port   = COM1

If you have more than one display, point to the ports, and the rooms they are in, with this format:

 Display_Alpha_port   = COM1=>living, COM2=>bedroom

Then use the display room= parm to pick the room.  If room is not used, it goes to all displays.

Here are some usage examples:

 display device => 'alpha', mode => 'hold',   color => 'amber', text => $Time_Now;
 display device => 'alpha', mode => 'rotate', color => 'green', text => $Weather{Summary};
 display "device=alpha $caller";

More examples can be found in mh/code/bruce/display_alpha.pl

=cut

use strict;
package Display_Alpha;

my @room_names;
sub startup {
                                # Open all ports
    for my $port_room (split ',', $::config_parms{Display_Alpha_port}) {
        my ($port, $room) = $port_room =~ /(\S+) *=> *(\S+)/;
        unless ($room) {
            $port = $port_room;
            $room = 'default';
        }
        $room = lc $room;
        print "Opening Display_Alpha port: pr=$port_room port=$port room=$room\n" if $::Debug{display_alpha};
        push @room_names, $room;
        &::serial_port_create("Display_Alpha_$room", $port, 9600);
    }
    &::Exit_add_hook( sub { &main::display_alpha(text => 'I am dead', color => 'yellow') }, 1);
}

sub main::display_alpha {
    my (%parms) = @_;

    print "Alpha display: @_\n" if $::Debug{display_alpha};

    my %mode  = ( rotate   => "\x61", hold     => "\x62", flash    => "\x63", auto      => "\x64",
                  rollup   => "\x65", rolldown => "\x66", rollleft => "\x67", rollright => "\x68",
                  wipeup   => "\x69", wipedown => "\x6A", wipeleft => "\x6B", wiperight => "\x6C",
                  rollup2  => "\x6D", rainbow  => "\x6E", auto2    => "\x6F",
                  wipein2  => "\x70", wipeout2 => "\x71", wipein   => "\x72", wipeout   => "\x73",
                  rotates  => "\x74",
                );
    my %color = (      red => "\x31",    green => "\x32",  amber => "\x33", darkred => "\x34",
                 darkgreen => "\x35",    brown => "\x36", orange => "\x37",  yellow => "\x38",
                  rainbow1 => "\x39", rainbow2 => "\x41",    mix => "\x42",    auto => "\x43",   off => "\x30");

# [COMMAND CODE][FILE LABEL] <esc> [Display Position][Mode Code] Special Specifier [ASCII MESSAGE]
#  Command Code AA ->  write (A) to label A


    $parms{color}   = lc $parms{color} if $parms{color};
    $parms{color}   = 'green' if !$parms{color} or !$color{$parms{color}};

    $parms{mode}    = lc $parms{mode} if $parms{mode};
    $parms{mode}    = 'hold'  if !$parms{mode}  or !$mode{$parms{mode}};

    my $init  = "\0\0\0\0\0\001" . "Z00" . "\002";  # Nul, StartOfHeader=01, Type=Z, Address=00, StartOfText=02
    my $cmd   = "AA";          # Write to Lable A
    my $pos   = "\x1B\x20";    # Middle is best. Top=\x22, Bottom=\x26, Fill=\x30

    my $data = $init . $cmd . $pos . $mode{$parms{mode}} . "\x1c" . $color{$parms{color}} . $parms{text} . "\004";

    my @rooms = split ',', lc($parms{room}) if $parms{room};
    @rooms = @room_names unless @rooms;
    for my $room (@rooms) {
        print "Display_Alpha: room=$room parms=@_ data=$data\n" if $::Debug{display_alpha};
        if ($::Serial_Ports{"Display_Alpha_$room"} and $::Serial_Ports{"Display_Alpha_$room"}{object}) {
            $::Serial_Ports{"Display_Alpha_$room"}{object}->write($data);
        }
        else {
            print "Error, can not find Display_Alpha port: room=$room\n";
        }
    }
}

1;
