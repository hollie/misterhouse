# $Date$
# $Revision$

use strict;
use warnings;

package X10_Interface;

use Device_Item;

our @supported_interfaces = ();

my @X10_Interface_Names = qw!cm11 bx24 homevision homebase stargate houselinc
  marrick ncpuxa cm17 lynx10plc weeder wish w800 ti103 ncpuxa!;

@X10_Interface::ISA = ('Device_Item');

sub new {
    my ( $class, $id, $state, $device_name ) = @_;

    my $self = Device_Item->new( $id, $state, $device_name );
    bless( $self, $class );
    return $self;
}

sub check_for_x10_interface {
    my ($self) = @_;

    return if not defined $self->{interface};

    if (
        grep ( { lc( $self->{interface} ) eq lc($_); } @X10_Interface_Names ) >
        0 )
    {
        my $interface = $self->{interface};
        $self->{X10Interface} = 1;
    }
}

sub processData {
    my ( $self, $data ) = @_;

    #print "self is $self\n";
    #print "processData interface is ".$self->{interface}."\n";
    #print "processData device_name is ".$self->{device_name}."\n";
    #print "processData X10Interface is ".$self->{X10Interface}."\n";

    # if we aren't an X10 Interface, just do a raw write of the data
    if ( !$self->{X10Interface} ) {
        $self->write_data($data);
        return;
    }

    # ensure data is in uppercase
    $data = uc($data);

    my $interface = $self->{interface};

    if ( $data =~ /(\d+)%/ ) {
        $data = '&P' . int( $1 * 63 / 100 + 0.5 );
    }

    # Make sure that &P codes have the house_unit code prefixed
    #  - e.g. device A1 -> A&P1

    if ( $data =~ /&P/ ) {
        $data = substr( $self->{x10_id}, 1, 1 ) . $data;
    }

    # If code is &P##, prefix with item code.
    #  - e.g. A&P1 -> A1A&P1
    if ( substr( $data, 1, 1 ) eq '&' ) {
        $data = $self->{x10_id} . $data;
    }

    # Make sure that +-\d codes have the house_unit code prefixed
    #  - e.g. device +12 -> A1A+12
    # Also round of to the nearest 5
    if ( $data =~ /^X?[\+\-]?\d+$/ ) {
        $data = $self->{x10_id} . substr( $self->{x10_id}, 1, 1 ) . $data;
    }
    &main::print_log("X10: Outgoing data=$data")
      if $main::config_parms{x10_errata} >= 4;

    # Allow for long strings like this: XAGAGAGAG (e.g. SmartLinc control)
    #  - break it into individual codes (XAG  XAG  XAG)
    $data =~ s/^X//;
    my $chunk;

    while ($data) {
        if (
               $data =~ /^([A-P]STATUS_OFF)(\S*)/
            or $data =~ /^([A-P]STATUS_ON)(\S*)/
            or $data =~ /^([A-P]STATUS)(\S*)/
            or $data =~ /^([A-P]ALL_LIGHTS_OFF)(\S*)/
            or $data =~ /^([A-P]EXTENDED_CODE)(\S*)/
            or $data =~ /^([A-P]EXTENDED_DATA)(\S*)/
            or $data =~ /^([A-P]HAIL_REQUEST)(\S*)/
            or $data =~ /^([A-P]HAIL_ACK)(\S*)/
            or $data =~ /^([A-P]PRESET_DIM1)(\S*)/
            or $data =~ /^([A-P]PRESET_DIM2)(\S*)/
            or $data =~ /^([A-P][1][0-6])(\S*)/
            or $data =~ /^([A-P][1-9A-W])(\S*)/
            or $data =~ /^([A-P]\&P\d+)(\S*)/
            or    # extended direct dim cmd
            $data =~ /^([A-P]Z\S*)/
            or    # Extended Code cmd with arbitrary extended bytes
            $data =~ /^([A-P]\d+\%)(\S*)/ or   # these are converted to &P above
            $data =~ /^([A-P][\+\-]?\d+)(\S*)/
          )
        {
            $chunk = $1;
            $data  = $2;

            # Allow for unit=9,10,11..16, instead of 9,A,B,C..F
            $chunk = $1 . substr 'ABCDEFG', $2, 1 if $chunk =~ /^(\S)1(\d)$/;

            $self->send_x10_data( $interface, 'X' . $chunk, $self->{type} );

            &send_x10_data_hooks($chunk);      # Created by &add_hooks

        }
        else {
            print "X10_Interface error, X10 string not parsed: $data.\n";
            return;
        }
    }    # while looking for chunks
}

# Note: this method is overriden by Serial_Item::send_x10_data
sub send_x10_data {
    my ( $self, $interface, $data, $module_type ) = @_;

    $self->write_data($data);
}

# Avoid sending the same X10 code on consecutive passes to prevent
# loops
sub set_prev_pass_check {
    my ( $self, $state );

    if (    defined $state
        and $state =~ /^X/
        and $self->{state_prev}
        and $state eq $self->{state_prev}
        and $self->{change_pass} >= ( $main::Loop_Count - 1 ) )
    {

        my $item_name = $self->{object_name};
        print
          "X10 item set skipped on consecutive pass.  item=$item_name state= $state id=$state\n";
        return 1;
    }
    return 0;
}

sub set_interface {
    my ( $self, $interface ) = @_;

    $self->SUPER::set_interface($interface);
    $self->check_for_x10_interface;
}

sub get_supported_interfaces {
    my ($self) = @_;

    return \@supported_interfaces;
}

sub lookup_interface {
    my ( $self, $interface ) = @_;

    if ( $interface and $interface ne '' ) {
        return lc $interface;
    }

    if (    $::config_parms{x10_interface}
        and $self->supports( $::config_parms{x10_interface} ) )
    {
        return lc( $::config_parms{x10_interface} );
    }

    return $self->SUPER::lookup_interface;
}

# do not remove the following line, packages must return a true value
1;
