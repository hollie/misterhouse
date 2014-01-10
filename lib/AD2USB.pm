# ###########################################################################
# Name: AD2USB Monitoring Module
#
# Description:
#   Module that monitors a serial device for the AD2USB for known events and 
#   maintains the state of the Ademco system in memory. Module also sends
#   instructions to the panel as requested.
#
# Author: Kirk Friedenberger (kfriedenberger@gmail.com)
# $Revision: $
# $Date: $
#
# Change log:
# - Added relay support (Wayne Gatlin, wayne@razorcla.ws)
# - Added 2-way zone expander support (Wayne Gatlin, wayne@razorcla.ws)
# - Completed Wireless support (Wayne Gatlin, wayne@razorcla.ws)  
# - Added ser2sock support (Wayne Gatlin, wayne@razorcla.ws)
# - Added in child MH-Style objects (Door & Motion items) (H Plato, hplato@gmail.com)
##############################################################################
# Copyright Kirk Friedenberger (kfriedenberger@gmail.com), 2013, All rights reserved
##############################################################################
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
# 
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
# 
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
# THE SOFTWARE.
############################################################################### 

use Switch;

package AD2USB;

@AD2USB::ISA = ('Generic_Item');

my $Self;  #Kludge
my %ErrorCode;
my $IncompleteCmd;
my $connecttype;

#    Starting a new object                                                  {{{
# Called by user code `$AD2USB = new AD2USB`
sub new {
   my ($class) = @_;
   ::print_log("Starting ADEMCO panel interface module");

   my $self = new Generic_Item();

   # Initialize Variables
   $$self{last_cmd}       = '';
   $$self{Log}            = []; #Not clear why this is needed
   $$self{ac_power}       = 0;
   $$self{battery_low}    = 1;
   $$self{chime}          = 0;
   $$self{keys_sent}      = 0;
   $$self{reconnect_time} = $::config_parms{'AD2USB_ser2sock_recon'};
   $$self{reconnect_time} = 10 if !defined($$self{reconnect_time});

   bless $self, $class;

   # load command hash
   $$self{CmdMsg} = $self->DefineCmdMsg();
   $$self{CmdMsgRev} = {reverse %{$$self{CmdMsg}}}; #DeRef Hash, Rev, Conv to Ref

   # The following logs default to being enabled, can only be disabled by 
   # proactively setting their ini parameters to 0:
   # AD2USB_part_log AD2USB_zone_log AD2USB_debug_log

   #Set all zones and partitions to ready
   ChangeZones( 1, 100, "ready", "ready", 0);
   ChangePartitions( 1, 1, "ready", 0);

   $Self = $self; #Kludge

   return $self;
}

#}}}
#    serial port configuration                                         {{{
sub init {

   my ($serial_port) = @_;
   $serial_port->error_msg(1);
   $serial_port->databits(8);
   $serial_port->parity("none");
   $serial_port->stopbits(1);
   $serial_port->handshake('none');
   $serial_port->datatype('raw');
   $serial_port->dtr_active(1);
   $serial_port->rts_active(0);

   select( undef, undef, undef, .100 );    # Sleep a bit

}

#}}}
#    module startup / enabling serial port                             {{{
sub serial_startup {
   my ($instance) = @_;
   my $self = $Self; #WTH is this?
   my $port; my $BaudRate; my $ip;

   #If Set to Use Ser2Sock Interface stop processing now
   if ($::config_parms{$instance . "_use_TCP"} == 1) {return;}

   if ($::config_parms{'AD2USB_serial_port'} and $::config_parms{'AD2USB_serial_port'} ne '/dev/none') {
      $port = $::config_parms{'AD2USB_serial_port'};
      $BaudRate = ( defined $::config_parms{AD2USB_baudrate} ) ? $main::config_parms{AD2USB_baudrate} : 115200;
      if ( &main::serial_port_create( 'AD2USB', $port, $BaudRate, 'none', 'raw' ) ) {
         init( $::Serial_Ports{AD2USB}{object}, $port );
         &main::print_log("  AD2USB.pm initializing port $port at $BaudRate baud") if $main::config_parms{debug} eq 'AD2USB';
         &::MainLoop_pre_add_hook( \&AD2USB::check_for_data, 1 ) if $main::Serial_Ports{AD2USB}{object};
         $::Year_Month_Now = &::time_date_stamp( 10, time );    # Not yet set when we init.
         LocalLogit( "$main::config_parms{data_dir}/logs/AD2USB.$main::Year_Month_Now.log", "    ========= AD2USB.pm Serial Initialized =========" );
         $connecttype = 'serial';
      }
   } elsif ($::config_parms{'AD2USB_ser2sock_ip'}) {
      #This shouldn't be in this routine, which is meant to startup serial items
      #The current kludge is to use '/dev/none' to get this routine to run, but
      #that seems silly.
      $recon_timer = new Timer;
      $ip = $::config_parms{'AD2USB_ser2sock_ip'};
      $port = $::config_parms{'AD2USB_ser2sock_port'};
      &main::print_log("  AD2USB.pm initializing TCP session with $ip on port $port") if $main::config_parms{debug} eq 'AD2USB';
      $AD2USB_ser2sock = new Socket_Item(undef, undef, "$ip:$port", 'AD2USB', 'tcp', 'raw');
      $AD2USB_ser2sock_sender = new Socket_Item(undef, undef, "$ip:$port", 'AD2USB_SENDER', 'tcp', 'rawout');
      start $AD2USB_ser2sock;
      start $AD2USB_ser2sock_sender;
      &::MainLoop_pre_add_hook( \&AD2USB::check_for_data, 1 );
      $::Year_Month_Now = &::time_date_stamp( 10, time );    # Not yet set when we init.
      LocalLogit( "$main::config_parms{data_dir}/logs/AD2USB.$main::Year_Month_Now.log", "    ========= AD2USB.pm Socket Initialized =========" );
      $connecttype = 'tcp';
   } else { 
      warn "AD2USB.pm->startup  AD2USB_serial_port or AD2USB_ser2sock_ip not defined in mh.ini file";
   }
} 

#}}}
#    module startup; hack because of the startup error                 {{{
sub startup {
   ##This is called as a result of using a .*_module parameter in the ini file
   ##if only purpose of _module paramter is to call this, why do we use the
   ##parameter?
   ##Perhaps move socket startup here?  Then we would still need the _module
   ##parameter
}



#}}}
#    check for incoming data on serial port                                 {{{
# This is called once per loop by a Mainloop_pre hook 
sub check_for_data {
   my ($self) = @_;
   my $NewCmd;

   if ($connecttype eq 'serial') {
      &main::check_for_generic_serial_data('AD2USB');
      $NewCmd = $main::Serial_Ports{'AD2USB'}{data};
      $main::Serial_Ports{'AD2USB'}{data} = '';
   }

   if ($connecttype eq 'tcp') {
      if (active $AD2USB_ser2sock) {
         $NewCmd = said $AD2USB_ser2sock;
      } else {
         # restart the TCP connection if its lost.
         if (inactive $recon_timer) {
            &main::print_log("Connection to AD2USB was lost, I will try to reconnect in $$self{reconnect_time} seconds");
            # LocalLogit( "$main::config_parms{data_dir}/logs/AD2USB.$main::Year_Month_Now.log", "AD2USB.pm ser2sock connection lost! Trying to reconnect." );
            set $recon_timer $$self{reconnect_time}, sub {
               start $AD2USB_ser2sock;
               start $AD2USB_ser2sock_sender;
            }
         }
      }
   }

   $self=$Self; #WTH is this?
   # we need to buffer the information receive, because many command could be include in a single pass
   $NewCmd = $IncompleteCmd . $NewCmd if $IncompleteCmd;
   return if !$NewCmd;
   $NewCmd =~ s/\r\n/#/g;    # Replace newlines with # (use # as command delimiter)
	#LocalLogit( "$main::config_parms{data_dir}/logs/AD2USB.$main::Year_Month_Now.log", "TCP DATA - - $NewCmd" ); 
   my $Cmd = '';	     # Build up a command string by iterating each character
   foreach my $c ( split( //, $NewCmd ) ) {
      if ( $c eq '#' ) {
         if ($Cmd) {
            # This is a full command that was terminated by \r\n
            ::print_log("[AD2USB] " . $Cmd) if $main::Debug{AD2USB} >= 1;
            my $status_type = GetStatusType($Cmd);
            if ($status_type >= 10) {
               # This is a panel message
               if (($Cmd ne $self->{last_cmd}) || ($status_type == 11))  {
                  # This is a new message
                  &LocalLogit( "$main::config_parms{data_dir}/logs/AD2USB.$main::Year_Month_Now.log", "NEW: $Cmd") unless ($main::config_parms{AD2USB_debug_log} == 0);
                  CheckCmd($Cmd);
                  ResetAdemcoState();
                  $self->{last_cmd} = $Cmd;
               }
               else {
                  # This is a duplicate message
                  &LocalLogit( "$main::config_parms{data_dir}/logs/AD2USB.$main::Year_Month_Now.log", "DUPE: $Cmd") unless ($main::config_parms{AD2USB_debug_log} == 0);
               }
            }
            else {
               # This is a relay or RF or zone expander message
               &LocalLogit( "$main::config_parms{data_dir}/logs/AD2USB.$main::Year_Month_Now.log", "NONPANEL: $Cmd") unless ($main::config_parms{AD2USB_debug_log} == 0);
               CheckCmd($Cmd);
               ResetAdemcoState();
	            #$self->{last_cmd} = $Cmd;
            }
            $Cmd = '';
         }
      }
      else {
         # Append this character to the current command
         $Cmd .= $c;
      }

   }
   # Save partial command for next serial read
   $IncompleteCmd = $Cmd;
}

#}}}
#    Validate the command and perform action                                {{{

sub CheckCmd {
   my $CmdStr = shift;
   my $status_type = GetStatusType($CmdStr);
   my $self = $Self;
   
   switch ( $status_type ) {

      case -1 {                         # UNRECOGNIZED STATUS
         &LocalLogit( "$main::config_parms{data_dir}/logs/AD2USB.$main::Year_Month_Now.log", "UNKNOWN STATUS: $CmdStr" ) unless ($main::config_parms{AD2USB_debug_log} == 0);
      }

      case 0 {                          # Key send confirmation
         if ($self->{keys_sent} == 0) {
            &LocalLogit( "$main::config_parms{data_dir}/logs/AD2USB.$main::Year_Month_Now.log", "Key sent from ANOTHER panel." ) unless ($main::config_parms{AD2USB_debug_log} == 0);
         }
         else {
            $self->{keys_sent}--;
            &LocalLogit( "$main::config_parms{data_dir}/logs/AD2USB.$main::Year_Month_Now.log", "Key received ($self->{keys_sent} left)" ) unless ($main::config_parms{AD2USB_debug_log} == 0);
         }

      }

      case 10 {               # FAULTS AVAILABLE
#         &LocalLogit( "$main::config_parms{data_dir}/logs/AD2USB.$main::Year_Month_Now.log", "Faults exist and are available to parse" ) unless ($main::config_parms{AD2USB_debug_log} == 0);
         cmd( $self, "ShowFaults" );
      }

      case 11 {               # IN FAULT LOOP
         my $status_codes = substr( $CmdStr, 1, 12 );
         my $fault = substr( $CmdStr, 23, 3 );
         $fault = substr($CmdStr, 67, 2); #TODO Why do we set $fault twice? ^
         $fault = "0$fault";
         my $panel_message = substr( $CmdStr, 61, 32);

         my $ZoneName = my $ZoneNum = $fault;
         my $PartNum = "1";
         $ZoneName = $main::config_parms{"AD2USB_zone_${ZoneNum}"} if exists $main::config_parms{"AD2USB_zone_${ZoneNum}"};
         $ZoneNum =~ s/^0*//;
         $fault = $ZoneNum;

         if (&MappedZones("00$ZoneNum")) { 
            &LocalLogit( "$main::config_parms{data_dir}/logs/AD2USB.$main::Year_Month_Now.log", "Zone $ZoneNum is mapped to a Relay or RF ID, skipping normal monitoring!") } 
         else {
            #Check if this is the new lowest fault number and reset the zones before it
            if (int($fault) <= int($self->{zone_lowest_fault})) {
               $self->{zone_lowest_fault} = $fault;
               #Reset zones to ready before the lowest
               $start = 1;
               $end = $self->{zone_lowest_fault} - 1;
               ChangeZones( $start, $end, "ready", "bypass", 1);
            }

            #Check if this is a new highest fault number and reset zones after it
            if (int($fault) > int($self->{zone_highest_fault})) {
               $self->{zone_highest_fault} = $fault;
               #Reset zones to ready after the highest
               $start = $self->{zone_highest_fault} + 1;;
               $end = 11;
               ChangeZones( $start, $end, "ready", "bypass", 1);
            }
   
            # Check if this zone was already faulted
            if ($self->{zone_status}{"$fault"} eq "fault") {
   
               #Check if this fault is less than the last fault (and must now be the new lowest zone)
               if (int($fault) <= int($self->{zone_last_num})) {
                  #This is the new lowest zone
                  $self->{zone_lowest_fault} = $fault;
                  #Reset zones to ready before the lowest
                  $start = 1;
                  $end = $self->{zone_lowest_fault} - 1;
                  ChangeZones( $start, $end, "ready", "bypass", 1);
               }         
   
               #Check if this fault is equal to the last fault (and must now be the only zone)
               if (int($fault) == int($self->{zone_last_num})) {
                  #Reset zones to ready after the only one
                  $start = int($fault) + 1;
                  $end = 11;
                  ChangeZones( $start, $end, "ready", "bypass", 1);
               }
   
               #Check if this fault is greater than the last fault and reset the zones between it and the prior one
               if (int($fault) > int($self->{zone_last_num})) {
                  $start = (($self->{zone_last_num} == $fault) ? 1 : int($self->{zone_last_num}) + 1);
                  $end = $fault - 1;
                  ChangeZones( $start, $end, "ready", "bypass", 1);
               }
            } #End Already Faulted

            $self->{zone_now_msg}            = "$panel_message";
            $self->{zone_now_status}         = "fault";
            $self->{zone_now_name}           = "$ZoneName";
            $self->{zone_now_num}            = "$ZoneNum";
            ChangeZones( int($ZoneNum), int($ZoneNum), "fault", "", 1);
         } #Not MappedZones
         $self->{partition_now_msg}       = "$panel_message"; 
         $self->{partition_now_status}    = "not ready";
         $self->{partition_now_num}       = "$PartNum";
         ChangePartitions( int($PartNum), int($PartNum), "not ready", 1);
      }

      case 12 {               # IN BYPASS FLASH LOOP
         my $status_codes = substr( $CmdStr, 1, 12 );
         my $fault = substr( $CmdStr, 23, 3 );
         $fault = substr($CmdStr, 67, 2);
         $fault = "0$fault";
         my $panel_message = substr( $CmdStr, 61, 32);

         my $ZoneName = my $ZoneNum = $fault;
         my $PartNum = "1";
         $ZoneName = $main::config_parms{"AD2USB_zone_${ZoneNum}"} if exists $main::config_parms{"AD2USB_zone_${ZoneNum}"};
         $ZoneNum =~ s/^0*//;
         $fault = $ZoneNum;
         
         $self->{zone_now_msg}            = "$panel_message";
         $self->{zone_now_status}         = "bypass";
         $self->{zone_now_name}           = "$ZoneName";
         $self->{zone_now_num}            = "$ZoneNum";
         ChangeZones( int($ZoneNum), int($ZoneNum), "bypass", "", 1);
         $self->{partition_now_msg}       = "$panel_message";
         $self->{partition_now_status}    = "not ready";
         $self->{partition_now_num}       = "$PartNum";
         ChangePartitions( int($PartNum), int($PartNum), "not ready", 1);
         
      }

      case 13 {               # NORMAL STATUS

         # Get three sections of the Ademco status message
         my $status_codes = substr( $CmdStr, 1, 12 );
         my $fault = substr( $CmdStr, 23, 3 );
         my $panel_message = substr( $CmdStr, 61, 32);
            &LocalLogit( "$main::config_parms{data_dir}/logs/AD2USB.$main::Year_Month_Now.log", "Key received ($self->{keys_sent} left)" ) unless ($main::config_parms{AD2USB_debug_log} == 0);

         # READY
         $data = 0;
         if ( substr($status_codes,$data,1) == "1" ) {
            my $start = 1;
            my $end = 11;
            if ( substr($status_codes,6,1) ne "1" ) {
               # Reset all zones to ready if partition is ready and not bypassed
               ChangeZones( $start, $end, "ready", "", 1);
            }
            else {
               # If zones are bypassed, reset unbypassed zones to ready
               for ($i = $start; $i <= $end; $i++) {
                  my $current_status = $self->{zone_status}{"$i"};
                  if ($current_status eq "fault") {
                     ChangeZones($i, $i, "ready", "bypass", 1);
                  }
               }
            }

            my $PartName = my $PartNum = "1";

            $PartName = $main::config_parms{"AD2USB_part_${PartNum}"} if exists $main::config_parms{"AD2USB_part_${PartNum}"};
            $self->{partition_now_msg}    = "$panel_message";
            $self->{partition_now_num}    = "$PartNum";
            $self->{partition_now_status} = "ready";
            ChangePartitions( int($PartNum), int($PartNum), "ready", 1);
            $self->{zone_lowest_fault} = 999;
            $self->{zone_highest_fault} = -1;            

            # Reset state for fault checks
            $self->{zone_last_status} = "";
            $self->{zone_last_num} = "";
            $self->{zone_last_name} = "";
         }

         # ARMED AWAY
         $data = 1;
         if ( substr($status_codes,$data,1) == "1" ) {
            my $PartNum = my $PartName = "1";
            $PartName = $main::config_parms{"AD2USB_part_${PartNum}"} if exists $main::config_parms{"AD2USB_part_${PartNum}"};

	    my $mode = "ERROR";
            if (index($panel_message, "ALL SECURE")) {
               $mode = "armed away";
            }
            elsif (index($panel_message, "You may exit now")) {
               $mode = "exit delay";
            }
            elsif (index($panel_message, "or alarm occurs")) {
               $mode = "entry delay";
            }
            elsif (index($panel_message, "ZONE BYPASSED")) {
               $mode = "armed away";
            }

            set $self "$mode";
            $self->{partition_now_msg}        = "$panel_message";
            $self->{partition_now_status}     = "$mode";
            $self->{partition_now_num}        = "$PartNum";
            ChangePartitions( int($PartNum), int($PartNum), "$mode", 1);

            # Reset state for fault checks
            $self->{zone_last_status} = "";
            $self->{zone_last_num} = "";
            $self->{zone_last_name} = "";
         }

         # ARMED HOME
         $data = 2;
         if ( substr($status_codes,$data,1) eq "1" ) {
            my $PartNum = my $PartName = "1";

            my $mode = "armed stay";
            $PartName = $main::config_parms{"AD2USB_part_${PartNum}"} if exists $main::config_parms{"AD2USB_part_${PartNum}"};
            $self->{partition_now_msg}        = "$panel_message";
            $self->{partition_now_status}     = "$mode";
            $self->{partition_now_num}        = "$PartNum";
            ChangePartitions( int($PartNum), int($PartNum), "$mode", 1);

            # Reset state for fault checks
            $self->{zone_last_status} = "";
            $self->{zone_last_num} = "";
            $self->{zone_last_name} = "";
         }

         # SKIP BACKLIGHT
         $data = 3;

         # PROGRAMMING MODE
         $data = 4;
         if ( substr($status_codes,$data,1) eq "1" ) {
            &LocalLogit( "$main::config_parms{data_dir}/logs/AD2USB.$main::Year_Month_Now.log", "Panel is in programming mode" ) unless ($main::config_parms{AD2USB_debug_log} == 0);

            # Reset state for fault checks
            $self->{zone_last_status} = "";
            $self->{zone_last_num} = "";
            $self->{zone_last_name} = "";
         }

         # SKIP BEEPS
         $data = 5;

         # A ZONE OR ZONES ARE BYPASSED
         $data = 6;
         if ( substr($status_codes,$data,1) == "1" ) {

            # Reset zones to ready that haven't appeared in the bypass loop
#            if ($self->{zone_last_status} eq "bypass") {
#               if (int($fault) < int($self->{zone_now_num})) {
#                  $start = int($self->{zone_now_num}) + 1;
#                  $end = 12;
#               }
#               ChangeZones( $start, $end - 1, "ready", "", 1);
#               $self->{zone_now_status} = "";
#               $self->{zone_now_num} = "0";
#            }

            # Reset state for fault checks
            $self->{zone_last_status} = "";
            $self->{zone_last_num} = "";
            $self->{zone_last_name} = "";
         }

         # SKIP AC POWER
         $data = 7;

         # SKIP CHIME MODE
         $data = 8;

         # ALARM WAS TRIGGERED (Sticky until disarm)
         $data = 9;
         if ( substr($status_codes,$data,1) == "1" ) {
            $EventName = "ALARM WAS TRIGGERED";
            &LocalLogit( "$main::config_parms{data_dir}/logs/AD2USB.$main::Year_Month_Now.log", "$EventName" ) unless ($main::config_parms{AD2USB_part_log} == 0);
         }

         # ALARM IS SOUNDING
         $data = 10;
         if ( substr($status_codes,$data,1) == "1" ) {
            $EventName = "ALARM IS SOUNDING";

            #TODO: figure out how to get a partition number
            my $PartName = my $PartNum = "1";
            my $ZoneNum = $fault;
            $ZoneName = $main::config_parms{"AD2USB_zone_$ZoneNum"}  if exists $main::config_parms{"AD2USB_zone_$ZoneNum"};
            $PartName = $main::config_parms{"AD2USB_part_$PartName"} if exists $main::config_parms{"AD2USB_part_$PartName"};
            &LocalLogit( "$main::config_parms{data_dir}/logs/AD2USB.$main::Year_Month_Now.log", "$EventName - Zone $ZoneNum ($ZoneName)" ) unless ($main::config_parms{AD2USB_part_log} == 0);
            $ZoneNum =~ s/^0*//;
            ChangeZones( int($ZoneNum), int($ZoneNum), "alarm", "", 1);
            $self->{zone_now_msg}         = "$panel_message";
            $self->{zone_now_status}      = "alarm";
            $self->{zone_now_num}         = "$ZoneNum";
            $self->{partition_now_msg}    = "$panel_message";
            $self->{partition_now_status} = "alarm";
            $self->{partition_now_num}    = "$PartNum";
            ChangePartitions( int($PartNum), int($PartNum), "alarm", 1);
         }

         # SKIP BATTERY LOW
         $data = 11;
      }

      case 2 {                # WIRELESS STATUS
	 my $ZoneLoop = "";
	 my $MZoneLoop = "";
         # Parse raw status strings
         my $rf_id = substr( $CmdStr, 5, 7 );
         my $rf_status = substr( $CmdStr, 13, 2 );
	 my $lc = 0;
	 my $wnum = 0;

         # UNKNOWN
         my $unknown_1 = 0;
         $unknown_1 = 1 if (hex(substr($rf_status, 1, 1)) & 1) == 1;
         # Parse for low battery signal
         my $low_batt = 0;
         $low_batt = 1 if (hex(substr($rf_status, 1, 1)) & 2) == 2;
         # Parse for supervision flag
         my $supervised = 0;
         $supervised = 1 if (hex(substr($rf_status, 1, 1)) & 4) == 4;
         # UNKNOWN
         my $unknown_8 = 0;
         $unknown_8 = 1 if (hex(substr($rf_status, 1, 1)) & 8) == 8;

         # Parse loop faults
         my $loop_fault_1 = 0;
         $loop_fault_1 = 1 if (hex(substr($rf_status, 0, 1)) & 8) == 8;
         my $loop_fault_2 = 0;
         $loop_fault_2 = 1 if (hex(substr($rf_status, 0, 1)) & 2) == 2;
         my $loop_fault_3 = 0;
         $loop_fault_3 = 1 if (hex(substr($rf_status, 0, 1)) & 1) == 1;
         my $loop_fault_4 = 0;
         $loop_fault_4 = 1 if (hex(substr($rf_status, 0, 1)) & 4) == 4;

         &LocalLogit( "$main::config_parms{data_dir}/logs/AD2USB.$main::Year_Month_Now.log", "WIRELESS: rf_id($rf_id) status($rf_status) loop1($loop_fault_1) loop2($loop_fault_2) loop3($loop_fault_3) loop4($loop_fault_4)" ) unless ($main::config_parms{AD2USB_debug_log} == 0);
         &LocalLogit( "$main::config_parms{data_dir}/logs/AD2USB.$main::Year_Month_Now.log", "WIRELESS: rf_id($rf_id) status($rf_status) low_batt($low_batt) supervised($supervised)" ) unless ($main::config_parms{AD2USB_debug_log} == 0);

         my $ZoneStatus = "ready";
         my $PartStatus = "";
         my @parsest;
         my $sensortype;

         if (exists $main::config_parms{"AD2USB_wireless_$rf_id"}) {
            # Assign zone
            my @ParseNum = split(",", $main::config_parms{"AD2USB_wireless_$rf_id"});

            # Assign status (zone and partition)
            if ($low_batt == "1") {
               $ZoneStatus = "low battery";
            }
	   
	   foreach $wnum(@ParseNum) {
	    if ($lc eq 0 or $lc eq 2 or $lc eq 4 or $lc eq 6) { 
	     $ZoneNum = $wnum;
	    }

	    if ($lc eq 1 or $lc eq 3 or $lc eq 5 or $lc eq 7) {
	    @parsest = split("", $wnum);
	    $sensortype = $parsest[0];
            $ZoneLoop = $parsest[1];
            $ZoneName = "Unknown";
            $ZoneName = $main::config_parms{"AD2USB_zone_$ZoneNum"} if exists $main::config_parms{"AD2USB_zone_$ZoneNum"};
 
	    	if ($ZoneLoop eq "1") {$MZoneLoop = $loop_fault_1}
            	if ($ZoneLoop eq "2") {$MZoneLoop = $loop_fault_2}
           	if ($ZoneLoop eq "3") {$MZoneLoop = $loop_fault_3}
            	if ($ZoneLoop eq "4") {$MZoneLoop = $loop_fault_4}
	 
	    	if ("$MZoneLoop" eq "1") {
               	 $ZoneStatus = "fault";
            	} elsif ("$MZoneLoop" eq 0) {
                 $ZoneStatus = "ready";
            	}
	      
            $self->{zone_now_msg}            = "$CmdStr";
            $self->{zone_now_status}         = "$ZoneStatus";
            $self->{zone_now_name}           = "$ZoneName";
            $self->{zone_now_num}            = "$ZoneNum";
            ChangeZones( int($ZoneNum), int($ZoneNum), "$ZoneStatus", "", 1);
              if ($sensortype eq "k") {
		  $ZoneStatus = "ready";
                  $self->{zone_now_msg}            = "$CmdStr";
            	  $self->{zone_now_status}         = "$ZoneStatus";
            	  $self->{zone_now_name}           = "$ZoneName";
                  $self->{zone_now_num}            = "$ZoneNum";
                  ChangeZones( int($ZoneNum), int($ZoneNum), "$ZoneStatus", "", 1);
              }
            }
	  $lc++
          }
         }

      }

      case 3 {                # EXPANDER STATUS
         my $exp_id = substr( $CmdStr, 5, 2 );
         my $input_id = substr( $CmdStr, 8, 2 );
         my $status = substr( $CmdStr, 11, 2 );
	 my $ZoneStatus;
         my $PartStatus;

         &LocalLogit( "$main::config_parms{data_dir}/logs/AD2USB.$main::Year_Month_Now.log", "EXPANDER: exp_id($exp_id) input($input_id) status($status)" ) unless ($main::config_parms{AD2USB_debug_log} == 0);

       if (exists $main::config_parms{"AD2USB_expander_$exp_id$input_id"}) {
            # Assign zone
            $ZoneNum = $main::config_parms{"AD2USB_expander_$exp_id$input_id"};
            $ZoneName = "Unknown";
            $ZoneName = $main::config_parms{"AD2USB_zone_$ZoneNum"} if exists $main::config_parms{"AD2USB_zone_$ZoneNum"};
            # Assign status (zone and partition)


            if ($status == 01) {
               $ZoneStatus = "fault";
               $PartStatus = "not ready";
            } elsif ($status == 00) {
                $ZoneStatus = "ready";
                $PartStatus = "";
            }

            $self->{zone_now_msg}            = "$CmdStr";
            $self->{zone_now_status}         = "$ZoneStatus";
            $self->{zone_now_name}           = "$ZoneName";
            $self->{zone_now_num}            = "$ZoneNum";
            ChangeZones( int($ZoneNum), int($ZoneNum), "$ZoneStatus", "", 1);
         #  if (($self->{partition_status}{int($PartNum)}) eq "ready") { #only change the partition status if the current status is "ready". We dont change if the system is armed.
         #   if ($PartStatus ne "") {
         #      $self->{partition_now_msg}       = "$CmdStr";
         #      $self->{partition_now_status}    = "$PartStatus";
         #      $self->{partition_now_num}       = "$PartNum";
         #      ChangePartitions( int($PartNum), int($PartNum), "$PartStatus", 1);
         #   }
         # }
        }
      }

      case 4 {                # RELAY STATUS
         my $rel_id = substr( $CmdStr, 5, 2 );
         my $rel_input_id = substr( $CmdStr, 8, 2 );
         my $rel_status = substr( $CmdStr, 11, 2 );
	 my $PartName = my $PartNum = "1";
         my $ZoneStatus;
         my $PartStatus;


         &LocalLogit( "$main::config_parms{data_dir}/logs/AD2USB.$main::Year_Month_Now.log", "RELAY: rel_id($rel_id) input($rel_input_id) status($rel_status)" ) unless ($main::config_parms{AD2USB_debug_log} == 0);

          if (exists $main::config_parms{"AD2USB_relay_$rel_id$rel_input_id"}) {
            # Assign zone
            $ZoneNum = $main::config_parms{"AD2USB_relay_$rel_id$rel_input_id"};
            $ZoneName = "Unknown";
            $ZoneName = $main::config_parms{"AD2USB_zone_$ZoneNum"} if exists $main::config_parms{"AD2USB_zone_$ZoneNum"};
            # Assign status (zone and partition)
       	   
          
	    if ($rel_status == 01) {
               $ZoneStatus = "fault";
               $PartStatus = "not ready";
            } elsif ($rel_status == 00) {
		$ZoneStatus = "ready";
		$PartStatus = "";
	    }

            $self->{zone_now_msg}            = "$CmdStr";
            $self->{zone_now_status}         = "$ZoneStatus";
            $self->{zone_now_name}           = "$ZoneName";
            $self->{zone_now_num}            = "$ZoneNum";
            ChangeZones( int($ZoneNum), int($ZoneNum), "$ZoneStatus", "", 1);
	  # if (($self->{partition_status}{int($PartNum)}) eq "ready") { #only change the partition status if the current status is "ready". We dont change if the system is armed.
          #  if ($PartStatus ne "") {
          #     $self->{partition_now_msg}       = "$CmdStr";
          #     $self->{partition_now_status}    = "$PartStatus";
          #     $self->{partition_now_num}       = "$PartNum";
          #     ChangePartitions( int($PartNum), int($PartNum), "$PartStatus", 1);
          #  }
         # }
	}
      }

      else {
         &LocalLogit( "$main::config_parms{data_dir}/logs/AD2USB.$main::Year_Month_Now.log", "SOMETHING SERIOUSLY WRONG - UNKNOWN COMMAND" ) unless ($main::config_parms{AD2USB_debug_log} == 0);
      }
   }

   # NORMAL STATUS TYPE
   # ALWAYS CHECK CHIME / AC POWER / BATTERY STATUS / BACKLIGHT / BEEPS
   if ($status_type >= 10) {

         # PARSE codes
         my $status_codes = substr( $CmdStr, 1, 12 );
         my $fault = substr( $CmdStr, 23, 3 );
         my $panel_message = substr( $CmdStr, 61, 32);

         # BACKLIGHT
         $data = 3;
         if ( substr($status_codes,$data,1) == "1" ) {
            &LocalLogit( "$main::config_parms{data_dir}/logs/AD2USB.$main::Year_Month_Now.log", "Panel backlight is on" ) unless ($main::config_parms{AD2USB_debug_log} == 0);
         }

         # BEEPS
         $data = 5;
         if ( substr($status_codes,$data,1) != "0" ) {
            $NumBeeps = substr($status_codes,$data,1);
            &LocalLogit( "$main::config_parms{data_dir}/logs/AD2USB.$main::Year_Month_Now.log", "Panel beeped $NumBeeps times" ) unless ($main::config_parms{AD2USB_debug_log} == 0);
         }

         # AC POWER
         $data = 7;
	 if ( substr($status_codes,$data,1) == "0" ) {
            $$self{ac_power} = 0;
            &LocalLogit( "$main::config_parms{data_dir}/logs/AD2USB.$main::Year_Month_Now.log", "AC Power has been lost" );
         }
         else {
            $$self{ac_power} = 1;
         }

         # CHIME MODE
         $data = 8;
         if ( substr($status_codes,$data,1) == "0" ) { 
            $self->{chime} = 0;
#            &LocalLogit( "$main::config_parms{data_dir}/logs/AD2USB.$main::Year_Month_Now.log", "Chime is off" ) unless ($main::config_parms{AD2USB_debug_log} == 0);
         }
         else {
            $self->{chime} = 1;
#            &LocalLogit( "$main::config_parms{data_dir}/logs/AD2USB.$main::Year_Month_Now.log", "Chime is on" ) unless ($main::config_parms{AD2USB_debug_log} == 0);
         }
   
         # BATTERY LOW
         $data = 11;
         if ( substr($status_codes,$data,1) == "1" ) {
            $self->{battery_low} = 1;
            &LocalLogit( "$main::config_parms{data_dir}/logs/AD2USB.$main::Year_Month_Now.log", "Panel is low on battery" );
         }
         else {
            $self->{battery_low} = 0;
         }

   }

   return;

}

#}}}
# local logit call {{{
sub LocalLogit {
   my $file = shift;
   my $str  = shift;
   &::logit( "$file", "$str" );
   my $Timestamp = &::time_date_stamp(16);
   $str =~ s/  +/ /;
   unshift @{ $Self->{Log} }, "$Timestamp: $str" if $str !~ /Temperature/;
   pop @{ $Self->{Log} } if scalar( @{ $Self->{Log} } ) > 60;

}

#}}}
#    Determine if the status string requires parsing                    {{{
sub GetStatusType {
   my $AdemcoStr   = shift;
   my $ll       = length($AdemcoStr);

   if ($ll eq 94) {
      # Keypad Message 
      # Format: Bit field,Numeric code,Raw data,Alphanumeric Keypad Message
      # TODO I would be inclined to split by comma rather than use substr
      my $substatus = substr($AdemcoStr, 61, 5);
      if ( $substatus eq "FAULT" ) {
         &LocalLogit( "$main::config_parms{data_dir}/logs/AD2USB.$main::Year_Month_Now.log", "Fault zones available: $AdemcoStr") unless ($main::config_parms{AD2USB_debug_log} == 0);
         return 11;
      }
      elsif ( $substatus eq "BYPAS" ) {
         &LocalLogit( "$main::config_parms{data_dir}/logs/AD2USB.$main::Year_Month_Now.log", "Bypass zones available: $AdemcoStr") unless ($main::config_parms{AD2USB_debug_log} == 0);
         return 12;
      }
      elsif ($AdemcoStr =~ m/Hit \*|Press \*/) {
         &LocalLogit( "$main::config_parms{data_dir}/logs/AD2USB.$main::Year_Month_Now.log", "Faults available: $AdemcoStr") unless ($main::config_parms{AD2USB_debug_log} == 0);
         return 10;
      }
      else {
#         &LocalLogit( "$main::config_parms{data_dir}/logs/AD2USB.$main::Year_Month_Now.log", "Standard status received: $AdemcoStr");
         return 13;
      }
   }
   elsif (substr($AdemcoStr,0,5) eq "!RFX:") {
      &LocalLogit( "$main::config_parms{data_dir}/logs/AD2USB.$main::Year_Month_Now.log", "Wireless status received.") unless ($main::config_parms{AD2USB_debug_log} == 0);
      return 2;
   }
   elsif (substr($AdemcoStr,0,5) eq "!EXP:") {
      &LocalLogit( "$main::config_parms{data_dir}/logs/AD2USB.$main::Year_Month_Now.log", "Expander status received.") unless ($main::config_parms{AD2USB_debug_log} == 0);
      return 3;
   }
   elsif (substr($AdemcoStr,0,5) eq "!REL:") {
      &LocalLogit( "$main::config_parms{data_dir}/logs/AD2USB.$main::Year_Month_Now.log", "Relay status received.") unless ($main::config_parms{AD2USB_debug_log} == 0);
      return 4;
   }
   elsif ($AdemcoStr eq "!Sending...done") {
      &LocalLogit( "$main::config_parms{data_dir}/logs/AD2USB.$main::Year_Month_Now.log", "Command sent successfully.") unless ($main::config_parms{AD2USB_debug_log} == 0);
      return 0;
   }
   return -1;
}

#}}}
#    Change zone statuses for zone indices from start to end            {{{
sub ChangeZones {
   my $start  = @_[0];
   my $end  = @_[1];
   my $new_status = @_[2];
   my $neq_status = @_[3];
   my $log = @_[4];

   my $self = $Self;
   for ($i = $start; $i <= $end; $i++) {
      $current_status = $self->{zone_status}{"$i"};
      if (($current_status ne $new_status) && ($current_status ne $neq_status)) {
         if (($main::config_parms{AD2USB_zone_log} != 0) && ($log == 1)) {
            my $ZoneNumPadded = $i; 
            $ZoneNumPadded = sprintf("%3d", $ZoneNumPadded);
            $ZoneNumPadded =~ tr/ /0/;
            $ZoneName = "Unknown";
            $ZoneName = $main::config_parms{"AD2USB_zone_$ZoneNumPadded"}  if exists $main::config_parms{"AD2USB_zone_$ZoneNumPadded"};
            &LocalLogit( "$main::config_parms{data_dir}/logs/AD2USB.$main::Year_Month_Now.log", "Zone $i ($ZoneName) changed from '$current_status' to '$new_status'" ) unless ($main::config_parms{AD2USB_zone_log} == 0);
         }
         $self->{zone_status}{"$i"} = $new_status;
	 #  Set child object status if it is registered to the zone
	 $$self{zone_object}{"$i"}->set($new_status, $$self{zone_object}{"$i"}) if defined $$self{zone_object}{"$i"};
      }
   }
}

#}}}
#    Change partition statuses for partition indices from start to end  {{{
sub ChangePartitions {
   my $start  = @_[0];
   my $end  = @_[1];
   my $new_status = @_[2];
   my $log = @_[3];

   my $self = $Self;
   for ($i = $start; $i <= $end; $i++) {
      $current_status = $self->{partition_status}{"$i"};
      if ($current_status ne $new_status) {
         if (($main::config_parms{AD2USB_part_log} != 0) && ($log == 1)) {
            $PartName = $main::config_parms{"AD2USB_part_$i"}  if exists $main::config_parms{"AD2USB_part_$i"};
            &LocalLogit( "$main::config_parms{data_dir}/logs/AD2USB.$main::Year_Month_Now.log", "Partition $i ($PartName) changed from '$current_status' to '$new_status'" ) unless ($main::config_parms{AD2USB_part_log} == 0);
         }
         $self->{partition_status}{"$i"} = $new_status;
      }
   }
}

#}}}
#    Reset Ademco state to simulate a "now" on some value ie: zone, temp etc.  {{{
sub ResetAdemcoState {

   my $self = $Self;
   # store faults (fault and bypass) for next message parsing
   if (($self->{zone_now_status} eq "fault") || ($self->{zone_now_status} eq "bypass")) {
      $self->{zone_last_status} = $self->{zone_now_status};
      $self->{zone_last_num} = $self->{zone_now_num};
      $self->{zone_last_name} = $self->{zone_now_name};
   }

   # reset zone
   if ( defined $self->{zone_now_num} ) {
      my $ZoneNum = $self->{zone_now_num};
      $self->{zone_num}{$ZoneNum}   = $self->{zone_now_num};
      $self->{zone_msg}{$ZoneNum}    = $self->{zone_now_msg};
      $self->{zone_status}{$ZoneNum} = $self->{zone_now_status};
      $self->{zone_time}{$ZoneNum}   = &::time_date_stamp( 17, time );
      undef $self->{zone_now_num};
      undef $self->{zone_now_name};
      undef $self->{zone_now_status};
      undef $self->{zone_now_msg};
   }

   # reset partition
   if ( defined $self->{partition_now_num} ) {
      my $PartNum = $self->{partition_now_num};
      $self->{partition}{$PartNum}        = $self->{partition_now_num};
      $self->{partition_msg}{$PartNum}    = $self->{partition_now_msg};
      $self->{partition_status}{$PartNum} = $self->{partition_now_status};
      $self->{partition_time}{$PartNum}   = &::time_date_stamp( 17, time );
      undef $self->{partition_now_num};
      undef $self->{partition_now_msg};
      undef $self->{partition_now_status};
   }

   return;
}

#}}}
#    Define hash with Ademco commands                                           {{{
sub DefineCmdMsg {
   my %Return_Hash = (
      "Disarm"                            => "$::config_parms{AD2USB_user_master_code}1",
      "ArmAway"                           => "$::config_parms{AD2USB_user_master_code}2",
      "ArmStay"                           => "$::config_parms{AD2USB_user_master_code}3",
      "ArmAwayMax"                        => "$::config_parms{AD2USB_user_master_code}4",
      "Test"                              => "$::config_parms{AD2USB_user_master_code}5",
      "Bypass"                            => "$::config_parms{AD2USB_user_master_code}6#",
      "ArmStayInstant"                    => "$::config_parms{AD2USB_user_master_code}7",
      "Code"                              => "$::config_parms{AD2USB_user_master_code}8",
      "Chime"                             => "$::config_parms{AD2USB_user_master_code}9",
      "ToggleVoice"                       => '#024',
      "ShowFaults"                        => "*",
      "AD2USBReboot"                      => "=",
      "AD2USBConfigure"                   => "!"
   );

   my $two_digit_zone;
   foreach my $key (keys(%::config_parms)) {
      #Create Commands for Relays
      if ($key =~ /^AD2USB_output_(\D+)_(\d+)$/){
         if ($1 eq 'co') {
            $Return_Hash{"$::config_parms{$key}c"} = "$::config_parms{AD2USB_user_master_code}#70$2";
            $Return_Hash{"$::config_parms{$key}o"} = "$::config_parms{AD2USB_user_master_code}#80$2";
         }
         elsif ($1 eq 'oc') {
            $Return_Hash{"$::config_parms{$key}o"} = "$::config_parms{AD2USB_user_master_code}#80$2";
            $Return_Hash{"$::config_parms{$key}c"} = "$::config_parms{AD2USB_user_master_code}#70$2";
         }
         elsif ($1 eq 'o') {
            $Return_Hash{"$::config_parms{$key}o"} = "$::config_parms{AD2USB_user_master_code}#80$2";
         }
         elsif ($1 eq 'c') {
            $Return_Hash{"$::config_parms{$key}c"} = "$::config_parms{AD2USB_user_master_code}#70$2";
         }
      }
      #Create Commands for Zone Expanders
      elsif ($key =~ /^AD2USB_expander_(\d+)$/) {
         $two_digit_zone = substr($::config_parms{$key}, 1); #Trim leading zero
         $Return_Hash{"exp$::config_parms{$key}c"} = "L$two_digit_zone"."0";
         $Return_Hash{"exp$::config_parms{$key}f"} = "L$two_digit_zone"."1";
         $Return_Hash{"exp$::config_parms{$key}p"} = "L$two_digit_zone"."2"; 
      }
   }

   return \%Return_Hash;
}

#}}}
#    Define hash with all zone numbers and names {{{
sub ZoneName {
   #my $self = $Self;
   my @Name = ["none"];

	foreach my $key (keys(%::config_parms)) {
		next if $key !~ /^AD2USB_zone_(\d+)$/;
		$Name[int($1)]=$::config_parms{$key};
	}
   return @Name;
}


sub MappedZones {
	foreach my $mkey (keys(%::config_parms)) {
                next if $mkey !~ /^AD2USB_(relay|wireless|expander)_(\d+)$/;
                if ("@_" eq $::config_parms{$mkey}) { return 1 }
        }
    return 0;
}

#}}}
#    Sending command to ADEMCO panel                                           {{{
sub cmd {
   my ( $self, $cmd, $password ) = @_;
   $cmd = $self->{CmdMsg}->{$cmd};

   $CmdName = ( exists $self->{CmdMsgRev}->{$cmd} ) ? $self->{CmdMsgRev}->{$cmd} : "unknown";
   $CmdStr = $cmd;

   # Exit if unknown command
   if ( $CmdName =~ /^unknown/ ) {
      &LocalLogit( "$main::config_parms{data_dir}/logs/AD2USB.$main::Year_Month_Now.log", "Invalid ADEMCO panel command : $CmdName ($cmd)");
      return;
   }

   # Exit if password is wrong
   if ( ($password ne $::config_parms{AD2USB_user_master_code}) && ($CmdName ne "ShowFaults" ) ) {
      &LocalLogit( "$main::config_parms{data_dir}/logs/AD2USB.$main::Year_Month_Now.log", "Invalid password for command $CmdName ($password)");
      return;
   }

   &LocalLogit( "$main::config_parms{data_dir}/logs/AD2USB.$main::Year_Month_Now.log", ">>> Sending to ADEMCO panel                      $CmdName ($cmd)" ) unless ($main::config_parms{AD2USB_debug_log} == 0);
   $self->{keys_sent} = $self->{keys_sent} + length($CmdStr);
   if ($connecttype eq 'serial') {
    $main::Serial_Ports{AD2USB}{object}->write("$CmdStr");
    } else {
    set $AD2USB_ser2sock_sender "$CmdStr";
    } 
   return "Sending to ADEMCO panel: $CmdName ($cmd)";

}

#}}}
#    user call from MH                                                         {{{

sub zone_now {
   return $_[0]->{zone_now_name} if defined $_[0]->{zone_now_name};
}

sub zone_msg {
   return $_[0]->{zone_now_msg} if defined $_[0]->{zone_now_msg};
}

sub zone_now_restore {
   return $_[0]->{zone_now_restore} if defined $_[0]->{zone_now_restore};
}

sub zone_now_tamper {
   return $_[0]->{zone_now_tamper} if defined $_[0]->{zone_now_tamper};
}

sub zone_now_tamper_restore {
   return $_[0]->{zone_now_tamper_restore} if defined $_[0]->{zone_now_tamper_restore};
}

sub zone_now_alarm {
   return $_[0]->{zone_now_alarm} if defined $_[0]->{zone_now_alarm};
}

sub zone_now_alarm_restore {
   return $_[0]->{zone_now_alarm_restore} if defined $_[0]->{zone_now_alarm_restore};
}

sub zone_now_fault {
   return $_[0]->{zone_now_num} if defined $_[0]->{zone_now_num};
}

sub status_zone {
   my ( $class, $zone ) = @_;
   return $_[0]->{zone_status}{$zone} if defined $_[0]->{zone_status}{$zone};
}

sub zone_name {
   my ( $class, $zone_num ) = @_;
   $zone_num = sprintf "%03s", $zone_num;
   my $ZoneName = $main::config_parms{"AD2USB_zone_$zone_num"} if exists $main::config_parms{"AD2USB_zone_$zone_num"};
   return $ZoneName if $ZoneName;
   return $zone_num;
}

sub partition_now {
   my ( $class, $part ) = @_;
   return $_[0]->{partition_now_num} if defined $_[0]->{partition_now_num};
}

sub partition_now_msg {
   my ( $class, $part ) = @_;
   return $_[0]->{partition_now_msg} if defined $_[0]->{partition_now_msg};
}

sub partition_name {
   my ( $class, $part_num ) = @_;
   my $PartName = $main::config_parms{"AD2USB_part_$part_num"} if exists $main::config_parms{"AD2USB_part_$part_num"};
   return $PartName if $PartName;
   return $part_num;
}

sub cmd_list {
   my ($self) = @_;
   foreach my $k ( sort keys %{$self->{CmdMsg}} ) {
      &::print_log("$k");
   }
}
#}}}
##Used to register a child object to the zone. Allows for MH-style Door & Motion sensors {{{
sub register {
   my ($self, $object, $zone_num ) = @_;
   &::print_log("Registering Child Object on zone $zone_num");
   $self->{zone_object}{$zone_num} = $object;
   }

sub get_child_object_name {
   my ($self,$zone_num) = @_;
   my $object = $self->{zone_object}{$zone_num};
   return $object->get_object_name() if defined ($object);
}

#}}}
# MH-Style child objects
# These allow zones to behave like Door_Items and Motion Sensors
# to use, just create the item with the Master AD2USB object and the appropriate zone
#
# ie. 
# $AD2USB = new AD2USB;
# $Front_door = new AD2USB_Door_Item($AD2USB,1);
#   states include open, closed and check
# $Front_motion = new AD2USB_Motion_Item($AD2USB,2);
#   states include motion and still
#
# inactivity timers are not working...don't know if those are relevant for panel items.

package AD2USB_Door_Item;

@AD2USB_Door_Item::ISA = ('Generic_Item');

sub new
{
   my ($class,$object,$zone) = @_;

   my $self = new Generic_Item();
   bless $self,$class;

   $$self{m_write} = 0;
   $$self{m_timerCheck} = new Timer() unless $$self{m_timerCheck};
   $$self{m_timerAlarm} = new Timer() unless $$self{m_timerAlarm};
   $$self{'alarm_action'} = '';
   $$self{last_open} = 0;
   $$self{last_closed} = 0;
   $$self{zone_number} = $zone;
   $$self{master_object} = $object;
   $$self{item_type} = 'door';
   $object->register($self,$zone);

   return $self;

}

sub set
{
   my ($self,$p_state,$p_setby) = @_;

      if (ref $p_setby and $p_setby->can('get_set_by')) {
         &::print_log("AD2USB_Door_Item($$self{object_name})::set($p_state, $p_setby): $$p_setby{object_name} was set by " . $p_setby->get_set_by) if $main::Debug{AD2USB};
      } else {
         &::print_log("AD2USB_Door_Item($$self{object_name})::set($p_state, $p_setby)") if $main::Debug{AD2USB};
      }

      if ($p_state =~ /^fault/) {
         $p_state = 'open';
         $$self{last_open} = $::Time;

      } elsif ($p_state =~ /^ready/) {
         $p_state = 'closed';
         $$self{last_closed} = $::Time;

      # Other door sensors?
      } elsif ($p_state eq 'on') {
         $p_state = 'open';
         $$self{last_open} = $::Time;

      } elsif ($p_state eq 'off') {
         $p_state = 'closed';
         $$self{last_closed} = $::Time;

      } else {
      	 $p_state = 'check';
      }

      $self->SUPER::set($p_state,$p_setby);
}
   
sub get_last_close_time {
   my ($self) = @_;
   return $$self{last_closed};
}

sub get_last_open_time {
   my ($self) = @_;
   return $$self{last_open};
}

sub get_child_item_type {
   my ($self) = @_;
   return $$self{item_type};
}

#Left in these methods to maintain compatibility. Since we're not tracking inactivity, these won't return proper results. {{{

sub set_alarm($$$) {
   my ($self, $time, $action, $repeat_time) = @_;
   $$self{'alarm_action'} = $action;
   $$self{'alarm_time'} = $time;
   $$self{'alarm_repeat_time'} = $repeat_time if defined $repeat_time;
   &::print_log ("AD2USB_Door_Item:: set_alarm not supported");

}

sub set_inactivity_alarm($$$) {
   my ($self, $time, $action) = @_;
   $$self{'inactivity_action'} = $action;
   $$self{'inactivity_time'} = $time*3600;
   &::print_log("AD2USB_Door_Item:: set_inactivity_alarm not supported");

}

#}}}
package AD2USB_Motion_Item;
@AD2USB_Motion_Item::ISA = ('Generic_Item');

sub new
{
   my ($class,$object,$zone) = @_;

   my $self = new Generic_Item();
   bless $self,$class;

   $$self{m_write} = 0;
   $$self{m_timerCheck} = new Timer() unless $$self{m_timerCheck};
   $$self{m_timerAlarm} = new Timer() unless $$self{m_timerAlarm};
   $$self{'alarm_action'} = '';
   $$self{last_still} = 0;
   $$self{last_motion} = 0;
   $$self{zone_number} = $zone;
   $$self{master_object} = $object;
   $$self{item_type} = 'motion';

   $object->register($self,$zone);

   return $self;

}

sub set
{
	my ($self,$p_state,$p_setby) = @_;


   if (ref $p_setby and $p_setby->can('get_set_by')) {
      &::print_log("AD2USB_Motion_Item($$self{object_name})::set($p_state, $p_setby): $$p_setby{object_name} was set by " . $p_setby->get_set_by) if $main::Debug{AD2USB};
   } else {
      &::print_log("AD2USB_Motion_Item($$self{object_name})::set($p_state, $p_setby)") if $main::Debug{AD2USB};
   }

   if ($p_state =~ /^fault/i) {
      $p_state = 'motion';
      $$self{last_motion} = $::Time;

   } elsif ($p_state =~ /^ready/i) {
      $p_state = 'still';
      $$self{last_still} = $::Time;

   } else {
      $p_state = 'check';
   }

	$self->SUPER::set($p_state, $p_setby);
}

sub get_last_still_time {
   my ($self) = @_;
   return $$self{last_still};
}

sub get_last_motion_time {
   my ($self) = @_;
   return $$self{last_motion};
}

sub get_child_item_type {
   my ($self) = @_;
   return $$self{item_type};
}

#Left in these methods to maintain compatibility. Since we're not tracking inactivity, these won't return proper results. {{{
sub delay_off()
{
	my ($self,$p_time) = @_;
	$$self{m_delay_off} = $p_time if defined $p_time;
	&::print_log("AD2USB_Motion_Item:: delay_off not supported");
	return $$self{m_delay_off};
}

sub set_inactivity_alarm($$$) {
   my ($self, $time, $action) = @_;
   $$self{'inactivity_action'} = $action;
   $$self{'inactivity_time'} = $time*3600;
	$$self{m_timerCheck}->set($time*3600, $self);
	&::print_log("AD2USB_Motion_Item:: set_inactivity_alarm not supported");
}

1;

#}}}
#$Log:$

__END__

