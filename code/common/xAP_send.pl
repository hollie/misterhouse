
# Category = xAP

#@ This code sends out various mh source data data as xAP messages, for use with other xAP enabled clients.
#@ xap_echo_all defaults to enabled (1).  To selectively enable only certain functions, set xap_echo_all=0
#@ and enable individual echo parms (e.g., xap_echo_speech=1).  xap_echo_speech allows compatibility with
#@ the standard tts.speak xAP schema (that non-mh apps use).  xap_echo_mhspeech allows peer-based, speech
#@ proxies.

# default to echoing to all clients (possible not a smart idea)
my $xap_echo_all = $config_parms{xap_echo_all};
$xap_echo_all = 1 unless defined $xap_echo_all;

                                # Send weather data
if (new_minute 1 and ($xap_echo_all or $config_parms{xap_echo_weather})) {
# Scheme from: From: http://www.xapautomation.org/modules.php?name=Sections&op=viewarticle&artid=2
    &xAP::send('xAP', 'weather.report', 'weather.report' => {
          UTC  => "$Hour:$Minute",                DATE => scalar &time_date_stamp(19),
        WindM  => $Weather{WindAvgSpeed},     WindDirC => $Weather{AvgDir}, WindGustsM => $Weather{WindGustSpeed},
        TempF  => $Weather{TempOutdoor},   TempIndoorF => $Weather{TempIndoor},
        HumidF => $Weather{HumidOutdoor},  HumidIndoor => $Weather{HumidIndoor},
         DewF  => $Weather{DewOutdoor},    AirPressure => $Weather{Barom}
    } );
}

                                # Echo incoming X10 data
&Serial_data_add_hook(\&xAP_send_x10) if $Reload and ($xap_echo_all or $config_parms{xap_echo_x10});

sub xAP_send_x10 {
    my ($data) = @_;
    return unless $data =~ /^X(\S+)/;
#   print "x10 data: $data\n";
#   &xAP::send('xAP', 'xap-x10.event', 'xap-x10.event' => {device => 'M10', event => 'on'});
    &xAP::send('xAP', 'xap-x10.data', 'xap-x10.data' =>   {data  => $data});
}


                                # Send spoken data, if we have a local speech engine
                                #  - This is also done in code/common/display_slimserver.pl
&Speak_parms_add_hook(\&xAP_send_tts_speak, 0) 
   if $Reload && $config_parms{voice_text} && ($xap_echo_all or $config_parms{xap_echo_speech});

&Speak_parms_add_hook(\&xAP_send_mhtts_speak, 0) 
   if $Reload && $config_parms{voice_text} && ($xap_echo_all or $config_parms{xap_echo_mhspeech});


sub xAP_send_tts_speak {
   &xAP_send_speak('tts.speak',@_);
}

sub xAP_send_mhtts_speak {
   &xAP_send_speak('mhtts.speak',@_);
}


sub xAP_send_speak {
    my ($schema, $parms_ref) = @_;

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
    $tts_block->{'volume'} = $$parms_ref{'volume'} if defined $$parms_ref{'volume'};
    $tts_block->{'voice'} = $$parms_ref{'voice'} if defined $$parms_ref{'voice'};
    if ($schema eq 'tts.speak') {
       my $priority = lc $$parms_ref{'priority'};
       if ($priority) {
          if ($priority eq 'high') {
             $tts_block->{'priority'} = 'yes';
          } else {
             $tts_block->{'priority'} = 'no';
          }
       }
    } elsif ($schema eq 'mhtts.speak') {
       $tts_block->{'device'} = $$parms_ref{'card'} if defined $$parms_ref{'card'};
       $tts_block->{'mode'} = $$parms_ref{'mode'} if defined $$parms_ref{'mode'};
       $tts_block->{'app'} = $$parms_ref{'app'} if defined $$parms_ref{'app'};
       $tts_block->{'requestor'} = $$parms_ref{'requestor'} if defined $$parms_ref{'requestor'};
       $tts_block->{'priority'} = $$parms_ref{'priority'} if defined $$parms_ref{'priority'};
    }
    &xAP::send('xAP', $schema, 'tts.speak' => $tts_block);
}

$_xap_speech_echo_obj = new xAP_Item('*tts.speak');
if ($_xap_speech_echo_obj->state_now) {
   my $source = $_xap_speech_echo_obj->{'xap-header'}{source};
   my $classname = $_xap_speech_echo_obj->{'xap-header'}{class};
   return unless ((($classname eq 'tts.speak') and $config_parms{xap_echo_speech}) or
     (($classname eq 'mhtts.speak') and $config_parms{xap_echo_mhspeech}) or $xap_echo_all);
   my $local_xap_address = &xAP::get_xap_mh_source_info();
   my $text_to_speak = $_xap_speech_echo_obj->{'tts.speak'}{say};
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
    &xAP::send('xAP', 'xAP-OSD.Display', 'Display.Alpha' => {%parms});
}
