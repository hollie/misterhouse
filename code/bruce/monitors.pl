
# Category=Misc

# Enable X10 based indicator night lights for monitoring various things

$v_indicator_light1 = new Voice_Cmd 'Indicator Light 1 [on,off]';
$v_indicator_light2 = new Voice_Cmd 'Indicator Light 2 [on,off]';
$v_indicator_light3 = new Voice_Cmd 'Indicator Light 3 [on,off]';

tie_items $v_indicator_light1 $indicator_light1;
tie_items $v_indicator_light2 $indicator_light2;
tie_items $v_indicator_light3 $indicator_light3;

# Two ways of tracking $internet_connection
if ( $state = state_now $internet_connection) {
    print_msg "Internet is $state" if state_changed $internet_connection;
    set $indicator_light1 ( $state eq 'up' ) ? OFF : ON;
}
tie_items $internet_connection $indicator_light3, 'up',   ON;
tie_items $internet_connection $indicator_light3, 'down', OFF;

# Restart the Linksys router if the internet is down
if (    ( state $internet_connection eq 'down' )
    and ( state_now $internet_connection or new_minute 10 ) )
{
    print_log "Restarting the router (internet is down)";
    run_voice_cmd 'Reboot the router';
}

logit "$config_parms{data_dir}/logs/phone_minutes.log",
  "day=$Day used=$Save{phone_minutes_used}, left=$Save{phone_minutes_left}, days=$Save{phone_minutes_days}, left_day=$Save{phone_minutes_left_day}"
  if time_now '8:59 pm';

$v_phone_minutes_zack = new Voice_Cmd('Read Zack phone minutes');

if ( ( time_now '9 pm' and $Save{phone_minutes_left} < 300 )
    or said $v_phone_minutes_zack)
{
    my $msg = "Zack, you have $Save{phone_minutes_left} phone minutes left.";
    $msg .=
      " $Save{phone_minutes_left_day} per day for the next $Save{phone_minutes_days} days";
    speak "app=notice $msg";
    $msg = file_tail "$config_parms{data_dir}/logs/phone_minutes.log", 30;
    display
      text   => $msg,
      time   => 0,
      title  => 'Phone Minutes',
      width  => 80,
      height => 35,
      font   => 'fixed';
}
