
# Authority: anyone

# This code generates the status line at the bottom of some web pages.
# See bin/mh/mh.ini for more info

my $argv  = join '&', @ARGV;
my @parms = @ARGV;
my $parms = "@parms";
my %parms = map { $_, 1 } @parms;

my $color = $config_parms{html_color_header};

my ( $fontsize, undef, $fontname ) = $parms =~ /font=(\d+)(;(\S+))? /;
$fontsize = 3 unless $fontsize;

$color = $1 if $parms =~ /color=(\S+)/;

my $fontstart = qq[<font size=${fontsize}>];
$fontstart = qq[<font size=${fontsize} face="${fontname}">] if $fontname;

#color = '#cccdcc';
$color = '#9999cc' unless $color;

my $html = qq[<html><head><title>MrHouse</title>\n];

# Try javascript, instead of meta refresh ... might be more reliable?

my $refresh_rate = $config_parms{html_status_refresh};
$refresh_rate = 60 unless $refresh_rate;

#print "db rr=$refresh_rate\n";

# This is simplier.
$html .= qq[<meta http-equiv='Refresh' content='$refresh_rate'>\n];

# The javascript refresh can cause problems.   When the java timer expires and it
# triggers a refresh on the Audrey, it will interrupt any other voyager browser activity.
# Disable by avoiding the 'doLoad' call.
my $refresh_rate2 = $refresh_rate * 1000;
my $servertimestr = "$Date_Now $Year $Hour:$Minute:$Second";
$servertimestr =~ s/^[^,]+,//;
$html .= qq|
<script language="JavaScript">
var dateused=false;
function doLoad()  { setTimeout( "refresh()", $refresh_rate2 ); }
function refresh() { window.location.href = "status_line.pl?$argv"; }
var servertimestr = '$servertimestr';
</script>
|;
$html .= qq|<script language="JavaScript">dateused=true</script>|
  if $parms{date};

if ( $parms{jclock1} or $parms{jclock2} ) {
    $html .= &file_read("$config_parms{html_dir}/bin/clock1.js")
      if $parms{jclock1};
    $html .= &file_read("$config_parms{html_dir}/bin/clock2.js")
      if $parms{jclock2};
    $html .= "</head>\n";
    $html .= qq[<body bgcolor='$color' onLoad="clock()">\n];

    #   $html .= qq[<body bgcolor='$color' onLoad="clock();doLoad()">\n];
    $html =~ s/font size='\d'/font size='$fontsize'/ if $fontsize != 2;
}
else {
    $html .= "</head>\n";
    $html .= qq[<body bgcolor='$color'>\n];

    #   $html .= qq[<body bgcolor='$color' onload='doLoad()'>\n];
}

$html .= qq[<form>\n];

$html .=
  qq[<table cellpadding=0 cellspacing=0 width='100%' border='0' align='center'>\n];
$html .= qq[<tr valign='center'><td nowrap><b>$fontstart\n];

# Do parms in specified order
for my $parm (@parms) {

    # Allow for a reference mintute, so we can verify against javaclock
    if ( $parm eq 'minute' ) {
        $html .= qq[$Minute];
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
            $html .=
              qq[&nbsp;<img src='/ia5/images/sunrise.gif' border=0>&nbsp;Rise $Time_Sunrise\n];
        }
        else {
            $html .=
              qq[&nbsp;<img src='/ia5/images/sunset.gif' border=0>&nbsp;Set $Time_Sunset\n];
        }
    }

    elsif ( $parm eq 'mode' ) {
        $html .= qq[&nbsp;<img src='/ia5/images/home.gif' border=0>&nbsp;];
        if ( $Save{mode} ne 'normal' ) {
            $html .= qq[<FONT color='red'><BLINK>$Save{mode}</BLINK></FONT>\n];
        }
        else {
            $html .= qq[$Save{mode}\n];
        }
        use vars '$mh_volume';    # In case we don't have mh_sound
        if ($mh_volume) {
            my $sl_vol = state $mh_volume;
            $html .= qq[($sl_vol%)\n];
        }
    }

    # This can be set by an mp3 player script
    elsif ( $parm eq 'playing' ) {
        my $html_playing = $Save{NowPlaying};
        $html .= qq[$html_playing];
    }

    elsif ( $parm eq 'email' ) {
        $Save{email_flag} = '' unless $Save{email_flag};
        $html .=
          qq[&nbsp;<img src='/ia5/images/mail.gif' border=0>$Save{email_flag}\n];
    }

    elsif ( $parm eq 'weather' ) {
        $Weather{Summary_Short} = '' unless $Weather{Summary_Short};
        $html .=
          qq[&nbsp;<img src='/ia5/images/temp.gif' border=0>&nbsp;$Weather{Summary_Short}\n];
    }
    elsif ( $parm eq 'weather_long' ) {
        $Weather{Summary} = '' unless $Weather{Summary};
        $html .=
          qq[&nbsp;<img src='/ia5/images/temp.gif' border=0>&nbsp;$Weather{Summary}\n];
    }

    elsif ( $parm eq 'wind' ) {
        my $html_wind = $Weather{Wind};
        $html_wind = '' unless $html_wind;
        $html_wind =~ s/from the/ /;
        $html .=
          qq[&nbsp;<img src='/ia5/images/wind.gif' border=0>&nbsp;$html_wind\n];
    }

    # Allow for user defined html (e.g. code/bruce/web_sub.pl)
    elsif ( $parm eq 'web_status_line' ) {
        $html .= &web_status_line();
    }

}

$html .= "</font></td>\n";

if ( $parms{date} ) {
    $html .=
      qq[<td id='jdate' nowrap align='right'>$fontstart<b>$Date_Now</b></font></td>\n];
}
if ( $parms{clock} ) {
    $html .= qq[<td nowrap>${fontstart}<b>&nbsp;$Time_Now</b></font></td>\n];
}
if ( $parms{jclock1} ) {
    $html .=
      qq[<td><form name=form><input type=button name=jclock value='' style="font-size: 15"></form></td>\n];
}
if ( $parms{jclock2} ) {
    $html .=
      qq[<td nowrap align='right'><div id='jclock'>${fontstart}<b>&nbsp;$Time_Now</b></font></div></td>\n];
}

$html .= qq[</tr></table></form></body></html>\n];

return &html_page( '', $html, ' ' );
