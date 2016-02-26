
=head1 B<dss_interface>

=head2 SYNOPSIS

NONE

=head2 DESCRIPTION

NONE

=head2 INHERITS

B<Generic_Item>

=head2 METHODS

=over

=item B<UnDoc>

=cut

use strict;

package dss_interface;

@dss_interface::ISA = ('Generic_Item');

my @DSS_Ports;

sub startup {
    &::MainLoop_pre_add_hook( \&dss_interface::check_for_data, 1 );
}

sub check_for_data {
    foreach my $portname (@DSS_Ports) {
        &main::check_for_generic_serial_data($portname);
    }
}

sub new {
    my ( $class, $id, $state, $portname ) = @_;
    my $self = {};
    my %commands;
    my $doIt;
    my $type = uc $main::config_parms{ $portname . "_type" };
    &main::serial_port_create( $portname,
        $main::config_parms{ $portname . "_port" },
        9600, 'none', 'raw' );
    if ( $main::Serial_Ports{$portname}{object} ) {
        push( @DSS_Ports, $portname );
    }
    else {
        $self = {};
        return undef;
    }
    $$self{state}       = undef;
    $$self{said}        = undef;
    $$self{portname}    = $portname;
    $$self{lastcommand} = undef;
    if ( $type eq "AUTO" ) {

        # Send a benign command such as GETTIME to see if we are a regular or newrca
        my $fullcommand = "0xFA,0x11";
        eval "\$doIt = pack(\"C*\", $fullcommand )";
        $main::Serial_Ports{$portname}{object}->write($doIt);
        select( undef, undef, undef, .2 );
        &main::check_for_generic_serial_data($portname);
        $type = ( &GetReply( $self, 'GETTIME' ) ) ? "REGULAR" : "NEWRCA";
        $main::Serial_Ports{$portname}{data} = '';
    }
    $type = "REGULAR" if $type ne "NEWRCA";
    $$self{type} = $type;
    my $KPC = ($type) eq "NEWRCA" ? "0xA5,0x00,0x00" : "0x45,0x00,0x00";
    %commands = (
        POWER       => "$KPC,0xD5",
        DSS         => "$KPC,0xC5",
        OFF         => "$KPC,0xC4",
        ONE         => "$KPC,0xCE",
        TWO         => "$KPC,0xCD",
        THREE       => "$KPC,0xCC",
        FOUR        => "$KPC,0xCB",
        FIVE        => "$KPC,0xCA",
        SIX         => "$KPC,0xC9",
        SEVEN       => "$KPC,0xC8",
        EIGHT       => "$KPC,0xC7",
        NINE        => "$KPC,0xC6",
        ZERO        => "$KPC,0xCF",
        PREVIOUS    => "$KPC,0xD8",
        UP          => "$KPC,0x9C",
        DOWN        => "$KPC,0x9D",
        LEFT        => "$KPC,0x9B",
        RIGHT       => "$KPC,0x9A",
        SELECT      => "$KPC,0xC3",
        GUIDE       => "$KPC,0xE5",
        MENU        => "$KPC,0xF7",
        FAVOURITE   => "$KPC,0x9E",
        CLEAR       => "$KPC,0xF9",
        FETCH       => "$KPC,0x6C",
        TVSAT       => "$KPC,0xFA",
        ALTAUDIO    => "$KPC,0x4F",
        POWERON     => ($type) eq "NEWRCA" ? "0x82" : "0x02",
        POWEROFF    => ($type) eq "NEWRCA" ? "0x81" : "0x01",
        SETCHANNEL  => ($type) eq "NEWRCA" ? "0xA6" : "0x46",
        ENABLEIR    => ($type) eq "NEWRCA" ? "0x93" : "0x13",
        DISABLEIR   => ($type) eq "NEWRCA" ? "0x94" : "0x14",
        MESSAGESET  => ($type) eq "NEWRCA" ? "0xAA" : "0x4A",
        MESSAGESHOW => ($type) eq "NEWRCA" ? "0x85" : "0x05",
        MESSAGEHIDE => ($type) eq "NEWRCA" ? "0x86" : "0x06",
        GETTIME     => ($type) eq "NEWRCA" ? "0x91" : "0x11",
        GETCHANNEL  => ($type) eq "NEWRCA" ? "0x87" : "0x07",
        GETSIGNAL   => ($type) eq "NEWRCA" ? "0x90" : "0x10"
    );

    $$self{command} = {%commands};
    $$self{type}    = $type;
    bless $self, $class;
    &add( $self, $id, $state );
    return $self;
}

sub add {
    my ( $self, $id, $state ) = @_;
    $id    = uc $id;
    $state = uc $state;
    $$self{id_by_state}{$state} = $id if ( $state and $id );
}

sub default_setstate {
    my ( $self, $state ) = @_;
    my $portname = $self->{portname};
    $state = uc $state;
    $state = $self->{id_by_state}{$state}
      if ( defined $self->{id_by_state}{$state} );

    my ( $cmd, $text ) = split( / /, $state, 2 );
    my $reply = '';

    my $fullcommand = $self->{command}{$cmd};
    my @chararray;
    my $val;
    my $doIt;
    my ( $highbyte, $lowbyte );

    if ($fullcommand) {
        $fullcommand = "0xFA,$fullcommand";

        if ( $cmd eq "MESSAGESET" ) {
            $fullcommand .= sprintf( ",0x%x", length($text) );
            @chararray = unpack( "C*", $text );
            foreach $val (@chararray) {
                $fullcommand .= sprintf( ",0x%x", $val );
            }
        }
        elsif ( $cmd eq "SETCHANNEL" ) {
            $highbyte = $text >> 8;
            $lowbyte  = $text % 256;
            $fullcommand .= sprintf( ",0x%x,0x%x", $highbyte, $lowbyte );
            $fullcommand .= ",0xFF,0xFF" if $self->{type} eq 'NEWRCA';
        }

        eval "\$doIt = pack(\"C*\", $fullcommand )";
        print "Sent:$fullcommand\n" if $main::config_parms{debug} eq 'DSS';
        $main::Serial_Ports{$portname}{data} = '';
        $main::Serial_Ports{$portname}{object}->write($doIt);
    }

    $self->{lastcommand} = $cmd;
}

sub said {
    my ($self) = @_;
    return &GetReply( $self, $self->{lastcommand} ) if $self->{lastcommand};
    return undef;
}

sub GetReply {
    my ( $self, $cmd ) = @_;
    my $portname  = $self->{portname};
    my $strreturn = '';
    my ( $last, @ret, $buf, $str, $new_data, $serial_data, $remain );
    my $valid_count = 0;
    my $error       = 0;
    my $ok          = 0;
    my $type        = $self->{type};
    my %results     = (
        "0xF0" => "VALID",
        "0xF1" => "INVALID",
        "0xF2" => "PROCESSING",
        "0xF3" => "TIMEOUT",
        "0xF4" => "SUCCESS",
        "0xF5" => "FAILED",
        "0xFB" => "PROMPT",
        "0xFD" => "BUFFEROVERFLOW",
        "0xFF" => "BUFFEROVERFLOW"
    );
    $serial_data                         = $main::Serial_Ports{$portname}{data};
    $main::Serial_Ports{$portname}{data} = '';
    $new_data                            = $serial_data;

    while ($serial_data) {
        ( $buf, $serial_data ) = split( //, $serial_data, 2 );
        $str = sprintf( "0x%2.2X", ord($buf) );
        print "RECV: [$str] - $results{$str}\n"
          if $main::config_parms{debug} eq 'DSS';
        $valid_count++ if $results{$str} eq "VALID";

        if ( $valid_count > 1 ) {
            $new_data = $buf . $serial_data;
            last;
        }

        next if $valid_count < 1;
        push( @ret, hex($str) ) if !$results{$str};

        if ( $results{$str} eq "SUCCESS" ) {
            $ok = 1;
            last;
        }

        if ( " 0xF1 0xF4 0xF5 0xFD 0xFF " =~ m/ $str / ) {
            $new_data  = $serial_data;
            $strreturn = "ERROR:$cmd";
            $error     = 1;
            last;
        }

        if ( $results{$last} eq "PROMPT" and $results{$str} eq "PROMPT" ) {
            $strreturn = "ERROR:$cmd";
            $error     = 1;
            last;
        }

        $last = $str;
    }

    if ($ok) {
        $new_data  = $serial_data;
        $strreturn = "OK:";

        $strreturn .= "YEAR="
          . ( $ret[0] + 1993 )
          . ",MONTH=$ret[1],"
          . "DAY=$ret[2],HOUR=$ret[3],MINUTE=$ret[4],SECOND=$ret[5],DAYOFWEEK=$ret[6]"
          if ( $cmd eq "GETTIME" and @ret + 0 == 7 );

        $strreturn .= "CHANNEL="
          . ( $ret[0] * 256 + $ret[1] )
          if (
            $cmd eq "GETCHANNEL"
            and (  ( $type eq "NEWRCA" and @ret + 0 == 4 )
                or ( $type eq "REGULAR" and @ret + 0 == 2 ) )
          );

        $strreturn .= "SIGNAL=$ret[0]" if $cmd eq "GETSIGNAL";
        print "RETURNED = $strreturn\n" if $main::config_parms{debug} eq 'DSS';
    }
    elsif ( !$error ) {
        $strreturn = undef;
    }

    $main::Serial_Ports{$portname}{data} = $new_data;
    return $strreturn;
}

1;

=back

=head2 INI PARAMETERS

  dss_module = dss_interface
  dss_port   = /dev/ttyS7
  dss_type   = REGULAR or NEWRCA or AUTO

=head2 AUTHOR

UNK

=head2 SEE ALSO

More info is in mh/code/public/dss_interface.pl

=head2 LICENSE

This program is free software; you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation; either version 2 of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more details.

You should have received a copy of the GNU General Public License along with this program; if not, write to the Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.

=cut

