
# This shows how to query both state and brightness level of an X10 lamp item

$test_x10a = new Voice_Cmd 'Test bright [30,80,+30,+80,-80]';
set $pedestal_light $state if $state = said $test_x10a;

if ( $state = state_now $pedestal_light) {
    my $level = level $pedestal_light;
    print_log "Pedestal is state=$state, level=$level";
}

# This will monitor bright/dim commands on a specific house code

$housecode_l = new X10_Item 'O';
print_log "House code L state=$state" if $state = state_now $housecode_l;

