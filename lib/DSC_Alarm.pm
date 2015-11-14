
=head1 B<DSC_Alarm>

=head2 SYNOPSIS

  $DSC_Alarm = new DSC_Alarm;
  if (my $log = said $DSC_Alarm) {
    print_log "Alarm system data = $log\n";
  }

  mh.ini entry of 'DSC_Alarm:2_serial_port=com5'

  $DSC_test = new DSC_Alarm('DSC_Alarm:2');
  if (my $state = state $DSC_test) {
    print_log "Alarm system state change, state = $state\n";
  }

=head2 DESCRIPTION

DSC_Alarm module supports the DSC PC5400 serial printer interface. This allows mh to be aware of events that DSC alarm systems log to their event buffers

The PC5400 works with: PC5010, PC1555, PC580, PC5015, and PC1575 main panels.

  DSC programming location 801 subsection 01 set to:
   1-3---78
   1        = Printer Enabled
    2       = Handshake from printer (DTR)
     3      = 80 Column Printer (off = 40 Column)
      4     = 300  Baud Enabled
       5    = 1200 Baud Enabled
        6   = 2400 Baud Enabled
         7  = 4800 Baud Enabled
          8 = Local clock displays 24hr time
  DSC programming location 801 subsection 02 set to: 01 = English

Logging: The internal support module for DSC_Alarm (DSC_Alarm.pm) maintains a log of all serial data received from the DSC PC5400 interface.  This log is placed in /mh.ini parm data_dir/logs/$port_name.YYYY_MM.log; for example, the log entries shown below would be in file '/mh/data/logs/DSC_Alarm.2000_10.log'.  This implies a new log will be started each month.

DSC User Codes:

  40 = Master code (can arm/disarm, change codes, any keypad function)
  41 = Supervisor code (can arm/disarm, change codes)
  42 = Supervisor code (can arm/disarm, change codes)
  01-32 = User codes (can arm/disarm, can be associated to individual wireless keys)
  33 = Duress code (can arm/disarm + sends duress code to master station)
  34 = Duress code (can arm/disarm + sends duress code to master station)

The above information derived from PC1555 master panel; please see the installer manual for your particular panel for further information.

Duress code reporting is NOT reflected via states as of December 2000.  Coming soon...

Examples of typical DSC alarm system event/log entries:
Mon 10/09/00 17:09:00 DSC_Alarm.pm Initialized Mon 10/09/00 17:10:16 17:10 10/09/00 System [*1] Access by User Mon 10/09/00 17:12:28 17:12 10/09/00 System Partial Closing Mon 10/09/00 17:12:28 17:12 10/09/00 System Bypass Zone 1 Mon 10/09/00 17:12:28 17:12 10/09/00 System Bypass Zone 2 Mon 10/09/00 17:12:28 17:12 10/09/00 System Bypass Zone 4 Mon 10/09/00 17:12:29 17:12 10/09/00 System Closing by User Code 40 Mon 10/09/00 17:12:29 17:12 10/09/00 System Armed in Away Mode Mon 10/09/00 17:12:45 17:12 10/09/00 System Opening by User Code 2 Mon 10/09/00 17:14:42 17:14 10/09/00 System Closing by User Code 40 Mon 10/09/00 17:14:43 17:14 10/09/00 System Armed in Away Mode Mon 10/09/00 17:14:47 17:14 10/09/00 System Opening by User Code 40 Mon 10/09/00 17:22:28 17:22 10/09/00 System [*1] Access by User Mon 10/09/00 17:33:39 DSC_Alarm.pm Initialized Tue 10/10/00 09:47:38 09:47 10/10/00 System Closing by User Code 40 Tue 10/10/00 09:47:38 09:47 10/10/00 System Armed in Away Mode Tue 10/10/00 17:48:42 17:48 10/10/00 System Opening by User Code 40 Tue 10/10/00 23:37:33 23:37 10/10/00 System Closing by User Code 40 Tue 10/10/00 23:37:33 23:37 10/10/00 System Armed in Away Mode Wed 10/11/00 07:38:11 07:38 10/11/00 System Opening by User Code 40

=head2 INHERITS

B<Generic_Item>

=head2 METHODS

=over

=cut

use strict;

package DSC_Alarm;

@DSC_Alarm::ISA = ('Generic_Item');

my @DSC_Alarm_Ports;
my %DSC_Alarm_Objects;

=item C<serial_startup>

Create serial port(s) according to mh.ini  Register hooks if any ports created.

=cut

sub serial_startup {
    my ($instance) = @_;
    push( @DSC_Alarm_Ports, $instance );

    my $port  = $::config_parms{ $instance . "_serial_port" };
    my $speed = $::config_parms{ $instance . "_baudrate" };
    if ( &::serial_port_create( $instance, $port, $speed, 'dtr' ) ) {

        # The create call will not succeed for proxies, so we don't enter this case for proxy configsk
        init( $::Serial_Ports{$instance}{object} );
        ::print_log
          "\nDSC_Alarm.pm initialzed $instance on hardware $port at $speed baud\n"
          if $main::Debug{dsc};
    }

    # Add to the generic list so check_for_generic_serial_data is called for us automatically
    push( @::Generic_Serial_Ports, $instance );

    if ( 1 == scalar @DSC_Alarm_Ports )    # Add hooks on first call only
    {
        &::Reload_pre_add_hook( \&DSC_Alarm::reload_reset, 'persistent' );
        &::MainLoop_pre_add_hook( \&DSC_Alarm::check_for_data, 'persistent' );

        #&::Serial_data_add_hook(\&DSC_Alarm::serial_data, 'persistent');
        #      &::MainLoop_pre_add_hook( \&DSC_Alarm::UserCodePreHook,   1);
        #      &::MainLoop_post_add_hook( \&DSC_Alarm::UserCodePostHook, 1 );
        $::Year_Month_Now =
          &::time_date_stamp( 10, time );    # Not yet set when we init.
        &::logit(
            "$::config_parms{data_dir}/logs/$instance.$::Year_Month_Now.log",
            "DSC_Alarm.pm Initialized" );
        ::print_log "DSC_Alarm.pm adding hooks \n" if $main::Debug{dsc};
    }
}

sub init {
    my ($serial_port) = @_;

    $serial_port->error_msg(0);

    $serial_port->parity_enable(1);
    $serial_port->databits(8);
    $serial_port->parity("none");
    $serial_port->stopbits(1);

    $serial_port->dtr_active(1) or warn "Could not set dtr_active(1)";
    $serial_port->rts_active(0);
    select( undef, undef, undef, .100 );    # Sleep a bit
}

sub reload_reset {
    undef %DSC_Alarm_Objects;
}

sub check_for_data {
    for my $port_name (@DSC_Alarm_Ports) {
        if ( my $data = $main::Serial_Ports{$port_name}{data_record} ) {
            $main::Serial_Ports{$port_name}{data_record} = undef;
            &::logit(
                "$::config_parms{data_dir}/logs/$port_name.$::Year_Month_Now.log",
                "$data"
            );
            ::print_log
              "DSC_Alarm port $port_name data = $data, $::Loop_Count\n"
              if $main::Debug{dsc};

            #print "DSC_Alarm port $port_name data = $data, $::Loop_Count\n";

            if ( $DSC_Alarm_Objects{$port_name} ) {
                my @object_refs = @{ $DSC_Alarm_Objects{$port_name} };
                while ( my $self = pop @object_refs ) {
                    if ( $data =~ /^.*System\s+Armed in (.*) Mode/ ) {
                        set $self "Armed";
                        $self->{mode} = $1;
                    }
                    set $self "Disarmed" if $data =~ /^.*System\s+Opening.*/;
                    if ( $data =~ /^.*System\s+Alarm Zone\s+(\d+).*/ ) {
                        set $self "Alarm";
                        $self->{zone} = $1;
                    }
                    $self->{user} = $2 if $data =~ /^.*User (|Code)\s+(\d+).*/;
                }
            }
            else {
                ::print_log
                  "DSC_Alarm.pm Warning: Data received on port $port_name, but no user script objects defined\n";
                my $warn_once = new DSC_Alarm($port_name)
                  ;    # Create dummy object to avoid repetitious log messages.
            }
        }
    }
}

#
# End of system functions; start of functions called by user scripts.
#

=item C<new('alarm-name')>

Where 'alarm-name' is the prefix used in the mh.ini entry 'DSC_Alarm_serial_port=xyz'.  The 'alarm-name' argument defaults to 'DSC_Alarm' if not specified.

=cut

sub new {
    my ( $class, $port_name ) = @_;
    $port_name = 'DSC_Alarm' if !$port_name;

    my $self = {};
    $$self{state}     = '';
    $$self{said}      = '';
    $$self{state_now} = '';
    $$self{port_name} = $port_name;
    bless $self, $class;

    push @{ $DSC_Alarm_Objects{$port_name} }, $self;
    ::print_log
      "DSC_Alarm.pm Warning: Over 50 DSC Alarm user script objects defined on $port_name\n"
      if 50 < scalar @{ $DSC_Alarm_Objects{$port_name} };
    restore_data $self ( 'user', 'zone', 'mode' );

    return $self;
}

=item C<said>

Returns the last serial data received.  Valid for 1 pass only.  Important Note:  Due to mh internals, the "said" method and the "state" method (and all "state" derived methods) lag each other's values by 1 pass through the user scripts.  As such, any given script should use "said" or "state", but should NOT mix the two!

=cut

sub said {
    my $port_name = $_[0]->{port_name};
    return $main::Serial_Ports{$port_name}{data_record};
}

=item C<user>

User number of last code used to arm/disarm system.  If present, mh.ini parm DSC_Alarm_user_nn=xyz will cause "user" to return string "xyz" from the parm.

=cut

sub user {
    my $instance = $_[0]->{port_name};
    my $user     = $_[0]->{user};
    my $name     = $main::config_parms{ $instance . '_user_' . $user };
    $name = $user if !$name;
    return $name;
}

=item C<alarm_now>

True when system enters Alarm state.  Valid for 1 pass only.

=cut

sub alarm_now {
    return 'Alarm' eq $_[0]->{state_now};
}

=item C<zone>

Zone number that caused Alarm. Valid only when alarm_now is true.

=cut

sub zone {
    return if !alarm_now $_[0];
    return $_[0]->{zone};
}

=item C<mode>

Returns arming mode. Valid only when state = Armed.

  Stay = System armed in stay mode; User pressed F1 key before arming.
  Away = System armed in away mode; User pressed F2 key (or nothing) before arming

Note: Most DSC systems will not arm in "Stay" mode unless at least one zone is defined as a "Stay/Away" zone.  Also, even when "Away" mode is requested system will be in "Stay" mode unless a delay zone is violated during the exit delay.

=cut

sub mode {
    return if 'Armed' ne $_[0]->{state};
    return $_[0]->{mode};
}

1;

=back

=head2 INHERITED METHODS

=over

=item C<state>

Returns last state of alarm system from following values:

  Armed    = System is closed and armed.
  Disarmed = System is opened.
  Alarm    = System is alarming.

=item C<state_now>

Same as state, but valid for 1 pass only.

=back

=head2 INI PARAMETERS

  DSC_Alarm_serial_port=com2

  DSC_Alarm_serial_port=COM1 or /dev/ttys0
  DSC_Alarm_baudrate=4800

Multiple instances may be supported by adding instance numbers to the parms as in:

  DSC_Alarm:1_serial_port=COMx or /dev/ttysX
  DSC_Alarm:1_baudrate=4800
  DSC_Alarm:2_serial_port=COMy or /dev/ttysY
  DSC_Alarm:2_baudrate=4800

Optional mh.ini entries:

  DSC_Alarm_user_40=Jane Doe
  DSC_Alarm_user_1=Bob Smith

=head2 AUTHOR

By: Danal Estes, N5SVV
E-Mail: danal@earthling.net

Based on original code by Bill Sobel:
bsobel@vipmail.com

=head2 SEE ALSO

See mh/code/public/Danal/DSC_Alarm.pl for more info/examples

=head2 LICENSE

This program is free software; you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation; either version 2 of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more details.

You should have received a copy of the GNU General Public License along with this program; if not, write to the Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.

=cut
