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

my %Socket_Items; #Stores the socket instances and attributes
my %Interfaces; #Stores the relationships btw instances and interfaces
my %Configuration; #Stores the local config parms 

#    Starting a new object                                                  {{{
# Called by user code `$AD2USB = new AD2USB`
sub new {
   my ($class, $instance) = @_;
   $instance = "AD2USB" if (!defined($instance));
   ::print_log("Starting $instance instance of ADEMCO panel interface module");

   my $self = new Generic_Item();

   # Initialize Variables
   $$self{ac_power}       = 0;
   $$self{battery_low}    = 1;
   $$self{chime}          = 0;
   $$self{keys_sent}      = 0;
   $$self{instance}       = $instance;
   $$self{reconnect_time} = $::config_parms{$instance.'_ser2sock_recon'};
   $$self{reconnect_time} = 10 if !defined($$self{reconnect_time});
   $$self{log_file}       = $::config_parms{'data_dir'}."/logs/AD2USB.$::Year_Month_Now.log";

   bless $self, $class;

   # load command hash
   $$self{CmdMsg} = $self->DefineCmdMsg();
   $$self{CmdMsgRev} = {reverse %{$$self{CmdMsg}}}; #DeRef Hash, Rev, Conv to Ref

   # The following logs default to being enabled, can only be disabled by 
   # proactively setting their ini parameters to 0:
   # AD2USB_part_log AD2USB_zone_log AD2USB_debug_log

   #Set all zones and partitions to ready
   $self->ChangeZones( 1, 999, "ready", "ready", 0);

   #Store Object with Instance Name
   $self->set_object_instance($instance);

   #Load the Parameters from the INI file
   $self->read_parms($instance);

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

# Reads the ini settings and pushes them into the appropriate Hashes
sub read_parms{
   my ($self, $instance) = @_;
   foreach my $mkey (keys(%::config_parms)) {
      next if $mkey =~ /_MHINTERNAL_/;
      #Load All Configuration Settings
      $Configuration{$mkey} = $::config_parms{$mkey} if $mkey =~ /^AD2USB_/;
      #Put wireless settings in correct hash
      if ($mkey =~ /^${instance}_wireless_(.*)/){
         $$self{wireless}{$1} = $::config_parms{$mkey};
      }
      #Put expander settings in correct hash
      if ($mkey =~ /^${instance}_expander_(.*)/){
         $$self{expander}{$1} = $::config_parms{$mkey};
      }
      #Put relay settings in correct hash
      if ($mkey =~ /^${instance}_relay_(.*)/){
         $$self{relay}{$1} = $::config_parms{$mkey};
      }
      #Put Partition Addresses in Correct Hash
      if ($mkey =~ /^${instance}_partition_(\d*)_address$/){
         $$self{partition_address}{$1} = $::config_parms{$mkey};
      }
      #Put Zone Names in Correct Hash
      if ($mkey =~ /^${instance}_partition_(\d*)$/){
         $$self{zone_name}{$1} = $::config_parms{$mkey};
      }
      #Put Zone Partition Relationship in Correct Hash
      if ($mkey =~ /^${instance}_zone_(\d*)_partition$/){
         $$self{zone_partition}{$1} = $::config_parms{$mkey};
      }
      #Put Partition Name in Correct Hash
      if ($mkey =~ /^${instance}_part_(\d)$/){
         $$self{partition_name}{$1} = $::config_parms{$mkey};
      }
   }
}

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
      $BaudRate = ( defined $::config_parms{$instance . '_baudrate'} ) ? $::config_parms{"$instance" . '_baudrate'} : 115200;
      if ( &main::serial_port_create( $instance, $port, $BaudRate, 'none', 'raw' ) ) {
         init( $::Serial_Ports{$instance}{object}, $port );
         ::print_log("[AD2USB] initializing $instance on port $port at $BaudRate baud") if $main::Debug{'AD2USB'};
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
   ::print_log("  AD2USB.pm initializing $instance TCP session with $ip on port $port") if $main::Debug{'AD2USB'};
   $Socket_Items{"$instance"}{'socket'} = new Socket_Item($instance, undef, "$ip:$port", $instance, 'tcp', 'raw');
   $Socket_Items{"$instance" . '_sender'}{'socket'} = new Socket_Item($instance . '_sender', undef, "$ip:$port", $instance . '_sender', 'tcp', 'rawout');
   $Socket_Items{"$instance"}{'socket'}->start;
   $Socket_Items{"$instance" . '_sender'}{'socket'}->start;
   ::MainLoop_pre_add_hook( sub {AD2USB::check_for_data($instance, 'tcp');}, 1 );
}

#}}}

#    check for incoming data on serial port                                 {{{
# This is called once per loop by a Mainloop_pre hook, it parses out the string
# of data into individual messages.  
sub check_for_data {
   my ($instance, $connecttype) = @_;
   my $self = get_object_by_instance($instance);
   my $NewCmd;

   # Clear Zone and Partition_Now Function
   $self->{zone_now} = ();
   $self->{partition_now} = ();

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
            # ::logit( $$self{log_file}, "AD2USB.pm ser2sock connection lost! Trying to reconnect." );
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
            $self->debug_log("DUPE: $Cmd");
         }
         else {
            # This is a non-dupe panel message or a fault panel message or a
            # relay or RF or zone expander message or something important
            # Log the message, parse it, and store it to detect future dupes
            $self->debug_log("MSG: $Cmd");
            $self->CheckCmd($Cmd);
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
   my @partitions = $status_type->{partition};
   my $instance = $self->{instance};
   
   if ($status_type->{unknown}) {
      $self->debug_log("UNKNOWN STATUS: $CmdStr");
   }
   elsif ($status_type->{cmd_sent}) {
      if ($self->{keys_sent} == 0) {
         $self->debug_log("Key sent from ANOTHER panel.");
      }
      else {
         $self->{keys_sent}--;
         $self->debug_log("Key received ($self->{keys_sent} left)");
      }
   }
   elsif ($status_type->{fault_avail}) {
      #Send command to show faults
      cmd( $self, "ShowFaults" );
   }
   elsif ($status_type->{fault}) {
      # Each fault message tells us two things, 1) this zone is faulted and 
      # 2) all zones between this zone and the last fault are ready.
      
      #Loop through partions set in message
      foreach my $partition (@partitions){
         #Reset the zones between the current zone and the last zone. If zones
         #are sequential do nothing, if same zone, reset all other zones
         if ($self->{zone_last_num}{$partition} - $zone_no_pad > 1 
            || $self->{zone_last_num}{$partition} - $zone_no_pad == 0) {
            $self->ChangeZones( $self->{zone_last_num}{$partition}+1, $zone_no_pad-1, "ready", "bypass", 1, $partition);
         }
   
         # Set this zone to faulted
         $self->ChangeZones( $zone_no_pad, $zone_no_pad, "fault", "", 1);
         
         # Store Zone Number for Use in Fault Loop
         $self->{zone_last_num}{$partition}           = $zone_no_pad;
      }
   }
   elsif ($status_type->{bypass}) {
      $self->ChangeZones( $zone_no_pad, $zone_no_pad, "bypass", "", 1);
   }
   elsif ($status_type->{wireless}) {
      $self->debug_log( $$self{log_file}, "WIRELESS: rf_id("
         .$status_type->{rf_id}.") status(".$status_type->{rf_status}.") loop1("
         .$status_type->{rf_loop_fault_1}.") loop2(".$status_type->{rf_loop_fault_2}
         .") loop3(".$status_type->{rf_loop_fault_3}.") loop4("
         .$status_type->{rf_loop_fault_4}.")" );
      $self->debug_log( $$self{log_file}, "WIRELESS: rf_id("
         .$status_type->{rf_id}.") status(".$status_type->{rf_status}.") low_batt("
         .$status_type->{rf_low_batt}.") supervised(".$status_type->{rf_supervised}
         .")" );

      if (defined $$self{wireless}{$status_type->{rf_id}}) {
         my ($MZoneLoop, $PartStatus, $ZoneNum);
         my $lc = 0;
         my $ZoneStatus = "ready";

         # Assign status (zone and partition)
         if ($status_type->{rf_low_batt} == "1") {
            $ZoneStatus = "low battery";
         }
   
         foreach my $wnum(split(",", $$self{wireless}{$status_type->{rf_id}})) {
            if ($lc % 2 == 0) { 
               $ZoneNum = $wnum;
            }
            else {
               my ($sensortype, $ZoneLoop) = split("", $wnum);
               if ($ZoneLoop eq "1") {$MZoneLoop = $status_type->{rf_loop_fault_1}}
               if ($ZoneLoop eq "2") {$MZoneLoop = $status_type->{rf_loop_fault_2}}
               if ($ZoneLoop eq "3") {$MZoneLoop = $status_type->{rf_loop_fault_3}}
               if ($ZoneLoop eq "4") {$MZoneLoop = $status_type->{rf_loop_fault_4}}
   
               if ("$MZoneLoop" eq "1") {
                  $ZoneStatus = "fault";
               } elsif ("$MZoneLoop" eq 0) {
                 $ZoneStatus = "ready";
               }

               $self->ChangeZones( int($ZoneNum), int($ZoneNum), "$ZoneStatus", "", 1);
               if ($sensortype eq "k") {
                  $ZoneStatus = "ready";
                  $self->ChangeZones( int($ZoneNum), int($ZoneNum), "$ZoneStatus", "", 1);
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

      $self->debug_log("EXPANDER: exp_id($exp_id) input($input_id) status($status)");

      if (my $ZoneNum = $$self{expander}{$exp_id.$input_id}) {
         my $ZoneStatus = ($status == 01) ? "fault" : "ready";
         $self->ChangeZones( int($ZoneNum), int($ZoneNum), "$ZoneStatus", "", 1);
      }
   }
   elsif ($status_type->{relay}) {
      my $rel_id = $status_type->{rel_address};
      my $rel_input_id = $status_type->{rel_channel};
      my $rel_status = $status_type->{rel_status};

      $self->debug_log("RELAY: rel_id($rel_id) input($rel_input_id) status($rel_status)");

      if (my $ZoneNum = $$self{relay}{$rel_id.$rel_input_id}) {
         my $ZoneStatus = ($rel_status == 01) ? "fault" : "ready";
         $self->ChangeZones( int($ZoneNum), int($ZoneNum), "$ZoneStatus", "", 1);
      }
   }

   # NORMAL STATUS TYPE
   # ALWAYS Check Bits in Keypad Message
   if ($status_type->{keypad}) {
      # If this was not a fault message then clear log of last fault msg
      foreach my $partition (@partitions){
         $self->{zone_last_num}{$partition} = "" unless $status_type->{fault};
         $self->{partition_msg}{$partition} = $status_type->{alphanumeric};
      }
      
      # Set things based on Bit Codes

      # READY
      if ( $status_type->{ready_flag}) {
         my $bypass = ($status_type->{bypassed_flag}) ? 'bypass' : '';
         # Reset all zones, if bypass enabled skip bypassed zones
         foreach my $partition (@partitions){
            $self->ChangeZones( 1, 999, "ready", $bypass, 1, $partition);
         }
         # TODO - If the partition is set to STAY, does a fault on a motion
         # sensor cause the ready flag to be set to 0?  If not, then we need
         # to avoid alterning mapped zones.
      }

      # ARMED AWAY
      if ( $status_type->{armed_away_flag}) {
         # TODO The setting of modes needs to be done on partitions
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
      }

      # ARMED HOME
      if ( $status_type->{armed_home_flag}) {
         $self->set("armed stay");
      }

      # BACKLIGHT
      if ( $status_type->{backlight_flag}) {
         $self->debug_log("Panel backlight is on");
      }

      # PROGRAMMING MODE
      if ( $status_type->{programming_flag}) {
         $self->debug_log("Panel is in programming mode"); 
      }

      # BEEPS
      if ( $status_type->{beep_count}) {
         my $NumBeeps = $status_type->{beep_count};
         $self->debug_log("Panel beeped $NumBeeps times"); 
      }

      # A ZONE OR ZONES ARE BYPASSED
      if ( $status_type->{bypassed_flag}) {
      }

      # AC POWER
      $$self{ac_power} = 1;
      if ( !$status_type->{ac_flag} ) {
         $$self{ac_power} = 0;
         $self->debug_log("AC Power has been lost");;
      }

      # CHIME MODE
      $self->{chime} = 0;
      if ( $status_type->{chime_flag}) { 
         $self->{chime} = 1;#            $self->debug_log("Chime is off");
      }

      # ALARM WAS TRIGGERED (Sticky until disarm)
      if ( $status_type->{alarm_past_flag}) {
         my $EventName = "ALARM WAS TRIGGERED";
         $self->debug_log( $$self{log_file}, "$EventName" );
      }

      # ALARM IS SOUNDING
      if ( $status_type->{alarm_now_flag}) {
         $self->debug_log( $$self{log_file}, "ALARM IS SOUNDING - Zone $zone_no_pad (".$self->zone_name($zone_no_pad).")" );
         $self->ChangeZones( $zone_no_pad, $zone_no_pad, "alarm", "", 1);
      }

      # BATTERY LOW
      $self->{battery_low} = 0;
      if ( $status_type->{battery_low_flag}) {
         $self->{battery_low} = 1;
         $self->debug_log("Panel is low on battery");;
      }
   }
   return;
}

#    Determine if the status string requires parsing                    {{{
# Returns a hash reference containing the message details
sub GetStatusType {
   my ($self, $AdemcoStr) = @_;
   my $instance = $self->{instance};
   my %message;

   # Panel Message Format
   if ($AdemcoStr =~ /(!KPM:)?\[([\d-]*)\],(\d{3}),\[(.*)\],\"(.*)\"/) {
      $message{keypad} = 1;

      # Parse The Cmd into Message Parts
      $message{bit_field} = $2;
      $message{numeric_code} = $3;
      $message{raw_data} = $4;
      $message{alphanumeric} = $5;
      
      # Partition Data is Contained in the Raw Data, in the form of a bit mask 
      # identifying the panels that each message is destined for.  By knowing 
      # which panels are on which partitions, we can determine the partition of 
      # this message.
      my $address_mask = substr($message{raw_data}, 2, 8);
      my @addresses;
      for (my $b = 3; $b >= 0; $b--){
          my $byte = hex(uc substr($address_mask, -2));
          $address_mask = substr($address_mask, 0, -2);
          for (my $i = 0; $i <= 7; $i++){
              push (@addresses, (($b*8)+$i)) if ($byte &0b1);
              $byte = $byte >> 1;
          }
      }
      #Place message in partition if address is equal to partition, or no 
      #address is specified (system wide messages).
      foreach my $partition (keys %{$$self{partition_address}}){
         my $part_addr = $$self{partition_address}{$partition};
         if (grep($part_addr, @addresses) || 
            (scalar @addresses == 0)) {
            push(@{$message{partition}}, $partition);
         }
      }
      if (scalar $message{partition} == 0){
         # The addresses identified in this message did not match any defined
         # partition addresses, default to putting in partition 1.
         @{$message{partition}} = (1); #Default to partition 1
      }

      # Decipher and Set Bit Flags
      my @flags = ('ready_flag', 'armed_away_flag', 'armed_home_flag',
      'backlight_flag', 'programming_flag', 'beep_count', 'bypassed_flag', 'ac_flag',
      'chime_flag', 'alarm_past_flag', 'alarm_now_flag', 'battery_low_flag', 'no_delay_flag',
      'fire_flag', 'zone_issue_flag', 'perimeter_only_flag');
      for (my $i = 0; $i <= 15; $i++){
         $message{$flags[$i]} = substr($message{bit_field}, $i, 1);
      }

      # Determine the Message Type
      if ( $message{alphanumeric} =~ m/^FAULT/) {
         $self->debug_log("Fault zones available: $AdemcoStr");
         $message{fault} = 1;
      }
      elsif ( $message{alphanumeric} =~ m/^BYPAS/ ) {
         $self->debug_log("Bypass zones available: $AdemcoStr");
         $message{bypass} = 1;
      }
      elsif ($message{alphanumeric} =~ m/Hit \*|Press \*/) {
         $self->debug_log("Faults available: $AdemcoStr");
         $message{fault_avail} = 1;
      }
      else {
         $message{status} = 1;
      }
   }
   elsif ($AdemcoStr =~ /!RFX:(\d{7}),(\d{2})/) {
      $self->debug_log("Wireless status received.");
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
      $self->debug_log("Expander status received.");
      $message{expander} = 1;
      $message{exp_address} = $1;
      $message{exp_channel} = $2;
      $message{exp_status} = $3;
   }
   elsif ($AdemcoStr =~ /!REL:(\d{2}),(\d{2}),(\d{2})/) {
      $self->debug_log("Relay status received.");
      $message{relay} = 1;
      $message{rel_address} = $1;
      $message{rel_channel} = $2;
      $message{rel_status} = $3;
   }
   elsif ($AdemcoStr =~ /!Sending\.\.\.done/) {
      $self->debug_log("Command sent successfully.");
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
   my ($self, $start, $end, $new_status, $neq_status, $log, $partition) = @_;
   my $instance = $self->{instance};

   # Allow for reverse looping from 999->1
   my $reverse = ($start > $end)? 1 : 0;
   for (my $i = $start; (!$reverse && $i <= $end) ||
         ($reverse && ($i >= $start || $i <= $end)); $i++) {
      my $current_status = $$self{$self->zone_partition($i)}{zone_status}{$i};
      # If partition set, then zone partition must equal that
      if (($current_status ne $new_status) && ($current_status ne $neq_status)
         && (!$partition || ($partition == $self->zone_partition($i)))) {
         if ($log == 1) {
            my $ZoneNumPadded = sprintf("%03d", $i);
            $self->debug_log( $$self{log_file}, "Zone $i (".$self->zone_name($i)
               .") changed from '$current_status' to '$new_status'" );
         }
         $$self{$self->zone_partition($i)}{zone_status}{$i} = $new_status;
         #  Store Change for Zone_Now Function
         $self->{zone_now}{"$i"} = 1;
         #  Store Change for Partition_Now Function
         $self->{partition_now}{$partition} = 1;
         #  Set child object status if it is registered to the zone
         $$self{zone_object}{"$i"}->set($new_status, $$self{zone_object}{"$i"}) 
            if defined $$self{zone_object}{"$i"};
         my $zone_partition = $self->zone_partition($i);
         my $partition_status = $self->status_partition($zone_partition);
         $$self{parition_object}{$zone_partition}->set($partition_status, $$self{zone_object}{"$i"}) 
            if defined $$self{parition_object}{$zone_partition};
      }
      $i = 0 if ($i == 999 && $reverse); #loop around
   }
}

#}}}

#    Define hash with Ademco commands                                           {{{
sub DefineCmdMsg {
   my ($self) = @_;
   my $instance = $self->{instance};
   my %Return_Hash = (
      "Disarm"                            => $Configuration{$instance."_user_master_code"}."1",
      "ArmAway"                           => $Configuration{$instance."_user_master_code"}."2",
      "ArmStay"                           => $Configuration{$instance."_user_master_code"}."3",
      "ArmAwayMax"                        => $Configuration{$instance."_user_master_code"}."4",
      "Test"                              => $Configuration{$instance."_user_master_code"}."5",
      "Bypass"                            => $Configuration{$instance."_user_master_code"}."6#",
      "ArmStayInstant"                    => $Configuration{$instance."_user_master_code"}."7",
      "Code"                              => $Configuration{$instance."_user_master_code"}."8",
      "Chime"                             => $Configuration{$instance."_user_master_code"}."9",
      "ToggleVoice"                       => '#024',
      "ShowFaults"                        => "*",
      "AD2USBReboot"                      => "=",
      "AD2USBConfigure"                   => "!"
   );

   my $two_digit_zone;
   foreach my $key (keys %Configuration) {
      #Create Commands for Relays
      if ($key =~ /^${instance}_output_(\D+)_(\d+)$/){
         if ($1 eq 'co') {
            $Return_Hash{$Configuration{$key}."c"} = $Configuration{$instance."_user_master_code"}."#70$2";
            $Return_Hash{$Configuration{$key}."o"} = $Configuration{$instance."_user_master_code"}."#80$2";
         }
         elsif ($1 eq 'oc') {
            $Return_Hash{$Configuration{$key}."o"} = $Configuration{$instance."_user_master_code"}."#80$2";
            $Return_Hash{$Configuration{$key}."c"} = $Configuration{$instance."_user_master_code"}."#70$2";
         }
         elsif ($1 eq 'o') {
            $Return_Hash{$Configuration{$key}."o"} = $Configuration{$instance."_user_master_code"}."#80$2";
         }
         elsif ($1 eq 'c') {
            $Return_Hash{$Configuration{$key}."c"} = $Configuration{$instance."_user_master_code"}."#70$2";
         }
      }
      #Create Commands for Zone Expanders
      elsif ($key =~ /^${instance}_expander_(\d+)$/) {
         $two_digit_zone = substr($Configuration{$key}, 1); #Trim leading zero
         $Return_Hash{"exp".$Configuration{$key}."c"} = "L$two_digit_zone"."0";
         $Return_Hash{"exp".$Configuration{$key}."f"} = "L$two_digit_zone"."1";
         $Return_Hash{"exp".$Configuration{$key}."p"} = "L$two_digit_zone"."2"; 
      }
   }

   return \%Return_Hash;
}

sub debug_log {
   my ($self, $text) = @_;
   my $instance = $$self{instance};
   ::logit( $$self{log_file}, $text) unless ($Configuration{$instance.'_debug_log'} == 0);
}

#}}}
#    Define hash with all zone numbers and names {{{
sub MappedZones {
   my ($self, $zone) = @_;
   my $instance = $self->{instance};
   foreach my $mkey (keys $$self{relay}) {
      if ($zone eq $$self{relay}{$mkey}) { return 1 }
   }
   foreach my $mkey (keys $$self{wireless}) {
      if ($zone eq $$self{wireless}{$mkey}) { return 1 }
   }
   foreach my $mkey (keys $$self{expander}) {
      if ($zone eq $$self{expander}{$mkey}) { return 1 }
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
      ::logit( $$self{log_file}, "Invalid ADEMCO panel command : $CmdName ($cmd)");
      return;
   }

   # Exit if password is wrong
   if ( ($password ne $Configuration{$instance.'_user_master_code'}) && ($CmdName ne "ShowFaults" ) ) {
      ::logit( $$self{log_file}, "Invalid password for command $CmdName ($password)");
      return;
   }

   $self->debug_log(">>> Sending to ADEMCO panel              $CmdName ($cmd)");
   $self->{keys_sent} = $self->{keys_sent} + length($CmdStr);
   if (defined $Socket_Items{$instance}) {
      if ($Socket_Items{$instance . '_sender'}{'socket'}->active) {
         $Socket_Items{$instance . '_sender'}{'socket'}->set("$CmdStr");
      } else {
         # restart the TCP connection if its lost.
         if ($Socket_Items{$instance}{recon_timer}->inactive) {
            ::print_log("Connection to $instance sending instance of AD2USB was lost, I will try to reconnect in $$self{reconnect_time} seconds");
            $Socket_Items{$instance}{recon_timer}->set($$self{reconnect_time}, sub {
               $Socket_Items{$instance . '_sender'}{'socket'}->start;
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

sub status_zone {
   my ( $self, $zone ) = @_;
   $zone =~ s/^0*//;
   return $$self{$self->zone_partition($zone)}{zone_status}{$zone};
}

sub zone_now {
   my ( $self, $zone ) = @_;
   $zone =~ s/^0*//;
   return $self->{zone_now}{$zone};
}

sub zone_name {
   my ( $self, $zone_num ) = @_;
   my $instance = $self->{instance};
   $zone_num = sprintf "%03s", $zone_num;
   return $$self{zone_name}{$zone_num};
}

sub zone_partition {
   my ( $self, $zone_num ) = @_;
   my $instance = $self->{instance};
   $zone_num = sprintf "%03s", $zone_num;
   my $partition = $$self{zone_partition}{$zone_num};
   # Default to partition 1
   $partition = 1 unless $partition;
   return $partition;
}

sub partition_now {
   my ( $self, $part ) = @_;
   return $self->{partition_now}{$part};
}

sub partition_msg {
   my ( $self, $part ) = @_;
   return $self->{partition_msg}{part};
}

sub partition_name {
   my ( $self, $part_num ) = @_;
   my $instance = $self->{instance};
   return $$self{partition_name}{$part_num};
}

sub status_partition {
   my ( $self, $partition ) = @_;
   my %partition_zones = %{$$self{$partition}{zone_status}};
   my $partition_status = 'ready';
   for my $zone (keys %partition_zones){
      if ($partition_zones{$zone} eq 'fault'){
         $partition_status = 'fault';
         last;
      }
      elsif ($partition_zones{$zone} eq 'alarm'){
         $partition_status = 'alarm';
         last;
      }
      elsif ($partition_zones{$zone} eq 'bypass'){
         $partition_status = 'bypass';
      }
   }
   return $partition_status;
}

sub cmd_list {
   my ($self) = @_;
   foreach my $k ( sort keys %{$self->{CmdMsg}} ) {
      &::print_log("$k");
   }
}
#}}}
##Used to register a child object to a zone or partition. Allows for MH-style Door & Motion sensors {{{
sub register {
   my ($self, $object, $num ) = @_;
   &::print_log("Registering Child Object on zone $num");
   if ($object->isa('AD2USB_Motion_Item') || $object->isa('AD2USB_Door_Item')) {
      $self->{zone_object}{$num} = $object;
   }
   elsif ($object->isa('AD2USB_Partition')) {
      $self->{partition_object}{$num} = $object;
   }
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
   my ($class,$interface,$zone,$partition) = @_;

   my $self = new Generic_Item();
   bless $self,$class;

   $$self{last_open} = 0;
   $$self{last_closed} = 0;
   $$self{item_type} = 'door';
   $interface->register($self,$zone);
   $zone = sprintf("%03d", $zone);
   $$self{zone_partition}{$zone} = $partition;
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

      if ($p_state =~ /^fault/ || $p_state eq 'on') {
         $p_state = 'open';
         $$self{last_open} = $::Time;

      } elsif ($p_state =~ /^ready/ || $p_state eq 'off') {
         $p_state = 'closed';
         $$self{last_closed} = $::Time;
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

#}}}
package AD2USB_Motion_Item;
@AD2USB_Motion_Item::ISA = ('Generic_Item');

sub new
{
   my ($class,$interface,$zone,$partition) = @_;

   my $self = new Generic_Item();
   bless $self,$class;

   $$self{last_still} = 0;
   $$self{last_motion} = 0;
   $$self{item_type} = 'motion';
   $interface->register($self,$zone);
   $zone = sprintf("%03d", $zone);
   $$self{zone_partition}{$zone} = $partition;
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

package AD2USB_Partition;
@AD2USB_Partition::ISA = ('Generic_Item');

sub new
{
   my ($class,$interface, $partition, $address) = @_;
   my $self = new Generic_Item();
   bless $self,$class;
   $$interface{partition_address}{$partition} = $address;
   $interface->register($self,$partition);
   return $self;
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

