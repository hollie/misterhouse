##################################################################
#  Interface to DSC alarm system via DSC PC5400 Printer Module   #
#                                                                #
#  The PC5400 works with: PC5010, PC1555, PC580, PC5015, and     #
#  PC1575 main panels.                                           #
#                                                                #
#  Add these entries to your mh.ini file:                        #
#                                                                #
#    DSC_Alarm_serial_port=COM2                                  #
#    DSC_Alarm_baudrate=4800                                     #
#                                                                #
#  Multiple instances may be supported by adding instance        #
#  numbers to the parms as in:                                   #
#                                                                #
#    DSC_Alarm:1_serial_port=COMx                                #
#    DSC_Alarm:1_baudrate=4800                                   #
#                                                                #
#   DSC programming location 801 subsection 01 set to:           #
#    1-3---78                                                    #
#    1        = Printer Enabled                                  #
#     2       = Handshake from printer (DTR)                     #
#      3      = 80 Column Printer (off = 40 Column)              #
#       4     = 300  Baud Enabled                                #
#        5    = 1200 Baud Enabled                                #
#         6   = 2400 Baud Enabled                                #
#          7  = 4800 Baud Enabled                                #
#           8 = Local clock displays 24hr time                   #
#   DSC programming location 801 subsection 02 set to:           #
#    01 = English                                                #
#                                                                #
#  See mh/code/public/Danal/DSC_Alarm.pl for more info/examples  #
#                                                                #
#  By: Danal Estes, N5SVV                                        #
#  E-Mail: danal@earthling.net                                   #
#                                                                #
#  Based on original code by Bill Sobel:                         #
#    bsobel@vipmail.com                                          #
#                                                                #
##################################################################

# Note: This original version (October 2000) exposes 
# only "new" & "said", where "said" contains the raw data
# from the printer module.
#
# It is my intent to expose object methods (such as 
# "state") in a future release.  This may lead to 
# incompatible changes in existing methods.
# Danal Estes, October 9, 2000

use strict;

package DSC_Alarm;

@DSC_Alarm::ISA = ('Serial_Item');

my @DSC_Alarm_Ports;

#
#  Create serial port(s) according to mh.ini
#  Register hooks if any ports created.
#
sub serial_startup
{
    my ($instance) = @_;
    push(@DSC_Alarm_Ports, $instance);

    my $port     = $::config_parms{$instance . "_serial_port"};
    my $speed    = $::config_parms{$instance . "_baudrate"};
    if (&::serial_port_create($instance, $port, $speed, 'dtr')) {
      init($::Serial_Ports{$instance}{object}); 
      ::print_log "\nDSC_Alarm.pm initialzed $instance on hardware $port at $speed baud\n" if $::config_parms{debug} eq 'DSC';
    }

    if (1==scalar @DSC_Alarm_Ports) {  # Add hooks on first call only
      &::MainLoop_pre_add_hook( \&DSC_Alarm::UserCodePreHook,   1);
      &::MainLoop_post_add_hook( \&DSC_Alarm::UserCodePostHook, 1 );
      $::Year_Month_Now = &::time_date_stamp(10,time);  # Not yet set when we init.
      &::logit("$::config_parms{data_dir}/logs/$instance.$::Year_Month_Now.log", "DSC_Alarm.pm Initialized");
      ::print_log "DSC_Alarm.pm adding hooks \n" if $::config_parms{debug} eq 'DSC';
    }
}

sub init 
{
    my ($serial_port) = @_;
    $serial_port->error_msg(0);  

    $serial_port->parity_enable(1);		
    $serial_port->databits(8);
    $serial_port->parity("none");
    $serial_port->stopbits(1);

    $serial_port->dtr_active(1);		
    $serial_port->rts_active(0);		
    select (undef, undef, undef, .100); 	# Sleep a bit
}

sub UserCodePreHook
{
    for my $port_name (@DSC_Alarm_Ports) {
      &::check_for_generic_serial_data($port_name) if $::Serial_Ports{$port_name}{object};
      my $data = $::Serial_Ports{$port_name}{data_record};
      &::logit("$::config_parms{data_dir}/logs/$port_name.$::Year_Month_Now.log", "$data") if $data;
      ::print_log "DSC_Alarm port $port_name data = $data, $::Loop_Count\n" if $data and $::config_parms{debug} eq 'DSC';
    }
}

sub UserCodePostHook
{
    #
    # Reset data for _now functions
    #
    for my $port_name (@DSC_Alarm_Ports) {
      $::Serial_Ports{$port_name}{data_record} =''; 
    }
}

#
# End of system functions; start of functions called by user scripts.
#

sub new {
    my ($class, $port_name) = @_;
    $port_name = 'DSC_Alarm' if !$port_name;
    my $self = {state => ''};
    $$self{port_name} = $port_name;
    bless $self, $class;
    return $self;
}

sub said {
    my $port_name = $_[0]->{port_name};
    return $main::Serial_Ports{$port_name}{data_record};
}


1;

