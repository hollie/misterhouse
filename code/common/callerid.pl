# Category=Phone

# $Date$
# $Revision$

use Telephony_Interface;
use CID_Lookup;
use CID_Log;
use CID_Announce;
use CID_Server;
use Telephony_Item;

#@ Uses a callerid device to announce and log incoming phone calls.
#@ Add these entries to your mh.ini file:
#@  callerid_port   = COM1
#@  callerid_name   = line 1 (or match serial_xyz name if using a proxy)
#@  callerid_type   = type (e.g. netcallerid, rockwell, zyxel, ncid)  See lib/Telephony_Interface.pm for options.
#@  callerid_format =      (number only)
#@ The NetCallerID device
#@ available <a href="http://www.electronicdiscountsales.com/shop/pub/1154299397_44598505.htm">here</a>
#@ will also do call waiting callerid (caller id even while you are on the phone).

=begin comment

 The NetCallerID interface will do callerid and call waiting id
 (tells you who is calling even you are on the phone).
 To enable call waiting id, you need to have this device
 in series with your phones.  If hooked in parallel, it will
 only do normal caller id. You also need the 'caller waiting id' service.

 Also see public/phone_identifier.pl for an example of another interface.

=cut

# Use this for each of your cid hardware interfaces
$cid_interface1 = new Telephony_Interface(
    $config_parms{callerid_name},
    $config_parms{callerid_port},
    $config_parms{callerid_type}
);
$cid_item = new CID_Lookup($cid_interface1);

my $cid_interface2;

if ( $Startup and defined( $config_parms{callerid2_name} ) ) {
    print_log("Creating and adding 2nd Caller ID interface");
    $cid_interface2 = new Telephony_Interface(
        $config_parms{callerid2_name},
        $config_parms{callerid2_port},
        $config_parms{callerid2_type}
    );
    {
        $cid_item->add($cid_interface2);
    }    # the brace brackets keep mh from pulling this line out of the loop
}

#$PhoneKillerPort = new  Telephony_Item($config_parms{callerid_port});

# Examples of other interfaces
#cid_interface3 = new Telephony_Identifier('Identifier', $config_parms{identifier_port});
$PhoneKillTimer = new Timer;

# These objects will enable cid logging and announcing
$cid_log = new CID_Log($cid_item);    # Enables logging
$cid_server =
  new CID_Server($cid_item);   # Enables YAC, Acid, and xAP/xPL callerid clients

# Add one of these for each YAC client:  http://www.sunflowerhead.com/software/yac
#$cid_client1 = new CID_Server_YAC('localhost');

# $format1 includes City and State, if out of Town/State
$cid_announce = new CID_Announce( $cid_item, 'Call from $format1' );

#$cid_announce  = new CID_Announce($cid_item, 'Call from $first $last');

# Setup commands we can use to run tests without the modem
$cid_interface_test = new Voice_Cmd(
    'Test callerid [0,1,2,3,4,5,6,7,8,9,offhook,UKknown,UK unknown]');
if ( defined( $state = state_now $cid_interface_test) ) {
    set_test $cid_interface1 'RING' if $state == 0;
    set_test $cid_interface1
      'DATE = 1215 TIME = 1249 NMBR = 5071234560 NAME = WINTER LAUREL  '
      if $state == 1;
    set_test $cid_interface1
      'DATE = 1215 TIME = 1249 NAME = BUSH, GEORGE W  NMBR = 2021230001'
      if $state == 2;
    set_test $cid_interface2
      '###DATE12151248...NMBR2021230002...NAMEBUSH GEORGE +++'
      if $state == 3;
    set_test $cid_interface1
      'DATE = 1215 TIME = 1249 NMBR = 4061230003      NAME = '
      if $state == 4;
    set_test $cid_interface1
      'DATE = 1215 TIME = 1249 NAME = BUSH GEORGE W   NMBR = 2021230003'
      if $state == 5;
    set_test $cid_interface1
      'DATE = 1215 TIME = 1249 NAME = BUSH,GEORGE W   NMBR = 2021230003'
      if $state == 6;
    set_test $cid_interface2 '###DATE01061252...NMBR...NAME-UNKNOWN CALLER-+++'
      if $state == 7;
    set_test $cid_interface2 '###DATE01061252...NMBR...NAME-PRIVATE CALLER-+++'
      if $state == 8;
    set_test $cid_interface2 '###DATE...NMBR...NAME MESSAGE WAITING+++'
      if $state == 9;    # Netcallerid msg watiing

    if ( $state == 'offhook' ) {

        #start $PhoneKillerPort;
        set $PhoneKillTimer 3;

        #	&Serial_Item::send_serial_data($config_parms{callerid_name}, 'ATA');
        set $cid_interface1 'offhook';

        #stop $PhoneKillerPort;
    }
    set_test $cid_interface1 'DATE TIME=12/27 15:14 NBR=100 END MSG'
      if $state eq 'UK known';    # 100 needs to be set as a recognised number
    set_test $cid_interface1 'DATE TIME=12/27 15:14 NBR=02075849648 END MSG'
      if $state eq 'UK unknown';

}

# Allow for user specified hooks
$cid_item->tie_event( 'cid_handler($state, $object)',  'cid' ) if $Reload;
$cid_item->tie_event( 'phonestopper($state, $object)', 'cid' ) if $Reload;

sub phonestopper {
    my ( $p_state, $p_setby ) = @_;
    my $rejecttest = $p_setby->category();
    if ( $rejecttest eq "reject" ) {
        print_log "Ending Incomimg Phone Call.";
        speak "This call should be rejected";
        set $PhoneKillTimer 3;

        #		&Serial_Item::send_serial_data($config_parms{callerid_name}, 'ATA');
        set $cid_interface1 'offhook';
    }
}

if ( expired $PhoneKillTimer) {

    #   &Serial_Item::send_serial_data($config_parms{callerid_name}, 'ATH');
    set $cid_interface1 'onhook';
    print_log "Setting Phone Back To Hook";
}

sub cid_handler {
    my ( $p_state, $p_setby ) = @_;
    print_log "Callerid: "
      . $p_setby->cid_name() . ' '
      . $p_setby->cid_number();
    my $msg = "\n\nPhone Call on $Time_Date";
    $msg .= "\nLine: " . $p_setby->address();
    $msg .= "\nFirst: " . $p_setby->first();
    $msg .= "\nMiddle: " . $p_setby->middle();
    $msg .= "\nLast: " . $p_setby->last();
    $msg .= "\nCat: " . $p_setby->category();
    $msg .= "\nType: " . $p_setby->type();
    $msg .= "\nArea: " . $p_setby->areacode();
    $msg .= "\nPref: " . $p_setby->prefix();
    $msg .= "\nSuff: " . $p_setby->suffix();
    $msg .= "\nCity: " . $p_setby->city();
    $msg .= "\nState: " . $p_setby->cid_state();
    $msg .= "\nRings: " . $p_setby->ring_count();
    display
      text        => $msg,
      time        => 0,
      title       => 'CallerID log',
      width       => 35,
      height      => 30,
      window_name => 'CallerID',
      append      => 'top',
      font        => 'fixed';

    #   play $p_setby->file();
    $p_setby->ring_count(0);
}
