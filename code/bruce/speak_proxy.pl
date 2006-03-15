# Category = MisterHouse

#@ Sends speak text and play wav files to proxy clients

=begin comment

Use this code to speak to distributed mh clients.  
Run mh_proxy on each target computer, enabling the voice_text parm.
Also use parms like these on your main mh box to enable the ports:
 
  speak_study_port  = proxy 192.168.0.4:8085
  speak_piano_port  = proxy 192.168.0.85:8085
  speak_art_port    = proxy 192.168.0.100:8085

See 'Use distributed MisterHouse proxies' in mh/docs/mh.*  for more info.

=cut

# Log hook is not muted like speak hook is
&Speak_pre_add_hook(\&proxy_speak_play, 0, 'speak') if $Reload;
#Log_Hooks_add_hook(\&proxy_speak_play, 0, 'speak') if $Reload;

&Play_pre_add_hook (\&proxy_speak_play, 0, 'play')  if $Reload;

my %proxy_by_room = ( dj => '192.168.0.3:8085');
#                     piano => '192.168.0.85:8085',
#                     art   => '192.168.0.100:8085' );

$test_voice_proxy = new Voice_Cmd 'Test proxy speak to [all,study,piano,art]';
$test_voice_proxy -> tie_event('speak "rooms=$state Testing speech to $state"');

# speak "rooms=all The time is $Time_Now" if new_second 15;

sub proxy_speak_play {
    my ($mode) = pop @_;
    my (%parms) = @_;

    return unless $Run_Members{speak_proxy};
    return unless $parms{text} or $parms{file};

    print "proxy_play mode=$mode parms: @_\n" if $Debug{'proxy'};
                                # Drop extra blanks and newlines
    $parms{text} =~ s/[\n\r ]+/ /gm;

    my @rooms = split ',', lc $parms{rooms};
    push @rooms, 'dj';          # Announce all stuff to the shoutcast dj

    @rooms = sort keys %proxy_by_room if lc $parms{rooms} eq 'all';
    for my $room (@rooms) {
        next unless my $address = $proxy_by_room{$room};
        print "Sending speech to proxy room=$room address=$address\n" if $Debug{'proxy'};
                                # Filter out the blank parms
        %parms = map {$_, $parms{$_}} grep $parms{$_} =~ /\S+/, keys %parms;
        undef $parms{room};
        &main::proxy_send($address, $mode, %parms);
    }
}


# The following loads up a remote proxy system to allow it to receive speech.

$proxy_register = new Socket_Item(undef, undef, 'server_proxy_register');

if (my $datapart = said $proxy_register) {
    my ($pass, $ws, $port) = split /,/, $datapart;
    my $client = $Socket_Ports{'server_proxy_register'}{client_ip_address};
    if (my $user = password_check $pass, 'server_proxy_register') {
        print_log "Proxy accepted for:  $ws at $client";
        $proxy_by_room{$ws} = $client . ":$port";
        &add_proxy($client . ":$port");
    }
    else {
        print_log "Proxy denied for:  $ws at $client";
    }
    stop $proxy_register;
}

