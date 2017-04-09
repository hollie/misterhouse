# Category = IA7

#@   IA7 v1.1 : Enables speech notifications to browsers.
#@   also includes some sample code of how to use other notifications

if ( $Startup or $Reload ) {
    if ( !defined $Info{IPAddress_local} ) {
        print_log "json_server.pl: \$Info{IPAddress_local} not defined. Json speech disabled";
    }
    else {
        print_log "IA7 Speech Notifications enabled";
        &Speak_parms_add_hook( \&json_speech_enable );
    }
}

$v_ia7_test_sound  = new Voice_Cmd("Test playing a sound");
$v_ia7_test_banner = new Voice_Cmd("Test [blue,green,yellow,red] Banner Notification");

if ( my $said = said $v_ia7_test_banner) {
    my %data;
    $data{text}  = "This is a test of the IA7 notification";
    $data{color} = $said;
    &json_notification( "banner", {%data} );
}

if ( said $v_ia7_test_sound) {
    my %data;
    $data{url} = "http://" . $Info{IPAddress_local} . ":" . $config_parms{http_port} . "/misc/tellme_welcome.wav";
    &json_notification( "sound", {%data} );
}

sub json_speech_enable {
    my ($parms) = @_;
    push @{ $parms->{web_hook} }, \&file_ready_for_ia7;
}

sub file_ready_for_ia7 {
    my (%parms) = @_;
    my %data;
    $data{mode}   = $parms{mode};
    $data{url}    = "http://" . $Info{IPAddress_local} . ":" . $config_parms{http_port} . "/" . $parms{web_file};
    $data{text}   = $parms{raw_text};
    $data{client} = $parms{requestor};
    &json_notification( "speech", {%data} );
}

