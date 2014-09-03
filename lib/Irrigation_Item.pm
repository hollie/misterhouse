
=head1 NAME

B<Irrigation_Item>

=head1 SYNOPSIS

Example initialization:

These are to be placed in a *.mht file in your user code directory.

First, define your actual irrigation object:

  UPB_Rain8, irrigation_controller1, 13, 1

Then, define the Irrigation_Item(s) and attach the real object:

  IRRIGATION, irrigation_controller1, morning_irrigation
  IRRIGATION, irrigation_controller1, evening_irrigation

=head1 DESCRIPTION

Irrigation Cycle controller - This is an attempt to abstract irrigation control features from the hardware specific device driver.   This driver can cycle through specific zones with specified time delays (much like a generic sprinkler controller found on an existing system)  This driver has been tested to work with the UPB_Rain8 driver, but should work with any other device object that can turn on/off its zones using the MH support substate syntax ( ->set(on:4);)

=head1 INHERITS

B<>

=head1 METHODS

=over

=item C<set(state)>

Start / Stop full irrigation cycle

  state[on/off] = Start/Stop full irrigation cycle

=item C<zone_single(zone,state,time)>

Start / Stop single zone

  zone[x] = Single zone to activate/deactivate
  state[on/off] = Start / Stop single zone
  time[x] = Time in seconds for the zone to run

=item C<zone_activate(zone,activated)>

Set zone activation part of the cycle

  zone[x] = Zone to set activate/de-activated
  activated[1/0] = Set / unset active zone in full cycle

=item C<zone_time(zone,time)>

Set zone cycle time

  zone[x] = Zone to set cycle time
  time[x] = Time in seconds for the zone to run part of the cycle

=item C<zone_count(zones)>

Set total zones

  zones[x] = Number of zones as a part of the system (default 8)

=item C<zone_hammer(time)>

Set anti-water hammer time (seconds)

  time[x] = Time in seconds for overlaping zones

=item C<running()>

Returns (1/0) system running

=item C<zone_current()>

Returns [1/0] current zone running

=cut

use strict;
use Base_Item;

package Irrigation_Item;

@Irrigation_Item::ISA = ('Base_Item');

sub initialize {
    my ($self) = @_;

    $$self{m_write}           = 1;
    $$self{m_timerCycle}      = new Timer();
    $$self{m_zoneCurrent}     = 0;
    $$self{m_zoneHammer}      = 0;
    $$self{m_zoneHammerTime}  = 0;
    $$self{m_zoneHammerTimer} = new Timer();
    $$self{m_zoneMaximum} =
      1 * 60 * 60;    #if no time is specified this is the failsafe time
    $$self{m_ETData}[12];
    $self->zone_count(8);    #default 8 zones
}

sub set {
    my ( $self, $p_state, $p_setby, $p_respond ) = @_;

    my $l_final_state = undef;

    #	&::print_log("Irrigation Set:". $p_state . ":" . $p_setby);
    #Timer is up
    if ( $p_setby eq $$self{m_timerCycle} ) {    ### Timer calling us back
        if ( $self->single() ne 1 and $self->zone_current() ne 0 ) {
            $self->cascade();
            $l_final_state = 'zone_change';
        }
        elsif ( $self->single() eq 1 ) {
            $self->zone( $self->zone_current(), 'off' );
            $self->single(0);
            $self->zone_current(0);
            $l_final_state = 'off';
            &::print_log("Irrigation Single Stopped");
        }
        else {
            $l_final_state = 'off';
            &::print_log("Irrigation Cycle Stopped");
        }

        #Water hammer timer expiration
    }
    elsif ( $p_setby eq $$self{m_zoneHammerTimer} ) {
        $self->zone( $$self{m_zoneHammer}, 'off' );

        # Turned us on for start of cycle
    }
    elsif ( lc($p_state) eq 'on' ) {
        $self->cascade();
        $l_final_state = 'on';

        # Turned off (end cycle)
    }
    elsif ( lc($p_state) eq 'off' ) {
        $$self{m_timerCycle}->set('off');
        $self->zone( $self->zone_current(), 'off' );
        $self->zone_current(0);
        $l_final_state = 'off';
    }

    #	$self->SUPER::set($l_final_state,$p_setby,$p_respond) if defined $l_final_state;
    #			$self->SUPER::set($l_final_state,$self,$p_respond);
}

sub cascade {
    my ($self) = @_;

    if (    $self->zone_hammer() > 0
        and $self->zone_current() ne 0 )
    {    #If there is a specified anti-hammer time
            #Start a zone hammer timer to delay the off command
        $$self{m_zoneHammer} = $self->zone_current();
        $$self{m_zoneHammerTimer}->set( $self->zone_hammer(), $self );
    }
    else {    # No hammer protection on, just turn off
        $self->zone( $self->zone_current(), 'off' )
          if $self->zone_current() ne 0;
    }
    my $next_zone = $self->zone_next();
    if ( $next_zone ne 0 )    #go to next zone if there is one
    {
        #		&::print_log("Irrigation_Cascade". $next_zone . ":");
        $self->zone( $next_zone, 'on', $self->zone_time($next_zone) );
    }
    else {                    #No More zones left

        #		$$self{m_timerCycle}->set('off'); #re-dundant
        $self->zone_current(0);
        &::print_log("Irrigation Cycle Stopped");
    }
}

sub zone_next {
    my ( $self, $p_current ) = @_;
    $p_current = $self->zone_current() if not defined $p_current;

    for ( my $index = $p_current + 1; $index < $self->zone_count(); $index++ ) {
        if ( $self->zone_active($index) eq 1 ) {
            return $index;
        }
    }
    return 0;
}

sub zone_previous {
    my ( $self, $p_current ) = @_;
    $p_current = $self->zone_current() if not defined $p_current;

    #start at one index lower
    $p_current = $p_current - 1 if ( $p_current > 0 );
    for ( my $index = $p_current; $index >= 0; $index-- ) {
        if ( $self->zone_active($index) eq 1 ) {
            return $index;
        }
    }
    return 0;
}

sub zone_active {
    my ( $self, $p_zone, $p_blnActive ) = @_;

    #	&::print_log("here1:$p_zone,$p_blnActive");
    $$self{m_zoneActive}[ $p_zone - 1 ] = $p_blnActive if defined $p_blnActive;
    return $$self{m_zoneActive}[ $p_zone - 1 ];
}

sub zone_time {
    my ( $self, $p_zone, $p_time ) = @_;

    #	&::print_log("zonetime:$self:$p_zone,$p_time");
    $$self{m_zoneTime}[ $p_zone - 1 ] = $p_time if defined $p_time;
    return $$self{m_zoneTime}[ $p_zone - 1 ];
}

sub zone_hammer {
    my ( $self, $p_time ) = @_;
    $$self{m_zoneHammerTime} = $p_time if defined $p_time;
    return $$self{m_zoneHammerTime};
}

sub zone_single {
    my ( $self, $p_zone, $p_time ) = @_;
    $self->single(1);
    $self->zone( $p_zone, $p_time );
    return 1;
}

sub zone_count {
    my ( $self, $p_count ) = @_;

    #	&::print_log("IRR:Count:$p_count");
    if ( defined $p_count ) {
        $$self{m_zoneCount} = $p_count;
        for ( my $index = 1; $index <= $p_count; $index++ ) {
            $self->zone_active( $index, 1 );    #default all zones active
            $self->zone_time( $index, 10 * 60 );    #default 10 minutes

            #			$$self{m_zoneActive}[$index] = 1; #default all zone active
            #			$$self{m_zoneTime}[$index] = 30; #default 10 minutes
        }

    }
    return $$self{m_zoneCount};
}

sub running {
    my ( $self, $p_blnState ) = @_;

    #	$$self{m_isRunning} = $p_blnState if defined $p_blnState;
    #	return $$self{m_isRunning};
    if ( $self->zone_current() ne 0 ) {
        return 1;
    }
    else {
        return 0;
    }
}

sub zone_current {
    my ( $self, $p_zone ) = @_;
    $$self{m_zoneCurrent} = $p_zone if defined $p_zone;
    return $$self{m_zoneCurrent};
}

sub zone {
    my ( $self, $p_zone, $p_state, $p_time ) = @_;

    #turn on or off zone
    if ( lc($p_state) eq 'on' ) {
        &::print_log("Irrigation Zone:$p_zone:On:");
        $self->zone_current($p_zone);
        $self->SUPER::set( 'on:' . $p_zone );
    }
    else {
        &::print_log("Irrigiation Zone:$p_zone:Off:");
        $self->SUPER::set( 'off:' . $p_zone );
        if ( $self->single() eq 1 ) { #if single shot mode, shut everything down
            $self->zone_current(0);
            $$self{m_timerCycle}->set('off');
        }
        else {                        # if normal cycle mode, skip this zone
            if (    $self->zone_current() eq $p_zone
                and $$self{m_timerCycle}->active() eq 1 )
            {
                $$self{m_timerCycle}->set( 1, $self );
            }
        }
    }

    #set time limit
    #		&::print_log("Irr:Timer:" , $p_time);
    if ( defined $p_time ) {
        $$self{m_timerCycle}->set( $p_time, $self );
    }
    elsif ( lc($p_state) eq 'on' ) {
        $$self{m_timerCycle}->set( 1 * 60 * 60, $self );  #Failsafe 1 hour limit
    }

}

sub single {
    my ( $self, $p_blnSingle ) = @_;
    $$self{m_modeSingle} = $p_blnSingle if defined $p_blnSingle;
    return $$self{m_modeSingle};
}

1;

=back

=head1 INI PARAMETERS

NONE

=head1 AUTHOR

Jason Sharpee  - jason@sharpee.com

=head1 SEE ALSO

NONE

=head1 LICENSE

This program is free software; you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation; either version 2 of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more details.

You should have received a copy of the GNU General Public License along with this program; if not, write to the Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.

=cut

