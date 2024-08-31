package Schluter_Ditra;

# v1.5


#TODO
#
# - voice commands? generate new token, enable/disable module?

# - if online eq false then set mode to offline
# - schedule item. Manual or Schedule -> {"RegulationMode":1,"VacationEnabled":false}

# How to use
#Set the username (email) and password in the mh.config like this:

#ditra_username = name@email.com
#ditra_password = password

#Then define the master object. I have two thermostats, but they use the master object like this:

#use Schulter_Ditra;
#$ditra = new Schulter_Ditra;

#$room1_sp = new Ditra_thermostat_sp($ditra,123456);
#$room1_mode = new Ditra_thermostat_mode($ditra,123456);
#$room1_temp = new Ditra_thermostat_temp($ditra,123456);

#$room2_sp = new Ditra_thermostat_sp($ditra,234567);
#$room2_mode = new Ditra_thermostat_mode($ditra,234567);
#$room2_temp = new Ditra_thermostat_temp($ditra,234567);


use strict;
use warnings;

use LWP::UserAgent;
use HTTP::Request::Common qw(POST);
use JSON::XS;
use Data::Dumper;
use IO::Select;
use IO::Socket::INET;



@Schluter_Ditra::ISA = ('Generic_Item');

# -------------------- START OF SUBROUTINES --------------------
# --------------------------------------------------------------


my $api_url = "https://ditra-heat-e-wifi.schluter.com";
my $api_auth_url = $api_url . "/api/authenticate/user";
my $api_get_stats_url = $api_url .  "/api/thermostats";
my $api_set_temp_url = $api_url . "/api/thermostat";

sub new {
    my ( $class, $username, $password, $poll, $options ) = @_;
    my $self = new Generic_Item();
    bless $self, $class;

    $self->{data}                   = undef;
    $self->{child_object}           = undef;
    $self->{config}->{poll_seconds} = 10;
    $self->{config}->{poll_seconds} = $::config_parms{ "ditra_poll" }  if ( defined $::config_parms{ "ditra_poll" } );
    $self->{config}->{poll_seconds} = $poll if ($poll);
    $self->{config}->{poll_seconds} = 5     if ( $self->{config}->{poll_seconds} < 5 );

    $self->{config}->{username} = "";
    $self->{config}->{username} = $::config_parms{ "ditra_username" }  if ( defined $::config_parms{ "ditra_username" } );
    $self->{config}->{username} = $username if ($username);

    $self->{config}->{password} = "";
    $self->{config}->{password} = $::config_parms{ "ditra_password" }  if ( defined $::config_parms{ "ditra_password" } );
    $self->{config}->{password} = $password if ($password);
    
    $self->{config}->{app_id} = 7; #hardcoded to 7. Manual override. Some work as app id 0
    $self->{config}->{app_id} = $::config_parms{ "ditra_application_id" }  if ( defined $::config_parms{ "ditra_application_id" } );


    $self->{enabled} = 1;
    if ($self->{config}->{username} eq "" or $self->{config}->{password} eq "") {
        main::print_log( "[Schluter_Ditra]: ERROR, username or password undefined" );
        $self->{enabled} = 0;
    }            

    $self->{updating}               = 0;
    $self->{data}->{retry}          = 0;
    $self->{status}                 = "";
    $self->{module_version}         = "v1.5";

#how to store and restore a token
    $self->{token} = "";
    $self->restore_data('token');
    $self->{auth_try} = 0;

    $options = "" unless ( defined $options );
    $options = $::config_parms{ "ditra_options" } if ( $::config_parms{ "ditra_options" } );

    $self->{debug} = 0;
    ( $self->{debug} ) = ( $options =~ /debug\=(\d+)/i ) if ( $options =~ m/debug\=/i );
    $self->{debug} = 0 if ( $self->{debug} < 0 );

    $self->{loglevel} = 5;
    ( $self->{loglevel} ) = ( $options =~ /loglevel\=(\d+)/i ) if ($options =~ m/loglevel\=/i );


    $self->{poll_data_timestamp}     = 0;
    $self->{max_poll_queue}          = 3;
    $self->{max_cmd_queue}           = 5;
    $self->{cmd_process_retry_limit} = 6;

    @{ $self->{poll_queue} } = ();
    $self->{poll_data_file} = "$::config_parms{data_dir}/Ditra_poll.data";
    unlink "$::config_parms{data_dir}/Ditra_poll.data";
    $self->{poll_process} = new Process_Item;
    $self->{poll_process}->set_output( $self->{poll_data_file} );
    @{ $self->{cmd_queue} } = ();
    $self->{cmd_data_file} = "$::config_parms{data_dir}/Ditra_cmd.data";
    unlink "$::config_parms{data_dir}/Ditra_cmd.data";
    $self->{cmd_process} = new Process_Item;
    $self->{cmd_process}->set_output( $self->{cmd_data_file} );
    $self->{init}      = 0;
    
    if ($self->{enabled}) {
        &::MainLoop_post_add_hook( \&Schluter_Ditra::process_check, 0, $self );
        $self->get_data();    
        $self->{timer} = new Timer;
        $self->start_timer;
        main::print_log( "[Schluter_Ditra]: module " . $self->{module_version} . " active" );            
        return $self;
    } else {
        main::print_log( "[Schluter_Ditra]: module disabled, will not fetch data" );    
    }
}

sub start_timer {
    my ($self) = @_;
    unless ( defined $self->{timer} ) {
        $self->{timer} = new Timer;    #HP: why do timers get undefined??
    }
    if ( defined $self->{timer} ) {
        $self->{timer}->set( $self->{config}->{poll_seconds}, sub { &Schluter_Ditra::get_data($self) }, -1 );
    }
    else {
        main::print_log( "[Schluter_Ditra]: Warning, start_timer called but timer undefined" );
    }
}

sub get_data {
    my ($self) = @_;

    main::print_log( "[Schluter_Ditra] get_data initiated" ) if ( $self->{debug} );

     $self->poll();

}

sub get_token {
    my ($self) = @_;
    main::print_log( "[Schluter_Ditra]: Sending Authentication request for token..." );
    $self->_push_JSON_data('auth');
    return ('1');
}

sub poll {
    my ($self) = @_;

    main::print_log( "[Schluter_Ditra] Background Polling initiated" ) if ( $self->{debug} );
    $self->_get_JSON_data('poll');

    return ('1');
}

sub process_check {
    my ($self) = @_;

    return unless ( defined $self->{poll_process} );

    if ( $self->{poll_process}->done_now() ) {
    
        #shift @{ $self->{poll_queue} };    #remove the poll since they are expendable.
        @{ $self->{poll_queue} } = ();      #clear the queue since process is done.

        my $com_status = "online";
        main::print_log( "[Schluter_Ditra] Background poll process completed" ) if ( $self->{debug} );

        my $file_data = &main::file_read( $self->{poll_data_file} );

        return unless ($file_data);    #if there is no data, then don't process
        if ( $file_data =~ m/401 unauthorized/i ) {
            main::print_log( "[Schluter_Ditra]: Authentication request denied, requesting new token" );
            $self->{auth_try}++;
            $self->get_token();
            return;
        }
        my ($responsecode) = $file_data =~ /^RESPONSECODE:(\d+)\n/;
        $file_data =~ s/^RESPONSECODE:\d+\n// if ($responsecode);

        #print "debug: code=$responsecode\n" if ( $self->{debug} );

        #for some reason get_url adds garbage to the output. Clean out the characters before and after the json
        print "debug: file_data=$file_data\n" if ( $self->{debug} > 2);
        my ($json_data) = $file_data =~ /({.*})/;
        print "debug: json_data=$json_data\n" if ( $self->{debug} > 2);
        unless ( ($file_data) and ($json_data) ) {
            main::print_log( "[Schluter_Ditra]: ERROR! bad data returned by poll" );
            main::print_log( "[Schluter_Ditra]: ERROR! file data is [$file_data]. json data is [$json_data]" );
            return;
        }
        my $data;
        eval { $data = JSON::XS->new->decode($json_data); };

        # catch crashes:
        if ($@) {
            main::print_log( "[Schluter_Ditra]: ERROR! JSON file parser crashed! $@\n" );
            $com_status = "offline";
        }
        else {
            if ( keys %{$data} ) {

                $self->{data} = $data;
                $self->process_data();

            }
            else {
                main::print_log( "[Schluter_Ditra]: ERROR! Returned data not structured! Not processing..." );
                $com_status = "offline";
            }
        }

        if ( defined $self->{child_object}->{comm} ) {
            if ( $self->{status} ne $com_status ) {
                main::print_log "[Schluter_Ditra]: Communication Tracking object found. Updating from "
                  . $self->{child_object}->{comm}->state() . " to "
                  . $com_status . "..."
                  if ( $self->{loglevel} );
                $self->{status} = $com_status;
                $self->{child_object}->{comm}->set( $com_status, 'poll' );
            }
        }
    }

#TODO if auth responds back yes, reset auth tries.
    return unless ( defined $self->{cmd_process} );
    if ( $self->{cmd_process}->done_now() ) {
        main::print_log( "[Schluter_Ditra] Background Command " . $self->{cmd_process_mode} . " process completed" ) if ( $self->{debug} );
        my $file_data = &main::file_read( $self->{cmd_data_file} );

        my ($responsecode) = $file_data =~ /^RESPONSECODE:(\d+)\n/;
        $file_data =~ s/^RESPONSECODE:\d+\n// if ($responsecode);
        print "debug: code=$responsecode\n" if ( $self->{debug} );

        #print "success\n\n" if (($responsecode == 204) or ($responsecode == 200));
        my $com_status = "offline";

        if ( ( $responsecode == 204 ) or ( $responsecode == 200 ) or ( $responsecode == 404) ) { #added 404 since a few calls can generate 404 if the data isn't present (like querying static without a static scene active)
            $com_status = "online";

            # Successful commands should be [200 OK, 204 No Content]
            shift @{ $self->{cmd_queue} };    #remove the command from queue since it was successful
            $self->{cmd_process_retry} = 0;

            if ($file_data) {

                #for some reason get_url adds garbage to the output. Clean out the characters before and after the json
                print "debug: file_data=$file_data\n" if ( $self->{debug} > 2);
                my ($json_data) = $file_data =~ /({.*})/;
                print "debug: json_data=$json_data\n" if ( $self->{debug} > 2);
                my $data;
                eval { $data = JSON::XS->new->decode($json_data); };

                # catch crashes:
                if ($@) {
                    main::print_log( "[Schluter_Ditra] ERROR! JSON file parser crashed! $@\n" );
                    $com_status = "offline";
                }
                else {

                    #print Dumper $data;

                    if ( keys %{$data} ) {

                        #Process any returned data from a command straing
                        if ( $self->{cmd_process_mode} eq "auth" ) {
                        #{"SessionId":"xxxxxxxx","NewAccount":false,"ErrorCode":0,"RoleType":3000,"Email":"xxxx","Language":"EN"}
                        #ErrorCode = 1, bad username, ErrorCode = 2 bad password
                            if ( defined $data->{SessionId} ) {
                                main::print_log( "[Schluter_Ditra]: authentication token returned" );
                                $self->{token} = $data->{SessionId};
                            } else {
                                my $err = "Bad Username";
                                $err = "Bad Password" if ($data->{ErrorCode} == 2);
                                main::print_log( "[Schluter_Ditra] Error, could not request token. " . $err . "ErrorCode = " . $data->{ErrorCode} . " Email = " . $data->{Email} );                            
                            } 
                        }
                        if ( $self->{cmd_process_mode} eq "set" ) {
                            main::print_log( "[Schluter_Ditra] set returned" );
                            #RESPONSECODE:200
                            #{"Success":true} is success, anything else is an error/warning
#TODO                            
                        }
                        
                    }

                    $self->poll;
                }
            }

            if ( scalar @{ $self->{cmd_queue} } ) {
                main::print_log( "[Schluter_Ditra]: Command Queue found" );            
                my $cmd = @{ $self->{cmd_queue} }[0];    #grab the first command, but don't take it off.
                $self->{cmd_process}->set($cmd);
                $self->{cmd_process}->start();
                main::print_log( "[Schluter_Ditra] Command Queue " . $self->{cmd_process}->pid() . " cmd=$cmd" )
                  if ( ( $self->{debug} ) or ( $self->{cmd_process_retry} ) );
            }

        }
        else {

            main::print_log( "[Schluter_Ditra]: WARNING Issued command was unsuccessful, retrying..." );
            if ( $self->{cmd_process_retry} > $self->{cmd_process_retry_limit} ) {
                main::print_log( "[Schluter_Ditra]: ERROR Issued command max retries reached. Abandoning command attempt..." );
                shift @{ $self->{cmd_queue} };
                $self->{cmd_process_retry} = 0;
                $com_status = "offline";
            }
            else {
                $self->{cmd_process_retry}++;
            }
        }

        if ( defined $self->{child_object}->{comm} ) {
            if ( $self->{status} ne $com_status ) {
                main::print_log "[Schluter_Ditra]: Communication Tracking object found. Updating from "
                  . $self->{child_object}->{comm}->state() . " to "
                  . $com_status . "..."
                  if ( $self->{loglevel} );
                $self->{status} = $com_status;
                $self->{child_object}->{comm}->set( $com_status, 'poll' );
            }
        }
    }
}

#polling process. Keep it separate from commands
sub _get_JSON_data {
    my ( $self) = @_;
    if ($self->{token} eq "") {
        main::print_log( "[Schluter_Ditra] Token blank, requesting first one" ) if ( $self->{debug} );
        $self->get_token();
    } else {
        my $cmd = "get_url " . $api_get_stats_url . "?sessionId=" . $self->{token};
        if ( $self->{poll_process}->done() ) {
            $self->{poll_process}->set($cmd);
            $self->{poll_process}->start();
            main::print_log( "[Schluter_Ditra] Backgrounding " . $self->{poll_process}->pid() . " command $cmd" ) if ( $self->{debug} );
        }
        else {
            if ( scalar @{ $self->{poll_queue} } < $self->{max_poll_queue} ) {
                main::print_log( "[Schluter_Ditra] Queue is " . scalar @{ $self->{poll_queue} } . ". Queing command $cmd" ) if ( $self->{debug} );
                push @{ $self->{poll_queue} }, "$cmd";
            }
            else {
                #the queue has grown past the max, so it might be down. Since polls are expendable, just don't do anything
                #when the device is back it will process the backlog, and as soon as a poll is processed, the queue is cleared.
            }
        }
    }
}

#command process
sub _push_JSON_data {
    my ( $self, $mode, $serial, $params ) = @_;
    my $get_url_string = "";
    
    if (lc $mode eq "auth") {
        $get_url_string = "-response_code -json -post '{\"Email\":\"" . $self->{config}->{username} . "\",\"Password\":\"" . $self->{config}->{password} . "\",\"Application\":\"" . $self->{config}->{app_id} . "\"}' ";
        $get_url_string .= $api_auth_url;
    } elsif (lc $mode eq "sched") {
        $get_url_string = "-response_code -json -post '{\"RegulationMode\":1,\"VacationEnabled\":0}' ";
        $get_url_string .= '"' . $api_set_temp_url . "?sessionId=" . $self->{token} . "&serialNumber=" . $serial . '"';
    } else { #assume set
        $params = int($params * 100) if ($params < 1000);
        $get_url_string = "-response_code -json -post '{\"ManualTemperature\":" . $params . ",\"RegulationMode\":3,\"VacationEnabled\":0}' ";
        $get_url_string .= '"' . $api_set_temp_url . "?sessionId=" . $self->{token} . "&serialNumber=" . $serial . '"';
    }
    my $cmd = "get_url $get_url_string";
    if ( $self->{cmd_process}->done() ) {
        $self->{cmd_process}->set($cmd);
        $self->{cmd_process}->start();
        $self->{cmd_process_pid}->{ $self->{cmd_process}->pid() } = $mode;    #capture the type of information requested in order to parse;
        $self->{cmd_process_mode} = $mode;
        push @{ $self->{cmd_queue} }, "$cmd";

        main::print_log( "[Schluter_Ditra] Backgrounding " . $self->{cmd_process}->pid() . " command $mode, $cmd" ) if ( $self->{debug} );
    }
    else {
        if ( scalar @{ $self->{cmd_queue} } < $self->{max_cmd_queue} ) {
            main::print_log( "[Schluter_Ditra]: Queue is " . scalar @{ $self->{cmd_queue} } . ". Queing command $mode, $cmd" )
              if ( $self->{debug} );
            push @{ $self->{cmd_queue} }, "$cmd";
        }
        else {
            main::print_log( "[Schluter_Ditra] WARNING. Queue has grown past " . $self->{max_cmd_queue} . ". Command discarded." );
            if ( defined $self->{child_object}->{comm} ) {
                if ( $self->{status} ne "offline" ) {
                    main::print_log "[Schluter_Ditra]: Communication Tracking object found. Updating from "
                      . $self->{child_object}->{comm}->state()
                      . " to offline..."
                      if ( $self->{loglevel} );
                    $self->{status} = "offline";
                    $self->{child_object}->{comm}->set( "offline", 'poll' );
                }
            }
        }
    }
}

sub stop_timer {
    my ($self) = @_;

    if ( defined $self->{timer} ) {
        $self->{timer}->stop() if ( $self->{timer}->active() );
    }
    else {
        main::print_log( "[Schluter_Ditra]: Warning, stop_timer called but timer undefined" );
    }
}

sub print_info {
    my ($self,$serial) = @_;

    $serial = "" unless (defined $serial);
    $self->{init} = 1;
    
    foreach my $group (@{ $self->{data}->{Groups} }) {
        main::print_log( "[Schluter_Ditra] Group " . $group->{GroupName} . "..." );
        foreach my $stat (@{ $group->{Thermostats} }) {
            if ($serial eq "" or $stat->{SerialNumber} eq $serial) {
                main::print_log( "[Schluter_Ditra] ********************************************************" );
                main::print_log( "[Schluter_Ditra] * Note: Schluter_Ditra.pm is now depreciated in favour *");
                main::print_log( "[Schluter_Ditra] *       of using Home Assistant for device access      *" );
                main::print_log( "[Schluter_Ditra] ********************************************************" );
                main::print_log( "[Schluter_Ditra] ----------------------------------------------");            
                main::print_log( "[Schluter_Ditra] Serial:               " . $stat->{SerialNumber});
                main::print_log( "[Schluter_Ditra] Room:                 " . $stat->{Room});
                main::print_log( "[Schluter_Ditra] TZOffset:             " . $stat->{TZOffset});
                main::print_log( "[Schluter_Ditra] SWVersion:            " . $stat->{SWVersion});
                main::print_log( "[Schluter_Ditra] VacationTemperature:  " . $stat->{VacationTemperature});
                main::print_log( "[Schluter_Ditra] ComfortTemperature:   " . $stat->{ComfortTemperature});
                main::print_log( "[Schluter_Ditra] LoadMeasuredWatt:     " . $stat->{LoadMeasuredWatt});
                main::print_log( "[Schluter_Ditra] SetPointTemp:         " . $stat->{SetPointTemp});
                main::print_log( "[Schluter_Ditra] Temperature:          " . $stat->{Temperature});
                main::print_log( "[Schluter_Ditra] ManualTemperature:    " . $stat->{ManualTemperature});
                main::print_log( "[Schluter_Ditra] MinTemp:              " . $stat->{MinTemp});
                main::print_log( "[Schluter_Ditra] MaxTemp:              " . $stat->{MaxTemp});
                main::print_log( "[Schluter_Ditra] Online:               " . $stat->{Online});
                main::print_log( "[Schluter_Ditra] LastPrimaryModeIsAuto:" . $stat->{LastPrimaryModeIsAuto});
                main::print_log( "[Schluter_Ditra] Heating:              " . $stat->{Heating});
                main::print_log( "[Schluter_Ditra] *** Child Object Defined for this serial # ***") if (defined $self->{child_object}->{$stat->{SerialNumber}});
                main::print_log( "[Schluter_Ditra] ----------------------------------------------");            
            }
        }
    }
}

sub process_data {
    my ($self) = @_;

    my (%state);

    # Main core of processing
    # set state of self for state
    # for any registered child selfs, update their state if

    main::print_log( "[Schluter_Ditra]: Processing Data..." ) if ( $self->{debug} );

    foreach my $group (@{ $self->{data}->{Groups} }) {
        main::print_log( "[Schluter_Ditra]: Processing Data for Group " . $group->{GroupName} . "..." ) if ( $self->{debug} );

        foreach my $stat (@{ $group->{Thermostats} }) {
            if ($self->{child_object}->{$stat->{SerialNumber}}) {
                my $temp = sprintf("%.1f",$stat->{Temperature} / 100);
                if (defined $self->{child_object}->{$stat->{SerialNumber}}->{temp}) { 
                    $self->{child_object}->{$stat->{SerialNumber}}->{temp}->set($temp,'poll') if ($self->{child_object}->{$stat->{SerialNumber}}->{temp}->state() != $temp);
                    main::print_log( "[Schluter_Ditra]: Setting stat " . $stat->{Room} . " with serial #" . $stat->{SerialNumber} . " temperature to " . $temp ) if ( $self->{debug} );
                }
                if (defined $self->{child_object}->{$stat->{SerialNumber}}->{sp}) { 
                    my $sp = sprintf("%.1f",$stat->{SetPointTemp} / 100);
                    $self->{child_object}->{$stat->{SerialNumber}}->{sp}->set($sp,'poll') if ($self->{child_object}->{$stat->{SerialNumber}}->{sp}->state() != $sp);
                    main::print_log( "[Schluter_Ditra]: Setting stat " . $stat->{Room} . " with serial #" . $stat->{SerialNumber} . " set point to " . $sp ) if ( $self->{debug} );
                }
                if (defined $self->{child_object}->{$stat->{SerialNumber}}->{sched}) { 
                    my $schedule = "off";
                    $schedule = "on" if ($stat->{RegulationMode} == 1);
                    $self->{child_object}->{$stat->{SerialNumber}}->{sched}->set($schedule,'poll') if ($self->{child_object}->{$stat->{SerialNumber}}->{sched}->state() ne $schedule);
                    main::print_log( "[Schluter_Ditra]: Setting stat " . $stat->{Room} . " with serial #" . $stat->{SerialNumber} . " schedule to " . $schedule ) if ( $self->{debug} );
                }
                if (defined $self->{child_object}->{$stat->{SerialNumber}}->{mode_status}) { 
                    my $heating = "idle";
                    $heating = "heating" if ($stat->{Heating});
                    $heating = "offline" unless ($stat->{Online});
                    $self->{child_object}->{$stat->{SerialNumber}}->{mode_status} = $heating;
                    $self->{child_object}->{$stat->{SerialNumber}}->{mode}->set($heating,'poll') if ($self->{child_object}->{$stat->{SerialNumber}}->{mode}->state() ne $heating);
                    main::print_log( "[Schluter_Ditra]: Setting stat " . $stat->{Room} . " with serial #" . $stat->{SerialNumber} . " mode to " . $heating ) if ( $self->{debug} );
                }
            } else {
                main::print_log( "[Schluter_Ditra]: Warning: No child object defined for Stat serial #" . $stat->{SerialNumber} );
            }

        }
    }

    $self->print_info() unless ($self->{init});
}


sub print_command_queue {
    my ($self) = @_;
    main::print_log( "Schluter_Ditra] ------------------------------------------------------------------" );
    my $commands = scalar @{ $self->{cmd_queue} };
    my $name = "$commands commands";
    $name = "empty" if ($commands == 0);
    main::print_log( "[Schluter_Ditra]: Current Command Queue: $name" );
    for my $i ( 1 .. $commands ) {
        main::print_log( "[Schluter_Ditra]: Command $i: " . @{ $self->{cmd_queue} }[$i - 1] );
    }
    main::print_log( "[Schluter_Ditra] ------------------------------------------------------------------" );
    
}

sub purge_command_queue {
    my ($self) = @_;
    my $commands = scalar @{ $self->{cmd_queue} };
    main::print_log( "[Schluter_Ditra] Purging Command Queue of $commands commands" );
    @{ $self->{cmd_queue} } = ();
}

#------------
# User access methods

sub get_debug {
    my ($self) = @_;
    return $self->{debug};
}

sub get_mode {
    my ($self, $serial) = @_;
    my $mode = "unknown";
    $mode = $self->{child_object}->{$serial}->{mode_status} if (defined $self->{child_object}->{$serial}->{mode_status});
    return $mode;
}


sub set {
    my ($self) = @_;
    #device doesn't actually have a state
} 

sub set_stat {
    my ( $self, $serial, $value ) = @_;

    main::print_log( "[Schluter_Ditra] DB set_mode, in master set, serial=$serial, p_setby=$serial" ) if ( $self->{debug} );
    $self->_push_JSON_data('set',$serial,$value);

    return ('1');
}

sub set_sched {
    my ( $self, $serial) = @_;

    main::print_log( "[Schluter_Ditra] DB set_sched, in master set, serial=$serial, p_setby=$serial" ) if ( $self->{debug} );
    $self->_push_JSON_data('sched',$serial);

    return ('1');
}

sub register {
    my ( $self, $object, $mode, $serial, $options ) = @_;
    if ( lc $mode eq 'comm' ) {
        &main::print_log("[Schluter_Ditra]: Registering Communication object to controller");
        $self->{child_object}->{comm} = $object;
    }
    elsif ( lc $mode eq 'sp' )  {
        &main::print_log("[Schluter_Ditra]: Registering Serial # $serial Setpoint object" );
        $self->{child_object}->{$serial}->{sp} = $object;
    }
    elsif ( lc $mode eq 'temp' )  {
        &main::print_log("[Schluter_Ditra]: Registering Serial # $serial Temperature object" );
        $self->{child_object}->{$serial}->{temp} = $object;
    }
    elsif ( lc $mode eq 'sched' )  {
        &main::print_log("[Schluter_Ditra]: Registering Serial # $serial Schedule object" );
        $self->{child_object}->{$serial}->{sched} = $object;
    }
    elsif ( lc $mode eq 'mode' )  {
        &main::print_log("[Schluter_Ditra]: Registering Serial # $serial Mode object" );
        $self->{child_object}->{$serial}->{mode} = $object; 
        $self->{child_object}->{$serial}->{mode_status} = "idle";   
    } else {
        main::print_log( "[Schluter_Ditra] Warning: child object with mode [$mode] not recognized" );
    }
}

package Ditra_thermostat_sp;

@Ditra_thermostat_sp::ISA = ('Generic_Item');

sub new {
    my ( $class, $object, $serial, $options, $deg ) = @_;

    my $self = new Generic_Item();
    bless $self, $class;
    if ( ( defined $deg ) and ( lc $deg eq "f" ) ) {
        push( @{ $$self{states} }, 60, 61, 62, 63, 64, 65, 66, 67, 68, 69, 70, 71, 72, 73, 74, 75, 76, 77, 78, 79, 80 );
        $self->{units}    = "F";
        $self->{min_temp} = 58;
        $self->{max_temp} = 80;

    }
    else {
        push( @{ $$self{states} }, 15, 15.5, 16, 16.5, 17, 17.5, 18, 18.5, 19, 19.5, 20, 20.5, 21, 21.5, 22, 22.5, 23, 23.5, 24, 24.5, 25, 25.5, 26, 26.5, 27, 27.5, 28, 28.5, 29, 29.5, 30, 30.5, 31, 31.5, 32, 32.5, 33, 33.5, 34, 34.5, 35, 35.5, 36, 36.5, 37, 37.5, 38, 38.5, 39, 39.5, 40 );
        $self->{units}    = "C";
        $self->{min_temp} = 10;
        $self->{max_temp} = 40;
    }

    $$self{master_object} = $object;
    $$self{serial} = $serial;

    $object->register( $self, 'sp', $serial, $options );

    $self->{level} = "";

    $self->{debug} = $object->{debug};
    return $self;

}

sub set {
    my ( $self, $p_state, $p_setby ) = @_;

    if ( defined $p_setby && ( ( $p_setby eq 'poll' ) or ( $p_setby eq 'push' ) ) ) {
        $self->{level} = $p_state;
        $self->SUPER::set($p_state);
    }
    else {
        if (   ( $p_state < $self->{min_temp} )
            or ( $p_state > $self->{max_temp} ) )
        {
            main::print_log( "[Ditra_Thermostat]: WARNING not setting level to $p_state since out of bounds " . $self->{min_temp} . ":" . $self->{max_temp} );
        }
        else {
            $$self{master_object}->set_stat( $$self{serial}, $p_state );
        }
    }
}

sub level {
    my ($self) = @_;

    return ( $self->{level} );
}

package Ditra_thermostat_schedule;

@Ditra_thermostat_schedule::ISA = ('Generic_Item');

sub new {
    my ( $class, $object, $serial, $options, $deg ) = @_;

    my $self = new Generic_Item();
    bless $self, $class;

    push( @{ $$self{states} }, 'off', 'on' );

    $$self{master_object} = $object;
    $$self{serial} = $serial;

    $object->register( $self, 'sched', $serial, $options );

    $self->{debug} = $object->{debug};
    return $self;

}

sub set {
    my ( $self, $p_state, $p_setby ) = @_;

    if ( defined $p_setby && ( ( $p_setby eq 'poll' ) or ( $p_setby eq 'push' ) ) ) {
        $self->SUPER::set($p_state);
    }
    else {
        if (lc $p_state eq "on") {
            $$self{master_object}->set_sched( $$self{serial} );
        } else {
            main::print_log( "[Ditra_Thermostat]: WARNING Schedule child object only supports set(ON), change setpoint to take off schedule" );        
        }
    }
}

package Ditra_thermostat_temp;

@Ditra_thermostat_temp::ISA = ('Generic_Item');

sub new {
    my ( $class, $object, $serial, $options ) = @_;

    my $self = new Generic_Item();
    bless $self, $class;

    $$self{master_object} = $object;
    $$self{serial} = $serial;

    $object->register( $self, 'temp', $serial, $options );

    $self->{level} = "";

    $self->{debug} = $object->{debug};
    return $self;

}

sub set {
    my ( $self, $p_state, $p_setby ) = @_;

    if ( defined $p_setby && ( $p_setby eq 'poll' ) ) {
        $self->SUPER::set($p_state);
    }
}

package Ditra_thermostat_mode;

@Ditra_thermostat_mode::ISA = ('Generic_Item');

sub new {
    my ( $class, $object, $serial ) = @_;

    my $self = new Generic_Item();
    bless $self, $class;

    $$self{master_object} = $object;
    $$self{serial} = $serial;

    $object->register( $self, 'mode', $serial );
    $self->set( $object->get_mode($serial), 'poll' );
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
# v1.0.0  - initial module
