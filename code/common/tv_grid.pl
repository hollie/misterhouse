# Category=Entertainment

#@ This code will download TV schedules from the Internet and
#@ optionally create events to remind you or your vcr to watch shows

# updated for XMLTV  11/11/07

# Note: This $tv_grid is a special name, used by the get_tv_grid_xmltv program.
#       Do not change it.
$tv_grid = new Generic_Item();

# This item will be set whenever someone clicks on the 'set the vcr' link on the tv web page
if ( my $data = state_now $tv_grid) {

    # http://house:8080/SET?$tv_grid?channel_2_from_7:00_to_8:00

    my ( $channel, $start, $stop, $date, $show_name ) =
      $data =~ /(\d+) from (\S+) to (\S+) on (\S+) for (.*)/;

    unless ($start) {
        my $msg = "Bad tv_grid time: $data";
        speak $msg;
        print_log $msg;
        return;
    }

    my $msg =
      "Programing vcr for $show_name.  Channel $channel from $start to $stop on $date.";
    speak $msg;
    print_log $msg;

    # Allow set $VCR only if we have $VCR defined somewhere
    # Not sure why this does not work ... eval is more sure-fired anyway
    #   my $vcr_set = ($main::{VCR}) ? 'set' : '# set';
    eval '$VCR';
    my $vcr_set = ($@) ? '# set' : 'set';
    &trigger_set(
        "time_now '$date $start - 00:02'",
        "speak qq~app=tv \$Time_Now. VCR recording will be started in 2 minutes for $show_name on channel $channel~"
    );
    &trigger_set(
        "time_now '$date $start'",
        "speak 'VCR recording started';\n"
          . "print_log qq~VCR recording on channel $channel for $show_name~;\n"
          . "$vcr_set \$VCR 'STOP,$channel,RECORD';\n"
    );
    &trigger_set(
        "time_now '$date $stop'",
        "speak 'VCR recording stopped';\n" . "$vcr_set \$VCR '$channel,STOP';"
    );

}

# This is what downloads tv data.  This needs to be forked/detatched, as it can take a while
$v_get_tv_grid_xmltv_data1 = new Voice_Cmd('[Get,reget] TV XML data for today');
$v_get_tv_grid_xmltv_data2 = new Voice_Cmd('[Get,reget] all TV XML data');
$v_get_tv_grid_xmltv_data1->set_info(
    'Updates the TV database from XMLTV data.  Get will only reget if the data is old.'
);
if (   $state = said $v_get_tv_grid_xmltv_data1
    or $state = said $v_get_tv_grid_xmltv_data2)
{
    my $days = ( said $v_get_tv_grid_xmltv_data2) ? 7 : 1;
    $state = ( $state eq 'Get' ) ? '' : "-$state";

    # Call with -db sat to use sat_* parms instead of tv_* parms
    # Use mh_run so we can find mh libs and/or compiled mh.exe/mhe
    my $label =
      ( $config_parms{tv_label} ) ? "-label $config_parms{tv_label}" : "";

    # my $pgm = "mh_run get_tv_grid_xmltv $label -preserveRaw -db tv $state -days $days";
    my $pgm =
      "mh_run get_tv_grid_xmltv -db tv -infile $config_parms{tv_xml} -days $days";

    # Allow data to be stored wherever the alias points to
    my $tvdir = &html_alias('tv');
    $pgm .= qq[ -outdir "$tvdir"] if $tvdir;

    # If we have set the net_mail_send_account, send default web page via email
    my $tv_mail      = $config_parms{tv_mail};
    my $mail_account = $config_parms{net_mail_send_account};
    my $mail_server =
      $main::config_parms{"net_mail_${mail_account}_server_send"};
    my $mail_to = $main::config_parms{"net_mail_${mail_account}_address"};
    if ( $mail_to and $mail_server and $tv_mail ) {
        if (&net_connect_check) {    # We only need to net_connect_check here
                                     # because this will work off-line
                                     # with the XML file local
            $pgm .= " -mail_to $mail_to -mail_server $mail_server ";
            $pgm .=
              " -mail_baseref $config_parms{http_server}:$config_parms{http_port} ";
        }
        else {
            speak "Sorry, you must be logged onto the net to send TV Mail";
        }
    }
    run $pgm;
    print_log "TV grid update started";
}

# Set the default page to the current time
# Check it a few minutes prior to the hour
#f (time_cron "0 $config_parms{tv_hours} * * *") {
if ( time_cron "50 * * * *" ) {
    my ( $hour, $mday ) = ( localtime( time + 600 ) )[ 2, 3 ];
    my $tvfile = sprintf "%02d_%02d.html", $mday, $hour;
    my $tvdir = "$config_parms{html_dir}/tv";
    $tvdir = &html_alias('tv') if &html_alias('tv');
    if ( -e "$tvdir/$tvfile" ) {
        print_log "Updating TV index page for with $tvfile";
        copy "$tvdir/$tvfile", "$tvdir/index.html";
    }
}
