
#&Serial_data_add_hook(\&check_x10_data) if $Reload;

sub check_x10_data {
    my ($data) = @_;
    print "x10 data: $data\n";
}

#$x10_receiver = new Serial_Item 'X';
#print "x10 data: $state" if $state = state_now $x10_receiver;

$test_x10_rf1 = new Serial_Item 'XA1AJ';
$test_x10_rf2 = new Serial_Item 'XA1AJ';

tie_event $test_x10_rf1 'print_log "rf1 set to $state"';
tie_event $test_x10_rf2 'print_log "rf2 set to $state"';

#test_x10_rf2 -> tie_filter('get_set_by $test_x10_rf2 eq "rf"', undef, 'Ignoring x10 rf data') if $Reload;
$test_x10_rf2->tie_filter( '$set_by eq "rf"',, 'Ignoring x10 rf data' )
  if $Reload;

if ( $state = state_now $test_x10_rf1) {
    print_log "test_x10_rf1 set to $state by $test_x10_rf1->{set_by}";
}
if ( $state = state_now $test_x10_rf2) {
    my $set_by = get_set_by $test_x10_rf2;
    print_log
      "test_x10_rf2 a set to $state by $test_x10_rf2->{set_by} sb=$set_by";
    print_log "test_x10_rf2 b set to $state by $test_x10_rf2->{set_by}"
      if get_set_by $test_x10_rf2 eq "rf";
}

#$test_x10_a = new X10_Appliance 'L2';
#set $test_x10_a TOGGLE if new_second 20;
