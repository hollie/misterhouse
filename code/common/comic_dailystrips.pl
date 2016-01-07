# Category = Entertainment
#
# $Date$
# $Revision$

#@ This module downloads selected comic strips daily and
#@ cleans out old strips weekly. They can be accessed <A HREF="/comics/">here</A>
#@ You will need to set the 'comics' parameter in your
#@ private mh.ini. For example:
#@    comics = dilbert foxtrot userfriendly doonesbury speedbump
#@ A full list of available comics is located
#@ in mh/web/comics/dailystrips/strips.def

$v_dailystrip_update = new Voice_Cmd '[Update,Clean] the daily comic strips';
$v_dailystrip_update->set_info(
    "Runs the dailystrip program to retrieve comics specified in mh.ini parm comics: $config_parms{comics}"
);

# *** We need to get the corners and FP icons, etc. out of the graphics root!
# *** set_icon short-circuits the matching logic with no recourse

#$v_dailystrip_update-> set_icon("goofy");

if ( $state = said $v_dailystrip_update) {
    my $comics_dir = &html_alias('/comics');
    if ( $state eq 'Update' ) {
        $v_dailystrip_update->respond(
            "app=comics Retrieving daily comic strips...");
        my $cmd = "${Pgm_Path}/mh -run dailystrips ";
        $cmd .= "--defs $config_parms{html_dir}/comics/dailystrips/strips.def ";
        $cmd .= "--local --basedir $comics_dir --save --nostale ";
        $cmd .= "--nospaces ";

        #       $cmd .= "--titles MisterHouse --stripnav ";
        $cmd .= "--proxy $config_parms{proxy} " if $config_parms{proxy};
        $cmd .= $config_parms{comics};
        print "Running $cmd";
        run $cmd;
    }
    else {
        $v_dailystrip_update->respond(
            "app=comics Cleaning out old comic strips...");
        run "mh -run dailystrips-clean --dir $comics_dir 14";
    }
}

$v_dailystrips_email = new Voice_Cmd 'Email daily comics';

if ( said $v_dailystrips_email) {
    $v_dailystrips_email->respond(
        "app=comics image=email Mailing daily comic strips...");
    my $comics_dir = &html_alias('/comics');
    my $to         = $config_parms{comics_sendto} || "";
    my $baseref    = $config_parms{comics_baseref}
      || "$config_parms{http_server}:$config_parms{http_port}/comics/";
    print_log "Sending daily comics email to $to from $comics_dir";
    &net_mail_send(
        subject => "Daily Comics for $Date_Now",
        to      => "$to",
        baseref => "$baseref",
        file    => "$comics_dir/index.html",
        mime    => 'html_inline'
    );
}

# lets allow the user to control via triggers

if ($Reload) {
    &trigger_set(
        "time_now '4 am' and net_connect_check",
        "run_voice_cmd 'Update the daily comic strips'",
        'NoExpire',
        'update comics'
    ) unless &trigger_get('update comics');
    &trigger_set(
        "time_now '5 am' and net_connect_check",
        "run_voice_cmd 'Clean the daily comic strips'",
        'NoExpire',
        'clean comics'
    ) unless &trigger_get('clean comics');
}
