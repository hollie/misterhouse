use strict;
use warnings;
use Device::SerialPort;
use Time::HiRes;
use experimental 'smartmatch';
use Group;
use Process_Item;
use IO::Socket::INET;
use IO::Select;

package PLCBUS;
use 5.12.0;

@PLCBUS::ISA = qw( Class::Singleton );

use Data::Dumper qw(Dumper);
use List::Util qw(sum first);
my %cmd_to_hex = (
    ##  + = needs feedback
    all_unit_off => {
        cmd               => 0x00,
        flags             => 0x00,
        data              => 0,
        noreplay          => 1,
        description       => "In Same HOME, “All Units Off”.",
        home_cmd          => 1,
        expected_response => undef,
    },
    all_lts_on => {
        cmd               => 0x01,
        flags             => 0x00,
        data              => 0,
        noreplay          => 1,
        description       => "In Same HOME, “All Lights On”.",
        home_cmd          => 1,
        expected_response => undef,
    },
    on => {
        cmd               => 0x02,
        flags             => 0x20,
        data              => 0,
        expected_response => ['status_on'],
        description       => "In Same HOME & UNIT, “One UNIT On”.  +",
    },
    off => {
        cmd               => 0x03,
        flags             => 0x20,
        data              => 0,
        expected_response => ['status_off'],
        description       => "In Same HOME & UNIT, ”One UNIT Off”. +",
    },
    dim => {
        cmd               => 0x04,
        flags             => 0x20,
        data              => 1,
        description       => "In Same HOME & UNIT, ”One UNIT Dim”. *+",
        expected_response => undef,
    },
    bright => {
        cmd               => 0x05,
        flags             => 0x20,
        data              => 1,
        description       => "In Same HOME & UNIT, ”One UNIT Brighten” *+",
        expected_response => undef,
    },
    all_light_off => {
        cmd               => 0x06,
        flags             => 0x00,
        data              => 0,
        noreplay          => 1,
        description       => "In Same HOME, “All Lights Off”.",
        home_cmd          => 1,
        expected_response => undef,
    },
    all_user_lts_on => {
        cmd               => 0x07,
        flags             => 0x00,
        data              => 0,
        noreplay          => 1,
        description       => "Under Same USER, “All USER Lights On”.",
        user_cmd          => 1,
        expected_response => undef,
    },
    all_user_unit_off => {
        cmd               => 0x08,
        flags             => 0x00,
        data              => 0,
        noreplay          => 1,
        description       => "Under Same USER, “All USER Units Off”.",
        user_cmd          => 1,
        expected_response => undef,
    },
    all_user_light_off => {
        cmd               => 0x09,
        flags             => 0x00,
        data              => 0,
        noreplay          => 1,
        description       => "Under Same USER, “All USER Lights Off”",
        user_cmd          => 1,
        expected_response => undef,
    },
    blink => {
        cmd               => 0x0A,
        flags             => 0x20,
        data              => 1,
        description       => "In Same HOME & UNIT, “One Light Blink”. *+",
        expected_response => undef,
    },
    fade_stop => {
        cmd         => 0x0B,
        flags       => 0x20,
        data        => 0,
        description => "In Same HOME & UNIT, “One light Stop Dimming”. +",
        expected_response => undef,
    },
    presetdim => {
        cmd         => 0x0C,
        flags       => 0x20,
        data        => 1,
        description => "In Same HOME & UNIT, “Preset Brightness Level”. *+",
        expected_response => undef,
    },
    status_on => {
        cmd               => 0x0D,
        flags             => 0x00,
        data              => 1,
        description       => "Status feedback as “ON”.*",
        expected_response => undef,
    },
    status_off => {
        cmd               => 0x0E,
        flags             => 0x00,
        data              => 0,
        description       => "Status feedback as “OFF”.",
        expected_response => undef,
    },
    status_req => {
        cmd               => 0x0F,
        flags             => 0x00,
        data              => 0,
        expected_response => [ 'status_on', 'status_off' ],
        description       => "Status Checking"
    },
    r_master_addrs_setup => {

        # ??????
        cmd               => 0x10,
        flags             => 0x20,
        data              => 1,
        description       => "Setup the main addre ss of Receiver. *+",
        expected_response => undef,
    },
    t_master_addrs_setup => {

        # ??????
        cmd               => 0x11,
        flags             => 0x20,
        data              => 1,
        description       => "Setup the main addr ess of Transmitter. *+",
        expected_response => undef,
    },
    scenes_addrs_setup => {
        cmd               => 0x12,
        flags             => 0x00,
        data              => 1,
        description       => "Setup Scene address *",
        expected_response => undef,
    },
    scenes_addrs_erase => {
        cmd               => 0x13,
        flags             => 0x00,
        data              => 0,
        description       => "Clean Scene address under the same HOME & UNIT",
        expected_response => undef,
    },
    all_scenes_addrs_erase => {
        cmd         => 0x14,
        flags       => 0x20,
        data        => 1,
        description => "Clean all the Scene a ddresses in each receiver. *+",
        expected_response => undef,
    },
    future1 => {
        cmd               => 0x15,
        flags             => 0x00,
        data              => 1,
        description       => "* for future",
        expected_response => undef,
    },
    future2 => {
        cmd               => 0x16,
        flags             => 0x00,
        data              => 1,
        description       => "* for future",
        expected_response => undef,
    },
    future3 => {
        cmd               => 0x17,
        flags             => 0x00,
        data              => 1,
        description       => "* for future",
        expected_response => undef,
    },
    get_signal_strength => {
        cmd               => 0x18,
        flags             => 0x20,
        data              => 0,
        description       => "Check the Signal Stre ngth. +",
        expected_response => ['report_signal_strength'],
    },
    get_noise_strength => {
        cmd               => 0x19,
        flags             => 0x20,
        data              => 0,
        description       => "Check the Noise Strength.   +",
        expected_response => ['report_noise_strength'],
    },
    report_signal_strength => {
        cmd               => 0x1A,
        flags             => 0x00,
        data              => 1,
        description       => "Report the Signal Stren gth. *",
        expected_response => undef,
    },
    report_noise_strength => {
        cmd               => 0x1B,
        flags             => 0x00,
        data              => 1,
        description       => "Report the Noise Str ength. *",
        expected_response => undef,
    },
    get_all_id_pulse => {
        cmd   => 0x1C,
        flags => 0x00,
        data  => 0,
        description =>
          "(THE SAME USER AND THE SAME HOME) Check the ID PULSE in the same USER & HOME.",
        expected_response => ['report_all_id_pulse'],
        home_cmd          => 1,
        noreplay          => 1,
    },
    get_only_on_id_pulse => {
        cmd               => 0x1D,
        flags             => 0x00,
        data              => 0,
        expected_response => ['report_only_on_pulse'],
        home_cmd          => 1,
        description =>
          "(THE SAME USER AND THE SAME HOME) Check the Only ON ID PULSE in the same USER & HOME."
    },
    report_all_id_pulse => {
        cmd               => 0x1E,
        flags             => 0x00,
        data              => 1,
        description       => "（ For 3-phase power line only ）",
        expected_response => undef,
    },
    report_only_on_pulse => {
        cmd               => 0x1F,
        flags             => 0x00,
        data              => 1,
        description       => "（ For 3-phase power line only ）",
        expected_response => undef,
    },
);

my %hex_to_cmd = (
    ##  * = contains data
    ##  + = needs feedback

    0x00 => "all_unit_off",    #  In Same HOME, “All Units Off”.
    0x01 => "all_lts_on",      #  In Same HOME, “All Lights On”.
    0x02 => "on",              #  In Same HOME +UNIT, “One UNIT On”.  +
    0x03 => "off",             #  In Same HOME + UNIT,”One UNIT Off”. +
    0x04 => "dim",             #  In Same HOME + UNIT,”One UNIT Dim”. *+
    0x05 => "bright",          #  In Same HOME + UNIT,”One UNIT Brighten” *+
    0x06 => "all_light_off",   #  In Same HOME, “All Lights Off”.
    0x07 => "all_user_lts_on", #  Under Same USER, “All USER Lights On”.
    0x08 => "all_user_unit_off",   #  Under Same USER, “All USER Units Off”.
    0x09 => "all_user_light_off",  #  Under Same USER, “All USER Lights Off”
    0x0A => "blink",     #  In Same HOME+ UNIT, “One Light Blink”. *+
    0x0B => "fade_stop", #  In Same HOME+ UNIT, “One light Stop Dimming”. +
    0x0C => "presetdim", #  In Same HOME+UNIT, “Preset Brightness Level”. *+
    0x0D => "status_on", #  Status feedback as “ON”.*
    0x0E => "status_off",           #  Status feedback as “OFF”.
    0x0F => "status_req",           #  Status Checking
    0x10 => "r_master_addrs_setup", #  Setup the main address of Receiver. *+
    0x11 => "t_master_addrs_setup", #  Setup the main address of Transmitter. *+
    0x12 => "scenes_addrs_setup",   #  Setup Scene address *
    0x13 => "scenes_addrs_erase"
    ,    #  Clean    Scene    address    under the    same HOME+UNIT
    0x14 => "all_scenes_addrs_erase"
    ,    #  Clean all the Scene addresses in each receiver. *+
    0x15 => "",                          #  * for future
    0x16 => "",                          #  * for future
    0x17 => "",                          #  * for future
    0x18 => "get_signal_strength",       #  Check the Signal Strength. +
    0x19 => "get_noise_strength",        #  Check the Noise Strength.   +
    0x1A => "report_signal_strength",    #  Report the Signal Strength. *
    0x1B => "report_noise_strength",     #  Report the Noise Strength. *
    0x1C => "get_all_id_pulse"
    , #  (THE SAME USER AND THE SAME HOM E) Check the ID PULSE in the same USER + HOME.
    0x1D => "get_only_on_id_pulse"
    , #  (THE SAME USER AND THE SAME HOME) Check the Only ON ID PULSE in the same USER+ HOME.
    0x1E => "report_all_id_pulse",     #  （ For 3-phase power line only ）
    0x1F => "report_only_on_pulse",    #  （ For 3-phase power line only ）
);

## NOTES
# 3-Phase coupler has no Address
# Pc2Plcbus interface has no address
#   * homeVisu sends blink command to usercode 0 home A unit 0 to check for echo on the BUS
#     no unit will react to this command.
#     if the echo is seen => 1141 is plugged in (should I do this too?)
#
# to learn phase the coupler our user code:
#   * phase coupler will not repeat commands with unknown user code
#   * press coupler button 5s => LED off
#   * send any command => LED off => user code learned.
#
# on/off
#   In 3-Phase 'on', 'off' get seperate reply 'status_on/off',
#   in 1-Phase only the on/off is with R_ACK_SW flag set is received
#
# get_only_on_id_pulse
#   3-Phase answer is 'report_only_on_pulse'
#   1-Phase answer is 'get_only_on_id_pulse' with only R_SW flag
#
#
# LINK: if set 1 means target adress is scene address (adress of linked devices) (Link Packet)
#       if 0 means direct packet towards 1 Module (Direct Packet)
#
# ????
#   * how to display current brightness level in ia7 Button
#   * how to display set phase mode for device?
########

sub __log {
    my ( $msg, $global_log, $loglevel ) = @_;
    &main::print_log("PLC: $msg") if $global_log;

    my $logfile = "$main::config_parms{data_dir}/logs/plcbus.log";
    &::logit( $logfile, "$loglevel: $msg" ) if $::config_parms{plcbus_logfile};
}

sub _log {
    __log( "@_", 1, "I" );
}

sub _logw {
    __log( "@_", 1, "W" );
}

sub _logd {
    __log( "@_", $::Debug{plcbus}, "V" );
}

sub _logdd {
    my $mh_log = ( $::Debug{plcbus} && $::Debug{plcbus} > 1 );
    __log( "@_", $mh_log, "D" );
}

sub _logddd {
    my $mh_log = ( $::Debug{plcbus} && $::Debug{plcbus} > 2 );
    __log( "@_", $mh_log, "T" );
}

sub bin_rep($) {
    return sprintf( "%08b", shift );
}

sub hex_rep($) {
    return sprintf( "%02x", shift );
}

sub _new_instance {
    my ($class) = @_;
    my $self = bless {}, $class;
    if ( $::Debug{plcbus} ) {
        _log("debug log: $::Debug{plcbus}");
    }
    else {
        _log("plcbus debug logging disabled.");
    }
    my $serial = $::config_parms{plcbus_serial_port};
    die("plcbus interface missing. Set 'plcbus_serial_port' in mh.private.ini")
      unless $serial;

    $self->{last_data_to_from_bus} = [ Time::HiRes::gettimeofday() ];

    $self->{current_cmd}   = undef;    ## currrent active command
    $self->{command_queue} = [];       ## qued commands
    $self->{plc_devices} =
      ();    # stores a hash of homes. Each home hold a hash of plcbus modules
    $self->{homes} = ()
      ; # only used for code generation so we know which home commands have alreay been created
    $self->{plcbussrv_proc} =
      new Process_Item();    # to start/stop the plcbussrv server
    $self->{plcbussrv_port} = $::config_parms{plcbussrv_port} || 4567;

    my $plcbusserv_log = "/dev/null";
    $plcbusserv_log = $::config_parms{plcbussrv_logfile}
      if $::config_parms{plcbussrv_logfile};
    my $c =
      "plcbussrv /dev/plcbus $self->{plcbussrv_port} &>1 > $plcbusserv_log";
    _log($c);
    $self->{plcbussrv_proc}->set($c);
    $self->{plcbussrv_proc}->start();
    $self->_connect_command_server();

    &::MainLoop_pre_add_hook( \&_handle_commands, 'persistent', $self );
    &::Exit_add_hook( \&_on_exit, 'persistent', $self );

    _logd("Manager created.");
    return $self;
}

sub _connect_command_server() {
    my ($self) = @_;
    $self->{plcbussrv_connection} = new IO::Socket::INET(
        PeerHost => 'localhost',
        PeerPort => $self->{plcbussrv_port},
        Proto    => 'tcp',
        Timeout  => 2000,
    );    #or die "could not connect to plcbussrv_connection.pl";
    if ( $self->{plcbussrv_connection} ) {
        $self->{plcbussrv_connection}->blocking(0);
        $self->{select} = IO::Select->new( $self->{plcbussrv_connection} );
    }
}

sub _on_exit() {
    my ($self) = @_;
    if ( $self->{plcbussrv_connection} ) {
        $self->{plcbussrv_connection}->close();
        $self->{plcbussrv_connection} = undef;
        _log("closed connection to commandserver");
    }
    _log("stopping server");
    $self->{plcbussrv_proc}->stop();
    _log("commandserver stopped");
    $self->{current_cmd} = undef;
    _log("Exiting...");
}

sub _get_user_code() {
    my ($self) = @_;
    if ( !$::config_parms{plcbus_user_code} ) {
        _logd("'plcbus_user_code' not set falling back to default '0xff'");
        return 0xff;
    }
    else {
        return hex( $::config_parms{plcbus_user_code} );
    }
}

sub add_device($) {
    my ( $self, $dev ) = @_;
    my $home = $dev->{home};
    my $unit = $dev->{unit};
    $self->{plc_devices}{$home}{$unit} = $dev;
    _logd("$home$unit $dev->{name} added to devicelist");
}

sub _handle_commands () {
    my ($self) = @_;
    $self->_check_external_plcbus_command_file();

    #$self->_queue_maintainance_commands();
    while ( $self->_handle_incoming_commands() ) { }
    return unless $self->_can_transmit();

    $self->{current_cmd} = shift @{ $self->{command_queue} };

    #_logddd("sending: ". Dumper($self->{current_cmd}));
    $self->_write_current_command();
    $self->_log_waiting_commands();
}

sub _queue_maintainance_commands() {
    my ($self) = @_;
    return unless ( &::new_minute(5) );
    for my $home ( keys %{ $self->{plc_devices} } ) {
        _logdd("Doing maintainance for '$home'");
        $self->_check_for_on_units_in_home($home);
    }
}

sub _check_for_on_units_in_home($) {
    my ( $self, $home ) = @_;
    my $cmd = "get_only_on_id_pulse";
    $self->queue_command( { home => $home, unit => 0, cmd => $cmd } );
}

sub _handle_incoming_commands {
    my ($self) = @_;
    return 0 unless my @raw = $self->_read_packet();
    return 0 unless my $dec = $self->_decode_incoming(@raw);

    #_log(Dumper($dec));

    my $home = $dec->{home};
    my $unit = $dec->{unit};
    my $cmd  = $dec->{cmd};
    my $rxtx = $dec->{rxtx};

    if ( defined( $self->{current_cmd} ) ) {
        $dec->{setby}   = $self->{current_cmd}->{setby};
        $dec->{respond} = $self->{current_cmd}->{respond};
        if ( $rxtx->{R_ITSELF} ) {
            $self->{current_cmd}->{echo_seen} = 1;

            # _logd("Received myself on PLCBUS.");
            return 1;
        }
        if (   $self->{current_cmd}->{three_phase}
            && !$dec->{REPRQ}
            && !$rxtx->{R_ITSELF} )
        {
            $self->{current_cmd}->{replay_seen} = 1;

            #_logd("Received replay from PLCBUS phase coupler.");
        }
        if (   $self->{current_cmd}->{waits_for_ack}
            && $dec->{ACK_PULSE}
            && !$dec->{R_ACK_SW}
            && !$rxtx->{R_ITSELF} )
        {
            $self->{current_cmd}->{ack_seen} = 1;

            #_logd("ACK_PULSE seen.");
        }
        if (   $self->{current_cmd}->{expected_response}
            && !$dec->{REPRQ}
            && $cmd ~~ ( $self->{current_cmd}->{expected_response} ) )
        {
            $self->{current_cmd}->{expected_response_seen} = 1;

            #_logd("expected response seen.");
        }
        _check_current_command();
    }

    if ( $cmd =~ /^all_.*/ ) {
        return 1;
    }
    elsif ( $cmd =~ /^report_only_on_pulse$/ ) {

        # use home of the current command, it looks like 1141/4825(?) sometimes sends home code of previous/random home :-/
        my $current_cmd_home = $home;
        if ( defined( $self->{current_cmd} ) ) {
            $current_cmd_home = $self->{current_cmd}->{home};
        }
        $self->_handle_REPORT_ONLY_ON_PULSE( $current_cmd_home, $dec->{d1},
            $dec->{d2} );
        return 1;
    }
    elsif ( $cmd =~ /^report_all_id_pulse$/ ) {

        # use home of the current command, it looks like 1141/4825(?) sometimes sends home code of previous/random home :-/
        my $current_cmd_home = $home;
        if ( defined( $self->{current_cmd} ) ) {
            $current_cmd_home = $self->{current_cmd}->{home};
        }
        $self->_handle_REPORT_ALL_ID_PULSE( $current_cmd_home, $dec->{d1},
            $dec->{d2} );
        return 1;
    }
    else {
        my $module = $self->{plc_devices}{$home}{$unit};
        if ($module) {
            $module->handle_incoming($dec);
            return 1;
        }
    }
}

sub _handle_REPORT_ONLY_ON_PULSE($$$) {
    my ( $self, $home, $d1, $d2 ) = @_;
    my $d_all = $d1 . $d2;
    my $on    = "";
    my $off   = "";
    for my $i ( 0 .. 15 ) {
        my $unit   = $i + 1;
        my $module = $self->{plc_devices}{$home}{$unit};
        if ($module) {
            if ( $d_all & ( 1 << $i ) ) {
                $module->_set('on');
                $on .= " " if ($on);
                $on .= $self->_get_module_name( $home, $unit );
            }
            else {
                $module->_set('off');
                $off .= " " if ($off);
                $off .= $self->_get_module_name( $home, $unit );
            }
        }
    }
    _logdd( "$home report_only_on_pulse 'd1d2': '"
          . bin_rep($d1)
          . bin_rep($d2)
          . "'" );
    _log("$home ON : '$on' OFF: '$off'");
}

sub _handle_REPORT_ALL_ID_PULSE($$$) {
    my ( $self, $home, $d1, $d2 ) = @_;
    my $d_all = $d1 . $d2;
    my $exist = "";
    for my $i ( 0 .. 15 ) {
        my $unit = $i + 1;
        if ( $d_all & ( 1 << $i ) ) {
            $exist .= " " if ($exist);
            $exist .= "$home$unit";
        }
    }
    _logdd( "$home report_all_id_pulse 'd1d2': '"
          . bin_rep($d1)
          . bin_rep($d2)
          . "'" );
    _log("$home present: $exist");
}

sub _check_external_plcbus_command_file() {
    my ($self) = @_;
    my $filename = $::config_parms{plcbus_command_file};
    return unless $filename;
    return unless $::New_Second;

    # Note: Check for non-zero size, not -e.  Zero length files cause a loop!
    return unless ( -s $filename );
    _logd("pclbus command file found: $filename");
    unless ( open( FD, $filename ) ) {
        print "\nWarning, can not open file $filename $!\n";
        return;
    }
    while ( my $line = <FD> ) {
        chomp($line);
        _logd("from commandfile: $line");
        $line =~ s/\s*//g;

        my @d = split /,/, $line;
        $self->queue_command(
            {
                home  => $d[0],
                unit  => $d[1],
                cmd   => $d[2],
                d1    => $d[3],
                d2    => $d[4],
                setby => 'pclbus cmd file',
            }
        ) unless ( $line eq "" );
    }
    close FD;
    unlink $filename;
}

sub _log_waiting_commands {
    my ($self) = @_;
    my $count = scalar @{ $self->{command_queue} };
    if ( $count > 0 ) {
        _logd("'$count' commands in queue");
    }
}

sub _is_current_command_complete() {
    my ($self) = @_;
    if ( !( defined( $self->{current_cmd} ) ) ) {
        return 1;
    }
    my $current = $self->{current_cmd};
    my $ok      = 1;
    my $what;
    if ( !$current->{echo_seen} ) {
        $what = $what . "'echo' ";
        $ok   = 0;
    }
    if ( $current->{waits_for_ack} && !$current->{ack_seen} ) {
        $what .= "'ack' ";
        $ok = 0;
    }
    if ( $current->{expected_response} && !$current->{expected_response_seen} )
    {
        $what .= "'response ("
          . join( "|", @{ $self->{current_cmd}->{expected_response} } ) . ")' ";
        $ok = 0;
    }
    if (
        $current->{three_phase}
        && (   !$cmd_to_hex{ $current->{cmd} }{noreplay}
            && !$current->{replay_seen} )
      )
    {
        if (   $current->{expected_response}
            && $current->{expected_response_seen} )
        {
            ## if we saw teh expected response we do not care for the replay fron the couple
            # if the 1141 is under heavy use it does seem to miss responses..
        }
        $what .= "'replay'";
        $ok = 0;
    }
    if ($what) {
        $current->{what} = "waiting for $what";
    }

    if (    ( $current->{cmd} eq "on" or $current->{cmd} eq "off" )
        and $current->{three_phase} == 0
        and $current->{ack_seen} )
    {
        _logdd(
            "Considering 1-Phase command completed, because ACK was received");
        $ok = 1;
        $current->{completed} = 1;
        my $module =
          $self->{plc_devices}->{ $current->{home} }->{ $current->{unit} };
        $module->_set( $current->{cmd}, $current->{setby},
            $current->{respond} );
    }
    elsif ( $ok && !$self->{current_cmd}->{completed} ) {
        $current->{completed} = 1;
    }

    if ( $current->{completed} ) {
        $current->{duration} =
          Time::HiRes::tv_interval( $current->{last_write} );
        my $name = "$self->{current_cmd}->{home}$self->{current_cmd}->{unit}";
        _logdd(
            "$name completed within $self->{current_cmd}->{duration} (allowed: "
              . $self->_get_timeout()
              . ")" );
    }
    return $ok;
}

sub _get_timeout() {
    my ($self)       = @_;
    my $t_one_packet = 0.500;           #worst case to send on comand on the BUS
    my $timeout      = $t_one_packet;
    $timeout += 0.300;                  # grace time...
    if ( $self->{current_cmd}->{three_phase} ) {
        $timeout += $t_one_packet;      # replay from phasecoupler
    }
    if ( $self->{current_cmd}->{expected_response} ) {
        $timeout += $t_one_packet;      # answer from module
        if ( $self->{current_cmd}->{three_phase} ) {
            $timeout += $t_one_packet;    # replay from phasecoupler
        }
    }

    #return 5;
    return $timeout;
}

sub _has_current_command_timeout() {
    my ($self) = @_;
    if ( !defined( $self->{current_cmd} ) ) {
        return 0;
    }
    if ( !$self->{current_cmd}->{last_write} ) {
        return 0;
    }
    my $maxwait = $self->_get_timeout();
    my $diff = Time::HiRes::tv_interval( $self->{current_cmd}->{last_write} );
    if ( $diff < $maxwait ) {
        return 0;
    }
    my ( $home, $unit ) =
      ( $self->{current_cmd}->{home}, $self->{current_cmd}->{unit} );
    my $name = "$home$unit";
    my $c = $self->{current_cmd}->{three_phase} ? "3" : "1";
    $c .= "-Phase command";
    my $msg = "timeout $c after " . sprintf( "%.3f", ${diff} ) . "s ";
    if ( $self->{current_cmd}->{what} ) {
        $msg .= $self->{current_cmd}->{what};
    }
    _logw("$name $msg");    #\n" .Dumper($self->{current_cmd}));
    return 1;
}

sub _get_module_name($$) {
    my ( $self, $home, $unit ) = @_;
    my $name   = "$home$unit";
    my $module = $self->{plc_devices}{$home}{$unit};
    if ($module) {
        $name .= " $module->{name}";
    }
    return $name;
}

sub _check_current_command() {
    my ($self) = @_;
    if ( !defined( $self->{current_cmd} ) ) {
        return 1;
    }

    my $delete_cmd = 0;
    if ( $self->_is_current_command_complete() ) {
        $delete_cmd = 1;
    }
    elsif ( $self->_has_current_command_timeout() ) {
        $delete_cmd = 1;
    }

    if ($delete_cmd) {
        _logdd("command removed");
        $self->{current_cmd} = undef;
        return 1;
    }

    return 0;

}

sub _can_transmit() {
    my ($self) = @_;
    if ( $self->_check_current_command() == 0 ) {
        return 0;
    }

    if ( scalar @{ $self->{command_queue} } == 0 ) {
        return 0;
    }

    # if data was sent or received we wait some time...
    # stupid plcbus pc interface seems to get to hot and
    # or chokes if it gets too much/too fast/too often data, i don't
    # get it... bitchy thingy... hope this helps
    #
    # there is also a chance of the last command beeing repeated by
    # the coupler or the the sender e.g. report_only_on_pulse
    my $diff = Time::HiRes::tv_interval( $self->{last_data_to_from_bus} );
    if ( $diff < 0.500 ) {

        #_logddd("to early... $diff");
        return 0;
    }

    if ( !$self->{plcbussrv_connection} || !$self->{select} ) {
        _log(
            "not connected to plcpus command server can't transmit, dropping all pending commands"
        );
        $self->{command_queue} = [];
        return 0;
    }

    return 1;
}

sub _read_from_server() {
    my ($self) = @_;
    if ( !$self->{select} ) {
        $self->_connect_command_server();
    }
    else {
        my @ready = $self->{select}->can_read(0);
        foreach my $c (@ready) {
            my $data;
            my $rv = $c->recv( $data, 9, 0 );
            unless ( defined($rv) and length($data) ) {
                $self->{select}->remove( $self->{plcbussrv_connection} );
                $self->{select}               = undef;
                $self->{plcbussrv_connection} = undef;
                _log(
                    "Connection to comman server broken, trying to reconnect.");
                $self->_connect_command_server();
            }
            return $data;
        }
    }
    return undef;
}

my @rx_tmp = ();
my $STX    = 0x02;
my $STE    = 0x03;

sub _read_packet() {
    my ($self) = @_;
    READ_MORE:
    while ( my $b = $self->_read_from_server() ) {
        $self->{last_data_to_from_bus} = [ Time::HiRes::gettimeofday() ];
        my @u = unpack( 'C*', $b );
        for my $cur (@u) {
            if ( scalar @rx_tmp == 0 ) {
                if ( $cur != $STX ) {
                    _log( "< not a startbyte. Dropped "
                          . sprintf( "0x%02x", $cur ) );
                }
                else {
                    push @rx_tmp, $cur;
                }
            }
            else {
                push @rx_tmp, $cur;
            }
        }

        if ( scalar @rx_tmp < 9 ) {
            my $data = sprintf( "%02x" x scalar @rx_tmp, @rx_tmp );
            _log("< $data INCOMPLETE PACKET!");
            next READ_MORE;
        }

        my @rx = splice( @rx_tmp, 0, 9 );

        if ( sum(@rx) % 0x100 != 0x0 )
        { ## aus pcbbus.pl geklaut, kp warum das so ghet, nirgends steht wie die checksumme funktioniert..
            _log(   "< READ INVALID PACKET: \n"
                  . sprintf( " 0x%02x" x scalar @rx, @rx )
                  . "\n" );
            my @tmp = @rx_tmp;
            @rx_tmp = ();
            for my $cur (@tmp) {
                if ( scalar @rx_tmp == 0 && $cur != $STX ) {
                    _log( "< Dropped " . sprintf( "0x%02x", $cur ) );
                }
                else {
                    push @rx_tmp, $cur;
                }
            }
            if ( scalar @rx_tmp > 0 ) {
                next READ_MORE;
            }
            else {
                return ();
            }
        }
        else {
            return @rx;
        }
    }
    return ();
}

sub _decode_incoming($) {
    my ( $self, @rx ) = @_;

    return 0 unless scalar(@rx) == 9;

    my (
        $rx_STX,       $rx_length,       $rx_USER_CODE,
        $rx_home_unit, $rx_command,      $rx_data1,
        $rx_data2,     $rx_RX_TX_SWITCH, $rx_ETX
    ) = @rx;

    my $rx_decoded = decode_command($rx_command);
    my $home       = get_home($rx_home_unit);
    $rx_decoded->{home} = $home;
    my $unit = get_unit($rx_home_unit);
    $rx_decoded->{unit} = $unit;
    my $cmd_hex = ( $rx_command & 0x1F );
    my $cmd     = $hex_to_cmd{$cmd_hex};
    my $datastr = "";
    if ( $cmd_to_hex{$cmd}{data} == 1 ) {
        $datastr =
            ", d1=0x"
          . hex_rep($rx_data1)
          . "($rx_data1) d2=0x"
          . hex_rep($rx_data2)
          . "($rx_data2)";
        $rx_decoded->{data} = 1;
        $rx_decoded->{d1}   = $rx_data1;
        $rx_decoded->{d2}   = $rx_data2;
    }

    my $m = "$home$unit RX " . sprintf( " %02x" x scalar @rx, @rx ) . " => ";

    $m .= _command_to_string($rx_command);

    my $rxtx =
      decode_rx_tx_switch( $rx_RX_TX_SWITCH, $rx_data1, $rx_data2, \$m );
    $rx_decoded->{rxtx} = $rxtx;
    $m .= ", R_ID_SW"  if ( $rxtx->{R_ID_SW} );
    $m .= ", R_ACK_SW" if ( $rxtx->{R_ACK_SW} );
    $m .= ", R_ITSELF" if ( $rxtx->{R_ITSELF} );
    $m .= ", R_RISC"   if ( $rxtx->{R_RISC} );
    $m .= ", R_SW"     if ( $rxtx->{R_SW} );
    $m .= $datastr;
    _logd($m);

    return $rx_decoded;
}

sub queue_command {
    my ( $self, $command ) = @_;
    if ( !$command->{home} ) {
        _logw( "home missing:\n" . Dumper($command) );
        return;
    }
    $command->{home} = uc $command->{home};

    if ( !defined $command->{unit} ) {
        _logw( "unit  missing:\n" . Dumper($command) );
        return;
    }
    if ( !defined $command->{cmd} ) {
        _logw( "command missing:\n " . Dumper($command) );
        return;
    }

    if ( !$cmd_to_hex{ $command->{cmd} } ) {
        _logw( "command '$command->{cmd}' unknown => not queued.\n"
              . Dumper($command) );
        return;
    }

    push( @{ $self->{command_queue} }, $command );

    my $msg = $self->_get_module_name( $command->{home}, $command->{unit} );

    $msg .= " queued '$command->{cmd}";
    $msg .= " d1=$command->{d1}" if $command->{d1};
    $msg .= " d2=$command->{d2}" if $command->{d2};
    $msg .= "'";
    _logd($msg);
}

sub _write_current_command {
    my ($self) = @_;
    my ( $home, $unit, $cmd, $d1, $d2 ) = (
        $self->{current_cmd}->{home}, $self->{current_cmd}->{unit},
        $self->{current_cmd}->{cmd},  $self->{current_cmd}->{d1},
        $self->{current_cmd}->{d2}
    );
    my $tx_home_unit = 0x00;
    $tx_home_unit = $unit - 1 if $unit;
    $tx_home_unit =
      $tx_home_unit | ( ( ord($home) - 0x41 ) << 4 );    # 0x41 == 'A'

    my $tx_STX = 0x02;
    my $tx_ETX = 0x03;

    my $tx_command = $cmd_to_hex{$cmd}{cmd};

    my $phase_flag = $self->_get_phase_flag( $home, $unit );
    $tx_command = $tx_command | $phase_flag;                   #  3-/1-phase
    $tx_command = $tx_command | $cmd_to_hex{$cmd}{'flags'};    # ack_pulse
    $self->{current_cmd}->{waits_for_ack} = $cmd_to_hex{$cmd}{'flags'};
    $self->{current_cmd}->{expected_response} =
      $cmd_to_hex{$cmd}{expected_response};
    $self->{current_cmd}->{three_phase} = $phase_flag;

    $self->{current_cmd}->{data} = $cmd_to_hex{$cmd}{data};
    my $tx_data1 = $d1 || 0x00;
    my $tx_data2 = $d2 || 0x00;
    my $tx_length = 0x5;

    my $usercode = _get_user_code();

    my $m = sprintf( "$home$unit TX " . " %02x" x 8,
        $tx_STX, $tx_length, $usercode, $tx_home_unit, $tx_command, $tx_data1,
        $tx_data2, $tx_ETX );
    $m .= "    => " . _command_to_string($tx_command);
    my $tx = pack( 'C*',
        $tx_STX, $tx_length, $usercode, $tx_home_unit, $tx_command, $tx_data1,
        $tx_data2, $tx_ETX );

    my $result = $self->{plcbussrv_connection}->send($tx);

    $self->{current_cmd}->{last_write} = [ Time::HiRes::gettimeofday() ];
    $self->{last_data_to_from_bus} = [ Time::HiRes::gettimeofday() ];
    if ( !$result ) {
        _log( $m . ": WRITE TO COMAND SERVER FAILED" );
    }
    elsif ( $result != length $tx ) {
        _log(   $m
              . ": WRITE incomplete. have written '$result' of '"
              . length $tx
              . "'" );
    }
    else {
        _logd($m);
    }
}

sub _get_phase_flag($$) {
    my ( $self, $home, $unit ) = @_;

    my $mode;
    my $module = $self->{plc_devices}{$home}{$unit};
    if ($module) {
        $mode = $module->_get_phase_mode();
    }
    else {
        $mode = $::config_parms{plcbus_phase_mode};
    }

    if ( $mode == 1 ) {
        return 0;
    }
    else {
        return ( 1 << 6 );
    }
}

sub get_home($) {
    my ($addr) = @_;
    my $home = ( ( $addr & 0xF0 ) >> 4 ) + 0x41;
    return chr($home);
}

sub get_unit($) {
    my ($addr) = @_;
    my $unit = ( $addr & 0x0F ) + 1;
    return $unit;
}

sub _command_to_string($) {
    my ($command) = @_;
    my $LINK      = ( $command & 0x80 );
    my $REPRQ     = ( $command & 0x40 );
    my $ACK_PULSE = ( $command & 0x20 );
    my $cmd_hex   = ( $command & 0x1F );
    my $cmd       = $hex_to_cmd{$cmd_hex};
    my $d         = "$cmd";
    $d .= ", LINK"      if ($LINK);
    $d .= ", REPRQ"     if ($REPRQ);
    $d .= ", ACK_PULSE" if ($ACK_PULSE);
    return $d;
}

sub decode_command($) {
    my ($command) = @_;
    my $c = ();
    $c->{LINK}      = ( $command & 0x80 );
    $c->{REPRQ}     = ( $command & 0x40 );
    $c->{ACK_PULSE} = ( $command & 0x20 );
    $c->{cmd_hex}   = ( $command & 0x1F );
    $c->{cmd}       = $hex_to_cmd{ $c->{cmd_hex} };
    return $c;
}

sub decode_rx_tx_switch($$$$) {
    my ( $b, $d1, $d2, $m ) = @_;
    my $rx_tx = ();

    $rx_tx->{R_ID_SW}  = $b & ( 1 << 6 );
    $rx_tx->{R_ACK_SW} = $b & ( 1 << 5 );
    $rx_tx->{R_ITSELF} = $b & ( 1 << 4 );
    $rx_tx->{R_RISC}   = $b & ( 1 << 3 );
    $rx_tx->{R_SW}     = $b & ( 1 << 2 );

    if ( $rx_tx->{R_ID_SW} ) {
        my $online = "< present: ";
        for my $i ( 0 .. 15 ) {
            my $bit = 1 << ( $i % 8 );
            my $is_present = 0;
            if ( $i <= 7 && $d2 & $bit ) {
                $is_present = 1;
            }
            elsif ( $d1 & $bit ) {
                $is_present = 1;
            }
            $online .= ( $i + 1 ) if ($is_present);
        }
        _logd($online);
    }
    return $rx_tx;
}

sub _split_homeunit {
    my ($address) = @_;
    die("$address is not a valid PLCBUS home unit address")
      unless ( $address =~ /^([A-O])([0-9]{1,2})$/ );
    return ( $1, $2 );
}

sub get_cmd_list($) {
    my ($what) = @_;
    my $cmdlist = "";
    while ( my ( $cmd, $cmd_options ) = each %cmd_to_hex ) {
        if ( $cmd_options->{ $what . "_cmd" } ) {
            $cmdlist .= "," unless ( $cmdlist eq "" );
            $cmdlist .= $cmd;
        }
    }
    $cmdlist =~ s/_/ /g;
    return $cmdlist;
}

my $homes = ();

sub generate_code(@) {
    my ( $self, $type, $address, $name, $grouplist ) = @_;
    my ( $home, $unit ) = _split_homeunit($address);

    # $grouplist = ($grouplist?"$grouplist|PLCBUS":"PLCBUS");
    my $home_name = "PLCBUS_$home";

    # $grouplist .= "|$phome";

    _logd("$address $name '$type' groups: '$grouplist'");
    my $object;
    if ( $type =~ /^PLCBUS_(\d{4}).*/i ) {
        $object = "PLCBUS_$1('$name', '$home','$unit', '$grouplist')";
    }
    elsif ( $type =~ /^PLCBUS_Scene.*/i ) {
        $object = "PLCBUS_Scene('$name', '$home','$unit', '$grouplist')";
    }
    elsif ( $type =~ /^PLCBUS.*/i ) {
        _log(
            "Unknown PLCBUS device type '$type'. Creating generic PLCBUS item");
        $object = "PLCBUS_Item('$name', '$home','$unit', '$grouplist')";
    }
    else {
        _logW("WTF WTFWTFWTFWTFWTFWTFWTF");
        return;

        #   $object = "PLCBUS_Item('$name', '$home', '$unit')";
    }

    my $more;
    ## 3 spaces instead of "my " means global mh object!
    if ( !$homes->{$home} ) {
        $homes->{$home}++;
        my $vc = "\$" . $home_name . "_voice_cmds";
        $more .= "\n";
        $more .=
            "   $vc = new Voice_Cmd(\"PLCBUS "
          . $home . " ["
          . get_cmd_list('home')
          . "]\");\n";
        $more .= ::store_object_data( $vc, 'Voice_Cmd', 'PLCBUS', 'PLCBUS' );

        # $more .= "\$PLCBUS->add(".$vc.");\n";
        # $more .= "\$". $phome."->add(".$vc.");\n";
        $more .= " if (my \$status = said $vc){\n";
        $more .= "     \$status =~ s/ /_/g;\n";
        $more .= "     respond \"queued \$status for home '$home'\";\n";
        $more .=
          "     PLCBUS->instance()->queue_command( {home => '$home', unit => 0, cmd => \$status});\n";
        $more .= " }\n";
    }
    my $usercode = _get_user_code();
    if ( !$homes->{$usercode} ) {
        $homes->{$usercode}++;
        $more .=
            "   \$PLCBUS_USER_Commands = new Voice_Cmd(\"PLCBUS ["
          . get_cmd_list('user')
          . "]\");\n";
        $more .=
          ::store_object_data( "\$PLCBUS_USER_Commands", 'Voice_Cmd', 'PLCBUS',
            'PLCBUS' );

        #$more .= "\$PLCBUS->add(\$PLCBUS_USER_Commands);\n";
        $more .= " if (my \$status = said \$PLCBUS_USER_Commands){\n";
        $more .= "     \$status =~ s/ /_/g;\n";
        $more .= "     respond \"queued comand \$status for all\";\n";
        $more .=
          "     PLCBUS->instance()->queue_command( {home => 'A', unit => 0, cmd => \$status});\n";
        $more .= " }\n";

        $more .=
          "   \$PLCBUS_scan_house = new Voice_Cmd(\"PLCBUS scan house\");\n";
        $more .=
          ::store_object_data( "\$PLCBUS_scan_house", 'Voice_Cmd', 'PLCBUS',
            'PLCBUS' );
        $more .= " if (my \$status = said \$PLCBUS_scan_house){\n";
        $more .= "     \$status =~ s/ /_/g;\n";
        $more .= "     respond \"scanning home codes A .. P\";\n";
        $more .= "     PLCBUS->instance()->scan_whole_hose();\n";
        $more .= " }\n";
    }

    # if ($more){
    #     _logdd($more);
    # }
    return ( $object, $grouplist, $more );
}

sub scan_whole_hose {
    my ($self) = @_;
    foreach my $home ( "A" .. "P" ) {
        $self->queue_command(
            { home => $home, unit => 0, cmd => 'report_all_id_pulse' } );
    }
}

1;

=head1 NAME

PLCBUS - use the PLCBUS with misterhouse

=head1 DESCRIPTION

Enables the use of PLCBUS modules with misterhouse. To send/receive data from
the bus a PLCBUS2-T 1141 device is required.

All testing was done with the USB variant but there should be no difference.

This module depends on a separate server process 'plcbussrv' to connect to the
PLCBUS. You can get the tool from L<https://github.com/tobser/plcbussrv>, see
README.md for installation instructions. The server process is automatically
started by this module


=head1 mh.private.ini

    plcbus_serial_port=/dev/plcbus
    plcbus_phase_mode=3
    plcbus_user_code=0xAB
    plcbus_command_file=/tmp/plcbuscommands
    plcbussrv_port=4567
    debug=plcbus:2|plcbus_module:2
    plcbus_logfile=1

=over

=item B<plcbus_serial_port>

Filename of your 1141

=item B<plcbus_phase_mode>

Set to 1 or 3, default is 1

=item B<plcbus_user_code>

The PLCBUS user code. All all modules including the 3-Phasecouple must be setup
with the same user code otherwise they will not react to commands if not set the
default of 0xff is used

=item B<plcbus_command_file>

Can be used to execute arbitrary PLCBUS commands not available through the web
interface. See SETTING UP A NEW PLCBUS MODULE on how to use it.

For a list of available commands take a look at %cmd_to_hex at the beginning of
PLCBUS.pm

=item B<plcbussrv_port>

TCP port to use for the plcbussrv server process. Default is '4567'

=item B<plcbus_logfile>

if set to '1' a seperate logfile
"$main::config_parms{data_dir}/logs/plcbus.log" with all plcbus logging is
created. This may help to keep the global mh logfile clean while still being
able to debug plcbus. All logmessages are written regardless of your 'debug='
setting.

if set to '0' or omitted, no logfile is created.

=back

=head2 SAMPLE .MHT FILE

    Format = A
    # PLCBUS_TYPE,   address,  name,                groups
    PLCBUS_2026G,    B2,       StandardLamp,        Property|livingroom(10;10)
    PLCBUS_2263DAU,  B4,       StaircaseLightning,  Property|staircase(5;20)
    PLCBUS_2026G,    B5,       TvLamp,              Property|livingroom(20;20)
    PLCBUS_Scene,    O2,       TestScene

=head2 CATEGORY PLCBUS

The module automatically creates the "PLCBUS"-Category which contains all
PLCBUS voice commands.

=head2 VOICE COMMANDS

Voice commands for the user code and for all home address are created. Those are
worded as found in the documentation for the serial interface of the 1141. This
may and probably will change in future.

=head2 PLCBUS ITEMS

For now all devices can only go into on/off state You can use the Voice_Cmds of
the PLCBUS Category execute specific PLCBUS commands e.g. 'status_req' to
retrieve the current state of the module. 'status_req' will also change the
on/off state of the module if an answer is received. Other commands such as to
get the signal strength do not change the state of the item. You have to check
the misterhouse log for the result of those commands.

There are 3 special voice command states '1_phase', '3-phase' and
'use_mh_ini_phase_mode' to use a specific phase mode for one unit. This command
is stored per unit, and is also restored between misterhouse restarts.
'use_mh_ini_phase_mode' deletes the setting and the phase mode specified in
mh.ini is used.

=head1 SETTING UP A NEW PLCBUS MODULE

You may want to enable full debug output in for PLCBUS in your private mh.ini
file to see what's actually going on:

    debug=plcbus:2|plcbus_module:2

Let's say we purchased a new PLCBUS_2026G plug in module. First we need to decide
for an address for our new module, e.g. B<C7> and create a 
new entry in our mht file:

    PLCBUS_2026G,    C7,       newTestLamp, PLCBUS_C

Now reload or restart misterhouse. Misterhouse should now create the new device
and start the B<plcbussrv> server, which you should have installed already. If
not 
see the DESCRIPTION for a link.

If all went as expected you should find your new device in the PLCBUS_C group:

L<http://misterhouse/ia7/#path=/objects&parents=PLCBUS_C&_collection_key=0,1,17,$PLCBUS_C>

Now we have to tell the module about its new address. All modules I used so far
are brought into setup mode by pressing the setup button for 5s. The LED starts
blinking as soon as the module changes into setup mode. The 3-Phasecouple is an
exception, its LED turns of as soon as it changed to setup
mode.

As soon as the LED start to blink you have to send a 'on' command to the module.
Either by changing its state via the web interface to 'on' or by using the PCLBUS
command file (see mh.private.ini setting)

    echo c,7,on > /tmp/plcbuscommands

If the module stops blinking and the attached light turns off, the module now
knows its own address and should react to your commands. To change the
brightness level and fade rate try the following command

    echo c,7,presetdim,60,7 > /tmp/plcbuscommands

For less information on available commands see the documentation for the 1141
RS-232 Interface. You can get it in the download section of the PLCBUS forum
L<http://www.plc-bus.info/downloads.php?cat=2> (you need to be logged in)

Now start playing with your new toys. But not too much, cause your 1141 and/or
your phase couple may get annoyed :-(


=head1 AUTHOR

Tobias Sachs diespambox@gmx.net

=cut

package PLCBUS_Item;
@PLCBUS_Item::ISA = ('Generic_Item');

sub _logd {
    my ( $self, @msg ) = @_;
    my $global_log = ( $::Debug{plcbus_module} && $::Debug{plcbus_module} > 1 );
    $self->__log( "@msg", $global_log, "V" );
}

sub _log {
    my ( $self, @msg ) = @_;
    my $global_log = $::Debug{plcbus_module};
    $self->__log( "@msg", $global_log, "I" );
}

sub __log {
    my ( $self, $msg, $global_log, $level ) = @_;
    my $name = "$self->{home}$self->{unit} $self->{name}:";
    PLCBUS::__log( "$name $msg", $global_log, $level );
}

sub new {
    my ( $class, $name, $home, $unit, $grouplist ) = @_;
    my $self = {};
    bless $self, $class;
    $self->{home}   = $home;
    $self->{unit}   = $unit;
    $self->{name}   = $name;
    $self->{groups} = $grouplist;
    my @default_states =
      qw|on off bright dim status_req get_noise_strength get_signal_strength status_on status_off|;
    $self->set_states(@default_states);
    $self->_logd("ctor $self->{name} home: $self->{home} unit: $self->{unit}");
    PLCBUS->instance()->add_device($self);
    $self->restore_data('phase_override');
    $self->generate_voice_commands();
    return $self;
}

sub generate_voice_commands {
    my ($self) = @_;
    $self->_log("Generating Voice commands");
    my $object_string;
    my $name = $self->{name};

    my $varlist;
    my $vc_pref = $name;
    $vc_pref =~ tr/_/ /;

    my $voice_cmds = $self->get_voice_cmds();

    foreach ( sort keys %$voice_cmds ) {
        my $vc_var_name = "\$${name}_$_";
        $varlist .= " $vc_var_name";
        $object_string .=
          "$vc_var_name  = new Voice_Cmd '$vc_pref $voice_cmds->{$_}[0]';\n";
        $object_string .=
          "$vc_var_name -> tie_event('" . $voice_cmds->{$_}[1] . "');\n";
        $object_string .=
          ::store_object_data( "$vc_var_name", 'Voice_Cmd', 'PLCBUS',
            'PLCBUS' );
    }
    $object_string = "use vars qw($varlist);\n" . $object_string;

    #$self->_log("\n\n$object_string");

    #Evaluate the resulting object generating string
    package main;
    eval $object_string;
    die "Error in PLCBUS item voice command genertion: $@\n" if $@;

    package PLCBUS_Item;
}

sub get_voice_cmds {
    my ($self)      = @_;
    my $object_name = $self->{name};
    my %voice_cmds  = (
        'change_state' => [
            '[on,off,status req,get signal strength,get noise strength,1 phase,3 phase,use mh ini phase mode]',
            "\$$object_name->set(\$state)"
        ],
        'bright_025' => [
            'presetdim to 25% within [0,1,2,3,4,5,6,7,8,9,10]s',
            "\$$object_name->preset_dim_from_voice_cmd( 25, \$state)"
        ],
        'bright_050' => [
            'presetdim to 50% within [0,1,2,3,4,5,6,7,8,9,10]s',
            "\$$object_name->preset_dim_from_voice_cmd( 50, \$state)"
        ],
        'bright_075' => [
            'presetdim to 75% within [0,1,2,3,4,5,6,7,8,9,10]s',
            "\$$object_name->preset_dim_from_voice_cmd( 75, \$state)"
        ],
        'bright_100' => [
            'presetdim to 100% within [0,1,2,3,4,5,6,7,8,9,10]s',
            "\$$object_name->preset_dim_from_voice_cmd(100, \$state)"
        ],
        'bright_cmd' => [
            'bright [25,50,75,100]%',
            "\$$object_name->command(\"bright\", \$state, 1)"
        ],
        'dim_cmd' => [
            'dim [25,50,75,100]%',
            "\$$object_name->command(\"dim\", \$state, 1)"
        ],
    );

    return \%voice_cmds;
}

sub default_setstate {
    my ( $self, @rest ) = @_;
    my $msg = "";
    foreach my $x (@rest) {
        $msg .= ", " if ( length $msg > 0 );
        $msg .= $x   if $x;
    }
    $self->_log("default_setstate: '$msg'");
}

sub handle_incoming {
    my ( $self, $c ) = @_;
    my $msg;
    my $setby = "PLCBUSInc";
    $setby = $c->{setby} if ( $c->{setby} );

    my $data = "";
    $data .= "d1=$c->{d1} " if $c->{d1};
    $data .= "d2=$c->{d2}"  if $c->{d2};
    if ( $c->{cmd} eq "status_on" ) {
        $msg = "On $data";
        my $mState = 'on';
        if ( $c->{d1} ) {

            #$mState .= ":$c->{d1}";
        }
        $self->_set( $mState, $setby );
    }
    elsif ( $c->{cmd} eq "status_off" ) {
        $msg = "Off $data";
        $self->_set( "off", $setby );
    }
    elsif ( $c->{cmd} eq "report_signal_strength" ) {
        $msg = "Signal strength is $data";
    }
    elsif ( $c->{cmd} eq "report_noise_strength" ) {
        $msg = "Noise is $data";
    }

    if ($msg) {
        if ( $c->{respond} ) {
            &::respond( $c->{respond}, $msg );
        }
        $self->_log($msg);
    }
}

sub _set {
    my ( $self, $new_state, $setby, $respond ) = @_;
    my $prev = $self->{state};
    $prev = 'undef' if ( !$prev );

    if ( $new_state ne $prev ) {
        my $msg = "'$prev' => '$new_state'";
        $msg .= ", set by $setby"    if $setby;
        $msg .= ", respond $respond" if $respond;
        $self->_logd($msg);
        $self->SUPER::set( $new_state, $setby, $respond );
    }
}

sub preset_dim_from_voice_cmd() {
    my ( $self, $brightness, $faderate ) = @_;
    my $msg =
      "change preset brightness to $brightness% at a faderate of $faderate seconds for $self->{name} was requested";
    ::respond("$msg");
    $self->preset_dim( $brightness, $faderate );
}

sub preset_dim {
    my ( $self, $bright_percent, $fade_rate_secs ) = @_;

    my $msg = "preset dim $bright_percent% $fade_rate_secs";
    $self->_log($msg);
    $self->command( 'presetdim', $bright_percent, $fade_rate_secs );
}

my @light_cmds = [ "on", "off", "bright", "dim" ];
my @plc_cmds = [
    "status req",
    "blink",
    "status on",
    "status off",
    "get signal strength",
    "get noise strength"
];

sub set {
    my ( $self, $new_state, $setby, $respond ) = @_;

    my $l = "set $new_state ";
    $l .= "from $setby "      if $setby;
    $l .= "respond $respond " if $respond;
    $self->_logd($l);

    if ( $new_state ~~ @light_cmds ) {
        if ( $new_state ne $self->{state} ) {
            $self->command( $new_state, undef, undef, $setby, $respond );
        }
        else {
            $self->_logd("Already in state $new_state");
        }

        #        if ($new_state eq "on" or $new_state eq "off"){
        #            $self->_set($new_state, $setby, $respond);
        #        }
    }
    elsif ( $new_state ~~ @plc_cmds ) {
        $new_state =~ s/ /_/g;
        $self->command( $new_state, undef, undef, $setby, $respond );
    }
    elsif ( $new_state =~ /(.*) phase/ ) {
        if ( $1 =~ /.*mh ini.*/ ) {
            delete $self->{phase_override};
            $self->_log("removed phase mode override.");
        }
        else {
            $self->{phase_override} = $1;
            $self->_log("switched to '$self->{phase_override}' phase mode.");
        }
    }
    else {
        $self->_log("do not know what to do with state '$new_state'");
        return 0;
    }
}

sub command {
    my ( $self, $cmd, $d1, $d2, $setby, $respond ) = @_;
    my $msg = "$cmd";
    $msg .= " d1=$d1" if $d1;
    $msg .= " d2=$d2" if $d2;
    my $home = $self->{home};
    my $unit = $self->{unit};
    PLCBUS->instance()->queue_command(
        {
            home    => $home,
            unit    => $unit,
            cmd     => $cmd,
            d1      => $d1,
            d2      => $d2,
            setby   => $setby,
            respond => $respond
        }
    );
}

sub _get_phase_mode {
    my ($self) = @_;
    my $mode;
    if ( $self->{phase_override} ) {
        $mode = $self->{phase_override};
        $self->_logd("using module specific phase mode '$mode'");
    }
    else {
        $mode = $::config_parms{plcbus_phase_mode};
        if ( !$mode ) {
            $self->_log("Phase mode not defined in mh.ini. Asuming 1-Phase");
            $mode = 1;
        }
    }
    return $mode;
}

package PLCBUS_LightItem;
@PLCBUS_LightItem::ISA = ('PLCBUS_Item');

package PLCBUS_2026;
@PLCBUS_2026::ISA = ('PLCBUS_LightItem');

package PLCBUS_2263;
@PLCBUS_2263::ISA = ('PLCBUS_LightItem');

package PLCBUS_Scene;
@PLCBUS_Scene::ISA = ('PLCBUS_Item');

1;
