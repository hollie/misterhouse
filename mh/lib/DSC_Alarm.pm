#!/usr/bin/perl                                                                                 
#
#
#
#    Add these entries to your mh.ini file:
#
#    DSC_Alarm_serial_port=COM2
#    DSC_Alarm_baudrate=4800 (or whatever you've configured the DSC printer interface for)
# 
#    bsobel@vipmail.com
#    June 25, 2000
#
#

use strict;

package DSC_Alarm;

#
# This code create the serial port and registers the callbacks we need
#
sub serial_startup
{
    if ($::config_parms{DSC_Alarm_serial_port}) 
    {
        my($speed) = $::config_parms{DSC_Alarm_baudrate} || 4800;
        if (&::serial_port_create('DSC', $::config_parms{DSC_Alarm_serial_port}, $speed, 'dtr')) 
        {
            init($::Serial_Ports{DSC}{object}); 
            &::MainLoop_pre_add_hook( \&DSC_Alarm::UserCodePreHook,   1);
            &::MainLoop_post_add_hook( \&DSC_Alarm::UserCodePostHook, 1 );
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
    $serial_port->databits(8);
    $serial_port->parity("none");
    $serial_port->stopbits(1);

    #$serial_port->is_handshake("none");         #&? Should this be DTR?

    $serial_port->dtr_active(1);		
    $serial_port->rts_active(0);		
    select (undef, undef, undef, .100); 	# Sleep a bit
    ::print_log "DSC_Alarm init\n";
}

sub UserCodePreHook
{
    &::check_for_generic_serial_data('DSC');
    if (my $data = $::Serial_Ports{DSC}{data_record}) 
    {
        $::Serial_Ports{DSC}{data_record};
        ::print_log $data . "\n";;
    }
}

sub UserCodePostHook
{
    #
    # Reset data for _now functions
    #
    $::Serial_Ports{DSC}{data_record} = '';
}


1;

