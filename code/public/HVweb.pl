#
# Package to control Homevision controller via the Homevision web server
#
# Set homevision_url=<your homevision web server url> in mh.ini
#
# Create items as follows:
#

use HVweb_Item;

$kitchen_light = new HVweb_Item( 'On', 'X10 G1 On' );
$kitchen_light->add( 'Off', 'X10 G1 Off' );
$vcr = new HVweb_Item( 'Power', 'IR 45 1 time' );
$vcr->add( 'Play', 'IR 46 1 time' );

# See Homevision documentation for complete list of command formats
# Configure Homevision Webserver to report command results
#
# Operate devices as follows:
#
#     set $kitchen_light 'On';
#     set $vcr 'Play';
