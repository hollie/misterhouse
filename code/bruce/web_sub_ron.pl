
#@ Code with web functions for Audrey's interface by Ron Klinkien

# Write today's calender (UNIX) facts.
if ($New_Day) {
    run
      qq[calendar -A 1 -f /usr/share/calendar/calendar.world >$config_parms{html_dir}/ia5/calendar/calendar.txt];
    return;
}

# Grab an image from my MiroPCTV camera.
# Being run from cameras/*.shtml.
sub backgrab {
    run
      qq[/mh/bin_my/grab -type jpeg -width 320 -height 240 -output $config_parms{html_dir}/ia5/cameras/captures/back_latest.jpg -quality 100 -settle 1];
    return;
}

# Grab an image from my QuickCam camera.
# Because it works to slow save a tmpcopy first.
# Being run from cameras/*.shtml.
sub deskgrab {
    copy(
        "$config_parms{html_dir}/ia5/cameras/captures/desk_tmp.jpg",
        "$config_parms{html_dir}/ia5/cameras/captures/desk_latest.jpg"
    );
    run
      qq[/mh/bin_my/cqcam -q 100 -32+ -j -x 320 -y 240 >$config_parms{html_dir}/ia5/cameras/captures/desk_tmp.jpg];
    return;
}

# Save a small fortune cookie every hour
# for use on menu.shtml.
if ( $New_Hour and !$OS_win ) {
    run
      qq[/usr/games/fortune -s >$config_parms{html_dir}/ia5/house/fortune.txt];
    return;
}

# Return a list of voice messages.
# This is called by phone/voicemail.shtml.
sub voicemails {
    my ( $PhoneName, $PhoneNumber, $PhoneTimeStamp, $PhoneLength, $htmlcode );
    $htmlcode = "<table width=100% cellspacing=2><tbody><font size=2>";
    $htmlcode .= "<tr bgcolor=\"#999999\">";
    $htmlcode .= "<th align=\"middle\">Time</th>";
    $htmlcode .= "<th align=\"middle\">Number</th>";
    $htmlcode .= "<th align=\"middle\">Name</th>";
    $htmlcode .= "<th align=\"middle\">Length</th></tr>";

    # Insert routine to parse data in /var/isdn/voice/

    $htmlcode .=
      "<tr vAlign=center bgColor=\"#cccccc\"><td nowrap>$PhoneTimeStamp</td><td nowrap>$PhoneNumber</td><td nowrap>$PhoneName</td><td nowrap>$PhoneLength</td></tr>";

    $htmlcode .= "</tbody></table>";
    return $htmlcode;
}

# Delete voice mails when user ask for it.
# Called from phone/voicemail.shtml.
sub clearvoicemails {
    my $htmlcode;
    $htmlcode = "Voice Messages Deleted...";

    # Insert code to delete the messages

    return $htmlcode;
}
