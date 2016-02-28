package Venstar_Colortouch;

use strict;
use warnings;

use LWP::UserAgent;
use HTTP::Request::Common qw(POST);
use JSON::XS;
use Data::Dumper;

# Venstar::Colortouch
# $stat_upper        = new Venstar_Colortouch('192.168.0.100');
#
# $stat_upper_temp   = new Venstar_Colortouch_Temp($stat_upper);
# $stat_upper_fan    = new Venstar_Colortouch_Fan($stat_upper);
# $stat_upper_hum    = new Venstar_Colortouch_Humidity($stat_upper);
# $stat_upper_hum_sp = new Venstar_Colortouch_Humidity_sp($stat_upper);
# $stat_upper_sched  = new Venstar_Colortouch_Sched($stat_upper);
# $stat_upper_comm	 = new Venstar_Colortouch_Comm($stat_upper);

# v1.1 - added in schedule and humidity control.
# v1.2 - added communication tracker object & timeout control
# v1.3 - added check for timer defined

# Notes:
#  - Best to use firmware at least 3.14 released Nov 2014. This fixes issues with both
#    schedule and humidity/dehumidify control.

#todo
# - temp setpoint bounds checking
# - log runtimes. Maybe into a dbm file? log_runtimes method with destination.
# - figure out timezone w/ DST
# - changing heating/cooling setpoints for heating/cooling only stats does not need both setpoints
# - add decimals for setpoints
# # make the data poll non-blocking, turn off timer
#
# State can only be set by stat. Set mode will change the mode.

@Venstar_Colortouch::ISA = ('Generic_Item');

# -------------------- START OF SUBROUTINES --------------------
# --------------------------------------------------------------

our %rest;
$rest{info}     = "query/info";
$rest{api}      = "";
$rest{sensors}  = "query/sensors";
$rest{runtimes} = "query/runtimes";
$rest{alerts}   = "query/alerts";
$rest{control}  = "/control";
$rest{settings} = "/settings";

sub new {
    my ( $class, $host, $poll ) = @_;
    my $self = {};
    bless $self, $class;
    $self->{data}                 = undef;
    $self->{child_object}         = undef;
    $self->{config}->{cache_time} = 30;      #TODO fix cache timeouts
    $self->{config}->{cache_time} = $::config_params{venstar_config_cache_time}
      if defined $::config_params{venstar_config_cache_time};
    $self->{config}->{tz} = $::config_params{time_zone}
      ;    #TODO Need to figure out DST for print runtimes
    $self->{config}->{poll_seconds} = 60;
    $self->{config}->{poll_seconds} = $poll if ($poll);
    $self->{config}->{poll_seconds} = 1
      if ( $self->{config}->{poll_seconds} < 1 );
    $self->{updating}      = 0;
    $self->{data}->{retry} = 0;
    $self->{host}          = $host;
    $self->{debug}         = 0;
    $self->{loglevel}      = 1;
    $self->{timeout}       = 15;      #300;

    $self->_init;
    $self->{timer} = new Timer;
    $self->start_timer;
    return $self;
}

sub _poll_check {
    my ($self) = @_;

    #main::print_log("[Venstar Colortouch] _poll_check initiated");
    #main::run (sub {&Venstar_Colortouch::get_data($self)}); #spawn this off to run in the background
    $self->get_data();
}

sub get_data {
    my ($self) = @_;

    #main::print_log("[Venstar Colortouch] get_data initiated");
    $self->poll;
    $self->process_data;
}

sub _init {
    my ($self) = @_;
    my @state;
    $state[0] = "idle";
    $state[1] = "heating";
    $state[2] = "cooling";
    $state[3] = "lockout";
    $state[4] = "error";
    my ( $isSuccessResponse1, $stat ) = $self->_get_JSON_data('api');

    if ($isSuccessResponse1) {

        if ( ( $stat->{api_ver} > 3 ) and ( $stat->{type} eq "residential" ) ) {

            main::print_log(
                "[Venstar Colortouch] Residental Venstar ColorTouch found with api level $stat->{api_ver}"
            );
            if ( $self->poll() ) {
                main::print_log( "[Venstar Colortouch:"
                      . $self->{data}->{name}
                      . "] Data Successfully Retrieved" );
                $self->{active}                = 1;
                $self->{previous}->{tempunits} = $self->{data}->{tempunits};
                $self->{previous}->{name}      = $self->{data}->{name};
                foreach my $key1 ( keys $self->{data}->{info} ) {
                    $self->{previous}->{info}->{$key1} =
                      $self->{data}->{info}->{$key1};
                }
                $self->{previous}->{sensors}->{sensors}[0]->{temp} =
                  $self->{data}->{sensors}->{sensors}[0]->{temp};
                $self->{previous}->{sensors}->{sensors}[0]->{hum} =
                  $self->{data}->{sensors}->{sensors}[0]->{hum};
                ## set states based on available mode
                $self->print_info();
                $self->set( $state[ $self->{data}->{info}->{state} ], 'poll' );

            }
            else {
                main::print_log(
                    "[Venstar Colortouch] Problem retrieving initial data");
                $self->{active} = 0;
                return ('1');
            }

        }
        else {
            main::print_log(
                "[Venstar Colortouch] Unknown device " . $self->{host} );
            $self->{active} = 0;
            return ('1');
        }

    }
    else {
        main::print_log( "[Venstar Colortouch] Error. Unable to connect to "
              . $self->{host} );
        $self->{active} = 0;
        return ('1');
    }
}

sub poll {
    my ($self) = @_;

    main::print_log("[Venstar Colortouch] Polling initiated")
      if ( $self->{debug} );

    my ( $isSuccessResponse1, $info )    = $self->_get_JSON_data('info');
    my ( $isSuccessResponse2, $sensors ) = $self->_get_JSON_data('sensors');

    if ( $isSuccessResponse1 and $isSuccessResponse2 ) {
        $self->{data}->{tempunits} = $info->{tempunits};
        $self->{data}->{name}      = $info->{name};
        $self->{data}->{info}      = $info;
        $self->{data}->{sensors}   = $sensors;
        $self->{data}->{timestamp} = time;
        $self->{data}->{retry}     = 0;
        if ( defined $self->{child_object}->{comm} ) {
            if ( $self->{child_object}->{comm}->state() ne "online" ) {
                main::print_log
                  "[Venstar Colortouch] Communication Tracking object found. Updating..."
                  if ( $self->{loglevel} );
                $self->{child_object}->{comm}->set( "online", 'poll' );
            }
        }
        return ('1');
    }
    else {
        main::print_log( "[Venstar Colortouch:"
              . $self->{data}->{name}
              . "] Problem retrieving poll data from "
              . $self->{host} );
        $self->{data}->{retry}++;
        if ( defined $self->{child_object}->{comm} ) {
            if ( $self->{child_object}->{comm}->state() ne "offline" ) {
                main::print_log
                  "[Venstar Colortouch] Communication Tracking object found. Updating..."
                  if ( $self->{loglevel} );
                $self->{child_object}->{comm}->set( "offline", 'poll' );
            }
        }
        return ('0');
    }

}

#------------------------------------------------------------------------------------
sub _get_JSON_data {
    my ( $self, $mode ) = @_;

    unless ( $self->{updating} ) {

        $self->{updating} = 1;
        my $ua = new LWP::UserAgent( keep_alive => 1 );
        $ua->timeout( $self->{timeout} );

        my $host = $self->{host};

        my $request = HTTP::Request->new( POST => "http://$host/$rest{$mode}" );
        $request->content_type("application/x-www-form-urlencoded");

        my $responseObj = $ua->request($request);
        print $responseObj->content . "\n--------------------\n"
          if $self->{debug};

        my $responseCode = $responseObj->code;
        print 'Response code: ' . $responseCode . "\n" if $self->{debug};
        my $isSuccessResponse = $responseCode < 400;
        $self->{updating} = 0;
        if ( !$isSuccessResponse ) {
            main::print_log( "[Venstar Colortouch:"
                  . $self->{data}->{name}
                  . "] Warning, failed to get data. Response code $responseCode"
            );
            if ( defined $self->{child_object}->{comm} ) {
                if ( $self->{child_object}->{comm}->state() ne "offline" ) {
                    main::print_log
                      "[Venstar Colortouch] Communication Tracking object found. Updating..."
                      if ( $self->{loglevel} );
                    $self->{child_object}->{comm}->set( "offline", 'poll' );
                }
            }
            return ('0');
        }
        else {
            if ( defined $self->{child_object}->{comm} ) {
                if ( $self->{child_object}->{comm}->state() ne "online" ) {
                    main::print_log
                      "[Venstar Colortouch] Communication Tracking object found. Updating..."
                      if ( $self->{loglevel} );
                    $self->{child_object}->{comm}->set( "online", 'poll' );
                }
            }
        }
        my $response;
        eval { $response = JSON::XS->new->decode( $responseObj->content ); };

        # catch crashes:
        if ($@) {
            print "[Venstar Colortouch:"
              . $self->{data}->{name}
              . "] ERROR! JSON parser crashed! $@\n";
            return ('0');
        }
        else {
            return ( $isSuccessResponse, $response );
        }
    }
    else {
        main::print_log( "[Venstar Colortouch:"
              . $self->{data}->{name}
              . "] Warning, not fetching data due to operation in progress" );
        return ('0');
    }
}

sub _push_JSON_data {
    my ( $self, $type, $params ) = @_;

    my $cmd;

    #print "VCT DB: $params\n";
    $self->stop_timer;    #stop timer to prevent a clash of updates
    if ( $type eq 'settings' ) {

        #tempunits=0&away=0&schedule=0&hum_setpoint=0&dehum_setpoint=0

        my ( $newunits, $newaway, $newsched, $newhumsp, $newdehumsp );
        my ($units) = $params =~ /tempunits=(\d+)/;
        my ($away)  = $params =~ /away=(\d+)/;
        my ($sched) = $params =~ /schedule=(\d+)/;
        my $hum;
        my ($humsp)   = $params =~ /hum_setpoint=(\d+)/;
        my ($dehumsp) = $params =~ /dehum_setpoint=(\d+)/
          ;               #need to add in dehumidifier stuff at some point

        my ( $isSuccessResponse, $cunits, $caway, $csched, $chum, $chumsp,
            $cdehumsp )
          = $self->_get_setting_params;

        $units = $cunits if ( not defined $units );
        $units = 1 if ( ( $units eq "C" ) or ( $units eq "c" ) );
        $units = 0 if ( ( $units eq "F" ) or ( $units eq "f" ) );

        $away    = $caway    if ( not defined $away );
        $sched   = $csched   if ( not defined $sched );
        $hum     = $chum     if ( not defined $hum );
        $humsp   = $chumsp   if ( not defined $humsp );
        $dehumsp = $cdehumsp if ( not defined $dehumsp );

        if ( $cunits ne $units ) {
            main::print_log( "[Venstar Colortouch:"
                  . $self->{data}->{name}
                  . "] Changing Units from $cunits to $units" );
            $newunits = $units;
        }
        else {
            $newunits = $cunits;
        }

        if ( $caway ne $away ) {
            main::print_log( "[Venstar Colortouch:"
                  . $self->{data}->{name}
                  . "] Changing Away from $caway to $away" );
            $newaway = $away;
        }
        else {
            $newaway = $caway;
        }

        if ( $csched ne $sched ) {
            main::print_log( "[Venstar Colortouch:"
                  . $self->{data}->{name}
                  . "] Changing Schedule from $csched to $sched" );
            $newsched = $sched;
        }
        else {
            $newsched = $csched;
        }

        if ( $chumsp ne $humsp ) {
            print
              "[Venstar Colortouch] Changing Humidity Setpoint from $chumsp to $humsp\n";
            $newhumsp = $humsp;
        }
        else {
            $newhumsp = $chumsp;
        }

        if ( $cdehumsp ne $dehumsp ) {
            print
              "[Venstar Colortouch] Changing Dehumidity Setpoint from $cdehumsp to $dehumsp\n";
            $newdehumsp = $dehumsp;
        }
        else {
            $newdehumsp = $cdehumsp;
        }

        $cmd =
          "tempunits=$newunits&away=$newaway&schedule=$newsched&hum_setpoint=$newhumsp&dehum_setpoint=$newdehumsp";
        main::print_log( "Sending Settings command $cmd to " . $self->{host} )
          ;    # if $self->{debug};

    }
    elsif ( $type eq 'control' ) {

        #mode=0&fan=0&heattemp=70&cooltemp=75
        #have to include heattemp and cooltemp
        #and must ensure they differ from setpointdelta
        #TODO This would only be for auto stats
        my ( $newmode, $newfan, $newcoolsp, $newheatsp );
        my ($mode)     = $params =~ /mode=(\d+)/;
        my ($fan)      = $params =~ /fan=(\d+)/;
        my ($heattemp) = $params =~ /heattemp=(\d+)/;    #need decimals
        my ($cooltemp) = $params =~ /cooltemp=(\d+)/;

        my (
            $isSuccessResponse, $cmode,     $cfan,
            $cheattemp,         $ccooltemp, $setpointdelta,
            $minheat,           $maxheat,   $mincool,
            $maxcool
        ) = $self->_get_control_params;

        $mode     = $cmode     if ( not defined $mode );
        $fan      = $cfan      if ( not defined $fan );
        $heattemp = $cheattemp if ( !$heattemp );
        $cooltemp = $ccooltemp if ( !$cooltemp );

        main::print_log(
            "data1=$isSuccessResponse,$cmode,$cfan,$cheattemp,$ccooltemp,$setpointdelta"
        );    #TODO pass object to get debug
        main::print_log("data2=$mode,$fan,$heattemp,$cooltemp");    #TODO debug

        if ( $cmode ne $mode ) {
            main::print_log( "[Venstar Colortouch:"
                  . $self->{data}->{name}
                  . "] Changing mode from $cmode to $mode" );
            $newmode = $mode;
        }
        else {
            $newmode = $cmode;
        }

        if ( $cfan ne $fan ) {
            main::print_log( "[Venstar Colortouch:"
                  . $self->{data}->{name}
                  . "] Changing fan from $cfan to $fan" );
            $newfan = $fan;
        }
        else {
            $newfan = $cfan;
        }

        if ( $heattemp ne $cheattemp ) {
            main::print_log( "[Venstar Colortouch:"
                  . $self->{data}->{name}
                  . "] Changing heat setpoint from $cheattemp to $heattemp" );
            $newheatsp = $heattemp;
        }
        else {
            $newheatsp = $cheattemp;
        }

        if ( $cooltemp ne $ccooltemp ) {
            main::print_log( "[Venstar Colortouch:"
                  . $self->{data}->{name}
                  . "] Changing cool setpoint from $ccooltemp to $cooltemp" );
            $newcoolsp = $cooltemp;
        }
        else {
            $newcoolsp = $ccooltemp;
        }

        if ( ( $newcoolsp > $maxcool ) or ( $newcoolsp < $mincool ) ) {
            main::print_log( "[Venstar Colortouch:"
                  . $self->{data}->{name}
                  . "] Error: New cooling setpoint $newcoolsp out of bounds $mincool - $maxcool"
            );
            $newcoolsp = $ccooltemp;
        }

        if ( ( $newheatsp > $maxheat ) or ( $newheatsp < $minheat ) ) {
            main::print_log( "[Venstar Colortouch:"
                  . $self->{data}->{name}
                  . "] Error: New heating setpoint $newheatsp out of bounds $minheat - $maxheat"
            );
            $newheatsp = $cheattemp;
        }

        if ( ( $newheatsp - $newcoolsp ) < $setpointdelta ) {
            main::print_log( "[Venstar Colortouch:"
                  . $self->{data}->{name}
                  . "] Error: Cooling and Heating setpoints need to be less than setpoint $setpointdelta"
            );
            main::print_log( "[Venstar Colortouch:"
                  . $self->{data}->{name}
                  . "] Not setting setpoints" );
            $newcoolsp = $ccooltemp;
            $newheatsp = $cheattemp;
        }

        $cmd =
          "mode=$newmode&fan=$newfan&heattemp=$newheatsp&cooltemp=$newcoolsp";
        main::print_log( "Sending Control command $cmd to " . $self->{host} )
          ;    # if $self->{debug};

    }
    else {

        main::print_log("Unknown mode!");
        return ( '1', 'error' );
    }

    my $ua = new LWP::UserAgent( keep_alive => 1 );
    $ua->timeout( $self->{timeout} );

    my $host = $self->{host};

    my $request = HTTP::Request->new( POST => "http://$host/$rest{$type}" );
    $request->content_type("application/x-www-form-urlencoded");
    $request->content($cmd) if $cmd;

    my $responseObj = $ua->request($request);
    print $responseObj->content . "\n--------------------\n" if $self->{debug};

    my $responseCode = $responseObj->code;
    print 'Response code: ' . $responseCode . "\n" if $self->{debug};
    my $isSuccessResponse = $responseCode < 400;
    if ( !$isSuccessResponse ) {
        main::print_log( "[Venstar Colortouch:"
              . $self->{data}->{name}
              . "] Warning, failed to push data. Response code $responseCode" );
        if ( defined $self->{child_object}->{comm} ) {
            if ( $self->{child_object}->{comm}->state() ne "offline" ) {
                main::print_log
                  "[Venstar Colortouch] Communication Tracking object found. Updating..."
                  if ( $self->{loglevel} );
                $self->{child_object}->{comm}->set( "offline", 'poll' );
            }
        }
    }
    else {
        if ( defined $self->{child_object}->{comm} ) {
            if ( $self->{child_object}->{comm}->state() ne "online" ) {
                main::print_log
                  "[Venstar Colortouch] Communication Tracking object found. Updating..."
                  if ( $self->{loglevel} );
                $self->{child_object}->{comm}->set( "online", 'poll' );
            }
        }
    }

    #my $response = JSON::XS->new->decode ($responseObj->content);

    #print Dumper $response if $self->{debug};
    my ($response) = $responseObj->content =~ /\{\"(.*)\":/;
    print "response=$response\n" if $self->{debug};
    $self->poll if ( $response eq "success" );
    $self->start_timer;
    return ( $isSuccessResponse, $response );
}

sub register {
    my ( $self, $object, $type ) = @_;

    #my $name;
    #$name = $$object{object_name};  #TODO: Why can't we get the name of the child object?
    &main::print_log( "[Venstar Colortouch:"
          . $self->{data}->{name}
          . "] Registering $type child object" );
    $self->{child_object}->{$type} = $object;

}

sub _get_control_params {
    my ($self) = @_;
    my ( $isSuccessResponse, $info ) = $self->_get_JSON_data('info');
    return (
        $isSuccessResponse,   $info->{mode},        $info->{fan},
        $info->{heattemp},    $info->{cooltemp},    $info->{setpointdelta},
        $info->{heattempmin}, $info->{heattempmax}, $info->{cooltempmin},
        $info->{cooltempmax}
    );
}

sub _get_setting_params {
    my ($self) = @_;
    my ( $isSuccessResponse, $info ) = $self->_get_JSON_data('info');
    return ( $isSuccessResponse, $info->{tempunits}, $info->{away},
        $info->{schedule}, $info->{hum}, $info->{hum_setpoint},
        $info->{dehum_setpoint} );
}

sub stop_timer {
    my ($self) = @_;

    if ( defined $self->{timer} ) {
        $self->{timer}->stop() if ( $self->{timer}->active() );
    }
    else {
        main::print_log( "[Venstar Colortouch:"
              . $self->{data}->{name}
              . "] Warning, stop_timer called but timer undefined" );
    }
}

sub start_timer {
    my ($self) = @_;

    if ( defined $self->{timer} ) {
        $self->{timer}->set( $self->{config}->{poll_seconds},
            sub { &Venstar_Colortouch::_poll_check($self) }, -1 );
    }
    else {
        main::print_log( "[Venstar Colortouch:"
              . $self->{data}->{name}
              . "] Warning, start_timer called but timer undefined" );
    }
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
          . " Thermostat" );

    main::print_log( "[Venstar Colortouch:"
          . $self->{data}->{name}
          . "] Fan mode is set to "
          . $fan[ $self->{data}->{info}->{fan} ] );
    main::print_log( "[Venstar Colortouch:"
          . $self->{data}->{name}
          . "] Fan is currently "
          . $fanstate[ $self->{data}->{info}->{fanstate} ] );
    main::print_log( "[Venstar Colortouch:"
          . $self->{data}->{name}
          . "] System mode is "
          . $mode[ $self->{data}->{info}->{mode} ] );
    main::print_log( "[Venstar Colortouch:"
          . $self->{data}->{name}
          . "] System is "
          . $state[ $self->{data}->{info}->{state} ] );

    my $sch = " ";
    $sch = " not " if ( $self->{data}->{info}->{schedule} == 0 );
    main::print_log( "[Venstar Colortouch:"
          . $self->{data}->{name}
          . "] System is"
          . $sch
          . "on a schedule" );

    main::print_log( "[Venstar Colortouch:"
          . $self->{data}->{name}
          . "] System schedule is "
          . $schedule[ $self->{data}->{info}->{schedulepart} ] );

    my $away = "home mode";
    $away = "away mode" if ( $self->{data}->{info}->{away} );
    main::print_log( "[Venstar Colortouch:"
          . $self->{data}->{name}
          . "] System is currently on $away" );

    main::print_log( "[Venstar Colortouch:"
          . $self->{data}->{name}
          . "] Current Temperature: "
          . $self->{data}->{info}->{spacetemp}
          . "$unit" );
    main::print_log( "[Venstar Colortouch:"
          . $self->{data}->{name}
          . "] Current Humidity:"
          . $self->{data}->{info}->{hum}
          . "%" );

    main::print_log( "[Venstar Colortouch:"
          . $self->{data}->{name}
          . "] Current Setpoint\tMin\tMax" );
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
    main::print_log( "[Venstar Colortouch:"
          . $self->{data}->{name}
          . "] Humidity:\t"
          . $self->{data}->{info}->{hum_setpoint}
          . "%" )
      unless ( $self->{data}->{info}->{hum_setpoint} == 99 );
    main::print_log( "[Venstar Colortouch:"
          . $self->{data}->{name}
          . "] Dehumidity:"
          . $self->{data}->{info}->{dehum_setpoint}
          . "%" )
      unless ( $self->{data}->{info}->{dehum_setpoint} == 99 );

    main::print_log( "[Venstar Colortouch:"
          . $self->{data}->{name}
          . "] Setpoint Delta: "
          . $self->{data}->{info}->{setpointdelta}
          . "$unit" );

    main::print_log( "[Venstar Colortouch:"
          . $self->{data}->{name}
          . "] Current Thermostat Sensor Temperature:"
          . $self->{data}->{sensors}->{sensors}[0]->{temp}
          . "$unit" );
    main::print_log( "[Venstar Colortouch:"
          . $self->{data}->{name}
          . "] Current Thermostat Sensor Humidity:"
          . $self->{data}->{sensors}->{sensors}[0]->{hum}
          . "%" );

    if ( $self->{data}->{sensors}->{sensors}[1]->{temp} != -39 ) {
        main::print_log( "[Venstar Colortouch:"
              . $self->{data}->{name}
              . "] Current Outdoor Sensor Temperature:"
              . $self->{data}->{sensors}->{sensors}[1]->{temp} );
    }
    else {
        main::print_log( "[Venstar Colortouch:"
              . $self->{data}->{name}
              . "] Outdoor Temperature Sensor not connected" );
    }
}

sub process_data {
    my ($self) = @_;

    # Main core of processing
    # set state of self for state
    # for any registered child selfs, update their state if

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
        main::print_log( "[Venstar Colortouch:"
              . $self->{data}->{name}
              . "] Temperature Units changed from $self->{previous}->{tempunits} to $self->{data}->{tempunits}"
        );
        main::print_log( "[Venstar Colortouch:"
              . $self->{data}->{name}
              . "] This really isn't a regular operation. Should check Thermostat to confirm"
        );
        $self->{previous}->{tempunits} = $self->{data}->{tempunits};
    }

    if ( $self->{previous}->{name} ne $self->{data}->{name} ) {
        main::print_log( "[Venstar Colortouch:"
              . $self->{data}->{name}
              . "] Device Name changed from $self->{previous}->{name} to $self->{data}->{name}"
        );
        main::print_log( "[Venstar Colortouch:"
              . $self->{data}->{name}
              . "] This really isn't a regular operation. Should check Thermostat to confirm"
        );
        $self->{previous}->{name} = $self->{data}->{name};
    }

    if ( $self->{previous}->{info}->{availablemodes} !=
        $self->{data}->{info}->{availablemodes} )
    {
        main::print_log( "[Venstar Colortouch:"
              . $self->{data}->{name}
              . "] Available Modes changed from $self->{previous}->{info}->{availablemodes} to $self->{data}->{info}->{availablemodes}"
        );
        main::print_log( "[Venstar Colortouch:"
              . $self->{data}->{name}
              . "] This really isn't a regular operation. Should check Thermostat to confirm"
        );
        $self->{previous}->{info}->{availablemodes} =
          $self->{data}->{info}->{availablemodes};
    }

    if ( $self->{previous}->{info}->{fan} != $self->{data}->{info}->{fan} ) {
        main::print_log( "[Venstar Colortouch:"
              . $self->{data}->{name}
              . "] Fan changed from $fan[$self->{previous}->{info}->{fan}] to $fan[$self->{data}->{info}->{fan}]"
        ) if ( $self->{loglevel} );
        $self->{previous}->{info}->{fan} = $self->{data}->{info}->{fan};
        if ( defined $self->{child_object}->{fanstate} ) {
            main::print_log "Child object found. Updating..."
              if ( $self->{loglevel} );
            $self->{child_object}->{fanstate}
              ->set_mode( $fan[ $self->{data}->{info}->{fan} ] );
        }
    }

    if ( $self->{previous}->{info}->{fanstate} !=
        $self->{data}->{info}->{fanstate} )
    {
        main::print_log( "[Venstar Colortouch:"
              . $self->{data}->{name}
              . "] Fan state changed from $fanstate[$self->{previous}->{info}->{fanstate}] to $fanstate[$self->{data}->{info}->{fanstate}]"
        ) if ( $self->{loglevel} );
        $self->{previous}->{info}->{fanstate} =
          $self->{data}->{info}->{fanstate};
        if ( defined $self->{child_object}->{fanstate} ) {
            main::print_log "Child object found. Updating..."
              if ( $self->{loglevel} );
            $self->{child_object}->{fanstate}
              ->set( $fanstate[ $self->{data}->{info}->{fanstate} ], 'poll' );
        }
    }

    if ( $self->{previous}->{info}->{mode} != $self->{data}->{info}->{mode} ) {
        main::print_log( "[Venstar Colortouch:"
              . $self->{data}->{name}
              . "] Mode changed from $mode[$self->{previous}->{info}->{mode}] to $mode[$self->{data}->{info}->{mode}]"
        ) if ( $self->{loglevel} );
        $self->{previous}->{info}->{mode} = $self->{data}->{info}->{mode};
    }

    if ( $self->{previous}->{info}->{state} != $self->{data}->{info}->{state} )
    {
        main::print_log( "[Venstar Colortouch:"
              . $self->{data}->{name}
              . "] Thermostat state changed from $state[$self->{previous}->{info}->{state}] to $state[$self->{data}->{info}->{state}]"
        ) if ( $self->{loglevel} );
        $self->{previous}->{info}->{state} = $self->{data}->{info}->{state};
        $self->set( $state[ $self->{data}->{info}->{state} ], 'poll' );
    }

    if ( $self->{previous}->{info}->{schedule} !=
        $self->{data}->{info}->{schedule} )
    {
        my $sch = " ";
        my @sched;
        $sched[0] = "off";
        $sched[1] = "on";
        $sch = " not " if ( !$self->{data}->{info}->{schedule} );
        main::print_log( "[Venstar Colortouch:"
              . $self->{data}->{name}
              . "] Thermostat state changed to"
              . $sch
              . "on a schedule" )
          if ( $self->{loglevel} );
        $self->{previous}->{info}->{schedule} =
          $self->{data}->{info}->{schedule};
        if ( defined $self->{child_object}->{sched} ) {
            main::print_log "Child object found. Updating..."
              if ( $self->{loglevel} );
            $self->{child_object}->{sched}
              ->set( $sched[ $self->{data}->{info}->{schedule} ], 'poll' );
        }
    }

    if ( $self->{previous}->{info}->{schedulepart} !=
        $self->{data}->{info}->{schedulepart} )
    {
        main::print_log( "[Venstar Colortouch:"
              . $self->{data}->{name}
              . "] Thermostat schedule changed from $schedule[$self->{previous}->{info}->{schedulepart}] to $schedule[$self->{data}->{info}->{schedulepart}]"
        ) if ( $self->{loglevel} );
        $self->{previous}->{info}->{schedulepart} =
          $self->{data}->{info}->{schedulepart};
    }

    if ( $self->{previous}->{info}->{away} != $self->{data}->{info}->{away} ) {
        my $away = "home mode";
        $away = "away mode" if ( $self->{data}->{info}->{away} );
        main::print_log( "[Venstar Colortouch:"
              . $self->{data}->{name}
              . "] Thermostat occupency changed to"
              . $away )
          if ( $self->{loglevel} );
        $self->{previous}->{info}->{away} = $self->{data}->{info}->{away};
    }

    if ( $self->{previous}->{info}->{spacetemp} !=
        $self->{data}->{info}->{spacetemp} )
    {
        main::print_log( "[Venstar Colortouch:"
              . $self->{data}->{name}
              . "] Thermostat temperature changed from $self->{previous}->{info}->{spacetemp} to $self->{data}->{info}->{spacetemp}"
        ) if ( $self->{loglevel} );
        $self->{previous}->{info}->{spacetemp} =
          $self->{data}->{info}->{spacetemp};
        if ( defined $self->{child_object}->{temp} ) {
            main::print_log "Child object found. Updating..."
              if ( $self->{loglevel} );
            $self->{child_object}->{temp}
              ->set( $self->{data}->{info}->{spacetemp}, 'poll' );
        }
    }

    if ( $self->{previous}->{info}->{heattemp} !=
        $self->{data}->{info}->{heattemp} )
    {
        main::print_log( "[Venstar Colortouch:"
              . $self->{data}->{name}
              . "] Thermostat heating setpoint changed from $self->{previous}->{info}->{heattemp} to $self->{data}->{info}->{heattemp}"
        ) if ( $self->{loglevel} );
        $self->{previous}->{info}->{heattemp} =
          $self->{data}->{info}->{heattemp};
    }

    if ( $self->{previous}->{info}->{heattempmin} !=
        $self->{data}->{info}->{heattempmin} )
    {
        main::print_log( "[Venstar Colortouch:"
              . $self->{data}->{name}
              . "] Thermostat heating setpoint minimum changed from $self->{previous}->{info}->{heattempmin} to $self->{data}->{info}->{heattempmin}"
        ) if ( $self->{loglevel} );
        $self->{previous}->{info}->{heattempmin} =
          $self->{data}->{info}->{heattempmin};
    }

    if ( $self->{previous}->{info}->{heattempmax} !=
        $self->{data}->{info}->{heattempmax} )
    {
        main::print_log( "[Venstar Colortouch:"
              . $self->{data}->{name}
              . "] Thermostat heating setpoint maximum changed from $self->{previous}->{info}->{heattempmax} to $self->{data}->{info}->{heattempmax}"
        ) if ( $self->{loglevel} );
        $self->{previous}->{info}->{heattempmax} =
          $self->{data}->{info}->{heattempmax};
    }

    if ( $self->{previous}->{info}->{cooltemp} !=
        $self->{data}->{info}->{cooltemp} )
    {
        main::print_log( "[Venstar Colortouch:"
              . $self->{data}->{name}
              . "] Thermostat cooling setpoint changed from $self->{previous}->{info}->{cooltemp} to $self->{data}->{info}->{cooltemp}"
        ) if ( $self->{loglevel} );
        $self->{previous}->{info}->{cooltemp} =
          $self->{data}->{info}->{cooltemp};
    }

    if ( $self->{previous}->{info}->{cooltempmin} !=
        $self->{data}->{info}->{cooltempmin} )
    {
        main::print_log( "[Venstar Colortouch:"
              . $self->{data}->{name}
              . "] Thermostat cooling setpoint minimum changed from $self->{previous}->{info}->{cooltempmin} to $self->{data}->{info}->{cooltempmin}"
        ) if ( $self->{loglevel} );
        $self->{previous}->{info}->{cooltempmin} =
          $self->{data}->{info}->{cooltempmin};
    }

    if ( $self->{previous}->{info}->{cooltempmax} !=
        $self->{data}->{info}->{cooltempmax} )
    {
        main::print_log( "[Venstar Colortouch:"
              . $self->{data}->{name}
              . "] Thermostat cooling setpoint maximum changed from $self->{previous}->{info}->{cooltempmax} to $self->{data}->{info}->{cooltempmax}"
        ) if ( $self->{loglevel} );
        $self->{previous}->{info}->{cooltempmax} =
          $self->{data}->{info}->{cooltempmax};
    }

    if ( $self->{previous}->{info}->{dehum_setpoint} !=
        $self->{data}->{info}->{dehum_setpoint} )
    {
        main::print_log( "[Venstar Colortouch:"
              . $self->{data}->{name}
              . "] Thermostat dehumidity setpoint changed from $self->{previous}->{info}->{dehum_setpoint} to $self->{data}->{info}->{dehum_setpoint}"
        ) if ( $self->{loglevel} );
        $self->{previous}->{info}->{dehum_setpoint} =
          $self->{data}->{info}->{dehum_setpoint};
        if ( defined $self->{child_object}->{dehum_sp} ) {
            main::print_log "Child object found. Updating..."
              if ( $self->{loglevel} );
            $self->{child_object}->{dehum_sp}
              ->set( $self->{data}->{info}->{dehum_setpoint}, 'poll' );
        }
    }

    if ( $self->{previous}->{info}->{hum_setpoint} !=
        $self->{data}->{info}->{hum_setpoint} )
    {
        main::print_log( "[Venstar Colortouch:"
              . $self->{data}->{name}
              . "] Thermostat humidity setpoint changed from $self->{previous}->{info}->{hum_setpoint} to $self->{data}->{info}->{hum_setpoint}"
        ) if ( $self->{loglevel} );
        $self->{previous}->{info}->{hum_setpoint} =
          $self->{data}->{info}->{hum_setpoint};
        if ( defined $self->{child_object}->{hum_sp} ) {
            main::print_log "Child object found. Updating..."
              if ( $self->{loglevel} );
            $self->{child_object}->{hum_sp}
              ->set( $self->{data}->{info}->{hum_setpoint}, 'poll' );
        }
    }

    #if ($self->{previous}->{info}->{hum} != $self->{data}->{info}->{hum}) {
    #  main::print_log("[Venstar Colortouch:". $self->{data}->{name} . "] Thermostat humidity changed from $self->{previous}->{info}->{hum} to $self->{data}->{info}->{hum}") if ($self->{loglevel});
    #  $self->{previous}->{info}->{hum} = $self->{data}->{info}->{hum};
    #}

    if ( $self->{previous}->{info}->{setpointdelta} !=
        $self->{data}->{info}->{setpointdelta} )
    {
        main::print_log( "[Venstar Colortouch:"
              . $self->{data}->{name}
              . "] Thermostat setpoint delta changed from $self->{previous}->{info}->{setpointdelta} to $self->{data}->{info}->{setpointdelta}"
        ) if ( $self->{loglevel} );
        $self->{previous}->{info}->{setpointdelta} =
          $self->{data}->{info}->{setpointdelta};
    }

    if ( $self->{previous}->{sensors}->{sensors}[0]->{hum} !=
        $self->{data}->{sensors}->{sensors}[0]->{hum} )
    {
        main::print_log( "[Venstar Colortouch:"
              . $self->{data}->{name}
              . "] Thermostat Humidity Sensor changed from $self->{previous}->{sensors}->{sensors}[0]->{hum} to $self->{data}->{sensors}->{sensors}[0]->{hum}"
        ) if ( $self->{loglevel} );
        $self->{previous}->{sensors}->{sensors}[0]->{hum} =
          $self->{data}->{sensors}->{sensors}[0]->{hum};
        if ( defined $self->{child_object}->{hum} ) {
            main::print_log "Child object found. Updating..."
              if ( $self->{loglevel} );
            $self->{child_object}->{hum}
              ->set( $self->{data}->{sensors}->{sensors}[0]->{hum}, 'poll' );
        }
    }

}

sub print_runtimes {
    my ($self) = @_;
    my ( $isSuccessResponse1, $data ) =
      get_JSON_data( $self->{host}, 'runtimes' );

    for my $tstamp ( 0 .. $#{ $data->{runtimes} } ) {

        print $data->{runtimes}[$tstamp]->{ts} . " -> ";
        print scalar localtime( ( $data->{runtimes}[$tstamp]->{ts} ) -
              ( $self->{config}->{tz} * 60 * 60 + 1 ) );
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
    return ( $self->{data}->{info}->{hum_setpoint} );
}

sub get_sp_dehum {
    my ($self) = @_;
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
    my ($self) = @_;

    #  my ($isSuccessResponse) = $self->poll;
    #    if ($isSuccessResponse) {
    return ( $self->{data}->{sensors}->{sensors}[0]->{temp} );

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

#------------
# User control methods
#tempunits=0&away=0&schedule=0&hum_setpoint=0&dehum_setpoint=0
#mode=0&fan=0&heattemp=70&cooltemp=75
#($isSuccessResponse3,$status) = push_JSON_data($host,'control','fan=0');
#($isSuccessResponse3,$status) = push_JSON_data($host,'settings','away=0&schedule=1');

sub set_heat_sp {
    my ( $self, $value ) = @_;
    my ( $isSuccessResponse, $status ) =
      $self->_push_JSON_data( 'control', "heattemp=$value" );
    if ($isSuccessResponse) {
        if ( $status eq "success" ) {
            return (1);
        }
        else {
            main::print_log( "[Venstar Colortouch:"
                  . $self->{data}->{name}
                  . "] Error. Could not set heating setpoint to $value" );
            return (0);
        }
    }
    else {
        main::print_log( "[Venstar Colortouch:"
              . $self->{data}->{name}
              . "] Error. Could not send data to Thermostat" );
        return (0);
    }
}

sub set_cool_sp {
    my ( $self, $value ) = @_;

    my ( $isSuccessResponse, $status ) =
      $self->_push_JSON_data( 'control', "cooltemp=$value" );
    if ($isSuccessResponse) {
        if ( $status eq "success" ) {
            return (1);
        }
        else {
            main::print_log( "[Venstar Colortouch:"
                  . $self->{data}->{name}
                  . "] Error. Could not set cooling setpoint to $value" );
            return (0);
        }
    }
    else {
        main::print_log( "[Venstar Colortouch:"
              . $self->{data}->{name}
              . "] Error. Could not send data to Thermostat" );
        return (0);
    }
}

sub set_hum_sp {
    my ( $self, $value ) = @_;

    my ( $isSuccessResponse, $status ) =
      $self->_push_JSON_data( 'settings', "hum_setpoint=$value" );
    if ($isSuccessResponse) {
        if ( $status eq "success" ) {
            return (1);
        }
        else {
            main::print_log( "[Venstar Colortouch:"
                  . $self->{data}->{name}
                  . "] Error. Could not set humidity setpoint to $value" );
            return (0);
        }
    }
    else {
        main::print_log( "[Venstar Colortouch:"
              . $self->{data}->{name}
              . "] Error. Could not send data to Thermostat" );
        return (0);
    }
}

sub set_dehum_sp {
    my ( $self, $value ) = @_;

    my ( $isSuccessResponse, $status ) =
      $self->_push_JSON_data( 'settings', "dehum_setpoint=$value" );
    if ($isSuccessResponse) {
        if ( $status eq "success" ) {
            return (1);
        }
        else {
            main::print_log( "[Venstar Colortouch:"
                  . $self->{data}->{name}
                  . "] Error. Could not set humidity setpoint to $value" );
            return (0);
        }
    }
    else {
        main::print_log( "[Venstar Colortouch:"
              . $self->{data}->{name}
              . "] Error. Could not send data to Thermostat" );
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
        main::print_log( "Venstar Colortouch:"
              . $self->{data}->{name}
              . "] Error, unknown schedule mode $value" );
        return ('0');
    }
    my ( $isSuccessResponse, $status ) =
      $self->_push_JSON_data( 'settings', "schedule=$num" );
    if ($isSuccessResponse) {
        if ( $status eq "success" ) {
            return (1);
        }
        else {
            main::print_log( "[Venstar Colortouch:"
                  . $self->{data}->{name}
                  . "] Error. Could not set schedule mode to $value" );
            return (0);
        }
    }
    else {
        main::print_log( "[Venstar Colortouch:"
              . $self->{data}->{name}
              . "] Error. Could not send data to Thermostat" );
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

    my ( $isSuccessResponse, $status ) =
      $self->_push_JSON_data( 'control', "mode=$num" );
    if ($isSuccessResponse) {
        if ( $status eq "success" ) {    #todo parse return value
            $self->poll;
            return (1);
        }
        else {
            main::print_log( "[Venstar Colortouch:"
                  . $self->{data}->{name}
                  . "] Error. Could not set mode to $value" );
            return (0);
        }
    }
    else {
        main::print_log( "[Venstar Colortouch:"
              . $self->{data}->{name}
              . "] Error. Could not send data to Thermostat" );
        return (0);
    }

}

sub set_away {

    #($isSuccessResponse3,$status) = push_JSON_data($host,'settings','away=0&schedule=1');

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
        main::print_log( "Venstar Colortouch:"
              . $self->{data}->{name}
              . "] Error, unknown fan mode $value" );
        return ('0');
    }
    my ( $isSuccessResponse, $status ) =
      $self->_push_JSON_data( 'control', "fan=$num" );
    if ($isSuccessResponse) {
        if ( $status eq "success" ) {
            return (1);
        }
        else {
            main::print_log( "[Venstar Colortouch:"
                  . $self->{data}->{name}
                  . "] Error. Could not set fan mode to $value" );
            return (0);
        }
    }
    else {
        main::print_log( "[Venstar Colortouch:"
              . $self->{data}->{name}
              . "] Error. Could not send data to Thermostat" );
        return (0);
    }

}

sub set_units {

    #($isSuccessResponse3,$status) = push_JSON_data($host,'settings','away=0&schedule=1');

}

sub set {
    my ( $self, $p_state, $p_setby ) = @_;

    if ( $p_setby eq 'poll' ) {
        $self->SUPER::set($p_state);
    }
    else {
        $self->set_mode($p_state);
    }
}

package Venstar_Colortouch_Temp;

@Venstar_Colortouch_Temp::ISA = ('Generic_Item');

sub new {
    my ( $class, $object ) = @_;

    my $self = {};
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

    my $self = {};
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
            main::print_log(
                "[Venstar Colortouch Fan] Error. Unknown set state $p_state");
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

    my $self = {};
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

    my $self = {};
    bless $self, $class;

    $$self{master_object} = $object;

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
            main::print_log(
                "[Venstar Colortouch Humidity_SP] Error. Unknown set state $p_state"
            );
        }
    }
}

package Venstar_Colortouch_Schedule;

@Venstar_Colortouch_Schedule::ISA = ('Generic_Item');

sub new {
    my ( $class, $object ) = @_;

    my $self = {};
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
            main::print_log(
                "[Venstar Colortouch Scheduler] Error. Unknown set state $p_state"
            );
        }
    }
}

package Venstar_Colortouch_Comm;

@Venstar_Colortouch_Comm::ISA = ('Generic_Item');

sub new {
    my ( $class, $object ) = @_;

    my $self = {};
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
