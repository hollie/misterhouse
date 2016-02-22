package Voice_Text;

# $Date$
# $Revision$

use strict;
use LWP::UserAgent;
use LWP::ConnCache;

use vars '$VTxt_version';
my ( @VTxt, $VTxt_stream1, $VTxt_stream2, %VTxt_cards, $VTxt_festival,
    $VTxt_mac );
my ( $save_mute_esd, $save_change_volume, %pronouncable );
my ( %voice_names, @voice_names, $voice_names_index, $VTxt_pid, $web_index );

my $is_speaking_timer = new Timer;

sub init {
    my ($engine) = @_;

    $web_index = 0;

    # OS X
    if ( $main::Info{OS_name} =~ /darwin/i ) {
        my $voice = $main::config_parms{speak_voice};
        $voice = 'Albert' unless $voice;
    }

    if (
        (
               $main::config_parms{voice_text} =~ /festival/i
            or $engine and $engine eq 'festival'
        )
        and $main::config_parms{festival_host}
      )
    {
        my $festival_address =
          "$main::config_parms{festival_host}:$main::config_parms{festival_port}";
        print " - creating festival TTS socket on $festival_address\n";
        $VTxt_festival =
          new Socket_Item( undef, undef, $festival_address, 'festival', 'tcp',
            'raw' );
    }

    if ( $main::config_parms{voice_text} =~ /ms/i and $main::OS_win ) {
        print
          " - creating MS TTS object for voice_text=$main::config_parms{voice_text} ...\n";

        # Test and default to the new SDK 5 SAPI
        $VTxt_version = lc $main::config_parms{voice_text};
        unless ( $VTxt_version eq 'msv4' ) {
            if ( my $test = Win32::OLE->new('Sapi.SpVoice') ) {
                $VTxt_version = 'msv5';

                # Create objects for all available output cards
                my $outputs = $test->GetAudioOutputs;
                if ($outputs) {
                    my $count = $outputs->Count;
                    for my $i ( 1 .. $count ) {
                        my $object = $outputs->Item( $i - 1 );
                        my $des    = $object->GetDescription;
                        print " - sound card $i: $des\n";
                        if ( $main::config_parms{voice_text_cards} ) {
                            my $flag = 0;
                            for my $card ( split ',',
                                $main::config_parms{voice_text_cards} )
                            {
                                if ( $i eq $card or $des =~ /$card/i ) {
                                    $flag = 1;
                                    $VTxt_cards{$card} = $i;
                                }
                            }
                            next unless $flag;
                        }
                        $VTxt[$i] = Win32::OLE->new('Sapi.SpVoice');
                        $VTxt[$i]->{AudioOutput} = $object;

                        # Pick the default card, if specified
                        $VTxt[0] = $VTxt[$i]
                          if $des =~ /$main::config_parms{voice_text_card}/i
                          or !$VTxt[0];
                    }
                }
                else {
                    print " - WARN: no sound card outputs are available\n";
                }
                $VTxt[0] = $VTxt[1]
                  unless $VTxt[0]
                  ;    # Default to the first card if specified one not found

                # Create an object for to_file calls
                $VTxt_stream1 = Win32::OLE->new('Sapi.SpVoice');
                $VTxt_stream1 = undef
                  unless defined
                  $VTxt_stream1->GetVoices;    # undef it if now voices exist
                if ( defined $VTxt_stream1 ) {
                    for (
                        my $VoiceCnt = 0;
                        $VoiceCnt < $VTxt_stream1->GetVoices->Count();
                        $VoiceCnt++
                      )
                    {
                        my $desc = $VTxt_stream1->GetVoices->Item($VoiceCnt)
                          ->GetDescription;
                        print " -- available voice: $desc\n";
                    }
                    &set_voice( $main::config_parms{speak_voice},
                        undef, undef, $VTxt_stream1 )
                      if $main::config_parms{speak_voice};
                }

            }
            else {
                $VTxt_version = 'msv4';
            }
        }

        if ( $VTxt_version eq 'msv4' ) {
            $VTxt[0] = Win32::OLE->new('Speech.VoiceText');
            unless ( $VTxt[0] ) {
                print "\n\nError, could not create ms Speech TTS object.  ",
                  Win32::OLE->LastError(), "\n\n";
                return;
            }

            #           print "Registering the MS TTS object\n";
            $VTxt[0]->Register( "Local PC", "perl voice_text.pm" );

            #           $VTxt[0]->{Enabled} = 1;
        }
        print " - engine used:  $VTxt_version\n";
    }

}

# Execute callback for web based clients
sub web_hook_callback {
    my (%parms) = @_;
    &main::print_log("web_hook_callback: $parms{web_file}");
    return if ( $parms{web_file} eq "web_file" );
    if ( defined $parms{web_hook} ) {
        foreach my $web_hook ( @{ $parms{web_hook} } ) {
            &$web_hook(%parms);
        }
    }
}

sub speak_text {
    my (%parms) = @_;

    if ( $::Debug{voice} ) {
        my $parmsdisplay;
        foreach ( sort( keys(%parms) ) ) {
            $parmsdisplay .= " '$_'='$parms{$_}'";
        }
        &main::print_log("speak_text: parms are $parmsdisplay");
    }

    # set a default voice, if configured
    $parms{voice} = $::config_parms{voice_text_default_voice}
      unless $parms{voice};
    return if lc $parms{voice} eq 'none';
    return if !$parms{to_file} and $::config_parms{disable_local_sound};

    if ( $parms{address} ) {
        my @address = split ',', $parms{address};
        delete $parms{address};
        $parms{to_file} =
          "$main::config_parms{html_alias_cache}/speak_address.$main::Second.wav";

        &speak_text(%parms);

        package main;    # So the we do not have to use $main::
        for my $address (@address) {
            my $address_code = $config_parms{voice_text_address_code};
            $address_code =~ s|\$address|$address|;
            $address_code =~
              s|\$url|http://$Info{IPAddress_local}:$config_parms{http_port}/cache/speak_address.$main::Second.wav|;
            print "Voice_text running address code: $address_code\n"
              if $main::Debug{voice};
            eval $address_code;
            print "voice_text_address_code eval error: $@" if $@;
        }
        return;
    }

    # Support for audrey, android, and other web based clients which
    # synthesized text to voice is provided for.  Make a recursive call
    # to create the static file pushed to web devices.
    if ( $parms{web_file} eq "web_file" ) {
        my $wavFile = "speakToWeb" . $web_index . ".wav";
        $parms{web_file} = "web/" . $wavFile;
        my $to_file = $parms{to_file};
        $parms{to_file} = $::config_parms{html_alias_web} . "/" . $wavFile;
        $web_index++;
        $web_index = $web_index % 10;
        &speak_text(%parms);
        $parms{to_file}  = $to_file;
        $parms{web_file} = "web_file";
    }

    # Pick the correct card (default, if not specified).   Currently only engine=MS
    my $vtxt_card = $VTxt[0];
    if ( $parms{card} ) {
        my $card = $parms{card};
        $card = $VTxt_cards{$card}
          if $VTxt_cards{$card};    # Allow for text card name
        $vtxt_card = $VTxt[$card];
    }

    # Use this as a rough guess if other methods fail
    # - Must trigger timer this pass, not next, or http server
    #   will return before we start!  Hence, call to set_from_last_pass
    unless (@VTxt) {
        set $is_speaking_timer ( 1 + ( length $parms{text} ) / 10 );
        set_from_last_pass $is_speaking_timer;
    }

    my ( $speak_pgm, $speak_engine );
    $speak_engine = $parms{engine};
    $speak_engine = $main::config_parms{voice_text} unless $speak_engine;

    $speak_pgm = $1 if $speak_engine =~ /program (\S+)/;
    $speak_pgm = $main::config_parms{voice_text_flite}
      if $speak_engine eq 'flite';
    $speak_pgm = $main::config_parms{voice_text_theta}
      if $speak_engine eq 'theta';
    $speak_pgm = $main::config_parms{voice_text_swift}
      if $speak_engine eq 'swift';
    $speak_pgm = "$^X $main::Pgm_Path/vv_tts.pl" if $speak_engine =~ /vv_tts/i;
    $speak_pgm = "$^X $main::Pgm_Path/vv_tts_simple.pl"
      if $speak_engine =~ /viavoice/i;

    if ( $speak_engine =~ /NaturalVoiceWine/i ) {
        my $wine_path = $main::config_parms{wine_path};
        $wine_path = 'wine' unless -e $wine_path;
        my $nv_path = $main::config_parms{voice_text_naturalvoice}
          ;    # DOS path to NatVox stuff
        $speak_pgm =
          "$wine_path '$nv_path/bin/ttsstandaloneplayer.exe' -- -data '$nv_path/data' -xml";
    }
    elsif ( $speak_engine =~ /NaturalVoice/i ) {
        my $path = $main::config_parms{voice_text_naturalvoice};
        $speak_pgm = "$path/bin/TTSStandalonePlayerDT -data $path/data -xml";

        #       $speak_pgm = "$path/bin/TTSDesktopPlayer      -data $path/data -xml";
    }
    elsif ( $main::Info{OS_name} =~ /darwin/i ) {
        $speak_pgm = 'say' unless $speak_pgm;

        #       $speak_pgm = 'osascript' unless $speak_pgm;
    }
    elsif ( $speak_engine =~ /viavoice/i or $speak_engine =~ /vv_tts/i ) {
        $parms{voice} = $main::config_parms{viavoice_voice}
          unless $parms{voice};
        $parms{voice} = $voice_names{ lc $parms{voice} }
          if $voice_names{ lc $parms{voice} };
        my %voice_table = (
            male         => 1,
            female       => 2,
            child        => 3,
            elder_female => 7,
            elder_male   => 8
        );
        $parms{voice} = $voice_table{ lc $parms{voice} }
          if $voice_table{ lc $parms{voice} };
    }
    elsif ( $speak_engine =~ /(theta|swift)/i ) {
        $parms{voice} = $voice_names{ lc $parms{voice} }
          if $voice_names{ lc $parms{voice} };
    }

    # Allow for pause,resume,stop,ff,rew.  Also allow mode to set rate
    # *** Why?  Older versions?
    if ( my $mode = $parms{mode} ) {
        if (   $mode eq 'fast'
            or $mode eq 'normal'
            or $mode eq 'slow'
            or $mode =~ /^[\+\-]?\d+$/ )
        {
            $parms{rate} = $mode;
        }
        else {
            &set_mode( $mode, $vtxt_card );
        }
    }

    # Allow for a percentage volume number - Steve Switzer 1/19/2003
    my $mh_volume = state $main::mh_volume if $main::mh_volume;
    print
      "Voice_Text volume=$parms{volume}, mh_volume=$mh_volume vc=$vtxt_card\n"
      if $main::Debug{voice};
    if ( $parms{volume} =~ /(\d+)\%$/ ) {
        $parms{volume} = int( $mh_volume * $1 / 100 );
    }
    else {
        $parms{volume} = $mh_volume unless $parms{volume};
    }
    print "Voice_Text new volume=$parms{volume}\n" if $main::Debug{voice};

    $parms{volume} = 100 if $parms{volume} and $parms{volume} > 100;

    # These mess up -text "text" calls and not useful when speaking?
    $parms{text} =~ s/\"//g unless $parms{no_mod};
    $parms{text} =~ s/\'//g unless $parms{no_mod};

    $parms{text} = &set_rate( $parms{rate}, $parms{text}, $vtxt_card )
      if $parms{rate};    # Allow for slow,normal,fast,wpm:###
    $parms{text} =
      &set_voice( $parms{voice}, $parms{text}, $speak_engine, $vtxt_card )
      if $parms{voice};
    $parms{text} = &set_volume( $parms{volume}, $parms{text}, $vtxt_card )
      if $parms{volume};
    $parms{text} = &set_pitch( $parms{pitch}, $parms{text} ) if $parms{pitch};

    # Drop XML speech tags unless supported
    $parms{text} =~ s/<\/?voice.*?>//g
      unless ( $VTxt_version and $VTxt_version eq 'msv5' )
      or $speak_engine =~ /naturalvoice/i;

    return unless $parms{text} or $parms{play};

    if ( $speak_engine =~ /^&/ ) {
        $speak_engine =~ s/^&/&main::/;
        eval "$speak_engine(%parms)";
        print "Voice_Text $speak_engine eval error: $@" if $@;
    }
    elsif ( $speak_engine =~ /festival/i ) {

        # Initialize the festival server if necessary
        &init('festival') unless $VTxt_festival;
        if ( $VTxt_festival and not active $VTxt_festival) {
            if ( start $VTxt_festival) {
                if ( $main::config_parms{festival_init_cmds} ) {
                    print
                      "Data sent to festival: $main::config_parms{festival_init_cmds}\n";
                    set $VTxt_festival
                      qq[$main::config_parms{festival_init_cmds}];
                }
            }
        }

        # Clear out buffer, so is_speaking works
        $main::Socket_Ports{festival}{data_record} = '';
        $main::Socket_Ports{festival}{data}        = '';

        # Send Voice Text to a file
        if ( $parms{to_file} ) {

            # Change from relative to absolute path
            $parms{to_file} = "$main::Pgm_Path/$1"
              if $parms{to_file} =~ /^\.\/(.+)/;
            $parms{text} =
              qq[(utt.save.wave (utt.synth (Utterance Text "$parms{text}")) "$parms{to_file}" "riff")];

            # Use the festival server
            if ( $VTxt_festival and active $VTxt_festival) {
                $parms{text} =~
                  s/<\/?speaker.*?>//ig;    # Server does not do sable
                &main::print_log(
                    "Voice_text TTS:  Festival saving to file via server: $parms{to_file}\n"
                ) if $main::Debug{voice};
                set $VTxt_festival $parms{text};

                my $fork = 1 if $parms{async};

                if ($fork) {
                    my $pid = fork;

                    # we are the parent
                    if ( $fork and $pid ) {
                        return
                          ; # nothing else to do, the child is looking after the rest of the work
                    }
                }

                # Wait for server to respond that it is done
                my $sock = $main::Socket_Ports{festival}{sock};
                my $i;
                while ( $i++ < 100 ) {
                    print '-' if $main::Debug{voice};
                    select undef, undef, undef, .1;
                    my $nfound = &main::socket_has_data($sock);
                    if ( $nfound > 0 ) {
                        last;
                    }
                }

                # Send voice text to waiting web clients
                &web_hook_callback(%parms);

                # End the child if necessary
                if ($fork) {
                    if ($main::OS_win) {
                        exec 'true';
                    }
                    else {
                        &POSIX::_exit(0);
                    }

                    # 			    exit; # nothing left for the child to do
                }
            }

            # Call festival directly
            else {
                my $file = "$main::config_parms{data_dir}/mh_temp.festival.txt";
                &main::file_write( $file, $parms{text} );
                &main::print_log(
                    "Voice_text TTS: Festival saving to file: $file\n")
                  if $main::Debug{voice};
                my $fork = $parms{async};
                if ($fork) {
                    my $pid = fork;

                    # we are the parent
                    if ( $fork and $pid ) {
                        return;    # the child will look after the real work
                    }
                }

                # Call festival
                system("$main::config_parms{voice_text_festival} -b $file");

                # Send voice text to waiting web clients
                &web_hook_callback(%parms);

                # Clean up the child if necessary
                if ($fork) {
                    if ($main::OS_win) {
                        exec 'true';
                    }
                    else {
                        &POSIX::_exit(0);
                    }

                    # 			    exit; # nothing left for the child to do
                }
            }
            select undef, undef, undef, .2;    # Need this ?
        }

        # Speak Voice directly, not to a file
        # Check for sable requests.  Server does not do sable
        elsif ( !$VTxt_festival
            or $parms{voice}
            or $parms{volume}
            or $parms{rate}
            or $parms{text} =~ /<sable>i/ )
        {
            my $text = $parms{text};
            unless ( $text =~ /<sable>i/ ) {
                $parms{rate}   = '-50%'  if $parms{rate} eq 'slow';
                $parms{rate}   = '+50%'  if $parms{rate} eq 'fast';
                $parms{volume} = 'quiet' if $parms{volume} eq 'soft';

                # Does this need to be scaled from 0->100 to ???
                if ( $parms{volume} ) {
                    $text = qq[<VOLUME LEVEL="$parms{volume}"> $text </VOLUME>];
                }
                if ( $parms{rate} ) {
                    $text = qq[<RATE SPEED="$parms{rate}"> $text </RATE>];
                }
                $text = qq[<SABLE> $text </SABLE>];
            }
            my $random =
              int rand 1000;   # Use random file name so we can talk 2+ at once.
            my $file =
              "$main::config_parms{data_dir}/mh_temp.festival.$random.sable";
            &main::file_write( $file, $text );
            print
              "Voice_text TTS: $main::config_parms{voice_text_festival} --tts $file\n"
              if $main::Debug{voice};
            my $fork = $parms{async};
            if ($fork) {
                my $pid = fork;

                # we are the parnet
                if ( $fork and $pid ) {
                    return;    # the child will look after the real work
                }
            }
            system(
                "($main::config_parms{voice_text_festival} --tts $file ; rm $file) &"
            );

            # Send voice text to waiting web clients
            &web_hook_callback(%parms);

            if ($fork) {
                if ($main::OS_win) {
                    exec 'true';
                }
                else {
                    &POSIX::_exit(0);
                }

                # 		    exit; # nothing left for the child to do
            }
        }
        else {
            my $text = $parms{text};

            # Remove <tags> like </this> as we don't want them read
            $text =~ s/<[^>]*>//g;
            print "Data sent to festival: $text\n" if $main::Debug{voice};

            # not sure if we will ever do a fork here as an asynchronous TTS that's not to
            # a file doesn't sound likely.  For completeness, though, it's here.
            my $fork = $parms{async};
            if ($fork) {
                my $pid = fork;

                # we are the parnet
                if ( $fork and $pid ) {
                    return;    # the child will look after the real work
                }
            }
            set $VTxt_festival qq[(SayText "$text")];
            if ($fork) {
                if ($main::OS_win) {
                    exec 'true';
                }
                else {
                    &POSIX::_exit(0);
                }

                # 		    exit; # nothing left for the child to do
            }
        }
    }
    elsif ( $speak_engine =~ /google/ ) {

        # Speak to tile using the Google TTS Engine

        # Define a basic LWP agent for retrieving the Google MP3
        my $ua;
        $ua = LWP::UserAgent->new;
        $ua->agent("Mozilla/5.0 (X11; Linux; rv:8.0) Gecko/20100101");
        $ua->env_proxy;
        $ua->conn_cache( LWP::ConnCache->new() );
        $ua->timeout(10);

        my $random =
          int rand 1000;    # Use random file name so we can talk 2+ at once.

        # If being forced to file, use the filename being forced, otherwise, use a random temp file.
        my $out_file =
          ( $parms{to_file} )
          ? $parms{to_file}
          : "$main::config_parms{data_dir}/mh_temp.google-$random.wav";

        # The temp file to store google's MP3 as
        my $google_file =
          "$main::config_parms{data_dir}/mh_temp.google-$random.mp3";

        # Make the request, store the result in the google temp file
        my $language =
          ( $main::config_parms{language} )
          ? lc( $main::config_parms{language} )
          : "en";
        my $ua_request = HTTP::Request->new(
            'GET' => "http://translate.google.com/translate_tts?tl=$language&q="
              . qq[ $parms{text} ] );
        my $ua_response = $ua->request( $ua_request, $google_file );

        # Log the failure
        if ( !$ua_response->is_success ) {
            print "Failed to contact the Google TTS API.\n";
            return;
        }

        # Convert the returned mp3 file to a wav, and clean up the temp file
        my $sound_converter =
          ( $main::config_parms{sound_converter} )
          ? $main::config_parms{sound_converter}
          : "ffmpeg";
        system( $sound_converter, '-v', 'panic', '-i', $google_file,
            $out_file );
        unlink($google_file);

        # Play the wav file, clean up only if we are not being forced to file
        system("$main::config_parms{sound_program} $out_file")
          unless $parms{to_file};
        unlink($out_file) unless $parms{to_file};
    }
    elsif ($speak_pgm) {
        my $fork = 1
          unless $parms{to_file}
          and !$parms{async}
          ;    # Must wait for to_file requests, so http requests work

        my $pid = fork if $fork;

        #       $SIG{CHLD}  = "IGNORE";                   # eliminate zombies created by FORK() ... we do this in bin/mh
        if ( $fork and $pid ) {
            $VTxt_pid = $pid;
        }
        elsif ( !$fork or defined $pid ) {

            # Or else browser will wait for child to finish speaking
            &::socket_close('http') if $main::Socket_Ports{http}{socka};
            my $speak_pgm_arg       = '';
            my $speak_pgm_use_stdin = 0;
            my $sound_key           = $parms{play};
            if ( $sound_key and $main::Sounds{$sound_key} ) {

                #print "main::Sounds{sound_key}=$main::Sounds{$sound_key}\n";
                for my $parm ( keys %{ $main::Sounds{$sound_key} } ) {

                    #print "parm=$parm, $main::Sounds{$sound_key}{$parm}\n";
                    $parms{$parm} = $main::Sounds{$sound_key}{$parm}
                      unless $parms{$parm} and $parm ne 'play';
                }
                $parms{play} = $parms{file} if $parms{file};
            }
            if ( $parms{play} ) {
                my $file = $parms{play};
                unless ( $parms{play} =~ /^System/
                    or $parms{play} =~ /^[\\\/]/
                    or $parms{play} =~ /^\S\:/ )
                {
                    $parms{play} = "$main::config_parms{sound_dir}/$file";
                    $parms{play} = "$main::config_parms{sound_dir_common}/$file"
                      unless -e $parms{play};
                }
            }
            $speak_pgm_arg .= " -play $parms{play} " if $parms{play};

            if ( $speak_engine =~ /vv_tts/i ) {
                $speak_pgm_arg .=
                  " -engine " . $main::config_parms{vv_tts_engine}
                  if $main::config_parms{vv_tts_engine};
                $speak_pgm_arg .=
                  " -prescript " . $main::config_parms{vv_tts_prescript}
                  if $main::config_parms{vv_tts_prescript};
                $speak_pgm_arg .=
                  " -postscript " . $main::config_parms{vv_tts_postscript}
                  if $main::config_parms{vv_tts_postscript};
                $speak_pgm_arg .=
                  " -playcmd " . $main::config_parms{vv_tts_playcmd}
                  if $main::config_parms{vv_tts_playcmd};
                $speak_pgm_arg .=
                  " -default_sound " . $main::config_parms{vv_tts_default_sound}
                  if $main::config_parms{vv_tts_default_sound};
                $speak_pgm_arg .=
                  " -default_volume " . $main::config_parms{sound_volume}
                  if $main::config_parms{sound_volume};
                if (    $main::config_parms{vv_tts_pa_control}
                    and $main::config_parms{xcmd_file} )
                {
                    $speak_pgm_arg .= ' -pa_control -xcmd_file '
                      . $main::config_parms{xcmd_file};
                    if ( $parms{rooms} ) {
                        $speak_pgm_arg .= ' -rooms ' . $parms{rooms};
                    }
                    else {
                        $speak_pgm_arg .= ' -rooms default';
                    }
                }
                $speak_pgm_arg .= ' -debug ' if $main::Debug{voice};
                $speak_pgm_arg .= ' -nomixer '
                  if $main::config_parms{vv_tts_nomixer};

                $parms{volume} = '75'  if $parms{volume} eq 'soft';
                $parms{volume} = '100' if $parms{volume} eq 'loud';

                $speak_pgm_arg .= ' -text_first' if $parms{text_first};
                $speak_pgm_arg .= ' -volume ' . $parms{volume}
                  if $parms{volume};
                $speak_pgm_arg .= ' -play_volume ' . $parms{play_volume}
                  if $parms{play_volume};
                $speak_pgm_arg .= ' -voice_volume ' . $parms{voice_volume}
                  if $parms{voice_volume};
                $parms{voice} = ''
                  unless $parms{voice} =~
                  /^\d+$/;    # -voice supports numbers only
                $speak_pgm_arg .= ' -voice ' . "'$parms{voice}'"
                  if $parms{voice};
                $speak_pgm_arg .= ' -to_file ' . $parms{to_file}
                  if $parms{to_file};
                $speak_pgm_arg .= qq[ -text "$parms{text}"];
            }
            elsif ( $speak_engine =~ /viavoice/ ) {
                $speak_pgm_arg .= ' -voice ' . "'$parms{voice}'"
                  if $parms{voice};
                $speak_pgm_arg .= ' -to_file ' . $parms{to_file}
                  if $parms{to_file};
                $speak_pgm_arg .= ' -right ' . $parms{right} if $parms{right};
                $speak_pgm_arg .= ' -left ' . $parms{left}   if $parms{left};
                $speak_pgm_arg .= qq[ "$parms{text}"];
            }
            elsif ( $speak_pgm =~ /flite/ ) {
                $speak_pgm_arg .= ' -voice ' . "'$parms{voice}'"
                  if $parms{voice};
                $speak_pgm_arg .= " -o $parms{to_file}" if $parms{to_file};
                $speak_pgm_arg .= qq[ -t "$parms{text}"];
            }
            elsif ( $speak_engine =~ /naturalvoice/i ) {
                if ( $parms{to_file} ) {
                    $speak_pgm =~ s/Player/File/i;
                    my $file = $parms{to_file};

                    #                   $file = "$main::config_parms{wine_path_temp}/mh_voice_text.wav" if $speak_engine =~ /naturalvoicewine/i;
                    $speak_pgm .= " -o $file";
                }

                # Use either of these ... use_stdin has problems with mh -tk 1
                $parms{text} =~ s/\"/\'/g;    # Leave ' for use in I've etc
                $speak_pgm = qq[echo "$parms{text}" | $speak_pgm];

                #               $speak_pgm_use_stdin = 1;

                $speak_pgm .= " > /dev/null"
                  unless $main::Debug{voice} and $main::Debug{voice} > 1;
            }
            elsif ( $speak_pgm eq 'say' ) {
                system "say $parms{text}";

                #my $volume_reset = GetDefaultOutputVolume();
                #SetDefaultOutputVolume(2**$parms{volume}) if $parms{volume};
                #SpeakText($VTxt_mac, $parms{text});
                #SetDefaultOutputVolume(2**$volume_reset)  if $parms{volume};
                #               sleep 1 while SpeechBusy();
            }
            elsif ( $speak_pgm eq 'osascript' ) {
                $parms{text} =~ s/\"/\'/g;    # Leave ' for use in I've etc
                if ( $parms{volume} ) {
                    $parms{volume} = int( 7 * $parms{volume} / 100 )
                      if $parms{volume} > 7;
                    $speak_pgm_arg .= qq[ -e 'set volume $parms{volume}'];
                }
                $speak_pgm_arg .= qq[ -e 'say "$parms{text}"'];

                # Reset to previous level ... how do we get that??
                if ( $parms{volume_reset} ) {
                    $speak_pgm_arg .= qq[ -e 'set $parms{volume_reset}'];
                }
            }
            elsif ( $speak_engine =~ /(theta|swift)/i ) {

                $speak_pgm_arg .= " -S $parms{pitch}" if $parms{pitch};
                $speak_pgm_arg .= " -r $parms{rate}"  if $parms{rate};
                if ( $speak_engine eq 'theta' ) {
                    $speak_pgm_arg .= ' -N ' . "'$parms{voice}'"
                      if $parms{voice};
                }
                else {
                    $speak_pgm_arg .= ' -n ' . "'$parms{voice}'"
                      if $parms{voice};
                }
                $speak_pgm_arg .= ' -o ' . $parms{to_file}
                  if $parms{to_file};    # Not working yet??
                $speak_pgm_arg .= qq[ "$parms{text}"];
            }

            # Not sure what other programs are being used here
            else {
                $speak_pgm_arg .= qq[ "$parms{text}"];
                $speak_pgm_arg .= " -volume  $parms{volume}" if $parms{volume};
                $speak_pgm_arg .= " -pitch   $parms{pitch}" if $parms{pitch};
                $speak_pgm_arg .= " -rate    $parms{rate}" if $parms{rate};
                $speak_pgm_arg .= " -voice   '$parms{voice}'" if $parms{voice};
                $speak_pgm_arg .= " -to_file $parms{to_file}"
                  if $parms{to_file};
            }

            print
              "Voice_text TTS: f=$fork stdin=$speak_pgm_use_stdin p=$speak_pgm a=$speak_pgm_arg to_file=$parms{to_file}\n"
              if $main::Debug{voice};

            if ($speak_pgm_use_stdin) {
                open VOICE, "| $speak_pgm $speak_pgm_arg";
                print VOICE $parms{text};
                close VOICE;

                #                exit 0 if $fork;
                if ($fork) {
                    if ($main::OS_win) {
                        exec 'true';
                    }
                    else {
                        &POSIX::_exit(0);
                    }
                }
            }
            elsif ($fork) {
                system qq[$speak_pgm $speak_pgm_arg];

                # if ($? == -1) {
                # 	print "can't execute $speak_pgm $speak_pgm_arg: rc is $? and  $!\n";
                # 	exit;
                #	}
                # Send voice text to waiting web clients
                &web_hook_callback(%parms);

                if ($main::OS_win) {
                    exec 'true';
                }
                else {
                    &POSIX::_exit(0);
                }

                #				exit;
                #                system qq[$speak_pgm $speak_pgm_arg];
                #                &main::copy("$main::config_parms{wine_path_temp}/mh_voice_text.wav", $parms{to_file})
                #                  if $parms{to_file} and $speak_engine =~ /naturalvoicewine/i;
                #                exit 0;
            }
            else {
                system qq[$speak_pgm $speak_pgm_arg];

                # Send voice text to waiting web clients
                &web_hook_callback(%parms);
            }
        }
    }
    elsif ( $vtxt_card or $VTxt_stream1 ) {
        print
          "Voice_Text.pm ms_tts: v=$VTxt_version comp=$parms{compression} async=$parms{async} to_file=$parms{to_file} VTxt=$vtxt_card text=$parms{'text'}\n"
          if $main::Debug{voice};
        if ( $VTxt_version eq 'msv5' ) {

            # Allow option to save speech to a wav file
            if ( $parms{to_file} ) {
                my $webFork = 0;

                # we only fork if we are asynchronously generating a file for Audrey.
                # otherwise, we can just use the native async capability

                $webFork = 1 if ( $parms{async} and defined $parms{to_file} );

                # this currently doesn't work - causes a strange "Bizarre SvType [92]" error at the fork line below
                # This is due to Win32::OLE not supporting forks!  Known problem, not yet fixed.
                # For now, force async=0 for Audrey on windows
                # Hopefully this will work sometime in the future.  :-(
                if ($webFork) {
                    $webFork = 0;
                    $parms{async} = 0;
                }

                # From sdk SpeechAudioFormatType:
                # SAFT8kHz8BitMono            =  4 (16k for for 4 words)
                # SAFT8kHz16BitMono           =  6 (32k)
                # SAFT11kHz8BitMono           =  8 (22k)
                # SAFT11kHz16BitMono          = 10 (44k)
                # SAFT22kHz16BitMono          = 22 (88k ... this is the default)
                # SAFTCCITT_ALaw_8kHzMono     = 41 (16k)
                # SAFTTrueSpeech_8kHz1BitMono = 40 (2k .. the most compressed, but not useable by Audrey)
                # SAFTCCITT_uLaw_8kHzMono     = 48 (176k)
                # SAFTADPCM_8kHzMono          = 56 (176k)
                # SAFTGSM610_8kHzMono         = 64 (88k?? ... this is the same as the default)
                # SAFTGSM610_11kHzMono        = 65 (3k .. not useable on CE3 CompaQ IA1)
                # SAFTGSM610_22kHzMono        = 66 (5k .. not choppy like above 11kHz mode)
                # SAFTGSM610_44kHzMono        = 67 (9k)

                # we are asynchronously generating a file for Audrey, so we need to fork a child process
                # so that we can wait around for the file to get created.  Once created, we notify
                # Audrey that the file is ready through &::file_ready_for_audrey

                if ($webFork) {
                    my $pid = fork;

                    # if we are the child
                    if ( !defined($pid) ) {

                        # fork failed
                        warn('fork failed when trying to create Audrey TTS');
                    }
                    elsif ( $pid == 0 ) {

                        # we are the child process
                        $VTxt_stream2 = Win32::OLE->new('Sapi.SpFileStream');
                        $VTxt_stream2->{Format}->{Type} =
                          22;    # see table above for constant defs
                        $VTxt_stream2->{Format}->{Type} = $parms{compression}
                          if $parms{compression} =~ /^\d+$/;
                        $VTxt_stream2->{Format}->{Type} = 20
                          if $parms{compression} eq 'low';
                        $VTxt_stream2->{Format}->{Type} = 66
                          if $parms{compression} eq 'high';
                        $VTxt_stream2->Open( $parms{to_file}, 3, 0 );
                        $VTxt_stream1->{AudioOutputStream} = $VTxt_stream2;
                        $VTxt_stream1->Speak( $parms{text}, 8 )
                          ;      # Flags: 8=XML (no async, so we can close)
                        $VTxt_stream2->Close;

                        # at this point, the file _should_ be ready for Audrey
                        undef $VTxt_stream2;

                        # Send voice text to waiting web clients
                        &web_hook_callback(%parms);

                        # child is done all its work
                        exec 'true';
                    }
                    else {
                        # we are the parent - $pid will contain process ID
                        # so we have nothing special to do
                        return;
                    }
                }
                else {
                    if ($VTxt_stream1) {
                        $VTxt_stream2 = Win32::OLE->new('Sapi.SpFileStream');
                        $VTxt_stream2->{Format}->{Type} =
                          22;    # see table above for constant defs
                        $VTxt_stream2->{Format}->{Type} = $parms{compression}
                          if $parms{compression} =~ /^\d+$/;
                        $VTxt_stream2->{Format}->{Type} = 20
                          if $parms{compression} eq 'low';
                        $VTxt_stream2->{Format}->{Type} = 66
                          if $parms{compression} eq 'high';
                        $VTxt_stream2->Open( $parms{to_file}, 3, 0 );
                        $VTxt_stream1->SetProperty( 'AudioOutputStream',
                            $VTxt_stream2 );
                        if ( $parms{async} ) {
                            $VTxt_stream1->Speak( $parms{text}, 1 + 8 )
                              ;    # Flags: 1=async 8=XML
                        }
                        else {
                            $VTxt_stream1->Speak( $parms{text}, 8 )
                              ;    # Flags: 8=XML (no async, so we can close)
                            $VTxt_stream2->Close;
                            undef $VTxt_stream2;

                            # Send voice text to waiting web clients
                            &web_hook_callback(%parms);
                        }
                    }
                    else {
                        &main::print_log(
                            "WARN: no file could be produced for audrey.");
                    }
                }
            }
            else {
                #               $vtxt_card->Speak($parms{text}, 1 + 2 + 8); # Flags: 1=async  2=purge  8=XML
                unless ($vtxt_card
                    and $vtxt_card->Speak( $parms{text}, 1 + 8 ) )
                {
                    print "Voice_Text error: parms=@_\n"
                      ;    #  error=" .  Win32::OLE->LastError() . "\n";
                }
            }
        }

        # Older engine
        else {
            if ( $parms{to_file} ) {
                &main::print_log(
                    "speak -to_file not supported with tts engine msv4.  Text=$parms{text}"
                );
                return;
            }

            # Turn off vr while speaking ... SB live card will listen while speaking!
            #  - this doesn't work.  TTS does not start right away.  Best to poll in Voice_Cmd
            #           &Voice_Cmd::deactivate;

            my (%priority) = (
                'normal'   => hex(200),
                'high'     => hex(100),
                'veryhigh' => hex(80)
            );
            my (%type) = (
                'statement'   => hex(1),
                'question'    => hex(2),
                'command'     => hex(4),
                'warning'     => hex(8),
                'reading'     => hex(10),
                'numbers'     => hex(20),
                'spreadsheet' => hex(40)
            );
            $parms{type}     = 'statement' unless $parms{'type'};
            $parms{speed}    = 170         unless $parms{'speed'};
            $parms{priority} = 'normal'    unless $parms{priority};
            $priority{ $parms{'priority'} } = $parms{'priority'}
              if $parms{'priority'} =~ /\d+/;    # allow for direct parm

            #           $vtxt_card->{'Speed'} = $parms{'speed'} if defined $parms{'speed'};
            my ( $priority, $type, $voice );
            $priority = $priority{ $parms{'priority'} };
            $type     = $type{ $parms{'type'} };

            #           $voice = qq[\\Vce=Speaker="$parms{voice}"\\] if $parms{voice};
            $voice = '' unless $voice;

            print "Voice_Text.pm ms_tts: VTxt=$vtxt_card text=$parms{'text'}\n"
              if $main::Debug{voice};
            $vtxt_card->Speak( $voice . $parms{'text'}, $priority );

            #           $vtxt_card->Speak($parms{'text'}, ($priority | $type));
            #           $vtxt_card->Speak('Hello \Chr="Angry"\ there. Bruce is \Vce=Speaker=Biff\ a very smart idiot guy.', hex('201'));
        }

    }
    else {
        print "Can not speak for engine=$speak_engine: Phrase=$parms{text}\n"
          if $speak_engine;
    }

}

sub is_speaking {
    my ($card) = @_;
    $card = 0 unless $card;
    $card = $VTxt_cards{$card} if $VTxt_cards{$card}; # Allow for text card name

    # Allow for a check of all cards
    if ( lc $card eq 'any' ) {
        my $speaking_flag = 0;
        for my $cardn ( 1 .. $#VTxt ) {
            next unless $VTxt[$cardn];
            $speaking_flag++ if &is_speaking($cardn);
        }
        return $speaking_flag;
    }

    #   print "db c=$card vt=$VTxt[$card] vt=@VTxt\n";
    if ( @VTxt and $VTxt[$card] ) {
        if ( $VTxt_version eq 'msv5' ) {

            # Either of these methods work. Benchmark show both use little cpu time.
            #           return      $VTxt[$card]->WaitUntilDone(0);
            return 2 == $VTxt[$card]->Status->{RunningState};
        }
        else {
            return $VTxt[$card]->{IsSpeaking};    # I think this is slow
        }
    }
    elsif ($VTxt_pid) {
        return 1 unless waitpid( $VTxt_pid, 1 );
        unset $is_speaking_timer;
        undef $VTxt_pid;
        return 0;
    }
    else {
        return active $is_speaking_timer;
    }
}

sub is_speaking_wav {
    if ($VTxt_stream1) {

        # I RunningState does not work with streams, but
        # WaitUntilDone does (returns 0 while speaking)
        my $rc = $VTxt_stream1->WaitUntilDone(0);
        if ($rc) {
            $VTxt_stream2->Close;
            undef $VTxt_stream2;
        }
        return !$rc;
    }

    # Festival will echo back when it is done generating speech
    # Note: This does NOT work with live speech, as it finished
    #       generating that before it finishes speaking it.
    elsif ( $VTxt_festival and active $is_speaking_timer) {

        # Either of these should work
        #       my $d=&main::socket_has_data($main::Socket_Ports{festival}{sock});
        my $s = said $VTxt_festival;

        #	print "s=$s d=$d ";
        if ($s) {
            unset $is_speaking_timer;
            select undef, undef, undef, .2;    # Need this ?
        }
        return active $is_speaking_timer;
    }
    else {
        return &is_speaking();
    }
}

# This has been moved to mh.  Leave this stub in so
# we don't break old user code
sub last_spoken {
    my ($how_many) = @_;
    &main::speak_log_last($how_many);
}

sub list_voices {

    #   return @voice_names;
    #   &read_parms unless %voice_names;  # Don't need this ... now called on startup.
    return ( sort keys %voice_names );
}

sub list_voice_names {
    return @voice_names;
}

sub read_parms {

    # Read in voice name translation and list of available voices
    &main::read_parm_hash( \%voice_names, $main::config_parms{voice_names} );
    my %temp = reverse %voice_names;
    @voice_names = sort keys %temp;
    print "Voice names: " . join( ', ', @voice_names ) . "\n";

    my $pronouncable_list_file = $main::config_parms{pronouncable_list_file};
    if ( $pronouncable_list_file
        and ( $::Startup or main::file_change($pronouncable_list_file) ) )
    {
        my ( $phonemes, $word, $cnt );
        open( WORDS, $pronouncable_list_file )
          or print
          "\nError, could not find the pronouncable word file $pronouncable_list_file: $!\n";
        undef %pronouncable;
        while (<WORDS>) {
            next if /^\#/;
            ( $word, $phonemes ) = $_ =~ /^(\S+)\s+(.+)\s*$/;
            next unless $word;
            $cnt++;
            $pronouncable{$word} = $phonemes;
        }
        print "Read $cnt entries from $pronouncable_list_file\n";
        close WORDS;
    }

}

sub set_mode {
    my ( $mode, $vtxt_card ) = @_;
    $mode = lc $mode;
    print "Setting mode to $mode for card=$vtxt_card\n"
      if $mode and $main::Debug{voice};

    # Only MS TTS for now
    if (@VTxt) {
        if ( $VTxt_version eq 'msv5' ) {
            return $vtxt_card->Skip( 'Sentence', 99999 ) if $mode eq 'stop';
            return $vtxt_card->Pause  if $mode eq 'pause';
            return $vtxt_card->Resume if $mode eq 'resume';
            return $vtxt_card->Skip( 'Sentence', 5 )  if $mode eq 'fastforward';
            return $vtxt_card->Skip( 'Sentence', -5 ) if $mode eq 'rewind';
            return $vtxt_card->Skip( 'Sentence', $1 )
              if $mode =~ /forward_(\d+)/;
            return $vtxt_card->Skip( 'Sentence', -$1 )
              if $mode =~ /rewind_(\d+)/;
        }
        else {
            return $vtxt_card->StopSpeaking     if $mode eq 'stop';
            return $vtxt_card->AudioPause       if $mode eq 'pause';
            return $vtxt_card->AudioResume      if $mode eq 'resume';
            return $vtxt_card->AudioFastForward if $mode eq 'fastforward';
            return $vtxt_card->AudioRewind      if $mode eq 'rewind';
        }
    }
}

sub set_pitch {
    my ( $pitch, $text ) = @_;

    # Only MS TTS v5 for now
    if ( $VTxt_version eq 'msv5' ) {

        # Only xml support, so only for the specified text
        if ($text) {
            return "<pitch absmiddle='$pitch'/> " . $text;
        }
        else {
            print "\nError, no support for setting the default pitch\n";
            return;
        }
    }
    else {
        return $text;
    }
}

sub set_rate {
    my ( $rate, $text, $vtxt_card ) = @_;

    # Only MS TTS for now
    return $text unless @VTxt;

    if ( $VTxt_version eq 'msv4' ) {
        $vtxt_card->{Speed} = 250   if $rate eq 'fast';
        $vtxt_card->{Speed} = 200   if $rate eq 'normal';
        $vtxt_card->{Speed} = 150   if $rate eq 'slow';
        $vtxt_card->{Speed} = $rate if $rate =~ /^\d+$/;
        return $text;
    }
    else {
        $rate = 4  if $rate eq 'fast';
        $rate = 0  if $rate eq 'normal';
        $rate = -4 if $rate eq 'slow';

        # If text is given, set for just this text with XML.  Otherwise change the default
        if ($text) {
            return "<rate absspeed='$rate'/> " . $text;
        }
        else {
            $vtxt_card->{Rate} = $rate;
            return;
        }
    }

}

sub set_volume {
    my ( $volume, $text, $vtxt_card ) = @_;

    # Only MS TTS v5 for now
    if ( $VTxt_version eq 'msv5' ) {

        # AT&T docs say range is 0 -> 200, but
        # I saw no difference between 100 and 200
        #       $volume *= 2;           # Volume range is 0 -> 200

        # If text is given, set for just this text with XML.  Otherwise change the default
        if ($text) {

            #           return "<volume level='$volume'/> " . $text;
            return "<volume level='$volume'> $text </volume>";
        }
        else {
            $vtxt_card->{Volume} = $volume;
            return;
        }
    }
    else {
        return $text;
    }
}

sub set_voice {
    my ( $voice, $text, $speak_engine, $vtxt_card ) = @_;

    return $text unless $voice;

    $speak_engine = $main::config_parms{voice_text} unless $speak_engine;

    # Override according to mh.ini voice_names list
    $voice = $voice_names{ lc $voice } if $voice_names{ lc $voice };

    # Random pick from the list in the mh.ini voice_names parm
    if ( $voice eq 'random' ) {
        my $i = int( (@voice_names) * rand );
        $voice = $voice_names[$i];
        print "Setting random voice.  i=$i voice=$voice\n"
          if $main::Debug{voice};
    }
    elsif ( $voice eq 'next' ) {
        $voice_names_index = 1 if ++$voice_names_index > @voice_names;
        $voice = $voice_names[ $voice_names_index - 1 ];
        print "Setting next voice.  index=$voice_names_index voice=$voice\n"
          if $main::Debug{voice};
    }

    # This option is just plain goofy.  Inspired by dictionaraoke.org
    # Works only for xml enabled engines like MSv5 or linux NaturalVoices
    elsif ( $voice eq 'all' ) {
        my @words = split ' ', $text;
        $text = '';
        for my $word (@words) {
            $voice_names_index = 1 if ++$voice_names_index > @voice_names;
            $text .=
              "<voice required='Name=$voice_names[$voice_names_index-1]'>$word</voice> ";
        }
        return $text . '.';    # Add . or last word is not spoken??
    }

    if ( ( $VTxt_version and $VTxt_version eq 'msv5' )
        or $speak_engine =~ /naturalvoice/i )
    {
        my $spec;
        if ( $voice =~ /female/i ) {
            $spec .= "Gender=Female;";
        }
        elsif ( $voice =~ /male/i ) {
            $spec .= "Gender=Male;";
        }
        if ( $voice =~ /child/i ) {
            $spec .= "Age=Child;";
        }
        elsif ( $voice =~ /grownup/i ) {
            $spec .= "Age=!Child;";
        }

        # Old code
        if ( 0 and $voice =~ /random/ ) {
            my ( @voices, $object );

            #           @voices = Win32::OLE::in $vtxt_card->GetVoices($spec);
            # Filter out unusual voices
            for $object ( Win32::OLE::in $vtxt_card->GetVoices($spec) ) {
                next if $object->GetDescription eq 'Sample TTS Voice';
                next
                  if $object->GetDescription eq 'MS Simplified Chinese Voice';
                push @voices, $object;
            }
            my $i = int( (@voices) * rand );
            $object = $voices[$i];
            $spec   = "Name=" . $object->GetDescription;
            print "Setting random voice.  i=$i spec=$spec\n";
        }

        unless ($spec) {

            #           $spec = "Name=Microsoft $voice";
            #           $spec = "Name=ATT DTNV 1.3 $voice";
            $spec = "Name=$voice";
        }

        print "Setting xml voice ($voice) to spec=$spec\n"
          if $main::Debug{voice};

        # If text is given, set for just this text with XML.  Otherwise change the default
        if ($text) {
            return "<voice required='$spec'> " . $text . " </voice>";
        }

        # First voice returned is the best fit
        elsif ($VTxt_version) {
            for my $object ( Win32::OLE::in $vtxt_card->GetVoices($spec) ) {
                print "Setting voice ($voice) to $spec: $object\n"
                  if $main::Debug{voice};
                $vtxt_card->{Voice} = $object;
                return;
            }
        }
    }
    elsif ( $voice and $speak_engine =~ /festival/i ) {
        return "<SPEAKER NAME='$voice'> " . $text . " </SPEAKER>";
    }
    else {
        return $text;
    }
}

sub force_pronounce {
    my ( $phrase, $parmsRef ) = @_;

    print "input  phrase is '$phrase'\n" if $main::Debug{voice};

    if ( not $parmsRef->{raw_numbers} ) {

        # convert long numbers to their text equivalent
        while ( $phrase =~ /^(.*?)(\d{3,})(.*?)$/ ) {
            $phrase = $1 . &num_to_text($2) . $3;
        }
    }

    for my $word ( keys %pronouncable ) {
        if ( $word =~ /^regex/ ) {    # Allow for regexs
            eval "\$phrase =~ $pronouncable{$word}";
        }
        else {
            $phrase =~ s/\b$word\b/$pronouncable{$word}/gi;
        }
    }

    print "output phrase is '$phrase'\n" if $main::Debug{voice};
    return $phrase;
}

sub num_to_text {
    my $num = shift;

    my $lang = $::config_parms{language}
      || 'en';

    my $text = Lingua::Num2Word::cardinal( $lang, $num )
      || 'num to text error';

    return $text;
}

1;
