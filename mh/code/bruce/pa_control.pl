# Category=Music


$v_pa_radio = new  Voice_Cmd('Music [on,off]');
$v_pa_radio-> set_info('Play the phone "music on hold" over the PA system');

if ($state = said $v_pa_radio) {
    set $pa_radio $state;
    run_voice_cmd "speakers $state";
}

                                # These are set in my items.pl
my @speakers = ($pa_study, $pa_family, $pa_shop, $pa_nick, $pa_bedroom, $pa_zack, $pa_living);

$v_pa_speakers = new  Voice_Cmd('speakers [on,off]');
$v_pa_speakers-> set_info('Turn all the PA speakers on/off');

                                # Add a fail-safe turn speakers off timer
$pa_speaker_timer = new Timer;
set $pa_speaker_timer 60 if state $mh_speakers eq ON;

if ($state = said $v_pa_speakers or expired $pa_speaker_timer) {
    $state = 'off' unless $state;
    for $ref (@speakers) {
        set $ref $state;
    }
}

                                # $mh_speakers set in mh/code/common/volume.pl
my $pa_action_flag;
if (state_now $mh_speakers eq ON) {
    $pa_action_flag = 0;
    &pa_sleep_mode('parents', $Save{sleeping_parents});
    &pa_sleep_mode('kids',    $Save{sleeping_kids});
    for $ref (@speakers) {
#       print "db pa ref=$ref ws=$ref->{while_speaking}\n";
        if ($ref->{while_speaking}) {
            $pa_action_flag = 1;
            $ref->{state} = ON unless $ref->{sleeping};
        }
    }
}

                                # See if we should turn any pa speakers OFF
if (state_now $mh_speakers eq OFF) {
    $pa_action_flag = 0;
    for $ref (@speakers) {
        if ($ref->{while_speaking}) {
            $pa_action_flag = 1;
            $ref->{state} = OFF;
            $ref->{while_speaking} = 0;
        }
    }
}

                                # Messy code to set the PA port by byte, not bit 
if ($pa_action_flag) {
    $pa_action_flag = 0;
    my ($bit, $byte_string);
#   for $bit ('A' .. 'H') {
    for $bit (reverse('A' .. 'H')) {
        if ($ref = &Serial_Item::serial_item_by_id("DBL$bit")) {
# nwb   if ($ref = &Serial_Item::serial_item_by_id("AL$bit")) {
            $state = $ref->{state};
        }
        else {
            $state = OFF;
        }
#   print "db bit=$bit state=$state\n";
        $byte_string .= ($state eq ON) ? 1 : 0;
    }
#   my $send = "DBWb" . $byte_string;
#   my $send = "DBW\$" . pack('B8', $byte_string) . "   ";   ... hmmm, when byte = 0000, end of sent record is not detected :(
    my $send = "DBWh" . sprintf("%0.2x", unpack('C', pack('B8', $byte_string)));
# nwb  $send = "AW"   . sprintf("%0.2x", unpack('C', pack('B8', $byte_string)));
#   print "\ndb byte_string=$byte_string send=$send...\n";

#    print "pa_control serial results: ", $main::serial_port->write($send . "\r"), ".\n";
#   $main::Serial_Ports{weeder}{object}->write($send . "\r")    if $main::Serial_Ports{weeder}{object};
    &Serial_Item::send_serial_data('weeder', $send . "\r") if $main::Serial_Ports{weeder}{object};

#    if (&main::write_socket("serial", " ",  $send . "\r")) {
#   print "Error writing to socket\n";
#    }

#    $digital_write_port_b->{id} = "DBW\$$byte";
#    set $digital_write_port_b;
}

&Serial_match_add_hook(\&serial_stub) if $Reload;

#sub serial_stub {
#    my ($ref, $state, $event) = @_;
#    my $name = substr $$ref{object_name}, 1;
#    print_log "$event: $name $state";
#}

                # This is called by the main loop whenever a serial item is triggered
my %rooms_by_event = qw( XH shop XJ zack XK study XM family  XN nick XO living XP bedroom);
sub serial_stub {
    my ($ref, $state, $event) = @_;
#   print "db room=$ref->{room} event=$event ref=$ref\n";

    my $object_name = substr $$ref{object_name}, 1;

                # Set the room reference
    my $room = substr($event, 0, 2);
    $ref->{room} = $rooms_by_event{$room};

                # Speak the object name if it was a manual keypad entry
    return unless $state and $state eq 'manual';
    my $object_type = ref $ref;
    return unless $object_type eq "X10_Item";
    return unless $object_name;
    return if     $ref->{no_log}; # Ignore motion sensors

    $object_name =~ s/_/ /g;
    $room = $ref->{room};
    $room = 'all' unless $room;
    speak("rooms=$room $object_name");
}

&Speak_pre_add_hook(\&pa_stub) if $Reload;
&Play_pre_add_hook (\&pa_stub) if $Reload;

sub pa_stub {
    my (%parms) = @_;
    my $rooms = $parms{rooms};
                                # This is another way of setting rooms (e.g. bruce/x10_keypads.pl)
    if ($mh_speakers->{rooms}) {
        $rooms = $mh_speakers->{rooms};
        $mh_speakers->{rooms} = '';
    }
    my $room;
                # Must use time for stuff like play where we can not detect when done
    $rooms = '' unless $rooms;
    for $room (split(',', $rooms)) {
        $room = lc $room;
        if ($room =~ /all/i) {
            for $ref (@speakers) {
                                # Lets skip outside pa speaker unless specified or it is after hours
                next if $ref->{object_name} =~ /family/ and 
                    ($room ne 'all_and_out' or time_greater_than '10 pm' or time_less_than '8 am');
                $ref->{while_speaking} = 1 unless ON eq $ref->state;
            }
        }
        else {
#           no strict 'refs';
#           ${"pa_$room"}->{while_speaking} = 1;
            eval "\${pa_$room}->{while_speaking} = 1";
        }
    }       
} 

sub pa_sleep_mode {
    my($who, $mode) = @_;
    my @refs;
    push(@refs, $pa_bedroom, $pa_living) if $who eq 'parents' or $who eq 'all';
    push(@refs, $pa_nick,    $pa_zack)   if $who eq 'kids' or $who eq 'all';
    my $ref;
    for $ref (@refs) {
        $ref->{sleeping} = $mode;
    }
}
