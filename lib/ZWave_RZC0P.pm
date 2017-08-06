=begin comment

From David Satterfield <david_misterhouse@yahoo.com>

ZWave Interface for Leviton RZC0P serial interface

This module was shamelessly adapted from all the existing code I could find
Thanks for the starting point everybody.

Use these mh.ini parameters to enable this code:

# Serial port that the RZC0P is connected to
ZWave_RZC0P_serial_port = /dev/ttyS0

Here are the config parms for the interface:

# 0 = silent, 1 = Errors, 2 = Warnings, Errors, 3 = Info, Warnings, Errors, 4 = 3 + Debug
rzc0p_errata = 3
# how many times to retry before giving up a command
rzc0p_retry_limit = 20

# print statistics
rzc0p_update10 = 0
rzc0p_update100 = 1
rzc0p_update1000 = 1

# timeout in seconds for each command
rzc0p_timeout = 10

# node id of serial interface
rzc0p_id = 019

=cut

use strict;
use warnings;
use Serial_Item;

package ZWave_RZC0P;

@ZWave_RZC0P::ISA=('Serial_Item');

my %zwave_ids;       # hash that holds each object that the interface controls

# stats
my %defers_by_id;          # defers for each object
my %errors_by_id;          # errors for each object
my %retries_by_id;         # retries for each object
my %peak_latency_by_id;    # worst latency for each object  
my %updates_by_id;         #
my %total_latency_by_id;   # hash that holds each object that the interface controls
my %last_latency_by_id;   # hash that holds each object that the interface controls

# command queues
my @zwave_update_command_list; # the list of update (>?N) commands 
my @zwave_set_command_list;    # the list of set commands

# timeouts and retry limits
my $interface_timeout;
my $retry_limit;

# name of port for printing messages
my $portname = 'ZWave_RZC0P';

sub new {

    my ($class, $port_name)=@_;
    $port_name = 'RZC0P' if !$port_name;

    $retry_limit = $::config_parms{rzc0p_retry_limit};
    &report("Info: Specified retry_limit of $retry_limit",1);
    unless ($retry_limit) {
	&report("Info: No retry limit defined, setting to 10",1);
	$retry_limit = 10;
    }

    $interface_timeout = $::config_parms{rzc0p_timeout};
    &report ("Info: Specified timeout of $interface_timeout seconds",1) if ($interface_timeout);
    unless ($interface_timeout) {
	&report("Info: No interface timeout defined, setting to 10 seconds",1);
	$interface_timeout = 10;
    }

    my $self = {};
    $self->{port_name} = $port_name;
    $self->{device_name}=$portname;
    $self->{expect_data} = 0;
    $self->{expect_xmit} = 0;
    $self->{cmd_acked} = 0;
    $self->{xmit_acked} = 0;
    $self->{data_acked} = 0;
    $self->{doing_retry} = 0;
    $self->{retry_limit} = $retry_limit;
    $self->{stats_start_10} = &::gettimeofday();
    $self->{stats_start_100} = &::gettimeofday();
    $self->{stats_start_1000} = &::gettimeofday();
    $self->{commands_10} = 0;
    $self->{updates_10}  = 0;
    $self->{retrys_10} = 0; 
    $self->{fails_10} = 0;
    $self->{defers_10} = 0;
    $self->{commands_100} = 0;
    $self->{updates_100}  = 0;
    $self->{retrys_100} = 0; 
    $self->{fails_100} = 0;
    $self->{defers_100} = 0;
    $self->{commands_1000} = 0;
    $self->{updates_1000}  = 0;
    $self->{retrys_1000} = 0; 
    $self->{fails_1000} = 0;
    $self->{defers_1000} = 0;
    $self->{interface_ready} = 0;
    $self->{start_time} = 0;
    $self->{expecting_reset} = 1;
    $self->{zwave_id} = $::config_parms{rzc0p_id};

    bless $self, $class;

    my @states = ('busy', 'idle', 'disabled');
    $self->set_states(@states);

#    print "setting my state to idle";
    $self->set_now('disabled');

    # reset the interface
    $self->{command_type} = 'reset';
    &send_zwave_data($self,$self,">DE\r",0,1,1,1);

    &::MainLoop_pre_add_hook(\&ZWave_RZC0P::check_for_data,   1, 
			     $self) if $self->{state} eq 'idle';
    return $self;
}

sub add_id {
    my ($self,$item) =@_;

    my $id = $item->{zwave_id};
    my $type = $item->{type};
    my $instant_update = $item->{instant_update};

    &report("Adding id:$id,type:$type,inst:$instant_update to node list",4); 

    if (defined $zwave_ids{$id}) { 
	&report("Error: Node id $id already exists in network",1); 
    }
    else { # make sure that the item exists
#	&::print_log("Adding id:$id item:$item to node list\n"); 	
	$zwave_ids{$id} = $item;
#	&::print_log("$portname: Adding id $id of type $type to node list\n"); 

	my $data = '>?N' . $id;

	$self->{command_type} = 'check_id';
	&send_zwave_data($self,$zwave_ids{$id},$data,1,1,1,1);

#       my $name = $item->get_object_name();
#	print "name is $name\n";
#	print "item is $item\n";
#	$name =~ s/\$//;

	if (defined $item->{level}) { # Success

	    &report("Info: Successfully added ZWave item $id, Level:$item->{level}",1); 
#	    &associate_item($self,$item) if $item->{instant_update};
	} 
	else { 
	    while ($self->{doing_retry}) { 
		&check_for_data($self); 
	    }

	    if (defined $item->{level}) { 
		&report("Info: Successfully added ZWave node id $id, after $self->{retry_count} retries. Level is $item->{level}",1); 
#		&associate_item($self,$item) if $item->{instant_update};
	    }
	    else {
		&report("Error: Could not communicate with node id $id. Check that your ZWave setup is correct for this node",1); 
		delete$zwave_ids{$id};
	    }
	}
    }
}

#
# associates the item to the controller, so that it can get instant updates
# this isn't implemented yet, you need to do it by hand with the primary remote
# 
sub associate_item {
    my ($self,$item) = @_;
    my $id = $item->{zwave_id};

    &report("Getting association for id $item->{zwave_id}",1);
    my $command = '>N' . $id . 'SE133,2,1';
    $self->{command_type} = 'get_association';
    &send_zwave_data($self,$zwave_ids{$id},$command,1,1,1,1);
    while ($self->{doing_retry}) { 
	&check_for_data($self); 
    }
}

sub serial_startup {
    my $port  = $::config_parms{'ZWave_RZC0P_serial_port'};
    &::serial_port_create($portname, $port, '9600', 'dtr', 'raw');
#    $::Serial_Ports{$portname}{object}->dtr_active(1);
}

sub update_statistics {
    my ($self) = @_;

    my $time = &::gettimeofday();
    return unless $time > ($self->{stats_start_10} + 10);

    &report("10 second stats: commands: $self->{commands_10} updates: $self->{updates_10} retrys:$self->{retrys_10} defers:$self->{defers_10} fails:$self->{fails_10}",1) if $::config_parms{rzc0p_update10};
    $self->{commands_10} = 0; # reset commands
    $self->{updates_10} = 0;  # updates
    $self->{fails_10} = 0;    # fails
    $self->{retrys_10} = 0;   # retrys
    $self->{defers_10} = 0;   # retrys
    
    if (($time > $self->{stats_start_100} + 100) && 
	$::config_parms{rzc0p_update100}) { # 100 second stats 
	&report("100 second stats: commands: $self->{commands_100} updates: $self->{updates_100} retrys:$self->{retrys_100} defers:$self->{defers_100} fails:$self->{fails_100}",1);
	$self->{commands_100} = 0; # reset commands
	$self->{updates_100} = 0;  # updates
	$self->{fails_100} = 0;    # fails
	$self->{retrys_100} = 0;   # retrys
	$self->{defers_100} = 0;   # retrys
	$self->{stats_start_100} = $time;
	&print_error_stats();
	&print_latency_stats();
    }

    if (($time > $self->{stats_start_1000} + 1000) && $::config_parms{rzc0p_update1000}) { # 1000 second stats 
	&report("1000 second stats: commands: $self->{commands_1000} updates: $self->{updates_1000} retrys:$self->{retrys_1000} defers:$self->{defers_1000} fails:$self->{fails_1000}",3);
	$self->{commands_1000} = 0; # reset commands
	$self->{updates_1000} = 0;  # reset updates
	$self->{fails_1000} = 0;    # reset fails
	$self->{retrys_1000} = 0;   # reset retrys
	$self->{defers_1000} = 0;   # reset retrys
	$self->{stats_start_1000} = $time;
    }

    $self->{stats_start_10} = $time;
}

sub print_error_stats {
    foreach my $id (sort keys %defers_by_id) {
	&report("id: $id defer count: $defers_by_id{$id}",3) if defined $defers_by_id{$id};
	&report("id: $id error count: $errors_by_id{$id}",3) if defined $errors_by_id{$id};
	&report("id: $id retry count: $retries_by_id{$id}",3) if defined $retries_by_id{$id};
    }
}

sub print_latency_stats {
    foreach my $id (sort keys %peak_latency_by_id) {
	my $avg_latency = $total_latency_by_id{$id} / $updates_by_id{$id};
	my $ppeak =  substr($peak_latency_by_id{$id},0,4);
	my $plast =  substr($last_latency_by_id{$id},0,4);
	my $pavg  =  substr($avg_latency,0,4);
	my $pname = $zwave_ids{$id}->get_object_name();
	my $bad_sets = $zwave_ids{$id}->{bad_sets};
	my $total_sets = $zwave_ids{$id}->{total_sets};
	$pname = 'unknown' unless defined $pname;
#	&report("Latency Info: $pname (Id $id)\n\t peak: $ppeak avg: $pavg last:$plast updates:$updates_by_id{$id}",1);
	&report("Latency Info: Id $id peak: $ppeak avg: $pavg last:$plast updates:$updates_by_id{$id} total sets:$total_sets bad sets:$bad_sets ",3);
    }
}

sub check_for_data {
    my ($self) = @_;

    &report("enter cfd",6);

    my $cfd_enter_time = &::gettimeofday(); # track the time in sub

    &update_statistics($self); # update the stats

    my $set_number = scalar @zwave_set_command_list;    
    my $update_number = scalar @zwave_update_command_list;

    # debug
    &report("Info: There are $set_number set commands pending",5);
    &report("Info: There are $update_number update commands pending", 5);
    
    &report("Warning: ZWave interface is getting backed up, set_cmds=$set_number up_cmds:$update_number",2) if (($set_number > 3) || ($update_number > 20));

    # check for data
    &main::check_for_generic_serial_data($portname);

    if ($main::Serial_Ports{$portname}{data}) {

	# go get and process the data
	&process_incoming_data($self);

	# adjust the state of the interface based on the new data
	&adjust_interface_state($self);
    }

    # are we still busy? state goes to idle on success only
    if ($self->{state} eq 'busy') {

	&report("waiting for command $self->{command} to complete at time $cfd_enter_time",4) if $set_number > 0;
#	print "could send another command\n" if $self->{cmd_acked};
#	if (($self->{cmd_acked}) and 
#	    ($set_number > 0) and 
#	    ($zwave_set_command_list[0]{expect_data} == 0)) { 

#	    my $command = $zwave_set_command_list[0]{data};
#	    &::print_log("sending command $command while interface is busy");
#	    $self->write_data(">AB\r");  # outgoing data
#	    $command .= '\r';

#	    $self->write_data($command);  # outgoing data
#	    shift @zwave_set_command_list;	
#	} 
	
#	my $data = defined $self->{data} ? $self->{data} : '';
#	print "cmd_acked: $self->{cmd_acked}, data_rcvd: $data exp_d:$self->{expect_data} exp_x:$self->{expect_xmit} xmit_acked:$self->{xmit_acked}\n";

	# check for bad command
	if ($self->{command_response_error}) {
	    &report("Error: Bad Command $self->{command}. SW Bug",1);
	    &report("Type:$self->{command_response_info}",1);
	    &terminate_command($self);
	}
	
	my $time = &::gettimeofday();

	# busy and an update command?, then defer
	if ($self->{device_busy} and ($self->{command_type} eq 'update')) {
	    &report ("Info: have device busy, deferring",3);
	    &defer_update($self);
	    &terminate_command($self);
	} 

        # timed out
	if ($time > $self->{start_time} + $interface_timeout) {
	    &handle_timeout($self);
	} 

    } # busy

    else { # we are idle
#	print "idle:state:$self->{state}\n";

	if ($self->{doing_retry}) {
	    $self->{retrys_10}++;
	    $self->{retrys_100}++;
	    $self->{retrys_1000}++;
#	    print "calling retry_send\n";
	    &retry_send($self);
	}
	    
	elsif (@zwave_set_command_list > 0) { #issue set command
#	    &::print_log("issuing command $zwave_set_command_list[0]{data} from hp queue");
#	    print "idle:state1 = $self->{state}\n";
#	    print "issuing command $zwave_set_command_list[0]{data} from queue\n";
#	    &::print_log("there are $number commands pending");
	    my $queue_time = &::gettimeofday() - $zwave_set_command_list[0]{enqueue_time};
	    &report("command $zwave_set_command_list[0]{data} waited in hp queue for $queue_time",3);

	    $self->{commands_10}++;
	    $self->{commands_100}++;
	    $self->{commands_1000}++;

	    &xmit_zwave_data($self,
			     $zwave_set_command_list[0]{data},
			     $zwave_set_command_list[0]{expect_xmit},
			     $zwave_set_command_list[0]{expect_data},
			     0);

	    shift @zwave_set_command_list;
        }

	elsif (@zwave_update_command_list > 0) {
#	    print "issuing command $zwave_update_command_list[0]{data} from lp queue\n";
#	    print "idle:state2 = $self->{state}\n";
#	    &::print_log("there are $update_number commands pending");

	    $self->{updates_10}++;
	    $self->{updates_100}++;
	    $self->{updates_1000}++;

	    &xmit_zwave_data($self,
			     $zwave_update_command_list[0]{data},
			     $zwave_update_command_list[0]{expect_xmit},
			     $zwave_update_command_list[0]{expect_data},
			     0);

	    shift @zwave_update_command_list;
        }

	else {
	    &update_connected_items($self); 
	}
    }

#    print "end cfd\n";

    my $cfd_exit_time = &::gettimeofday();
    my $cfd_time = $cfd_exit_time - $cfd_enter_time;
    if ( $cfd_time > 2) { &report("Was in Zwave check_for_data sub for $cfd_time seconds\n",1); }
}

sub handle_timeout {
    my ($self) = @_;

    my $printcmd = $self->{command};
    $printcmd =~ s/\r$//;
    &report("$portname error: ZWave interface timeout, cmd:$printcmd",3); # 4
    &report("$portname error: data timeout",3) if $self->{expect_data} and not $self->{data_acked};
    &report("$portname error: xmit timeout",3) if $self->{expect_xmit} and not $self->{xmit_acked};
    &report("$portname info: got xmit ack",3) if $self->{expect_xmit} and $self->{xmit_acked};
    &report("$portname error: cmd timeout",3) if !$self->{cmd_acked};
    &report("$portname info: got cmd ack",3) if $self->{cmd_acked};


#    &::print_log("defer count is:$zwave_ids{$self->{target_id}}->{update_deferral_count}");
#    &::print_log("id is:$zwave_ids{$self->{target_id}}->{zwave_id}");

    my $upd_count = $zwave_ids{$self->{target_id}}->{update_deferral_count};
#    my $obj_name = $zwave_ids{$self->{target_id}}->get_object_name();

    if ($upd_count > 3) {
	&report("Warning: Something seems to be wrong with $self->{target_id}. The update has been deferred and failed $upd_count times already.",2);
    }

    my $time = &::gettimeofday();

    &report ("Warning: ZWave interface timeout, cmd:$printcmd xmit_acked:$self->{xmit_acked} da:$self->{data_acked}, ex_xmit:$self->{expect_xmit} ex_data:$self->{expect_data} cmd_acked:$self->{cmd_acked},now:$time start:$self->{start_time}, data:$main::Serial_Ports{$portname}{data}, defer_count:$zwave_ids{$self->{target_id}}->{update_deferral_count}",2) if (!$self->{device_busy} and ($zwave_ids{$self->{target_id}}->{update_deferral_count} > 1));

    &terminate_command($self);

    if ($self->{command_type} eq 'update') {
#	    if (($self->{command} =~ /\?/) and !$self->{blocking}) { # update command timeout
	&defer_update($self);
    }

    elsif ($self->{retry_count} <= $self->{retry_limit}) {
#	print "trying to do retry\n";
	$self->{doing_retry} = 1;
    }

    else {
	&report("Error: Could not execute command $self->{command}. This is a fatal error for this command.",1);
	$self->{cmd_failed} = 1;
    }
}

sub defer_update {
    my ($self) = @_;

    my $pname = $zwave_ids{$self->{target_id}}->get_object_name();
    $pname =~ s/\$//;
    my $count = $zwave_ids{$self->{target_id}}->{update_deferral_count};
    &report("Warning: deferring update for $pname (id $self->{target_id}, count:$count)",2);
    # update the last update time to retry in 2 seconds
#    print "adjusting update rate\n"
    $zwave_ids{$self->{target_id}}->{update_deferral_count}++;
    $zwave_ids{$self->{target_id}}->{update_deferral_pending}++;
    $zwave_ids{$self->{target_id}}->{update_adjust} = 2;

    $self->{defers_10}++;
    $self->{defers_100}++;
    $self->{defers_1000}++;
    $defers_by_id{$self->{target_id}}++;
}

sub terminate_command {
    my ($self) = @_;
#    print "terminating command for  $self->{target_id}\n";
    $self->{state} = 'idle';
}

sub update_connected_items {
    my ($self) = @_;
    my $time = &::gettimeofday();

    foreach my $id (sort keys %zwave_ids) { 
#	print "updating id $id, item is $zwave_ids{$id}\n";

	my $last_update = $zwave_ids{$id}->{last_update_time};
	$last_update = 0 if (not defined $last_update);
	
	# how often to update
	my $update_rate = $zwave_ids{$id}->{update_rate};
	next if $update_rate == -1;

	# an adjust could happen if we time out 
	my $update_adjust = defined $zwave_ids{$id}->{update_adjust} ? $zwave_ids{$id}->{update_adjust} : 0;

#	print "update time adjusted by $update_adjust\n" if $update_adjust;
#	print "now: $time lu:$last_update ur:$update_rate ua:$update_adjust\n";

	if ($time > $last_update + $update_rate + $update_adjust) { 
#	    print "sending update request for id $id\n";
	    $zwave_ids{$id}->{update_adjust} = 0; # clear the adjust
	    $self->{command_type} = 'update';
	    &send_zwave_data($self, $zwave_ids{$id}, '>?N' . "$id", 1, 1, 0, 0);
	}
    }
}

sub adjust_interface_state {
    my ($self)=@_;
     my $xmit_ok = ((not $self->{expect_xmit}) || ($self->{expect_xmit} and 
						   $self->{xmit_acked})) ? 1 : 0;

    my $data_ok = ((not $self->{expect_data}) || ($self->{data_acked})) ? 1 : 0;

    my $data = defined $self->{data} ? $self->{data} : 'none';

    &report("checking state $self->{state}, \n\tdr:$data \b\n\tde:$self->{expect_data} \n\txa:$self->{xmit_acked} \n\tex_xm:$self->{expect_xmit} \n\tex_data:$self->{expect_xmit} \n\tcmd_acked:$self->{cmd_acked}\n xmitok:$xmit_ok dataok:$data_ok\n",4);

    # normal completion
    if ($self->{cmd_acked} and $xmit_ok and $data_ok and ($self->{state} eq 'busy')) {
	&report("Info: Command $self->{command} Completed Successfully.",4);
	&report("Info: Command $self->{command} Completed Successfully on retry number $self->{retry_count}",2) if $self->{retry_count};
	&terminate_command($self);
	$self->{doing_retry} = 0;

	if (defined $self->{target_id} and
	    $zwave_ids{$self->{target_id}}->{update_deferral_count} > 1) {
	    &report ("Info: Command $self->{command} Completed Successfully on deferred try $zwave_ids{$self->{target_id}}->{update_deferral_count}",3);
	   $zwave_ids{$self->{target_id}}->{update_deferral_count} = 0;
	}

	my $time = &::gettimeofday();
	my $latency = $time - $self->{start_time};
	my $print_latency = substr($latency,0,4);

	if (defined $self->{target_id}) {
	    &report ("Info: latency for $self->{target_id} is $print_latency seconds",4);
	    $peak_latency_by_id{$self->{target_id}} = 0 unless defined $peak_latency_by_id{$self->{target_id}};

	    $total_latency_by_id{$self->{target_id}} = 0 unless defined $total_latency_by_id{$self->{target_id}};
	    $last_latency_by_id{$self->{target_id}} = 0 unless defined $total_latency_by_id{$self->{target_id}};
	    $updates_by_id{$self->{target_id}} = 0 unless $updates_by_id{$self->{target_id}};

	    $peak_latency_by_id{$self->{target_id}} = $latency if ($latency > $peak_latency_by_id{$self->{target_id}});
	    $updates_by_id{$self->{target_id}}++;

	    $total_latency_by_id{$self->{target_id}} += $latency;
	    $last_latency_by_id{$self->{target_id}} = $latency;
	}
    }

    # command failed (after retries)
    elsif ($self->{cmd_failed} and ($self->{state} eq 'busy')) {
	&report("Error: Command Failed. Setting interface to idle",1);
	&increment_fails($self);
	&terminate_command($self);
    }
    # transmission failed 
    elsif ($self->{cmd_acked} and $self->{xmit_failed}) {
	&report ("Warning: Xmit fail retry",2);
#	&terminate_command($self);
	if ($self->{retry_count} <= $self->{retry_limit}) {
	    if ($self->{command_type} eq 'update') { 
		&defer_update($self);
		&terminate_command($self);
	    }
	    else {
		&report ("Warning: Doing Retry",2);
		$self->{doing_retry} = 1;
		&retry_send($self);
	    }

	}
	else {
	    &report("Can't retry command, retries exceeded",1);
	    &increment_fails($self);
	}
    }

}

sub increment_fails {
    my ($self) = @_;
	$self->{doing_retry} = 0;
	$self->{fails_10}++;
	$self->{fails_100}++;
	$self->{fails_1000}++;
}

sub retry_send {
    my ($self) = @_;

    $self->{retry_count}++;

    my $time = &::gettimeofday();

    &report("Info: Retrying Command $self->{command}, Retry Number:$self->{retry_count} time:$time",1);

#    $self->{command_type}= 'retry';
       
    if (not ($self->{retry_count} >= $self->{retry_limit})) {
	&send_zwave_data($self, 
			 $zwave_ids{$self->{target_id}}, # use current values for
			 $self->{command},               # comand, expects
			 $self->{expect_xmit}, 
			 $self->{expect_data}, 
			 1,  # priority
			 1); # blocking
	return 0;
    }
    else {
	&report("Error: Failed after $self->{retry_count} retry attempts.",1);
	$self->{doing_retry} = 0;
	$self->{cmd_failed} = 1;
	return 1;
    }

}

sub process_incoming_data {
    my ($self)=@_;

#    print "before loop:$main::Serial_Ports{$portname}{data}, state:$self->{state}:\n";
 
    my $loopcount = 0;
    while ($main::Serial_Ports{$portname}{data} =~ /\r\n/) { 
	$loopcount++;
	if ($loopcount > 3) {
	    &report("loop count is $loopcount",2);
	    &report("Looping data:$main::Serial_Ports{$portname}{data}",2);
	}
	if ($loopcount > 10) {
	    &report ("Error: don't know how to handle data $main::Serial_Ports{$portname}{data}, removing it from port",1);
	    $main::Serial_Ports{$portname}{data} = '';
	}

	if ($main::Serial_Ports{$portname}{data} =~ /^\r\n/) { 
	    $main::Serial_Ports{$portname}{data} =~ s/^\r\n//; # remove leading cr
	}

	if ($main::Serial_Ports{$portname}{data} =~ /<N(\d+)L(\d+)\r\n/) {
	    my $id = $1;
	    my $level = $2;

	    if ($id == $self->{target_id}) {
#		print "got data:$main::Serial_Ports{$portname}{data}:\n";
		$self->{data_acked} = 1;
		$zwave_ids{$id}->update_item_state($level);
	    }

	    else {
		&report("Info: Got data for another node. working on:$self->{target_id} got id:$id got level: $level exp_data:$self->{expect_data}. Updating state of Item.", 3);
		# take the data and update the item
		if (defined $zwave_ids{$id}) {
		    $zwave_ids{$id}->update_item_state($level);
		}
	    }

#	    $self->{cmd_acked} = 1;  # sometimes a command ack doesn't come,
	                             # so let data coming serve as a command ack
#	    $self->{xmit_acked} = 1; # sometimes a xmit ack doesn't come,
	                             # so let data coming serve as a xmit ack

	    $main::Serial_Ports{$portname}{data} =~ s/<N\d+L\d+\r\n//; # remove data
	}

	# scene response
	if ($main::Serial_Ports{$portname}{data} =~ /<N(\d+)S(\d+),(\d+),(\d+)\r\n/) {
	    my $id = $1;
	    my $scene = $2;
	    my $level = $3;
	    my $fade_rate = $4;

	    &report("Info: Got Scene response $1.",3);

	    if ($id == $self->{target_id}) {
		$self->{data_acked} = 1;
		$zwave_ids{$self->{target_id}}->update_item_state($level);
	    }
	    else {

		if ($zwave_ids{$id}->{button_press_pending}) {
		    my $old_level = $zwave_ids{$id}->{level};
		    my $object_name = $zwave_ids{$id}->get_object_name();
		    $object_name =~ s/\$//;
		    &report("Info: It's a response to a button press for $object_name (id $id), level was $old_level, is now: $level",3);
		    # update the object
		    $zwave_ids{$id}->update_item_state($level);
		}
		
		else {
		    &report("Warning: Got Scene Response for unexpected node. target:$self->{target_id} rcvd level $level from id $id exp_data:$self->{expect_data}. Ignoring it.",3);
		}
	    }

#	    $self->{cmd_acked} = 1;  # sometimes a command ack doesn't come,
	                             # so let data coming serve as a command ack
#	    $self->{xmit_acked} = 1; # sometimes a xmit ack doesn't come,
	                             # so let data coming serve as a xmit ack

	    $main::Serial_Ports{$portname}{data} =~ s/<N\d+S\d+,\d+,\d+\r\n//; # remove data
	}

	if ($main::Serial_Ports{$portname}{data} =~ /^\s+$/){
	    &report("it's just whitespace, data is $main::Serial_Ports{'zwave_rzc0p'}{data}",1);
	    $main::Serial_Ports{$portname}{data} =~ s/^s+$//;
	}

	if ($main::Serial_Ports{$portname}{data} =~ /<E(\d+)\r\n/) {
	    my $response = $1;
#	    print "process_incoming: got command ack, value=$response\n";

	    if (&check_command_response($self, $response)) { # command had trouble
		&report("Info: Command $self->{command} had trouble. Response was $response",1);

		if ($self->{command_response_info} eq 'FLOW_ERROR') { # can retry these
		    &report("Warning: Got Flow error, retrying",2); 
		    $self->{doing_retry} = 1;
		}
		else {
		    &report("Error: Command Failed. This is bad.",1);
		    $self->{cmd_failed} = 1; # 
		}
	    }

	    else {
#		&::print_log("$portname: command succeeded");
#		&::print_log("Error: command already acked") if $self->{cmd_acked};
		$self->{cmd_acked} = 1; # mark it acked
	    }
	    
	    $main::Serial_Ports{$portname}{data} =~ s/<E\d+\r\n//; # remove command
	}
	    
	if ($main::Serial_Ports{$portname}{data} =~ /<X(\d+)\r\n/) { # expected
	    $self->{xmit_acked} = 1; # mark it acked
	    $self->{xmit_failed} = ($1 > 0) ? 1 : 0;
	    if ($self->{xmit_failed}) {
		&report("Warning: zwave transmit failed for id $self->{target_id}. Reply = $1",2);
	    }

#	    &::print_log("got end of transmit for command $self->{command}. Reply=$1");	  
	    $main::Serial_Ports{$portname}{data} =~ s/<X\d+\r\n//;
	}

        if ($main::Serial_Ports{$portname}{data} =~ /.*?\$Leviton\(C\) (.*)\r\n/) { # Startup message
	    my $version = $1;
#	    &::print_log("data before:$main::Serial_Ports{$portname}{data}");  
	    $main::Serial_Ports{$portname}{data} =~ s/.*?\$Leviton.*\r\n//;
	    $self->{state} = 'idle';
	    
	    if ($self->{expecting_reset}) {
		&report("Info: Interface was reset, Version $version",3);	  
		$self->{cmd_acked} = 1; # mark it acked
		$self->{data_acked} = 1;
	    }
	    else {
		&report("Warning: Interface was reset unexpectedly, Version $version",2);	  
	    }

#	    &::print_log("data now:$main::Serial_Ports{$portname}{data}");  

	}

        if ($main::Serial_Ports{$portname}{data} =~ /^\r\n$/) {
	    &report("Info: process incoming: removing blank line",1);
	    $main::Serial_Ports{$portname}{data} =~ s/^\r\n$//; # remove blank
	}
	if ($main::Serial_Ports{$portname}{data} =~ /^<!(\d+)\r\n$/) {
	    &report("Info: Got programming info $1",3);
	    $main::Serial_Ports{$portname}{data} =~ s/^<!\d+\r\n$//; 
	}
        if ($main::Serial_Ports{$portname}{data} =~ /<N(\d+):(\d+),(\d+),*(\d*),*(\S*)\r\n/) {
	    &report("Info: Got $main::Serial_Ports{$portname}{data}",4);
	    my $id = $1;
	    my $major = $2;
	    my $minor = $3;
	    my $value = $4;
	    my $rest = $5;
	    if (($major eq '032') && ($minor eq '002')) {
		if ($1 eq $self->{target_id}) {
		    $self->{data_acked} = 1;
		    $zwave_ids{$self->{target_id}}->update_item_state($4);
		}
		else {
		    &report("Info: Got basic report response from non-target device:$main::Serial_Ports{$portname}{data}",3);
		}
	    }

	    elsif ($major eq '033') { # we don't support multilevel sensors 
		# yet but the RZI06 spits it out?!?
		&report("Error: Got upsupported multilevel sensor response",1);
	    }
	    elsif (($major eq '034') && ($minor eq '001')) {
		if ($1 eq $self->{target_id}) {
#		    &::print_log("this device is saying it is busy");
		    $self->{device_busy} = 1;
		}
		else {
		    &report("Info: Got busy response from non-target device:$main::Serial_Ports{$portname}{data}",3);
		}
	    }

	    # SWITCH_ALL_REPORT
	    elsif (($major eq '039') && ($minor eq '003')) {
		if ($1 eq $self->{target_id}) {
		    $self->{data_acked} = 1;
		    $zwave_ids{$self->{target_id}}->update_item_state($4);
		}
		else {
		    &report("Got switch_all report response from non-target device:$main::Serial_Ports{$portname}{data}",3);
		}
	    }

	    # this code is undocumented, but we get it on an instant update
	    elsif (($major eq '130') && ($minor eq '001')) {
		my $object_name = $zwave_ids{$id}->get_object_name();
		&report("Info: Someone pushed the button on $object_name, (id $id)",3);
		$zwave_ids{$id}->{button_press_pending} = 1;
	    }

	    # 133 is association list
	    elsif (($major eq '133') && ($minor eq '003')) {
		my $object_name = $zwave_ids{$id}->get_object_name();
		&report("Info: Got assoc list: maj:$major min:$minor val:$value rest:$rest",3);
		my @ids = split ',', $rest;
		&report("number of controllers supported::$ids[0]\n",3);
		for my $index (1..$#ids) { 
		    &report("Info: Controller:$ids[$index]",1);
		    if ($ids[$index] == $::config_parms{rzc0p_id}) {
			&report("Info: Found our controller already",3);
		    }
		}
		$self->{data_acked} = 1;
	    }
	    
	    $main::Serial_Ports{$portname}{data} =~ s/<N\d+:\d+,\d+,*\d*,*\S*\r\n//; # remove data
#	    &::print_log("data now:$main::Serial_Ports{$portname}{data}:");
	}

	&main::check_for_generic_serial_data($portname);
	&report ("Debug: End of loop:$main::Serial_Ports{$portname}{data}",4) if defined $main::Serial_Ports{$portname}{data};
    } # end while loop
    
#    if (not ($main::Serial_Ports{$portname}{data} eq '')) {
#	print "loop done, there was leftover data:$main::Serial_Ports{$portname}{data}:\n";
#	if ($main::Serial_Ports{$portname}{data} =~ /\r/) { print "has cr\n";}
#	if ($main::Serial_Ports{$portname}{data} =~ /\n/) { print "has lf\n";}
#    }
#    print "got out\n";
}

# checks the command response, returns 0 if ok, 1 if error
sub check_command_response {
    my ($self, $response)=@_;

    if ($response eq '000') { 
	$self->{command_response_info} = 'SUCCESS';
	$self->{command_response_error} = 0; # clear error flag
	return 0;
    }
    elsif (($response eq '001') or ($response eq '005') or ($response eq '007')) {
	if ($response eq '001') { &report("Error: command response error: wrong start symbol ($response)",1);}
	if ($response eq '005') { &report("Error: command response error: unrecognized command ($response)",1); }
	if ($response eq '007') { &report("Error: command response error: message data fields missing ($response)",1) };
	$self->{command_response_info} = 'MALFORMED';				  	
	$self->{command_response_error} = 1;
    }
    elsif (($response eq '002') or ($response eq '003') or ($response eq '004') or
	   ($response eq '006') or ($response eq '009')) {
	if ($response eq '002') { &report("Error: command response error: input buffer overflow ($response)",1); }
	if ($response eq '003') { &report("Error: command response error: buffers full ($response)",1); }
	if ($response eq '004') { &report("Error: command response error: rf xmit not done ($response)",1); }
	if ($response eq '006') { &report("Error: command response error: previous command not complete ($response)",1); }
	if ($response eq '009') { &report("Error: command response error: EEPROM busy ($response)",1); }
	$self->{command_response_info} = 'FLOW_ERROR';			  	
	$self->{command_response_error} = 1;
    }
    elsif ($response eq '008') { 
	&report("Error: command response error: cannot stop SUC mode ($response)",1); 
	$self->{command_response_info} = 'SUC_ERROR';
	$self->{command_response_error} = 1;
    }
    elsif ($response eq '010') {
	&report("Error: command response error: No device found ($response)",1); 
	$self->{command_response_info} = 'NO_DEVICE';
	$self->{command_response_error} = 1;
    }
    return 1;
}

sub send_zwave_data {
    my ($self, $object, $data, $expect_xmit, $expect_data, $high_priority, $blocking)=@_;
    my %command;
    
    $command{object}=$object;
    $command{data}=$data;
    $command{expect_xmit}=$expect_xmit;
    $command{expect_data}=$expect_data;
    $command{enqueue_time}= &::gettimeofday();

    $blocking = 0 unless defined $blocking;

#    &::print_log("Adding command $data to Zwave interface");

#    print "Adding command $data to Zwave interface upds:$#zwave_update_command_list, cmds:$#zwave_set_command_list retries:$#zwave_retry_command_list\n";
#    print "Adding command $data to Zwave interface upds:$#zwave_update_command_list, cmds:$#zwave_set_command_list\n";

    if ($self->{state} eq 'idle') {
#	print "directly issuing command $command{data}\n" if $command{data} =~ />N\d+/;
#	print "directly issuing command $command{data}, blocking = $blocking\n";

	&xmit_zwave_data($self,
			 $command{data},
			 $command{expect_xmit},
			 $command{expect_data},
			 $blocking);
    }
    else { # not idle
	if ($blocking) {
#	    print "sending blocking command $command{data}\n";
	    # send my data
	    &xmit_zwave_data($self,
			     $command{data},
			     $command{expect_xmit},
			     $command{expect_data},
			     $blocking);
	}
	    
	elsif ($high_priority) {
#	    print "queueing high priority command $command{data}\n";
	    push (@zwave_set_command_list,    { %command } );
	}
	else {
#	    print "queueing low priority command $command{data}\n";
	    push (@zwave_update_command_list, { %command } );
	}
    }

#    print "state at end is $self->{state}\n";
}

# this sub returns once the interface goes idle. 
sub wait_for_interface_idle {
    my ($self) =@_; 
#    print "waiting for interface idle state = $self->{state}\n";
    # block until response received,
    while ($self->{state} eq 'busy') {
	&check_for_data($self);
    }
}

# this sub sends the data and either lets the response come back asynchronously
# or it blocks until the command is complete
# worst case this is timeout seconds if the command times out
# the $blocking var dictates the mode
sub xmit_zwave_data {

    my ($self, $command, $expect_xmit, $expect_data, $blocking)=@_;

    $blocking = 0 unless $blocking;
    my $time = &::gettimeofday();

    &report ("xmit_zwave_data: state:$self->{state},cmd:$command time:$time bl:$blocking",1) if $command =~ />N/;

    &wait_for_interface_idle($self) if ($blocking && !($self->{state} eq 'idle'));

    $command =~ /(\d+)/;
    my $target_id = $1;
    if (!(($command =~ />DE/) or ($command =~ />AB/))) {
	&report("Error: can't find target id in command $command",1) unless $target_id;
	unless ($zwave_ids{$target_id}) {
	    &report("Error: Id $target_id not registered with interface",1);
	    $self->{cmd_failed} = 1;
	    return;
	}
    }

    &report("Debug: Writing data $command to Zwave interface",4);
	
    if ($self->{state} eq 'busy') {
	&report("Error: Can't execute command $command, interface busy", 1);        
	return;
    }

    $self->{command}     = $command;
    $command .= "\r";
    $self->{target_id}   = $target_id;
    $self->{device_busy} = 0;
    $self->{expect_data} = defined $expect_data ? $expect_data : 0;
    $self->{expect_xmit} = defined $expect_xmit ? $expect_xmit : 0;
    $self->{cmd_acked}   = 0;     # got command response
    $self->{retry_count} = 0 if !$self->{doing_retry}; # reset retry count if not retrying
    $self->{cmd_failed}  = 0;     # command failed
    $self->{xmit_acked}  = 0;     # got rf transmission ack
#    print "setting blocking to $blocking\n";
    $self->{blocking}    = $blocking;    # got rf transmission ack
    $self->{xmit_failed} = 0;     # rf transmission failed
    $self->{data_acked}  = 0;     # got response data 
    $self->{data}        = undef; # the response data itself
    $self->{last_found}  = undef; # result of find command (which we don't use yet)
    $self->{start_time}  = &::gettimeofday();  # time command was launched 
    # (for timeout calc)
    $self->{state} = 'busy';      # state of the interface
    $self->write_data($command);  # outgoing data
#    print "before wait: $self->{state}\n";
#    &wait_for_interface_idle($self) if $blocking;
    &wait_for_interface_idle($self) if ($blocking && !($self->{state} eq 'idle'));

}

sub report {
    my ($text,$level) = @_;
    &::print_log("$portname $text") if $::config_parms{rzc0p_errata} >= $level;
}

# do not remove the following line, packages must return a true value
1;
# =========== Revision History ==============
# Revision 1.0  -- 10/26/2007 -- David Satterfield
# - First Release
#
