if (time_now '11/6/2002 9:00 PM - 00:02') {
   speak "rooms=all $Time_Now. VCR recording will be started in 2 minutes for Southpark on channel 47";
}
if (time_now '11/6/2002 9:00 PM') {
    set $VCR '47,RECORD';
#   run('min', 'IR_cmd VCR,47,RECORD');
}
if (time_now '11/6/2002 9:30 PM') {
    set $VCR 'STOP';
#  run('min', 'IR_cmd VCR,STOP');
}
