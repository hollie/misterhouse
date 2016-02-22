# Category = Entertainment

# You can get the most current version of this file and other files related
# whole-house music/speech setup here:
#   http://www.linux.kaybee.org:81/tabs/whole_house_audio/

# Here are my current .mht entries:
#MUSICA,        Musica
#MUSICA_ZONE,   music_kitchen,    Musica, 1
#MUSICA_SOURCE, music_source1,    Musica, 1
#MUSICA_SOURCE, music_source2,    Musica, 2
#MUSICA_SOURCE, music_source3,    Musica, 3
#MUSICA_SOURCE, music_source4,    Musica, 4

#VIRTUAL_AUDIO_ROUTER, audio_router, 6, 4
#VIRTUAL_AUDIO_SOURCE, v_classical,    audio_router
#VIRTUAL_AUDIO_SOURCE, v_romantic,     audio_router
#VIRTUAL_AUDIO_SOURCE, v_new_age,      audio_router
#VIRTUAL_AUDIO_SOURCE, v_kirk_mp3s,    audio_router
#VIRTUAL_AUDIO_SOURCE, v_pink_floyd,   audio_router
#VIRTUAL_AUDIO_SOURCE, v_rock,         audio_router
#VIRTUAL_AUDIO_SOURCE, v_tivo,         audio_router, 3|4
#VIRTUAL_AUDIO_SOURCE, v_pvr,          audio_router, 3|4
#VIRTUAL_AUDIO_SOURCE, v_dvd,          audio_router, 3|4
#VIRTUAL_AUDIO_SOURCE, v_tuner,        audio_router, 3|4
#VIRTUAL_AUDIO_SOURCE, v_internet,     audio_router, 3|4
#VIRTUAL_AUDIO_SOURCE, v_voice,        audio_router

# noloop=start
$IR_Switch1 = new IR_Item 'SWITCH1', '', 'usb_uirt';
$IR_Switch2 = new IR_Item 'SWITCH2', '', 'usb_uirt';
$IR_Zone2   = new IR_Item 'ZONE2',   '', 'usb_uirt';
$IR_Zone3   = new IR_Item 'ZONE3',   '', 'usb_uirt';
my @Primary_IR_queue   = ();
my @Secondary_IR_queue = ();

my $Zone2_start_timer = 0;
my $Zone3_start_timer = 0;
my $Zone2_off_timer   = undef;
my $Zone3_off_timer   = undef;

my @dish_network_music = ( 956, 957, 958, 959, 960, 970, 971, 972, 973, 977 );
my $pvr_curr_channel;

use AlsaPlayer;
use PlayList;
$player1 = new AlsaPlayer( 'player1', 'channel12' );
$player2 = new AlsaPlayer( 'player2', 'channel34' );
$player3 = new AlsaPlayer( 'player3', 'channel56' );
$player4 = new AlsaPlayer( 'player4', 'channel78' );

foreach ( $player1, $player2, $player3, $player4 ) {
    $_->volume(0.85);
}

my @players = ( undef, $player1, $player2, $player3, $player4 );

# Define the playlists that I'll add to the virtual audio sources
# defined in my .mht file
my $pl_kirk_mp3s  = new PlayList;
my $pl_romantic   = new PlayList;
my $pl_pink_floyd = new PlayList;
my $pl_rock       = new PlayList;
my $pl_classical  = new PlayList;
my $pl_new_age    = new PlayList;

if ($Reload) {
    for ( my $i = 1; $i <= 4; $i++ ) {
        $players[$i]->start();
    }
}

my @musica_zones = ( undef, $music_kitchen );
my @musica_sources =
  ( undef, $music_source1, $music_source2, $music_source3, $music_source4 );

# noloop=stop

sub handle_virtual_source {
    my ( $obj, $action, $source ) = @_;
    print_log
      "VirtualAudio: got action $action for $$obj{name} (source=$source)";
    if ( $obj->get_data('label') ) {
        print_log "VirtualAudio:    $$obj{name} has label: "
          . $obj->get_data('label');
    }
    if ( $obj->get_data('playlist') ) {
        print_log "VirtualAudio:    $$obj{name} has playlist: "
          . $obj->get_data('playlist');
    }
    if ( $action eq 'attach' ) {
        if ( $$obj{name} eq 'v_pvr' ) {
            set $IR_PVR 'SELECT';
        }
        if ( $obj->get_data('switch_input') ) {
            print_log "VirtualAudio: Switch input for $$obj{name} is "
              . $obj->get_data('switch_input')
              . " (source=$source)";
            if ( $source == 3 ) {

                # Send twice to make sure it is executed
                push @Primary_IR_queue, $IR_Switch1,
                  $obj->get_data('switch_input');
                push @Secondary_IR_queue, $IR_Switch1,
                  $obj->get_data('switch_input');
            }
            elsif ( $source == 4 ) {

                # Send twice to make sure it is executed
                push @Primary_IR_queue, $IR_Switch2,
                  $obj->get_data('switch_input');
                push @Secondary_IR_queue, $IR_Switch2,
                  $obj->get_data('switch_input');
            }
        }
        if ( $obj->get_data('label') ) {
            $musica_sources[$source]->set_label( $obj->get_data('label') );
        }
        if ( $obj->get_data('playlist') ) {
            $players[$source]->remove_all_playlists();
            $players[$source]->shuffle( $obj->get_data('shuffle') );
            $players[$source]->add_playlist( $obj->get_data('playlist') );
            $players[$source]->pause();
        }
        if ( $$obj{name} eq 'v_voice' ) {
            &set_default_alsaplayer( $players[$source] );
            $players[$source]->stop();
        }
    }
    elsif ( $action eq 'detach' ) {
        if ( $obj->get_data('playlist') ) {
            $players[$source]->pause();
            $players[$source]->remove_playlist( $obj->get_data('playlist') );
        }
    }
    elsif ( $action eq 'in_use' ) {
        if ( $obj->get_data('playlist') ) {
            $players[$source]->unpause();
        }
        if ( $obj->get_data('receiver_input') ) {
            print_log
              "VirtualAudio: Object $$obj{name} has receiver input (source=$source): "
              . $obj->get_data('receiver_input');
            if ( $source == 3 ) {
                if ($Zone2_off_timer) {
                    print_log "VirtualAudio: cancelling timer for zone2";
                    $Zone2_off_timer->stop();
                    $Zone2_off_timer = undef;
                }
                $Zone2_start_timer = 0;
                print_log
                  "VirtualAudio: Object $$obj{name} (source=$source) selecting input: "
                  . $obj->get_data('receiver_input');
                push @Primary_IR_queue, $IR_Zone2, 'ZONEON';
                push @Primary_IR_queue, $IR_Zone2,
                  $obj->get_data('receiver_input');
                push @Secondary_IR_queue, $IR_Zone2, 'ZONEON';
                push @Secondary_IR_queue, $IR_Zone2,
                  $obj->get_data('receiver_input');
            }
            elsif ( $source == 4 ) {
                if ($Zone3_off_timer) {
                    print_log "VirtualAudio: cancelling timer for zone3";
                    $Zone3_off_timer->stop();
                    $Zone3_off_timer = undef;
                }
                $Zone3_start_timer = 0;
                print_log
                  "VirtualAudio: Object $$obj{name} (source=$source): turning on";
                push @Primary_IR_queue, $IR_Zone3, 'ZONEON';
                push @Primary_IR_queue, $IR_Zone3,
                  $obj->get_data('receiver_input');
                push @Secondary_IR_queue, $IR_Zone3, 'ZONEON';
                push @Secondary_IR_queue, $IR_Zone3,
                  $obj->get_data('receiver_input');
            }
        }
        else {
            &check_zones_off( $obj, $source );
        }
    }
    elsif ( $action eq 'not_in_use' ) {
        if ( $obj->get_data('playlist') ) {
            $players[$source]->pause();
        }
        &check_zones_off( $obj, $source );
    }
}

sub check_zones_off {
    my ( $obj, $source ) = @_;
    if ( $obj->get_data('receiver_input') ) {
        if ( $source == 3 ) {
            unless ($Zone2_off_timer) {
                print_log "VirtualAudio: requesting timer for zone2";
                $Zone2_start_timer = 1;
            }
        }
        elsif ( $source == 4 ) {
            unless ($Zone3_off_timer) {
                print_log "VirtualAudio: requesting timer for zone3";
                $Zone3_start_timer = 1;
            }
        }
    }
}

sub turn_voice_on {
    my ($obj) = @_;
    unless ( $obj->get_source() ) {
        print_log "VirtualAudio/Musica: turn_voice_on() called...";
        my $source = $audio_router->select_virtual_source( $obj->get_zone_num(),
            'v_voice' );
        $obj->set_source($source) if ( $source > 0 );
        if ( $speech_volume{$obj} ) {
            $obj->set_volume( $speech_volume{$obj} );
        }
        unless ( $music_kitchen->get_amp() eq 'both' ) {

            # Switch to internal and external amp
            $music_kitchen->both_amps();
        }
    }
}

sub turn_audio_off {
    my ($obj) = @_;
    print_log "VirtualAudio/Musica: turn_audio_off() called...";
    $obj->turn_off();
    $audio_router->specify_source_for_zone( $obj->get_zone_num(), 0 );
}

if ($Reload) {
    print_log "VirtualAudio/Musica: Reload block is running...";

    # Load files into playlists
    $pl_kirk_mp3s->add_files('/mnt/mp3s/KirkAll.m3u');
    $pl_romantic->add_files('/mnt/mp3s/Les_Miserables.m3u');
    $pl_pink_floyd->add_files('/mnt/mp3s/All_Pink_Floyd.m3u');
    $pl_rock->add_files('/mnt/mp3s/Rock.m3u');
    $pl_classical->add_files( '/mnt/mp3s/sorted/classical',
        '/mnt/mp3s/mp3disks/classical' );
    $pl_new_age->add_files( '/mnt/mp3s/sorted/new_age',
        '/mnt/mp3s/mp3disks/folk/Enya' );

    # Set handlers for all virtual sources (I use the same for all)
    $v_kirk_mp3s->set_action_function( \&handle_virtual_source );
    $v_romantic->set_action_function( \&handle_virtual_source );
    $v_pink_floyd->set_action_function( \&handle_virtual_source );
    $v_rock->set_action_function( \&handle_virtual_source );
    $v_classical->set_action_function( \&handle_virtual_source );
    $v_new_age->set_action_function( \&handle_virtual_source );
    $v_voice->set_action_function( \&handle_virtual_source );
    $v_internet->set_action_function( \&handle_virtual_source );
    $v_pvr->set_action_function( \&handle_virtual_source );
    $v_tivo->set_action_function( \&handle_virtual_source );
    $v_dvd->set_action_function( \&handle_virtual_source );
    $v_tuner->set_action_function( \&handle_virtual_source );

    $v_kirk_mp3s->attach_difficulty(100);
    $v_romantic->attach_difficulty(15);
    $v_pink_floyd->attach_difficulty(50);
    $v_rock->attach_difficulty(50);
    $v_classical->attach_difficulty(25);
    $v_new_age->attach_difficulty(15);
    $v_voice->attach_difficulty(1);
    $v_internet->attach_difficulty(5);
    $v_pvr->attach_difficulty(10);
    $v_tivo->attach_difficulty(10);
    $v_dvd->attach_difficulty(10);
    $v_tuner->attach_difficulty(10);

    # Keep 'v_voice' virtual source attached whenever possible
    # The 'v_voice' source represents a clear ALSA output channel to be used for
    # Misterhouse speech output
    $v_voice->keep_attached_when_possible();
    $v_voice->set_data( 'label', 'LIGHTS' );

    $v_internet->set_data( 'label',        'INTERNET' );
    $v_internet->set_data( 'switch_input', 'SOURCE3' );

    $v_tivo->set_data( 'label',          'SAT' );
    $v_tivo->set_data( 'switch_input',   'SOURCE2' );
    $v_tivo->set_data( 'receiver_input', 'VCR1' );

    $v_pvr->set_data( 'label',          'SAT2' );
    $v_pvr->set_data( 'switch_input',   'SOURCE2' );
    $v_pvr->set_data( 'receiver_input', 'CBL-SAT' );

    $v_dvd->set_data( 'label',          'DVD' );
    $v_dvd->set_data( 'switch_input',   'SOURCE2' );
    $v_dvd->set_data( 'receiver_input', 'DVD' );

    $v_tuner->set_data( 'label',          'TUNER' );
    $v_tuner->set_data( 'switch_input',   'SOURCE2' );
    $v_tuner->set_data( 'receiver_input', 'TUNER' );

    # Setup all MP3 playlists
    $pl_kirk_mp3s->randomize();
    $pl_pink_floyd->randomize();
    $pl_rock->randomize();
    $pl_classical->randomize();
    $pl_new_age->randomize();
    $v_kirk_mp3s->set_data( 'playlist', $pl_kirk_mp3s );
    $v_kirk_mp3s->set_data( 'shuffle',  1 );
    $v_kirk_mp3s->set_data( 'label',    'DAD' );
    $v_romantic->set_data( 'playlist', $pl_romantic );
    $v_romantic->set_data( 'shuffle',  0 );
    $v_romantic->set_data( 'label',    'DANCE' );
    $v_pink_floyd->set_data( 'playlist', $pl_pink_floyd );
    $v_pink_floyd->set_data( 'shuffle',  1 );
    $v_pink_floyd->set_data( 'label',    'BLUES' );
    $v_rock->set_data( 'playlist', $pl_rock );
    $v_rock->set_data( 'shuffle',  1 );
    $v_rock->set_data( 'label',    'ROCK' );
    $v_classical->set_data( 'playlist', $pl_classical );
    $v_classical->set_data( 'shuffle',  1 );
    $v_classical->set_data( 'label',    'CLASSIC' );
    $v_new_age->set_data( 'playlist', $pl_new_age );
    $v_new_age->set_data( 'shuffle',  1 );
    $v_new_age->set_data( 'label',    'SOUL' );

    foreach (
        $v_kirk_mp3s, $v_pink_floyd, $v_rock,
        $v_classical, $v_romantic,   $v_new_age
      )
    {
        $_->set_data( 'switch_input', 'SOURCE1' );
    }

    # Resume audio sources across a restart/reload
    $audio_router->resume();

    # Timers to turn on/off audio
    $om_presence_family_room->add_presence_timer( 120,
        '&turn_voice_on($music_kitchen);' );
    $om_presence_family_room->add_vacancy_timer( 600,
        '&turn_audio_off($music_kitchen);' );
}

if ( state_now $om_presence_kitchen eq 'occupied' ) {
    $om_presence_family_room->handle_presence();
}

foreach (@musica_zones) {
    next unless $_;
    if ( $state = state_now $_) {
        print_log "VirtualAudio: Got state for zone $$_{object_name}: $state ("
          . $_->get_set_by() . ')';
        if (   ( $state eq 'zone_on' )
            or ( $state eq 'zone_off' )
            or ( $state eq 'source_changed' ) )
        {
            #if ($state eq 'zone_on') {
            #   $_->set_volume($speech_volume{$_});
            #}
            my $source = $_->get_source();
            if ( $source eq 'E' ) {
                $source = 0;
            }
            $audio_router->specify_source_for_zone( $_->get_zone_num(),
                $source );
        }
        elsif ( $state eq 'button_pressed_stop' ) {
            if (
                $audio_router->get_virtual_source_name_for_zone(
                    $_->get_zone_num()
                ) eq 'v_voice'
              )
            {
                # Already on voice.. stop any MP3s
                my $source =
                  $audio_router->get_real_source_number_for_zone(
                    $_->get_zone_num() );
                $players[$source]->stop();
                $players[$source]->clear();
                $players[$source]->restart();
            }
            else {
                my $source =
                  $audio_router->select_virtual_source( $_->get_zone_num(),
                    'v_voice' );
                $_->set_source($source) if ( $source > 0 );
            }
        }
        elsif ( $state eq 'button_held_pause' ) {
            my $source =
              $audio_router->select_virtual_source( $_->get_zone_num(),
                'v_classical' );
            $_->set_source($source) if ( $source > 0 );
        }
        elsif ( $state eq 'button_held_stop' ) {
            my $source =
              $audio_router->select_virtual_source( $_->get_zone_num(),
                'v_romantic' );
            $_->set_source($source) if ( $source > 0 );
        }
        elsif ( $state eq 'button_held_play' ) {
            my $source =
              $audio_router->select_virtual_source( $_->get_zone_num(),
                'v_new_age' );
            $_->set_source($source) if ( $source > 0 );
        }
        elsif ( $state eq 'button_held_rewind' ) {
            my $source =
              $audio_router->select_virtual_source( $_->get_zone_num(),
                'v_kirk_mp3s' );
            $_->set_source($source) if ( $source > 0 );
        }
        elsif ( $state eq 'button_held_up' ) {
            my $source =
              $audio_router->select_virtual_source( $_->get_zone_num(),
                'v_pink_floyd' );
            $_->set_source($source) if ( $source > 0 );
        }
        elsif ( $state eq 'button_held_forward' ) {
            my $source =
              $audio_router->select_virtual_source( $_->get_zone_num(),
                'v_rock' );
            $_->set_source($source) if ( $source > 0 );
        }
        elsif ( $state eq 'button_held_left' ) {
            my $source =
              $audio_router->select_virtual_source( $_->get_zone_num(),
                'v_tivo' );
            $_->set_source($source) if ( $source > 0 );
        }
        elsif ( $state eq 'button_held_down' ) {
            my $source =
              $audio_router->select_virtual_source( $_->get_zone_num(),
                'v_pvr' );
            $_->set_source($source) if ( $source > 0 );
        }
        elsif ( $state eq 'button_held_right' ) {
            my $source =
              $audio_router->select_virtual_source( $_->get_zone_num(),
                'v_dvd' );
            $_->set_source($source) if ( $source > 0 );
        }
        elsif ( $state eq 'button_held_previous' ) {

            #my $source = $audio_router->select_virtual_source($_->get_zone_num(), 'v_tuner');
            #$_->set_source($source) if ($source > 0);
        }
        elsif ( $state eq 'button_held_power' ) {

            #my $source = $audio_router->select_virtual_source($_->get_zone_num(), 'v_dvd');
            #$_->set_source($source) if ($source > 0);
        }
        elsif ( $state eq 'button_held_next' ) {
            my $source =
              $audio_router->select_virtual_source( $_->get_zone_num(),
                'v_internet' );
            $_->set_source($source) if ( $source > 0 );
        }
        elsif ( $state eq 'button_pressed_left' ) {
            my $source =
              $audio_router->request_previous_virtual_source_for_zone(
                $_->get_zone_num() );
            $_->set_source($source) if ( $source > 0 );
        }
        elsif ( $state eq 'button_pressed_right' ) {
            my $source =
              $audio_router->request_next_virtual_source_for_zone(
                $_->get_zone_num() );
            $_->set_source($source) if ( $source > 0 );
        }
        elsif ( $state eq 'overheated' ) {
            speak(
                'rooms'      => 'all',
                'text'       => "Zone $$_{object_name} has overheated",
                'importance' => 'urgent'
            );
            set $_ OFF;
        }
    }
}

if ( state_now $music_kitchen eq 'source_changed' ) {
    if ( $music_kitchen->get_source() eq 'E' ) {

        # Turn volume to 25 whenever external source is selected
        $music_kitchen->set_volume(25);
    }
}

if ( state_now $music_kitchen eq 'button_pressed_up' ) {

    # Toggle between external-amp-only and internal-and-external amp modes
    if ( $music_kitchen->get_amp() eq 'external_amp' ) {

        # Switch to internal and external amp
        $music_kitchen->set_volume( $speech_volume{$music_kitchen} );
        $music_kitchen->set_volume(15);
        $music_kitchen->both_amps();
    }
    else {
        # Switch to external-amp only
        $music_kitchen->external_amp();
        $music_kitchen->set_volume('100%');
        push @Primary_IR_queue,   $IR_Receiver, 'POWERON';
        push @Primary_IR_queue,   $IR_Receiver, 'INPUTCDR';
        push @Secondary_IR_queue, $IR_Receiver, 'POWERON';
        push @Secondary_IR_queue, $IR_Receiver, 'INPUTCDR';
    }
}

if ( state_now $music_kitchen eq 'button_pressed_down' ) {
    my $source =
      $audio_router->select_virtual_source( $music_kitchen->get_zone_num(),
        'v_tuner' );
    $music_kitchen->set_source($source) if ( $source > 0 );
}

sub pick_prev_channel {
    my ( $curr, @list ) = @_;
    return $list[$#list] unless $curr;
    for ( my $i = $#list; $i >= 0; $i-- ) {
        if ( $curr eq $list[$i] ) {
            if ( $i == 0 ) {
                return $list[$#list];
            }
            else {
                return $list[ $i - 1 ];
            }
        }
    }
}

sub pick_next_channel {
    my ( $curr, @list ) = @_;
    return $list[0] unless $curr;
    for ( my $i = 0; $i <= $#list; $i++ ) {
        if ( $curr eq $list[$i] ) {
            if ( $i == $#list ) {
                return $list[0];
            }
            else {
                return $list[ $i + 1 ];
            }
        }
    }
}

sub change_to_channel {
    my ( $iritem, $channel, $finish ) = @_;
    while ( $channel =~ s/^(\d)// ) {
        push @Primary_IR_queue, $iritem, "DIGIT$1";
    }
    push @Primary_IR_queue, $iritem, $finish;
}

foreach (@musica_sources) {
    next unless $_;
    if ( $state = state_now $_) {
        my $source = $_->get_source_num();
        my $vsource =
          $audio_router->get_virtual_source_obj_for_real_source($source);
        if ($vsource) {
            print_log
              "VirtualAudio: got state $state from source $source (vsource is $$vsource{name})";
            print_log "VirtualAudio: playlist="
              . $vsource->get_data('playlist');
            if (   ( $vsource->get_data('playlist') )
                or ( $$vsource{name} eq 'v_voice' ) )
            {
                if ( $players[$source] ) {
                    if ( $state eq 'button_pressed_next' ) {
                        $players[$source]->next_song();
                    }
                    if ( $state eq 'button_pressed_previous' ) {
                        $players[$source]->previous_song();
                    }
                    if ( $state eq 'button_pressed_pause' ) {
                        $players[$source]->pause_toggle();
                    }
                    if ( $state eq 'button_pressed_play' ) {
                        $players[$source]->unpause();
                    }
                }
            }
            elsif ( $$vsource{name} eq 'v_pvr' ) {
                if ( $state eq 'button_pressed_next' ) {
                    $pvr_curr_channel =
                      &pick_next_channel( $pvr_curr_channel,
                        @dish_network_music );
                    &change_to_channel( $IR_PVR, $pvr_curr_channel, 'SELECT' );
                }
                if ( $state eq 'button_pressed_previous' ) {
                    $pvr_curr_channel =
                      &pick_prev_channel( $pvr_curr_channel,
                        @dish_network_music );
                    &change_to_channel( $IR_PVR, $pvr_curr_channel, 'SELECT' );
                }
            }
            elsif ( $$vsource{name} eq 'v_dvd' ) {
                if ( $state eq 'button_pressed_next' ) {
                    set $IR_DVD 'NEXTTRACK';
                }
                if ( $state eq 'button_pressed_previous' ) {
                    set $IR_DVD 'PREVIOUSTRACK';
                }
                if ( $state eq 'button_pressed_pause' ) {
                    set $IR_DVD 'PAUSE';
                }
                if ( $state eq 'button_pressed_play' ) {
                    set $IR_DVD 'PLAY';
                }
            }
            elsif ( $$vsource{name} eq 'v_tuner' ) {
                if ( $state eq 'button_pressed_next' ) {
                    set $IR_Receiver 'NEXTPRESET';
                }
                if ( $state eq 'button_pressed_previous' ) {
                    set $IR_Receiver 'PREVIOUSPRESET';
                }
                if ( $state eq 'button_pressed_play' ) {
                    set $IR_Receiver 'PRESETGROUPSELECT';
                }
            }
        }
    }
}

if ( $Zone2_start_timer and not $Zone2_off_timer ) {
    print_log "VirtualAudio: setting timer for zone2";
    $Zone2_off_timer = new Timer;
    $Zone2_off_timer->set( 15, '$IR_Zone2->set("ZONEOFF");' );
    $Zone2_start_timer = 0;
}
if ( $Zone3_start_timer and not $Zone3_off_timer ) {
    print_log
      "VirtualAudio: setting timer for zone3 (start_timer=$Zone3_start_timer, off_timer=$Zone3_off_timer)";
    $Zone3_off_timer = new Timer;
    $Zone3_off_timer->set( 15, '$IR_Zone3->set("ZONEOFF");' );
    $Zone3_start_timer = 0;
}

# This allows me to queue commands to send one per second so that
# if there is IR traffic that caused this event I won't have to fight over it.
if ($New_Msecond_500) {
    if (@Primary_IR_queue) {
        my $obj = shift @Primary_IR_queue;
        my $cmd = shift @Primary_IR_queue;
        print_log "$Time_Date Sending primary IR command: $cmd";
        $obj->set($cmd);
        unless (@Primary_IR_queue) {

            # Put in a few blanks before the secondary queue executes
            for ( my $i = 0; $i <= ( 10 - $#Secondary_IR_queue ); $i++ ) {
                unshift @Secondary_IR_queue, undef, undef;
            }
        }
    }
    elsif (@Secondary_IR_queue) {
        my $obj = shift @Secondary_IR_queue;
        my $cmd = shift @Secondary_IR_queue;
        if ( $obj and $cmd ) {
            print_log "$Time_Date Sending secondary IR command: $cmd";
            $obj->set($cmd);
        }
    }
}

#  <a href="/RUN;referrer?&selectvsource($zone_object,'vsource_name')">...</a>
sub selectvsource {
    my ( $zone_obj, $vsource ) = @_;
    my $source =
      $audio_router->select_virtual_source( $zone_obj->get_zone_num(),
        $vsource );
    $zone_obj->set_source($source) if ( $source > 0 );
    print_log "Got here: $zone_obj, $vsource";
    return "<P>Test message";
}
