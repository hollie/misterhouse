# Category=Other

				# Set up so we can use keys on a remote transmiter to taunt the kids
$personal_remark_good   = new Serial_Item('XACAJ', 'Zack');
$personal_remark_good  -> add            ('XADAJ', 'Nick');
$personal_remark_bad    = new Serial_Item('XACAK', 'Zack');
$personal_remark_bad   -> add            ('XADAK', 'Nick');

$v_personal_remark_good = new Voice_Cmd("Say something good to [hey,Nick,Zack,Bruce,Laurie]", 'Ok');
$v_personal_remark_bad  = new Voice_Cmd("Say something bad to [hey,Nick,Zack,Bruce,Laurie]", 'Ok');

$f_personal_remark_good = new File_Item("$config_parms{data_dir}/remarks/personal_good.txt", 'Ok');
$f_personal_remark_bad  = new File_Item("$config_parms{data_dir}/remarks/personal_bad.txt", 'Ok');

speak "rooms=all $state, " . read_next $f_personal_remark_good
    if $state = said $v_personal_remark_good or $state = state_now $personal_remark_good;
speak "rooms=all $state, " . read_next $f_personal_remark_bad
    if $state = said $v_personal_remark_bad  or $state = state_now $personal_remark_bad;


$v_go_away = new  Voice_Cmd("Please go away");
$v_go_away-> set_info('Tell the house to leave');
speak("I would go away if I could, but Mr. Cement footings won't let me.") if said $v_go_away;


                                # On april fools, lets do this a lot :)
$april_fools = new File_Item("$config_parms{data_dir}/remarks/april_fools.txt");
speak("rooms=all " . read_next $april_fools) if time_cron('1 8-22 01 04 *');

                                # On other days, just one-a-day
if (time_random('* 18-22 * * 1-5', 240) or
    time_random('*  8-22 * * 0,6', 240)) {
    logit "$config_parms{data_dir}/random_test.txt",  "$Time_Now 30";
    speak ("rooms=all " . read_next $april_fools);
}

                                # One a day random wav file
if (time_random('* 18-22 * * 1-5', 240) or
    time_random('*  8-22 * * 0,6', 240)) {
    play(rooms => 'all', file => "fun/*.wav");
}
