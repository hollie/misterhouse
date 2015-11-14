
=head1 B<Concept>

=head2 SYNOPSIS

NONE

=head2 DESCRIPTION

This is a Misterhouse module for handling input from the Concept alarm system made by Inner Range. Details on the alarm system can be found at www.innerrange.com.au  At the moment the model expects the alarm system to be connected to one of the serial ports on the computer. The computer, which looks like a printer to the alarm system, will scan the lines recieved looking for key strings and take the appropiate action if one is found.

The module will log everything recieved to; {data_dir}/logs/ConceptYYYY_MM.log  where YYYY is the year amd MM is the month

This module is based on the DSC_Alarm module writen by Danal Estes

  20020601 - Nick Maddock - Creation day
  20020609 - Nick Maddock - Tiedied up a lot of things
  20020609 - Nick Maddock - Put handling to occupied in
  20020609 - Nick Maddock - Put in change of logs every day

Still to do

  - Handler for over alarm things
  - Migrate to a better communication standard
  - Handling for alarm auxilaries
  - Activation, Deactivation (???) of the alarm system

=head2 INHERITS

B<Generic_Item>

=head2 METHODS

=over

=cut

use strict;

package Concept;

@Concept::ISA = ('Generic_Item');

my @Zone_Objects
  ;    # Holds a list of all the zone objects to try match the to inputs
my @timer_refs;    # Hold the object instances for when timers are operating
my $FirstCall =
  0;    # Used to indicate to the serial_startup, the first time it is called.

=item C<serial_startup> 

Create serial port(s) according to mh.ini  Register hooks if any ports created.

=cut

sub serial_startup {
    my $port  = $::config_parms{"Concept_serial_port"};
    my $speed = $::config_parms{"Concept_baudrate"};
    if ( &::serial_port_create( "Concept", $port, $speed, 'dtr' ) ) {
        init( $::Serial_Ports{"Concept"}{object} );
        ::print_log
          "\nConcept.pm initialzed Concept on hardware $port at $speed baud"
          if $main::Debug{concept};
    }

    if ( $FirstCall == 0 ) {    # Add hooks on first call only
        $FirstCall = 1;
        &::MainLoop_pre_add_hook( \&Concept::UserCodePreHook, 1 );
        &::MainLoop_post_add_hook( \&Concept::UserCodePostHook, 1 );
        $::Year_Month_Day =
          &::time_date_stamp( 18, time );    # Not yet set when we init.
        &::logit(
            "$::config_parms{data_dir}/logs/Concept.$::Year_Month_Day.log",
            "Concept.pm Initialized" );
        ::print_log "Concept.pm adding hooks" if $main::Debug{concept};
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
    $serial_port->rts_active(1);
    select( undef, undef, undef, .100 );    # Sleep a bit
}

sub UserCodePreHook {
    if ($::New_Day)    # Move the log file name if it's a new day
    {
        $::Year_Month_Day =
          &::time_date_stamp( 18, time );    # Not yet set when we init.
    }

    if ($::New_Msecond_100) {
        &::check_for_generic_serial_data('Concept')
          if $::Serial_Ports{Concept}{object};
        my $data = $::Serial_Ports{Concept}{data_record};
        if ($data) {

            # Sometimes the Alarm system returns short lines without any information,
            # If we get such a line, just discard it and return
            if ( length($data) < 4 ) {
                return;
            }

            # Hey, we got something, So we had best do the logging bit
            &::logit(
                "$::config_parms{data_dir}/logs/Concept.$::Year_Month_Day.log",
                "$data"
            );
            ::print_log "Concept.pm, Recieved data = $data, $::Loop_Count"
              if $main::Debug{concept};

            # Is it a Zone Alarm?
            if ( substr( $data, 22, 9 ) eq "Alarm on " ) {

                # Get the zone name
                my $zone_name = substr( $data, 31 );
                ::print_log "Concept.pm, Alarm on Zone = $zone_name"
                  if $main::Debug{concept};

                # See if we have an object for it
                my @objects = @Zone_Objects;
                my $self    = pop @objects;
                my $found   = 0;
                while ( $self && $found == 0 ) {
                    if ( $self->zone_name eq $zone_name ) {
                        $found = 1;
                    }
                    else {
                        $self = pop @objects;
                    }
                }
                if ( $found == 1 ) {
                    $self->alarm;

                }
                else {
                    ::print_log "Concept.pm, No handler for zone:$zone_name";
                }
            }
            elsif (
                substr( $data, 22, 11 ) eq
                "Restore on " )    # Is it a Zone Restore?
            {
                # Get the zone name
                my $zone_name = substr( $data, 33 );
                ::print_log "Concept.pm, Restoring on Zone = $zone_name"
                  if $main::Debug{concept};

                # See if we have an object for it
                my @objects = @Zone_Objects;
                my $self    = pop @objects;
                my $found   = 0;
                while ( $self && $found == 0 ) {
                    if ( $self->zone_name eq $zone_name ) {
                        $found = 1;
                    }
                    else {
                        $self = pop @objects;
                    }
                }
                if ( $found == 1 ) {
                    $self->restore;

                }
                else {
                    ::print_log "Concept.pm, No handler for Zone:$zone_name";
                }
            }
            else    # We seem to have an unknown inpu
            {
                ::print_log "Concept.pm, Recieved an unknow line = $data";
            }
        }
    }
}

sub UserCodePostHook {
    #
    # Reset data for said function
    #
    $::Serial_Ports{Concept}{data_record} = '';
}

#
# End of system functions; start of functions called by user scripts.
#

=back

=head2 INI PARAMETERS

  Concept_serial_port = COMx    # The serial port alarm system is on
                      = /dev/sttyx
  Concept_baudrate = [1200, 4800, 9600]   # The baudrate of the port
  debug = Concept    # Will turn dbuging information on if present

=head2 AUTHOR

UNK

=head2 SEE ALSO

NONE

=head2 LICENSE

This program is free software; you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation; either version 2 of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more details.

You should have received a copy of the GNU General Public License along with this program; if not, write to the Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.
















=head1 B<ConceptZone>

=head2 SYNOPSIS

NONE

=head2 DESCRIPTION

NONE

=head2 INHERITS

B<Concept>

=head2 METHODS

=over

=cut

package ConceptZone;

@ConceptiZone::ISA = ('Concept');

=item C<new>

Cretes a new object of one of the alarm types. Takes:

  Class - The object class, well it's automatamiatically passed
  Zone Name - The zone name associated with this object
  Idle Timer - The amount of time the object should be restored for
               before it is considered to be restored, this is for
               occupancy on the motion sensors

=cut

sub new {
    my ( $class, $zone_name, $idle_timer ) = @_;
    my $self;

    if ( !defined($idle_timer) ) {
        $idle_timer = 0;
    }
    $self = {
        name        => $zone_name,
        idle_time   => $idle_timer,
        state       => 0,
        occupied    => 0,
        said        => '',
        timer       => new Timer,
        timer_index => scalar(@timer_refs),
    };
    bless( $self, $class );
    $self->{timer}->unset;
    $timer_refs[ $self->{timer_index} ] =
      $self;    # ugly code to handle the ocuppied timer
    push @Zone_Objects, $self;

    return $self;
}

=item C<zone_name>

Returns the Zone Name that the object is interested in this routine is used by the parent object so that it can find the correct instance when it recieves and alarm or restore

=cut

sub zone_name {
    my $self = shift();
    return $self->{name};
}

=item C<alarm>

Called by the parrent function when an alarm is recieved for this object.  This function should change the state to alarmed and stop the timer if it is running

=cut

sub alarm {
    my $self = shift();
    $self->{state}    = 1;
    $self->{occupied} = 1;
    $self->{timer}->unset;
    return;
}

=item C<restore>

Called by the parent object when a restore is recieved for this input, This should change the state to not alarmed and start a timer to clear the occupied flag

=cut

sub restore {
    my $self  = shift();
    my $index = 1;
    $self->{state} = 0;
    if ( $self->{idle_time} == 0 ) {
        $self->{occupied} = 0;
    }
    else {
        # Unfortunalty I could pass the objects instance to the Timer object,
        # so I store the instance in an array and pass the index to the array
        # element to the timer function.

        $self->{timer}->set( $self->{idle_time},
            "&ConceptZone::timer_expired( $self->{ timer_index } )" );
    }

    return;
}

=item C<timer_expired>

This routine is run when the timer expires it rests the occupied flag to indicate that the room isn't occupied any longer

=cut

sub timer_expired {

    my $index = shift();
    my $self  = $timer_refs[$index];

    $self->{timer}->unset;
    $self->{occupied} = 0;

    return;
}

=item C<state>

returns the current state of the zone object

=cut

sub state {
    my $self = shift();
    return $self->{state};
}

=item C<occupied>

returns the current occupied state of the zone

=cut

sub occupied {
    my $self = shift();
    return $self->{occupied};
}

############################
## Old functions we inherited from copying DSV_Alarms
#############################

sub said {
    return $main::Serial_Ports{Concept}{data_record};
}

1;

=back

=head2 INI PARAMETERS

NONE

=head2 AUTHOR

UNK

=head2 SEE ALSO

NONE

=head2 LICENSE

This program is free software; you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation; either version 2 of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more details.

You should have received a copy of the GNU General Public License along with this program; if not, write to the Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.

=cut

