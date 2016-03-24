package Clipsal_CBus::Group;

use strict;
use Clipsal_CBus;

@Clipsal_CBus::Group::ISA = ('Generic_Item', 'Clipsal_CBus');

=item C<new()>
 
 Instantiates a new CBus group object.
 
 $cbus_Guest_Bedroom_Cupboard_Light = new Generic_Item;
 $cbus_Guest_Bedroom_Cupboard_Light -> set_label('Guest Bedroom Cupboard Light');
 $cbus_Guest_Bedroom_Cupboard_Light -> set_states(split ',','on,off,5%,10%,20%,30%,40%,50%,60%,70%,80%,90%');
 
 $v_cbus_Guest_Bedroom_Cupboard_Light = new Voice_Cmd 'Guest Bedroom Cupboard Light [on,off,5%,10%,20%,30%,40%,50%,60%,70%,80%,90%]';
 $v_cbus_Guest_Bedroom_Cupboard_Light -> set_info ('Item Guest Bedroom Cupboard Light');
 tie_items $v_cbus_Guest_Bedroom_Cupboard_Light  $cbus_Guest_Bedroom_Cupboard_Light;
 tie_event $cbus_Guest_Bedroom_Cupboard_Light
 'cbus_set("//HOME/254/56/9", $state, $cbus_Guest_Bedroom_Cupboard_Light->{set_by})';
 
=cut

sub new {
    my ( $class, $address, $name, $label ) = @_;
    my $self = new Generic_Item();
    
    bless $self, $class;
    
    my $object_name = "\$". $name;
    my $object_name_v = $object_name . '_v';
    
    &::print_log ("[Clipsal CBus] New group object $object_name at $address");
    
    $self->set_states(split ',','on,off,5%,10%,20%,30%,40%,50%,60%,70%,80%,90%');
    $self->set_label($label);
    $$self{ramp_speed} = $::config_parms{cbus_ramp_speed};
    $$self{address} = $address;

    #Add this object to the CBus object hash.
    $Clipsal_CBus::Groups{$address}{object_name} = $object_name;
    $Clipsal_CBus::Groups{$address}{name} = $name;
    $Clipsal_CBus::Groups{$address}{label} = $label;
    $Clipsal_CBus::Groups{$address}{note} = "Added at object creation";
    
    eval "$object_name_v = new Voice_Cmd '$label [on,off,5%,10%,20%,30%,40%,50%,60%,70%,80%,90%]';";
    eval "$object_name_v->set_info('$label');";
    eval "tie_items $object_name_v $object_name;";
    eval "tie_event $object_name '$object_name->set(\"$address\", \$state, \$object_name->{set_by})';";
    
    return $self;
}

=item C<set(state, set_by, respond)>
 
 Places the value into the state field (e.g. set $light on) at the start of the next mh pass, and reflects that state
 to the CBus group via the CBus talker. 
 
 Depending on the source of the set() call, one or both of these actions may not be required. Scenarios are as follows:
 
 1) A CBus group is set to a new value by a CBus unit (e.g. a switch). This is seen by the CBus monitor, and the source
    of set_by is passed as "cbus".
 
 (optional) set_by overrides the defeult set_by value.
 
 (optional) respond overrides the defeult respond value.
 
=cut

sub set {
    my ( $self, $state, $set_by, $respond ) = &Generic_Item::_set_process(@_);
    &Generic_Item::set_states_for_next_pass( $self, $state, $set_by, $respond ) if $self;
    
    my $orig_state = $state;
    my $cbus_label = $self->{label};
    my $address = $$self{address};
    my $speed = $$self{ramp_speed};
    
    &::print_log ("[Clipsal CBus] set() $cbus_label set to state $state by $set_by");
    
    if ( $set_by =~ /cbus/ ) {
        
        # This was a Recursive set, we are ignoring
        &::print_log ("[Clipsal CBus] set() by CBus - no CBus update required");
        return;
    }
    
    if ( $set_by =~ /MisterHouseSync/ ) {
        
        # This was a Recursive set, we are ignoring
        &::print_log ("[Clipsal CBus] set() by MisterHouse sync - no CBus update required");
        return;
    }
    
    # Get rid of any % signs in the $Level value
    $state =~ s/%//g;
    
    if ( ( $state =~ /on/ ) || ( $state =~ /ON/ ) ) {
        $state = 255;
        
    }
    elsif ( ( $state eq /off/ ) || ( $state eq /OFF/ ) ) {
        $state = 0;
        
    }
    elsif ( ( $state <= 100 ) && ( $state >= 0 ) ) {
        $state = int( $state / 100.0 * 255.0 );
        
    }
    else {
        &::print_log ("[Clipsal CBus] unknown level \'$state\' passed to set()");
        return;
    }
    

    my $cmd_log_string = "RAMP $cbus_label set $state, speed=$speed";
    &::print_log ("[Clipsal CBus] $cmd_log_string");
    
    my $ramp_command = "[MisterHouse-$Clipsal_CBus::Command_Counter] RAMP $address $state $speed\n";
    $Clipsal_CBus::Talker->set($ramp_command);
    #$last_talk_state = "Ramp unit $addr to level $level, speed $speed";
    #$cmd_list[$cmd_counter] = $ramp_command;
    $Clipsal_CBus::Command_Counter = 0 if ( ++$Clipsal_CBus::Command_Counter > $Clipsal_CBus::Command_Counter_Max );
}


=item C<get_voice_cmds>
 
 Returns a hash of voice commands where the key is the voice command name and the
 value is the perl code to run when the voice command name is called.
 
 Higher classes which inherit this object may add to this list of voice commands by
 redefining this routine while inheriting this routine using the SUPER function.
 
 This routine is called by L<Insteon::generate_voice_commands> to generate the
 necessary voice commands.
 
=cut

sub get_voice_cmds {
    my ($self) = @_;
    my %voice_cmds = (
    
    
    
    #The Sync Links routine really resides in BaseController, maybe move this
    #ther
    'set on' => $self->get_object_name . '->cbus_set( 100 , ' . $self->get_object_name . '->{set_by})',
    'set off' => $self->get_object_name . '->cbus_set( 0 , ' . $self->get_object_name . '->{set_by})'
    );
    
    return \%voice_cmds;
}

1;
