# Category = Entertainment

#@ Says and Plays goofy remarks and sound files

$v_personal_remark_good = new Voice_Cmd("Say something nice", 'Ok');
$v_personal_remark_bad  = new Voice_Cmd("Say something mean", 'Ok');

$f_personal_remark_good = new File_Item("$config_parms{data_dir}/remarks/personal_good.txt", 'Ok');
$f_personal_remark_bad  = new File_Item("$config_parms{data_dir}/remarks/personal_bad.txt", 'Ok');

respond "app=goofy " . read_next $f_personal_remark_good
    if said $v_personal_remark_good or state_now $v_personal_remark_good;
respond "app=goofy " . read_next $f_personal_remark_bad
    if said $v_personal_remark_bad  or state_now $v_personal_remark_bad;


$v_go_away = new  Voice_Cmd("Please go away");
$v_go_away-> set_info('Tell the house to leave');
respond("I would go away if I could, but Mr. Cement footings won't let me.") if said $v_go_away;


                                # On april fools, lets do this a lot :)
$april_fools = new File_Item("$config_parms{data_dir}/remarks/april_fools.txt");
if (time_cron('1 8-22 01 04 *')) {
    print_log "Speaking a goofy remark from " . name $april_fools;
    speak("app=goofy " . read_next $april_fools);
}

                                # On other days, just one-a-day
if (time_random('* 18-22 * * 1-5', 240) or
    time_random('*  8-22 * * 0,6', 240)) {
#   logit "$config_parms{data_dir}/random_test.txt",  "$Time_Now 30";
    print_log "Speaking a goofy remark from " . name $april_fools;
    speak ("app=goofy " . read_next $april_fools);
}

$fun_wav = new Voice_Cmd 'Play a goofy sound file';
                                # One a day random wav file
if (time_random('* 18-22 * * 1-5', 240) or
    time_random('*  8-22 * * 0,6', 240) or
    said $fun_wav) {
    print_log "Playing a random wav file from fun/*.wav";
    play(app => 'goofy', volume => 20, file => "fun/*.wav");
}
