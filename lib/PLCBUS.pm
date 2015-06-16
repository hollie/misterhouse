use strict;
use warnings;
use Device::SerialPort;
use PLCBUS::PLCBUS_Item;
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
my @command_queue;
my $current_cmd;
my %hex_to_cmd =(
    ##  * = contains data
    ##  + = needs feedback

    0x00 => "all_unit_off",           #  In Same HOME, “All Units Off”.
    0x01 => "all_lts_on",              #  In Same HOME, “All Lights On”.
    0x02 => "on",                      #  In Same HOME +UNIT, “One UNIT On”.  +
    0x03 => "off",                     #  In Same HOME + UNIT,”One UNIT Off”. +
    0x04 => "dim",                     #  In Same HOME + UNIT,”One UNIT Dim”. *+
    0x05 => "bright",                  #  In Same HOME + UNIT,”One UNIT Brig hten” *+
    0x06 => "all_light_off",           #  In Same HOME, “All Lights Off”.
    0x07 => "all_user_lts_on",         #  Under Same USER, “All USER Lig hts On”.
    0x08 => "all_user_unit_off",       #  Under Same USER, “All USER U nits Off”.
    0x09 => "all_user_light_off",      #  Under Same USER, “All USER L ights Off”
    0x0A => "blink",                   #  In Same HOME+ UNIT, “One Light Blin k”. *+
    0x0B => "fade_stop",               #  In Same HOME+ UNIT, “One light S top Dimming”. +
    0x0C => "presetdim",               #  In Same HOME+UNIT, “Preset Brigh tness Level”. *+
    0x0D => "status_on",               #  Status feedback as “ON”.*
    0x0E => "status_off",              #  Status feedback as “OFF”.
    0x0F => "status_req",              #  Status Checking
    0x10 => "r_master_addrs_setup",    #  Setup the main addre ss of Receiver. *+
    0x11 => "t_master_addrs_setup",    #  Setup the main addr ess of Transmitter. *+
    0x12 => "scenes_addrs_setup",      #  Setup Scene address *
    0x13 => "scenes_addrs_erase",      #  Clean    Scene    address    under the    same HOME+UNIT
    0x14 => "all_scenes_addrs_erase",  #  Clean all the Scene a ddresses in each receiver. *+
    0x15 => "",                        #  * for future
    0x16 => "",                        #  * for future
    0x17 => "",                        #  * for future
    0x18 => "get_signal_strength",     #  Check the Signal Stre ngth. +
    0x19 => "get_noise_strength",      #  Check the Noise Streng th.   +
    0x1A => "report_signal_strength",  #  Report the Signal Stren gth. *
    0x1B => "report_noise_strength",   #  Report the Noise Str ength. *
    0x1C => "get_all_id_pulse",        #  (THE SAME USER AND THE SAME HOM E) Check the ID PULSE in the same USER + HOME.
    0x1D => "get_only_on_id_pulse",    #  (THE SAME USER AND THE SAME HOME) Check the Only ON ID PULSE in the same USER+ HOME.
    0x1E => "report_all_id_pulse",     #  （ For 3-phase power line only ）
    0x1F => "report_only_on_pulse",    #  （ For 3-phase power line only ）
);

## NOTES
# 3-Phase coupler has no Adress
# Pc2Plcbus interface has no adress 
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

my %cmd_to_hex =(
    ##  + = needs feedback
    all_unit_off => {
        cmd => 0x00,
        flags => 0x00,
        data => 0,
        noreplay => 1,
        description => "In Same HOME, “All Units Off”.",
        home_cmd => 1,
        expected_response => undef,
    },
    all_lts_on => {
        cmd => 0x01,
        flags => 0x00,
        data => 0,
        noreplay => 1,
        description => "In Same HOME, “All Lights On”.",
        home_cmd => 1,
        expected_response => undef,
    },
    on => {
        cmd => 0x02,
        flags => 0x20,
        data => 0,
        expected_response => [ 'status_on' ],
        description => "In Same HOME & UNIT, “One UNIT On”.  +",
    },
    off => {
        cmd => 0x03,
        flags => 0x20,
        data => 0,
        expected_response => [ 'status_off' ],
        description => "In Same HOME & UNIT, ”One UNIT Off”. +",
    },
    dim => { 
        cmd => 0x04,
        flags => 0x20,
        data => 1,
        description => "In Same HOME & UNIT, ”One UNIT Dim”. *+",
        expected_response => undef,
    },
    bright => { 
        cmd => 0x05,
        flags => 0x20,
        data => 1,
        description => "In Same HOME & UNIT, ”One UNIT Brighten” *+",
        expected_response => undef,
    },
    all_light_off=> {
        cmd => 0x06,
        flags => 0x00,
        data => 0,
        noreplay => 1,
        description => "In Same HOME, “All Lights Off”.",
        home_cmd => 1,
        expected_response => undef,
    },
    all_user_lts_on => {
        cmd => 0x07,
        flags => 0x00,
        data => 0,
        noreplay => 1,
        description => "Under Same USER, “All USER Lights On”.",
        user_cmd => 1,
        expected_response => undef,
    },
    all_user_unit_off=> {
        cmd => 0x08,
        flags => 0x00,
        data => 0,
        noreplay => 1,
        description => "Under Same USER, “All USER Units Off”.",
        user_cmd => 1,
        expected_response => undef,
    },
    all_user_light_off=> {
        cmd => 0x09,
        flags => 0x00,
        data => 0,
        noreplay => 1,
        description => "Under Same USER, “All USER Lights Off”",
        user_cmd => 1,
        expected_response => undef,
    },
    blink => {
        cmd => 0x0A,
        flags => 0x20,
        data => 1,
        description => "In Same HOME & UNIT, “One Light Blink”. *+",
        expected_response => undef,
    },
    fade_stop  => {
        cmd => 0x0B,
        flags => 0x20,
        data => 0,
        description => "In Same HOME & UNIT, “One light Stop Dimming”. +",
        expected_response => undef,
    },
    presetdim => {
        cmd => 0x0C,
        flags => 0x20,
        data => 1,
        description => "In Same HOME & UNIT, “Preset Brightness Level”. *+",
        expected_response => undef,
    },
    status_on => {
        cmd => 0x0D,
        flags => 0x00,
        data => 1,
        description => "Status feedback as “ON”.*",
        expected_response => undef,
    },
    status_off  => {
        cmd => 0x0E,
        flags => 0x00,
        data => 0,
        description => "Status feedback as “OFF”.",
        expected_response => undef,
    },
    status_req => {
        cmd => 0x0F,
        flags => 0x00,
        data => 0,
        expected_response => ['status_on', 'status_off'],
        description => "Status Checking"
    },
    r_master_addrs_setup => {
        # ??????
        cmd => 0x10,
        flags => 0x20,
        data => 1,
        description => "Setup the main addre ss of Receiver. *+",
        expected_response => undef,
    },
    t_master_addrs_setup => {
        # ??????
        cmd => 0x11,
        flags => 0x20,
        data => 1,
        description => "Setup the main addr ess of Transmitter. *+",
        expected_response => undef,
    },
    scenes_addrs_setup       => {
        cmd => 0x12,
        flags => 0x00,
        data => 1,
        description => "Setup Scene address *",
        expected_response => undef,
    },
    scenes_addrs_erase      => {
        cmd => 0x13,
        flags => 0x00,
        data => 0,
        description => "Clean Scene address under the same HOME & UNIT",
        expected_response => undef,
    },
    all_scenes_addrs_erase  => {
        cmd => 0x14,
        flags => 0x20,
        data => 1,
        description => "Clean all the Scene a ddresses in each receiver. *+",
        expected_response => undef,
    },
    future1 => {
        cmd => 0x15,
        flags => 0x00,
        data => 1,
        description => "* for future",
        expected_response => undef,
    },
    future2 => {
        cmd => 0x16,
        flags => 0x00,
        data => 1,
        description => "* for future",
        expected_response => undef,
    },
    future3 => {
        cmd => 0x17,
        flags => 0x00,
        data => 1,
        description => "* for future",
        expected_response => undef,
    },
    get_signal_strength => {
        cmd => 0x18,
        flags => 0x20,
        data => 0,
        description => "Check the Signal Stre ngth. +",
        expected_response => [ 'report_signal_strength' ],
    },
    get_noise_strength => { 
        cmd => 0x19,
        flags => 0x20,
        data => 0,
        description => "Check the Noise Strength.   +",
        expected_response => [ 'report_noise_strength' ],
    },
    report_signal_strength  => {
        cmd => 0x1A,
        flags => 0x00,
        data => 1,
        description => "Report the Signal Stren gth. *",
        expected_response => undef,
    },
    report_noise_strength => {
        cmd => 0x1B,
        flags => 0x00,
        data => 1,
        description => "Report the Noise Str ength. *",
        expected_response => undef,
    },
    get_all_id_pulse => {
        cmd => 0x1C,
        flags => 0x00,
        data => 0,
        description => "(THE SAME USER AND THE SAME HOME) Check the ID PULSE in the same USER & HOME.",
        expected_response => ['report_all_id_pulse'],
        home_cmd => 1,
        noreplay => 1,
    },
    get_only_on_id_pulse => {
        cmd => 0x1D,
        flags => 0x00,
        data => 0,
        expected_response => ['report_only_on_pulse' ],
        home_cmd => 1,
        noreplay => 1 ,
        description => "(THE SAME USER AND THE SAME HOME) Check the Only ON ID PULSE in the same USER & HOME."
    },
    report_all_id_pulse => {
        cmd => 0x1E,
        flags => 0x00,
        data => 1,
        description => "（ For 3-phase power line only ）",
        expected_response => undef,
    },
    report_only_on_pulse => {
        cmd => 0x1F,
        flags => 0x00,
        data => 1,
        description => "（ For 3-phase power line only ）",
        expected_response => undef,
    },
);

my $select;
my $plc_command_server;
my %plc_devices = ();
my $plcbus_group;
my $homes = (); # hash for home->unit

sub _log{
    my $prefix = "PLCBUS";
    &main::print_log("$prefix: @_");
}
sub _logd{
    return unless $::Debug{plcbus};
    _log(@_);
}
sub _logdd{
    return unless ($::Debug{plcbus} && $::Debug{plcbus} > 1);
    _log(@_);
}

sub _logw{
    _log("W: @_");
}

sub bin_rep($){
    return sprintf("%08b", shift);
}
sub hex_rep($){
    return sprintf("%02x", shift);
}


my $dev;
sub _start_serial_port(){
    my  $serial_device = $::config_parms{plcbus_serial_port};
    my $plc_dev = Device::SerialPort->new($serial_device);
    if (!$plc_dev){
        _log "Error opening serial port '$serial_device': $!";
        return 0;
    }
    $plc_dev->baudrate(9600);
    $plc_dev->databits(8);
    $plc_dev->parity("none");
    $plc_dev->stopbits(1);
    $plc_dev->handshake("none");
    $plc_dev->read_const_time(10);
    $plc_dev->write_settings;
    $dev = $plc_dev;
    _log("serial port '$serial_device' opened");
    return 1;
}


my $server_proc = new Process_Item();
sub _new_instance {
    my ($class) = @_;
    my $self  = bless { }, $class;

    _log("debuglevel: $::Debug{plcbus}");
    my $serial = $::config_parms{plcbus_serial_port};
    die ("plcbus interface missing. Set 'plcbus_serial_port' in mh.private.ini") unless $serial;
    
#    _start_serial_port();

    #  my $c = "plcbus_command_server.pl  --device /dev/plcbus --port 4567 &>1 >> /home/tob/plc.log";

    my $c = "plcbussrv /dev/plcbus 4567"; # &>1 > /home/tob/plc.log";
     _log($c);
     set $server_proc $c;
     start $server_proc;

    _connect_command_server();

    &::MainLoop_pre_add_hook(\&_handle_commands);
    &::Exit_add_hook(\&_on_exit);


    _logd("plcbus manager created.");
    return $self;
}

sub _connect_command_server(){
    $plc_command_server = new IO::Socket::INET (
        PeerHost => 'localhost',
        PeerPort => '4567',
        Proto => 'tcp',
        Timeout => 2000,
    ) ;#or die "could not connect to plc_command_server.pl";
    if ($plc_command_server){
        $plc_command_server->blocking(0);
        $select = IO::Select->new($plc_command_server);
    }
}
sub _on_exit(){
    if ($plc_command_server){
        $plc_command_server->close();
        $plc_command_server = undef;
        _log("closed connection to commandserver");
    }
    _log("stopping server");
    $server_proc->stop();
    _log("commandserver stopped");
    $current_cmd = undef;
    _log("Exiting...");
}

sub _get_user_code(){
    if (!$::config_parms{plcbus_user_code}){
        _log("'plcbus_user_code' not set falling back to default '0xff'");
        return 0xff;
    }
    else {
        return hex($::config_parms{plcbus_user_code});
    }
}

sub _is_three_phase_enabled($){
    my ($module) = @_;
    my $mode ;
    if ($module && $module->{phase_override}){
        $mode = $module->{phase_override};
        _logdd("using module specific phase mode '$mode'");
    }
    else{
        $mode = $::config_parms{plcbus_phase_mode};
        if(! $mode ){
            _log("Phase mode not defined in mh.ini. Asuming 1-Phase");
            return 0;
        }
    }

    if($mode != 1 && $mode != 3 ) {
        _log("Phase mode '$mode' unknown. Asuming 1-Phase");
        return 0;
    }
    elsif ($mode == 1){
        return 0;
    }
    elsif ($mode == 3) {
        return 1;
    }
}

sub add_device($){
    my ($self,$dev) = @_;
    my $home = $dev->{home};
    my $unit = $dev->{unit};
    $plc_devices{$home}{$unit}  = $dev;
    _logd ("$dev->{name} $home$unit added");
}

sub _handle_commands (){
    _check_external_plcbus_command_file();
    _check_current_command();
    # _queue_maintainance_commands();
    while(_handle_incoming_commands()){};
    return unless _can_transmit();


    $current_cmd = shift @command_queue;
    _write_current_command();
    _log_waiting_commands();
}

sub _queue_maintainance_commands(){
    return unless (&::new_minute(5));
    for my $home (keys %plc_devices){
        _logdd("Doing maintainance for '$home'");
        _check_for_on_units_in_home($home);
    }
}

sub _check_for_on_units_in_home($){
    my ($home) =@_;
    my $cmd = "get_only_on_id_pulse";
    PLCBUS->instance()->queue_command( { home => $home, unit => 1, cmd => $cmd});
}

sub _handle_incoming_commands{
    return 0 unless my @raw = _read_packet();
    return 0 unless my $dec = _decode_incoming(@raw);

    #_log(Dumper($dec));

    my $home = $dec->{home};
    my $unit = $dec->{unit};
    my $cmd = $dec->{cmd};
    my $rxtx = $dec->{rxtx};

    if ($current_cmd){
        if ($rxtx->{R_ITSELF}) {
            $current_cmd->{echo_seen} = 1;
            # _logd("Received myself on PLCBUS.");
            return 1;
        }
        if($current_cmd->{three_phase}
            && $dec->{REPRQ}
            && !$rxtx->{R_ITSELF}){
            $current_cmd->{replay_seen} = 1;
            #_logd("Received replay from PLCBUS phase coupler.");
        }
        if($current_cmd->{waits_for_ack}
            && $dec->{ACK_PULSE}
            && !$dec->{R_ACK_SW}
            && !$rxtx->{R_ITSELF}){
            $current_cmd->{ack_seen} = 1;
            #_logd("ACK_PULSE seen.");
        }
        if( $current_cmd->{expected_response}
            && !$dec->{REPRQ}
            && $cmd ~~ ($current_cmd->{expected_response})){
            $current_cmd->{expected_response_seen} = 1;
            #_logd("expected response seen.");
        }
        _check_current_command();
    }

   if ($cmd =~ /^all_.*/) {
       return 1;
   }
   elsif ($cmd =~ /^report_only_on_pulse$/){
       _handle_REPORT_ONLY_ON_PULSE($home,$dec->{d1},$dec->{d2});
       return 1;
   }
   else{
       my $module = $plc_devices{$home}{$unit};
       if ($module) {
           $module->handle_incoming($dec);
           return 1;
       }
       else{
           _logdd("module $home$unit not known");
           return 0;
       }
   }
 }

 sub _handle_REPORT_ONLY_ON_PULSE($$$){
     my ($home,$d1,$d2) = @_;
     my $d_all = $d1.$d2;
     for my $i (0..15){
         my $unit = $i +1;
         my $module = $plc_devices{$home}{$unit};
         if ($module) {
             if ( $d_all & (1 << $i)){
                 $module->_set('on');
             }
             else{
                 $module->_set('off');
             }
         }
     }
 }

sub _check_external_plcbus_command_file(){
    my $filename = $::config_parms{plcbus_command_file};
    return unless $filename;
    return unless $::New_Second;
    # Note: Check for non-zero size, not -e.  Zero length files cause a loop!
    return unless (-s $filename);
    _logd("pclbus command file found: $filename");
    unless (open(FD, $filename)) {
        print "\nWarning, can not open file $filename $!\n";
        return;
    }
    while(my $line = <FD>)
    {
        chomp($line);
        _logd("from commandfile: $line");
        $line =~ s/\s*//g;
    
        my @d = split /,/ , $line;
        PLCBUS->instance()->queue_command( 
            {
                home => $d[0],
                unit => $d[1],
                cmd  => $d[2],
                d1   => $d[3],
                d2   => $d[4]
            }) unless ($line eq "");
    }
    close FD;
    unlink $filename;
}

sub _log_waiting_commands{
    my $count = scalar @command_queue;
    if ( $count > 0){
        _logd("'$count' commands in queue");
    }
}

sub _is_current_command_complete(){
   if(!$current_cmd){
       return 1;
   }

    my $ok = 1;
    my $what;
    if(!$current_cmd->{echo_seen}) {
        $what = $what ."'echo' ";
        $ok = 0;
    }
    if($current_cmd->{waits_for_ack} && ! $current_cmd->{ack_seen}){
        $what .= "'ack' ";
        $ok = 0;
    }
    if($current_cmd->{expected_response} && !$current_cmd->{expected_response_seen}){
        $what .= "'response (". join ("|", @{ $current_cmd->{expected_response}}). ")' ";
        $ok = 0;
    }
    if($current_cmd->{three_phase} && (!$cmd_to_hex{$current_cmd->{cmd}}{noreplay} && !$current_cmd->{replay_seen})){
        if($current_cmd->{expected_response} && $current_cmd->{expected_response_seen}){
            ## if we saw teh expected response we do not care for the replay fron the couple
            # if the 1141 is under heavy use it does seem to miss responses..
        }
        $what .= "'replay'";
        $ok = 0;
    }
    if ($what){
        $current_cmd->{what} = "waiting for $what";
    }
    if ($ok && !$current_cmd->{completed}){
        $current_cmd->{completed} = 1;
        $current_cmd->{duration} = Time::HiRes::tv_interval($current_cmd->{last_write});
        _logdd("completion of '$current_cmd->{cmd}' took $current_cmd->{duration} (max allowed: ". _get_timeout().")");
        $current_cmd = undef;
    }
    return $ok;
}

sub _get_timeout(){
    my $t_one_packet = 0.500;#worst case to send on comand on the BUS
    my $timeout = $t_one_packet;
    $timeout += 0.300; # mh loop time  is 0.250 if all goes well.. but 
    if ($current_cmd->{three_phase}){
        $timeout += $t_one_packet; # replay from phasecoupler
    }
    if ($current_cmd->{expected_response}){
        $timeout += $t_one_packet; # answer from module
        if ($current_cmd->{three_phase}){
            $timeout += $t_one_packet; # replay from phasecoupler
        }
    }
    #return 5;
    return $timeout;
}

sub _has_current_command_timeout(){
    if(!$current_cmd){
        return 0;
    }
    if(!$current_cmd->{last_write}){
        return 0;
    }
    my $maxwait = _get_timeout();
    my $diff= Time::HiRes::tv_interval($current_cmd->{last_write});
    if($diff < $maxwait){
        return 0;
    }
    my $c=_get_module_name($current_cmd->{home},$current_cmd->{unit}). ",$current_cmd->{cmd}";
    if($current_cmd->{data}){
        $c .= ",$current_cmd->{d1}" ;
        $c .= ",$current_cmd->{d2}" ;
    }
    $c .= ",";
    $c .= $current_cmd->{three_phase}? "3" : "1";
    $c .= "-Phase";
    my $msg = "TIMEOUT($diff) '$c': ";
    if ($current_cmd->{what}){
        $msg .=  $current_cmd->{what};
    }
    _logw($msg); #:\n" .Dumper($current_cmd));
    return 1;
}

sub _get_module_name($$){
    my ($home,$unit) = @_;
    my $name = "$home$unit";
    my $module = $plc_devices{$home}{$unit};
    if ($module) {
        $name = "$module->{name}($name)";
    }
    return $name;
}

sub _check_current_command(){
    if (!$current_cmd){
        return 1;
    }
    elsif (_is_current_command_complete()){
        $current_cmd = undef; 
        return 1;
    }
    elsif (_has_current_command_timeout()){
        $current_cmd = undef; 
        return 1;
    }
    else{
        return 0;
    }
}

my $last_data_to_from_bus = [Time::HiRes::gettimeofday()];
sub _can_transmit(){
    return 0 if( scalar @command_queue == 0);
    if (!_check_current_command()){
        # _log("have ongoing command...");
        return 0;
    }

    # if data was sent or received we wait some time...
    # stupid plcbus pc interface seems to get to hot and
    # or chokes if it gets too much/too fast/too often data, i don't 
    # get it... bitchy thingy... hope this helps
    my $diff= Time::HiRes::tv_interval($last_data_to_from_bus);
    if($diff < 0.750) 
    {
        # _log("to early... $diff");
        return 0;
    }

    if (!$plc_command_server || !$select){
        _log("not connected to plcpus command server can't transmit, dropping all pending commands");
        @command_queue = ();
        return 0;
    }

    return 1;
}

sub _read_from_server(){
    if (!$select){
        _connect_command_server();
    }
    else{
        my @ready = $select->can_read(0);
        foreach my $c (@ready){
            my $data;
            my $rv = $c->recv($data, 9, 0);
            unless (defined($rv) and length($data)) {
                $select->remove($plc_command_server);
                $select = undef;
                $plc_command_server = undef;
                _log("Connection to comman server broken, trying to reconnect.");
                _connect_command_server();
            }
            return $data;
        }
    }
    return undef;
}


my @rx_tmp = ();
my $STX = 0x02;
my $STE = 0x03;
sub _read_packet(){
    READ_MORE:
    while (my $b = _read_from_server()){
        $last_data_to_from_bus =  [Time::HiRes::gettimeofday()];
        my @u = unpack('C*', $b);
        for my $cur (@u){
            if(scalar @rx_tmp == 0){
                if ($cur != $STX){
                    _log("< not a startbyte. Dropped ". sprintf("0x%02x", $cur));
                }
                else{
                    push @rx_tmp, $cur;
                }
            }
            else{
                push @rx_tmp, $cur;
            }
        }

        if (scalar @rx_tmp < 9) {
            my $data = sprintf ("%02x"x scalar @rx_tmp, @rx_tmp);
           _log("< $data INCOMPLETE PACKET!");
           next READ_MORE;
        }

        my @rx = splice(@rx_tmp,0,9);

        if (sum(@rx) % 0x100 != 0x0) { ## aus pcbbus.pl geklaut, kp warum das so ghet, nirgends steht wie die checksumme funktioniert..
            _log("< READ INVALID PACKET: \n". sprintf(" 0x%02x"x scalar @rx, @rx) . "\n");
            my @tmp = @rx_tmp;
            @rx_tmp = ();
            for my $cur (@tmp){
                if (scalar @rx_tmp == 0 && $cur != $STX){
                    _log("< Dropped ". sprintf("0x%02x", $cur));
                }
                else {
                    push @rx_tmp, $cur;
                }
            }
            if (scalar @rx_tmp > 0){
                next READ_MORE;
            }
            else{
                return ();
            }
        }
        else{
            return @rx;
        }
    }
    return ();
}


sub _decode_incoming($) {
    my @rx = @_;

    return 0 unless scalar (@rx) == 9;

    my ($rx_STX, $rx_length, $rx_USER_CODE, $rx_home_unit , $rx_command , $rx_data1 , $rx_data2 , $rx_RX_TX_SWITCH, $rx_ETX) = @rx;

    my $rx_decoded = decode_command($rx_command);
    my $home = get_home($rx_home_unit);
    $rx_decoded->{home} = $home;
    my $unit = get_unit($rx_home_unit);
    $rx_decoded->{unit} = $unit;
    my $cmd_hex = ($rx_command & 0x1F);
    my $cmd = $hex_to_cmd{$cmd_hex};
    my $datastr = "";
    if ($cmd_to_hex{$cmd}{data} == 1){
        $datastr = ", d1=0x" . hex_rep($rx_data1) . "($rx_data1) d2=0x" . hex_rep($rx_data2). "($rx_data2)" ;
        $rx_decoded->{data} = 1;
        $rx_decoded->{d1} = $rx_data1;
        $rx_decoded->{d2} = $rx_data2;
    }

    my $m =  "< $home$unit: " . sprintf ("%02x"x scalar @rx, @rx) . " => ";

    $m .=  _command_to_string ($rx_command);

    my $rxtx = decode_rx_tx_switch($rx_RX_TX_SWITCH, $rx_data1, $rx_data2, \$m);
    $rx_decoded->{rxtx} = $rxtx;
    $m .= ", R_ID_SW"  if ($rxtx->{R_ID_SW});
    $m .= ", R_ACK_SW" if ($rxtx->{R_ACK_SW});
    $m .= ", R_ITSELF" if ($rxtx->{R_ITSELF});
    $m .= ", R_RISC"   if ($rxtx->{R_RISC});
    $m .= ", R_SW"     if ($rxtx->{R_SW});
    $m .=$datastr; 
    _logd($m);

    return $rx_decoded;
}

sub queue_command {
    my ($self, $command) = @_;
    #_log("cmd: ". Dumper($command));
    if (!$command->{home}){
        _logw("home missing:\n". Dumper($command));
        return;
    }
    $command->{home} = uc $command->{home};

    if (!defined $command->{unit}){
        _logw("unit  missing:\n". Dumper($command));
        return;
    }
    if (!defined $command->{cmd}){
        _logw("command missing:\n ". Dumper($command));
        return;
    }

    if (!$cmd_to_hex{$command->{cmd}}){
        _logw("command '$command->{cmd}' unknown => not queued.\n".Dumper($command));
        return;
    }

    if ( first {$_->{cmd}  eq $command->{cmd}
            &&  $_->{home} eq $command->{home}
            &&  $_->{unit} eq $command->{unit} } @command_queue) {
        _logw("command already in queue:\n ". Dumper($command));
        return;
    }

    push (@command_queue,$command);
    _logd("queued '$command->{home}$command->{unit} $command->{cmd}'");
}

sub _write_current_command {
    my ($home,$unit,$cmd, $d1, $d2) = ($current_cmd->{home}, $current_cmd->{unit}, $current_cmd->{cmd}, $current_cmd->{d1}, $current_cmd->{d2});
    my $tx_home_unit = 0x00;
    $tx_home_unit = $unit -1 if $unit;
    $tx_home_unit = $tx_home_unit | ((ord($home) - 0x41)<< 4); # 0x41 == 'A'

    my $tx_STX = 0x02;
    my $tx_ETX = 0x03;

    my $tx_command =$cmd_to_hex{$cmd}{cmd};

    my $module = $plc_devices{$home}{$unit};
    # _log("des isch a '". ref ($module)."'");
    my $phase_flag = _is_three_phase_enabled($module) ? (1 << 6) : 0;

    $tx_command = $tx_command | $phase_flag; #  3-/1-phase
    $tx_command = $tx_command | $cmd_to_hex{$cmd}{'flags'}; # ack_pulse
    $current_cmd->{waits_for_ack} = $cmd_to_hex{$cmd}{'flags'};
    $current_cmd->{three_phase} = $phase_flag;
    $current_cmd->{expected_response} = $cmd_to_hex{$cmd}{expected_response};

    $current_cmd->{data} = $cmd_to_hex{$cmd}{data};
    my $tx_data1 = $d1 || 0x00;
    my $tx_data2 = $d2 || 0x00;
    my $tx_length = 0x5;

    my $usercode = _get_user_code();

    my $m = sprintf("> $home$unit: ". "%02x"x8 , $tx_STX, $tx_length, $usercode, $tx_home_unit, $tx_command, $tx_data1, $tx_data2, $tx_ETX);
    $m .= "   => ". _command_to_string ($tx_command);
    my $tx = pack('C*', $tx_STX,$tx_length, $usercode, $tx_home_unit, $tx_command, $tx_data1, $tx_data2, $tx_ETX);

    my $result = $plc_command_server->send($tx);

    $current_cmd->{last_write} = [Time::HiRes::gettimeofday()];
    $last_data_to_from_bus =  [Time::HiRes::gettimeofday()];
    if (!$result) {
        _log($m . ": WRITE TO COMAND SERVER FAILED");
    }
    elsif ( $result != length $tx) {
        _log($m . ": WRITE incomplete. have written '$result' of '".length $tx."'");
    }
    else{
        _logd($m);
    }
}

sub get_home($){
    my ($addr) = @_;
    my $home = (($addr & 0xF0) >> 4) + 0x41;
    return chr($home);
}

sub get_unit($){
    my ($addr) = @_;
    my $unit = ($addr & 0x0F) + 1;
    return $unit;
}

sub _command_to_string($){
    my ($command) = @_;
    my $LINK  = ($command & 0x80);
    my $REPRQ = ($command & 0x40);
    my $ACK_PULSE = ($command & 0x20);
    my $cmd_hex = ($command & 0x1F);
    my $cmd = $hex_to_cmd{$cmd_hex};
    my $d = "$cmd";
    $d .= ", LINK" if ($LINK);
    $d .= ", REPRQ" if($REPRQ);
    $d .= ", ACK_PULSE" if ($ACK_PULSE);
    return $d;
}

sub decode_command($){
    my ($command) = @_;
    my $c = ();
    $c->{LINK}  = ($command & 0x80);
    $c->{REPRQ} = ($command & 0x40);
    $c->{ACK_PULSE} = ($command & 0x20);
    $c->{cmd_hex} = ($command & 0x1F);
    $c->{cmd} = $hex_to_cmd{$c->{cmd_hex}};
    return $c;
}

sub decode_rx_tx_switch($$$$){
    my ($b, $d1, $d2, $m) = @_;
    my $rx_tx = ();

    $rx_tx->{R_ID_SW}  = $b & (1 << 6);
    $rx_tx->{R_ACK_SW} = $b & (1 << 5);
    $rx_tx->{R_ITSELF} = $b & (1 << 4);
    $rx_tx->{R_RISC}   = $b & (1 << 3);
    $rx_tx->{R_SW}     = $b & (1 << 2);

    if ($rx_tx->{R_ID_SW}){
        my $online = "< present: ";
        for my $i (0..15){
            my $bit = 1 <<  ($i%8);
            my $is_present = 0;
            if ($i <= 7 && $d2 & $bit){
                $is_present = 1;
            }
            elsif ($d1 & $bit){
                $is_present = 1;
            }
            $online .= ($i +1) if ($is_present);
        }
        _logd($online);
    }
    return $rx_tx;
}

sub _split_homeunit{
    my ($address) = @_;
    die ("$address is not a valid PLCBUS home unit address") unless ($address =~ /^([A-O])([0-9]{1,2})$/);
    return ($1,$2);
}

sub get_cmd_list($){
    my ($what) = @_;
    my $cmdlist = "";
    while ( my ($cmd, $cmd_options) = each %cmd_to_hex )
    {
        if ($cmd_options->{$what."_cmd"}){
            $cmdlist .= "," unless ($cmdlist eq "");
            $cmdlist .= $cmd;
        }
    }
    $cmdlist =~ s/_/ /g;
    return $cmdlist;
}
sub generate_code(@){
    my ($type, $address, $name, $grouplist) = @_;
    my ($home,$unit) = _split_homeunit($address);

    $grouplist = ($grouplist?"$grouplist|PLCBUS":"PLCBUS");
    my $phome = "PLCBUS_$home";
    $grouplist .= "|$phome";

    _logd("$address: '$type' => '$name', groups: '$grouplist'");
    my $object ;
    if ($type =~ /^PLCBUS_(\d{4}).*/i){
        $object =  "PLCBUS_$1('$name', '$home','$unit')";
    }
    elsif ($type =~ /^PLCBUS_Scene.*/i){
        $object =  "PLCBUS_Scene('$name', '$home','$unit')";
    }
    else{
        _log("WTF WTFWTFWTFWTFWTFWTFWTF")
        #   $object = "PLCBUS_Item('$name', '$home', '$unit')";
    }
    my $more;
    ## 3 spaces instead of "my " means global mh object!
    if (!$homes->{$home})
    {
        $homes->{$home}++;
        my $vc = "\$".$phome."_voice_cmds";
        $more .= "\n";
        $more .= "   $vc = new Voice_Cmd(\"PLCBUS ".$home." [".get_cmd_list('home')."]\");\n";
        $more .= "\$PLCBUS->add(".$vc.");\n";
        $more .= "\$". $phome."->add(".$vc.");\n";
        $more .= " if (my \$status = said $vc){\n";
        $more .= "     \$status =~ s/ /_/g;\n";
        $more .= "     respond \"queued \$status for home '$home'\";\n";
        $more .= "     PLCBUS->instance()->queue_command( {home => '$home', unit => 0, cmd => \$status});\n";
        $more .= " }\n";
    }
    my $usercode = _get_user_code();
    if (!$homes->{$usercode})
    {
        $homes->{$usercode}++;
        $more .= "   \$PLCBUS_USER_Commands = new Voice_Cmd(\"PLCBUS [".get_cmd_list('user')."]\");\n";
        $more .= "\$PLCBUS->add(\$PLCBUS_USER_Commands);\n";
        $more .= " if (my \$status = said \$PLCBUS_USER_Commands){\n";
        $more .= "     \$status =~ s/ /_/g;\n";
        $more .= "     respond \"queued comand \$status for all\";\n";
        $more .= "     PLCBUS->instance()->queue_command( {home => 'A', unit => 0, cmd => \$status});\n";
        $more .= " }\n";
    }
    # if ($more){
    #     _logdd($more);
    # }
    return ($object, $grouplist, $more);
}

1;
=head_PLCBUS

=head2 mh.private.ini

configuration settings:

    plcbus_serial_port=/dev/plcbus

    plcbus_phase_mode=3

    plcbus_user_code=0xAB

    plcbus_command_file=/home/tob/plcbuscommands

    debug=plcbus:2|plcbus_module:2
=over

=item C<plcbus_serial_port>

filename of your 1141

=item C<plcbus_phase_mode>

optional.
set to 1 or 3, default is 1

=item C<plcbus_user_code>

usercode for your houes, default is 0xff

=item C<plcbus_command_file>

send arbitrary plcbus commands

if set to a file eg. /tmp/plcbuscommand 

 echo "B,3,on\nB,2,on\nB,4,on" >> /tmp/plcbuscommand

the three commands will be sent

=back

=cut
