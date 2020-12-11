# ##################################################
# grafik.pl
#
# This file interfaces to the Lutron Grafik Eye system
# This has only been tested on a GRX-PRG RS-232 port
#
# Copyright 2002 Rob Williams rob@invertex.com
#
# Licensed under any version of the GNU Public License
#
# ###################################################
#
# The protocol is documented at:
#    http://www.lutron.com/instructions/040138.pdf
#
#
#
# Add these entries to your mh.ini file:
#
#  serial_grafik_port=COM3
#  serial_grafik_baudrate=9600
#  serial_grafik_handshake=none
#  serial_grafik_datatype=raw
#

my $state_test;
my $said_grafik;
my $grafik_status;

# Grafik Port grabs status feedback when controllers are pressed

$grafik_port = new Serial_Item( ":G\r", 'init1', 'serial_grafik' );

# Request system state if we just started

set $grafik_port 'init1' if $Startup;

# We only are using the first 9 scenes and off.  Not all 16 are supported.

# GE_Kitchen is the Kitchen Grafic Eye at Address "1"

$ge_kitchen = new Serial_Item( undef, undef, 'serial_grafik' );
$ge_kitchen->add( ":A01\r", '0' );
$ge_kitchen->add( ":A11\r", '1' );
$ge_kitchen->add( ":A21\r", '2' );
$ge_kitchen->add( ":A31\r", '3' );
$ge_kitchen->add( ":A41\r", '4' );
$ge_kitchen->add( ":A51\r", '5' );
$ge_kitchen->add( ":A61\r", '6' );
$ge_kitchen->add( ":A71\r", '7' );
$ge_kitchen->add( ":A81\r", '8' );
$ge_kitchen->add( ":A91\r", '9' );

# GE_Living is the Living Room Grafik Eye at Address "2"

$ge_living = new Serial_Item( undef, undef, 'serial_grafik' );
$ge_living->add( ":A02\r", '0' );
$ge_living->add( ":A12\r", '1' );
$ge_living->add( ":A22\r", '2' );
$ge_living->add( ":A32\r", '3' );
$ge_living->add( ":A42\r", '4' );
$ge_living->add( ":A52\r", '5' );
$ge_living->add( ":A62\r", '6' );
$ge_living->add( ":A72\r", '7' );
$ge_living->add( ":A82\r", '8' );
$ge_living->add( ":A92\r", '9' );

# GE_Mbed is the Bedroom Grafik Eye at Address "3"

$ge_mbed = new Serial_Item( undef, undef, 'serial_grafik' );
$ge_mbed->add( ":A03\r", '0' );
$ge_mbed->add( ":A13\r", '1' );
$ge_mbed->add( ":A23\r", '2' );
$ge_mbed->add( ":A33\r", '3' );
$ge_mbed->add( ":A43\r", '4' );
$ge_mbed->add( ":A53\r", '5' );
$ge_mbed->add( ":A63\r", '6' );
$ge_mbed->add( ":A73\r", '7' );
$ge_mbed->add( ":A83\r", '8' );
$ge_mbed->add( ":A93\r", '9' );

# GE_Garage is the Garage Grafik Eye at Address "4"

$ge_garage = new Serial_Item( undef, undef, 'serial_grafik' );
$ge_garage->add( ":A04\r", '0' );
$ge_garage->add( ":A14\r", '1' );
$ge_garage->add( ":A24\r", '2' );
$ge_garage->add( ":A34\r", '3' );
$ge_garage->add( ":A44\r", '4' );
$ge_garage->add( ":A54\r", '5' );
$ge_garage->add( ":A64\r", '6' );
$ge_garage->add( ":A74\r", '7' );
$ge_garage->add( ":A84\r", '8' );
$ge_garage->add( ":A94\r", '9' );

start $grafik_port
  if $New_Minute
  and is_stopped $grafik_port
  and is_available $grafik_port;

# Grafik Eye status grab
# This updates MisterHouse's database whenever any scene is sleceted on
# any keypad in the house.

# GRX-PRG should have dip switch #7 on for Scene Status Information
# This is setup for Systems with 4 Grafik Eye controllers.
# Systems that have more or less need to add more or less $1,$2,$3
# and need to add additional or remove ([0-9]) to grab the additional status.

# I'm personally shocked this works.

$_ = said $grafik_port;
if (/:ss ([0-9])([0-9])([0-9])([0-9])/) {

    print_log "Grafik eye status $1 $2 $3 $4";
    if ( !( state $ge_kitchen eq $1 ) ) { set $ge_kitchen $1; }
    if ( !( state $ge_living eq $2 ) )  { set $ge_living $2; }
    if ( !( state $ge_mbed eq $3 ) )    { set $ge_mbed $3; }
    if ( !( state $ge_garage eq $4 ) )  { set $ge_garage $4; }

}
