# Category=Alarm

#@ Verion 1.0
#@ This module set the DSC Panel Clock
# $Revision$
# $Date$

if ( $Startup || $Reload ) {
    print_log "DSC Panel Clock Sync statup...";

    #use DSC5401;
    #$DSC = new DSC5401;
}

#- Each new day Sync DSC Time Clock to MH
if ($New_Day) {
    my ( $sec, $m, $h, $mday, $mon, $year, $wday, $yday, $isdst ) =
      localtime(time);
    $year = sprintf( "%02d", $year % 100 );
    $mon += 1;
    $m    = ( $m < 10 )    ? "0" . $m    : $m;
    $h    = ( $h < 10 )    ? "0" . $h    : $h;
    $mday = ( $mday < 10 ) ? "0" . $mday : $mday;
    $mon  = ( $mon < 10 )  ? "0" . $mon  : $mon;
    my $TimeStamp = "$h$m$mon$mday$year";
    &::print_log("Setting time on DSC panel to $TimeStamp");
    &::logit(
        "$main::config_parms{data_dir}/logs/DSC5401.$main::Year_Month_Now.log",
        "Setting time on DSC panel to $TimeStamp"
    );
    $DSC->cmd( "SetDateTime", $TimeStamp );
}    # END of new day

