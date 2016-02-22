#Category=Weather
# weather_warnings.pl
# Author: Dan Hoffard
# Gets and reads weather warning/watch info from NOAA.
# Go to http://www.srh.noaa.gov/ to find your warncounty and replace in the URL below

# Replace the following values:
########################################
# Replace this with your county name
my $County = 'Tarrant';

# Replace the "warncounty" portion of this URL with your warncounty (go to http://www.srh.noaa.gov)
my $NOAA_Warnings_URL =
  'http://www.srh.noaa.gov/showsigwx.php?warncounty=TXC439';

#439
########################################
my $f_weather_warnings_summary =
  "$config_parms{data_dir}/web/weather_warnings_summary.txt";
my $f_weather_warnings_html =
  "$config_parms{data_dir}/web/weather_warnings.html";
my $prev_summary    = '';
my $Severe_Wx_Flag  = '0';
my $Severe_Wx_Type  = '';
my $Severe_Wx_Type2 = '';
my $Severe_Wx_Type3 = '';
my $Severe_Wx_Type4 = '';
my ( $summary, $i );
$summary = '';
$i       = 0;

$p_weather_warnings =
  new Process_Item("perl get_url $NOAA_Warnings_URL $f_weather_warnings_html");
$v_weather_warnings = new Voice_Cmd('[Get,Read,Show] weather warnings');

speak($f_weather_warnings_summary)   if said $v_weather_warnings eq 'Read';
display($f_weather_warnings_summary) if said $v_weather_warnings eq 'Show';

if ( said $v_weather_warnings eq 'Get' or time_cron '10,20,30,40,50,0 * * * *' )
{

    if (&net_connect_check) {
        print_log "Retrieving Weather Warnings from the net ...";

        # Use start instead of run so we can detect when it is done
        start $p_weather_warnings;
    }
}

if ( done_now $p_weather_warnings) {

    $Save{Severe_Wx_Type}  = '';
    $Save{Severe_Wx_Type2} = '';
    $Save{Severe_Wx_Type3} = '';
    $Save{Severe_Wx_Type4} = '';
    $Save{Severe_Wx_Flag}  = 0;

    for ( file_read "$f_weather_warnings_html" ) {
        if (    (/Tornado(.+)Watch/)
            and $Save{Severe_Wx_Type} ne 'Tornado Watch'
            and $Save{Severe_Wx_Type2} ne 'Tornado Watch'
            and $Save{Severe_Wx_Type3} ne 'Tornado Watch'
            and $Save{Severe_Wx_Type4} ne 'Tornado Watch' )
        {
            $Save{Severe_Wx_Flag} = 1;
            $i++;
            $summary .=
              "A Tornado Watch has been issued and is currently in effect for $County county. ";
            if ( $Save{Severe_Wx_Type} eq '' ) {
                $Save{Severe_Wx_Type} = 'Tornado Watch';
            }
            elsif ( $Save{Severe_Wx_Type2} eq '' ) {
                $Save{Severe_Wx_Type2} = 'Tornado Watch';
            }
            elsif ( $Save{Severe_Wx_Type3} eq '' ) {
                $Save{Severe_Wx_Type3} = 'Tornado Watch';
            }
            elsif ( $Save{Severe_Wx_Type4} eq '' ) {
                $Save{Severe_Wx_Type4} = 'Tornado Watch';
            }
        }
        elsif ( (/Severe(.+)Thunderstorm(.+)Warning/)
            and $Save{Severe_Wx_Type} ne 'Thunderstorm Warning'
            and $Save{Severe_Wx_Type2} ne 'Thunderstorm Warning'
            and $Save{Severe_Wx_Type3} ne 'Thunderstorm Warning'
            and $Save{Severe_Wx_Type4} ne 'Thunderstorm Warning' )
        {
            $Save{Severe_Wx_Flag} = 1;
            $i++;
            $summary .=
              "A Severe Thunderstorm Warning has been issued and is currently in effect for $County county. ";
            if ( $Save{Severe_Wx_Type} eq '' ) {
                $Save{Severe_Wx_Type} = 'Thunderstorm Warning';
            }
            elsif ( $Save{Severe_Wx_Type2} eq '' ) {
                $Save{Severe_Wx_Type2} = 'Thunderstorm Warning';
            }
            elsif ( $Save{Severe_Wx_Type3} eq '' ) {
                $Save{Severe_Wx_Type3} = 'Thunderstorm Warning';
            }
            elsif ( $Save{Severe_Wx_Type4} eq '' ) {
                $Save{Severe_Wx_Type4} = 'Thunderstorm Warning';
            }
        }
        elsif ( (/Severe(.+)Thunderstorm(.+)Watch/)
            and $Save{Severe_Wx_Type} ne 'Thunderstorm Watch'
            and $Save{Severe_Wx_Type2} ne 'Thunderstorm Watch'
            and $Save{Severe_Wx_Type3} ne 'Thunderstorm Watch'
            and $Save{Severe_Wx_Type4} ne 'Thunderstorm Watch' )
        {
            $Save{Severe_Wx_Flag} = 1;
            $i++;
            $summary .=
              "A Severe Thunderstorm Watch has been issued and is currently in effect for $County county. ";
            if ( $Save{Severe_Wx_Type} eq '' ) {
                $Save{Severe_Wx_Type} = 'Thunderstorm Watch';
            }
            elsif ( $Save{Severe_Wx_Type2} eq '' ) {
                $Save{Severe_Wx_Type2} = 'Thunderstorm Watch';
            }
            elsif ( $Save{Severe_Wx_Type3} eq '' ) {
                $Save{Severe_Wx_Type3} = 'Thunderstorm Watch';
            }
            elsif ( $Save{Severe_Wx_Type4} eq '' ) {
                $Save{Severe_Wx_Type4} = 'Thunderstorm Watch';
            }
        }
        elsif ( (/Tornado(.+)Warning/)
            and $Save{Severe_Wx_Type} ne 'Tornado Warning'
            and $Save{Severe_Wx_Type2} ne 'Tornado Warning'
            and $Save{Severe_Wx_Type3} ne 'Tornado Warning'
            and $Save{Severe_Wx_Type4} ne 'Tornado Warning' )
        {
            $Save{Severe_Wx_Flag} = 1;
            $i++;
            $summary .=
              "A Tornado Warning has been issued and is currently in effect for $County county. ";
            if ( $Save{Severe_Wx_Type} eq '' ) {
                $Save{Severe_Wx_Type} = 'Tornado Warning';
            }
            elsif ( $Save{Severe_Wx_Type2} eq '' ) {
                $Save{Severe_Wx_Type2} = 'Tornado Warning';
            }
            elsif ( $Save{Severe_Wx_Type3} eq '' ) {
                $Save{Severe_Wx_Type3} = 'Tornado Warning';
            }
            elsif ( $Save{Severe_Wx_Type4} eq '' ) {
                $Save{Severe_Wx_Type4} = 'Tornado Warning';
            }
        }
        elsif ( (/Flood(.+)Warning/)
            and $Save{Severe_Wx_Type} ne 'Flood Warning'
            and $Save{Severe_Wx_Type2} ne 'Flood Warning'
            and $Save{Severe_Wx_Type3} ne 'Flood Warning'
            and $Save{Severe_Wx_Type4} ne 'Flood Warning' )
        {
            $Save{Severe_Wx_Flag} = 1;
            $i++;
            $summary .=
              "A Flood Warning has been issued and is currently in effect for $County county. ";
            if ( $Save{Severe_Wx_Type} eq '' ) {
                $Save{Severe_Wx_Type} = 'Flood Warning';
            }
            elsif ( $Save{Severe_Wx_Type2} eq '' ) {
                $Save{Severe_Wx_Type2} = 'Flood Warning';
            }
            elsif ( $Save{Severe_Wx_Type3} eq '' ) {
                $Save{Severe_Wx_Type3} = 'Flood Warning';
            }
            elsif ( $Save{Severe_Wx_Type4} eq '' ) {
                $Save{Severe_Wx_Type4} = 'Flood Warning';
            }
        }
        elsif ( (/Flood(.+)Watch/)
            and $Save{Severe_Wx_Type} ne 'Flood Watch'
            and $Save{Severe_Wx_Type2} ne 'Flood Watch'
            and $Save{Severe_Wx_Type3} ne 'Flood Watch'
            and $Save{Severe_Wx_Type4} ne 'Flood Watch' )
        {
            $Save{Severe_Wx_Flag} = 1;
            $i++;
            $summary .=
              "A Flood Watch has been issued and is currently in effect for $County county. ";
            if ( $Save{Severe_Wx_Type} eq '' ) {
                $Save{Severe_Wx_Type} = 'Flood Watch';
            }
            elsif ( $Save{Severe_Wx_Type2} eq '' ) {
                $Save{Severe_Wx_Type2} = 'Flood Watch';
            }
            elsif ( $Save{Severe_Wx_Type3} eq '' ) {
                $Save{Severe_Wx_Type3} = 'Flood Watch';
            }
            elsif ( $Save{Severe_Wx_Type4} eq '' ) {
                $Save{Severe_Wx_Type4} = 'Flood Watch';
            }
            $Save{Severe_Wx_Type} = 'Flood Watch';
        }

        $summary .= "$1" if /<br>(.+)<\/p>/;
    }

    if ( $summary ne '' and $summary ne $Save{prev_summary} ) {
        if ( $i > 1 ) {
            speak("Weather Alert: There are $i Weather Advisories:  $summary");
        }
        else {
            speak("Weather Alert: There is $i Weather Advisory:  $summary");
        }

        net_mail_send
          to      => $config_parms{cell_phone},
          subject => 'Weather Advisory',
          text =>
          'Weather Advisories issued for Tarrant County: $Save{Severe_Wx_Type} $Save{Severe_Wx_Type2} $Save{Severe_Wx_Type3} $Save{Severe_Wx_Type4}';
    }

    file_write "$f_weather_warnings_summary", $summary;
    $Save{prev_summary} = $summary;
}
