# Category=xAP

use BSC;

#@ This code will monitor mh items and send out state changes via xAP BSC.
#@ In addition, it will accepts commands via xAP BSC and update the
#@ corresponding states of mh items.

=begin comment

   This code "registers" entire types of devices (e.g., X10_Item) and optionally
   individual devices.

   IMPORTANT!!!
   The current BSC spec constrains the number of "endpoints" (which translates
   to mh devices/items) to 254 per xAP "device".  Because mh can support
   many more real (e.g., x10) or virtual (e.g., presence_item) devices than 254, 
   the current code and BSC.pm library implement the concept of "virtual (xap) device"
   It is very important that no more than 254 mh items/devices ever be added to 
   an individual BSC item.  You will note that the below code attempts to 
   group "sane" (and similar) classes of mh items.  Make sure that this number
   is never exceeded.

   The xAP steering group is aware of the limitation discussed above and plans
   to dramatically increase the allowed number of endpoints.  Once that occurs,
   the requirement for "virtual xAP devices" will go away and the below code 
   as well as BSC.pm will be revised to reflect the change.  The implication will
   be a change to the source and target xAP addresses.

=cut

# mh_parms:
# bsc_info_interval = 10
# bsc_prefer_abstract = 0

my $bsc_info_interval = $::config_parms{bsc_info_interval};
$bsc_info_interval = 10
  if !$bsc_info_interval;    # send out BSC info messages every 10 minutes

my $bsc_prefer_abstract = $::config_parms{bsc_prefer_abstract};
$bsc_prefer_abstract = 0
  unless $bsc_prefer_abstract;   # support x10 devices in favor of abstract ones

if ($::Startup) {
    $bsc_x10_device      = new BSCMH_Item(BSCMH_Item::DEVICE_TYPE_X10);
    $bsc_abstract_device = new BSCMH_Item(BSCMH_Item::DEVICE_TYPE_ABSTRACT);
    $bsc_presence_device = new BSCMH_Item(BSCMH_Item::DEVICE_TYPE_PRESENCE);

    if ( !($bsc_prefer_abstract) ) {

        # register each device type that will be supported
        # TO-DO: provide an easy method for the user to select
        #        the device types to be supported other than commenting the below in/out
        $bsc_x10_device->register_device_type(BSCMH_Item::X10_ITEM);
        $bsc_x10_device->register_device_type(BSCMH_Item::X10_APPLIANCE);
        $bsc_x10_device->register_device_type(BSCMH_Item::X10_TRANSMITTER);
        $bsc_x10_device->register_device_type(BSCMH_Item::X10_RF_RECEIVER);
        $bsc_x10_device->register_device_type(BSCMH_Item::X10_GARAGE_DOOR);
        $bsc_x10_device
          ->register_device_type(BSCMH_Item::X10_IRRIGATION_CONTROLLER);
        $bsc_x10_device->register_device_type(BSCMH_Item::X10_SWITCHLINC);
        $bsc_x10_device->register_device_type(BSCMH_Item::X10_TEMPLINC);
        $bsc_x10_device->register_device_type(BSCMH_Item::X10_OTE);
        $bsc_x10_device->register_device_type(BSCMH_Item::X10_SENSOR);
    }
    else {
        # TO-DO: extend the support for abstract device types
        $bsc_abstract_device->register_device_type(BSCMH_Item::MOTION_ITEM);
        $bsc_abstract_device->register_device_type(BSCMH_Item::LIGHT_ITEM);
    }

    # TO-DO handle ability to enable/disable presence monitoring
    if ( 1 == 1 ) {
        $bsc_presence_device
          ->register_device_type(BSCMH_Item::PRESENCE_MONITOR);
    }

    # initiate sending a block of info messages for all devices handled by this BSCMH item
    &send_info;

    # and, create a timer to do same
    $bsc_info_timer = new Timer;

    # set the timer to run send_info forever
    $bsc_info_timer->set( $bsc_info_interval * 60, \&send_info, -1 );

    # to register individual objects, do something like:
    # $bsc_x10_device->register_obj('some_mh_x10_item_name',BSCMH_Item::DEVICE_TYPE_X10);
}

sub send_info {
    $bsc_x10_device->do_info();
    $bsc_abstract_device->do_info();
    $bsc_presence_device->do_info();
}

