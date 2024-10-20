=begin comment

Tasmota_HTTP_Item.pm

Basic Tasmota support using the HTTP interface rather than MQTT
Copyright (C) 2020 Jeff Siddall (jeff@siddall.name)
Last modified: 2021-02-22 to push, power, rrd and async support (hp)

CONFIG.INI
setting tasmota_sync=1 in config.ini will use a direct get rather than a Process_Item to prevent pauses in main loop 

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program.  If not, see <https://www.gnu.org/licenses/>.

This module currently supports Tasmota switch, power monitoring and fan type devices but other
devices can be added with extra packages

Requirements:

  The Tasmota device needs to be setup with a rule to send HTTP requests to MH
  if two-way communication is desired.  For example, a Sonoff Mini switch input
  can be sent to MH with the rule:
  Rule1 ON Power1#State DO WebSend [192.168.0.1:80] /SET;none?select_item=Kitchen_Light&select_state=%value% ENDON

  For Asynchronous setup, there are 2 rules (change mhip:port to the misterhouse ip address and port)
  NOTE: $main::Socket_Ports{http}{client_ip_address} is not reliable to get the true source IP address of the sender. Setting an ID
        on the device and in the rule increases the reliability of messages coming into the correct object. Replace [ID] with the value from the object option
  
  Rule1 ON Rules#Timer=1 DO BACKLOG WebSend [mhip:port] /SUB%3Btasmota_push(hb,[ID]); RuleTimer1 10 ENDON
  Rule1 4
  RuleTimer1 10
  
  * Rule 1 sends a 'heartbeat' web call every 10 seconds. If MH doesn't receive a heartbeat for a device within a minute, the
    device state is set to 'unknown'. This can be disabled with the nohb option
    
  Rule2 ON Power1#State DO WebSend [mhip:port] /SUB;tasmota_push(state,%value%,[ID]) ENDON
  
  * Rule 2 is a more generic web call. It doesn't require setting the tasmota device to the specific MH object. Instead
    The source address of the device is used to look up the proper MH object, or an ID is specified.
    
  *** IMPORTANT *** : the tasmota device needs to be set up with the IP address rather than a DNS name
  
  ----- Other Rules -----
  * Power Monitoring
  Rule3
   ON Energy#Power DO VAR1 %value% ENDON
   ON Energy#Current DO VAR2 %value% ENDON
   ON Margins#PowerDelta DO BACKLOG VAR3 1; RuleTimer2 1 ENDON
   ON VAR3#State > 6 0 DO BACKLOG RuleTimer2 0 ; VAR3 0 ENDON
   ON Rules#Timer=2 DO BACKLOG WebSend [mhip:port] /SUB%3Btasmota_push(power,%var1%,%var2%,[ID]); RuleTimer2 1; ADD3 1  ENDON

  PowerDelta 10
  VAR3 0
  
  * Rule 3 triggers when PowerDelta% power change has occurred. It then sends power data to MH for the next 5 seconds, to 
    ensure a proper reading is captured.



Setup:

In your code define Tasmota_HTTP::Things in an MHT:

  TASMOTA_HTTP_SWITCH,   192.168.x.y,   Kitchen_Light,   POWER1,   Kitchen, options
  
  where options are id=x (for specifying unique ID), sync (for sending a get directly in the loop), nohb (disable heartbeat checking), debug or rrd (for power monitoring)

Or in a code file:

 $Kitchen_Light = new Tasmota_HTTP::Switch("192.168.x.y", "POWER1");
 Where:
   192.168.x.y is the IPv4 address or hostname of the Tasmota device
   POWER1 is the name of the Tasmota output to control (POWER1 if not specified)

 $Kitchen_Light->set(ON);

=cut

#=======================================================================================
#
# Generic Tasmota_HTTP::Item
#
#=======================================================================================

# The Tasmota_HTTP::Item is a base item for other real devices (see below)

our $Tasmota_HTTP_Items ={}; #hash of addresses and device type used for push processing

package Tasmota_HTTP::Item;
use strict;
use parent 'Generic_Item';


use Data::Dumper;
use LWP::UserAgent ();
use JSON;
use URI::Escape;
	
# Item class constructor
sub new {
    my ( $class, $address, $output, $options ) = @_;

    # Call the parent class constructor to make sure all the important things are done
    my $self = new Generic_Item();
    bless $self, $class;

    # Additional Tasmota variables
    $self->{address}     = $address;

    $self->{async} = 1;
    $self->{async} = 0 if ($main::config_parms{tasmota_sync} or ($options =~ /sync/i));
    $self->{async} = 1 if ($main::config_parms{tasmota_async} or ($options =~ /async/i));

  
    $self->{loglevel} = 1; #show INFO messages
    $self->{debug} = 0;
    $self->{debug} = 1 if ($main::Debug{tasmota} or ($options =~ /debug/i));

    
    if (defined($output)) {
        $self->{output_name} = $output;
    } else {
        $self->{output_name} = 'POWER1';
    }
    $self->{ack}         = 0;
    $self->{last_http_status};

    if (( $options =~ m/nohb/i ) or ( $options =~ m/noheartbeat/i )) {
        $self->{heartbeat_enable} = 0;
        &main::print_log("[Tasmota_HTTP::Item] " . $self->{address} . " heartbeat check DISABLED" );   

    } else {
        $self->{heartbeat_enable} = 1;
        $self->{heartbeat_timestamp} = 0;
        $self->{heartbeat_timer} = new Timer;
        $self->{heartbeat_timer}->set(60);
        &main::print_log("[Tasmota_HTTP::Item] " . $self->{address} . " heartbeat check enabled with 60 second timeout" );   

    }
    my $mode = "synchronous get";
    
    if ($self->{async}) {
        @{ $self->{cmd_queue} } = ();
        $self->{max_cmd_queue}          = 6;
        $self->{max_cmd_queue}          = $main::config_parms{tasmota_max_cmd_queue}     if ( defined $main::config_parms{tasmota_max_cmd_queue} );;       
        $self->{cmd_data_file} = "$::config_parms{data_dir}/tasmota_cmd_" . $self->{address} . ".data";
        unlink "$::config_parms{data_dir}/tasmota_cmd_" . $self->{address} . ".data";
        $self->{cmd_process} = new Process_Item;
        $self->{cmd_process}->set_output( $self->{cmd_data_file} );
        &::MainLoop_post_add_hook( \&Tasmota_HTTP::Item::process_check, 0, $self ); #check for changes to output file, and then process results
        ( $self->{id} ) = ( $options =~ /id=(\d+)/i ) if ( ( defined $options ) and ( $options =~ m/id=/i ) );
        $Tasmota_HTTP_Items->{$self->{address}}->{object} = \%{$self};
        $Tasmota_HTTP_Items->{$self->{address}}->{type} = "generic";
        $Tasmota_HTTP_Items->{id}->{$self->{id}} = $self->{address};
        $mode = "asynchronous process_item";
    }
    my $id = "";
    $id = "(ID set to " . $self->{id} . ")" if ($self->{id});
    &main::print_log("[Tasmota_HTTP::Item] " . $self->{address} . " set for " . $mode . " data mode. " . $id );   

    return $self;
}

# Use HTTP get calls to set the Tasmota item, being sure to check that the set did not come
# from the device itself
sub set {
    my ( $self, $state, $set_by, $respond ) = @_;

    # Debug logging
    my $debug = $self->{debug} || $main::Debug{tasmota};
    if ( $set_by eq "push" ) {
            $self->SUPER::set( $state, $set_by, $respond );
    
    # Determine whether the update came from the Tasmota device itself and convert states
    # and record the set as an ack
    } elsif ( $set_by eq "web [$self->{address}]" ) {

        # Convert Tasmota states to MH states
        $state = $self->{tasmota_to_state}{$state};

        # If the current state is the same as the received state, and ack=0 then consider
        # this set an ack and do not update the state of the item
        if ( ( $state eq $self->{state} ) && ( $self->{ack} == 0 ) ) {
            &main::print_log("[Tasmota_HTTP::Item] DEBUG: Received ack from $self->{object_name} ($self->{address})") if $debug;
            $self->{ack} = 1;
        }
        else {
            &main::print_log("[Tasmota_HTTP::Item] DEBUG: Received set state to $state from $self->{object_name} ($self->{address})") if $debug;

            # Call the parent class set to make sure all the important things are done
            $self->SUPER::set( $state, $set_by, $respond );
        }

        # Only send an update to the device if the set did not come from the device to prevent
        # set loops
    } elsif ($self->{async}) {
    
        my $cmd = "$self->{output_name}%20$self->{state_to_tasmota}{$state}";
        $self->send_cmd($cmd);          

    } else {

        # Use a small timeout since devices are typically local and should respond quickly
        # 5 seconds should allow for 3 syn attempts plus another second to get a response
        my $ua = LWP::UserAgent->new( timeout => 5 );

        # Reset the ack flag
        $self->{ack} = 0;

        # Send the HTTP request
        my $response = $ua->get("http://$self->{address}/cm?cmnd=$self->{output_name}%20$self->{state_to_tasmota}{$state}");

        # Record the status of the last request
        $self->{last_http_status} = $response->status_line;

        # Log request failures
        if ( !$response->is_success ) {
            &main::print_log("[Tasmota_HTTP::Item] ERROR: Received HTTP response code $self->{last_http_status} from last command)");
        }

        # Call the parent class set to make sure all the important things are done
        $self->SUPER::set( $state, $set_by, $respond );
        &main::print_log("[Tasmota_HTTP::Item] DEBUG: Set $self->{object_name} state to $state") if $debug;
    }
}

sub send_cmd {
    my ($self,$cmnd) = @_;
    
    my $cmd = "get_url -response_code -status_line http://$self->{address}/cm?cmnd=$cmnd";
    if ($self->{cmd_process}->done()) {
        $self->{cmd_process}->set($cmd);
        $self->{cmd_process}->start();
    } else {
        &main::print_log("[Tasmota_HTTP::Item] $self->{address} INFO: last command has not finished. Queuing command $cmd") if ($self->{loglevel});   
    }
    push @{ $self->{cmd_queue} }, [$cmd,$main::Time,0];  
}   

# Use HTTP get calls to send a command to the Tasmota item
# returns the JSON response from the Tasmota and sets $self->{run_cmnd_response}
# it urlencodes the command so user doesnt need to
# if no command sent it decodes the json and returns the state of the device e.g.
# $device->run_cmnd() returns on or off
# $device->run_cmnd('status 10') returns a json string of the sensor status
# $device->run_cmnd('restart 1') reboots the Tasmota
# This is a synchronous call at this time

sub run_cmnd {
	my ( $self, $command ) = @_;

	# Debug logging
	my $debug = $self->{debug} || $main::Debug{tasmota};

	# Use a small timeout since devices are typically local and should respond quickly
	# 5 seconds should allow for 3 syn attempts plus another second to get a response
	my $ua = LWP::UserAgent->new( timeout => 5 );

	# Reset the ack flag
	$self->{ack} = 0;
	my $decode_JSON = 0;

	# Send the HTTP request
	if ( !defined($command) ) {
		$command     = $self->{output_name};
		$decode_JSON = 1;
	}
	# now URI encode the command
	$command = URI::Escape::uri_escape_utf8($command);

	my $response = $ua->get("http://$self->{address}/cm?cmnd=$command");

	# Record the status of the last request
	$self->{last_http_status} = $response->status_line;

	# Log request failures
	if ( !$response->is_success ) {
		&main::print_log("[Tasmota_HTTP::Item] ERROR: run_cmnd received HTTP response code $self->{last_http_status})");
	}

	$self->{run_cmnd_response}  = $response->decoded_content;

	if ($decode_JSON) {
		my $output_name = $self->{output_name};

		# oddly if you send POWER1 or POWER it returns POWER
		if ( $output_name eq "POWER1" ) {
			$output_name = "POWER";
		}
		my $jsonstatus = decode_json($self->{run_cmnd_response});
		$self->{run_cmnd_response} = lc( $jsonstatus->{$output_name} );
	}

	&main::print_log(
		"[Tasmota_HTTP::Item] DEBUG: " . substr( $self->{object_name}, 1 ) . " run_cmnnd returns " . $self->{run_cmnd_response},
		"INFORMATIONAL", "Tasmota_HTTP::Item" )
	  if $debug;

	return $self->{run_cmnd_response};
}

sub process_check {
    my ($self) = @_;
    
    if ( $self->{cmd_process}->done_now() ) {
        
        main::print_log( "[Tasmota_HTTP::Item] " . $self->{address} . " Command process completed" ) if ($self->{loglevel});

        my $file_data = &main::file_read( $self->{cmd_data_file} );

        my ($status) = $file_data =~ m/STATUSLINE\:(.*)\n/;
        my ($state) =  $file_data =~ m/\:\"([a-zA-Z0-9]+)\"}/;
        my ($power) = $file_data =~ m/\"Power\"\:(\d+\.?\d*)/;
        my ($current) = $file_data =~ m/\"Current\"\:(\d+\.?\d*)/;
        main::print_log( "[Tasmota_HTTP::Item] " . $self->{address} . " file_data=[" . $file_data . "]") if ($self->{debug});   
        main::print_log( "[Tasmota_HTTP::Item] " . $self->{address} . " status=$status state=$state power=$power current=$current") if ($self->{debug});   
       
        if ($status eq "200 OK") {
            if ($state) {
                $self->SUPER::set( $state, "process_check") unless (lc $state eq lc $self->state());
            }
            if ($power) {
                $self->update_power($power,$current);
            }
        }
        shift @{ $self->{cmd_queue} }; #successfully processed to remove item from the queue
        
        #check if there is a queue of items;
        if (scalar @{ $self->{cmd_queue}}) {
            my ($cmd, $time, $retry) = @ { ${ $self->{cmd_queue} }[0] };
            $self->{cmd_process}->set($cmd);
            $self->{cmd_process}->start();
        }
    }
    if ($self->{heartbeat_enable}) {

        if ($self->{heartbeat_timer}->expired()) {
            &main::print_log("[Tasmota_HTTP::Item] $self->{address} WARNING. Lost heartbeat. Device might be offline");
            $self->SUPER::set( 'unknown', 'heartbeat');
        }
    }
}

sub heartbeat {
    my ($self) = @_;

    return $self->{heartbeat_timestamp};
}

sub main::tasmota_push {
    my ($attribute,$value,$value2,$value3) = @_;
    my $id = "";
    
    if ($attribute eq "") {
        &main::print_log("[Tasmota_HTTP::Item] ERROR tasmota device sent unknown attribute");
        return "";
    } elsif ($attribute eq "state") {
        $id = $value2 if ($value2);
    } elsif ($attribute eq "hb") {
        $id = $value2 if ($value2);
    } elsif ($attribute eq "power") {    
        $id = $value3 if ($value3);
    }        

    my $client_ip_address = $main::Socket_Ports{http}{client_ip_address};
    $client_ip_address = $Tasmota_HTTP_Items->{id}->{$id} if ($Tasmota_HTTP_Items->{id}->{$id});
    my $type = $Tasmota_HTTP_Items->{$client_ip_address}->{type};
    if ($type) {
        my $debug =  $Tasmota_HTTP_Items->{$client_ip_address}->{object}->{debug};
        my $loglevel = $Tasmota_HTTP_Items->{$client_ip_address}->{object}->{loglevel};
        &main::print_log("[[Tasmota_HTTP::Item] webAPI client=$client_ip_address attribute=$attribute value=$value value2=$value2 value3=$value3 type=$type attribute=$attribute") if ($debug);
        
        if ($attribute eq "state") {
            my $state = $Tasmota_HTTP_Items->{$client_ip_address}->{object}->{tasmota_to_state}{$value};
            &main::print_log("[Tasmota_HTTP::Item] INFO Received state $state for tasmota device with IP address $client_ip_address") if ($debug);
            $Tasmota_HTTP_Items->{$client_ip_address}->{object}->set($state,'push');

        } elsif ($attribute eq "hb") {
            &main::print_log("[Tasmota_HTTP::Item] INFO Received heartbeat for tasmota device with IP address $client_ip_address") if ($debug);
            $Tasmota_HTTP_Items->{$client_ip_address}->{object}->{heartbeat_timer}->restart();
            $Tasmota_HTTP_Items->{$client_ip_address}->{object}->{heartbeat_timestamp} = $main::Time;
            $Tasmota_HTTP_Items->{$client_ip_address}->{object}->send_cmd($Tasmota_HTTP_Items->{$client_ip_address}->{object}->{output_name}) if (lc $Tasmota_HTTP_Items->{$client_ip_address}->{object}->state eq "unknown")
        }
        if ($type eq "switch_powermon") {
            if ($attribute eq "power") {
               &main::print_log("[Tasmota_HTTP::Item] INFO received power information for $client_ip_address. Power: $value Current: $value2") if ($debug);
               $Tasmota_HTTP_Items->{$client_ip_address}->{object}->update_power($value,$value2);
            } 
        }
    } else {
    
        &main::print_log("[Tasmota_HTTP::Item] wepAPI ERROR, could not find object associated with IP address $client_ip_address!") unless ($client_ip_address eq $main::Info{IPAddress_local}); #ignore the random calls from MH internal?
    
    }

 return "";
}

#=======================================================================================
#
# Basic Tasmota_HTTP::Switch
#
#=======================================================================================

# To add table support, add these lines to the read_table_A.pl file:
# elsif ( $type eq "TASMOTA_HTTP_SWITCH" ) {
#     require Tasmota_HTTP_Item;
#     ( $address, $name, $grouplist ) = @item_info;
#     $object = "Tasmota_HTTP::Switch('$address')";
# }

package Tasmota_HTTP::Switch;
use strict;
use parent-norequire, 'Tasmota_HTTP::Item';

# Switch class constructor
sub new {
    my $class = shift;

    # Call the parent class constructor to make sure all the important things are done
    my $self = $class->SUPER::new(@_);

    # Additional switch variables
    # Add additional hash pairs (rows) to this variable to send other states to devices
    $self->{state_to_tasmota} = {
        "off" => "0",
        "on"  => "1",
    };

    # Add additional hash pairs (rows) to this variable to use other states from devices
    $self->{tasmota_to_state} = {
        "0" => "off",
        "1" => "on",
    };

    # Initialize states
    push( @{ $self->{states} }, keys( %{ $self->{state_to_tasmota} } ) );

    # Log the setup of the item
    &main::print_log("[Tasmota_HTTP::Switch] Created item with address $self->{address}");
    $Tasmota_HTTP_Items->{$self->{address}}->{type} = "switch";
    return $self;
}

package Tasmota_HTTP::Switch_PowerMon;
use strict;
use parent-norequire, 'Tasmota_HTTP::Item';

# Switch class constructor
sub new {
    my ( $class, $address, $output, $options ) = @_;
    #my $class = shift;    
    # Call the parent class constructor to make sure all the important things are done
    my $self = $class->SUPER::new($address,$output,$options);

    # Additional switch variables
    # Add additional hash pairs (rows) to this variable to send other states to devices
    $self->{state_to_tasmota} = {
        "off" => "0",
        "on"  => "1",
    };

    # Add additional hash pairs (rows) to this variable to use other states from devices
    $self->{tasmota_to_state} = {
        "0" => "off",
        "1" => "on",
    };

    $self->{RRD} = 0;
    $self->{RRD} = 1 if ( $options =~ m/rrd/i );

    eval {
        require RRD::Simple;
        require RRDs;
    };
    if ($@) { 
        &main::print_log("[Tasmota_HTTP::Switch_PowerMon] Warning, RRD specified but RRD::Simple and/or RRDs are not found. Disabling RRD functionality");
        $self->{RRD} = 0;
    }
    
    if ($self->{RRD}) {
        
        mkdir($$::config_parms{data_dir} . "/rrd") unless (-d $::config_parms{data_dir} . "/rrd");
        $self->set_rrd($::config_parms{data_dir} . "/rrd/" . $self->{address} . ".rrd","power,current");
        unless ( -e $self->get_rrd()) {
            &main::print_log("[Tasmota_HTTP::Switch_PowerMon] $self->{address} Creating RRD file " . $self->get_rrd() . " for power usage");
            create_rrd($self->get_rrd());
        }
        &::MainLoop_post_add_hook( \&Tasmota_HTTP::Switch_PowerMon::update_rrd, 0, $self ); #check for $New_Minute and the update the RRD with the maximum value during the last minute
    }
    
    #initialize power values
    $self->{monitor}->{power} = 0;
    $self->{monitor}->{prevpower} = 0;
    $self->{monitor}->{maxpower} = 0;

    $self->{monitor}->{current} = 0;
    $self->{monitor}->{prevcurrent} = 0;
    $self->{monitor}->{maxcurrent} = 0;

    # Initialize states
    push( @{ $self->{states} }, keys( %{ $self->{state_to_tasmota} } ) );
    undef $self->{power_state_changed};
    $self->{power_state_changed_loop} = 0;

    # Log the setup of the item
    &main::print_log("[Tasmota_HTTP::Switch_PowerMon] Created item with address $self->{address}");
    $Tasmota_HTTP_Items->{$self->{address}}->{type} = "switch_powermon";
    &::MainLoop_post_add_hook( \&Tasmota_HTTP::Switch_PowerMon::reset_power_state, 0, $self ); #check for changes to output file, and then process results
    $self->send_cmd($self->{output_name}); #query the current state
    $self->send_cmd('status%208'); #query the current power usage
    return $self;
}

#this is to set 
sub reset_power_state {
    my ($self) = @_;
        if ($self->{power_state_changed}) {
            if ($self->{power_state_changed_loop}) { #wait for a loop to reset power_state_changed
                undef $self->{power_state_changed};
                $self->{power_state_changed_loop} = 0;
            } else {
                $self->{power_state_changed_loop} = 1;
            }
        }
}

sub update_rrd {
    my ($self) = @_;
    if ($main::New_Minute) {
        my $rrd = RRD::Simple->new( file => $self->get_rrd() );
        #Use maximum values in the minute to avoid the loss of any power spikes in that minute
        &main::print_log("[Tasmota_HTTP::PowerMon] $self->{address} Writing to RRD: power=" . $self->{monitor}->{maxpower} . " current=" . $self->{monitor}->{maxcurrent}) if ($self->{debug});
        
        #wrap this in a eval in case there's an issue with the RRD, don't want to bring down MH
        eval {
            $rrd->update(
                power => $self->{monitor}->{maxpower},
                current => $self->{monitor}->{maxcurrent}
            );
        };
        if ($@) {
            main::print_log( "[Tasmota_HTTP::PowerMon] " . $self->{address} . "] ERROR updating RRD! $@\n" );
        }
        #reset the maximum to the current power level
        $self->{monitor}->{maxpower} = $self->{monitor}->{power};
        $self->{monitor}->{maxcurrent} = $self->{monitor}->{current};
    }
}

sub update_power {
    my ($self,$power, $current) = @_;
    $self->{monitor}->{prevpower} = $self->{monitor}->{power};
    $self->{monitor}->{power} = $power;
    $self->{monitor}->{maxpower} = $power if ($self->{monitor}->{power} > $self->{monitor}->{maxpower});
    if ($self->{monitor}->{prevpower} == $self->{monitor}->{power}) {
        undef $self->{power_state_changed};
    } else {
        $self->{power_state_changed} = $power;
        $self->{power_state_changed} = "0E0" if ($self->{power_state_changed} == 0);
    }
    $self->{monitor}->{prevcurrent} = $self->{monitor}->{current};
    $self->{monitor}->{current} = $current;    
    $self->{monitor}->{maxcurrent} = $current if ($self->{monitor}->{current} > $self->{monitor}->{maxcurrent});
}

sub power {
    my ($self) = @_;
    return $self->{monitor}->{power};
}

sub power_changed {
    my ($self) = @_;
    return $self->{power_state_changed};
}

sub current {
    my ($self) = @_;
    return $self->{monitor}->{current};
}

sub power_factor {

}

sub create_rrd {
    my ($file) = @_;

    #create the RRD similar to the weather RRD configuration
    RRDs::create $file,
      '-b', $main::Time, '-s', 60,
      "DS:power:GAUGE:300:0:U",
      "DS:current:GAUGE:300:0:U",
      'RRA:AVERAGE:0.5:1:801',    # details for 6 hours (agregate 1 minute)
      'RRA:MIN:0.5:2:801',        # 1 day (agregate 2 minutes)
      'RRA:AVERAGE:0.5:2:801', 'RRA:MAX:0.5:2:801',
      'RRA:MIN:0.5:5:641',        # 2 day (agregate 5 minutes)
      'RRA:AVERAGE:0.5:5:641', 'RRA:MAX:0.5:5:641',
      'RRA:MIN:0.5:18:623',       # 1 week (agregate 18 minutes)
      'RRA:AVERAGE:0.5:18:623', 'RRA:MAX:0.5:18:623',
      'RRA:MIN:0.5:35:618',       # 2 weeks (agregate 35 minutes)
      'RRA:AVERAGE:0.5:35:618', 'RRA:MAX:0.5:35:618',
      'RRA:MIN:0.5:75:694',       # 1 month (agregate 1h15mn)
      'RRA:AVERAGE:0.5:75:694', 'RRA:MAX:0.5:75:694',
      'RRA:MIN:0.5:150:694',      # 2 months (agregate 2h30mn)
      'RRA:AVERAGE:0.5:150:694', 'RRA:MAX:0.5:150:694',
      'RRA:MIN:0.5:1080:268',     # 6 months (agregate 18 hours)
      'RRA:AVERAGE:0.5:1080:268', 'RRA:MAX:0.5:1080:268',
      'RRA:MIN:0.5:2880:209',     # 12 months (agregate 2 days)
      'RRA:AVERAGE:0.5:2880:209', 'RRA:MAX:0.5:2880:209',
      'RRA:MIN:0.5:4320:279',     # 2 years (agregate 3 days)
      'RRA:AVERAGE:0.5:4320:279', 'RRA:MAX:0.5:4320:279',
      'RRA:MIN:0.5:8640:334',     # 5 months (agregate 6 days)
      'RRA:AVERAGE:0.5:8640:334', 'RRA:MAX:0.5:8640:334';

    main::print_log( "[Tasmota_HTTP::PowerMon ] ERROR creating RRD $file!" ) if RRDs::error;
}

#=======================================================================================
#
# Basic Tasmota_HTTP::Fan
#
#=======================================================================================

# To add table support, add these lines to the read_table_A.pl file:
# elsif ( $type eq "TASMOTA_HTTP_FAN" ) {
#     require Tasmota_HTTP_Item;
#     ( $address, $name, $grouplist ) = @item_info;
#     $object = "Tasmota_HTTP::Fan('$address')";
# }

package Tasmota_HTTP::Fan;
use strict;
use parent-norequire, 'Tasmota_HTTP::Item';

# Switch class constructor
sub new {
    my $class = shift;

    # Call the parent class constructor to make sure all the important things are done
    my $self = $class->SUPER::new(@_);
    # Fans use a different output name
    $self->{output_name} = 'FanSpeed';

    # Additional fan variables
    # Add additional hash pairs (rows) to this variable to send other states to devices
    $self->{state_to_tasmota} = {
        "off" => "0",
        "0" => "0",
        "1" => "1",
        "2" => "2",
        "3" => "3",
        "on" => "3",
    };

    # Add additional hash pairs (rows) to this variable to use other states from devices
    $self->{tasmota_to_state} = {
        "0" => "off",
        "1" => "1",
        "2" => "2",
        "3" => "3",
    };

    # Initialize states
    push( @{ $self->{states} }, keys( %{ $self->{state_to_tasmota} } ) );

    # Log the setup of the item
    &main::print_log("[Tasmota_HTTP::Fan] Created item with address $self->{address}");
    $Tasmota_HTTP_Items->{$self->{address}}->{type} = "fan";
    
    return $self;
}

# Perl modules need to return true
1;
