
# This does not seem to effect the sound device used by mh :(
# But, it makes for a good example on how to set a registry entry :)

$sound_set = new Voice_Cmd 'Set sound device to [modem,sound card]';

if ( $state = said $sound_set) {
    $state =
      ( $state eq 'modem' ) ? 'Modem #0 Line Playback' : 'SB Live! Wave Device';
    print_log "Setting sound device to $state";
    registry_set 'HKEY_CURRENT_USER\Software\Microsoft\Multimedia\Sound Mapper',
      'Playback', 1, $state;

    #   $state = 'HKEY_LOCAL_MACHINE\\SOFTWARE\\Microsoft\\Speech\\AudioOutput\\TokenEnums\\MMAudioOut\\' . $state;
    #   registry_set 'HKEY_CURRENT_USER\Software\Microsoft\Speech\AudioOutput', 'DefaultTokenId', 1, $state;

    #   registry_set 'HKEY_CURRENT_USER\Software\Voice\VoiceText\Local PC', 'PName', 1, $state;
    #   registry_set 'HKEY_USERS\S-1-5-21-2025429265-1993962763-1801674531-1001\Software\Voice\VoiceText\Local PC', 'PName', 1, $state;

}
