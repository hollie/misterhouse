
=begin comment
This script is intended to be run on the main MH and expects that
there is an X10 proxy MH by which we are sending X10 events onto
either a CM11 (AC) or CM17 (RF). 

To allow the proxy to send an idle status, set this mh.ini parm
on your X10 proxy :

 mh_proxy_status = 1

=cut

# This item will be set here to the $interface string when it
# is busy and then set by the proxy_server to 'idle' when complete
$proxy_x10_send = new Generic_Item;

# Lists for prioritizing X10 traffic, more
# lists could be added for other devices.
my @cm11a_high;
my @cm11a_norm;
my @cm11a_low;
my @cm17a_high;
my @cm17a_norm;
my @cm17a_low;

my $cm11a_tick = 0;
my $cm17a_tick = 0;

# Queue/Prioritize the set requests
sub set_cm11a {
    my ( $device, $state, $priority ) = @_;

    if ( $priority eq 'high' ) {
        push( @cm11a_high, $device, $state, $cm11a_tick );
    }
    elsif ( $priority eq 'norm' ) {
        push( @cm11a_norm, $device, $state, $cm11a_tick );
    }
    elsif ( $priority eq 'low' ) {
        push( @cm11a_low, $device, $state, $cm11a_tick );
    }
    else {
        print
          "SET_CM11A: ERROR, BAD PRIORITY VALUE, DEVICE $device, STATE $state\n";
        return;
    }
    $cm11a_tick += 1;
}

sub set_cm17a {
    my ( $device, $state, $priority ) = @_;

    if ( $priority eq 'high' ) {
        push( @cm17a_high, $device, $state, $cm17a_tick );
    }
    elsif ( $priority eq 'norm' ) {
        push( @cm17a_norm, $device, $state, $cm17a_tick );
    }
    elsif ( $priority eq 'low' ) {
        push( @cm17a_low, $device, $state, $cm17a_tick );
    }
    else {
        print
          "SET_CM17A: ERROR, BAD PRIORITY VALUE, DEVICE $device, STATE $state\n";
        return;
    }
    $cm17a_tick += 1;
}

# This is the main 'set' routine to use for prioritizing
# could be expanded with more interfaces later...
sub x10_priority_set {
    return unless ( 3 == @_ );
    my ( $device, $state, $priority ) = @_;

    # For debugging...
    #   set $device $state;
    #   return;

    if ( $device->{interface} eq 'cm11' ) {
        &set_cm11a( $device, $state, $priority );
    }
    elsif ( $device->{interface} eq 'cm17' ) {
        &set_cm17a( $device, $state, $priority );
    }
    else {
        print "x10_priority_set: UNSUPPORTED INTERFACE=$device->{interface}\n";
    }
}

# If this set is going to a proxy then we'll flag it here,
# the proxy will set it back to 'idle' when its done.
sub do_x10_set {
    my ( $device, $state ) = @_;

    if ( $Serial_Ports{ $device->{interface} }{object} eq 'proxy' ) {
        set $proxy_x10_send $device->{interface};
    }

    set $device $state;
}

# Un-Queue the set requests according to priority, we wont try
# sending if our interface is not 'idle' (could be on a proxy).

# CM11A
if ( ( @cm11a_high + @cm11a_norm + @cm11a_low ) > 0
    and state $proxy_x10_send ne 'cm11' )
{
    my $tickcount;
    my $state;
    my $device;
    my $valid_set = 'false';

    # Loop through HIGH priority list until a valid 'set $...' is made
    while ( @cm11a_high > 0 and $valid_set eq 'false' ) {
        $device    = shift(@cm11a_high);
        $state     = shift(@cm11a_high);
        $tickcount = shift(@cm11a_high);

        # Check for lower priority sets that were queued before the above
        # higher priority set and invalidate it.
        # This shouldn't happen very often but can cause an out-of-sequence set
        # if we dont invalidate it.
        for ( my $i = 0; $i < @cm11a_norm; $i += 3 ) {
            if (    $cm11a_norm[ $i + 1 ] ne 'invalid'
                and $cm11a_norm[$i] == $device
                and $cm11a_norm[ $i + 2 ] < $tickcount )
            {
                $cm11a_norm[ $i + 1 ] = 'invalid';
                $cm11a_norm_invalid += 1;
            }
        }

        for ( my $i = 0; $i < @cm11a_low; $i += 3 ) {
            if (    $cm11a_low[ $i + 1 ] ne 'invalid'
                and $cm11a_low[$i] == $device
                and $cm11a_low[ $i + 2 ] < $tickcount )
            {
                $cm11a_low[ $i + 1 ] = 'invalid';
                $cm11a_low_invalid += 1;
            }
        }

        # Skip setting to the same state or if invalidated
        if ( $device->{state} ne $state and $state ne 'invalid' ) {
            &do_x10_set( $device, $state );
            $valid_set = 'true';
            $cm11a_actual_sets += 1;

            # See if this valid HIGH set had preempted any of the valid lower sets
            if (
                (
                        @cm11a_norm > 0
                    and $cm11a_norm[2] < $tickcount
                    and $cm11a_norm[1] ne 'invalid'
                )
                or (    @cm11a_low > 0
                    and $cm11a_low[2] < $tickcount
                    and $cm11a_low[1] ne 'invalid' )
              )
            {
                $cm11a_high_preempt += 1;
            }
        }
        else { $cm11a_discarded_sets += 1; }

        # See if this HIGH set had preempted any of the lower sets
        #      if ((@cm11a_norm > 0 and $cm11a_norm[2] < $tickcount) or
        #          (@cm11a_low > 0 and $cm11a_low[2] < $tickcount))
        #         {
        #            $cm11a_high_preempt += 1;
        #         }
    }

    # If no valid set in HIGH, loop through NORM priority list
    while ( $valid_set eq 'false' and @cm11a_norm > 0 ) {
        $device    = shift(@cm11a_norm);
        $state     = shift(@cm11a_norm);
        $tickcount = shift(@cm11a_norm);

        # Check for lower priority sets that were queued before the above
        # higher priority set and invalidate it by setting it to the same state
        # This shouldn't happen very often but can cause an out-of-sequence set
        # if we dont invalidate it.
        for ( my $i = 0; $i < @cm11a_low; $i += 3 ) {
            if (    $cm11a_low[ $i + 1 ] ne 'invalid'
                and $cm11a_low[$i] == $device
                and $cm11a_low[ $i + 2 ] < $tickcount )
            {
                $cm11a_low[ $i + 1 ] = 'invalid';
                $cm11a_low_invalid += 1;
            }
        }

        # Skip setting to the same state or if invalidated
        if ( $device->{state} ne $state and $state ne 'invalid' ) {
            &do_x10_set( $device, $state );
            $valid_set = 'true';
            $cm11a_actual_sets += 1;

            # See if this valid HIGH set had preempted the valid lower set
            if (    @cm11a_low > 0
                and $cm11a_low[2] < $tickcount
                and $cm11a_low[1] ne 'invalid' )
            {
                $cm11a_high_preempt += 1;
            }
        }
        else { $cm11a_discarded_sets += 1; }

        # See if this NORM set had preempted the lower set
        #      if (@cm11a_low > 0 and $cm11a_low[2] < $tickcount)
        #         {  $cm11a_norm_preempt += 1; }
    }

    # If no valid set in HIGH or NORM, loop through LOW priority list
    while ( $valid_set eq 'false' and @cm11a_low > 0 ) {
        $device    = shift(@cm11a_low);
        $state     = shift(@cm11a_low);
        $tickcount = shift(@cm11a_low);

        # Skip setting to the same state or if invalidated
        if ( $device->{state} ne $state and $state ne 'invalid' ) {
            &do_x10_set( $device, $state );
            $valid_set = 'true';
            $cm11a_actual_sets += 1;
        }
        else { $cm11a_discarded_sets += 1; }
    }
}

# CM17A
if ( ( @cm17a_high + @cm17a_norm + @cm17a_low ) > 0
    and state $proxy_x10_send ne 'cm17' )
{
    my $tickcount;
    my $state;
    my $device;
    my $valid_set = 'false';

    # Loop through HIGH priority list until a valid 'set $...' is made
    while ( @cm17a_high > 0 and $valid_set eq 'false' ) {
        $device    = shift(@cm17a_high);
        $state     = shift(@cm17a_high);
        $tickcount = shift(@cm17a_high);

        # Check for lower priority sets that were queued before the above
        # higher priority set and invalidate it.
        # This shouldn't happen very often but can cause an out-of-sequence set
        # if we dont invalidate it.
        for ( my $i = 0; $i < @cm17a_norm; $i += 3 ) {
            if (    $cm17a_norm[ $i + 1 ] ne 'invalid'
                and $cm17a_norm[$i] == $device
                and $cm17a_norm[ $i + 2 ] < $tickcount )
            {
                $cm17a_norm[ $i + 1 ] = 'invalid';
                $cm17a_norm_invalid += 1;
            }
        }

        for ( my $i = 0; $i < @cm17a_low; $i += 3 ) {
            if (    $cm17a_low[ $i + 1 ] ne 'invalid'
                and $cm17a_low[$i] == $device
                and $cm17a_low[ $i + 2 ] < $tickcount )
            {
                $cm17a_low[ $i + 1 ] = 'invalid';
                $cm17a_low_invalid += 1;
            }
        }

        # Skip setting to the same state or if invalidated
        if ( $device->{state} ne $state and $state ne 'invalid' ) {
            &do_x10_set( $device, $state );
            $valid_set = 'true';
            $cm17a_actual_sets += 1;

            # See if this valid HIGH set had preempted any of the valid lower sets
            if (
                (
                        @cm17a_norm > 0
                    and $cm17a_norm[2] < $tickcount
                    and $cm17a_norm[1] ne 'invalid'
                )
                or (    @cm17a_low > 0
                    and $cm17a_low[2] < $tickcount
                    and $cm17a_low[1] ne 'invalid' )
              )
            {
                $cm17a_high_preempt += 1;
            }
        }
        else { $cm17a_discarded_sets += 1; }

        # See if this HIGH set had preempted any of the lower sets
        #      if ((@cm17a_norm > 0 and $cm17a_norm[2] < $tickcount) or
        #          (@cm17a_low > 0 and $cm17a_low[2] < $tickcount))
        #         {  $cm17a_high_preempt += 1; }
    }

    # If no valid set in HIGH, loop through NORM priority list
    while ( $valid_set eq 'false' and @cm17a_norm > 0 ) {
        $device    = shift(@cm17a_norm);
        $state     = shift(@cm17a_norm);
        $tickcount = shift(@cm17a_norm);

        # Check for lower priority sets that were queued before the above
        # higher priority set and invalidate it by setting it to the same state
        # This shouldn't happen very often but can cause an out-of-sequence set
        # if we dont invalidate it.
        for ( my $i = 0; $i < @cm17a_low; $i += 3 ) {
            if (    $cm17a_low[ $i + 1 ] ne 'invalid'
                and $cm17a_low[$i] == $device
                and $cm17a_low[ $i + 2 ] < $tickcount )
            {
                $cm17a_low[ $i + 1 ] = 'invalid';
                $cm17a_low_invalid += 1;
            }
        }

        # Skip setting to the same state or if invalidated
        if ( $device->{state} ne $state and $state ne 'invalid' ) {
            &do_x10_set( $device, $state );
            $valid_set = 'true';
            $cm17a_actual_sets += 1;

            # See if this valid HIGH set had preempted the valid lower set
            if (    @cm17a_low > 0
                and $cm17a_low[2] < $tickcount
                and $cm17a_low[1] ne 'invalid' )
            {
                $cm17a_high_preempt += 1;
            }
        }
        else { $cm17a_discarded_sets += 1; }

        # See if this NORM set had preempted the lower set
        if ( @cm17a_low > 0 and $cm17a_low[2] < $tickcount ) {
            $cm17a_norm_preempt += 1;
        }
    }

    # If no valid set in HIGH or NORM, loop through LOW priority list
    while ( $valid_set eq 'false' and @cm17a_low > 0 ) {
        $device    = shift(@cm17a_low);
        $state     = shift(@cm17a_low);
        $tickcount = shift(@cm17a_low);

        # Skip setting to the same state or if invalidated
        if ( $device->{state} ne $state and $state ne 'invalid' ) {
            &do_x10_set( $device, $state );
            $valid_set = 'true';
            $cm17a_actual_sets += 1;
        }
        else { $cm17a_discarded_sets += 1; }
    }
}

# Statistics so we can see if this code is actually working :^)
my $cm11a_high_preempt   = 0;
my $cm11a_norm_preempt   = 0;
my $cm11a_norm_invalid   = 0;
my $cm11a_low_invalid    = 0;
my $cm11a_actual_sets    = 0;
my $cm11a_discarded_sets = 0;
my $cm17a_high_preempt   = 0;
my $cm17a_norm_preempt   = 0;
my $cm17a_norm_invalid   = 0;
my $cm17a_low_invalid    = 0;
my $cm17a_actual_sets    = 0;
my $cm17a_discarded_sets = 0;

# Display once an hour if debug is set to X10P and there
# are actually statistics to display.
#if ($main::config_parms{debug} eq 'X10P'and $New_Hour)
if ($New_Hour) {
    if ( ( $cm11a_actual_sets + $cm11a_discarded_sets ) > 0 ) {
        print "X10 CM11A Priority Statistics for x10_priority.pl code module\n";
        print
          "CM11A: Total actual sets = $cm11a_actual_sets, discarded sets = $cm11a_discarded_sets\n";
        print
          "CM11A: HIGH sets that preempted NORM & LOW sets = $cm11a_high_preempt\n";
        print
          "CM11A: NORM sets that preempted LOW sets = $cm11a_norm_preempt\n";
        print
          "CM11A: NORM sets Invalidated by HIGH sets = $cm11a_norm_invalid\n";
        print
          "CM11A: LOW sets Invalidated by HIGH & NORM sets = $cm11a_low_invalid\n";
    }

    if ( ( $cm17a_actual_sets + $cm17a_discarded_sets ) > 0 ) {
        print "X10 CM17A Priority Statistics for x10_priority.pl code module\n";
        print
          "CM17A: Total actual sets = $cm17a_actual_sets, discarded sets = $cm17a_discarded_sets\n";
        print
          "CM17A: HIGH sets that preempted NORM & LOW sets = $cm17a_high_preempt\n";
        print
          "CM17A: NORM sets that preempted LOW sets = $cm17a_norm_preempt\n";
        print
          "CM17A: NORM sets Invalidated by HIGH sets = $cm17a_norm_invalid\n";
        print
          "CM17A: LOW sets Invalidated by HIGH & NORM sets = $cm17a_low_invalid\n";
    }
}

# A Simple Validation Test, set $testing_state = 1 to enable
my $testing_state = 0;

if ( $testing_state == 1 ) {
    $testing_state = 0;
    &x10_priority_set( $pc_room_light, 'off', 'low' );
    &x10_priority_set( $pc_room_light, 'on',  'norm' );
    &x10_priority_set( $pc_room_light, 'off', 'norm' );
    &x10_priority_set( $pc_room_light, 'on',  'low' );
    &x10_priority_set( $pc_room_light, 'off', 'low' );
    &x10_priority_set( $pc_room_light, 'on',  'high' );
}

