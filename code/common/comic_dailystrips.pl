
# Category = Entertainment

#@ This module downloads selected comic strips daily and
#@ cleans out old strips weekly. They can be accessed <A HREF="/comics/">here</A>
#@ You will need to set the 'comics' parameter in your
#@ private mh.ini. For example:
#@    comics = dilbert foxtrot userfriendly doonesbury speedbump
#@ A full list of available comics is located
#@ in mh/web/comics/dailystrips/strips.def

$dailystrip_update = new Voice_Cmd '[Update,Clean] the daily comic strips';
$dailystrip_update-> set_info("Runs the dailystrip program to retrieve comics specified in mh.ini parm comics: $config_parms{comics}");
$dailystrip_update-> set_icon("goofy");

if ($state = said $dailystrip_update) {
    my $comics_dir = &html_alias('/comics');
    if ($state eq 'Update') {
        my $cmd = "mh -run dailystrips ";
        $cmd .= "--defs $config_parms{html_dir}/comics/dailystrips/strips.def ";
        $cmd .= "--local --basedir $comics_dir --save --nostale ";
#       $cmd .= "--titles MisterHouse --stripnav ";
        $cmd .= "--proxy $config_parms{proxy} " if $config_parms{proxy};
        $cmd .= $config_parms{comics};
        print_log "Running $cmd";
        run $cmd;
    }
    else {
        run "mh -run dailystrips-clean --dir $comics_dir 14";
    }
}

#run_voice_cmd 'Update the daily comic strips' if time_now '4 am';
#run_voice_cmd  'Clean the daily comic strips' if time_now '5 am';


$dailystrips_email = new Voice_Cmd 'Email daily comics';

if (said $dailystrips_email) {
    my $comics_dir = &html_alias('/comics');
    my $to = $config_parms{comics_sendto} || "";
    my $baseref = $config_parms{comics_baseref} ||
                  "$config_parms{http_server}:$config_parms{http_port}/comics/";
    print_log "Sending daily comics email to $to from $comics_dir, base $baseref";
    &net_mail_send(subject => "Daily Comics for $Date_Now",
                   to => "$to",
                   baseref => "$baseref",
                   file => "$comics_dir/index.html", mime  => 'html_inline');
#                  file => "$comics_dir/index.html", mime  => 'html');
}


# lets allow the user to control via triggers

if ($Reload and $Run_Members{'trigger_code'}) {
    eval qq(
        &trigger_set("time_now '4 am' and net_connect_check", "run_voice_cmd 'Update the daily comic strips'", 'NoExpire', 'update comics')
          unless &trigger_get('update comics');
    );
    eval qq(
        &trigger_set("time_now '5 am' and net_connect_check", "run_voice_cmd 'Clean the daily comic strips'", 'NoExpire', 'clean comics')
          unless &trigger_get('clean comics');
    );
}
