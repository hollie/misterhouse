# Category=Test

#@ Test code hooks

# Test the Sound/Play hooks
#&Play_pre_add_hook (\&test_play_hook)  if $Reload;
#&Speak_pre_add_hook(\&test_speak_hook) if $Reload;

sub test_play_hook {
    print "play_hook parms: @_\n";
}

sub test_speak_hook {
    print "speak_hook parms: @_\n";
}

$v_test_play = new Voice_Cmd 'Test the play code hooks';
tie_event $v_test_play
  "&play(rooms => 'living', time => 5, file => 'sound_beep1.wav')";

$v_test_speak = new Voice_Cmd 'Test the speak code hooks';
tie_event $v_test_speak "&speak('rooms=all Testing speak hook')";

#$v_hook_pre_add   = new Voice_Cmd 'Add  the pre  code hook';
$v_hook_pre_drop  = new Voice_Cmd 'Drop main pre  code hook';
$v_hook_post_add  = new Voice_Cmd 'Add  main post code hook';
$v_hook_post_drop = new Voice_Cmd 'Drop main post code hook';

#&MainLoop_pre_add_hook(  \&test_hook_pre)  if said $v_hook_pre_add;
&MainLoop_pre_drop_hook( \&test_hook_pre )   if said $v_hook_pre_drop;
&MainLoop_post_add_hook( \&test_hook_post )  if said $v_hook_post_add;
&MainLoop_post_drop_hook( \&test_hook_post ) if said $v_hook_post_drop;

sub test_hook_pre  { print "<"; }
sub test_hook_post { print ">"; }

$v_hook_add  = new Voice_Cmd 'Add  main pre code hook [1,2,3]';
$v_hook_drop = new Voice_Cmd 'Drop main pre code hook [1,2,3]';

if ( $state = said $v_hook_add) {
    print_log "Adding hook $state";
    &MainLoop_pre_add_hook( \&{ "test_hook_" . $state } );
}
if ( $state = said $v_hook_drop) {
    print_log "Dropping hook $state";
    &MainLoop_pre_drop_hook( \&{ "test_hook_" . $state } );
}

sub test_hook_1 { print "-"; }
sub test_hook_2 { print "="; }
sub test_hook_3 { print "#"; }

# Echo serial matches
#&State_change_add_hook(\&state_change_log) if $Reload;

sub state_change_log {
    my ( $ref, $state ) = @_;
    my $name = substr $$ref{object_name}, 1;
    print_log "State change: $name $state";
}
