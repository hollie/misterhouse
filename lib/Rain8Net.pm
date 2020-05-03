
=begin comment
@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@


Rain8Net.pm  v1.1
by Marco Maddalena (mhcoder@nowheremail.com)

Description:

Allows the control of WGL rain8Net serial sprinkler control modules
(see http://www.wgldesigns.com/rain8pc.html)
Each unit can control 8 zones, and 8 units can be daisy-chained on 1 serial connection.


Methods
  status_zone  - returns the zone status (1=on,0=off).
                 Parms:  Unit  (required) : Numeric    - Unit number
                         Zone  (required) : numeric    - Zone number



  cmd          - send Rain8Net Cmd to the unit (some function below alias these commands)
                 Parms   cmd    (required) : string     - See list
                         Unit   (optional) : numeric    - Unit number IF required by the cmd
                         Zone   (optional) : numeric    - Zone number IF required by the cmd

                 Supported commands are
                        "COMCheck"       - Check communications link. No parameters.
                        "StatusRequest"  - Request an update of zone statuses. Unit number required.
                                           (Note: automatic status request happens via RAIN8NET_AutoStatusRequestTimer value)
                        "ZoneON"         - Turn zone on. Requires unit and Zone number
                        "ZoneOFF"        - Turn zone off. Requires unit and Zone number
                        "AllModuleOFF"   - Turn all zones of a unit off. Requires unit number.
                        "AllGlobalOff"   - Turns all zones of all units. No paramters

  ZoneOn       - send the ZoneOn command to Rain8Net
                 Parms   Unit   (required) : numeric    - Unit number
                         Zone   (required) : numeric    - Zone number

  ZoneOff      - send the ZoneOff/AllUnitOff/AllGlobalOff command to Rain8Net
                 Parms   Unit   (optional) : numeric    - Unit number (if not passed, then the equivalent to AllGlobalOff is performed)
                         Zone   (optional) : numeric    - Zone number (if not passed, but unit was, the  equivalent to AllModuleOff is performed)





Examples

    use Rain8Net;
    $Rain8 = new Rain8Net;


    if (time_now("22:00"))
    {
      print_log "Sprinkler ON for unit 1, Zone 2 [" . $Rain8->get_name(1,2) . "]";
      $Rain8->cmd('ZoneON',1,2);
    }

    if (time_now("01:00"))
    {
      print_log "Sprinkler OFF for unit 1, Zone 2 [" . $Rain8->get_name(1,2) . "]";
      $Rain8->cmd('ZoneOFF',1,2);
    }

    if ((time_now("23:00")) && (Rain8->status_zone(1,5)))
    {
      print_log "Sprinkler OFF for unit 1, Zone 5 [" . $Rain8->get_name(1,5) . "]";
      $Rain8->cmd('ZoneOFF',1,5);
    }




mh.ini parameter Values

RAIN8NET_serial_port
  Required
  Serial port where Rain8Net module is connected.
  ie /dev/ttySx


RAIN8NET_Units
  Optional (default 1)
  Number of Rain8Net units linked on 1 serial connection. rain8Net support 1-8
  Valid Values: 1 - 8


RAIN8NET_AutoStatusRequestTimer
  Optional (default 30)
  Number of seconds between auto executions of StatusRequests
  Valid Values: 0 - 999999
  If 0, no automatic Status request are performed.


RAIN8NET_unit_[U]_zone_[Z]
  Optional (no default)
  String name of a Unit/Zone (see zone_name method)
  Allows for zones to be named. ie "RAIN8NET_unit_1_zone_2=Front Yard Sprinklers" names the zone 2 of unit 1


RAIN8NET_ModuleDebug
  Optional (default 0)
  if 1, echo debug messasges of the Rain8Net.pm module into the MH log
  Valid Values: 0,1



Notes:

This is my 1st Perl module and I am a novice, so I welcome comments and criticism but please be gentle ... I bruise easily ;)
This module was heavily derived from the DSC5401.pm module by Jocelyn Brouillard and Gaetan lord. Thanks to them


Changes

v1.0  2015-07-14  initial module construction
v1.1  2015-12-11  Fixes and more documentation


@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
=cut

use strict;

package Rain8Net;

# Rain8Net Serial parameters
use constant RAIN8NET_BAUDRATE  => 4800;
use constant RAIN8NET_DATABITS  => 8;
use constant RAIN8NET_PARITY    => "none";
use constant RAIN8NET_STOPBITS  => 1;
use constant RAIN8NET_HANDSHAKE => 'none';
use constant RAIN8NET_MAXUNITS  => 8;
use constant RAIN8NET_MAXZONES  => 8;

use constant SUBCOMMAND_STATUSREQUEST => 1;
use constant SUBCOMMAND_ZONEON        => 2;
use constant SUBCOMMAND_ZONEOFF       => 4;
use constant SUBCOMMAND_ALLUNITOFF    => 8;

@Rain8Net::ISA = ('Generic_Item');

my %CmdMsg;
my %CmdMsgRev;
my @Rain8Net_Objects = ();
my $IncompleteCmd;
my $ModuleDebug = 0;

# ---------------------------------------------------------------------------
# Method: new (public)
# Desc:  Instantiate the new object
sub new {
    my ($class) = @_;
    my $self = {};

    &main::print_log("Rain8Net.pm - MODULE DEBUG : entering [new]...") if $ModuleDebug;

    bless $self, $class;

    $$self{state}           = 'Unknown';
    $$self{said}            = '';
    $$self{MaxUnits}        = 0;
    $$self{LastCmdSent}     = '';
    $$self{LastSubCmdSent}  = -1;
    $$self{LastCmdSentUnit} = -1;
    $$self{LastCmdSentZone} = -1;
    $$self{LastResponseRaw} = '';
    $$self{LastCmdResponse} = '';
    $$self{TimerInterval}   = 0;

    # Module-level reference to self
    push @Rain8Net_Objects, $self;

    # read event message hash
    _DefineCmdMsg();

    # test if ModuleDebug is on
    $ModuleDebug = 1 if ( exists $main::config_parms{RAIN8NET_ModuleDebug} );

    &main::print_log("Rain8Net Starting interface module");

    # Call Startup to initialize serial port
    $self->startup();

    select( undef, undef, undef, 0.250 );    # wait 250 millseconds

    # We send a COMCheck, which is really a NOP.
    $self->cmd('COMCheck');                  # request an initial COMCheck

    select( undef, undef, undef, 0.250 );    # wait 250 millseconds to avoid overrunning RS-232 receive buffer on panel

    return $self;
}

# ---------------------------------------------------------------------------
# Method: _init_serial_port (private)
# Description: serial port configuration
sub _init_serial_port {
    my ( $self, $serial_port ) = @_;

    &main::print_log("Rain8Net.pm - MODULE DEBUG : entering [_init_serial_port]...") if $ModuleDebug;

    $serial_port->error_msg(1);

    $serial_port->databits(RAIN8NET_DATABITS);
    $serial_port->parity(RAIN8NET_PARITY);
    $serial_port->stopbits(RAIN8NET_STOPBITS);
    $serial_port->handshake(RAIN8NET_HANDSHAKE);
    $serial_port->datatype('raw');
    $serial_port->dtr_active(1);
    $serial_port->rts_active(1);

    $serial_port->debug(1) if ( $ModuleDebug eq 1 );

    select( undef, undef, undef, .100 );    # Sleep a bit
}

# ---------------------------------------------------------------------------
# Method: startup (public)
# Description: Called by MH on startup
sub startup {
    my ($self) = @_;

    &main::print_log("Rain8Net.pm - MODULE DEBUG : entering [_startup]...") if $ModuleDebug;

    my $port;

    if ( $::config_parms{'RAIN8NET_serial_port'} ) {
        $port = $::config_parms{'RAIN8NET_serial_port'};
        &main::print_log( "Rain8Net.pm - MODULE DEBUG : mh.ini [RAIN8NET_serial_port] read, value is [" . $port . "]" ) if ($ModuleDebug);
        if ( not( -c "$port" ) ) {
            &main::print_log( "Rain8Net.pm Error : Invalid port [" . $port . "] defined in mh.ini [RAIN8NET_serial_port]. Cannot create object." );
            $$self{state} = "Error";
            return;
        }
    }
    else {
        &main::print_log("Rain8Net.pm Error : Port not defined in mh.ini [RAIN8NET_serial_port]. Cannot create object.");
        $$self{state} = "Error";
        return;
    }

    # If here, validate other settings
    $$self{MaxUnits} = ( defined $::config_parms{RAIN8NET_Units} ) ? $main::config_parms{RAIN8NET_Units} : 1;
    if ( ( ( $$self{MaxUnits} + 0 ) eq $$self{MaxUnits} ) && ( ( $$self{MaxUnits} + 0 ) => 1 ) && ( ( $$self{MaxUnits} + 0 ) <= RAIN8NET_MAXUNITS ) ) {
        $$self{MaxUnits} = ( $$self{MaxUnits} + 0 );    # convert numeric
        &main::print_log( "Rain8Net.pm - MODULE DEBUG : mh.ini [RAIN8NET_Units] read, value is [" . $$self{MaxUnits} . "]" ) if ($ModuleDebug);
    }
    else {
        &main::print_log("Rain8Net.pm Error : Invalid value for mh.ini [RAIN8NET_Units], ignoring and setting to 1");
        $$self{MaxUnits} = 1;
    }

    # initialize state of all units/zones as off
    for ( my $j = 1; $j <= $$self{MaxUnits}; $j++ ) {
        for ( my $i = 1; $i <= RAIN8NET_MAXZONES; $i++ ) {
            $$self{zone_status}{$j}{$i} = 0;
        }
    }

    # create the Serial port item
    if ( &main::serial_port_create( 'Rain8Net', $port, RAIN8NET_BAUDRATE, 'none', 'raw' ) ) {
        $self->_init_serial_port( $::Serial_Ports{Rain8Net}{object}, $port );
        &main::print_log( "Rain8Net.pm initializing port $port at " . RAIN8NET_BAUDRATE . " baud" ) if $ModuleDebug;
        &::MainLoop_pre_add_hook( \&Rain8Net::_check_for_data, 1 ) if $main::Serial_Ports{Rain8Net}{object};
        $$self{state} = "Active";
    }
    else {
        &main::print_log("Rain8Net.pm Error : Unable to open serial port [$port]. Cannot create object.");
        $$self{state} = "Error";
        return;
    }

    # Get the Auto Status request value and validate
    my $timerinterval = ( defined $::config_parms{RAIN8NET_AutoStatusRequestTimer} ) ? $main::config_parms{RAIN8NET_AutoStatusRequestTimer} : 30;
    if ( ( ( $timerinterval + 0 ) eq $timerinterval ) && ( ( $timerinterval + 0 ) >= 0 ) && ( ( $timerinterval + 0 ) <= 9999 ) ) {
        $$self{TimerInterval} = ( $timerinterval + 0 );    # convert numeric
        &main::print_log( "Rain8Net.pm - MODULE DEBUG : mh.ini [RAIN8NET_AutoStatusRequestTimer] read, value is [" . $$self{TimerInterval} . "]" )
          if ($ModuleDebug);
    }
    else {
        &main::print_log("Rain8Net.pm Error : Invalid value for mh.ini [RAIN8NET_AutoStatusRequestTimer], ignoring and setting to 0");
        $$self{TimerInterval} = 0;
    }
}

# ---------------------------------------------------------------------------
# Method: _check_for_data (private)
# Description: hooked routine that checks data on port
sub _check_for_data {

    # &main::print_log("Rain8Net.pm - MODULE DEBUG : entering init [_check_for_data]...") if $ModuleDebug;

    $main::Serial_Ports{'Rain8Net'}{data} = '';
    &main::check_for_generic_serial_data('Rain8Net');

    #-- my $NewCmd = $main::Serial_Ports{'Rain8Net'}{data};

    my $NewCmd = $main::Serial_Ports{'Rain8Net'}{data};

    #-- $main::Serial_Ports{'Rain8Net'}{data} = '';

    &main::print_log("Rain8Net.pm - MODULE DEBUG : Received the following [$NewCmd]") if ( ($NewCmd) && ($ModuleDebug) );

    # we need to buffer the information received, because many command could be include in a single pass
    $NewCmd = $IncompleteCmd . $NewCmd if $IncompleteCmd;
    return if !$NewCmd;

    my $self = $Rain8Net_Objects[0];

    # Flush last buffered response
    $$self{LastResponseRaw} = '';

    # Rain8Net commands are 3 bytes
    if ( length($NewCmd) ge 3 ) {
        $IncompleteCmd = substr( $NewCmd, 3 );    # Keep rest of Command
        &_CheckCmd( $self, $NewCmd );
    }
}

# ---------------------------------------------------------------------------
# Method: _SetTimers (private)
# Description: set up auto status request timers for all units
sub _SetTimers {
    my ($self) = @_;

    &main::print_log("Rain8Net.pm - MODULE DEBUG : entering [_SetTimers]...") if $ModuleDebug;

    # set a timer to perform auto Statusrequest every 30
    if ( ( $$self{object_name} ) && ( $$self{TimerInterval} > 0 ) ) {
        &::print_log( "Rain8Net.pm - MODULE DEBUG : creating timer(s) for object [" . $$self{object_name} . "]" ) if $ModuleDebug;
        for ( my $count = 1; $count <= $$self{MaxUnits}; $count++ ) {
            my $timername = 'statusrequest_timer' . $count;

            if ( not( $$self{$timername} ) ) {
                &::print_log("Rain8Net.pm - MODULE DEBUG : creating timer [$timername]") if $ModuleDebug;
                $$self{$timername} = new Timer;
                $$self{$timername}->set( $$self{TimerInterval}, "$$self{object_name}->cmd('StatusRequest',$count)", -1 );
            }
        }
    }

}

# ---------------------------------------------------------------------------
# Method: _CheckCmd (private)
# Description: validate in incoming command string from the Rain8 unit and apply the data updates
sub _CheckCmd {
    my ( $self, $CmdStr ) = @_;

    my $UnitNumber  = -1;
    my $ZoneNumber  = -1;
    my $ZoneBitFlag = 0;

    &main::print_log("Rain8Net.pm - MODULE DEBUG : entering [_CheckCmd]...") if $ModuleDebug;

    &_SetTimers($self);

    &main::print_log("Rain8Net.pm - MODULE DEBUG : _CheckCmd - cmdstr is ($CmdStr)") if $ModuleDebug;

    return if !$CmdStr;

    $$self{LastResponseRaw} = $CmdStr;

    my $l       = length($CmdStr);
    my $code    = unpack( "H*", substr( $CmdStr, 0, 1 ) );
    my $arg1    = unpack( "H*", substr( $CmdStr, 1, 1 ) );
    my $arg2    = unpack( "H*", substr( $CmdStr, 2, 1 ) );
    my $hexcode = sprintf( "0x%d", $code );

    &main::print_log("Rain8Net.pm - MODULE DEBUG :  _CheckCmd Raw input is [$code] [$arg1] [$arg2], length [$l]") if $ModuleDebug;

    # test received command is valid
    if ( not( exists $CmdMsgRev{$hexcode} ) ) {
        &::print_log("Unknown rain8Net response code recieved : code [$code] with arguments [$arg1] , [$arg2]");
        $$self{LastSubCmdSent} = 0;
        return;
    }

    my $CmdName;

    # Since StatusRequest and ZoneOn and ZoneOFF all return the same god-damn 40 hex, use our flag
    if ( ( $hexcode eq "0x40" ) && ( $$self{LastSubCmdSent} eq SUBCOMMAND_STATUSREQUEST ) ) {
        $CmdName = "StatusRequest";
    }
    elsif ( ( $hexcode eq "0x40" ) && ( $$self{LastSubCmdSent} eq SUBCOMMAND_ZONEON ) ) {
        $CmdName = "ZoneON";
    }
    elsif ( ( $hexcode eq "0x40" ) && ( $$self{LastSubCmdSent} eq SUBCOMMAND_ZONEOFF ) ) {
        $CmdName = "ZoneOFF";
    }
    elsif ( ( $hexcode eq "0x40" ) && ( $$self{LastSubCmdSent} eq SUBCOMMAND_ALLUNITOFF ) ) {
        $CmdName = "AllModuleOFF";
    }
    else {
        $CmdName = ( $CmdMsgRev{$hexcode} );
    }

    &main::print_log( "Rain8Net.pm - MODULE DEBUG : _CheckCmd Command recived is = [" . $CmdName . "]" ) if $ModuleDebug;

    # At this point process the response...--------------

    # If Status request response, the last  byte is a bit pattern of active zones
    if ( $CmdName eq "StatusRequest" ) {
        $UnitNumber  = hex($arg1);
        $ZoneBitFlag = hex($arg2);
        my $match = 1;
        for ( my $i = 1; $i <= RAIN8NET_MAXZONES; $i++ ) {
            $$self{zone_status}{$UnitNumber}{$i} = ( $ZoneBitFlag & $match ) ? 1 : 0;
            $match = $match << 1;
        }
    }

    # Echo from ZoneOFF
    if ( $CmdName eq "ZoneOFF" ) {
        $UnitNumber = hex($arg1);
        my $UpperNible = hex($arg2) & hex('0x40');
        my $LowerNible = hex($arg2) & hex('0x08');

        &main::print_log("Rain8Net.pm - MODULE DEBUG : sub _checkCmd - ZONE OFF, Unit [$UnitNumber], uppernibble [$UpperNible], lowerninble [$LowerNible]")
          if $ModuleDebug;

        $$self{zone_status}{$UnitNumber}{$LowerNible} = 0;
    }

    # Echo from ZoneON
    if ( $CmdName eq "ZoneON" ) {
        $UnitNumber = hex($arg1);
        my $UpperNible = hex($arg2) & hex("0x30");
        my $LowerNible = hex($arg2) & hex('0x08');

        &main::print_log("Rain8Net.pm - MODULE DEBUG : sub _checkCmd - ZONE ON, Unit [$UnitNumber], uppernibble [$UpperNible], lowerninble [$LowerNible]")
          if $ModuleDebug;

        $$self{zone_status}{$UnitNumber}{$LowerNible} = 1;
    }

    # Echo from AllModuleOff
    if ( $CmdName eq "AllModuleOFF" ) {
        $UnitNumber = hex($arg1);

        if ( hex($arg2) eq hex("0x55") ) {
            for ( my $i = 1; $i <= RAIN8NET_MAXZONES; $i++ ) {
                $$self{zone_status}{$UnitNumber}{$i} = 0;
            }
        }
    }

    # Dump debug
    if ( ($ModuleDebug) && ( $UnitNumber >= 1 ) ) {
        &main::print_log("Rain8Net.pm - MODULE DEBUG : _CheckCmd dump status -->");
        for ( my $i = 1; $i <= RAIN8NET_MAXZONES; $i++ ) {
            &main::print_log( "         Unit [$UnitNumber], zone [$i] is [" . ( $$self{zone_status}{$UnitNumber}{$i} ) . "]" );
        }
    }

    # Reset the last subcommand
    $$self{LastSubCmdSent} = 0;

    return;
}

#}}}
#    Define hash with DSC command                                           {{{
sub _DefineCmdMsg {

    &main::print_log("Rain8Net.pm - MODULE DEBUG : entering [_DefineCmdMsg]...") if $ModuleDebug;

    %CmdMsg = (
        lc("COMCheck")              => "0x70",
        lc("StatusRequest")         => "0x40",
        lc("ZoneON")                => "0x40",
        lc("ZoneOFF")               => "0x40",
        lc("AllModuleOFF")          => "0x40",
        lc("AllGlobalOFF")          => "0x20",
        lc("ReadRainSwitchStatus")  => "0x50",
        lc("ReadFlowMeterCounter")  => "0x50",
        lc("ClearFlowMeterCounter") => "0x50"
    );

    %CmdMsgRev = reverse %CmdMsg;
    return;
}

#}}}
#    Sending command to Rain8Net
sub cmd {

    my ( $self, $cmd, $arg1, $arg2 ) = @_;
    my $CmdName;

    if ($ModuleDebug) {
        &main::print_log("Rain8Net.pm - MODULE DEBUG : entering [cmd]...");
        &main::print_log( "Rain8Net.pm - MODULE DEBUG : sub cmd - cmd  is [" . $cmd . "]" );
        &main::print_log( "Rain8Net.pm - MODULE DEBUG : sub cmd - arg1 is [" . $arg1 . "]" );
        &main::print_log( "Rain8Net.pm - MODULE DEBUG : sub cmd - arg2 is [" . $arg2 . "]" );
    }

    $cmd = lc($cmd);
    if ( not( exists $CmdMsg{$cmd} ) ) {
        &::print_log("Rain8Net.pm ERROR - Invalid command : ($cmd) with arguments $arg1 , $arg2");
        return;
    }

    my $CmdByte    = hex( $CmdMsg{$cmd} );
    my $CmdStr     = chr($CmdByte);
    my $UnitNumber = 0;
    my $ZoneNumber = 0;

    if ( $cmd eq lc("COMCheck") ) {

        # pad command with 2 extra bytes, does not matter which
        $CmdStr .= "xx";
    }
    elsif ( $cmd eq lc("StatusRequest") ) {
        $UnitNumber = $self->_ConvertUnit( $cmd, $arg1 );
        return if ( $UnitNumber lt 0 );

        # Second arg is "all status code"
        $CmdStr .= chr( hex( "0x0" . $UnitNumber ) ) . chr( hex("0xf0") );
        $$self{LastSubCmdSent} = SUBCOMMAND_STATUSREQUEST;
    }
    elsif ( $cmd eq lc("ZoneON") ) {
        $UnitNumber = $self->_ConvertUnit( $cmd, $arg1 );
        return if ( $UnitNumber lt 0 );

        $ZoneNumber = $self->_ConvertZone( $cmd, $arg2 );
        return if ( $ZoneNumber lt 0 );

        # Second arg is 3 upper nibble, zone - lower nibble
        $CmdStr .= chr( hex( "0x0" . $UnitNumber ) ) . chr( hex( "0x3" . "$ZoneNumber" ) );
        $$self{LastSubCmdSent} = SUBCOMMAND_ZONEON;
        $$self{zone_status}{$UnitNumber}{$ZoneNumber} = 1;
    }
    elsif ( $cmd eq lc("ZoneOFF") ) {
        $UnitNumber = $self->_ConvertUnit( $cmd, $arg1 );
        return if ( $UnitNumber lt 0 );

        $ZoneNumber = $self->_ConvertZone( $cmd, $arg2 );
        return if ( $ZoneNumber lt 0 );

        # Second arg is 4 upper nibble, zone - lower nibble
        $CmdStr .= chr( hex( "0x0" . $UnitNumber ) ) . chr( hex( "0x4" . "$ZoneNumber" ) );
        $$self{LastSubCmdSent} = SUBCOMMAND_ZONEOFF;
        $$self{zone_status}{$UnitNumber}{$ZoneNumber} = 0;
    }
    elsif ( $cmd eq lc("AllModuleOFF") ) {
        $UnitNumber = $self->_ConvertUnit( $cmd, $arg1 );
        return if ( $UnitNumber lt 0 );

        $CmdStr .= chr( hex( "0x0" . $UnitNumber ) ) . chr( hex("0x55") );
        $$self{LastSubCmdSent} = SUBCOMMAND_ALLUNITOFF;
        for ( my $i = 1; $i <= RAIN8NET_MAXZONES; $i++ ) {
            $$self{zone_status}{$UnitNumber}{$i} = 0;
        }

    }
    elsif ( $cmd eq lc("AllGlobalOff") ) {
        $$self{LastSubCmdSent} = 0;
        $CmdStr .= chr( hex("0x55") ) . chr( hex("0x55") );
        for ( my $i = 1; $i <= $$self{MaxUnits}; $i++ ) {
            for ( my $j = 1; $j <= RAIN8NET_MAXZONES; $j++ ) {
                $$self{zone_status}{$i}{$j} = 0;
            }
        }
    }

    #  &::print_log("Sending to Rain8Net panel     ($cmd) with argument ($arg1, $arg2)");
    &main::print_log( "Rain8Net.pm - MODULE DEBUG : sub cmd  - Writing (" . $CmdStr . ")" ) if $ModuleDebug;
    if ( $main::Serial_Ports{Rain8Net}{object}->write($CmdStr) ) {
        &main::print_log( "Rain8Net.pm - MODULE DEBUG : sub cmd  - Command (" . $CmdStr . ") successfully written to serial port." ) if $ModuleDebug;
        $$self{LastCmdSent}     = $cmd;
        $$self{LastCmdSentUnit} = $UnitNumber;
        $$self{LastCmdSentZone} = $ZoneNumber;
    }

    return "Sent to Rain8Net panel: ($cmd) with argument ($arg1,$arg2) - Successful";

}

#}}}
# validate and Convert Unit Number to value
sub _ConvertUnit {
    my ( $self, $cmd, $Unit ) = @_;

    my $UnitNumber = $Unit + 0;
    if ( ( $UnitNumber >= 1 ) && ( $UnitNumber <= $$self{MaxUnits} ) ) {

        # $UnitNumber is in the range
        return ($UnitNumber);
    }
    else {
        &::print_log("Rain8Net Error - Invalid Unit number on command : [$cmd], Unit [$Unit]");
        return -1;
    }
}

#}}}
# validate and Convert Zone Number to numeric value.
# retrun -1 if invalid
sub _ConvertZone {

    my ( $self, $cmd, $Zone ) = @_;

    my $ZoneNumber = $Zone + 0;

    if ( ( $ZoneNumber >= 1 ) && ( $ZoneNumber <= RAIN8NET_MAXZONES ) ) {

        # $ZoneNumber is in the range
        return ($ZoneNumber);
    }
    else {
        &::print_log("Rain8Net Error - Invalid zone number on command : [$cmd], zone [$Zone])");
        return -1;
    }
}

#}}}
#    user call from MH                                                         {{{
# most of them are replicate to hash value, easier to code

sub status_zone {
    my ( $self, $unit, $zone ) = @_;

    &main::print_log("Rain8Net.pm - MODULE DEBUG : entering [status_zone]...") if $ModuleDebug;

    my $UnitNumber = $self->_ConvertUnit( "method: status_zone", $unit );
    return -1 if ( $UnitNumber < 1 );

    my $ZoneNumber = $self->_ConvertZone( "method: status_zone", $zone );
    return -1 if ( $ZoneNumber < 1 );

    return $$self{zone_status}{$UnitNumber}{$ZoneNumber} if defined $$self{zone_status}{$UnitNumber}{$ZoneNumber};
}

sub zone_name {
    my ( $self, $unit, $zone ) = @_;

    &main::print_log("Rain8Net.pm - MODULE DEBUG : entering [zone_name]...") if $ModuleDebug;

    my $UnitNumber = $self->_ConvertUnit( "method: zone_name", $unit );
    return -1 if ( $UnitNumber < 1 );

    my $ZoneNumber = $self->_ConvertZone( "method: zone_name", $zone );
    return -1 if ( $ZoneNumber < 1 );

    my $unitstr = sprintf "%d", $UnitNumber;
    my $zonestr = sprintf "%d", $ZoneNumber;

    my $cfgparmname = "RAIN8NET_unit_" . $unitstr . "_zone_" . $zonestr;

    my $ZoneName = $main::config_parms{$cfgparmname} if exists $main::config_parms{$cfgparmname};

    return $ZoneName if $ZoneName;

    return $ZoneNumber;
}

sub ZoneOn {
    my ( $self, $unit, $zone ) = @_;

    &main::print_log("Rain8Net.pm - MODULE DEBUG : entering [ZoneOn]...") if $ModuleDebug;

    my $UnitNumber = $self->_ConvertUnit( "method: ZoneOn", $unit );
    return -1 if ( $UnitNumber < 1 );

    my $ZoneNumber = $self->_ConvertZone( "method: ZoneOn", $zone );
    return -1 if ( $ZoneNumber < 1 );

    $self->cmd( "ZoneOn", $UnitNumber, $ZoneNumber );
}

sub ZoneOff {
    my ( $self, $unit, $zone ) = @_;

    &main::print_log("Rain8Net.pm - MODULE DEBUG : entering [ZoneOff]...") if $ModuleDebug;

    # If no unit or zone, all global off!!!!
    if ( @_ < 2 ) {
        &main::print_log("Rain8Net.pm - MODULE DEBUG : [ZoneOff] missing unit/zone - calling AllGlobalOff...") if $ModuleDebug;
        $self->cmd("AllGlobalOff");
        return;
    }

    my $UnitNumber = $self->_ConvertUnit( "method: ZoneOff", $unit );
    return -1 if ( $UnitNumber < 1 );

    # If unit but no zone
    if ( @_ < 3 ) {
        &main::print_log("Rain8Net.pm - MODULE DEBUG : [ZoneOff] missing zone - calling AllModuleOFF...") if $ModuleDebug;
        $self->cmd( "AllModuleOFF", $UnitNumber );
        return;
    }

    # If Here ... a particular unit/zone is to be turned off

    my $ZoneNumber = $self->_ConvertZone( "method: ZoneOff", $zone );
    return -1 if ( $ZoneNumber < 1 );

    &main::print_log("Rain8Net.pm - MODULE DEBUG : [ZoneOff] call ZoneOff...") if $ModuleDebug;
    $self->cmd( "ZoneOff", $UnitNumber, $ZoneNumber );
}

1;

