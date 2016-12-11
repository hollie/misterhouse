
=head1 B<RCS_Item>

=head2 SYNOPSIS

NONE

=head2 DESCRIPTION

NONE

=head2 INHERITS

B<Serial_Item>

=head2 METHODS

=over

=item B<UnDoc>

=cut

package RCS_Item;

@RCS_Item::ISA          = ("Serial_Item");
@RCS_Item::Inherit::ISA = @ISA;

sub new {
    my ( $class, $id, $interface ) = @_;
    my $self = Serial_Item->new( $id, undef, $interface );

    $$self{members} = [ () ];
    $$self{members_by_type}{members} = [ () ];

    bless $self, $class;

    $self->set_interface($interface);

    #   print "\n\nWarning: duplicate ID codes on different RCS objects: id=$id\n\n" if $serial_item_by_id{$id};

    print " - creating RCSx10 Interface on $interface\n";

    $id = "X$id";
    $self->{x10_id} = $id;

    my @RCS_table_send_cmd = (
        "System Off",
        "Heat Mode",
        "Cool Mode",
        "Auto Mode",
        "Fan On",
        "Fan Off",
        "Setback On",
        "Setback Off",
        "Increase 1 Deg",
        "Decrease 1 Deg",
        "SB Delta 6",
        "SB Delta 8",
        "SB Delta 10",
        "SB Delta 12",
        "SB Delta 14",
        "SB Delta 16",
        "Unit On",
        "Unit Off",
        "Preset On",
        "Preset Off",
        "Ack On",
        "Ack Off",
        "Echo On",
        "Echo Off",
        "Safe On",
        "Safe Off",
        "Autosend On",
        "Autosend Off",
        "Decode Table 1",
        "Decode Table 2",
        "Decode Table 3",
        "Decode Table 4"
    );

    my @RCS_table_req_status = (
        "Request Temp",
        "Request Setpoint",
        "Request Mode",
        "Request Fan",
        "Request SB Mode",
        "Request SB Delta"
    );

    my @RCS_table_report_status = (
        "Off",       "Heat",       "Cool",          "Auto",
        "Fan is On", "Fan is Off", "Setback is On", "Setback is Off"
    );

    my $i = 0;
    for my $hc (qw(M N O P C D A B E F G H K L I J)) {

        # unit 1,2,3,9 -> send setpoint
        # Disabled by default to minimize menu select lists size
        #       $self -> add ($id . '1' . $hc . 'PRESET_DIM1',   4 + $i . ' degrees', 'setpoint');
        #       $self -> add ($id . '1' . $hc . 'PRESET_DIM2',  20 + $i . ' degrees', 'setpoint');
        #       $self -> add ($id . '2' . $hc . 'PRESET_DIM1',  36 + $i . ' degrees', 'setpoint');
        $self->add( $id . '2' . $hc . 'PRESET_DIM2',
            52 + $i . ' degrees', 'setpoint' );
        $self->add( $id . '3' . $hc . 'PRESET_DIM1',
            68 + $i . ' degrees', 'setpoint' );
        $self->add( $id . '3' . $hc . 'PRESET_DIM2',
            84 + $i . ' degrees', 'setpoint' );
        $self->add( $id . '9' . $hc . 'PRESET_DIM1',
            100 + $i . ' degrees', 'setpoint' );
        $self->add( $id . '9' . $hc . 'PRESET_DIM2',
            116 + $i . ' degrees', 'setpoint' );

        # unit 4 -> send command
        $self->add( $id . '4' . $hc . 'PRESET_DIM1',
            $RCS_table_send_cmd[$i], 'cmd' );
        $self->add( $id . '4' . $hc . 'PRESET_DIM2',
            $RCS_table_send_cmd[ 16 + $i ], 'cmd' );

        # unit 5 -> request status
        $self->add( $id . '5' . $hc . 'PRESET_DIM1',
            $RCS_table_req_status[$i], 'request' )
          if $i < 6;

        # unit 6 -> report status
        $self->add( $id . '6' . $hc . 'PRESET_DIM1',
            $RCS_table_report_status[$i], 'status' )
          if $i < 8;

        # unit 10 -> echo responses
        $self->add( $id . 'A' . $hc . 'PRESET_DIM1',
            'Echo:' . $RCS_table_send_cmd[$i], 'echo' );
        $self->add( $id . 'A' . $hc . 'PRESET_DIM2',
            'Echo:' . $RCS_table_send_cmd[ 16 + $i ], 'echo' );

        # unit 11,12,13,14,15,16 -> report temperature
        # Disabled by default to minimize menu select lists size (do you really want to set your thermostat to -60?
        #        $self -> add ($id . 'B' . $hc . 'PRESET_DIM1', -60 + $i . " degrees ", 'temp');
        #        $self -> add ($id . 'B' . $hc . 'PRESET_DIM2', -44 + $i . " degrees ", 'temp');
        #        $self -> add ($id . 'C' . $hc . 'PRESET_DIM1', -28 + $i . " degrees ", 'temp');
        #        $self -> add ($id . 'C' . $hc . 'PRESET_DIM2', -12 + $i . " degrees ", 'temp');
        $self->add( $id . 'D' . $hc . 'PRESET_DIM1',
            4 + $i . " degrees ", 'temp' );
        $self->add( $id . 'D' . $hc . 'PRESET_DIM2',
            20 + $i . " degrees ", 'temp' );
        $self->add( $id . 'E' . $hc . 'PRESET_DIM1',
            36 + $i . " degrees ", 'temp' );
        $self->add( $id . 'E' . $hc . 'PRESET_DIM2',
            52 + $i . " degrees ", 'temp' );
        $self->add( $id . 'F' . $hc . 'PRESET_DIM1',
            68 + $i . " degrees ", 'temp' );
        $self->add( $id . 'F' . $hc . 'PRESET_DIM2',
            84 + $i . " degrees ", 'temp' );
        $self->add( $id . 'G' . $hc . 'PRESET_DIM1',
            100 + $i . " degrees ", 'temp' );
        $self->add( $id . 'G' . $hc . 'PRESET_DIM2',
            116 + $i . " degrees ", 'temp' );

        $i++;
    }

    return $self;
}

sub add {
    my ( $self, $id, $state, $cmd_type ) = @_;
    $$self{cmd_type}{$state} = $cmd_type;
    push( @{ $$self{members} }, ($state) );
    push( @{ $$self{members_by_type}{$cmd_type} }, ($state) );

    $self->RCS_Item::Inherit::add( $id, $state );

    #print "id=$id, state=$state, cmd_type=$cmd_type s=$$self->{cmd_type}{$state}\n";
}

sub set {
    my ( $self, $state ) = @_;
    return if &main::check_for_tied_filters( $self, $state );

    #print "set state=$state id=$self->{id_by_state}{$state} cmd_type=.$self->{cmd_type}{$state}. ";
    if (   $self->{cmd_type}{$state} eq 'setpoint'
        or $self->{cmd_type}{$state} eq 'cmd'
        or $self->{cmd_type}{$state} eq 'request' )
    {
        #print "set last_cmd=";
        #print $self->{id_by_state}{$state};
        #$$self{last_cmd} = $self->{id_by_state}{$state};
        $$self{last_cmd}      = $state;
        $$self{last_cmd_type} = $self->{cmd_type}{$state};
    }
    $self->RCS_Item::Inherit::set($state);
}

sub type {
    my ( $self, $state ) = @_;
    return $self->{cmd_type}{$state};
}

sub last_cmd {
    my ($self) = @_;
    return $self->{last_cmd};
}

sub last_cmd_type {
    my ($self) = @_;
    return $self->{last_cmd_type};
}

sub list {
    my ($self) = @_;
    print "RCS_item list: self=$self members=@{$$self{members}}\n"
      if $main::Debug{rcs};
    return sort @{ $$self{members} };
}

sub list_by_type {
    my ( $self, $cmd_type ) = @_;
    print
      "RCS_item list: self=$self members=@{$$self{members_by_type}{$cmd_type}}\n"
      if $main::Debug{rcs};
    return sort @{ $$self{members_by_type}{$cmd_type} };
}

1;

#
# Revision 1.1  1999/12/11 14:30:00  cschaeffer
# - created.
#
#
#

=back

=head2 INI PARAMETERS

NONE

=head2 AUTHOR

Craig Schaeffer

=head2 SEE ALSO

NONE

=head2 LICENSE

  Copyright (c) 1999 Craig Schaeffer. All rights reserved.
  This program is free software.  You may modify and/or
  distribute it under the same terms as Perl itself.
  This copyright notice must remain attached to the file.

  Protocol is documented here:
    http://www.resconsys.com/docs/X10%20BIDIRECTIONAL%20PROTOCOL%20REV13.pdf

=cut

