# Category=Other
# 
# This code is used to display data to a 4x20 LCD display.  An optional
# keypad can be used to select what data to display.
#
# This code uses a Socket to talk to the LCDproc server program, available at:
#      Unix: http://lcdproc.omnipotent.net
#   Windows: http://www.2morrow.com/
#
# Both version of the LCDproc server support displays from:
#   http://www.matrix-orbital.com/
#   http://www.crystalfontz.com/
#
# The Matrix displays also supports a keypad interface.
# 
# Since Sockets are used, the computer with the serial-attatched
# display can be different than the MisterHouse computer.
#
# Any of the many LCDproc clients can be used at the same time
# as this MisterHouse client, and the LCDproc server will page between
# the displays.
#

#return;                         # Disable till we get another serial port
 
my %lcd_data;
$lcdproc = new  Socket_Item(undef, undef, '200.200.200.5:13666');

$v_lcdproc_control = new  Voice_Cmd("[Start,Stop] the lcdproc client");
$v_lcdproc_control-> set_info('Connects to the lcdproc server, used to display LCD data.');

set $v_lcdproc_control 'Start' if $Startup;

if ($state = said $v_lcdproc_control) {
    print_log "${state}ing the lcdproc client";
    if ($state eq 'Start') {
        unless (active $lcdproc) {
            print_log "Starting a connection to lcdproc";
            start $lcdproc;
        }
        set $lcdproc "\nhello\n";
        my $data;
        $data  = "client_set name {MisterHouse)}\n";
        $data .= "screen_add mh1\n";
#       $data .= "screen_set mh1 name {Mh1}\n";
#       $data .= "widget_add mh1 mytitle title\n";
#       $data .= "widget_set mh1 mytitle {Mh1 hi}\n";
        $data .= "widget_add mh1 1 string\n";
        $data .= "widget_add mh1 2 string\n";
        $data .= "widget_add mh1 3 string\n";
        $data .= "widget_add mh1 4 string\n";
        set $lcdproc $data;
        $lcd_data{refresh} = 1;
    }
    elsif ($state eq 'Stop' and active $lcdproc) {
       print_log "closing $lcdproc";
       stop  $lcdproc;
    }
}

                                # Read LCD proc server->client messages 
if (my $data = said $lcdproc) {
#   print "db first_byte = ", unpack('C', substr($data, 0, 1));
    $data = substr($data, 1);   # The first byte is 0!!??
    print "ldproc server said:$data...\n";
    if ($data =~ /^key.(\S)/) {
        $lcd_data{key}     = $1;
        $lcd_data{refresh} = 1;
    }
}

                                # Echo latest said command
if (my $speak_num = &Voice_Cmd::said_this_pass) {
    my $text = &Voice_Cmd::text_by_num($speak_num);
    print_log "spoken text: $speak_num, $text";
    $lcd_data{'4_override'} = $text;
    $lcd_data{refresh} = 1;
    $time_reset_override = &get_tickcount + 3000;
}

                                # Show that noise was detected.
my $time_reset_override;
if (my $text = &Voice_Cmd::noise_this_pass) {
    if ($text eq 'Noise') {
        $lcd_data{'4_override'} = '      Noise     ';
        $lcd_data{refresh} = 1;
        $time_reset_override = &get_tickcount + 1500;
    }
}
                                # Put old data back on the LCD
if ($time_reset_override and $time_reset_override < &get_tickcount) {
    undef $time_reset_override;
    delete $lcd_data{'2_override'};
    delete $lcd_data{'3_override'};
    delete $lcd_data{'4_override'};
    $lcd_data{refresh} = 1;
}


                                # Decide how often to refresh the screen
if ($New_Second) {
    $lcd_data{refresh} = 1 if $lcd_data{key} eq 'M' or $New_Minute;
}

                                # Set up new data to display
my @lcd_data_prev;
if (active $lcdproc and $lcd_data{refresh}) {
    $lcd_data{refresh} = 0;

                                # On my keypad, top row is NLNM, 2nd row is IHGF,
                                # third row used for lcdproc controls. 
    $lcd_data{key} = 'N' unless $lcd_data{key}; # Default

                                # Display time/temp
    if ($lcd_data{key} eq 'N') {
        $lcd_data{1} = substr(&time_date_stamp(14, $Time), 0, 18);
                                # Make sure phone data is speakable
        my $temp = substr($Save{phone_last}, 7);
        $temp = 'No call' if $temp !~ /^[\n\r !-~]+$/;
        $lcd_data{2} = $temp;
        $lcd_data{3} = $weather{Summary_Short};
        $lcd_data{4} = $Save{email_flag};
    }
                                # Display uptimes
    elsif ($lcd_data{key} eq 'M') {
        $lcd_data{1} = &time_date_stamp(14, $Time);
        substr($lcd_data{1}, 11, 3) = ''; # Drop the year, so the seconds fit
        $lcd_data{2} = "Pgm" . &time_diff($Time_Startup_time, $Time, undef, "numeric");
        $lcd_data{3} = "Box" . &time_diff($Time_Boot_time, (&get_tickcount)/1000, undef, "numeric");
        $lcd_data{4} = "SunT $Time_Sunrise $Time_Sunset";
    }
                                # Display tagline
    elsif ($lcd_data{key} eq 'L') {
        $Text::Wrap::columns = 20;
        if ($lcd_data{key} ne $lcd_data{key_prev}) {
            my $data = read_next $house_tagline;
            $data = wrap('','', $data);
            $data .= "  \n  \n  \n  \n  "; # Make sure we get blank, not empty, lines
            my @data = split("\n", $data);
            $lcd_data{1} = $data[0];
            $lcd_data{2} = $data[1];
            $lcd_data{3} = $data[2];
            $lcd_data{4} = $data[3];
        }
    }

                                # Set the VR mode indicator
    my $vr_mode_flag;
    if ($Save{vr_mode} eq 'awake') {
        $vr_mode_flag = 'A';
    }
    elsif ($Save{vr_mode} eq 'asleep') {
        $vr_mode_flag = 'S';
    }
    elsif ($Save{vr_mode} eq 'off') {
        $vr_mode_flag = 'O';
    }
    elsif ($Save{vr_mode} eq 'list') {
        $vr_mode_flag = 'L';
    }
#   $lcd_data{1} = sprintf("%-19s%1s", substr($lcd_data{1}, 0, 19), $vr_mode_flag) if $vr_mode_flag;
    $lcd_data{1} = $vr_mode_flag . ' ' . $lcd_data{1} if $vr_mode_flag;

                                # Send only changed lines
    my ($data, $line);
    for my $i (1 .. 4) {
        $line = $lcd_data{$i . '_override'};
        $line = $lcd_data{$i} unless $line;
        $data .= "widget_set mh1 $i 1 $i {$line}\n" unless $line eq $lcd_data_prev[$i];
        $lcd_data_prev[$i] = $line;
    }
    set $lcdproc $data if $data;
#   print "lcdproc data=$data\n";
}

                                # Display the last spoken text
$temp = &speak_log_last(1);
#$temp = Voice_Text::last_spoken(1);
if ($last_speak_log ne $temp) {
    $last_speak_log  = $temp;
    $lcd_data{'2_override'} = substr($temp, 9);
    $lcd_data{refresh} = 1;
    $time_reset_override = &get_tickcount + 5000;
}
                                # Display the last print log
my ($last_print_log, $last_speak_log);
$temp = main::print_log_last(1);
if ($last_print_log ne $temp) {
    $last_print_log  = $temp;
    $lcd_data{'3_override'} = substr($temp, 18);
    $lcd_data{refresh} = 1;
    $time_reset_override = &get_tickcount + 5000;
}

                                # Detect change in VR mode
my  $lcdvr_mode_prev;
if ($lcdvr_mode_prev ne $Save{vr_mode}) {
    $lcdvr_mode_prev =  $Save{vr_mode};
    $lcd_data{refresh} = 1;
}




