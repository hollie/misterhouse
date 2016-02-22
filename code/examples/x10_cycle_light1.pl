
=begin comment

From Scott Reston on 5/2002

here's another "light function"... i have several lights that i wanted
to be able to have cycle through various brightness levels in response
to a single voice command / palmpad keypress. you can supply the various
levels in any order - the function will always start with the brightest
state and move to the dimmest.


=cut

$v_cycle_kitchen_ceiling = new Voice_Cmd('Cycle kitchen ceiling');

if ( said $v_cycle_kitchen_ceiling) {
    &step_light( $Kitchen_Ceiling, "53%", "14%" );
}

sub step_light {
    my ($light_to_step) = shift;
    my (@step_states)   = sort numerically @_
      ; #sort list so that incoming args can be in any order - note that you'll need the 'numerically' subroutine.
    my ($light_has_been_set) =
      0;    #to keep track of whether light has been set within loop

    my $light_current_level = level $light_to_step;
    my $light_current_state = state $light_to_step;

    #print_log $light_to_step->{object_name} . " is currently at : " . $light_current_level;
    #print_log "Step states = (" . join(',',@step_states) . ").";

    if ( $light_current_state eq OFF || $light_current_level eq '' ) {
        print_log $light_to_step->{object_name}
          . " is currently OFF. Setting it to "
          . $step_states[ scalar(@step_states) - 1 ] . ".";
        set $light_to_step $step_states[ scalar(@step_states) - 1 ]
          ;    #set to last in list

    }
    else {

        for ( my $i = scalar(@step_states) - 1; $i >= 0; --$i ) {
            if ( $light_current_level > $step_states[$i] )
            {    #step through the incoming states...
                print_log "Setting "
                  . $light_to_step->{object_name} . " to "
                  . $step_states[$i];
                $light_has_been_set = 1;
                set $light_to_step $step_states[$i];
                last;    #don't loop any more if we set the light this pass
            }
        }
        if ( $light_has_been_set == 0 )
        {                #we didn't set the light when passing through the loop
            print_log "Setting "
              . $light_to_step->{object_name} . " to "
              . $step_states[ scalar(@step_states) - 1 ];
            set $light_to_step $step_states[ scalar(@step_states) - 1 ];
        }

    }

}
sub numerically { $a <=> $b; }
