
=head1 B<Homevision>

=head2 SYNOPSIS

NONE

=head2 DESCRIPTION

This module implements code to support the Homevision controller http://www.csi3.com/homevis2.htm

=head2 INHERITS

B<NONE>

=head2 METHODS

=over

=item B<UnDoc>

=cut

use strict;

package Homevision;

my $temp;
my $serial_data;    # Holds left over serial data
my $saveCode;
my $outCode;

sub init {
    my ($serial_port) = @_;

    # Set to echo mode, so we can monitor events
    &send( $serial_port, "INIT_ReportX10" );
    &send( $serial_port, "INIT_ReportIR" );
    &send( $serial_port, "INIT_ReportInputs" );

}

sub read_time {
    my ($serial_port) = @_;
    print "Reading Homevision time\n";

    print "Homevision::read_time unimplemented\n";
}

sub set_time {
    my ($serial_port) = @_;

    print "Homevision::set_time unimplemented\n";

}

sub send {
    my ( $serial_port, $data ) = @_;

    my $cmd = ",";    #All Homevision commands start with a ,

    print "Hello!! I'm supposed to send $data!!\n"
      if lc( $main::config_parms{debug} ) =~ /homevision/;

    if ( $data =~ /^X/ ) {
        if ( my ( $house, $unit, $func ) = $data =~ /^X([A-P])([0-9A-F]).(.*)/ )
        {
            $house = unpack( 'C', $house ) - 65;    #Get HV code from ASCII

            #           printf("House $house = %s ($house)\n", makehex($house));
            print "unit = $unit\n"
              if lc( $main::config_parms{debug} ) =~ /homevision/;
            $unit = hex($unit) if $unit =~ /[A-F]/;
            print "unit = $unit\n"
              if lc( $main::config_parms{debug} ) =~ /homevision/;

            my ($code) = &makehex( $house * 16 + $unit - 1 );

            {
                $cmd .= "X" . $code . "00", last if $func eq "J"; #On
                $cmd .= "X" . $code . "03", last if $func eq "K"; #Off
                $cmd .= "X" . $code . "0B", last if $func eq "L"; #Brighten once
                $cmd .= "X" . $code . "05", last if $func eq "M"; #Dim once

                #Set to level
                $cmd .= "P" . $code . "11" . &makehex( int( $func / 6.5 ) ),
                  last
                  if $func =~ /^[0-9]*/;

                #Dim n-times
                $cmd .= "P" . $code . "07" . &makehex( int( $1 / 6.5 ) ), last
                  if $func =~ /^\-([0-9]*)/;

                #Brighten n-times
                $cmd .= "P" . $code . "0D" . &makehex( int( $1 / 6.5 ) ), last
                  if $func =~ /^\+([0-9]*)/;

                #else (if it falls through to here...
                print
                  "Homevision::send X10, sorry I don't understand $data just yet\n";
                return;
            }
        }

    }
    elsif ( my ($code) = $data =~ /^IRSlot([0-9]+)$/ ) {

        #Send a Homevision IR command (one that's been given a Homevision location)

        $cmd .= ";" . makehex($code) . "00";
    }
    elsif ( my ( $byte1, $byte2 ) =
        $data =~ /^IRCode([0-9A-F][0-9A-F])([0-9A-F][0-9A-F])$/ )
    {
        #Send a Homevision IR command (one that Homevision understands)

        $cmd .= "T" . $byte1 . $byte2 . "00";
    }
    elsif ( my ( $port, $state ) = $data =~ /^OUTPUT([0-9]+)(high|low)/i ) {

        #Set a Homevision ouput port high or low

        $cmd .= "3" . makehex($port) . ( $state =~ /high/i ? "01" : "00" );
    }
    else {
        #Unimplemented
        print "Homevision::send unimplemented command $data\n";
        return;
    }

    print "Homevision::send command sent: $cmd\n"
      if lc( $main::config_parms{debug} ) =~ /homevision/;

    my $sent = $serial_port->write( $cmd . "\r" );
    print "Bad Homevision X10 transmition sent=$sent\n"
      unless length($cmd) + 1 == $sent;

    my $response;
    print "Waiting for HV response...\n"
      if lc( $main::config_parms{debug} ) =~ /homevision/;

    my $count = 0;
    do {
        $count++;
        select undef, undef, undef, .2; #sleep .2 seconds or until input happens
        $response .= $serial_port->input;
      } until $response =~ /(.*)(Done\r)(.*)/
      || $count >
      26;    #Wait up to five seconds for response (could be a long dim)

    if ( $2 =~ /Done/ ) {
        print "Cool, got it. Leftovers (if any): ($1, $2)\n"
          if lc( $main::config_parms{debug} ) =~ /homevision/;
    }
    else {
        print
          "Homevision::send() I waited for a return response for '$cmd', but it didn't come...\n";
    }

    #Give any leftovers to the read routine's overflow buffer:
    $serial_data .= $1 . $3;

    return;
}

sub send_X10 {
    my ( $serial_port, $house_code ) = @_;
    print "\ndb sending Homevision x10 code: $house_code\n"
      if lc( $main::config_parms{debug} ) =~ /homevision/;

    my ( $house, $code ) = $house_code =~ /(\S)(\S+)/;
    $house = uc($house);
    $code  = uc($code);

    my ($cmd) = ",";

    $house = unpack( 'C', $house ) - 65;

    #   printf("House $house = %s ($house)\n", makehex($house));

    if ( $code =~ /^[A-F0-9]+$/ ) {

        #Send House/Unit only
        $cmd .= "X" . &makehex( $house + $code ) . "15";
    }
    elsif ( $code =~ /^([JKLM]?)$/ ) {
        $cmd .= "P" . &makehex($house) . "16";

        $cmd .= "02" if ( $1 eq "J" );    #On
        $cmd .= "0A" if ( $1 eq "K" );    #Off
        $cmd .= "06" if ( $1 eq "L" );    #Brighten
        $cmd .= "0E" if ( $1 eq "M" );    #Dim
    }

    #Put more elsif's here...

    else {
        print "Homevision::send_X10 unimplemented: $house_code\n";
        return;
    }

    print "db Homevision x10 command sent: $cmd\n"
      if lc( $main::config_parms{debug} ) =~ /homevision/;

    my $sent = $serial_port->write( $cmd . "\r" );
    print "Bad Homevision X10 transmition sent=$sent\n"
      unless length($cmd) + 1 == $sent;

    #############
    #############
    #Need to wait for return code!!!!!
    print
      "Homevision::send_X10 checking for return code is unimplemented so far...\n";
    #############
    #############

    return;

}

sub read {
    my ( $serial_port, $no_block ) = @_;

    my ($data);
    if ( $data = $serial_port->input ) {

        #       print "db Homevision data1=$data\n";
        #       print "db Homevision serial data1=$data\n" if lc($main::config_parms{debug}) =~ /homevision/;

        $serial_data .= $data;    #Append to remainder from last time

        #       print "db Homevision serial data2=$serial_data\n" if lc($main::config_parms{debug}) =~ /homevision/;

        my ( $record, $remainder );
        $serial_data =~ tr/\n\001//sd;    #Strip terminators except \r

        #Special routine for ECS relaying only: command responses must be immediate
        if (   ( defined $main::config_parms{ECS_port} )
            && ( ($record) = $serial_data =~ /^([0-9]+ Cmd: )$/ ) )
        {
            #Homevision command response
            $main::Serial_Ports{'serial2'}{object}->write("$record");

            print "Forwarding partial '$record' to ECS\n"
              if lc( $main::config_parms{debug} ) =~ /ecs/;

            $serial_data = "";
        }

        my %table_hcodes = qw(6  A 7  B 4  C 5  D 8  E 9  F a  G b H
          e  I f  J c  K d  L 0  M 1  N 2  O 3 P);
        my %table_dcodes = qw(On J    Off K    Bright L    Dim M);

        while ( ( $record, $remainder ) = $serial_data =~ /(.+?)\r(.*)/ ) {
            $serial_data =
              $remainder;    # Might have part of the next record left over

            #            print "db Homevision serial data3=$record remainder=$remainder\n" if lc($main::config_parms{debug}) =~ /homevision/;

            #Relay it to ECS:
            if ( defined $main::config_parms{ECS_port} ) {
                print "Forwarding '$record' to ECS\n"
                  if lc( $main::config_parms{debug} ) =~ /ecs/;
                $main::Serial_Ports{'serial2'}{object}
                  ->write("$record\r\n\001");
            }

            #	    print "Homevision report: $record\n" if lc($main::config_parms{debug}) =~ /homevision/;

            {
                my ($hvcode) = $record =~ /^([0-9A-F]*)/;
                my $string = $record;

                if ( my ( $house, $code ) =
                    $string =~ /X-10 House\/Unit : ([A-P]) ([0-9]+)$/ )
                {
                    $code = substr( &makeX10hex($code), 1, 1 );
                    $code = chop($code);
                    print "Homevision returns: X" . $house . $code . "\n";
                    return "X" . $house . $code;
                }
                elsif ( my ( $house, $func ) =
                    $string =~ /X-10 .* : ([A-P]) (.*)$/ )
                {
                    print "Homevision returns: X"
                      . $house
                      . $table_dcodes{$func} . "\n";
                    return "X" . $house . $table_dcodes{$func};
                }
                elsif ( my ( $input, $state ) =
                    $string =~
                    /Input Port Changed.*: \#([0-9A-F]+) (Low|High)/ )
                {
                    #Digital input changed state

                    $input = hex($input);
                    $state = lc($state);
                    return "INPUT$input$state";
                }
                elsif ( my ( $one, $two ) =
                    $string =~ /Received IR Code = ([0-9A-F]+) ([0-9A-F]+)/ )
                {
                    #Standard format IR code
                    return "IRCode$one$two";
                }
                elsif ( my ($num) =
                    $string =~ /Matches IR Signal.*= ([0-9A-F]+)/ )
                {
                    #Defined format IR code
                    $num = hex($num);
                    return "IRSlot$num";
                }
                elsif ( $string =~ /(Done|Unknown IR Signal)/ ) {

                    #Ignore
                }
                elsif ( $hvcode eq "82" || $hvcode eq "83" || $hvcode eq "93" )
                {
                    #Homevision Error!
                    print
                      "\n********\nHomevision::read error received: $record\n********\n";
                }
                else {
                    print "Homevision::read unimplemented: '$record'\n"
                      unless ( $main::config_parms{ECS_port}
                        && $string =~ /Cmd: / );

                    #Ignore command responses from ECS
                }
            }
        }
    }

    # If we do not do this, we may get endless error messages.
    else {
        $serial_port->reset_error;
    }

    return undef;    # No data read
}

sub makehex {
    my ($dec) = @_;

    my $hex = "";

    if ( $dec > 255 ) {

        #My decimal to hex code sucks....
        #Plus, I don't know if I'm on a big-endian or little-endian machine anyway...
        warn "Homevision::makehex error: $dec is too big to be a byte...";
        return undef;
    }

    while ( $dec > 15 ) {

        my $byte = int( $dec / 16 );    #Byte
        $dec = $dec % 16;               #Remainder
        $hex .= substr( '0123456789ABCDEF', $byte, 1 );
    }

    $hex .= substr( '0123456789ABCDEF', $dec, 1 );

    $hex = "0$hex" if length($hex) == 1;

    return $hex;
}

sub makeX10hex {
    my ($dec) = @_;

    my $hex = "";

    if ( $dec > 255 ) {

        #My decimal to hex code sucks....
        #Plus, I don't know if I'm on a big-endian or little-endian machine anyway...
        warn "Homevision::makehex error: $dec is too big to be a byte...";
        return undef;
    }

    while ( $dec > 16 ) {

        my $byte = int( $dec / 17 );    #Byte
        $dec = $dec % 17;               #Remainder
        $hex .= substr( '0123456789ABCDEFG', $byte, 1 );
    }

    $hex .= substr( '0123456789ABCDEFG', $dec, 1 );

    $hex = "0$hex" if length($hex) == 1;

    return $hex;
}
return 1;                               # for require

# $Log: Homevision.pm,v $
# Revision 1.4  2000/05/03 04:10:27  aceautomator
#
# # Updated to correctly report X10 codes per the mh convention
#
# Revision 1.2  2000/01/27 13:42:03  winter
# - update version number
#
# Revision 1.1  1999/11/11 05:26:10  idean
# Initial revision
#
#
#

=back

=head2 INI PARAMETERS

  Homevision_port=/dev/ttyS0
  Homevision_baudrate=19200

=head2 AUTHOR

Ingo Dean, idean@iname.com
for Misterhouse, http://www.misterhouse.net
by Bruce Winter and many contributors

=head2 SEE ALSO

NONE

=head2 LICENSE

This program is free software; you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation; either version 2 of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more details.

You should have received a copy of the GNU General Public License along with this program; if not, write to the Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.

=cut

