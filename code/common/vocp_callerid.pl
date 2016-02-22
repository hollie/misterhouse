# Category=Phone

#@ vocp_callerid.pl v1.03
#@ Uses the vocp system to announce and log incoming phone calls.
#@ Add these entries to your mh.ini file:
#@ vocp_logfile = /var/log/vocp-calls.log
#@ vocp_audrey = 1 (if you want Audrey notification)
#@ vocp_ignore_length = (minimum length to report as voicemail)

## 1.03 Added 'don't turn on the phone indicator if in home mode'

=cut comment

I wrote this as a companion program to David Satterfields vocp_voicemail, as I did not have
extra serial ports to split the modems tx line. This parses the vocp-calls.log and looks for incoming calls
I also added the ability to populate the callerid.dbm file from the misterhouse
contacts as CallerID names do not seem to cross Canadian provincial boundaries

I have also added a vocp_ignore_length function as hang-ups were being announced as new
messages. 

I needed to add a 6th format to lib/Caller_ID.pm in order to get the the make_speakable part
to work. It looks like this:

CallerID.pm line #128
# Format 6 for custom scripts using module
    elsif ($format == 6) {
        ($time, $number, $name) = (split /,/, $data);
	print "CallerID Format 6: phone number=$number name=$name\n";
      }


=cut

## ------------------------------------------------------
## VOCP Event monitoring
## ------------------------------------------------------

if ($Startup) {
    use vars qw($vocp_alert_flag);    # Flag to see if there is voicemail
    $vocp_alert_flag = 0;
}

# Requires modified Caller_ID.pm to take vocp-formatted callerid
if ( file_changed $config_parms{vocp_logfile} ) {
    my $data = file_tail( $config_parms{vocp_logfile}, 1 );
    my ( $uid, $ctype, $ctime, $cnumber, $cname ) = ( split /\|/, $data );
    $cnumber =~ s/\D//g;

    # Format raw 10 digit number to (XXX) XXX-XXXX for Callerid compatibility
    my $fcnumber =
        substr( $cnumber, 0, 3 ) . "-"
      . substr( $cnumber, 3, 3 ) . "-"
      . substr( $cnumber, 6, 4 );

    if ( $ctype eq 'incoming call' ) {

        # Search the callerid.dbm file
        if ( ( $cname eq '0' ) or ( $cname eq 'O' ) ) {
            my %callerid_by_number =
              dbm_read("$config_parms{data_dir}/phone/callerid.dbm")
              unless %callerid_by_number;
            my $cid_data = $callerid_by_number{$fcnumber};
            my ( $cid_calls, $cid_time, $cid_date, $cid_name ) =
              $cid_data =~ /^(\d+) +(.+), (.+) name=(.+)/
              if $cid_data;
            $cname = $cid_name;
            $cname = "Unknown" if $cname eq '';
        }

        my $callerid_data = $ctime . "," . $cnumber . "," . $cname;
        &Caller_ID::read_areacode_list(
            'local_area_code' => $config_parms{local_area_code} );
        my ( $caller, $cid_number, $cid_name, $cid_time ) =
          &Caller_ID::make_speakable( $callerid_data, 6 );
        logit(
            "$config_parms{data_dir}/phone/logs/callerid.$Year_Month_Now.log",
            "$fcnumber name=$cname   line=Line 1" );

        # Parse the caller-id.list format to check for group membership
        my ( $cid2_name, $cid2_wav, $cid2_group, $cid2_from ) =
          ( split /\t/, $caller );

        # Reject the REJECT* Group. Should add code to hang up on the caller
        if ( $cid2_group =~ m/reject/i ) {
            print_log
              "Call Rejected at $cid_time from number: $cid_number name: $cid_name";
            speak( rooms => "all", text => "Phone call from Rejected Number." );
        }
        else {
            $caller = $cid2_name . $cid2_from;
            $Save{last_caller} = $caller;
            speak( rooms => "all", text => "Phone call from $caller." );
            print_log
              "Call Recieved at $cid_time from number: $cid_number name: $cid_name";
            logit_dbm( "$config_parms{data_dir}/phone/callerid.dbm",
                $fcnumber, "$Time_Now $Date_Now $Year name=$cname" );
            run_voice_cmd 'Set All Audrey top light on'
              if ( !$vocp_alert_flag
                and $config_parms{vocp_audrey}
                and ( $mode_occupied ne 'home' ) );
        }
    }

    elsif ( $ctype eq 'new message' ) {

        my $duration = vocp_duration( $cnumber, $uid );
        print_log "VOCP: Voicemail message for box $cnumber (length=$duration)";
        if (
            !(
                    ( $config_parms{vocp_ignore_length} )
                and ( $duration < $config_parms{vocp_ignore_length} )
            )
          )
        {
            speak( rooms => "all", text => "Voicemail message left" );
            if ( $config_parms{vocp_audrey} ) {
                print_log "VOCP: Alerting Audreys";
                run_voice_cmd 'Set All Audrey top light blink';
                $vocp_alert_flag = 1;
            }
        }
    }
}

#----------------------------------------------------------------------
# Listen for Audrey Top light resets, and update flag based on that event
if (
    (
           ( $state = said $v_audrey_top_led_off )
        or ( $state = said $v_audrey_both_leds_off )
    )
    and $config_parms{vocp_audrey}
  )
{
    print_log "VOCP Message flag reset";
    $vocp_alert_flag = 0;
}

#----------------------------------------------------------------------
$v_ciddb_upd = new Voice_Cmd('Update CallerID database with contacts');
if ( $state = said $v_ciddb_upd) {
    print_log "Updating CallerID Database with contacts...";
    my $records = 0;

    for ( file_read "$config_parms{data_dir}/organizer/contacts.tab" ) {
        my (
            $ID,           $FirstName,      $LastName,     $Title,
            $Company,      $WorkAddress1,   $WorkAddress2, $WorkCity,
            $WorkState,    $WorkZip,        $HomeAddress1, $HomeAddress2,
            $HomeCity,     $HomeState,      $HomeZip,      $WorkPhone,
            $HomePhone,    $MobilePhone,    $Fax,          $Pager,
            $PrimaryEmail, $SecondaryEmail, $WebSiteURL,   $Notes
        ) = split( /\t/, $_ );
        $WorkPhone =~ s/\D//g;
        $HomePhone =~ s/\D//g;
        $MobilePhone =~ s/\D//g;
        if ( $WorkPhone and ( length($WorkPhone) == 10 ) ) {
            $records++;
            my $tmp =
                substr( $WorkPhone, 0, 3 ) . "-"
              . substr( $WorkPhone, 3, 3 ) . "-"
              . substr( $WorkPhone, 6, 4 );
            logit_dbm( "$config_parms{data_dir}/phone/callerid.dbm",
                $tmp,
                "$Time_Now $Date_Now $Year name=$LastName $FirstName (Work)" );
            print_log "Contacts.tab: $tmp = $FirstName $LastName (Work)";
        }
        if ( $HomePhone and ( length($HomePhone) == 10 ) ) {
            $records++;
            my $tmp =
                substr( $HomePhone, 0, 3 ) . "-"
              . substr( $HomePhone, 3, 3 ) . "-"
              . substr( $HomePhone, 6, 4 );
            logit_dbm( "$config_parms{data_dir}/phone/callerid.dbm",
                $tmp, "$Time_Now $Date_Now $Year name=$LastName $FirstName" );
            print_log "Contacts.tab: $tmp = $FirstName $LastName";
        }
        if ( $MobilePhone and ( length($MobilePhone) == 10 ) ) {
            $records++;
            my $tmp =
                substr( $MobilePhone, 0, 3 ) . "-"
              . substr( $MobilePhone, 3, 3 ) . "-"
              . substr( $MobilePhone, 6, 4 );
            logit_dbm( "$config_parms{data_dir}/phone/callerid.dbm",
                $tmp,
                "$Time_Now $Date_Now $Year name=$LastName $FirstName (Cell)" );
            print_log "Contacts.tab: $tmp = $FirstName $LastName (Cell)";
        }
    }
    print_log "Update CallerID Database Complete. $records added to database";
}

#----------------------------------------------------------------------
$v_ciddb_disp = new Voice_Cmd('Display CallerID database');
if ( $state = said $v_ciddb_disp) {
    print_log "Displaying CallerID.dbm";
    my %data = read_dbm("$config_parms{data_dir}/phone/callerid.dbm");
    my $html = "Number    Line Date                  Name<br>\n";
    my @temp;
    while ( @temp = each(%data) ) {
        print_log "CallerID.dbm: @temp";
    }
}

sub vocp_duration {
    use XML::Simple;
    my ( $boxnum, $time ) = @_;

    my $xml      = new XML::Simple;
    my $flagfile = $config_parms{vocp_voicemail_dir} . "/" . ".flag." . $boxnum;

    #    print "checking for file $flagfile\n";
    die "can't find file $flagfile" if ( not( -f $flagfile ) );

    my $data = $xml->XMLin( $flagfile, keyattr => "", forcearray => '1' );
    my $duration = 0;
    my $tmptime;

    for my $key ( @{ $data->{boxData}->[0]->{message} } ) {
        $tmptime = $key->{time}->[0];
        $tmptime =~ s/\D//g;

        #print_log "key=[$tmptime] time=[$time]";
        if ( $tmptime = $time ) {

            #print_log "key found";
            $duration = int $key->{size}->[0] / 2000;
        }
    }
    return $duration;
}

# End of vocp_callerid.pl code
