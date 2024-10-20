package Venstar_Colortouch;

# v2.1.3

#added in https support and don't retry commands that have a valid error reason code. Only retry if the device doesn't respond. (ie error 500)

#check linesl829 l477 l493 l203
#TODO - check that data is current before issuing command. within 2 poll periods.
# Does this even really need to happen. If the data isn't current, then polling again
# Doesn't really buy anything.

use strict;
use warnings;

use LWP::UserAgent;
use HTTP::Request::Common qw(POST);
use JSON::XS;
use Data::Dumper;

# Venstar::Colortouch Objects
# $stat_upper         = new Venstar_Colortouch('192.168.0.100',,"ssl,debug=1");
#
# $stat_upper_mode    = new Venstar_Colortouch_Mode($stat_upper);
# $stat_upper_temp    = new Venstar_Colortouch_Temp($stat_upper);
# $stat_upper_heat_sp = new Venstar_Colortouch_Heat_sp($stat_upper,"F"); #F for Fahrenheit
# $stat_upper_cool_sp = new Venstar_Colortouch_Cool_sp($stat_upper);
# $stat_upper_fan     = new Venstar_Colortouch_Fan($stat_upper);
# $stat_upper_hum     = new Venstar_Colortouch_Humidity($stat_upper);
# $stat_upper_hum_sp  = new Venstar_Colortouch_Humidity_sp($stat_upper);
# $stat_upper_sched   = new Venstar_Colortouch_Schedule($stat_upper);
# $stat_upper_comm	  = new Venstar_Colortouch_Comm($stat_upper);

# Version History
# v1.1 - added in schedule and humidity control.
# v1.2 - added communication tracker object & timeout control
# v1.3 - added check for timer defined
# v1.4 - support for API v5. It seems like v5
#	"hum_setpoint": is the current humidity and
#   "dehum_setpoint": is the humidity setpoint
#	"hum" doesn't return anything anymore.
# v1.4.1 - API v5, working schedule, humidity setpoints
# v2.0 - Background process
# v2.1 - fixed up some problems reconnecting to stat
# v2.1.1 - added in logger ability

# Notes
#  - State can only be set by stat. Set mode will change the mode.
#  - Best to use firmware at least 3.14 released Nov 2014. This fixes issues with both
#    schedule and humidity/dehumidify control.
#  - 4.08 brings API5, and a workaround to a humidity bug.

# Issues
#2
# - log runtimes. Maybe into a dbm file? log_runtimes method with destination.
# - figure out timezone w/ DST
#1
# - TEST temp setpoint bounds checking
# - changing heating/cooling setpoints for heating/cooling only stats does not need both setpoints?
# - add in communication tracker for background requests
# - verify command sets work both with existing poll data, and have a poll data gap.
# - verify that network issues don't escalate CPU usage (by _push_json_data being continually called)
# - add in the commercial stat fields
# - incorporate Steve's approach for more efficient detection of changed values.

@Venstar_Colortouch::ISA = ('Generic_Item');

# -------------------- START OF SUBROUTINES --------------------
# --------------------------------------------------------------

our %rest;
$rest{info}     = "query/info";
$rest{api}      = "";
$rest{sensors}  = "query/sensors";
$rest{runtimes} = "query/runtimes";
$rest{alerts}   = "query/alerts";
$rest{control}  = "control";
$rest{settings} = "settings";

sub new {
    my ( $class, $host, $poll, $options ) = @_;
    $options = "" unless ( defined $options );
    my $self = new Generic_Item();
    bless $self, $class;
    $self->{data}                 = undef;
    $self->{api_ver}              = 0;
    $self->{child_object}         = undef;
    $self->{config}->{cache_time} = 30;                                           #is this still necessary?
    $self->{config}->{cache_time} = $::config_params{venstar_config_cache_time}
      if defined $::config_params{venstar_config_cache_time};
    $self->{config}->{tz}           = $::config_params{time_zone};                #TODO Need to figure out DST for print runtimes
    $self->{config}->{poll_seconds} = 10;
    $self->{config}->{poll_seconds} = $poll if ($poll);
    $self->{config}->{poll_seconds} = 1
      if ( $self->{config}->{poll_seconds} < 1 );
    $self->{updating}      = 0;
    $self->{data}->{retry} = 0;
    $self->{host}          = $host;
    $self->{method}        = "http";
    $self->{method}        = "https" if ( $options =~ m/ssl/i );
    $self->{debug}         = 0;
    ( $self->{debug} ) = ( $options =~ /debug\=(\d+)/i ) if ( $options =~ m/debug\=/i );
    $self->{debug}                   = 0 if ( $self->{debug} < 0 );
    $self->{loglevel}                = 1;
    $self->{status}                  = "";
    $self->{timeout}                 = 15;                            #for http direct mode;
    $self->{background}              = 2;                             #0 for direct, 1 for set commands, 2 for poll and set commands
    $self->{poll_data_timestamp}     = 0;
    $self->{max_poll_queue}          = 3;
    $self->{max_cmd_queue}           = 5;
    $self->{cmd_process_retry_limit} = 6;

    if ( $self->{background} ) {
        @{ $self->{poll_queue} } = ();
        $self->{poll_data_file} = "$::config_parms{data_dir}/venstar_poll_" . $self->{host} . ".data";
        unlink "$::config_parms{data_dir}/venstar_poll_" . $self->{host} . ".data";
        $self->{poll_process} = new Process_Item;
        $self->{poll_process}->set_output( $self->{poll_data_file} );
        @{ $self->{cmd_queue} } = ();
        $self->{cmd_data_file} = "$::config_parms{data_dir}/venstar_cmd_" . $self->{host} . ".data";
        unlink "$::config_parms{data_dir}/venstar_cmd_" . $self->{host} . ".data";
        $self->{cmd_process} = new Process_Item;
        $self->{cmd_process}->set_output( $self->{cmd_data_file} );
        &::MainLoop_post_add_hook( \&Venstar_Colortouch::process_check, 0, $self );
    }
    $self->{timer} = new Timer;
    $self->_init;
    $self->start_timer;
    main::print_log( "[Venstar Colortouch:" . $self->{data}->{name} . "] Debug is " . $self->{debug} ) if ( $self->{debug} );
    main::print_log( "[Venstar Colortouch:" . $self->{data}->{name} . "] v2.1 Controller Initialization Complete" );

    return $self;
}

sub _poll_check {
    my ($self) = @_;

    main::print_log("[Venstar Colortouch] _poll_check initiated")
      if ( $self->{debug} );

    #main::run (sub {&Venstar_Colortouch::get_data($self)}); #spawn this off to run in the background
    $self->get_data();
}

sub get_data {
    my ($self) = @_;

    main::print_log("[Venstar Colortouch] get_data initiated")
      if ( $self->{debug} );
    $self->poll;
    $self->process_data
      unless ( $self->{background} > 1 );    #for background tasks, data will be processed when process completed.
}

sub _init {
    my ($self) = @_;
    my @state;
    $state[0] = "idle";
    $state[1] = "heating";
    $state[2] = "cooling";
    $state[3] = "lockout";
    $state[4] = "error";
    my ( $isSuccessResponse1, $stat ) = $self->_get_JSON_data( 'api', "direct" );

    if ($isSuccessResponse1) {
        $self->{api_ver} = $stat->{api_ver};

        if (    ( $stat->{api_ver} > 3 )
            and ( $stat->{type} eq "residential" or $stat->{type} eq "commercial" ) )
        {

            $self->{type} = $stat->{type};

            main::print_log("[Venstar Colortouch] $stat->{type} Venstar ColorTouch found with api level $stat->{api_ver}");
            main::print_log( "[Venstar Colortouch] *************************************************************" );
            main::print_log( "[Venstar Colortouch] * Note: Venstar _Colortouch.pm is now depreciated in favour *");
            main::print_log( "[Venstar Colortouch] *       of using Home Assistant for device access           *" );
            main::print_log( "[Venstar Colortouch] *************************************************************" );
            if ( $self->poll("direct") ) {
                main::print_log( "[Venstar Colortouch:" . $self->{data}->{name} . "] Data Successfully Retrieved" );
                $self->{active}                = 1;
                $self->{previous}->{tempunits} = $self->{data}->{tempunits};
                $self->{previous}->{name}      = $self->{data}->{name};
                foreach my $key1 ( keys %{$self->{data}->{info}} ) {
                    $self->{previous}->{info}->{$key1} = $self->{data}->{info}->{$key1};
                }
                $self->{previous}->{sensors}->{sensors}[0]->{temp} = $self->{data}->{sensors}->{sensors}[0]->{temp};
                $self->{previous}->{sensors}->{sensors}[0]->{hum}  = $self->{data}->{sensors}->{sensors}[0]->{hum};
                ## set states based on available mode
### Strange, if this set is here, then the timer is not defined.
                #print "db: set " . $state[ $self->{data}->{info}->{state} ] . "=" . $self->{data}->{info}->{state} . "\n";
                #$self->set( $state[ $self->{data}->{info}->{state} ], 'poll' );
                $self->print_info();

            }
            else {
                main::print_log("[Venstar Colortouch] Problem retrieving initial data");
                $self->{active} = 0;
                return ('1');
            }

        }
        else {
            main::print_log( "[Venstar Colortouch] Unknown device " . $self->{host} );
            $self->{active} = 0;
            return ('1');
        }

    }
    else {
        main::print_log( "[Venstar Colortouch] Error. Unable to connect to " . $self->{host} );
        $self->{active} = 0;
        return ('1');
    }
}

sub poll {
    my ( $self, $method ) = @_;
    $method = "" unless ( defined $method );

    if ( ( $self->{background} > 1 ) and ( $method ne "direct" ) ) {
        main::print_log("[Venstar Colortouch] Background Polling initiated")
          if ( $self->{debug} );
        $self->_get_JSON_data( 'info', $method );

        #$self->_get_JSON_data('sensors',$method);
        return ('1');
    }
    else {
        main::print_log("[Venstar Colortouch] Direct Polling initiated")
          if ( $self->{debug} );
        my ( $isSuccessResponse1, $info )    = $self->_get_JSON_data( 'info',    $method );
        my ( $isSuccessResponse2, $sensors ) = $self->_get_JSON_data( 'sensors', $method );

        if ( $isSuccessResponse1 and $isSuccessResponse2 ) {
            $self->{poll_data_timestamp} = &main::get_tickcount();
            $self->{data}->{tempunits}   = $info->{tempunits};
            $self->{data}->{name}        = $info->{name};
            $self->{data}->{info}        = $info;
            $self->{data}->{sensors}     = $sensors;
            $self->{data}->{timestamp}   = time;
            $self->{data}->{retry}       = 0;

            return ('1');
        }
    }

}

sub process_check {
    my ($self) = @_;

    #Need to catch error 500's 403's and update communication tracker and success:false messages to write to log
    # as a safety measure, just check that the timer's active
    if ( defined $self->{timer} ) {
        if ( $self->{timer}->inactive() ) {
            main::print_log( "[Venstar Colortouch:" . $self->{data}->{name} . "] INFO, timer is not active. " )
              if ( ( $self->{debug} ) or ( $self->{loglevel} > 2 ) );

            #$self->start_timer();
        }
    }
    else {
        #		main::print_log( "[Venstar Colortouch:" . $self->{data}->{name} . "] ERROR! timer is not defined!");
    }

    #	$self->start_timer if ($self->{timer}->inactive());
    return unless ( defined $self->{poll_process} );
    if ( $self->{poll_process}->done_now() ) {
        my $com_status = "online";
        main::print_log( "[Venstar Colortouch:" . $self->{data}->{name} . "] Background poll " . $self->{poll_process_mode} . " process completed" )
          if ( $self->{debug} );

        my $file_data = &main::file_read( $self->{poll_data_file} );
        $file_data = "" unless ($file_data);    #just to prevent warning messages
                                                #for some reason get_url adds garbage to the output. Clean out the characters before and after the json
        print "debug: file_data=$file_data\n" if ( $self->{debug} );
        my ($json_data) = $file_data =~ /(\{.*\})/;
        $json_data = "" unless ($json_data);    #just to prevent warning messages
        print "debug: json_data=$json_data\n" if ( $self->{debug} );
        unless ( ($file_data) and ($json_data) ) {
            main::print_log( "[Venstar Colortouch:" . $self->{data}->{name} . "] ERROR! bad data returned by poll" );
            main::print_log( "[Venstar Colortouch:" . $self->{data}->{name} . "] ERROR! file data is $file_data. json data is $json_data" );
            $com_status = "offline";
        }
        else {
            my $data;
            eval { $data = JSON::XS->new->decode($json_data); };

            # catch crashes:
            if ($@) {
                main::print_log( "[Venstar Colortouch:" . $self->{data}->{name} . "] ERROR! JSON file parser crashed! $@\n" );
                $com_status = "offline";
            }
            else {
                if ( keys %{$data} ) {
                    $self->{poll_data_timestamp} = &main::get_tickcount();
                    if ( $self->{poll_process_mode} eq "info" ) {
                        $self->{data}->{tempunits} = $data->{tempunits};
                        $self->{data}->{name}      = $data->{name};
                        $self->{data}->{info}      = $data;
                        $self->{data}->{timestamp} = &main::get_tickcount();
                    }
                    elsif ( $self->{poll_process_mode} eq "sensors" ) {
                        $self->{data}->{sensors}   = $data;
                        $self->{data}->{timestamp} = &main::get_tickcount();
                    }
                    $self->process_data();
                }
                else {
                    main::print_log( "[Venstar Colortouch:" . $self->{data}->{name} . "] ERROR! Returned data not structured! Not processing..." );
                    $com_status = "offline";
                }
            }
        }
        if ( scalar @{ $self->{poll_queue} } ) {
            my $cmd_string = shift @{ $self->{poll_queue} };
            my ( $mode, $cmd ) = split /\|/, $cmd_string;
            $self->{poll_process}->set($cmd);
            $self->{poll_process}->start();
            $self->{poll_process_pid}->{ $self->{poll_process}->pid() } = $mode;    #capture the type of information requested in order to parse;
            $self->{poll_process_mode} = $mode;
            main::print_log( "[Venstar Colortouch:" . $self->{data}->{name} . "] Poll Queue " . $self->{poll_process}->pid() . " mode=$mode cmd=$cmd" )
              if ( $self->{debug} );

        }
        if ( defined $self->{child_object}->{comm} ) {
            if ( $self->{status} ne $com_status ) {
                main::print_log "[Venstar Colortouch:"
                  . $self->{data}->{name}
                  . "] Communication Tracking object found. Updating from "
                  . $self->{child_object}->{comm}->state() . " to "
                  . $com_status . "..."
                  if ( $self->{loglevel} );
                $self->{status} = $com_status;
                $self->{child_object}->{comm}->set( $com_status, 'poll' );
            }
        }
    }
    return unless ( defined $self->{cmd_process} );
    if ( $self->{cmd_process}->done_now() ) {
        my $com_status = "online";
        main::print_log( "[Venstar Colortouch:" . $self->{data}->{name} . "] Background Command " . $self->{cmd_process_name} . " process completed" )
          if ( $self->{debug} );

        my $file_data = &main::file_read( $self->{cmd_data_file} );
        unless ($file_data) {
            main::print_log( "[Venstar Colortouch:" . $self->{data}->{name} . "] ERROR! no data returned by command" );
            return;
        }

        #for some reason get_url adds garbage to the output. Clean out the characters before and after the json
        my ($json_data) = $file_data =~ /(\{.*\})/;
        my $data;
        eval { $data = JSON::XS->new->decode($json_data); };

        # catch crashes:
        if ($@) {
            main::print_log( "[Venstar Colortouch:" . $self->{data}->{name} . "] ERROR! JSON file parser crashed! $@\n" );
            $com_status = "offline";

        }
        else {
            if ( keys %{$data} ) {
                if ( $data->{success} eq "true" ) {
                    shift @{ $self->{cmd_queue} };    #remove the command from queue since it was successful
                    $self->{cmd_process_retry} = 0;
                    $self->poll;
                }
                else {
                    if ( defined $data->{reason} ) {
                        main::print_log(
                            "[Venstar Colortouch:" . $self->{data}->{name} . "] WARNING Issued command was unsuccessful (reason=" . $data->{reason} . ")" );
                        shift @{ $self->{cmd_queue} };
                    }
                    else {
                        main::print_log( "[Venstar Colortouch:"
                              . $self->{data}->{name}
                              . "] WARNING Issued command was unsuccessful with no returned reason , retrying..." );
                        if ( $self->{cmd_process_retry} > $self->{cmd_process_retry_limit} ) {
                            main::print_log(
                                "[Venstar Colortouch:" . $self->{data}->{name} . "] ERROR Issued command max retries reached. Abandoning command attempt..." );
                            shift @{ $self->{cmd_queue} };
                            $self->{cmd_process_retry} = 0;
                            $com_status = "offline";
                        }
                        else {
                            $self->{cmd_process_retry}++;
                        }
                    }
                }
            }
            else {
                print_log( "[Venstar Colortouch:" . $self->{data}->{name} . "] ERROR! Returned data not structured! Not processing..." );
                $com_status = "offline";
            }
        }
        if ( scalar @{ $self->{cmd_queue} } ) {
            my $cmd = @{ $self->{cmd_queue} }[0];    #grab the first command, but don't take it off.
            $self->{cmd_process}->set($cmd);
            $self->{cmd_process}->start();
            main::print_log( "[Venstar Colortouch:" . $self->{data}->{name} . "] Command Queue " . $self->{cmd_process}->pid() . " cmd=$cmd" )
              if ( ( $self->{debug} ) or ( $self->{cmd_process_retry} ) );
        }
        if ( defined $self->{child_object}->{comm} ) {
            if ( $self->{status} ne $com_status ) {
                main::print_log "[Venstar Colortouch:"
                  . $self->{data}->{name}
                  . "] Communication Tracking object found. Updating from "
                  . $self->{child_object}->{comm}->state() . " to "
                  . $com_status . "..."
                  if ( $self->{loglevel} );
                $self->{status} = $com_status;
                $self->{child_object}->{comm}->set( $com_status, 'poll' );
            }
        }
    }

}

#------------------------------------------------------------------------------------
sub _get_JSON_data {
    my ( $self, $mode, $method ) = @_;

    if ( ( $self->{background} > 1 ) and ( lc $method ne "direct" ) ) {

        my $cmd = 'get_url "' . $self->{method} . '://' . $self->{host} . "/$rest{$mode}" . '"';
        if ( $self->{poll_process}->done() ) {
            $self->{poll_process}->set($cmd);
            $self->{poll_process}->start();
            $self->{poll_process_pid}->{ $self->{poll_process}->pid() } = $mode;    #capture the type of information requested in order to parse;
            $self->{poll_process_mode} = $mode;
            main::print_log( "[Venstar Colortouch:" . $self->{data}->{name} . "] Backgrounding " . $self->{poll_process}->pid() . " command $mode, $cmd" )
              if ( $self->{debug} );

        }
        else {
### Polls are expendable. If one doesn't trigger log it and move on.

            if ( scalar @{ $self->{poll_queue} } < $self->{max_poll_queue} ) {
                main::print_log(
                    "[Venstar Colortouch:" . $self->{data}->{name} . "] Queue is " . scalar @{ $self->{poll_queue} } . ". Queing command $mode, $cmd" )
                  if ( $self->{debug} );
                push @{ $self->{poll_queue} }, "$mode|$cmd";

                #TODO: queue shouldn't grow for polling. Since a poll is 2 queries, the queue should only be 3 items. Otherwise it will grow every poll
                # if there are device issues.
            }
            else {
                main::print_log( "[Venstar Colortouch:"
                      . $self->{data}->{name}
                      . "] WARNING. Queue has grown past "
                      . $self->{max_poll_queue}
                      . ". Command discarded and background poll process stopped" );
                @{ $self->{poll_queue} } = ();
                $self->{poll_process}->stop();
                $self->process_check();
            }
        }
    }
    else {
        unless ( $self->{updating} ) {

            $self->{updating} = 1;
            my $ua = new LWP::UserAgent( keep_alive => 1 );
            $ua->timeout( $self->{timeout} );

            my $host = $self->{host};

            my $request = HTTP::Request->new( POST => $self->{method} . "://$host/$rest{$mode}" );
            $request->content_type("application/x-www-form-urlencoded");

            my $responseObj = $ua->request($request);
            print $responseObj->content . "\n--------------------\n"
              if $self->{debug};

            my $responseCode = $responseObj->code;
            print 'Response code: ' . $responseCode . "\n" if $self->{debug};
            my $isSuccessResponse = $responseCode < 400;
            $self->{updating} = 0;
            if ( !$isSuccessResponse ) {
                main::print_log( "[Venstar Colortouch: (" . $self->{host} . ")] Warning, failed to get data. Response code $responseCode" );
                print "Venstar. status=" . $self->{status};
                if ( defined $self->{child_object}->{comm} ) {
                    print " Tracker defined\n";
                }
                else {
                    print " Tracker UNDEFINED\n";
                }
                if ( defined $self->{child_object}->{comm} ) {
                    if ( $self->{status} eq "online" ) {
                        main::print_log "[Venstar Colortouch:"
                          . $self->{data}->{name}
                          . "] Communication Tracking object found. Updating from "
                          . $self->{child_object}->{comm}->state()
                          . " to offline..."
                          if ( $self->{loglevel} );
                        $self->{status} = "offline";
                        $self->{child_object}->{comm}->set( "offline", 'poll' );
                    }
                }
                return ('0');
            }
            else {
                if ( defined $self->{child_object}->{comm} ) {
                    if ( $self->{status} eq "offline" ) {
                        main::print_log "[Venstar Colortouch:"
                          . $self->{data}->{name}
                          . "] Communication Tracking object found. Updating from "
                          . $self->{child_object}->{comm}->state()
                          . " to online..."
                          if ( $self->{loglevel} );
                        $self->{status} = "online";
                        $self->{child_object}->{comm}->set( "online", 'poll' );
                    }
                }
            }
            my $response;
            eval { $response = JSON::XS->new->decode( $responseObj->content ); };

            # catch crashes:
            if ($@) {
                print "[Venstar Colortouch:" . $self->{data}->{name} . "] ERROR! JSON parser crashed! $@\n";
                return ('0');
            }
            else {
                return ( $isSuccessResponse, $response );
            }
        }
        else {
            main::print_log( "[Venstar Colortouch:" . $self->{data}->{name} . "] Warning, not fetching data due to operation in progress" );
            return ('0');
        }
    }
}

sub _push_JSON_data {
    my ( $self, $type, $params, $method ) = @_;

    my ( @fan, @fanstate, @modename, @statename, @schedule, @home, @schedulestat );
    $fan[0]          = "auto";
    $fan[1]          = "on";
    $fanstate[0]     = "off";
    $fanstate[1]     = "running";
    $home[0]         = "home";
    $home[1]         = "away";
    $modename[0]     = "off";
    $modename[1]     = "heating";
    $modename[2]     = "cooling";
    $modename[3]     = "auto";
    $statename[0]    = "idle";
    $statename[1]    = "heating";
    $statename[2]    = "cooling";
    $statename[3]    = "lockout";
    $statename[4]    = "error";
    $schedule[0]     = "morning (occupied1)";
    $schedule[1]     = "day (occupied2)";
    $schedule[2]     = "evening (occupied3)";
    $schedule[3]     = "night (occupied4)";
    $schedule[255]   = "inactive";
    $schedulestat[0] = "off";
    $schedulestat[1] = "on";

    #4.08, schedulepart is now the schedule type. schedule 0 is off,

    my $cmd;
    $method = "" unless ( defined $method );

    #For background tasks, we want up to date data, ie returned within the last poll period.
    #recursively calling the same subroutine might be a memory or performance hog, but need to effectively
    #'suspend' the data push until we get valid data.

    #	if (($self->{background} > 1) and (lc $method ne "direct")) {
    #		if (($self->{poll_data_timestamp} + ($self->{config}->{poll_seconds} * 1000)) < &main::get_tickcount()) {
    #			$self->poll() if (scalar @{$self->{poll_queue}} < $self->{max_poll_queue}); #once max reached, no sense adding more
    #			if ($self->{poll_data_timestamp} + 300000 > &main::get_tickcount()) { #give up after 5 minutes of trying
    #		        main::print_log( "[Venstar Colortouch:" . $self->{data}->{name} . "] WARNING: retrying command attempt due to stale poll data!" );
    #				&Venstar_Colortouch::_push_JSON_data($self,$type,$params);
    #			} else {
    #		        main::print_log( "[Venstar Colortouch:" . $self->{data}->{name} . "] ERROR: Abandoning command attempt due to stale poll data!" );
    #				return ('1');
    #			}
    #		}
    #	}

    #    $self->stop_timer; # unless ($self->{background} > 1);    #stop timer to prevent a clash of updates
    if ( $type eq 'settings' ) {

        #for testing purposes, curl is:
        #curl --data "tempunits=1&away=0&schedule=0&hum_setpoint=30&dehum_setpoint=35" http://ip/settings

        #       my ( $isSuccessResponse, $thedata ) = $self->_get_setting_params;
        #       my %info = %$thedata;
        #       my %cinfo = %$thedata;
        #       my @changearr;
        #
        #       while ($params =~ /(\w+)=(\d+)/g) {
        #           print "[Venstar Colortouch:"
        #             . $self->{data}->{name}
        #             . "] _push_JSON_data match: $1 = $2\n";
        #           $info{$1} = $2;
        #           if ($info{$1} ne $cinfo{$1}) {
        #               main::print_log( "[Venstar Colortouch:"
        #                 . $self->{data}->{name}
        #                 . "] Changing $1 from $cinfo{$1} to $info{$1}" );
        #               push(@changearr, "$1=$info{$1}");
        #           }
        #       }

        #        $cmd = join ('&', @changearr);
        #        main::print_log( "Sending Settings command $cmd to " . $self->{host} ) if $cmd;    # if $self->{debug};

        my ( $newunits, $newaway, $newholiday, $newsched, $newhumsp, $newdehumsp );
        my ($units)        = $params =~ /tempunits=(\d+)/;
        my ($away)         = $params =~ /away=(\d+)/;
        my ($holiday)      = $params =~ /holiday=(\d+)/;
        my ($override)     = $params =~ /override=(\d+)/;
        my ($overridetime) = $params =~ /overridetime=(\d+)/;
        my ($forceunocc)   = $params =~ /forceunocc=(\d+)/;
        my ($sched)        = $params =~ /schedule=(\d+)/;
        my $hum;
        my ($humsp)   = $params =~ /hum_setpoint=(\d+)/;
        my ($dehumsp) = $params =~ /dehum_setpoint=(\d+)/;    #need to add in dehumidifier stuff at some point
        my $humidity_change = 0;

        my ( $isSuccessResponse, $cunits, $caway, $csched, $chum, $chumsp, $cdehumsp );
        my ( $choliday, $coverride, $coverridetime, $cforceunocc );

        if ( ( $self->{background} > 1 ) and ( lc $method ne "direct" ) ) {
            $cunits   = $self->{data}->{info}->{tempunits};
            $caway    = $self->{data}->{info}->{away};
            $csched   = $self->{data}->{info}->{schedule};
            $chumsp   = $self->{data}->{info}->{hum_setpoint};
            $cdehumsp = $self->{data}->{info}->{dehum_setpoint};
        }
        else {
            ( $isSuccessResponse, $cunits, $caway, $csched, $chum, $chumsp, $cdehumsp ) = $self->_get_setting_params;

            #($choliday,$coverride,$coverridetime,$cforceunocc);
        }
        $units = $cunits if ( not defined $units );
        $units = 1 if ( ( $units eq "C" ) or ( $units eq "c" ) );
        $units = 0 if ( ( $units eq "F" ) or ( $units eq "f" ) );

        $away         = $caway         if ( not defined $away );
        $holiday      = $choliday      if ( not defined $holiday );
        $override     = $coverride     if ( not defined $override );
        $overridetime = $coverridetime if ( not defined $overridetime );
        $forceunocc   = $cforceunocc   if ( not defined $forceunocc );
        $sched        = $csched        if ( not defined $sched );
        $hum          = $chum          if ( not defined $hum );

        #v4.08, dehum_sp is humidify, and hum_sp is dehumidify.
        if ( $self->{api_ver} >= 5 ) {
            $humsp = $cdehumsp if ( not defined $humsp );
        }
        else {
            $humsp = $chumsp if ( not defined $humsp );
        }
        if ( $self->{api_ver} >= 5 ) {
            $dehumsp = $chumsp if ( not defined $dehumsp );
        }
        else {
            $dehumsp = $cdehumsp if ( not defined $dehumsp );
        }

        #print "venstar db: params = $params\n";
        #print "units=$units, away=$away, sched=$sched, humsp=$humsp, dehumsp=$dehumsp\n";
        #print "cunits=$cunits, caway=$caway, csched=$csched, chum=$chum, chumsp=$chumsp, cdehumsp=$cdehumsp\n";

        if ( $cunits ne $units ) {
            main::print_log( "[Venstar Colortouch:" . $self->{data}->{name} . "] Changing Units from $cunits to $units" );
            $newunits = $units;
        }
        else {
            $newunits = $cunits;
        }

        if ( $caway ne $away ) {
            main::print_log( "[Venstar Colortouch:" . $self->{data}->{name} . "] Changing Away from $home[$caway] to $home[$away]" );
            $newaway = $away;
        }
        else {
            $newaway = $caway;
        }

        if ( ( $self->{type} eq "commercial" ) and ( $choliday ne $holiday ) ) {
            main::print_log( "[Venstar Colortouch:" . $self->{data}->{name} . "] Changing Away from $choliday to $holiday" );
            $newholiday = $holiday;
        }
        else {
            $newholiday = $choliday;
        }

        if ( $caway ne $away ) {
            main::print_log( "[Venstar Colortouch:" . $self->{data}->{name} . "] Changing Away from $caway to $away" );
            $newaway = $away;
        }
        else {
            $newaway = $caway;
        }

        if ( $csched ne $sched ) {
            if ( $self->{api_ver} >= 5 ) {
                main::print_log( "[Venstar Colortouch:" . $self->{data}->{name} . "] Changing Schedule from $schedulestat[$csched] to $schedulestat[$sched]" );
            }
            else {
                main::print_log( "[Venstar Colortouch:" . $self->{data}->{name} . "] Changing Schedule from $schedule[$csched] to $schedule[$sched]" );
            }
            $newsched = $sched;
        }
        else {
            $newsched = $csched;
        }
        if ( $self->{api_ver} >= 5 ) {
            if ( $cdehumsp ne $humsp ) {
                main::print_log( "[Venstar Colortouch:" . $self->{data}->{name} . "] Changing Humidity Setpoint from $cdehumsp to $humsp\n" );
                $newhumsp        = $humsp;
                $humidity_change = 1;
            }
            else {
                $newhumsp = $cdehumsp;
            }

            if ( $chumsp ne $dehumsp ) {
                main::print_log( "[Venstar Colortouch:" . $self->{data}->{name} . "] *Changing Dehumidity Setpoint from $chumsp to $dehumsp\n" );
                $newdehumsp = $dehumsp;
            }
            else {
                $newdehumsp = $chumsp;
            }
        }
        else {
            if ( $chumsp ne $humsp ) {
                main::print_log( "[Venstar Colortouch:" . $self->{data}->{name} . "] Changing Humidity Setpoint from $chumsp to $humsp\n" );
                $newhumsp        = $humsp;
                $humidity_change = 1;
            }
            else {
                $newhumsp = $chumsp;
            }

            if ( $cdehumsp ne $dehumsp ) {
                main::print_log( "[Venstar Colortouch:" . $self->{data}->{name} . "] Changing Dehumidity Setpoint from $cdehumsp to $dehumsp\n" );
                $newdehumsp = $dehumsp;
            }
            else {
                $newdehumsp = $cdehumsp;
            }
        }

## to set v4.08, humidity to 32%, this is needed "tempunits=1&away=0&schedule=0&hum_setpoint=32&dehum_setpoint=38"
## so humidity setpoint hasn't changed?
        if ( $self->{api_ver} >= 5 ) {

            # v4.08 has changed humidification settings
            # - need 6 % point delta on humidity and dehumidity.
            $newdehumsp = $newhumsp + 6
              if ( ( ( $newhumsp >= $newdehumsp ) or ( ( $newdehumsp - $newhumsp ) < 6 ) ) );
        }
        $cmd = "tempunits=$newunits&away=$newaway&schedule=$newsched&hum_setpoint=$newhumsp&dehum_setpoint=$newdehumsp";
        main::print_log( "Sending Settings command [$cmd] to " . $self->{host} )
          if $self->{debug};

    }
    elsif ( $type eq 'control' ) {

        #mode=0&fan=0&heattemp=70&cooltemp=75
        #have to include heattemp and cooltemp
        #and must ensure they differ from setpointdelta
        #TODO This would only be for auto stats
        my ( $newmode, $newfan, $newcoolsp, $newheatsp );
        my ($mode)     = $params =~ /mode=(\d+)/;
        my ($fan)      = $params =~ /fan=(\d+)/;
        my ($heattemp) = $params =~ /heattemp=(\d+\.?\d?)/;    #need decimals
        my ($cooltemp) = $params =~ /cooltemp=(\d+\.?\d?)/;

        my ( $isSuccessResponse, $cmode, $cfan, $cheattemp, $ccooltemp, $setpointdelta, $minheat, $maxheat, $mincool, $maxcool );

        if ( ( $self->{background} > 1 ) and ( lc $method ne "direct" ) ) {
            $cmode         = $self->{data}->{info}->{mode};
            $cfan          = $self->{data}->{info}->{fan};
            $cheattemp     = $self->{data}->{info}->{heattemp};
            $ccooltemp     = $self->{data}->{info}->{cooltemp};
            $setpointdelta = $self->{data}->{info}->{setpointdelta};
            $minheat       = $self->{data}->{info}->{heattempmin};
            $maxheat       = $self->{data}->{info}->{heattempmax};
            $mincool       = $self->{data}->{info}->{cooltempmin};
            $maxcool       = $self->{data}->{info}->{cooltempmax};

        }
        else {
            ( $isSuccessResponse, $cmode, $cfan, $cheattemp, $ccooltemp, $setpointdelta, $minheat, $maxheat, $mincool, $maxcool ) = $self->_get_control_params;
        }

        $mode     = $cmode     if ( not defined $mode );
        $fan      = $cfan      if ( not defined $fan );
        $heattemp = $cheattemp if ( !$heattemp );
        $cooltemp = $ccooltemp if ( !$cooltemp );

        if ( $cmode ne $mode ) {
            main::print_log( "[Venstar Colortouch:" . $self->{data}->{name} . "] Changing mode from $modename[$cmode] to $modename[$mode]" );
            $newmode = $mode;
        }
        else {
            $newmode = $cmode;
        }

        if ( $cfan ne $fan ) {
            main::print_log( "[Venstar Colortouch:" . $self->{data}->{name} . "] Changing fan from $fan[$cfan] to $fan[$fan]" );
            $newfan = $fan;
        }
        else {
            $newfan = $cfan;
        }

        if ( $heattemp ne $cheattemp ) {
            main::print_log( "[Venstar Colortouch:" . $self->{data}->{name} . "] Changing heat setpoint from $cheattemp to $heattemp" );
            $newheatsp = $heattemp;
        }
        else {
            $newheatsp = $cheattemp;
        }

        if ( $cooltemp ne $ccooltemp ) {
            main::print_log( "[Venstar Colortouch:" . $self->{data}->{name} . "] Changing cool setpoint from $ccooltemp to $cooltemp" );
            $newcoolsp = $cooltemp;
        }
        else {
            $newcoolsp = $ccooltemp;
        }

        if ( ( $newcoolsp > $maxcool ) or ( $newcoolsp < $mincool ) ) {
            main::print_log( "[Venstar Colortouch:" . $self->{data}->{name} . "] Error: New cooling setpoint $newcoolsp out of bounds $mincool - $maxcool" );
            $newcoolsp = $ccooltemp;
        }

        if ( ( $newheatsp > $maxheat ) or ( $newheatsp < $minheat ) ) {
            main::print_log( "[Venstar Colortouch:" . $self->{data}->{name} . "] Error: New heating setpoint $newheatsp out of bounds $minheat - $maxheat" );
            $newheatsp = $cheattemp;
        }

        if ( ( $newheatsp - $newcoolsp ) > $setpointdelta ) {
            main::print_log( "[Venstar Colortouch:"
                  . $self->{data}->{name}
                  . "] Error: Cooling ($newcoolsp) and Heating ($newheatsp) setpoints need to be less than setpoint $setpointdelta" );
            main::print_log( "[Venstar Colortouch:" . $self->{data}->{name} . "] Not setting setpoints" );
            $newcoolsp = $ccooltemp;
            $newheatsp = $cheattemp;
        }

        $cmd = "mode=$newmode&fan=$newfan&heattemp=$newheatsp&cooltemp=$newcoolsp";
        main::print_log( "Sending Control command $cmd to " . $self->{host} )
          if $self->{debug};

    }
    else {

        main::print_log("Unknown mode!");
        return ( '1', 'error' );
    }
    my $isSuccessResponse;
    my $response;
    if ( ( $self->{background} ) and ( lc $method ne "direct" ) ) {
        $isSuccessResponse = 1;           #set these to successful, since the process_data will indicate if a setting was unsuccessful.
        $response          = "success";
        my $cmd = 'get_url -post "' . $cmd . '" "' . $self->{method} . '://' . $self->{host} . "/$rest{$type}" . '"';
        push @{ $self->{cmd_queue} }, "$cmd";
        if ( $self->{cmd_process}->done() ) {
            $self->{cmd_process}->set($cmd);
            $self->{cmd_process_name} = $cmd;
            $self->{cmd_process}->start();
            $self->{cmd_process_retry} = 0;
            main::print_log( "[Venstar Colortouch:" . $self->{data}->{name} . "] Backgrounding " . $self->{cmd_process}->pid() . " command $cmd" )
              if ( $self->{debug} );

        }
        else {
            if ( scalar @{ $self->{cmd_queue} } < $self->{max_cmd_queue} ) {
                main::print_log( "[Venstar Colortouch:" . $self->{data}->{name} . "] Queue is " . scalar @{ $self->{cmd_queue} } . ". Queing command $cmd" )
                  if ( $self->{debug} );
            }
            else {
                main::print_log(
                    "[Venstar Colortouch:" . $self->{data}->{name} . "] WARNING. Queue has grown past " . $self->{max_cmd_queue} . ". Command discarded." );
            }
        }
    }
    else {

        my $ua = new LWP::UserAgent( keep_alive => 1 );
        $ua->timeout( $self->{timeout} );

        my $host = $self->{host};

        my $request = HTTP::Request->new( POST => $self->{method} . "://$host/$rest{$type}" );
        $request->content_type("application/x-www-form-urlencoded");
        $request->content($cmd) if $cmd;

        my $responseObj = $ua->request($request);
        print $responseObj->content . "\n--------------------\n"
          if ( $self->{debug} );

        my $responseCode = $responseObj->code;
        print 'Response code: ' . $responseCode . "\n" if ( $self->{debug} );
        $isSuccessResponse = $responseCode < 400;
        if ( !$isSuccessResponse ) {
            main::print_log( "[Venstar Colortouch:" . $self->{data}->{name} . "] Warning, failed to push data. Response code $responseCode" );
            print "Venstar. status=" . $self->{status};
            if ( defined $self->{child_object}->{comm} ) {
                print " Tracker defined\n";
            }
            else {
                print " Tracker UNDEFINED\n";
            }
            if ( defined $self->{child_object}->{comm} ) {
                if ( $self->{status} eq "online" ) {
                    main::print_log "[Venstar Colortouch:"
                      . $self->{data}->{name}
                      . "] Communication Tracking object found. Updating from "
                      . $self->{child_object}->{comm}->state()
                      . " to offline..."
                      if ( $self->{loglevel} );
                    $self->{status} = "offline";
                    $self->{child_object}->{comm}->set( "offline", 'poll' );
                }
            }
        }
        else {
            if ( defined $self->{child_object}->{comm} ) {
                if ( $self->{status} eq "offline" ) {
                    main::print_log "[Venstar Colortouch:"
                      . $self->{data}->{name}
                      . "] Communication Tracking object found. Updating from "
                      . $self->{child_object}->{comm}->state()
                      . " to online..."
                      if ( $self->{loglevel} );
                    $self->{status} = "online";
                    $self->{child_object}->{comm}->set( "online", 'poll' );
                }
            }

            #my $response = JSON::XS->new->decode ($responseObj->content);
            ($response) = $responseObj->content =~ /\{\"(.*)\":/;
        }
    }

    #print Dumper $response if $self->{debug};
    print "response=$response\n" if $self->{debug};

    # remove this poll since the stat pauses after being set?
    #    if ( $response eq "success" ) {
    #    	$self->poll();
    #    	$self->process_data() unless ($self->{background} >1);
    #    }
    $self->start_timer;    # unless ($self->{background} > 1);

    return ( $isSuccessResponse, $response );
}

sub register {
    my ( $self, $object, $type ) = @_;

    #my $name;
    #$name = $$object{object_name};  #TODO: Why can't we get the name of the child object?
    &main::print_log( "[Venstar Colortouch:" . $self->{data}->{name} . "] Registering $type child object" );
    $self->{child_object}->{$type} = $object;

}

sub _get_control_params {
    my ($self) = @_;
    my ( $isSuccessResponse, $info ) = $self->_get_JSON_data('info');
    return (
        $isSuccessResponse,     $info->{mode},        $info->{fan},         $info->{heattemp},    $info->{cooltemp},
        $info->{setpointdelta}, $info->{heattempmin}, $info->{heattempmax}, $info->{cooltempmin}, $info->{cooltempmax}
    );
}

sub _get_setting_params {
    my ($self) = @_;
    my ( $isSuccessResponse, $info ) = $self->_get_JSON_data( 'info', "direct" );
    return ( $isSuccessResponse, $info->{tempunits}, $info->{away}, $info->{schedule}, $info->{hum}, $info->{hum_setpoint}, $info->{dehum_setpoint} );
}

sub stop_timer {
    my ($self) = @_;

    if ( defined $self->{timer} ) {
        $self->{timer}->stop() if ( $self->{timer}->active() );
    }
    else {
        main::print_log( "[Venstar Colortouch:" . $self->{data}->{name} . "] Warning, stop_timer called but timer undefined" );
    }
}

sub start_timer {
    my ($self) = @_;
    unless ( defined $self->{timer} ) {
        $self->{timer} = new Timer;    #HP: why do timers get undefined??
    }
    if ( defined $self->{timer} ) {
        $self->{timer}->set( $self->{config}->{poll_seconds}, sub { &Venstar_Colortouch::_poll_check($self) }, -1 );
    }
    else {
        main::print_log( "[Venstar Colortouch:" . $self->{data}->{name} . "] Warning, start_timer called but timer undefined" );
    }
}

sub background_enable {
    my ( $self, $level ) = @_;
    $level = 1 unless ( defined $level );
    $self->{background} = $level;
    main::print_log( "[Venstar Colortouch:" . $self->{data}->{name} . "] Background mode enabled (level " . $level . ")" );
}

sub background_disable {
    my ($self) = @_;
    $self->{background} = 0;
    main::print_log( "[Venstar Colortouch:" . $self->{data}->{name} . "] Background mode disabled. Now in direct mode." );
}

sub print_info {
    my ($self) = @_;

    my ( @fan, @fanstate, @mode, @state, @schedule );
    $fan[0]        = "auto";
    $fan[1]        = "on";
    $fanstate[0]   = "off";
    $fanstate[1]   = "running";
    $mode[0]       = "off";
    $mode[1]       = "heating";
    $mode[2]       = "cooling";
    $mode[3]       = "auto";
    $state[0]      = "idle";
    $state[1]      = "heating";
    $state[2]      = "cooling";
    $state[3]      = "lockout";
    $state[4]      = "error";
    $schedule[0]   = "morning (occupied1)";
    $schedule[1]   = "day (occupied2)";
    $schedule[2]   = "evening (occupied3)";
    $schedule[3]   = "night (occupied4)";
    $schedule[255] = "inactive";
    my $unit = "C";
    $unit = "F" if ( $self->{data}->{tempunits} == 0 );

    my $type;
    if ( $self->{data}->{info}->{availablemodes} == 0 ) {
        $type = "an all modes";
    }
    elsif ( $self->{data}->{info}->{availablemodes} == 1 ) {
        $type = "a heat/cool only";
    }
    elsif ( $self->{data}->{info}->{availablemodes} == 2 ) {
        $type = "a heating only";
    }
    elsif ( $self->{data}->{info}->{availablemodes} == 3 ) {
        $type = "a cooling only";
    }
    main::print_log( "[Venstar Colortouch:"
          . $self->{data}->{name}
          . "] Device "
          . $self->{data}->{name} . " is "
          . $type
          . " Thermostat with API level "
          . $self->{api_ver} );

    if ( $self->{background} ) {
        if ( $self->{background} > 1 ) {
            main::print_log( "[Venstar Colortouch:" . $self->{data}->{name} . "] Background mode enabled" );
        }
        else {
            main::print_log( "[Venstar Colortouch:" . $self->{data}->{name} . "] Hybrid mode enabled (Background commands, direct polling)" );
        }
    }
    else {
        main::print_log( "[Venstar Colortouch:" . $self->{data}->{name} . "] Direct mode enabled" );
    }
    main::print_log( "[Venstar Colortouch:" . $self->{data}->{name} . "] Communicating using $self->{method}" );
    main::print_log( "[Venstar Colortouch:" . $self->{data}->{name} . "] Fan mode is set to " . $fan[ $self->{data}->{info}->{fan} ] );
    main::print_log( "[Venstar Colortouch:" . $self->{data}->{name} . "] Fan is currently " . $fanstate[ $self->{data}->{info}->{fanstate} ] );
    main::print_log( "[Venstar Colortouch:" . $self->{data}->{name} . "] System mode is " . $mode[ $self->{data}->{info}->{mode} ] );
    main::print_log( "[Venstar Colortouch:" . $self->{data}->{name} . "] System is " . $state[ $self->{data}->{info}->{state} ] );

    my $sch = " ";
    $sch = " not " if ( $self->{data}->{info}->{schedule} == 0 );
    main::print_log( "[Venstar Colortouch:" . $self->{data}->{name} . "] System is" . $sch . "on a schedule" );

    main::print_log( "[Venstar Colortouch:" . $self->{data}->{name} . "] System schedule is " . $schedule[ $self->{data}->{info}->{schedulepart} ] );

    my $away = "home mode";
    $away = "away mode" if ( $self->{data}->{info}->{away} );
    main::print_log( "[Venstar Colortouch:" . $self->{data}->{name} . "] System is currently on $away" );

    main::print_log( "[Venstar Colortouch:" . $self->{data}->{name} . "] Current Temperature: " . $self->{data}->{info}->{spacetemp} . "$unit" );
    main::print_log( "[Venstar Colortouch:" . $self->{data}->{name} . "] Current Humidity:" . $self->{data}->{info}->{hum} . "%" )
      if ( $self->{api_ver} < 5 );

    main::print_log( "[Venstar Colortouch:" . $self->{data}->{name} . "] Current Setpoint\tMin\tMax" );
    main::print_log( "[Venstar Colortouch:"
          . $self->{data}->{name}
          . "] Heat:\t"
          . $self->{data}->{info}->{heattemp}
          . "$unit\t\t"
          . $self->{data}->{info}->{heattempmin}
          . "$unit\t"
          . $self->{data}->{info}->{heattempmax}
          . "$unit" );
    main::print_log( "[Venstar Colortouch:"
          . $self->{data}->{name}
          . "] Cool:\t"
          . $self->{data}->{info}->{cooltemp}
          . "$unit\t\t"
          . $self->{data}->{info}->{cooltempmin}
          . "$unit\t"
          . $self->{data}->{info}->{cooltempmax}
          . "$unit" );
    my $hum_value = $self->{data}->{info}->{hum_setpoint};
    $hum_value = $self->{data}->{info}->{dehum_setpoint}
      if ( $self->{api_ver} >= 5 );
    main::print_log( "[Venstar Colortouch:" . $self->{data}->{name} . "] Humidity:\t" . $hum_value . "%" )
      unless ( $hum_value == 99 );
    main::print_log( "[Venstar Colortouch:" . $self->{data}->{name} . "] Dehumidity:" . $self->{data}->{info}->{dehum_setpoint} . "%" )
      unless ( ( $self->{data}->{info}->{dehum_setpoint} == 99 )
        or ( $self->{api_ver} >= 5 ) );

    main::print_log( "[Venstar Colortouch:" . $self->{data}->{name} . "] Setpoint Delta: " . $self->{data}->{info}->{setpointdelta} . "$unit" );

    main::print_log( "[Venstar Colortouch:"
          . $self->{data}->{name}
          . "] Current Thermostat Sensor Temperature:"
          . $self->{data}->{sensors}->{sensors}[0]->{temp}
          . "$unit" );
    main::print_log(
        "[Venstar Colortouch:" . $self->{data}->{name} . "] Current Thermostat Sensor Humidity:" . $self->{data}->{sensors}->{sensors}[0]->{hum} . "%" );

    if ( $self->{data}->{sensors}->{sensors}[1]->{temp} != -39 ) {
        main::print_log(
            "[Venstar Colortouch:" . $self->{data}->{name} . "] Current Outdoor Sensor Temperature:" . $self->{data}->{sensors}->{sensors}[1]->{temp} );
    }
    else {
        main::print_log( "[Venstar Colortouch:" . $self->{data}->{name} . "] Outdoor Temperature Sensor not connected" );
    }
}

sub process_data {
    my ($self) = @_;

    # Main core of processing
    # set state of self for state
    # for any registered child selfs, update their state if

    main::print_log( "[Venstar Colortouch:" . $self->{data}->{name} . "] Processing Data..." )
      if ( $self->{debug} );

    my ( @fan, @fanstate, @mode, @state, @schedule );
    $fan[0]        = "auto";
    $fan[1]        = "on";
    $fanstate[0]   = "off";
    $fanstate[1]   = "on";
    $mode[0]       = "off";
    $mode[1]       = "heating";
    $mode[2]       = "cooling";
    $mode[3]       = "auto";
    $state[0]      = "idle";
    $state[1]      = "heating";
    $state[2]      = "cooling";
    $state[3]      = "lockout";
    $state[4]      = "error";
    $schedule[0]   = "morning (occupied 1)";
    $schedule[1]   = "day (occupied 2)";
    $schedule[2]   = "evening (occupied 3)";
    $schedule[3]   = "night (occupied 4)";
    $schedule[255] = "inactive";

    if ( $self->{previous}->{tempunits} != $self->{data}->{tempunits} ) {
        main::print_log(
            "[Venstar Colortouch:" . $self->{data}->{name} . "] Temperature Units changed from $self->{previous}->{tempunits} to $self->{data}->{tempunits}" );
        main::print_log( "[Venstar Colortouch:" . $self->{data}->{name} . "] This really isn't a regular operation. Should check Thermostat to confirm" );
        $self->{previous}->{tempunits} = $self->{data}->{tempunits};
    }

    if ( $self->{previous}->{name} ne $self->{data}->{name} ) {
        main::print_log( "[Venstar Colortouch:" . $self->{data}->{name} . "] Device Name changed from $self->{previous}->{name} to $self->{data}->{name}" );
        main::print_log( "[Venstar Colortouch:" . $self->{data}->{name} . "] This really isn't a regular operation. Should check Thermostat to confirm" );
        $self->{previous}->{name} = $self->{data}->{name};
    }

    if ( $self->{previous}->{info}->{availablemodes} != $self->{data}->{info}->{availablemodes} ) {
        main::print_log( "[Venstar Colortouch:"
              . $self->{data}->{name}
              . "] Available Modes changed from $self->{previous}->{info}->{availablemodes} to $self->{data}->{info}->{availablemodes}" );
        main::print_log( "[Venstar Colortouch:" . $self->{data}->{name} . "] This really isn't a regular operation. Should check Thermostat to confirm" );
        $self->{previous}->{info}->{availablemodes} = $self->{data}->{info}->{availablemodes};
    }

    if ( $self->{previous}->{info}->{fan} != $self->{data}->{info}->{fan} ) {
        main::print_log(
            "[Venstar Colortouch:" . $self->{data}->{name} . "] Fan changed from $fan[$self->{previous}->{info}->{fan}] to $fan[$self->{data}->{info}->{fan}]" )
          if ( $self->{loglevel} );
        $self->{previous}->{info}->{fan} = $self->{data}->{info}->{fan};
        if ( defined $self->{child_object}->{fanstate} ) {
            main::print_log "[Venstar Colortouch:" . $self->{data}->{name} . "] Fan Child object found. Updating..."
              if ( $self->{loglevel} );
            $self->{child_object}->{fanstate}->set_mode( $fan[ $self->{data}->{info}->{fan} ] );
        }
    }

    if ( $self->{previous}->{info}->{fanstate} != $self->{data}->{info}->{fanstate} ) {
        main::print_log( "[Venstar Colortouch:"
              . $self->{data}->{name}
              . "] Fan state changed from $fanstate[$self->{previous}->{info}->{fanstate}] to $fanstate[$self->{data}->{info}->{fanstate}]" )
          if ( $self->{loglevel} );
        $self->{previous}->{info}->{fanstate} = $self->{data}->{info}->{fanstate};
        if ( defined $self->{child_object}->{fanstate} ) {
            main::print_log "[Venstar Colortouch:" . $self->{data}->{name} . "] Fan state Child object found. Updating..."
              if ( $self->{loglevel} );
            $self->{child_object}->{fanstate}->set( $fanstate[ $self->{data}->{info}->{fanstate} ], 'poll' );
        }
    }

    if ( $self->{previous}->{info}->{mode} != $self->{data}->{info}->{mode} ) {
        main::print_log( "[Venstar Colortouch:"
              . $self->{data}->{name}
              . "] Mode changed from $mode[$self->{previous}->{info}->{mode}] to $mode[$self->{data}->{info}->{mode}]" )
          if ( $self->{loglevel} );
        $self->{previous}->{info}->{mode} = $self->{data}->{info}->{mode};
        if ( defined $self->{child_object}->{mode} ) {
            main::print_log "[Venstar Colortouch:" . $self->{data}->{name} . "] Mode Child object found. Updating..."
              if ( $self->{loglevel} );
            $self->{child_object}->{mode}->set( $mode[ $self->{data}->{info}->{mode} ] );
        }

    }

    if ( $self->{previous}->{info}->{state} != $self->{data}->{info}->{state} ) {
        main::print_log( "[Venstar Colortouch:"
              . $self->{data}->{name}
              . "] Thermostat state changed from $state[$self->{previous}->{info}->{state}] to $state[$self->{data}->{info}->{state}]" )
          if ( $self->{loglevel} );
        $self->{previous}->{info}->{state} = $self->{data}->{info}->{state};
        $self->set( $state[ $self->{data}->{info}->{state} ], 'poll' );
    }

    if ( $self->{previous}->{info}->{schedule} != $self->{data}->{info}->{schedule} ) {
        my $sch = " ";
        my @sched;
        $sched[0] = "off";
        $sched[1] = "on";
        $sch = " not " if ( !$self->{data}->{info}->{schedule} );
        main::print_log( "[Venstar Colortouch:" . $self->{data}->{name} . "] Thermostat state changed to" . $sch . "on a schedule" )
          if ( $self->{loglevel} );
        $self->{previous}->{info}->{schedule} = $self->{data}->{info}->{schedule};
        if ( defined $self->{child_object}->{sched} ) {
            main::print_log "[Venstar Colortouch:" . $self->{data}->{name} . "] Schedule Child object found. Updating..."
              if ( $self->{loglevel} );
            $self->{child_object}->{sched}->set( $sched[ $self->{data}->{info}->{schedule} ], 'poll' );
        }
    }

    if ( $self->{previous}->{info}->{schedulepart} != $self->{data}->{info}->{schedulepart} ) {
        main::print_log( "[Venstar Colortouch:"
              . $self->{data}->{name}
              . "] Thermostat schedule changed from $schedule[$self->{previous}->{info}->{schedulepart}] to $schedule[$self->{data}->{info}->{schedulepart}]" )
          if ( $self->{loglevel} );
        $self->{previous}->{info}->{schedulepart} = $self->{data}->{info}->{schedulepart};
    }

    if (    $self->{type} eq "residential"
        and $self->{previous}->{info}->{away} != $self->{data}->{info}->{away} )
    {
        my $away = "home mode";
        $away = "away mode" if ( $self->{data}->{info}->{away} );
        main::print_log( "[Venstar Colortouch:" . $self->{data}->{name} . "] Thermostat occupancy changed to " . $away )
          if ( $self->{loglevel} );
        $self->{previous}->{info}->{away} = $self->{data}->{info}->{away};
    }

    if (    $self->{type} eq "commercial"
        and $self->{previous}->{info}->{holiday} != $self->{data}->{info}->{holiday} )
    {
        my $holiday = "observing holiday";
        $holiday = "no holiday" if ( $self->{data}->{info}->{holiday} );
        main::print_log( "[Venstar Colortouch:" . $self->{data}->{name} . "] Thermostat holiday changed to " . $holiday )
          if ( $self->{loglevel} );
        $self->{previous}->{info}->{holiday} = $self->{data}->{info}->{holiday};
    }

    if (    $self->{type} eq "commercial"
        and $self->{previous}->{info}->{override} != $self->{data}->{info}->{override} )
    {
        my $override = "off";
        $override = "on" if ( $self->{data}->{info}->{override} );
        main::print_log( "[Venstar Colortouch:" . $self->{data}->{name} . "] Thermostat override changed to " . $override )
          if ( $self->{loglevel} );
        $self->{previous}->{info}->{override} = $self->{data}->{info}->{override};
    }

    if (    $self->{type} eq "commercial"
        and $self->{previous}->{info}->{overridetime} != $self->{data}->{info}->{overridetime} )
    {
        main::print_log( "[Venstar Colortouch:" . $self->{data}->{name} . "] Thermostat overridetime changed to " . $self->{data}->{info}->{overridetime} )
          if ( $self->{loglevel} );
        $self->{previous}->{info}->{overridetime} = $self->{data}->{info}->{overridetime};
    }

    if (    $self->{type} eq "commercial"
        and $self->{previous}->{info}->{forceunocc} != $self->{data}->{info}->{forceunocc} )
    {
        my $forceunocc = "off";
        $forceunocc = "on" if ( $self->{data}->{info}->{forceunocc} );
        main::print_log( "[Venstar Colortouch:" . $self->{data}->{name} . "] Thermostat forceunocc changed to " . $forceunocc )
          if ( $self->{loglevel} );
        $self->{previous}->{info}->{forceunocc} = $self->{data}->{info}->{forceunocc};
    }

    if ( $self->{previous}->{info}->{spacetemp} != $self->{data}->{info}->{spacetemp} ) {
        main::print_log( "[Venstar Colortouch:"
              . $self->{data}->{name}
              . "] Thermostat temperature changed from $self->{previous}->{info}->{spacetemp} to $self->{data}->{info}->{spacetemp}" )
          if ( $self->{loglevel} );
        $self->{previous}->{info}->{spacetemp} = $self->{data}->{info}->{spacetemp};
        if ( defined $self->{child_object}->{temp} ) {
            main::print_log "[Venstar Colortouch:" . $self->{data}->{name} . "] Temperature Sensor Child object found. Updating..."
              if ( $self->{loglevel} );
            $self->{child_object}->{temp}->set( $self->{data}->{info}->{spacetemp}, 'poll' );
        }
    }

    if ( $self->{previous}->{info}->{heattemp} != $self->{data}->{info}->{heattemp} ) {
        main::print_log( "[Venstar Colortouch:"
              . $self->{data}->{name}
              . "] Thermostat heating setpoint changed from $self->{previous}->{info}->{heattemp} to $self->{data}->{info}->{heattemp}" )
          if ( $self->{loglevel} );
        $self->{previous}->{info}->{heattemp} = $self->{data}->{info}->{heattemp};
        if ( defined $self->{child_object}->{heat_sp} ) {
            main::print_log "[Venstar Colortouch:" . $self->{data}->{name} . "] Heat Setpoint Child object found. Updating..."
              if ( $self->{loglevel} );
            $self->{child_object}->{heat_sp}->set( $self->{data}->{info}->{heattemp}, 'poll' );
        }
    }

    if ( $self->{previous}->{info}->{heattempmin} != $self->{data}->{info}->{heattempmin} ) {
        main::print_log( "[Venstar Colortouch:"
              . $self->{data}->{name}
              . "] Thermostat heating setpoint minimum changed from $self->{previous}->{info}->{heattempmin} to $self->{data}->{info}->{heattempmin}" )
          if ( $self->{loglevel} );
        $self->{previous}->{info}->{heattempmin} = $self->{data}->{info}->{heattempmin};
    }

    if ( $self->{previous}->{info}->{heattempmax} != $self->{data}->{info}->{heattempmax} ) {
        main::print_log( "[Venstar Colortouch:"
              . $self->{data}->{name}
              . "] Thermostat heating setpoint maximum changed from $self->{previous}->{info}->{heattempmax} to $self->{data}->{info}->{heattempmax}" )
          if ( $self->{loglevel} );
        $self->{previous}->{info}->{heattempmax} = $self->{data}->{info}->{heattempmax};
    }

    if ( $self->{previous}->{info}->{cooltemp} != $self->{data}->{info}->{cooltemp} ) {
        main::print_log( "[Venstar Colortouch:"
              . $self->{data}->{name}
              . "] Thermostat cooling setpoint changed from $self->{previous}->{info}->{cooltemp} to $self->{data}->{info}->{cooltemp}" )
          if ( $self->{loglevel} );
        $self->{previous}->{info}->{cooltemp} = $self->{data}->{info}->{cooltemp};
        if ( defined $self->{child_object}->{cool_sp} ) {
            main::print_log "[Venstar Colortouch:" . $self->{data}->{name} . "] Cooling Setpoint Child object found. Updating..."
              if ( $self->{loglevel} );
            $self->{child_object}->{cool_sp}->set( $self->{data}->{info}->{cooltemp}, 'poll' );
        }
    }

    if ( $self->{previous}->{info}->{cooltempmin} != $self->{data}->{info}->{cooltempmin} ) {
        main::print_log( "[Venstar Colortouch:"
              . $self->{data}->{name}
              . "] Thermostat cooling setpoint minimum changed from $self->{previous}->{info}->{cooltempmin} to $self->{data}->{info}->{cooltempmin}" )
          if ( $self->{loglevel} );
        $self->{previous}->{info}->{cooltempmin} = $self->{data}->{info}->{cooltempmin};
    }

    if ( $self->{previous}->{info}->{cooltempmax} != $self->{data}->{info}->{cooltempmax} ) {
        main::print_log( "[Venstar Colortouch:"
              . $self->{data}->{name}
              . "] Thermostat cooling setpoint maximum changed from $self->{previous}->{info}->{cooltempmax} to $self->{data}->{info}->{cooltempmax}" )
          if ( $self->{loglevel} );
        $self->{previous}->{info}->{cooltempmax} = $self->{data}->{info}->{cooltempmax};
    }

    if ( $self->{previous}->{info}->{dehum_setpoint} != $self->{data}->{info}->{dehum_setpoint} ) {
        if ( $self->{api_ver} >= 5 ) {    #v5, dehum_setpoint is now the humidity setpoint?
            main::print_log( "[Venstar Colortouch:"
                  . $self->{data}->{name}
                  . "] Thermostat humidity setpoint changed from $self->{previous}->{info}->{dehum_setpoint} to $self->{data}->{info}->{dehum_setpoint}" )
              if ( $self->{loglevel} );
            $self->{previous}->{info}->{dehum_setpoint} = $self->{data}->{info}->{dehum_setpoint};
            if ( defined $self->{child_object}->{hum_sp} ) {
                main::print_log "[Venstar Colortouch:" . $self->{data}->{name} . "] Humidify Child object found. Updating..."
                  if ( $self->{loglevel} );
                $self->{child_object}->{hum_sp}->set( $self->{data}->{info}->{dehum_setpoint}, 'poll' );
            }
        }
        else {
            main::print_log( "[Venstar Colortouch:"
                  . $self->{data}->{name}
                  . "] Thermostat dehumidity setpoint changed from $self->{previous}->{info}->{dehum_setpoint} to $self->{data}->{info}->{dehum_setpoint}" )
              if ( $self->{loglevel} );
            $self->{previous}->{info}->{dehum_setpoint} = $self->{data}->{info}->{dehum_setpoint};
            if ( defined $self->{child_object}->{dehum_sp} ) {
                main::print_log "[Venstar Colortouch:" . $self->{data}->{name} . "] Dehumidify Child object found. Updating..."
                  if ( $self->{loglevel} );
                $self->{child_object}->{dehum_sp}->set( $self->{data}->{info}->{dehum_setpoint}, 'poll' );
            }
        }
    }

    if ( $self->{previous}->{info}->{hum_setpoint} != $self->{data}->{info}->{hum_setpoint} ) {
        if ( $self->{api_ver} < 5 ) {    #v5, hum_setpoint is now the humidity sensor?
            main::print_log( "[Venstar Colortouch:"
                  . $self->{data}->{name}
                  . "] Thermostat humidity setpoint changed from $self->{previous}->{info}->{hum_setpoint} to $self->{data}->{info}->{hum_setpoint}" )
              if ( $self->{loglevel} );
            $self->{previous}->{info}->{hum_setpoint} = $self->{data}->{info}->{hum_setpoint};
            if ( defined $self->{child_object}->{hum_sp} ) {
                main::print_log "[Venstar Colortouch:" . $self->{data}->{name} . "] Humidify Child object found. Updating..."
                  if ( $self->{loglevel} );
                $self->{child_object}->{hum_sp}->set( $self->{data}->{info}->{hum_setpoint}, 'poll' );
            }
        }
    }

    #if ($self->{previous}->{info}->{hum} != $self->{data}->{info}->{hum}) {
    #  main::print_log("[Venstar Colortouch:". $self->{data}->{name} . "] Thermostat humidity changed from $self->{previous}->{info}->{hum} to $self->{data}->{info}->{hum}") if ($self->{loglevel});
    #  $self->{previous}->{info}->{hum} = $self->{data}->{info}->{hum};
    #}

    if ( $self->{previous}->{info}->{setpointdelta} != $self->{data}->{info}->{setpointdelta} ) {
        main::print_log( "[Venstar Colortouch:"
              . $self->{data}->{name}
              . "] Thermostat setpoint delta changed from $self->{previous}->{info}->{setpointdelta} to $self->{data}->{info}->{setpointdelta}" )
          if ( $self->{loglevel} );
        $self->{previous}->{info}->{setpointdelta} = $self->{data}->{info}->{setpointdelta};
    }

    if ( $self->{previous}->{sensors}->{sensors}[0]->{hum} != $self->{data}->{sensors}->{sensors}[0]->{hum} ) {
        main::print_log( "[Venstar Colortouch:"
              . $self->{data}->{name}
              . "] Thermostat Humidity Sensor changed from $self->{previous}->{sensors}->{sensors}[0]->{hum} to $self->{data}->{sensors}->{sensors}[0]->{hum}" )
          if ( $self->{loglevel} );
        $self->{previous}->{sensors}->{sensors}[0]->{hum} = $self->{data}->{sensors}->{sensors}[0]->{hum};
        if ( defined $self->{child_object}->{hum} ) {
            main::print_log "[Venstar Colortouch:" . $self->{data}->{name} . "] Humidity Sensor Child object found. Updating..."
              if ( $self->{loglevel} );
            $self->{child_object}->{hum}->set( $self->{data}->{sensors}->{sensors}[0]->{hum}, 'poll' );
        }
    }

}

sub print_runtimes {
    my ($self) = @_;
    my ( $isSuccessResponse1, $data ) = get_JSON_data( $self->{host}, 'runtimes' );

    for my $tstamp ( 0 .. $#{ $data->{runtimes} } ) {

        print $data->{runtimes}[$tstamp]->{ts} . " -> ";
        print scalar localtime( ( $data->{runtimes}[$tstamp]->{ts} ) - ( $self->{config}->{tz} * 60 * 60 + 1 ) );
        main::print_log( "\tCooling: " . $data->{runtimes}[$tstamp]->{cool1} );
        main::print_log( "\tHeating: " . $data->{runtimes}[$tstamp]->{heat1} );
        main::print_log( "\tCooling 2: " . $data->{runtimes}[$tstamp]->{cool2} )
          if $data->{runtimes}[$tstamp]->{cool2};
        main::print_log( "\tHeating 2: " . $data->{runtimes}[$tstamp]->{heat2} )
          if $data->{runtimes}[$tstamp]->{heat2};
        main::print_log( "\tAux 1: " . $data->{runtimes}[$tstamp]->{aux1} )
          if $data->{runtimes}[$tstamp]->{aux1};
        main::print_log( "\tAux 2: " . $data->{runtimes}[$tstamp]->{aux2} )
          if $data->{runtimes}[$tstamp]->{aux2};
        main::print_log( "\tFree Cooling: " . $data->{runtimes}[$tstamp]->{fc} )
          if $data->{runtimes}[$tstamp]->{fc};

    }
}

#------------
# User access methods

sub get_apiver {
    my ($self) = @_;

    return ( $self->{api_ver} );
}

sub get_mode {
    my ($self) = @_;
    my @mode;
    $mode[0] = "off";
    $mode[1] = "heating";
    $mode[2] = "cooling";
    $mode[3] = "auto";

    #  my ($isSuccessResponse) = $self->poll;
    #  if ($isSuccessResponse) {
    return ( $mode[ $self->{data}->{info}->{mode} ] );

    #  } else {
    #  	return ("unknown");
    #  }
}

sub get_fan_mode {
    my ($self) = @_;
    my @fan;
    $fan[0] = "auto";
    $fan[1] = "on";

    #  my ($isSuccessResponse) = $self->poll;
    #  if ($isSuccessResponse) {
    return ( $fan[ $self->{data}->{info}->{fan} ] );

    #  } else {
    #  	return ("unknown");
    #  }
}

sub get_fan {
    my ($self) = @_;
    my @fanstate;
    $fanstate[0] = "off";
    $fanstate[1] = "running";

    #  my ($isSuccessResponse) = $self->poll;
    #  if ($isSuccessResponse) {
    return ( $fanstate[ $self->{data}->{info}->{fanstate} ] );

    #  } else {
    #  	return ("unknown");
    #  }
}

sub get_sp_heat {
    my ($self) = @_;

    #  my ($isSuccessResponse) = $self->poll;
    #    if ($isSuccessResponse) {
    return ( $self->{data}->{info}->{heattemp} );

    #  } else {
    #  	return ("unknown");
    #  }
}

sub get_sp_cool {
    my ($self) = @_;

    #  my ($isSuccessResponse) = $self->poll;
    #    if ($isSuccessResponse) {
    return ( $self->{data}->{info}->{cooltemp} );

    #  } else {
    #  	return ("unknown");
    #  }
}

sub get_sp_hum {
    my ($self) = @_;
    my $value = $self->{data}->{info}->{hum_setpoint};
    $value = $self->{data}->{info}->{dehum_setpoint}
      if ( $self->{api_ver} >= 5 );
    return ($value);
}

sub get_sp_dehum {
    my ($self) = @_;
    main::print_log("[Venstar_Colortouch]: WARNING, api v5 humidity settings are questionable.") if ( $self->{api_ver} >= 5 );
    return ( $self->{data}->{info}->{dehum_setpoint} );

}

sub get_units {
    my ($self) = @_;
    my @units;
    $units[0] = "F";
    $units[1] = "C";

    #  my ($isSuccessResponse) = $self->poll;
    #    if ($isSuccessResponse) {
    return ( $units[ $self->{data}->{tempunits} ] );

    #  } else {
    #  	return ("unknown");
    #  }
}

sub get_temp {
    my ($self, $index) = @_;

    $index=0 unless ( defined $index );


    #  my ($isSuccessResponse) = $self->poll;
    #    if ($isSuccessResponse) {
    return ( $self->{data}->{sensors}->{sensors}[$index]->{temp} );

    #  } else {
    #  	return ("unknown");
    #  }
}

sub get_hum {
    my ($self) = @_;

    #  my ($isSuccessResponse) = $self->poll;
    #    if ($isSuccessResponse) {
    return ( $self->{data}->{sensors}->{sensors}[0]->{hum} );

    #  } else {
    #  	return ("unknown");
    #  }
}

sub get_sched {
    my ($self) = @_;
    my @sched;
    $sched[0] = "off";
    $sched[1] = "on";

    return ( $sched[ $self->{data}->{info}->{schedule} ] );
}

sub get_lastpoll {
    my ($self) = @_;
    return ( time() - $self->{data}->{timestamp} );
}

sub get_mode_cool {
    my ($self) = @_;
    my $can_cool = 0;
    $can_cool = 1 unless ( $self->{data}->{info}->{availablemodes} == 2 );
    return $can_cool;
}

sub get_mode_heat {
    my ($self) = @_;
    my $can_heat = 0;
    $can_heat = 1 unless ( $self->{data}->{info}->{availablemodes} == 3 );
    return $can_heat;
}

sub get_mode_humid {
    my ($self) = @_;
    my $value = 0;    #0 no humidify, 1 humidify, 2 dehumidify, 3 both
    $value = 1 if ( $self->{data}->{info}->{hum_setpoint} != 99 );
    $value = 2 if ( $self->{data}->{info}->{dehum_setpoint} != 99 );
    $value = 3
      if (  ( $self->{data}->{info}->{dehum_setpoint} != 99 )
        and ( $self->{data}->{info}->{hum_setpoint} != 99 ) );

    return $value;

}

sub get_debug {
    my ($self) = @_;
    return $self->{debug};
}

#------------
# User control methods
#tempunits=0&away=0&schedule=0&hum_setpoint=0&dehum_setpoint=0
#mode=0&fan=0&heattemp=70&cooltemp=75
#($isSuccessResponse3,$status) = push_JSON_data($host,'control','fan=0');
#($isSuccessResponse3,$status) = push_JSON_data($host,'settings','away=0&schedule=1');

sub set_heat_sp {
    my ( $self, $value ) = @_;
    my ( $isSuccessResponse, $status ) = $self->_push_JSON_data( 'control', "heattemp=$value" );
    if ($isSuccessResponse) {
        if ( $status eq "success" ) {
            return (1);
        }
        else {
            main::print_log( "[Venstar Colortouch:" . $self->{data}->{name} . "] Error. Could not set heating setpoint to $value" );
            return (0);
        }
    }
    else {
        main::print_log( "[Venstar Colortouch:" . $self->{data}->{name} . "] Error. Could not send data to Thermostat" );
        return (0);
    }
}

sub set_cool_sp {
    my ( $self, $value ) = @_;

    my ( $isSuccessResponse, $status ) = $self->_push_JSON_data( 'control', "cooltemp=$value" );
    if ($isSuccessResponse) {
        if ( $status eq "success" ) {
            return (1);
        }
        else {
            main::print_log( "[Venstar Colortouch:" . $self->{data}->{name} . "] Error. Could not set cooling setpoint to $value" );
            return (0);
        }
    }
    else {
        main::print_log( "[Venstar Colortouch:" . $self->{data}->{name} . "] Error. Could not send data to Thermostat" );
        return (0);
    }
}

sub set_hum_sp {
    my ( $self, $value ) = @_;

    my ( $isSuccessResponse, $status ) = $self->_push_JSON_data( 'settings', "hum_setpoint=$value" );
    if ($isSuccessResponse) {
        if ( $status eq "success" ) {
            return (1);
        }
        else {
            main::print_log( "[Venstar Colortouch:" . $self->{data}->{name} . "] Error. Could not set humidity setpoint to $value" );
            return (0);
        }
    }
    else {
        main::print_log( "[Venstar Colortouch:" . $self->{data}->{name} . "] Error. Could not send data to Thermostat" );
        return (0);
    }
}

sub set_dehum_sp {
    my ( $self, $value ) = @_;

    my ( $isSuccessResponse, $status ) = $self->_push_JSON_data( 'settings', "dehum_setpoint=$value" );
    if ($isSuccessResponse) {
        if ( $status eq "success" ) {
            return (1);
        }
        else {
            main::print_log( "[Venstar Colortouch:" . $self->{data}->{name} . "] Error. Could not set humidity setpoint to $value" );
            return (0);
        }
    }
    else {
        main::print_log( "[Venstar Colortouch:" . $self->{data}->{name} . "] Error. Could not send data to Thermostat" );
        return (0);
    }
}

sub set_schedule {
    my ( $self, $value ) = @_;
    my $num;
    if ( lc $value eq "off" ) {
        $num = 0;
    }
    elsif ( lc $value eq "on" ) {
        $num = 1;
    }
    else {
        main::print_log( "Venstar Colortouch:" . $self->{data}->{name} . "] Error, unknown schedule mode $value" );
        return ('0');
    }
    my ( $isSuccessResponse, $status ) = $self->_push_JSON_data( 'settings', "schedule=$num" );
    if ($isSuccessResponse) {
        if ( $status eq "success" ) {
            return (1);
        }
        else {
            main::print_log( "[Venstar Colortouch:" . $self->{data}->{name} . "] Error. Could not set schedule mode to $value" );
            return (0);
        }
    }
    else {
        main::print_log( "[Venstar Colortouch:" . $self->{data}->{name} . "] Error. Could not send data to Thermostat" );
    }
}

sub set_mode {
    my ( $self, $value ) = @_;

    my $num;
    if (    ( lc $value eq lc "auto" )
        and ( $self->{data}->{info}->{availablemodes} == 0 ) )
    {
        $num = 3;
    }
    elsif ( ( ( lc $value eq lc "cooling" ) or ( lc $value eq lc "cool" ) )
        and ( $self->{data}->{info}->{availablemodes} != 2 ) )
    {
        $num = 2;
    }
    elsif ( ( ( lc $value eq lc "heating" ) or ( lc $value eq lc "heat" ) )
        and ( $self->{data}->{info}->{availablemodes} != 3 ) )
    {
        $num = 1;
    }
    elsif ( lc $value eq lc "off" ) {
        $num = 0;
    }
    else {
        main::print_log( "Venstar Colortouch:"
              . $self->{data}->{name}
              . "] Error, unknown mode $value or mismatch with Thermostat Modes"
              . $self->{data}->{info}->{availablemodes} );
        return ('0');
    }

    my ( $isSuccessResponse, $status ) = $self->_push_JSON_data( 'control', "mode=$num" );
    if ($isSuccessResponse) {
        if ( $status eq "success" ) {    #todo parse return value
            $self->poll;
            return (1);
        }
        else {
            main::print_log( "[Venstar Colortouch:" . $self->{data}->{name} . "] Error. Could not set mode to $value" );
            return (0);
        }
    }
    else {
        main::print_log( "[Venstar Colortouch:" . $self->{data}->{name} . "] Error. Could not send data to Thermostat" );
        return (0);
    }

}

sub set_away {
    my ( $self, $value ) = @_;
    return unless $self->{type} eq "residential";
    my $num;
    if ( lc $value eq "off" ) {
        $num = 0;
    }
    elsif ( lc $value eq lc "on" ) {
        $num = 1;
    }
    else {
        main::print_log( "Venstar Colortouch:" . $self->{data}->{name} . "] Error, unknown away mode $value" );
        return ('0');
    }
    my ( $isSuccessResponse, $status ) = $self->_push_JSON_data( 'control', "away=$num" );
    if ($isSuccessResponse) {
        if ( $status eq "success" ) {
            return (1);
        }
        else {
            main::print_log( "[Venstar Colortouch:" . $self->{data}->{name} . "] Error. Could not set away to $num" );
            return (0);
        }
    }
    else {
        main::print_log( "[Venstar Colortouch:" . $self->{data}->{name} . "] Error. Could not send data to Thermostat" );
        return (0);
    }
}

sub set_holiday {
    my ( $self, $value ) = @_;
    return unless $self->{type} eq "commercial";
    my $num;
    if ( lc $value eq "off" ) {
        $num = 0;
    }
    elsif ( lc $value eq lc "on" ) {
        $num = 1;
    }
    else {
        main::print_log( "Venstar Colortouch:" . $self->{data}->{name} . "] Error, unknown holiday $value" );
        return ('0');
    }
    my ( $isSuccessResponse, $status ) = $self->_push_JSON_data( 'settings', "holiday=$num" );
    if ($isSuccessResponse) {
        if ( $status eq "success" ) {
            return (1);
        }
        else {
            main::print_log( "[Venstar Colortouch:" . $self->{data}->{name} . "] Error. Could not set holiday to $num" );
            return (0);
        }
    }
    else {
        main::print_log( "[Venstar Colortouch:" . $self->{data}->{name} . "] Error. Could not send data to Thermostat" );
        return (0);
    }
}

sub set_override {
    my ( $self, $value ) = @_;
    return unless $self->{type} eq "commercial";
    my $num;
    if ( lc $value eq "off" ) {
        $num = 0;
    }
    elsif ( lc $value eq lc "on" ) {
        $num = 1;
    }
    else {
        main::print_log( "Venstar Colortouch:" . $self->{data}->{name} . "] Error, unknown override $value" );
        return ('0');
    }
    my ( $isSuccessResponse, $status ) = $self->_push_JSON_data( 'settings', "override=$num" );
    if ($isSuccessResponse) {
        if ( $status eq "success" ) {
            return (1);
        }
        else {
            main::print_log( "[Venstar Colortouch:" . $self->{data}->{name} . "] Error. Could not set override to $num" );
            return (0);
        }
    }
    else {
        main::print_log( "[Venstar Colortouch:" . $self->{data}->{name} . "] Error. Could not send data to Thermostat" );
        return (0);
    }
}

sub set_overridetime {
    my ( $self, $value ) = @_;
    return unless $self->{type} eq "commercial";
    my ( $isSuccessResponse, $status ) = $self->_push_JSON_data( 'settings', "overridetime=$value" );
    if ($isSuccessResponse) {
        if ( $status eq "success" ) {
            return (1);
        }
        else {
            main::print_log( "[Venstar Colortouch:" . $self->{data}->{name} . "] Error. Could not set overridetime to $value" );
            return (0);
        }
    }
    else {
        main::print_log( "[Venstar Colortouch:" . $self->{data}->{name} . "] Error. Could not send data to Thermostat" );
        return (0);
    }
}

sub set_forceunocc {
    my ( $self, $value ) = @_;
    return unless $self->{type} eq "commercial";
    my $num;
    if ( lc $value eq "off" ) {
        $num = 0;
    }
    elsif ( lc $value eq lc "on" ) {
        $num = 1;
    }
    else {
        main::print_log( "Venstar Colortouch:" . $self->{data}->{name} . "] Error, unknown forceunocc mode $value" );
        return ('0');
    }
    my ( $isSuccessResponse, $status ) = $self->_push_JSON_data( 'settings', "forceunocc=$num" );
    if ($isSuccessResponse) {
        if ( $status eq "success" ) {
            return (1);
        }
        else {
            main::print_log( "[Venstar Colortouch:" . $self->{data}->{name} . "] Error. Could not set forceunocc to $num" );
            return (0);
        }
    }
    else {
        main::print_log( "[Venstar Colortouch:" . $self->{data}->{name} . "] Error. Could not send data to Thermostat" );
        return (0);
    }
}

sub set_fan {
    my ( $self, $value ) = @_;

    my $num;
    if ( ( lc $value eq lc "auto" ) or ( lc $value eq "off" ) ) {
        $num = 0;
    }
    elsif ( lc $value eq lc "on" ) {
        $num = 1;
    }
    else {
        main::print_log( "Venstar Colortouch:" . $self->{data}->{name} . "] Error, unknown fan mode $value" );
        return ('0');
    }
    my ( $isSuccessResponse, $status ) = $self->_push_JSON_data( 'control', "fan=$num" );
    if ($isSuccessResponse) {
        if ( $status eq "success" ) {
            return (1);
        }
        else {
            main::print_log( "[Venstar Colortouch:" . $self->{data}->{name} . "] Error. Could not set fan mode to $value" );
            return (0);
        }
    }
    else {
        main::print_log( "[Venstar Colortouch:" . $self->{data}->{name} . "] Error. Could not send data to Thermostat" );
        return (0);
    }

}

sub set_units {

    #($isSuccessResponse3,$status) = push_JSON_data($host,'settings','away=0&schedule=1');

}

sub set_debug {
    my ( $self, $debug ) = @_;
    $self->{debug} = $debug if ($debug);
    $self->{debug} = 0
      if ( $self->{debug} < 0 );
}

sub set {
    my ( $self, $p_state, $p_setby ) = @_;
    if ( $p_setby eq 'poll' ) {
        main::print_log( "[Venstar Colortouch:" . $self->{data}->{name} . "] DB super::set, in master set, p_state=$p_state, p_setby=$p_setby" )
          if ( $self->{debug} );

        $self->SUPER::set($p_state);
        $self->start_timer if ( $self->{background} == 2 );

    }
    else {
        main::print_log( "[Venstar Colortouch:" . $self->{data}->{name} . "] DB set_mode, in master set, p_state=$p_state, p_setby=$p_setby" )
          if ( $self->{debug} );

        $self->set_mode($p_state);
    }
}

package Venstar_Colortouch_Temp;

@Venstar_Colortouch_Temp::ISA = ('Generic_Item');

sub new {
    my ( $class, $object ) = @_;

    my $self = new Generic_Item();
    bless $self, $class;

    $$self{master_object} = $object;

    $object->register( $self, 'temp' );
    $self->set( $object->get_temp, 'poll' );
    return $self;

}

sub set {
    my ( $self, $p_state, $p_setby ) = @_;

    if ( $p_setby eq 'poll' ) {
        $self->SUPER::set($p_state);
    }
}

package Venstar_Colortouch_Fan;

# the venstar expected either AUTO or ON
# however the object's state will either be on or off depending on if it's actually on or off
# the mode object will get the true fan mode, either on or auto.

@Venstar_Colortouch_Fan::ISA = ('Generic_Item');

sub new {
    my ( $class, $object ) = @_;

    my $self = new Generic_Item();
    bless $self, $class;
    push( @{ $$self{states} }, 'off', 'on' );
    $self->{current_mode} = "";
    $$self{master_object} = $object;

    $object->register( $self, 'fanstate' );
    $self->set( $object->get_fan, 'poll' );
    return $self;

}

sub set {
    my ( $self, $p_state, $p_setby ) = @_;

    if ( $p_setby eq 'poll' ) {
        $self->SUPER::set($p_state);

    }
    else {
        $p_state = "auto" if ( lc $p_state eq "off" );
        if ( ( lc $p_state eq "auto" ) or ( lc $p_state eq "on" ) ) {
            $$self{master_object}->set_fan($p_state);
        }
        else {
            main::print_log("[Venstar Colortouch Fan] Error. Unknown set state $p_state");
        }
    }
}

sub set_mode {
    my ( $self, $p_mode ) = @_;

    $self->{current_mode} = $p_mode;
}

sub get_mode {
    my ($self) = @_;

    return ( $self->{current_mode} );
}

package Venstar_Colortouch_Humidity;

@Venstar_Colortouch_Humidity::ISA = ('Generic_Item');

sub new {
    my ( $class, $object ) = @_;

    my $self = new Generic_Item();
    bless $self, $class;

    $$self{master_object} = $object;

    $object->register( $self, 'hum' );
    $self->set( $object->get_hum, 'poll' );
    return $self;

}

sub set {
    my ( $self, $p_state, $p_setby ) = @_;

    if ( $p_setby eq 'poll' ) {
        $self->SUPER::set($p_state);
    }
}

package Venstar_Colortouch_Humidity_sp;

@Venstar_Colortouch_Humidity_sp::ISA = ('Generic_Item');

sub new {
    my ( $class, $object ) = @_;

    my $self = new Generic_Item();
    bless $self, $class;

    $$self{master_object} = $object;
    push( @{ $$self{states} }, '0', '5', '10', '15', '20', '25', '30', '35', '40' );

    $object->register( $self, 'hum_sp' );
    $self->set( $object->get_sp_hum, 'poll' );
    return $self;

}

sub set {
    my ( $self, $p_state, $p_setby ) = @_;

    if ( $p_setby eq 'poll' ) {
        $self->SUPER::set($p_state);
    }
    else {
        if ( ( $p_state >= 0 ) and ( $p_state <= 98 ) ) {
            $$self{master_object}->set_hum_sp($p_state);
        }
        else {
            main::print_log("[Venstar Colortouch Humidity_SP] Error. Unknown set state $p_state");
        }
    }
}

package Venstar_Colortouch_Schedule;

@Venstar_Colortouch_Schedule::ISA = ('Generic_Item');

sub new {
    my ( $class, $object ) = @_;

    my $self = new Generic_Item();
    bless $self, $class;

    $$self{master_object} = $object;
    push( @{ $$self{states} }, 'off', 'on' );
    $object->register( $self, 'sched' );
    $self->set( $object->get_sched, 'poll' );
    return $self;

}

sub set {
    my ( $self, $p_state, $p_setby ) = @_;

    if ( $p_setby eq 'poll' ) {
        $self->SUPER::set($p_state);
    }
    else {
        if ( ( lc $p_state eq "off" ) or ( lc $p_state eq "on" ) ) {
            $$self{master_object}->set_schedule($p_state);
        }
        else {
            main::print_log("[Venstar Colortouch Scheduler] Error. Unknown set state $p_state");
        }
    }
}

package Venstar_Colortouch_Comm;

@Venstar_Colortouch_Comm::ISA = ('Generic_Item');

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

package Venstar_Colortouch_Mode;

@Venstar_Colortouch_Mode::ISA = ('Generic_Item');

sub new {
    my ( $class, $object ) = @_;

    my $self = new Generic_Item();
    bless $self, $class;

    $$self{master_object} = $object;

    $object->register( $self, 'mode' );
    $self->set( $object->get_mode, 'poll' );
    return $self;

}

sub set {
    my ( $self, $p_state, $p_setby ) = @_;

    if ( $p_setby eq 'poll' ) {
        $self->SUPER::set($p_state);
    }
    else {
        if (   ( lc $p_state eq "cooling" )
            or ( lc $p_state eq "heating" )
            or ( lc $p_state eq "cool" )
            or ( lc $p_state eq "heat" )
            or ( lc $p_state eq "auto" )
            or ( lc $p_state eq "off" ) )
        {
            $$self{master_object}->set_mode($p_state);
        }
        else {
            main::print_log("[Venstar Colortouch Mode] Error. Unknown set state $p_state");
        }
    }
}

package Venstar_Colortouch_Heat_sp;

@Venstar_Colortouch_Heat_sp::ISA = ('Generic_Item');

sub new {
    my ( $class, $object, $scale ) = @_;

    my $self = new Generic_Item();
    bless $self, $class;

    $$self{master_object} = $object;
    if ( ( defined $scale ) and ( lc $scale eq "F" ) ) {
        push( @{ $$self{states} }, '65', '66', '67', '68', '69', '70', '71', '72', '73', '74', '75', '76', '77', '78', '79', '80' );
        $self->{lower_limit} = 65;
        $self->{upper_limit} = 80;
    }
    else {
        push( @{ $$self{states} },
            '17', '17.5', '18', '18.5', '19', '19.5', '20', '20.5', '21', '21.5', '22', '22.5', '23', '23.5', '24', '24.5', '25', '25.5', '26' );
        $self->{lower_limit} = 17;
        $self->{upper_limit} = 26;
    }

    $object->register( $self, 'heat_sp' );
    $self->set( $object->get_sp_heat, 'poll' );
    return $self;

}

sub set {
    my ( $self, $p_state, $p_setby ) = @_;

    if ( $p_setby eq 'poll' ) {
        $self->SUPER::set($p_state);
    }
    else {
        if ( ( $p_state >= 0 ) and ( $p_state <= 98 ) ) {
            if (    ( $p_state >= $self->{lower_limit} )
                and ( $p_state <= $self->{upper_limit} ) )
            {
                $$self{master_object}->set_heat_sp($p_state);
            }
            else {
                main::print_log( "[Venstar Colortouch Heat_SP] Error. $p_state out of limits (" . $self->{lower_limit} . " to " . $self->{upper_limit} . ")" );
            }
        }
        else {
            main::print_log("[Venstar Colortouch Heat_SP] Error. Unknown set state $p_state");
        }
    }
}

package Venstar_Colortouch_Cool_sp;

@Venstar_Colortouch_Cool_sp::ISA = ('Generic_Item');

sub new {
    my ( $class, $object, $scale ) = @_;

    my $self = new Generic_Item();
    bless $self, $class;

    $$self{master_object} = $object;
    if ( ( defined $scale ) and ( lc $scale eq "F" ) ) {
        push( @{ $$self{states} },
            '58', '59', '60', '61', '62', '63', '64', '65', '66', '67', '68', '69', '70', '71', '72', '73', '74', '75', '76', '77', '78', '79', '80' );
        $self->{lower_limit} = 58;
        $self->{upper_limit} = 80;
    }
    else {
        push( @{ $$self{states} },
            '17', '17.5', '18', '18.5', '19', '19.5', '20', '20.5', '21', '21.5', '22', '22.5', '23', '23.5', '24', '24.5', '25', '25.5', '26' );
        $self->{lower_limit} = 17;
        $self->{upper_limit} = 26;
    }

    $object->register( $self, 'cool_sp' );
    $self->set( $object->get_sp_cool, 'poll' );
    return $self;

}

sub set {
    my ( $self, $p_state, $p_setby ) = @_;

    if ( $p_setby eq 'poll' ) {
        $self->SUPER::set($p_state);
    }
    else {
        if ( ( $p_state >= 0 ) and ( $p_state <= 98 ) ) {
            if (    ( $p_state >= $self->{lower_limit} )
                and ( $p_state <= $self->{upper_limit} ) )
            {
                $$self{master_object}->set_cool_sp($p_state);
            }
            else {
                main::print_log( "[Venstar Colortouch Cool_SP] Error. $p_state out of limits (" . $self->{lower_limit} . " to " . $self->{upper_limit} . ")" );
            }
        }
        else {
            main::print_log("[Venstar Colortouch Cool_SP] Error. Unknown set state $p_state");
        }
    }
}

1;
