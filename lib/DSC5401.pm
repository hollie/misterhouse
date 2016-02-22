
=head1 B<DSC5401>

=head2 SYNOPSIS

NONE

=head2 DESCRIPTION

NONE

=head2 INHERITS

B<Generic_Item>

=head2 METHODS

=over

=cut

#use strict;

package DSC5401;

@DSC5401::ISA = ('Generic_Item');

my $CalcChecksum;
my %EventMsg;
my %CmdMsg;
my %CmdMsgRev;
my $Self;
my %ErrorCode;
my $ImcompleteCmd;

=item C<new>

Starting a new object

=cut

sub new {
    my ($class) = @_;
    my $self = {};
    $$self{state}          = 'Unknown';
    $$self{said}           = '';
    $$self{last_event}     = '';
    $$self{command}        = '';
    $$self{description}    = '';
    $$self{TimeBroadcast}  = 'off';
    $$self{TstatBroadcast} = 'off';
    $$self{Log}            = [];

    bless $self, $class;

    # read event message hash
    DefineEventMsg();
    DefineCmdMsg();
    DefineErrorCode();

    my @LogType = qw(DSC_5401_ring_log DSC_5401_part_log DSC_5401_zone_log);
    foreach (@LogType) {
        if ( !exists $::config_parms{$_} ) {
            $main::config_parms{$_} = 1;
            &::print_log(
                "Parameter $_ not defined in mh.private.ini, enabling by default"
            );
        }
    }

    &main::print_log("Starting DSC 5401 computer interface module");
    $Self = $self;

    # Sometimes the first command sent generates an API Command Syntax Error.
    # This is likely due to stray bits making it onto the serial port.
    # So, we send a poll, which is really a NOP.  If this command fails,
    # no big deal.
    cmd( $self, 'Poll' );    # request an initial poll

    select( undef, undef, undef, 0.250 )
      ; # wait 250 millseconds to avoid overrunning RS-232 receive buffer on panel
    cmd( $self, 'StatusReport' );    # request an initial status report
    if ( defined $::config_parms{DSC_5401_verbose_arming} )
    {    # enable/disable verbose arming if configured
        select( undef, undef, undef, 0.250 )
          ; # wait 250 millseconds to avoid overrunning RS-232 receive buffer on panel
        cmd( $self, 'VerboseArmingControl',
            $::config_parms{DSC_5401_verbose_arming} );
    }
    if ( defined $::config_parms{DSC_5401_time_log} )
    {       # enable/disable time broadcasts if configured
        select( undef, undef, undef, 0.250 )
          ; # wait 250 millseconds to avoid overrunning RS-232 receive buffer on panel
        cmd( $self, 'TimeBroadcastControl',
            $::config_parms{DSC_5401_time_log} );
    }
    if ( defined $::config_parms{DSC_5401_temp_log} )
    {       # enable/disable temperature broadcasts if configured
        select( undef, undef, undef, 0.250 )
          ; # wait 250 millseconds to avoid overrunning RS-232 receive buffer on panel
        cmd( $self, 'TemperatureBroadcastControl',
            $::config_parms{DSC_5401_temp_log} );
    }
    return $self;
}

=item C<init>

serial port configuration

=cut

sub init {
    my ($serial_port) = @_;
    $serial_port->error_msg(1);
    $serial_port->databits(8);
    $serial_port->parity("none");
    $serial_port->stopbits(1);
    $serial_port->handshake('none');
    $serial_port->datatype('raw');
    $serial_port->dtr_active(1) or warn "Could not set dtr_active(1)";
    $serial_port->rts_active(0);

    #$serial_port->debug(0);
    select( undef, undef, undef, .100 );    # Sleep a bit
}

=item C<startup>

module startup / enabling serial port

=cut

sub startup {
    my $self = $Self;
    ( my $port = $::config_parms{'DSC_5401_serial_port'} )
      or warn
      "DSC5401.pm->startup  DSC_5401_serial_port not defined in mh.ini file";
    my $BaudRate =
      ( defined $::config_parms{DSC_5401_baudrate} )
      ? $main::config_parms{DSC_5401_baudrate}
      : 9600;
    if ( &main::serial_port_create( 'DSC5401', $port, $BaudRate, 'none', 'raw' )
      )
    {
        init( $::Serial_Ports{DSC5401}{object}, $port );
        &main::print_log(
            "  DSC5401.pm initializing port $port at $BaudRate baud")
          if $main::config_parms{debug} eq 'DSC5401';
        &::MainLoop_pre_add_hook( \&DSC5401::check_for_data, 1 )
          if $main::Serial_Ports{DSC5401}{object};
        $::Year_Month_Now =
          &::time_date_stamp( 10, time );    # Not yet set when we init.
        LocalLogit(
            "$main::config_parms{data_dir}/logs/DSC5401.$main::Year_Month_Now.log",
            "    ========= DSC5401.pm Initialized ========="
        );
    }
}

=item C<check_for_data>

check for incoming data on serial port

=cut

sub check_for_data {
    ResetDscState();
    &main::check_for_generic_serial_data('DSC5401');
    my $NewCmd = $main::Serial_Ports{'DSC5401'}{data};
    $main::Serial_Ports{'DSC5401'}{data} = '';

    # we need to buffer the information receive, because many command could be include in a single pass
    #&::print_log("Receive the following [$NewCmd]\n") if $NewCmd;
    $NewCmd = $ImcompleteCmd . $NewCmd if $ImcompleteCmd;
    return if !$NewCmd;
    $NewCmd =~ s/\r\n/#/g;    # to validate if there is newline missing
    my $Cmd = '';
    foreach my $c ( split( //, $NewCmd ) ) {
        if ( $c eq '#' ) {
            CheckCmd($Cmd) if $Cmd;
            $Cmd = '';
        }
        else {
            $Cmd .= $c;
        }
    }
    $ImcompleteCmd = $Cmd;
}

=item C<CmdStr>

Validate the command and perform action

=cut

sub CheckCmd {
    my $CmdStr = shift;

    if ( $CmdStr && $main::config_parms{debug} eq 'DSC5401' ) {
        my $l    = length($CmdStr);
        my $code = substr( $CmdStr, 0, 3 );
        my $arg  = substr( $CmdStr, 3, ( $l - 5 ) );
        my $Ck   = substr( $CmdStr, -2 );
        &main::print_log("DSC5401:check_for_data DscString=$code  $arg  $Ck");
    }

    if ( IsChecksumOK($CmdStr) ) {
        my $cmd = substr( $CmdStr, 0, 3 );
        my $data = substr( $CmdStr, 3, ( length($CmdStr) - 5 ) );
        my $self = $Self;

        if ( $cmd == 500 ) {    # System Error
            my $CmdName = "Unknown";
            $CmdName = $CmdMsgRev{$data} if exists $CmdMsgRev{$data};
            &LocalLogit(
                "$main::config_parms{data_dir}/logs/DSC5401.$main::Year_Month_Now.log",
                "$cmd $EventMsg{$cmd} $CmdName"
            );

            #&::print_log("$EventMsg{$cmd}:   $CmdName");
        }
        elsif ( $cmd == 501 ) {    # Command Error (bad checksum)
            my $ECName = "Unknown";
            $ECName = $ErrorCode{$data} if exists $ErrorCode{$data};
            &LocalLogit(
                "$main::config_parms{data_dir}/logs/DSC5401.$main::Year_Month_Now.log",
                "$cmd $EventMsg{$cmd} $ECName"
            );
            &::print_log("$EventMsg{$cmd}:   $ECName");
        }
        elsif ( $cmd == 502 ) {    # System Error
            my $ECName = "Unknown";
            $ECName = $ErrorCode{$data} if exists $ErrorCode{$data};
            &LocalLogit(
                "$main::config_parms{data_dir}/logs/DSC5401.$main::Year_Month_Now.log",
                "$cmd $EventMsg{$cmd} $ECName"
            );
            &::print_log("$EventMsg{$cmd}:   $ECName");
        }
        elsif ( $cmd == 550 ) {    # Time Broadcast
            my $Hour = substr( $data, 0, 2 );
            my $Min  = substr( $data, 2, 2 );
            my $MM   = substr( $data, 4, 2 );
            my $DD   = substr( $data, 6, 2 );
            my $YY   = substr( $data, 8, 2 );
            LocalLogit(
                "$main::config_parms{data_dir}/logs/DSC5401.$main::Year_Month_Now.log",
                "$cmd $EventMsg{$cmd} $Hour:$Min $MM/$DD/$YY"
            ) if $main::config_parms{DSC_5401_time_log};
            $self->{TimeBroadcast} = 'on';
            $self->{Time}          = "$Hour:$Min $MM/$DD/$YY";
            $self->{TimeStamp}     = &::time_date_stamp( 17, time );
            $self->{TimeEpoch}     = time;
        }
        elsif ( $cmd == 560 ) {    # Telephone ring detected
            my $Name = $data;
            &LocalLogit(
                "$main::config_parms{data_dir}/logs/DSC5401.$main::Year_Month_Now.log",
                "$cmd $EventMsg{$cmd}:"
            ) if $main::config_parms{DSC_5401_ring_log};
            $self->{ring_now} = 1;
        }
        elsif ( $cmd == 561 ) {    # Indoor Temperature Broadcast
            my $TstatNum  = substr( $data, 0, 1 );
            my $TstatTemp = substr( $data, 1, 3 );
            $TstatTemp = ( 128 - $TstatTemp ) if $TstatTemp > 128;
            LocalLogit(
                "$main::config_parms{data_dir}/logs/DSC5401.$main::Year_Month_Now.log",
                "$cmd $EventMsg{$cmd} Thermostat:$TstatNum  Temp:$TstatTemp"
            ) if $main::config_parms{DSC_5401_temp_log};
            $self->{TstatBroadcast}          = 'on';
            $self->{IntTstatTemp_now}        = $TstatTemp;
            $self->{IntTstatTemp_now_number} = $TstatNum;
            $self->{IntTstatTemp}{$TstatNum} = $TstatTemp;
            $self->{IntTstatTime}{$TstatNum} = &::time_date_stamp( 17, time );
            $self->{IntTstatEpoch}{$TstatNum} = time;
        }
        elsif ( $cmd == 562 ) {    # Outdoor Temperature Broadcast
            my $TstatNum  = substr( $data, 0, 1 );
            my $TstatTemp = substr( $data, 1, 3 );
            $TstatTemp = ( 128 - $TstatTemp ) if $TstatTemp > 128;
            &LocalLogit(
                "$main::config_parms{data_dir}/logs/DSC5401.$main::Year_Month_Now.log",
                "$cmd $EventMsg{$cmd} Thermostat:$TstatNum  Temp:$TstatTemp"
            ) if $main::config_parms{DSC_5401_temp_log};
            $self->{TstatBroadcast}          = 'on';
            $self->{ExtTstatTemp_now}        = $TstatTemp;
            $self->{ExtTstatTemp_now_number} = $TstatNum;
            $self->{ExtTstatTemp}{$TstatNum} = $TstatTemp;
            $self->{ExtTstatTime}{$TstatNum} = &::time_date_stamp( 17, time );
            $self->{ExtTstatEpoch}{$TstatNum} = time;
        }
        elsif ( $cmd == 601 ) {    # zone alarm
            my $PartName = substr( $data, 0, 1 );
            my $ZoneNum = my $ZoneName = substr( $data, 1, 3 );
            $ZoneName = $main::config_parms{"DSC_5401_zone_$ZoneNum"}
              if exists $main::config_parms{"DSC_5401_zone_$ZoneNum"};
            $PartName = $main::config_parms{"DSC_5401_part_$PartName"}
              if exists $main::config_parms{"DSC_5401_part_$PartName"};
            &LocalLogit(
                "$main::config_parms{data_dir}/logs/DSC5401.$main::Year_Month_Now.log",
                "$cmd $EventMsg{$cmd} zone $ZoneName  ($ZoneNum)"
            );
            $ZoneNum =~ s/^0*//;
            $self->{zone_now_cmd} = $cmd;
            $self->{zone_status}{"$ZoneNum"} = "alarm";
            $self->{zone_now_msg}   = "$EventMsg{$cmd} $ZoneName ($ZoneNum)";
            $self->{zone_now_state} = "alarm";
            $self->{zone_now}       = "$ZoneNum";
            $self->{zone_status}{"$ZoneNum"} = "alarm";
            $self->{zone_now_cmd} = $cmd;
        }
        elsif ( $cmd == 602 ) {    # zone alarm restore
            my $PartName = substr( $data, 0, 1 );
            my $ZoneNum = my $ZoneName = substr( $data, 1, 3 );
            $ZoneName = $main::config_parms{"DSC_5401_zone_$ZoneNum"}
              if exists $main::config_parms{"DSC_5401_zone_$ZoneNum"};
            $PartName = $main::config_parms{"DSC_5401_part_$PartName"}
              if exists $main::config_parms{"DSC_5401_part_$PartName"};
            &LocalLogit(
                "$main::config_parms{data_dir}/logs/DSC5401.$main::Year_Month_Now.log",
                "$cmd $EventMsg{$cmd} zone $ZoneName  ($ZoneNum)"
            );
            $ZoneNum =~ s/^0*//;
            $self->{zone_now_cmd}     = $cmd;
            $self->{zone_now_msg}     = "$EventMsg{$cmd} $ZoneName ($ZoneNum)";
            $self->{zone_now_state}   = "alarm restore";
            $self->{zone_now}         = "$ZoneNum";
            $self->{zone_now_restore} = "$ZoneNum";
            $self->{zone_status}{"$ZoneNum"} = "alarm restore";
        }
        elsif ( $cmd == 603 ) {    # zone tamper
            my $PartName = substr( $data, 0, 1 );
            my $ZoneNum = my $ZoneName = substr( $data, 1, 3 );
            $ZoneName = $main::config_parms{"DSC_5401_zone_$ZoneNum"}
              if exists $main::config_parms{"DSC_5401_zone_$ZoneNum"};
            $PartName = $main::config_parms{"DSC_5401_part_$PartName"}
              if exists $main::config_parms{"DSC_5401_part_$PartName"};
            &LocalLogit(
                "$main::config_parms{data_dir}/logs/DSC5401.$main::Year_Month_Now.log",
                "$cmd $EventMsg{$cmd} zone $ZoneName  ($ZoneNum)"
            );
            $ZoneNum =~ s/^0*//;
            $self->{zone_now_cmd}    = $cmd;
            $self->{zone_now_msg}    = "$EventMsg{$cmd} $ZoneName ($ZoneNum)";
            $self->{zone_now_status} = "alarm restore";
            $self->{zone_now}        = "$ZoneNum";
            $self->{zone_now_tamper} = "$ZoneNum";
            $self->{zone_status}{"$ZoneNum"} = "alarm restore";
        }
        elsif ( $cmd == 604 ) {    # zone tamper restore
            my $PartName = substr( $data, 0, 1 );
            my $ZoneNum = my $ZoneName = substr( $data, 1, 3 );
            $ZoneName = $main::config_parms{"DSC_5401_zone_$ZoneNum"}
              if exists $main::config_parms{"DSC_5401_zone_$ZoneNum"};
            $PartName = $main::config_parms{"DSC_5401_part_$PartName"}
              if exists $main::config_parms{"DSC_5401_part_$PartName"};
            &LocalLogit(
                "$main::config_parms{data_dir}/logs/DSC5401.$main::Year_Month_Now.log",
                "$cmd $EventMsg{$cmd} zone $ZoneName  ($ZoneNum)"
            );
            $ZoneNum =~ s/^0*//;
            $self->{zone_now_cmd}    = $cmd;
            $self->{zone_now_msg}    = "$EventMsg{$cmd} $ZoneName ($ZoneNum)";
            $self->{zone_now_status} = "alarm restore";
            $self->{zone_now}        = "$ZoneNum";
            $self->{zone_now_tamper_restore} = "$ZoneNum";
            $self->{zone_status}{"$ZoneNum"} = "alarm restore";
        }
        elsif ( $cmd == 605 ) {    # zone fault
            my $ZoneName = my $ZoneNum = $data;
            $ZoneName = $main::config_parms{"DSC_5401_zone_${data}"}
              if exists $main::config_parms{"DSC_5401_zone_${data}"};
            &LocalLogit(
                "$main::config_parms{data_dir}/logs/DSC5401.$main::Year_Month_Now.log",
                "$cmd $EventMsg{$cmd} zone $ZoneName  ($ZoneNum)"
            ) if $main::config_parms{DSC_5401_zone_log};
            $ZoneNum =~ s/^0*//;
            $self->{zone_now_cmd}            = $cmd;
            $self->{zone_now_msg}            = "$EventMsg{$cmd} $ZoneName";
            $self->{zone_now_status}         = "fault";
            $self->{zone_now}                = "$ZoneName";
            $self->{zone_now_fault}          = "$ZoneNum";
            $self->{zone_status}{"$ZoneNum"} = "fault";
        }
        elsif ( $cmd == 606 ) {    # zone restore
            my $ZoneName = my $ZoneNum = $data;
            $ZoneName = $main::config_parms{"DSC_5401_zone_${data}"}
              if exists $main::config_parms{"DSC_5401_zone_${data}"};
            &LocalLogit(
                "$main::config_parms{data_dir}/logs/DSC5401.$main::Year_Month_Now.log",
                "$cmd $EventMsg{$cmd} zone $ZoneName  ($ZoneNum)"
            ) if $main::config_parms{DSC_5401_zone_log};
            $ZoneNum =~ s/^0*//;
            $self->{zone_now_cmd}    = $cmd;
            $self->{zone_now_msg}    = "$EventMsg{$cmd} $ZoneName ($ZoneNum)";
            $self->{zone_now_status} = "fault restored";
            $self->{zone_now}        = "$ZoneNum";
            $self->{zone_now_fault_restore} = "$ZoneNum";
            $self->{zone_status}{"$ZoneNum"} = "fault restored";
        }
        elsif ( $cmd == 609 ) {    # zone open
            my $ZoneName = my $ZoneNum = $data;
            $ZoneName = $main::config_parms{"DSC_5401_zone_${data}"}
              if exists $main::config_parms{"DSC_5401_zone_${data}"};
            &LocalLogit(
                "$main::config_parms{data_dir}/logs/DSC5401.$main::Year_Month_Now.log",
                "$cmd $EventMsg{$cmd} zone $ZoneName ($ZoneNum)"
            ) if $main::config_parms{DSC_5401_zone_log};
            $ZoneNum =~ s/^0*//;
            $self->{zone_now_cmd}    = $cmd;
            $self->{zone_now_msg}    = "$EventMsg{$cmd} $ZoneName ($ZoneNum)";
            $self->{zone_now_status} = "open";
            $self->{zone_now}        = "$ZoneNum";
            $self->{zone_now_open}   = "$ZoneNum";
            $self->{zone_status}{"$ZoneNum"} = "open";
        }
        elsif ( $cmd == 610 ) {    # zone restored
            my $ZoneName = my $ZoneNum = $data;
            $ZoneName = $main::config_parms{"DSC_5401_zone_${data}"}
              if exists $main::config_parms{"DSC_5401_zone_${data}"};
            &LocalLogit(
                "$main::config_parms{data_dir}/logs/DSC5401.$main::Year_Month_Now.log",
                "$cmd $EventMsg{$cmd} zone $ZoneName ($ZoneNum)"
            ) if $main::config_parms{DSC_5401_zone_log};
            $ZoneNum =~ s/^0*//;
            $self->{zone_now_cmd}     = $cmd;
            $self->{zone_now_msg}     = "$EventMsg{$cmd} $ZoneName ($ZoneNum)";
            $self->{zone_now_status}  = "restored";
            $self->{zone_now}         = "$ZoneNum";
            $self->{zone_now_restore} = "$ZoneNum";
            $self->{zone_status}{"$ZoneNum"} = "restored";
        }
        elsif ( $cmd == 650 ) {    # Partition Ready
            my $PartName = my $PartNum = $data;
            $PartName = $main::config_parms{"DSC_5401_part_${data}"}
              if exists $main::config_parms{"DSC_5401_part_${data}"};
            &LocalLogit(
                "$main::config_parms{data_dir}/logs/DSC5401.$main::Year_Month_Now.log",
                "$cmd $EventMsg{$cmd} partition $PartName  ($PartNum)"
            ) if $main::config_parms{DSC_5401_part_log};
            $self->{zone_now_cmd}         = $cmd;
            $self->{partition_now_msg}    = "Partition $PartName is ready";
            $self->{partition_now_status} = "ready";
            $self->{partition_now}        = "$PartNum";
        }
        elsif ( $cmd == 651 ) {    # Partition Not Ready
            my $PartName = my $PartNum = $data;
            $PartName = $main::config_parms{"DSC_5401_part_${data}"}
              if exists $main::config_parms{"DSC_5401_part_${data}"};
            &LocalLogit(
                "$main::config_parms{data_dir}/logs/DSC5401.$main::Year_Month_Now.log",
                "$cmd $EventMsg{$cmd} parition $PartName  ($PartNum)"
            ) if $main::config_parms{DSC_5401_part_log};
            $self->{partition_now_cmd}    = $cmd;
            $self->{partition_now_msg}    = "Partition $PartName is not ready";
            $self->{partition_now_status} = "not ready";
            $self->{partition_now}        = "$PartNum";
        }
        elsif ( $cmd == 652 ) {    # Partition Armed
            my $PartNum = my $PartName = substr( $data, 0, 1 );
            my $Mode = ( length($data) == 2 ) ? substr( $data, 1, 1 ) : 4;
            my @ModeTxt = (
                "armed away",
                "armed stay",
                "armed Zero-Entry-Away",
                "armed Zero-Entry-Stay",
                "armed"
            );
            $PartName = $main::config_parms{"DSC_5401_part_${PartName}"}
              if exists $main::config_parms{"DSC_5401_part_${PartName}"};
            &LocalLogit(
                "$main::config_parms{data_dir}/logs/DSC5401.$main::Year_Month_Now.log",
                "$cmd $EventMsg{$cmd} partition $PartName ($PartNum) in mode $ModeTxt[$Mode] by user $self->{user_name}  ($self->{user_id})"
            );
            set $self "$ModeTxt[$Mode]";
            $self->{partition_now_cmd} = $cmd;
            $self->{partition_now_msg} =
              "Partition $PartName armed $ModeTxt[$Mode] by user $self->{user_name}";
            $self->{partition_now_status}     = "$ModeTxt[$Mode]";
            $self->{partition_now}            = "$PartNum";
            $self->{partition_now_mode}       = "$ModeTxt[$Mode]";
            $self->{partition_mode}{$PartNum} = "$ModeTxt[$Mode]";
        }
        elsif ( $cmd == 654 ) {    # Partition in Alarm
            my $PartName = my $PartNum = $data;
            $PartName = $main::config_parms{"DSC_5401_part_${data}"}
              if exists $main::config_parms{"DSC_5401_part_${data}"};
            &LocalLogit(
                "$main::config_parms{data_dir}/logs/DSC5401.$main::Year_Month_Now.log",
                "$cmd $EventMsg{$cmd} parition $PartName  ($PartNum)"
            ) if $main::config_parms{DSC_5401_part_log};
            $self->{partition_now_cmd}    = $cmd;
            $self->{partition_now_msg}    = "Partition $PartName is in alarm";
            $self->{partition_now_status} = "alarm";
            $self->{partition_now}        = "$PartNum";
        }
        elsif ( $cmd == 655 ) {    # Partition Disarmed
            my $PartName = my $PartNum = $data;
            $PartName = $main::config_parms{"DSC_5401_part_${data}"}
              if exists $main::config_parms{"DSC_5401_part_${data}"};
            &LocalLogit(
                "$main::config_parms{data_dir}/logs/DSC5401.$main::Year_Month_Now.log",
                "$cmd $EventMsg{$cmd} partition $PartName ($PartNum) by user $self->{user_name} ($self->{user_id})"
            );
            set $self "disarmed";
            $self->{partition_now_cmd} = $cmd;
            $self->{partition_now_msg} =
              "Partition $PartName ($PartNum) disarmed by user $self->{user_name}";
            $self->{partition_now_status} = "disarmed";
            $self->{partition_now}        = "$PartNum";
        }
        elsif ( $cmd == 656 ) {    # Exit Delay in Progress
            my $PartName = my $PartNum = $data;
            $PartName = $main::config_parms{"DSC_5401_part_${data}"}
              if exists $main::config_parms{"DSC_5401_part_${data}"};
            &LocalLogit(
                "$main::config_parms{data_dir}/logs/DSC5401.$main::Year_Month_Now.log",
                "$cmd $EventMsg{$cmd} partition $PartName  ($PartNum)"
            );
            set $self "exit delay";
            $self->{partition_now_cmd}    = $cmd;
            $self->{partition_now_msg}    = "Partition $PartName in exit delay";
            $self->{partition_now_status} = "exit delay";
            $self->{partition_now}        = "$PartNum";
            $self->{partition_mode}{$PartNum} = "exit delay";
        }
        elsif ( $cmd == 657 ) {    # Entry Delay in Progress
            my $PartName = my $PartNum = $data;
            $PartName = $main::config_parms{"DSC_5401_part_${data}"}
              if exists $main::config_parms{"DSC_5401_part_${data}"};
            &LocalLogit(
                "$main::config_parms{data_dir}/logs/DSC5401.$main::Year_Month_Now.log",
                "$cmd $EventMsg{$cmd} partition $PartName ($PartNum)"
            );
            set $self "Entry Delay";
            $self->{partition_now_cmd} = $cmd;
            $self->{partition_now_msg} = "Partition $PartName in entry delay";
            $self->{partition_now_status} = "entry delay";
            $self->{partition_now}        = "$PartNum";
        }
        elsif ( $cmd == 700 ) {    # User closing
            my $PartName = my $PartNum = substr( $data, 0, 1 );
            my $UserName = my $UserNum = substr( $data, 1, 4 );
            $PartName = $main::config_parms{"DSC_5401_part_${PartName}"}
              if exists $main::config_parms{"DSC_5401_part_${PartName}"};
            $UserName = $main::config_parms{"DSC_5401_user_${UserName}"}
              if exists $main::config_parms{"DSC_5401_user_${UserName}"};
            &LocalLogit(
                "$main::config_parms{data_dir}/logs/DSC5401.$main::Year_Month_Now.log",
                "$cmd $EventMsg{$cmd} user $UserName ($UserNum) closing partition $PartName ($PartNum)"
            );
            set $self "user closing";
            $self->{user_name}         = $UserName;
            $self->{user_id}           = $UserNum;
            $self->{partition_now_cmd} = $cmd;
            $self->{partition_now_msg} =
              "User $UserName  closing partition $PartName";
            $self->{partition_now_status} = "user closing";
            $self->{partition_now}        = "$PartNum";
        }
        elsif ( $cmd == 701 )
        {    # Special closing (probably via computer command)
            my $PartName = my $PartNum = $data;
            $PartName = $main::config_parms{"DSC_5401_part_${PartName}"}
              if exists $main::config_parms{"DSC_5401_part_${PartName}"};
            &LocalLogit(
                "$main::config_parms{data_dir}/logs/DSC5401.$main::Year_Month_Now.log",
                "$cmd $EventMsg{$cmd} Misterhouse or Anonymous doing special closing on partition $PartName ($PartNum)"
            );
            set $self "special closing";
            $self->{user_name}         = "Misterhouse or Anonymous";
            $self->{user_id}           = "0000";
            $self->{partition_now_cmd} = $cmd;
            $self->{partition_now_msg} =
              "Misterhouse or Anonymous doing special closing on partition $PartName";
            $self->{partition_now_status} = "special closing";
            $self->{partition_now}        = "$PartNum";
        }
        elsif ( $cmd == 702 )
        {    # Partial closing (probably via computer command)
            my $PartName = my $PartNum = $data;
            $PartName = $main::config_parms{"DSC_5401_part_${PartName}"}
              if exists $main::config_parms{"DSC_5401_part_${PartName}"};
            &LocalLogit(
                "$main::config_parms{data_dir}/logs/DSC5401.$main::Year_Month_Now.log",
                "$cmd $EventMsg{$cmd} Misterhouse or Anonymous doing spartial closing on partition $PartName ($PartNum)"
            );
            set $self "partial closing";
            $self->{user_name}         = "Misterhouse or Anonymous";
            $self->{user_id}           = "0000";
            $self->{partition_now_cmd} = $cmd;
            $self->{partition_now_msg} =
              "Misterhouse or Anonymous doing partital closing on partition $PartName";
            $self->{partition_now_status} = "partial closing";
            $self->{partition_now}        = "$PartNum";
        }
        elsif ( $cmd == 750 ) {    # User opening
            my $PartName = my $PartNum = substr( $data, 0, 1 );
            my $UserName = my $UserNum = substr( $data, 1, 4 );
            $PartName = $main::config_parms{"DSC_5401_part_${PartName}"}
              if exists $main::config_parms{"DSC_5401_part_${PartName}"};
            $UserName = $main::config_parms{"DSC_5401_user_${UserName}"}
              if exists $main::config_parms{"DSC_5401_user_${UserName}"};
            &LocalLogit(
                "$main::config_parms{data_dir}/logs/DSC5401.$main::Year_Month_Now.log",
                "$cmd $EventMsg{$cmd} User $UserName ($UserNum) opening partition $PartName ($PartNum)"
            );
            set $self "user opening";
            $self->{user_name}         = "$UserName";
            $self->{user_id}           = $UserNum;
            $self->{partition_now_cmd} = $cmd;
            $self->{partition_now_msg} =
              "User $UserName  opening partition $PartName";
            $self->{partition_now_status} = "user opening";
            $self->{partition_now}        = "$PartNum";
        }
        elsif ( $cmd == 751 )
        {    # Special opening (probably via computer command)
            my $PartName = my $PartNum = $data;
            $PartName = $main::config_parms{"DSC_5401_part_${PartName}"}
              if exists $main::config_parms{"DSC_5401_part_${PartName}"};
            &LocalLogit(
                "$main::config_parms{data_dir}/logs/DSC5401.$main::Year_Month_Now.log",
                "$cmd $EventMsg{$cmd} Misterhouse or Anonymous doing spartial closing on partition $PartName ($PartNum)"
            );
            set $self "special opening";
            $self->{user_name}         = "Misterhouse or Anonymous";
            $self->{user_id}           = "0000";
            $self->{partition_now_cmd} = $cmd;
            $self->{partition_now_msg} =
              "Misterhouse or Anonymous opening partition $PartName";
            $self->{partition_now_status} = "special opening";
            $self->{partition_now}        = "$PartNum";
        }
        elsif ( $cmd == 810 ) {    # Phone line 1 open or short condition
            &LocalLogit(
                "$main::config_parms{data_dir}/logs/DSC5401.$main::Year_Month_Now.log",
                "$cmd $EventMsg{$cmd} Phone line 1 is in open or short condition"
            );
            set $self "phone line 1 trouble";
        }
        elsif ( $cmd == 811 ) {    # Phone line 1 trouble restored
            &LocalLogit(
                "$main::config_parms{data_dir}/logs/DSC5401.$main::Year_Month_Now.log",
                "$cmd $EventMsg{$cmd} Phone line 1 trouble is restored"
            );
            set $self "phone line 1 restored";
        }
        elsif ( $cmd == 812 ) {    # Phone line 2 open or short condition
            &LocalLogit(
                "$main::config_parms{data_dir}/logs/DSC5401.$main::Year_Month_Now.log",
                "$cmd $EventMsg{$cmd} Phone line 2 is in open or short condition"
            );
            set $self "phone line 2 trouble";
        }
        elsif ( $cmd == 813 ) {    # Phone line 2 trouble restored
            &LocalLogit(
                "$main::config_parms{data_dir}/logs/DSC5401.$main::Year_Month_Now.log",
                "$cmd $EventMsg{$cmd} Phone line 2 trouble is restored"
            );
            set $self "phone line 2 restored";
        }
        elsif ( $cmd == 831 ) {    # Trouble With Escort module
            my $PartName = my $PartNum = $data;
            $PartName = $main::config_parms{"DSC_5401_part_${PartName}"}
              if exists $main::config_parms{"DSC_5401_part_${PartName}"};
            &LocalLogit(
                "$main::config_parms{data_dir}/logs/DSC5401.$main::Year_Month_Now.log",
                "$cmd $EventMsg{$cmd} System report trouble with Escort"
            );
            &::print_log(
                "$EventMsg{$cmd}:   System report trouble with Escort module");
        }
        elsif ( $cmd == 832 ) {    # Escort trouble restored
            my $PartName = my $PartNum = $data;
            $PartName = $main::config_parms{"DSC_5401_part_${PartName}"}
              if exists $main::config_parms{"DSC_5401_part_${PartName}"};
            &LocalLogit(
                "$main::config_parms{data_dir}/logs/DSC5401.$main::Year_Month_Now.log",
                "$cmd $EventMsg{$cmd} System trouble with Escort restored"
            );
            &::print_log("$EventMsg{$cmd}:   Escort module trouble restored");
        }
        elsif ( $cmd == 840 ) {    # Trouble Status (trouble on system)
            my $PartName = my $PartNum = $data;
            $PartName = $main::config_parms{"DSC_5401_part_${PartName}"}
              if exists $main::config_parms{"DSC_5401_part_${PartName}"};
            &LocalLogit(
                "$main::config_parms{data_dir}/logs/DSC5401.$main::Year_Month_Now.log",
                "$cmd $EventMsg{$cmd} System report trouble on partition $PartName"
            );
            &::print_log(
                "$EventMsg{$cmd}:   System report trouble on partition $PartName"
            );
        }
        elsif ( $cmd == 841 ) {  # Trouble Status Restore (No trouble on system)
            my $PartName = my $PartNum = $data;
            $PartName = $main::config_parms{"DSC_5401_part_${PartName}"}
              if exists $main::config_parms{"DSC_5401_part_${PartName}"};
            &LocalLogit(
                "$main::config_parms{data_dir}/logs/DSC5401.$main::Year_Month_Now.log",
                "$cmd $EventMsg{$cmd} System report no trouble on partition $PartName"
            );
            print(
                "$EventMsg{$cmd}:   System report no trouble on partition $PartName\n"
            );
        }
        else {
            &main::print_log(
                "DSC5401:check_for_data  Undefined command [$cmd] received via $CmdStr"
            );
        }
    }
    else {
        &main::print_log(
            "DSC5401:check_for_data  Invalid checksum from $CmdStr ($CalcChecksum)"
        );
    }
    return;
}

=item C<LocalLogit>

local logit call

=cut

sub LocalLogit {
    my $file = shift;
    my $str  = shift;
    &::logit( "$file", "$str" );
    my $Timestamp = &::time_date_stamp(16);
    $str =~ s/  +/ /;
    unshift @{ $Self->{Log} }, "$Timestamp: $str" if $str !~ /Temperature/;
    pop @{ $Self->{Log} } if scalar( @{ $Self->{Log} } ) > 60;

}

=item C<IsChecksumOK>

Validate if checksum is OK, from the string receive

=cut

sub IsChecksumOK {
    my $DscStr   = shift;
    my $ll       = length($DscStr);
    my $CksValue = substr( $DscStr, -2 );

    $CalcChecksum = DoChecksum($DscStr);

    #&main::print_log("DSC5401:IsChecksumOK   DscString=[$DscStr] CksValue=[$CksValue] CksCalc=[$CalcChecksum]") if ( $DscStr && $main::config_parms{debug} eq 'DSC5401');
    return 1 if $CksValue eq $CalcChecksum;
    return 0;
}

=item C<ResetDscState>

Reset DSC state to simulate a "now" on some value ie: zone, temp etc.

=cut

sub ResetDscState {

    # reset zone
    my $self = $Self;
    if ( defined $self->{zone_now} ) {
        my $ZoneNum = $self->{zone_now};
        $self->{zone}{$ZoneNum}        = $self->{zone_now};
        $self->{zone_cmd}{$ZoneNum}    = $self->{zone_now_cmd};
        $self->{zone_msg}{$ZoneNum}    = $self->{zone_now_msg};
        $self->{zone_status}{$ZoneNum} = $self->{zone_now_status};
        $self->{zone_time}{$ZoneNum}   = &::time_date_stamp( 17, time );
        $self->{zone_epoch}{$ZoneNum}  = time;
        undef $self->{zone_now};
        undef $self->{zone_now_msg};
        undef $self->{zone_now_status};
        undef $self->{zone_now_alarm};
        undef $self->{zone_now_fault};
        undef $self->{zone_now_fault_restore};
        undef $self->{zone_now_open};
        undef $self->{zone_now_restore};
        undef $self->{zone_now_tamper};
        undef $self->{zone_now_tamper_restore};
    }

    # reset partition
    for ( 1 .. 8 ) {
        if ( defined $self->{partition_now} ) {
            my $PartNum = $self->{partition_now};
            $self->{partition}{$PartNum}        = $self->{partition_now};
            $self->{partition_cmd}{$PartNum}    = $self->{partition_now_cmd};
            $self->{partition_msg}{$PartNum}    = $self->{partition_now_msg};
            $self->{partition_status}{$PartNum} = $self->{partition_now_status};
            $self->{partition_time}{$PartNum}  = &::time_date_stamp( 17, time );
            $self->{partition_epoch}{$PartNum} = time;
            undef $self->{partition_now};
            undef $self->{partition_now_cmd};
            undef $self->{partition_now_msg};
            undef $self->{partition_now_modE};
            undef $self->{partition_now_status};
        }
    }

    # reset ring
    if ( defined $self->{ring_now} ) {
        $self->{ring_time} = &::time_date_stamp( 17, time );
        $self->{ring_epoch} = time;
    }

    # reset thermostat
    if ( defined $self->{ExtTstatTemp_now} ) {
        undef $self->{ExtTstatTemp_now};
        undef $self->{ExtTstatTemp_now_number};
    }
    if ( defined $self->{IntTstatTemp_now} ) {
        undef $self->{IntTstatTemp_now};
        undef $self->{IntTstatTemp_now_number};
    }
    return;
}

=item C<DoChecksum>

calculate checksum

=cut

sub DoChecksum {
    my $Str = shift;    # expect to receive string with checksum value included
    my $CKStmp;
    my $CKStmp2;
    for ( my $i = 0; $i < length($Str) - 2; $i++ ) {
        $CKStmp2 = unpack( "C", substr( $Str, $i, 1 ) );
        $CKStmp += $CKStmp2;
    }
    return uc substr( unpack( "H*", pack( "N", $CKStmp ) ), -2 );
}

=item C<DefineEventMsg>

Define hash with DSC message event

=cut

sub DefineEventMsg {

    %EventMsg = (
        "000" => "Poll                                     "
        ,    # Application originated command
        "001" => "Status Report                            ",    #         |
        "010" => "Set Date and Time                        ",    #        \ /
        "020" => "Command Output Control                   ",
        "030" => "Partition Arm Control                    ",
        "031" => "Partition Arm Control - Stay Arm         ",
        "032" => "Partition Arm Control - Zero Entry Delay ",
        "033" => "Partition Arm Control - With Code        ",
        "040" => "Partition Disarm Control                 ",
        "050" => "Verbose Arming Control                   ",
        "055" => "Time Stamp Control                       ",
        "056" => "Time Broadcast Control                   ",
        "057" => "Temperature Broadcast Control            ",
        "060" => "Trigger Panic Alarm                      ",
        "200" => "Code Send                                ",
        "500" => "Command Acknowledge                      "
        ,    # PC5401 Originated Command
        "501" => "Command Error                            ",    #        |
        "502" => "System Error                             ",    #       \ /
        "550" => "Time/Date Broadcast                      ",
        "560" => "Ring Detected                            ",
        "561" => "Indoor Temperature Broadcast             ",
        "562" => "Outdoor Temperature Broadcast            ",
        "601" => "Zone Alarm                               ",
        "602" => "Zone Alarm Restore                       ",
        "603" => "Zone Tamper                              ",
        "604" => "Zone Tamper Restore                      ",
        "605" => "Zone Fault                               ",
        "606" => "Zone Fault Restore                       ",
        "609" => "Zone Open                                ",
        "610" => "Zone Restored                            ",
        "620" => "Duress Alarm                             ",
        "621" => "Fire Key Alarm                           ",
        "622" => "Fire Key Restore                         ",
        "623" => "Auxiliairy Key Alarm                     ",
        "624" => "Auxiliairy Key Restore                   ",
        "625" => "Panic Key Alarm                          ",
        "626" => "Panic Key Restore                        ",
        "631" => "2-Wire Smoke Alarm                       ",
        "632" => "2-Wire Smoke Restore                     ",
        "650" => "Partition Ready                          ",
        "651" => "Partition Not Ready                      ",
        "652" => "Partition Armed                          ",
        "654" => "Partition in Alarm                       ",
        "655" => "Partition Disarmed                       ",
        "656" => "Exit Delay in Progress                   ",
        "657" => "Entry Delay in Progress                  ",
        "658" => "Keypad Lock-Out                          ",
        "670" => "Invalid Code Access                      ",
        "671" => "Function Not Available                   ",
        "700" => "User Closing                             ",
        "701" => "Special Closing                          ",
        "702" => "Partial Closing                          ",
        "750" => "User Opening                             ",
        "751" => "Special Opening                          ",
        "800" => "Panel Battery Trouble                    ",
        "801" => "Panel Battery Trouble Restore            ",
        "802" => "Panel AC Trouble                         ",
        "803" => "Panel AC Restore                         ",
        "806" => "System Bell Trouble                      ",
        "807" => "System Bell Trouble Restoral             ",
        "810" => "TLM Trouble                              ",
        "811" => "TLM Trouble Restore                      ",
        "812" => "TLM Trouble Line 2                       ",
        "813" => "TLM Trouble Restore Line 2               ",
        "814" => "FTC Trouble                              ",
        "816" => "Buffer Near Full                         ",
        "821" => "Device Low Battery                       ",
        "822" => "Device Low Battery Restore               ",
        "825" => "Wireless Key Low Battery Trouble         ",
        "826" => "Wireless Key Low Battery Trouble Restore ",
        "827" => "Handheld Keypad Low Battery Alarm        ",
        "828" => "Handheld Keypad Low Battery Alarm Restore",
        "829" => "General System Tamper                    ",
        "830" => "General System Tamper Restore            ",
        "831" => "Home Automation Trouble                  ",
        "832" => "Home Automation Trouble Restore          ",
        "840" => "Trouble Status                           ",
        "841" => "Trouble Status Restore                   ",
        "842" => "Fire Trouble Alarm                       ",
        "843" => "Fire Trouble Alarm Restore               ",
        "900" => "Code Required                            "
    );
    return;
}

=item C<DefineCmdMsg>

Define hash with DSC command

=cut

sub DefineCmdMsg {

    %CmdMsg = (
        "Poll"                              => "000",
        "StatusReport"                      => "001",
        "SetDateTime"                       => "010",
        "CommandOutputControl"              => "020",
        "PartitionArmControl"               => "030",
        "PartitionArmControlStayArm"        => "031",
        "PartitionArmControlZeroEntryDelay" => "032",
        "PartitionArmControlWithCode"       => "033",
        "PartitionDisarmControl"            => "040",
        "VerboseArmingControl"              => "050",
        "TimeStampControl"                  => "055",
        "TimeBroadcastControl"              => "056",
        "TemperatureBroadcastControl"       => "057",
        "TriggerPanicAlarm"                 => "060",
        "CodeSend"                          => "200"
    );

    %CmdMsgRev = reverse %CmdMsg;
    return;
}

=item C<DefineErrorCode>

Define hash with DSC command error code

=cut

sub DefineErrorCode {

    %ErrorCode = (
        "000" => "No Error",
        "001" => "RS-232 Receive Buffer Overrun",
        "002" => "RS-232 Receive Buffer Overflow",
        "003" => "Keybus Transmit Buffer Overrun",
        "010" => "Keybus Transmit Buffer Overrun",
        "011" => "Keybus Transmit Time Timeout",
        "012" => "Keybus Transmit Mode Timeout",
        "013" => "Keybus Transmit Keystring Timeout",
        "014" => "Keybus Not Functioning",
        "015" => "Keybus Busy (attempting arm or disarm)",
        "016" => "Keybus Busy - Lockout (too many disarms)",
        "017" => "Keybus Busy - Installers Mode",
        "020" => "API Command Syntax Error",
        "021" => "API Command Partition Error (partition out of bound)",
        "022" => "API Command Not Supported",
        "023" => "API System Not Armed",
        "024" => "API System Not Ready To Arm",
        "025" => "API Command Invalid Length",
        "026" => "API User Code not Required",
        "027" => "API Invalid Characters in Command"
    );

    return;
}

=item C<ZoneName>

read the zone name and put name in hash

=cut

sub ZoneName {

    #my $self = $Self;
    my @Name = ["none"];

    foreach my $key ( keys(%::config_parms) ) {
        next if $key =~ /_MHINTERNAL_/;
        next if $key !~ /^DSC_5401_zone_(\d+)$/;
        $Name[ int($1) ] = $::config_parms{$key};
    }
    return @Name;
}

=item C<cmd>

Sending command to DSC panel

=cut

sub cmd {

    my ( $class, $cmd, @arg_array ) = @_;
    my $arg = join( '', @arg_array );
    $arg = 1             if ( $arg eq 'on' );
    $arg = 0             if ( $arg eq 'off' );
    $cmd = $CmdMsg{$cmd} if ( length($cmd) > 3 );

    my $CmdStr = $cmd . $arg;
    $CmdStr .= DoChecksum( $CmdStr . "00" );
    my $CmdName;
    $CmdName = ( exists $CmdMsgRev{$cmd} ) ? $CmdMsgRev{$cmd} : "unknown";

    if ( $CmdName =~ /^unknown/ ) {
        &::print_log(
            "Invalid DSC panel command : $CmdName ($cmd) with argument $arg");
        return;
    }

    if ( $cmd eq "033" || $cmd eq "040" ) {    # we don't display password
        &::print_log("Sending to DSC panel     $CmdName ($cmd)");
        &LocalLogit(
            "$main::config_parms{data_dir}/logs/DSC5401.$main::Year_Month_Now.log",
            ">>> Sending to DSC panel                      $CmdName ($cmd)"
        );
        $main::Serial_Ports{DSC5401}{object}->write("$CmdStr\r\n");
        return "Sending to DSC panel: $CmdName ($cmd)";
    }
    else {
        &::print_log(
            "Sending to DSC panel     $CmdName ($cmd) with argument ($arg)");
        &LocalLogit(
            "$main::config_parms{data_dir}/logs/DSC5401.$main::Year_Month_Now.log",
            ">>> Sending to DSC panel                      $CmdName ($cmd) with argument ($arg)  [$CmdStr]"
        );
        $main::Serial_Ports{DSC5401}{object}->write("$CmdStr\r\n");
        return "Sending to DSC panel: $CmdName ($cmd) with argument ($arg)";
    }

}

#}}}
#    user call from MH                                                         {{{
# most of them are replicate to hash value, easier to code

sub zone_now {
    return $_[0]->{zone_now} if defined $_[0]->{zone_now};
}

sub zone_msg {
    return $_[0]->{zone_now_msg} if defined $_[0]->{zone_now_msg};
}

sub zone_now_open {
    return $_[0]->{zone_now_open} if defined $_[0]->{zone_now_open};
}

sub zone_now_restore {
    return $_[0]->{zone_now_restore} if defined $_[0]->{zone_now_restore};
}

sub zone_now_tamper {
    return $_[0]->{zone_now_tamper} if defined $_[0]->{zone_now_tamper};
}

sub zone_now_tamper_restore {
    return $_[0]->{zone_now_tamper_restore}
      if defined $_[0]->{zone_now_tamper_restore};
}

sub zone_now_alarm {
    return $_[0]->{zone_now_alarm} if defined $_[0]->{zone_now_alarm};
}

sub zone_now_alarm_restore {
    return $_[0]->{zone_now_alarm_restore}
      if defined $_[0]->{zone_now_alarm_restore};
}

sub zone_now_fault {
    return $_[0]->{zone_now_fault} if defined $_[0]->{zone_now_fault};
}

sub zone_now_fault_restore {
    return $_[0]->{zone_now_fault_restore}
      if defined $_[0]->{zone_now_fault_restore};
}

sub status_zone {
    my ( $class, $zone ) = @_;
    return $_[0]->{zone_status}{$zone} if defined $_[0]->{zone_status}{$zone};
}

sub zone_name {
    my ( $class, $zone_num ) = @_;
    $zone_num = sprintf "%03s", $zone_num;
    my $ZoneName = $main::config_parms{"DSC_5401_zone_$zone_num"}
      if exists $main::config_parms{"DSC_5401_zone_$zone_num"};
    return $ZoneName if $ZoneName;
    return $zone_num;
}

sub partition_now {
    my ( $class, $part ) = @_;
    return $_[0]->{partition_now} if defined $_[0]->{partition_now};
}

sub partition_now_msg {
    my ( $class, $part ) = @_;
    return $_[0]->{partition_now_msg} if defined $_[0]->{partition_now_msg};
}

sub partition_name {
    my ( $class, $part_num ) = @_;
    my $PartName = $main::config_parms{"DSC_5401_part_$part_num"}
      if exists $main::config_parms{"DSC_5401_part_$part_num"};
    return $PartName if $PartName;
    return $part_num;
}

sub user_name {
    return $_[0]->{user_name} if defined $_[0]->{user_name};
}

sub user_id {
    return $_[0]->{user_id} if defined $_[0]->{user_id};
}

sub IntTstat {
    my ( $class, $TstatNum ) = @_;
    return $_[0]->{IntTstatTemp}{$TstatNum}, $_[0]->{IntTstatTime}{$TstatNum},
      $_[0]->{IntTstatEpoch}{$TstatNum}
      if defined $_[0]->{IntTstatTemp};
    return -999;
}

sub ExtTstat {
    my ( $class, $TstatNum ) = @_;
    return $_[0]->{ExtTstatTemp}{$TstatNum}, $_[0]->{ExtTstatTime}{$TstatNum},
      $_[0]->{ExtTstatEpoch}{$TstatNum}
      if defined $_[0]->{ExtTstatTemp};
    return -999;
}

sub cmd_list {
    foreach my $k ( sort keys %CmdMsg ) {
        &::print_log("$k");
    }
}

=item C<set_clock>

This method copied from Gaeton's example DSC_Clock.pl code.  I recommend that this be run every day at 3am to keep the clock synchronized and also to correct for daylight saving time.

=cut

sub set_clock {
    my ($self) = @_;

    my ( $sec, $m, $h, $mday, $mon, $year, $wday, $yday, $isdst ) =
      localtime(time);
    $year = sprintf( "%02d", $year % 100 );
    $mon += 1;
    $m    = ( $m < 10 )    ? "0" . $m    : $m;
    $h    = ( $h < 10 )    ? "0" . $h    : $h;
    $mday = ( $mday < 10 ) ? "0" . $mday : $mday;
    $mon  = ( $mon < 10 )  ? "0" . $mon  : $mon;
    my $TimeStamp = "$h$m$mon$mday$year";
    &::print_log("Setting time on DSC panel to $TimeStamp");
    &::logit(
        "$main::config_parms{data_dir}/logs/DSC5401.$main::Year_Month_Now.log",
        "Setting time on DSC panel to $TimeStamp"
    );
    $self->cmd( "SetDateTime", $TimeStamp );
}

1;

#}}}
#$Log:$

__END__


#log message 

#When misterhouse start
Thu 01/13/2005 13:18:55 DSC5401.pm Initialized


# when we enable temperature broadcast
Thu 01/13/2005 13:23:31 Sending to DSC panel: TemperatureBroadcastControl (057) with argument (1)  [0571CD]
Thu 01/13/2005 13:23:31 Command Acknowledge:   TemperatureBroadcastControl

# when we disable temparature broadcast
Thu 01/13/2005 13:24:17 Sending to DSC panel: TemperatureBroadcastControl (057) with argument (0)  [0570CC]
Thu 01/13/2005 13:24:17 Command Acknowledge:   TemperatureBroadcastControl

# when we receive broadcast from temperature sensor
Thu 01/13/2005 13:19:18 Indoor Temperature Broadcast:   Thermostat:1  Temp:021
Thu 01/13/2005 13:19:18 Outdoor Temperature Broadcast:   Thermostat:1  Temp:122

# when we enable time broadcast
Thu 01/13/2005 13:33:49 Sending to DSC panel: TimeBroadcastControl (056) with argument (1)  [0560CB]
Thu 01/13/2005 13:33:49 Command Acknowledge:   TimeBroadcastControl

# when we disable time broadcast
Thu 01/13/2005 13:33:49 Sending to DSC panel: TimeBroadcastControl (056) with argument (0)  [0560CB]
Thu 01/13/2005 13:33:49 Command Acknowledge:   TimeBroadcastControl

# when we receive broadcast from timestamp
Thu 01/13/2005 13:19:23 Time/Date Broadcast:   13:20 01/13/05

# when we set panel time and date
Thu 01/13/2005 13:24:58 Setting time on DSC panel to 1324011305
Thu 01/13/2005 13:24:58 Sending to DSC panel: SetDateTime (010) with argument (1324011305)  [010132401130585]
Thu 01/13/2005 13:24:58 Command Acknowledge:   SetDateTime

# when we open and close a zone (sensor, door)
Thu 01/13/2005 13:20:10 Zone Open:   Detecteur de mouvement haut (003)
Thu 01/13/2005 13:20:10 Partition Not Ready:   maison  (1)
Thu 01/13/2005 13:20:13 Zone Restored:   Detecteur de mouvement haut (003)
Thu 01/13/2005 13:20:13 Partition Ready:   maison  (1)

#when we arm in stay mode via web (no user code)
Thu 01/13/2005 13:35:22 Sending to DSC panel: PartitionArmControl (030) with argument (1)  [0301C4]
Thu 01/13/2005 13:35:22 Command Acknowledge:   PartitionArmControl
Thu 01/13/2005 13:35:22 Exit Delay in Progress:   maison  (1)
Thu 01/13/2005 13:35:32 Special Closing:   partition maison (1) by misterhouse
Thu 01/13/2005 13:35:32 Partition Armed:   maison in mode   (10)

# when we disarm the house
Thu 01/13/2005 13:38:18 Sending to DSC panel: PartitionDisarmControl (040) with argument (1####)  [0401####9D]
Thu 01/13/2005 13:38:18 Command Acknowledge:   PartitionDisarmControl
Thu 01/13/2005 13:38:19 User Opening:   partition maison (1) by user Gaetan (0040)
Thu 01/13/2005 13:38:19 Partition Disarmed:   maison  (1)
Thu 01/13/2005 13:38:24 Partition Ready:   maison  (1)



=back

=head2 INI PARAMETERS

NONE

=head2 AUTHOR

Jocelyn Brouillard
Gaetan lord           email@gaetanlord.ca

=head2 SEE ALSO

NONE

=head2 LICENSE

This program is free software; you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation; either version 2 of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more details.

You should have received a copy of the GNU General Public License along with this program; if not, write to the Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.

=cut

