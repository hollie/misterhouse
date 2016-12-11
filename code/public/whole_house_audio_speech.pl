# This is a user-code file for Misterhouse that supports importance for
# speech events as well as the ability to send speech to one or more
# rooms through a whole-house audio system.

# You can get the most current version of this file and other files related
# whole-house music/speech setup here:
#   http://www.linux.kaybee.org:81/tabs/whole_house_audio/

# This file assumes you have one or more properly installed and configured
# sound cards with Linux ALSA drivers.  See my sample asound.conf for how
# I have four stereo outputs with a Delta M-Audio 410.

# This file also assumes you are using my VirtualAudio.pm for the management
# of your whole-house audio system.

# Also, this file assumes you are using my AlsaPlayer.pm to handle any MP3
# players sharing the audio system, but it could be modified easily to support
# other MP3 players.

# This code also assumes you are using a Netstreams Musica whole-house audio
# system and my Musica.pm module to control it.  But it also could be modified
# fairly easily to support another whole-house audio system.

# Finally, this provides optional integration with occupancy/presence tracking
# using Jason Sharpee's Occupancy_Monitor.pm and Presence_Monitor.pm.

# Importance (only applies to specified rooms if rooms are specified)
#    debug: only speak into zones tuned to speech-only
#    notice: turns on zones in occupied rooms if necessary, reduces volume
#       of (or pauses) MP3s and talks over them if necessary.
#    important: Turns on (and changes sources for) all necessary zones,
#       talks over MP3s after volume is decreased or player is paused
#    urgent: Turns on (and changes sources for) all zones, talks
#       over MP3s after volume is decreased or player is paused
#       * ignores any muting restrictions

#####################################################################
# noloop=start

#####################################################################
# Begin Configuration section
#####################################################################

# I find it best if the festival output is converted to 44100 since
# my asound.conf is set up for that bitrate.  Set to 0 to disable
# bitrate modification with sox (reduces speech delay when disabled)
#my $bitrate = 44100;
my $bitrate = 0;

# Same thing here -- I converted this to a PCM WAV file at 44100
# Set to a blank string if you want to disable a pre-speak wav file
my $pre_speak_wav = '/mh/data/trek.wav';

# If the wav file is played before festival runs, you get the sound
# immediately (i.e. if it is in response to some other event), but
# there may be a few seconds delay before the speech starts.  On the
# other hand, if you play the wav after Festival generates the speech,
# there may be a few seconds delay before you hear anything.
my $wav_before_festival = 1;

# If you want certain zones to turn on only if certain rooms are occupied,
# you can list zone names and then associated presence objects here
my %presence_by_room =
  ( 'kitchen' => [ $om_presence_kitchen, $om_presence_family_room ] );

# Define your alsa channels here (leave the undef there to fill the space
# of the 0 array index).  These should be listed in the same order that
# they are connected to you whole-house audio system
my @alsa_channels =
  ( undef, 'channel12', 'channel34', 'channel56', 'channel78' );

# Provide list of rooms to be used when speech goes to 'all' rooms
# kitchen, master_bed, outside, office, kirks_room, guest_room
my @all_rooms = ('kitchen');

# Provide the Musica zone object for each room
my %zones_by_room = ( 'kitchen' => $music_kitchen );

# Provide the volume level to be used when zone is turned on for speech
# for each Musica zone object
my %speech_volume = ( $music_kitchen => 26 );

# Set to 0 to reduce volume of AlsaPlayer MP3s only, or 1 to pause
my $pause_mp3s = 1;

#####################################################################
# End Configuration section
#####################################################################

my %zone_recovery;
my @restore_volume;
my %delay;
my %last_played;
my $SpeechCount = 0;
my @wav_players = (
    undef,
    new Process_Item(),
    new Process_Item(),
    new Process_Item(),
    new Process_Item()
);

sub play_audio {
    my ( $output, $file ) = @_;
    my $cmd;
    if ( $bitrate and $file =~ /speak_festival/ ) {
        $cmd =
          "sox '$file' -r $bitrate '$file.new.wav'; /usr/bin/aplay -D '$alsa_channels[$output]' '$file.new.wav'";
    }
    else {
        $cmd = "/usr/bin/aplay -D '$alsa_channels[$output]' '$file'";
    }
    if ( $wav_players[$output]->done() ) {
        print_log "Speech: running command '$cmd'";
        $wav_players[$output]->set($cmd);
        $wav_players[$output]->start();
    }
    else {
        print_log "Speech: queueing command '$cmd'";
        $wav_players[$output]->add($cmd);
    }
}

sub pre_play_hook {
    my ($parms) = @_;
    if ( $$parms{'use_source'} ) {

        #$$parms{'sound_program'} = "aplay -D '$alsa_channels[$$parms{'use_source'}]'";
    }
    else {
        $$parms{'sound_program'} = "aplay -D 'channelALL'";
    }
}

sub is_room_occupied {
    my ($room) = @_;
    return 0 unless ( $presence_by_room{$room} );
    foreach ( @{ $presence_by_room{$room} } ) {
        if ( $_->state() eq 'occupied' ) {
            return 1;
        }
    }
    return 0;
}

sub check_for_pause {
    my ($zone_num) = @_;
    my $source = $audio_router->get_real_source_number_for_zone($zone_num);
    unless ( $players[$source]->is_paused() ) {
        if ($pause_mp3s) {
            print_log "Speech: Pausing $source MP3 player...";
            $players[$source]->pause();
        }
        else {
            print_log "Speech: Reducing volume of $source MP3 player...";
            $players[$source]->volume('0.2');
        }
        print_log "Speech: restore_volume[$source]=$restore_volume[$source]";
    }
    $restore_volume[$source]++;
    return $source;
}

# Handles setting up speech to one particular room
sub pre_handle_room {
    my ( $room, $importance, $only_if_occupied ) = @_;
    my $source = 0;
    return 0 unless ( $zones_by_room{$room} );
    my $zone_num = $zones_by_room{$room}->get_zone_num();
    print_log
      "Speech: Checking room $room(zone=$zone_num): importance=$importance, only_if_occupied=$only_if_occupied";
    print_log "Speech:    name of current virtual source: "
      . $audio_router->get_virtual_source_name_for_zone($zone_num);
    print_log "Speech:    current source: "
      . $zones_by_room{$room}->get_source();
    if ( $audio_router->get_virtual_source_name_for_zone($zone_num) eq
        'v_voice' )
    {
        # Always play if room is already tuned in...
        $source = $audio_router->get_real_source_number_for_zone($zone_num);
        print_log
          "Speech:    Room $room(zone=$zone_num): already on voice (source=$source)";

        # Check for pause in case I'm playing MP3s through the Misterhouse web-based jukebox
        &check_for_pause($zone_num);
    }
    elsif ( ( $zones_by_room{$room}->get_source() > 0 )
        and ( $importance ne 'debug' ) )
    {
        # Zone is already on another virtual source...
        print_log "Speech:    mute=" . $Save{"mute_$room"};
        if ( ( $importance eq 'urgent' ) or ( not $Save{"mute_$room"} ) ) {
            my $vsource =
              $audio_router->get_virtual_source_obj_for_zone($zone_num);
            print_log "Speech:    vsource=$$vsource{name}";
            if ( $vsource->get_data('playlist') ) {

                # Source is playing MP3s...
                $source = &check_for_pause($zone_num);
                print_log
                  "Speech:    Room $room(zone=$zone_num): listening to MP3s. (source=$source)";
            }
            elsif (( $importance eq 'urgent' )
                or ( $importance eq 'important' ) )
            {
                # Not tuned to voice or MP3s
                if ( not $only_if_occupied or &is_room_occupied($room) ) {
                    $zone_recovery{$room}->{'vsource'} =
                      $audio_router->get_virtual_source_name_for_zone(
                        $zone_num);
                    $source = $audio_router->select_virtual_source( $zone_num,
                        'v_voice' );
                    $zones_by_room{$room}->set_source($source)
                      if ( $source > 0 );
                    print_log
                      "Speech:    Room $room(zone=$zone_num): listening to something else, switching to voice source. (source=$source";
                    $zone_recovery{$room}->{'source'} = $source;
                    $zone_recovery{$room}->{'zone'}   = $zone_num;
                }
            }
        }
    }
    elsif ( $importance ne 'debug' ) {

        # Zone is off... turn on unless debug importance
        if ( not $only_if_occupied or &is_room_occupied($room) ) {
            if ( ( $importance eq 'urgent' ) or ( not $Save{"mute_$room"} ) ) {
                $source =
                  $audio_router->select_virtual_source( $zone_num, 'v_voice' );
                if ( $source > 0 ) {
                    print_log
                      "Speech:    Room $room(zone=$zone_num): turning on to source $source";
                    $zones_by_room{$room}->set_source($source);
                    if ( $speech_volume{ $zones_by_room{$room} } ) {
                        $zones_by_room{$room}->set_volume(
                            $speech_volume{ $zones_by_room{$room} } );
                    }
                    $zones_by_room{$room}->delay_off(120);
                }
            }
        }
    }
    if ( ($wav_before_festival) and ( $source > 0 ) and $pre_speak_wav ) {
        if ( $wav_players[$source]->done() ) {
            if ( $last_played{$source} ne "${Hour}.${Minute}.${Second}" ) {
                &play_audio( $source, $pre_speak_wav );

                #play('use_source' => $source, 'file' => $pre_speak_wav);
                $last_played{$source} = "${Hour}.${Minute}.${Second}";
            }
        }
    }
    print_log
      "Speech:    returning source $source for room $room(zone=$zone_num)";
    return $source;
}

sub pre_speak_hook {
    my ($parms) = @_;
    print_log
      "Speech: pre_speak_hook importance=$$parms{importance}, rooms=[$$parms{rooms}]";
    my $only_if_occupied = 1;
    my $importance       = $$parms{'importance'};
    unless ($importance) {
        $importance = 'debug';
    }

    # Determine in which rooms we want to speak
    my @rooms = @all_rooms;
    if ( $$parms{'rooms'} and ( $$parms{'rooms'} ne 'all' ) ) {
        $only_if_occupied = 0;
        @rooms = split /,/, $$parms{'rooms'};
    }
    if ( $importance eq 'urgent' ) {
        $only_if_occupied = 0;
    }

    # Now, check each room and store the whole-house audio system
    # source to be used for each room
    my $source;
    my %use_players;
    foreach (@rooms) {
        if ( $source = &pre_handle_room( $_, $importance, $only_if_occupied ) )
        {
            print_log "Speech: got source $source for room $_";
            $use_players{$source}++;
        }
    }

    # Now generate string of sources that need to be spoken to
    my $player_str = '';
    foreach ( keys %use_players ) {
        if ( $use_players{$_} ) {
            $player_str .= ",$_";
        }
    }
    $player_str =~ s/^,//;
    print_log "Speech: player string is: $player_str";
    if ($player_str) {
        $SpeechCount++;
        $parms->{'to_file'} =
          "$config_parms{html_alias_cache}/speak_festival.${Hour}.${Minute}.${Second}.${SpeechCount}.wav";
        $parms->{'use_players'} = $player_str;
    }
    else {
        $parms->{'no_speak'} = 1;
    }
}

sub post_speak_hook {
    my (%parms) = @_;
    while ( not -f $parms{to_file} ) {
        print "File $parms{to_file} not there yet!\n";
        select( undef, undef, undef, 0.1 );
    }
    foreach ( split /,/, $parms{'use_players'} ) {
        if ( not $wav_before_festival and $pre_speak_wav ) {
            if ( $last_played{$_} ne "${Hour}.${Minute}.${Second}" ) {
                &play_audio( $_, $pre_speak_wav );
                $last_played{$_} = "${Hour}.${Minute}.${Second}";
            }
        }
        &play_audio( $_, $parms{to_file} );
    }
}

# noloop=stop
#####################################################################

if ($New_Hour) {
    system( 'find', "$config_parms{html_alias_cache}",
        '-mmin', '+5', '-exec', 'rm', '-f', '{}', ';' );
}

if ($Reload) {
    &Speak_parms_add_hook( \&pre_speak_hook );
    &Speak_post_add_hook( \&post_speak_hook );
    &Play_parms_add_hook( \&pre_play_hook );
}

# Watch for completion...
for ( my $source = 1; $source <= $#wav_players; $source++ ) {
    if ( $wav_players[$source]->done_now() ) {
        print_log
          "Speech:    speech to source $source is complete (restore_volume=$restore_volume[$source]).";
        if ( $restore_volume[$source] ) {
            if ($pause_mp3s) {
                print_log "Speech:    Unpausing MP3s on source $source";
                $players[$source]->unpause();
            }
            else {
                print_log
                  "Speech:    Increasing volume of MP3s on source $source";
                $players[$source]->volume('1.0');
            }
            $restore_volume[$source] = 0;
        }
        foreach my $room ( keys %zone_recovery ) {
            if ( $zone_recovery{$room}->{'source'} == $source ) {
                if ( $zone_recovery{$room}->{'vsource'} ) {
                    print_log
                      "Speech:    returning $room to virtual source $zone_recovery{$room}->{'vsource'}";
                    my $newsource = $audio_router->select_virtual_source(
                        $zone_recovery{$room}->{'zone'},
                        $zone_recovery{$room}->{'vsource'}
                    );
                    $zones_by_room{$room}->set_source($newsource)
                      if ( $newsource > 0 );
                }
                delete $zone_recovery{$room};
            }
        }
    }
}

if ( $state = state_changed $mode_guest) {
    if ( $state eq 'disabled' ) {
        $Save{'mute_guest_room'} = 0;
    }
    else {
        $Save{'mute_guest_room'} = 1;
    }
}

$say_urgent = new Voice_Cmd 'Say Something Urgent';
if ( said $say_urgent) {
    print_log "Speech: Saying something urgent";
    speak(
        rooms      => 'all',
        importance => 'urgent',
        text       => 'This is an urgent message'
    );
}

$say_important = new Voice_Cmd 'Say Something Important';
if ( said $say_important) {
    print_log "Speech: Saying something important";
    speak(
        rooms      => 'all',
        importance => 'important',
        text       => 'This is an important message'
    );
}

$say_notice = new Voice_Cmd 'Say Something Possibly Worth Mentioning';
if ( said $say_notice) {
    print_log "Speech: Saying something at 'notice' level";
    speak(
        rooms      => 'all',
        importance => 'notice',
        text       => 'This may be an interesting message'
    );
}

$say_debug = new Voice_Cmd 'Say Something Not Worth Mentioning';
if ( said $say_debug) {
    print_log "Speech: Saying something at 'debug' level";
    speak(
        rooms      => 'all',
        importance => 'debug',
        text       => 'This is probably not an interesting message'
    );
}

$say_several = new Voice_Cmd 'Say Several Things';
if ( said $say_several) {
    speak(
        rooms      => 'all',
        importance => 'important',
        text       => 'this is the first message'
    );
    speak(
        rooms      => 'all',
        importance => 'important',
        text       => 'this is the second message'
    );
    speak(
        rooms      => 'all',
        importance => 'important',
        text       => 'this is the third message'
    );
    speak(
        rooms      => 'all',
        importance => 'important',
        text       => 'this is the fourth message'
    );
}

