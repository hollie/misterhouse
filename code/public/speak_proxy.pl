
=begin comment

Use this code to speak to distributed mh clients.  
Run mh_proxy on each target computer, enabling the voice_text parm.
Also use parms like these on your main mh box to enable the ports:
 
  speak_study_port  = proxy 192.168.0.4:8085
  speak_piano_port  = proxy 192.168.0.85:8085
  speak_art_port    = proxy 192.168.0.100:8085

See 'Use distributed MisterHouse proxies' in mh/docs/mh.*  for more info.

=cut

&Speak_pre_add_hook( \&proxy_speak_play, 0, 'speak' ) if $Reload;
&Play_pre_add_hook( \&proxy_speak_play, 0, 'play' ) if $Reload;

my %proxy_by_room = (
    study => '192.168.0.3:8085',
    piano => '192.168.0.85:8085',
    art   => '192.168.0.100:8085'
);

$test_voice_proxy = new Voice_Cmd 'Test proxy speak to [all,study,piano,art]';
$test_voice_proxy->tie_event('speak "rooms=$state Testing speech to $state"');

# speak "rooms=all The time is $Time_Now" if new_second 15;

sub proxy_speak_play {
    my ($mode)  = pop @_;
    my (%parms) = @_;

    return unless $Run_Members{speak_proxy};
    return unless $parms{text} or $parms{file};

    # We have a proxyip (e.g. common/mhsend_server.pl), so find our system to send to.
    if ( $parms{proxyip} ) {
        for my $key (%proxy_by_room) {

            #should be smarter about this, but for now...
            if ( $proxy_by_room{$key} eq $parms{proxyip} . ':8085' ) {

                #Figure out how to override or keep an existing
                #rooms variable. How should we do it? Always override
                #or always defer?
                $parms{rooms} = $key;
            }
        }
    }

    #   print "proxy_play mode=$mode parms: @_\n";
    # Drop extra blanks and newlines
    $parms{text} =~ s/[\n\r ]+/ /gm;

    my @rooms = split ',', lc $parms{rooms};
    @rooms = sort keys %proxy_by_room if lc $parms{rooms} eq 'all';
    for my $room (@rooms) {
        next unless my $address = $proxy_by_room{$room};
        print "Sending speech to proxy room=$room address=$address\n";

        # Filter out the blank parms
        %parms = map { $_, $parms{$_} } grep $parms{$_} =~ /\S+/, keys %parms;
        &main::proxy_send( $address, $mode, %parms );
    }
}

# Check proxies.  If down, this is slow (1-2 seconds), so don't do it too often
use Net::Ping;
if ( new_minute(1) ) {
    for my $address ( keys %proxy_servers ) {
        my ( $addr, $trash ) = split /:/, $address;
        my $p = Net::Ping->new();
        if ( $p->ping($addr) ) {
            my $proxy = $proxy_servers{$address};
            if ( !$proxy->active ) {
                unless ( $proxy->start ) {
                    &print_log("Proxy is dead: $address");
                    $address =~ s/\:\d+$//;    # Shorten up name for speaking
                    $address =~ s/.+\.(\d+)$/$1/;

                    #&speak("proxy $address is dead") if &new_minute(2);
                    next;
                }
            }
        }
        else {
            &print_log("Proxy is dead: $address");
        }
        $p->close();
    }
}

# An alternate test ... not sure which is best
if ( 0 and new_second(5) ) {
    for my $address ( keys %proxy_servers ) {
        my $proxy = $proxy_servers{$address};
        if ( !$proxy->active ) {
            unless ( $proxy->start ) {
                &print_log("Proxy is dead: $address");
                $address =~ s/\:\d+$//;    # Shorten up name for speaking
                $address =~ s/.+\.(\d+)$/$1/;
                &speak("proxy $address is dead") if &new_minute(2);
                next;
            }
        }
    }
}
