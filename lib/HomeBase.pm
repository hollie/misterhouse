
=head1 B<HomeBase>

=head2 SYNOPSIS

NONE

=head2 DESCRIPTION

NONE

=head2 INHERITS

B<NONE>

=head2 METHODS

=over

=cut

use strict;

package HomeBase;

my $temp;

sub init {
    my ($serial_port) = @_;

    # Set to echo mode, so we can monitor events
    #   print "Sending HomeBase init string\n";
    print "Bad HomeBase init echo command transmition\n"
      unless 6 == $serial_port->write("##%1d\r");
}

sub read_time {
    my ($serial_port) = @_;
    print "Reading HomeBase time\n";
    if ( 6 == ( $temp = $serial_port->write("##%06\r") ) ) {
        select undef, undef, undef, 100 / 1000;    # Give it a chance to respond
        if ( my $data = $serial_port->input ) {

            #print "HomeBase time string: $data\n";
            # Not sure about $second.  $wday looks like year, not 0-7??
            my ( $year, $month, $mday, $wday, $hour, $minute, $second ) =
              unpack( "A2A2A2A2A2A2A2", $data );
            print "Homebase time:  $hour:$minute:$second $month/$mday/$year\n";
            return
              wantarray
              ? ( $second, $minute, $hour, $mday, $month, $year, $wday )
              : " $hour:$minute:$second $month/$mday/$year";
        }
        else {
            print "Homebase did not respond to read_time request\n";
            return 0;
        }
    }
    else {
        print "Homebase bad write on read_time request: $temp\n";
        return 0;
    }
}

sub read_log {
    my ($serial_port) = @_;
    print "Reading HomeBase log\n";
    if ( 6 == ( $temp = $serial_port->write("##%15\r") ) ) {
        select undef, undef, undef, 100 / 1000;    # Give it a chance to respond
               # May need to paste data together to find real line breaks
        my @log;
        my $buffer;

        # Read data in a buffer string
        while ( my $data = $serial_port->input ) {
            $buffer .= $data;
            select undef, undef, undef,
              100 / 1000;    # Need more/less/any delay here???
        }

        # Filter out extraneous stuff before splitting into list
        $buffer =~ s/##0\r\n//g;
        $buffer =~ s/!!.*\r\n//g;

        @log = split /\r\n/, $buffer;

        #my $elem;
        #foreach $elem (@log) {
        #        # Check for real log record
        #        if ( $elem =~ /^\d+\// ) {
        #                print "-->$elem<--\n";
        #        }
        #}

        my $count = @log;
        print "$count HomeBase log records were read\n";
        return @log;
    }
    else {
        print "Homebase bad write on read_log request: $temp\n";
        return 0;
    }
}

#       Homebase log sample format
#HomeBase log record: r call
#09/29 10:03:54 Downstairs Unoccupied
#09/29 11:58:14 Call from Mom
#09/29 15:21:34 Crawl
#HomeBase log record:  space door opened
#09/29 15:22:13 Downstairs is Occupied
#09/29 15:24:00 Call from Mom
#09/29 15:43:06

sub clear_log {
    my ($serial_port) = @_;

    #print "Clearing HomeBase log\n";
    if ( 6 == $serial_port->write("##%16\r") ) {
        print "HomeBase log cleared\n";
        return 1;
    }
    else {
        print "Bad Homebase log reset\n";
        return 0;
    }
}

sub read_flags {
    my ($serial_port) = @_;
    print "Reading HomeBase Flags\n";
    if ( 6 == ( $temp = $serial_port->write("##%10\r") ) ) {
        select undef, undef, undef, 100 / 1000;    # Give it a chance to respond
               # How may flags?? Best look for end of data character ... \n\n??
        my @flags;
        while ( my $data = $serial_port->input ) {
            my ( $header, $flags ) = $data =~ /(\S+?)[\n\r]+(\S+)/;
            my $l = length $flags;
            $l /= 2;

            #print "Flag string has $l bits: $flags\n";
            # There are 2 characters per flag
            #           push(@flags, split('', $flags));
            while ($flags) {
                push( @flags, substr( $flags, 0, 2 ) );
                $flags = substr( $flags, 2 );
            }
        }
        print "Homebase did not respond to read_flags request\n" unless @flags;
        return @flags;
    }
    else {
        print "Homebase bad write on read_flags request: $temp\n";
    }
}

sub read_variables {
    my ($serial_port) = @_;
    print "Reading HomeBase Variables\n";
    if ( 6 == ( $temp = $serial_port->write("##%12\r") ) ) {
        select undef, undef, undef, 100 / 1000;    # Give it a chance to respond
               # May need to paste data together to find real line breaks
        my @vars;
        my $buffer;
        while ( my $data = $serial_port->input ) {
            $buffer .= $data
              unless ( $data =~ /#/ );    # ##0 is end of list marker
            select undef, undef, undef,
              100 / 1000;                 # Need more/less/any delay here???
        }
        @vars = split /\r\n/, $buffer;
        my $count = @vars;
        print "$count HomeBase var records were read\n";
        print "Homebase did not respond to read_flags request\n" unless @vars;
        return @vars;
    }
    else {
        print "Homebase bad write on read_variables request: $temp\n";
    }
}

=item C<set_time>

this command was decoded empirically from Starate/WinEVM interaction

  Homebase (Stargate) command is ##%05AAAALLLLTTSSYYMMDDRRHHMMCC
  AAAA = Latitude, LLLL = Longitude, TT=Timezone (05=EST)
  SS="Is daylight savings time used in your area?" (01=Yes)
  YY=Year, MM=Month, DD=Day, RR=DOW (Seems to be ignored, but set as
        Th=01, Wen=02, Tu=04, Mo=08, Sun=10, Sat=20)
  CC=00 (Checksum? doesn't appear to be used)

=cut

sub set_time {
    my ($serial_port) = @_;
    my ( $Second, $Minute, $Hour, $Mday, $Month, $Year, $Wday, $Yday, $isdst )
      = localtime time;
    $Month++;
    $Wday++;
    my $localtime = localtime time;

    # Week day setting seems to be ignored by stargate, so set it to 00
    $Wday = 0;

    # Bruce's weekday calculation, Mon=1, Sun=7)
    # $Wday = 2 ** (7 - $Wday);
    # if ($Yday > 255) {
    #    $Yday -= 256;
    #    $Wday *= 2;
    # }

    # Fix Year 2000 = 100 thing??
    if ( $Year ge 100 ) {
        $Year -= 100;
    }

    # Set daylight savings flag, this should be in mh.private.ini if your area uses DST
    $isdst = "01";
    #
    #print ("DST=$isdst Y=$Year M=$Month D=$Mday DOW=$Wday H=$Hour M=$Minute\n");
    my $set_time = sprintf(
        "%04x%04x%02x%02x%02d%02d%02d%02d%02d%02d",
        abs( $main::config_parms{latitude} ),
        abs( $main::config_parms{longitude} ),
        abs( $main::config_parms{time_zone} ),
        $isdst,
        $Year,
        $Month,
        $Mday,
        $Wday,
        $Hour,
        $Minute
    );

    #Checksum not required, so set it to 00
    #my $checksum = sprintf("%02x", unpack("%8C*", $set_time));
    my $checksum = "00";
    print "HomeBase set_time=$set_time checksum=$checksum\n";

    if (
        32 == (
            $temp =
              $serial_port->write( "##%05" . $set_time . $checksum . "\r" )
        )
      )
    {
        print "HomeBase time has been updated to $localtime\n";
        return 1;
    }
    else {
        print "Homebase bad write on set_time: $temp\n";
        return -1;
    }

}

sub send_X10 {
    my ( $serial_port, $house_code ) = @_;
    print "\ndb sending HomeBase x10 code: $house_code\n"
      if lc( $main::config_parms{debug} ) eq 'homebase';

    my ( $house, $code ) = $house_code =~ /(\S)(\S+)/;
    $house = uc($house);
    $code  = uc($code);

    my %table_hcodes = qw(A 6  B 7  C 4  D 5  E 8  F 9  G a  H b
      I e  J f  K c  L d  M 0  N 1  O 2  P 3);

    my %table_dcodes = qw(1 06  2 07  3 04  4 05  5 08  6 09  7 0a  8 0b
      9 0e  A 0f  B 0c  C 0d  D 00  E 01  F 02  G 03
      J 14  K 1c  L 12  M 1a O 18 P 10
      ON 14  OFF 1c  BRIGHT 12  DIM 1a);

    #                          ALL_OFF 10  ALL_ON 18
    #                          ALL_OFF_LIGHTS 16);

    my ( $house_bits, $code_bits, $function, $header );

    $house_bits = $table_hcodes{ uc($house) };
    unless ( defined $house_bits ) {
        print "Error, invalid HomeBase X10 house code: $house\n";
        return;
    }

    unless ( $code_bits = $table_dcodes{ uc($code) } ) {
        print "Error, invalid HomeBase x10 code: $code\n";
        return;
    }

    $header = "##%040" . $code_bits . $house_bits;
    print "db HomeBase x10 command sent: $header\n"
      if lc( $main::config_parms{debug} ) eq 'homebase';

    my $sent = $serial_port->write( $header . "\r" );
    print "Bad HomeBase X10 transmition sent=$sent\n" unless 10 == $sent;
}

# Valid digitis 0-9, * #
# OnHook = +
# OffHook = ^
# Pause = ,
# CallerID C
# HookFlash !
sub send_telephone {
    my ( $serial_port, $phonedata ) = @_;
    print "\ndb sending HomeBase telephone command: $phonedata\n"
      if lc( $main::config_parms{debug} ) eq 'homebase';

    $phonedata = "##%57<" . $phonedata . ">";
    print "db HomeBase telephone command sent: $phonedata\n"
      if lc( $main::config_parms{debug} ) eq 'homebase';

    my $sent = $serial_port->write( $phonedata . "\r" );
    print "Bad HomeBase telephone transmition sent=$sent\n" unless $sent > 0;
}

my $serial_data;    # Holds left over serial data

sub read {

    return undef unless $::New_Msecond_100;

    my ( $serial_port, $no_block ) = @_;

    my %table_hcodes = qw(6  A 7  B 4  C 5  D 8  E 9  F a  G b H
      e  I f  J c  K d  L 0  M 1  N 2  O 3 P);
    my %table_dcodes = qw(06  1 07  2 04  3 05  4 08  5 09  6 0a  7 0b 8
      0e  9 0f  A 0c  B 0d  C 00  D 01  E 02  F 03 B
      14  J 1c  K 12  L 1a M 18 O 10 P);

    #                          10 ALL_OFF 18 ALL_ON
    #                          16 ALL_OFF_LIGHTS);

    my ($data);
    if ( $data = $serial_port->input ) {
        print "db HomeBase serial data1=$data...\n"
          if lc( $main::config_parms{debug} ) eq 'homebase';
        $serial_data .= $data;
        print "db HomeBase serial data2=$serial_data...\n"
          if lc( $main::config_parms{debug} ) eq 'homebase';
        my ( $record, $remainder );
        while ( ( $record, $remainder ) = $serial_data =~ /(.+?)\n(.*)/ ) {
            $serial_data =
              $remainder;    # Might have part of the next record left over
            print "db HomeBase serial data3=$record remainder=$remainder.\n"
              if lc( $main::config_parms{debug} ) eq 'homebase';

            #           return undef unless ($data) = $record =~ m|!!\d\d\\/\d{8}(\S+)|;
            return undef
              unless $record =~ /^\!\!\d\d\//;    # Only look at echo records
            $data = substr( $record, 13 );
            print "db data4=$data\n"
              if lc( $main::config_parms{debug} ) eq 'homebase';
            my @bytes = split //, $data;

            return undef
              unless $bytes[0] eq '0';    # Only look at x10 data for now
            return undef
              unless $bytes[1] eq '0'
              or $bytes[1] eq '1';        # Only look at receive data for now
             # Disable using the Stargate for X10 receive if so configured.  I am using the CM11a and just use
             # the stargate for I/O and phone control (bsobel@vipmail.com)
            return if $main::config_parms{HomeBase_DisableX10Receive};

            my ( $house, $device );
            unless ( $house = $table_hcodes{ lc( $bytes[3] ) } ) {
                print "Error, not a valid HomeBase house code: $bytes[3]\n";
                return;
            }
            my $code = $bytes[1] . $bytes[2];
            unless ( $device = $table_dcodes{ lc($code) } ) {
                print "Error, not a valid HomeBase device code: $code\n";
                return;
            }
            else {
                my $data = $house . $device;
                print "X10 receive:$data\n"
                  if lc( $main::config_parms{debug} ) eq 'homebase';
                return $data;
            }
        }
    }

    # If we do not do this, we may get endless error messages.
    else {
        $serial_port->reset_error;
    }

    return undef;    # No data read
}

return 1;            # for require

# For reference on dealing with bits/bytes/strings:
#
#print pack('B8', '01101011');   # -> k   To go from bit to string
#print unpack('C', 'k');         # -> 107 To go from string to decimal
#print   pack('C', 107);         # -> k   To go from decimal to srting
#printf("%0.2lx", 107);          # -> 6b  To go to decimal -> hex
#print hex('6b');                # -> 107 to go from hex -> decimal

# Examples:
# 0x5a -> 90  -> Z
# 0xa5 -> 165 -> ~N (tilde over N)
# 0xc3 -> 195 -> |-
# 0x3c -> 60 -> <

# Modified by Bob Steinbeiser 2/12/00
#
# $Log: HomeBase.pm,v $
# Revision 1.14  2006/01/29 20:30:17  winter
# *** empty log message ***
#
# Revision 1.13  2005/03/20 19:02:01  winter
# *** empty log message ***
#
# Revision 1.12  2001/03/24 18:08:38  winter
# - 2.47 release
#
# Revision 1.11  2001/02/04 20:31:31  winter
# - 2.43 release
#
# Revision 1.10  2000/03/10 04:09:01  winter
# - Add Ibutton support and more web changes
#
# Revision 1.7  1999/09/12 16:56:41  winter
# - more debug
#
# Revision 1.6  1999/08/30 00:22:42  winter
# - add more debug
#
# Revision 1.5  1999/08/01 01:29:10  winter
# - add (untested) read/time functions
#
# Revision 1.4  1999/07/21 21:09:32  winter
# - Make debug conditional
#
# Revision 1.3  1999/05/30 21:19:32  winter
# - add debug (a long time ago)
#
# Revision 1.2  1998/09/16 13:05:33  winter
# - First pass commited
#
# Revision 1.1  1998/09/12 22:12:33  winter
# - created.
#
#
#

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

