=head1 B<AD2USB>

=head2 SYNOPSIS

---Example Code and Usage---

=head2 DESCRIPTION

Module that monitors a serial device for the AD2USB for known events and 
maintains the state of the Ademco system in memory. Module also sends
instructions to the panel as requested.

=head2 CONNFIGURATION

This is only a start of the documentation of the configuration for this module.
At the moment, I am just documenting the main changes that I have made

=head3 Serial Connections (USB or Serial)

Add the following commands to your INI file:

AD2USB_serial_port=/dev/ttyAMA0

=head3 IP Connections (Ser2Sock)

AD2USB_server_ip=192.168.11.17
AD2USB_server_port=10000

=head3 Code Inserts for All Devices

$AD2USB = new AD2USB;

=head3 For Additional Devices (Multiple Seperate Panels)

Each additional device can be defined as follows:

AD2USB_1_serial_port=/dev/ttyAMA0

OR

AD2USB_1_server_ip=192.168.11.17
AD2USB_1_server_port=10000

PLUS

$AD2USB_1 = new AD2USB('AD2USB_1');

Each addition panel should be iterated by 1.
=head2 INHERITS

L<Generic_Item>

=head2 METHODS

=over

=cut

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

package AD2USB;
use strict;

@AD2USB::ISA = ('Generic_Item');

my $Self;  #Kludge
my %ErrorCode;
my %Socket_Items; #Stores the socket instances and attributes
my %Interfaces; #Stores the relationships btw instances and interfaces

#    Starting a new object                                                  {{{
# Called by user code `$AD2USB = new AD2USB`
sub new {
   my ($class, $instance) = @_;
   $instance = "AD2USB" if (!defined($instance));
   ::print_log("Starting $instance instance of ADEMCO panel interface module");

   my $self = new Generic_Item();

   # Initialize Variables
   $$self{last_cmd}       = '';
   $$self{ac_power}       = 0;
   $$self{battery_low}    = 1;
   $$self{chime}          = 0;
   $$self{keys_sent}      = 0;
   $$self{instance}       = $instance;
   $$self{reconnect_time} = $::config_parms{'AD2USB_ser2sock_recon'};
   $$self{reconnect_time} = 10 if !defined($$self{reconnect_time});
   $$self{log_file}       = "$::config_parms{data_dir}/logs/AD2USB.$::Year_Month_Now.log"

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

   #Store Object with Instance Name
   $self->set_object_instance($instance);

   $Self = $self; #Kludge

   return $self;
}

#}}}

#    Set/Get Object by Instance                                        {{{
sub get_object_by_instance{
   my ($instance) = @_;
   return $Interfaces{$instance};
}

sub set_object_instance{
   my ($self, $instance) = @_;
   $Interfaces{$instance} = $self;
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
   my ($port, $BaudRate, $ip);

   if ($::config_parms{$instance . '_serial_port'} and 
         $::config_parms{$instance . '_serial_port'} ne '/dev/none') {
      $port = $::config_parms{$instance .'_serial_port'};
      $BaudRate = ( defined $::config_parms{$instance . '_baudrate'} ) ? $main::config_parms{"$instance" . '_baudrate'} : 115200;
      if ( &main::serial_port_create( $instance, $port, $BaudRate, 'none', 'raw' ) ) {
         init( $::Serial_Ports{$instance}{object}, $port );
         ::print_log("[AD2USB] initializing $instance on port $port at $BaudRate baud") if $main::config_parms{debug} eq 'AD2USB';
         ::MainLoop_pre_add_hook( sub {AD2USB::check_for_data($instance, 'serial');}, 1 ) if $main::Serial_Ports{"$instance"}{object};
      }
   }
}

#}}}
#    startup /enable socket port                                       {{{
sub server_startup {
   my ($instance) = @_;

   $Socket_Items{"$instance"}{recon_timer} = ::Timer::new();
   my $ip = $::config_parms{"$instance".'_server_ip'};
   my $port = $::config_parms{"$instance" . '_server_port'};
   ::print_log("  AD2USB.pm initializing $instance TCP session with $ip on port $port") if $main::config_parms{debug} eq 'AD2USB';
   $Socket_Items{"$instance"}{'socket'} = new Socket_Item($instance, undef, "$ip:$port", 'AD2USB', 'tcp', 'raw');
   $Socket_Items{"$instance" . '_sender'}{'socket'} = new Socket_Item($instance . '_sender', undef, "$ip:$port", 'AD2USB_SENDER', 'tcp', 'rawout');
   $Socket_Items{"$instance"}{'socket'}->start;
   $Socket_Items{"$instance" . '_sender'}{'socket'}->start;
   &::MainLoop_pre_add_hook( sub {AD2USB::check_for_data($instance, 'tcp');}, 1 );
}

#}}}

#    check for incoming data on serial port                                 {{{
# This is called once per loop by a Mainloop_pre hook, it parses out the string
# of data into individual messages.  
sub check_for_data {
   my ($instance, $connecttype) = @_;
   my $self = get_object_by_instance($instance);
   my $NewCmd;

   # Get the date from serial or tcp source
   if ($connecttype eq 'serial') {
      &main::check_for_generic_serial_data($instance);
      $NewCmd = $main::Serial_Ports{$instance}{data};
      $main::Serial_Ports{$instance}{data} = '';
   }

   if ($connecttype eq 'tcp') {
      if ($Socket_Items{$instance}{'socket'}->active) {
         $NewCmd = $Socket_Items{$instance}{'socket'}->said;
      } else {
         # restart the TCP connection if its lost.
         if ($Socket_Items{$instance}{recon_timer}->inactive) {
            &main::print_log("Connection to $instance instance of AD2USB was lost, I will try to reconnect in $$self{reconnect_time} seconds");
            # ::logit( $self{log_file}, "AD2USB.pm ser2sock connection lost! Trying to reconnect." );
            $Socket_Items{$instance}{recon_timer}->set($$self{reconnect_time}, sub {
               $Socket_Items{$instance}{'socket'}->start;
            });
         }
      }
   }

   # Return if nothing received
   return if !$NewCmd;

   # Prepend any prior message fragment
   $NewCmd = $self->{IncompleteCmd} . $NewCmd if $self->{IncompleteCmd};
   $self->{IncompleteCmd} = '';

   # Split Data into Individual Messages and Then Send the Message to be Parsed
   foreach my $Cmd (split("\n", $NewCmd)){
      # Split leaves part of line ending so full message can be confirmed
      if (substr($Cmd, -1) eq "\r"){
         # Valid Message, Strip off last line ending
         $Cmd = substr($Cmd, 0, -1);
         ::print_log("[AD2USB] " . $Cmd) if $main::Debug{AD2USB} >= 1;

         # Get the Message Type, and Ignore Duplicate Status Messages
         my $status_type = $self->GetStatusType($Cmd);
         if ($status_type->{keypad} && $Cmd eq $self->{last_cmd} &&
            (!$status_type->{fault})) {
            # This is a duplicate panel message with no important status
            ::logit( $self{log_file}, "DUPE: $Cmd") unless ($main::config_parms{AD2USB_debug_log} == 0);
         }
         else {
            # This is a non-dupe panel message or a fault panel message or a
            # relay or RF or zone expander message or something important
            # Log the message, parse it, and store it to detect future dupes
            ::logit( $self{log_file}, "MSG: $Cmd") unless ($main::config_parms{AD2USB_debug_log} == 0);
            $self->CheckCmd($Cmd);
            $self->ResetAdemcoState();
            $self->{last_cmd} = $Cmd if ($status_type->{keypad});
         }
      }
      else {
         # Save partial command for next serial read
         $self->{IncompleteCmd} = $Cmd;
      }
   }
}

#}}}
#    Validate the command and perform action                                {{{

sub CheckCmd {
   my ($self, $CmdStr) = @_;
   my $status_type = $self->GetStatusType($CmdStr);
   my $zone_padded = $status_type->{numeric_code};
   my $zone_no_pad = int($zone_padded);
   
   if ($status_type->{unknown}) {
      ::logit( $self{log_file}, "UNKNOWN STATUS: $CmdStr" ) unless ($main::config_parms{AD2USB_debug_log} == 0);
   }
   elsif ($status_type->{cmd_sent}) {
      if ($self->{keys_sent} == 0) {
         ::logit( $self{log_file}, "Key sent from ANOTHER panel." ) unless ($main::config_parms{AD2USB_debug_log} == 0);
      }
      else {
         $self->{keys_sent}--;
         ::logit( $self{log_file}, "Key received ($self->{keys_sent} left)" ) unless ($main::config_parms{AD2USB_debug_log} == 0);
      }
   }
   elsif ($status_type->{fault_avail}) {
      #Send command to show faults
      cmd( $self, "ShowFaults" );
   }
   elsif ($status_type->{fault}) {
      my $PartNum = "1";
      my $ZoneName = $main::config_parms{"AD2USB_zone_${zone_padded}"};

      # Each fault message tells us two things, 1) this zone is faulted and 
      # 2) all zones between this zone and the last fault are ready.
      
      #Reset the zones between the current zone and the last zone. If zones
      #are sequential do nothing, if same zone, reset all other zones
      if ($self->{zone_last_num} - $zone_no_pad > 1 
         || $self->{zone_last_num} - $zone_no_pad == 0) {
         ChangeZones( $self->{zone_last_num}+1, $zone_no_pad-1, "ready", "bypass", 1);
      }

      $self->{zone_now_status}         = "fault";
      $self->{zone_now_name}           = $ZoneName;
      $self->{zone_now_num}            = $zone_no_pad;
      ChangeZones( $zone_no_pad, $zone_no_pad, "fault", "", 1);
      $self->{partition_now_msg}       = $status_type->{alphanumeric}; 
      $self->{partition_now_status}    = "not ready";
      $self->{partition_now_num}       = $PartNum;
      ChangePartitions( int($PartNum), int($PartNum), "not ready", 1);
   }
   elsif ($status_type->{bypass}) {
      my $PartNum = "1";
      my $ZoneName = $main::config_parms{"AD2USB_zone_${zone_padded}"} if exists $main::config_parms{"AD2USB_zone_${zone_padded}"};
      
      $self->{zone_now_status}         = "bypass";
      $self->{zone_now_name}           = $ZoneName;
      $self->{zone_now_num}            = $zone_no_pad;
      ChangeZones( $zone_no_pad, $zone_no_pad, "bypass", "", 1);
      $self->{partition_now_msg}       = $status_type->{alphanumeric};
      $self->{partition_now_status}    = "not ready";
      $self->{partition_now_num}       = $PartNum;
      ChangePartitions( int($PartNum), int($PartNum), "not ready", 1);
   }
   elsif ($status_type->{wireless}) {
      ::logit( $self{log_file}, "WIRELESS: rf_id("
         .$status_type->{rf_id}.") status(".$status_type->{rf_status}.") loop1("
         .$status_type->{rf_loop_fault_1}.") loop2(".$status_type->{rf_loop_fault_2}
         .") loop3(".$status_type->{rf_loop_fault_3}.") loop4("
         .$status_type->{rf_loop_fault_4}.")" ) unless ($main::config_parms{AD2USB_debug_log} == 0);
      ::logit( $self{log_file}, "WIRELESS: rf_id("
         .$status_type->{rf_id}.") status(".$status_type->{rf_status}.") low_batt("
         .$status_type->{rf_low_batt}.") supervised(".$status_type->{rf_supervised}
         .")" ) unless ($main::config_parms{AD2USB_debug_log} == 0);

      if (exists $main::config_parms{"AD2USB_wireless_".$status_type->{rf_id}}) {
         my ($MZoneLoop, $PartStatus, $ZoneNum, $ZoneName);
         my $lc = 0;
         my $ZoneStatus = "ready";

         # Assign status (zone and partition)
         if ($status_type->{rf_low_batt} == "1") {
            $ZoneStatus = "low battery";
         }
   
         foreach my $wnum(split(",", $main::config_parms{"AD2USB_wireless_".$status_type->{rf_id}})) {
            if ($lc % 2 == 0) { 
               $ZoneNum = $wnum;
            }
            else {
               my ($sensortype, $ZoneLoop) = split("", $wnum);
               $ZoneName = "Unknown";
               $ZoneName = $main::config_parms{"AD2USB_zone_$ZoneNum"} if exists $main::config_parms{"AD2USB_zone_$ZoneNum"};
   
               if ($ZoneLoop eq "1") {$MZoneLoop = $status_type->{rf_loop_fault_1}}
               if ($ZoneLoop eq "2") {$MZoneLoop = $status_type->{rf_loop_fault_2}}
               if ($ZoneLoop eq "3") {$MZoneLoop = $status_type->{rf_loop_fault_3}}
               if ($ZoneLoop eq "4") {$MZoneLoop = $status_type->{rf_loop_fault_4}}
   
               if ("$MZoneLoop" eq "1") {
                  $ZoneStatus = "fault";
               } elsif ("$MZoneLoop" eq 0) {
                 $ZoneStatus = "ready";
               }
   
               $self->{zone_now_status}         = "$ZoneStatus";
               $self->{zone_now_name}           = "$ZoneName";
               $self->{zone_now_num}            = "$ZoneNum";
               ChangeZones( int($ZoneNum), int($ZoneNum), "$ZoneStatus", "", 1);
               if ($sensortype eq "k") {
                  $ZoneStatus = "ready";
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
   elsif ($status_type->{expander}) {
      my $exp_id = $status_type->{exp_address};
      my $input_id = $status_type->{exp_channel};
      my $status = $status_type->{exp_status};

      ::logit( $self{log_file}, "EXPANDER: exp_id($exp_id) input($input_id) status($status)" ) unless ($main::config_parms{AD2USB_debug_log} == 0);

      if (exists $main::config_parms{"AD2USB_expander_$exp_id$input_id"}) {
         my $ZoneNum = $main::config_parms{"AD2USB_expander_$exp_id$input_id"};
         my $ZoneName = "Unknown";
         $ZoneName = $main::config_parms{"AD2USB_zone_$ZoneNum"} if exists $main::config_parms{"AD2USB_zone_$ZoneNum"};
         # Assign status (zone and partition)

         my $ZoneStatus = "ready";
         my $PartStatus = "";
         if ($status == 01) {
            $ZoneStatus = "fault";
            $PartStatus = "not ready";
         }

         $self->{zone_now_status}         = "$ZoneStatus";
         $self->{zone_now_name}           = "$ZoneName";
         $self->{zone_now_num}            = "$ZoneNum";
         ChangeZones( int($ZoneNum), int($ZoneNum), "$ZoneStatus", "", 1);
      }
   }
   elsif ($status_type->{relay}) {
      my $rel_id = $status_type->{rel_address};
      my $rel_input_id = $status_type->{rel_channel};
      my $rel_status = $status_type->{rel_status};

      ::logit( $self{log_file}, "RELAY: rel_id($rel_id) input($rel_input_id) status($rel_status)" ) unless ($main::config_parms{AD2USB_debug_log} == 0);

      if (exists $main::config_parms{"AD2USB_relay_$rel_id$rel_input_id"}) {
         # Assign zone
         my $ZoneNum = $main::config_parms{"AD2USB_relay_$rel_id$rel_input_id"};
         my $ZoneName = "Unknown";
         $ZoneName = $main::config_parms{"AD2USB_zone_$ZoneNum"} if exists $main::config_parms{"AD2USB_zone_$ZoneNum"};

         # Assign status (zone and partition)
         my $ZoneStatus = "ready";
         my $PartStatus = "";
         if ($rel_status == 01) {
            $ZoneStatus = "fault";
            $PartStatus = "not ready";
         }

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

   # NORMAL STATUS TYPE
   # ALWAYS Check Bits in Keypad Message
   if ($status_type->{keypad}) {
      # Set things based on Bit Codes

      # READY
      if ( $status_type->{ready_flag}) {
         my $bypass = ($status_type->{bypassed_flag}) ? 'bypass' : '';
         # Reset all zones, if bypass enabled skip bypassed zones
         ChangeZones( 1, 999, "ready", $bypass, 1);

         my $PartName = my $PartNum = 1;

         $PartName = $main::config_parms{"AD2USB_part_${PartNum}"} 
            if exists $main::config_parms{"AD2USB_part_${PartNum}"};
         $self->{partition_now_msg}    = $status_type->{alphanumeric};
         $self->{partition_now_num}    = $PartNum;
         $self->{partition_now_status} = "ready";
         ChangePartitions( $PartNum, $PartNum, "ready", 1);
         $self->{zone_lowest_fault} = 999;
         $self->{zone_highest_fault} = -1;            

         # Reset state for fault checks
         $self->{zone_last_status} = "";
         $self->{zone_last_num} = "";
         $self->{zone_last_name} = "";
      }

      # ARMED AWAY
      if ( $status_type->{armed_away_flag}) {
         my $PartNum = my $PartName = 1;
         $PartName = $main::config_parms{"AD2USB_part_${PartNum}"} 
            if exists $main::config_parms{"AD2USB_part_${PartNum}"};

         my $mode = "ERROR";
         if (index($status_type->{alphanumeric}, "ALL SECURE")) {
            $mode = "armed away";
         }
         elsif (index($status_type->{alphanumeric}, "You may exit now")) {
            $mode = "exit delay";
         }
         elsif (index($status_type->{alphanumeric}, "or alarm occurs")) {
            $mode = "entry delay";
         }
         elsif (index($status_type->{alphanumeric}, "ZONE BYPASSED")) {
            $mode = "armed away";
         }

         $self->set($mode);
         $self->{partition_now_msg}        = $status_type->{alphanumeric};
         $self->{partition_now_status}     = "$mode";
         $self->{partition_now_num}        = "$PartNum";
         ChangePartitions( int($PartNum), int($PartNum), "$mode", 1);

         # Reset state for fault checks
         $self->{zone_last_status} = "";
         $self->{zone_last_num} = "";
         $self->{zone_last_name} = "";
      }

      # ARMED HOME
      if ( $status_type->{armed_home_flag}) {
         my $PartNum = my $PartName = 1;

         my $mode = "armed stay";
         $PartName = $main::config_parms{"AD2USB_part_${PartNum}"} 
            if exists $main::config_parms{"AD2USB_part_${PartNum}"};
         $self->{partition_now_msg}        = $status_type->{alphanumeric};
         $self->{partition_now_status}     = "$mode";
         $self->{partition_now_num}        = "$PartNum";
         ChangePartitions( int($PartNum), int($PartNum), "$mode", 1);

         # Reset state for fault checks
         $self->{zone_last_status} = "";
         $self->{zone_last_num} = "";
         $self->{zone_last_name} = "";
      }

      # BACKLIGHT
      if ( $status_type->{backlight_flag}) {
         ::logit( $self{log_file}, "Panel backlight is on" ) 
            unless ($main::config_parms{AD2USB_debug_log} == 0);
      }

      # PROGRAMMING MODE
      if ( $status_type->{programming_flag}) {
         ::logit( $self{log_file}, "Panel is in programming mode" ) 
            unless ($main::config_parms{AD2USB_debug_log} == 0);

         # Reset state for fault checks
         $self->{zone_last_status} = "";
         $self->{zone_last_num} = "";
         $self->{zone_last_name} = "";
      }

      # BEEPS
      if ( $status_type->{beep_count}) {
         my $NumBeeps = $status_type->{beep_count};
         ::logit( $self{log_file}, "Panel beeped $NumBeeps times" ) 
            unless ($main::config_parms{AD2USB_debug_log} == 0);
      }

      # A ZONE OR ZONES ARE BYPASSED
      if ( $status_type->{bypassed_flag}) {

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

      # AC POWER
      $$self{ac_power} = 1;
      if ( !$status_type->{ac_flag} ) {
         $$self{ac_power} = 0;
         ::logit( $self{log_file}, "AC Power has been lost" );
      }

      # CHIME MODE
      $self->{chime} = 0;
      if ( $status_type->{chime_flag}) { 
         $self->{chime} = 1;#            ::logit( $self{log_file}, "Chime is off" ) unless ($main::config_parms{AD2USB_debug_log} == 0);
      }

      # ALARM WAS TRIGGERED (Sticky until disarm)
      if ( $status_type->{alarm_past_flag}) {
         my $EventName = "ALARM WAS TRIGGERED";
         ::logit( $self{log_file}, "$EventName" ) unless ($main::config_parms{AD2USB_part_log} == 0);
      }

      # ALARM IS SOUNDING
      if ( $status_type->{alarm_now_flag}) {
         my $EventName = "ALARM IS SOUNDING";

         #TODO: figure out how to get a partition number
         my $PartName = my $PartNum = 1;
         my $ZoneName = $main::config_parms{"AD2USB_zone_$zone_padded"} 
            if exists $main::config_parms{"AD2USB_zone_$zone_padded"};
         $PartName = $main::config_parms{"AD2USB_part_$PartName"} 
            if exists $main::config_parms{"AD2USB_part_$PartName"};
         ::logit( $self{log_file}, "$EventName - Zone $zone_no_pad ($ZoneName)" ) 
            unless ($main::config_parms{AD2USB_part_log} == 0);
         ChangeZones( $zone_no_pad, $zone_no_pad, "alarm", "", 1);
         $self->{zone_now_status}      = "alarm";
         $self->{zone_now_num}         = $zone_no_pad;
         $self->{partition_now_msg}    = $status_type->{alphanumeric};
         $self->{partition_now_status} = "alarm";
         $self->{partition_now_num}    = $PartNum;
         ChangePartitions( int($PartNum), int($PartNum), "alarm", 1);
      }

      # BATTERY LOW
      $self->{battery_low} = 0;
      if ( $status_type->{battery_low_flag}) {
         $self->{battery_low} = 1;
         ::logit( $self{log_file}, "Panel is low on battery" );
      }
   }
   return;
}

#    Determine if the status string requires parsing                    {{{
# Returns a hash reference containing the message details
sub GetStatusType {
   my ($self, $AdemcoStr) = @_;
   my %message;

   # Panel Message Format
   if ($AdemcoStr =~ /(!KPM:)?\[([\d-]*)\],(\d{3}),\[(.*)\],\"(.*)\"/) {
      $message{keypad} = 1;

      # Parse The Cmd into Message Parts
      $message{bit_field} = $2;
      $message{numeric_code} = $3;
      $message{raw_data} = $4;
      $message{alphanumeric} = $5;
      my @flags = ('ready_flag', 'armed_away_flag', 'armed_home_flag',
      'backlight_flag', 'programming_flag', 'beep_count', 'bypassed_flag', 'ac_flag',
      'chime_flag', 'alarm_past_flag', 'alarm_now_flag', 'battery_low_flag', 'no_delay_flag',
      'fire_flag', 'zone_issue_flag', 'perimeter_only_flag');
      for (my $i = 0; $i <= 15; $i++){
         $message{$flags[$i]} = substr($message{bit_field}, $i, 1);
      }

      # Determine the Message Type
      if ( $message{alphanumeric} =~ m/^FAULT/) {
         ::logit( $self{log_file}, "Fault zones available: $AdemcoStr") unless ($main::config_parms{AD2USB_debug_log} == 0);
         $message{fault} = 1;
      }
      elsif ( $message{alphanumeric} =~ m/^BYPAS/ ) {
         ::logit( $self{log_file}, "Bypass zones available: $AdemcoStr") unless ($main::config_parms{AD2USB_debug_log} == 0);
         $message{bypass} = 1;
      }
      elsif ($message{alphanumeric} =~ m/Hit \*|Press \*/) {
         ::logit( $self{log_file}, "Faults available: $AdemcoStr") unless ($main::config_parms{AD2USB_debug_log} == 0);
         $message{fault_avail} = 1;
      }
      else {
         $message{status} = 1;
      }
   }
   elsif ($AdemcoStr =~ /!RFX:(\d{7}),(\d{2})/) {
      ::logit( $self{log_file}, "Wireless status received.") unless ($main::config_parms{AD2USB_debug_log} == 0);
      $message{wireless} = 1;
      $message{rf_id} = $1;
      $message{rf_status} = $2;
      
      $message{rf_unknown_1} = ((hex(substr($message{rf_status}, 1, 1)) & 1) == 1) ? 1 : 0;
      $message{rf_low_batt} = ((hex(substr($message{rf_status}, 1, 1)) & 2) == 2) ? 1 : 0;
      $message{rf_supervised} = ((hex(substr($message{rf_status}, 1, 1)) & 4) == 4) ? 1 : 0;
      $message{rf_unknown_8} = ((hex(substr($message{rf_status}, 1, 1)) & 8) == 8) ? 1 : 0;

      $message{rf_loop_fault_1} = ((hex(substr($message{rf_status}, 0, 1)) & 8) == 8) ? 1 : 0;
      $message{rf_loop_fault_2} = ((hex(substr($message{rf_status}, 0, 1)) & 2) == 2) ? 1 : 0;
      $message{rf_loop_fault_3} = ((hex(substr($message{rf_status}, 0, 1)) & 1) == 1) ? 1 : 0;
      $message{rf_loop_fault_4} = ((hex(substr($message{rf_status}, 0, 1)) & 4) == 4) ? 1 : 0;

   }
   elsif ($AdemcoStr =~ /!EXP:(\d{2}),(\d{2}),(\d{2})/) {
      ::logit( $self{log_file}, "Expander status received.") unless ($main::config_parms{AD2USB_debug_log} == 0);
      $message{expander} = 1;
      $message{exp_address} = $1;
      $message{exp_channel} = $2;
      $message{exp_status} = $3;
   }
   elsif ($AdemcoStr =~ /!REL:(\d{2}),(\d{2}),(\d{2})/) {
      ::logit( $self{log_file}, "Relay status received.") unless ($main::config_parms{AD2USB_debug_log} == 0);
      $message{relay} = 1;
      $message{rel_address} = $1;
      $message{rel_channel} = $2;
      $message{rel_status} = $3;
   }
   elsif ($AdemcoStr =~ /!Sending\.\.\.done/) {
      ::logit( $self{log_file}, "Command sent successfully.") unless ($main::config_parms{AD2USB_debug_log} == 0);
      $message{cmd_sent} = 1;
   }
   else {
      $message{unknown} = 1;
   }
   return \%message;
}

#}}}
#    Change zone statuses for zone indices from start to end            {{{
sub ChangeZones {
   my ($start, $end, $new_status, $neq_status, $log) = @_;
   my $self = $Self; #Kludge

   # Allow for reverse looping from 999->1
   my $reverse = ($start > $end)? 1 : 0;
   for (my $i = $start; (!$reverse && $i <= $end) ||
         ($reverse && ($i >= $start || $i <= $end)); $i++) {
      my $current_status = $self->{zone_status}{"$i"};
      if (($current_status ne $new_status) && ($current_status ne $neq_status)) {
         if (($main::config_parms{AD2USB_zone_log} != 0) && ($log == 1)) {
            my $ZoneNumPadded = sprintf("%03d", $i);
            my $ZoneName = "Unknown";
            $ZoneName = $main::config_parms{"AD2USB_zone_$ZoneNumPadded"}  if exists $main::config_parms{"AD2USB_zone_$ZoneNumPadded"};
            ::logit( $self{log_file}, "Zone $i ($ZoneName) changed from '$current_status' to '$new_status'" ) unless ($main::config_parms{AD2USB_zone_log} == 0);
         }
         $self->{zone_status}{"$i"} = $new_status;
         #  Set child object status if it is registered to the zone
         $$self{zone_object}{"$i"}->set($new_status, $$self{zone_object}{"$i"}) if defined $$self{zone_object}{"$i"};
      }
      $i = 0 if $i == 999; #loop around
   }
}

#}}}
#    Change partition statuses for partition indices from start to end  {{{
sub ChangePartitions {
   my ($start, $end, $new_status, $log) = @_;

   my $self = $Self;
   for (my $i = $start; $i <= $end; $i++) {
      my $current_status = $self->{partition_status}{"$i"};
      if ($current_status ne $new_status) {
         if (($main::config_parms{AD2USB_part_log} != 0) && ($log == 1)) {
            my $PartName = $main::config_parms{"AD2USB_part_$i"}  if exists $main::config_parms{"AD2USB_part_$i"};
            ::logit( $self{log_file}, "Partition $i ($PartName) changed from '$current_status' to '$new_status'" ) unless ($main::config_parms{AD2USB_part_log} == 0);
         }
         $self->{partition_status}{"$i"} = $new_status;
      }
   }
}

#}}}
#    Reset Ademco state to simulate a "now" on some value ie: zone, temp etc.  {{{
sub ResetAdemcoState {
   my ($self) = @_;
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
      $self->{zone_status}{$ZoneNum} = $self->{zone_now_status};
      $self->{zone_time}{$ZoneNum}   = &::time_date_stamp( 17, time );
      undef $self->{zone_now_num};
      undef $self->{zone_now_name};
      undef $self->{zone_now_status};
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
   my $instance = $$self{instance};
   $cmd = $self->{CmdMsg}->{$cmd};

   my $CmdName = ( exists $self->{CmdMsgRev}->{$cmd} ) ? $self->{CmdMsgRev}->{$cmd} : "unknown";
   my $CmdStr = $cmd;

   # Exit if unknown command
   if ( $CmdName =~ /^unknown/ ) {
      ::logit( $self{log_file}, "Invalid ADEMCO panel command : $CmdName ($cmd)");
      return;
   }

   # Exit if password is wrong
   if ( ($password ne $::config_parms{AD2USB_user_master_code}) && ($CmdName ne "ShowFaults" ) ) {
      ::logit( $self{log_file}, "Invalid password for command $CmdName ($password)");
      return;
   }

   ::logit( $self{log_file}, ">>> Sending to ADEMCO panel                      $CmdName ($cmd)" ) unless ($main::config_parms{$instance . '_debug_log'} == 0);
   $self->{keys_sent} = $self->{keys_sent} + length($CmdStr);
   if (defined $Socket_Items{$instance}) {
      if ($Socket_Items{$instance . '_sender'}{'socket'}->active) {
         $Socket_Items{$instance . '_sender'}{'socket'}->set("$CmdStr");
      } else {
         # restart the TCP connection if its lost.
         if ($Socket_Items{$instance}{recon_timer}->inactive) {
            ::print_log("Connection to $instance sending instance of AD2USB was lost, I will try to reconnect in $$self{reconnect_time} seconds");
            $Socket_Items{$instance}{recon_timer}->set($$self{reconnect_time}, sub {
               $Socket_Items{$instance}{'socket'}->start;
               $Socket_Items{$instance . '_sender'}{'socket'}->set("$CmdStr");
            });
         }
      }
   }
   else {
      $main::Serial_Ports{$instance}{'socket'}->write("$CmdStr");
   }
   return "Sending to ADEMCO panel: $CmdName ($cmd)";
}

#}}}
#    user call from MH                                                         {{{

sub zone_now {
   return $_[0]->{zone_now_name} if defined $_[0]->{zone_now_name};
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

=back

=head2 INI PARAMETERS

=head2 NOTES

=head2 AUTHOR

=head2 SEE ALSO

=head2 LICENSE

This program is free software; you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation; either version 2 of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more details.

You should have received a copy of the GNU General Public License along with this program; if not, write to the Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.

=cut

1;

#}}}
#$Log:$

__END__

