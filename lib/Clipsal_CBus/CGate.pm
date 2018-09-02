
=head1 B<Clipsal CGate>

=head2 SYNOPSIS

CGate.pm - support for the Clipsal  CGate interface.

=head2 DESCRIPTION

This module adds support for the Clispal CGtae interface. It is largely derived from the
original CBus support available in cbus.pl. See Clipsal_CBus.pm for detailed usage notes.

=cut

package Clipsal_CBus::CGate;

use strict;
use Clipsal_CBus;

#log levels
my $warn   = 1;
my $notice = 2;
my $info   = 3;
my $debug  = 4;
my $trace  = 5;

@Clipsal_CBus::CGate::ISA = ( 'Generic_Item', 'Clipsal_CBus' );

=item C<new()>
 
 Instantiates a new object.
 
=cut

sub new {
    my ($class) = @_;
    my $self = new Generic_Item();

    $$self{project} = $::config_parms{cbus_project_name};
    $$self{cbus_mht_filename} =
      $::config_parms{code_dir} . "/" . $::config_parms{cbus_mht_file};

    $$self{session_id}               = undef;
    $$self{cbus_units_config}        = undef;
    $$self{cbus_got_tree_list}       = undef;
    $$self{cbus_scanning_tree}       = undef;
    $$self{cbus_unit_list}           = undef;
    $$self{cbus_group_list}          = undef;
    $$self{cbus_scanning_cgate}      = undef;
    $$self{cbus_scan_last_addr_seen} = undef;
    $$self{network_state}            = undef;
    $$self{addr_not_sync_ref} => {};
    $$self{cmd_list}          => {};
    $$self{cbus_net_list}     => {};
    $$self{cbus_app_list}     => {};
    $$self{CBus_Sync}          = new Generic_Item();
    $$self{sync_in_progress}   = 0;
    $$self{DELAY_CHECK_SYNC}   = 10;
    $$self{cbus_group_idx}     = undef;
    $$self{cbus_unit_idx}      = undef;
    $$self{request_cgate_scan} = 0;

    bless $self, $class;

    $self->monitor_start();
    $self->talker_start();

    # Add hooks to the main loop to check the monitor and talker sockets for data on each pass.
    &::MainLoop_pre_add_hook( sub { $self->monitor_check(); }, 'persistent' );
    &::MainLoop_pre_add_hook( sub { $self->talker_check(); },  'persistent' );

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
    $self->debug( "scan_cgate() Scanning CGate...", $notice );

    # Cleanup from any previous scan and initialise flags/counters
    @{ $$self{cbus_net_list} } = [];

    if ( defined $$self{project} ) {
        $Clipsal_CBus::Talker->set( "project load " . $$self{project} );
        $Clipsal_CBus::Talker_last_sent = "project load " . $$self{project};

        $Clipsal_CBus::Talker->set( "project use " . $$self{project} );
        $Clipsal_CBus::Talker_last_sent = "project use " . $$self{project};

        $self->debug( "scan_cgate() Command - project start $$self{project}",
            $notice );
        $Clipsal_CBus::Talker->set( "project start " . $$self{project} );
        $Clipsal_CBus::Talker_last_sent = "project start " . $$self{project};
    }

    $$self{request_cgate_scan} = 1;
    $Clipsal_CBus::Talker->set("get cbus networks");
    $Clipsal_CBus::Talker_last_sent = "get cbus networks";

}

sub add_address_to_hash {
    my ( $self, $addr, $label ) = @_;
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

    $self->debug(
        "add_address_to_hash() Addr $addr is $name of type $addr_type",
        $debug );

    # Store the CBus name and address in the cbus_def hash
    if ( $addr_type eq 'group' ) {
        if ( not exists $Clipsal_CBus::Groups{$addr} ) {
            $self->debug(
                "add_address_to_hash() group not defined yet, adding $addr, $name",
                $info
            );

            $Clipsal_CBus::Groups{$addr}{name}  = $name;
            $Clipsal_CBus::Groups{$addr}{label} = $label;
            $Clipsal_CBus::Groups{$addr}{note} =
              "Added by CBus scan $::Date_Now $::Time_Now";

            $self->debug( "Address: $addr",                           $debug );
            $self->debug( "Name: $Clipsal_CBus::Groups{$addr}{name}", $debug );
            $self->debug( "Label: $Clipsal_CBus::Groups{$addr}{label}",
                $debug );
            $self->debug( "Note: $Clipsal_CBus::Groups{$addr}{note}", $debug );

        }
        else {
            $self->debug( "add_address_to_hash() group $addr already exists",
                $info );
        }
    }
    elsif ( $addr_type eq 'unit' ) {
        if ( not exists $Clipsal_CBus::Units{$addr} ) {
            $self->debug(
                "add_address_to_hash() unit not defined yet, adding $addr, $name",
                $info
            );
            $Clipsal_CBus::Units{$addr} = {
                name => $name,
                note => "Added by MisterHouse $::Date_Now $::Time_Now"
            };
        }
        else {
            $self->debug( "add_address_to_hash() unit $addr already exists",
                $info );
        }
    }

}

#
# Setup to sync levels of all known addresses
#
sub start_level_sync {
    my ($self) = @_;

    #return if not defined $Clipsal_CBus::Groups;

    $self->debug( "Syncing MisterHouse to CBus", $notice );

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
    $self->debug( "attempt_level_sync() count=" . @count, $info );

    if ( not %{ $$self{addr_not_sync} } ) {
        $self->debug( "Sync to CGate complete", $notice );
        $$self{CBus_Sync}->set('on');
        $$self{sync_in_progress} = 0;

    }
    else {
        $self->debug( "attempt_level_sync() list:@count", $info );

        my @addresses = keys %{ $$self{addr_not_sync} };
        foreach my $addr (@addresses) {

            # Skip if CBus scene group address
            if (   $addr =~ /\/\/.+\/\d+\/202\/\d+/
                or $addr =~ /\/\/.+\/\d+\/203\/\d+/ )
            {
                delete $$self{addr_not_sync}->{$addr};
                next;
            }
            $Clipsal_CBus::Talker->set("[MisterHouse $addr] get $addr level");
            $Clipsal_CBus::Talker_last_sent =
              "[MisterHouse $addr] get $addr level";

        }

        &::eval_with_timer( '$CGATE->attempt_level_sync()',
            $$self{DELAY_CHECK_SYNC} );
    }
}

sub cbus_update {
    my ( $self, $addr, $cbus_state, $set_by ) = @_;

    my $object_name = $Clipsal_CBus::Groups{$addr}{object_name};
    my $set_command = $object_name . "->set('$cbus_state','$set_by');";

    $self->debug(
        "cbus_update triggering set() for object $object_name with state $cbus_state",
        $debug
    );
    $self->debug( "cbus_update set() command: $set_command", $trace );

    package main;
    eval $set_command;
    print "Error in cbus set command: $@\n" if $@;

    package Clipsal_CBus::CGate;
}

sub write_mht_file {
    my ($self) = @_;

    my $count = 0;
    $self->debug( "Writing MHT file $$self{cbus_mht_filename}", $notice );

    open( CF, ">$$self{cbus_mht_filename}" )
      or $self->debug(
        "write_mht_file() Could not open $$self{cbus_mht_filename}: $!",
        $warn );

    print CF "# CBus mht file auto-generated on $::Date_Now at $::Time_Now.\n";
    print CF "\n";
    print CF
      "# This file may be overwritten - do not edit. Instead, copy this file to \n";
    print CF "# (for example) cbus.mht and edit as required.\n";
    print CF "\n";
    print CF "Format = A\n";
    print CF "\n";
    print CF "#TYPE, 					Address, 			Name, 	GroupList, 		Other\n";
    print CF "\n";
    print CF "CBUS_CGATE,   CGATE\n";
    print CF "\n";

    print CF "# CBus trigger group addresses.\n";
    print CF "\n";

    foreach my $address ( sort keys %Clipsal_CBus::Groups ) {
        if ( $address =~ /\/\d+\/(\d+)\/\d+/ ) {
            my $application = $1;
            next if not $application == 202;
        }

        my $name  = $Clipsal_CBus::Groups{$address}{name};
        my $label = $Clipsal_CBus::Groups{$address}{label};

        print CF "CBUS_TRIGGER, $address, $name, All_CBus, $label\n";
    }

    print CF "\n";
    print CF "# CBus lighting group addresses.\n";
    print CF "\n";

    foreach my $address ( sort keys %Clipsal_CBus::Groups ) {
        if ( $address =~ /\/\d+\/(\d+)\/\d+/ ) {
            my $application = $1;
            next if not $application == 56;
        }
        my $name  = $Clipsal_CBus::Groups{$address}{name};
        my $label = $Clipsal_CBus::Groups{$address}{label};

        print CF "CBUS_GROUP, $address, $name, All_CBus, $label\n";

    }

    print CF "\n";
    print CF "# CBus Unit addresses.\n";
    print CF "\n";

    foreach my $address ( sort keys %Clipsal_CBus::Units ) {
        my $name  = $Clipsal_CBus::Units{$address}{name};
        my $label = $Clipsal_CBus::Units{$address}{label};

        print CF "CBUS_UNIT, $address, $name, $label\n";

    }

    print CF "#\n#\n# EOF\n#\n#\n";

    close(CF)
      or $self->debug(
        "write_mht_file() Could not close $$self{cbus_mht_filename}: $!",
        $warn );

    $self->debug(
        "write_mht_file() Completed CBus build to $$self{cbus_mht_filename}",
        $notice );

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

    if ( $Clipsal_CBus::Monitor->active() ) {
        $self->debug( "Monitor already running, skipping start", $notice );
    }
    else {
        $$self{monitor_retry} = 0;
        if ( $Clipsal_CBus::Monitor->start() ) {
            $self->debug( "Monitor started", $notice );
        }
        else {
            $self->debug( "Monitor failed to start", $warn );
        }
    }
}

sub monitor_stop {
    my ($self) = @_;

    # Stop the CBus listener (monitor)

    if ( not $Clipsal_CBus::Monitor->active() ) {
        $self->debug( "Monitor isn't active, skipping stop", $notice );
    }
    else {
        #$$self{monitor_retry} = 0;
        if ( $Clipsal_CBus::Monitor->stop() ) {
            $self->debug( "Monitor stopped", $notice );
        }
        else {
            $self->debug( "Monitor failed to stop", $warn );
        }
    }
}

sub monitor_status {
    my ($self) = @_;

    # Return the status of the CBus listener (monitor)

    if ( $Clipsal_CBus::Monitor->active() ) {
        $self->debug( "Monitor is active.", $notice );
    }
    else {
        $self->debug( "Monitor is NOT running", $warn );
    }
}

sub monitor_check {
    my ($self) = @_;
    
    #Check to see if the monitor socket is still available, and attempt
    #to restart it if it's not
    if (!$Clipsal_CBus::Monitor->active() ) {
    	$self->monitor_start
    }

    # Monitor Voice Command / Menu processing
    if ( my $data = $::CBus_Monitor_v->said() ) {
        if ( $data eq 'Status' ) {
            $self->monitor_status();
        }
        else {
            $self->debug( "Monitor: command $data is not implemented", $warn );
        }
    }

    #Process monitor socket input
    if ( my $monitor_msg = $Clipsal_CBus::Monitor->said() ) {
        $self->debug( "Monitor message: $monitor_msg", $debug );

        my @cg = split / /, $monitor_msg;
        my $cg_code = $cg[1];

        unless ( $cg_code == 730 ) {    # only code 730 are of interest
            $self->debug(
                "Monitor ignoring uninteresting message type $cg_code",
                $debug );
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

        $self->debug( "Monitor processing message type $cg_code", $debug );

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
            $source = "cbus unit: $Clipsal_CBus::Units{$source}{name}";
        }

        $self->debug( "Monitor source is $source", $debug );

        # Determine what level is being reported
        my $ramping;
        my $state_speak;
        $cg_ramptime =~ s/ramptime=//i;

        ### if ($could_be_ramp_starting and $cg_ramptime > 0) {
        if ( $cg_ramptime > 0 ) {
            $self->debug( "Monitor ramptime $cg_ramptime detected", $debug );

            # The group has started ramping
            if ( $level == 255 ) {
                $cbus_state  = 'on';
                $ramping     = 'UP/ON';
                $state_speak = 'ramping UP';
            }
            elsif ( $level == 0 ) {
                $cbus_state  = 'off';
                $ramping     = 'DOWN/OFF';
                $state_speak = 'ramping DOWN';
            }
            else {
                my $plevel = $level / 255 * 100;
                $ramping = 'UP/DOWN';
                $cbus_state = sprintf( "%.0f%%", $plevel );
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
            $self->debug( "Monitor not ramping - level set to $cbus_state",
                $debug );
        }

        my $cbus_label = $Clipsal_CBus::Groups{$cg_addr}{label};

        if ( $source eq 'MisterHouse via Session ID' ) {

            # This is a Reflected mesg, we will ignore
            $self->debug( "Monitor ignoring reflected message from $source",
                $debug );
        }
        elsif ( $source eq 'MisterHouse via Command ID' ) {

            # This is a Reflected mesg, we will ignore
            $self->debug( "Monitor ignoring reflected message from $source",
                $debug );
        }
        elsif ( not defined $cbus_label ) {
            $self->debug(
                "Monitor UNKNOWN Address $cg_addr $state_speak by $source",
                $debug );
        }
        else {
            # The source is a CBus unit, CGate, Toolkit, or some other software. Trigger an object set().
            $self->debug( "Monitor $cbus_label ramping $ramping by $source",
                $debug )
              if ($ramping);
            $self->cbus_update( $cg_addr, $cbus_state, $source );
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
        $self->debug( "Talker already running, skipping start", $notice );
    }
    else {
        #set $Clipsal_CBus_CGate::CBus_Sync = "OFF";
        $$self{talker_retry} = 0;
        if ( $Clipsal_CBus::Talker->start() ) {
            $self->debug( "Talker started", $notice );
        }
        else {
            $self->debug( "Talker failed to start", $warn );
        }
    }
}

sub talker_stop {
    my ($self) = @_;

    # Stops the CBus command driver (Talker)

    if ( not $Clipsal_CBus::Talker->active() ) {
        $self->debug( "Talker isn't active, skipping stop", $notice );
    }
    else {
        #set $Clipsal_CBus_CGate::CBus_Sync = "OFF";
        if ( $Clipsal_CBus::Talker->stop() ) {
            $self->debug( "Talker stopped", $notice );
        }
        else {
            $self->debug( "Talker failed to stop", $warn );
        }
    }
}

sub talker_status {
    my ($self) = @_;

    # Returns the status of the CBus command driver (Talker)

    if ( $Clipsal_CBus::Talker->active() ) {
        $self->debug( "Talker is active.", $notice );
    }
    else {
        $self->debug( "Talker is not running", $notice );
    }
}

sub talker_check {
    my ($self) = @_;

    #Check to see if the talker socket is still available, and attempt
    #to restart it if it's not
    if (!$Clipsal_CBus::Talker->active() ) {
    	$self->talker_start
    }
    
    # Talker Voice Command / Menu processing
    if ( my $data = $::CBus_Talker_v->said() ) {
        if ( $data eq 'Status' ) {
            $self->talker_status();

        }
        elsif ( $data eq 'Scan' ) {
            $self->scan_cgate();

        }
        else {
            $self->debug( "Talker: command $data is not implemented", $warn );
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

        $self->debug( "Talker received: $talker_msg", $debug );

        ###### Message code 200: Completed successfully

        if ( $msg_code == 200 ) {
            $self->debug( "Talker Cmd OK - $talker_msg", $debug );
        }

        ###### Message code 201: Service ready

        elsif ( $msg_code == 201 ) {
            $self->debug( "Talker Comms established - $talker_msg", $notice );

            # Newly started comms, therefore find the networks available
            # then we will wait until CGate has sync'ed with the network
            $$self{request_cgate_scan} = 0;
            $Clipsal_CBus::Talker->set("session_id");
            $Clipsal_CBus::Talker_last_sent = "session_id";

            if ( not defined $$self{project} ) {
                $self->debug(
                    "Talker ***ERROR*** Set \$cbus_project_name in mh.ini",
                    $warn );
            }
            elsif ( keys %Clipsal_CBus::Groups == 0 ) {

                #we have no pre-defined CBus group objects loaded into the hash, so kick off a scan
                $self->debug(
                    "Talker - no existing CBus Group objects. Initiating Scan.",
                    $warn
                );
                $self->scan_cgate();
            }
            else {
                # initial a sync
                $Clipsal_CBus::Talker->set("project load $$self{project}");
                $Clipsal_CBus::Talker_last_sent =
                  "project load $$self{project}";

                $Clipsal_CBus::Talker->set("project use $$self{project}");
                $Clipsal_CBus::Talker_last_sent = "project use $$self{project}";

                $Clipsal_CBus::Talker->set("project start $$self{project}");
                $Clipsal_CBus::Talker_last_sent =
                  "project start $$self{project}";

                $Clipsal_CBus::Talker->set("get cbus networks");
                $Clipsal_CBus::Talker_last_sent = "get cbus networks";
            }
        }

        ###### Message code 300: Object information, for example: 300 1/56/1: level=200

        elsif ( $msg_code == 300 ) {

            if ( $talker_msg =~ /(sessionID=.+)/ ) {
                $$self{session_id} = $1;    # Set global session ID
                $self->debug( "Talker Session ID is \"$$self{session_id}\"",
                    $notice );

            }
            elsif ( $talker_msg =~ /networks=(.+)/ ) {
                my $netlist = $1;
                $self->debug( "Talker network list: $netlist", $notice );
                @{ $self->{cbus_net_list} } = split /,/, $netlist;

                # Request state of network
                $self->debug(
                    "Talker sent: get " . $self->{cbus_net_list}[0] . " state",
                    $debug
                );
                $Clipsal_CBus::Talker->set(
                    "get " . $self->{cbus_net_list}[0] . " state" );
                $Clipsal_CBus::Talker_last_sent =
                  "get " . $self->{cbus_net_list}[0] . " state";

            }
            elsif ( $talker_msg =~ /state=(.+)/ ) {
                my $network_state = $1;
                $self->debug( "Talker CGate Status - $talker_msg", $debug );
                if ( $network_state ne "ok" ) {
                    $Clipsal_CBus::Talker->set(
                        "get " . $self->{cbus_net_list}[0] . " state" );
                    $Clipsal_CBus::Talker_last_sent =
                      "get " . $self->{cbus_net_list}[0] . " state";
                }
                else {
                    if ( $$self{request_cgate_scan} ) {

                        # This state request was part of scanning startup
                        $self->debug(
                            "Talker state request was part of scanning startup",
                            $debug
                        );

                        $$self{cbus_scanning_cgate} = 1;    # Set scanning flag
                        $$self{request_cgate_scan}  = 0;
                    }
                    else {
                        # If not a scan, then is a startup sync being kicked off
                        $self->debug( "Not a scan... starting level sync",
                            $info );
                        $self->start_level_sync();
                    }
                }

            }
            elsif (
                $talker_msg =~ /(\/\/[\w|\d]+\/\d+\/\d+\/\d+):\s+level=(.+)/ )
            {
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

                delete $self->{addr_not_sync} >
                  {$addr};    # Remove from not sync'ed list
                my $name = $Clipsal_CBus::Groups{$addr}{name};
                $self->debug( "Talker $name ($addr) is $cbus_state", $info )
                  if $cbus_state ne 'off';
            }
            else {
                $self->debug( "Talker UNEXPECTED 300 msg \"$talker_msg\"",
                    $info );
            }

        }

        ###### Message code 320: Tree information. Returned from the tree command, which returns a list of units
        ###### followed by a list of groups, ordered by application.

        elsif ( $msg_code == 320 ) {
            if ( not $$self{cbus_got_tree_list} ) {
                if ( not $$self{cbus_units_config} ) {
                    if ( $talker_msg =~ /Applications/ ) {

                        #we've started listing applications and groups
                        $$self{cbus_units_config} = 1;
                    }
                    elsif (
                        $talker_msg =~ /(\/\/.+\/\d+\/p\/\d+).+type=(.+) app/ )
                    {

                        # CGate is listing CBus "units" (input and output)
                        $self->debug( "Talker scanned addr=$1 is type $2",
                            $debug );

                        # Store unit on a list for later scanning of details
                        push( @{ $$self{cbus_unit_list} }, $1 );

                    }

                }
                else {
                    # CGate is listing CBus "groups"
                    if ( $talker_msg =~ /end/ ) {

                        #we've finished scanning the tree
                        $self->debug(
                            "Talker end of CBus scan data, got tree list",
                            $notice );
                        $$self{cbus_got_tree_list} = 1;
                    }
                    elsif (
                        #this is an applcation response, e.g. 320 Application 56 ($38) [lighting]
                        $talker_msg =~ /Application (\d+).+\[(.+)\]/
                      )
                    {
                        $self->debug( "Talker found application $1 of type $2",
                            $notice );

                        # Store application on a list
                        $$self{cbus_app_list}{$1}{type} = $2;
                    }
                    elsif (
                        #this is a group response, e.g. 320 //HOME/254/56/0 ($0) level=0 state=ok units=2,12
                        $talker_msg =~ /(\/\/.+\/\d+\/\d+\/\d+).+level=(\d+)/
                      )
                    {
                        $self->debug( "Talker scanned group=$1 at level $2",
                            $info );

                        # Store group on a list for later scanning of details
                        push( @{ $$self{cbus_group_list} }, $1 );
                    }
                }
            }
        }

        ###### Message code 342: DBGet response (not documented in CGate Server Guide 1.0.)

        elsif ( $msg_code == 342 ) {
            if ( $$self{cbus_scanning_cgate} ) {

                $self->debug( "Talker message 342 response data: $talker_msg",
                    $debug );

                if ( $talker_msg =~ /\d+\s+(\d+\/[a-z\d]+\/\d+)\/TagName=(.+)/ )
                {

                    #response matched against "new" format, i.e. network/app/group
                    my ( $addr, $name ) = ( $1, $2 );
                    $addr = "//$$self{project}/$addr";

                    $$self{cbus_scan_last_addr_seen} = $addr;

                    # $name =~ s/ /_/g;  Change spaces, depends on user usage...
                    $self->add_address_to_hash( $addr, $name );

                }
                elsif ( $talker_msg =~
                    /(\/\/.+\/\d+\/[a-z\d]+\/\d+)\/TagName=(.+)/ )
                {
                    #response matched against "old" format, i.e. //project/network/app/group
                    my ( $addr, $name ) = ( $1, $2 );

                    $$self{cbus_scan_last_addr_seen} = $addr;

                    # $name =~ s/ /_/g;  Change spaces, depends on user usage...
                    $self->add_address_to_hash( $addr, $name );

                }
                $self->debug( "Talker end message", $info );
            }
        }

        ###### Message code 401: Bad object or device ID

        elsif ( $msg_code == 401 ) {
            $self->debug( "Talker $talker_msg", $info );
        }

        ###### Message code 408: Indicates that a SET, GET or other method
        ###### failed for a given object

        elsif ( $msg_code == 408 ) {
            $self->debug( "Talker **** Failed Cmd - $talker_msg", $warn );
            $self->debug(
                "Talker last sent command = $Clipsal_CBus::Talker_last_sent",
                $warn );

            if ( $msg_id =~ /\[MisterHouse-(\d+)\]/ ) {
                my $cmd_num = $1;
                my $cmd     = $self->{cmd_list}{$cmd_num};
                if ( $cmd ne "" ) {
                    $self->debug( "Talker  Trying command again - $cmd",
                        $warn );
                    $Clipsal_CBus::Talker->set($cmd);
                    $Clipsal_CBus::Talker_last_sent = $cmd;
                    $self->{cmd_list}{$cmd_num} = "";
                }
                else {
                    $self->debug( "Talker 2nd failure - abandoning command",
                        $warn );
                }
            }
        }

        ###### Message code unhandled

        else {
            $self->debug( "Talker Cmd port - UNHANDLED: $talker_msg", $warn );
        }
    }

    #
    # Control scanning of the CGate configuration
    #
    if ( $$self{cbus_scanning_cgate} ) {
        if ( not $$self{cbus_scanning_tree} ) {
            if ( my $network = pop @{ $$self{cbus_net_list} } ) {

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
                $self->debug( "Talker scanning network $network", $notice );
                $self->debug( "Talker sent: tree $network",       $debug );
                $Clipsal_CBus::Talker->set("tree $network");
                $Clipsal_CBus::Talker_last_sent = "tree $network";

                $$self{cbus_scanning_tree} = 1;

            }
            else {
                # All networks scanned - set completion flag
                ### FIXME - RichardM test with two networks??
                $self->debug( "Talker leaving scanning mode", $notice );
                $$self{cbus_scanning_cgate} = 0;
                $self->debug( "CBus server scan complete", $notice );
                $self->write_mht_file();
            }

        }
        elsif ( $$self{cbus_got_tree_list} ) {
            if ( $$self{cbus_group_idx} < @{ $$self{cbus_group_list} } ) {
                my $group = $$self{cbus_group_list}[ $$self{cbus_group_idx}++ ];
                $self->debug( "Talker dbget group $group", $info );
                $Clipsal_CBus::Talker->set("dbget $group/TagName");
                $Clipsal_CBus::Talker_last_sent = "dbget $group/TagName";

            }
            elsif ( $$self{cbus_unit_idx} < @{ $$self{cbus_unit_list} } ) {
                my $unit = $$self{cbus_unit_list}[ $$self{cbus_unit_idx}++ ];
                $self->debug( "Talker dbget unit $unit", $info );
                $Clipsal_CBus::Talker->set("dbget $unit/TagName");
                $Clipsal_CBus::Talker_last_sent = "dbget $unit/TagName";

            }
            else {
                if ( $$self{cbus_scan_last_addr_seen} eq
                    $$self{cbus_unit_list}[ $#{ $$self{cbus_unit_list} } ] )
                {
                    # Tree Scan complete - set tree completion flag
                    $self->debug( "Talker leaving scanning mode", $notice );
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

=head1 AUTHOR
 
 Richard Morgan, omegaATbigpondDOTnetDOTau
 Andrew McCallum, Mandoon Technologies, andyATmandoonDOTcomDOTau
 Jon Whitear, jonATwhitearDOTorg
 
=head1 VERSION HOSTORY
 
 03-12-2001
 Modified to support c-gate 1.5
 23-06-2002
 Monitor: Source name now works, and shows 'MH' is source 0
 05-07-2002
 Modified for cbus_dat.csv input file support
 Added groups and set_info support
 06-07-2002
 Minor changes to support new cbus_builder
 Modified to support global %cbus_data hash
 removed make_cbus_file(), replaced with cbus_builder.pl
 11-07-2002
 Added announce flag to cbus_dat.csv, and conditional speak flag $announce
 19-09-2002
 Fixed bug in cbus_set() that prevented dimming numeric % set values
 being accepted.  Dimming now works.
 21-09-2002
 Modified cbus_groups and cbus_catagories to read from input file
 rather than hard coded
 Put in config item cbus_category_prefix
 Comments in input file now allowed
 Fixed some other minor things
 22-09-2002 V2.0
 Collapsed cbus_talker.pl, cbus_builder.pl and cbus_monitor.pl
 into one new file, cbus.pl.  Now issued as V2.0.
 
 V2.1    Fixed up some menu uglies.
 Improved coding in monitor loop
 Fixed up code labels, docs etc
 
 V2.2    Changed all speak() calls to say 'C-Bus' rather than 'CBus', so the diction is correct
 
 V2.2.1  Fixed minor bug in cbus monitor start voice command
 
 V2.2.2  Implemented;
 oneshot device type
 cbus_oneshot_log config param
 
 V2.2.3  Made the dump_cbus_data format pretty HTML tables
 
 V3.0    2008-02-04
 Fixed to work with C-Gate Version: v2.6.1 (build 2236)
 Latest version as of June 2008
 Now reports the name of the source unit that modified a group level.
 Added ability to scan CGate for groups and output to config file.
 *** Configuration only requires running Builder to scan cgate and
 *** build XML file, then commanding MH to "reload code". Job Done.
 *** Customisation if wanted can be done through the config file.
 Changed config file to XML format.
 Builder command auto scans CGate if no config file exists.
 Fixed interpretation of dimming commands.
 PROD is the default state. In PROD, no option to stop comms.
 Changed DEV to DEBUG for commonality.
 Monitor and Talker attempt to always run unless in DEBUG state.
 
 V3.0.1	2013-11-22
 Fixed to work with C-Gate Version: v2.9.7 (build 2569), which returns
 cbus addresses in the form NETWORK/APPLICATION/GROUP rather than
 //PROJECT/NETWORK/APPLICATION/GROUP.
 Add logging to aid debugging cbus_builder
 Contributed by Jon Whitear <jonATwhitearDOTorg>
 
 V3.0.2  2013-11-25
 Add support for both formats of return code, i.e. NETWORK/APPLICATION/GROUP
 and //PROJECT/NETWORK/APPLICATION/GROUP.
 
 V3.0.3	2013-11-28
 Test debug flag for logging statements.
 
 V4.0    2016-03-25
 Refactor cbus.pl into Clipsal_CBus.pm, CGate.pm, Group.pm, and Unit.pm, and
 make CBus support more MisterHouse "native".
 
=head1 LICENSE
 
 This program is free software; you can redistribute it and/or modify it under the terms of the GNU General Public License as
 published by the Free Software Foundation; either version 2 of the License, or (at your option) any later version.
 
 This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty
 of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more details.
 
 You should have received a copy of the GNU General Public License along with this program; if not, write to the
 Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.
 
=cut

1;

