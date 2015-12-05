
=head1 B<OneWire_xAP>

=head2 SYNOPSIS

Documentation on installing/configuring oxc is found in the oxc distribution.
oxc now uses digitemp (www.digitemp.com) or one-wire file system
(owfs; see - www.owfs.org).

The xAP message convention assumes that the one-wire xAP connector, oxc,
is addressed via the target: liming.oxc.house

Each "device" is subaddressed using the convention: :<type>.<name> where
<type> can be temp, humid, etc and <name> is a user-definable name
specfified in the oxc config.

Declaration:

If declaring via .mht:

  OWX,  liming.oxc.house,   house_owx

Where 'liming.oxc.house' is the xAP source address and 'house_owx' is the object

  # declare the oxc "conduit" object
  $oxc = new OneWire_xAP;

  # create one or more AnalogSensor_Items that will be attached to the OneWire_xAP
  # See additional comments in AnalogSensor_Items for .mht based declaration

  $indoor_temp = new AnalogSensor_Item('indoor-t', 'temp');
  # 'indoor-t' is the device name, 'temp' is the sensor type
  $indoor_humid = new AnalogSensor_Item('indoor-h', 'humid');

  $ocx->add($indoor_temp, $indoor_humid);

Information on using AnalogSensor_Items is contained within its
corresponding package documentation

=head2 DESCRIPTION

This package provides an interface to one-wire devices via the xAP
(www.xapautomation.org) "connector": oxc (www.limings.net/xap/oxc)

=head2 INHERITS

B<Base_Item>

=head2 METHODS

=over

=item B<UnDoc>

=cut

use strict;

package OneWire_xAP;
@OneWire_xAP::ISA = ('Base_Item');

use BSC;
use AnalogSensor_Item;

sub new {

    my ( $class, $xap_base_address ) = @_;
    my $self = {};
    bless $self, $class;

    $$self{source_map} = {};
    @{ $$self{m_devices} } = ();
    if ($xap_base_address) {
        $$self{m_base_address} = $xap_base_address;
    }
    else {
        $$self{m_base_address} = '';
    }
    return $self;
}

sub add {

    my ( $self, @devices ) = @_;
    foreach my $device (@devices) {
        unless ( $self->is_member_device($device) ) {
            push @{ $$self{m_devices} }, $device;
            my $xap_address = $$self{m_base_address};
            my $is_oxc      = 1;
            if ($xap_address) {
                if ( $xap_address !~ /^\S+\.\S+/ ) {
                    $xap_address = "liming.oxc.$xap_address";
                }
                elsif ( $xap_address !~ /^liming\.oxc\.\S+/i ) {
                    $is_oxc = 0;
                }
            }
            else {
                $xap_address = "liming.oxc.house";
            }
            if ( $is_oxc and $device->id !~ /^\S*\.\S*/ ) {
                $xap_address =
                  $xap_address . ':' . lc $device->type . "." . $device->id;
            }
            else {
                $xap_address = $xap_address . ':' . $device->id;
            }
            print
              "Adding BSC_Item to a OneWire_xAP instance with address: $xap_address\n"
              if $::Debug{onewire};
            my $xap_item = new BSC_Item($xap_address);
            $xap_item->always_set_state(1)
              ;    # needed so that we always update from info or event messages
            $$self{source_map}{$xap_item} = $device;
            $self->SUPER::add_item_if_not_present($xap_item)
              ;    # add it so that it can set this obejct
            $xap_item->query();
        }
    }
}

sub is_member_device {
    my ( $self, $device ) = @_;
    my @devices = @{ $$self{m_devices} };
    for my $ref_device (@devices) {
        if ( $ref_device eq $device ) {
            return 1;
        }
    }
    return 0;
}

sub set {

    my ( $self, $p_state, $p_setby, $p_response ) = @_;

    for my $source ( $self->find_members('BSC_Item') ) {
        if ( $source eq $p_setby ) {
            print "text=" . $source->text . " level=" . $source->level . "\n"
              if $::Debug{onewire};
            my $device = $$self{source_map}{$source};

            # TO-DO: support other sensors types than just humid and temp
            if ( $device->type eq 'humid' ) {

                # parse the data from the level member stripping % char
                if ( $source->level ) {
                    if ( $source->level =~ /\d+\/\d+/ ) {
                        my ( $humid1, $range ) =
                          $source->level =~ /^(\d+\.?\d*)\/(\d+)/;
                        $device->measurement( 100 * ( $humid1 / $range ) )
                          if ( defined($humid1) and ($range) );
                    }
                    else {
                        my ( $humid, $humid_scale ) =
                          $source->level =~ /^(-?\d*\.?\d*)\s*(\S*)/;
                        $device->measurement($humid) if defined($humid);
                    }
                }
                elsif ( $source->text ) {
                    my ( $humid, $humid_scale ) =
                      $source->text =~ /^(-?\d*\.?\d*)\s*(\S*)/;
                    $device->measurement($humid) if defined($humid);
                }
            }
            elsif ( $device->type eq 'temp' ) {

                # parse the data from the text member using the last char for scale
                # TO-DO: perform conversion if temp_scale is not what device wants
                my ( $temp, $temp_scale ) =
                  $source->text =~ /^(-?\d*\.?\d*)\s*(\S*)/;
                $device->measurement($temp) if defined($temp);
            }
            elsif ( $device->type eq 'solar' ) {
                my $solar = $source->level;
                $device->measurement($solar) if defined($solar);
            }
            last;    # we're done as only one setby
        }
    }
}

1;

=back

=head2 INI PARAMETERS

NONE

=head2 AUTHOR

Gregg Liming  gregg@limings.net

=head2 SEE ALSO

NONE

=head2 LICENSE

This program is free software; you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation; either version 2 of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more details.

You should have received a copy of the GNU General Public License along with this program; if not, write to the Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.

=cut

