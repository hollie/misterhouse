
# This code shows how to use a Generic_Item and tk button to store/test/change a state

my $alarm_states =
  "Disarmed,Disarming,Arming,Armed,Violated,Exit Delay,Entry Delay";
my @alarm_states = split ',', $alarm_states;

$alarm_status   = new Generic_Item;
$v_alarm_status = new Voice_Cmd "Set the alarm to [$alarm_states]";
$v_alarm_status->tie_items($alarm_status);

&tk_radiobutton( 'Security Status', $alarm_status, [@alarm_states] );

print_log "Alarm status changed to $state" if $state = state_now $alarm_status;

$mp3_search_text = new Generic_Item;
$mp3_search_text->tie_event('print_log "mp3 search text is now $state"');
&tk_entry( 'mp3 Search', $mp3_search_text );

$v_mp3_search_text = new Voice_Cmd 'Change mp3 search to [good,bad,ugly]';
$v_mp3_search_text->tie_items($mp3_search_text);
