use strict;

package Generic_Item_Hash;

require Tie::Hash;
@Generic_Item_Hash::ISA = ('Tie::ExtraHash');

#@Generic_Item_Hash::ISA = ('Tie::StdHash');

sub STORE {
    my $oldValue = $_[0][0]{ $_[1] };
    $_[0][0]{ $_[1] } = $_[2];
    $_[0][1]->property_changed( $_[1], $_[2], $oldValue );
}

package Generic_Item;

use HTML::Entities;    # So we can encode characters like <>& etc

=head1 B<Generic_Item>

=head2 SYNOPSIS

     $tv_grid = new Generic_Item;
     set $tv_grid 'channel 2 from 7:00 to 8:00 on 1/24 for This Old House';
     speak "tv set to $state" if $state = state_now $tv_grid;
  
     $wakeup_time = new Generic_Item;
     speak "Your wakeup time is set for $state" 
       if $state = state_now $wakeup_time;
     speak "Time to wake up" if time_now state $wakeup_time;
  
   # Since Voice_Cmd objects inherit Generic_Items methods, we can
   # use tie_items and tie_event like this:
  
     $indoor_fountain    = new X10_Appliance('OB');
     $v_indoor_fountain  = new Voice_Cmd 'Indoor fountain [on,off]';
     $v_indoor_fountain -> tie_items($indoor_fountain);
     $v_indoor_fountain -> tie_event('speak "Ok, fountain was turned $state"');
  
     if ($state = state_now $test_button) {
        my $ref = get_set_by $test_button;
        print_log "Test button's was set to $state by $ref->{object_name}" 
          if $ref;
     }
  
                           # This shows how to set states
    $TV  = new IR_Item 'TV';
    my  $tv_states = 'power,on,off,mute,vol+,vol-,ch+,ch-';
                           # causes $tv_states to be split into array
                           # values deliminated by ,
    set_states  $TV split ',', $tv_states;
    $v_tv_control = new  Voice_Cmd("tv [$tv_states]");
  
                           # This shows how to save persistant arbitrary data
    $Test = new Generic_Item;
    $Test->{junk_data1} = $Time_Now if $Reload;
    $Test->{junk_data2} = $Month    if $Reload;
    $Test->restore_data('junk_data1', 'junk_data2');
  
                           # Here are some tie* examples
    $fountain -> tie_filter('state $windy eq ON', ON,
                            'Overriding item1 ON command because of wind');
  
    $fountain -> tie_time('10PM', OFF, 'Fountain turned off');
  
                           # Disable an item when we are away
    $item1 -> tie_filter('state $status_away eq ON');
    $item1 -> tie_event('print_log "item1 toggled to $state"');
  
                           # Ignore RF sourced (e.g. W800 or MR26) X10 data
    $light1 -> tie_filter('$set_by eq "rf"', , 'Ignoring x10 rf data');
  
                           # Disable callerid announcements when we are not
                           # at home
    $cid_announce -> tie_filter('state $mode_occupied ne "home"');
    
                           # Set an item to multiple states, with a 5 second
                           # delay between states
    $test_set1  = new Generic_Item;
    $test_set1 -> set('0%~5~30%~5~60%~5~100%') if new_second 20;
    $test_set1 -> tie_event('print_log "test set $state"');
  
    print 'Item is idle' if $test_set1 -> time_idle('4 seconds');

See C<mh/code/examples/generic_item.pl> for more examples,
C<test_tie.pl> for more examples on how to tie/untie items/events, and
C<test_idle.pl> for more examples on testing idle times.

=head2 DESCRIPTION

This is the parent object for all state-based mh objects,
and can be used by itself.

You can use this object to store and query arbitrary data.
This is more useful than 'my' variables, if you need to share data between
code files, since 'my' variables are local to a code file.
States of these items are also saved/restored when
mh is stopped/started.

=head2 INHERITS

This item inherits nothing, but
all other mh items that have states (e.g. X10_Item, Serial_Item, iButton,
Voice_Cmd, Group) inherit all Generic_Item methods.

=cut

my ( @reset_states, @states_from_previous_pass, @recently_changed );
use vars qw(@items_with_tied_times);

=head2 METHODS

=over

=item C<new()>

Instantiation method.

=cut

sub new {
    my ($class) = @_;
    my %myhash;
    my $self = \%myhash;
    tie %myhash, 'Generic_Item_Hash', $self;
    bless $self, $class;

    # Use undef ... '' will return as defined
    $$self{state}         = undef;
    $$self{said}          = undef;
    $$self{state_now}     = undef;
    $$self{state_changed} = undef;
    $self->restore_data('sort_order');
    return $self;
}

=item C<property_changed(property, new_value, old_value)>

This method is called internally whenever a property (instance variable) is changed.  It only logs the property, new_value, and old_value, but can be overridden to do more (see X10_Item).

=cut

sub property_changed {
    my ( $self, $property, $new_value, $old_value ) = @_;
    print "s=$self: property_changed: $property ='$new_value' (was"
      . " '$old_value')\n"
      if $::Debug{store};
}

=item C<set(state, set_by, respond)>

Places the value into the state field (e.g. set $light on) at the start of the next mh pass.

(optional) set_by overrides the defeult set_by value.

(optional) respond overrides the defeult respond value.

=cut

sub set {
    my ( $self, $state, $set_by, $respond ) = &_set_process(@_);
    &set_states_for_next_pass( $self, $state, $set_by, $respond ) if $self;
}

=item C<set_now(state, set_by, respond)>

Like set, except states are set when called, not on the next pass.

=cut

sub set_now {
    my ( $self, $state, $set_by, $respond ) = &_set_process(@_);
    &set_states_for_this_pass( $self, $state, $set_by, $respond ) if $self;
    push @reset_states, $self;
}

=item C<set_with_timer(state, time, return_state, additional_return_states)>

Like set, but will return to return_state after time.  

If return_state is not specified and state is 'off', it sets state to 'on' after time.  If return_state is not specified and state is missing or something other than 'off', it sets state to 'on' after time.  If return_state is 'previous', it returns to the previous state after time.

(optional) additional_return_states lets you specify one or more extra states to set after time (separate states with ';').  If set is called before the timer expires, the timer will be unset, and return_state not set..

You can also stack a series of set_with_timer calls with one set call like this:

    set('s1~t1~s2~t2...sn');

where s1, s2, ... sn are various states, and t1, t2 ... tn are the times to
wait between states.  See example below.

If you want to stack a set of states without delays, you use ; like this:

    set('on~2~random:on;repeat:on;play');

See mh/code/examples/test_states_stacked.pl for a complete example.
Note, this is turnded off by default for Serial_Item objects.

To enable, run:

    $object -> state_overload(ON);

=cut

sub set_with_timer {
    my ( $self, $state, $time, $return_state, $additional_return_states ) = @_;
    return if &main::check_for_tied_filters( $self, $state );

    # If blank state, then set the return_state only
    $self->set( $state, $self ) unless $state eq '';

    return unless $time;

    # If off, timeout to on, else timeout to off
    my $state_change;
    $state_change = ( $state eq 'off' ) ? 'on' : 'off';
    $state_change = $return_state if defined $return_state;
    $state_change = $self->{state}
      if $return_state and lc $return_state eq 'previous';

    # Handle additoinal return states if requested
    # (this is done so we don't need to parse for
    # ; seperators in this function, that work has
    # already been done in MH)
    $state_change .= ';' . $additional_return_states
      if $additional_return_states;

    # Reuse timer for this object if it exists
    $$self{timer} = &Timer::new() unless $$self{timer};
    my $object = $self->{object_name};
    my $action = "set $object '$state_change', $object"; # Set set_by to itself?
    &Timer::set( $$self{timer}, $time, $action );
}

sub _set_process {
    my ( $self, $state, $set_by, $respond ) = @_;

    print "db _set_process: s=$state sb=$set_by r=$respond\n" if $::Debug{set};

    # Check for tied or repeated states.
    return if &main::check_for_tied_filters( $self, $state, $set_by );

    # Override any set_by_timer requests
    if ( $$self{timer} ) {
        &Timer::unset( $$self{timer} );
        delete $$self{timer};
    }

    # Some devices may need to see states and substates in a case sensitive
    # manner.  This flag allows them to do so.
    $state = lc($state) unless $self->{states_casesensitive};

    if ( $state and lc($state) eq 'toggle' ) {
        my $state_current = $$self{state};

        # If states are defined, toggle will pick the next one
        if ( $$self{states} ) {
            my @s = @{ $$self{states} };
            my $i = 0;
            while ( $i < @s ) {
                last if $s[$i] eq $state_current;
                $i++;
            }
            $i++;
            $i = 0 if $i > $#s;
            $state = $s[$i];
        }
        else {
            $state = ( $state_current eq 'on' ) ? 'off' : 'on';
        }
        &main::print_log( "Toggling $self->{object_name} from $state_current "
              . "to $state" );
    }

    # Respond_Target is write-only from here (and its use for speech chimes
    # and lazy automated targeting is deprecated)

    # Handle overloaded state processing
    unless ( $self->{states_nosubstate} ) {
        my ( $primarystate, $substate ) = split( /:/, $state, 2 );
        my $setcall = 'setstate_' . lc($primarystate);
        if ( $self->can($setcall) ) {

            # Some devices may need to wait for the set to occur
            # (for example the Compool which doesn't actually change a state
            # until the device has confirmed the requested action has been
            # performed)
            return if $self->$setcall( $substate, $set_by, $respond ) == -1;
        }
        elsif ( $self->can('default_setstate') ) {
            my $test =
              $self->default_setstate( $primarystate, $substate,
                $set_by, $respond );
            return if $test and $test == -1;
        }
        elsif ( $self->can('default_setrawstate') ) {
            return
              if $self->default_setrawstate( $state, $set_by, $respond ) == -1;
        }
    }

    # Allow for default setstate methods
    else {
        if ( $self->can('default_setstate') ) {
            my $test =
              $self->default_setstate( $state, undef, $set_by, $respond );
            return if $test and $test == -1;
        }
        elsif ( $self->can('default_setrawstate') ) {
            return
              if $self->default_setrawstate( $state, $set_by, $respond ) == -1;
        }
    }

    return ( $self, $state, $set_by, $respond );

}

=item C<get_object_name()>

Returns the object name.

=cut

sub get_object_name {
    return $_[0]->{object_name};
}

=item C<set_by(set_by)>

Allows setting a description of what caused the last state change.  For example, motion, sunrise, manual, serial, etc.  Any string is allowed.  Value is returned by get_set_by below.

=cut

sub set_by {
    $_[0]->{set_by} = $_[1];
}

=item C<get_set_by()>

Returns what caused this object to change.  Standard values are web, tk, telnet, vr, xcmd, serial, xap, and xpl.

An example is in mh/code/examples/test_set_by.pl

=cut

sub get_set_by {
    return $_[0]->{set_by};
}

=item C<set_target(target)>

Sets the target instance variable to target.

=cut

sub set_target {
    $_[0]->{target} = $_[1];
}

=item C<get_target()>

Returns the current target.

=cut

sub get_target {
    return $_[0]->{target};
}

=item C<get_idle_time()>

Returns number of seconds since the last state change.

=cut

sub get_idle_time {
    return undef unless $_[0]->{set_time};
    return $main::Time - $_[0]->{set_time};
}

=item C<time_idle(time)>

Returns true when the object has had no state changes since the specified time. time can be be in seconds, minutes, hours, or days (e.g. '90 s' or '7 days').  Defaults to seconds.  Only the first of the unit word is checked and it is case-insensitive.

(optional) time can also specify a spefic state (e.g. '4 m on')

=cut

sub time_idle {
    my ( $self, $idle_spec ) = @_;
    if ( my ( $idle_time, $idle_type, $idle_state ) =
        $idle_spec =~ /^(\d+)\s*(D|H|M|S)*\w*\s*(\S*)/i )
    {
        my $state = $self->state();
        if ( $idle_state eq undef or $idle_state eq $state ) {
            my $scale = 1;
            $scale = 60           if $idle_type eq 'm';
            $scale = 60 * 60      if $idle_type eq 'h';
            $scale = 60 * 60 * 24 if $idle_type eq 'd';
            if ( ( $idle_time * $scale ) <= $self->get_idle_time() ) {
                return 1;
            }
        }
    }
    return 0;
}

=item C<restore_string()>

This is called by mh on exit to save persistant data.

=cut

sub restore_string {
    my ($self) = @_;

    my $state = $self->{state};
    $state =~ s/~/\\~/g if $state;
    my $restore_string;
    $restore_string .= $self->{object_name} . "->{state} = q~$state~;\n"
      if defined $state;
    $restore_string .= $self->{object_name} . "->{count} = q~$self->{count}~;\n"
      if $self->{count};
    $restore_string .=
      $self->{object_name} . "->{set_time} =" . " q~$self->{set_time}~;\n"
      if $self->{set_time};
    $restore_string .= $self->{object_name} . "->{states_casesensitive} = 1;\n"
      if $self->{states_casesensitive};

    if ( $self->{state_log}
        and my $state_log = join $;, @{ $self->{state_log} } )
    {
        $state_log =~ s/\n/ /g;    # Avoid new-lines on restored vars
        $state_log =~ s/~/\\~/g;

        $restore_string .= '@{'
          . $self->{object_name}
          . "->{state_log}} ="
          . " split(\$;, q~$state_log~);";
    }

    # Allow for dynamicaly/user defined save data
    for my $restore_var ( @{ $$self{restore_data} } ) {
        my $restore_value = $self->{$restore_var};
        $restore_string .=
          $self->{object_name} . "->{$restore_var} =" . " q~$restore_value~;\n"
          if defined $restore_value;
    }

    return $restore_string;
}

=item C<restore_data(vars)>

Specifies which variables should be saved/restored between mh reload/restarts.  The state var is always saved.  Can only be run at startup or reload.

=cut

sub restore_data {
    return unless $main::Reload;
    my ( $self, @restore_vars ) = @_;
    push @{ $$self{restore_data} }, @restore_vars;
}

=item C<hidden(1/0)>

If set to 1, the object will not show up on Tk or Web menus.  Can only be run at startup or reload.

=cut

sub hidden {
    my ( $self, $flag ) = @_;
    if ( defined $flag ) {
        return unless $main::Reload;
        $self->{hidden} = $flag;
    }
    else {    # Return it, but this currently only will work on $Reload.
        return $self->{hidden}
          ; # HP - really, no reason why this can't be a read-only method any time?
    }
}

=item C<set_casesensitive()>

By default, states are all lowercased, to allow for case insensitive tests.  To avoid this (for example on Serial Interfaces that are case sensitive), call this method.  Can only be run at startup or reload.

=cut

sub set_casesensitive {
    return unless $main::Reload;
    my ($self) = @_;
    $self->{states_casesensitive} = 1;
}

=item C<state()>

Returns the state (e.g. on, off).

=cut

sub state {
    my ( $self, $state ) = @_;

    $state = lc($state) unless defined $self->{states_casesensitive};

    if ($state) {
        my $getcall = 'getstate_' . lc($state);
        return $self->$getcall() if $self->can($getcall);
    }

    return $self->default_getstate($state) if $self->can('default_getstate');

    # No need to lc() the state here, we will return what was originally set.
    return $self->{state};
}

=item C<state_now()>

Returns the current state only for one pass after object state is set.  Unlike state_changed, will return the state even if the new state matches the previous one.  Otherwise, returns null.

=cut

sub state_now {
    if ( $_[0]->{target} ) {
        $main::Respond_Target = $_[0]->{target};
    }
    else {
        # This needs to be phased out
        # (who needs a global respond target?)
        $main::Respond_Target = $_[0]->{legacy_target};
    }
    return $_[0]->{state_now};
}

=item C<state_changed()>

Returns the current state only for one pass after object state is set.  Unlike state_now, will only return the state if the new state differs from the previous one.  Otherwise, returns null.

=cut

sub state_changed {
    return $_[0]->{state_changed};
}

=item C<state_final()>

Returns the state the object will be in after all queued state changes have been processed, if there is at least one state pending.  Otherwise, returns null.

=cut

sub state_final {
    my ($self) = @_;
    if ( ref $self->{state_next_pass} eq 'ARRAY' ) {
        if ( @{ $self->{state_next_pass} } ) {
            return $self->{state_next_pass}->[-1];
        }
    }
    return $self->state();
}

=item C<respond()>

This method sends a message back by whatever method was used to set this 
object.  For example, if you use voice recognition to set an object 
than the message will be emailed back to you. 

This method is almost always used by Voice_Cmd items, which inherit it.  
(maybe it should be moved there?) 

No need to pass target parameter(s) to this method! (Targeting is automatic.)
These are the targets derived from these set_by values:

    set_by    target
  
    default   none
    email     email
    im        im
    telnet    telnet
    time      none
    usercode  none
    voice     speak
    web       speak
    xap       xap
    xpl       xpl 

These are the parameters you can specify in the argument string:

    connected
    target       - override the target derived from set_by 
    important
    to
    pgm
    mode
    app
    no_chime
    force_chime
    text 

=cut

# TODO: pass hash instead of string

sub respond {
    my $object = shift;
    my $target;
    my ($text) = @_;
    my %parms  = &::parse_func_parms($text);
    my $set_by = $object->{set_by};

    my ( $to, $pgm );    # latter for IM only

    $parms{connected} = 1 if !defined( $parms{connected} );

    if ( !defined( $parms{target} ) ) {    # no target passed and we need one!
                                           # Aquire target
        $target =
          ( $object->{target} )
          ? $object->{target}
          : &main::set_by_to_target( $object->{set_by} );
    }
    else {
        $target = $parms{target};
    }

    $set_by = &main::set_by_to_target( $set_by, 1 );
    my $automation = (
            !$set_by
          or $set_by =~ /usercode/i
          or $set_by =~ /unknown/i
          or $set_by =~ /time/i
          or $set_by eq 'status'
    );

    # cancel automation (regardless) if an explicit target is set
    $automation = 0 if $parms{target} or $object->{target};

    # get user info or ip address
    if ( $set_by =~ /^im/i ) {
        my ( $im_pgm, $address ) = $set_by =~ /\[(.+?),(.+)\]/;
        $to  = $address if !$parms{to};
        $pgm = $im_pgm  if !$parms{pgm};
    }
    elsif ( $set_by =~ /^email/i ) {
        my ($address) = $set_by =~ /\[(.+)\]/;
        $to = $address if !$parms{to};
    }
    elsif ( $set_by =~ /^xap/i ) {
        my ($address) = $set_by =~ /\[(.+)\]/;
        $to = $address if !$parms{to};
    }
    elsif ( $set_by =~ /^xpl/i ) {
        my ($address) = $set_by =~ /\[(.+)\]/;
        $to = $address if !$parms{to};
    }
    elsif ( $set_by =~ /^telnet/i ) {
        my ($address) = $set_by =~ /\[(.+)\]/;
        $to = $address if !$parms{to};
    }

    # important messages are never diverted to log (even if automated)
    # ex. new mh version available
    if ( !$automation or $parms{important} ) {
        my $extra;
        if ( !$parms{connected} ) {

            # don't override these if explicitly passed
            # mute remote web responses (convert all Web to speech)
            my $mode;

            if ( $set_by =~ /^web/i ) {
                my ($address) = $set_by =~ /\[(.+)\]/;

                # *** TODO:Set room from IP if local
                $target = 'speak';
                $mode   = 'mute'
                  if ( !&main::is_local_address($address) and !$parms{mode} );
            }

            # Used to mute remote Web speech
            $extra .= "mode=$mode " if $mode;
        }

        $extra .= "target=$target " if $target;

        # include the app parm if it is passed
        $extra .= "app=$parms{app} " if $parms{app};

        # Send dicrete chime parameters if none specified (we know what
        # to do, no need to rely on global respond target.)
        if ( !$parms{no_chime} and !$parms{force_chime} ) {
            $extra .= ($automation) ? 'force_chime=1 ' : 'no_chime=1 ';
        }

        # should do subject too (all of this can be accomplished with
        # a weird target syntax too)  Better to leave the target empty
        # (as it is in 99% of responses) unless the target needs to be
        # something other than the default (which unravels set_by.)
        # Ex. tack on an email (or IM) target to an alarm response.
        $extra .= "to=$to "   if $to;     # Email/IM user
        $extra .= "pgm=$pgm " if $pgm;    # IM program (AOL,ICQ,MSN,Jabber)

        &main::respond("$extra$text");

    }
    else {
        # command run internally (by code, trigger, etc.}
        &main::respond("target=log $parms{text}");
    }
}

=item C<said()>

Same as C<state_now()>.

=cut

sub said {

    # Set (evil) global Respond_Target var, so (lazy) user code doesn't
    # have to pay attention (bad practice and should be phased out!)
    if ( $_[0]->{target} ) {
        $main::Respond_Target = $_[0]->{target};
    }
    else {
        $main::Respond_Target = $_[0]->{legacy_target};
    }

    return $_[0]->{said};
}

=item C<state_log()>

Returns the current state log.

=cut

sub state_log {
    my ($self) = @_;
    return @{ $$self{state_log} } if $$self{state_log};
}

=item C<state_overload()>

TODO

=cut

# Allow for turning off ~;: state processing
sub state_overload {
    my ( $self, $flag ) = @_;
    if ( lc $flag eq 'off' ) {
        $self->{states_nomultistate} = 1;
        $self->{states_nosubstate}   = 1;
    }
    elsif ( lc $flag eq 'on' ) {
        $self->{states_nomultistate} = 0;
        $self->{states_nosubstate}   = 0;
    }
}

=item C<set_icon(icon)>

Point to the icon member you want the web interface to use.  See the 
'Customizing the web interface' section of the documentation for specific 
details.  In short, this can be set to a file name such as 'light.gif' or to a
prefix such as 'light.'  If a prefix is used, MH will attempt to find icons that
match a combination of the prefix and the device's state. Can only be run at 
startup or reload.

=cut

sub set_icon {
    return unless $main::Reload;
    my ( $self, $icon ) = @_;

    # Set it
    if ( defined $icon ) {
        $self->{icon} = $icon;
    }
    else {    # Return it
        return $self->{icon};
    }
}

=item C<set_info(info)>

Adds additional information.  This will show up as a popup window on the web interface, when the mouse hovers over the command text.  Can only be run at startup or reload.

=cut

sub set_info {
    return unless $main::Reload;
    my ( $self, $text ) = @_;

    # Set it
    if ( defined $text ) {
        $self->{info} = $text;
    }
    else {    # Return it
        return $self->{info};
    }
}

=item C<incr_count()>

TODO

=cut

sub incr_count {
    my ($self) = @_;
    $self->{count}++;
    return;
}

=item C<reset_count()>

TODO

=cut

sub reset_count {
    my ($self) = @_;
    $self->{count} = 0;
    return;
}

=item C<set_count()>

TODO

=cut

sub set_count {
    my ( $self, $val ) = @_;

    # Set it
    if ( defined $val ) {
        $self->{count} = $val;
    }
    else {    # Return it
        return $self->{count};
    }
}

=item C<get_count()>

TODO

=cut

sub get_count {
    my ( $self, $val ) = @_;

    # Set it
    if ( defined $val ) {
        $self->{count} = $val;
    }
    else {    # Return it
        return $self->{count};
    }
}

=item C<set_label(label)>

Specify a text label, useful for creating touch screen interfaces.  Can only be run at startup or reload.

=cut

sub set_label {
    return unless $main::Reload;
    my ( $self, $label ) = @_;

    # Set it
    if ( defined $label ) {
        $self->{label} = $label;
    }
    else {    # Return it
        return $self->{label};
    }
}

=item C<set_authority(who)>

Sets authority for this object to who.  Setting who to 'anyone' bypasses password control.  Can only be run at startup or reload.

=cut

sub set_authority {
    return unless $main::Reload;
    my ( $self, $who ) = @_;
    $self->{authority} = $who;
}

=item C<get_authority()>

TODO

=cut

sub get_authority {
    return $_[0]->{authority};
}

=item C<get_type()>

Returns the class (or type, in Misterhouse terminology) of this item.

=cut

sub get_type {
    return ref $_[0];
}

=item C<set_fp_location()>

TODO

=cut

sub set_fp_location {
    my ( $self, @location ) = @_;
    @{ $$self{location} } = @location;
}

=item C<get_fp_location()>

TODO

=cut

sub get_fp_location {
    my ($self) = @_;
    if ( !defined $$self{location} ) { return }
    return @{ $$self{location} };
}

=item C<set_fp_nodes()>

TODO

=cut

sub set_fp_nodes {
    my ( $self, @nodes ) = @_;
    @{ $$self{nodes} } = @nodes;
}

=item C<get_fp_nodes()>

TODO

=cut

sub get_fp_nodes {
    my ($self) = @_;
    return @{ $$self{nodes} };
}

=item C<set_fp_icons(%icons)>

Sets the icons used by the floorplan web interface.  The %icons hash contains the 
list of icons stored in the web/graphics directory.  Each key is a state of the
object with the value being the icon filename. Can only be run at startup or reload.

=cut

sub set_fp_icons {
    return unless $main::Reload;
    my ( $self, %icons ) = @_;
    %{ $$self{fp_icons} } = %icons;
}

=item C<get_fp_icons()>

Returns the hash of icons for use by the floorplan web interface that were set 
by C<set_fp_icons>.

=cut

sub get_fp_icons {
    my ($self) = @_;
    if ( $$self{fp_icons} ) {
        return %{ $$self{fp_icons} };
    }
    else {
        return undef;
    }
}

=item C<set_fp_icons_set(name)>

Sets the icons group used by the IA7 floorplan web interface.  The name contains the 
group name of icons that can be found in /web/ia7/graphics.
Can only be run at startup or reload.

=cut

sub set_fp_icon_set {
    return unless $main::Reload;
    my ( $self, $icons ) = @_;
    $$self{fp_icon_set} = $icons;
}

=item C<get_fp_icons()>

Returns the name of the icon set used by the floorplan IA7 web interface that were set 
by C<set_fp_icon_set>.

=cut

sub get_fp_icon_set {
    my ($self) = @_;
    if ( $$self{fp_icon_set} ) {
        return $$self{fp_icon_set};
    }
    else {
        return undef;
    }
}

=item C<set_states(states)>

Sets valid states to states, which is a list or array.  Can only be run at startup or reload.  TODO

=cut

sub set_states {
    return unless $main::Reload;
    my ( $self, @states ) = @_;
    @{ $$self{states} } = @states;
}

=item C<add_states(states)>

Adds states to the list of valid states.  Can only be run at startup or reload.

=cut

sub add_states {
    return unless $main::Reload;
    my ( $self, @states ) = @_;
    push @{ $$self{states} }, @states;
}

=item C<get_states()>

Returns the list of valid states.

=cut

sub get_states {
    my ($self) = @_;
    return @{ $$self{states} } if defined $$self{states};
}

=item C<set_states_for_this_pass()>

TODO

=cut

sub set_states_for_this_pass {
    my ( $self, $state, $set_by, $target ) = @_;

    # Log states, process set_by and target
    ( $set_by, $target ) = &set_state_log( $self, $state, $set_by, $target );

    # Set state
    &reset_states2( $self, $state, $set_by, $target );
}

=item C<set_states_for_next_pass()>

TODO

=cut

sub set_states_for_next_pass {
    my ( $self, $state, $set_by, $target ) = @_;
    print "db set_states_for_next_pass: s=$state sb=$set_by t=$target\n"
      if $::Debug{set};

    # Log states, process set_by and target
    ( $set_by, $target ) = &set_state_log( $self, $state, $set_by, $target );

    # Track which objects we need to process next pass
    push @states_from_previous_pass, $self
      unless $self->{state_next_pass} and @{ $self->{state_next_pass} };

    # Store this for use on next pass
    push @{ $self->{state_next_pass} },  $state;
    push @{ $self->{setby_next_pass} },  $set_by;
    push @{ $self->{target_next_pass} }, $target;
}

=item C<set_state_log(state, set_by, target)>

When a state is set, it (along with a timestamp and who set it) are logged to the state_log array by this method.  The number of log entries kept is set by the max_state_log_entries ini parameter.

=cut

sub set_state_log {
    my ( $self, $state, $set_by, $target ) = @_;
    my $set_by_name;    # Must preserve set_by objects!

    # Used in get_idle_time
    $self->{set_time} = $main::Time;

    # If set by another object, find/use object name
    my $set_by_type = ref($set_by);
    $set_by_name = $set_by->{object_name}
      if $set_by_type and $set_by_type ne 'SCALAR';
    $set_by_name = $set_by unless $set_by_name;

    # Else set to Usercode [calling code file]
    $set_by = &main::get_calling_sub() unless $set_by;
    $set_by = $main::Set_By if !$set_by and $main::Set_By;

    # We do not want to step on target with set_by
    # If target is missing (allowed), response method figures it out
    # Deprecated $Respond_Target var changed to work the same way

    #   $target = $set_by unless defined $target;

    # Set the state_log ... log non-blank states
    # Avoid -w unintialized variable errors
    $state       = '' unless defined $state;
    $set_by_name = '' unless defined $set_by_name;
    $target      = '' unless defined $target;
    unshift(
        @{ $$self{state_log} },
        "$main::Time_Date $state set_by=$set_by_name"
          . ( ($target) ? "target=$target" : '' )
      )
      if defined($state)
      or ( ref $self ) eq 'Voice_Cmd';
    pop @{ $$self{state_log} }
      if $$self{state_log}
      and @{ $$self{state_log} } > $main::config_parms{max_state_log_entries};

    return ( $set_by, $target );
}

=item C<reset_states2()>

TODO

=cut

sub reset_states2 {
    my ( $ref, $state, $set_by, $target ) = @_;
    $ref->{state_prev}    = $ref->{state};
    $ref->{change_pass}   = $main::Loop_Count;
    $ref->{state}         = $state;
    $ref->{said}          = $state;
    $ref->{state_now}     = $state;
    $ref->{set_by}        = $set_by;
    $ref->{target}        = $target;
    $ref->{legacy_target} = &main::set_by_to_target($set_by)
      unless $ref->{target}
      ; # just for old code and will be phased out along with old respond calls (done for speed in said and state_now methods)

    if (
           ( defined $state  and !defined $ref->{state_prev} )
        or ( !defined $state and defined $ref->{state_prev} )
        or (    defined $state
            and defined $ref->{state_prev}
            and $state ne $ref->{state_prev} )
      )
    {
        $ref->{state_changed} = $state;
    }

    # This allows for an 'undo' function
    unless ( $ref->isa('Voice_Cmd') ) {
        unshift @recently_changed, $ref;
        pop @recently_changed if @recently_changed > 20;
    }

    # Set/fire tied objects/events
    #  - do it in main, so eval works ok
    &main::check_for_tied_events($ref);

    # Send out to xAP/xPL.
    # Avoid loops on mirrored mh systems by checking $set_by.
    my ( $send_xap, $send_xpl );
    $send_xap = 1 if $main::config_parms{xap_enable_items} or $$ref{xap_enable};
    $send_xap = 0 if defined $$ref{xap_enable} and $$ref{xap_enable} == 0;
    $send_xpl = 1 if $main::config_parms{xpl_enable_items} or $$ref{xpl_enable};
    $send_xpl = 0 if defined $$ref{xpl_enable} and $$ref{xpl_enable} == 0;
    if ( $send_xap and $set_by !~ /^xap/i ) {
        &xAP::send(
            'xAP',
            'mhouse.item',
            'mhouse.item' => {
                name       => $$ref{object_name},
                state      => $state,
                state_prev => $$ref{state_prev},
                set_by     => $set_by,
                mh_target  => $target
            }
        );
    }
    if ( $send_xpl and $set_by !~ /^xpl/i ) {
        &xPL::sendXpl(
            'mhouse.item',
            'stat',
            'mhouse.item' => {
                name       => $$ref{object_name},
                state      => $state,
                state_prev => $$ref{state_prev},
                set_by     => $set_by,
                mh_target  => $target
            }
        );
    }

}

=item C<xAP_enable()>

TODO.  Can only be run at startup or reload.

=cut

sub xAP_enable {
    return unless $main::Reload;
    my ( $self, $enable ) = @_;
    $self->{xap_enable} = $enable;
}

=item C<xPL_enable()>

TODO.  Can only be run at startup or reload.

=cut

sub xPL_enable {
    return unless $main::Reload;
    my ( $self, $enable ) = @_;
    $self->{xpl_enable} = $enable;
}

=item C<tie_event(code, state, log_msg)>

If the state of the generic_item changes, then code will trigger, with the lexical variables $state and $object getting set.  The code is a string that will be eval'd and the variables are available to it, but not to any subroutines called by it unless you pass them.  You can also set the state variable explicitly since you usually know the item.  The code is a string that will be eval'd.

(optional) Setting state limits this tied code to run only when the given
state is set.

(optional) Setting log_msg causes the message to be logged when 
this tied code is run.

=cut

sub tie_event {
    my ( $self, $code, $state, $log_msg ) = @_;
    $state   = 'all_states' unless defined $state;
    $log_msg = 1            unless $log_msg;
    $$self{tied_events}{$code}{$state} = $log_msg;
}

=item C<untie_event(code, state)>

Remove the tie to code.  If you don't specify a code string, all tied code is
removed.

(optional) Setting state removes the tied code previously associated with
that state.

=cut

sub untie_event {
    my ( $self, $event, $state ) = @_;
    if ($state) {
        delete $self->{tied_events}{$event}{$state};
    }
    elsif ($event) {
        delete $self->{tied_events}{$event};    # Untie all states
    }
    else {
        delete $self->{tied_events};            # Untie em all
    }
}

=item C<tie_items(item)>

If the state of the generic_item changes, then the state of $item will be set to that same state.

=cut

sub tie_items {

    #   return unless $main::Reload;
    my ( $self, $object, $state, $desiredstate, $log_msg ) = @_;
    $state        = 'all_states' unless defined $state;
    $desiredstate = $state       unless defined $desiredstate;
    $log_msg      = 1            unless $log_msg;
    return if $$self{tied_objects}{$object}{$state}{$desiredstate};
    $$self{tied_objects}{$object}{$state}{$desiredstate} =
      [ $object, $log_msg ];
}

=item C<untie_items(item, state)>

Remove the tie to item.  If you don't specify an item, all tied items are removed.

(optional) Setting state removes the tied item and state combination.

=cut

sub untie_items {
    my ( $self, $object, $state ) = @_;
    if ($state) {
        delete $self->{tied_objects}{$object}{$state};
    }
    elsif ($object) {
        delete $self->{tied_objects}{$object};    # Untie all states
    }
    else {
        delete $self->{tied_objects};             # Untie em all
    }
}

=item C<tie_filter(filter, state, log_msg)>

Use this to disable control of the item whenever filter returns true.  Variables $state and $set_by can be used in the filter test.

(optional) Setting state limits this tied filter code to run only when the given
state is set.

(optional) Setting log_msg causes the message to be logged when 
this filter is run.

=cut

sub tie_filter {
    my ( $self, $filter, $state, $log_msg ) = @_;
    $state   = 'all_states' unless defined $state;
    $log_msg = 1            unless $log_msg;
    $$self{tied_filters}{$filter}{$state} = $log_msg;
}

=item C<untie_filter(filter, state)>

Remove the tie to filter.  If you don't specify a filter, all tied filters are removed.

(optional) Setting state removes the tied filter and state combination.

=cut

sub untie_filter {
    my ( $self, $filter, $state ) = @_;
    if ($state) {
        delete $self->{tied_filters}{$filter}{$state};
    }
    elsif ($filter) {
        delete $self->{tied_filters}{$filter};    # Untie all states
    }
    else {
        delete $self->{tied_filters};             # Untie em all
    }
}

=item C<tie_time(time, state, log_msg)>

Sets item to state if the time string evaluates true.  state defaults to 'on' if undefined.  time can be in either time_cron or time_now format.

(optional) Setting log_msg causes the message to be logged when 
the time string evaluates true.

=cut

sub tie_time {
    my ( $self, $time, $state, $log_msg ) = @_;
    $state   = 'on' unless defined $state;
    $log_msg = 1    unless $log_msg;
    push @items_with_tied_times, $self unless $$self{tied_times};
    $$self{tied_times}{$time}{$state} = $log_msg;
}

=item C<untie_time(time, state)>

Remove the tie to time.  If you don't specify a time, all tied times are removed.

(optional) Setting state removes the tied time and state combination.

=cut

sub untie_time {
    my ( $self, $time, $state ) = @_;
    if ($state) {
        delete $self->{tied_times}{$time}{$state};
    }
    elsif ($time) {
        delete $self->{tied_times}{$time};    # Untie all states
    }
    else {
        delete $self->{tied_times};           # Untie em all
    }
}

=item C<set_web_style(style)>

Contols the style of we form used when displaying states of this item on a web page.  Can be 'dropdown', 'radio', or 'url'.  See mh/code/examples/test_web_styles.pl

=cut

sub set_web_style {
    my ( $self, $style ) = @_;

    my %valid_styles = map { $_ => 1 } qw( dropdown radio url );

    if ( !$valid_styles{ lc($style) } ) {
        &main::print_log( "Invalid style ($style) passed to set_web_style.  "
              . "Valid choices are: "
              . join( ", ", sort keys %valid_styles ) );
        return;
    }

    $self->{web_style} = lc($style);
}

=item C<get_web_style>

Returns the web style associated with this item.

=cut

sub get_web_style {
    my $self = shift;
    return if !exists $self->{web_style};
    return $self->{web_style};
}

=item C<user_data>

Returns the user data associated with this item.

=cut

sub user_data {
    my $self = shift;
    return \%{ $$self{user_data} };
}

=item C<debuglevel([level], [debug_group])>

Returns 1 if debug_group or this device is at least debug level 'level', otherwise returns 0.

=cut

sub debuglevel {
    my ( $object, $debug_level, $debug_group ) = @_;
    $debug_level = 1 unless $debug_level;
    my $objname;
    $objname = lc $object->get_object_name if defined $object;
    return 1 if $main::Debug{$debug_group} >= $debug_level;
    return 1 if defined $objname && $main::Debug{$objname} >= $debug_level;
    return 0;
}

=item C<sort_order($ref_list_of_member_names)>

Used to store an ordered list of object names.  The purpose of which is to be 
used to arrange the list of member objects in a specific order.

NOTE:  This routine does not verify that the objects are in fact members of this
object.

=cut

sub sort_order {
    my ( $self, $list_ref ) = @_;
    if ( defined $list_ref ) {
        $$self{sort_order} = join( ',', @{$list_ref} );
    }
    return [ split( ',', $$self{sort_order} ) ];
}

=back

=head2 PACKAGE FUNCTIONS

=over

=item C<delete_old_tied_times()>

TODO

=cut

sub delete_old_tied_times {
    undef @items_with_tied_times;
}

=item C<recently_changed()>

TODO

=cut

# You can use this for an undo function
sub recently_changed {
    return wantarray ? @recently_changed : $recently_changed[0];
}

=item C<reset_states()>

TODO

=cut

# Reset, then set, states from previous pass.  Called from bin/mh.
sub reset_states {
    my $ref;
    while ( $ref = shift @reset_states ) {
        undef $ref->{state_now};
        undef $ref->{state_changed};
        undef $ref->{said};
    }

    # Allow for multiple sets from the same pass
    #  - each will get run, one per subsequent pass
    my @items_with_more_states;
    while ( $ref = shift @states_from_previous_pass ) {
        my $state = shift @{ $ref->{state_next_pass} };
        push @reset_states, $ref;
        push @items_with_more_states, $ref if @{ $ref->{state_next_pass} };

        my $set_by = shift @{ $ref->{setby_next_pass} };

        my $target = shift @{ $ref->{target_next_pass} };

        &reset_states2( $ref, $state, $set_by, $target );
    }
    @states_from_previous_pass = @items_with_more_states;
}

#-------------------------------------------------------------------------------
#
# The following methods are used for android support
#
#-------------------------------------------------------------------------------
sub android_xml {
    my ( $self, $depth, $fields, $num_tags, $attributes ) = @_;
    my $xml_objects;

    # Determine how many tags this item has
    my $prefix = '  ' x ( $depth - 1 );
    my $log_size = 0;
    $log_size = scalar( @{ $$self{state_log} } ) if $$self{state_log};
    if ( ( $num_tags > 0 ) || ( $log_size > 0 ) ) {
        $attributes->{more} = "true";
    }

    # Insert the initial "object" tag
    my $object = "object";
    if ( exists $attributes->{object} ) {
        $object = $attributes->{object};
        delete $attributes->{object};
    }
    $xml_objects .= $self->android_xml_tag( $prefix, $object, $attributes );

    # Add tags name, state, and optional state_log
    my @f = qw( name );
    if (
        (
            ( defined $self->{states} ) && ( scalar( @{ $$self{states} } ) > 0 )
        )
        || ( defined $self->state() )
      )
    {
        push @f, qw ( state );
    }
    if ( $log_size > 0 ) {
        push @f, qw ( state_log );
    }

    $prefix = '  ' x $depth;

    foreach my $f (@f) {
        next unless $fields->{all} or $fields->{$f};

        my $method = $f;
        my $value;
        if (
            $self->can($method)
            or ( ( $method = 'get_' . $method )
                and $self->can($method) )
          )
        {
            if ( $f eq 'state_log' ) {
                my @a = $self->$method;
                $value = \@a;
            }
            else {
                $value = $self->$method;
                $value = encode_entities( $value, "\200-\377&<>" );
            }
        }
        elsif ( exists $self->{$f} ) {
            $value = $self->{$f};
            $value = encode_entities( $value, "\200-\377&<>" );
        }

        if ( $f eq "state" ) {
            my @states = ();
            push( @states, @{ $$self{states} } ) if defined $self->{states};
            my $numStates = scalar(@states);
            my $state     = $self->state();
            &::print_log(
                "android_xml: numStates: $numStates state: $state states: @states"
            ) if $::Debug{android};
            if (   ( $numStates eq 0 )
                && ( defined $state )
                && ( length($state) < 20 ) )
            {
                push( @states, $state );
            }
            $attributes->{type} = "text";
            if ( $numStates eq 2 ) {
                $attributes->{type} = "toggle";
            }
            if ( $numStates > 2 ) {
                $attributes->{type} = "spinner";
            }
            foreach (@states) {
                $_ = 'undef' unless defined $_;
                if ( $_ eq $value ) {
                    $attributes->{value} =
                      encode_entities( $value, "\200-\377&<>" );
                }
            }
            $xml_objects .= $self->android_xml_tag( $prefix, $f, $attributes );
            $prefix = "  " x ( $depth + 1 );
            foreach (@states) {
                $_     = 'undef' unless defined $_;
                $value = $_;
                $value = encode_entities( $value, "\200-\377&<>" );
                $xml_objects .=
                  $self->android_xml_tag( $prefix, "value", $attributes,
                    $value );
            }
            $prefix = '  ' x $depth;
            $xml_objects .= $prefix . "</$f>\n";
        }
        elsif ( $f eq "state_log" ) {
            $attributes->{type} = "arrayList";
            $xml_objects .= $self->android_xml_tag( $prefix, $f, $attributes );
            my @state_log = @{$value};
            $prefix = "  " x ( $depth + 1 );
            foreach (@state_log) {
                $_     = 'undef' unless defined $_;
                $value = $_;
                $value = encode_entities( $value, "\200-\377&<>" );
                $xml_objects .=
                  $self->android_xml_tag( $prefix, "value", $attributes,
                    $value );
            }
            $prefix = '  ' x $depth;
            $xml_objects .= $prefix . "</$f>\n";
        }
        elsif ( $f eq "name" ) {
            my $name = "";
            $name = $self->{object_name} if defined $self->{object_name};
            $xml_objects .=
              $self->android_xml_tag( $prefix, $f, $attributes, $name );
        }
        else {
            $value = "" unless defined $value;
            $xml_objects .=
              $self->android_xml_tag( $prefix, $f, $attributes, $value );
        }
    }
    return $xml_objects;
}

sub android_set_name {
    my ( $self, $name ) = @_;
    if ( !exists $self->{object_name} ) {
        $self->{object_name} = $name;
    }
}

sub android_xml_tag {
    my ( $self, $prefix, $tag, $attributes, $value ) = @_;
    my $xml_objects = $prefix . "<$tag";

    #&::print_log("android_xml_tag: prefix: $prefix tag: $tag value: $value") if $::Debug{android};
    foreach my $key ( keys %$attributes ) {
        my $val = $attributes->{$key};
        $xml_objects .= " " . $key . "=\"" . $attributes->{$key} . "\"";

        #&::print_log("android_xml_tag: attr:: key: $key value: $val") if $::Debug{android};
        delete $attributes->{$key};
    }
    $xml_objects .= ">";
    if ( defined $value ) {
        $xml_objects .= $value . "</$tag>\n";
    }
    else {
        $xml_objects .= "\n";
    }
    return $xml_objects;
}

=back 

=head2 INI PARAMETERS

Debug:  Include C<set> and C<store> in the comma seperated list of debug keywords
to produce debugging output from this item. 

=head2 AUTHOR

Bruce Winter

=head2 SEE ALSO

None

=head2 LICENSE

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program; if not, write to the Free Software
Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, 
MA  02110-1301, USA.

=cut

#
# $Log: Generic_Item.pm,v $
# Revision 1.42  2005/05/22 18:13:06  winter
# *** empty log message ***
#
# Revision 1.41  2004/11/22 22:57:26  winter
# *** empty log message ***
#
# Revision 1.40  2004/09/25 20:01:19  winter
# *** empty log message ***
#
# Revision 1.39  2004/07/30 23:26:38  winter
# *** empty log message ***
#
# Revision 1.38  2004/07/18 22:16:37  winter
# *** empty log message ***
#
# Revision 1.37  2004/07/05 23:36:37  winter
# *** empty log message ***
#
# Revision 1.36  2004/06/06 21:38:44  winter
# *** empty log message ***
#
# Revision 1.35  2004/05/02 22:22:17  winter
# *** empty log message ***
#
# Revision 1.34  2004/04/25 18:19:41  winter
# *** empty log message ***
#
# Revision 1.33  2004/03/23 01:58:08  winter
# *** empty log message ***
#
# Revision 1.32  2004/02/01 19:24:35  winter
#  - 2.87 release
#
# Revision 1.31  2003/12/22 00:25:05  winter
#  - 2.86 release
#
# Revision 1.30  2003/11/23 20:26:01  winter
#  - 2.84 release
#
# Revision 1.29  2003/09/02 02:48:46  winter
#  - 2.83 release
#
# Revision 1.28  2003/07/06 17:55:11  winter
#  - 2.82 release
#
# Revision 1.27  2003/04/20 21:44:07  winter
#  - 2.80 release
#
# Revision 1.26  2003/02/08 05:29:23  winter
#  - 2.78 release
#
# Revision 1.25  2003/01/12 20:39:20  winter
#  - 2.76 release
#
# Revision 1.24  2002/12/24 03:05:08  winter
# - 2.75 release
#
# Revision 1.23  2002/11/10 01:59:57  winter
# - 2.73 release
#
# Revision 1.22  2002/10/13 02:07:59  winter
#  - 2.72 release
#
# Revision 1.21  2002/09/22 01:33:23  winter
# - 2.71 release
#
# Revision 1.20  2002/08/22 04:33:20  winter
# - 2.70 release
#
# Revision 1.19  2002/05/28 13:07:51  winter
# - 2.68 release
#
# Revision 1.18  2002/03/31 18:50:38  winter
# - 2.66 release
#
# Revision 1.17  2002/03/02 02:36:51  winter
# - 2.65 release
#
# Revision 1.16  2001/12/16 21:48:41  winter
# - 2.62 release
#
# Revision 1.14  2001/05/06 21:07:26  winter
# - 2.51 release
#
# Revision 1.13  2001/04/15 16:17:21  winter
# - 2.49 release
#
# Revision 1.12  2001/02/24 23:26:40  winter
# - 2.45 release
#
# Revision 1.11  2001/02/04 20:31:31  winter
# - 2.43 release
#
# Revision 1.10  2000/10/22 16:48:29  winter
# - 2.32 release
#
# Revision 1.9  2000/10/01 23:29:40  winter
# - 2.29 release
#
# Revision 1.8  2000/09/09 21:19:11  winter
# - 2.28 release
#
# Revision 1.7  2000/08/19 01:22:36  winter
# - 2.27 release
#
# Revision 1.6  2000/06/24 22:10:54  winter
# - 2.22 release.  Changes to read_table, tk_*, tie_* functions, and hook_ code
#
# Revision 1.5  2000/02/12 06:11:37  winter
# - commit lots of changes, in preperation for mh release 2.0
#
# Revision 1.4  2000/01/27 13:39:27  winter
# - update version number
#
# Revision 1.3  1999/02/16 02:04:27  winter
# - add set method
#
# Revision 1.2  1999/01/30 19:50:51  winter
# - add state_now and reset_states loop
#
# Revision 1.1  1999/01/24 20:04:13  winter
# - created
#
#

# Debug ... will not see when using fast POSIX::_exit in bin/mh

#sub DESTROY {
#    my ($self) = @_;
#    print "Destorying object $self, name=$self->{object_name}\n";
#}
#END {
#    print "This is the end of Generic_Item\n";
#}

1;
