
=head1 B<RCSsTR40>

=head2 SYNOPSIS

  $$self{cool_start} = $::Time;

Creating the object:

   $thermostat = new RCSsTR40;
   die "rcs init failed\n" unless $thermostat;

Use internet weather temperature to automatically update the outside
temperature on the display.  If you have a physical external temp monitor
hooked up to the unit, then this will have no effect.  If you have a
weather station or an iButton, just change the reference from
\$Weather{TempInternet} to something else and stop running
'Get internet weather data' every hour.

   if ($Startup or $Reload) {
      $thermostat->auto_set_outside_temp(\$Weather{TempInternet});
   }
   if ($New_Hour or $Startup) {
      run_voice_cmd 'Get internet weather data';
   }

Watch for temperature changes (can do the same with outside_temp_change if
you have a physical outside temperature monitor hooked up to the TR40).

   if (state_now $thermostat eq 'temp_change') {
      my $temp = $thermostat->get_temp();
      print "Got new thermostat temperature: $temp\n";
   }

Watch for other changes such as fan mode, system mode, etc.  I only currently
watch for vacation mode (enabled/disabled by holding down the HOLD button for 3
seconds) and use this to enable/disable the Misterhouse vacation mode.  This
module looks for the temperatures to change to 66 and 80 at the same time to
detect this.  This is what my unit does when you place it into vacation mode.
You can change the temperatures (locally or remotely) after it goes into
vacation mode and the mode will still remain active until turned off on
the control panel.

   $mode_vacation = new Generic_Item;
   $mode_vacation->set_states('all', 'one', 'nobody');

   if ($state = state_changed $thermostat) {
      print "Got new thermostat state: $state\n";
      if ($state eq 'vacation') {
         set $mode_vacation 'all';
      } elsif ($state eq 'no_vacation') {
         set $mode_vacation 'nobody';
      }
   }

And, you can set the temperature and mode at will...

   if (state_changed $mode_vacation eq 'all') {
      $thermostat->mode('auto');
      $thermostat->heat_setpoint(60);
      $thermostat->cool_setpoint(89);
   }

All of the states that may be set:

   temp_change: inside temperature changed (call get_temp() to get value)
   outside_temp_change: outside temperature changed (call
      get_outside_temp() to get value)
   heat_sp_change: Heat setpoint was changed from the control pad
      (call get_heat_sp() to get value).
   cool_sp_change: Cool setpoint was changed from the control pad
      (call get_cool_sp() to get value).
   off: System mode set to 'off'
   heat: System mode set to 'heat'
   cool: System mode set to 'cool'
   auto: System mode set to 'auto'
   emerg_heat: System mode set to emergency heat (only with heat pumps?)
   invalid: Controlled failed to communicate with the control pad
   fan_on: Fan was turned on
   fan_auto: Fan was set to auto mode
   hold: Program hold was activated by user
   run: Program mode was resumed by user
   vacation: Vacation mode was enabled by user
   no_vacation: Vacation mode was turned off by user

=head2 DESCRIPTION

Control RCS serial (rs232/rs485) TR40 model thermostats.  This will probably
need some enhancement to work with rs485, or at least if you want to put
multiple units on the same drop.

I created a new module because I don't have a full understanding of the
compatibility issues with older/other models.  My new module *should* be usable
with multiple thermostats and could be expanded to support some of the more
advanced RCS thermostat modules.

SERIAL PIN CONNECTIONS

PS - I don't know if I'm just stupid or what, but I could not send anything
to the TR40 through either minicom (Linux) or HypterTerminal (Windows), but I
could receive messages (i.e. when the TR40 was powered up).  I thought it was
broken, but it turns out that this module talked to it fine.  Who knows.

I don't know why they don't mention this in the manual... maybe it is common
knowledge?  But I went to Radio Shack and bought a female, 9-pin serial
connector and use that to wire into the TR40 control unit.  These pin-outs
worked for me:

   Cable            Controller
   -----------------------------------
                    +V (not connected)
   Pin 5 (SG)       G (Gnd)
   Pin 2 (receive)  T+ (transmit)
   Pin 3 (transmit) R- (receive)

INITIAL CONFIGURATION

I recommend enabling auto-send either in the configuration menu or by
calling (once) the function: set_variable(74,1);  I don't like having to leave
the thermostat in "hold" mode, so instead I clear out the schedule (just once
using the clear_schedule() command).

BUGS

The get_heat_run_time() and get_cool_run_time() functions are not always
accurate... I must still have some bugs there.

=head2 INHERITS

B<Serial_Item>

=head2 METHODS

=over

=cut

use strict;

package RCSsTR40;

@RCSsTR40::ISA = ('Serial_Item');

my %RCSsTR40_Data;

sub serial_startup {
    my ($instance) = @_;

    my $port      = $::config_parms{ $instance . "_serial_port" };
    my $speed     = $::config_parms{ $instance . "_baudrate" };
    my $thermaddr = $::config_parms{ $instance . "_address" };
    $thermaddr = "01" if !$thermaddr;
    $RCSsTR40_Data{$instance}{'addr'} = $thermaddr;

    &::serial_port_create( $instance, $port, $speed );

    if ( 1 == scalar( keys %RCSsTR40_Data ) ) {   # Add hooks on first call only
        &::MainLoop_post_add_hook( \&RCSsTR40::poll_all, 1 );
        &::MainLoop_pre_add_hook( \&RCSsTR40::check_for_data, 1 );
    }
}

sub poll_all {
    if ($main::New_Minute) {
        for my $port_name ( keys %RCSsTR40_Data ) {
            $RCSsTR40_Data{$port_name}{'obj'}->_check_auto_outside_temp();
            $RCSsTR40_Data{$port_name}{'obj'}->_poll();
        }
    }
    if ($main::New_Hour) {
        for my $port_name ( keys %RCSsTR40_Data ) {
            $RCSsTR40_Data{$port_name}{'obj'}->set_date_time();
        }
    }
}

sub check_for_data {
    for my $port_name ( keys %RCSsTR40_Data ) {
        &::check_for_generic_serial_data($port_name)
          if $::Serial_Ports{$port_name}{object};
        my $data = $::Serial_Ports{$port_name}{data_record};
        next if !$data;

        #main::print_log("$port_name got: [$::Serial_Ports{$port_name}{data_record}]");
        $RCSsTR40_Data{$port_name}{'obj'}->_parse_data($data);
        $RCSsTR40_Data{$port_name}{'send_count'}--;
        if ( $RCSsTR40_Data{$port_name}{'send_count'} < 0 ) {

            # User changed something and a status message was sent... but for some
            # reason the status message sent doesn't usually (ever?) contain the
            # actual change.  So, make sure we requset a full status update.
            print
              "RCSs_TR40: Received status report... requesting full report\n"
              unless $main::config_parms{no_log} =~ /RCSsTR40/;
            $RCSsTR40_Data{$port_name}{'send_count'}++;
            $RCSsTR40_Data{$port_name}{'obj'}->_poll();
        }
        $main::Serial_Ports{$port_name}{data_record} = '';
        if ( ( $RCSsTR40_Data{$port_name}{'obj'}->{'last_change'} + 5 ) ==
            $main::Time )
        {
            $RCSsTR40_Data{$port_name}{'obj'}->{'last_change'} = 0;
            $RCSsTR40_Data{$port_name}{'obj'}->_poll();
        }
    }
}

# -------------------- START OF SUBROUTINES --------------------
# --------------------------------------------------------------

sub new {
    my ( $class, $port_name ) = @_;
    $port_name = 'RCSsTR40' if !$port_name;
    my $thermaddr = $RCSsTR40_Data{$port_name}{'addr'};

    my $self = {};
    $$self{state}        = '';
    $$self{said}         = '';
    $$self{state_now}    = '';
    $$self{port_name}    = $port_name;
    $$self{thermaddress} = $thermaddr;
    bless $self, $class;
    $RCSsTR40_Data{$port_name}{'obj'}        = $self;
    $RCSsTR40_Data{$port_name}{'send_count'} = 0;
    push(
        @{ $$self{states} },
        'temp_change',    'outside_temp_change', 'heat_sp_change',
        'cool_sp_change', 'off',                 'heat',
        'cool',           'auto',                'emerg_heat',
        'invalid',        'fan_on',              'fan_auto',
        'hold',           'run',                 'vacation',
        'no_vacation'
    );
    $self->_get_times();
    $self->_poll();
    return $self;
}

sub _get_times {
    my ($self) = @_;
    my $instance = $self->{port_name};
    &::print_log("Requesting minimum run/off times from thermostat");
    my $cmd = "A=$self->{thermaddress} SV11=?\r";
    $main::Serial_Ports{$instance}{object}->write($cmd);
    $RCSsTR40_Data{ $$self{'port_name'} }{'send_count'}++;
    select( undef, undef, undef, 0.1 );
    &check_for_data();
    my $cmd = "A=$self->{thermaddress} SV10=?\r";
    $RCSsTR40_Data{ $$self{'port_name'} }{'send_count'}++;
    $main::Serial_Ports{$instance}{object}->write($cmd);
    select( undef, undef, undef, 0.1 );
    &check_for_data();
}

sub _process_off_times {
    my ($self) = @_;
    if ( $$self{heat_start} and $$self{heat_end} ) {
        if ( $$self{heat_end} <= $::Time ) {
            if ( $$self{heat_start} < $$self{heat_end} ) {
                $$self{hrt} += ( $$self{heat_end} - $$self{heat_start} );
                $$self{heat_start} = 0;
            }
        }
    }
    if ( $$self{cool_start} and $$self{cool_end} ) {
        if ( $$self{cool_start} < $$self{cool_end} ) {
            if ( $$self{cool_end} <= $::Time ) {
                $$self{hrt} += ( $$self{cool_end} - $$self{cool_start} );
                $$self{cool_start} = 0;
            }
        }
    }
}

sub get_system_state {
    my ($self) = @_;
    if ( $$self{heat_start} and ( $$self{heat_start} < $::Time ) ) {
        return 'heat';
    }
    elsif ( $$self{cool_start} and ( $$self{cool_start} < $::Time ) ) {
        return 'cool';
    }
    return 'off';
}

=item C<reset_run_times()>

Clears all runtime data

=cut

sub reset_run_times {
    my ($self) = @_;
    $self->_process_off_times();
    $$self{hrt} = 0;
    $$self{crt} = 0;
    if ( $$self{heat_start} and ( $$self{heat_start} < $::Time ) ) {
        $$self{heat_start} = $::Time;
    }
    if ( $$self{cool_start} and ( $$self{cool_start} < $::Time ) ) {
        $$self{cool_start} = $::Time;
    }
}

=item C<get_heat_run_time()>

Returns # of seconds of heating since last reset

=cut

sub get_heat_run_time {
    my ($self) = @_;
    $self->_process_off_times();
    my $tmp = 0;
    if ( $$self{heat_start} and ( $$self{heat_start} < $::Time ) ) {
        $tmp = ( $::Time - $$self{heat_start} );
    }
    return ( $$self{hrt} + $tmp );
}

=item C<get_cool_run_time()>

Returns # of seconds of cooling since last reset

=cut

sub get_cool_run_time {
    my ($self) = @_;
    $self->_process_off_times();
    my $tmp = 0;
    if ( $$self{cool_start} and ( $$self{cool_start} < $::Time ) ) {
        $tmp = $::Time - $$self{cool_start};
    }
    return ( $$self{crt} + $tmp );
}

sub _send_cmd {
    my ( $self, $cmd ) = @_;
    my $instance = $$self{port_name};
    print "$::Time_Date: RCSsTR40: Executing command $cmd\n"
      unless $main::config_parms{no_log} =~ /RCSsTR40/;
    my $data = "A=$self->{thermaddress} $cmd\r";
    $main::Serial_Ports{$instance}{object}->write($data);
    select( undef, undef, undef, 0.15 );
    $$self{'last_change'} = $main::Time;
    $self->_poll();
}

=item C<mode()>

Sets system mode to argument: 'off', 'heat', 'cool', 'auto', or
'emerg_heat' (if available)

=cut

sub mode {
    my ( $self, $state ) = @_;
    $state = lc($state);
    print "$::Time_Date: RCSsTR40 -> Mode $state\n"
      unless $main::config_parms{no_log} =~ /RCSsTR40/;
    my $mode;
    if ( $state eq 'off' ) {
        $mode = "0";
    }
    elsif ( $state eq 'heat' ) {
        $mode = "H";
    }
    elsif ( $state eq 'cool' ) {
        $mode = "C";
    }
    elsif ( $state eq 'auto' ) {
        $mode = "A";
    }
    elsif ( $state eq 'emerg_heat' ) {
        $mode = "EH";
    }
    else {
        print "RCSsTR40: Invalid Mode state: $state\n";
        return ();
    }
    $$self{'mode'} = $state;
    $self->_send_cmd("M=$mode");
}

=item C<fan()>

Sets fan to 'on' or 'off'

=cut

sub fan {
    my ( $self, $state ) = @_;
    $state = lc($state);
    print "$::Time_Date: RCSsTR40 -> Fan $state\n"
      unless $main::config_parms{no_log} =~ /RCSsTR40/;
    my $fan;
    if ( ( $state eq 'on' ) or ( $state eq 'fan_on' ) ) {
        $fan   = 1;
        $state = 'fan_on';
    }
    elsif ( $state eq 'auto' or $state eq 'off' or $state eq 'fan_auto' ) {
        $fan   = 0;
        $state = 'fan_auto';
    }
    else {
        print "RCSsTR40: Invalid Fan state: $state\n";
        return ();
    }
    $$self{'fan_mode'} = $state;
    $self->_send_cmd("F=$fan");
}

=item C<set_schedule_control()>

Sets schedule control to 'hold' or 'run'.  Note
that this has no effect if there is no scehdule defined.

=cut

sub set_schedule_control {
    my ( $self, $state ) = @_;
    $state = lc($state);
    print "$::Time_Date: RCSsTR40 -> Schedule Control $state\n"
      unless $main::config_parms{no_log} =~ /RCSsTR40/;
    my $val;
    if ( $state eq 'hold' ) {
        $val = 0;
    }
    elsif ( $state eq 'run' ) {
        $val = 1;
    }
    else {
        print "RCSsTR40: Invalid schedule control state: $state\n";
        return ();
    }
    $$self{'schedule_mode'} = $state;
    $self->_send_cmd("SC=$val");
}

=item C<lock_display()>

Locks the TR40 display.

=cut

sub lock_display {
    my ( $self, $msg ) = @_;
    print "$::Time_Date: RCSsTR40 -> Lock Display\n"
      unless $main::config_parms{no_log} =~ /RCSsTR40/;
    $self->_send_cmd("DL=1");
}

=item C<unlock_display()>

Unlocks the TR40 display.

=cut

sub unlock_display {
    my ( $self, $msg ) = @_;
    print "$::Time_Date: RCSsTR40 -> Unlock Display\n"
      unless $main::config_parms{no_log} =~ /RCSsTR40/;
    $self->_send_cmd("DL=0");
}

=item C<create_schedule_entry()>

Creates a schedule entry.  Parameters are:

  1) day of week (1=Sunday, ..., 7=Saturday)
  2) entry # (1 through 4)
  3) hour (00-23)
  4) minute (00-59)
  5) heat setpoint
  6) cool setpoint

=cut

sub create_schedule_entry {
    my ( $self, $day, $entry, $hour, $min, $heat, $cool ) = @_;
    unless ( ( $day >= 1 ) and ( $day <= 7 ) ) {
        print "RCSsTR40: set_schedule: Day must be 1 through 7: $day\n";
    }
    unless ( ( $entry >= 1 ) and ( $entry <= 4 ) ) {
        print "RCSsTR40: set_schedule: Entry # must be 1 through 4: $entry\n";
    }
    $min =~ s/^\d$/0$min/;
    $hour =~ s/^\d$/0$hour/;
    $heat =~ s/^\d$/0$heat/;
    $cool =~ s/^\d$/0$cool/;
    print
      "$::Time_Date: RCSsTR40 -> Set Schedule: $day/$entry=$hour$min$heat$cool\n"
      unless $main::config_parms{no_log} =~ /RCSsTR40/;
    $self->_send_cmd("SE$day/$entry=$hour$min$heat$cool");
}

=item C<clear_schedule()>

A convenience function that can be used to clear out
the entire schedule.  This is permanent so it only has to be run once.
I use this so that Misterhouse can completely control the thermostat.

=cut

sub clear_schedule {
    my ($self) = @_;
    print "$::Time_Date: RCSsTR40 -> Clearing schedule\n"
      unless $main::config_parms{no_log} =~ /RCSsTR40/;
    for ( my $i = 1; $i <= 7; $i++ ) {
        $self->create_schedule_entry( $i, 1, 6,  0, 0, 0 );
        $self->create_schedule_entry( $i, 2, 9,  0, 0, 0 );
        $self->create_schedule_entry( $i, 3, 16, 0, 0, 0 );
        $self->create_schedule_entry( $i, 4, 21, 0, 0, 0 );
    }
}

=item C<set_variable()>

Sets an arbitrary variable to an arbitrary value.  First
argument is the variable number (from back of programming manual) and
the second argument is the value.

=cut

sub set_variable {
    my ( $self, $var, $val ) = @_;
    print "$::Time_Date: RCSsTR40 -> Set Variable $var=$val\n"
      unless $main::config_parms{no_log} =~ /RCSsTR40/;
    $self->_send_cmd("SV$var=$val");
}

=item C<clear_messages()>

Clears all text messages from the system

=cut

sub clear_messages {
    my ( $self, $msg ) = @_;
    print "$::Time_Date: RCSsTR40 -> Clear Text Messages\n"
      unless $main::config_parms{no_log} =~ /RCSsTR40/;
    $self->_send_cmd("TM=\"#\"");
}

=item C<send_text_msg()>

Sends an arbitrary text message to the display.  The TR40
automatically timestamps the message.  Max length is 80 characters and
the double-quotes character (") is not allowed.

Use carriage returns (\r) for new lines

=cut

sub send_text_msg {
    my ( $self, $msg ) = @_;
    print "$::Time_Date: RCSsTR40 -> Send Text message: $msg\n"
      unless $main::config_parms{no_log} =~ /RCSsTR40/;
    if ( $msg =~ /\"/ ) {
        print
          "$::Time_Date: RCSsTR40 -> send_text_msg ERROR message contains double-quotes: $msg\n";
        return;
    }
    if ( length($msg) > 80 ) {
        print
          "$::Time_Date: RCSsTR40 -> send_text_msg ERROR message is longer than 80 characters: $msg\n";
        return;
    }
    $self->_send_cmd("TM=\"$msg\"");
}

=item C<cool_setpoint()>

Sets a new cool setpoint.

=cut

sub cool_setpoint {
    my ( $self, $temp ) = @_;
    print "$::Time_Date: RCSsTR40 -> Cool setpoint $temp\n"
      unless $main::config_parms{no_log} =~ /RCSsTR40/;
    if ( $temp !~ /^\d+$/ ) {
        print
          "$::Time_Date: RCSsTR40 -> cool_setpoint ERROR $temp not numeric\n";
        return;
    }
    if (   ( $temp < $$self{'cool_min_limit'} )
        or ( $temp > $$self{'cool_max_limit'} ) )
    {
        print
          "$::Time_Date: RCSsTR40 -> cool_setpoint WARNING temp '$temp' is outside of limits\n";
        return;
    }
    $$self{'cool_sp'}         = $temp;
    $$self{'cool_sp_pending'} = $temp;
    $self->_send_cmd("SPC=$temp");
}

=item C<heat_setpoint()>

Sets a new heat setpoint.

=cut

sub heat_setpoint {
    my ( $self, $temp ) = @_;
    print "$::Time_Date: RCSsTR40 -> Heat setpoint $temp\n"
      unless $main::config_parms{no_log} =~ /RCSsTR40/;
    if ( $temp !~ /^\d+$/ ) {
        print
          "$::Time_Date: RCSsTR40 -> heat_setpoint ERROR $temp not numeric\n";
        return;
    }
    if (   ( $temp < $$self{'heat_min_limit'} )
        or ( $temp > $$self{'heat_max_limit'} ) )
    {
        print
          "$::Time_Date: RCSsTR40 -> heat_setpoint WARNING temp '$temp' is outside of limits\n";
        return;
    }
    $$self{'heat_sp'}         = $temp;
    $$self{'heat_sp_pending'} = $temp;
    $self->_send_cmd("SPH=$temp");
}

=item C<set_outside_temp()>

Sets the displayed outside temp.  Only works if no
external temperature sensor is connected to the TR40.

=cut

sub set_outside_temp {
    my ( $self, $temp ) = @_;
    print "$::Time_Date: RCSsTR40 -> Set outside temp: $temp\n"
      unless $main::config_parms{no_log} =~ /RCSsTR40/;
    if ( $temp !~ /^\d+$/ ) {
        print
          "$::Time_Date: RCSsTR40 -> set_outside_temp ERROR $temp not numeric\n";
        return;
    }
    $$self{'outside_temp'} = $temp;
    $self->_send_cmd("OT=$temp");
}

=item C<set_remote_temp()>

Sets a remote temperature that will be average with the
internal temperature sensor when determining the actual current temperature.
Does not work if you actually have a remote temperature sensor connected.

=cut

sub set_remote_temp {
    my ( $self, $temp ) = @_;
    print "$::Time_Date: RCSsTR40 -> Set remote temp: $temp\n"
      unless $main::config_parms{no_log} =~ /RCSsTR40/;
    if ( $temp !~ /^\d+$/ ) {
        print
          "$::Time_Date: RCSsTR40 -> set_remote_temp ERROR $temp not numeric\n";
        return;
    }
    $self->_send_cmd("RT=$temp");
}

=item C<set_date_time()>

Sends Misterhouse's current date/time to the TR40.  Note
that the module automatically calls this once per hour.

=cut

sub set_date_time {
    my ($self) = @_;
    my ( $Second, $Minute, $Hour, $Mday, $Month, $Year, $Wday ) =
      localtime $main::Time;
    $Year += 1900;
    $Wday++;
    $Second =~ s/^\d$/0$Second/;
    $Minute =~ s/^\d$/0$Minute/;
    $Hour =~ s/^\d$/0$Hour/;
    $Month =~ s/^\d$/0$Month/;
    $Year =~ s/^\d\d(\d\d)$/$1/;
    my $time = "$Hour:$Minute:$Second";
    my $date = "$Month:$Mday:$Year";
    print
      "$::Time_Date: RCSsTR40 -> Set date ($date), time ($time), and weekday ($Wday)\n"
      unless $main::config_parms{no_log} =~ /RCSsTR40/;
    $self->_send_cmd("TIME=$time DATE=$date DOW=$Wday");
}

sub _poll {
    my ($self)   = @_;
    my $instance = $self->{port_name};
    my $cmd      = "A=$self->{thermaddress} R=1 SC=?\r";
    $main::Serial_Ports{$instance}{object}->write($cmd);
    select( undef, undef, undef, 0.1 );

    # Indicate that we requested the coming status request
    $RCSsTR40_Data{ $$self{'port_name'} }{'send_count'}++;
}

=item C<auto_set_outside_temp()>

Pass in a scalar reference to this function and it
will automatically set the displayed outside temperature whenever the
scalar changes.  See above for an example.

=cut

sub auto_set_outside_temp {
    my ( $self, $temp_ref ) = @_;
    $$self{'auto_outside_temp_ref'}  = $temp_ref;
    $$self{'last_auto_outside_temp'} = 0;
}

sub _check_auto_outside_temp {
    my ($self) = @_;
    if ( ref $$self{'auto_outside_temp_ref'} ) {
        if ( ${ $$self{'auto_outside_temp_ref'} } !=
            $$self{'last_auto_outside_temp'} )
        {
            $$self{'last_auto_outside_temp'} =
              ${ $$self{'auto_outside_temp_ref'} };
            if ( $$self{'last_auto_outside_temp'} ) {
                $self->set_outside_temp( $$self{'last_auto_outside_temp'} );
            }
        }
    }
}

=item C<get_temp()>

Returns the current inside temperature.

=cut

sub get_temp() {
    my ($self) = @_;
    return $$self{'temp'};
}

=item C<get_outside_temp()>

Returns the current outside temperature.

=cut

sub get_outside_temp() {
    my ($self) = @_;
    return $$self{'outside_temp'};
}

=item C<get_heat_sp()>

Returns the current heat setpoint.

=cut

sub get_heat_sp() {
    my ($self) = @_;
    return $$self{'heat_sp'};
}

=item C<get_cool_sp()>

Returns the current cool setpoint.

=cut

sub get_cool_sp() {
    my ($self) = @_;
    return $$self{'cool_sp'};
}

=item C<get_mode()>

Returns the current mode (off, auto, heat, cool, emerg_heat)

=cut

sub get_mode() {
    my ($self) = @_;
    return $$self{'mode'};
}

=item C<get_fan_mode()>

Returns the current fan mode (fan_on or fan_auto)

=cut

sub get_fan_mode() {
    my ($self) = @_;
    return $$self{'fan_mode'};
}

=item C<get_schedule_mode()>

Returns the current schedule mode ('hold' or 'run').
Note that this will always return 'hold' if there is no schedule defined.

=cut

sub get_schedule_mode() {
    my ($self) = @_;
    return $$self{'schedule_mode'};
}

=item C<get_vacation_status()>

Returns either 'vacation' or 'no_vacation'.  Vacation
mode is (de)activated by pressing and holding the away button for 3 seconds.

=cut

sub get_vacation_status() {
    my ($self) = @_;
    return $$self{'vacation'};
}

=item C<set_heat_limits(min, max)>

Specify minimum and maximum heat setpoints

=cut

sub set_heat_limits($$) {
    my ( $self, $min, $max ) = @_;
    $$self{'heat_min_limit'} = $min;
    $$self{'heat_max_limit'} = $max;
}

=item C<set_cool_limits(min, max)>

Specify minimum and maximum cool setpoints

=cut

sub set_cool_limits($$) {
    my ( $self, $min, $max ) = @_;
    $$self{'cool_min_limit'} = $min;
    $$self{'cool_max_limit'} = $max;
}

sub _parse_data {
    my ( $self, $data ) = @_;
    return if ( ( $$self{'last_change'} + 5 ) > $main::Time );
    my ( $name, $val );
    $data =~ s/^\s*//;
    $data =~ s/\s*$//;
    print "RCSsTR40: Parsing serial data: $data\n"
      unless $main::config_parms{no_log} =~ /RCSsTR40/;
    my $vacation_sph = 0;
    my $vacation_spc = 0;
    my $last_sph;
    my $last_spc;

    while ( $data =~ s/^\s*(\S+)=(\S+)\s*// ) {
        $name = $1;
        $val  = $2;
        if ( $name eq 'A' ) {

            # Address code... ignore
        }
        elsif ( $name eq 'O' ) {

            # Ignoring the originator ID... since I only have one RS232 device
        }
        elsif ( $name eq 'Z' ) {

            # No current support for multi-zone systems...
        }
        elsif ( $name eq 'T' ) {
            if ( $$self{'temp'} and ( $$self{'temp'} != $val ) ) {
                $self->set_receive('temp_change');
            }
            $$self{'temp'} = $val;
            $self->_process_off_times();
            if ( $$self{'temp'} < $$self{'heat_sp'} ) {
                &::print_log(
                    "RCSsTR40: Temp $$self{temp} is less than $$self{heat_sp} (mode=$$self{mode})"
                );
                if (   ( $$self{'mode'} eq 'heat' )
                    or ( $$self{'mode'} eq 'auto' ) )
                {
                    &::print_log(
                        "RCSsTR40: heat_start=$$self{heat_start}, heat_end=$$self{heat_end}, mot=$$self{mot}"
                    );
                    if ( $$self{'heat_end'} > $::Time ) {

                        # It was scheduled to turn off, so cancel that
                        $$self{'heat_end'} = 0;
                    }
                    unless ( $$self{'heat_start'} ) {

                        # Assume heater is going to come on
                        if ( ( $$self{'heat_end'} + $$self{mot} ) < $::Time ) {

                            # Minimum-off-time already satisfied.
                            $$self{'heat_start'} = $::Time;
                        }
                        else {
                            # It will start in the future...
                            $$self{'heat_start'} =
                              ( $$self{'heat_end'} + $$self{mot} );
                        }
                        $$self{'heat_end'} = 0;
                    }
                }
            }
            if ( $$self{'temp'} > $$self{'cool_sp'} ) {
                if (   ( $$self{'mode'} eq 'cool' )
                    or ( $$self{'mode'} eq 'auto' ) )
                {
                    if ( $$self{'cool_end'} > $::Time ) {

                        # It was scheduled to turn off, so cancel that
                        $$self{'cool_end'} = 0;
                    }
                    unless ( $$self{'cool_start'} ) {

                        # Assume cooler is going to come on
                        if ( ( $$self{'cool_end'} + $$self{mot} ) < $::Time ) {

                            # Minimum-off-time already satisfied.
                            $$self{'cool_start'} = $::Time;
                        }
                        else {
                            # It will start in the future...
                            $$self{'cool_start'} =
                              ( $$self{'cool_end'} + $$self{mot} );
                        }
                        $$self{'cool_end'} = 0;
                    }
                }
            }
            if (    ( $$self{'temp'} >= $$self{'heat_sp'} )
                and ( ( $$self{'temp'} <= $$self{'cool_sp'} ) )
                or ( $$self{'mode'} eq 'off' ) )
            {
                if ( $$self{'heat_start'} ) {

                    # Done heating...
                    if ( $$self{'heat_start'} > $::Time ) {

                        # Was going to start, so cancel that...
                        $$self{'heat_end'} =
                          ( $$self{'heat_start'} - $$self{mot} );
                        $$self{'heat_start'} = 0;
                    }
                    elsif ( not $$self{'heat_end'} ) {

                        # Is running, schedule stop time
                        if ( ( $$self{'heat_start'} + $$self{mrt} ) > $::Time )
                        {
                            # Schedule future stop
                            $$self{'heat_end'} =
                              ( $$self{'heat_start'} + $$self{mrt} );
                        }
                        else {
                            # Stop now...
                            $$self{'heat_end'} = $::Time;
                        }
                    }
                }
                elsif ( $$self{'cool_start'} ) {

                    # Done cooling...
                    if ( $$self{'cool_start'} > $::Time ) {

                        # Was going to start, so cancel that...
                        $$self{'cool_end'} =
                          ( $$self{'cool_start'} - $$self{mot} );
                        $$self{'cool_start'} = 0;
                    }
                    elsif ( not $$self{'cool_end'} ) {

                        # Is running, schedule stop time
                        if ( ( $$self{'cool_start'} + $$self{mrt} ) > $::Time )
                        {
                            # Schedule future stop
                            $$self{'cool_end'} =
                              ( $$self{'cool_start'} + $$self{mrt} );
                        }
                        else {
                            # Stop now...
                            $$self{'cool_end'} = $::Time;
                        }
                    }
                }
                $self->_process_off_times();
            }
        }
        elsif ( $name eq 'OA' ) {
            if ( $$self{'outside_temp'} and ( $$self{'outside_temp'} != $val ) )
            {
                $self->set_receive('outside_temp_change');
            }
            $$self{'outside_temp'} = $val;
        }
        elsif ( $name eq 'SP' ) {

            # Ignore this deprecated feature as it is replaced by SPH & SPC
        }
        elsif ( $name eq 'SV10' ) {
            $val = int($val);
            &::print_log("Got Minimum Off Time from thermostat: $val minutes");
            $$self{'mot'} = ( $val * 60 );
        }
        elsif ( $name eq 'SV11' ) {
            $val = int($val);
            &::print_log("Got Minimum Run Time from thermostat: $val minutes");
            $$self{'mrt'} = ( $val * 60 );
        }
        elsif ( $name eq 'SC' ) {
            $val = ( $val == 0 ? 'hold' : 'run' );
            if ( $$self{'schedule_mode'}
                and ( $$self{'schedule_mode'} ne $val ) )
            {
                $self->set_receive($val);
            }
            $$self{'schedule_mode'} = $val;
        }
        elsif ( $name eq 'SPH' ) {
            print
              "Examining SPH: $val, $$self{heat_sp_pending}, $$self{heat_sp}, $$self{vacation}\n"
              unless $main::config_parms{no_log} =~ /RCSsTR40/;
            if ( $val == 66 ) {
                $vacation_sph = 1;
            }
            elsif ( $$self{'heat_sp'} == 66 ) {
                $vacation_sph = -1;
            }
            if ( $$self{'heat_sp_pending'} eq $val ) {
                $$self{'heat_sp_pending'} = 0;
                $vacation_sph = 0;
            }
            elsif ( $$self{'heat_sp'} and ( $$self{'heat_sp'} != $val ) ) {
                if ( $$self{'vacation'} eq 'vacation' ) {
                    $vacation_sph = -1;
                }
                unless ($vacation_sph) {
                    unless ( $$self{'heat_sp_pending'} ) {
                        $self->set_receive('heat_sp_change');
                    }
                }
            }
            $last_sph = $$self{'heat_sp'};
            $$self{'heat_sp'} = $val;
        }
        elsif ( $name eq 'SPC' ) {
            print
              "Examining SPC: $val, $$self{cool_sp_pending}, $$self{cool_sp}, $$self{vacation}\n"
              unless $main::config_parms{no_log} =~ /RCSsTR40/;
            if ( $val == 80 ) {
                $vacation_spc = 1;
            }
            elsif ( $$self{'cool_sp'} == 80 ) {
                $vacation_spc = -1;
            }
            if ( $$self{'cool_sp_pending'} eq $val ) {
                $$self{'cool_sp_pending'} = 0;
                $vacation_spc = 0;
            }
            elsif ( $$self{'cool_sp'} and ( $$self{'cool_sp'} != $val ) ) {
                if ( $$self{'vacation'} eq 'vacation' ) {
                    $vacation_spc = -1;
                }
                unless ($vacation_spc) {
                    unless ( $$self{'cool_sp_pending'} ) {
                        $self->set_receive('cool_sp_change');
                    }
                }
            }
            $last_spc = $$self{'cool_sp'};
            $$self{'cool_sp'} = $val;
        }
        elsif ( $name eq 'M' ) {
            if ( $val eq 'O' ) {
                $val = 'off';
            }
            elsif ( $val eq 'H' ) {
                $val = 'heat';
            }
            elsif ( $val eq 'C' ) {
                $val = 'cool';
            }
            elsif ( $val eq 'A' ) {
                $val = 'auto';
            }
            elsif ( $val eq 'EH' ) {
                $val = 'emerg_heat';
            }
            elsif ( $val eq 'I' ) {
                $val = 'invalid';
            }
            if ( $$self{'mode'} and ( $$self{'mode'} ne $val ) ) {
                $self->set_receive($val);
            }
            $$self{'mode'} = $val;
        }
        elsif ( $name eq 'FM' ) {
            $val = ( $val == 0 ? 'fan_auto' : 'fan_on' );
            if ( $$self{'fan_mode'} and ( $$self{'fan_mode'} ne $val ) ) {
                $self->set_receive($val);
            }
            $$self{'fan_mode'} = $val;
        }
    }
    if ( ( $vacation_spc == 1 ) and ( $vacation_sph == 1 ) ) {
        $self->set_receive('vacation');
        $$self{'vacation'} = 'vacation';
    }
    elsif ( ( $vacation_spc == -1 ) and ( $vacation_sph == -1 ) ) {
        $self->set_receive('no_vacation');
        $$self{'vacation'} = 'no_vacation';
    }
    elsif ($vacation_spc) {
        print "Vacation_SPC set, $last_spc, $$self{'cool_sp'}))";
        $self->set_receive('cool_sp_change')
          unless ( $last_spc and ( $last_spc == $$self{'cool_sp'} ) );
    }
    elsif ($vacation_sph) {
        print "Vacation_SPC set, $last_sph, $$self{'heat_sp'}))";
        $self->set_receive('heat_sp_change')
          unless ( $last_sph and ( $last_sph == $$self{'heat_sp'} ) );
    }
}

1;

=back

=head2 INI PARAMETERS

RCSsTR40_serial_port=/dev/ttyS4
RCSsTR40_baudrate=9600
RCSsTR40_address=1 to 255 (for mutiple thermostats on a 422 interface) May be omitted (or 1) if using RS232.

=head2 AUTHOR

Initial version created by Chris Witte <cwitte@xmlhq.com>
Expanded for TR40 by Kirk Bauer <kirk@kaybee.org>

=head2 SEE ALSO

NONE

=head2 LICENSE

This program is free software; you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation; either version 2 of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more details.

You should have received a copy of the GNU General Public License along with this program; if not, write to the Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.

=cut

