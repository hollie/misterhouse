#!/usr/bin/perl                                                                                 
#
#    Add these entries to your mh.ini file:
#
#    Stargate485_serial_port=COM2
# 
#    bsobel@vipmail.com'
#    July 11, 2000
#
#

use strict;

# This needs to be available to both Stargate485 and StargateLCDKeypad
my @lcdkeypad_object_list;
my (@stargate485_command_list, $transmitok, $temp);

package Stargate485;

my ($temp);

#
# This code create the serial port and registers the callbacks we need
#
sub serial_startup
{
    if ($::config_parms{Stargate485_serial_port}) 
    {
        my($speed) = $::config_parms{Stargate485_baudrate} || 9600;
        if (&::serial_port_create('Stargate485', $::config_parms{Stargate485_serial_port}, $speed, 'none')) 
        {
            init($::Serial_Ports{Stargate485}{object}); 
            &::MainLoop_pre_add_hook( \&Stargate485::UserCodePreHook,   1 );
            &::MainLoop_post_add_hook( \&Stargate485::UserCodePostHook, 1 );
        }
    }
}

sub init 
{
    my ($serial_port) = @_;
    $::Serial_Ports{'Stargate485'}{process_data} = 1;

    $serial_port->error_msg(0);  
    $serial_port->user_msg(1);
#    $serial_port->debug(1);

#    $serial_port->parity_enable(1);		
    $serial_port->baudrate(9600);
    $serial_port->databits(8);
    $serial_port->parity("none");
    $serial_port->parity_enable(0);
    $serial_port->stopbits(1);

    $serial_port->handshake("none");         #&? Should this be DTR?

    #    $serial_port->dtr_active(1);		
    $serial_port->dtr_active(1);		
    $serial_port->rts_active(1);		
    select (undef, undef, undef, .100); 	# Sleep a bit
    ::print_log "Stargate485 init\n";

    $transmitok = 1;
}

sub UserCodePreHook
{
    # Special case startup but notifying already created objects about it and then return.
    if($::Startup)
    {
        SetKeypadStates('all','startup');
        return;
    }

    my $data;
    unless ($data = $::Serial_Ports{'Stargate485'}{object}->input) 
    {
        # If we do not do this, we may get endless error messages.
        $::Serial_Ports{'Stargate485'}{object}->reset_error;
    }

    $::Serial_Ports{'Stargate485'}{data} .= $data if $data;

    print "  serial name=Stargate485 type=$::Serial_Ports{'Stargate485'}{datatype} data2=$::Serial_Ports{'Stargate485'}{data}...\n" 
    if $data and ($::config_parms{debug} eq 'serial' or $::config_parms{debug} eq 'Stargate485');

    # Check to see if we have a carrage return yet
    if ($::Serial_Ports{'Stargate485'}{data})
    {
        while (my($record, $remainder) = $::Serial_Ports{'Stargate485'}{data} =~ /(.+?)[\r\n]+(.*)/s) 
        {
            &::print_log("Data from Stargate485: $record.  remainder=$remainder.") if $::config_parms{debug} eq 'serial';
            $::Serial_Ports{'Stargate485'}{data_record} = $record;
            $::Serial_Ports{'Stargate485'}{data} = $remainder;
            if( $::config_parms{debug} eq 'Stargate')
            {
                print "Data: " . $record . "\n"  unless substr($record,1,2) eq 'TP' and (substr($record,5,1) eq 'Q' or substr($record,6,1) eq 'A');
            }

            # Look something like '$TP01D2cff         11' ?
            if(substr($record,0,3) eq '$TP')
            {
                my $NewState;
                my $TargetLCD;

                # Extracr the keypad address
                $TargetLCD = substr($record,3,2);
                #print "Target: $TargetLCD\n";

                # Change it to 'D2cff         11'
                $record = substr($record,5);
                #print "Record: $record\n";

                # Is this a MACRO?
                if(substr($record,0,3) eq 'D2c')
                {
                    # Set the generic 'macro triggered' state
                    #SetKeypadStates($TargetLCD,'MACRO');

                    # Set the specific 'macro triggered' state
                    my $MacroId = substr($record,3,2);
                    #print "MacroID = $MacroId\n";
                    # Hex to decimal
                    $MacroId = hex($MacroId) + 1;
                    #print "MacroID decoded as: " . $MacroId . "\n";
                    SetKeypadStates($TargetLCD,sprintf('macro%3.3d',$MacroId));
                }
            }
        }
    }
    
    if(@stargate485_command_list > 0 && $transmitok && !$::Serial_Ports{'Stargate485'}{data})
    {
        $::Serial_Ports{Stargate485}{object}->rts_active(1);		
        select (undef, undef, undef, .10); 	# Sleep a bit

        $::Serial_Ports{Stargate485}{object}->write("\r");

        if(@stargate485_command_list > 0)
        {
            (my $output) = shift @stargate485_command_list;
            print "Stargate LCD Output: " .$output . "\n";
            $::Serial_Ports{Stargate485}{object}->write($output . "\r");
        }
        select (undef, undef, undef, .30); 	# Sleep a bit

        $::Serial_Ports{Stargate485}{object}->rts_active(0);		
        select (undef, undef, undef, .10); 	# Sleep a bit
    }
}

sub UserCodePostHook
{
    #
    # Reset data for _now functions
    #
    $::Serial_Ports{Stargate485}{data_record} = '';
}

sub SetKeypadStates
{
    my ($address, $state) = @_;

    #print "SetKeypadStats: $address $state\n";

    my $object;
    foreach $object (@lcdkeypad_object_list)
    {
        if(($address eq 'all') or ($object->{address} == 0) or ($object->{address} == $address))
        {
            $object->set($state);
        }
    }
}


1;
    
#
# Item object version (this lets us use object links and events)
#

# $TP from keypad.  01 address 
#$TP01D2cff         11

package StargateLCDKeypad;
@StargateLCDKeypad::ISA = ('Generic_Item');

sub new 
{
    my ($class, $address) = @_;

    my $self = {address => $address};
    bless $self, $class;

    push(@lcdkeypad_object_list,$self);

    return $self;
}

sub ClearScreen
{
    my ($self) = @_;
    my $output = "!TP" . sprintf("%2.2xC", $self->{address});
    push(@stargate485_command_list, $output);
}

sub GoToMenu
{
    my ($self, $menu) = @_;
    my $output = "!TP" . sprintf("%2.2xG%2.2x", $self->{address}, $menu-1);
    push(@stargate485_command_list, $output);
}

sub WriteText
{
    my ($self,$row,$text) = @_;
    my $output = "!TP" . sprintf("%2.2xT%2.2x0a%-10.10s00", $self->{address}, $row-1, $text);
    push(@stargate485_command_list, $output);
}

sub ChangeText
{
    my ($self,$menu,$row,$text) = @_;

    my $output = "!TP" . sprintf("%2.2xm%2.2x%2.2x80%-10.10s00", $self->{address}, $menu-1, $row-1, $text);
    push(@stargate485_command_list, $output);
}

sub InvertText
{
    my ($self,$menu,$row) = @_;

#    my $output = "!TP" . sprintf("%2.2dm%2.2d%2.2d80%-10.10s00", $self->{address}, $menu-1, $row-1, $text);
#    push(@stargate485_command_list, $output);
}

sub UnInvertText
{
    my ($self,$menu,$row) = @_;

    #    my $output = "!TP" . sprintf("%2.2dm%2.2d%2.2d80%-10.10s00", $self->{address}, $menu-1, $row-1, $text);
    #    push(@stargate485_command_list, $output);
}
1;

