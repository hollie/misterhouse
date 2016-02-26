# Category=Home_Network
#
#@ Sends OSD message to Mythtv (is displayed when Live tv or Recordings watching is active.
#@ Mythtv_status is not used at the moment.

$Mythtv_status = new Generic_Item;

if ($Startup) {
    start $myth_osd unless ( active $myth_osd);
}

$v_mythtv_status = new Voice_Cmd("Mythtv is [live,passive]");

if ( $state = said $v_mythtv_status) {

    print_log("Mythtv status info received : $state !!! \n");
    set $Mythtv_status $state;
}

$v_myth_osd = new Voice_Cmd("Test myth OSD");

if ( $state = said $v_myth_osd) {
    &display_mythosd("This is a test notice !!");
}

$myth_osd = new Socket_Item( undef, undef, $config_parms{myth_notify_address},
    'mythtv', 'udp' );

sub display_mythosd {
    my ($text) = @_;

    start $myth_osd unless ( active $myth_osd);
    set $myth_osd <<EOT;
<?xml version="1.0"?>
<mythnotify version="1"><container name="notify_cid_info"><textarea name="notify_cid_line"><value>Unused</value></textarea><textarea name="notify_cid_name"><value>Message from MH</value></textarea><textarea name="notify_cid_num"><value>$text</value></textarea><textarea name="notify_cid_dt"><value>$Time_Now</value></textarea></container></mythnotify>
EOT

}
