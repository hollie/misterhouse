#
# These are the Stargate macro numbers and what we've mapped them to in MisterHouse
#
# TBD

# This relies on my Stargate keypads and my Xantech controller and relays commands
# between them and the MP3 player object.

# These are in a .mht file:
#MP3PLAYER,      oberon,                 house_input_1, Audio|Mp3Player
#MP3PLAYER,      ophelia,                house_input_2, Audio|Mp3Player
#MP3PLAYER,      centari,                house_input_3, Audio|Mp3Player
#MP3PLAYER,      ariel,                  family_room,   Audio|Mp3Player

#noloop=start
use Tie::IxHash;
use vars qw(%audio_zones);
my $audio_zones_ix = tie( %audio_zones, 'Tie::IxHash' );

%audio_zones = (
    'All'        => [$All_Music],
    'FamilyRoom' => [$FamilyRoom_Music],
    'Downstairs' => [ $FamilyRoom_Music, $LivingRoom_Music ],
    'LivingRoom' => [$LivingRoom_Music],
    'MasterBed'  => [$MasterBedroom_Music],
    'Pool'       => [$Pool_Music],

    #               'Outisde'    => [$Pool_Music, $Garage_Music],
    'Garage' => [$Garage_Music],
);

sub AudioZoneSetNext {

    # Get the target zone (a number or 'next', 'prev')
    my ( $object, $TargetZone ) = @_;

    print "AudioZoneSetNext has been called with a TargetZone of $TargetZone\n"
      if $main::config_parms{debug} eq 'audio';

    # Get the current zone
    my $MusicZone = $audio_zones_ix->Indices( $object->{music_zone_name} );

    # Move the counter up or done or to a specific zone
    if ( $TargetZone eq 'next' ) {
        $MusicZone += 1;
    }
    elsif ( $TargetZone eq 'prev' ) {
        $MusicZone -= 1;
    }
    else {
        $MusicZone = $audio_zones_ix->Indices($TargetZone);
    }

    my $ZoneCount = scalar keys %audio_zones;

    $MusicZone = 0 if $MusicZone >= $ZoneCount;
    $MusicZone = $ZoneCount - 1 if $MusicZone < 0;

    my $NewZoneName = $audio_zones_ix->Keys($MusicZone);

    # Set the zone name on the top of the lcd keypad
    $object->ChangeText( 17, 1, $NewZoneName );

    $object->{music_zone_name} = $NewZoneName;

    print "AudioZoneSetNext set zone name to $NewZoneName\n"
      if $main::config_parms{debug} eq 'audio';
}

sub AudioZoneRelayCommand {

    # Take the object (which LCD generated this command) and relay the requested command to the zipper zone
    my ( $object, $command ) = @_;

    print "AudioZoneRelayCommand $object $command\n";

    foreach my $i ( 0 .. $#{ $audio_zones{ $object->{music_zone_name} } } ) {
        ( $audio_zones{ $object->{music_zone_name} }[$i] )->set("$command");
    }
}

sub AudioPlayerRelayCommand {

    # Take the object (which LCD generated this command) and relay the requested command to the associated auidio device
    my ( $object, $command ) = @_;

    print "AudioPlayerRelayCommand $object $command\n";

    ( $audio_zones{ $object->{music_zone_name} }[0] )->{zone_device}
      ->set("$command");
}

sub AudioZoneSetup {
    my ( $object, $defaultzone ) = @_;

    # Ask MH to save this data across session
    $object->restore_data("music_zone_name");

    $defaultzone = $object->{music_zone_name}
      if $object->{music_zone_name} ne undef;

    $object->tie_event( '&::AudioZoneSetNext($object,\'' . $defaultzone . '\')',
        "startup" );
    $object->tie_event( '&::AudioZoneSetNext($object, "next")', "macro243" );
    $object->tie_event( '&::AudioZoneSetNext($object, "prev")', "macro244" );

    #$object->tie_event('&::AudioInputSetNext($object, "next")', "macro245");
    #$object->tie_event('&::AudioInputSetNext($object, "prev")', "macro246");

    $object->tie_event( '&::AudioZoneRelayCommand($object, "on")', "macro252" );
    $object->tie_event( '&::AudioZoneRelayCommand($object, "off")',
        "macro253" );
    $object->tie_event( '&::AudioZoneRelayCommand($object, "mute")',
        "macro247" );
    $object->tie_event( '&::AudioZoneRelayCommand($object, "volume:up")',
        "macro248" );
    $object->tie_event( '&::AudioZoneRelayCommand($object, "volume:down")',
        "macro249" );

    $object->tie_event( '&::AudioZoneRelayCommand($object, "input:01")',
        "macro222" );
    $object->tie_event( '&::AudioZoneRelayCommand($object, "input:02")',
        "macro223" );
    $object->tie_event( '&::AudioZoneRelayCommand($object, "input:03")',
        "macro224" );
    $object->tie_event( '&::AudioZoneRelayCommand($object, "input:04")',
        "macro225" );
    $object->tie_event( '&::AudioZoneRelayCommand($object, "input:05")',
        "macro226" );
    $object->tie_event( '&::AudioZoneRelayCommand($object, "input:06")',
        "macro227" );
    $object->tie_event( '&::AudioZoneRelayCommand($object, "input:07")',
        "macro228" );
    $object->tie_event( '&::AudioZoneRelayCommand($object, "input:08")',
        "macro229" );

    $object->tie_event(
        '&::AudioPlayerRelayCommand($object, "playlist://centari/media/playlists/background.m3u")',
        'macro230'
    );
    $object->tie_event(
        '&::AudioPlayerRelayCommand($object, "playlist://centari/media/playlists/classical.m3u")',
        'macro231'
    );
    $object->tie_event(
        '&::AudioPlayerRelayCommand($object, "playlist://centari/media/playlists/romance.m3u")',
        'macro232'
    );
    $object->tie_event(
        '&::AudioPlayerRelayCommand($object, "playlist://centari/media/playlists/baby.m3u")',
        'macro233'
    );
    $object->tie_event(
        '&::AudioPlayerRelayCommand($object, "playlist://centari/media/playlists/party.m3u")',
        'macro234'
    );
    $object->tie_event(
        '&::AudioPlayerRelayCommand($object, "playlist://centari/media/playlists/all.m3u")',
        'macro235'
    );
    $object->tie_event( '&::AudioPlayerRelayCommand($object, "next")',
        'macro250' );
    $object->tie_event( '&::AudioPlayerRelayCommand($object, "prev")',
        'macro251' );
    $object->tie_event( '&::AudioPlayerRelayCommand($object, "stop")',
        'macro254' );
    $object->tie_event( '&::AudioPlayerRelayCommand($object, "pause")',
        'macro255' );
    $object->tie_event( '&::AudioPlayerRelayCommand($object, "play")',
        'macro256' );
}

sub AudioDeviceSetupPlayers {
    my ($object) = @_;

    $object->tie_event( '$object->{zone_device} = $house_input_1', "input:01" );
    $object->tie_event( '$object->{zone_device} = $house_input_2', "input:02" );
    $object->tie_event( '$object->{zone_device} = $house_input_3', "input:03" );
}

sub AudioDeviceSetup {
    AudioDeviceSetupPlayers($All_Music);
    AudioDeviceSetupPlayers($FamilyRoom_Music);
    AudioDeviceSetupPlayers($LivingRoom_Music);
    AudioDeviceSetupPlayers($MasterBedroom_Music);
    AudioDeviceSetupPlayers($Pool_Music);
    AudioDeviceSetupPlayers($Garage_Music);
}

sub AudioSetup {
    print "!!!!! AudioSetup called\n";
    AudioDeviceSetup();
    AudioZoneSetup( $Kitchen_LCD,       "Downstairs" );
    AudioZoneSetup( $FamilyRoom_LCD,    "Downstairs" );
    AudioZoneSetup( $MasterBedroom_LCD, "MasterBed" );
}

# Run our setup code after object states have been restored
&::Reload_post_add_hook( \&AudioSetup );

#noloop=stop

