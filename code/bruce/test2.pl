
#if (new_second 20) {
#   file_write "$config_parms{data_dir}/web/rss_phone.xml", &html_file(undef, '../web/bin/rss_logs.pl', 'phone', 1);
#   file_write "$config_parms{data_dir}/web/rss_speak.xml", &html_file(undef, '../web/bin/rss_logs.pl', 'speak', 1);
#   file_write "$config_parms{data_dir}/web/rss_print.xml", &html_file(undef, '../web/bin/rss_logs.pl', 'print', 1);
#}

#print_log "new minute 1" if new_minute 1;
#print_log "new minute 2" if new_minute 2;
#print_log "new minute 3" if new_minute 3;

$test_x10_n = new X10_Item 'N';

print "state=$state" if $state = state_now $test_x10_n;

#if (new_second) {
#    print "speaking 0" if &Voice_Text::is_speaking(0);
#    print "speaking 1" if &Voice_Text::is_speaking(1);
#    print "speaking 2" if &Voice_Text::is_speaking(2);
#    print "speaking 3" if &Voice_Text::is_speaking(3);
#}

#speak "card=1/2 nolog=1 $Second" if new_second 5;

# Test weeder port (bad connection on the relay board?)
#set $furnace_fan ON if new_second 15;

#set $pa_family ON  if new_second 4;
#set $pa_family OFF if new_second 10;

#$lightA1 = new X10_Item 'A1';
#$lightA5 = new X10_Item 'A5';
#$light_group = new Group $lightA1, $lightA5;

#set $light_group 60 if new_second 30;

#$xap_monitor1  = new xAP_Item;
#$xap_monitor1 -> tie_event('print_log "xap data: $state"');
#if ($state = state_now $xap_monitor1) {
#    display text => "$Time_Date: $state\n", time => 0, title => 'xAP data', width => 130, height => 50,
#      window_name => 'xAP', append => 'top', font => 'fixed' unless $state =~ /^xap-hbeat/;
#}
