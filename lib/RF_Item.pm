
=head1 B<RF_Item>

=head2 SYNOPSIS

RF items can be created in the items.mht in the following manner:

  RF,     68,     keychain_remote,                Security
  RF,     System, security_system,                Security
  RF,     Sensor, security_sensors,               Security
  RF,     81,     door_sensor,                    Security
  RF,     Remote, tv_remote,                      TV

RF Items can be manually created in the following manner:

  $keychain_remote  = new RF_Item('68'    , 'keychain_remote' );
  $security_system  = new RF_Item('system', 'security_system' );
  $security_sensors = new RF_Item('sensor', 'security_sensors');
  $door_sensor      = new RF_Item('81'    , 'door_sensor'     );
  $tv_remote        = new RF_Item('remote', 'tv_remote'       );

The 2nd column the items.mht file (or the 1st parameter when manually creating a new RF_Item) is the 2 digit hexadecimal unit id of the particular transmitter or one of the following classes:

system - Any device that change the state of the security system.  States from any transmitters that go into this class are: armawaymin, armawaymax, armhomemin, armhomemax, disarm, panic

sensor - Any device that changes a sensor state.  States from any transmitters that go into this class are: normal, normalmax, normalmin, alert, alertmin, alertmax

control - Any device that changes some general feature.  States from any transmitter that go into this class are: lightson, lightsoff

remote - Any TV style remote control (UR51A, etc.).  States from any transmitter that go into this class are: Power PC Title Display Enter Return Up Down Left Right Menu Exit Rew Play FF Record Stop Pause Recall 0 1 2 3 4 5 6 7 8 9 AB Ch+ Ch- Vol- Vol+ Mute

Some transmitters have a min and max switch that cause the transmitter to send different states depending on that switch. If you don't care about the full detail of the state, you can do a test like:

  if (my $state = state_now $door_sensor =~ /^alert/) { ... }

To determine what the 2 digit hexadecimal unit id for a particular security transmetter is, press the button on the transmitter (or open/close the sensor) and look at the misterhouse log to find the id that the unit transmitted.

=head2 DESCRIPTION

An RF_item is created to receive states from X10 security devices and RF TV style remote through a W800RF32 module or an MR26A module (the MR26A only passes TV remote style data through, it does not pass security data).

To configure the W800 or MR26 interfaces, see the comments at the top of mh/lib/X10_MR26.pm and mh/lib/X10_W800.pm.

=head2 INHERITS

B<Generic_Item>

=head2 METHODS

=over

=item B<UnDoc>

=cut

use strict;

package RF_Item;

@RF_Item::ISA = ('Generic_Item');

sub new {
    my ( $class, $id, $name, $type ) = @_;
    my $self = &Generic_Item::new('Generic_Item');

    $$self{state} = '';
    bless $self, $class;

    $id = lc $id;

    $name = $id unless $name;
    $self->{name} = $name;

    &::print_log("RF_Item::new($id, $name, $type)") if $main::Debug{rf};

    $self->{rf_id} = $id;

    # Must be a 2 or 4 digit hex unit id or a one of our predefined classes (from
    # X10_RF.pm).
    if (
            $id !~ /^[0-9a-f]{2}$/
        and $id !~ /^[0-9a-f]{4}$/    # CJB
        and $id ne 'sensor'
        and $id ne 'system'
        and $id ne 'control'
        and $id ne 'remote'
      )
    {

        &::print_log("RF_Item::new: invalid RF device id \"$id\"");
    }

    return $self;
}

#
# $Log: RF_Item.pm,v $
# Revision 1.3  2004/02/01 19:24:35  winter
#  - 2.87 release
#
#

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

