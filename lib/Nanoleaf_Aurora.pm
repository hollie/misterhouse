package Nanoleaf_Aurora;

# v1.0.2

use strict;
use warnings;

use LWP::UserAgent;
use HTTP::Request::Common qw(POST);
use JSON::XS;
use Data::Dumper;
use IO::Select;
use IO::Socket::INET;

# Nanoleaf_Aurora Objects
# $aurora         = new NanoLeaf_Aurora(<id>,<nl_id>,<location>,<poll>,<options>);
# $aurora_effects = new NanoLeaf_Aurora_Effects($aurora);
# $aurora_static1 = new NanoLeaf_Aurora_Static($aurora);
# $aurora_comm    = new Nanoleaf_Aurora_Comm($aurora);

#NB: if any effect gets set, or another static is active, then other statics should be set to off.

# Version History
# v1.0   - initial
# v1.0.1 - static support
# v1.0.2 - multiple auroras, brightness

# Notes

# Issues

#

@Nanoleaf_Aurora::ISA = ('Generic_Item');

# -------------------- START OF SUBROUTINES --------------------
# --------------------------------------------------------------

our %rest;
$rest{info}        = "";
$rest{effects}     = "effects";
$rest{auth}        = "new";
$rest{on}          = "state/on";
$rest{off}         = "state/on";
$rest{set_effect}  = "effects/select";
$rest{set_static}  = "";
$rest{brightness}  = "state/brightness";
$rest{brightness2} = "state/brightness";

our %opts;
$opts{info}        = "-ua";
$opts{auth}        = "-json -post '{}'";
$opts{on}          = "-json -put '{\"on\":true}'";
$opts{off}         = "-json -put '{\"on\":false}'";
$opts{set_effect}  = "-json -put '{\"select\":";
$opts{set_static}  = "-json -put '{\"write\":{\"command\":\"display\",\"version\":\"1.0\",\"animType\":\"static\",\"animData\":";
$opts{brightness}  = "-json -put '{\"value\":";
$opts{brightness2} = "-json -put '{\"increment\":";

my $api_path = "/api/beta";

sub new {
    my ( $class, $id, $nl_deviceid, $location, $poll, $options ) = @_;
    my $self = {};
    bless $self, $class;
    $self->{data}         = undef;
    $self->{child_object} = undef;
    $options = "" unless ( defined $options );
    $self->{config}->{poll_seconds} = 10;
    $self->{config}->{poll_seconds} = $poll if ($poll);
    $self->{config}->{poll_seconds} = 1 if ( $self->{config}->{poll_seconds} < 1 );
    $self->{updating}               = 0;
    $self->{data}->{retry}          = 0;
    $self->{status}                 = "";
    $self->{name}                   = "1";
    $self->{module_version}         = "v1.0.2";
    $self->{ssdp_timeout}           = 4000;
    $self->{name}        = $id if ($id);
    $self->{nl_deviceid} = "";
    $self->{nl_deviceid} = $nl_deviceid if ( defined $nl_deviceid );
    $self->{location}    = $location;
    $self->{debug}       = 5;
    ( $self->{debug} ) = ( $options =~ /debug\=(\d+)/i ) if ( $options =~ m/debug\=/i );
    $self->{debug}                   = 0 if ( $self->{debug} < 0 );
    $self->{loglevel}                = 5;
    $self->{poll_data_timestamp}     = 0;
    $self->{max_poll_queue}          = 3;
    $self->{max_cmd_queue}           = 5;
    $self->{cmd_process_retry_limit} = 6;
    $self->{config_file}             = "$::config_parms{data_dir}/Aurora_config.json";

    @{ $self->{poll_queue} } = ();
    $self->{poll_data_file} = "$::config_parms{data_dir}/Aurora_poll_" . $self->{name} . ".data";
    unlink "$::config_parms{data_dir}/Aurora_poll_" . $self->{name} . ".data";
    $self->{poll_process} = new Process_Item;
    $self->{poll_process}->set_output( $self->{poll_data_file} );
    @{ $self->{cmd_queue} } = ();
    $self->{cmd_data_file} = "$::config_parms{data_dir}/Aurora_cmd_" . $self->{name} . ".data";
    unlink "$::config_parms{data_dir}/Auroroa_cmd_" . $self->{name} . ".data";
    $self->{cmd_process} = new Process_Item;
    $self->{cmd_process}->set_output( $self->{cmd_data_file} );
    &::MainLoop_post_add_hook( \&Nanoleaf_Aurora::process_check, 0, $self );
    $self->get_data();
    $self->{init}      = 0;
    $self->{init_data} = 0;
    $self->{file}      = 0;
    push( @{ $$self{states} }, 'off', '20%', '40%', '60%', '80%', 'on' );
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
        $self->{timer}->set( $self->{config}->{poll_seconds}, sub { &Nanoleaf_Aurora::get_data($self) }, -1 );
    }
    else {
        main::print_log( "[Aurora:" . $self->{name} . "] Warning, start_timer called but timer undefined" );
    }
}

sub get_data {
    my ($self) = @_;

    main::print_log( "[Aurora:" . $self->{name} . "] get_data initiated" ) if ( $self->{debug} );
    print "db: self->{token} [$self->{token}] self->{location} [$self->{location}]\n";

    #Check that we have data
    if ( ( !$self->{file} ) and ( -f $self->{config_file} ) and ( !defined $self->{location} ) ) {
        main::print_log( "[Aurora:" . $self->{name} . "] get file data" ) if ( $self->{debug} );
        ( $self->{location}, $self->{nl_deviceid}, $self->{token} ) = $self->get_config_data( $self->{nl_deviceid} );
    }
    if ( !defined $self->{location} ) {
        main::print_log( "[Aurora:" . $self->{name} . "] get ssdp data" ) if ( $self->{debug} );

        ( $self->{location}, $self->{nl_deviceid} ) = $self->get_ssdp_data( $self->{nl_deviceid} );

        #TODO            $self->update_config_data() if ($self->{location});
    }

    #Check for a token
    if ( ( !defined $self->{token} ) and ( defined $self->{location} ) ) {
        main::print_log( "[Aurora:" . $self->{name} . "] Location found ($self->{location})" );
        main::print_log( "[Aurora:" . $self->{name} . "] Please hold down power button to generate access token" );
        eval { ia7_notify( "[Aurora:" . $self->{name} . "] Please hold down power button to generate access token" ); };
        $self->get_auth();

        #if we have a location and token, then get some data
    }
    elsif ( $self->{token} and $self->{location} ) {
        $self->poll();

        if ( ( defined $self->{data}->{panels} ) and ( $self->{init} == 0 ) ) {
            main::print_log( "[Aurora:" . $self->{name} . "] " . $self->{module_version} . "Configuration Loaded" );
            $self->print_info();
            $self->{init} = 1;
        }
    }
    else {
        main::print_log( "[Aurora:" . $self->{name} . "] WARNING, Did not poll: location: $self->{location}, token: $self->{token}" ) if ( $self->{debug} );
    }
}

sub get_auth {
    my ($self) = @_;

    main::print_log( "[Aurora:" . $self->{name} . "] Sending Authentication request..." );
    $self->_get_JSON_data('auth');

    return ('1');
}

sub poll {
    my ($self) = @_;

    main::print_log( "[Aurora:" . $self->{name} . "] Background Polling initiated" ) if ( $self->{debug} );
    $self->_get_JSON_data('info');

    return ('1');
}

sub process_check {
    my ($self) = @_;

    return unless ( defined $self->{poll_process} );

    if ( $self->{poll_process}->done_now() ) {
        my $com_status = "online";
        main::print_log( "[Aurora:" . $self->{name} . "] Background poll " . $self->{poll_process_mode} . " process completed" ) if ( $self->{debug} );

        my $file_data = &main::file_read( $self->{poll_data_file} );

        return unless ($file_data);    #if there is no data, then don't process
        if ( $file_data =~ m/403 Forbidden/i ) {
            main::print_log( "[Aurora:" . $self->{name} . "] 403 Forbidden: Pair Button not pressed or auth token is incorrect" );
            return;
        }

        #for some reason get_url adds garbage to the output. Clean out the characters before and after the json
        print "debug: file_data=$file_data\n" if ( $self->{debug} );
        my ($json_data) = $file_data =~ /({.*})/;
        print "debug: json_data=$json_data\n" if ( $self->{debug} );
        unless ( ($file_data) and ($json_data) ) {
            main::print_log( "[Aurora:" . $self->{name} . "] ERROR! bad data returned by poll" );
            main::print_log( "[Aurora:" . $self->{name} . "] ERROR! file data is $file_data. json data is $json_data" );
            return;
        }
        my $data;
        eval { $data = JSON::XS->new->decode($json_data); };

        # catch crashes:
        if ($@) {
            main::print_log( "[Aurora:" . $self->{name} . "] ERROR! JSON file parser crashed! $@\n" );
            $com_status = "offline";
        }
        else {
            if ( keys $data ) {
                if ( $self->{poll_process_mode} eq "info" ) {

                    #{"name":"Nanoleaf Aurora","serialNo":"XXXXXXXX","manufacturer":"Nanoleaf","firmwareVersion":"1.4.39","model":"NL22","state":{"on":{"value":true},"brightness":{"value":100,"max":100,"min":0},"hue":{"value":255,"max":360,"min":0},"sat":{"value":68,"max":100,"min":0},"ct":{"value":4000,"max":100,"min":0},"colorMode":"effect"},"effects":{"select":"Fireplace","list":["Color Burst","Flames","Forest","Inner Peace","Nemo","Northern Lights","Romantic","Snowfall","Fireplace","Sunset"]},"panelLayout":{"layout":{"layoutData":"2 150 195 -74 129 -120 149 -74 43 -60"},"globalOrientation":{"value":294,"max":360,"min":0}
                    $self->{data}->{info} = $data;

                    #                    ($self->{data}->{panels}, $self->{data}->{panel_size}) = substr($data->{panelLayout}->{layout}->{layoutData},0,1);
                    my $layout;
                    ( $self->{data}->{panels}, $self->{data}->{panel_size}, $layout ) = $data->{panelLayout}->{layout}->{layoutData} =~ /^(\d+)\s+(\d+)\s+(.*)/;
                    my @panels = split / /, $layout;
                    for ( my $i = 0; $i < $self->{data}->{panels}; $i++ ) {
                        $self->{data}->{panel}->{ $panels[ $i * 4 ] }->{x} = $panels[ ( $i * 4 ) + 1 ];
                        $self->{data}->{panel}->{ $panels[ $i * 4 ] }->{y} = $panels[ ( $i * 4 ) + 2 ];
                        $self->{data}->{panel}->{ $panels[ $i * 4 ] }->{o} = $panels[ ( $i * 4 ) + 3 ];
                    }

                }
                elsif ( $self->{poll_process_mode} eq "auth" ) {
                    main::print_log( "[Aurora:" . $self->{name} . "] Authentication token found!" );
                    $self->{token} = $data->{auth_token};
                    main::print_log( "[Aurora:" . $self->{name} . "] Token $self->{token}" ) if ( $self->{debug} );

                    #TODO                    #$self->update_config_data();
                }
                $self->process_data();
            }
            else {
                main::print_log( "[Aurora:" . $self->{name} . "] ERROR! Returned data not structured! Not processing..." );
                $com_status = "offline";
            }
        }

        if ( scalar @{ $self->{poll_queue} } ) {
            my $cmd_string = shift @{ $self->{poll_queue} };
            my ( $mode, $cmd ) = split /\|/, $cmd_string;
            $self->{poll_process}->set($cmd);
            $self->{poll_process}->start();
            $self->{poll_process_pid}->{ $self->{poll_process}->pid() } = $mode;    #capture the type of information requested in order to parse;
            $self->{poll_process_mode} = $mode;
            main::print_log( "[Aurora:" . $self->{name} . "] Poll Queue " . $self->{poll_process}->pid() . " mode=$mode cmd=$cmd" )
              if ( $self->{debug} );

        }
        if ( defined $self->{child_object}->{comm} ) {
            if ( $self->{status} ne $com_status ) {
                main::print_log "[Aurora:"
                  . $self->{name}
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
        main::print_log( "[Aurora:" . $self->{name} . "] Background Command " . $self->{cmd_process_name} . " process completed" )
          if ( $self->{debug} );
        $self->get_data();    #poll since the command is done to get a new state

        my $file_data = &main::file_read( $self->{cmd_data_file} );
        unless ($file_data) {
            main::print_log( "[Aurora:" . $self->{name} . "] ERROR! no data returned by command" );
            return;
        }

        #for some reason get_url adds garbage to the output. Clean out the characters before and after the json
        print "debug: file_data=$file_data\n" if ( $self->{debug} );
        my ($json_data) = $file_data =~ /({.*})/;
        print "debug: json_data=$json_data\n" if ( $self->{debug} );
        my $data;
        eval { $data = JSON::XS->new->decode($json_data); };

        # catch crashes:
        if ($@) {
            main::print_log( "[Aurora:" . $self->{name} . "] ERROR! JSON file parser crashed! $@\n" );
            $com_status = "offline";

        }
        else {
            #TODO - what are the possible command return strings
            if ( keys $data ) {
                if ( $data->{success} eq "true" ) {
                    shift @{ $self->{cmd_queue} };    #remove the command from queue since it was successful
                    $self->{cmd_process_retry} = 0;
                    $self->poll;
                }
                else {
                    if ( defined $data->{reason} ) {
                        main::print_log( "[Aurora:" . $self->{name} . "] WARNING Issued command was unsuccessful (reason=" . $data->{reason} . ")" );
                        shift @{ $self->{cmd_queue} };
                    }
                    else {
                        main::print_log( "[Aurora:" . $self->{name} . "] WARNING Issued command was unsuccessful with no returned reason , retrying..." );
                        if ( $self->{cmd_process_retry} > $self->{cmd_process_retry_limit} ) {
                            main::print_log( "[Aurora:" . $self->{name} . "] ERROR Issued command max retries reached. Abandoning command attempt..." );
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
                print_log( "[Aurora:" . $self->{name} . "] ERROR! Returned data not structured! Not processing..." );
                $com_status = "offline";
            }
        }
        if ( scalar @{ $self->{cmd_queue} } ) {
            my $cmd = @{ $self->{cmd_queue} }[0];    #grab the first command, but don't take it off.
            $self->{cmd_process}->set($cmd);
            $self->{cmd_process}->start();
            main::print_log( "[Aurora:" . $self->{name} . "] Command Queue " . $self->{cmd_process}->pid() . " cmd=$cmd" )
              if ( ( $self->{debug} ) or ( $self->{cmd_process_retry} ) );
        }
        if ( defined $self->{child_object}->{comm} ) {
            if ( $self->{status} ne $com_status ) {
                main::print_log "[Aurora:"
                  . $self->{name}
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
    my ( $self, $mode, $params ) = @_;
    $params = $opts{$mode} unless defined($params);
    my $token = "";
    $token = "/" . $self->{token} if ( defined $self->{location} and lc $mode ne "auth" );
    my $cmd = "get_url $params " . '"' . $self->{location} . $api_path . "$token/$rest{$mode}" . '"';
    if ( $self->{poll_process}->done() ) {
        $self->{poll_process}->set($cmd);
        $self->{poll_process}->start();
        $self->{poll_process_pid}->{ $self->{poll_process}->pid() } = $mode;    #capture the type of information requested in order to parse;
        $self->{poll_process_mode} = $mode;
        main::print_log( "[Aurora:" . $self->{name} . "] Backgrounding " . $self->{poll_process}->pid() . " command $mode, $cmd" ) if ( $self->{debug} );
    }
    else {
        if ( scalar @{ $self->{poll_queue} } < $self->{max_poll_queue} ) {
            main::print_log( "[Aurora:" . $self->{name} . "] Queue is " . scalar @{ $self->{poll_queue} } . ". Queing command $mode, $cmd" )
              if ( $self->{debug} );
            push @{ $self->{poll_queue} }, "$mode|$cmd";
        }
        else {
            main::print_log( "[Aurora:" . $self->{name} . "] WARNING. Queue has grown past " . $self->{max_poll_queue} . ". Command discarded." );
            if ( defined $self->{child_object}->{comm} ) {
                if ( $self->{status} ne "offline" ) {
                    main::print_log "[Aurora:"
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

sub _push_JSON_data {
    my ( $self, $mode, $params ) = @_;
    $params = $opts{$mode} unless defined($params);
    unless ( defined $self->{token} ) {
        main::print_log( "[Aurora:" . $self->{name} . "] ERROR no authentication token for command!" );
        return;
    }

    my $cmd = "get_url $params" . ' "' . $self->{location} . $api_path . "/" . $self->{token} . "/$rest{$mode}" . '"';
    if ( $self->{cmd_process}->done() ) {
        $self->{cmd_process}->set($cmd);
        $self->{cmd_process}->start();
        $self->{cmd_process_pid}->{ $self->{cmd_process}->pid() } = $mode;    #capture the type of information requested in order to parse;
        $self->{cmd_process_mode} = $mode;
        main::print_log( "[Aurora:" . $self->{name} . "] Backgrounding " . $self->{cmd_process}->pid() . " command $mode, $cmd" ) if ( $self->{debug} );
    }
    else {
        if ( scalar @{ $self->{cmd_queue} } < $self->{max_cmd_queue} ) {
            main::print_log( "[Aurora:" . $self->{name} . "] Queue is " . scalar @{ $self->{cmd_queue} } . ". Queing command $mode, $cmd" )
              if ( $self->{debug} );
            push @{ $self->{cmd_queue} }, "$mode|$cmd";
        }
        else {
            main::print_log( "[Aurora:" . $self->{name} . "] WARNING. Queue has grown past " . $self->{max_cmd_queue} . ". Command discarded." );
            if ( defined $self->{child_object}->{comm} ) {
                if ( $self->{status} ne "offline" ) {
                    main::print_log "[Aurora:"
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

}

sub scan_ssdp_data {
    my ( $self, $timeout ) = @_;
    $timeout = 500 unless ($timeout);
    my $addr = '239.255.255.250';
    my $port = 1900;
    my $sock = new IO::Socket::INET->new(
        LocalPort => $port,
        Proto     => 'udp',
        Reuse     => 1
    ) || &main::print_log( "[Aurora:" . $self->{name} . "] ERROR:  SSDP Discovery, could not start a udp server on " . $port . $@ . "\n\n" ) && return;

    _mcast_add( $sock, '239.255.255.250' );
    setsockopt( $sock, getprotobyname('ip') || 0, _constant('IP_MULTICAST_TTL'), pack 'I', 4 );

    my $sel = new IO::Select;
    $sel->add($sock);

    my $q = <<EOT;
M-SEARCH * HTTP/1.1
HOST: 239.255.255.250:1900
MAN: "ssdp:discover"
ST: ssdp:all
MX: 0

EOT
    $q =~ s/\n/\r\n/g;

    my $dest = sockaddr_in( $port, inet_aton($addr) );
    send( $sock, $q, 0, $dest );

    my @dev_locs = ();
    my @dev_ids  = ();
    my $data;
    my $i;
    my $discovery = "Discovering >";
    while ( $i++ < $timeout ) {
        select undef, undef, undef, .1;

        my @ready = $sel->can_read(2);
        last unless scalar @ready;

        $sock->recv( $data, 4096 );
        $discovery .= "-";

        #print $data;

        if ( $data =~ m/ST: nanoleaf_aurora:light/ ) {

            #print "found" . $data;
            my ($location) = $data =~ /Location:\s+(.*)/;

            #print "location " . $location;
            $location =~ s/[^a-zA-Z0-9\:\.\/]*//g;
            push @dev_locs, $location;
            my ($devid) = $data =~ /nl\-deviceid:\s+(.*)/;

            #print "location " . $location;
            $devid =~ s/[^a-zA-Z0-9\:\.\/]*//g;
            push @dev_ids, $devid;

            &main::print_log( "[Aurora:" . $self->{name} . "] Found Aurora: $location, nl-deviceid: $devid" );

            #last;
        }
    }
    $discovery .= "< [" . scalar @dev_locs . "]\n";
    &main::print_log( "[Aurora:" . $self->{name} . "] $discovery" );
    return ( scalar @dev_locs, \@dev_locs, \@dev_ids );
}

sub _mcast_add {
    my ( $sock, $addr ) = @_;
    my $ip_mreq = inet_aton($addr) . INADDR_ANY;

    setsockopt( $sock, getprotobyname('ip') || 0, _constant('IP_ADD_MEMBERSHIP'), $ip_mreq ) || warn "Unable to add IGMP membership: $!\n";
}

sub _constant {
    my $name  = shift;
    my %names = (
        IP_MULTICAST_TTL  => 0,
        IP_ADD_MEMBERSHIP => 1,
        IP_MULTICAST_LOOP => 0,
    );

    my %constants = (
        MSWin32 => [ 10, 12 ],
        cygwin  => [ 3,  5 ],
        darwin  => [ 10, 12 ],
        linux   => [ 33, 35 ],
        default => [ 33, 35 ],
    );

    my $index = $names{$name};
    my $ref = $constants{$^O} || $constants{default};
    return $ref->[$index];
}

sub read_config_data {
    my ($self) = @_;

    my $file_data = &main::file_read( $self->{config_file} );
    unless ($file_data) {
        main::print_log( "[Aurora:" . $self->{name} . "] WARNING! Cannot read config file $self->{config_file}" );
        return;
    }

    my $data;
    eval { $data = JSON::XS->new->decode($file_data); };

    # catch crashes:
    if ($@) {
        main::print_log( "[Aurora:" . $self->{name} . "] ERROR! JSON file parser crashed when reading config file! $@\n" );
    }
    else {
        print Dumper $data if ( $self->{debug} );

        return $data;
    }
}

sub write_config_data {
    my ( $self, $data ) = @_;

    my $file_data;
    eval { $file_data = JSON::XS->new->encode($data); };

    # catch crashes:
    if ($@) {
        main::print_log( "[Aurora:" . $self->{name} . "] ERROR! JSON file parser crashed when creating config file! $@\n" );
    }
    else {
        print Dumper $file_data if ( $self->{debug} );
        &main::file_write( $self->{config_file}, $file_data );
    }

}

sub get_config_data {
    my ( $self, $id ) = @_;

    my $data = $self->read_config_data();

    if ($data) {
        my $nid = $self->{name};

        #override $nid if a $nl_device is specified
        if ( ( defined $id ) and ($id) ) {
            print "checking id=$id\n";
            foreach my $key ( keys %$data ) {
                if (   ( lc $self->{nl_deviceid} eq lc $data->{$key}->{device}->{nl_deviceid} )
                    or ( lc $self->{location} eq lc $data->{$key}->{device}->{location} )
                    or ( lc $self->{token} eq lc $data->{$key}->{device}->{token} ) )
                {
                    $nid = $key;
                    last;
                }
            }
        }
        $self->{file} = 1;
        print "nid=$nid, loc=$data->{$nid}->{device}->{location}\n";
        return ( $data->{$nid}->{device}->{location}, $data->{$nid}->{device}->{nl_deviceid}, $data->{$nid}->{device}->{token} );
    }
    else {
        return;
    }
}

sub update_config_data {
    my ($self) = @_;

    my $nid = $self->{name};
    my $data;
    $data = $self->read_config_data();

    #override $nid if a $nl_device is specified
    if ( defined $data ) {
        foreach my $key ( keys %$data ) {
            if (   ( lc $self->{nl_deviceid} eq lc $data->{$key}->{device}->{nl_deviceid} )
                or ( lc $self->{location} eq lc $data->{$key}->{device}->{location} )
                or ( lc $self->{token} eq lc $data->{$key}->{device}->{token} ) )
            {
                $nid = $key;
                last;
            }
        }
    }

    #TODO add static definitions

    if ( ( defined $self->{location} ) and ( $data->{$nid}->{device}->{location} ne $self->{location} ) ) {
        $data->{$nid}->{device}->{location} = $self->{location};
        main::print_log( "[Aurora:" . $self->{name} . "] Updating location ($self->{location}) in config file" );

    }
    if ( ( defined $self->{token} ) and ( $data->{$nid}->{device}->{token} ne $self->{token} ) ) {
        $data->{$nid}->{device}->{token} = $self->{token};
        main::print_log( "[Aurora:" . $self->{name} . "] Updating authentication token in config file" );

    }
    if ( ( defined $self->{nl_device} ) and ( $data->{$nid}->{device}->{nl_device} ne $self->{nl_device} ) and ( $self->{nl_device} ) ) {
        $data->{$nid}->{device}->{nl_device} = $self->{nl_device};
        main::print_log( "[Aurora:" . $self->{name} . "] Updating nl-device ($self->{nl_device} ) in config file" );
    }
    $self->write_config_data($data);
}

sub register {
    my ( $self, $object, $type ) = @_;

    #my $name;
    #$name = $$object{object_name};  #TODO: Why can't we get the name of the child object?
    &main::print_log( "[Aurora:" . $self->{name} . "] Registering $type child object" );
    $self->{child_object}->{$type} = $object;

}

sub stop_timer {
    my ($self) = @_;

    if ( defined $self->{timer} ) {
        $self->{timer}->stop() if ( $self->{timer}->active() );
    }
    else {
        main::print_log( "[Aurora:" . $self->{name} . "] Warning, stop_timer called but timer undefined" );
    }
}

sub print_info {
    my ($self) = @_;

    #{"name":"Nanoleaf Aurora",
    #"serialNo":"XXXXXXXXXXX",
    #"manufacturer":"Nanoleaf",
    #"firmwareVersion":"1.4.39",
    #"model":"NL22",
    #"state":{"on":{"value":true},
    #"brightness":{"value":100,"max":100,"min":0},
    #"hue":{"value":255,"max":360,"min":0},
    #"sat":{"value":68,"max":100,"min":0},
    #"ct":{"value":4000,"max":100,"min":0},
    #"colorMode":"effect"},
    #"effects":{"select":"Fireplace","list":["Color Burst","Flames","Forest","Inner Peace","Nemo","Northern Lights","Romantic","Snowfall","Fireplace","Sunset"]},
    #"panelLayout":{"layout":{"layoutData":"2 150 195 -74 129 -120 149 -74 43 -60"},
    #"globalOrientation":{"value":294,"max":360,"min":0}}}

    main::print_log( "[Aurora:" . $self->{name} . "] Name:             " . $self->{data}->{info}->{name} );
    main::print_log( "[Aurora:" . $self->{name} . "] Serial Number:    " . $self->{data}->{info}->{serialNo} );
    main::print_log( "[Aurora:" . $self->{name} . "] Manufacturer:     " . $self->{data}->{info}->{manufacturer} );
    main::print_log( "[Aurora:" . $self->{name} . "] Model:            " . $self->{data}->{info}->{model} );
    main::print_log( "[Aurora:" . $self->{name} . "] Firmware:         " . $self->{data}->{info}->{firmwareVersion} );
    main::print_log( "[Aurora:" . $self->{name} . "] Connected Panels: " . $self->{data}->{panels} );
    main::print_log( "[Aurora:" . $self->{name} . "] Panel Size:       " . $self->{data}->{panel_size} );

    main::print_log( "[Aurora:" . $self->{name} . "] -- Current Settings --" );

    if ( $self->{data}->{info}->{state}->{on}->{value} ) {
        main::print_log( "[Aurora:" . $self->{name} . "]    State:\t  ON" );
    }
    else {
        main::print_log( "[Aurora:" . $self->{name} . "]    State:\t  OFF" );
    }
    main::print_log(
        "[Aurora:" . $self->{name} . "]    Mode:\t  " . $self->{data}->{info}->{state}->{colorMode} . " " . $self->{data}->{info}->{effects}->{select} );
    main::print_log( "[Aurora:"
          . $self->{name}
          . "]    Brightness:\t  "
          . $self->{data}->{info}->{state}->{brightness}->{value} . "\t["
          . $self->{data}->{info}->{state}->{brightness}->{min} . "-"
          . $self->{data}->{info}->{state}->{brightness}->{max}
          . "]" );
    main::print_log( "[Aurora:"
          . $self->{name}
          . "]    Hue:\t\t  "
          . $self->{data}->{info}->{state}->{hue}->{value} . "\t["
          . $self->{data}->{info}->{state}->{hue}->{min} . "-"
          . $self->{data}->{info}->{state}->{hue}->{max}
          . "]" );
    main::print_log( "[Aurora:"
          . $self->{name}
          . "]    Saturation:\t  "
          . $self->{data}->{info}->{state}->{sat}->{value} . "\t["
          . $self->{data}->{info}->{state}->{sat}->{min} . "-"
          . $self->{data}->{info}->{state}->{sat}->{max}
          . "]" );
    main::print_log( "[Aurora:"
          . $self->{name}
          . "]    Color Temp:\t  "
          . $self->{data}->{info}->{state}->{brightness}->{value} . "\t["
          . $self->{data}->{info}->{state}->{brightness}->{min} . "-"
          . $self->{data}->{info}->{state}->{brightness}->{max}
          . "]" );
    main::print_log( "[Aurora:" . $self->{name} . "] -- Active Effects --" );
    foreach my $effect ( @{ $self->{data}->{info}->{effects}->{list} } ) {
        main::print_log( "[Aurora:" . $self->{name} . "]   - $effect" );
    }
    main::print_log( "[Aurora:" . $self->{name} . "] -- Layout --" );
    main::print_log( "[Aurora:"
          . $self->{name}
          . "]    Orientation:\t  "
          . $self->{data}->{info}->{panelLayout}->{globalOrientation}->{value} . "\t["
          . $self->{data}->{info}->{panelLayout}->{globalOrientation}->{min} . "-"
          . $self->{data}->{info}->{panelLayout}->{globalOrientation}->{max}
          . "]" );
    foreach my $key ( sort( keys %{ $self->{data}->{panel} } ) ) {
        main::print_log( "[Aurora:"
              . $self->{name}
              . "]    ID: "
              . $key . "\tx:"
              . $self->{data}->{panel}->{$key}->{x} . "\ty:"
              . $self->{data}->{panel}->{$key}->{y} . "\to:"
              . $self->{data}->{panel}->{$key}->{o} );
    }
}

sub process_data {
    my ($self) = @_;

    my (%state);
    $state{true}  = "on";
    $state{false} = "off";

    # Main core of processing
    # set state of self for state
    # for any registered child selfs, update their state if

    main::print_log( "[Aurora:" . $self->{name} . "] Processing Data..." ) if ( $self->{debug} );

    if ( ( !$self->{init_data} ) and ( defined $self->{data}->{info} ) ) {
        main::print_log( "[Aurora:" . $self->{name} . "] Init: Setting startup values" );

        foreach my $key ( keys $self->{data}->{info} ) {
            $self->{previous}->{info}->{$key} = $self->{data}->{info}->{$key};
        }
        $self->{previous}->{panels} = $self->{data}->{panels};
        @{ $self->{previous}->{effects}->{list} } = @{ $self->{data}->{info}->{effects}->{list} };
        if ( defined $self->{child_object}->{effects} ) {
            $self->{child_object}->{effects}->load_effects( @{ $self->{data}->{info}->{effects}->{list} } );
            $self->{child_object}->{effects}->set( $self->{data}->{info}->{effects}->{select}, 'poll' );
        }

        $self->set( $state{ $self->{data}->{info}->{state}->{on}->{value} }, 'poll' );
        $self->{init_data} = 1;
    }

    #print Dumper $self->{data};

    #{"name":"Nanoleaf Aurora",
    #"serialNo":"XXXXXXXXXXX",
    #"manufacturer":"Nanoleaf",
    #"firmwareVersion":"1.4.39",
    #"model":"NL22",
    #"state":{"on":{"value":true},
    #"brightness":{"value":100,"max":100,"min":0},
    #"hue":{"value":255,"max":360,"min":0},
    #"sat":{"value":68,"max":100,"min":0},
    #"ct":{"value":4000,"max":100,"min":0},
    #"colorMode":"effect"},
    #"effects":{"select":"Fireplace","list":["Color Burst","Flames","Forest","Inner Peace","Nemo","Northern Lights","Romantic","Snowfall","Fireplace","Sunset"]},
    #"panelLayout":{"layout":{"layoutData":"2 150 195 -74 129 -120 149 -74 43 -60"},
    #"globalOrientation":{"value":294,"max":360,"min":0}}}

    if ( $self->{previous}->{info}->{firmwareVersion} ne $self->{data}->{info}->{firmwareVersion} ) {
        main::print_log(
            "[Aurora:" . $self->{name} . "] Firmware changed from $self->{previous}->{info}->{firmwareVersion} to $self->{data}->{info}->{firmwareVersion}" );
        main::print_log( "[Aurora:" . $self->{name} . "] This really isn't a regular operation. Should check Aurora to confirm" );
        $self->{previous}->{info}->{firmwareVersion} = $self->{data}->{info}->{firmwareVersion};
    }

    if ( $self->{previous}->{info}->{name} ne $self->{data}->{info}->{name} ) {
        main::print_log( "[Aurora:" . $self->{name} . "] Device Name changed from $self->{previous}->{info}->{name} to $self->{data}->{info}->{name}" );
        main::print_log( "[Aurora:" . $self->{name} . "] This really isn't a regular operation. Should check Aurora to confirm" );
        $self->{previous}->{info}->{name} = $self->{data}->{info}->{name};
    }

    if ( $self->{previous}->{panels} != $self->{data}->{panels} ) {
        main::print_log( "[Aurora:" . $self->{name} . "] Number of panels has changed from $self->{previous}->{panels} to $self->{data}->{panels}" );
        my $panel_added   = "";
        my $panel_removed = "";
        foreach my $key ( sort( keys %{ $self->{data}->{panel} } ) ) {
            $panel_added .= $key unless ( defined $self->{previous}->{panel}->{$key} );
        }
        foreach my $key ( sort( keys %{ $self->{previous}->{panel} } ) ) {
            $panel_removed .= $key unless ( defined $self->{data}->{panel}->{$key} );
        }
        main::print_log( "[Aurora:" . $self->{name} . "] Panel ID(s) added: $panel_added" )     if ($panel_added);
        main::print_log( "[Aurora:" . $self->{name} . "] Panel ID(s) removed: $panel_removed" ) if ($panel_removed);
        $self->{previous}->{panels} = $self->{data}->{panels};
        $self->{previous}->{panel}  = $self->{data}->{panel};
    }

    if ( $self->{previous}->{info}->{state}->{on}->{value} != $self->{data}->{info}->{state}->{on}->{value} ) {
        main::print_log( "[Aurora:"
              . $self->{name}
              . "] State changed from $state{$self->{previous}->{info}->{state}->{on}->{value}} to $state{$self->{data}->{info}->{state}->{on}->{value}}" )
          if ( $self->{loglevel} );
        $self->{previous}->{info}->{state}->{on}->{value} = $self->{data}->{info}->{state}->{on}->{value};

        #if on and brightness not 100 set brightness else set on or off
        if ( ( $self->{data}->{info}->{state}->{on}->{value} ) and ( $self->{data}->{info}->{state}->{brightness}->{value} != 100 ) ) {
            $self->set( $self->{data}->{info}->{state}->{brightness}->{value}, 'poll' );
        }
        else {
            $self->set( $state{ $self->{data}->{info}->{state}->{on}->{value} }, 'poll' );
        }
    }

    if ( $self->{previous}->{info}->{state}->{brightness}->{value} != $self->{data}->{info}->{state}->{brightness}->{value} ) {
        main::print_log( "[Aurora:"
              . $self->{name}
              . "] Brightness changed from $state{$self->{previous}->{info}->{state}->{brightness}->{value}} to $state{$self->{data}->{info}->{state}->{brightness}->{value}}"
        ) if ( $self->{loglevel} );
        $self->{previous}->{info}->{state}->{brightness}->{value} = $self->{data}->{info}->{state}->{brightness}->{value};
        $self->set( $self->{data}->{info}->{state}->{brightness}->{value}, 'poll' );
    }

    if ( $self->{previous}->{info}->{state}->{colorMode} ne $self->{data}->{info}->{state}->{colorMode} ) {
        main::print_log( "[Aurora:"
              . $self->{name}
              . "] State ColorMode changed from $self->{previous}->{info}->{state}->{colorMode} to $self->{data}->{info}->{state}->{colorMode}" )
          if ( $self->{loglevel} );
        $self->{previous}->{info}->{state}->{colorMode} = $self->{data}->{info}->{state}->{colorMode};
    }

    if ( $self->{previous}->{info}->{effects}->{select} ne $self->{data}->{info}->{effects}->{select} ) {
        main::print_log( "[Aurora:"
              . $self->{name}
              . "] Selected Effect changed from $self->{previous}->{info}->{effects}->{select} to $self->{data}->{info}->{effects}->{select}" )
          if ( $self->{loglevel} );
        $self->{previous}->{info}->{effects}->{select} = $self->{data}->{info}->{effects}->{select};
        if ( defined $self->{child_object}->{effects} ) {
            main::print_log "[Aurora:" . $self->{name} . "] Effects Child object found. Updating..." if ( $self->{loglevel} );
            $self->{child_object}->{effects}->set( $self->{data}->{info}->{effects}->{select}, 'poll' );
        }
    }

}

#------------
# User access methods

sub get_effect {
    my ($self) = @_;

    return ( $self->{data}->{info}->{effects}->{select} );

}

sub check_panelid {
    my ( $self, $id ) = @_;

    my $found = 0;
    $found = 1 if ( defined $self->{data}->{panel}->{$id} );

    return $found;
}

sub get_debug {
    my ($self) = @_;
    return $self->{debug};
}

sub set {
    my ( $self, $p_state, $p_setby ) = @_;

    if ( $p_setby eq 'poll' ) {
        $p_state .= "%" if ( $p_state =~ m/\d+(?!%)/ );
        main::print_log( "[Aurora:" . $self->{name} . "] DB super::set, in master set, p_state=$p_state, p_setby=$p_setby" ) if ( $self->{debug} );
        $self->SUPER::set($p_state);
        $self->start_timer;

    }
    else {
        main::print_log( "[Aurora:" . $self->{name} . "] DB set_mode, in master set, p_state=$p_state, p_setby=$p_setby" ) if ( $self->{debug} );
        my $mode = lc $p_state;
        if ( ( $mode eq "on" ) or ( $mode eq "off" ) ) {
            $self->_push_JSON_data($mode);
        }
        elsif ( $mode =~ /^(\d+)/ ) {
            my $params = $opts{brightness} . $1 . '}' . "'";
            $self->_push_JSON_data( 'brightness', $params );
        }
        elsif ( $mode =~ /^([-+]\d+)/ ) {
            my $params = $opts{brightness2} . $1 . '}' . "'";
            $self->_push_JSON_data( 'brightness2', $params );
        }
        else {
            main::print_log( "Aurora:" . $self->{name} . "] Error, unknown set state $p_state" );
            return ('0');
        }
        return ('1');
    }
}

sub set_effect {
    my ( $self, $effect ) = @_;

    my $params = $opts{set_effect} . '"' . $effect . '"}' . "'";
    $self->_push_JSON_data( 'set_effect', $params );
    return ('1');
}

sub set_static {
    my ( $self, $string, $loop ) = @_;

    my $jloop = "false";
    $jloop = "true" if ($loop);
    my $params = $opts{set_static} . '"' . $string . '","loop":' . $jloop . "}}'";
    $self->_push_JSON_data( 'set_static', $params );
    return ('1');
}

package Nanoleaf_Aurora_Effects;

@Nanoleaf_Aurora_Effects::ISA = ('Generic_Item');

sub new {
    my ( $class, $object ) = @_;

    my $self = {};
    bless $self, $class;

    $$self{master_object} = $object;

    $object->register( $self, 'effects' );
    return $self;

}

sub set {
    my ( $self, $p_state, $p_setby ) = @_;

    if ( $p_setby eq 'poll' ) {
        $self->SUPER::set($p_state);
    }
    else {
        my $found = 0;
        foreach my $eff ( @{ $$self{states} } ) {
            $found = 1 if ( $p_state eq $eff );
        }
        if ($found) {
            $$self{master_object}->set_effect($p_state);
        }
        else {
            main::print_log("[Aurora Effect] Error. Unknown effect state $p_state");
        }
    }
}

sub load_effects {
    my ( $self, @effect_states ) = @_;

    @{ $$self{states} } = @effect_states;
}

package Nanoleaf_Aurora_Static;

@Nanoleaf_Aurora_Static::ISA = ('Generic_Item');

sub new {
    my ( $class, $object, $static_string ) = @_;

    my $self = {};
    bless $self, $class;
    @{ $$self{states} } = ( 'on', 'off' );

    $$self{master_object} = $object;
    $$self{loop}          = 0;
    $$self{static_string} = $static_string if ( defined $static_string );
    $object->register( $self, 'static' );
    return $self;

}

sub set {
    my ( $self, $p_state, $p_setby ) = @_;

    if ( $p_setby eq 'poll' ) {
        $self->SUPER::set($p_state);
    }
    else {
        #if ON then backup current configuration and set the new one.
        #if OFF then check if current is same as static, and if so restore the old one.
        if ( defined $$self{static_string} ) {
            $$self{master_object}->set_static( $$self{static_string}, $$self{loop} );
        }
    }
}

sub configure {
    my ( $self, $pid, $frames, $frame, $r, $g, $b, $w, $t ) = @_;
    if ( $$self{master_object}->check_panelid($pid) ) {
        $$self{data}{$pid}{frames} = $frames;
        $$self{data}{$pid}{$frame} = "$r $g $b $w $t";
    }
    else {
        main::print_log("[Aurora Static] Error. Unknown panel ID $pid");
    }
}

sub loop {
    my ( $self, $value ) = @_;

    if ( defined $value ) {
        if ($value) {
            $$self{loop} = 1;
        }
        else {
            $$self{loop} = 0;
        }
    }
    else {
        return $$self{loop};
    }
}

package Nanoleaf_Aurora_Comm;

@Nanoleaf_Aurora_Comm::ISA = ('Generic_Item');

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
