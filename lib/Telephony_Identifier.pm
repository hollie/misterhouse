use strict;

=begin comment
@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@

File:
	Telephony_Identifier.pm

Description:
	Adds support for the Identifier Caller ID and Line Monitor unit made by Yes-Tele.com
	The primary function of the Identifier is used to monitor telephone lines 
	and report the Caller ID telephone number and name of the incoming caller 
	and dialed number of outgoing calls. Additionally the Identifier can report 
	the status and activity of each telephone line. The Identifier events include:

		Caller ID Name & Number 
		Outgoing Numbers 
		Length of Call (incoming & outgoing) 
		Number of Rings 
		Line Number 
		Distinctive Ring (Ring Master) 

	More info at:
		http://www.yes-tele.com/mlm.html

Author:
	Craig Schaeffer

License:
	This free software is licensed under the terms of the GNU public license.

Usage:
	
	Add this to your mh.ini:
		
		identifier_port=COMx

	Example initialization:

		use Telephony_Identifier;
		$identifier = new Telephony_Identifier('Identifier', $config_parms{identifier_port});		

		$cid_lookup     = new CID_Lookup($identifier);
		$cid_log        = new CID_Log($cid_lookup);
		$cid_announce   = new CID_Announce($cid_lookup, 'Call from $name. Phone call is from $name');

	Constructor Parameters:
		ex. $x = new Telephony_Identifier($y,$z);
		$x		- Reference to the class
		$y		- Object name reference
		$z		- Serial Port of Identifier

	Input states:

	Output states:
		"ring"		- Ring
		"cid"		- Caller ID event
		"dtmf"		- DTMF received
		"onhook"	- Device went on hook
		"offhook"	- Device went off hook

Example:
	mh/code/public/identifier.pl

Special Thanks to: 
	Jason Sharpee
		

@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
=cut

use Telephony_Item;

package Telephony_Identifier;
@Telephony_Identifier::ISA = ('Telephony_Item');

my ( $hooks_added, $identifier_object );

sub new {
    my ( $class, $name, $serial_port ) = @_;
    print "new Telephony_Identifier, name:$name, port:$serial_port\n"
      if $main::Debug{phone};

    my $self = {};
    bless $self, $class;

    $name = 'Identifier' unless $name;
    $$self{port} = $serial_port;
    $$self{name} = $name;

    &open_port($self);

    unless ( $hooks_added++ ) {
        &::MainLoop_pre_add_hook( \&Telephony_Identifier::check_for_data,
            'persistent' );
    }

    $identifier_object = $self;

    return $self;
}

sub open_port {
    my ($self) = @_;
    my $port   = $$self{port};
    my $name   = $$self{name};

    return if $main::Serial_Ports{$name};    # Already open

    print "Telephony_Identifier port open:  name=$name port=$port\n"
      if $main::Debug{phone};
    if ($port) {
        &::serial_port_create( $name, $port, 4800, 'dtr' );
        push( @::Generic_Serial_Ports, $name );
        &init unless $port =~ /proxy/;
    }
}

sub init {
    my ($self) = @_;
    my $name = $$self{name};
    if ($name) {
        &Serial_Item::send_serial_data( $name, 'ATSN' );
        &::print_log("$name interface has been initialized with 'ATSN'");
    }
}

sub check_for_data {

    if ( my $data = $main::Serial_Ports{Identifier}{data_record} ) {
        $main::Serial_Ports{Identifier}{data_record} = undef;

        print "Identifier data: [$data]\n" if $main::Debug{phone};

        if ( $data =~ /\+/ ) {
            process_identifier_data($data);
        }
    }
}

sub process_identifier_data {
    my ($data) = @_;
    my $msg = "[$data], ";

    my ( $event, $event_type, $number, $name, $line, $status, $digit );
    ($event) = $data =~ /\s*\+(\d),.*/;

    if ( $event eq '1' ) {    # cid
        $msg .= "cid event 1";
        ( $event, $number, $name, $line ) = split /,/, $data;
        $name = 'OUT OF AREA' if $name eq 'O';
        $name = 'PRIVATE'     if $name eq 'P';
        $identifier_object->cid_name($name);
        $identifier_object->cid_number($number);
        $identifier_object->cid_type('N');
        $identifier_object->address( $line + 0 );
        $identifier_object->SUPER::set( 'cid', 'identifier' );
        $msg .= "$number,$name,$line";

    }
    elsif ( $event eq '2' ) {    # line status
        ( $event, $status, $line ) = split /,/, $data;
        $msg .= "line status, status:$status, ";

        if ( $status eq '0' ) {    # On hook, idle (hangup)
            $msg .= "onhook (hangup)";
            if ( my $dtmf = $identifier_object->dtmf_buffer() ) {
                &::logit(
                    "$::config_parms{data_dir}/phone/logs/phone.$::Year_Month_Now.log",
                    "O$dtmf"
                );
                $identifier_object->dtmf_buffer('');
            }
            $identifier_object->SUPER::set('onhook');
            $identifier_object->ring_count(0);
        }
        elsif ( $status eq '1' ) {    #ring start
            $identifier_object->SUPER::set( 'ring', 'identifier' );
            $identifier_object->ring_count(
                $identifier_object->ring_count() + 1 );
            $msg .= "ring #" . $identifier_object->ring_count();
        }
        elsif ( $status eq '2' ) {    #ring stop
            $msg .= "ring stop";
            $msg = '' unless $main::Debug{phone};
        }
        elsif ( $status eq '3' ) {    #incoming call answered (offhook)
            $msg .= "offhook (answered)";
            $identifier_object->SUPER::set('offhook');
            $identifier_object->ring_count(0);
        }
        elsif ( $status eq '4' ) {    #offhook outgoing
            $msg .= "offhook outgoing";
            $identifier_object->SUPER::set('offhook');
            $identifier_object->ring_count(0);
        }
        else {
            $msg .= "UNKNOWN Identifier line status: $status";
        }
    }
    elsif ( $event eq '3' ) {         # maintenance
        ( $event, $event_type, $number ) = split /,/, $data;
        if ( $event_type eq '1' ) {
            $msg .= "watchdog timer event";
            $msg = '' unless $main::Debug{phone};
        }
        else {
            $msg .= "serial number event: s/n:$number";
        }
    }
    elsif ( $event eq '4' ) {         # cid w/private or out of area
        $msg .= "cid event 4";
        ( $event, $name, $line ) = split /,/, $data;
        $name = 'OUT OF AREA' if $name eq 'O';
        $name = 'PRIVATE'     if $name eq 'P';
        $identifier_object->cid_name($name);
        $identifier_object->cid_number($name);
        $identifier_object->address( $line + 0 );
        $identifier_object->cid_type($name);
        $identifier_object->cid_type('U') if $name eq 'OUT OF AREA|PRIVATE';
        $identifier_object->SUPER::set( 'cid', 'identifier' );
        $msg .= "$number,$name,$line";

    }
    elsif ( $event eq '5' ) {    # DTMF
        ( $event, $digit, $line ) = split /,/, $data;
        $identifier_object->SUPER::dtmf($digit);
        $identifier_object->SUPER::set('dtmf');
        $msg .=
          "DTMF digit:$digit, buffer:" . $identifier_object->dtmf_buffer();
    }
    elsif ( $event eq '7' ) {    # Status
        $msg .= "status event";
    }
    else {
        $msg .= "unknown Identifier event";
    }

    return unless $msg;
    &::print_msg($msg);
    print $main::Hour . ":" . $main::Minute . " " . "$msg\n"
      if $msg =~ /cid event/;
}

sub set_test {
    my ( $self, $data ) = @_;
    my $name = $$self{name};
    $main::Serial_Ports{$name}{data_record} = $data;
}

1;

#+2,1,001 Ring start on line 1
#+2,2,001 Ring stop on line 1
#+1,4085551212,Doe J          ,001
#+2,1,001 Ring start on line 1
#+2,2,001 Ring stop on line 1
#+2,3,001 Incoming call answered on line 1
#+2,0,001 Line 1 On Hook, idle  (hangup)

# Revision 1.0  2003/04/19 08:00:00  cschaeffer
# - initial release
#
