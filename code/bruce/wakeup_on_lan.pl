
# Category = MisterHouse

# These objects are created in private.mht, not distributed
# to keep the lan addresses private.

use WakeOnLan;

$wakeup_on_lan = new Voice_Cmd 'Wakeup computer [C1,C2,P1,Warp,Warp2,HP,SPC]';

if ( $state = state_now $wakeup_on_lan) {
    respond "Waking up computer $state";
    set $Computer_C1 ON    if $state eq 'C1';
    set $Computer_C2 ON    if $state eq 'C2';
    set $Computer_P1 ON    if $state eq 'P1';
    set $Computer_Warp ON  if $state eq 'Warp';
    set $Computer_Warp2 ON if $state eq 'Warp2';
    set $Computer_HP ON    if $state eq 'HP';
    set $Computer_SPC ON   if $state eq 'SPC';
}
