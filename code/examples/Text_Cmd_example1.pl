
# Create a widget for inputing text commands
$Text_Input = new Generic_Item;
&tk_entry( "Text Input", $Text_Input, "tcmd1", $tcmd1 );

if ( $state = state_now $Text_Input) {
    my $set_by = get_set_by $Text_Input;
    print_log "Text_Input set_by $set_by typed $state";
    run_voice_cmd( $state, undef, $set_by );
}

# Create commands
$tcmd1 = new Text_Cmd('hi (a|b|c)');
$tcmd2 = new Text_Cmd('bye *(.*)');
$tcmd3 = new Text_Cmd('(hi.*) (bye.*)');

# Fire events if the commands match text input
$tcmd1->tie_event('print_log "tcmd1 state: $state"');
print_log "tcmd2 state=$state" if $state = state_now $tcmd2;
print_log "tcmd3 state=$state set_by=$tcmd3->{set_by}, target=$tcmd3->{target}"
  if $state = state_now $tcmd3;
