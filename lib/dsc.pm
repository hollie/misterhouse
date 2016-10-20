use strict;

package DSC;

@DSC::ISA = ('Generic_Item');

use constant MAX_ZONES => 64;

my %DSC_Systems;
my $CalcChecksum;
my %EventMsg;
my %CmdMsg;
my %CmdMsgRev;
my $Self;
my %ErrorCode;
my $IncompleteCmd;
my %BaudRate = (0 => 9600, 1 => 19200, 2 => 38400, 3 => 57600, 4 => 115200);
my @ModeTxt = ( "armed away", "armed stay", "armed Zero-Entry-Away", "armed Zero-Entry-Stay", "armed" );


sub serial_startup
{
   # Nothing needs to be done here...
}

sub _check_for_data
{
  for my $port_name (keys %DSC_Systems)
  {
    &::check_for_generic_serial_data($port_name) if $::Serial_Ports{$port_name}{'object'};
    my $NewCmd = $::Serial_Ports{$port_name}{data};
    $::Serial_Ports{$port_name}{data} = '';

    # we need to buffer the information receive, because many command could be include in a single pass
    #&::print_log("Receive the following [$NewCmd]\n") if $NewCmd;
    $NewCmd = $IncompleteCmd . $NewCmd if $IncompleteCmd;
    return if !$NewCmd;
    $NewCmd =~ s/\r\n/#/g;    # to validate if there is newline missing
    my $Cmd = '';
    foreach my $c ( split( //, $NewCmd ) )
    {
      if ( $c eq '#' )
      {
        _CheckCmd($Cmd, $port_name) if $Cmd;
        $Cmd = '';
      }
      else
      {
        $Cmd .= $c;
      }
    }
    $IncompleteCmd = $Cmd;
  }
}

sub _CheckCmd
{
  my ($CmdStr, $port_name) = @_;

  if ( $CmdStr && $main::Debug{'DSC'} )
  {
    my $l    = length($CmdStr);
    my $code = substr( $CmdStr, 0, 3 );
    my $arg  = substr( $CmdStr, 3, ( $l - 5 ) );
    my $Ck   = substr( $CmdStr, -2 );
    &main::print_log("$port_name::_check_for_data cmd=$code; arg=$arg; checksum=$Ck");
  }

  if ( _IsChecksumOK($CmdStr) )
  {
    my $cmd = substr( $CmdStr, 0, 3 );
    my $data = substr( $CmdStr, 3, ( length($CmdStr) - 5 ) );
    my $self = $DSC_Systems{$port_name}{'object'};

    if ( $cmd == 500 )
    {    # System acknowledgement
      my $CmdName = "Unknown";
      $CmdName = $CmdMsgRev{$data} if exists $CmdMsgRev{$data};
      &_LocalLogit($self, "$cmd $EventMsg{$cmd} $CmdName" );
    }
    elsif ( $cmd == 501 )
    {    # Command Error (bad checksum)
      my $ECName = "Unknown";
      $ECName = $ErrorCode{$data} if exists $ErrorCode{$data};
      &_LocalLogit($self, "$cmd $EventMsg{$cmd} $ECName data($data)");
    }
    elsif ( $cmd == 502 )
    {    # System Error
      my $ECName = "Unknown";
      $ECName = $ErrorCode{$data} if exists $ErrorCode{$data};
      &_LocalLogit($self, "$cmd $EventMsg{$cmd} $ECName" );
    }
    elsif ( $cmd == 550 )
    {    # Time Broadcast
      my $Hour = substr( $data, 0, 2 );
      my $Min  = substr( $data, 2, 2 );
      my $MM   = substr( $data, 4, 2 );
      my $DD   = substr( $data, 6, 2 );
      my $YY   = substr( $data, 8, 2 );
      &_LocalLogit($self, "$cmd $EventMsg{$cmd} $Hour:$Min $MM/$DD/$YY" ) if $main::config_parms{DSC_time_log};
      #$self->{TimeBroadcast} = 'on';
      #$self->{Time}          = "$Hour:$Min $MM/$DD/$YY";
      #$self->{TimeStamp}     = &::time_date_stamp( 17, time );
      #$self->{TimeEpoch}     = time;
    }
    elsif ( $cmd == 560 )
    {    # Telephone ring detected
      my $Name = $data;
      &_LocalLogit($self, "$cmd $EventMsg{$cmd}:" ) if $main::config_parms{DSC_ring_log};
    }
    elsif ( $cmd == 561 )
    {    # Indoor Temperature Broadcast
      my $TstatNum  = substr( $data, 0, 1 );
      my $TstatTemp = substr( $data, 1, 3 );
      $TstatTemp = ( 128 - $TstatTemp ) if $TstatTemp > 128;
      &_LocalLogit($self, "$cmd $EventMsg{$cmd} Thermostat:$TstatNum  Temp:$TstatTemp" ) if $main::config_parms{DSC_temp_log};
    }
    elsif ( $cmd == 562 )
    {    # Outdoor Temperature Broadcast
      my $TstatNum  = substr( $data, 0, 1 );
      my $TstatTemp = substr( $data, 1, 3 );
      $TstatTemp = ( 128 - $TstatTemp ) if $TstatTemp > 128;
      &_LocalLogit($self, "$cmd $EventMsg{$cmd} Thermostat:$TstatNum  Temp:$TstatTemp" ) if $main::config_parms{DSC_temp_log};
    }
    elsif ( $cmd == 563 )
    {    # Thermostats Set Point (untested; no escort/thermostat)
      my $TstatNum  = substr( $data, 0, 1 );
      my $CoolSP = substr( $data, 1, 3 );
      my $HeatSP = substr( $data, 4, 3 );
      &_LocalLogit($self, "$cmd $EventMsg{$cmd} Thermostat:$TstatNum; Cool Setpoint:$CoolSP; Heat Setpoint:$HeatSP" ) if $main::config_parms{DSC_temp_log};
    }
    elsif ( $cmd == 570 )
    {    # Broadcast Labels
      my $lblNum = substr($data, 0, 3);
      my $lbl = substr($data, 3, 32);
      &_LocalLogit($self, "$cmd $EventMsg{$cmd} Label#:$lblNum; Label:$lbl" );
    }
    elsif ( $cmd == 580 )
    {    # Baud Rate Set
      &_LocalLogit($self, "$cmd $EventMsg{$cmd} value:" . $BaudRate{$data});
    }
    elsif ( $cmd == 601 )
    {    # zone alarm
      my $PartName = substr( $data, 0, 1 );
      my $ZoneNum = substr( $data, 1, 3 );
      $$self{'zones'}[$ZoneNum]->_alarm($cmd, 'on');
    }
    elsif ( $cmd == 602 )
    {    # zone alarm restore
      my $PartName = substr( $data, 0, 1 );
      my $ZoneNum = substr( $data, 1, 3 );
      $$self{'zones'}[$ZoneNum]->_alarm($cmd, 'off');
    }
    elsif ( $cmd == 603 )
    {    # zone tamper
      my $PartNum = substr( $data, 0, 1 );
      my $ZoneNum = substr( $data, 1, 3 );
      $$self{'zones'}[$ZoneNum]->_tamper($cmd, 'on');
    }
    elsif ( $cmd == 604 )
    {    # zone tamper restore
      my $PartNum = substr( $data, 0, 1 );
      my $ZoneNum = substr( $data, 1, 3 );
      $$self{'zones'}[$ZoneNum]->_tamper($cmd, 'off');
    }
    elsif ( $cmd == 605 )
    {    # zone fault
      my $ZoneNum = $data;
      $$self{'zones'}[$ZoneNum]->_fault($cmd, 'on');
    }
    elsif ( $cmd == 606 )
    {    # zone restore
      my $ZoneNum = $data;
      $$self{'zones'}[$ZoneNum]->_fault($cmd, 'off');
    }
    elsif ( $cmd == 609 )
    {    # zone open
      my $ZoneNum = $data;
      $$self{'zones'}[$ZoneNum]->_state($cmd, 'open') if defined($$self{'zones'}[$ZoneNum]);
    }
    elsif ( $cmd == 610 )
    {    # zone restored
      my $ZoneNum = $data;
      $$self{'zones'}[$ZoneNum]->_state($cmd, 'close') if defined($$self{'zones'}[$ZoneNum]);
    }
    elsif ( $cmd == 620 )
    {    # duress alarm
      &_LocalLogit($self, "$cmd $EventMsg{$cmd} ($data)" );
    }
    elsif ( $cmd == 621 )
    {    # Fire Key Alarm
      &_LocalLogit($self, "$cmd $EventMsg{$cmd}" );
    }
    elsif ( $cmd == 622 )
    {    # Fire Key Alarm Restore
      &_LocalLogit($self, "$cmd $EventMsg{$cmd}" );
    }
    elsif ( $cmd == 623 )
    {    # Auxiliary Key Alarm
      &_LocalLogit($self, "$cmd $EventMsg{$cmd}" );
    }
    elsif ( $cmd == 624 )
    {    # Auxiliary Key Alarm Restore
      &_LocalLogit($self, "$cmd $EventMsg{$cmd}" );
    }
    elsif ( $cmd == 625 )
    {    # Panic Key Alarm
      &_LocalLogit($self, "$cmd $EventMsg{$cmd}" );
    }
    elsif ( $cmd == 626 )
    {    # Panic Key Alarm Restore
      &_LocalLogit($self, "$cmd $EventMsg{$cmd}" );
    }
    elsif ( $cmd == 631 )
    {    # Auxiliary Input Alarm
      &_LocalLogit($self, "$cmd $EventMsg{$cmd}" );
    }
    elsif ( $cmd == 632 )
    {    # Auxiliary Input Alarm Restore
      &_LocalLogit($self, "$cmd $EventMsg{$cmd}" );
    }
    elsif (( $cmd == 650 )
      or   ( $cmd == 651 ))
    {    # Partition Ready|Not Ready
      my $PartNum = $data;
      $$self{'partitions'}[$PartNum]->_status($cmd);
    }
    elsif (( $cmd == 652 ) # Partition Armed
#      or ( $cmd == 653 )
      or ( $cmd == 654 ) # Partition in Alarm
      or ( $cmd == 655 )) # Partition Disarmed
    {
      my $PartNum = substr( $data, 0, 1 );
#      my $Mode = ( length($data) == 2 ) ? substr( $data, 1, 1 ) : 4;
#      print(" cmd: $cmd; data: $data\n");
      $$self{'partitions'}[$PartNum]->_mode($cmd, substr( $data, 1, 1 ));
    }
    elsif ( $cmd == 653 )
    {    # Force partition to Arm
      my $PartName = my $PartNum = $data;
      $PartName = $main::config_parms{"DSC_part_${data}"} if exists $main::config_parms{"DSC_part_${data}"};
      &_LocalLogit($self, "$cmd $EventMsg{$cmd} partition $PartName  ($PartNum)" ) if $main::config_parms{DSC_part_log};
    }
    elsif (( $cmd == 656 )  # Exit Delay in Progress
        or ( $cmd == 657 )) # Entry Delay in Progress
    { # the data portion only contains the partition number
      $$self{'partitions'}[$data]->_entryExitDelay($cmd);
    }
    elsif ( $cmd == 658 )
    {    # Keypad Lockout
      my $PartName = my $PartNum = $data;
      $PartName = $main::config_parms{"DSC_part_${data}"} if exists $main::config_parms{"DSC_part_${data}"};
      &_LocalLogit($self, "$cmd $EventMsg{$cmd} partition $PartName ($PartNum)" );
    }
    elsif ( $cmd == 659 )
    {    # Keypad blanking
      my $PartName = my $PartNum = $data;
      $PartName = $main::config_parms{"DSC_part_${data}"} if exists $main::config_parms{"DSC_part_${data}"};
      &_LocalLogit($self, "$cmd $EventMsg{$cmd} partition $PartName ($PartNum)" );
    }
    elsif ( $cmd == 660 )
    {    # Command Output In Progress
      my $PartName = my $PartNum = $data;
      $PartName = $main::config_parms{"DSC_part_${data}"} if exists $main::config_parms{"DSC_part_${data}"};
      &_LocalLogit($self, "$cmd $EventMsg{$cmd} partition $PartName ($PartNum)" );
    }
    elsif ( $cmd == 670 )
    {    # Invalid Access Code
      my $PartName = my $PartNum = $data;
      $PartName = $main::config_parms{"DSC_part_${data}"} if exists $main::config_parms{"DSC_part_${data}"};
      &_LocalLogit($self, "$cmd $EventMsg{$cmd} partition $PartName ($PartNum)" );
    }
    elsif ( $cmd == 671 )
    {    # Function Not Available
      my $PartName = my $PartNum = $data;
      $PartName = $main::config_parms{"DSC_part_${data}"} if exists $main::config_parms{"DSC_part_${data}"};
      &_LocalLogit($self, "$cmd $EventMsg{$cmd} partition $PartName ($PartNum)" );
    }
    elsif ( $cmd == 672 )
    {    # Failed To Arm
      my $PartName = my $PartNum = $data;
      $PartName = $main::config_parms{"DSC_part_${data}"} if exists $main::config_parms{"DSC_part_${data}"};
      &_LocalLogit($self, "$cmd $EventMsg{$cmd} partition $PartName ($PartNum)" );
      #set $self "failed to arm";
    }
    elsif ( $cmd == 673 )
    {    # Partition Busy
      my $PartName = my $PartNum = $data;
      $PartName = $main::config_parms{"DSC_part_${data}"} if exists $main::config_parms{"DSC_part_${data}"};
      &_LocalLogit($self, "$cmd $EventMsg{$cmd} partition $PartName ($PartNum)" );
    }
    elsif (( $cmd == 700 )
      or ( $cmd == 701 )
      or ( $cmd == 702 )
      or ( $cmd == 750 )
      or ( $cmd == 751 )
      )
    {    # User or computer closing
      my $PartNum = substr( $data, 0, 1 );

      # if a user value does exists from the panel
      # then MisterHouse or some automation trigger  this state
      # send user "0000" which is defined as automation
      $$self{'partitions'}[$PartNum]->_state($cmd, (length($data) > 1) ? substr( $data, 1, 4 ) : "0000");
      #set $self "user closing";
      #$self->{user_name}            = $UserName;
      #$self->{user_id}              = $UserNum;
    }
#    =begin
#    elsif ( $cmd == 701 )
#    {    # Special closing (probably via computer command)
#      my $PartName = my $PartNum = $data;
#      $PartName = $main::config_parms{"DSC_part_${PartName}"} if exists $main::config_parms{"DSC_part_${PartName}"};
#      &_LocalLogit($self, "$cmd $EventMsg{$cmd} Misterhouse or Anonymous armed partition $PartName ($PartNum) in mode $self->{state}" );
#      #set $self "special closing";
#      #$self->{user_name}            = "Misterhouse or Anonymous";
#      #$self->{user_id}              = "0000";
#    }
#    elsif ( $cmd == 702 )
#    {    # Partial closing (one or more zones are being bypassed)
#      my $PartName = my $PartNum = $data;
#      $PartName = $main::config_parms{"DSC_part_${PartName}"} if exists $main::config_parms{"DSC_part_${PartName}"};
#      &_LocalLogit($self, "$cmd $EventMsg{$cmd} (zones bypassed) armed partition $PartName ($PartNum) in mode $self->{state}" );
#      #set $self "partial closing";
#      #$self->{user_name}            = "Misterhouse or Anonymous";
#      #$self->{user_id}              = "0000";
#    }
#    elsif ( $cmd == 750 )
#    {    # User opening
#      my $PartName = my $PartNum = substr( $data, 0, 1 );
#      my $UserName = my $UserNum = substr( $data, 1, 4 );
#      $PartName = $main::config_parms{"DSC_part_${PartName}"} if exists $main::config_parms{"DSC_part_${PartName}"};
#      $UserName = $main::config_parms{"DSC_user_${UserName}"} if exists $main::config_parms{"DSC_user_${UserName}"};
#      &_LocalLogit($self, "$cmd $EventMsg{$cmd} User $UserName ($UserNum) disarmed partition $PartName ($PartNum)" );
#      #set $self "user opening";
#      #$self->{user_name}            = "$UserName";
#      #$self->{user_id}              = $UserNum;
#    }
#    elsif ( $cmd == 751 )
#    {    # Special opening (probably via computer command)
#      my $PartName = my $PartNum = $data;
#      $PartName = $main::config_parms{"DSC_part_${PartName}"} if exists $main::config_parms{"DSC_part_${PartName}"};
#      &_LocalLogit($self, "$cmd $EventMsg{$cmd} Misterhouse or Anonymous disarmed partition $PartName ($PartNum)" );
#      #set $self "special opening";
#      #$self->{user_name}            = "Misterhouse or Anonymous";
#      #$self->{user_id}              = "0000";
#    }
#    =cut
    elsif ( $cmd == 800 )
    {    # Panel Battery Trouble
      &_LocalLogit($self, "$cmd $EventMsg{$cmd}" );
      set $self "panel trouble";
    }
    elsif ( $cmd == 801 )
    {    # Panel Battery Trouble Restore
      &_LocalLogit($self, "$cmd $EventMsg{$cmd}" );
      set $self "panel trouble restore";
    }
    elsif ( $cmd == 802 )
    {    # Panel AC Trouble
      &_LocalLogit($self, "$cmd $EventMsg{$cmd}" );
      set $self "panel AC trouble";
    }
    elsif ( $cmd == 803 )
    {    # Panel AC Trouble Restore
      &_LocalLogit($self, "$cmd $EventMsg{$cmd}" );
      set $self "panel AC trouble restore";
    }
    elsif ( $cmd == 806 )
    {    # System Bell Trouble
      &_LocalLogit($self, "$cmd $EventMsg{$cmd}" );
      set $self "system bell trouble";
    }
    elsif ( $cmd == 807 )
    {    # System Bell Trouble restore
      &_LocalLogit($self, "$cmd $EventMsg{$cmd}" );
      set $self "system bell trouble restore";
    }
    elsif ( $cmd == 810 )
    {    # Phone line 1 open or short condition
      &_LocalLogit($self, "$cmd $EventMsg{$cmd} Phone line 1 is in open or short condition" );
      set $self "phone line 1 trouble";
    }
    elsif ( $cmd == 811 )
    {    # Phone line 1 trouble restored
      &_LocalLogit($self, "$cmd $EventMsg{$cmd} Phone line 1 trouble is restored" );
      set $self "phone line 1 restored";
    }
    elsif ( $cmd == 812 )
    {    # Phone line 2 open or short condition
      &_LocalLogit($self, "$cmd $EventMsg{$cmd} Phone line 2 is in open or short condition" );
      set $self "phone line 2 trouble";
    }
    elsif ( $cmd == 813 )
    {    # Phone line 2 trouble restored
      &_LocalLogit($self, "$cmd $EventMsg{$cmd} Phone line 2 trouble is restored" );
      set $self "phone line 2 restored";
    }
    elsif ( $cmd == 814 )
    {    # FTC Trouble
      &_LocalLogit($self, "$cmd $EventMsg{$cmd}" );
      set $self "ftc trouble";
    }
    elsif ( $cmd == 816 )
    {    # Buffer Near Full
      &_LocalLogit($self, "$cmd $EventMsg{$cmd}" );
    }
    elsif ( $cmd == 821 )
    {    # General Device Low Battery
      my $ZoneNum = my $ZoneName = $data;
      $ZoneName = $main::config_parms{"DSC_zone_$ZoneNum"}  if exists $main::config_parms{"DSC_zone_$ZoneNum"};
      &_LocalLogit($self, "$cmd $EventMsg{$cmd} $ZoneName($ZoneNum)" );
      set $self "low battery";
    }
    elsif ( $cmd == 822 )
    {    # General Device Low Battery REstore
      my $ZoneNum = my $ZoneName = $data;
      $ZoneName = $main::config_parms{"DSC_zone_$ZoneNum"}  if exists $main::config_parms{"DSC_zone_$ZoneNum"};
      &_LocalLogit($self, "$cmd $EventMsg{$cmd} $ZoneName($ZoneNum)" );
    }
    elsif ( $cmd == 825 )
    {    # Wireless Key Low Battery
      my $KeyNum = $data;
      &_LocalLogit($self, "$cmd $EventMsg{$cmd} ($KeyNum)" );
    }
    elsif ( $cmd == 826 )
    {    # Wireless Key Low Battery Restore
      my $KeyNum = $data;
      &_LocalLogit($self, "$cmd $EventMsg{$cmd} ($KeyNum)" );
    }
    elsif ( $cmd == 827 )
    {    # HandheldKey Low Battery
      my $KeyNum = $data;
      &_LocalLogit($self, "$cmd $EventMsg{$cmd} ($KeyNum)" );
    }
    elsif ( $cmd == 828 )
    {    # Handheld Key Low Battery Restore
      my $KeyNum = $data;
      &_LocalLogit($self, "$cmd $EventMsg{$cmd} ($KeyNum)" );
    }
    elsif ( $cmd == 829 )
    {    # General System Tamper
      &_LocalLogit($self, "$cmd $EventMsg{$cmd} " );
    }
    elsif ( $cmd == 830 )
    {    # General System Tamper Restore
      &_LocalLogit($self, "$cmd $EventMsg{$cmd} " );
    }
    elsif ( $cmd == 831 )
    {    # Trouble With Escort module
      #my $PartName = my $PartNum = $data;
      #$PartName = $main::config_parms{"DSC_part_${PartName}"} if exists $main::config_parms{"DSC_part_${PartName}"};
      &_LocalLogit($self, "$cmd $EventMsg{$cmd} System report trouble with Escort" );
    }
    elsif ( $cmd == 832 )
    {    # Escort trouble restored
      #my $PartName = my $PartNum = $data;
      #$PartName = $main::config_parms{"DSC_part_${PartName}"} if exists $main::config_parms{"DSC_part_${PartName}"};
      &_LocalLogit($self, "$cmd $EventMsg{$cmd} System trouble with Escort restored" );
    }
    elsif ( $cmd == 840 )
    {    # Trouble Status (trouble on system)
      my $PartName = my $PartNum = $data;
      $PartName = $main::config_parms{"DSC_part_${PartName}"} if exists $main::config_parms{"DSC_part_${PartName}"};
      &_LocalLogit($self, "$cmd $EventMsg{$cmd} System report trouble on partition $PartName" );
    }
    elsif ( $cmd == 841 )
    {    # Trouble Status Restore (No trouble on system)
      my $PartName = my $PartNum = $data;
      $PartName = $main::config_parms{"DSC_part_${PartName}"} if exists $main::config_parms{"DSC_part_${PartName}"};
      &_LocalLogit($self, "$cmd $EventMsg{$cmd} System report no trouble on partition $PartName" );
    }
    elsif ( $cmd == 842 )
    {    # Fire Trouble
      &_LocalLogit($self, "$cmd $EventMsg{$cmd} " );
    }
    elsif ( $cmd == 843 )
    {    # Fire Trouble  Restore
      &_LocalLogit($self, "$cmd $EventMsg{$cmd} " );
    }
    elsif ( $cmd == 896 )
    {    # Keybus Fault
      &_LocalLogit($self, "$cmd $EventMsg{$cmd} " );
    }
    elsif ( $cmd == 897 )
    {    # Keybus Fault Restore
      &_LocalLogit($self, "$cmd $EventMsg{$cmd} " );
    }
    elsif ( $cmd == 900 )
    {    # user code required
      &_LocalLogit($self, "$cmd $EventMsg{$cmd} " );
      $self->cmd("CodeSend", $self->{houseCode} . "00")
    }
    elsif ( $cmd == 908 )
    {    # softwre version
      &_LocalLogit($self, "$cmd $EventMsg{$cmd}  version ($data)" );
    }
    else
    {
      &main::print_log("DSC_IT100:check_for_data  Undefined command [$cmd] received via $CmdStr");
    }
  }
  else
  {
   &main::print_log("DSC_IT100:check_for_data  Invalid checksum from $CmdStr ($CalcChecksum)");
  }
  return;
}

sub _IsChecksumOK
{
  my ($DscStr) = @_;
  my $ll = length($DscStr);
  my $CksValue = substr( $DscStr, -2 );

  $CalcChecksum = _DoChecksum($DscStr);

  #&main::print_log("DSC_IT100::IsChecksumOK   DscString=[$DscStr] CksValue=[$CksValue] CksCalc=[$CalcChecksum]") if ( $DscStr && $main::config_parms{debug} eq 'DSC_IT100');
  return 1 if $CksValue eq $CalcChecksum;
  return 0;
}

sub _DoChecksum
{
  my ($Str) = @_;
  my $CKStmp;
  my $CKStmp2;
  for ( my $i = 0 ; $i < length($Str) - 2 ; $i++ )
  {
    $CKStmp2 = unpack( "C", substr( $Str, $i, 1 ) );
    $CKStmp += $CKStmp2;
  }
  return uc substr( unpack( "H*", pack( "N", $CKStmp ) ), -2 );
}

sub _DefineEventMsg
{

  %EventMsg = (
    "000" => "Poll                                     ",    # Application originated command
    "001" => "Status Report                            ",    #         |
    "010" => "Set Date and Time                        ",    #        \ /
    "020" => "Command Output Control                   ",
    "030" => "Partition Arm Control - Away             ",
    "031" => "Partition Arm Control - Stay             ",
    "032" => "Partition Arm Control - Zero Entry Delay ",
    "033" => "Partition Arm Control - With Code        ",
    "040" => "Partition Disarm Control - With Code     ",
    "050" => "Verbose Arming Control                   ", # legacy; not on the IT100 board
    "055" => "Time Stamp Control                       ",
    "056" => "Time Broadcast Control                   ",
    "057" => "Temperature Broadcast Control            ",
    "058" => "Virtual Keypad Control                   ",
    "060" => "Trigger Panic Alarm                      ",
    "070" => "Virtual Key Press                        ", # no returns except for acknowledgements
    "080" => "Baud Rate Change                         ",
    "095" => "Get Temperature Setpoint                 ",
    "096" => "Temperature Change                       ",
    "097" => "Save Temperature                         ",
    "200" => "Code Send                                ",
    "500" => "Command Acknowledge                      ",    # PC_IT100 Originated Command
    "501" => "Command Error                            ",    #        |
    "502" => "System Error                             ", # 3-digit error code is returned
    "550" => "Time/Date Broadcast                      ", # 10 (mmhhMMddyy)
    "560" => "Ring Detected                            ", # 10 (mmhhMMddyy)
    "561" => "Indoor Temperature Broadcast             ", # 4 bytes (thermostat #1-4, tempature)
    "562" => "Outdoor Temperature Broadcast            ", # 4 bytes (thermostat #1-4, tempature)
    "563" => "Thermostat Set Points                    ", # 8 bytes (thermostat #1-4 (2 digits), cool (3 digits), heat (3 digits)
    "570" => "Broadcast Labels                         ", # 35 characters (3 digit label number, 32 bytes label)
    "580" => "Baud Rate Set                            ", # 1 byte (see command below)
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
    "623" => "Auxiliary Key Alarm                      ",
    "624" => "Auxiliary Key Restore                    ",
    "625" => "Panic Key Alarm                          ",
    "626" => "Panic Key Restore                        ",
    "631" => "2-Wire Smoke Alarm                       ",
    "632" => "2-Wire Smoke Restore                     ",
    "650" => "Partition Ready                          ",
    "651" => "Partition Not Ready                      ",
    "652" => "Partition Armed                          ",
    "653" => "Partition In Ready To Force Armed        ",
    "654" => "Partition in Alarm                       ",
    "655" => "Partition Disarmed                       ",
    "656" => "Exit Delay in Progress                   ",
    "657" => "Entry Delay in Progress                  ",
    "658" => "Keypad Lock-Out                          ",
    "659" => "Keypad Blanking                          ",
    "660" => "Command Output In Progress               ",
    "670" => "Invalid Code Access                      ",
    "671" => "Function Not Available                   ",
    "672" => "Failed To Arm                            ",
    "673" => "Partition Busy                           ",
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
    "896" => "Keybus Fault                             ",
    "897" => "Keybus Fault Restore                     ",
    "900" => "Code Required                            ",
    "901" => "LCD Update                               ",
    "902" => "LCD Cursor                               ",
    "903" => "LED Status                               ",
    "904" => "Beep Status                              ",
    "905" => "Tone Status                              ",
    "906" => "Buzzer Status                            ",
    "907" => "Door Chime Status                        ",
    "908" => "Software Version                         "
  );
  return;
}

sub _DefineCmdMsg
{

  %CmdMsg = (
    "Poll"                              => "000",
    "StatusReport"                      => "001",
    "RequestLabel"                      => "002",
    "SetDateTime"                       => "010",
    "CommandOutputControl"              => "020",   # 2 (Part 1-8 (31-38h), Pgm 1-4(31-34h))
    "PartitionArmControlAway"           => "030",
    "PartitionArmControlStay"           => "031",
    "PartitionArmControlZeroEntryDelay" => "032",
    "PartitionArmControlWithCode"       => "033",   # 7 (Part.1-8 (31-38h) & Code 6 bytes h)
    "PartitionDisarmControlWithCode"    => "040",   # 7 (Part.1-8 (31-38h) & Code 6 bytes h)
    "VerboseArmingControl"              => "050",
    "TimeStampControl"                  => "055",
    "TimeBroadcastControl"              => "056",
    "TemperatureBroadcastControl"       => "057",
    "VirtualKeypadControl"              => "058",   # 1 on/off
    "TriggerPanicAlarm"                 => "060",   # 1 (1 (31h)= F, 2(32h) = A, 3 (33h= P)
    "KeyPress"                          => "070",   #
    "BaudRateChange"                    => "080",   # 1 (0 = 9600, 1 = 19200, 2 = 38400, 3 = 57600, 4 = 115200)
    "GetTemperatureSetpoint"            => "095",   # 1 (thermostat # 1-4)
    "TemperatureChange"                 => "096",   # 8 (Thermostats #1-4, Type (c or h), Mode (+ - = [, Value1,Value2,Value3 (if =, use values to set)])
    "SaveTemperature"                   => "097",   # 1 (Thermostats #1-4)
    "CodeSend"                          => "200"   # 6 (user code--add '00' to the end of a 4-digit code)
  );

  %CmdMsgRev = reverse %CmdMsg;
  return;
}

sub _DefineErrorCode
{

  %ErrorCode = (
    "000"   => "No Error",
    "001"   => "RS-232 Receive Buffer Overrun",
    "002"   => "RS-232 Receive Buffer Overflow",
    "003"   => "Keybus Transmit Buffer Overrun",
    "010"   => "Keybus Transmit Buffer Overrun",
    "011"   => "Keybus Transmit Time Timeout",
    "012"   => "Keybus Transmit Mode Timeout",
    "013"   => "Keybus Transmit Keystring Timeout",
    "014"   => "Keybus Not Functioning",
    "015"   => "Keybus Busy (attempting arm or disarm)",
    "016"   => "Keybus Busy - Lockout (too many disarms)",
    "017"   => "Keybus Busy - Installers Mode",
    "020"   => "API Command Syntax Error",
    "021"   => "API Command Partition Error (partition out of bound)",
    "022"   => "API Command Not Supported",
    "023"   => "API System Not Armed",
    "024"   => "API System Not Ready To Arm",
    "025"   => "API Command Invalid Length",
    "026"   => "API User Code not Required",
    "027"   => "API Invalid Characters in Command"
  );

  return;
}

sub _LocalLogit
{
  my ($self, $str) = @_;

  my $file = "$main::config_parms{data_dir}/logs/DSC_$$self{'type'}.$main::Year_Month_Now.log";
  &::logit( "$file", "$str" );
}

sub _cmd
{
  my ( $self, $cmd, @arg_array ) = @_;
  my $arg = join( '', @arg_array );
  $arg = 1 if ( $arg eq 'on' );
  $arg = 0 if ( $arg eq 'off' );
  $cmd = $CmdMsg{$cmd} if ( length($cmd) > 3 );

  my $CmdStr = $cmd . $arg;
  $CmdStr .= _DoChecksum( $CmdStr . "00" );
  my $CmdName;
  $CmdName = ( exists $CmdMsgRev{$cmd} ) ? $CmdMsgRev{$cmd} : "unknown";

  if ( $CmdName =~ /^unknown/ )
  {
    &::print_log("Invalid DSC panel command : $CmdName ($cmd) with argument $arg");
    return;
  }
=begin
  if ( $cmd eq "033" || $cmd eq "040" )
  {    # we don't display password
#      &::print_log("Sending to DSC panel     $CmdName ($cmd)");
    &_LocalLogit($self, ">>> Sending to DSC panel                      $CmdName ($cmd)" );
  }
  else
  {
#      &::print_log("Sending to DSC panel     $CmdName ($cmd) with argument ($arg)");
    &_LocalLogit($self, ">>> Sending to DSC panel                      $CmdName ($cmd) with argument ($arg)  [$CmdStr]" );
  }
=cut
  &_LocalLogit($self, ">>> Sending to DSC panel                      $CmdName ($cmd) with argument ($arg)  [$CmdStr]" );
  $::Serial_Ports{$$self{'port_name'}}{object}->write("$CmdStr\r\n");
  return; # "Sending to DSC panel: $CmdName ($cmd)";
}

sub new
{
  my ($class, $port_name, $type) = @_;
  my $self = {};
  $$self{'port_name'} = $port_name;
  $$self{houseCode} = $::config_parms{DSC_house_code};
  $$self{'type'} = $type;
#  $$self{'zone'} = 0;
  for (my $i = 1; $i <= MAX_ZONES; $i++)
  {
    $$self{'zones'}[$i] = undef;
  }
  bless $self, $class;
  _DefineEventMsg();
  _DefineCmdMsg();
  _DefineErrorCode();

  $$self{'dsc_obj'} = $self;
  $DSC_Systems{$port_name}{'object'} = $self;
  if (1==scalar(keys %DSC_Systems))
  { # Add hooks on first call only
    &::MainLoop_pre_add_hook(\&DSC::_check_for_data, 1);
  }
  &::serial_port_create($port_name, $::config_parms{$port_name . "_serial_port"}, $::config_parms{$port_name . "_baudrate"}, 'none', 'raw' ) ;

  $::Year_Month_Now = &::time_date_stamp( 10, time );    # Not yet set when we init.
  _LocalLogit($self, "========= DSC.pm Initialized for $type device =========" );
  &main::print_log("Starting DSC computer interface module for device: $type");
  _cmd( $self, 'Poll' ); # request an initial poll
  if (defined $::config_parms{DSC_time_log})
  { # enable/disable time broadcasts if configured
    select(undef, undef, undef, 0.250); # wait 250 millseconds to avoid overrunning RS-232 receive buffer on panel
    _cmd( $self, 'TimeBroadcastControl', $::config_parms{DSC_time_log});
  }
  if (defined $::config_parms{DSC_temp_log})
  { # enable/disable temperature broadcasts if configured
    select(undef, undef, undef, 0.250); # wait 250 millseconds to avoid overrunning RS-232 receive buffer on panel
    _cmd( $self, 'TemperatureBroadcastControl', $::config_parms{DSC_temp_log});
  }
  if ($type =~ /5401/)
  { # enable/disable VerboseArmingControl
    select(undef, undef, undef, 0.250); # wait 250 millseconds to avoid overrunning RS-232 receive buffer on panel
    _cmd( $self, 'VerboseArmingControl', $::config_parms{DSC_verbose_arming});
  }
  select(undef, undef, undef, 0.250); # wait 250 millseconds to avoid overrunning RS-232 receive buffer on panel
  _cmd( $self, 'StatusReport' ); # request an initial status report

  return $self;
}

sub _register_partition
{
  my ($self, $partition_obj, $partition_num) = @_;
  $$self{'partitions'}[$partition_num] = $partition_obj;
}

sub _register_zone
{
  my ($self, $zone_obj, $zone_num) = @_;
  $$self{'zones'}[$zone_num] = $zone_obj;
}

sub set_clock
{
   my ($self) = @_;

   my ($sec,$m,$h,$mday,$mon,$year,$wday,$yday,$isdst) = localtime(time);
   $year = sprintf("%02d", $year % 100);
   $mon += 1;
   $m = ($m<10) ? "0".$m : $m; # make a 2 digit minute
   $h = ($h<10) ? "0".$h : $h; # make a 2 digit hour
   $mday = ($mday<10) ? "0".$mday : $mday; # make a 2 digit day
   $mon = ($mon<10) ? "0".$mon : $mon; # make a 2 digit month

   my $TimeStamp="$h$m$mon$mday$year";

#   &::print_log("Setting time on DSC panel to $TimeStamp");
#   &::logit( "Setting time on DSC panel to $TimeStamp" );
   $self->_cmd("SetDateTime", $TimeStamp);
}

sub user_name {
   return $_[0]->{user_name} if defined $_[0]->{user_name};
}

sub user_id {
   return $_[0]->{user_id} if defined $_[0]->{user_id};
}

package DSC::Zone;

@DSC::Zone::ISA = ('DSC');

sub new
{
  my ($class, $dsc_obj, $zone_num, $partition_num) = @_;
  my $self = {};
  $$self{'zone'} = $zone_num;
  $$self{'partition'} = $partition_num;
  # defaulting to partition 1 if a value was not passed in
  $$self{'partition'} = 1 if !$partition_num;
  $$self{'dsc_obj'} = $dsc_obj;
  bless $self, $class;
  $dsc_obj->_register_zone($self, $zone_num);
#  &::print_log("initializing zone: $$self{'object_name'}; num: $zone_num");
  return $self;
}

sub _alarm
{
  my ($self, $event, $state) = @_;
  $$self{'dsc_obj'}->_LocalLogit( "$event $EventMsg{$event} for zone $$self{'object_name'}" );
}

sub _tamper
{
  my ($self, $event, $state) = @_;
  $$self{'dsc_obj'}->_LocalLogit( "$event $EventMsg{$event} for zone $$self{'object_name'}" );
}

sub _fault
{
  my ($self, $event, $state) = @_;
  $$self{'dsc_obj'}->_LocalLogit( "$event $EventMsg{$event} for zone $$self{'object_name'}" );
}

sub _state
{
  my ($self, $event, $state) = @_;
  # state = "open" or "close"
  $$self{'dsc_obj'}->_LocalLogit( "$event $EventMsg{$event} for zone $$self{'object_name'}" );
  $self->set($state);
}

package DSC::Partition;

@DSC::Partition::ISA = ('DSC');

sub new
{
  my ($class, $dsc_obj, $partition_num) = @_;
  my $self = {};
  $$self{'partition'} = $partition_num;
  # defaulting to partition 1 if a value was not passed in
  $$self{'partition'} = 1 if !$partition_num;
  $$self{'dsc_obj'} = $dsc_obj;
  bless $self, $class;
  $dsc_obj->_register_partition($self, $partition_num);
  return $self;
}

sub _status
{
  my ($self, $event) = @_;

  # The event determines the status
  # not setting the state for this
  # 650 is 'ready'
  # 651 is 'not ready'

  $$self{'dsc_obj'}->_LocalLogit( "$event $EventMsg{$event} for zone $$self{'object_name'}" );
  $$self{status} = ($event == 650) ? 'ready' : 'not ready';
  $self->set( ($event == 650) ? "ready" : "not ready" );
}

sub _mode
{
  my ($self, $event, $mode) = @_;

  # mode = "armed, disarmed, alarm)
  # not setting the state for this as the state will be set once the user is determined
  # events:
  # 652 armed
  # 654 alarm
  # 655 disarmed (no "mode" is sent with this command)

  $$self{'dsc_obj'}->_LocalLogit( "$event $EventMsg{$event} for $$self{'object_name'}" );

  # setting a previous mode
  $$self{previous_mode} = $$self{mode};

  # if $event is 655, this is a "disarm" command
  $$self{mode} = ($event == 655) ? "disarmed" : "$ModeTxt[$mode]";

  # clearing the user values
  $$self{user_num} = undef;
  $$self{user} = undef;
}

sub _state
{
  my ($self, $event, $user) = @_;

  # We have the user name/number
  # now we are setting the state to the mode set just before this pass
  # and setting the user property on the partition object

  $$self{'dsc_obj'}->_LocalLogit( "$event $EventMsg{$event} for zone $$self{'object_name'}" );

  $$self{user} = $main::config_parms{"DSC_user_${user}"} if exists $main::config_parms{"DSC_user_${user}"};
  $$self{user_num} = $user;

  $self->set($$self{mode});
}

sub _entryExitDelay
{
  my ($self, $event) = @_;

  # entry or exit delay
  # set the state so this can be acted upon
  # the state will change once these are over and the panel sends the message
  # for which user armed/disarmed the partition

  $$self{'dsc_obj'}->_LocalLogit( "$event $EventMsg{$event} partition $$self{'object_name'}" );

  $self->set( ($event == 656) ? "exit delay" : "entry delay" );
}

sub arm
{
  my ($self, $mode) = @_;

  if ($mode eq 'away')
  {
    $$self{'dsc_obj'}->_cmd("PartitionArmControlAway", $$self{'partition'});
  }
  elsif ($mode eq 'stay')
  {
    $$self{'dsc_obj'}->_cmd("PartitionArmControlStay", $$self{'partition'});
  }
}

sub disarm
{
  my ($self) = @_;

  $$self{'dsc_obj'}->_cmd("PartitionDisarmControlWithCode", "$$self{'partition'}" . "$$self{'dsc_obj'}->{'houseCode'}" . "00");
}

1;


=back

=head2 INI PARAMETERS

NONE

=head2 AUTHOR

Kirk Bauer  kirk@kaybee.org

=head2 SEE ALSO

NONE

=head2 LICENSE

This program is free software; you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation; either version 2 of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more details.

You should have received a copy of the GNU General Public License along with this program; if not, write to the Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.

=cut


