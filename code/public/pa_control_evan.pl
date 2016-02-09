# Category=Music

my @speakers;
my $weeder_address =
  'A';    # edit to match weeder dip switch setting (new weeder only)
my $port_name =
  'weeder';    # edit to match weeder serial port name from mh.private.ini

## EDIT THE FOLLOWING LINE WITH YOUR ROOM NAMES.
## MUST MATCH SERIAL ITEM DEFINITIONS IN PA_ITEMS.PL
@speakers = ( $pa_kitchen, $pa_server, $pa_master );

$v_pa_speakers = new Voice_Cmd('speakers [on,off]');
$v_pa_speakers->set_info('Turn all the PA speakers on/off');

# turn all speakers on/off
if ( $state = said $v_pa_speakers) {
    for $ref (@speakers) {
        $state = ( $state eq 'on' ) ? ON : OFF;
        $ref->{state}          = $state;
        $ref->{while_speaking} = 0;
    }
    &set_weeder;
}

# Add a fail-safe turn speakers off timer

$pa_speaker_timer = new Timer;

#set $pa_speaker_timer 60 if state_now $mh_speakers eq ON;
run_voice_cmd 'speakers off' if expired $pa_speaker_timer;

my $pa_action_flag = 0;

# Set flag to turn off speakers after speaking
if ( state_now $mh_speakers eq OFF ) {
    unset $pa_speaker_timer;
    print "mh_speakers now off\n";
    for $ref (@speakers) {

        #        if ($ref->{while_speaking}) {
        $pa_action_flag = 1;
        $ref->{state} = OFF;
        print "Off: " . $ref->{object_name} . "\n";    #uncomment for debugging
        $ref->{while_speaking} = 0;

        #        }
    }
    &set_weeder if ($pa_action_flag);
}

# Do the business of sending the proper on/off data to the weeder card
sub set_weeder {
    my ( $bit, $byte_string );
    $pa_action_flag = 0;
    my $state;
    for $bit ( reverse( 'A' .. 'H' ) ) {
        if ( $ref = &Serial_Item::serial_item_by_id("AL$bit") ) {
            $state = $ref->{state};

            #$state = state $ref;

        }
        else {
            $state = OFF;
        }
        print "db bit=$bit state=$state\n";    # uncomment for debugging
        $byte_string .= ( $state =~ /on/i ) ? 1 : 0;
    }
    print "db byte string: $byte_string\n";

    my $send = $weeder_address . "W"
      . sprintf( "%0.2x", unpack( 'C', pack( 'B8', $byte_string ) ) );
    print "sending $send to the weeder card\n";    # uncomment for debugging

    &Serial_Item::send_serial_data( $port_name, $send . "\r" )
      if $main::Serial_Ports{$port_name}{object};

    set $pa_speaker_timer 60;
}

# Stuff to flag which rooms to turn on based on "rooms=" parm in speak command
&Speak_pre_add_hook( \&pa_stub ) if $Reload;
&Play_pre_add_hook( \&pa_stub )  if $Reload;

sub pa_stub {
    my (%parms) = @_;
    my $mode = $parms{mode};
    $mode = state $mode_mh unless $mode;

    #   print "db PA MODE: $mode\n";
    return if $mode eq 'mute' or $mode eq 'offline';

    my $rooms = $parms{rooms};
    if ( $mh_speakers->{rooms} ) {
        $rooms = $mh_speakers->{rooms};
        $mh_speakers->{rooms} = '';
    }
    my $room;
    $rooms = 'all' unless $rooms;
    for $room ( split( ',', $rooms ) ) {
        $room = lc $room;
        if ( $room =~ /all/i ) {
            for $ref (@speakers) {
                $ref->{while_speaking} = 1 unless ON eq $ref->state;
            }
        }
        else {
            no strict 'refs';
            ${"pa_$room"}->{while_speaking} = 1;
            print "Room: $room\n";    # uncomment for debugging

        }
    }
################## Moved this stuff into pa_stub to allow timing control of relay w.r.t. sound
    for $ref (@speakers) {
        if ( $ref->{while_speaking} ) {
            $pa_action_flag = 1;
            print "On: " . $ref->{object_name} . "\n"; # uncomment for debugging
            $ref->{state} = ON unless $ref->{sleeping};
        }
    }
    &set_weeder;
    select undef, undef, undef, 0.2; # adjust to delay sound until relays are on
##################
}

=begin comment
sub pa_sleep_mode {
    my($who, $mode) = @_;
    my @refs;
    push(@refs, $pa_kitchen) if $who eq 'parents' or $who eq 'all';
  #  push(@refs, $pa_nick,    $pa_zack)   if $who eq 'kids' or $who eq 'all';
    my $ref;
    for $ref (@refs) {
        $ref->{sleeping} = $mode;
    }
}
=cut

=begin comment
&Serial_match_add_hook(\&serial_stub) if $Reload;

                # This is called by the main loop whenever a serial item is triggered
my %rooms_by_event = qw( XP bedroom XM family);
sub serial_stub {
    my ($ref, $state, $event) = @_;
   print "db room=$ref->{room} event=$event ref=$ref\n";

    my $object_name = substr $$ref{object_name}, 1;

                # Set the room reference
    my $room = substr($event, 0, 2);
    $ref->{room} = $rooms_by_event{$room};

                # Speak the object name if it was a manual keypad entry
    return unless $state and $state eq 'manual';
    my $object_type = ref $ref;
    return unless $object_type eq "X10_Item";
    return unless $object_name;

    $object_name =~ s/_/ /g;
    $room = $ref->{room};
    $room = 'all' unless $room;
    speak("rooms=$room $object_name");
}
=cut
