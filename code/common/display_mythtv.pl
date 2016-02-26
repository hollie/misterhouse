# Category=Home_Network
#
#
# Subversion $Date:$
# Subversion $Revision:$
#
#
#@ Send OSD message to MythTV (displayed when Live TV or Recordings are being viewed.)
#@ Uses the "notify_alert_text" or "notify_cid_info" OSD container.
#@
#@ Example configuration, store in mh.private.ini
#@ ----------------------------------------------
#@ display_rooms = lounge_myth_msg => device=mythtv address=lex:6948 container=alert,
#@                 lounge_myth_cid => device=mythtv address=lex:6948 container=cid
#@
#@ Example user code:
#@      display('display_rooms=lounge_myth_msg   This actually works!!");
#@

sub display_mythtv {
    my (%args) = @_;

    my $address   = ${args}{address};
    my $container = lc ${args}{container};
    my $text      = ${args}{text};

    print_log
      "display_mythtv() address=$address, container=$container, text=$text"
      if $Debug{display_mythtv};

    my $mythtv_osd =
      new Socket_Item( undef, undef, $address, 'display_mythtv', 'udp' );
    start $mythtv_osd;

    if ( not defined $container or $container eq '' or $container eq 'cid' ) {

        # Default is CID, since this could be expected by users of display_mythosd()
        set $mythtv_osd <<EOT;
<?xml version="1.0"?>
<mythnotify version="1">
    <container name="notify_cid_info">
	<textarea name="notify_cid_line"><value>Unused</value></textarea>
	<textarea name="notify_cid_name"><value>MisterHouse</value></textarea>
	<textarea name="notify_cid_num"><value>$text</value></textarea>
	<textarea name="notify_cid_dt"><value>$Time_Now</value></textarea>
    </container>
</mythnotify>
EOT

    }
    elsif ( $container eq 'alert' ) {
        set $mythtv_osd <<EOT;
<?xml version="1.0"?>
<mythnotify version="1">
    <container name="notify_alert_text">
        <textarea name="notify_text"><value>$text</value></textarea>
    </container>
</mythnotify>
EOT

    }
    else {
        print_log
          "display_mythtv: MythTV container \'$container\' not available";
    }

    stop $mythtv_osd;
}

