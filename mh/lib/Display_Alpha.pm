
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

Here are some usage examples:

 display device => 'alpha', mode => 'hold',   color => 'amber', text => $Time_Now;
 display device => 'alpha', mode => 'rotate', color => 'green', text => $Weather{Summary};
 display "device=alpha $caller";

More examples can be found in mh/code/bruce/display_alpha.pl

=cut


use strict;
package Display_Alpha;

sub startup {
   &::serial_port_create('Display_Alpha', $main::config_parms{Display_Alpha_port}, 9600);
   &::Exit_add_hook( sub { &main::display_alpha(text => 'I am dead', color => 'yellow') }, 1);
}

sub main::display_alpha {
    my (%parms) = @_;
    
    print "Alpha display: $parms{text}\n" if $::Debug{display_alpha};

# [COMMAND CODE][FILE LABEL] <esc> [Display Position][Mode Code] Special Specifier [ASCII MESSAGE]
#  Command Code AA ->  write (A) to label A

    $parms{color} = 'green' unless $parms{color};
    $parms{mode}  = 'hold'  unless $parms{mode};

    my $init  = "\0\0\0\0\0\001" . "Z00" . "\002";  # Nul, StartOfHeader=01, Type=Z, Address=00, StartOfText=02
    my $cmd   = "AA";          # Write to Lable A
    my $pos   = "\x1B\x20";    # Middle is best. Top=\x22, Bottom=\x26, Fill=\x30
    my %mode  = ( rotate => "\x61", hold => "\x62", flash => "\x63" );
    my %color = (      red => "\x31",    green => "\x32",  amber => "\x33", darkred => "\x34", 
                 darkgreen => "\x35",    brown => "\x36", orange => "\x37",  yellow => "\x38",
                  rainbow1 => "\x39", rainbow2 => "\x41",    mix => "\x42",    auto => "\x43",   off => "\x30",);
    my $data = $init . $cmd . $pos . $mode{lc $parms{mode}} . "\x1c" . $color{lc $parms{color}} . $parms{text} . "\004";

    print "Display_Alpha: parms=@_ data=$data\n" if $::Debug{display_alpha} == 2;

    $main::Serial_Ports{'Display_Alpha'}{object}->write($data);
}

1;
