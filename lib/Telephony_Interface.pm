
=head1 B<Telephony_Interface>

=head2 SYNOPSIS

In the ini you must define a device such as:

    callerid_port = localhost:3333
    callerid_name = acheron-ncid
    callerid_type = ncid

=head2 DESCRIPTION

Provides support for common serial and network attached Caller ID devices. 
The majority of serial devices are basically modems, but some chipsets better 
support CID features than others. The following CID device types are supported:

    default         Default modem
    motorola        Motorola modem
    powerbit        Intertex (Powerbit, Telia)
    rockwell        Rockwell chipset modems
    supra           Supra modems
    cirruslogic     Cirrus Logic chipset modems
    zyxel           Zyxel modems
    netcallerid     NetCallerID devices (no longer available)
    ncid            NCID - Network Caller ID server

=head3 NCID

When using callerid_type = ncid, the callerid_port must be given in the format I<hostname/IP:port> such as:

    callerid_port = localhost:3333

=head2 INHERITS

L<Telephony_Item>

=head2 METHODS

=over

=cut

use strict;

use Telephony_Item;

package Telephony_Interface;
@Telephony_Interface::ISA = ('Telephony_Item');

my ( $hooks_added, @list_ports, %list_objects, %type_by_port, %caller_id_data,
    $cid_server_connect, $cid_server_timer );

# US Robotics 56k Voice model 0525 -> rockewell

my %table = (
    default     => [ 'ATE1V1X4&C1&D2S0=0+VCID=1',          38400, 'dtr' ],
    motorola    => [ 'ATE1V1X4&C1&D2S0=0*ID1',             38400, 'dtr' ],
    powerbit    => [ 'ATE1V1X4&C1&D2S0=0#CID=1',           38400, 'dtr' ],
    rockwell    => [ 'ATE1V1X4&C1&D2S0=0#CID=1',           38400, 'dtr' ],
    supra       => [ 'ats0=0#cid=1',                       38400, 'dtr' ],
    cirruslogic => [ 'ats0=0+vcid=1',                      38400, 'dtr' ],
    zyxel       => [ 'ATE1V1S40.2=1S41.6=1S42.2=1&L1M3N1', 38400, 'dtr' ],
    netcallerid => [ '',                                   4800,  '' ],
    ncid        => [ '',                                   0,     '' ]
);

=item C<new()>

Instantiates a new object.

=cut

sub new {
    my ( $class, $name, $port, $type ) = @_;
    my $self = {};
    bless $self, $class;

    unless ($port) {

        #       print "\nTelephony_Interface error, no port specified: name=$name.\n";
    }

    # Allow for a user defined type
    # e.g.  'modem1:ATE1V1X4&C1&D2S0=0#CID=1,38400,dtr'
    if ( $type and $type =~ /(\S+?):(.+)/ ) {
        $type = $1;
        @{ $table{$type} } = split ',', $2;
    }

    $type = 'default' unless $type;
    $type = 'default'
      unless $table{$type};    # In case someone makes up a bad type

    $name = 'Line 1' unless $name;

    $$self{name} = $name;
    $$self{type} = $type;
    $$self{port} = $port;
    &open_port($self) if $port;
    push( @{ $list_objects{$name} }, $self );
    unless ( $hooks_added++ ) {
        &::Reload_pre_add_hook( \&Telephony_Interface::reload_reset, 1 );
        &::MainLoop_pre_add_hook( \&Telephony_Interface::check_for_data, 1 );
    }
    return $self;
}

=item C<open_port()>

Open the given serial port or network socket.

=cut

sub open_port {
    my ($self) = @_;
    my $name   = $$self{name};
    my $type   = lc $$self{type};
    my $port   = $$self{port};
    if ( $port =~ /.*:\d*/ ) {

        # This is a hostname/IP:port, so open a Socket_Item instead
        return if $main::Socket_Ports{$name};    # Already open
        &::print_log("Telephony_Interface port open:  n=$name t=$type p=$port")
          if $main::Debug{phone};
        $cid_server_connect =
          new Socket_Item( undef, undef, $port, $name, 'tcp', 'record' );
        start $cid_server_connect;
        $cid_server_timer = new Timer;
        set $cid_server_timer 10;
        $type_by_port{$name} = $type;
        push @list_ports, $name;
    }
    else {
        return if $main::Serial_Ports{$name};    # Already open
        push @list_ports, $name;
        $type_by_port{$name} = $type;
        my $baudrate  = 38400;
        my $handshake = 'dtr';
        if ( $table{$type} ) {
            $baudrate  = $table{$type}[1];
            $handshake = $table{$type}[2];
        }
        &::print_log(
            "Telephony_Interface port open:  n=$name t=$type p=$port b=$baudrate h=$handshake"
        ) if $main::Debug{phone};
        if ($port) {
            &::serial_port_create( $name, $port, $baudrate, $handshake );
            push( @::Generic_Serial_Ports, $name );
            &init unless $port =~ /proxy/;
        }
    }
}

=item C<init()>

Initialize the serial device

=cut

sub init {
    my ($self) = @_;
    my $name   = $$self{name};
    my $type   = lc $$self{type};
    if ( $table{$type} and my $init = $table{$type}[0] ) {
        &Serial_Item::send_serial_data( $name, $init );
        &::print_log(
            "$name interface, type=$type, has been initialized with $init");
    }
}

=item C<reload_reset()>

Unload any defined devices and force a reset.

=cut

sub reload_reset {
    undef %list_objects;
}

=item C<check_for_data()>

Look for new data on the serial port or network socket.

=cut

sub check_for_data {
    for my $port (@list_ports) {
        if ($cid_server_connect) {
            if ( my $data = said $cid_server_connect) {
                &::print_log("Phone data: $data.") if $main::Debug{phone};
                if ( $data =~ /^CID:/ ) {
                    &::print_log("Callerid: $data");
                    &process_cid_data( $port, $data );
                }
                else {
                    &process_phone_data( $port, 'ring' ) if $data =~ /ring/i;
                }
            }
            elsif ( !( active $cid_server_connect)
                && ( expired $cid_server_timer) )
            {
                &::print_log(
                    "Callerid: Socket is not active, attempting to reconnect.");
                start $cid_server_connect;
                set $cid_server_timer 10
                  ; # Set the timer for 10 seconds before we try again so we don't thrash
            }
        }
        elsif ( my $data = $main::Serial_Ports{$port}{data_record} ) {
            $main::Serial_Ports{$port}{data_record} = undef;

            # Ignore garbage data (ascii is between ! thru ~)
            $data = '' if $data !~ /^[\n\r\t !-~]+$/;
            $caller_id_data{$port} .= ' ' . $data;
            &::print_log("Phone data: $data.") if $main::Debug{phone};
            if (
                   ( $caller_id_data{$port} =~ /NAME.+NU?MBE?R/s )
                or ( $caller_id_data{$port} =~ /NU?MBE?R.+NAME/s )
                or ( $caller_id_data{$port} =~ /NU?MBE?R.+MESG/s )
                or (    $caller_id_data{$port} =~ /NU?MBE?R/
                    and $main::config_parms{caller_id_format} eq 'number only' )
                or ( $caller_id_data{$port} =~ /END MSG/s )
                or    # UK format
                ( $caller_id_data{$port} =~ /FM:/ )
              )
            {
                &::print_log("Callerid: $caller_id_data{$port}");
                &process_cid_data( $port, $caller_id_data{$port} );
                undef $caller_id_data{$port};
            }
            else {
                &process_phone_data( $port, 'ring' ) if $data =~ /ring/i;
            }
        }
    }
}

=item C<process_phone_data($port, $data)>

Process misc phone data like rings

=cut

# Process Other phone data
sub process_phone_data {
    my ( $port, $data ) = @_;

    # Set all objects monitoring this port
    for my $object ( @{ $list_objects{$port} } ) {
        &::print_log(
            "Setting Telephony_Interface object $$object{name} to $data.");
        $object->SUPER::set('ring') if $data eq 'ring';
        $object->ring_count( $object->ring_count() + 1 )
          ;    # Where/when does this get reset??
    }
}

=item C<process_cid_data($port, $data)>

Process CID data from the device.

=cut

# Process Caller ID data
sub process_cid_data {
    my ( $port, $data ) = @_;

    my ( $number, $name, $time, $date );

    $data =~ s/[\n\r]//g;    # Drop newlines

    # Clean up Dock-N-Talk data
    #   ###DATE...NMBR5071234567...NAMEDock-N-Talk+++
    #   ###DATE...NMBR...NAME   -MSG OFF-+++
    return if $data =~ /-MSG OFF-/;
    $data =~ s/Dock-N-Talk//;

    my $type = $type_by_port{$port};
    if ( $type eq 'weeder' ) {
        ( $time, $number, $name ) = unpack( "A13A13A15", $data );
    }
    elsif ( $type eq 'netcallerid' ) {

        #  ###DATE12151248...NMBR2021230002...NAMEBUSH GEORGE +++
        #  ###DATE01061252...NMBR...NAME-UNKNOWN CALLER-+++
        #  ###DATE01061252...NMBR...NAME-PRIVATE CALLER-+++
        #  ###DATE...NMBR...NAME MESSAGE WAITING+++
        ( $date, $time, $number, $name ) =
          $data =~ /DATE(\d{4})(\d{4})\.{3}NMBR(.*)\.{3}NAME(.*?)\++$/;
        ($name)   = $data =~ /NAME(.*?)\++$/ unless $date;
        ($number) = $data =~ /NMBR(.+)\.{3}/ unless $name;
    }

    # Old NCID format
    # NCID data=CID:*DATE*10202003*TIME*0019*NMBR*2125551212*MESG*NONE*NAME*INFORMATION*
    # New NCID format
    # NCID data=CID: *DATE*03272014*TIME*1734*LINE*1234*NMBR*2125551212*MESG*NONE*NAME*OUT-OF-AREA*
    # http://ncid.sourceforge.net/
    elsif ( $type eq 'ncid' ) {
        ( $date, $time, $number, $name ) = $data =~
          /CID:\s\*DATE\*(\d{8})\*TIME\*(\d{4})\*LINE\*[^\*]+\*NMBR\*(\d*)\*MESG\*.*\*NAME\*([^\*]+)\*$/;
        &::print_log(
            "Phone NCID: date='$date', time='$time', number='$number', name='$name'."
        ) if $main::Debug{phone};
    }
    elsif ( $type eq 'zyxel' or $type eq 'motorola' ) {
        ($date)   = $data =~ /TIME: *(\S+)\s\S+/s;
        ($time)   = $data =~ /TIME: *\S+\s(\S+)/s;
        ($name)   = $data =~ /CALLER NAME: *([^\n]+)/s;
        ($name)   = $data =~ /REASON FOR NO CALLER NAME: *(\S+)/s unless $name;
        ($number) = $data =~ /CALLER NUMBER: *(\S+)/s;
        ($number) = $data =~ /REASON FOR NO CALLER NUMBER: *(\S+)/s
          unless $number;
        if ( $type eq 'motorola' ) {
            ($number) =~ s/\(//;
            ($number) =~ s/\)/-/;
        }
        $name = substr( $name, 0, 15 );
    }
    else {
        ($date) = $data =~ /DATE *= *(\S+)/s;
        ($time) = $data =~ /TIME *= *(\S+)/s;
        ($name) = $data =~ /NAME *= *(.{1,15})/s;
        ($name) = $data =~ /MESG *= *([^\n]+)/s unless $name;
        $name = 'private'     if $name eq '080150';
        $name = 'unavailable' if $name eq '08014F';
        ($number) = $data =~ /NU?M?BE?R *= *(\S+)/s;
        ($number) = $data =~ /FM:(\S+)/s unless $number;
    }

    $name   = '' unless $name;
    $number = '' unless $number;

    unless ( $name or $number ) {
        &::print_log(
            "Callerid data not parsed: p=$port t=$type d=$data date=$date time=$time number=$number name=$name"
        );
        return;
    }

    $number =~ s/[\(\)]//g;    # Drop () around area code

    $time = "$date $time" unless $time;

    my $cid_type = 'N';
    $cid_type = 'P' if $name =~ /private/i or uc $name eq 'P';
    $cid_type = 'U' if $name =~ /unknown/i or uc $name =~ /unavailable/i;
    if ( $name =~ /-unknown name-/i )
    {    #Netcallerid reports "-UNKNOWN NAME-"when it knows number, but not name
        $cid_type = 'N';
        $name     = '';
    }
    $cid_type = 'U' if uc $name eq 'O' or $number eq 'O';
    $cid_type = 'N'
      if $number =~ /^[\d\- ]+$/;    # Override the type if the number is known

    if ( $main::Debug{phone} ) {
        &::print_log(
            "Callerid data1: port=$port type=$type cid_type=$cid_type name=$name number=$number date=$date time=$time"
        );
        &::print_log("Callerid data2: data=$data.");
    }

    # Set all objects monitoring this port
    for my $object ( @{ $list_objects{$port} } ) {
        $object->address($port);
        $object->cid_name($name);
        $object->cid_number($number);
        $object->cid_type($cid_type);

        #       $object->ring_count('2');  # Need this??
        $object->SUPER::set('cid');
    }
}

=item C<set($p_state, $p_setby)>

Set the device on or off hook

=cut

sub set {
    my ( $self, $p_state, $p_setby ) = @_;
    if ( $p_state =~ /^offhook/i ) {
        &Serial_Item::send_serial_data( $self->{name}, 'ATA' );
    }
    elsif ( $p_state =~ /^onhook/i ) {
        &Serial_Item::send_serial_data( $self->{name}, 'ATH' );
    }
    $self->SUPER::set( $p_state, $p_setby );
}

=item C<set_test($data)>

Used for testing.

=cut

sub set_test {
    my ( $self, $data ) = @_;
    my $name = $$self{name};
    $main::Serial_Ports{$name}{data_record} = $data;
}

=back

=head2 AUTHOR

Chris Witte,
Bruce Winter,
Matthew Williams,
Brian Rudy

=head2 SEE ALSO

L<NCID - Network Caller ID|http://ncid.sourceforge.net/ncid/ncid.html>

=head2 LICENSE

This program is free software; you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation; either version 2 of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more details.

You should have received a copy of the GNU General Public License along with this program; if not, write to the Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.

=cut

1;

__END__

UK callerid data:

CID RING
CALLING MSG
DATE TIME=10/05 11:39
NO MESSAGE REASON=SECRET
NAME=WITHHELD
WITHHELD
END MSG
RING

RING

RING

RING

CID RING

CID RING
CALLING MSG
DATE TIME=10/05 20:27
NBR=01231231234
END MSG

---
Supra modem:
 DATE = 1229 TIME = 1848 NAME = VANCOUVER    WA NMBR = 3601231234
