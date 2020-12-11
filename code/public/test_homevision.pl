#Test Homevision MisterHouse interface:

# Add these lines to your mh.ini:
#Homevision_port=/dev/ttyS0
#Homevision_baudrate=19200

# Then emulate these commands in your scripts:

# Listen for the X-10 address "N5":
$btn5 = new X10_Item("N5");

# Control the family room lamp at B1
$frlamp = new X10_Item("B1");

# Prepare some IR signals you've saved into Homevision's "slots"
$tvir = new Serial_Item( "IRSlot3", "chup", 'Homevision' );
$tvir->add( "IRSlot4", "chdn" );

# Do some I/O:
$mbrspkr = new Serial_Item( "OUTPUT00high", "on", 'Homevision' );
$mbrspkr->add( 'OUTPUT00low', 'off' );

$tvpwrsensor = new Serial_Item( 'INPUT15low', 'on', 'Homevision' );
$tvpwrsensor->add( 'INPUT15high', 'off' );

# Here's some more code

print "Received IR signal $state\n" if $state = state_now $tvir;
print "TV input is now $state\n"    if $state = state_now $tvpwrsensor;

set $tvir "chup"  if state_now $btn5 eq 'on';
set $tvir "chdn"  if state_now $btn5 eq 'off';
set $frlamp '0'   if state_now $btn5 eq 'on';
set $frlamp '100' if state_now $btn5 eq 'off';

#set $mbrspkr 'on' if $New_Second && $Second%20 == 0 && $Second%40==0;
#set $mbrspkr 'off' if $New_Second && $Second%20 == 0 && $Second%40!=0;

