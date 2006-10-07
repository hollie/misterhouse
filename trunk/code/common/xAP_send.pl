
# Category = xAP

#@ This code sends out various mh source data data as xAP messages, for use with other xAP enabled clients.

                                # Send weather data
if (new_minute 1) {
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
&Serial_data_add_hook(\&xAP_send_x10) if $Reload;

sub xAP_send_x10 {
    my ($data) = @_;
    return unless $data =~ /^X(\S+)/;
#   print "x10 data: $data\n";
#   &xAP::send('xAP', 'xap-x10.event', 'xap-x10.event' => {device => 'M10', event => 'on'});
    &xAP::send('xAP', 'xap-x10.data', 'xap-x10.data' =>   {data  => $data});
}


                                # Send spoken data, if we have a local speech engine
                                #  - This is also done in code/common/display_slimserver.pl
&Speak_parms_add_hook(\&xAP_send_speak, 0) if $Reload && $config_parms{voice_text};


sub xAP_send_speak {
    my ($parms_ref) = @_;

    return unless $$parms_ref{text} or $$parms_ref{file};
#   return if $mode eq 'mute';

                                # Drop extra blanks and newlines
    $$parms_ref{text} =~ s/[\n\r ]+/ /gm;
# For the mi4.biz client, documented here: http://www.mi4.biz/modules.php?name=Content&pa=showpage&pid=17
    &xAP::send('xAP', 'tts.speak', 'tts.speak' =>
               {Say => $$parms_ref{text}, Volume => $$parms_ref{volume}, Voice => $$parms_ref{voice}, mode => $$parms_ref{mode},
                Priority  => $$parms_ref{priority}, Rooms => $$parms_ref{rooms},
                Device    => $$parms_ref{card},
                Requestor => $$parms_ref{requestor}
               });
}


                                 # Enable 'display device=alpha text' to send data to remote Alpha LED display
sub display_alpha {
    my %parms = @_;
    $parms{duration} = 15 unless $parms{duration};
    $parms{mode}     = 'Hold';
    $parms{color}    = 'Yellow';
    &xAP::send('xAP', 'xAP-OSD.Display', 'Display.Alpha' => {%parms});
}
