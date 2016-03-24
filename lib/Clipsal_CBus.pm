
=head1 B<Clipsal CBus>

=head2 SYNOPSIS

Clipsal_CBus.pm - support for Clipsal CBus

=head2 DESCRIPTION

This module adds support for ...

=cut

package Clipsal_CBus;

# Used solely to provide a consistent logging feature, copied from Nest.pm

use strict;

#log levels
my $warn  = 1;
my $info  = 2;
my $trace = 3;

# Set up the groups hash of hashes, a key-value hash, CBus group address is the key. Each value is a

%Clipsal_CBus::Groups = ();
%Clipsal_CBus::Units = ();
$Clipsal_CBus::Command_Counter = 0;
$Clipsal_CBus::Command_Counter_Max = 100;

$Clipsal_CBus::Talker = new Socket_Item( undef, undef, $::config_parms{cgate_talk_address} );
$Clipsal_CBus::Talker_v = new Voice_Cmd("cbus talker [Start,Stop,Status,Scan]");

$Clipsal_CBus::Monitor = new Socket_Item( undef, undef, $::config_parms{cgate_mon_address} );
$Clipsal_CBus::Monitor_v = new Voice_Cmd("cbus monitor [Start,Stop,Status]");

sub debug {
    my ( $self, $message, $level ) = @_;
    $level = 0 if $level eq '';
    my $line   = '';
    my @caller = caller(0);
    if ( $::Debug{'cbus'} >= $level || $level == 0 ) {
        $line = " at line " . $caller[2]
        if $::Debug{'cbus'} >= $trace;
        ::print_log( "[" . $caller[0] . "] " . $message . $line );
    }
}

sub generate_voice_commands {
    
    &::print_log("[Clipsal CBus] Generating Voice commands for all CBus objects");
    my $object_string;
    for my $object (&main::list_all_objects) {
        next unless ref $object;
        next
        unless $object->isa('Clipsal_CBus::Group');
        
        #get object name to use as part of variable in voice command
        my $object_name   = $object->get_object_name;
        my $object_name_v = $object_name . '_v';
        $object_string .= "use vars '${object_name}_v';\n";
        
        #Convert object name into readable voice command words
        my $command = $object->{label};
        #$command =~ s/^\$//;
        #$command =~ tr/_/ /;
        
        #my $group = ( $object->isa('Insteon_PLM') ) ? '' : $object->group;
        
        #Get list of all voice commands from the object
        my $voice_cmds = $object->get_voice_cmds();
        
        #Initialize the voice command with all of the possible device commands
        $object_string .= "$object_name_v  = new Voice_Cmd '$command ["
        . join( ",", sort keys %$voice_cmds ) . "]';\n";
        
        #Tie the proper routine to each voice command
        foreach ( keys %$voice_cmds ) {
            $object_string .=
            "$object_name_v -> tie_event('"
            . $voice_cmds->{$_}
            . "', '$_');\n\n";
        }
        
        #Add this object to the list of CBus Voice Commands on the Web Interface
        $object_string .=
        ::store_object_data( $object_name_v, 'Voice_Cmd', 'Clipsal CBus',
        'Clipsal_CBus_commands' );
    }
    
    #Evaluate the resulting object generating string
    package main;
    &::print_log ($object_string);
    eval $object_string;
    print "Error in cbus_item_commands: $@\n" if $@;
    
    package Clipsal_CBus;
}


package Clipsal_CBus::CGate;

use strict;
use Clipsal_CBus;
use Data::Dumper qw(Dumper);

@Clipsal_CBus::CGate::ISA = ('Generic_Item', 'Clipsal_CBus');

=item C<new()>
 
 Instantiates a new object.
 
=cut

sub new {
    my ( $class ) = @_;
    my $self = new Generic_Item();
    
    $$self{project} = $::config_parms{cbus_project_name};
    &::print_log ("[Clipsal CBus] Project Name: $$self{project}");
    
    $$self{session_id} = undef;
    $$self{cbus_units_config}       = undef;
    $$self{cbus_got_tree_list}      = undef;
    $$self{cbus_scanning_tree}      = undef;
    $$self{cbus_unit_list}          = undef;
    $$self{cbus_group_list}         = undef;
    $$self{cbus_scanning_cgate}     = undef;
    $$self{cbus_scan_last_addr_seen} = undef;
    $$self{network_state} = undef;
    $$self{addr_not_sync_ref} => {};
    $$self{cmd_list}  => {};
    $$self{cbus_net_list} => {};
    $$self{CBus_Sync} = new Generic_Item();
    $$self{sync_in_progress} = 0;
    $$self{DELAY_CHECK_SYNC}       = 10;
    $$self{cbus_group_idx} = undef;
    $$self{cbus_unit_idx} = undef;
    
    $$self{last_mon_state} = "un-initialised";
    $$self{last_talk_state} = "un-initialised";
    $$self{request_cgate_scan} = 0;
    
    # Set the CBus definitiions file
    $$self{cbus_mht_filename} = $::config_parms{code_dir} . "/" . $::config_parms{cbus_mht_file};
    &::print_log ("[Clipsal CBus] Generated mht file output to: $$self{cbus_mht_filename}");
    
    bless $self, $class;

    $self->monitor_start();
    $self->talker_start();
    $self->scan_cgate();
    
    # Add hooks to the main loop to check the monitor and talker sockets for data on each pass.
    &::MainLoop_pre_add_hook( sub { $self->monitor_check(); }, 'persistent' );
    &::MainLoop_pre_add_hook( sub { $self->talker_check(); }, 'persistent' );
    
    # Add hook to generate voice commnds post reload
    &::Reload_post_add_hook( \&Clipsal_CBus::generate_voice_commands, 1 );
    
    return $self;
}

=item C<scan_cgate()>
 
 Scan CGate server to update the configuration.
 
=cut

sub scan_cgate {
    my ($self) = @_;
    
    # Initiate scan of CGate data
    # The scan is controlled by code in the Talker mh main loop code
    &::print_log ("[Clipsal CBus] scan_cgate() Scanning CGate...");
    
    # Cleanup from any previous scan and initialise flags/counters
    @{ $$self{cbus_net_list} } = [];
    
    if ( defined $$self{project} ) {
        $Clipsal_CBus::Talker->set ("project load " . $$self{project});
        $Clipsal_CBus::Talker->set ("project use " . $$self{project});
        &::print_log ("[Clipsal CBus] scan_cgate() Command - project start $$self{project}");
        $Clipsal_CBus::Talker->set ("project start " . $$self{project});
    }
    
    $$self{request_cgate_scan} = 1;
    $Clipsal_CBus::Talker->set ("get cbus networks");
    
}

sub add_address_to_hash {
    my ($self, $addr, $label) = @_;
    my $name = join "_", split " ", $label;
    #my ( $addr, $name ) = @_;
    my $addr_type;
    
    if ( $addr =~ /\/p\/(\d+)/ ) {
        
        # Data is for a CBus device eg. switch, relay, dimmer
        $addr_type = 'unit';
        $addr      = $1;
    }
    else {
        # Data is for a CBus "group"
        $addr_type = 'group';
    }
    
    &::print_log ("[Clipsal CBus] add_address_to_hash() Addr $addr is $name of type $addr_type");
    
    # Store the CBus name and address in the cbus_def hash
    if ( $addr_type eq 'group' ) {
        if ( not exists $Clipsal_CBus::Groups{$addr} ) {
            &::print_log ("[Clipsal CBus] add_address_to_hash() group not defined yet, adding $addr, $name");
            
            $Clipsal_CBus::Groups{$addr}{name} = $name;
            $Clipsal_CBus::Groups{$addr}{label} = $label;
            $Clipsal_CBus::Groups{$addr}{note} = "Added by CBus scan $::Date_Now $::Time_Now";
            
            &::print_log ("[Clipsal CBus] Address: $addr");
            &::print_log ("[Clipsal CBus] Name: $Clipsal_CBus::Groups{$addr}{name}");
            &::print_log ("[Clipsal CBus] Label: $Clipsal_CBus::Groups{$addr}{label}");
            &::print_log ("[Clipsal CBus] Note: $Clipsal_CBus::Groups{$addr}{note}");
            
        }
        else {
            &::print_log ("[Clipsal CBus] add_address_to_hash() group $addr already exists");
        }
    }
    elsif ( $addr_type eq 'unit' ) {
        if ( not exists $Clipsal_CBus::Units{$addr}  ) {
            &::print_log ("[Clipsal CBus] add_address_to_hash() unit not defined yet, adding $addr, $name");
            $Clipsal_CBus::Units{$addr}  = {
                name => $name,
                note => "Added by MisterHouse $::Date_Now $::Time_Now"
            };
        }
        else {
            &::print_log ("[Clipsal CBus] add_address_to_hash() unit $addr already exists");
        }
    }
    
}

#
# Setup to sync levels of all known addresses
#
sub start_level_sync {
    my ($self) = @_;
    #return if not defined $Clipsal_CBus::Groups;
    
    &::print_log ("[Clipsal Cbus] Syncing MisterHouse to CBus (Off groups not displayed)");
    
    $$self{CBus_Sync}->set('off');
    $$self{sync_in_progress} = 1;
    %{ $$self{addr_not_sync} } = %Clipsal_CBus::Groups;
    
    $self->attempt_level_sync();
}

#
# Send commands to synchronise the Misterhouse level to CBus
#
sub attempt_level_sync {
    my ($self) = @_;
    
    my @count = keys %{ $$self{addr_not_sync} };
    &::print_log ("[Clipsal CBus] attempt_level_sync() count=" . @count) if $::Debug{cbus};
    
    if ( not %{ $$self{addr_not_sync} } ) {
        &::print_log ("[Clipsal CBus] Sync to CGate complete");
        $$self{CBus_Sync}->set('on');
        $$self{sync_in_progress} = 0;
        
    }
    else {
        &::print_log ("[Clipsal CBus] attempt_level_sync() list:@count") if $::Debug{cbus};
        
        my @addresses = keys %{ $$self{addr_not_sync} };
        foreach my $addr ( @addresses ) {
            
            # Skip if CBus scene group address
            if (   $addr =~ /\/\/.+\/\d+\/202\/\d+/
                or $addr =~ /\/\/.+\/\d+\/203\/\d+/ )
            {
                delete $$self{addr_not_sync}->{$addr};
                next;
            }
            $Clipsal_CBus::Talker->set("[MisterHouse $addr] get $addr level");
        }
        
        &::eval_with_timer('$CGATE->attempt_level_sync()', $$self{DELAY_CHECK_SYNC});
    }
}

sub cbus_update {
    my ($self, $addr, $cbus_state, $set_by) = @_;
    
    my $object_name = $Clipsal_CBus::Groups{$addr}{object_name};
    my $set_command = $object_name ."->set('$cbus_state','$set_by');";
    
    &::print_log ("[Clipsal CBus] cbus_update triggering set() for object $object_name with state $cbus_state");
    &::print_log ("[Clipsal CBus] cbus_update set() command: $set_command");
    
    package main;
    eval $set_command;
    print "Error in cbus set command: $@\n" if $@;
    package Clipsal_CBus::CGate;
}

sub write_mht_file {
    my ($self) = @_;
    
    my $count = 0;
    &::print_log ("[Clipsal CBus] Writing MHT file $$self{cbus_mht_filename}");
    
    print Dumper \%Clipsal_CBus::Groups;
    
    open( CF, ">$$self{cbus_mht_filename}" )
    or &::print_log ("[Clipsal CBus] write_mht_file() Could not open $$self{cbus_mht_filename}: $!");
    
    print CF "# Example CBus mht file auto-generated on $::Date_Now at $::Time_Now.\n";
    print CF "\n";
    print CF "# This file will be overwritten - do not edit. Instead, copy this file to \n";
    print CF "# (for example) cbus.mht and edit as required. Note the format as follows: yada.\n";
    print CF "\n";
    print CF "Format = A\n";
    print CF "\n";
    print CF "#TYPE, 					Address, 			Name, 	GroupList, 		Other\n";
    print CF "\n";
    print CF "CBUS_CGATE,   CGATE\n";
    print CF "\n";
    print CF "# CBus group addresses.\n";
    print CF "\n";
    
    foreach my $address ( sort keys %Clipsal_CBus::Groups ) {
        my $name = $Clipsal_CBus::Groups{$address}{name};
        my $label = $Clipsal_CBus::Groups{$address}{label};
        
        print CF "CBUS_GROUP, $address, $name, All_CBus, $label\n";

    }
    
    print Dumper \%Clipsal_CBus::Units;
    
    print CF "\n";
    print CF "# CBus Unit addresses.\n";
    print CF "\n";
    
    foreach my $address ( sort keys %Clipsal_CBus::Units ) {
        my $name = $Clipsal_CBus::Units{$address}{name};
        my $label = $Clipsal_CBus::Units{$address}{label};
        
        print CF "CBUS_UNIT, $address, $name, $label\n";
        
    }
    
    print CF "#\n#\n# EOF\n#\n#\n";
    
    close(CF)
    or &::print_log ("[Clipsal CBus] write_mht_file() Could not close $$self{cbus_mht_filename}: $!");
    
    &::print_log ("[Clipsal CBus] write_mht_file() Completed CBus build to $$self{cbus_mht_filename}");

    
}


##############################################################################
##############################################################################
##############################################################################
##############################################################################
###########                                                     ##############
###########        CBus MONITOR                                 ##############
###########                                                     ##############
##############################################################################
##############################################################################
##############################################################################
##############################################################################

# Monitor functions
#
sub monitor_start {
    my ($self) = @_;
    
    # Start the CBus listener (monitor)
    
    if ($Clipsal_CBus::Monitor->active() ) {
        &::print_log ("[Clipsal CBus] Monitor already running, skipping start");
    }
    else {
        $$self{monitor_retry} = 0;
        if ( $Clipsal_CBus::Monitor->start() ) {
            &::print_log ("[Clipsal CBus] Monitor started");
        }
        else {
            speak("C-Bus Monitor failed to start");
            &::print_log ("[Clipsal CBus] Monitor failed to start");
        }
    }
}

sub monitor_stop {
    my ($self) = @_;
    
    # Stop the CBus listener (monitor)
    
    return if not $$self{monitor}->active();
    &::print_log ("[Clipsal CBus] Monitor stopping");
    $Clipsal_CBus::Monitor->stop();
}

sub monitor_status {
    my ($self) = @_;
    
    # Return the status of the CBus listener (monitor)
    
    if ( $$self{monitor}->active() ) {
        &::print_log ("[Clipsal CBus] Monitor is active. Last event: $$self{last_mon_state}");
        speak("C-Bus Monitor is active. Last event was $$self{last_mon_state}");
    }
    else {
        &::print_log ("[Clipsal CBus] Monitor is NOT running");
        speak("C-Bus Monitor is not running");
    }
}

sub monitor_check {
    my ($self) = @_;
    
    # Monitor Voice Command / Menu processing
    if ( my $data = $Clipsal_CBus::Monitor_v->said() ) {
        if ( $data eq 'Start' ) {
            $Clipsal_CBus::Monitor->start();
            
        }
        elsif ( $data eq 'Stop' ) {
            $Clipsal_CBus::Monitor->stop();
            
        }
        elsif ( $data eq 'Status' ) {
            $Clipsal_CBus::Monitor->status();

        }
        else {
            &::print_log ("[Clipsal CBus] Monitor: command $data is not implemented");
        }
    }
    
    #Process monitor socket input
    if ( my $monitor_msg = $Clipsal_CBus::Monitor->said() ) {
        &::print_log ("[Clipsal CBus] Monitor message: $monitor_msg");

        my @cg = split / /, $monitor_msg;
        my $cg_code = $cg[1];
        my $state_speak;
        
        unless ( $cg_code == 730 ) {    # only code 730 are of interest
            &::print_log ("[Clipsal CBus] Monitor ignoring uninteresting message type $cg_code");
            return;
        }

        my $cg_time      = $cg[0];
        my $cg_addr      = $cg[2];
        my $cg_action    = $cg[4];
        my $cg_level     = $cg[5];
        my $cg_source    = $cg[6];
        my $cg_ramptime  = $cg[7];
        my $cg_sessionId = $cg[8];
        my $cg_commandId = $cg[9];
        
        my $level = abs( substr( $cg_level, 6, 3 ) );
        my $source = substr( $cg_source, 11 );
        my $cbus_state = 0;
        
        &::print_log ("[Clipsal CBus] Monitor processing message type $cg_code");
        
        # Determine SOURCE of the command
        my $could_be_ramp_starting = 1;
        
        
        if ( $cg_sessionId =~ /$$self{session_id}/ ) {
            # Monitor message includes the current Misterhouse CBus session ID, so the message is
            # a response to a talker message sent by misterhouse.
            $source = "MisterHouse via Session ID";
        }
        elsif ( $cg_commandId =~ /commandId=(.+)/ ) {
            
            # If commandId is present then CGate sent the command
            # Monitor message includes a command ID, so CGate sent the command.
            my $command_id = $1;
            
            # CGate doesn't send a "ramp starting" message
            $could_be_ramp_starting = 0;
            
            if ( $command_id =~ /^\d+/ ) {
                
                # Assume that Toolkit is the only software that uses only a count
                # for it's command IDs. Would have been helpful if Clipsal
                # had put a label specifying Toolkit as well....
                $source = "ToolKit";
            }
            elsif ( $command_id =~ /MisterHouse/ ) {
                $source = "MisterHouse via Command ID";
            }
            else {
                # If other software issues CGATE commands using the [] label,
                #  ie.      [DudHomeControl] on //HOME/254/56/1
                # then the source in MH will be shown as "DudHomeControl".
                $source = $command_id;
                
                # Otherwise, MH will just show that CGate was used.
                $source = "CGate" if $source eq '{none}';
            }
        }
        else {
            # the source was a CBus unit.
            $source = "unit: $Clipsal_CBus::Units{$source}{name}";
        }
        
        &::print_log ("[Clipsal CBus] Monitor source is $source");
        
        # Determine what level is being reported
        my $ramping;
        $cg_ramptime =~ s/ramptime=//i;
        
        ### if ($could_be_ramp_starting and $cg_ramptime > 0) {
        if ( $cg_ramptime > 0 ) {
            &::print_log ("[Clipsal CBus] Monitor ramptime $cg_ramptime detected");
            # The group has started ramping
            if ( $level == 255 ) {
                $ramping     = 'UP';
                $state_speak = 'ramping UP';
            }
            else {
                $ramping     = 'DOWN';
                $state_speak = 'ramping DOWN';
            }
            
        }
        else {
            if ( $level == 255 ) {
                $cbus_state  = 'on';
                $state_speak = 'set to ON';
                
            }
            elsif ( $level == 0 ) {
                $cbus_state  = 'off';
                $state_speak = 'set to OFF';
                
            }
            else {
                my $plevel = $level / 255 * 100;
                $cbus_state  = sprintf( "%.0f%%",        $plevel );
                $state_speak = sprintf( "dim to %.0f%%", $plevel );
            }
            &::print_log ("[Clipsal CBus] Monitor not ramping - level set to $cbus_state");
        }
        
        my $cbus_label = $Clipsal_CBus::Groups{$cg_addr}{label};
        my $speak_name = "dummy speak name";    #$$self{cbus_def}->{group}{$cg_addr}{speak_name};
        my $announce   = "dummy announce";      #$$self{cbus_def}->{group}{$cg_addr}{announce};
        
        #$cbus_label = $$self{cbus_def}->{group}{$cg_addr}{name} if not defined $cbus_label;
        #$speak_name = $$self{cbus_def}->{group}{$cg_addr}{name} if not defined $speak_name;
        $announce = 0 if not defined $announce;
        
        $$self{last_mon_state} = "$speak_name $state_speak";
        
        #if ( ( state $v_cbus_speak eq ON ) && ($announce) ) {
        #    speak($last_mon_state);
        #}
        
        if ( $source eq 'MisterHouse via Session ID') {
            
            # This is a Reflected mesg, we will ignore
            &::print_log ("[Clipsal CBus] Monitor ignoring reflected message from $source");
        }
        elsif ( $source eq 'MisterHouse via Command ID') {
            
            # This is a Reflected mesg, we will ignore
            &::print_log ("[Clipsal CBus] Monitor ignoring reflected message from $source");
        }
        elsif ( not defined $cbus_label ) {
            &::print_log ("[Clipsal CBus] Monitor UNKNOWN Address $cg_addr $state_speak by $source");
            
        }
        else {
            # The source is a CBus unit, CGate, Toolkit, or some other software. Trigger an object set().
            &::print_log ("[Clipsal CBus] Monitor $cbus_label ramping $ramping by $source") if ($ramping);
            
            $self->cbus_update($cg_addr, $cbus_state, 'cbus');
            
            #cbus_update( $cg_addr, $cbus_state, 'cbus' );
            
            #if ( $cbus_def->{group}{$cg_addr}{type} eq 'oneshot' ) {
            #    if ( $config_parms{cbus_log_oneshot} ) {
            #        ### FIXME RichardM to test
            #        # Device is a one-shot and logging is on
            #        print_log "CBus: ONESHOT device $cbus_label "
            #        . "set $state_speak by $source";
            #    }
                
            #}
            #else {
            #    &::print_log ("CBus: $cbus_label $state_speak by \"$source\"");
            #}
        }
    }
    
}



##############################################################################
##############################################################################
##############################################################################
##############################################################################
###########                                                     ##############
###########        CBus TALKER                                  ##############
###########                                                     ##############
##############################################################################
##############################################################################
##############################################################################
##############################################################################

#
# Talker functions
#
sub talker_start {
    my ($self) = @_;
    
    # Starts the CBus command driver (Talker)
    
    if ( $Clipsal_CBus::Talker->active() ) {
        &::print_log ("[Clipsal CBus] Talker already running, skipping start");
        &::speak("C-Bus talker is already running");
        
    }
    else {
        #set $Clipsal_CBus_CGate::CBus_Sync = "OFF";
        $$self{talker_retry} = 0;
        if ( $Clipsal_CBus::Talker->start() ) {
            &::print_log ("[Clipsal CBus] Talker started");
        }
        else {
            &::speak("C-Bus Talker failed to start");
            &::print_log ("[Clipsal CBus] Talker failed to start");
        }
    }
}

sub talker_stop {
    my ($self) = @_;
    
    # Stops the CBus command driver (Talker)
    
    #set $Clipsal_CBus_CGate::CBus_Sync OFF;
    return if not $$self{talker}->active();
    &::print_log ("[Clipsal CBus] Talker stopping");
    $Clipsal_CBus::Talker->stop();
}

sub talker_status {
    my ($self) = @_;
    
    # Returns the status of the CBus command driver (Talker)
    
    if ( $Clipsal_CBus::Talker->active() ) {
        &::print_log ("[Clipsal CBus] Talker is active.");
        &::print_log ("[Clipsal CBus] Last command sent was: $$self{last_talk_state}");
        &::speak(  "C-Bus Talker is active. "
        . "Last command sent was $$self{last_talk_state}" );
    }
    else {
        &::print_log ("[Clipsal CBus] Talker is not running");
        &::speak("C-Bus Talker is not running");
    }
}

sub talker_check {
    my ($self) = @_;
    
    # Talker Voice Command / Menu processing
    if ( my $data = $Clipsal_CBus::Talker_v->said() ) {
        if ( $data eq 'Start' ) {
            $Clipsal_CBus::Talker->start();
            
        }
        elsif ( $data eq 'Stop' ) {
            $Clipsal_CBus::Talker->stop();
            
        }
        elsif ( $data eq 'Status' ) {
            $Clipsal_CBus::Talker->status();
            
        }
        elsif ( $data eq 'Scan' ) {
            $self->scan_cgate();
            
        }
        else {
            &::print_log ("[Clipsal CBus] Talker: command $data is not implemented");
        }
    }
    
    # Process data returned from CBus server after a command is sent
    #
    if ( my $talker_msg = $Clipsal_CBus::Talker->said() ) {
        my $msg_code = -1;
        my $msg_id;
        
        if ( $talker_msg =~ /(\[.+\]\s+)?(\d\d\d)/ ) {
            $msg_id   = $1;
            $msg_code = $2;
        }
        
        &::print_log ("[Clipsal CBus] Talker message: $talker_msg");
        
        ###### Message code 320: Tree information. Returned from the tree command.
        
        if ( $msg_code == 320 ) {
            if ( not $$self{cbus_got_tree_list} ) {
                if ( not $$self{cbus_units_config} ) {
                    if ( $talker_msg =~ /Applications/ ) {
                        $$self{cbus_units_config} = 1;
                    }
                    elsif ( $talker_msg =~ /(\/\/.+\/\d+\/p\/\d+).+type=(.+) app/ ) {
                        
                        # CGate is listing CBus "devices" (input and output)
                        &::print_log ("[Clipsal CBus] Talker scanned addr=$1 is type $2");
                        
                        # Store unit on a list for later scanning of details
                        push ( @{ $$self{cbus_unit_list}}, $1);
                        
                    }
                    
                }
                else {
                    # CGate is listing CBus "groups"
                    if ( $talker_msg =~ /end/ ) {
                        &::print_log ("[Clipsal CBus] Talker end of CBus scan data, got tree list") if $::Debug{cbus};
                        $$self{cbus_got_tree_list} = 1;
                    }
                    elsif ( $talker_msg =~ /(\/\/.+\/\d+\/\d+\/\d+).+level=(\d+)/ ) {
                        &::print_log ("[Clipsal CBus] Talker scanned group=$1 at level $2");
                        
                        # Store group on a list for later scanning of details
                        push ( @{ $$self{cbus_group_list}}, $1);
                    }
                }
            }
            
            ###### Message code 342: DBGet response (not documented in CGate Server Guide 1.0.)
            
        }
        elsif ( $msg_code == 342 ) {
            if ($$self{cbus_scanning_cgate}) {
                
                &::print_log ("[Clipsal CBus] Talker message 342 response data: $talker_msg") if $::Debug{cbus};
                
                if ( $talker_msg =~ /\d+\s+(\d+\/[a-z\d]+\/\d+)\/TagName=(.+)/ ) {
                    
                    #response matched against "new" format, i.e. network/app/group
                    my ( $addr, $name ) = ( $1, $2 );
                    $addr = "//$$self{project}/$addr";
                    
                    $$self{cbus_scan_last_addr_seen} = $addr;
                    
                    # $name =~ s/ /_/g;  Change spaces, depends on user usage...
                    $self->add_address_to_hash( $addr, $name );
                    
                }
                elsif ( $talker_msg =~ /(\/\/.+\/\d+\/[a-z\d]+\/\d+)\/TagName=(.+)/ )
                {
                    #response matched against "old" format, i.e. //project/network/app/group
                    my ( $addr, $name ) = ( $1, $2 );
                    
                    $$self{cbus_scan_last_addr_seen} = $addr;
                    
                    # $name =~ s/ /_/g;  Change spaces, depends on user usage...
                    $self->add_address_to_hash( $addr, $name );
                    
                }
                &::print_log ("[Clipsal CBus] Talker end message") if $::Debug{cbus};
            }
            
            ###### Message code 300: Object information, for example: 300 1/56/1: level=200
            
        }
        elsif ( $msg_code == 300 ) {
            
            if ( $talker_msg =~ /(sessionID=.+)/ ) {
                $$self{session_id} = $1;    # Set global session ID
                &::print_log ("[Clipsal CBus] Talker Session ID is \"$$self{session_id}\"");
                
            }
            elsif ( $talker_msg =~ /networks=(.+)/ ) {
                my $netlist = $1;
                &::print_log ("[Clipsal CBus] Talker network list: $netlist");
                @{$self->{cbus_net_list}} = split /,/, $netlist;
                
                # Request state of network
                &::print_log ("[Clipsal CBus] Talker sent: get " . $self->{cbus_net_list}[0] . " state");
                $Clipsal_CBus::Talker->set ("get " . $self->{cbus_net_list}[0] . " state");
                
            }
            elsif ( $talker_msg =~ /state=(.+)/ ) {
                my $network_state = $1;
                &::print_log ("[Clipsal CBus] Talker CGate Status - $talker_msg");
                if ( $network_state ne "ok" ) {
                    $Clipsal_CBus::Talker->set ("get " . $self->{cbus_net_list}[0] . " state");
                }
                else {
                    if ($$self{request_cgate_scan}) {
                        # This state request was part of scanning startup
                        &::print_log ("[Clipsal CBus] This state request was part of scanning startup");

                        $$self{cbus_scanning_cgate} = 1;    # Set scanning flag
                        $$self{request_cgate_scan}  = 0;
                    }
                    else {
                        # If not a scan, then is a startup sync being kicked off
                        &::print_log ("[Clipsal CBus] Not a scan... starting level sync");
                        $self->start_level_sync();
                    }
                }
                
            }
            elsif ( $talker_msg =~ /(\/\/[\w|\d]+\/\d+\/\d+\/\d+):\s+level=(.+)/ ) {
                my ( $addr, $level ) = ( $1, $2 );
                
                my $cbus_state;
                if ( $level == 255 ) {
                    $cbus_state = 'on';
                }
                elsif ( $level == 0 ) {
                    $cbus_state = 'off';
                }
                else {
                    my $plevel = $level / 255 * 100;
                    $cbus_state = sprintf( "%.0f%%", $plevel );
                }
                
                # Store new level from sync response
                $self->cbus_update( $addr, $cbus_state, "MisterHouseSync" );
                
                delete $self->{addr_not_sync}>{$addr};    # Remove from not sync'ed list
                my $name = $Clipsal_CBus::Groups{$addr}{name};
                &::print_log ("[Clipsal CBus] Talker $name is $cbus_state") if $cbus_state ne 'OFF';
                &::print_log ("[Clipsal CBus] Talker $name ($addr) is $cbus_state") if $::Debug{cbus};
                
            }
            else {
                &::print_log ("[Clipsal CBus] Talker UNEXPECTED 300 msg \"$talker_msg\"");
            }
            
            ###### Message code 200: Completed successfully
            
        }
        elsif ( $msg_code == 200 ) {
            &::print_log ("[Clipsal CBus] Talker Cmd OK - $talker_msg") if $::Debug{cbus};
            
            ###### Message code 201: Service ready
            
        }
        elsif ( $msg_code == 201 ) {
            &::print_log ("[Clipsal CBus] Talker Comms established - $talker_msg");
            
            # Newly started comms, therefore find the networks available
            # then we will wait until CGate has sync'ed with the network
            $$self{request_cgate_scan} = 0;
            $Clipsal_CBus::Talker->set ("session_id");
            
            if ( not defined $$self{project} ) {
                &::print_log ("[Clipsal CBus] Talker ***ERROR*** Set \$cbus_project_name in mh.ini");
            }
            else {
                $Clipsal_CBus::Talker->set ("project load $$self{project}");
                $Clipsal_CBus::Talker->set ("project use $$self{project}");
                $Clipsal_CBus::Talker->set ("project start $$self{project}");
                $Clipsal_CBus::Talker->set ("get cbus networks");
            }
            
            ###### Message code 401: Bad object or device ID
            
        }
        elsif ( $msg_code == 401 ) {
            &::print_log ("[Clipsal CBus] Talker $talker_msg");
            
            ###### Message code 408: Indicates that a SET, GET or other method
            ###### failed for a given object
            
        }
        elsif ( $msg_code == 408 ) {
            &::print_log ("[Clipsal CBus] Talker **** Failed Cmd - $talker_msg");
            if ( $msg_id =~ /\[MisterHouse(\d+)\]/ ) {
                my $cmd_num = $1;
                my $cmd     = $self->{cmd_list}{$cmd_num};
                if ( $cmd ne "" ) {
                    &::print_log ("[Clipsal CBus] Talker  Trying command again - $cmd");
                    $Clipsal_CBus::Talker->set ($cmd);
                    $self->{cmd_list}{$cmd_num} = "";
                }
                else {
                    &::print_log ("[Clipsal CBus] Talker 2nd failure - abandoning command");
                }
            }
            
            ###### Message code unhandled
            
        }
        else {
            &::print_log ("[Clipsal CBus] Talker Cmd port - UNHANDLED: $talker_msg");
        }
    }
    
    #
    # Control scanning of the CGate configuration
    #
    if ( $$self{cbus_scanning_cgate} ) {        # i've removed $self->{cbus_talker}->active() and
        &::print_log ("[Clipsal CBus] Talker scanning cgate");
        if ( not $$self{cbus_scanning_tree} ) {
            if ( my $network = pop @{ $$self{cbus_net_list} } ) { #pop @{ $$self{cbus_net_list} }
                
                # Cleanup from any previous scan and initialise flags/counters
                $$self{cbus_units_config}  = 0;
                $$self{cbus_got_tree_list} = 0;
                undef @{ $$self{cbus_group_list} };
                undef @{ $$self{cbus_unit_list} };
                undef $$self{cbus_scan_last_addr_seen};
                $$self{cbus_group_idx} = 0;
                $$self{cbus_unit_idx}  = 0;
                
                # Request from CGate a list of addresses on network
                $network = "//$$self{project}/$network";
                &::print_log ("[Clipsal CBus] Talker scanning network $network");
                $Clipsal_CBus::Talker->set("tree $network");
                
                $$self{cbus_scanning_tree} = 1;
                
            }
            else {
                # All networks scanned - set completion flag
                ### FIXME - RichardM test with two networks??
                &::print_log ("[Clipsal CBus] Talker leaving scanning mode") if $::Debug{cbus};
                $$self{cbus_scanning_cgate} = 0;
                &::print_log ("[Clipsal CBus] CBus server scan complete");
                $self->write_mht_file();
            }
            
        }
        elsif ( $$self{cbus_got_tree_list} ) {
            if ( $$self{cbus_group_idx} < @{ $$self{cbus_group_list} } ) {
                my $group = $$self{cbus_group_list}[ $$self{cbus_group_idx}++ ];
                &::print_log ("[Clipsal CBus] Talker dbget group $group") if $::Debug{cbus};
                $Clipsal_CBus::Talker->set("dbget $group/TagName");
                
            }
            elsif ( $$self{cbus_unit_idx} < @{ $$self{cbus_unit_list} } ) {
                my $unit = $$self{cbus_unit_list}[ $$self{cbus_unit_idx}++ ];
                &::print_log ("[Clipsal CBus] Talker dbget unit $unit") if $::Debug{cbus};
                $Clipsal_CBus::Talker->set("dbget $unit/TagName");
                
            }
            else {
                if (
                    $$self{cbus_scan_last_addr_seen} eq $$self{cbus_unit_list}[$#{ $$self{cbus_unit_list} }] )
                {
                    # Tree Scan complete - set tree completion flag
                    &::print_log ("[Clipsal CBus] Talker leaving scanning mode") if $::Debug{cbus};
                    $$self{cbus_scanning_tree} = 0;
                }
            }
            
        }
        else {
            # We are in scanning_tree mode, and waiting for response to the
            # TREE command. The TREE command lists each address on the particular
            # network. Then we will "dbget" each address. (That will start when
            # cbus_got_tree_list becomes true.
        }
    }

    
}

1;

