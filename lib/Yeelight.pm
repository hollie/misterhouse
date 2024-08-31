=head1 B<yeelight> v1.4.3

=head2 Initial Setup
# To set up, first pair with mobile app -- the Yeelight needs to be set up initially with the app
# to get it's wifi information. 
# if problems with ios, use the android app if you can.
# MAKE SURE TO SELECT A 2.4Ghz WIRELESS NETWORK
# TURN ON LOCAL CONTROL

=head2 Firmware supported
# led strip (stripe)       : 44

=head2 Yeelight Objects

$yeelight         = new Yeelight('10.10.1.1');
$yeelight_comm    = new Yeelight_Comm($yeelight);
$yeelight_ct      = new Yeelight_Colortemp($yeelight);
$yeelight_rgb     = new Yeelight_RGB($yeelight);

 yeelight_rgb the set value is 'red, green, blue'
 ie $yeelight_rgb->set('255,10,32');



=head2 MH.INI CONFIG PARAMS

yeelight_timeout                TCP request timeout (default 5)
yeelight_max_cmd_queue          Maximum number of commands to queue up (default 8)
yeelight_com_threshold          Number of failed polls before controller marked offline (default 4)
yeelight_command_timeout        Number of seconds after a command is issued before it is abandoned (default 60)
yeelight_command_timeout_limit  Maximum number of retries for a command before abandoned
yeelight_ssdp_timeout           Maximum number of seconds to wait for SSDP data to return (default 1000)

=head2 Notes

The Yeelight needs to be specified as an IP address, since the module uses SSDP scan to determine
what features are supported

=head2 Issues
- retry time delay, should be based off process_item start not the original request time.

=head2 TODO
- test queuing fast commands
- check query data
- test socket reconnection
- test multi from state on
- test multi from state off
- comm tracker went offline when commands dropped
- 09/02/18 11:54:33 AM [Yeelight:1] WARNING. Queue has grown past 8. Command get_tcp -rn -quiet 192.168.0.173:55443 '{ "id":1, "method":"set_bright", "params":[90,"smooth",500] }' discarded.
- 09/02/18 11:54:33 AM [Yeelight:1] Communication Tracking object found. Updating from online to offline...
- comm device offline, didn't go online when data came back
- lost data and didn't reconnect
- check CPU usage for yeelight

=cut
our $yl_instances;
our $yl_ssdp_scanned;

package Yeelight;

use strict;
use warnings;

use LWP::UserAgent;
use HTTP::Request::Common qw(POST);
use JSON::XS;
use Data::Dumper;
use Socket;
use IO::Select;
use IO::Socket::INET;


@Yeelight::ISA = ('Generic_Item');

my %Socket_Items; #Stores the socket instances and attributes - taken from AD2.pm
# -------------------- START OF SUBROUTINES --------------------
# --------------------------------------------------------------

our %method;
$method{info}        = "\"get_prop\""; #power","bright","ct","rgb","hue","sat","color_mode","flowing","delayoff","flow_params","music_on","name","bg_power","bg_flowing","bg_flow_params","bg_ct","bg_lmode","bg_bright","bg_rgb","bg_hue","bg_sat","nl_br"]}\r\n);
$method{on}          = "\"set_power\"";
$method{off}         = "\"set_power\"";
$method{brightness}  = "\"set_bright\"";
$method{rgb}         = "\"set_rgb\"";
$method{hsv}         = "\"set_hsv\"";
$method{ct}          = "\"set_ct_abx\"";

my %param_array;
@{$param_array{info}}       = ('"power"','"bright"','"ct"','"rgb"','"hue"','"sat"','"color_mode"','"flowing"','"delayoff"','"flow_params"','"music_on"','"name"','"bg_power"','"bg_flowing"','"bg_flow_params"','"bg_ct"','"bg_lmode"','"bg_bright"','"bg_rgb"','"bg_hue"','"bg_sat"','"nl_br"');
@{$param_array{bright}}     = ('"smooth"',500);
@{$param_array{on}}         = ('"on"','"smooth"',500);
@{$param_array{off}}        = ('"off"','"smooth"',500);
@{$param_array{rgb}}        = ('"smooth"',500);
@{$param_array{ct}}         = ('"smooth"',500);

our %active_yeelights = ();

sub new {
    my ( $class, $location, $options ) = @_;
    my $self = new Generic_Item();
    bless $self, $class;
    
    unless (defined $yl_instances) {
        $self->{id}   = "1";
        $self->{name} = "1";
        $yl_instances = 1;
    } else {
        $yl_instances++;
        $self->{id} = $yl_instances;
        $self->{name} =  $yl_instances;
    }

    $self->{data}                   = undef;
    $self->{child_object}           = undef;

    $self->{updating}               = 0;
    $self->{data}->{retry}          = 0;
    $self->{status}                 = "";
    $self->{module_version}         = "v1.4";
    $self->{ssdp_timeout}           = 1000;
    $self->{ssdp_timeout}           = $main::config_parms{yeelight_ssdp_timeout} if ( defined $main::config_parms{yeelight_ssdp_timeout} );

    $self->{socket_connected}       = 0;
    $self->{host}                   = $location;
    $self->{port}                   = 55443;
    $self->{brightness_state_delay} = 1;
    $self->{command_timeout_limit}  = 4;   
    $self->{command_timeout_limit}  = $main::config_parms{yeelight_max_cmd_queue} if ( defined $main::config_parms{yeelight_max_cmd_queue} );

    if ($location =~ m/:/) {
        ($self->{host}, $self->{port}) = $location =~ /(.*):(.*)/;
    } 
     
    $options = "" unless ( defined $options );
    $options = $::config_parms{ "yeelight_" . $location . "_options" } if ( $::config_parms{ "yeelight_" . $location . "_options" } );

    $self->{debug} = 0;
    ( $self->{debug} ) = ( $options =~ /debug\=(\d+)/i ) if ( $options =~ m/debug\=/i );
    $self->{debug} = 0 if ( $self->{debug} < 0 );

    $self->{loglevel} = 5;
    ( $self->{loglevel} ) = ( $options =~ /loglevel\=(\d+)/i ) if ($options =~ m/loglevel\=/i );

    $self->{timeout}                 = 5;
    $self->{timeout}                 = $main::config_parms{yeelight_timeout} if ( defined $main::config_parms{yeelight_timeout} );

    $self->{poll_data_timestamp}     = 0;
    $self->{max_poll_queue}          = 3;
    
    $self->{max_cmd_queue}           = 8;
    $self->{max_cmd_queue}                = $main::config_parms{yeelight_max_cmd_queue} if ( defined $main::config_parms{yeelight_max_cmd_queue} );
    
    $self->{cmd_process_retry_limit} = 6;
    $self->{cmd_process_retry_limit} = $main::config_parms{yeelight_command_timeout_limit} if ( defined $main::config_parms{yeelight_command_timeout_limit} );

    $self->{command_timeout}         = 60;
    $self->{command_timeout}                = $main::config_parms{yeelight_command_timeout} if ( defined $main::config_parms{yeelight_command_timeout} );

    @{ $self->{poll_queue} } = ();
    $self->{poll_data_file} = "$::config_parms{data_dir}/Yeelight_poll_" . $location . ".data";
    unlink "$::config_parms{data_dir}/Yeelight_poll_" . $location . ".data";
    $self->{poll_process} = new Process_Item;
    $self->{poll_process}->set_output( $self->{poll_data_file} );
    @{ $self->{cmd_queue} } = ();
    $self->{cmd_data_file} = "$::config_parms{data_dir}/Yeelight_cmd_" . $location . ".data";
    unlink "$::config_parms{data_dir}/Yeelight_cmd_" . $location . ".data";
    $self->{cmd_process} = new Process_Item;
    $self->{cmd_process}->set_output( $self->{cmd_data_file} );
    $self->{init}      = 0 unless ($self->{init});
    $self->{init_data} = 0;
    $self->{init_v_cmd} = 0;
    
    $self->server_startup unless (defined $Socket_Items{"$self->{id}"}{recon_timer});
    &::MainLoop_post_add_hook( \&Yeelight::process_check, 0, $self );
    &::Reload_post_add_hook( \&Yeelight::generate_voice_commands, 1, $self );
    #push( @{ $$self{states} }, 'off', '10%', '20%', '30%', '40%', '50%', '60%', '70%', '80%', '90%', 'on' );
    push( @{ $$self{states} }, 'off');
    for my $i (0..100) { push @{ $$self{states} }, "$i%"; }
    push( @{ $$self{states} }, 'on');
    $self->{timer} = new Timer;    
    $self->get_data();    
    return $self;
}

sub server_startup {
   my ($self) = @_;

   $Socket_Items{"yeelight_$self->{id}"}{recon_timer} = ::Timer::new();
   main::print_log("[Yeelight]   STARTUP: initializing instance yeelight_$self->{id} TCP session on $self->{host}:$self->{port}");
   $Socket_Items{"yeelight_$self->{id}"}{'socket'} = new Socket_Item(undef, undef, "$self->{host}:$self->{port}", "yeelight_$self->{id}", 'tcp', 'raw');
   #$Socket_Items{"yeelight_$self->{id}"}{'socket'} = new Socket_Item(undef, undef, "$self->{host}:$self->{port}", "yeelight_$self->{name}", 'tcp', 'raw');
   #$Socket_Items{"yeelight_$self->{id}"}{'socket'}->start;
   ::MainLoop_pre_add_hook( \&Yeelight::check_for_socket_data, 1, $self );
   # $self->{data_socket} = new Socket_Item(undef, undef, "$self->{host}:$self->{port}", "yeelight" . $self->{id}, 'tcp', 'raw');
   # $self->{recon_timer} = new Timer;
    $self->{reconnect_time} = 10;  
   # &::MainLoop_post_add_hook( \&Yeelight::check_for_socket_data, 0, $self );    
     
}


sub check_for_socket_data {
    my ($self) = @_;

    my $rec_data;
    my $com_status = "offline";
      if ($Socket_Items{"yeelight_$self->{id}"}{'socket'}->active) {
         $rec_data = $Socket_Items{"yeelight_$self->{id}"}{'socket'}->said;
      } else {
         # restart the TCP connection if its lost.
         if (($Socket_Items{"yeelight_$self->{id}"}{recon_timer}->inactive) and ($self->{init})) {
            main::print_log("Connection to yeelight_$self->{id} instance of Yeelight was lost, I will try to reconnect in $$self{reconnect_time} seconds");
            $Socket_Items{"yeelight_$self->{id}"}{recon_timer}->set($$self{reconnect_time}, sub {
               $Socket_Items{"yeelight_$self->{id}"}{'socket'}->start;
            });
         }
      }

   # Return if nothing received
   #return if !$rec_data;
   
    if ($rec_data) {
        $self->{socket_connected} = 1;
        $com_status = "online";
        return if ($rec_data eq "");
        $rec_data =~ s/\r\n//g;
        print "debug: rec_data=$rec_data\n" if ( $self->{debug} > 2);
        my ($json_data) = $rec_data =~ /({.*})/;
        print "debug: json_data=$json_data\n" if ( $self->{debug} > 2);
        unless ( ($rec_data) and ($json_data) ) {
            main::print_log( "[Yeelight:" . $self->{name} . "] ERROR! bad data returned by socket" );
            main::print_log( "[Yeelight:" . $self->{name} . "] ERROR! received data is [$rec_data]. json data is [$json_data]" );
            $com_status = "offline";
        } else {
            my $data;
            main::print_log( "[Yeelight:" . $self->{name} . "] Data Received [$rec_data]" )  if ( $self->{debug} );
        
            eval { $data = JSON::XS->new->decode($json_data); };

            # catch crashes:
            if ($@) {
                main::print_log( "[Yeelight:" . $self->{name} . "] ERROR! JSON data parser crashed! $@\n" );
            } else {
                if ($data->{method} eq "props") {
                    foreach my $key (keys %{$data->{params}}) {
                        $self->{data}->{info}->{$key} = $data->{params}->{$key};                    
                    }
                    $self->process_data();
                } else {
                    main::print_log( "[Yeelight:" . $self->{name} . "] ERROR. Expected method props, recieved $data-{method}" );   
                }
            }
        }

    } 
#TODO 259 & 260 give uninitialized value errors.
    if ( defined $self->{child_object}->{comm} ) {
        if (( $self->{status} ne $com_status ) or ($self->{child_object}->{comm}->state() ne $com_status)) {
            $self->{status} = $com_status;
            if ($self->{child_object}->{comm}->state() ne $com_status) {
                main::print_log "[Yeelight:" . $self->{name} . "] 1 Communication Tracking object found. Updating from " . $self->{child_object}->{comm}->state() . " to " . $com_status . "..." if ( $self->{loglevel} );
                $self->{child_object}->{comm}->set( $com_status, 'poll' );
            }
        }
    }
}

sub get_data {
    my ($self) = @_;
    my $com_status = "online";

    main::print_log( "[Yeelight:" . $self->{name} . "] get_data initiated" ) if ( $self->{debug} );
    
    #Check that we have data

    if ( $self->{init} == 0 ) {
        main::print_log( "[Yeelight:" . $self->{name} . "] Contacting Yeelight for configuration details..." );
        $self->get_ssdp_data($self->{ssdp_timeout});             
    }

    if ( $self->{data}->{info}->{Location} ) {

        if ( ( defined $self->{data}->{info}->{model} ) and ( $self->{init} == 0 ) ) {
            main::print_log( "[Yeelight:" . $self->{name} . "] " . $self->{module_version} . " Configuration Found. Starting Server Socket..." );
            $active_yeelights{ $self->{host} } = 1;
            $self->print_info();
            $self->{init} = 1;
            $self->process_data();
            #$self->{data_socket}->start();
            $Socket_Items{"yeelight_$self->{id}"}{'socket'}->start;

        }

    }
    else {
        main::print_log( "[Yeelight:" . $self->{name} . "] WARNING, Did not find Yeelight data, retrying..." );
        $self->{timer}->set( 10, sub { &Yeelight::get_data($self) });
        $com_status = "offline";
    }

    if ( defined $self->{child_object}->{comm} ) {
        if (( $self->{status} ne $com_status ) or ($self->{child_object}->{comm}->state() ne $com_status)) {
            $self->{status} = $com_status;
            if ($self->{child_object}->{comm}->state() ne $com_status) {
                main::print_log "[Yeelight:" . $self->{name} . "] Communication Tracking object found. Updating from " . $self->{child_object}->{comm}->state() . " to " . $com_status . "..." if ( $self->{loglevel} );
                $self->{child_object}->{comm}->set( $com_status, 'poll' );
            }
        }
    } 
    
}

sub process_check {
    my ($self) = @_;
    my $com_status = $self->{status};

    return unless ( defined $self->{poll_process} );

    if ( $self->{poll_process}->done_now() ) {
    
        @{ $self->{poll_queue} } = ();      #clear the queue since process is done.

        $com_status = "online";
        main::print_log( "[Yeelight:" . $self->{name} . "] Background poll " . $self->{poll_process_mode} . " process completed" ) if ( $self->{debug} );

        my $file_data = &main::file_read( $self->{poll_data_file} );

        return unless ($file_data);    #if there is no data, then don't process
        if ( $file_data =~ m/^get_tcp_error:/i ) {
            main::print_log( "[Yeelight:" . $self->{name} . "] Data retrieval error: $file_data" );
            return;
        }

        # Clean out the characters before and after the json since the parser can crash
        print "debug: file_data=$file_data\n" if ( $self->{debug} > 2);
        my ($json_data) = $file_data =~ /({.*})/;
        print "debug: json_data=$json_data\n" if ( $self->{debug} > 2);
        unless ( ($file_data) and ($json_data) ) {
            main::print_log( "[Yeelight:" . $self->{name} . "] ERROR! bad data returned by query" );
            main::print_log( "[Yeelight:" . $self->{name} . "] ERROR! file data is [$file_data]. json data is [$json_data]" );
            return;
        }
        my $data;
        eval { $data = JSON::XS->new->decode($json_data); };

        # catch crashes:
        if ($@) {
            main::print_log( "[Yeelight:" . $self->{name} . "] ERROR! JSON file parser crashed! $@\n" );
            $com_status = "offline";
        }
        else {
            if ( keys %{$data} ) {

                my $index = 0;
                foreach my $item (@{$param_array{info}}) {
                    #$self->{data}->{info}->{power} 
                    $self->{data}->{info}->{$item} = $data->{result}[$index] unless ($data->{result}[$index] eq "");
                    print "poll process debug: index=$index " . '$self->{data}->{info}->{' . $item . "} = $data->{result}[$index] \n" if ( $self->{debug} > 2);
                    $index++;
                }

                $self->process_data();
            }
            else {
                main::print_log( "[Yeelight:" . $self->{name} . "] ERROR! Returned data not structured! Not processing..." );
                $com_status = "offline";
            }
        }

    }

    return unless ( defined $self->{cmd_process} );
    
    if ( $self->{cmd_process}->done_now() ) {
        main::print_log( "[Yeelight:" . $self->{name} . "] Background Command " . $self->{cmd_process_mode} . " process completed" ) if ( $self->{debug} );

        my $file_data = &main::file_read( $self->{cmd_data_file} );
        $com_status = "online";

        if ($file_data) {

            #for some reason get_url adds garbage to the output. Clean out the characters before and after the json
            print "debug: file_data=$file_data\n" if ( $self->{debug} > 2);
            my ($json_data) = $file_data =~ /({.*})/;
            print "debug: json_data=$json_data\n" if ( $self->{debug} > 2);
            my $data;
            eval { $data = JSON::XS->new->decode($json_data); };

            # catch crashes:
            if ($@) {
                main::print_log( "[Yeelight:" . $self->{name} . "] ERROR! JSON file parser crashed! $@\n" );
                ${ $self->{cmd_queue} }[0][2]++;
                $com_status = "offline";
            }
            else {

                if ($data->{result}[0] eq 'ok') {
                    shift @{ $self->{cmd_queue} };    #remove the command from queue since it was successful
                    $com_status = "online";

                } else {
                    main::print_log( "[Yeelight:" . $self->{name} . "] Last command failed with code ." .$data->{result}[0] . "! Going to retry" );
                    ${ $self->{cmd_queue} }[0][2]++;
                    $com_status = "offline";
                }
            }
        }
    }

    if (( scalar @{ $self->{cmd_queue} } ) and ($self->{cmd_process}->done()))  {
        my ($cmd, $time, $retry) = @ { ${ $self->{cmd_queue} }[0] };
        #print "***         cmd=$cmd, time=$time, retry=$retry\n";
        if ($retry > $self->{command_timeout_limit}) {
            main::print_log( "[Yeelight:" . $self->{name} . "] ERROR: Abandoning command $cmd due to $retry retry attempts" );
            shift @{ $self->{cmd_queue}};        
        } elsif (($main::Time - $time) > $self->{command_timeout}) {
            main::print_log( "[Yeelight:" . $self->{name} . "] ERROR: $cmd request older than " . $self->{command_timeout} ." seconds. Abandoning request" );
            shift @{ $self->{cmd_queue}}; 
        } elsif ($main::Time > ($time + 1 + ($retry * 5)) and ($self->{cmd_process}->done() )) { #the original time isn't a great base for deep queued commands
            if ($retry == 0) {
                main::print_log( "[Yeelight:" . $self->{name} . "] Command Queue found, processing next item" );
            } else {
                main::print_log( "[Yeelight:" . $self->{name} . "] Retrying previous command. Attempt number $retry" );
            }     
            $self->{cmd_process}->set($cmd);
            $self->{cmd_process}->start();            
            main::print_log( "[Yeelight:" . $self->{name} . "] Command Queue (" . $self->{cmd_process}->pid() . ") cmd=$cmd" ) if ( $self->{debug} );
        }
    }
                
    if ( defined $self->{child_object}->{comm} ) {
        if ( $self->{status} ne $com_status ) {
            $self->{status} = $com_status;
            if ($self->{child_object}->{comm}->state() ne $com_status) {
                main::print_log "[Yeelight:" . $self->{name} . "] Communication Tracking object found. Updating from " . $self->{child_object}->{comm}->state() . " to " . $com_status . "..." if ( $self->{loglevel} );
                $self->{child_object}->{comm}->set( $com_status, 'poll' );
            }
        }
    }
}

#TODO ADD VOICE COMMAND

#query subroutine. Used for voice command to refresh state if things get out of sync
sub _get_TCP_data {
    my ( $self, $mode, $params ) = @_;
    #{"id":1,"method":"get_prop","params":["power","bright","ct","rgb","hue","sat","color_mode","flowing","delayoff","flow_params","music_on","name","bg_power","bg_flowing","bg_flow_params","bg_ct","bg_lmode","bg_bright","bg_rgb","bg_hue","bg_sat","nl_br"]}\r\n);
    my $cmdline = "{\"id\":" . $self->{id} . ",\"method\":" . $method{$mode} . ",\"params\":[";
    $cmdline .= join(',', @{$param_array{$mode}});
    $cmdline .= "]}";
    my $options = "-timeout " . $self->{timeout} . " -rn -quiet ";
    my $cmd = "get_tcp " . $options . " " . $self->{host} . ":" . $self->{port} . " '" . $cmdline . "'";
    if ( $self->{poll_process}->done() ) {
        $self->{poll_process}->set($cmd);
        $self->{poll_process}->start();
        $self->{poll_process_pid}->{ $self->{poll_process}->pid() } = $mode;    #capture the type of information requested in order to parse;
        $self->{poll_process_mode} = $mode;
        main::print_log( "[Yeelight:" . $self->{name} . "] Backgrounding " . $self->{poll_process}->pid() . " command $mode, $cmd" ) if ( $self->{debug} );
    } else {
        main::print_log( "[Yeelight:" . $self->{name} . "] Query request already in progress" )
    }
}

#command process
sub _push_TCP_data {
    my ( $self, $mode, @params ) = @_;

    #check if socket is open
#    main::print_log( "[Yeelight:" . $self->{name} . "] 

    my $cmdline = "{ \"id\":" . $self->{id} . ", \"method\":" . $method{$mode} . ", \"params\":[";
    $cmdline .= join(',',@params);
    $cmdline .= "] }";
    my $options = "-timeout " . $self->{timeout} . " -rn -quiet ";
    my $cmd = "get_tcp " . $options . " " . $self->{host} . ":" . $self->{port} . " '" . $cmdline . "'";

    if ( $self->{cmd_process}->done() ) {
        $self->{cmd_process}->set($cmd);
        $self->{cmd_process}->start();
        $self->{cmd_process_pid}->{ $self->{cmd_process}->pid() } = $mode;    #capture the type of information requested in order to parse;
        $self->{cmd_process_mode} = $mode;
        push @{ $self->{cmd_queue} }, [$cmd,$main::Time,0];           

        main::print_log( "[Yeelight:" . $self->{name} . "] Backgrounding (" . $self->{cmd_process}->pid() . ") command $mode, $cmd" ) if ( $self->{debug} );
    }
    else {
        if ( scalar @{ $self->{cmd_queue} } < $self->{max_cmd_queue} ) {
            main::print_log( "[Yeelight:" . $self->{name} . "] Queue is " . scalar @{ $self->{cmd_queue} } . ". Queing command $mode, $cmd" ) if ( $self->{debug} );
            push @{ $self->{cmd_queue} }, [$cmd,$main::Time,0];           
        }
        else {
            main::print_log( "[Yeelight:" . $self->{name} . "] WARNING. Queue has grown past " . $self->{max_cmd_queue} . ". Command $cmd discarded." );
#            if ( defined $self->{child_object}->{comm} ) {
#                if ( $self->{status} ne "offline" ) {
#                    $self->{status} = "offline";
#                    if ($self->{child_object}->{comm}->state() ne "offline" ) {
#                        main::print_log "[Yeelight:" . $self->{name} . "] Communication Tracking object found. Updating from " . $self->{child_object}->{comm}->state() . " to offline..." if ( $self->{loglevel} );
#                        $self->{child_object}->{comm}->set( "offline", 'poll' );
#                    }
#                }
#            }
        }
    }
}

sub get_ssdp_data {
    my ( $self, $id, $timeout ) = @_;

    my ( $data ) = scan_ssdp_data($timeout);
    if (defined $data and defined $data->{$self->{host}}) {
        &main::print_log( "[Yeelight:" . $self->{name} . "] SSDP scan found device $self->{host}!");    
        $self->{data}->{info} = $data->{$self->{host}};

    } else {
        &main::print_log( "[Yeelight:" . $self->{name} . "] Warning, SSDP did not locate yeelight $self->{host}. Retrying.");
    }
    return;
}

sub scan_ssdp_data {
    my ($timeout) = @_;
    $timeout = 500 unless ($timeout);
    my %yl = ();
    
    my $CAST = '239.255.255.250';
    my $PORT = 1982;
    ################################################################################
    my $msg =<<SSDP;
M-SEARCH * HTTP/1.1
HOST: 239.255.255.250:1982
MAN: "ssdp:discover"
ST: wifi_bulb
MX: 3

SSDP

    $msg =~ s/\r?\n/\r\n/g;
    ################################################################################
    my $sock;
    my $addr = pack_sockaddr_in($PORT, inet_aton($CAST));
    socket($sock, AF_INET, SOCK_DGRAM, 0);
    setsockopt($sock, SOL_SOCKET, SO_BROADCAST, 1);
    bind($sock, pack_sockaddr_in(0, INADDR_ANY));
    send($sock, $msg, 0, $addr);

    my $sel = new IO::Select;
    $sel->add($sock);

    my $data;
    my $i;
    my $count = 0;
    my %locations = ();
    &main::print_log( "[Yeelight] Discovering >" ) unless ($yl_ssdp_scanned);
    while ($i++ < $timeout) {
        select undef, undef, undef, .1;

        my @ready = $sel->can_read(2);
        last unless scalar @ready;

        recv($sock,$data, 65536,0);
        my ($location) = $data =~ /Location:\syeelight:\/\/(.*)/;
        $location =~ s/[^a-zA-Z0-9\:\.\/]*//g;
        if (($location) and (! defined $locations{$location})) {
            $locations{$location} = 1;
            $count++;
             my ($host, $port) = $location =~ /(.*):(.*)/;
             $yl{$host}->{host} = $host;
             $yl{$host}->{port} = $port; 
             &main::print_log( "[Yeelight] Found Yeelight $count (location $location)") unless ($yl_ssdp_scanned);
               
             #Go through the rest of the data 
             foreach my $line (split(/\n/,$data)) {
                my ($field, $value) = $line =~ /(.*)\:\s+(.*)/;
                next if (!defined $field or $field =~ m/^Location:/);
                next unless ($value);
                $value =~ s/[^a-zA-Z 0-9\:\.\/]*//g;
                if ($field eq "support") {
                    @{$yl{$host}->{features}} = split(/ /,$value);
                } else {
                    $yl{$host}->{$field} = $value;
                }
            }
            $yl{$host}->{name} = "" unless (defined $yl{$host}->{name});
        }
    }
    $yl_ssdp_scanned = $count;
    return \%yl;    
    }


sub register {
    my ( $self, $object, $type ) = @_;

    $self->{child_object}->{$type} = $object;
    my ($red, $green, $blue) = $self->get_rgb($self->{data}->{info}->{rgb});
       
    if (lc $type eq "rgb") {
        $self->{child_object}->{rgb}->set("$red, $green, $blue", 'poll' ) if (defined $red);
    } elsif (lc $type eq "ct") {
        $self->{child_object}->{ct}->set($self->{data}->{info}->{ct}, 'poll' ) if (defined $self->{data}->{info}->{ct});  
    }          
    
    &main::print_log( "[Yeelight:" . $self->{name} . "] Registered $type child object" );

}

sub print_info {
    my ($self) = @_;
    my $name = $self->{data}->{info}->{name};
    $name = "Not Set" if ($self->{data}->{info}->{name} eq "");
    
    main::print_log( "[Yeelight:" . $self->{name} . "] *******************************************************" );
    main::print_log( "[Yeelight:" . $self->{name} . "] * Note: Yeelight.pm is now depreciated in favour      *");
    main::print_log( "[Yeelight:" . $self->{name} . "] *       of using Home Assistant for device access     *" );
    main::print_log( "[Yeelight:" . $self->{name} . "] *******************************************************" );
    main::print_log( "[Yeelight:" . $self->{name} . "] Name:              " . $name );
    main::print_log( "[Yeelight:" . $self->{name} . "] Model:             " . $self->{data}->{info}->{model} );
    main::print_log( "[Yeelight:" . $self->{name} . "] Firmware:          " . $self->{data}->{info}->{fw_ver} );
   

    main::print_log( "[Yeelight:" . $self->{name} . "] MH Module version: " . $self->{module_version} );
    main::print_log( "[Yeelight:" . $self->{name} . "] *** DEBUG MODE ENABLED ***") if ( $self->{debug} );

    main::print_log( "[Yeelight:" . $self->{name} . "] -- Current Settings --" );

    main::print_log( "[Yeelight:" . $self->{name} . "]    State:\t\t " . $self->{data}->{info}->{power}  );
    if ($self->{data}->{info}->{color_mode} == 1) {
        main::print_log( "[Yeelight:" . $self->{name} . "]    Color Mode:\t rgb mode");
    } elsif ($self->{data}->{info}->{color_mode} == 2) {
        main::print_log( "[Yeelight:" . $self->{name} . "]    Color Mode:\t color temperature mode");
    } elsif ($self->{data}->{info}->{color_mode} == 3) {
        main::print_log( "[Yeelight:" . $self->{name} . "]    Color Mode:\t hsv mode");
    } else {
        main::print_log( "[Yeelight:" . $self->{name} . "]    Color Mode:\t Unknown mode: " . $self->{data}->{info}->{color_mode});
    }
    main::print_log( "[Yeelight:" . $self->{name} . "]    Brightness:\t " . $self->{data}->{info}->{bright} );
    #rgb = red * 65536 + green * 256 + blue
    my ($r_red, $r_green, $r_blue) = $self->get_rgb();
    main::print_log( "[Yeelight:" . $self->{name} . "]    RGB:\t\t " . $self->{data}->{info}->{rgb} );
    main::print_log( "[Yeelight:" . $self->{name} . "]    \t Red:  " . $r_red );
    main::print_log( "[Yeelight:" . $self->{name} . "]    \t Green:" . $r_green );
    main::print_log( "[Yeelight:" . $self->{name} . "]    \t Blue: " . $r_blue );
    
    main::print_log( "[Yeelight:" . $self->{name} . "]    Hue:\t\t  " . $self->{data}->{info}->{hue} );
    main::print_log( "[Yeelight:" . $self->{name} . "]    Saturation:\t  " . $self->{data}->{info}->{sat} );
    main::print_log( "[Yeelight:" . $self->{name} . "]    Color Temp:\t  " . $self->{data}->{info}->{ct} );
    main::print_log( "[Yeelight:" . $self->{name} . "] -- Enabled Features --" );

    foreach my $feature ( @{ $self->{data}->{info}->{features} } ) {
        main::print_log( "[Yeelight:" . $self->{name} . "]   - $feature" );
    }
    
}

sub process_data {
    my ($self) = @_;


    # Main core of processing
    # set state of self for state
    # for any registered child selfs, update their state if changed

    main::print_log( "[Yeelight:" . $self->{name} . "] Processing Data..." ) if ( $self->{debug} );

    if ( ( !$self->{init_data} ) and ( defined $self->{data}->{info} ) ) {
        main::print_log( "[Yeelight:" . $self->{name} . "] Init: Setting startup values" );

        foreach my $key ( keys %{$self->{data}->{info}} ) {
            $self->{previous}->{info}->{$key} = $self->{data}->{info}->{$key};
        }
        
        if ( ( $self->{data}->{info}->{power} eq 'on') and ( $self->{data}->{info}->{bright} != 100 ) ) {
            $self->set( $self->{data}->{info}->{bright}, 'poll' );
        }
        else {
            $self->set( $self->{data}->{info}->{power}, 'poll' );
        }
        
        $self->{init_data} = 1;
    }

    if ( $self->{previous}->{info}->{fw_ver} ne $self->{data}->{info}->{fw_ver} ) {
        main::print_log(
            "[Yeelight:" . $self->{name} . "] Firmware changed from $self->{previous}->{info}->{fw_ver} to $self->{data}->{info}->{fw_ver}" );
        main::print_log( "[Yeelight:" . $self->{name} . "] This really isn't a regular operation. Should check Yeelight to confirm" );
        $self->{previous}->{info}->{fw_ver} = $self->{data}->{info}->{fw_ver};
    }

    if ( $self->{previous}->{info}->{name} ne $self->{data}->{info}->{name} ) {
        main::print_log( "[Yeelight:" . $self->{name} . "] Device Name changed from $self->{previous}->{info}->{name} to $self->{data}->{info}->{name}" );
        $self->{previous}->{info}->{name} = $self->{data}->{info}->{name};
    }

    if ( $self->{previous}->{info}->{power} ne $self->{data}->{info}->{power} ) {
        main::print_log( "[Yeelight:" . $self->{name} . "] State changed from $self->{previous}->{info}->{power} to $self->{data}->{info}->{power}" ) if ( $self->{loglevel} );
        $self->{previous}->{info}->{power} = $self->{data}->{info}->{power};

        #if on and brightness not 100 set brightness else set on or off
        if ( ( $self->{data}->{info}->{power} eq "on" ) and ( $self->{data}->{info}->{bright} != 100 ) ) {
            $self->set( $self->{data}->{info}->{bright}, 'poll' );
        }
        else {
            $self->set( $self->{data}->{info}->{power}, 'poll' );
        }
    }

    if ( $self->{previous}->{info}->{bright} != $self->{data}->{info}->{bright} ) {
        main::print_log( "[Yeelight:" . $self->{name} . "] Brightness changed from $self->{previous}->{info}->{bright} to $self->{data}->{info}->{bright}" ) if ( $self->{loglevel} );
        $self->{previous}->{info}->{bright} = $self->{data}->{info}->{bright};
        $self->set( $self->{data}->{info}->{bright}, 'poll' );
    }

#TODO Colormode child object / method
    if ( $self->{previous}->{info}->{color_mode} != $self->{data}->{info}->{color_mode} ) {
        main::print_log( "[Yeelight:" . $self->{name} . "] State Color Mode changed from $self->{previous}->{info}->{color_mode} to $self->{data}->{info}->{color_mode}" ) if ( $self->{loglevel} );
        $self->{previous}->{info}->{color_mode} = $self->{data}->{info}->{color_mode};
    }

    if ( $self->{previous}->{info}->{rgb} != $self->{data}->{info}->{rgb} ) {
        main::print_log( "[Yeelight:" . $self->{name} . "] RGB value changed from $self->{previous}->{info}->{rgb} to $self->{data}->{info}->{rgb}" ) if ( $self->{loglevel} );
        $self->{previous}->{info}->{rgb} = $self->{data}->{info}->{rgb};
        $self->{set_time} = $main::Time; #since we want updates if the color changes
        my ($red, $green, $blue) = $self->get_rgb($self->{data}->{info}->{rgb});
        
        if ( defined $self->{child_object}->{rgb} ) {
            main::print_log "[Yeelight:" . $self->{name} . "] RGB Child object found. Updating..." if ( $self->{loglevel} );        
            $self->{child_object}->{rgb}->set("$red, $green, $blue", 'poll' );
        }
    }

    if ( $self->{previous}->{info}->{ct} != $self->{data}->{info}->{ct} ) {
        main::print_log( "[Yeelight:" . $self->{name} . "] Color Temperature value changed from $self->{previous}->{info}->{ct} to $self->{data}->{info}->{ct}" ) if ( $self->{loglevel} );
        $self->{previous}->{info}->{ct} = $self->{data}->{info}->{ct};
        
        if ( defined $self->{child_object}->{ct} ) {
            main::print_log "[Yeelight:" . $self->{name} . "] Color Temperature Child object found. Updating..." if ( $self->{loglevel} );        
            $self->{child_object}->{ct}->set($self->{data}->{info}->{ct}, 'poll' );
        }
    }

}

sub print_command_queue {
    my ($self) = @_;
    main::print_log( "Yeelight:" . $self->{name} . "] ------------------------------------------------------------------" );
    my $commands = scalar @{ $self->{cmd_queue} };
    my $name = "$commands commands";
    $name = "empty" if ($commands == 0);
    main::print_log( "Yeelight:" . $self->{name} . "] Current Command Queue: $name" );
    for my $i ( 1 .. $commands ) {
        my ($cmd, $time, $retry) = @ { ${ $self->{cmd_queue} }[$i - 1] };
        main::print_log( "Yeelight:" . $self->{name} . "] Command $i cmd: " . $cmd );
        main::print_log( "Yeelight:" . $self->{name} . "] Command $i time: " . $time );
        main::print_log( "Yeelight:" . $self->{name} . "] Command $i retry: " . $retry );
    }
    main::print_log( "Yeelight:" . $self->{name} . "] ------------------------------------------------------------------" );
    
}

sub purge_command_queue {
    my ($self) = @_;
    my $commands = scalar @{ $self->{cmd_queue} };
    main::print_log( "Yeelight:" . $self->{name} . "] Purging Command Queue of $commands commands" );
    @{ $self->{cmd_queue} } = ();
}

#------------
# User access methods

sub get_debug {
    my ($self) = @_;
    return $self->{debug};
}

sub query_yeelight {
    my ($self) = @_;

    main::print_log( "[Yeelight:" . $self->{name} . "] Querying Yeelight for status" );
    $self->_get_TCP_data('info');
}

sub set {
    my ( $self, $p_state, $p_setby ) = @_;

    $p_setby = "" unless (defined $p_setby);
    
    if ( $p_setby eq 'poll' ) {
        $p_state .= "%" if ($p_state =~ m/\d+(?!%)/ );
        main::print_log( "[Yeelight:" . $self->{name} . "] DB super::set, in master set, p_state=$p_state, p_setby=$p_setby" ) if ( $self->{debug} );
        $self->SUPER::set($p_state);

    }
    elsif ($p_setby eq 'rgb') {
        main::print_log( "[Yeelight:" . $self->{name} . "] DB super::set, in rgb set, p_state=$p_state, p_setby=$p_setby" ) if ( $self->{debug} );
        my ($r, $g, $b) = split(/,/, $p_state);
        $self->set_rgb($r,$g,$b);
    }
    else {
        main::print_log( "[Yeelight:" . $self->{name} . "] DB set_mode, in master set, p_state=$p_state, p_setby=$p_setby" ) if ( $self->{debug} );
        my $mode = lc $p_state;
        if ( $mode =~ /^(\d+)/ ) {
            main::print_log( "[Yeelight:" . $self->{name} . "] DB power = $self->{data}->{info}->{power} \$1 = $1 " ) if ( $self->{debug} );
        
            if (($self->{data}->{info}->{power} eq "on") and ($1 == 0)) {
                $self->set("off"); 
            } elsif (($self->{data}->{info}->{power} eq "off") and ($1 > 0)) {
                $self->set("on"); 
                #main::print_log( "Yeelight:" . $self->{name} . "] Brightness change, delayed state change to $mode" ) if ( $self->{debug} );
                #my $object_name = $self->get_object_name;
                #my $cmd_string = $object_name . '->set("' . $mode .'");';
                #main::eval_with_timer $cmd_string, $self->{brightness_state_delay};
            } #else {
               my @params = @{$param_array{"bright"}};
               unshift @params, $1;
               $self->_push_TCP_data( 'brightness', @params );
            #}  
        }
        elsif ( $mode =~ /^([-+]\d+)/ ) {
            my $value = $self->{info}->{bright} + $1;
            if (($self->{data}->{info}->{power} eq "on") and ($value <= 0)) {
                $self->set("off");
            } elsif (($self->{data}->{info}->{power} eq "off") and ($value > 0)) {
                $self->set("on");  
                #main::print_log( "Yeelight:" . $self->{name} . "] Brightness change, delayed state change to $mode" ) if ( $self->{debug} );
                #my $object_name = $self->get_object_name;
                #my $cmd_string = $object_name . '->set("' . $mode .'");';
                #main::eval_with_timer $cmd_string, $self->{brightness_state_delay};
            } #else {

                my @params = @{$param_array{$mode}};
                $value = 0 if ($value < 0);
                $value = 100 if ($value > 100);
                unshift @params, $value;
                $self->_push_TCP_data( 'brightness', @params );
            #}
        }
        elsif ( ( $mode eq "on" ) or ( $mode eq "off" ) ) {
            $self->_push_TCP_data($mode, @{$param_array{$mode}});
        }
        else {
            main::print_log( "Yeelight:" . $self->{name} . "] Error, unknown set state $p_state" );
            return ('0');
        }
        return ('1');
    }
}

sub get_rgb {
    my ($self) = @_;
    if (defined $self->{data}->{info}->{rgb}) {
        my $red = int($self->{data}->{info}->{rgb} / 65536);
        my $green = int(($self->{data}->{info}->{rgb} - ($red * 65536)) / 256);
        my $blue = $self->{data}->{info}->{rgb} - ($red * 65536) - ($green * 256);
        return ($red, $green, $blue);
    } else {
        return (undef, undef, undef);
    }
}

sub set_rgb {
    my ( $self, $r, $g, $b ) = @_;
    
    if (($r >= 0) and ($r <= 255) and ($g >= 0) and ($g <= 255) and ($b >= 0) and ($b <=255)) {
        my ( $cred, $cgreen, $cblue) = $self->get_rgb();
        $r = $cred unless ($r);
        $g = $cgreen unless ($g);
        $b = $cblue unless ($b);
        my $value = ($r * 65536) + ($g * 256) + $b;
        my @params = @{$param_array{rgb}};
        unshift @params, $value;
        main::print_log ("[Yeelight:" . $self->{name} . "] params = " . join(@params,','));
        $self->_push_TCP_data( 'rgb', @params );
    } else {
        main::print_log( "[Yeelight:" . $self->{name} . "] ERROR, RGB value out of range (0-255). Red=$r, Green=$g, Blue=$b" );
    }
}

sub get_ct {
    my ( $self) = @_;
    
    return ($self->{data}->{info}->{ct});
}

sub set_ct {
    my ( $self, $ct ) = @_;
    if ( $self->{data}->{info}->{power} ne 'on') {
        main::print_log( "[Yeelight:" . $self->{name} . "] Yeelight needs to be on to set color temperature! Command not sent" );
    } else {
        if (($ct >= 1700) and ($ct <= 6500)) {
            my @params = @{$param_array{ct}};
            unshift @params, $ct;
            $self->_push_TCP_data( 'ct', @params );            
        } else {
            main::print_log( "[Yeelight:" . $self->{name} . "] ERROR: Color temperature $ct out of range (1700 - 6500)!" );
        }
    }
}

sub restart_socket {
    my ($self) = @_;
    main::print_log( "[Yeelight:" . $self->{name} . "] Socket Active: ".    $Socket_Items{"yeelight_$self->{id}"}{'socket'}->active() . " Connected: " .    $Socket_Items{"yeelight_$self->{id}"}{'socket'}->connected());
    main::print_log( "[Yeelight:" . $self->{name} . "] Stopping Socket...." );
    $Socket_Items{"yeelight_$self->{id}"}{'socket'}->stop;
    main::print_log( "[Yeelight:" . $self->{name} . "] Starting Socket...." );
    $Socket_Items{"yeelight_$self->{id}"}{'socket'}->start;
}

sub generate_voice_commands {
    my ($self) = @_;

    if ($self->{init_v_cmd} == 0) {
        my $object_string;
        my $object_name = $self->get_object_name;
        $self->{init_v_cmd} = 1;
        &main::print_log("Generating Voice commands for Yeelight $object_name");

        my $voice_cmds = $self->get_voice_cmds();
        my $i          = 1;
        foreach my $cmd ( keys %$voice_cmds ) {

            #get object name to use as part of variable in voice command
            my $object_name_v = $object_name . '_' . $i . '_v';
            $object_string .= "use vars '${object_name}_${i}_v';\n";

            #Convert object name into readable voice command words
            my $command = $object_name;
            $command =~ s/^\$//;
            $command =~ tr/_/ /;

            #Initialize the voice command with all of the possible device commands
            $object_string .= $object_name . "_" . $i . "_v  = new Voice_Cmd '$command $cmd';\n";

            #Tie the proper routine to each voice command
            $object_string .= $object_name . "_" . $i . "_v -> tie_event('" . $voice_cmds->{$cmd} . "');\n\n";    #, '$command $cmd');\n\n";

            #Add this object to the list of Insteon Voice Commands on the Web Interface
            $object_string .= ::store_object_data( $object_name_v, 'Voice_Cmd', 'Yeelight', 'Controller_commands' );
            $i++;
        }

        #Evaluate the resulting object generating string
        package main;
        eval $object_string;
        print "Error in Yeelight_item_commands: $@\n" if $@;

        package Yeelight;
    }
}

sub get_voice_cmds {
    my ($self) = @_;
    my %voice_cmds = (
        'Print Command Queue to print log'                                      => $self->get_object_name . '->print_command_queue',
        'Purge Command Queue'                                                   => $self->get_object_name . '->purge_command_queue',
        'Force Yeelight Status query'                                           => $self->get_object_name . '->query_yeelight',
        'Restart Data Socket connection'                                        =>  $self->get_object_name . '->restart_socket'
    );

    return \%voice_cmds;
}

package Yeelight_RGB;

@Yeelight_RGB::ISA = ('Generic_Item');

sub new {
    my ( $class, $object) = @_;

    my $self = new Generic_Item();
    bless $self, $class;

    $$self{master_object} = $object;
    $object->register( $self, 'rgb' );
    return $self;

}

sub set {
    my ( $self, $p_state, $p_setby ) = @_;

    if ( $p_setby eq 'poll' ) {
        $self->SUPER::set($p_state);
    }
    else {
        my ($r, $g, $b) = split(/,/, $p_state);
        main::print_log("[Yeelight RGB] p_state=$p_state R=$r G=$g B=$b");        
        if (( $r >= 0 and $r <= 255 ) and ( $g >= 0 and $g <= 255 ) and( $b >= 0 and $b <= 255 )) {    
            $$self{master_object}->set_rgb($r, $g, $b)
        } else {
            main::print_log("[Yeelight RGB] Error. Unknown set mode $p_state");
        }
    }
}

package Yeelight_ColorTemp;

@Yeelight_ColorTemp::ISA = ('Generic_Item');

sub new {
    my ( $class, $object) = @_;

    my $self = new Generic_Item();
    bless $self, $class;
    for my $i (1700..6500) { push @{ $$self{states} }, "$i"; }

    $$self{master_object} = $object;
    $object->register( $self, 'ct' );
    return $self;

}

sub set {
    my ( $self, $p_state, $p_setby ) = @_;

    if ( $p_setby eq 'poll' ) {
        $self->SUPER::set($p_state);
    }
    else {
        if ( $p_state >= 1700 and $p_state <= 6500  ) {    
            $$self{master_object}->set_ct($p_state)
            
        } else {
            main::print_log("[Yeelight Color Temp] Error. State out of range (1700-6500): $p_state ");
        }
    }
}

package Yeelight_Comm;

@Yeelight_Comm::ISA = ('Generic_Item');

sub new {
    my ( $class, $object ) = @_;

    my $self = new Generic_Item();
    bless $self, $class;

    $$self{master_object} = $object;
    push( @{ $$self{states} }, 'online', 'offline' );
    $object->register( $self, 'comm' );
    return $self;

}

sub set {
    my ( $self, $p_state, $p_setby ) = @_;

    if ( $p_setby eq 'poll' ) {
        $self->SUPER::set($p_state);
    }
}

1;

# Version History
# v1.0.0 - initial module
# v1.0.1 - color support
# v1.2.1 - command retry logic
