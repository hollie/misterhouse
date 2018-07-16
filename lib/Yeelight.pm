package Yeelight;

# v1.0

#if any effect is changed, by definition the static child should be set to off.
#cmd data returns, need to check by command
#NB: if any effect gets set, or another static is active, then other statics should be set to off.

#effects, turn static off and clear out static_check

#TODO

use strict;
use warnings;

use LWP::UserAgent;
use HTTP::Request::Common qw(POST);
use JSON::XS;
use Data::Dumper;
use Socket;
use IO::Select;
use IO::Socket::INET;

# To set up, first pair with mobile app -- the Yeelight needs to be set up initially with the app
# to get it's wifi information. 
# if problems with ios, use the android app if you can.
# MAKE SURE TO SELECT A 2.4Ghz WIRELESS NETWORK
# TURN ON LOCAL CONTROL

# Firmware supported
# stripe       : 44

# Yeelight Objects
#
# $Yeelight         = new Yeelight('1');
# $Yeelight_effects = new Yeelight_Effects($aurora);
# $Yeelight_comm    = new Yeelight_Comm($aurora);

# MH.INI settings
# If the token is auto generated, it will be written to the mh.ini. MH.INI settings can be used
# instead of object definitions
#
# Yeelight_<ID>_location =
# Yeelight_<ID>_poll =
# Yeelight_<ID>_options =
#
# for example
#Yeelight_1_location = 10.10.0.20
#Yeelight_1_token = EfgrIHH887EHhftotNNSD818erhNWHR0
#Yeelight_1_options = 'api=beta'

# OPTIONS
# current options that can be passed are;
#  - api=<level>
#  - debug=<level>
#  - loglevel=<level>

# Notes
#
# The Yeelight needs to be specified as an IP address, since the module uses SSDP scan to determine
# what features are supported

# Issues

#

@Yeelight::ISA = ('Generic_Item');

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
@{$param_array{info}}       = ("power","bright","ct","rgb","hue","sat","color_mode","flowing","delayoff","flow_params","music_on","name","bg_power","bg_flowing","bg_flow_params","bg_ct","bg_lmode","bg_bright","bg_rgb","bg_hue","bg_sat","nl_br");
@{$param_array{brightness}} = ("smooth",500);
@{$param_array{on}}         = ("on","smooth",500);
@{$param_array{off}}        = ("on","smooth",500);

our %active_yeelights = ();

sub new {
    my ( $class, $id, $location, $poll, $options ) = @_;
    my $self = new Generic_Item();
    bless $self, $class;
    $self->{id}   = "1";
    $self->{id} = $id if ((defined $id) and ($id));
    
    $self->{name} = "1";
    $self->{name} = $id if ((defined $id) and ($id));

    $self->{data}                   = undef;
    $self->{child_object}           = undef;
    $self->{config}->{poll_seconds} = 10;
    $self->{config}->{poll_seconds} = $::config_parms{ "yeelight_" . $self->{name} . "_poll" }
      if ( defined $::config_parms{ "yeelight_" . $self->{name} . "_poll" } );
    $self->{config}->{poll_seconds} = $poll if ($poll);
    $self->{config}->{poll_seconds} = 1     if ( $self->{config}->{poll_seconds} < 1 );
    $self->{updating}               = 0;
    $self->{data}->{retry}          = 0;
    $self->{status}                 = "";
    $self->{module_version}         = "v1.0";
    $self->{ssdp_timeout}           = 1000;
    $self->{last_static}            = "";
    $self->{host}                   = $location;
    $self->{port}                   = 55443;

    if ($location =~ m/:/) {
        ($self->{host}, $self->{port}) = $location =~ /(.*):(.*)/;
    } 

    $options = "" unless ( defined $options );
    $options = $::config_parms{ "yeelight_" . $self->{name} . "_options" } if ( $::config_parms{ "yeelight_" . $self->{name} . "_options" } );

    $self->{debug} = 4;
    ( $self->{debug} ) = ( $options =~ /debug\=(\d+)/i ) if ( $options =~ m/debug\=/i );
    $self->{debug} = 0 if ( $self->{debug} < 0 );

    $self->{loglevel} = 5;
    ( $self->{loglevel} ) = ( $options =~ /loglevel\=(\d+)/i ) if ($options =~ m/loglevel\=/i );

    $self->{poll_data_timestamp}     = 0;
    $self->{max_poll_queue}          = 3;
    $self->{max_cmd_queue}           = 5;
    $self->{cmd_process_retry_limit} = 6;

    @{ $self->{poll_queue} } = ();
    $self->{poll_data_file} = "$::config_parms{data_dir}/Yeelight_poll_" . $self->{name} . ".data";
    unlink "$::config_parms{data_dir}/Yeelight_poll_" . $self->{name} . ".data";
    $self->{poll_process} = new Process_Item;
    $self->{poll_process}->set_output( $self->{poll_data_file} );
    @{ $self->{cmd_queue} } = ();
    $self->{cmd_data_file} = "$::config_parms{data_dir}/Yeelight_cmd_" . $self->{name} . ".data";
    unlink "$::config_parms{data_dir}/Yeelight_cmd_" . $self->{name} . ".data";
    $self->{cmd_process} = new Process_Item;
    $self->{cmd_process}->set_output( $self->{cmd_data_file} );
    $self->{init}      = 0;
    $self->{init_data} = 0;
    $self->{init_v_cmd} = 0;
    &::MainLoop_post_add_hook( \&Yeelight::process_check, 0, $self );
    &::Reload_post_add_hook( \&Yeelight::generate_voice_commands, 1, $self );
    $self->get_data();    
    #push( @{ $$self{states} }, 'off', '10%', '20%', '30%', '40%', '50%', '60%', '70%', '80%', '90%', 'on' );
    push( @{ $$self{states} }, 'off');
    for my $i (1..99) { push @{ $$self{states} }, "$i%"; }
    push( @{ $$self{states} }, 'on');
    $self->{timer} = new Timer;
    $self->start_timer;
    return $self;
}

sub start_timer {
    my ($self) = @_;
    unless ( defined $self->{timer} ) {
        $self->{timer} = new Timer;    #HP: why do timers get undefined??
    }
    if ( defined $self->{timer} ) {
        $self->{timer}->set( $self->{config}->{poll_seconds}, sub { &Yeelight::get_data($self) }, -1 );
    }
    else {
        main::print_log( "[Yeelight:" . $self->{name} . "] Warning, start_timer called but timer undefined" );
    }
}

sub get_data {
    my ($self) = @_;

    main::print_log( "[Yeelight:" . $self->{name} . "] get_data initiated" ) if ( $self->{debug} );
    
    #Check that we have data

    if ( $self->{init} == 0 ) {
        main::print_log( "[Yeelight:" . $self->{name} . "] Contacting Yeelight for configuration details..." );
        $self->get_ssdp_data($self->{ssdp_timeout});             
    }

    if ( $self->{data}->{info}->{Location} ) {

        if ( ( defined $self->{data}->{info}->{model} ) and ( $self->{init} == 0 ) ) {
            main::print_log( "[Yeelight:" . $self->{name} . "] " . $self->{module_version} . " Configuration Loaded" );
            $active_yeelights{ $self->{host} } = 1;
            $self->print_info();
            $self->{init} = 1;
        }
        $self->poll();

    }
    else {
        main::print_log( "[Yeelight:" . $self->{name} . "] WARNING, Did not poll: location: $self->{location}" ) if ( $self->{debug} );
    }
}


sub poll {
    my ($self) = @_;

    main::print_log( "[Yeelight:" . $self->{name} . "] Background Polling initiated" ) if ( $self->{debug} );
    $self->_get_TCP_data('info');

    return ('1');
}

sub process_check {
    my ($self) = @_;

    return unless ( defined $self->{poll_process} );

    if ( $self->{poll_process}->done_now() ) {
    
        #shift @{ $self->{poll_queue} };    #remove the poll since they are expendable.
        @{ $self->{poll_queue} } = ();      #clear the queue since process is done.

        my $com_status = "online";
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
            main::print_log( "[Yeelight:" . $self->{name} . "] ERROR! bad data returned by poll" );
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
                    $self->{data}->{info}->{$item} = $data->{result}[$index] unless ($data->{result}[$index] eq "");
                    $index++;
                }

                $self->process_data();
            }
            else {
                main::print_log( "[Yeelight:" . $self->{name} . "] ERROR! Returned data not structured! Not processing..." );
                $com_status = "offline";
            }
        }

        if ( defined $self->{child_object}->{comm} ) {
            if ( $self->{status} ne $com_status ) {
                main::print_log "[Yeelight:" . $self->{name} . "] Communication Tracking object found. Updating from " . $self->{child_object}->{comm}->state() . " to " . $com_status . "..." if ( $self->{loglevel} );
                $self->{status} = $com_status;
                $self->{child_object}->{comm}->set( $com_status, 'poll' );
            }
        }
    }

    return unless ( defined $self->{cmd_process} );
    if ( $self->{cmd_process}->done_now() ) {
        main::print_log( "[Yeelight:" . $self->{name} . "] Background Command " . $self->{cmd_process_mode} . " process completed" ) if ( $self->{debug} );
        $self->get_data();    #poll since the command is done to get a new state

        my $file_data = &main::file_read( $self->{cmd_data_file} );
        my $com_status = "online";

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
                $com_status = "offline";
            }
            else {
shift @{ $self->{cmd_queue} };
print "***RESULTS***";
print Dumper $data;
                if ($data->{results} eq 'ok') {
                    shift @{ $self->{cmd_queue} };    #remove the command from queue since it was successful
                    $self->{cmd_process_retry} = 0;
                    $com_status = "online";

                } else {
                    main::print_log( "[Yeelight:" . $self->{name} . "] Last command failed! Going to retry" );
                }
                $self->poll;
            }

            if ( scalar @{ $self->{cmd_queue} } ) {
                main::print_log( "[Yeelight:" . $self->{name} . "] Command Queue found" );            
                my $cmd = @{ $self->{cmd_queue} }[0];    #grab the first command, but don't take it off.
                $self->{cmd_process}->set($cmd);
                $self->{cmd_process}->start();
                main::print_log( "[Yeelight:" . $self->{name} . "] Command Queue " . $self->{cmd_process}->pid() . " cmd=$cmd" )
                  if ( ( $self->{debug} ) or ( $self->{cmd_process_retry} ) );
            }

        }
        else {

            main::print_log( "[Yeelight:" . $self->{name} . "] WARNING Issued command was unsuccessful, retrying..." );
            if ( $self->{cmd_process_retry} > $self->{cmd_process_retry_limit} ) {
                main::print_log( "[Yeelight:" . $self->{name} . "] ERROR Issued command max retries reached. Abandoning command attempt..." );
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
                main::print_log "[Yeelight:" . $self->{name} . "] Communication Tracking object found. Updating from " . $self->{child_object}->{comm}->state() . " to " . $com_status . "..." if ( $self->{loglevel} );
                $self->{status} = $com_status;
                $self->{child_object}->{comm}->set( $com_status, 'poll' );
            }
        }
    }
}

#polling process. Keep it separate from commands
sub _get_TCP_data {
    my ( $self, $mode, $params ) = @_;
    #{"id":1,"method":"get_prop","params":["power","bright","ct","rgb","hue","sat","color_mode","flowing","delayoff","flow_params","music_on","name","bg_power","bg_flowing","bg_flow_params","bg_ct","bg_lmode","bg_bright","bg_rgb","bg_hue","bg_sat","nl_br"]}\r\n);
    my $cmdline = "{\"id\":" . $self->{id} . ",\"method\":" . $method{$mode} . ",\"params\":[";
    foreach my $item (@{$param_array{$mode}}) {
        $cmdline .= '"' . $item . '",';
    }
    chop($cmdline);
    $cmdline .= "]}";
    my $cmd = "get_tcp -rn -quiet $self->{host}:$self->{port} " . "'" . $cmdline . "'";
    if ( $self->{poll_process}->done() ) {
        $self->{poll_process}->set($cmd);
        $self->{poll_process}->start();
        $self->{poll_process_pid}->{ $self->{poll_process}->pid() } = $mode;    #capture the type of information requested in order to parse;
        $self->{poll_process_mode} = $mode;
        main::print_log( "[Yeelight:" . $self->{name} . "] Backgrounding " . $self->{poll_process}->pid() . " command $mode, $cmd" ) if ( $self->{debug} );
    }
    else {
        if ( scalar @{ $self->{poll_queue} } < $self->{max_poll_queue} ) {
            main::print_log( "[Yeelight:" . $self->{name} . "] Queue is " . scalar @{ $self->{poll_queue} } . ". Queing command $mode, $cmd" )
              if ( $self->{debug} );
            push @{ $self->{poll_queue} }, "$mode|$cmd";
        }
        else {
            #the queue has grown past the max, so it might be down. Since polls are expendable, just don't do anything
            #when the aurora is back it will process the backlog, and as soon as a poll is processed, the queue is cleared.
        }
    }
}

#command process
sub _push_TCP_data {
    my ( $self, $mode, @params ) = @_;

    my $cmdline = "{\"id\":" . $self->{id} . ",\"method\":" . $method{$mode} . ",\"params\":[";
    foreach my $item (@params) {
        $cmdline .= '"' . $item . '",';
    }
    chop($cmdline);
    $cmdline .= "]}";
    my $cmd = "get_tcp -rn -quiet $self->{host}:$self->{port} " . "'" . $cmdline . "'";

print "***cmd=$cmd\n";

    if ( $self->{cmd_process}->done() ) {
        $self->{cmd_process}->set($cmd);
        $self->{cmd_process}->start();
        $self->{cmd_process_pid}->{ $self->{cmd_process}->pid() } = $mode;    #capture the type of information requested in order to parse;
        $self->{cmd_process_mode} = $mode;
        push @{ $self->{cmd_queue} }, "$cmd";

        main::print_log( "[Yeelight:" . $self->{name} . "] Backgrounding " . $self->{cmd_process}->pid() . " command $mode, $cmd" ) if ( $self->{debug} );
    }
    else {
        if ( scalar @{ $self->{cmd_queue} } < $self->{max_cmd_queue} ) {
            main::print_log( "[Yeelight:" . $self->{name} . "] Queue is " . scalar @{ $self->{cmd_queue} } . ". Queing command $mode, $cmd" )
              if ( $self->{debug} );
            push @{ $self->{cmd_queue} }, "$cmd";
        }
        else {
            main::print_log( "[Yeelight:" . $self->{name} . "] WARNING. Queue has grown past " . $self->{max_cmd_queue} . ". Command discarded." );
            if ( defined $self->{child_object}->{comm} ) {
                if ( $self->{status} ne "offline" ) {
                    main::print_log "[Yeelight:"
                      . $self->{name}
                      . "] Communication Tracking object found. Updating from "
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

sub get_ssdp_data {
    my ( $self, $id, $timeout ) = @_;

    #return a location that isn't in the $active_auroras hash

    my ( $data ) = scan_ssdp_data($timeout);
    if (defined $data and defined $data->{$self->{host}}) {
        &main::print_log( "[Yeelight:" . $self->{name} . "] SSDP scan found device $self->{host}!");    
#TODO Cleanupthere probably is a better way to copy in a hash
        $self->{data}->{info} = $data->{$self->{host}};
        #foreach my $key (keys %{$data->{$self->{host}}}) { 
        #    print "**key = $key, $data->{$self->{host}}->{$key}\n";
        #    $self->{data}->{info}->{$key} = $data->{$self->{host}}->{$key}; 
        #}
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
    &main::print_log( "[Yeelight] Discovering >" );
    while ($i++ < $timeout) {
        select undef, undef, undef, .1;

        my @ready = $sel->can_read(2);
        last unless scalar @ready;

        recv($sock,$data, 65536,0);
        $count++;
        &main::print_log( "[Yeelight] Receiving $count ($i) ");
        my ($location) = $data =~ /Location:\syeelight:\/\/(.*)/;
        $location =~ s/[^a-zA-Z0-9\:\.\/]*//g;
        if ($location) {
             my ($host, $port) = $location =~ /(.*):(.*)/;
             $yl{$host}->{host} = $host;
             $yl{$host}->{port} = $port;    
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
    return \%yl;    
    }


sub register {
    my ( $self, $object, $type ) = @_;
    my $keys = "";

    #allow for multiple static entries
    if ( lc $type eq 'static' ) {
        if ( defined $self->{child_object}->{static} ) {
            $keys = keys %{ $self->{child_object}->{static} };
        }
        else {
            $keys = 0;
        }
        $self->{child_object}->{static}->{$keys} = $object;
    }
    else {
        $self->{child_object}->{$type} = $object;
    }
    $type .= " (" . $keys . ")" if ( $keys ne "" );
    &main::print_log( "[Yeelight:" . $self->{name} . "] Registered $type child object" );

}

sub stop_timer {
    my ($self) = @_;

    if ( defined $self->{timer} ) {
        $self->{timer}->stop() if ( $self->{timer}->active() );
    }
    else {
        main::print_log( "[Yeelight:" . $self->{name} . "] Warning, stop_timer called but timer undefined" );
    }
}

sub print_info {
    my ($self) = @_;
    my $name = $self->{data}->{info}->{name};
    $name = "Not Set" if ($self->{data}->{info}->{name} eq "");
    
    main::print_log( "[Yeelight:" . $self->{name} . "] Name:              " . $name );
    main::print_log( "[Yeelight:" . $self->{name} . "] Model:             " . $self->{data}->{info}->{model} );
    main::print_log( "[Yeelight:" . $self->{name} . "] Firmware:          " . $self->{data}->{info}->{fw_ver} );
   

    main::print_log( "[Yeelight:" . $self->{name} . "] MH Module version: " . $self->{module_version} );
    main::print_log( "[Yeelight:" . $self->{name} . "] *** DEBUG MODE ENABLED ***") if ( $self->{debug} );

    main::print_log( "[Yeelight:" . $self->{name} . "] -- Current Settings --" );

    main::print_log( "[Yeelight:" . $self->{name} . "]    State:\t\t " . $self->{data}->{info}->{power}  );
    if ($self->{data}->{info}->{color_mode} == 1) {
        main::print_log( "[Yeelight:" . $self->{name} . "]    Color Mode:\t  rgb mode");
    } elsif ($self->{data}->{info}->{color_mode} == 2) {
        main::print_log( "[Yeelight:" . $self->{name} . "]    Color Mode:\t  color temperature mode");
    } elsif ($self->{data}->{info}->{color_mode} == 3) {
        main::print_log( "[Yeelight:" . $self->{name} . "]    Color Mode:\t  hsv mode");
    } else {
        main::print_log( "[Yeelight:" . $self->{name} . "]    Color Mode:\t  Unknown mode: " . $self->{data}->{info}->{color_mode});
    }
    main::print_log( "[Yeelight:" . $self->{name} . "]    Brightness:\t " . $self->{data}->{info}->{bright} );
    #rgb = red * 65536 + green * 256 + blue
    my ($r_red, $r_green, $r_blue) = $self->get_rgb();
    main::print_log( "[Yeelight:" . $self->{name} . "]    RGB:\t\t  " . $self->{data}->{info}->{rgb} );
    main::print_log( "[Yeelight:" . $self->{name} . "]    \tRed:  " . $r_red );
    main::print_log( "[Yeelight:" . $self->{name} . "]    \tGreen:  " . $r_green );
    main::print_log( "[Yeelight:" . $self->{name} . "]    \tBlue:  " . $r_blue );
    
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
    # for any registered child selfs, update their state if

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
        main::print_log( "[Yeelight:" . $self->{name} . "] Brightness changed from $self->{previous}->{info}->{state}->{brightness}->{value} to $self->{data}->{info}->{state}->{brightness}->{value}" ) if ( $self->{loglevel} );
        $self->{previous}->{info}->{bright} = $self->{data}->{info}->{bright};
        $self->set( $self->{data}->{info}->{bright}, 'poll' );
    }
#TODO convert the rest

    if ( $self->{previous}->{info}{color_mode} != $self->{data}->{info}->{color_mode} ) {
        main::print_log( "[Yeelight:" . $self->{name} . "] State Color Mode changed from $self->{previous}->{info}->{color_mode} to $self->{data}->{info}->{color_mode}" ) if ( $self->{loglevel} );
        $self->{previous}->{info}->{color_mode} = $self->{data}->{info}->{color_mode};
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
        main::print_log( "Yeelight:" . $self->{name} . "] Command $i: " . @{ $self->{cmd_queue} }[$i - 1] );
    }
    main::print_log( "Yeelight:" . $self->{name} . "] ------------------------------------------------------------------" );
    
}

sub purge_command_queue {
    my ($self) = @_;
    my $commands = scalar @{ $self->{cmd_queue} };
    main::print_log( "Aurora:" . $self->{name} . "] Purging Command Queue of $commands commands" );
    @{ $self->{cmd_queue} } = ();
}

#------------
# User access methods

sub get_debug {
    my ($self) = @_;
    return $self->{debug};
}

sub set {
    my ( $self, $p_state, $p_setby ) = @_;

    if ( $p_setby eq 'poll' ) {
        $p_state .= "%" if ( defined $p_state and $p_state =~ m/\d+(?!%)/ );
        main::print_log( "[Yeelight:" . $self->{name} . "] DB super::set, in master set, p_state=$p_state, p_setby=$p_setby" ) if ( $self->{debug} );
        $self->SUPER::set($p_state);
        $self->start_timer;

    }
    else {
        main::print_log( "[Yeelight:" . $self->{name} . "] DB set_mode, in master set, p_state=$p_state, p_setby=$p_setby" ) if ( $self->{debug} );
        my $mode = lc $p_state;
        if ( ( $mode eq "on" ) or ( $mode eq "off" ) ) {
            $self->_push_TCP_data($mode, @{$param_array{$mode}});
        }
        elsif ( $mode =~ /^(\d+)/ ) {
            my @params = @{$param_array{$mode}};
            unshift @params, $1;
            $self->_push_TCP_data( 'brightness', @params );
        }
        elsif ( $mode =~ /^([-+]\d+)/ ) {
            my @params = @{$param_array{$mode}};
            unshift @params, $self->{info}->{bright} + $1;
            $self->_push_TCP_data( 'brightness', @params );
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
    my $red = int($self->{data}->{info}->{rgb} / 65536);
    my $green = int(($self->{data}->{info}->{rgb} - ($red * 65536)) / 256);
    my $blue = $self->{data}->{info}->{rgb} - ($red * 65536) - ($green * 256);
    return ($red, $green, $blue);
}

sub set_hsv {
    my ( $self, $h, $s, $v ) = @_;
}

sub set_rgb {
    my ( $self, $r, $g, $b ) = @_;
    my ( $cred, $cgreen, $cblue) = $self->get_rbg();
    $r = $cred unless ($r);
    $g = $cgreen unless ($g);
    $b = $cblue unless ($b);
    my $value = ($r * 65536) + ($g * 265) + $b;
#TODO    $self->_push_TCP_data( 'brightness', $params );
}

sub set_ct {
    my ( $self, $ct ) = @_;
}

sub generate_voice_commands {
    my ($self) = @_;

    if ($self->{init_v_cmd} == 0) {
        my $object_string;
        my $object_name = $self->get_object_name;
        $self->{init_v_cmd} = 1;
        &main::print_log("Generating Voice commands for Nanoleaf Aurora Controller $object_name");

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
            $object_string .= ::store_object_data( $object_name_v, 'Voice_Cmd', 'Nanoleaf_Aurora', 'Controller_commands' );
            $i++;
        }

        #Evaluate the resulting object generating string
        package main;
        eval $object_string;
        print "Error in nanoleaf_Yeelight_item_commands: $@\n" if $@;

        package Nanoleaf_Aurora;
    }
}

sub get_voice_cmds {
    my ($self) = @_;
    my %voice_cmds = (
        'Print Command Queue to print log'                                      => $self->get_object_name . '->print_command_queue',
        'Purge Command Queue'                                                   => $self->get_object_name . '->purge_command_queue'
       
    );

    return \%voice_cmds;
}



package Yeelight_Red;

@Nanoleaf_Yeelight_Static::ISA = ('Generic_Item');

sub new {
    my ( $class, $object, $static_string ) = @_;

    my $self = new Generic_Item();
    bless $self, $class;
    @{ $$self{states} } = ( 'on', 'off' );

    $$self{master_object} = $object;
    $$self{loop}          = 0;
    $$self{string}        = $static_string if ( defined $static_string );
    $object->register( $self, 'rgb-red' );
    return $self;

}

sub set {
    my ( $self, $p_state, $p_setby ) = @_;

    if ( $p_setby eq 'poll' ) {
        $self->SUPER::set($p_state);
    }
    else {
        #if ON then backup current configuration and set the new one.
        if ( lc $p_state eq 'on' ) {
            $$self{previous_effect} = $$self{master_object}->get_effect();
            $$self{master_object}->set_static( $$self{string} );

            #if OFF then check if current is same as static, and if so restore the old one.
        }
        elsif ( lc $p_state eq 'off' ) {
            $$self{master_object}->check_static( $$self{string}, $$self{previous_effect} );
        }
        else {
            main::print_log("[Aurora Static] Error. Unknown set mode $p_state");
        }
    }
}



package Yeelight_Comm;

@Nanoleaf_Yeelight_Comm::ISA = ('Generic_Item');

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
# v1.0.0  - initial module
# v1.0.1  - initial static support
# v1.0.2  - multiple auroras, brightness
# v1.0.3  - working static. turn on, overrides effect, turning off will restore previous effect
# v1.0.4  - Voice Commands
# v1.0.5  - working multi static
# v1.0.6  - better processing
# v1.0.7  - ability to specify API as an option
# v1.0.8  - initial v1.5.0 API v1 support
# v1.0.9  - use config_parms (mh.ini) instead of dedicated config file
# v1.0.10 - Updated to work with other versions of perl, typo with mh.ini
# v1.0.11 - cosmetic fixes for undefined variables
# v1.0.12 - get_effects method to get array of available effects
# v1.0.13 - ability to print and purge the command queue in case a network error prevents clearing, empty poll queue if max reached
# v1.0.14 - commands now queue properly
# v1.0.15 - fixed polling
# v1.1.01 - firmware v2.2.0 and rhythm module