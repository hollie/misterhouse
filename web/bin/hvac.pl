use strict;
$^W = 0;    # Avoid redefined sub msgs

# From Kirk Bauer on 2/2004, for use with RCS TR40 theromstat.

my ( $function, @parms ) = @ARGV;

if ( $function eq 'set' ) {
    return &hvac_set();
}
elsif ( $function eq 'cancel' ) {
    return &hvac_cancel();
}
else {
    return &hvac_ask();
}

sub hvac_ask {
    my $html       = &html_header('HVAC Status');
    my $currtemp   = $thermostat->get_temp();
    my $currhsp    = $thermostat->get_heat_sp();
    my $currcsp    = $thermostat->get_cool_sp();
    my $currfan    = $thermostat->get_fan_mode();
    my $currmode   = $thermostat->get_mode();
    my $state      = $Save{'hvac_state'};
    my $state_disp = $state;
    my $sunindex   = &get_sun_index();

    if ( $state eq 'hold' ) {
        $state_disp = '<font style="color:red">HOLD</font>';
    }

    $html = qq|
<HTML><HEAD><TITLE>HVAC Status</TITLE></HEAD>
<BODY>
<meta http-equiv="refresh" content="30">
$html
<table border=1>
 <tr><th>Time Now</th><td> $Time_Date</td>
 <tr><th>Current Temperature</th><td> $currtemp</td>
 <tr><th>Current HVAC Situation</th><td> $state_disp</td>
 <tr><th>Current Heat Setpoint</th><td> $currhsp</td>
 <tr><th>Current Cool Setpoint</th><td> $currcsp</td>
 <tr><th>System Mode</th><td> $currmode</td>
 <tr><th>Fan Mode</th><td> $currfan</td>
 <tr><th>Estimated Sun Index</th><td> $sunindex</td>
 <tr><th>Estimated Outside Temperature</th><td> $Weather{TempInternet}</td>
</table><p /><table border=1 cellpadding=5>
<tr><th colspan=2>Family Room Fan</th><th colspan=2>Master Bedroom Fan</th><th colspan=2>Dining Room Fan</th></tr>
<tr>
|;

    $html .=
      (     "<td>"
          . state $fr_fan_motor
          . "</td><td><form action='/SET;referer' name=fr_fan><select onchange='fr_fan.submit()' name='\$fr_fan_motor'><option></option><option value='off'>Off</option><option value='low'>Low</option><option value='med'>Medium</option><option value='high'>High</option></form></td>"
      );
    $html .=
      (     "<td>"
          . state $mb_fan_motor
          . "</td><td><form action='/SET;referer' name=mb_fan><select onchange='mb_fan.submit()' name='\$mb_fan_motor'><option></option><option value='off'>Off</option><option value='low'>Low</option><option value='med'>Medium</option><option value='high'>High</option></form></td>"
      );
    $html .=
      (     "<td>"
          . state $dr_fan_motor
          . "</td><td><form action='/SET;referer' name=dr_fan><select onchange='dr_fan.submit()' name='\$dr_fan_motor'><option></option><option value='off'>Off</option><option value='low'>Low</option><option value='med'>Medium</option><option value='high'>High</option></form></td>"
      );
    $html .= "</tr></table>";

    if ( $state eq 'hold' ) {
        $html .=
          '<P>Click <a href="hvac.pl?cancel">here to cancel the hold</a>.</P>';
    }
    else {
        $html .= qq|
<h3>Override the setpoints here (will expire overnight):</h3>
<form action='hvac.pl?set' method=post>
Heat SP: <input type=input name=heat_sp size=2 value="$currhsp">&nbsp;F
&nbsp;Cool SP: <input type=input name=cool_sp size=2 value="$currcsp">&nbsp;F
&nbsp;<input type=submit value='Activate Hold'>
</form>
|;
    }
    $html .= "<h3>Today's Log</h3><pre>";
    unless ( open( HVACLOG, "/mh/data/logs/hvac/$Year$Month$Mday.log" ) ) {
        print_log "Could not open hvac log: $!";
    }
    my @lines;
    while ( my $line = <HVACLOG> ) {
        unshift @lines, $line;
    }
    close(HVACLOG);
    foreach (@lines) {
        $html .= $_;
    }
    $html .= "\n</pre>";
    return &html_page( '', $html );
}

sub hvac_cancel {
    return 'Not authorized to make updates' unless $Authorized;
    $Save{'hvac_state'} = 'run - temp change pending';
    &hvac_ask();
}

sub hvac_set {
    return 'Not authorized to make updates' unless $Authorized;
    foreach (@parms) {
        if ( $_ =~ s/heat_sp=// ) {
            $thermostat->heat_setpoint($_);
        }
        elsif ( $_ =~ s/cool_sp=// ) {
            $thermostat->cool_setpoint($_);
        }
    }
    $Save{'hvac_state'} = 'hold';
    &hvac_ask();
}
