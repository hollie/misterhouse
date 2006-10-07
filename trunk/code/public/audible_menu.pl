# Category=Other

=begin comment

audible_menu.pl

By David Norwood, dnorwood2@yahoo.com

Here are some ways to configure audible menus, depending on your type of
input.  Edit the last last line of this file and place it in your code 
directory.  You will also need the menu.pl file from mh/code/bruce and 
optionally a custom menu file (see test.menu for an example.)

The arguments are: name of menu to use, delay between menu items in 
seconds, code for switch 1, optional code for switch 2.

Examples:

X10 remote input, where switch 1 is wired to M1 ON and switch 2 is
wired to M1 OFF:

$audible = new Audible_Menu 'mh', 5, 'XM1MJ', 'XM1MK';

Mouse input with one switch (Windows only, use 1 for left click and 2
for a right click, make sure QuickEdit is disabled in the properties 
for the MS-DOS window where Misterhouse is running):

$audible = new Audible_Menu 'mh', 5, 1;

Keyboard input using the space bar:

$audible = new Audible_Menu 'mh', 5, ' ';

Switch wired directly to parallel or serial port: not yet implemented.

=cut

use Audible_Menu;

#$audible = new Audible_Menu 'mh', 5, 's', 'e';
#$audible = new Audible_Menu 'mh', 5, 'XA8AJ', 'XA8AK';
$audible = new Audible_Menu 'mh', 5, 'XA8AJ', 'XA8AK';
