# Category=MisterHouse

#@ This code will retrieve and parse the MH download page to
#@ determine if a newer version is available.

=begin comment

 mh_release.pl
 Created by Axel Brown

 This code will retrieve and parse the MH download page to
 determine if a newer version is available.

 Revision History

 Version 0.1		January 04, 2005
 Version 0.2 - March, 2014, Use Github Tags URL, Ignore develop-ref version
 And so it begins...

=cut

use JSON::PP ()
  ; # Do not import any functions as it could conflict with the JSON imported functions from other locations in the code

# noloop=start
my $mhdl_url  = "https://api.github.com/repos/hollie/misterhouse/tags";
my $mhdl_file = "$config_parms{data_dir}/web/mh_download.html";
$p_mhdl_page = new Process_Item("get_url -quiet \"$mhdl_url\" \"$mhdl_file\"");

my $mhdl_date_url  = "";
my $mhdl_date_file = "$config_parms{data_dir}/web/mh_download_date.html";
$p_mhdl_date_page = new Process_Item;

# noloop=stop

$v_mhdl_page = new Voice_Cmd("Check Misterhouse version");
$v_mhdl_page->set_info("Check if Misterhouse version is current");

$v_version = new Voice_Cmd( "What version are you", 0 );
$v_version->set_info("Responds with current version information");

sub parse_version {
    my ( $maj, $min ) = $Version =~ /(\d)\.(\d*)/;
    my ($rev) = $Version =~ /R(\d*)/;
    $maj = $Version unless ($maj);
    my $version_str = $maj;
    $version_str .= ".$min" unless ( $min eq '' );
    $version_str .= " (revision $rev)" if ($rev);
    return ( $maj, $min, $version_str );
}

sub calc_age {

    #Get the time sent in. This is UTC
    my $time = shift;

    #*** This is a hack (same as earthquakes)
    #*** Surely PERL can turn a date string into a time hash!
    my ( $qyear, $qmnth, $qdate ) = $time =~ m!(\d+)-(\d+)-(\d+)T!;

    my $diff = ( time - timelocal( 0, 0, 0, $qdate, $qmnth - 1, $qyear ) );

    my $days_ago = int( $diff / ( 60 * 60 * 24 ) );
    return 'today'                    if !$days_ago;
    return 'yesterday'                if $days_ago == 1;
    return 'the day before yesterday' if $days_ago == 2;
    return "$days_ago days ago"       if $days_ago < 7;
    my $weeks = int( $days_ago / 7 );
    my $days  = $days_ago % 7;
    return
        "$weeks week"
      . ( ( $weeks == 1 ) ? '' : 's' )
      . (
        ( !$days ) ? '' : ( " and $days day" . ( ( $days == 1 ) ? '' : 's' ) ) )
      . " ago";
}

if ( said $v_version) {

    my ( $maj, $min, $version_str ) = &parse_version();

    if (
        (
               ( $Save{mhdl_maj} > $maj )
            or ( ( $Save{mhdl_maj} == $maj ) and ( $Save{mhdl_min} > $min ) )
        )
        and ( $maj !~ m/^develop-ref/ )
      )
    {
        respond(
            "app=control I am version $version_str and $Save{mhdl_maj}.$Save{mhdl_min} was released "
              . &calc_age( $Save{mhdl_date} )
              . '.' );
    }
    elsif ( $maj =~ m/^develop-ref/ ) {
        respond(
            "app=control You are running the development branch, it has no version releases."
        );
    }
    else {
        respond("app=control I am version $version_str.");
    }
}

if ( said $v_mhdl_page) {

    my $msg;

    if (&net_connect_check) {
        $msg = 'Checking version...';
        print_log("Retrieving download page");
        start $p_mhdl_page;
    }
    else {
        $msg =
          "app=control Unable to check version while disconnected from the Internet";
    }

    $v_mhdl_page->respond("app=control $msg");
}

if ( done_now $p_mhdl_page) {
    my @html = file_read($mhdl_file);
    print_log("Download page retrieved");
    my $json = JSON::PP::decode_json(@html)
      ; # Use the PP version of the call as otherwise this function fails at least on OS X 10.9.4 with Perl 5.18.2
    my ( $mhdl_date_url, $maj, $min );
    foreach ( @{$json} ) {
        next unless $_->{name} =~ m/^v(\d+)\.(\d+)/;
        next unless ( ( $1 > $maj ) or ( $1 == $maj and $2 > $min ) );
        $maj           = $1;
        $min           = $2;
        $mhdl_date_url = $_->{commit}{url};
    }
    $Save{mhdl_maj} = $maj;
    $Save{mhdl_min} = $min;
    my $msg;
    if (&net_connect_check) {
        $msg = 'Checking version date...';
        print_log("Retrieving download date page");
        set $p_mhdl_date_page
          "get_url -quiet \"$mhdl_date_url\" \"$mhdl_date_file\"";
        start $p_mhdl_date_page;
    }
    else {
        $msg =
          "app=control Unable to check version date while disconnected from the Internet";
    }
    respond("app=control $msg");
}

if ( done_now $p_mhdl_date_page) {
    my @html = file_read($mhdl_date_file);
    print_log("Download date page retrieved");
    my $json = JSON::PP::decode_json(@html);
    $Save{mhdl_date} = $json->{commit}{author}{date};
    if ( defined $Save{mhdl_maj} and defined $Save{mhdl_min} ) {
        my ( $maj, $min, $version_str ) = &parse_version();
        if (
            (
                   ( $Save{mhdl_maj} > $maj )
                or
                ( ( $Save{mhdl_maj} == $maj ) and ( $Save{mhdl_min} > $min ) )
            )
            and ( $maj !~ m/^develop-ref/ )
          )
        {
            respond(
                "important=1 connected=0 app=control I am version $version_str and version $Save{mhdl_maj}.$Save{mhdl_min} was released "
                  . &calc_age( $Save{mhdl_date} . '.' ) );
        }
        elsif ( $maj =~ m/^develop-ref/ ) {
            respond(
                "connected=0 app=control You are running the development branch, it has no version releases."
            );
        }
        else {
            # Voice command is only code to start this process, so check its set_by
            respond("connected=0 app=control Version $version_str is current.");
        }
    }
}

# create trigger to download version info at 6PM (or on dial-up connect)

if ($Reload) {
    if ( $Run_Members{'internet_dialup'} ) {
        &trigger_set(
            "state_now \$net_connect eq 'connected'",
            "run_voice_cmd 'Check Misterhouse version'",
            'NoExpire',
            'get MH version'
        ) unless &trigger_get('get MH version');
    }
    else {
        &trigger_set(
            "time_cron '0 18 * * *' and net_connect_check",
            "run_voice_cmd 'Check Misterhouse version'",
            'NoExpire',
            'get MH version'
        ) unless &trigger_get('get MH version');
    }
}
