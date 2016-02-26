# Category=Phone

#@ This code lists phone calls loged by the other phone_*.pl code.
#@ It also creates subroutines used by the web interface to
#@ display phone logs.

# Show phone logs via a popup or web page
$v_phone_log = new Voice_Cmd 'Display recent [incoming,outgoing,] phone calls';
$v_phone_log->set_info('Show recent phone calls.');

my $phone_dir = "$config_parms{data_dir}/phone";
if ( $state = said $v_phone_log) {
    display
      text => &phone_log( 'in', 999, 'text' ),
      font => 'fixed'
      if $state eq 'incoming' or $state eq ' ';
    display
      text => &phone_log( 'out', 999, 'text' ),
      font => 'fixed'
      if $state eq 'outgoing' or $state eq ' ';
}

# reload file if changed
&Caller_ID::read_callerid_list()
  if ( file_changed $config_parms{caller_id_file} );

# This function returns phone logs to menus
sub phone_log {
    my ( $log, $count, $format ) = @_;
    $count = 9 unless $count;
    $log = 'callerid' if $log eq 'in';
    $log = 'phone'    if $log eq 'out';
    my @members = &read_phone_logs1($log);
    my @calls = &read_phone_logs2( $count, @members );
    $format = $Menus{response_format} unless $format;
    return &menu_format_list( $format, "$log log", @calls );
}

# This function will read the members in the phone log dir
sub read_phone_logs1 {

    my ($file_qual) = @_;

    # Read directory for list of detailed phone logs ... default to the lastest one.
    opendir( DIR, "$phone_dir/logs" )
      or die "Could not open directory $phone_dir/logs: $!\n";
    my @members = readdir(DIR);

    # Default to just the latest 2 members
    @members = reverse sort grep( /$file_qual.*\.log$/, @members );
    if ( @members < 2 ) {
        return ( shift @members );
    }
    else {
        return ( shift @members, shift @members );
    }
}

# This function will read in or out phone logs and return
# a list array of all the calls.
my %callerid_by_number;

sub read_phone_logs2 {

    my ( $count1, @files ) = @_;

    # Sort by date, so most recent file is first
    my (@calls);
    my $count2 = 1;

    print "Reading @files\n" if $Debug{phone};
    for my $log_file (@files) {
        print "db lf=$log_file\n" if $Debug{phone};
        $log_file = "$phone_dir/logs/$log_file";
        open( PLOG, $log_file )
          or die "Error, could not open file $log_file: $!\n";
        binmode PLOG;    # In case bad (binary) data is logged
        my @a = reverse <PLOG>;
        while ( $_ = shift @a ) {

            tr/\x20-\x7e//cd; # Translate bad characters or else TK will mess up
            s/\x2a//;

            #save A reference copy
            my $refdata = $_;
            print_log "DB REF data $refdata" if $Debug{phone};

            my ( $time_date, $number, $name, $line, $type );

            # Incoming
            #Tue 04/03/01 11:11:37 507-252-5976 COLVIN ELIZABET
            #Mon 11/12/01 19:11:28  name=-UNKNOWN CALLER- data=###DATE11121911...NMBR...NAME-UNKNOWN CALLER-+++ line=W

            if ( $log_file =~ /callerid/ ) {
                ( $time_date, $number, $name, $line, $type ) = $_ =~
                  /(.+?) (1?\-?\d\d\d\-?\d\d\d\-?\d\d\d\d)\s+name=(.+)\s+line=(.+)\s+type=(.+)/;
                ( $time_date, $number, $name, $line, $type ) =
                  $_ =~ /(.+?) (\d{3,})\s+name=(.+)\s+line=(.+)\s+type=(.+)/
                  unless $name;
                ( $time_date, $number, $name ) =
                  $_ =~ /(.+?) (\d\d\d\-?\d\d\d\-?\d\d\d\d) name=(.+)/
                  unless $name;
                ( $time_date, $number, $name ) =
                  $_ =~ /(.+?) (\d\d\d\d\d\d\d\d\d\d)(\s\w+\s\w+\s\w+\s)/
                  unless $name;
                ( $time_date, $number, $name ) =
                  $_ =~ /(.+?) (\d\d\d\-?\d\d\d\d)/
                  unless $name;    # AC is optional

                print_log "DB CID $time_date, $number, $name, $line, $type"
                  if $Debug{phone};

                # Deal with "private, 'out of area', and bad data" calls
                unless ($name) {
                    ($name) = $_ =~ /name=(.+)/;
                    $time_date = substr( $_, 0, 21 );
                    if ( $_ =~ /out of area/i ) {
                        $number = "Out_of_Area";
                    }
                    elsif ( $_ =~ /private/i ) {
                        $number = "Private";
                    }
                    else {
                        $number = 'Unknown';
                    }
                }
                $name =~ s/line=.+//;
                $name =~ s/data=.+//;
            }

            # Outgoing
            #Sun 04/01/01 12:03:09 O2525976
            #Fri 07/02/04 16:29:47 O5084572543 name=00:00:55 ext=102 line=801 type=POTS

            else {

                my $number_length = length($number);

                ( $time_date, $number ) = $_ =~ /(.+?) O(\S+)/;

                # See if we can find a name for this number

                # Strip off any leading 1
                # if we use mixed 10 digit dialing we need to check
                if ( substr( $number, 0, 1 ) eq '1' ) {
                    $number = substr( $number, 1 );
                    print_log "DB Num > 10 Now it's $number" if $Debug{phone};
                }

                $number_length = length($number);

                print_log "Our incoming string is $number_length"
                  if $Debug{phone};

                # if we got extra digits ignore them and make it 10
                if ( $number_length > 10 ) {
                    $number = substr( $number, 0, 9 );
                    $number_length = length($number);
                    print_log " Num Still >10 mow = $number" if $Debug{phone};
                }

                # and format the whole thing
                #    $number =~ s/(\d\d\d)(\d\d\d)(\d\d\d\d)/$1-$2-$3/;

                if ( $number_length == 10 ) {

                    #$number = substr($number, 1);
                    $number =~ s/(\d\d\d)(\d\d\d)/$1-$2-/;
                }

                if ( $number_length == 7 ) {
                    $number =~ s/(\d\d\d)/$config_parms{local_area_code}-$1-/;
                }

                %callerid_by_number =
                  dbm_read("$config_parms{data_dir}/phone/callerid.dbm")
                  unless %callerid_by_number;

                #               my $data = dbm_read("$config_parms{data_dir}/phone/callerid.dbm", $number);
                my $data = $callerid_by_number{$number};
                print_log "DB data= $data" if $Debug{phone};
                my ( $calls, $time, $date, $name2 ) =
                  $data =~ /^(\d+) +(.+), (.+) name=(.+)/
                  if $data;
                $name = $name2;
            }

            next unless $number;

            my ( $day, $date, $time ) = split ' ', $time_date;
            $time = time_to_ampm $time;

            # Make it pretty
            my $name2 = $Caller_ID::name_by_number{$number};
            $name2 = $name unless $name2;
            $name2 = 'NA'  unless $name2;    # nothing to report from CID data
               # Seems the data has lots-o-whitespace at the end and Sometimes embedded
               #  so... strip the trailing and replace the embedded with _
               #  this makes passing and parsing way easier (and keeps things aligned)
            $name2 =~ s/\s+$//;
            $name2 =~ s/ /_/g;

            #Break it up for the Extended records
            my ( $ph_time, $ph_num, $ph_name, $ph_ext, $ph_line, $ph_type );
            ( $ph_time, $ph_num, $ph_name, $ph_ext, $ph_line, $ph_type ) =
              $refdata =~
              /(.+?) O(\S+) name=(\S+) ext=(\S+) line=(\S+) type=(\S+)/;
            print_log "REAL data $time_date, $number, $name2, $line, $type"
              if $Debug{phone};
            print_log "REF2 data $refdata" if $Debug{phone};

            # Now do substitutions for teh extended format
            $type = $ph_type if $ph_type;    # detailed data is replaced here
            $type = 'out'
              unless $type;    # Unless there isn't any then make a default

            $line = $ph_line if $ph_line;
            $line = "1" unless $line;

            $ph_ext = "000" unless $ph_ext;    #need a default if non existant

            $ph_name = "Not_Available" if ( $ph_ext eq "000" );
            $ph_name = $name2
              unless $ph_name;    #and the name is really the elapsed time

            #	my $num_len = length($number);
            #	if ( $num_len > 10 ) {
            #	    if ( substr($number,0,1) eq '1' ) {
            #		$number = substr($number,1);
            #	    }
            #	    $num_len = length($number);
            #	    if ( $num_len > 10 ){
            #		$number = substr($number,0,9);
            #	    }
            #	}
            print_log
              "split test  $time_date, $number, $name2, $ph_ext, $line, $type "
              if $Debug{phone};
            print_log "split test  $time_date, $number, $name2"
              if $Debug{phone};

            push @calls,
              sprintf(
                "date=%20s number=%-12s name=%s line=%s type=%s dur=%8s ext=%s ",
                $time_date, $number, $name2, $line, $type, $ph_name, $ph_ext );
            last if ++$count2 > $count1;

        }
        close PLOG;
    }
    print "Read ", scalar @calls, " calls\n" if $Debug{phone};
    return @calls;
}
