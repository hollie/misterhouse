# Category=Tinia
#
use strict;

##############################################################################
$winlirc_client =
  new Socket_Item( undef, undef, 'localhost:8765', 'winlirc', 'tcp', 'record' );

if ($Startup) {
    start $winlirc_client;
}

if ( my $msg = said $winlirc_client) {

    #    		print_log "Winlirc_message_received: $msg\n";
    my ( $code, $act, $key, $remote ) =
      ( $msg =~ /([^ ]+) +([^ ]+) +([^ ]+) +([^ ]+) */ );
    if ( $act eq '00' ) {
        print_log "Winlirc_message_received: $msg\n";
        print "Winlirc_message_received: $msg\n";

        run_voice_cmd 'Set house mp3 player to Play'  if ( $key eq 'CD-Play' );
        run_voice_cmd 'Set house mp3 player to Stop'  if ( $key eq 'CD-Stop' );
        run_voice_cmd 'Set house mp3 player to Pause' if ( $key eq 'CD-Pause' );
        run_voice_cmd 'Set house mp3 player to Volume up'
          if ( $key eq 'CD-Volume-up' );
        run_voice_cmd 'Set house mp3 player to Volume down'
          if ( $key eq 'CD-Volume-down' );
        run_voice_cmd 'Set house mp3 player to Next Song'
          if ( $key eq 'CD-Next-Song' );
        run_voice_cmd 'Set house mp3 player to Previous Song'
          if ( $key eq 'CD-Previous-Song' );
        run_voice_cmd 'Set house mp3 player to Next Song'
          if ( $key eq 'CD-FForward' );
        run_voice_cmd 'Set house mp3 player to Previous Song'
          if ( $key eq 'CD-Rewind' );
        run_voice_cmd 'Set music audible key to 1' if ( $key eq 'CD-1' );
        run_voice_cmd 'Set music audible key to 2' if ( $key eq 'CD-2' );
        run_voice_cmd 'Set audible key to 1'       if ( $key eq 'CD-4' );
        run_voice_cmd 'Set audible key to 2'       if ( $key eq 'CD-5' );
        run_voice_cmd 'Toggle the house mode'      if ( $key eq 'CD-Mute' );
        run_voice_cmd 'Media Box rand_next'        if ( $key eq 'TV-Prog-up' );
        run_voice_cmd 'Media Box stop'       if ( $key eq 'TV-Prog-down' );
        run_voice_cmd 'Media Box voldn'      if ( $key eq 'TV-1' );
        run_voice_cmd 'Media Box volup'      if ( $key eq 'TV-3' );
        run_voice_cmd 'Media Box voldn'      if ( $key eq 'TV-Volume-down' );
        run_voice_cmd 'Media Box volup'      if ( $key eq 'TV-Volume-up' );
        run_voice_cmd 'Media Box up'         if ( $key eq 'TV-2' );
        run_voice_cmd 'Media Box down'       if ( $key eq 'TV-8' );
        run_voice_cmd 'Media Box left'       if ( $key eq 'TV-4' );
        run_voice_cmd 'Media Box right'      if ( $key eq 'TV-6' );
        run_voice_cmd 'Media Box enter'      if ( $key eq 'TV-5' );
        run_voice_cmd 'Media Box play_pause' if ( $key eq 'TV-0' );
        run_voice_cmd 'Media Box play_pause' if ( $key eq 'TV-0' );
        run_voice_cmd 'Media Box fforward'   if ( $key eq 'TV-9' );
        run_voice_cmd 'Media Box mark'       if ( $key eq 'TV-7' );
        run_voice_cmd 'Media Box exit'       if ( $key eq 'TV-Exit' );
        run_voice_cmd 'Media Box start'      if ( $key eq 'TV-Switch-onoff' );
        run_voice_cmd 'Turn on TV channel 1' if ( $key eq 'TV 1' );
        run_voice_cmd 'Turn on TV channel 2' if ( $key eq 'TV 2' );
        run_voice_cmd 'Turn on TV channel 3' if ( $key eq 'TV 3' );
        run_voice_cmd 'Turn on TV channel 4' if ( $key eq 'TV 4' );
        run_voice_cmd 'Turn on TV channel 5' if ( $key eq 'TV 5' );
        run_voice_cmd 'Turn on TV channel 6' if ( $key eq 'TV 6' );
        run_voice_cmd 'Turn on TV channel 7' if ( $key eq 'TV 7' );
        run_voice_cmd 'Turn on TV channel 8' if ( $key eq 'TV 8' );
        run_voice_cmd 'Set TV Channel up'    if ( $key eq 'TV-Prog-up' );
        run_voice_cmd 'Set TV Channel down'  if ( $key eq 'TV-Prog-down' );
        run_voice_cmd 'Set TV OnOff'         if ( $key eq 'TV Switch onoff' );
        run_voice_cmd 'Set TV Full screen'   if ( $key eq 'TV Full screen' );
        run_voice_cmd 'Set TV Mute'          if ( $key eq 'TV Mute' );
        run_voice_cmd 'Toggle recording of TV programme'
          if ( $key eq 'TV Record' );
        run_voice_cmd 'Play recorded file' if ( $key eq 'TV Red' );
        run_voice_cmd 'Set the house video player to Off'
          if ( $key eq 'VCR-Exit' );
        run_voice_cmd 'Play recorded file' if ( $key eq 'VCR Red' );
        run_voice_cmd 'Toggle recording of TV programme'
          if ( $key eq 'VCR-Record' );

        run_voice_cmd 'Set house mp3 player to Play' if ( $key eq 'VCR-Play' );
        run_voice_cmd 'Set house mp3 player to Stop' if ( $key eq 'VCR-Stop' );
        run_voice_cmd 'Set house mp3 player to Pause'
          if ( $key eq 'VCR-Pause' );
        run_voice_cmd 'Set the house video player to Volume up'
          if ( $key eq 'VCR-Volume-up' );
        run_voice_cmd 'Set the house video player to Volume down'
          if ( $key eq 'VCR-Volume-down' );
        run_voice_cmd 'Set the house video player to Mute'
          if ( $key eq 'VCR-Mute' );
        run_voice_cmd 'Set the house video player to Off'
          if ( $key eq 'VCR-Exit' );
        run_voice_cmd 'Set house mp3 player to Next Song'
          if ( $key eq 'VCR-Next-Song' );
        run_voice_cmd 'Set house mp3 player to Previous Song'
          if ( $key eq 'VCR-Previous-Song' );
        run_voice_cmd 'Set video audible key to 1' if ( $key eq 'VCR-1' );
        run_voice_cmd 'Set video audible key to 2' if ( $key eq 'VCR-2' );
        run_voice_cmd 'Set audible key to 1'       if ( $key eq 'VCR-4' );
        run_voice_cmd 'Set audible key to 2'       if ( $key eq 'VCR-5' );
        run_voice_cmd 'Set the house video player to Full screen'
          if ( $key eq 'VCR-Full-screen' );
        run_voice_cmd 'Turn on Radio channel 1' if ( $key eq 'RADIO 1' );
        run_voice_cmd 'Turn on Radio channel 2' if ( $key eq 'RADIO 2' );
        run_voice_cmd 'Turn on Radio channel 3' if ( $key eq 'RADIO 3' );
        run_voice_cmd 'Turn on Radio channel 4' if ( $key eq 'RADIO 4' );
        run_voice_cmd 'Turn on Radio channel 5' if ( $key eq 'RADIO 5' );
        run_voice_cmd 'Turn on Radio channel 6' if ( $key eq 'RADIO 6' );
        run_voice_cmd 'Turn on Radio channel 7' if ( $key eq 'RADIO 7' );
        run_voice_cmd 'Turn on Radio channel 8' if ( $key eq 'RADIO 8' );
        run_voice_cmd 'Set Radio Seek up'       if ( $key eq 'RADIO Prog up' );
        run_voice_cmd 'Set Radio Seek down' if ( $key eq 'RADIO Prog down' );
        run_voice_cmd 'Set Radio Volume up' if ( $key eq 'RADIO Volume up' );
        run_voice_cmd 'Set Radio Volume down'
          if ( $key eq 'RADIO Volume down' );
        run_voice_cmd 'Set Radio Off'  if ( $key eq 'RADIO Exit' );
        run_voice_cmd 'Set Radio Off'  if ( $key eq 'RADIO Switch onoff' );
        run_voice_cmd 'Set Radio Mute' if ( $key eq 'RADIO Mute' );
        run_voice_cmd 'Set music audible key to 1' if ( $key eq 'TV-Red' );
        run_voice_cmd 'Set music audible key to 2' if ( $key eq 'TV-Green' );
        run_voice_cmd 'Set audible key to 1'       if ( $key eq 'TV-Yellow' );
        run_voice_cmd 'Set audible key to 2'       if ( $key eq 'TV-Blue' );

    }
}
