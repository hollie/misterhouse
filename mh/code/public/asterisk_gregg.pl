# Category=Phone

use Telephony_Interface;
use CID_Lookup;
use CID_Log;
use CID_Announce;
use CID_Server;
use Telephony_xAP;
use xAP_Items;

#@ Intercepts and processes xap events: outgoing.callcomplete for DTMF 
#@ and incoming callwithcid for CID 


# create the asterisk telephony item instance
$ast_tel_item = new Telephony_xAP();

# get the xap object so that we can tie value convertors
my $xap_tel_info = $ast_tel_item->xap_item(); #noloop
# tie a value convertor for the "line" parameter
#   this is desirable because * reports VoIP line info as the connecting channel like:
#   IAX2/NuFone@some.ip.num@4569-some_num
$xap_tel_info->tie_value_convertor('line','&main::convertTelephonyValues($section,"line",$value)'); #noloop
$xap_tel_info->tie_value_convertor('phone','&main::convertTelephonyValues($section,"phone",$value)'); #noloop
# create the net callerid item instance - since we can use the call waiting feature
# which * doesn't support for FXO lines
$ncid_tel_item = new Telephony_Interface($config_parms{callerid_name}, $config_parms{callerid_port}, $config_parms{callerid_type});

# create the lookup object so that inbound and outbound numbers can be converted
# add both telephony interface items to it
$cid_look = new CID_Lookup($ast_tel_item);
$cid_look -> add($ncid_tel_item); #noloop

# create the logger to get both in and outbound info (note: outbound info isn't available
#  from the ncid
$cid_logger = new CID_Log($cid_look);

$cid_announce = new CID_Announce($cid_look, 'Call from $format1 on $address');

# tie OSD logic to a cid lookup state change
$cid_look->tie_event('osd_hook($cid_look)'); #noloop


sub convertTelephonyValues {
	my ($section,$key,$value) = @_;
	if ($section eq 'incoming.callwithcid') {
		if ($key eq 'line') {
			if (lc $value =~ /^iax2\/voicepulse/i) {
				return "Gregg-Business";
			} elsif (lc $value =~ /^iax2\/nufone/i) {
				return "Gregg-Business";
			} elsif (lc $value =~ /^iax2\/jnctn/i) {
				return "Gregg-Business";
			} elsif (lc $value =~ /^iax2\/iaxfwd/i) {
				return "Gregg-Personal";
			} elsif (lc $value =~ /^zap\/1-1/i) {
				return "Home";
			} elsif (lc $value =~ /^zap\/2-1/i) {
				return "Cindy-Business";
			} else {
				return undef;
			}
		} elsif ($key eq 'phone') {
			# junction networks adds a "+1" to all numbers--what were they thinking?
			if (length($value) > 10) {
				# need to strip off the last 10 chars
				return substr($value,length($value)-10,10);
			} else {
				return undef;
			}
		}
		print "got an incoming.callwithcid to process: $value\n";
	}
}

sub osd_hook {
	my ($cid_lookup) = @_;

	if (defined $cid_lookup && ($cid_lookup->state() =~ /^cid/i)) {	
	    my $osd_format;
	    $osd_format = $cid_lookup->cid_name();
            my $display_time;
	    # set the default display time to 30 secs (for callers that we know)
	    $display_time = 30;
	    if (($osd_format =~ /CALL/i or lc $osd_format =~ /unknown/i) and $cid_lookup->formated_number()) {
		# any callerid info that is unuseful like "unknown" or "ohio call" or "cellular call"
		# we'll instead display their phone number--which is *much* more useful
		$osd_format = $cid_lookup->formated_number();
		# and, display it longer since we may be dialing it back (or attempting to recall)
		$display_time = 60;
	    }
	    my $line;
	    $line = $cid_lookup->address();
	    my $line2 = $osd_format . " on " . $line;
	    $osd_format = "\\n" . $osd_format . " on " . $line;
	    &xAP::send('xPL','slimdev-slimserv.squeezebox',
		'osd.basic' => { command => 'write', delay => $display_time, text => $osd_format });
	}
}
