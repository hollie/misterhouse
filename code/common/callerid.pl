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
#@  callerid_port      = COM1
#@  callerid_name      = line 1 (or match serial_xyz name if using a proxy)
#@  callerid_type      = type (e.g. netcallerid, rockwell, zyxel, ncid)  See lib/Telephony_Interface.pm for options.
#@  callerid_format    =      (number only)
#@  callerid_handlers  = comma seperated list (e.g. default, stopper, outlook) See callerid.pl for options.
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
$cid_interface1 = new Telephony_Interface($config_parms{callerid_name},  $config_parms{callerid_port},  $config_parms{callerid_type});
$cid_item       = new CID_Lookup($cid_interface1);

if ($Startup and defined($config_parms{callerid2_name})) {
    print_log("Creating and adding 2nd Caller ID interface");
	$cid_interface2 = new Telephony_Interface($config_parms{callerid2_name}, $config_parms{callerid2_port}, $config_parms{callerid2_type});
	{ $cid_item      -> add           ($cid_interface2); } # the brace brackets keep mh from pulling this line out of the loop
}

#$PhoneKillerPort = new  Telephony_Item($config_parms{callerid_port});

# Examples of other interfaces
#cid_interface3 = new Telephony_Identifier('Identifier', $config_parms{identifier_port});
$PhoneKillTimer = new Timer;
                                # These objects will enable cid logging and announcing
$cid_log        = new CID_Log($cid_item);    # Enables logging
$cid_server     = new CID_Server($cid_item); # Enables YAC, Acid, and xAP/xPL callerid clients

# Add one of these for each YAC client:  http://www.sunflowerhead.com/software/yac
#$cid_client1 = new CID_Server_YAC('localhost');

                       # $format1 includes City and State, if out of Town/State
$cid_announce  = new CID_Announce($cid_item, 'Call from $format1');
#$cid_announce  = new CID_Announce($cid_item, 'Call from $first $last');

                                # Setup commands we can use to run tests without the modem
$cid_interface_test = new Voice_Cmd('Test callerid [0,1,2,3,4,5,6,7,8,9,offhook,UKknown,UK unknown]');
if (defined($state = state_now $cid_interface_test)) {
    set_test $cid_interface1 'RING'                                                             if $state == 0;
    set_test $cid_interface1 'DATE = 1215 TIME = 1249 NMBR = 5071234560 NAME = WINTER LAUREL  ' if $state == 1;
    set_test $cid_interface1 'DATE = 1215 TIME = 1249 NAME = BUSH, GEORGE W  NMBR = 2021230001' if $state == 2;
    set_test $cid_interface2 '###DATE12151248...NMBR2021230002...NAMEBUSH GEORGE +++'           if $state == 3;
    set_test $cid_interface1 'DATE = 1215 TIME = 1249 NMBR = 4061230003      NAME = '           if $state == 4;
    set_test $cid_interface1 'DATE = 1215 TIME = 1249 NAME = BUSH GEORGE W   NMBR = 2021230003' if $state == 5;
    set_test $cid_interface1 'DATE = 1215 TIME = 1249 NAME = BUSH,GEORGE W   NMBR = 2021230003' if $state == 6;
    set_test $cid_interface2 '###DATE01061252...NMBR...NAME-UNKNOWN CALLER-+++'                 if $state == 7;
    set_test $cid_interface2 '###DATE01061252...NMBR...NAME-PRIVATE CALLER-+++'                 if $state == 8;
    set_test $cid_interface2 '###DATE...NMBR...NAME MESSAGE WAITING+++'                         if $state == 9; # Netcallerid msg watiing

    if ($state == 'offhook'){
	#start $PhoneKillerPort;
	set $PhoneKillTimer 3;
#	&Serial_Item::send_serial_data($config_parms{callerid_name}, 'ATA');
	set $cid_interface1 'offhook';
	#stop $PhoneKillerPort;
    }
    set_test $cid_interface1 'DATE TIME=12/27 15:14 NBR=100 END MSG'         if $state eq 'UK known'; # 100 needs to be set as a recognised number
    set_test $cid_interface1 'DATE TIME=12/27 15:14 NBR=02075849648 END MSG' if $state eq 'UK unknown';

}

                                # Allow for user specified hooks
if ($Reload) {
    if (!$config_parms{callerid_handlers}) {
        $config_parms{callerid_handlers} = "default,stopper";
    }

    for (split ',', $config_parms{callerid_handlers}) {
        if (/stopper/i) { $cid_item -> tie_event('phonestopper($state, $object)', 'cid'); }
        if (/outlook/i) { $cid_item -> tie_event('AddCidToOutlookContacts($state, $object)', 'cid'); }
        if (/default/i) { $cid_item -> tie_event('cid_handler($state, $object)', 'cid'); }
    }
}

sub phonestopper{
	my ($p_state, $p_setby) = @_;
	my $rejecttest = $p_setby->category();
	if ($rejecttest eq "reject"){
		print_log "Ending Incomimg Phone Call.";
		speak "This call should be rejected";
		set $PhoneKillTimer 3;
#		&Serial_Item::send_serial_data($config_parms{callerid_name}, 'ATA');
		set $cid_interface1 'offhook';
	}
}

if (expired $PhoneKillTimer){
#   &Serial_Item::send_serial_data($config_parms{callerid_name}, 'ATH');
    set $cid_interface1 'onhook';
    print_log "Setting Phone Back To Hook";
}

sub cid_handler {
	my ($p_state, $p_setby) = @_;
	print_log "Callerid: " . $p_setby->cid_name() . ' ' . $p_setby->cid_number();
    my $msg = "\n\nPhone Call on $Time_Date";
	$msg .= "\nLine: "   . $p_setby->address();
	$msg .= "\nFirst: "  . $p_setby->first();
	$msg .= "\nMiddle: " . $p_setby->middle();
	$msg .= "\nLast: "   . $p_setby->last();
	$msg .= "\nCat: "    . $p_setby->category();
	$msg .= "\nType: "   . $p_setby->type();
	$msg .= "\nArea: "   . $p_setby->areacode();
	$msg .= "\nPref: "   . $p_setby->prefix();
	$msg .= "\nSuff: "   . $p_setby->suffix();
	$msg .= "\nCity: "   . $p_setby->city();
	$msg .= "\nState: "  . $p_setby->cid_state();
	$msg .= "\nRings: "  . $p_setby->ring_count();
    display text => $msg, time => 0, title => 'CallerID log', width => 35, height => 30,
      window_name => 'CallerID', append => 'top', font => 'fixed';
#   play $p_setby->file();
    $p_setby->ring_count(0);
}


#----------------------------------------------------------------------------
# Look the caller ID number up in all telephone number fields of
# the Outlook contacts database. If a matching contact is not found,
# and the call type is not "reject", create a new Outlook contact entry.
# 
# Using this routine will make sure all phone numbers get entered into the 
# Outlook contact database. 
# 
# History
# 2007/11/22   Richard Shanks    First created
#----------------------------------------------------------------------------
sub AddCidToOutlookContacts($$) {
   my ($p_state, $p_setby) = @_;

   use Win32::OLE::Const 'Microsoft Outlook';
      $Win32::OLE::Warn = 2;    # Warn on error 

   # List of outlook fields that contain phone numbers
   my @OutlookPhoneFields = qw( Business2TelephoneNumber
                                BusinessTelephoneNumber
                                CallbackTelephoneNumber
                                CarTelephoneNumber
                                CompanyMainTelephoneNumber
                                Home2TelephoneNumber
                                HomeTelephoneNumber
                                MobileTelephoneNumber
                                OtherTelephoneNumber
                                PrimaryTelephoneNumber
                              );

   # Prefix to use on last name. Provides easy identification of new
   # entries automatically added to Outlook contacts
   my $CidPrefix = "__CID ";
   my $CidNumber = $p_setby->cid_number();

   my $Outlook = Win32::OLE->GetActiveObject('Outlook.Application')
              || Win32::OLE->new('Outlook.Application', 'Quit');

   my $Mapi     = $Outlook->GetNamespace('MAPI');
   my $Contacts = $Mapi->GetDefaultFolder(olFolderContacts)->{Items};
   my $Count    = $Contacts->{Count};

   # For each contact
   for my $i (1 .. $Count) {
      my $Contact = $Contacts->Item($i);

      # For each phone number field
      for my $Field (@OutlookPhoneFields){
         next unless ($Contact->{$Field});

         my $Num = $Contact->{$Field};
         $Num =~ s/[^\d]//g;        # Leave only digits

         # Found a matching number? (Compare this way as country code has been stripped from CidNumber)
         if ($Num =~ /$CidNumber/) {
            my $LogString   = "Outlook: Contact found $Contact->{LastNameAndFirstName}   $Contact->{$Field}";
            my $SpeakString = "Found Outlook contact $Contact->{FirstName} $Contact->{LastName}";
            $Field =~ s/TelephoneNumber//;
            $LogString   .= " $Field";
            $SpeakString .= " $Field";
            print_log $LogString;
            speak $SpeakString;

            # All done
            return;
         }
      }
   }

   # Add number as a new contact
   if ($p_setby->category() ne "reject"){
      my $NewContact = $Mapi->GetDefaultFolder(olFolderContacts)->Items->Add();
      $NewContact->{LastName}               = $CidPrefix.ucfirst(lc($p_setby->last()));
      $NewContact->{FirstName}              = ucfirst(lc($p_setby->first()));
      $NewContact->{MiddleName}             = uc($p_setby->middle());
      $NewContact->{HomeTelephoneNumber}    = $p_setby->cid_number();
      $NewContact->{HomeAddressCity}        = $p_setby->city();
      $NewContact->{HomeAddressState}       = $p_setby->cid_state();
      $NewContact->{SelectedMailingAddress} = 1;  # Select home address

      $NewContact->Save();
      print_log "Outlook: Added new Contact ".$p_setby->last()." ".$p_setby->first()." ".$p_setby->cid_number();
      speak "Added new Outlook contact ".$p_setby->first()." ".$p_setby->last();
   }
}

