#
#
#    The basic control packet allows the third party controller to
#    - Toggle On/Off state of the Spa, Pool, Aux 1 - 7.
#    - Enable or disable the Spa side remote(s).
#    - Cancel any current circuit delays (not recommended).
#    - Change/select heat source/method for Spa or Pool.
#    - Change/set desired temperature for Spa and/or Pool.
#    - Control Dimmers, (if unit has dimmers installed).
#    - Change/set the current time of day in LX3xxx control units clock.
#
#    The basic acknowledge packet allows the third party to determine
#    - Current state of Spa, Pool, Aux 1 - 7.
#    - Current state of Heater and Solar for both Spa and Pool.
#    - Whether LX3xxx is in Service mode (no commands should be sent).
#    - Current state of Spa side remotes (enabled or not).
#    - Current heat source selection.
#    - Solar presence.
#    - Freeze protection mode.
#    - Current water and solar temperature for Spa and Pool.
#    - Desired/set temperature for Spa and Pool.
#    - Air Temperature (Freeze sensor, not intended offer an accurate )
#                      (air temperature                               )
#    - Status of temperature sensors.
#    - Current time of day stored in LX3xxx unit.
#
#    Add these entries to your mh.ini file:
#
#    Compool_port=COM2
# 
#    bsobel@vipmail.com'
#    May 16, 2000
#
#

# noloop=start

#
# This should go into mh proper?
#
if ($config_parms{Compool_port}) 
{
#   require 'Compool.pm';
    my($speed) = $config_parms{Compool_baudrate} || 9600;
    if (&serial_port_create('Compool', $config_parms{Compool_port}, $speed, 'none', 'raw')) 
    {
        &Compool::init($Serial_Ports{Compool}{object}); 
    }
}
# noloop=stop

#use strict;
my %Compool_Data;
my $temp;

if ($New_Second) 
{
    if ($Serial_Ports{Compool}{object})
    {
        my $data, my $serial_port = $Serial_Ports{Compool}{object};
        $serial_port->reset_error;
        if ($data = $serial_port->input) 
        {
            my $index = index($data,"\xFF\xAA");
            if($index)
            {
                $data = substr($data,$index,24);
                if(length($data) > 5)		# 5 is the minimum length required
                {
    		    my $Checksum = unpack('%16C*', substr($data,0,22)) % 65536;
                    my $Checksum = pack("CC", (($Checksum >> 8) & 0xFF), ($Checksum & 0xFF));

		    #
		    # Check if this is tagged as a basic acknowledge packet (Opcode == 2 && InfoFieldLengh == 10h)
                    #
	            if(substr($data,4,1) eq "\x02" && substr($data,5,1) eq "\x10" && length($data) >= 24 && $Checksum eq substr($data,22,2))
		    {
	                print "Compool BAP data : " . unpack('H*', $data) . "\n";

			# If first packet then we must initialize the Next_ data for the equipment to be in the opposite bit states
                        # as the data inidicates so we fire the first get_device_now triggers.

			if ($Compool_Data{$serial_port}{Last_Basic_Acknowledgement_Packet} eq undef)
			{
			    print "Compool initializing _now data bit fields\n";
        		    substr($Compool_Data{$serial_port}{Now_Basic_Acknowledgement_Packet},8,1) = pack('C',(unpack('C',substr($data,8,1)) ^ 255));
        		    substr($Compool_Data{$serial_port}{Now_Basic_Acknowledgement_Packet},9,1) = pack('C',(unpack('C',substr($data,9,1)) ^ 255));
			}
		        $Compool_Data{$serial_port}{Last_Basic_Acknowledgement_Packet} = $data;


                    }
                    else
	            {	
                        print "Unchecked data   : " . unpack('H*', $data) . "\n";
                    }
	        }
            }
        }
        $serial_port->reset_error;
    }
}

package Compool;

sub init 
{
    my ($serial_port) = @_;
    $serial_port->error_msg(0);  
    #$serial_port->user_msg(1);
    #$serial_port->debug(1);

    $serial_port->parity_enable(1);		
    $serial_port->baudrate(9600);
    $serial_port->databits(8);
    $serial_port->parity("none");
    $serial_port->stopbits(1);

    $serial_port->is_handshake("none");         #&? Should this be DTR?


    $serial_port->dtr_active(1);		# sends outputs direct to hardware
    $serial_port->rts_active(0);		# returns status of API call
    select (undef, undef, undef, .100); 	# Sleep a bit
    print "Compool init\n";

    # Initial cleared data for _now commands
    $Compool_Data{$serial_port}{Now_Basic_Acknowledgement_Packet}  = "\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00";

    # Debuging setup for equipment less development
    $Compool_Data{$serial_port}{Last_Basic_Acknowledgement_Packet} = "\xff\xaa\x0f\x16\x02\x10\x04\x14\x0F\x01\x10\x82\x00\x00\x00\x88\x99\x32\x00\x00\xf0\x80\x05\x55";
    substr($Compool_Data{$serial_port}{Now_Basic_Acknowledgement_Packet},8,1) = pack('C',unpack('C',substr($Compool_Data{$serial_port}{Last_Basic_Acknowledgement_Packet},8,1)) ^ 255);
}

sub set_time 
{
    my ($serial_port) = @_;
    my ($Second, $Minute, $Hour, $Mday, $Month, $Year, $Wday, $Yday, $isdst) = localtime time;
    my $Compool_Time = pack("CC",$Minute,$Hour);
    return send_command($serial_port, $Compool_Time . "\x00\x00\x00\x00\x00\x03");
}

sub get_time 
{
    my ($serial_port) = @_;
    unless (length($Compool_Data{$serial_port}{Last_Basic_Acknowledgement_Packet}) == 24) {print "Compool get_time no status packet received\n"; return undef,undef;};
    return substr($Compool_Data{$serial_port}{Last_Basic_Acknowledgement_Packet},7,1),substr($Compool_Data{$serial_port}{Last_Basic_Acknowledgement_Packet},6,1);
}

sub get_time_now
{
    my ($serial_port) = @_;
    unless (length($Compool_Data{$serial_port}{Last_Basic_Acknowledgement_Packet}) == 24) {print "Compool get_time_now no status packet received\n"; return undef,undef;};

    if(substr($Compool_Data{$serial_port}{Last_Basic_Acknowledgement_Packet},6,2) eq substr($Compool_Data{$serial_port}{Now_Basic_Acknowledgement_Packet},6,2))
    {
        return undef;
    }
    else
    {
        # Update the Now_ data so we won't trigger again until the data changes.
        substr($Compool_Data{$serial_port}{Now_Basic_Acknowledgement_Packet},6,2) = substr($Compool_Data{$serial_port}{Last_Basic_Acknowledgement_Packet},6,2);
        return get_time($serial_port);
    }
}

sub set_temp
{
    my ($serial_port, $targetdevice, $targettemp) = @_;
    my $Compool_Target_Temp = pack("C",int((($targettemp - 32) / 1.8) * 4));

    SWITCH: for($targetdevice)
    {
    /pool/i	    && do { return send_command($serial_port, "\x00\x00\x00\x00\x00" . $Compool_Target_Temp . "\x00\x00\x20"); };
    /spa/i	    && do { return send_command($serial_port, "\x00\x00\x00\x00\x00\x00" . $Compool_Target_Temp . "\x00\x40"); };
    print "Compool set_temp unknown device\n";
    }
    return -1;
}

sub get_temp
{
    my ($serial_port, $targetdevice) = @_;

    unless (length($Compool_Data{$serial_port}{Last_Basic_Acknowledgement_Packet}) == 24) {print "Compool get_temp no status packet received\n"; return undef;};

    my $PacketOffset;

    SWITCH: for($targetdevice)
    {
    /pool/i 	    && do { $PacketOffset = 11; last SWITCH; };
    /poolsolar/i    && do { $PacketOffset = 12; last SWITCH; };
    /spa/i 	    && do { $PacketOffset = 13; last SWITCH; };
    /spasolar/i	    && do { $PacketOffset = 14; last SWITCH; };
    /pooldesired/i  && do { $PacketOffset = 15; last SWITCH; };
    /spadesired/i   && do { $PacketOffset = 16; last SWITCH; };
    /air/i 	    && do { $PacketOffset = 17; last SWITCH; };
    print "Compool get_temp unknown device", return 0;
    }
    
    if(unpack('C',substr($Compool_Data{$serial_port}{Last_Basic_Acknowledgement_Packet},$PacketOffset,1)) == 0)
    {
        return 0;
    }
    else
    {
        return int( ((unpack('C',substr($Compool_Data{$serial_port}{Last_Basic_Acknowledgement_Packet},$PacketOffset,1)) / 4) * 1.8) + 32 ); 
    }
}

sub get_temp_now
{
    my ($serial_port, $targetdevice) = @_;
    unless (length($Compool_Data{$serial_port}{Last_Basic_Acknowledgement_Packet}) == 24) {print "Compool get_temp_now no status packet received\n"; return undef;};

    my $PacketOffset;

    SWITCH: for($targetdevice)
    {
    /pool/i 	    && do { $PacketOffset = 11; last SWITCH; };
    /poolsolar/i    && do { $PacketOffset = 12; last SWITCH; };
    /spa/i 	    && do { $PacketOffset = 13; last SWITCH; };
    /spasolar/i	    && do { $PacketOffset = 14; last SWITCH; };
    /pooldesired/i  && do { $PacketOffset = 15; last SWITCH; };
    /spadesired/i   && do { $PacketOffset = 16; last SWITCH; };
    /air/i 	    && do { $PacketOffset = 17; last SWITCH; };
    print "Compool get_temp_now unknown device", return 0;
    }

    if(substr($Compool_Data{$serial_port}{Last_Basic_Acknowledgement_Packet},$PacketOffset,1) eq substr($Compool_Data{$serial_port}{Now_Basic_Acknowledgement_Packet},$PacketOffset,1))
    {
        return undef;
    }
    else
    {
        # Update the Now_ data so we won't trigger again until the data changes.
        substr($Compool_Data{$serial_port}{Now_Basic_Acknowledgement_Packet},$PacketOffset,1) = substr($Compool_Data{$serial_port}{Last_Basic_Acknowledgement_Packet},$PacketOffset,1);
        return get_temp($serial_port, $targetdevice);
    }
}

sub set_device
{
    my ($serial_port, $targetdevice, $targetstate) = @_;
   
    unless (length($Compool_Data{$serial_port}{Last_Basic_Acknowledgement_Packet}) == 24) {print "Compool set_device no status packet received\n"; return 0;};

    $targetstate eq 'on' ?  $targetstate = 1 : $targetstate = 0;

    my $targetprimary;
    my $targetbit = 0;

    SWITCH: for($targetdevice)
    {
    $targetprimary = 8;
    /spa/i 	    && do { $targetbit = 1;   last SWITCH; };
    /pool/i 	    && do { $targetbit = 2;   last SWITCH; };
    /aux1/i 	    && do { $targetbit = 4;   last SWITCH; };
    /aux2/i 	    && do { $targetbit = 8;   last SWITCH; };
    /aux3/i 	    && do { $targetbit = 16;  last SWITCH; };
    /aux4/i 	    && do { $targetbit = 32;  last SWITCH; };
    /aux5/i 	    && do { $targetbit = 64;  last SWITCH; };
    /aux6/i 	    && do { $targetbit = 128; last SWITCH; };
    $targetprimary = 9;
    /remote/i 	    && do { $targetbit = 1;   last SWITCH; };
    /display/i 	    && do { $targetbit = 2;   last SWITCH; };
    /delaycancel/i  && do { $targetbit = 4;   last SWITCH; };
    /spare1/i 	    && do { $targetbit = 8;   last SWITCH; };
    /aux7/i 	    && do { $targetbit = 16;  last SWITCH; };
    /spare2/i 	    && do { $targetbit = 32;  last SWITCH; };
    /spare3/i 	    && do { $targetbit = 64;  last SWITCH; };
    /spare4/i 	    && do { $targetbit = 128; last SWITCH; };
    print "Compool set_device unknown device", return -1;
    }

    my $currentstate;

    $currentstate = unpack('C',substr($Compool_Data{$serial_port}{Last_Basic_Acknowledgement_Packet},$targetprimary,1));

    #
    # Determine if we need to toggle the device to get it into the right state.
    #
    if($targetstate == 0 && ($currentstate & $targetbit) == 0)
    {
        return 1;
    }
    elsif($targetstate == 1 && ($currentstate & $targetbit) == $targetbit)
    {
        return 1;
    }

    # Sending to primary equipment field or secondary equipment field?
    $targetprimary == 8 ? return send_command($serial_port, "\x00\x00" . pack("C",$targetbit) . "\x00\x00\x00\x00\x00\x04") : return send_command($serial_port, "\x00\x00\x00" . pack("C",$targetbit) . "\x00\x00\x00\x00\x08");
}

sub get_device
{
    my ($serial_port, $targetdevice) = @_;
    unless (length($Compool_Data{$serial_port}{Last_Basic_Acknowledgement_Packet}) == 24) {print "Compool get_device no status packet received\n"; return undef;};

    my $targetprimary;
    my $targetbit = 0;

    SWITCH: for($targetdevice)
    {
    $targetprimary = 8;
    /spa/i 	    && do { $targetbit = 1;   last SWITCH; };
    /pool/i 	    && do { $targetbit = 2;   last SWITCH; };
    /aux1/i 	    && do { $targetbit = 4;   last SWITCH; };
    /aux2/i 	    && do { $targetbit = 8;   last SWITCH; };
    /aux3/i 	    && do { $targetbit = 16;  last SWITCH; };
    /aux4/i 	    && do { $targetbit = 32;  last SWITCH; };
    /aux5/i 	    && do { $targetbit = 64;  last SWITCH; };
    /aux6/i 	    && do { $targetbit = 128; last SWITCH; };
    $targetprimary = 9;
    /service/i 	    && do { $targetbit = 1;   last SWITCH; };
    /heater/i 	    && do { $targetbit = 2;   last SWITCH; };
    /solar/i 	    && do { $targetbit = 4;   last SWITCH; };
    /remote/i 	    && do { $targetbit = 8;   last SWITCH; };
    /display/i 	    && do { $targetbit = 16;  last SWITCH; };
    /allowsolar/i   && do { $targetbit = 32;  last SWITCH; };
    /aux7/i 	    && do { $targetbit = 64;  last SWITCH; };
    /freeze/i 	    && do { $targetbit = 128; last SWITCH; };
    print "Compool get_device unknown device", return undef;
    }

    (unpack('C',substr($Compool_Data{$serial_port}{Last_Basic_Acknowledgement_Packet},$targetprimary,1)) & $targetbit) ? return "on" : return "off";
}   

sub get_device_now
{
    my ($serial_port, $targetdevice) = @_;
    unless (length($Compool_Data{$serial_port}{Last_Basic_Acknowledgement_Packet}) == 24) {print "Compool get_device_now no status packet received\n"; return undef;};

    my $targetprimary;
    my $targetbit = 0;

    SWITCH: for($targetdevice)
    {
    $targetprimary = 8;
    /spa/i 	    && do { $targetbit = 1;   last SWITCH; };
    /pool/i 	    && do { $targetbit = 2;   last SWITCH; };
    /aux1/i 	    && do { $targetbit = 4;   last SWITCH; };
    /aux2/i 	    && do { $targetbit = 8;   last SWITCH; };
    /aux3/i 	    && do { $targetbit = 16;  last SWITCH; };
    /aux4/i 	    && do { $targetbit = 32;  last SWITCH; };
    /aux5/i 	    && do { $targetbit = 64;  last SWITCH; };
    /aux6/i 	    && do { $targetbit = 128; last SWITCH; };
    $targetprimary = 9;
    /service/i 	    && do { $targetbit = 1;   last SWITCH; };
    /heater/i 	    && do { $targetbit = 2;   last SWITCH; };
    /solar/i 	    && do { $targetbit = 4;   last SWITCH; };
    /remote/i 	    && do { $targetbit = 8;   last SWITCH; };
    /display/i 	    && do { $targetbit = 16;  last SWITCH; };
    /allowsolar/i   && do { $targetbit = 32;  last SWITCH; };
    /aux7/i 	    && do { $targetbit = 64;  last SWITCH; };
    /freeze/i 	    && do { $targetbit = 128; last SWITCH; };
    print "Compool get_device_now unknown device", return undef;
    }

    if((int(unpack('C',substr($Compool_Data{$serial_port}{Last_Basic_Acknowledgement_Packet},$targetprimary,1))) & $targetbit) == (int(unpack('C',substr($Compool_Data{$serial_port}{Now_Basic_Acknowledgement_Packet},$targetprimary,1))) & $targetbit))
    {
        return undef;
    }
    else
    {
        # Update the Now_ data so we won't trigger again until the data changes.
        substr($Compool_Data{$serial_port}{Now_Basic_Acknowledgement_Packet},$targetprimary,1) = pack('C',int(unpack('C',substr($Compool_Data{$serial_port}{Now_Basic_Acknowledgement_Packet},$targetprimary,1))) ^ $targetbit);
        return get_device($serial_port,$targetdevice);
    }
}   

sub get_version
{
    my ($serial_port, $targetdevice) = @_;
    unless (length($Compool_Data{$serial_port}{Last_Basic_Acknowledgement_Packet}) == 24) {print "Compool get_version no status packet received\n"; return undef;};
    return substr($Compool_Data{$serial_port}{Last_Basic_Acknowledgement_Packet},3,1);
}   

sub send_command
{
    my ($serial_port, $command) = @_;
    my $Compool_Command_Header = "\xFF\xAA\x00\x01\x82\x09";

    my $Checksum = unpack("%16C*", $Compool_Command_Header . $command) % 65536;
    my $Checksum = pack("CC", (($Checksum >> 8) & 0xFF), ($Checksum & 0xFF));

    print "Compool send data: " . unpack('H*', $Compool_Command_Header . $command . $Checksum) . "\n";
    
    (my $BlockingFlags, my $InBytes, my $OutBytes, my $LatchErrorFlags) = $serial_port->is_status || warn "could not get port status\n";
    my $ClearedErrorFlags = $serial_port->reset_error;
    # The API resets errors when reading status, $LatchErrorFlags
    # is all $ErrorFlags since they were last explicitly cleared

    $serial_port->dtr_active(1);
    $serial_port->rts_active(1);
    select (undef, undef, undef, .100); # Sleep a bit
    if (17 == ($temp = $serial_port->write($Compool_Command_Header . $command . $Checksum))) 
    {
        select (undef, undef, undef, .100); # Sleep a bit
        $serial_port->dtr_active(1);
        $serial_port->rts_active(0);
        print "Compool send command ok\n";
        return 1;
    }
    else 
    {
        select (undef, undef, undef, .100); # Sleep a bit
        $serial_port->dtr_active(1);
        $serial_port->rts_active(0);
        print "Compool send command failed sent " . $temp. " bytes\n";
        return -1;
    }
}
