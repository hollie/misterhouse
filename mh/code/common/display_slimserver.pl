# Category = MisterHouse

#@ Echos spoken text to a Slimp3 display ( http://www.slimdevices.com ).
#@ Example mh.ini parms:  slimserver_clients=192.168.0.60:69,192.168.0.61:69  slimserver_server=192.168.0.2:9000

# Slimserver http controls are documented here:
#  http://www.slimdevices.com/documentation/http.html

&Speak_pre_add_hook(\&slimserver_display, 0) if $Reload;

#speak "The time is $Time_Now" if new_second 15;

sub slimserver_display {
    my (%parms) = @_;
                                # Drop extra blanks and newlines
    return unless $parms{text};

    return if $parms{nolog}; # Do not display if we are not logging

    $parms{text} =~ s/[\n\r ]+/ /gm;

    print "slimserver request: $config_parms{slimserver_protocol} $parms{text}\n" if $Debug{'slimserver'};

				# This requires SlimServer Connector from: http://www.xapframework.net
				# This program also enables IR -> xAP data, even for non-slim IR data!
    if ($config_parms{slimserver_protocol} eq 'xAP') {
        my $duration = $parms{duration} || 15;
        &xAP::send('xAP', 'xAP-OSD.Display', 'Display.SliMP3' => 
                   {Line1 => $parms{text}, Line2 => ' ', Duration => $duration, Size => 'Double', Brightness => 'Brightest'});
    }
    else {
				# Allow for player and/or players parm.  No Big or Brightest option here :(
        $config_parms{slimserver_players} = $config_parms{slimserver_player} unless $config_parms{slimserver_players};
        for my $player (split ',', $config_parms{slimserver_players}) {
            my $request = "http://$config_parms{slimserver_server}/status?p0=display&p1=MisterHouse Message:&p2=$parms{text}&p3=30&player=$player";
            get $request;
        }
    }
}


