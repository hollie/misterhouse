=head1 B<AD2>

=head2 SYNOPSIS

---Example Code and Usage---

=head2 DESCRIPTION

Module for interfacing with the AD2 line of products.  Monitors known events and 
maintains the state of the Ademco system in memory. Module also sends
instructions to the panel as requested.

=head2 CONFIGURATION

Older versions of this library relied almost exclusively on ini parameters.
This revised library provides extensive support for using an mht file to define 
AD2 objects and only requires setting ini parameters for the initial AD2 
Interface configuration. [Feb 5, 2014]

At minimum, you must define the Interface.  In addition, this library provides
for the ability to define separate objects for each zone and relay.  This allows
for the display of these zones as separate items in the MH interface and allows
users to interact directly with these objects using the basic Generic_Item
functions such as tie_event.

Finally, this library permits the definition of Partitions.  Partitions are
available on all Ademco panels, but they are likely foreign to most users as
more than one Partition is rarely used.  In short, Partitions allow for what
appears to be multiple distinct alarm systems to share a single alarm board.
Each zone and alarm panel is assigned to a Partition.  For example, a business
may use partition 1 for the front office and partition 2 for the warehouse, this
allows warehouse personel to arm/disarm the warehouse but not the front office
while providing a single point of contact for the alarm monitoring company.

Within MisterHouse, the Partition is used primarily as a stand in for the alarm
panel.  The Partition object is used to arm/disarm the panel as well as to check
on the agregate state of all of the zones.

=head3 Interface Configuration

There is a small difference in configuring the AD2 Interface for direct 
connections (Serial or USB) or IP Connections (Ser2Sock).

=head4 AD2-Prefix

This library envisions that a user may connect multiple AD2 Interfaces to
MisterHouse.  In order to distinguish between each interface, each interface
must use a unique prefix.  This prefix must take the following form:

   AD2[_digits]

Wherein the _digits suffix is optional.  Each of the following prefixes 
define separate Interfaces:

   AD2
   AD2_1
   AD2_11

=head4 Direct Connections (USB or Serial)

INI file:

   AD2_serial_port=/dev/ttyAMA0

Wherein the format for the parameter name is:

   AD2-Prefix_serial_port

=head4 IP Connections (Ser2Sock)

INI file:

   AD2_server_ip=192.168.11.17
   AD2_server_port=10000

Wherein the format for the parameter name is:

   AD2-Prefix_server_ip
   AD2-Prefix_server_port

=head4 Defining the Interface Object (All Connection Types)

In addition to the above configuration, you must also define the interface
object.  The object can be defined in either an mht file or user code.

In mht file:

   AD2_INTERFACE, $AD2_Interface, AD2

Wherein the format for the definition is:

   AD2_INTERFACE, Object Name, AD2-Prefix

In user code:

   $AD2 = new AD2(AD2);

Wherein the format for the definition is:

   $AD2 = new AD2(AD2-Prefix);

=head3 Partition Configuration

See AD2_Partition

=head3 Zone Configuration

See AD2_Item

=head2 INHERITS

L<Generic_Item>

=head2 METHODS

=over

=cut

package AD2;
use strict;

@AD2::ISA = ('Generic_Item');

my %Socket_Items; #Stores the socket instances and attributes
my %Interfaces; #Stores the relationships btw instances and interfaces
my %Configuration; #Stores the local config parms 

=item C<new()>

Instantiates a new object.

=cut

sub new {
   my ($class, $instance) = @_;
   $instance = "AD2" if (!defined($instance));
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
   $$self{max_zones}      = 250; #The current max zones by any panel, can be increased
   my $year_mon           = &::time_date_stamp( 10, time );
   $$self{log_file}       = $::config_parms{'data_dir'}."/logs/AD2.$year_mon.log";

   bless $self, $class;

   # load command hash
   $$self{CmdMsg} = $self->DefineCmdMsg();
   $$self{CmdMsgRev} = {reverse %{$$self{CmdMsg}}}; #DeRef Hash, Rev, Conv to Ref

   # The following logs default to being enabled, can only be disabled by 
   # proactively setting their ini parameters to 0:
   # AD2_part_log AD2_zone_log AD2_debug_log

   #Set all zones and partitions to ready
   $self->ChangeZones( 1, $$self{max_zones}, "ready", "ready", 0);

   #Store Object with Instance Name
   $self->_set_object_instance($instance);

   #Load the Parameters from the INI file
   $self->read_parms($instance);

   return $self;
}

=item C<get_object_by_instance($instance)>

Takes a scalar instance name, AD2-Prefix, and returns the object associated with
that name.

=cut

sub get_object_by_instance{
   my ($instance) = @_;
   return $Interfaces{$instance};
}

sub _set_object_instance{
   my ($self, $instance) = @_;
   $Interfaces{$instance} = $self;
}

=item C<read_parms()>

Causes MH to read the ini parameters and load them into the local configuration
hash.  This is necessary in order to join together ini and mht defined features.

=cut

sub read_parms{
   my ($self, $instance) = @_;
   foreach my $mkey (keys(%::config_parms)) {
      next if $mkey =~ /_MHINTERNAL_/;
      #Load All Configuration Settings
      $Configuration{$mkey} = $::config_parms{$mkey} if $mkey =~ /^AD2_/;
      #Put wireless settings in correct hash
      if ($mkey =~ /^${instance}_wireless_(.*)/){
         if (index($::config_parms{$mkey}, ',') <= 0){
            #Supports new style ini parameter, wherein each zone is a separate entry:
            #AD2_wireless_[RF_ID],[LOOP],[TYPE]=[ZONE] such as:
            #AD2_wireless_1234567,1,k=10
            $$self{wireless}{$1} = $::config_parms{$mkey};
         }
         else {
            #This code supports the old style ini of wirelss parameters:
            #AD2_wireless_[RF_ID]=[ZONE],[TYPE][LOOP](,repeat) such as:
            #AD2_wireless_1234567=10,s1
            my $rf_id = $1;
            my $lc = 0;
            my $ZoneNum;
            foreach my $wnum(split(",", $::config_parms{$mkey})) {
               if ($lc % 2 == 0) { 
                  $ZoneNum = $wnum;
               }
               else {
                  my ($sensortype, $ZoneLoop) = split("", $wnum);
                  $$self{wireless}{"$rf_id,$ZoneLoop,$sensortype"} 
                     = $ZoneNum;
               }
               $lc++;
            }
         }
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
      if ($mkey =~ /^${instance}_zone_(\d*)$/){
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

=item C<init()>

Used to initialize the serial port.

=cut

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

=item C<serial_startup()>

Called by the MH main script as a result of defining a serial port.

=cut

sub serial_startup {
   my ($instance) = @_;
   my ($port, $BaudRate, $ip);

   if ($::config_parms{$instance . '_serial_port'} and 
         $::config_parms{$instance . '_serial_port'} ne '/dev/none') {
      $port = $::config_parms{$instance .'_serial_port'};
      $BaudRate = ( defined $::config_parms{$instance . '_baudrate'} ) ? $::config_parms{"$instance" . '_baudrate'} : 115200;
      if ( &main::serial_port_create( $instance, $port, $BaudRate, 'none', 'raw' ) ) {
         init( $::Serial_Ports{$instance}{object}, $port );
         ::print_log("[AD2] initializing $instance on port $port at $BaudRate baud") if $main::Debug{'AD2'};
         ::MainLoop_pre_add_hook( sub {AD2::check_for_data($instance, 'serial');}, 1 ) if $main::Serial_Ports{"$instance"}{object};
      }
   }
}

=item C<server_startup()>

Called by the MH main script as a result of defining a server port.

=cut

sub server_startup {
   my ($instance) = @_;

   $Socket_Items{"$instance"}{recon_timer} = ::Timer::new();
   my $ip = $::config_parms{"$instance".'_server_ip'};
   my $port = $::config_parms{"$instance" . '_server_port'};
   ::print_log("  AD2.pm initializing $instance TCP session with $ip on port $port") if $main::Debug{'AD2'};
   $Socket_Items{"$instance"}{'socket'} = new Socket_Item($instance, undef, "$ip:$port", $instance, 'tcp', 'raw');
   $Socket_Items{"$instance" . '_sender'}{'socket'} = new Socket_Item($instance . '_sender', undef, "$ip:$port", $instance . '_sender', 'tcp', 'rawout');
   $Socket_Items{"$instance"}{'socket'}->start;
   $Socket_Items{"$instance" . '_sender'}{'socket'}->start;
   ::MainLoop_pre_add_hook( sub {AD2::check_for_data($instance, 'tcp');}, 1 );
}

=item C<check_for_data()>

Called at the start of every loop. This checks either the serial or server port
for new data.  If data is found, the data is broken down into individual
messages and sent to C<GetStatusType> to be parsed.  The message is then 
compared to the previous data received if this is a duplicate message it is 
logged and ignored.  If this is a new message it is sent to C<CheckCmd>.

=cut

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
            &main::print_log("Connection to $instance instance of AD2 was lost, I will try to reconnect in $$self{reconnect_time} seconds");
            # ::logit("AD2.pm ser2sock connection lost! Trying to reconnect." );
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
         ::print_log("[AD2] " . $Cmd) if $main::Debug{AD2} >= 1;

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
            $self->CheckCmd($status_type);
            $self->{last_cmd} = $Cmd if ($status_type->{keypad});
         }
      }
      else {
         # Save partial command for next serial read
         $self->{IncompleteCmd} = $Cmd;
      }
   }
}

=item C<CheckCmd()>

This routine takes the parsed message and performs the necessary actions that
result.

=cut

sub CheckCmd {
   my ($self, $status_type) = @_;
   my $zone_padded = $status_type->{numeric_code};
   my $zone_no_pad = int($zone_padded);
   my @partitions = @{$status_type->{partition}} 
      if exists $status_type->{partition};
   my $instance = $self->{instance};
   
   if ($status_type->{unknown}) {
      $self->debug_log("UNKNOWN STATUS: $status_type->{cmd}");
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
      #Loop through partions set in message
      foreach my $partition (@partitions){
         #If zone numbers are sequential, there is nothing to do.
         #Reset the zones between the current zone and the last zone. 
         #Do not reset mapped zones, specific messages are recevied for these
         #If the current zone is lower than the previous zone, only reset zones
         #in between if highest zone has remained constant for one full cycle
         if ($zone_no_pad - $self->{zone_last_num}{$partition} != 1) {
            if (($self->{zone_last_num}{$partition} <= $zone_no_pad) &&
               $self->{highest_zone}{$partition} != $self->{zone_last_num}{$partition}){
               $self->{highest_zone}{$partition} = $zone_no_pad;
               # Do not reset the zones in between.  This is a new highest zone
               # number.  Can't be sure if the zone list completed a full cycle
            }
            else {
               $self->ChangeZones( $self->{zone_last_num}{$partition}+1, 
                  $zone_no_pad-1, "ready", "bypass", 1, $partition,1);
               $self->{highest_zone}{$partition} = $zone_no_pad 
                  if ($self->{zone_last_num}{$partition} <= $zone_no_pad);
            }
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
      my $rf_id = $status_type->{rf_id};
      $self->debug_log("WIRELESS: rf_id("
         .$rf_id.") status(".$status_type->{rf_status}.") loop1("
         .$status_type->{rf_loop_fault_1}.") loop2(".$status_type->{rf_loop_fault_2}
         .") loop3(".$status_type->{rf_loop_fault_3}.") loop4("
         .$status_type->{rf_loop_fault_4}.")" );
      $self->debug_log("WIRELESS: rf_id("
         .$status_type->{rf_id}.") status(".$status_type->{rf_status}.") low_batt("
         .$status_type->{rf_low_batt}.") supervised(".$status_type->{rf_supervised}
         .")" );

      foreach my $rf_key (keys $$self{wireless}){
         if ($rf_key =~ /^${rf_id}(.*)/) {
            my $LoopNum = 1;
            my $SensorType = 's';
            ($LoopNum, $SensorType) = split(',', $1);
            my $ZoneNum = $$self{wireless}{$rf_key};

            my $ZoneStatus = "ready";
            if ($status_type->{rf_low_batt} == "1") {
               $ZoneStatus = "low battery";
            }
            if ($status_type->{'rf_loop_fault_'.$LoopNum}) {
               $ZoneStatus = "fault";
            }

            $self->ChangeZones( int($ZoneNum), int($ZoneNum), "$ZoneStatus", "", 1);
            $self->ChangeZones( int($ZoneNum), int($ZoneNum), "ready", "", 1) 
               if ($SensorType eq "k"); #Toggle key buttons back to ready 
               #Not sure this works, set functions are called per loop
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
      
      # Prep mode for future use
      my $mode = '';
      $mode = 'fault' if $status_type->{fault};

      # READY
      if ( $status_type->{ready_flag}) {
         my $bypass = ($status_type->{bypassed_flag}) ? 'bypass' : '';
         $mode = 'ready';
         $mode = 'bypass' if $bypass;
         # Reset all zones, if bypass enabled skip bypassed zones
         for my $partition (@partitions){
            $self->ChangeZones( 1, $$self{max_zones}, "ready", $bypass, 1, $partition);
         }
      }

      # ARMED AWAY
      if ( $status_type->{armed_away_flag}) {
         # TODO The setting of modes needs to be done on partitions
         my $mode = "armed away - error";
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
            $mode = "armed away - bypass";
         }
      }

      # ARMED HOME
      if ( $status_type->{armed_home_flag}) {
         $mode = "armed stay - error";
         if (index($status_type->{alphanumeric}, "You may exit now")) {
            $mode = "exit delay";
         }
         elsif (index($status_type->{alphanumeric}, "or alarm occurs")) {
            $mode = "entry delay";
         }
         elsif (index($status_type->{alphanumeric}, "ZONE BYPASSED")) {
            $mode = "armed stay - bypass";
         }
         elsif (index($status_type->{alphanumeric}, "***STAY***")) {
            $mode = "armed stay";
         }
      }

      # BACKLIGHT
      if ( $status_type->{backlight_flag}) {
         $self->debug_log("Panel backlight is on");
      }

      # PROGRAMMING MODE
      if ( $status_type->{programming_flag}) {
         $mode = "programming";
         $self->debug_log("Panel is in programming mode"); 
      }

      # BEEPS
      if ( $status_type->{beep_count}) {
         my $NumBeeps = $status_type->{beep_count};
         $self->debug_log("Panel beeped $NumBeeps times"); 
      }

      # AC POWER
      $$self{ac_power} = 1;
      if ( !$status_type->{ac_flag} ) {
         $$self{ac_power} = 0;
         $mode = "ac power lost";
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
         $mode = "alarm was triggered";
         $self->debug_log("$EventName" );
      }

      # ALARM IS SOUNDING
      if ( $status_type->{alarm_now_flag}) {
         $mode = "alarm now sounding";
         $self->debug_log("ALARM IS SOUNDING - Zone $zone_no_pad (".$self->zone_name($zone_no_pad).")" );
         $self->ChangeZones( $zone_no_pad, $zone_no_pad, "alarm", "", 1);
      }

      # BATTERY LOW
      $self->{battery_low} = 0;
      if ( $status_type->{battery_low_flag}) {
         $self->{battery_low} = 1;
         $mode = "battery low";
         $self->debug_log("Panel is low on battery");;
      }
      if ($mode ne $self->state && $mode ne ''){
         $self->set($mode);
      }
   }
   return;
}

=item C<GetStatusType()>

This routine parses a message passed in the form of a string and returns a hash
filled with the resulting message data.

=cut

sub GetStatusType {
   my ($self, $AdemcoStr) = @_;
   my $instance = $self->{instance};
   my %message;
   $message{cmd} = $AdemcoStr;

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
         push(@{$message{partition}}, 1); #Default to partition 1
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

=item C<ChangeZones($start, $end, $new_status, $neq_status, $log, 
   $partition, $skip_mapped)>

This routine changes the defined zones to the state that was passed.

$start = Zone number to start at
$end   = Zone number to end at

All zones between and including $start and $end will be updated.  If $start is
greater than $end, the routine will loop around at the max_zones value.

$new_status = The status to which the zones should be changed too.
$neq_status = Do not alter zones that are equal to this status.
$log        = If true will log its actions
$partition  = Only change zones on the defined partition
$skip_mapped= If true, zones which are mapped (expander, relay, wireless) will
not be affected

=cut

sub ChangeZones {
   my ($self, $start, $end, $new_status, $neq_status, $log, $partition, 
      $skip_mapped) = @_;
   my $instance = $self->{instance};
   #Prevent improper start and end to suppress never ending loops.
   $end = $$self{max_zones} if ($end <=0 || $end > $$self{max_zones});
   $start = 1 if ($start <=0 || $start > $$self{max_zones});

   # Allow for reverse looping from max_zones->1
   my $reverse = ($start > $end)? 1 : 0;
   
   # Prevent infinite loop scenario
   my $y = 0;

   for (my $i = $start; ($y <= $$self{max_zones}) &&
         ((!$reverse && $i <= $end) ||
         ($reverse && ($i >= $start || $i <= $end)));
         $i++) {
      my $current_status = $$self{$self->zone_partition($i)}{zone_status}{$i};
      # If partition set, then zone partition must equal that
      if (($current_status ne $new_status) && ($current_status ne $neq_status)
         && (!$partition || ($partition == $self->zone_partition($i)))
         && (!$skip_mapped || (!$self->is_zone_mapped($i)))) {
         if ($log == 1) {
            my $ZoneNumPadded = sprintf("%03d", $i);
            $self->debug_log( "Zone $i (".$self->zone_name($i)
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
         $$self{partition_object}{$zone_partition}->set($partition_status, $$self{zone_object}{"$i"}) 
            if defined $$self{partition_object}{$zone_partition};
      }
      $y++;
      $i = 0 if ($i == $$self{max_zones} && $reverse); #loop around
   }
}

=item C<DefineCmdMsg()>

Creates the Hash of available commands.

This undoubtedly still needs work.

=cut

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
      "AD2Reboot"                      => "=",
      "AD2Configure"                   => "!"
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

=item C<debug_log()>

Used to log messages to the specific AD2 log file.

This can likely be eliminated once testing is complete and replaced with the new
debug routine in Generic_Item.

=cut

sub debug_log {
   my ($self, $text) = @_;
   my $instance = $$self{instance};
   ::logit( $$self{log_file}, $text) unless ($Configuration{$instance.'_debug_log'} == 0);
}

=item C<is_zone_mapped($zone)>

Takes a zone number as a parameter and returns true if it is mapped to a relay,
wireless, or expander.

=cut

sub is_zone_mapped {
   my ($self, $zone) = @_;
   $zone = sprintf "%03s", $zone;
   if (defined $$self{relay}){
      foreach my $mkey (keys $$self{relay}) {
         if ($zone eq $$self{relay}{$mkey}) { return 1 }
      }
   }
   if (defined $$self{wireless}){
      foreach my $mkey (keys $$self{wireless}) {
         if ($zone eq $$self{wireless}{$mkey}) { return 1 }
      }
   }
   if (defined $$self{expander}){
      foreach my $mkey (keys $$self{expander}) {
         if ($zone eq $$self{expander}{$mkey}) { return 1 }
      }
   }
   return 0;
}

=item C<cmd()>

Used to send commands to the Interface.

Needs work.

=cut

sub cmd {
   my ( $self, $cmd, $password ) = @_;
   my $instance = $$self{instance};
   $cmd = $self->{CmdMsg}->{$cmd};

   my $CmdName = ( exists $self->{CmdMsgRev}->{$cmd} ) ? $self->{CmdMsgRev}->{$cmd} : "unknown";
   my $CmdStr = $cmd;

   # Exit if unknown command
   if ( $CmdName =~ /^unknown/ ) {
      ::logit("Invalid ADEMCO panel command : $CmdName ($cmd)");
      return;
   }

   # Exit if password is wrong
   if ( ($password ne $Configuration{$instance.'_user_master_code'}) && ($CmdName ne "ShowFaults" ) ) {
      ::logit("Invalid password for command $CmdName ($password)");
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
            ::print_log("Connection to $instance sending instance of AD2 was lost, I will try to reconnect in $$self{reconnect_time} seconds");
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

=item C<status_zone($zone)>

Takes a zone number and returns its status.

If an object exists for this zone you can also use:

$object->state;

=cut

sub status_zone {
   my ( $self, $zone ) = @_;
   $zone =~ s/^0*//;
   return $$self{$self->zone_partition($zone)}{zone_status}{$zone};
}

=item C<zone_now($zone)>

Takes a zone number and returns its status if the zone status was set on this 
loop.

If an object exists for this zone you can also use:

$object->state_now;

=cut

sub zone_now {
   my ( $self, $zone ) = @_;
   $zone =~ s/^0*//;
   return $self->{zone_now}{$zone};
}

=item C<zone_name($zone)>

Takes a zone number and returns its name.

The name is not used very much, likely was more necessary before zones were
made into individual objects.

=cut

sub zone_name {
   my ( $self, $zone_num ) = @_;
   my $instance = $self->{instance};
   $zone_num = sprintf "%03s", $zone_num;
   return $$self{zone_name}{$zone_num};
}

=item C<zone_partition($zone)>

Takes a zone number and returns the partition that it is a member of.

=cut

sub zone_partition {
   my ( $self, $zone_num ) = @_;
   my $instance = $self->{instance};
   $zone_num = sprintf "%03s", $zone_num;
   my $partition = $$self{zone_partition}{$zone_num};
   # Default to partition 1
   $partition = 1 unless $partition;
   return $partition;
}

=item C<partition_now($part)>

Takes a partition number and returns its status if its status was set on this
loop.

If an object exists for this partition you can also use:

$object->state_now;

=cut

sub partition_now {
   my ( $self, $part ) = @_;
   return $self->{partition_now}{$part};
}

=item C<partition_msg($part)>

Takes a partition number and returns the last alphanumeric message that was sent
by this partition.

=cut

sub partition_msg {
   my ( $self, $part ) = @_;
   return $self->{partition_msg}{part};
}

=item C<partition_name($part)>

Takes a partition number and returns its name.

The name is not used very much, likely was more necessary before partitions were
made into individual objects.

=cut

sub partition_name {
   my ( $self, $part_num ) = @_;
   my $instance = $self->{instance};
   return $$self{partition_name}{$part_num};
}

=item C<status_partition($part)>

Takes a partition number and returns its status.

If an object exists for this partition you can also use:

$object->state;

=cut

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

=item C<cmd_list()>

Returns the list of available commands.

=cut

sub cmd_list {
   my ($self) = @_;
   foreach my $k ( sort keys %{$self->{CmdMsg}} ) {
      &::print_log("$k");
   }
}

=item C<register()>

Used to associate child objects with the interface.

=cut

sub register {
   my ($self, $object, $num, $expander,$relay,$wireless) = @_;
   &::print_log("Registering Child Object on zone $num");
   if ($object->isa('AD2_Item')) {
      $self->{zone_object}{$num} = $object;
      #Put wireless settings in correct hash
      if (defined $wireless){
         $$self{wireless}{$wireless} = $num;
      }
      #Put expander settings in correct hash
      if (defined $expander){
         $$self{expander}{$expander} = $num;
      }
      #Put relay settings in correct hash
      if (defined $relay){
         $$self{relay}{$relay} = $num;
      }
   }
   elsif ($object->isa('AD2_Partition')) {
      $self->{partition_object}{$num} = $object;
   }
}

=item C<get_child_object_name($zone)>

Takes a zone number and returns the name of the child object associated with it.

=cut

sub get_child_object_name {
   my ($self,$zone_num) = @_;
   my $object = $self->{zone_object}{$zone_num};
   return $object->get_object_name() if defined ($object);
}

=back

=head1 B<AD2_Item>

=head2 SYNOPSIS

User code:

    $front_door = new AD2_Item('door','AD2', 5, 1);
    $upstairs_motion = new AD2_Item('motion','AD2', 5, 1);

See C<new()> for a more detailed description of the arguments.

In mht file:

[NOT COMPLETED YET]

=head2 DESCRIPTION

Provides support for creating MH-Style child objects for each zone.  These allow
zones to behave like Generic_Items.  For example, Generic_Item subroutines such
as C<tie_event> and C<get_idle_time> can be used with these devices.

To use these, you must first create the appropriate AD2 Interface object.

=head2 INHERITS

L<Generic_Item>

=head2 METHODS

=over

=cut

package AD2_Item;

@AD2_Item::ISA = ('Generic_Item');

=item C<new($type,$interface,$zone,$partition,$expander,$relay,$wireless)>

Instantiates a new object.

$type      = May be either 'door' or 'motion'.  This just defines the states for
the object
$interface = The AD2-Prefix of the interface that this zone is found on
$zone      = The zone number of this zone
$partition = The partition number of this zone, usually 1

Zone Mapping

$expander  = If not null, the expander address that the zone is mapped to.
$relay     = If not null, the relay address that the zone is mapped to.
$wireless  = If not null, the wireless address that the zone is mapped to.

=cut

sub new
{
   my ($class,$type,$interface,$zone,$partition,$expander,$relay,$wireless) = @_;

   my $self = new Generic_Item();
   bless $self,$class;

   $$self{last_fault} = 0;
   $$self{last_ready} = 0;
   $$self{item_type} = lc($type);
   $interface->register($self,$zone,$expander,$relay,$wireless);
   $zone = sprintf("%03d", $zone);
   $$self{zone_partition}{$zone} = $partition;
   $self->set($interface->status_zone($zone), $self); #Set correct state on startup
   return $self;

}

=item C<set()>

Sets the object's state.

=cut

sub set
{
   my ($self,$p_state,$p_setby) = @_;

      if (ref $p_setby and $p_setby->can('get_set_by')) {
         ::print_log("AD2_Item($$self{object_name})::set($p_state, $p_setby): $$p_setby{object_name} was set by " . $p_setby->get_set_by) if $main::Debug{AD2};
      } else {
         ::print_log("AD2_Item($$self{object_name})::set($p_state, $p_setby)") if $main::Debug{AD2};
      }

      if ($p_state =~ /^fault/ || $p_state eq 'on') {
         $p_state = 'fault';
         $p_state = 'open' if $$self{item_type} eq 'door';
         $p_state = 'motion' if $$self{item_type} eq 'motion';
         $$self{last_fault} = $::Time;

      } elsif ($p_state =~ /^ready/ || $p_state eq 'off') {
         $p_state = 'ready';
         $p_state = 'closed' if $$self{item_type} eq 'door';
         $p_state = 'still' if $$self{item_type} eq 'motion';
         $$self{last_ready} = $::Time;
      }

      $self->SUPER::set($p_state,$p_setby);
}

=item C<get_child_item_type()>

Returns the item type, either 'motion' or 'door'.

=cut

sub get_child_item_type {
   my ($self) = @_;
   return $$self{item_type};
}

=back

=head2 Extraneous Methods

The following methods seem to me to be unnecessary in light of the functions
available in C<Generic_Item>.

=over

=cut

=item C<get_last_close_time()>

Returns the time the object was closed.

=cut

sub get_last_close_time {
   my ($self) = @_;
   return $$self{last_ready};
}

=item C<get_last_open_time()>

Returns the time the object was opened.

=cut

sub get_last_open_time {
   my ($self) = @_;
   return $$self{last_fault};
}

=item C<get_last_still_time()>

Returns the time the object was still.

=cut

sub get_last_still_time {
   my ($self) = @_;
   return $$self{last_ready};
}

=item C<get_last_motion_time()>

Returns the time the object was motion.

=cut

sub get_last_motion_time {
   my ($self) = @_;
   return $$self{last_fault};
}

=back

=head1 B<AD2_Partition>

=head2 SYNOPSIS

User code:

    $partition_1 = new AD2_Partition('AD2', 1, 31);

See C<new()> for a more detailed description of the arguments.

In mht file:

[NOT COMPLETED YET]

=head2 DESCRIPTION

Provides support for creating MH-Style child objects for each partition.

For an explanation of what a partition is, please see the Description section
of C<AD2>.  

The Partition is used primarily as a stand in for the alarm panel.  The 
Partition object is used to arm/disarm the panel as well as to check on the 
agregate state of all of the zones that are within this partition.

=head2 INHERITS

L<Generic_Item>

=head2 METHODS

=over

=cut

package AD2_Partition;
@AD2_Partition::ISA = ('Generic_Item');

=item C<new($interface, $partition, $address)>

Instantiates a new object.

$interface = The AD2-Prefix of the interface that this zone is found on
$partition = The partition number, usually 1
$address   = The address of a panel that is assigned to this partition.  For
non-addressable systems this should be set to 31.

While there may be multiple panels on a partition, and as a result multiple
addresses, only ONE address is needed in $address.

=cut

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

Kirk Friedenberger <kfriedenberger@gmail.com>
Wayne Gatlin <wayne@razorcla.ws>
H Plato <hplato@gmail.com>
Kevin Robert Keegan

=head2 SEE ALSO

=head2 LICENSE

This program is free software; you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation; either version 2 of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more details.

You should have received a copy of the GNU General Public License along with this program; if not, write to the Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.

=cut

1;