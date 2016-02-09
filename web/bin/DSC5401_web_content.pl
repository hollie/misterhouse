# DSC5401_web_content.pl
#
# $Revision$
# $Date$

my $DSCrefresh   = 60;
my @RefreshValue = qw[ 1 2 5 15 30 60 ];

my %Color = (
    'red'     => '#FF0000',
    'orange'  => '#FF6600',
    'yellow'  => '#FFFF00',
    'blue'    => '#0000FF',
    'default' => '#9999CC',
    'green'   => '#336633'
);

# parse command from web form
foreach (@ARGV) {
    print_log "WEB:DSC5401_web.pl: Receive alarm command $_"
      if $config_parms{debug} eq "DSC5401";
    my ( $DSCcommand, $DSCarg ) = split( '=', $_ );

    if ( $DSCcommand eq "TstatBroadcast" ) {
        $DSC->{TstatBroadcast} = $DSCarg;
        DSC5401->cmd( "TemperatureBroadcastControl", 1 ) if $DSCarg eq 'on';
        DSC5401->cmd( "TemperatureBroadcastControl", 0 ) if $DSCarg eq 'off';
        &::print_log(
            "DSC5401 WEB: The system temperature broadcast is now $DSCarg");
        &::logit(
            "$main::config_parms{data_dir}/logs/DSC5401.$main::Year_Month_Now.log",
            "DSC5401 WEB: The system temperature broadcast is now $DSCarg"
        );
    }

    if ( $DSCcommand eq "TimeBroadcast" ) {
        $DSC->{TimeBroadcast} = $DSCarg;
        DSC5401->cmd( "TimeBroadcastControl", 1 ) if $DSCarg eq 'on';
        DSC5401->cmd( "TimeBroadcastControl", 0 ) if $DSCarg eq 'off';
        &::print_log("DSC5401 WEB: The system time broadcast is now $DSCarg");
        &::logit(
            "$main::config_parms{data_dir}/logs/DSC5401.$main::Year_Month_Now.log",
            "DSC5401 WEB: The system time broadcast is now $DSCarg"
        );
    }

    if ( $DSCcommand eq "PartitionArmControl" ) {
        DSC5401->cmd( "PartitionArmControl", 1 );
        &::print_log("DSC5401 WEB: Arming AWAY without access code");
        &::logit(
            "$main::config_parms{data_dir}/logs/DSC5401.$main::Year_Month_Now.log",
            "DSC5401 WEB: Arming AWAY without access code"
        );
    }

    if ( $DSCcommand eq "PartitionArmControlStayArm" ) {
        DSC5401->cmd( "PartitionArmControlStayArm", 1 );
        &::print_log("DSC5401 WEB: Arming STAY without access code");
        &::logit(
            "$main::config_parms{data_dir}/logs/DSC5401.$main::Year_Month_Now.log",
            "DSC5401 WEB: Arming STAY without access code"
        );
    }

    if ( $DSCcommand eq "SetDateTime" ) {
        my ( $sec, $m, $h, $mday, $mon, $year, $wday, $yday, $isdst ) =
          localtime(time);
        $year = sprintf( "%02d", $year % 100 );
        $mon += 1;
        $m    = ( $m < 10 )    ? "0" . $m    : $m;
        $h    = ( $h < 10 )    ? "0" . $h    : $h;
        $mday = ( $mday < 10 ) ? "0" . $mday : $mday;
        $mon  = ( $mon < 10 )  ? "0" . $mon  : $mon;
        my $TimeStamp = "$h$m$mon$mday$year";
        $DSC->cmd( "SetDateTime", $TimeStamp );
        &::print_log(
            "DSC5401 WEB: Setting time on DSC panel to $TimeStamp (hhmmMMDDYY)"
        );
        &::logit(
            "$main::config_parms{data_dir}/logs/DSC5401.$main::Year_Month_Now.log",
            "DSC5401 WEB: Setting time on DSC panel to $TimeStamp (hhmmMMDDYY)"
        );
    }

    if ( $DSCcommand eq "PartitionArmControlWithCode" ) {
        $DSC->cmd( "PartitionArmControlWithCode", "1", "$DSCarg" )
          if $DSCarg ne '';
        &::print_log("DSC5401 WEB: Arming system with access code");
        &::logit(
            "$main::config_parms{data_dir}/logs/DSC5401.$main::Year_Month_Now.log",
            "DSC5401 WEB: Arming system with access code"
        );
    }

    if ( $DSCcommand eq "PartitionDisarmControl" ) {
        $DSC->cmd( "PartitionDisarmControl", "1", "$DSCarg" ) if $DSCarg ne '';
        &::print_log("DSC5401 WEB: Disarming system with access code");
        &::logit(
            "$main::config_parms{data_dir}/logs/DSC5401.$main::Year_Month_Now.log",
            "DSC5401 WEB: Disarming system with access code"
        );
    }

    if ( $DSCcommand eq "PartitionEventMsg" ) {
        my $log = ( $DSCarg eq "On" ) ? 1 : 0;
        $::config_parms{DSC_5401_part_log} = $log;
    }

    if ( $DSCcommand eq "ZoneEventMsg" ) {
        my $log = ( $DSCarg eq "On" ) ? 1 : 0;
        $::config_parms{DSC_5401_zone_log} = $log;
    }

    if ( $DSCcommand eq "refresh" ) {
        $DSCrefresh = $DSCarg;
    }

}

# html header  {{{
use vars '$DSC';
my $html;
$html .=
  qq[<html>\n<meta http-equiv='refresh' content='$DSCrefresh; URL=DSC5401_web_content.pl?refresh=$DSCrefresh'>\n];
$html .= qq[
<body>
];

my $StatusColor = 'blue';
$StatusColor = 'green'  if $DSC->{partition_status}{1} =~ /ready/;
$StatusColor = 'orange' if $DSC->{partition_status}{1} =~ /armed/;
$StatusColor = 'yellow' if $DSC->{partition_cmd}{1} >= "800";
$StatusColor = 'red'    if $DSC->{partition_status}{1} =~ /alarm/;
$html .=
  &my_header( "System status ($DSC->{partition_status}{1})", "$StatusColor" ),
  "\n";

# }}}

# display zone {{{
$html .= qq[<center>\n];
$html .= qq[<table cellSpacing=4 cellPadding=0 width='100%' border=1>\n];
$html .= qq[  <tr>\n];

my @name = DSC5401->ZoneName;
my $size = scalar(@name) - 1;

for ( 1 .. $size ) {

    my $Str = ( $_ < 10 ) ? "0$_: " : "$_: ";
    if ( $name[$_] ) {
        $Str .= $name[$_];
        my $status = $DSC->{zone_status}{$_};
        $Str .= "  <FONT COLOR=\"#800000\">($status)</FONT>"
          if $status ne "restored";

        $html .= qq[    <td width=33% align='left'>];
        $html .=
          qq[ <img border=0 name="ZONE_${_}" src="/graphics/green_bullet.gif">&nbsp $Str</td>\n]
          if $status eq "restored";
        $html .=
          qq[ <img border=0 name="ZONE_${_}"src="/graphics/red_bullet.gif">&nbsp $Str</td>\n]
          if $status ne "restored";
    }
    else {
        $Str  .= "Not Used";
        $html .= qq[    <td width=33% align='left' BGCOLOR='#DDDDDD'>];
        $html .=
          qq[ <img border=0 src="/graphics/black_bullet.gif">&nbsp $Str</td>\n]
          if $Str =~ /Not Used/;
    }

    $html .= qq[  </tr>\n  <tr>\n] unless $_ % 3;    # 2 icons per line
}
$html .= qq[</tr>\n];
$html .= qq[</table>\n];
$html .= qq[</center>\n];

#}}}

# show user command and status if available {{{
$html .= &my_header('User command');
$html .= qq[<table cellSpacing=0 cellPadding=0 width='100%' border=1>\n];
$html .= qq[<FORM action="/bin/DSC5401_web_content.pl" method="post">];
$html .= qq[<INPUT TYPE=hidden NAME='refresh' VALUE='$DSCrefresh'>\n];

$html .= qq[  <tr>\n];

# trigger thermostat broadcast
my $state = $DSC->{TstatBroadcast};

#$html .= qq[    <td width=50%>Thermostat broadcast is $state , set to ];
$html .= qq[    <td width=50%>Thermostat broadcast ];
$html .=
  qq[<input type="submit"  name="TstatBroadcast"  value="off" style="width: 30; border: 1px solid silver;">]
  if $state eq 'on';
$html .=
  qq[<input type="submit"  name="TstatBroadcast"  value="on" style="width: 40; border: 1px solid silver;">]
  if $state eq 'off';
$html .= qq[</td>\n];

# trigger timestamp broadcast
my $state = $DSC->{TimeBroadcast};

#$html .= qq[    <td width=50%>Time broadcast is $state , set to ];
$html .= qq[    <td width=50%>Time broadcast ];
$html .=
  qq[<input type="submit"  name="TimeBroadcast"  value="off"style="width: 30; border: 1px solid silver;">]
  if $state eq 'on';
$html .=
  qq[<input type="submit"  name="TimeBroadcast"  value="on" style="width: 40; border: 1px solid silver;">]
  if $state eq 'off';
$html .= qq[</td>\n];
$html .= qq[  </tr>\n\n];

$html .= qq[  <tr>\n];

# trigger partition event log message
my $state = $DSC->{TstatBroadcast};
my $log = $::config_parms{DSC_5401_part_log} ? "on" : "off";
$html .= qq[    <td width=50%>Partition event msg &nbsp; ($log)&nbsp;];
$html .=
  qq[<input type="submit"  name="PartitionEventMsg"  value="On"  style="width: 50; border: 1px solid silver;">];
$html .=
  qq[<input type="submit"  name="PartitionEventMsg"  value="Off" style="width: 50; border: 1px solid silver;">];
$html .= qq[</td>\n];

# trigger zone event log message
my $state = $DSC->{TimeBroadcast};
my $log = $::config_parms{DSC_5401_zone_log} ? "on" : "off";
$html .= qq[    <td width=50%>Enable zone event msg &nbsp; ($log)&nbsp;];
$html .=
  qq[<input type="submit"  name="ZoneEventMsg"  value="On"  style="width: 50; border: 1px solid silver;">];
$html .=
  qq[<input type="submit"  name="ZoneEventMsg"  value="Off" style="width: 50; border: 1px solid silver;">];
$html .= qq[</td>\n];
$html .= qq[  </tr>\n\n];

$html .= qq[  <tr>\n];

# set alarm time and date from PC
#$html .= qq[    <td width=50%>];
$html .= qq[    <td width=50%>];
$html .=
  qq[<input type="submit"  name="SetDateTime"  value="Set time & date" style="width: 100; border: 1px solid silver;">];
$html .= qq[</td>\n];

# enable verbose logging
$html .= qq[    <td width=50%>Verbose arming control&nbsp;&nbsp;];
$html .=
  qq[<input type="submit"  name="VerboseArmingControl"  value="On"  style="width: 50; border: 1px solid silver;">];
$html .=
  qq[<input type="submit"  name="VerboseArmingControl"  value="Off" style="width: 50; border: 1px solid silver;">];

$html .= qq[</td>\n];
$html .= qq[  </tr>\n\n];

$html .= qq[  <tr>\n];

# Arm system Away without access code
$html .= qq[    <td width=50%>System ];
$html .=
  qq[<input type="submit"  name="PartitionArmControl"  value="Arm away" style="width: 60; border: 1px solid silver;">];
$html .= qq[</td>\n];
$html .= qq[    <td width=50%>System ];
$html .=
  qq[<input type="submit"  name="PartitionArmControlStayArm"  value="Arm stay" style="width: 60; border: 1px solid silver;">];
$html .= qq[</td>\n];
$html .= qq[  </tr>\n\n];

$html .= qq[</FORM>\n];
$html .= qq[</table>\n];

$html .= qq[<table cellSpacing=0 cellPadding=0 width='100%' border=1>\n];
$html .= qq[<FORM action="/bin/DSC5401_web_content.pl" method="post">];
$html .= qq[<INPUT TYPE=hidden NAME='refresh' VALUE='$DSCrefresh'>\n];

$html .= qq[  <tr>\n];

# Arm system without access code
$html .= qq[    <td width=50%>Arm with access code ];
$html .=
  qq[       <input type="password"  name="PartitionArmControlWithCode" onChange="this.form.submit()" style="width: 40px; border: 2px solid silver;">\n];
$html .= qq[    </td>\n];

# Disarm system with access code
$html .= qq[    <td width=50%>Disarm with access code\n];
$html .=
  qq[       <input type="password"  name="PartitionDisarmControl"  size=6 onChange="this.form.submit()" style="width: 40px; border: 2px solid silver;">\n];
$html .= qq[    </td>\n];

$html .= qq[  </tr>\n\n];
$html .= qq[</FORM>\n];
$html .= qq[</table>\n];

#}}}

# show last log entry {{{
$html .= &my_header('Log');
$html .= qq[<FORM action="/bin/DSC5401_web_content.pl" method="post">];
$html .= qq[<INPUT TYPE=hidden NAME='refresh' VALUE='$DSCrefresh'>\n];
$html .= qq[<TEXTAREA name="thetext" rows="14" cols="100%">\n];
foreach ( @{ $DSC->{Log} } ) {
    $html .= "$_\r";
}
$html .= qq[</TEXTAREA>];

#}}}

#  put a refresh pulldown menu
$html .=
  qq[<br><form method='get' onsubmit=submit() action='DSC5401_web_content.pl' enctype='application/x-www-form-urlencoded'>Refresh: \n];
$html .= qq[  <select name="refresh" onchange="submit()">\n];
foreach (@RefreshValue) {
    if ( $DSCrefresh == $_ ) {
        $html .= qq[    <option selected='$_' value='$_'>$_ sec</option>\n];
    }
    else {
        $html .= qq[    <option value='$_'>$_ sec</option>\n];
    }
}
$html .= qq[  </select>\n</form>\n];

# html footer {{{
$html .= qq[</body>];
$html .= qq[</html>];

return &html_page( '', $html );

#}}}

sub my_header {
    my $txt   = shift;
    my $color = shift;
    $color = ($color) ? $color : "default";

    my $local_html;
    $local_html .= qq[<table width=100% bgcolor=$Color{$color}>];
    $local_html .= qq[<td><center>];
    $local_html .= qq[<font size=3 color="black"><b>];
    $local_html .= qq[$txt];
    $local_html .= qq[</b></font>];
    $local_html .= qq[</center></td>];
    $local_html .= qq[</table>];
    return $local_html;

}
