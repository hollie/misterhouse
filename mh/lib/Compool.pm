#!/usr/bin/perl                                                                                 
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
#    Compool_serial_port=COM2
# 
#    bsobel@vipmail.com'
#    May 16, 2000
#
#

use strict;

# This needs to be available to both Compool and Compool_Items
my @compool_item_list;

package Compool;

my (%Compool_Data,@compool_command_list,$temp,$last_command_time);

#
# This code create the serial port and registers the callbacks we need
#
sub serial_startup
{
    if ($::config_parms{Compool_serial_port}) 
    {
        my($speed) = $::config_parms{Compool_baudrate} || 9600;
        if (&::serial_port_create('Compool', $::config_parms{Compool_serial_port}, $speed, 'none', 'raw')) 
        {
            init($::Serial_Ports{Compool}{object}); 
            &::MainLoop_pre_add_hook( \&Compool::UserCodePreHook,   1 );
            &::MainLoop_post_add_hook( \&Compool::UserCodePostHook, 1 );
        }
    }
}

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

    $serial_port->dtr_active(1);		
    $serial_port->rts_active(0);		
    select (undef, undef, undef, .100); 	# Sleep a bit
    ::print_log "Compool init\n";

    # Initial cleared data for _now commands
    $Compool_Data{$serial_port}{Now_Basic_Acknowledgement_Packet}  = "\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00";
    $Compool_Data{$serial_port}{Last_Partial_Packet} = "";
    # Debuging setup for equipment less development
    #$Compool_Data{$serial_port}{Last_Basic_Acknowledgement_Packet} = "\xff\xaa\x0f\x16\x02\x10\x04\x14\x0F\x01\x10\x82\x00\x00\x00\x88\x99\x32\x00\x00\xf0\x80\x05\x55";
    #substr($Compool_Data{$serial_port}{Now_Basic_Acknowledgement_Packet},8,1) = pack('C',unpack('C',substr($Compool_Data{$serial_port}{Last_Basic_Acknowledgement_Packet},8,1)) ^ 255);
}

sub UserCodePreHook
{
    if ($::New_Msecond_100) 
    {
        if ($::Serial_Ports{Compool}{object})
        {
            my $serial_port = $::Serial_Ports{Compool}{object};
            my $data, my $packetsize=0;

            #$serial_port->reset_error;
            $serial_port->reset_error unless $data = &Compool::read_packet($serial_port);
            # Get any left over data and prepend to packet
            $data = $Compool_Data{$serial_port}{Last_Partial_Packet}  . $data;

            # Check for the minimum packet size
            if(length($data) >= 9)
            {
                #print "3:" . unpack('H*', $data) . "\n";

                if($::config_parms{debug} eq 'compool') {print "Compool debug data=" . unpack('H*', $data) . "\n";}

                my $index = index($data,"\xFF\xAA");
                if($index >=0)
                {
                    my $packet = substr($data,$index,24);
                    if(length($packet) > 8)		# 9 is the minimum length required
                    {
	                if(substr($packet,4,1) eq "\x02" && substr($packet,5,1) eq "\x10" && length($packet) >= 24)
                        {
                            print "BAP packet detected\n" if $::config_parms{debug} eq 'compool';
                            # Remove bytes from the received data to account for this packet
                            $packetsize = 24;

                            my $Checksum = unpack('%16C*', substr($packet,0,22)) % 65536;
                            my $Checksum = pack("CC", (($Checksum >> 8) & 0xFF), ($Checksum & 0xFF));

                            #
                            # Check if this is tagged as a basic acknowledge packet (Opcode == 2 && InfoFieldLengh == 10h)
                            #
                            if($Checksum eq substr($packet,22,2))
                            {
                                if($::config_parms{debug} eq 'compool') {print "Compool BAP data : " . unpack('H*', $packet) . "\n";}

                                # If first packet then we must initialize the Next_ data for the equipment to be in the opposite bit states
                                # as the data inidicates so we fire the first get_device_now triggers.

                                if ($Compool_Data{$serial_port}{Last_Basic_Acknowledgement_Packet} eq undef)
                                {
                                    if($::config_parms{debug} eq 'compool') {print "Compool initializing _now data bit fields\n";}
                                    substr($Compool_Data{$serial_port}{Now_Basic_Acknowledgement_Packet},8,1) = pack('C',(unpack('C',substr($packet,8,1)) ^ 255));
                                    substr($Compool_Data{$serial_port}{Now_Basic_Acknowledgement_Packet},9,1) = pack('C',(unpack('C',substr($packet,9,1)) ^ 255));
                                }
                                $Compool_Data{$serial_port}{Last_Basic_Acknowledgement_Packet} = $packet;

                                if(substr($Compool_Data{$serial_port}{Last_Basic_Acknowledgement_Packet},8,10) ne substr($Compool_Data{$serial_port}{Now_Basic_Acknowledgement_Packet},8,10))
                                {
                                    # WES handle object invocation.  Loop thru all current commands and
                                    # set tied objects to the corosponding state.
                                    my $object;
                                    my @tied_item_activation_list;
                                    foreach $object (@compool_item_list)
                                    {
                                        if($object->state_now)
                                        {
                                            push(@tied_item_activation_list, $object);
                                        }
                                    }
                                    &main::check_for_tied_events(@tied_item_activation_list);
                                }
                            }
                            else
                            {
                                if($::config_parms{debug} eq 'compool') {print "Compool BAP packet recieved with invalid checksum, ignoring\n";}
                            }
                        }
                        # Another controllers command packet
                        elsif(substr($packet,4,1) eq "\x82" && substr($packet,5,1) eq "\x09" && length($packet) >= 17)
                        {
	                    # Remove bytes from the received data to account for this packet
                            $packetsize = 9;
                            if($::config_parms{debug} eq 'compool') {print "Compool command packet recieved\n";}
                        }
                        # Ack packet received
                        elsif(substr($packet,4,1) eq "\x01" && substr($packet,5,1) eq "\x01" && length($packet) >= 9)
                        {
	                    # Remove bytes from the received data to account for this packet
                            $packetsize = 9;
                            if($::config_parms{debug} eq 'compool') {print "Compool ACK packet recieved\n";}
                            # Remove any command at the head of the queue (but only if it's been sent)
                            if(@compool_command_list[2] > 0)
                            {
                                remove_command();
                            }
                        }
                        # Nak packet received
                        elsif(substr($packet,4,1) eq "\x00" && substr($packet,5,1) eq "\x01" && length($packet) >= 9)
                        {
	                    # Remove bytes from the received data to account for this packet
                            $packetsize = 9;
                            # Reset the last command time to we resend immediately
                            $last_command_time = 0;

                            if($::config_parms{debug} eq 'compool') {print "Compool NAK packet recieved\n";}
                        }
                        else
	                {	
                            # Default packetsize to 2 so we move pass the found FFAA if no packet match is performed (next
                            # pass will jump to the next start of packet detected).  Only do this if we've read enough bytes
                            # to account for the largest packet we can handle.
                            if(length($packet) >= 24)
                            {
                                $packetsize = 2;
                            }
                            if($::config_parms{debug} eq 'compool') {print "Compool unchecked data   : " . unpack('H*', $packet) . "\n";}
                        }
	            }

                    # Adjust the packetsize to account for where the found packet started
                    $packetsize = $index + $packetsize;
                }

                # Store remaining data for next pass
                if($::config_parms{debug} eq 'compool') { print "Packetsize=$packetsize Length1=" . length($data) . " Length2=" . length(substr($data,$packetsize)) . "\n"; }
                $Compool_Data{$serial_port}{Last_Partial_Packet} = substr($data,$packetsize);
            }
        }

        # Require at least 2 seconds between commands to avoide blowing any circuit breakers by turning on 
        # too many items at once.
        if((@compool_command_list > 0) && (time - $last_command_time > 2))
        {
            # Increment our retry count
            @compool_command_list[2]++;

            # If we've already attempted to turn this item on 4 times, it's time to abort
            if(@compool_command_list[2] > 4)
            {
                remove_command();
            }
            else
            {
                send_command(@compool_command_list[0], @compool_command_list[1]);
                # We are about to get a new BAP packet, nuke any holdover data
                $Compool_Data{@compool_command_list[0]}{Last_Partial_Packet} = "";
            }
        }
    }
}

sub UserCodePostHook
{
    #
    # Reset data for _now functions
    #
    my $serial_port = $::Serial_Ports{Compool}{object};
    unless ($Compool_Data{$serial_port}{Last_Basic_Acknowledgement_Packet} eq undef)
    {
        $Compool_Data{$serial_port}{Now_Basic_Acknowledgement_Packet} = $Compool_Data{$serial_port}{Last_Basic_Acknowledgement_Packet};
    }
}

sub set_time 
{
    my ($serial_port) = @_;
    my ($Second, $Minute, $Hour, $Mday, $Month, $Year, $Wday, $Yday, $isdst) = localtime time;
    my $Compool_Time = pack("CC",$Minute,$Hour);
    return queue_command($serial_port, $Compool_Time . "\x00\x00\x00\x00\x00\x00\x03");
}

sub get_time 
{
    my ($serial_port) = @_;
    unless (length($Compool_Data{$serial_port}{Last_Basic_Acknowledgement_Packet}) == 24) {if($::config_parms{debug} eq 'compool'){::print_log "Compool get_time no status packet received\n";} return undef,undef;};
    return substr($Compool_Data{$serial_port}{Last_Basic_Acknowledgement_Packet},7,1),substr($Compool_Data{$serial_port}{Last_Basic_Acknowledgement_Packet},6,1);
}

sub get_time_now
{
    my ($serial_port) = @_;
    unless (length($Compool_Data{$serial_port}{Last_Basic_Acknowledgement_Packet}) == 24) {if($::config_parms{debug} eq 'compool'){::print_log "Compool get_time_now no status packet received\n";} return undef,undef;};

    if(substr($Compool_Data{$serial_port}{Last_Basic_Acknowledgement_Packet},6,2) eq substr($Compool_Data{$serial_port}{Now_Basic_Acknowledgement_Packet},6,2))
    {
        return undef;
    }
    else
    {
        return get_time($serial_port);
    }
}

sub set_temp
{
    my ($serial_port, $targetdevice, $targettemp) = @_;
    my $Compool_Target_Temp = pack("C",int(((($targettemp + .9) - 32) * 4) / 1.8));

    SWITCH: for($targetdevice)
    {
    /pooldesiredtemp/i && do { return queue_command($serial_port, "\x00\x00\x00\x00\x00" . $Compool_Target_Temp . "\x00\x00\x20"); };
    /pooldesired/i     && do { return queue_command($serial_port, "\x00\x00\x00\x00\x00" . $Compool_Target_Temp . "\x00\x00\x20"); };
    /pool/i	       && do { return queue_command($serial_port, "\x00\x00\x00\x00\x00" . $Compool_Target_Temp . "\x00\x00\x20"); };
    /spadesiredtemp/i  && do { return queue_command($serial_port, "\x00\x00\x00\x00\x00\x00" . $Compool_Target_Temp . "\x00\x40"); };
    /spadesired/i      && do { return queue_command($serial_port, "\x00\x00\x00\x00\x00\x00" . $Compool_Target_Temp . "\x00\x40"); };
    /spa/i	       && do { return queue_command($serial_port, "\x00\x00\x00\x00\x00\x00" . $Compool_Target_Temp . "\x00\x40"); };
    ::print_log "Compool set_temp unknown device\n";
    }
    return -1;
}

sub get_temp
{
    my ($serial_port, $targetdevice, $comparison, $limit) = @_;
    unless (length($Compool_Data{$serial_port}{Last_Basic_Acknowledgement_Packet}) == 24) {if($::config_parms{debug} eq 'compool'){::print_log "Compool get_temp no status packet received\n";} return undef;};

    my $PacketOffset;

    SWITCH: for($targetdevice)
    {
    /pooldesiredtemp/i  && do { $PacketOffset = 15; last SWITCH; };
    /pooldesired/i      && do { $PacketOffset = 15; last SWITCH; };
    /poolsolartemp/i    && do { $PacketOffset = 12; last SWITCH; };
    /poolsolar/i        && do { $PacketOffset = 12; last SWITCH; };
    /pooltemp/i 	&& do { $PacketOffset = 11; last SWITCH; };
    /pool/i 	        && do { $PacketOffset = 11; last SWITCH; };
    /spadesiredtemp/i   && do { $PacketOffset = 16; last SWITCH; };
    /spadesired/i       && do { $PacketOffset = 16; last SWITCH; };
    /spasolartemp/i	&& do { $PacketOffset = 14; last SWITCH; };
    /spasolar/i	        && do { $PacketOffset = 14; last SWITCH; };
    /spatemp/i 	        && do { $PacketOffset = 13; last SWITCH; };
    /spa/i 	        && do { $PacketOffset = 13; last SWITCH; };
    /airtemp/i 	        && do { $PacketOffset = 17; last SWITCH; };
    /air/i 	        && do { $PacketOffset = 17; last SWITCH; };
    ::print_log "Compool get_temp unknown device", return 0;
    }
    
    if(unpack('C',substr($Compool_Data{$serial_port}{Last_Basic_Acknowledgement_Packet},$PacketOffset,1)) == 0)
    {
        return 0;
    }
    else
    {
        # Solar and Air temperature are given in 0.5 degrees C increments (not 0.25 like the others)
        my $divisor = (($PacketOffset == 12) or ($PacketOffset == 17)) ? 2 : 4;
        
        my $temp = int( ((unpack('C',substr($Compool_Data{$serial_port}{Last_Basic_Acknowledgement_Packet},$PacketOffset,1)) / $divisor) * 1.8 ) + 32 ); 

        # If the spa temp is reading 0, then return the pool temp as they are the same
        $temp = get_temp("pool") if $temp == 0 and $PacketOffset == 13;
        
        return $temp if($comparison eq undef);
        return (($temp < $limit) ? 1 : 0) if($comparison eq '<');
        return (($temp > $limit) ? 1 : 0) if($comparison eq '>');
        return (($temp == $limit) ? 1 : 0) if($comparison eq '=');
    }
    return undef;
}

sub get_temp_now
{
    my ($serial_port, $targetdevice, $comparison, $limit) = @_;
    unless (length($Compool_Data{$serial_port}{Last_Basic_Acknowledgement_Packet}) == 24) {if($::config_parms{debug} eq 'compool'){::print_log "Compool get_temp_now no status packet received\n";} return undef;};

    my $PacketOffset;

    SWITCH: for($targetdevice)
    {
    /pooldesiredtemp/i  && do { $PacketOffset = 15; last SWITCH; };
    /pooldesired/i      && do { $PacketOffset = 15; last SWITCH; };
    /poolsolartemp/i    && do { $PacketOffset = 12; last SWITCH; };
    /poolsolar/i        && do { $PacketOffset = 12; last SWITCH; };
    /pooltemp/i 	&& do { $PacketOffset = 11; last SWITCH; };
    /pool/i 	        && do { $PacketOffset = 11; last SWITCH; };
    /spadesiredtemp/i   && do { $PacketOffset = 16; last SWITCH; };
    /spadesired/i       && do { $PacketOffset = 16; last SWITCH; };
    /spasolartemp/i	&& do { $PacketOffset = 14; last SWITCH; };
    /spasolar/i	        && do { $PacketOffset = 14; last SWITCH; };
    /spatemp/i 	        && do { $PacketOffset = 13; last SWITCH; };
    /spa/i 	        && do { $PacketOffset = 13; last SWITCH; };
    /airtemp/i 	        && do { $PacketOffset = 17; last SWITCH; };
    /air/i 	        && do { $PacketOffset = 17; last SWITCH; };
    ::print_log "Compool get_temp_now unknown device", return 0;
    }

    if(substr($Compool_Data{$serial_port}{Last_Basic_Acknowledgement_Packet},$PacketOffset,1) eq substr($Compool_Data{$serial_port}{Now_Basic_Acknowledgement_Packet},$PacketOffset,1))
    {
        return undef;
    }
    else
    {
        return get_temp($serial_port, $targetdevice, $comparison, $limit);
    }
}

sub set_device
{
    my ($serial_port, $targetdevice, $targetstate) = @_;

    # Handle 'toggle' state
    if($targetstate eq 'toggle')
    {
        $targetstate = (get_device($serial_port, $targetdevice) eq 'on') ? 'off' : 'on';
    }

    if($targetstate eq 'on' or $targetstate eq 'ON' or $targetstate eq '1') 
    {
        $targetstate=1;
    } 
    elsif($targetstate eq 'off' or $targetstate eq 'OFF' or $targetstate eq '0') 
    {
        $targetstate=0;
    }
    else
    {
        print "Invalid state passed to Compool::_set_device\n";
        return;
    }

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
    ::print_log "Compool set_device unknown device", return -1;
    }

    my $currentstate;

    $currentstate = unpack('C',substr($Compool_Data{$serial_port}{Last_Basic_Acknowledgement_Packet},$targetprimary,1));

    #
    # Determine if we need to toggle the device to get it into the right state.
    #
    if(($targetstate == 0) && (($currentstate & $targetbit) == 0))
    {
        return 0;
    }
    elsif(($targetstate == 1) && (($currentstate & $targetbit) == $targetbit))
    {
        return 0;
    }

    # Sending to primary equipment field or secondary equipment field?
    ($targetprimary == 8) ? return queue_command($serial_port, "\x00\x00" . pack("C",$targetbit) . "\x00\x00\x00\x00\x00\x04") : return queue_command($serial_port, "\x00\x00\x00" . pack("C",$targetbit) . "\x00\x00\x00\x00\x08");
}

sub set_device_with_timer 
{
    my ($serial_port, $targetdevice, $targetstate, $time) = @_;

    my $returncode = set_device($serial_port,$targetdevice,$targetstate);
    return $returncode unless $time;

                                # If off, timeout to on, otherwise timeout to off
    my $state_change = ($targetstate eq 'off' or $targetstate eq 'OFF') ? 'on' : 'off';

    my $compool_timer = &Timer::new();
    my $action = "&Compool::set_device(\$::Serial_Ports{Compool}{object},'$targetdevice','$state_change')";
#    my $action = "&Compool::set_device($serial_port,'$targetdevice','$state_change')";
    ::print_log "$action\n" if($::config_parms{debug} eq 'compool');

    &Timer::set($compool_timer, $time, $action);

    return $returncode;
}

sub get_device
{
    my ($serial_port, $targetdevice) = @_;
    unless (length($Compool_Data{$serial_port}{Last_Basic_Acknowledgement_Packet}) == 24) {if($::config_parms{debug} eq 'compool'){::print_log "Compool get_device no status packet received\n";} return undef;};

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
    ::print_log "Compool get_device unknown device", return undef;
    }

    (unpack('C',substr($Compool_Data{$serial_port}{Last_Basic_Acknowledgement_Packet},$targetprimary,1)) & $targetbit) ? return "on" : return "off";
}   

sub get_device_now
{
    my ($serial_port, $targetdevice) = @_;
    unless (length($Compool_Data{$serial_port}{Last_Basic_Acknowledgement_Packet}) == 24) {if($::config_parms{debug} eq 'compool'){::print_log "Compool get_device_now no status packet received\n";} return undef;};

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
    ::print_log "Compool get_device_now unknown device", return undef;
    }

    if((int(unpack('C',substr($Compool_Data{$serial_port}{Last_Basic_Acknowledgement_Packet},$targetprimary,1))) & $targetbit) == (int(unpack('C',substr($Compool_Data{$serial_port}{Now_Basic_Acknowledgement_Packet},$targetprimary,1))) & $targetbit))
    {
        return undef;
    }
    else
    {
        return get_device($serial_port,$targetdevice);
    }
}   

sub get_version
{
    my ($serial_port, $targetdevice) = @_;
    unless (length($Compool_Data{$serial_port}{Last_Basic_Acknowledgement_Packet}) == 24) {if($::config_parms{debug} eq 'compool'){::print_log "Compool get_version no status packet received\n";} return undef;};
    return substr($Compool_Data{$serial_port}{Last_Basic_Acknowledgement_Packet},3,1);
}   

sub get_delay
{
    my ($serial_port, $targetdevice) = @_;
    unless (length($Compool_Data{$serial_port}{Last_Basic_Acknowledgement_Packet}) == 24) {if($::config_parms{debug} eq 'compool'){::print_log "Compool get_delay no status packet received\n";} return undef;};

    my $targetbit = 0;

    SWITCH: for($targetdevice)
    {
    /spadelay/i     && do { $targetbit = 1;   last SWITCH; };
    /spa/i 	    && do { $targetbit = 1;   last SWITCH; };
    /pooldelay/i    && do { $targetbit = 2;   last SWITCH; };
    /pool/i 	    && do { $targetbit = 2;   last SWITCH; };
    /cleanerdelay/i && do { $targetbit = 4;   last SWITCH; };
    /cleaner/i 	    && do { $targetbit = 4;   last SWITCH; };
    ::print_log "Compool get_delay unknown device", return undef;
    }

    (unpack('C',substr($Compool_Data{$serial_port}{Last_Basic_Acknowledgement_Packet},10,1)) & $targetbit) ? return "on" : return "off";
}

sub get_delay_now
{
    my ($serial_port, $targetdevice) = @_;
    unless (length($Compool_Data{$serial_port}{Last_Basic_Acknowledgement_Packet}) == 24) {if($::config_parms{debug} eq 'compool'){::print_log "Compool get_delay_now no status packet received\n";} return undef;};

    my $targetbit = 0;

    SWITCH: for($targetdevice)
    {
    /spadelay/i     && do { $targetbit = 1;   last SWITCH; };
    /spa/i 	    && do { $targetbit = 1;   last SWITCH; };
    /pooldelay/i    && do { $targetbit = 2;   last SWITCH; };
    /pool/i 	    && do { $targetbit = 2;   last SWITCH; };
    /cleanerdelay/i && do { $targetbit = 4;   last SWITCH; };
    /cleaner/i 	    && do { $targetbit = 4;   last SWITCH; };
    ::print_log "Compool get_delay_now unknown device", return undef;
    }

    if((int(unpack('C',substr($Compool_Data{$serial_port}{Last_Basic_Acknowledgement_Packet},10,1))) & $targetbit) == (int(unpack('C',substr($Compool_Data{$serial_port}{Now_Basic_Acknowledgement_Packet},10,1))) & $targetbit))
    {
        return undef;
    }
    else
    {
        return get_delay($serial_port,$targetdevice);
    }
}   

sub get_solar_present
{
    my ($serial_port, $targetdevice) = @_;
    unless (length($Compool_Data{$serial_port}{Last_Basic_Acknowledgement_Packet}) == 24) {if($::config_parms{debug} eq 'compool'){::print_log "Compool get_solar_present no status packet received\n";} return undef;};

    (unpack('C',substr($Compool_Data{$serial_port}{Last_Basic_Acknowledgement_Packet},10,1)) & 8) ? return "yes" : return "no";
}

sub set_heatsource
{
    return undef;
}

sub get_heatsource
{
    my ($serial_port, $targetdevice) = @_;
    unless (length($Compool_Data{$serial_port}{Last_Basic_Acknowledgement_Packet}) == 24) {if($::config_parms{debug} eq 'compool'){::print_log "Compool get_heatsource no status packet received\n";} return undef;};

    my $targetbyte = unpack('C',substr($Compool_Data{$serial_port}{Last_Basic_Acknowledgement_Packet},10,1));
    my $targetshift = 0;
    SWITCH: for($targetdevice)
    {
        /spaheatsource/i  && do { $targetbyte &= 0xC0; $targetshift = 6;  last SWITCH; };
        /spa/i 	          && do { $targetbyte &= 0xC0; $targetshift = 6;  last SWITCH; };
        /poolheatsource/i && do { $targetbyte &= 0x30; $targetshift = 4;  last SWITCH; };
        /pool/i           && do { $targetbyte &= 0x30; $targetshift = 4;  last SWITCH; };
        ::print_log "Compool get_heatsource unknown device\n", return undef;
    }

    SWITCH: for( $targetbyte >> $targetshift)
    {
        /0x03/      && do { return "solarpri?"; };
        /0x02/      && do { return "heater?"; };
        /0x01/      && do { return "solar?"; };
        /0x00/      && do { return "off?"; };
    }
    ::print_log "Compool get_heatsource unknown state\n", return undef;
}

sub get_heatsource_now
{
    my ($serial_port, $targetdevice) = @_;
    unless (length($Compool_Data{$serial_port}{Last_Basic_Acknowledgement_Packet}) == 24) {if($::config_parms{debug} eq 'compool'){::print_log "Compool get_heatsource_now no status packet received\n";} return undef;};

    my $targetbit = 0;

    SWITCH: for($targetdevice)
    {
        /spaheatsource/i  && do { $targetbit = 0xC0;   last SWITCH; };
        /spa/i 	          && do { $targetbit = 0xC0;   last SWITCH; };
        /poolheatsource/i && do { $targetbit = 0x30;   last SWITCH; };
        /pool/i 	  && do { $targetbit = 0x30;   last SWITCH; };
        ::print_log "Compool get_heatsource_now unknown device", return undef;
    }

    if((int(unpack('C',substr($Compool_Data{$serial_port}{Last_Basic_Acknowledgement_Packet},10,1))) & $targetbit) == (int(unpack('C',substr($Compool_Data{$serial_port}{Now_Basic_Acknowledgement_Packet},10,1))) & $targetbit))
    {
        return undef;
    }
    else
    {
        return get_heatsource($serial_port,$targetdevice);
    }
}   


sub queue_command
{
    my ($serial_port, $command) = @_;
    push(@compool_command_list, $serial_port);
    push(@compool_command_list, $command);
    # Add a retry count to the list
    push(@compool_command_list, 0);
    return 1;
}


sub remove_command
{
    if(@compool_command_list > 0)
    {
        # Pop the serial port, command, and retry count off the list
        shift @compool_command_list;
        shift @compool_command_list;
        shift @compool_command_list;
    }
}


sub send_command
{
    my ($serial_port, $command) = @_;

    return if $serial_port == undef;

    my $Compool_Command_Header = "\xFF\xAA\x00\x01\x82\x09";

    my $Checksum = unpack("%16C*", $Compool_Command_Header . $command) % 65536;
    my $Checksum = pack("CC", (($Checksum >> 8) & 0xFF), ($Checksum & 0xFF));

    if($::config_parms{debug} eq 'compool'){print "Compool send data: " . unpack('H*', $Compool_Command_Header . $command . $Checksum) . "\n";}
    
    (my $BlockingFlags, my $InBytes, my $OutBytes, my $LatchErrorFlags) = $serial_port->is_status || warn "could not get port status\n";
    my $ClearedErrorFlags = $serial_port->reset_error;
    # The API resets errors when reading status, $LatchErrorFlags
    # is all $ErrorFlags since they were last explicitly cleared

    $serial_port->dtr_active(1);
    $serial_port->rts_active(1);
    select (undef, undef, undef, .100); # Sleep a bit
    if (17 == ($temp = $serial_port->write($Compool_Command_Header . $command . $Checksum))) 
    {
        select (undef, undef, undef, .02); # Sleep a bit
        $serial_port->dtr_active(1);
        $serial_port->rts_active(0);
        if($::config_parms{debug} eq 'compool'){print "Compool send command ok\n";}

        # Store the last time that we actually sent data to the wire so we don't do it more than every X seconds.
        $last_command_time = time;

        return 1;
    }
    else 
    {
        select (undef, undef, undef, .02); # Sleep a bit
        $serial_port->dtr_active(1);
        $serial_port->rts_active(0);
        print "Compool send command failed sent " . $temp. " bytes\n";
        return -1;
    }
}

sub read_packet 
{
    my ($serial_port) = @_;
    my $result = "";

    my $ok     = 0;
    my $got_p = " "x4;
    my ($bbb, $wanted, $ooo, $eee) = $serial_port->status;
    return "" if ($eee);
    return "" unless $wanted;

    my $got = $serial_port->read_bg ($wanted);

    if ($got != $wanted) 
    {
       	# Abort
        $serial_port->purge_rx;
        $serial_port->read_done(0);	
    }
    else 
    { 
        ($ok, $got, $result) = $serial_port->read_done(0); 
    }
    return $got ? $result : "";
}

1;

#
# Item object version (this lets us use object links and events)
#
package Compool_Item;

@Compool_Item::ISA = ('Generic_Item');

sub new 
{
    my ($class, $device, $comparison, $limit, $serial_port) = @_;
    $serial_port = $::Serial_Ports{Compool}{object} if ($serial_port == undef);

    if(($comparison ne undef) and ($comparison ne '<' and $comparison ne '>' and $comparison ne '='))
    {
        print "Invalid comparison operator (<>= valid) in Compool_Item\n";
        return;
    }

    my $self = {device => $device, comparison => $comparison, limit => $limit, serial_port => $serial_port};
    bless $self, $class;

    push(@compool_item_list,$self);

    SWITCH: for( $self->{device})
    {
        /pooltemp/i        && do { push(@{$$self{states}}, '64','66','68','70','72','74','76','78','80','82','84','86','88','90','92','94','96','98','100','102','104'); last SWITCH; };
        /spatemp/i         && do { push(@{$$self{states}}, '64','66','68','70','72','74','76','78','80','82','84','86','88','90','92','94','96','98','100','102','104'); last SWITCH; };

#       /spaheatsource/i   && do { ; };
#       /poolheatsource/i  && do { ; };

        /spa/i             && do { push(@{$$self{states}}, 'on','off'); last SWITCH; };
        /pool/i            && do { push(@{$$self{states}}, 'on','off'); last SWITCH; };
        /aux1/i            && do { push(@{$$self{states}}, 'on','off'); last SWITCH; };
        /aux2/i            && do { push(@{$$self{states}}, 'on','off'); last SWITCH; };
        /aux3/i            && do { push(@{$$self{states}}, 'on','off'); last SWITCH; };
        /aux4/i            && do { push(@{$$self{states}}, 'on','off'); last SWITCH; };
        /aux5/i            && do { push(@{$$self{states}}, 'on','off'); last SWITCH; };
        /aux6/i            && do { push(@{$$self{states}}, 'on','off'); last SWITCH; };
        /heater/i 	   && do { push(@{$$self{states}}, 'on','off'); last SWITCH; };
        /solar/i 	   && do { push(@{$$self{states}}, 'on','off'); last SWITCH; };
        /remote/i          && do { push(@{$$self{states}}, 'on','off'); last SWITCH; };
        /display/i         && do { push(@{$$self{states}}, 'on','off'); last SWITCH; };
        /delaycancel/i     && do { push(@{$$self{states}}, 'on','off'); last SWITCH; };
        /spare1/i          && do { push(@{$$self{states}}, 'on','off'); last SWITCH; };
        /aux7/i            && do { push(@{$$self{states}}, 'on','off'); last SWITCH; };
        /spare2/i          && do { push(@{$$self{states}}, 'on','off'); last SWITCH; };
        /spare3/i          && do { push(@{$$self{states}}, 'on','off'); last SWITCH; };
        /spare4/i          && do { push(@{$$self{states}}, 'on','off'); last SWITCH; };
    }
  
    return $self;
}

sub state
{
    my ($self) = @_;

    SWITCH: for( $self->{device})
    {
        /pooltemp/i        && do { return &Compool::get_temp($self->{serial_port}, $self->{device}, $self->{comparison}, $self->{limit}); };
        /poolsolartemp/i   && do { return &Compool::get_temp($self->{serial_port}, $self->{device}, $self->{comparison}, $self->{limit}); };
        /spatemp/i         && do { return &Compool::get_temp($self->{serial_port}, $self->{device}, $self->{comparison}, $self->{limit}); };
        /spasolartemp/i    && do { return &Compool::get_temp($self->{serial_port}, $self->{device}, $self->{comparison}, $self->{limit}); };
        /pooldesiredtemp/i && do { return &Compool::get_temp($self->{serial_port}, $self->{device}, $self->{comparison}, $self->{limit}); };
        /spadesiredtemp/i  && do { return &Compool::get_temp($self->{serial_port}, $self->{device}, $self->{comparison}, $self->{limit}); };
        /airtemp/i         && do { return &Compool::get_temp($self->{serial_port}, $self->{device}, $self->{comparison}, $self->{limit}); };

        /spadelay/i        && do { return &Compool::get_delay($self->{serial_port}, $self->{device}); };
        /pooldelay/i       && do { return &Compool::get_delay($self->{serial_port}, $self->{device}); };
        /cleanerdelay/i    && do { return &Compool::get_delay($self->{serial_port}, $self->{device}); };

        /spaheatsource/i   && do { return &Compool::get_heatsource($self->{serial_port}, $self->{device}); };
        /poolheatsource/i  && do { return &Compool::get_heatsource($self->{serial_port}, $self->{device}); };

        /spa/i             && do { return &Compool::get_device($self->{serial_port}, $self->{device}); };
        /pool/i            && do { return &Compool::get_device($self->{serial_port}, $self->{device}); };
        /aux1/i            && do { return &Compool::get_device($self->{serial_port}, $self->{device}); };
        /aux2/i            && do { return &Compool::get_device($self->{serial_port}, $self->{device}); };
        /aux3/i            && do { return &Compool::get_device($self->{serial_port}, $self->{device}); };
        /aux4/i            && do { return &Compool::get_device($self->{serial_port}, $self->{device}); };
        /aux5/i            && do { return &Compool::get_device($self->{serial_port}, $self->{device}); };
        /aux6/i            && do { return &Compool::get_device($self->{serial_port}, $self->{device}); };
        /heater/i 	   && do { return &Compool::get_device($self->{serial_port}, $self->{device}); };
        /solar/i 	   && do { return &Compool::get_device($self->{serial_port}, $self->{device}); };
        /remote/i          && do { return &Compool::get_device($self->{serial_port}, $self->{device}); };
        /display/i         && do { return &Compool::get_device($self->{serial_port}, $self->{device}); };
        /delaycancel/i     && do { return &Compool::get_device($self->{serial_port}, $self->{device}); };
        /spare1/i          && do { return &Compool::get_device($self->{serial_port}, $self->{device}); };
        /aux7/i            && do { return &Compool::get_device($self->{serial_port}, $self->{device}); };
        /spare2/i          && do { return &Compool::get_device($self->{serial_port}, $self->{device}); };
        /spare3/i          && do { return &Compool::get_device($self->{serial_port}, $self->{device}); };
        /spare4/i          && do { return &Compool::get_device($self->{serial_port}, $self->{device}); };
        /service/i         && do { return &Compool::get_device($self->{serial_port}, $self->{device}); };

    }
    print "Compool Item: state unknown device $self->{device}\n";
    return undef;
}

sub state_now
{
    my ($self) = @_;

    SWITCH: for( $self->{device})
    {
        /pooltemp/i        && do { return &Compool::get_temp_now($self->{serial_port}, $self->{device}, $self->{comparison}, $self->{limit}); };
        /poolsolartemp/i   && do { return &Compool::get_temp_now($self->{serial_port}, $self->{device}, $self->{comparison}, $self->{limit}); };
        /pooldesiredtemp/i && do { return &Compool::get_temp_now($self->{serial_port}, $self->{device}, $self->{comparison}, $self->{limit}); };
        /spatemp/i         && do { return &Compool::get_temp_now($self->{serial_port}, $self->{device}, $self->{comparison}, $self->{limit}); };
        /spasolartemp/i    && do { return &Compool::get_temp_now($self->{serial_port}, $self->{device}, $self->{comparison}, $self->{limit}); };
        /spadesiredtemp/i  && do { return &Compool::get_temp_now($self->{serial_port}, $self->{device}, $self->{comparison}, $self->{limit}); };
        /airtemp/i         && do { return &Compool::get_temp_now($self->{serial_port}, $self->{device}, $self->{comparison}, $self->{limit}); };

        /spadelay/i        && do { return &Compool::get_delay_now($self->{serial_port}, $self->{device}); };
        /pooldelay/i       && do { return &Compool::get_delay_now($self->{serial_port}, $self->{device}); };
        /cleanerdelay/i    && do { return &Compool::get_delay_now($self->{serial_port}, $self->{device}); };

        /spaheatsource/i   && do { return &Compool::get_heatsource_now($self->{serial_port}, $self->{device}); };
        /poolheatsource/i  && do { return &Compool::get_heatsource_now($self->{serial_port}, $self->{device}); };

        /spa/i             && do { return &Compool::get_device_now($self->{serial_port}, $self->{device}); };
        /pool/i            && do { return &Compool::get_device_now($self->{serial_port}, $self->{device}); };
        /aux1/i            && do { return &Compool::get_device_now($self->{serial_port}, $self->{device}); };
        /aux2/i            && do { return &Compool::get_device_now($self->{serial_port}, $self->{device}); };
        /aux3/i            && do { return &Compool::get_device_now($self->{serial_port}, $self->{device}); };
        /aux4/i            && do { return &Compool::get_device_now($self->{serial_port}, $self->{device}); };
        /aux5/i            && do { return &Compool::get_device_now($self->{serial_port}, $self->{device}); };
        /aux6/i            && do { return &Compool::get_device_now($self->{serial_port}, $self->{device}); };
        /heater/i 	   && do { return &Compool::get_device_now($self->{serial_port}, $self->{device}); };
        /solar/i 	   && do { return &Compool::get_device_now($self->{serial_port}, $self->{device}); };
        /remote/i          && do { return &Compool::get_device_now($self->{serial_port}, $self->{device}); };
        /display/i         && do { return &Compool::get_device_now($self->{serial_port}, $self->{device}); };
        /delaycancel/i     && do { return &Compool::get_device_now($self->{serial_port}, $self->{device}); };
        /spare1/i          && do { return &Compool::get_device_now($self->{serial_port}, $self->{device}); };
        /aux7/i            && do { return &Compool::get_device_now($self->{serial_port}, $self->{device}); };
        /spare2/i          && do { return &Compool::get_device_now($self->{serial_port}, $self->{device}); };
        /spare3/i          && do { return &Compool::get_device_now($self->{serial_port}, $self->{device}); };
        /spare4/i          && do { return &Compool::get_device_now($self->{serial_port}, $self->{device}); };
        /service/i         && do { return &Compool::get_device_now($self->{serial_port}, $self->{device}); };
    }
    print "Compool Item: state_now device item $self->{device}\n";
    return undef;
}

sub set
{
    my ($self, $state) = @_;
    return if &main::check_for_tied_filters($self, $state);

    unshift(@{$$self{state_log}}, "$main::Time_Date $state");
    pop @{$$self{state_log}} if @{$$self{state_log}} > $main::config_parms{max_state_log_entries};

    SWITCH: for( $self->{device})
    {
        /pooltemp/i        && do { return &Compool::set_temp($self->{serial_port}, $self->{device}, $state); };
        /poolsolartemp/i   && do { return &Compool::set_temp($self->{serial_port}, $self->{device}, $state); };
        /spatemp/i         && do { return &Compool::set_temp($self->{serial_port}, $self->{device}, $state); };
        /spasolartemp/i    && do { return &Compool::set_temp($self->{serial_port}, $self->{device}, $state); };
        /pooldesiredtemp/i && do { return &Compool::set_temp($self->{serial_port}, $self->{device}, $state); };
        /spadesiredtemp/i  && do { return &Compool::set_temp($self->{serial_port}, $self->{device}, $state); };
        /airtemp/i         && do { return &Compool::set_temp($self->{serial_port}, $self->{device}, $state); };

        /spaheatsource/i   && do { return &Compool::set_heatsource($self->{serial_port}, $self->{device}, $state); };
        /poolheatsource/i  && do { return &Compool::set_heatsource($self->{serial_port}, $self->{device}, $state); };

        /spa/i             && do { return &Compool::set_device($self->{serial_port}, $self->{device}, $state); };
        /pool/i            && do { return &Compool::set_device($self->{serial_port}, $self->{device}, $state); };
        /aux1/i            && do { return &Compool::set_device($self->{serial_port}, $self->{device}, $state); };
        /aux2/i            && do { return &Compool::set_device($self->{serial_port}, $self->{device}, $state); };
        /aux3/i            && do { return &Compool::set_device($self->{serial_port}, $self->{device}, $state); };
        /aux4/i            && do { return &Compool::set_device($self->{serial_port}, $self->{device}, $state); };
        /aux5/i            && do { return &Compool::set_device($self->{serial_port}, $self->{device}, $state); };
        /aux6/i            && do { return &Compool::set_device($self->{serial_port}, $self->{device}, $state); };
        /remote/i          && do { return &Compool::set_device($self->{serial_port}, $self->{device}, $state); };
        /display/i         && do { return &Compool::set_device($self->{serial_port}, $self->{device}, $state); };
        /delaycancel/i     && do { return &Compool::set_device($self->{serial_port}, $self->{device}, $state); };
        /spare1/i          && do { return &Compool::set_device($self->{serial_port}, $self->{device}, $state); };
        /aux7/i            && do { return &Compool::set_device($self->{serial_port}, $self->{device}, $state); };
        /spare2/i          && do { return &Compool::set_device($self->{serial_port}, $self->{device}, $state); };
        /spare3/i          && do { return &Compool::set_device($self->{serial_port}, $self->{device}, $state); };
        /spare4/i          && do { return &Compool::set_device($self->{serial_port}, $self->{device}, $state); };
    }
    print "Compool Item: state unknown or invalid device $self->{device}\n";
    return undef;
}

sub set_with_timer
{
    my ($self, $targetstate, $time) = @_;
    return if &main::check_for_tied_filters($self, $targetstate);
    return &Compool::set_device_with_timer($self->{serial_port}, $self->{device}, $targetstate, $time);
}

1;

