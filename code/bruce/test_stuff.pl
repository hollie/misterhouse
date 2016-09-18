
# Category = Test

#@ Test stuff :)

# These 2 vars are general purpose test vars, used by various
# sections of this testbed code member.

# Do NOT save test_input1 ... if we get an codeing error, we don't
# want this saved or we will loop on the error.
my $test_input1;
&tk_entry( 'Test 1 (a..z)', \$test_input1, "Test 2", \$Save{test_input2} );
my $test_label = 'Test out:';

#&tk_label(\$test_label, \$Save{test_output});

if ( $state = $test_input1 ) {

    # Test the display function
    if ( $state eq 'a' ) {
        speak "Hello.  Test A reporting in.";
    }
    elsif ( $state eq 'b' ) {
        display( "This is from test_stuff", 10, "test stuff" );
    }

    # Test calling of sun_time
    elsif ( $state eq 'c' ) {
        print_log "testing sun_time";
        @ARGV = ();
        my $results = do 'sun_time'
          ;    # Use do so we can run from compiled mh, without perl installed
        print_msg "results=$results";
    }

    # Test read_next on a file of records
    elsif ( $state eq 'd' ) {
        my $plant_talk =
          new File_Item("$config_parms{data_dir}/remarks/list_plant_talk.txt");
        speak "Plant talk: " . read_next $plant_talk;
    }

    # Test call of a voice command.
    elsif ( $state eq 'e' ) {
        my ($time_test) = &time_date_stamp(5);
        print_log "test top10 list time=$time_test";
        run_voice_cmd 'Get the top 10 list';
    }

    # Test playing of a wave file
    elsif ( $state eq 'f' ) {
        print_log "Testing play of wave file";
        play( file => "sound_scratch1.wav" );

        #       play(file => "f:/bruce_songs4/gm.wav");
        play( file => "c:/win98/media/ctmelody.wav" );
        play( file => "hello_from_bruce.wav" );
        play( file => "sound_beep1.wav" );
    }

    # Test external tk call
    elsif ( $state eq 'g' ) {

        # Note: This will set test_output widget
        speak 'running tk_entry';
        @ARGV = ( \$Save{test_output}, "Enter test output data:" );
        do "tk_entry";
    }

    # Test str2time
    elsif ( $state eq 'h' ) {
        my $t1 = &my_str2time($Time_Sunset);
        my $t2 = &my_str2time("$Time_Sunset + 0:15");
        print_log "$Time_Sunset, $t1, $t2";
    }
    elsif ( $state eq 'i' ) {
        speak "Starting test timers";
        my $timer1 = new Timer();
        my $timer2 = new Timer();
        my $timer3 = new Timer();
        print "seting timers\n";
        set $timer1 10, 'speak "hi from timer 1"', 2;
        set $timer2 5,  'speak("hi from timer2")';
        set $timer3 30, 'display("hi from timer3")';
    }
    elsif ( $state eq 'j' ) {
        print_log "Display an image";
        if ($OS_win) {
            my $image = 'e:\\homepage\\bruce_with_pack.jpg';
            run "explorer $image";
        }
        else {
            my $image = '/home/httpd/html/homepage/bruce_with_pack.jpg';
            run "xv $image";
        }
    }

    # Test the batch function
    elsif ( $state eq 'k' ) {
        my @pgms = (
            "echo 'starting'",
            "sleep 5",
            "call speak 'starting test'",
            "sleep 5",
            "call speak 'all done'",
            "sleep 5"
        );
        batch(@pgms);
    }
    elsif ( $state eq 'l' and $Save{test_input2} ) {
        print_log "Doing load in $Save{test_input2}";
        do $Save{test_input2};
        print_log "Error: $@\n" if $@;

        #       do 'http_server.pl';
    }

    elsif ( $state eq 'm' ) {
        my @ip_address = get_ip_address( $Save{test_input2} );
        print_log "IP address for $Save{test_input2}: @ip_address";
    }

    # This is windows only for now
    elsif ( $state eq 'n' ) {
        print_log "Testing volume control";

        #        play(file => "hello_from_bruce.wav", volume => '20%');
        speak 'volume=100 Hello from Mr. Bruce';

        #        speak volume => 5, text => 'Hello from Mr. Bruce';
    }

    # Test Setupsup sendkeys
    #  - documentaion is in mh/site/Win32/setupsup.html
    elsif ( $state eq 'o' ) {
        print_log "Testing Setupsup sendkeys to outlook";
        my $window;
        if ( &WaitForAnyWindow( 'Outlook', \$window, 1000, 100 ) ) {
            &SendKeys( $window, "\\alt\\te\\ret\\", 1, 500 )
              ;    # Send alt Tools sEnd Return (for all accounts)
        }
        else {
            print_log "Outlook is not running";
        }
    }
    elsif ( $state eq 'p' ) {
        print_log "Testing Setupsup test to start winamp";
        my $window;
        if ( &WaitForAnyWindow( 'Winamp', \$window, 100, 100 ) ) {
            print_log "Winamp is running ... shutting it down";
            sleep 2;

            #           &SendKeys($window, "\\alt+\\f\\alt-\\x\\", 1, 500);
            &SendKeys( $window, "\\alt\\fx\\", 1, 500 );
        }
        else {
            print_log "Winamp is not running ... starting it up";
            run 'd:\utils\Winamp\Winamp.exe';
        }
    }
    elsif ( $state eq 'q' ) {

        #       my $test_light_1 = new X10_Item('A1', 'CM17');
        #        my $test_light_1 = new X10_Item('A3');
        #        print "db in test_stuff tl=$test_light_1, ref=", ref $test_light_1, ".\n";
        #        $state = (ON eq state $test_light_1) ? OFF : ON;
        #        print_log "Setting X10 test light 1 to $state";
        #        set $test_light_1 $state;
    }

    #    elsif ($state eq 'r') {
    #        my $test_light_2 = new X10_Item('D5', 'CM11');
    #        print_log "Setting X10 test light 2 to $state";
    #        $state = (ON eq state $test_light_2) ? OFF : ON;
    #        set $test_light_2 $state;
    #    }
    elsif ( $state eq 's' ) {
        run 'mplayer.exe /play /close c:\win98\media\canyon.mid';

        #        print "Last change:" . (state_log $camera_light)[0] . ".\n";
        #        my @log = state_log $camera_light;
        #        print "Last change: @log.\n";

        #        my $h_last = (state_log $indoor_fountain)[0];
        #        print "db o=$indoor_fountain $h_last\n";

        #       print_log "date=$Date_Now year=$Year time=$Time_Now";
        #       print_log "The camera light is " . state $camera_light;
        #       print time_date_stamp(13) . "\n";
    }
    elsif ( $state eq 't' ) {
        print "Log running display jpg gif test";
        display "$config_parms{html_dir}/graphics/funny_face.gif";
        display "$config_parms{html_dir}/graphics/funny_face.jpg";
    }
    elsif ( $state eq 'u' ) {

        #        set_with_timer $watchdog_light '10%', 3;
        print_log( "hi bruce\n" x 100 );

        #        my $rc = net_ftp(file => 'c:/junk1.txt', file_remote => 'incoming/junk1.txt',
        #                         command => 'put', server => 'misterhouse.net',
        #                         user => 'anonymous', password => 'bruce@misterhouse.net');
        #        print_log "net_ftp delete results: $rc";
    }

    # If we recognized the state, reset it
    else {
        undef $state;
    }
    undef $test_input1 if $state;

}

if ( $Save{test_input2} eq 'time' ) {
    print "test1" if time_now('xyz');
    speak "test2" if time_now("8:20 + 1");
    speak "test3" if time_now("8:20 + 00:01");
    speak "test4" if $New_Minute and time_greater_than("8:22 + 00:02");
}

if ( $Save{test_input2} =~ /load (\S+)/ ) {
    $Save{test_input2} = '';
    my $code = $1;
    print "Loading code member $1\n";
    eval "$code";
    print "eval results: $@\n";
}

$toggle_gd = new Voice_Cmd 'Toggle GD on/off';

if ( said $toggle_gd) {
    $Info{module_GD} = ( $Info{module_GD} ) ? 0 : 1;
    print_log "GD toggled to $Info{module_GD}";
}

