
=head1 B<SysDiag_xAP>

=head2 SYNOPSIS

If declaring via .mht:

  SDX,  psixc_instance,   sdx_object_name,        psixc_server

Where 'psixc_instance' is the xap instance name, psixc_server is the monitored server, and
'sdx_object_name' is the Misterhouse object

  # declare the psixc "conduit" object
  $server1 = new SysDiag_xAP(instance, servername);

  # create one or more AnalogSensor_Items that will be attached to the SysDiag_xAP
  # See additional comments in AnalogSensor_Items for .mht based declaration

  $server1_eth0 = new AnalogSensor_Item('loadavg1', 'cpu');
  # 'loadavg1' is the attribute name, 'cpu' is the sensor type
  $server1_hda1 = new AnalogSensor_Item('hda1.free', 'disk');
  # 'hda1.free' is the attribute name, and sub-attribute value, 'disk' is the sensor type

  # Now add these to the SysDiag_xAP object
  $server1->add($server1_eth0, $server1_hda1);

  # Another useful function is get_diag. This returns the xAP value without creating
  # an AnalogSensor_Item object

  $server1->get_diag('disk.hda1.size');

Information on using AnalogSensor_Items is contained within its
corresponding package documentation

=head2 DESCRIPTION

This package provides an interface to PhpSysInfo xml source via the xAP
(www.xapautomation.org) "connector": psixc

Documentation on installing/configuring psixc is found in the psixc distribution.
(Note: psixc currently relies on phpsysinfo (phpsysinfo.sourceforge.net).

The xAP message convention assumes that the phpsysinfo xAP connector, psixc,
is addressed via the target: hpgl.psixc.house

Each "device" is subaddressed using the convention: :<type>.<item> where
<type> can be cpu, memory, network, disk and <item> is an attribute within that
item type (ie. eth0.rx hda1.used_percent)

=head2 INHERITS

B<Base_Item>

=head2 METHODS

=over

=item B<UnDoc>

=cut

use strict;

package SysDiag_xAP;
@SysDiag_xAP::ISA = ('Base_Item');

sub new {

    my ( $class, $instance, $server ) = @_;
    my $self = {};
    bless $self, $class;

    $$self{source_map} = {};
    $$self{instance}   = $instance;
    $$self{instance}   = "house" unless ( defined $instance );
    $$self{server}     = $server;
    my $xap_address = "hpgl.psixc.$instance";
    if ( $instance =~ /^\S*\.\S*/ ) {
        $xap_address = $instance;
    }
    $xap_address = $xap_address . ":" . lc $server;
    my $xap_item = new xAP_Item( 'sysdiag.*', $xap_address );
    print "Adding xAP_Item to SysDiag_xAP instance with address: $xap_address\n"
      if $::Debug{sysdiag};
    my $friendly_name = "xap_sysdiag_$instance" . "_$server";
    &main::store_object_data( $xap_item, 'xAP_Item', $friendly_name,
        $friendly_name );
    $$self{xap_item} = $xap_item;

    # now tie our only xAP item to our self
    $$self{xap_item}->tie_items($self);
    return $self;
}

sub add {
    my ( $self, @monitors ) = @_;
    if (@monitors) {
        for my $monitor (@monitors) {
            if ( $monitor->isa('AnalogSensor_Item') ) {
                my $key = $monitor->type . "." . $monitor->id;
                print "[SysDiag] Adding monitor: $key to "
                  . "sysdiag: $$self{instance}\n"
                  if $main::Debug{sysdiag};
                $$self{m_monitors}{$key} = $monitor;
                $self->SUPER::add($monitor)
                  ;    # add it so that it can set this object
            }
        }
    }
}

sub set {

    my ( $self, $p_state, $p_setby, $p_response ) = @_;
    if ( $$self{xap_item} eq $p_setby ) {
        for my $section_name ( keys %{ $$self{xap_item} } ) {
            if (   ( $section_name =~ /^cpu/i )
                or ( $section_name =~ /memory/i )
                or ( $section_name =~ /swap/i )
                or ( $section_name =~ /disk/i )
                or ( $section_name =~ /temp/i )
                or ( $section_name =~ /network/i ) )
            {
                $self->_process_section($section_name);
            }
        }
    }
}

sub _process_section {
    my ( $self, $section_name ) = @_;
    my $section = $$self{xap_item}{$section_name};
    for my $subsection_name ( keys %{$section} ) {
        print "[SysDiag] Processing $section_name.$subsection_name: "
          . $section->{$subsection_name} . ":"
          if $main::Debug{sysdiag};

        # now, copy it
        $$self{diag}{$section_name}{$subsection_name} =
          $$section{$subsection_name};

        # locate the corresponding device if it exists
        # the naming convention must use a period as the delimitter
        if (
            exists(
                $$self{m_monitors}{ $section_name . "." . $subsection_name }
            )
          )
        {
            my $monitor =
              $$self{m_monitors}{ $section_name . "." . $subsection_name };
            print "Exists $$section{$subsection_name} "
              if $main::Debug{sysdiag};
            $monitor->measurement( $$section{$subsection_name} );
        }
        print "\n" if $main::Debug{sysdiag};
    }
}

sub get_diag {

    my ( $self, $address ) = @_;
    my $return = 0;
    my ( $device, $attribute ) = $address =~ /^(.*)\.(.*)/;

    #	for my $test (keys %{$$self{diag}}) {
    #		print "[SysDiag:get_diag] $device, $attribute, $test, " . $$self{diag}{$device}{$attribute} . "\n";
    #	}

    if ( exists( $$self{diag}{$device}{$attribute} ) ) {

        $return = $$self{diag}{$device}{$attribute};

    }

    print "[SysDiag:get_diag] $device, $attribute, $return \n"
      if $main::Debug{sysdiag};

    return $return;
}

1;

=back

=head2 INI PARAMETERS

NONE

=head2 AUTHOR

Gregg Liming / Howard Plato  gregg@limings.net hplato@gmail.com

=head2 SEE ALSO

NONE

=head2 LICENSE

This program is free software; you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation; either version 2 of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more details.

You should have received a copy of the GNU General Public License along with this program; if not, write to the Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.

=cut

