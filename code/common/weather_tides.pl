# Category = Weather

#@ This script collects information about ocean tides, moonrise and moonset from the
#@ <a href="http://tbone.biol.sc.edu/tide">University of Southern Carolina Tide Predictor</a>.
#@ Set the weather_tide_site ini parameter to the tide site closest to you.

# Version 1.1 07/29/14 Fixed description and ini parameter reference - Jared J. Fernandez
# Version 1.0 12/04/05 created by David Norwood based on idea by Joey French

#noloop=start
my $tide_site = 'Charleston, South Carolina';
my $f_tides   = "$config_parms{data_dir}/web/tides.html";
$v_get_tides = new Voice_Cmd 'Get tide info';
$v_get_tides->set_info('Get tide information from the Internet');
$v_read_tides =
  new Voice_Cmd 'When is the next [High Tide,Low Tide,Moonrise,Moonset]?';
$v_read_tides->set_info(
    'Show tide, moonrise and moonset information from the Internet');
$p_get_tides = new Process_Item;
$tide_site   = $config_parms{weather_tide_site}
  if $config_parms{weather_tide_site};
$tide_site = &escape($tide_site);
set $p_get_tides
  "get_url http://tbone.biol.sc.edu/tide/tideshow.cgi?site=$tide_site $f_tides";
trigger_delete "get tide info";

#noloop=stop

if (
    (
        new_minute 10 and ( $Weather{'Next High Tide'} eq ''
            or $Weather{'Next Low Tide'} eq ''
            or $Weather{'Next Moonrise'} eq ''
            or $Weather{'Next Moonset'} eq '' )
    )
    or said $v_get_tides)
{
    $v_get_tides->respond(
        "app=tides Retrieving tide information for $tide_site...")
      if said $v_get_tides;
    unlink $f_tides;
    $p_get_tides->start;
}

if ( time_now $Weather{'Next High Tide'} ) {
    $Weather{'Previous High Tide'} = $Weather{'Next High Tide'};
    $Weather{'Next High Tide'}     = '';
    unlink $f_tides;
    $p_get_tides->start;
}

if ( time_now $Weather{'Next Low Tide'} ) {
    $Weather{'Previous Low Tide'} = $Weather{'Next Low Tide'};
    $Weather{'Next Low Tide'}     = '';
    unlink $f_tides;
    $p_get_tides->start;
}

if ( time_now $Weather{'Next Moonrise'} ) {
    $Weather{'Previous Moonrise'} = $Weather{'Next Moonrise'};
    $Weather{'Next Moonrise'}     = '';
    unlink $f_tides;
    $p_get_tides->start;
}

if ( time_now $Weather{'Next Moonset'} ) {
    $Weather{'Previous Moonset'} = $Weather{'Next Moonset'};
    $Weather{'Next Moonset'}     = '';
    unlink $f_tides;
    $p_get_tides->start;
}

if ( my $state = said $v_read_tides) {
    my ( undef, $time_str ) = split ' ', $Weather{"Next $state"};
    my $text;
    $time_str = time_to_ampm $time_str;
    $text .= "The next $state is at $time_str.";
    $text = "The next $state time has not been retrieved."
      unless $Weather{"Next $state"};
    respond $text;
}

=begin comment 

2006-01-03  04:01 EST  -0.60 feet  Low Tide
2006-01-03  07:22 EST   Sunrise
2006-01-03  10:23 EST   Moonrise
2006-01-03  10:30 EST   6.20 feet  High Tide
2006-01-03  16:44 EST  -0.47 feet  Low Tide
2006-01-03  17:26 EST   Sunset
2006-01-03  21:40 EST   Moonset
2006-01-03  22:51 EST   5.29 feet  High Tide
2006-01-04  04:55 EST  -0.37 feet  Low Tide
2006-01-04  07:22 EST   Sunrise
2006-01-04  10:55 EST   Moonrise
2006-01-04  11:22 EST   5.90 feet  High Tide
2006-01-04  17:26 EST   Sunset
2006-01-04  17:35 EST  -0.41 feet  Low Tide
2006-01-04  22:49 EST   Moonset
2006-01-04  23:48 EST   5.33 feet  High Tide

=cut

if ( done_now $p_get_tides) {
    my ( $nexth, $nextl, $nextr, $nexts );
    for my $html ( file_read $f_tides, '' ) {
        if ( my ( $year, $mnth, $date, $hour, $minu, $size, $units, $event ) =
            $html =~
            /^(\d\d\d\d)-(\d\d)-(\d\d)  (\d\d):(\d\d) \w\w\w\s+(-?\d+\.\d+ (feet|meters))?\s+?(Low Tide|High Tide|Sunrise|Sunset|Moonrise|Moonset)$/
          )
        {
            my $timediff =
              timelocal( 0, $minu, $hour, $date, $mnth - 1, $year - 1900 ) -
              $Time;
            my $time_str = "$mnth/$date $hour:$minu";
            print_log "$time_str $size $event \n";
            $Weather{'Previous High Tide'} = $time_str
              if $event eq 'High Tide' and $timediff < 0;
            $nexth = 1, $Weather{'Next High Tide'} = $time_str
              if $event eq 'High Tide'
              and $timediff > 0
              and not $nexth;
            $Weather{'Previous Low Tide'} = $time_str
              if $event eq 'Low Tide' and $timediff < 0;
            $nextl = 1, $Weather{'Next Low Tide'} = $time_str
              if $event eq 'Low Tide'
              and $timediff > 0
              and not $nextl;
            $Weather{'Previous Moonrise'} = $time_str
              if $event eq 'Moonrise' and $timediff < 0;
            $nextr = 1, $Weather{'Next Moonrise'} = $time_str
              if $event eq 'Moonrise'
              and $timediff > 0
              and not $nextr;
            $Weather{'Previous Moonset'} = $time_str
              if $event eq 'Moonset' and $timediff < 0;
            $nexts = 1, $Weather{'Next Moonset'} = $time_str
              if $event eq 'Moonset'
              and $timediff > 0
              and not $nexts;
        }
    }
    print_log
      "Previous High Tide: $Weather{'Previous High Tide'} Next High Tide: $Weather{'Next High Tide'} Previous Low Tide: $Weather{'Previous Low Tide'} Next Low Tide: $Weather{'Next Low Tide'}";
    print_log
      "Previous Moonrise: $Weather{'Previous Moonrise'} Next Moonrise: $Weather{'Next Moonrise'} Previous Moonset: $Weather{'Previous Moonset'} Next Moonset: $Weather{'Next Moonset'}";
}

