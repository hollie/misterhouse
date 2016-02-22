
# Category = xAP

#@ This code sends out various mh source data data as xAP messages, for use with other xAP enabled clients.
#@ xap_echo_all defaults to enabled (1).  To selectively enable only certain functions, set xap_echo_all=0
#@ and enable individual echo parms (e.g., xap_echo_speech=1).  xap_echo_speech allows compatibility with
#@ the standard tts.speak xAP schema (that non-mh apps use).  xap_echo_mhspeech allows peer-based, speech
#@ proxies.

use Weather_Common;

# default to echoing to all clients (possible not a smart idea)
my $xap_echo_all = $config_parms{xap_echo_all};
$xap_echo_all = 1 unless defined $xap_echo_all;

# Send weather data
if ( new_minute 1 and ( $xap_echo_all or $config_parms{xap_echo_weather} ) ) {

    # Scheme from: From: http://www.xapautomation.org/modules.php?name=Sections&op=viewarticle&artid=2
    my $f_date =
        $Year
      . ( ( length($Month) == 1 ) ? '0' : '' )
      . $Month
      . ( ( length($Mday) == 1 ) ? '0' : '' )
      . $Mday;
    my $f_tod = ($Dark) ? 'Night' : 'Day';
    my $f_time =
        ( ( length($Hour) == 1 ) ? '0' : '' )
      . $Hour . ':'
      . ( ( length($Minute) == 1 ) ? '0' : '' )
      . $Minute . ':'
      . ( ( length($Second) == 1 ) ? '0' : '' )
      . $Second;
    my ( $sunriseh, $sunrisem, $sunrisec ) =
      $Time_Sunrise =~ /(\S+):(\S+) (\S+)/;
    $sunriseh += 12 if $sunrisec =~ /pm/i;
    my ( $sunseth, $sunsetm, $sunsetc ) = $Time_Sunset =~ /(\S+):(\S+) (\S+)/;
    $sunseth += 12 if $sunsetc =~ /pm/i;
    my $utctime = gmtime($Time);
    my ($f_utc) = $utctime =~ /^\S+ \S+ \S+ (\d+:\d+):\d+ \S+$/;

    my $windspeedc = ( $config_parms{weather_uom_wind} =~ /mph/i ) ? 'M' : 'K';
    my $tempc      = ( $config_parms{weather_uom_temp} =~ /^f$/i ) ? 'F' : 'C';

    my $f_description =
        $Weather{Clouds}
      . ( ( $Weather{Clouds} ) ? ' ' : '' )
      . $Weather{Conditions};
    my $conditions =
      ( $Weather{Conditions} ) ? $Weather{Conditions} : $Weather{Clouds};
    my $f_icon = '';
    if ( $conditions eq 'broken clouds' ) {
        $f_icon = 'clouds1';
    }
    elsif ( $conditions =~ /clear/i ) {
        $f_icon = 'sunny';
    }

    my $f_winddir =
      &Weather_Common::convert_wind_dir_to_abbr( $Weather{WindAvgDir} );

    my ( $weatherrpt, $timerpt );
    $weatherrpt->{'UTC'}             = $f_utc;
    $weatherrpt->{'DATE'}            = $f_date;
    $weatherrpt->{"Wind$windspeedc"} = $Weather{WindAvgSpeed}
      if exists $Weather{WindAvgSpeed};
    $weatherrpt->{"WindGusts$windspeedc"} = $Weather{WindGustSpeed}
      if exists $Weather{WindGustSpeed};
    $weatherrpt->{'WindDirD'} = $Weather{WindAvgDir}
      if exists $Weather{WindAvgDir};
    $weatherrpt->{'WindDirC'}   = $f_winddir;
    $weatherrpt->{"Temp$tempc"} = $Weather{TempOutdoor}
      if exists $Weather{TempOutdoor};
    $weatherrpt->{"Dew$tempc"} = $Weather{DewOutdoor}
      if exists $Weather{DewOutdoor};
    $weatherrpt->{'AirPressure'} = $Weather{Barom} if exists $Weather{Barom};
    $weatherrpt->{'Icon'}        = $f_icon;
    $weatherrpt->{'Description'} = $f_description if $f_description;
    $timerpt->{'TOD'}            = $f_tod;
    $timerpt->{'Time'}           = $f_time;
    $timerpt->{'SunRise'}        = "$sunriseh:$sunrisem";
    $timerpt->{'SunSet'}         = "$sunseth:$sunsetm";

    &xAP::send(
        'xAP', 'Weather.Report',
        'Weather.Report' => $weatherrpt,
        'Time'           => $timerpt
    );
}

# Echo incoming X10 data
&Serial_data_add_hook( \&xAP_send_x10 )
  if $Reload and ( $xap_echo_all or $config_parms{xap_echo_x10} );

sub xAP_send_x10 {
    my ($data) = @_;
    return unless $data =~ /^X(\S+)/;

    #   print "x10 data: $data\n";
    #   &xAP::send('xAP', 'xap-x10.event', 'xap-x10.event' => {device => 'M10', event => 'on'});
    &xAP::send( 'xAP', 'xap-x10.data', 'xap-x10.data' => { data => $data } );
}

# Send spoken data, if we have a local speech engine
#  - This is also done in code/common/display_slimserver.pl
&Speak_parms_add_hook( \&xAP_send_tts_speak, 0 )
  if $Reload
  && $config_parms{voice_text}
  && ( $xap_echo_all or $config_parms{xap_echo_speech} );

&Speak_parms_add_hook( \&xAP_send_mhtts_speak, 0 )
  if $Reload
  && $config_parms{voice_text}
  && ( $xap_echo_all or $config_parms{xap_echo_mhspeech} );

sub xAP_send_tts_speak {
    my (%parms) = @_;
    my $mode = $parms{mode};
    unless ($mode) {
        if ( defined $mode_mh ) {
            $mode = state $mode_mh;
        }
        else {
            $mode = $Save{mode};
        }
    }
    return if $mode eq 'mute';
    &xAP_send_speak( 'tts.speak', @_ );
}

sub xAP_send_mhtts_speak {
    &xAP_send_speak( 'mhtts.speak', @_ );
}

sub xAP_send_speak {
    my ( $schema, $parms_ref ) = @_;

    return unless $$parms_ref{text} or $$parms_ref{file};

    #   return if $mode eq 'mute';

    my $requestor = $$parms_ref{requestor};

    #   prevent speak loops (across instances)
    return if $requestor =~ /^xap_echo/i;

    # Drop extra blanks and newlines
    $$parms_ref{text} =~ s/[\n\r ]+/ /gm;

    # For the mi4.biz client, documented here: http://www.mi4.biz/modules.php?name=Content&pa=showpage&pid=17
    my $tts_block;
    $tts_block->{'say'} = $$parms_ref{text};
    $tts_block->{'volume'} = $$parms_ref{'volume'} if $$parms_ref{'volume'};
    my $voice = $$parms_ref{'voice'};
    if ($voice) {
        my (%voice_names);
        &main::read_parm_hash( \%voice_names,
            $main::config_parms{voice_names} );
        if ( exists( $voice_names{$voice} ) ) {
            $voice = $voice_names{$voice};
        }
    }
    $tts_block->{'voice'} = $voice if $voice;
    if ( $schema eq 'tts.speak' ) {
        my $priority = lc $$parms_ref{'priority'};
        if ($priority) {
            if ( $priority eq 'high' ) {
                $tts_block->{'priority'} = 'yes';
            }
            else {
                $tts_block->{'priority'} = 'no';
            }
        }
        $tts_block->{'event'} = $$parms_ref{'rooms'}
          if defined $$parms_ref{'rooms'};
    }
    elsif ( $schema eq 'mhtts.speak' ) {
        $tts_block->{'device'} = $$parms_ref{'card'}
          if defined $$parms_ref{'card'};
        $tts_block->{'mode'} = $$parms_ref{'mode'}
          if defined $$parms_ref{'mode'};
        $tts_block->{'app'} = $$parms_ref{'app'} if defined $$parms_ref{'app'};
        $tts_block->{'requestor'} = $$parms_ref{'requestor'}
          if defined $$parms_ref{'requestor'};
        $tts_block->{'priority'} = $$parms_ref{'priority'}
          if defined $$parms_ref{'priority'};
    }
    &xAP::send( 'xAP', $schema, 'tts.speak' => $tts_block );
}

$_xap_speech_echo_obj = new xAP_Item('*tts.speak');
if ( $_xap_speech_echo_obj->state_now ) {
    my $source    = $_xap_speech_echo_obj->{'xap-header'}{source};
    my $classname = $_xap_speech_echo_obj->{'xap-header'}{class};
    return
      unless (
           ( ( $classname eq 'tts.speak' ) and $config_parms{xap_echo_speech} )
        or
        ( ( $classname eq 'mhtts.speak' ) and $config_parms{xap_echo_mhspeech} )
        or $xap_echo_all
      );
    my $local_xap_address = &xAP::get_xap_mh_source_info();
    my $text_to_speak     = $_xap_speech_echo_obj->{'tts.speak'}{say};
    print "DBG xAP speech echo source = $source says: $text_to_speak\n"
      if $main::Debug{xap_echo};
    return unless $text_to_speak;
    my $speak_info = "requestor=xap_echo[$source]";
    $speak_info .= " volume=" . $_xap_speech_echo_obj->{'tts.speak'}{volume}
      if $_xap_speech_echo_obj->{'tts.speak'}{volume};
    $speak_info .= " rooms=" . $_xap_speech_echo_obj->{'tts.speak'}{rooms}
      if $_xap_speech_echo_obj->{'tts.speak'}{rooms};
    $speak_info .= " app=" . $_xap_speech_echo_obj->{'tts.speak'}{app}
      if $_xap_speech_echo_obj->{'tts.speak'}{app};
    $speak_info .= " mode=" . $_xap_speech_echo_obj->{'tts.speak'}{mode}
      if $_xap_speech_echo_obj->{'tts.speak'}{mode};
    $speak_info .= " voice=" . $_xap_speech_echo_obj->{'tts.speak'}{voice}
      if $_xap_speech_echo_obj->{'tts.speak'}{voice};
    $speak_info .= " priority=" . $_xap_speech_echo_obj->{'tts.speak'}{priority}
      if $_xap_speech_echo_obj->{'tts.speak'}{priority};
    $speak_info .= " card=" . $_xap_speech_echo_obj->{'tts.speak'}{device}
      if $_xap_speech_echo_obj->{'tts.speak'}{device};
    $speak_info .= " " . $text_to_speak;
    &main::speak($speak_info);
}

# Enable 'display device=alpha text' to send data to remote Alpha LED display
sub display_alpha {
    my %parms = @_;
    $parms{duration} = 15 unless $parms{duration};
    $parms{mode}     = 'Hold';
    $parms{color}    = 'Yellow';
    &xAP::send( 'xAP', 'xAP-OSD.Display', 'Display.Alpha' => {%parms} );
}
