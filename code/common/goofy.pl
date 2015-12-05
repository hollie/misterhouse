# Category = Entertainment

#@ Says goofy remarks and plays fun sound files

$v_personal_remark_good = new Voice_Cmd("Say something nice");
$v_personal_remark_bad  = new Voice_Cmd("Say something mean");
$v_fun_wav              = new Voice_Cmd 'Play a fun sound file';

$v_go_away = new Voice_Cmd("Please go away");
$v_go_away->set_info('Tell the house to leave');

$v_why_here = new Voice_Cmd("Why are you here");
$v_why_here->set_info('Question house existence');

$v_shut_up = new Voice_Cmd("Shut up");
$v_shut_up->set_info('Tell computer to stifle');

# *** Remarks have spelling errors (and aren't particularly amusing.)

$f_personal_remark_good =
  new File_Item("$config_parms{data_dir}/remarks/personal_good.txt");
$f_personal_remark_bad =
  new File_Item("$config_parms{data_dir}/remarks/personal_bad.txt");
$f_april_fools =
  new File_Item("$config_parms{data_dir}/remarks/april_fools.txt");

# Create trigger to play the annoying South Park sounds (needs updating)

if ($Reload) {
    &trigger_set(
        "time_random('* 18-22 * * 1-5', 240) or time_random('*  8-22 * * 0,6', 240)",
        "run_voice_cmd('Play a fun sound file')",
        'NoExpire',
        'play fun sound'
    ) unless &trigger_get('play fun sound');
}

sub uninstall_goofy {
    &trigger_delete('play fun sound');
}

if ( said $v_shut_up) {
    $v_shut_up->respond("Okay, but you don't have to say it like that.");
    set $mode_mh 'mute';
}

$v_why_here->respond(
    "app=goofy Well, why are you here? Why are any of us here? I mean when you get down to it, it is all so meaningless. You know what I mean?"
) if said $v_why_here;

$v_go_away->respond("I would go away if I could.") if said $v_go_away;
$v_personal_remark_good->respond(
    "app=goofy " . read_next $f_personal_remark_good)
  if said $v_personal_remark_good;
$v_personal_remark_bad->respond(
    "app=goofy image=frown " . read_next $f_personal_remark_bad)
  if said $v_personal_remark_bad;

# One a day random wav file (triggered)
if ( said $v_fun_wav) {
    $v_fun_wav->respond("app=goofy Playing a fun sound effect.");
    play( app => 'goofy', file => "fun/*.wav" );
}

# On april fools, lets do this a lot :)
if ( time_cron('1 8-22 01 04 *') ) {
    print_log "Speaking a goofy remark from " . name $f_april_fools;
    speak( "app=goofy " . read_next $f_april_fools);
}

# On other days, just one-a-day
if (   time_random( '* 18-22 * * 1-5', 240 )
    or time_random( '*  8-22 * * 0,6', 240 ) )
{
    #   logit "$config_parms{data_dir}/random_test.txt",  "$Time_Now 30";
    print_log "Speaking a goofy remark from " . name $f_april_fools;
    speak( "app=goofy " . read_next $f_april_fools);
}
