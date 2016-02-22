
# This is an example of how to Group items together

$v_group       = new Voice_Cmd 'Set group       to [on,off]';
$v_group_item1 = new Voice_Cmd 'Set group item1 to [on,off]';
$v_group_item2 = new Voice_Cmd 'Set group item2 to [on,off]';

$group_item1 = new Generic_Item;
$group_item2 = new Generic_Item;
$group       = new Group( $group_item1, $group_item2 );

tie_event $group_item1 'print_log "Group item1 set to $state"';
tie_event $group_item2 'print_log "Group item2 set to $state"';
tie_event $group 'print_log "Group       set to $state"';

tie_items $v_group $group;
tie_items $v_group_item1 $group_item1;
tie_items $v_group_item2 $group_item2;
