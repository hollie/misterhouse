
# Create a test object with some example state methods

# noloop=start
package Test_State_Item;
@Test_State_Item::ISA = ('Generic_Item');

sub setstate_random {
    my ( $self, $state ) = @_;
    &main::print_log("Setting Test_State_Item random state to $state");
}

sub setstate_repeat {
    my ( $self, $state ) = @_;
    &main::print_log("Setting Test_State_Item repeat state to $state");
}

package main;

# noloop=stop

# Create a test object
$test_set1 = new Test_State_Item;
$test_set1->set_states(qw(on off random repeat));    # To enable web control

#$test_set1  = new Generic_Item;
$test_set2 = new Generic_Item;
$test_set1->tie_event('print_log "test set1 $state"');
$test_set2->tie_event('print_log "test set2 $state"');

# Test command
$test_set1_v = new Voice_Cmd 'Test stacked states [1,2,3,4]';
$state       = said $test_set1_v;

# Test a time-stacked states
$test_set1->set('0%~5~30%~5~60%~5~100%') if $state == 1;

# Test a timed and non-timed stacked states
set $test_set1 'on~2~off;on' if $state == 2;

# Test overloaded states
set $test_set1 'on~2~random:on;repeat:on;play' if $state == 3;

# Test states with stacked object references
set $test_set1 'on~2~$test_set2;on;$test_set2;off;$xyz' if $state == 4;
