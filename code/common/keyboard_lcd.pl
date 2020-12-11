# Category = MisterHouse

#@ Use this code to test LCD menus with a pc keyboard.
#@ See mh/code/bruce/lcd.pl for a real LCD example.
#@ The menu_group (e.g. default) is parsed with your menu.pl file.

# The first set is for Windows, the 2nd set is for Unix
#  - Use the arrow keys for up/down/left/right, 0 for ENTER, and . for exit
my %lcd_map_keyboard = (
    38       => 'up',
    40       => 'down',
    37       => 'left',
    39       => 'right',
    96       => 'enter',
    110      => 'exit',
    '1b5b41' => 'up',
    '1b5b42' => 'down',
    '1b5b44' => 'left',
    '1b5b43' => 'right',
    '0'      => 'enter',
    '.'      => 'exit'
);

#                            type    port   size   menu_group    keymap
#lcd_keyboard = new LCD 'keyboard', undef, '4x20', 'mh',   \%lcd_map_keyboard;
$lcd_keyboard = new LCD 'keyboard', undef, '4x20', 'test', \%lcd_map_keyboard;

# You can echo keystrokes with either of the following
#print "LCD key1: $state\n"    if defined($state = said_key $lcd2);
#print "LCD key2: $Keyboard\n" if defined $Keyboard;
