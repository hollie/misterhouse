# Category = Vehicles

$radar_active = new Generic_Item;

$timer_aftercon = new Timer;
$timer_beforedis = new Timer;

my ($ManualRadarFlag);

if ($Startup or $Reload) {
    set $radar_active 'no';
}

$p_get_radar = new Process_Item("get_url http://www.findu.com/cgi-bin/radar-find.cgi?call=n0qvc-1&nocall=1&offsetx=40&offsety=35 $config_parms{data_dir}/web/radar.png");
#$p_get_radar2 = new Process_Item("get_url http://www.swiftwx.com/warnings/warnings.aspx $config_parms{data_dir}/web/warnings.asp");
#$p_get_radar3 = new Process_Item("get_url http://www.swiftwx.com/warnings/watches.aspx $config_parms{data_dir}/web/watches.asp");

$v_get_radar = new  Voice_Cmd('Retrieve Chicklet Radar');
if (said $v_get_radar) {
    $ManualRadarFlag = 'yes';
    start $p_get_radar;
    #start $p_get_radar2;
    #start $p_get_radar3;
    speak "Retrieving RADAR";
}

# Main Loop

#if ((substr($APRSString, 0, 7) eq '*** CON') ||   # If a packet comes in,
#   (substr($APRSString, 0, 11) eq 'cmd:*** CON')) { # and we are connected,
#    speak "We're connected!";
#    set $tnc_output "$HamCall Radar Retrieval System";
#    set $radar_active 'yes';
#    set $enable_transmit 'no';
#    start $p_get_radar;
#    #start $p_get_radar2;
#    #start $p_get_radar3;
#    speak "Retrieving RADAR";
#}

# If the TNC shows we are disconnected, force a disconnect and re-enter
# converse mode.
if ((substr($APRSString, 0, 7) eq '*** DIS') ||
    (substr($APRSString, 0, 11) eq 'cmd:*** DIS') ||
    (substr($APRSString, 0, 15) eq 'cmd:cmd:*** DIS')) {
    set $timer_beforedis 1;
    speak "Disconnected!";
    set $enable_transmit 'yes';
    set $radar_active 'no';
    set $tnc_output pack('C',3);                  # Send Control-C
    set $tnc_output 'CONV';                       # Enter Converse Mode
}

# Force a disconnect
if (expired $timer_beforedis) {
    set $timer_beforedis 0;
    set $enable_transmit 'yes';
    set $radar_active 'no';
    set $tnc_output pack('C',3);                  # Send Control-C
    set $tnc_output 'D';                          # Go to Disconnect
    set $tnc_output 'CONV';                       # Enter Converse Mode
}

# After we retrieve the radar, pause for 15 seconds to allow uuencode to
# do it's thing.
if (done_now $p_get_radar) {
    speak "Done Retrieving Radar";
    if ($ManualRadarFlag ne 'yes') {set $timer_aftercon 15};
    $ManualRadarFlag = '';
    run qq[uueradar];
}

# After the 15 seconds is up, go ahead and send the data to the remote
# station.
if (expired $timer_aftercon) {
    set $timer_aftercon 0;
    my $RadarBase64 = file_read("$config_parms{data_dir}/web/radar.001");
    set $tnc_output $RadarBase64;
    set $timer_beforedis 360;
}
