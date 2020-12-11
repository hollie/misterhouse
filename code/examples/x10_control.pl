
# This is an example of how to create a Voice_Cmd
# control for all X10 items.

my $list_x10_items = join ',', &list_objects_by_type('X10_Item');
$list_x10_on  = new Voice_Cmd "X10 Turn on  [$list_x10_items]";
$list_x10_off = new Voice_Cmd "X10 Turn off [$list_x10_items]";

eval "$state->set(ON)"  if $state = state_now $list_x10_on;
eval "$state->set(OFF)" if $state = state_now $list_x10_off;

