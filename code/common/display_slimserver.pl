# Category = MisterHouse
# $Revision$
# $Date$

#@ Echos spoken text to a <a href="http://www.slimdevices.com">Slimp3 display</a>.
#@ Example mh.ini parms:  slimserver_clients=192.168.0.60:69,192.168.0.61:69  slimserver_server=192.168.0.2:9000

# Slimserver http controls are documented here:
#  http://www.slimdevices.com/documentation/http.html

&Speak_pre_add_hook( \&slimserver_display, 0 ) if $Reload;

#speak "The time is $Time_Now" if new_second 15;

my $slimdisplay = new Text_Cmd('slimdisplay\s*(.*)');
$slimdisplay->set_casesensitive() if $Reload;
$slimdisplay->tie_event('slimserver_display((text=>$state))') if $Reload;

sub slimserver_display {
    my (%parms) = @_;

    # use, in order, raw_text and then text.  If no text to display, return
    my $text = $parms{raw_text};
    $text = $parms{text} unless $text;
    return unless $text;

    return if $parms{nolog};    # Do not display if we are not logging

    my $duration = $config_parms{slimserver_duration};    # noloop
    $duration = 30 unless $duration;
    $duration = $parms{duration} if $parms{duration};

    # Drop extra blanks and newlines
    $text =~ s/[\n\r ]+/ /gm;

    print "slimserver request: $config_parms{slimserver_protocol} $text\n"
      if $Debug{'slimserver'};

    # This requires SlimServer Connector from: http://www.xapframework.net
    # This program also enables IR -> xAP data, even for non-slim IR data!
    if ( $config_parms{slimserver_protocol} eq 'xAP' ) {
        &xAP::send(
            'xAP',
            'xAP-OSD.Display',
            'Display.SliMP3' => {
                Line1      => $text,
                Line2      => ' ',
                Duration   => $duration,
                Size       => 'Double',
                Brightness => 'Brightest'
            }
        );
    }
    elsif ( lc( $config_parms{slimserver_protocol} ) eq 'xpl' ) {
        $config_parms{slimserver_players} = $config_parms{slimserver_player}
          unless $config_parms{slimserver_players};
        $text = "\\n$text" if $text !~ /\n/;
        for my $player ( split ',', $config_parms{slimserver_players} ) {
            $player =~ s/^\s*(.*)\s*$/$1/;
            &xAP::send( 'xPL', "slimdev-slimserv.$player",
                'osd.basic' =>
                  { command => 'write', text => $text, delay => $duration } );
        }
    }
    else {
        # Allow for player and/or players parm.  No Big or Brightest option here :(
        $config_parms{slimserver_players} = $config_parms{slimserver_player}
          unless $config_parms{slimserver_players};
        for my $player ( split ',', $config_parms{slimserver_players} ) {
            my $request =
              "http://$config_parms{slimserver_server}/status.txt?p0=display&p1=MisterHouse Message:&p2=${text}&p3=${duration}&player=${player}";
            get $request;
        }
    }
}
