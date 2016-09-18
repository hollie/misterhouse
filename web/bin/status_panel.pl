
# Authority: anyone

# This code generates the status panel on the left of some of the Improved UI web pages.
# See bin/mh/mh.ini for more info

my $argv = join '&', @ARGV;
my @parms = split( '&', $config_parms{html_status_line} );
my $parms = "@parms";
my %parms = map { $_, 1 } @parms;

my $html = qq[];

# Do parms in specified order
for my $parm (@parms) {

    # Allow for a reference mintute, so we can verify against javaclock
    if ( $parm eq 'minute' ) {
        $html .= qq[<p><b>Current Minute:</b> $Minute</p>\n];
    }

    # Allow for sun (auto-pick), sunrise, or sunset
    elsif ( $parm =~ /sun/ ) {
        if ( $parm eq 'sun' ) {
            $parm = (
                     time_less_than "$Time_Sunrise + 2:00"
                  or time_greater_than "$Time_Sunset  + 2:00"
            ) ? 'sunrise' : 'sunset';
        }
        if ( $parm eq 'sunrise' ) {
            $html .= qq[<p><b>Sunrise:</b> $Time_Sunrise</p>\n];
        }
        else {
            $html .= qq[<p><b>Sunset:</b> $Time_Sunset</p>\n];
        }
    }

    elsif ( $parm eq 'mode' ) {
        $html .= qq[<p><b>Mode:</b> <span style="text-transform: capitalize;">];
        if ( $Save{mode} ne 'normal' ) {
            $html .= qq[<FONT color='red'><BLINK>$Save{mode}</BLINK></FONT>];
        }
        else {
            $html .= qq[$Save{mode}];
        }
        $html .= qq[</span>];
        use vars '$mh_volume';    # In case we don't have mh_sound
        if ($mh_volume) {
            my $sl_vol = state $mh_volume;
            $html .= qq[ (Vol: $sl_vol%)];
        }
        $html .= qq[</p>\n];
    }

    # This can be set by an mp3 player script
    elsif ( $parm eq 'playing' ) {
        my $html_playing = $Save{NowPlaying};
        $html .= qq[<p><b>Playing:</b> $html_playing</p>\n];
    }

    elsif ( $parm eq 'email' ) {
        $Save{email_flag} = 'Unavailable' unless $Save{email_flag};
        $html .= qq[<p><b>Mail:</b> $Save{email_flag}</p>\n];
    }

    elsif ( $parm eq 'weather' ) {
        $Weather{Summary_Short} = 'Unavailable' unless $Weather{Summary_Short};
        $html .= qq[<p><b>Temp:</b> $Weather{Summary_Short}</p>\n];
    }
    elsif ( $parm eq 'weather_long' ) {
        $Weather{Summary} = 'Unavailable' unless $Weather{Summary};

        #$html .= qq[<p><b>Weather:</b> $Weather{Summary}</p>\n];
    }

    elsif ( $parm eq 'wind' ) {
        my $html_wind = $Weather{Wind};
        $html_wind = 'Unavailable' unless $html_wind;
        $html_wind =~ s/from the/ /;
        $html .= qq[<p><b>Wind:</b> $html_wind</p>\n];
    }

    # Allow for user defined html (e.g. code/bruce/web_sub.pl)
    elsif ( $parm eq 'web_status_line' ) {
        $html .= &web_status_line();
    }

}

if ( $parms{date} ) {
    $html .= qq[<p><b>Date:</b> $Date_Now, $Year</p>\n];
}
if ( $parms{clock} ) {
    $html .= qq[<p><b>Time:</b> $Time_Now</p>\n];
}

return $html;
