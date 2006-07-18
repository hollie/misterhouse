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

use strict;

package DSC_Alarm;

@DSC_Alarm::ISA = ('Generic_Item');

my @DSC_Alarm_Ports;
my %DSC_Alarm_Objects;

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
    if (&::serial_port_create($instance, $port, $speed, 'dtr'))
    {
        # The create call will not succeed for proxies, so we don't enter this case for proxy configsk
        init($::Serial_Ports{$instance}{object});
        ::print_log "\nDSC_Alarm.pm initialzed $instance on hardware $port at $speed baud\n" if $main::Debug{dsc};
    }

    # Add to the generic list so check_for_generic_serial_data is called for us automatically
    push(@::Generic_Serial_Ports, $instance);

    if (1==scalar @DSC_Alarm_Ports)   # Add hooks on first call only
    {
        &::Reload_pre_add_hook(\&DSC_Alarm::reload_reset, 'persistent');
        &::MainLoop_pre_add_hook(\&DSC_Alarm::check_for_data, 'persistent');

        #&::Serial_data_add_hook(\&DSC_Alarm::serial_data, 'persistent');
        #      &::MainLoop_pre_add_hook( \&DSC_Alarm::UserCodePreHook,   1);
        #      &::MainLoop_post_add_hook( \&DSC_Alarm::UserCodePostHook, 1 );
        $::Year_Month_Now = &::time_date_stamp(10,time);  # Not yet set when we init.
        &::logit("$::config_parms{data_dir}/logs/$instance.$::Year_Month_Now.log", "DSC_Alarm.pm Initialized");
        ::print_log "DSC_Alarm.pm adding hooks \n" if $main::Debug{dsc};
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

sub reload_reset
{
    undef %DSC_Alarm_Objects;
}

sub check_for_data
{
    for my $port_name (@DSC_Alarm_Ports)
    {
        if (my $data = $main::Serial_Ports{$port_name}{data_record})
        {
            $main::Serial_Ports{$port_name}{data_record} = undef;
            &::logit("$::config_parms{data_dir}/logs/$port_name.$::Year_Month_Now.log", "$data");
            ::print_log "DSC_Alarm port $port_name data = $data, $::Loop_Count\n" if $main::Debug{dsc};
            #print "DSC_Alarm port $port_name data = $data, $::Loop_Count\n";

            if ($DSC_Alarm_Objects{$port_name})
            {
                my @object_refs = @{$DSC_Alarm_Objects{$port_name}};
                while (my $self = pop @object_refs)
                {
                    if ($data =~ /^.*System\s+Armed in (.*) Mode/)
                    {
                      set $self "Armed";
                      $self->{mode} = $1;
                    }
                    set $self "Disarmed" if $data =~ /^.*System\s+Opening.*/;
                    if ($data =~ /^.*System\s+Alarm Zone\s+(\d+).*/)
                    {
                      set $self "Alarm";
                      $self->{zone} = $1;
                    }
                    $self->{user} = $2   if $data =~ /^.*User (|Code)\s+(\d+).*/;
                }
            }
            else
            {
                ::print_log "DSC_Alarm.pm Warning: Data received on port $port_name, but no user script objects defined\n";
                my $warn_once = new DSC_Alarm($port_name);  # Create dummy object to avoid repetitious log messages.
            }
        }
    }
}

#
# End of system functions; start of functions called by user scripts.
#

sub new {
    my ($class, $port_name) = @_;
    $port_name = 'DSC_Alarm' if !$port_name;

    my $self = {};
    $$self{state}     = '';
    $$self{said}      = '';
    $$self{state_now} = '';
    $$self{port_name} = $port_name;
    bless $self, $class;

    push @{$DSC_Alarm_Objects{$port_name}}, $self;
    ::print_log "DSC_Alarm.pm Warning: Over 50 DSC Alarm user script objects defined on $port_name\n" if 50 < scalar @{$DSC_Alarm_Objects{$port_name}};
    restore_data $self ('user', 'zone', 'mode');

    return $self;
}

sub said {
    my $port_name = $_[0]->{port_name};
    return $main::Serial_Ports{$port_name}{data_record};
}

sub user {
    my $instance = $_[0]->{port_name};
    my $user     = $_[0]->{user};
    my $name = $main::config_parms{$instance . '_user_' . $user};
    $name = $user if !$name;
    return $name;
}

sub alarm_now {
    return 'Alarm' eq $_[0]->{state_now};
}

sub zone {
    return if !alarm_now $_[0];
    return $_[0]->{zone};
}

sub mode {
    return if 'Armed' ne $_[0]->{state};
    return $_[0]->{mode};
}


1;

