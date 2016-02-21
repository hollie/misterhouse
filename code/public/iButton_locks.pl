# Category=Security

=begin comment

05/2005 Nigel Titley wrote:
I use the ID only buttons to operate the front door lock, via a weeder module.
I've attached my locks.pl file as an example (with the IButton ids hashed out).

=cut

my $state;

# Define the keys and create the iButton objects

my %ib_keys = (
    '010000081exxxxxx', 'nigel', '010000081exxxxxx', 'stephan',
    '010000081exxxxxx', 'tim',   '010000081exxxxxx', 'benedicte'
);

# Define the lock solenoid
$front_lock = new Serial_Item( 'AHD', 'on', 'weeder' );
add $front_lock ( 'ALD', 'off' );

# Define the lock led
$front_lock_led = new Serial_Item( 'AHE', 'on', 'weeder' );
add $front_lock_led ( 'ALE', 'off' );

# Set it up on startup (note delays to allow operation)
if ( $Startup or $Reread ) {
    select( undef, undef, undef, 0.01 );
    set $front_lock 'off';
    select( undef, undef, undef, 0.01 );
    set $front_lock_led 'off';
    select( undef, undef, undef, 0.01 );
    print_log "Set up locking system";
    speak "address=audrey Locking subsystem initialised";
}

# Voice commands
$v_front_lock     = new Voice_Cmd('Front lock [on,off]');
$v_front_lock_led = new Voice_Cmd('Front lock led [on,off]');

if ( $state = said $v_front_lock) {
    my $remark = "Front lock manually set to $state.";
    set $front_lock $state;
    print_log "$remark";
    speak "address=audrey $remark";
}

if ( $state = said $v_front_lock_led) {
    my $remark = "Front lock led manually set to $state.";
    set $front_lock_led $state;
    print_log "$remark";
    speak "address=audrey $remark";
}

if ($New_Second) {
    my $key;
    foreach $key ( iButton::scan('01') ) {
        print_log "Found key " . $key->id;
        if ( defined $ib_keys{ $key->id } ) {
            $front_lock->set_with_timer( 'on',   '3 s', 'off' );
            $front_door->set_with_timer( 'open', '3 s', 'closed' );
            print_log $ib_keys{ $key->id } . " identified.";
            print_log "Opened front door";
        }
        else {
            print_log "Attempt to use bad iButton key " . $key->id;
            print_log "Access denied";
        }
    }
}
