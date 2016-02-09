# Category=Alarm

#@ Verion 1.0
#@ DSC Alert Notification via e-mail
# $Revision$
# $Date$

if ( $Startup || $Reload ) {
    print_log "DSC Alarm Notification Statup...";
    my $DSC_text             = "";
    my $alarm_previous_state = 0;
    $DSC_Alarm_Timer = new Timer();
}

if ( $DSC->{partition_status}{1} =~ /alarm/ ) {
    if ( my $ZoneEvent = $DSC->zone_now ) {
        print_log "$DSC->{partition_status}{1} DSC->zone_now: $ZoneEvent";
        $DSC_text = "DSC $DSC->{partition_status}{1} - Zone:$ZoneEvent";

        &alarm_page("$DSC_text");
    }

    $alarm_previous_state = 1;
    if ( active $DSC_Alarm_Timer) { unset $DSC_Alarm_Timer }
    set $DSC_Alarm_Timer 300;

    if ($Dark) {
        set $All_Lights ON;
    }
}

if ( ( $alarm_previous_state = 1 ) && ( $DSC->state_now =~ /^disarmed/ ) ) {
    print_log
      "DSC Restored after alarm By: $DSC->{user_name} ($DSC->{user_id})";
    $DSC_text =
      "DSC Alarm Restored by $DSC->{user_name} ($DSC->{user_id}) $Date_Now $Time_Now";

    &alarm_page("$DSC_text");
    $DSC_text             = "";
    $alarm_previous_state = 0;
}

if ( expired $DSC_Alarm_Timer) {
    $alarm_previous_state = 0;
    print_log "DSC-MH Automatic Reset Alarm after infaction... ";
    $DSC_text =
      "DSC-MH Automatic Reset Alarm after infaction... $Date_Now $Time_Now";
    &alarm_page("$DSC_text");
    $DSC_text = "";
}

#---
# Subroutine to send a page / pcs message, etc.
#---
sub alarm_page {
    my ($text2) = @_;

    net_mail_send(
        from    => "a\@videotron.ca",
        to      => "a\@txt.bellmobilite.ca",
        text    => $text2,
        subject => $text2
    );

    net_mail_send(
        from    => "a\@videotron.ca",
        to      => "a\@cgi.com",
        text    => $text2,
        subject => $text2
    );

    net_mail_send(
        from    => "a\@videotron.ca",
        to      => "a\@videotron.ca",
        text    => $text2,
        subject => $text2
    );

    speak(
        mode   => 'unmuted',
        volume => 100,
        rooms  => 'all',
        text   => "DSC Alarm Panel Said $text2"
    );
    print_log "DSC email notification was sent...";
}

