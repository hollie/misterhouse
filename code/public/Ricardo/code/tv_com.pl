# Category=TV

my $f_tv_data = "$config_parms{data_dir}/tv_data";
$f_tv_file = new File_Item($f_tv_data);
my $calendar_data = "$config_parms{data_dir}/organizer/calendar.tab";

# The obligatory voice command.
$v_tv_page = new Voice_Cmd('[Reget,Get,Show] internet tv');
$v_tv_page->set_info("TV schedule");
$v_tv_page->set_authority('anyone');

respond &format_tv_com if said $v_tv_page eq 'Show';

# Here is the guts of the asynchronous processing. get_tv_com starts the
# fetch subprocess. When it is done, fetch_tv_com reads the resulting data
# back into the main misterhouse process.

# Fetch the latest TV programs at 3:00 AM every day
&get_tv_com(0) if ( said $v_tv_page eq 'Get' );
&get_tv_com(1) if ( ( said $v_tv_page eq 'Reget' )
    or time_cron("0 3 * * *") );

&fetch_tv_com if ( changed $f_tv_file);
&fetch_tv_com if ($Startup);

# Other code modules (eg. internet_jabber.pl) can call these without having to
# worry about implementation changes.
sub read_tv_com {
    respond &format_tv_com;
}

sub display_tv_com {
    display &format_tv_com;
}

# This subroutine formats the summary of the current TV programs and content.
sub format_tv_com {
    my $data;

    #    # simple summary for now.
    #    $temp = $TV_schedule{TempOutdoor};
    #    $temp =~ s/C/degrees celsius/;
    #    $temp =~ s/F/degrees farenheit/;
    #
    #    $data = "The weather is " . $Weather{Conditions} . ". ";
    #    $data .= "It is " . $temp . " degrees outside";
    #    $data .= ", with a windchill of " . $Weather{WindChill} . " degrees" if ($Weather{WindChill});
    #    $data .= ". ";
    #
    #    if ($Weather{TempOutdoor} > 15) {
    #	$data .= "The humidity is " . $Weather{HumidOutdoor} .
    #		"%, with a humidex of " . $Weather{Humidex} .
    #		" and a dewpoint of " . $Weather{DewpointOutdoor} . ". ";
    #    }
    #
    #    if ($Weather{WindAvg}) {
    #	$data .= "The wind is from the " . convert_direction($Weather{WindAvgDir}) . " at " . $Weather{WindAvg} . " kilometers per hour";
    #	$data .= ", gusting to " . $Weather{WindGust} . " kilometers per hour" if ($Weather{WindGust});
    #	$data .= ". ";
    #    }
    #    else {
    #	$data .= "There is no wind. ";
    #    }
    #
    #    $data =~ s%km/h%kilometers per hour%;

    return $data;
}

# Fetch the raw HTML TV page from the tv.com webserver, and update the parsed data file.
sub get_tv_com {
    my $programs_file =
      $config_parms{code_dir} . "/" . $config_parms{TV_com_progs_file};
    open( TV_PROGRAMS, $programs_file )
      or print_log "Warning, could not open $programs_file!\n";
    my @AllPrograms = <TV_PROGRAMS>;
    close TV_PROGRAMS;
    my $force = shift;
    my $line;
    my $lineNo = 0;
    my $pgm;

    # erase output file content
    main::file_write( $f_tv_data, '' );

    print_log "running $pgm multiple times";
    foreach $line (@AllPrograms) {
        chomp $line;
        $lineNo++;
        $pgm = "get_tv_com";
        $pgm .= " -reget" if $force;
        $pgm .= " -showId " . ( $lineNo - 1 );
        print_log "Getting TV $line $pgm";
        run 'inline', $pgm;
    }

    set_watch $f_tv_file;
    fetch_tv_com();
}

# this routine fetches the TV data already formatted for the organizer.
sub fetch_tv_com {
    my $tempCalBuffer = "";

    # need to strip all entries beginning with "TV"
    open CALENDAR, $calendar_data;
    while (<CALENDAR>) {
        if ( $_ =~ m/^TV/ ) {

            #            print "Stripped  $_";
        }
        else {
            $tempCalBuffer .= $_;
        }
    }
    close CALENDAR;

    open TV_DATA, $f_tv_data;
    while (<TV_DATA>) {
        $tempCalBuffer .= $_;
    }
    close TV_DATA;

    file_write( $calendar_data, $tempCalBuffer );
}

