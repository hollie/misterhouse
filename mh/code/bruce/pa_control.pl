# Category=Music


my @speakers = ($pa_study, $pa_family, $pa_shop, $pa_nick, $pa_bedroom, $pa_zack, $pa_living);

$v_pa_radio = new  Voice_Cmd('Music [on,off]');
$v_pa_radio-> set_info('Play the phone "music on hold" over the PA system');

if ($state = said $v_pa_radio) {
    set $pa_radio $state;
    run_voice_cmd "speakers $state";
}

$v_pa_speakers = new  Voice_Cmd('speakers [on,off]');
$v_pa_speakers-> set_info('Turn all the PA speakers on/off');

if ($state = said $v_pa_speakers) {
    foreach $ref (@speakers) {
	set $ref $state;
    }
}

my ($speaking_flag, $action_flag, $is_speaking);

				# See if we should turn any pa speakers ON

				# Note, a call to is_speaking seems to be expensive ... mip meter drops from
				# 220 to 170 with this call :(

				# Also, I think this helps avoid the following perl bug 
				# noted by perl ole dude jan.dubois@ibm.net (Jan Dubois) :
# When Perl initializes the OLE subsystem then OLE creates a message loop and a 
# hidden top level window for the current thread (Perl interpreter). Perl itself 
# never processes the message loop, but all OLE calls do (because OLE uses the 
# message loop to synchronize access to OLE objects). When *any* application tries 
# to start a DDE session it _sends_ WM_DDE_INITIATE to all top level application 
# windows (including the hidden window of the Perl thread). This sending happens 
# synchronously (send, not post) and the application wait to receive either an ACK 
# or a NAK from all the top level windows. 

# This means that the application will hang until it either times out or until the 
# Perl program spins its message loop by calling another OLE method or accessing 
# another OLE property. 

# In the latest version of Win32::OLE (from libwin32-0.12) I have added 
# Win32::OLE->Uninitialize() and Win32::OLE->SpinMessageloop  class methods. The 
# first can be called when you don't expect to do any more OLE work and the second 
# allows you to dispatch messages during long calculations. I'm investigating 
# delegating all OLE work to a second proxy thread, but that is messy and may take 
# some while to implement. 

$is_speaking =  &Voice_Text::is_speaking;

if (!$speaking_flag and ($is_speaking or active $speaking_timer)) {
    $speaking_flag = 1;
    $action_flag = 0;
    foreach $ref (@speakers) {
	if ($ref->{while_speaking}) {
	    $action_flag = 1;
	    $ref->{state} = ON unless $ref->{sleeping};
	}
    }
}

				# See if we should turn any pa speakers OFF
if ($speaking_flag and !($is_speaking or active $speaking_timer)) {
    $speaking_flag = 0;
    $action_flag = 0;
    foreach $ref (@speakers) {
	if ($ref->{while_speaking}) {
	    $action_flag = 1;
	    $ref->{state} = OFF;
	    $ref->{while_speaking} = 0;
	}
    }
}

				# Messy code to set the PA port by byte, not bit 
if ($action_flag) {
    $action_flag = 0;
    my ($bit, $byte_string);
#   for $bit ('A' .. 'H') {
    for $bit (reverse('A' .. 'H')) {
        if ($ref = &Serial_Item::serial_item_by_id("DBL$bit")) {
	    $state = $ref->{state};
	}
	else {
	    $state = OFF;
	}
#	print "db bit=$bit state=$state\n";
	$byte_string .= ($state eq ON) ? 1 : 0;
    }
#   my $send = "DBWb" . $byte_string;
#   my $send = "DBW\$" . pack('B8', $byte_string) . "   ";   ... hmmm, when byte = 0000, end of sent record is not detected :(
    my $send = "DBWh" . sprintf("%0.2x", unpack('C', pack('B8', $byte_string)));
#   print "\ndb byte_string=$byte_string send=$send...\n";

#    print "pa_control serial results: ", $main::serial_port->write($send . "\r"), ".\n";
    $main::Serial_Ports{weeder}{object}->write($send . "\r") if $main::Serial_Ports{weeder}{object};

#    if (&main::write_socket("serial", " ",  $send . "\r")) {
#	print "Error writing to socket\n";
#    }

#    $digital_write_port_b->{id} = "DBW\$$byte";
#    set $digital_write_port_b;
}

				# This is called by the main loop whenever a serial item is triggered
my %rooms_by_event = qw( XH shop XJ zack XK study XM family  XN nick XO living XP bedroom);
sub serial_stub {
    my ($ref, $state, $event) = @_;
#   print "db room=$ref->{room} event=$event ref=$ref\n";

				# Set the room reference
    my $room = substr($event, 0, 2);
    $ref->{room} = $rooms_by_event{$room};

				# Speak the object name if it was a manual keypad entry
    return unless $state eq 'manual';
    my $object_type = ref $ref;
    return unless $object_type eq "X10_Item";

    my $object_name = $ref->{usage_name};
    $object_name = substr($object_name, 1); # Drop the '$'
    $object_name =~ s/_/ /g;
    $room = $ref->{room};
    $room = 'all' unless $room;
    speak("rooms=$room $object_name");

}

$speaking_timer = new  Timer;

				# This is called by the main loop whenever speak is called
sub pa_stub {
    my ($rooms, $timer_amount) = @_;
    my $room;
#   print "db override pa_rooms stub rooms=$rooms timer=$timer_amount\n";
				# Must use time for stuff like play where we can not detect when done
    set $speaking_timer $timer_amount if $timer_amount;
    foreach $room (split(',', $rooms)) {
	$room = lc $room;
	if ($room eq 'all') {
	    foreach $ref (@speakers) {
		$ref->{while_speaking} = 1 unless ON eq $ref->state;
	    }
	}
	else {
	    no strict 'refs';
	    ${"pa_$room"}->{while_speaking} = 1;
	}	    
     } 
}

sub pa_sleep_mode {
    my($who, $mode) = @_;
    my @refs;
    push(@refs, $pa_bedroom, $pa_living) if $who eq 'parents' or $who eq 'all';
    push(@refs, $pa_nick,    $pa_zack)   if $who eq 'kids' or $who eq 'all';
    my $ref;
    foreach $ref (@refs) {
	$ref->{sleeping} = $mode;
    }
}
