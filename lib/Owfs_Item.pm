
=begin comment

Owfs_Item.pm

03/10/2007 Created by Jim Duda (jim@duda.tzo.com)

Use this module to interface with the OWFS (one-wire filesystem) software.
The OWFS software handles all the real-time processing of the one-wire itself,
offering a simple PERL API interface.  The Owfs_Item only requires the owserver
portion of owfs to be accessable.

Requirements:

 Download and install OWFS  (tested against release owfs-2.9p0).
 Only the owserver portion is required for Misterhouse.
 http://www.owfs.org

Setup:

In your code module, instantation the Owfs_Item class (or extension) to interface with some
one-wire element.  The one-wire device can be found using the OWFS html interface.

configure mh.private.ini

owfs_port = 4304    # defined port where the owfs server is listening
		    # (owserver defaults to 4304)

Example Usage:

 $item = new Owfs_Item ( "<device_id>", <location> );

 <device_id> - of the form family.address; identifies the one-wire device
 <location>  - ASCII string identifier providing a useful name for device_id

 $frontDoorBell = new Owfs_Item ( "12.487344000000", "Front DoorBell");
 $sensor        = new Owfs_Item ( "05.4D212A000000");

 Any of the fields in the one-wire device can be access via the set and get methods.

 $sensor->set ( "power", 1 );
 $sensor->get ( "alarm" );

 The get method only "requests" the property be fetched.  The property will be
 placed into the object state and can be accessed via:

   if (my $state = said $sensor) {
     ...
   }

   or;

   if (my $state = state_now $sensor) {
     ...
   }

   if (my $state = state_changed $sensor) {
     ...
   }

   or;

   my $state = $sensor->state( );

 Owfs_Item can be used as a baseclass and extended for specific one wire devices.
 For example, refer to package Owfs_DS2450 which describes a one wire A/D device.
 Extended devices will have different API routines and will typically not use
 the set/get methods.

=cut

# TODO
# maintain inventory
# dump inventory
# inventory of all items, not just those requested
# table A

#=======================================================================================
#
# Generic Owfs_Item
#
# Owfs_Item should handle any Owfs device, and provides access to any individual field.
#
#=======================================================================================

use Timer;
use Socket_Item;

package Owfs_Item;
use strict;

@Owfs_Item::ISA = ('Generic_Item');

our (%objects_by_id);    # database of all discovered objects by id
our $socket;             # single Socket_Item which serves all Owfs_Item objects
our @queue;    # Queue of commands for owserver, commands handled one at a time
our $socket_state    = 0;    # State variable for handling socket interface
our $socket_inactive = 0;    # State variable for handling socket interface

###################################################################################
# Static variables used for owserver interface
###################################################################################

our $msg_read     = 2;       # Command codes for owserver interface
our $msg_write    = 3;
our $msg_dir      = 4;
our $msg_presence = 6;
our $msg_dirall   = 7;
our $msg_get      = 8;

our $persistence_bit = 0x04;

# PresenceCheck, Return bus list,  and apply aliases
our $default_sg    = 0x100 + 0x2 + 0x8;
our $default_block = 4096;

our $tempscale = 0;
our $addr      = "";
TEMPSCALE: {
    $tempscale = 0x00000, last TEMPSCALE if $addr =~ /-C/;
    $tempscale = 0x10000, last TEMPSCALE if $addr =~ /-F/;
    $tempscale = 0x20000, last TEMPSCALE if $addr =~ /-K/;
    $tempscale = 0x30000, last TEMPSCALE if $addr =~ /-R/;
}

our $format = 0;
FORMAT: {
    $format = 0x2000000, last FORMAT if $addr =~ /-ff\.i\.c/;
    $format = 0x4000000, last FORMAT if $addr =~ /-ffi\.c/;
    $format = 0x3000000, last FORMAT if $addr =~ /-ff\.ic/;
    $format = 0x5000000, last FORMAT if $addr =~ /-ffic/;
    $format = 0x0000000, last FORMAT if $addr =~ /-ff\.i/;
    $format = 0x1000000, last FORMAT if $addr =~ /-ffi/;
    $format = 0x2000000, last FORMAT if $addr =~ /-f\.i\.c/;
    $format = 0x4000000, last FORMAT if $addr =~ /-fi\.c/;
    $format = 0x3000000, last FORMAT if $addr =~ /-f\.ic/;
    $format = 0x5000000, last FORMAT if $addr =~ /-fic/;
    $format = 0x0000000, last FORMAT if $addr =~ /-f\.i/;
    $format = 0x1000000, last FORMAT if $addr =~ /-fi/;
}

our $ON  => 'on';
our $OFF => 'off';

###################################################################################

# BaseClass constructor
sub new {
    my ( $class, $device, $location ) = @_;
    my $self = {};
    bless $self, $class;

    # Create one Socket_Item for ALL Owfs_Item devices to share
    if ( !$socket ) {
        &::MainLoop_pre_add_hook( \&Owfs_Item::_run_loop, 'persistent' );
        my $host = "localhost";
        my $port = "4304";
        $host = "$main::config_parms{owfs_host}"
          if exists $main::config_parms{owfs_host};
        $port = "$main::config_parms{owfs_port}"
          if exists $main::config_parms{owfs_port};
        &main::print_log("Owfs_Item::new Initializing host:port: $host:$port")
          if $main::Debug{owfs};
        $socket =
          new Socket_Item( undef, undef, "$host:$port", undef, 'tcp', 'raw',
            undef );
        @queue = ();
    }

    # Object identification
    $device =~ /(.*)\.(.*)/;
    $self->{device}   = $device;
    $self->{location} = $location;
    $self->{family}   = $1;
    $self->{id}       = $2;
    $self->{root}     = undef;

    # State variables for _discovery
    $self->{dir_tokens} = ();
    $self->{dir_level}  = 0;
    $self->{present}    = 0;
    $self->{failcnt}    = 0;

    # State variables for get/set operations
    $self->{path}   = undef;
    $self->{active} = 0;

    # State variables for debug
    $self->{debug} = 0;

    # Initialize object state
    $self->{state} = '';   # Will only be listed on web page if state is defined

    # Schedule item discovery
    $self->{discover_timer} = new Timer;
    $self->{discover_timer}->set( 5, sub { Owfs_Item::_discover($self); } );

    my $uom = "F";
    $uom = "$main::config_parms{owfs_uom_temp}"
      if exists $main::config_parms{owfs_uom_temp};

    my $tempscale = 0;
    if ( $uom =~ /C/ ) {
        $tempscale = 0x00000;
    }
    elsif ( $uom =~ /F/ ) {
        $tempscale = 0x10000;
    }
    elsif ( $uom =~ /K/ ) {
        $tempscale = 0x20000;
    }
    elsif ( $uom =~ /R/ ) {
        $tempscale = 0x30000;
    }

    # owserver state variables
    $self->{PERSIST} = $persistence_bit;
    $self->{SG}      = $default_sg + $tempscale + $format;
    $self->{VER}     = 0;

    return $self;
}

sub get_device {
    my ($self) = @_;
    return $self->{device};
}

sub get_location {
    my ($self) = @_;
    return $self->{location};
}

sub get_family {
    my ($self) = @_;
    return $self->{family};
}

sub get_id {
    my ($self) = @_;
    return $self->{id};
}

sub get_present {
    my ($self) = @_;
    return $self->{present};
}

sub set_key {
    my ( $self, $key, $data ) = @_;
    $self->{$key} = $data;
}

sub get_key {
    my ( $self, $key ) = @_;
    return ( $self->{$key} );
}

# This is a helper method to convert values to states
sub convert_state {
    my ( $self, $value ) = @_;
    my $state = $value;
    return $state;
}

# This is a helper method to convert states to values
sub convert_value {
    my ( $self, $state ) = @_;
    my $value = $state;
    return $value;
}

# This method is called when the response for a read request to owserver returns.
sub process_read_response {
    my ( $self, $token, $response ) = @_;
    my $device   = $self->{device};
    my $location = $self->{location};
    if ( defined $response ) {
        my $debug = $self->{debug} || $main::Debug{owfs};
        &main::print_log(
            "Owfs_Item::process_read_response device: $device location: $location token: $token response: $response"
        ) if $debug;
        my $state = $self->convert_state($response);
        if ( $state ne $self->state() ) {
            $self->SUPER::set($state);
        }
    }
}

# This method is called when the response for a write request to owserver returns.
sub process_write_response {
    my ( $self, $response, $token, $value, $set_by ) = @_;
    my $device   = $self->{device};
    my $location = $self->{location};
    my $type     = $self->isa('Owfs_Item');
    if ( defined $response ) {
        my $debug = $self->{debug} || $main::Debug{owfs};
        &main::print_log(
            "Owfs_Item::process_write_response type: $type device: $device location: $location response: $response token: $token value: $value"
        ) if $debug;
        my $state = $self->convert_state($value);
        if ( $state ne $self->state() ) {
            $self->SUPER::set( $state, $set_by );
        }
    }
}

# This method is called when the response for a directory request to owserver returns.  This method is
# used during device discovery.
sub process_dir_response {
    my ( $self, $response ) = @_;
    my $device   = $self->{device};
    my $location = $self->{location};
    my $family   = $self->{family};
    my $level    = $self->{dir_level};
    my $id       = $self->{id};
    my $path     = $self->{dir_path};
    my @tokens   = split( ',', $response );
    push @{ $self->{dir_tokens} }, @tokens;
    &main::print_log(
        "Owfs_Item::process_dir_response family: $family id: $id level: $level path: $path tokens: @tokens"
    ) if $main::Debug{owfs};

    while ( scalar( @{ $self->{dir_tokens} } ) ) {
        my $token = shift @{ $self->{dir_tokens} };
        &main::print_log(
            "Owfs_Item::process_dir_response family: $family id: $id level: $level path: $path token: $token"
        ) if $main::Debug{owfs};
        if ( $token =~ /\/([0123456789abcdefABCDEF\.]+|aux|main)$/ ) {
            my $leaf = $1;
            &main::print_log(
                "Owfs_Item::process_dir_response family: $family id: $id level: $level path: $path token: $token leaf: $leaf"
            ) if $main::Debug{owfs};
            $leaf =~ /(.+)\.(.+)$/;
            if ( ( uc $family eq uc $1 ) && ( uc $id eq uc $2 ) ) {
                $self->{root} = $path;
                if ( $self->{root} ne "/" ) {
                    $self->{root} .= "/";
                }
                $self->{path}       = $token . "/";
                $self->{present}    = 1;
                $objects_by_id{$id} = $self;
                &main::print_log(
                    "Owfs_Item::DEVICE_DISCOVERY: device: $device location: $location family: $family id: $id root: $path path: $token"
                );    # if $main::Debug{owfs};
                $self->discovered();
                return;
            }
            elsif (( $1 eq "1F" )
                || ( $leaf =~ /aux$/ )
                || ( $leaf =~ /main$/ ) )
            {
                my $val = $self->_find( $family, $id, $level + 1, $token );
            }
        }
    }
}

# This method is called to schedule a write command be sent to the owserver for the object.
sub set {
    my ( $self, $token, $value, $set_by ) = @_;
    return if ( !defined $self->{path} );
    my $path = $self->{path} . $token;
    my $debug = $self->{debug} || $main::Debug{owfs};
    $value = $self->convert_value($value);
    &main::print_log("Owfs_Item::set path: $path value: $value") if $debug;
    my $path_length = length($path) + 1;

    #$value .= ' ';
    my $value_length = length($value);
    my $payload =
      pack( 'Z' . $path_length . 'A' . $value_length, $path, $value );
    $self->_ToServer(
        $path,                $token,     $value,        $set_by,
        length($payload) + 1, $msg_write, $value_length, 0,
        $payload
    );
}

# This method is called to schedule a read command be sent to the owserver for the object.
sub get {
    my ( $self, $token ) = @_;
    return if ( !defined $self->{path} );
    my $path = $self->{path} . $token;
    &main::print_log("Owfs_Item::get path: $path") if $main::Debug{owfs};
    $self->_ToServer( $path, $token, 0, 0, length($path) + 1,
        $msg_read, $default_block, 0, $path );
}

# This method is called to schedule a directory command be sent to the owserver for the object.
# This method is used for item discovery.
sub _dir {
    my ( $self, $path ) = @_;

    # new msg_dirall method -- single packet
    &main::print_log("Owfs_Item::dir path: $path") if $main::Debug{owfs};
    $self->{dir_path} = $path;
    $self->_ToServer( $path, 0, 0, 0, length($path) + 1,
        $msg_dirall, $default_block, 0, $path );
}

# This method is called to schedule a write command be sent to the owserver for the object.
# The path used will be the device root instead of the device itself.  If the $token value
# is preceeded with a "/", then the token value will be used as a raw path.
sub _set_root {
    my ( $self, $token, $value, $set_by ) = @_;
    my $root = $self->{root};
    return if ( !defined $root );
    my $path = $self->{root} . $token;
    if ( $token =~ /^\// ) {
        $path = $token;
    }
    &main::print_log(
        "Owfs_Item::_set_root token: $token root: $root path: $path value: $value"
    ) if $main::Debug{owfs};
    my $path_length = length($path) + 1;

    #$value .= ' ';
    my $value_length = length($value);
    my $payload =
      pack( 'Z' . $path_length . 'A' . $value_length, $path, $value );
    $self->_ToServer(
        $path,                $token,     $value,        $set_by,
        length($payload) + 1, $msg_write, $value_length, 0,
        $payload
    );
}

# This method is called to schedule a read command be sent to the owserver for the object.
# The path used will be the device root instead of the device itself.  If the $token value
# is preceeded with a "/", then the token value will be used as a raw path.
sub _get_root {
    my ( $self, $token ) = @_;
    my $root = $self->{root};
    return if ( !defined $root );
    my $path = $self->{root} . $token;
    &main::print_log("Owfs_Item::_get_root path: $path") if $main::Debug{owfs};
    $self->_ToServer( $path, $token, 0, 0, length($path) + 1,
        $msg_read, $default_block, 0, $path );
}

# This method is used to search the one-wire tree for the specific object as defined
# by the $device passed during construction.
sub _discover {
    my ($self)   = @_;
    my $device   = $self->{device};
    my $location = $self->{location};
    my $family   = $self->{family};
    my $id       = $self->{id};
    my $path     = $self->{path};
    &main::print_log("Owfs_Item::_discover family: $family id: $id path: $path")
      if $main::Debug{owfs};
    return if ( defined $self->{path} );

    if ( !$self->{active} ) {
        $self->_find( $family, $id, 0, "/" );
    }
    if ( !$self->get_present() ) {
        $self->{discover_timer}->set( 5, sub { Owfs_Item::_discover($self); } );
    }
}

# This method is called whenever the object has been discovered.  Useful for initialization.
sub discovered {
    my ($self) = @_;
}

# This method is part of _discover.  It provides an interim method to allow for recursion to work.
sub _find {
    my ( $self, $family, $id, $level, $path ) = @_;
    &main::print_log("Owfs_Item::_find family: $family id: $id")
      if $main::Debug{owfs};
    $self->{dir_level} = $level;
    $self->_dir($path);
}

# This method is called when a device which had been previously discovered has been lost.  This
# method will schedule the _discover mechanism to run again.  The _lost and _discover methods
# allow for dynamic removal and insertion.
sub _lost {
    my ($self)   = @_;
    my $device   = $self->{device};
    my $location = $self->{location};
    my $family   = $self->{family};
    my $id       = $self->{id};
    my $path     = $self->{path};
    &main::print_log(
        "Owfs_Item::DEVICE_LOST: device: $device location: $location family: $family id: $id path: $path"
    );    # if $main::Debug{owfs};
    $self->{root}    = undef;
    $self->{path}    = undef;
    $self->{present} = 0;
    $self->{discover_timer}->set( 5, sub { Owfs_Item::_discover($self); } );
    $self->{failcnt} = 0;
    $self->{state}   = undef;
}

# The method can be used to dump the state of any Owfs_Item object.
sub _dump {
    my ($self) = @_;
    &main::print_log("\n")                       if $main::Debug{owfs};
    &main::print_log("path: \t\t$$self{path}")   if $main::Debug{owfs};
    &main::print_log("family: \t$$self{family}") if $main::Debug{owfs};
    &main::print_log("id: \t\t$$self{id}")       if $main::Debug{owfs};
    &main::print_log("type: \t\t$$self{type}")   if $main::Debug{owfs};
    for my $key ( sort keys %$self ) {
        next                                      if ( $key eq "root" );
        next                                      if ( $key eq "path" );
        next                                      if ( $key eq "family" );
        next                                      if ( $key eq "id" );
        next                                      if ( $key eq "type" );
        &main::print_log("$key:\t\t$$self{$key}") if $main::Debug{owfs};
    }
    &main::print_log("\n") if $main::Debug{owfs};
}

# This is a helper method to remove extra white space characters.
sub _chomp_plus {
    my ( $self, $string ) = @_;
    $string =~ s/^\s+//;
    chomp $string;
    return $string;
}

# This method is a direct port from the OWNet.pm module from owfs.  This is the lower layer interface
# to the owserver socket port.
sub _ToServer {
    my (
        $self,   $path,           $token,    $value,
        $set_by, $payload_length, $msg_type, $size,
        $offset, $payload_data
    ) = @_;
    my $f = "N6Z$payload_length";

    #$f .= 'Z'.$payload_length if ( $payload_length > 0 ) ;
    my $message = pack( $f,
        $self->{VER}, $payload_length, $msg_type,
        $self->{SG} | $self->{PERSIST},
        $size, $offset, $payload_data );
    &main::print_log(
        "Owfs_Item::_ToServer path: $path payload_length: $payload_length payload_data: $payload_data message: $message"
    ) if $main::Debug{owfs};
    my $hashref = {
        msg_type => $msg_type,
        self     => $self,
        path     => $path,
        token    => $token,
        value    => $value,
        set_by   => $set_by,
        message  => $message
    };
    push @queue, $hashref;
    $self->{active}++;
    my $num = scalar(@queue);
    &main::print_log("Owfs_Item::_ToServer num: $num") if $main::Debug{owfs};

    if ( $num > 100 ) {
        &main::print_log(
            "Owfs_Item::_ToServer high outstanding requests! num: $num");
    }
    if ( $main::Debug{owfs} && ( scalar(@queue) > 1 ) ) {
        foreach my $ref (@queue) {
            my $msg_type = $ref->{msg_type};
            my $path     = $ref->{path};
            &main::print_log(
                "Owfs_Item::_ToServer msg_type: $msg_type path: $path");
        }
    }
    if ( scalar(@queue) eq 1 ) {
        &main::print_log(
            "Owfs_Item::_ToServer path: $path message: $message sending socket...."
        ) if $main::Debug{owfs};
        start $socket unless active $socket;
        $socket->set($message);
    }
}

# This method is a direct port from the OWNet.pm module from owfs.  This is the lower layer interface
# to the owserver socket port.
sub _FromServerLow {
    my ( $self, $length_wanted ) = @_;
    my $length = length( $self->{record} );
    &main::print_log(
        "Owfs_Item::_FromServerLow length_wanted: $length_wanted length: $length"
    ) if $main::Debug{owfs};
    return '' if $length_wanted == 0;
    my $remaininglength = $length_wanted;
    my $fullread        = '';
    return if length( $self->{record} ) < $length_wanted;
    my $result = substr( $self->{record}, 0, $length_wanted );
    $self->{record} = substr( $self->{record}, $length_wanted );
    return $result;
}

# This method is a direct port from the OWNet.pm module from owfs.  This is the lower layer interface
# to the owserver socket port.
sub _FromServer {
    my ($self) = @_;
    my ( $version, $payload_length, $return_status, $sg, $size, $offset,
        $payload_data );
    while ( active $socket) {
        &main::print_log("Owfs_Item::_FromServer socket_state: $socket_state")
          if $main::Debug{owfs};
        if ( $socket_state == 0 ) {
            do {
                my $r = _FromServerLow( $self, 24 );
                if ( !defined $r ) {
                    &main::print_log(
                        "Owfs_Item::_FromServer Trouble getting header")
                      if $main::Debug{owfs};
                    return;
                }
                (
                    $version, $payload_length, $return_status, $sg, $size,
                    $offset
                ) = unpack( 'N6', $r );
                my @things = (
                    $version, $payload_length, $return_status, $sg, $size,
                    $offset
                );
                &main::print_log("Owfs_Item::_FromServer things: @things")
                  if $main::Debug{owfs};

                # returns unsigned (though originals signed
                # assume anything above 66000 is an error
                if ( $return_status > 66000 ) {
                    &main::print_log(
                        "Owfs_Item::_FromServer Trouble getting payload")
                      if $main::Debug{owfs};
                    return ( $version, $payload_length, $return_status, $sg,
                        $size, $offset, $payload_data );
                }
            } while ( $payload_length > 66000 );
            $socket_state = 1;
        }
        else {
            $payload_data = $self->_FromServerLow($payload_length);
            if ( !defined $payload_data ) {
                &main::print_log(
                    "Owfs_Item::_FromServer Trouble getting payload")
                  if $main::Debug{owfs};
                return;
            }
            $payload_data = substr( $payload_data, 0, $size );
            $socket_state = 0;
            return ( $version, $payload_length, $return_status, $sg, $size,
                $offset, $payload_data );
        }
    }
}

# This method runs one during the misterhouse main loop.  Its purpose is to handle the return responses
# from the Socket_Item attached to the owserver.  The results are dispatched back to the objects using
# the process_write/read/dir_response methods.  After each response is handled by the object, the next
# command will be popped from the queue and sent to owserver.  The owserver interface is only given
# one command at a time to process.
sub _run_loop {

    # State Machine
    return if !scalar(@queue);

    my $hashref  = $queue[0];
    my $self     = $hashref->{self};
    my $msg_type = $hashref->{msg_type};
    my $path     = $hashref->{path};
    my $token    = $hashref->{token};
    my $value    = $hashref->{value};
    my $set_by   = $hashref->{set_by};
    my $device   = $self->{device};
    my $location = $self->{location};
    my $popped   = 0;
    my $active   = 0;

    # Detect state change from inactive to active
    if ( $socket->inactive_now() ) {
        $socket_inactive = 1;
        $socket_state    = 0;
        &main::print_log("Owfs_Item::_run_loop socket INACTIVE")
          if $main::Debug{owfs};
    }

    if ( $socket->active_now() ) {
        $socket_state = 0;
        if ($socket_inactive) {
            $active = 1;
        }
        $socket_inactive = 0;
        &main::print_log("Owfs_Item::_run_loop socket ACTIVE")
          if $main::Debug{owfs};
    }

    start $socket unless active $socket;

    # Read Response
    if ( $msg_type eq $msg_read ) {
        if ( my $record = said $socket) {
            $self->{record} .= $record;
            my $len1 = length($record);
            my $len2 = length( $self->{record} );
            &main::print_log("Owfs_Item::_run_loop len1: $len1 len2: $len2")
              if $main::Debug{owfs};
            my @response = _FromServer($self);
            if ( !@response ) {
                &main::print_log(
                    "Owfs_Item::_run_loop msg_type: $msg_type path: $path EMPTY"
                ) if $main::Debug{owfs};
            }
            else {
                if ( $response[2] > 66000 ) {
                    &main::print_log(
                        "Owfs_Item::_run_loop read msg_type: $msg_type path: $path ERROR response: $response[2]"
                    );    # if $main::Debug{owfs};
                    $self->{failcnt}++;
                    if ( $self->{failcnt} >= 5 ) {
                        $self->_lost();
                    }
                    $self->process_read_response();
                }
                else {
                    # process response
                    &main::print_log(
                        "Owfs_Item::_run_loop msg_type: $msg_type path: $path response: $response[6]"
                    ) if $main::Debug{owfs};
                    $self->{failcnt} = 0;
                    $self->process_read_response( $token, $response[6] );
                }
                shift @queue;
                $popped = 1;
            }
        }
    }

    # Write Response
    elsif ( $msg_type eq $msg_write ) {
        if ( my $record = said $socket) {
            $self->{record} .= $record;
            my $len1 = length($record);
            my $len2 = length( $self->{record} );
            &main::print_log("Owfs_Item::_run_loop len1: $len1 len2: $len2")
              if $main::Debug{owfs};
            my @response = _FromServer($self);
            if ( !@response ) {
                &main::print_log(
                    "Owfs_Item::_run_loop msg_type: $msg_type path: $path EMPTY"
                ) if $main::Debug{owfs};
            }
            else {
                if ( $response[2] > 66000 ) {
                    &main::print_log(
                        "Owfs_Item::_run_loop write msg_type: $msg_type path: $path ERROR response: $response[2]"
                    );    # if $main::Debug{owfs};
                    $self->{failcnt}++;
                    if ( $self->{failcnt} >= 5 ) {
                        $self->_lost();
                    }
                    $self->process_write_response();
                }
                else {
                    # process response
                    &main::print_log(
                        "Owfs_Item::_run_loop msg_type: $msg_type path: $path response: $response[2]"
                    ) if $main::Debug{owfs};
                    $self->{failcnt} = 0;
                    $self->process_write_response( ( $response[2] >= 0 ),
                        $token, $value, $set_by );
                }
                shift @queue;
                $popped = 1;
            }
        }
    }

    # Dirall Response
    elsif ( $msg_type eq $msg_dirall ) {
        if ( my $record = said $socket) {
            $self->{record} .= $record;
            my @response = _FromServer($self);
            if ( !@response ) {
                &main::print_log(
                    "Owfs_Item::_run_loop msg_type: $msg_type path: $path EMPTY"
                ) if $main::Debug{owfs};
            }
            else {
                if ( $response[2] > 66000 ) {
                    &main::print_log(
                        "Owfs_Item::_run_loop dirall msg_type: $msg_type path: $path ERROR response: $response[2]"
                    );    # if $main::Debug{owfs};
                    $self->{failcnt}++;
                    if ( $self->{failcnt} >= 5 ) {
                        $self->_lost();
                    }
                    $self->process_dir_response();
                }
                else {
                    # process response
                    &main::print_log(
                        "Owfs_Item::_run_loop msg_type: $msg_type path: $path response: $response[6]"
                    ) if $main::Debug{owfs};
                    $self->{failcnt} = 0;
                    $self->process_dir_response( $response[6] );
                }
                shift @queue;
                $popped = 1;
            }
        }
    }

    # Dir response
    elsif ( $msg_type eq $msg_dir ) {
        if ( my $record = said $socket) {
            $self->{record} .= $record;
            my @response = _FromServer($self);
            if ( !@response ) {
                &main::print_log(
                    "Owfs_Item::_run_loop msg_type: $msg_type path: $path EMPTY"
                ) if $main::Debug{owfs};
            }
            else {
                if ( $response[2] > 66000 ) {
                    &main::print_log(
                        "Owfs_Item::_run_loop msg_dir msg_type: $msg_type path: $path ERROR response: $response[2]"
                    );    # if $main::Debug{owfs};
                    $self->{failcnt}++;
                    if ( $self->{failcnt} >= 5 ) {
                        $self->_lost();
                    }
                    $self->process_dir_response();
                }
                else {
                    $self->{failcnt} = 0;
                    if ( $response[1] == 0 ) {    # last null packet
                        &main::print_log(
                            "Owfs_Item::_run_loop msg_type: $msg_type path: $path response: $response[6]"
                        ) if $main::Debug{owfs};
                        $self->process_dir_response(
                            substr( $self->{dirlist}, 1 ) );
                        shift @queue;
                        $popped = 1;
                    }
                    else {
                        &main::print_log(
                            "Owfs_Item::_run_loop msg_type: $msg_type path: $path response: $response[6]"
                        ) if $main::Debug{owfs};
                        $self->{dirlist} .= ',' . $response[6];
                    }
                }
            }
        }
    }

    # Handle Unknown response
    else {
        &main::print_log("Owfs_Item::_run_loop unknown msg_type: $msg_type")
          if $main::Debug{owfs};
        if ( my $record = said $socket) {
            $self->{record} .= $record;
            my @response = _FromServer($self);
            if ( !@response ) {
                &main::print_log(
                    "Owfs_Item::_run_loop msg_type: $msg_type path: $path EMPTY"
                ) if $main::Debug{owfs};
            }
            else {
                if ( $response[2] > 66000 ) {
                    &main::print_log(
                        "Owfs_Item::_run_loop unknown msg_type: $msg_type path: $path ERROR response: $response[2]"
                    );    # if $main::Debug{owfs};
                }
                else {
                    &main::print_log(
                        "Owfs_Item::_run_loop msg_type: $msg_type (UNKNOWN) path: $path"
                    ) if $main::Debug{owfs};
                }
                shift @queue;
                $popped = 1;
            }
        }
    }

    if ($popped) {
        if ( $self->{active} > 0 ) {
            $self->{active}--;
        }
    }

    if ( ( $popped or $active ) and scalar(@queue) ) {
        my $hashref  = $queue[0];
        my $msg_type = $hashref->{msg_type};
        my $path     = $hashref->{path};
        my $message  = $hashref->{message};
        &main::print_log(
            "Owfs_Item::run_loop path: $path message: $message sending socket...."
        ) if $main::Debug{owfs};
        start $socket unless active $socket;
        $socket->set($message);
    }
}

#=======================================================================================
#
# Owfs_Switch
#
# This package is a common base class for many OWFS Switch like devices which
# have $PIO, Latch, and Sense.
#
#=======================================================================================

=begin comment

Usage:

 $sensor = new Owfs_Switch ( "<device_id>", <location>, <channel>, <interval>, <mode> );

 <device_id> - of the form family.address; identifies the one-wire device
 <location>  - ASCII string identifier providing a useful name for device_id
 <channel>   - "0", "1", "2", "3", "4", "5", "6", "7"
 <mode>      - Identifies what is stored in <state> 0: $PIO (Relay) 1: Sense 2: Latch
 <interval>  - Optional (defaults to 1).  Number of seconds between input samples.

 Examples:

 # RELAY
 my $relay = new Owfs_Switch ( "20.DB2506000000", "Some Relay", "0", 0 );
 $relay->set_pio("1");          # Turn on Relay
 $relay->set_pio("0");          # Turn off Relay
 my $state = $state->state( );  # 0: Relay off 1: Relay on

 # $LATCH
 my $doorbell = new Owfs_Switch ( "20.DB2506000000", "Front Door Bell", "1", 1 );
 if (my $state = said $doorbell) {
    print_log ("notice,,, someone is at the front door");
    speak (rooms=>"all", text=> "notice,,, someone is at the front door");
 }

 or

 if (my $state = state_now $doorbell) {
    print_log ("notice,,, someone is at the front door");
    speak (rooms=>"all", text=> "notice,,, someone is at the front door");
 }

 or

 if (my $state = state_changed $doorbell) {
    print_log ("notice,,, someone is at the front door");
    speak (rooms=>"all", text=> "notice,,, someone is at the front door");
 }

=cut

package Owfs_Switch;
use strict;

our $ON    = 'on';
our $OFF   = 'off';
our $PIO   = 0;
our $SENSE = 1;
our $LATCH = 2;

@Owfs_Switch::ISA = ('Owfs_Item');

our (%latch_mask);
our (%latch_store);

sub new {
    my ( $class, $device, $location, $channel, $interval, $mode ) = @_;
    my $self = new Owfs_Item( $device, $location );
    bless $self, $class;

    $self->{channel} = undef;
    if ( defined $channel ) {
        $self->{channel} = $channel;
    }
    $self->{interval} = 1;
    if ( defined $interval && ( $interval >= 1 ) ) {
        $self->{interval} = $interval;
    }
    $self->{mode} = $PIO;
    if ( defined $mode ) {
        $self->{mode} = $mode;
    }
    @{ $$self{states} } = ( 'on', 'off' );
    $self->{pio}         = undef;
    $self->{latch}       = 0;
    $self->{sensed}      = undef;
    $self->{pio_state}   = undef;
    $self->{pend_set_by} = undef;

    $self->restore_data( 'pio_state', 'pend_set_by' );

    $latch_store{$device} = 0;
    if ( !exists $latch_mask{$device} ) {
        $latch_mask{$device} = 0;
    }
    if ( defined $channel ) {
        $latch_mask{$device} |= ( 1 << $channel );
    }

    $self->{loop_timer} = new Timer;
    $self->{loop_timer}
      ->set( $self->{interval}, sub { Owfs_Switch::run_loop($self); } );

    &::Reload_pre_add_hook( \&Owfs_Switch::reload_hook, 1 );

    return $self;
}

sub set_interval {
    my ( $self, $interval ) = @_;
    $self->{interval} = $interval if defined $interval;
}

sub get_interval {
    my ($self) = @_;
    return $self->{interval};
}

sub set {
    my ( $self, $state, $set_by ) = @_;
    my $mode     = $self->{mode};
    my $debug    = $self->{debug} || $main::Debug{owfs};
    my $device   = $self->{device};
    my $location = $self->{location};
    my $channel  = $self->{channel};
    &main::print_log("Owfs_Switch::set mode: $mode state: $state") if $debug;
    if ( $mode == $PIO ) {
        my $value = $self->convert_value($state);
        $state = $self->convert_state($value);
        if ( ( $state eq $ON ) || ( $state eq $OFF ) ) {
            &main::print_log(
                "Owfs_Switch::set mode: $mode device: $device location: $location channel: $channel state: $state"
            ) if $debug;
            $self->{pio_state}   = $state;
            $self->{pend_set_by} = $set_by;

            # Let's just do it now!
            if ( $state ne $self->state() ) {
                $self->run_loop();
            }
        }
        else {
            &main::print_log(
                "Owfs_Switch::set ERROR mode: $mode Unknown state: $state")
              ;    # if $debug;
        }
    }
}

sub get {
    my ($self) = @_;
    return $self->state();
}

sub set_pio {
    my ( $self, $value ) = @_;
    $self->set($value);
}

sub get_pio {
    my ($self) = @_;
    return unless $self->get_present();
    return $self->{pio};
}

sub get_latch {
    my ($self)  = @_;
    my $device  = $self->{device};
    my $channel = $self->{channel};
    $channel = 0 if ( !defined $channel );
    return unless $self->get_present();
    return $self->convert_state( $self->{latch} );
}

sub get_sensed {
    my ($self) = @_;
    return unless $self->get_present();
    return $self->{sensed};
}

sub set_debug {
    my ( $self, $debug ) = @_;
    $self->{debug} = $debug;
}

# This method is called whenever the object has been discovered.  Useful for initialization.
sub discovered {
    my ($self)  = @_;
    my $channel = $self->{channel};
    my $mode    = $self->{mode};
    if ( $mode != $PIO ) {
        my $pio = "PIO";
        if ( defined $channel ) {
            $pio .= ".$channel";
        }
        &main::print_log(
            "Owfs_Item::discovered mode: $mode pio: $pio setting $PIO to 0")
          if $main::Debug{owfs};
        $self->SUPER::set( $pio, $OFF );
    }
}

# This is a helper method to convert states to 'on' and 'off'
sub convert_state {
    my ( $self, $value ) = @_;
    my $device   = $self->{device};
    my $location = $self->{location};
    my $channel  = $self->{channel};
    my $state    = $value;
    $state = $ON  if ( $value == 1 );
    $state = $OFF if ( $value == 0 );
    $state = $ON  if ( $value eq 'yes' );
    $state = $OFF if ( $value eq 'no' );
    if ( ( $state ne $ON ) && ( $state ne $OFF ) ) {
        my $debug = $self->{debug} || $main::Debug{owfs};
        &main::print_log(
            "Owfs_Item::convert_state Unknown state device: $device location: $location channel: $channel value: $value state: $state"
        ) if $debug;
    }
    return $state;
}

# This is a helper method to convert values to 0 and 1
sub convert_value {
    my ( $self, $state ) = @_;
    my $device   = $self->{device};
    my $location = $self->{location};
    my $channel  = $self->{channel};
    my $value    = $state;
    $value = 1 if ( $state ~~ $ON );
    $value = 0 if ( $state ~~ $OFF );
    $value = 1 if ( $state ~~ main::ON );
    $value = 0 if ( $state ~~ main::OFF );
    $value = 1 if ( $state ~~ 'yes' );
    $value = 0 if ( $state ~~ 'no' );
    if ( ( $value ne 1 ) && ( $value ne 0 ) ) {
        my $debug = $self->{debug} || $main::Debug{owfs};
        &main::print_log(
            "Owfs_Item::convert_value Unknown value device: $device location: $location channel: $channel state: $state value: $value"
        ) if $debug;
    }
    return $value;
}

sub process_read_response {
    my ( $self, $token, $response ) = @_;
    my $device   = $self->{device};
    my $location = $self->{location};
    my $channel  = $self->{channel};
    my $pio      = "PIO";
    my $debug    = $self->{debug} || $main::Debug{owfs};
    if ( defined $channel ) {
        $pio .= ".$channel";
    }
    my $sensed = "sensed";
    if ( defined $channel ) {
        $sensed .= ".$channel";
    }
    my $latchstr = "latch";
    if ( defined $channel ) {
        $latchstr .= ".$channel";
    }
    my $mode = $self->{mode};
    &main::print_log(
        "Owfs_Switch::process_read_response device: $device location: $location channel: $channel mode: $mode token: $token response: $response"
    ) if $debug;
    if ( defined $response ) {
        if ( $token =~ /PIO/ ) {
            if ( $mode == $PIO ) {
                $self->SUPER::process_read_response( $token, $response );
            }
            $self->{pio} = $response;
            &main::print_log(
                "Owfs_Switch::process_read_response $device $location $channel pio: $response"
            ) if $debug;
        }
        elsif ( $token =~ /sensed/ ) {
            if ( $mode == $SENSE ) {
                $self->SUPER::process_read_response( $token, $response );
            }
            $self->{sensed} = $response;
            &main::print_log(
                "Owfs_Switch::process_read_response $device $location $channel sensed: $response"
            ) if $debug;
        }
        elsif ( $token =~ /latch/ ) {
            $latch_store{$device} |= ( $latch_mask{$device} & $response );
            my $ls      = $latch_store{$device};
            my $lm      = sprintf( "%x", $latch_mask{$device} );
            my $chanidx = $channel;
            $chanidx = 0 if ( !defined $channel );
            my $latch  = ( $latch_store{$device} >> $chanidx ) & 1;
            my $slatch = $self->{latch};
            my $state  = $self->state();
            &main::print_log(
                "Owfs_Switch::process_read_response device: $device location: $location channel: $channel mode: $mode response: $response latch: $latch slatch: $slatch ls: $ls lm: $lm chanidx: $chanidx state: $state"
            ) if $debug;

            if ( $mode == $LATCH ) {
                $self->SUPER::process_read_response( $token, $latch );
            }
            $self->{latch} = $latch;
            $latch_store{$device} &= ~( 1 << $chanidx );
            if ( $response != 0 ) {
                my $device  = $self->{device};
                my $channel = $self->{channel};
                &main::print_log(
                    "Owfs_Switch::process_read_response device: $device channel: $channel chanidx: $chanidx latchstr: $latchstr"
                ) if $debug;
                $self->SUPER::set( $latchstr, 1 );    #$response);
            }
        }
    }
    else {
        &main::print_log(
            "Owfs_Switch::process_read_response $device $location $channel ERROR response: NULL"
        );                                            # if $debug;
    }
}

sub process_write_response {
    my ( $self, $response, $token, $value, $set_by ) = @_;
    my $device   = $self->{device};
    my $location = $self->{location};
    my $channel  = $self->{channel};
    my $mode     = $self->{mode};
    my $debug    = $self->{debug} || $main::Debug{owfs};
    &main::print_log(
        "Owfs_Switch::process_write_response device: $device location: $location channel: $channel mode: $mode token: $token value: $value response: $response"
    ) if $debug;
    if ( defined $response ) {

        if ( ( $mode == $PIO ) && ( $token =~ /PIO/ ) ) {
            $self->SUPER::process_write_response( $response, $token, $value,
                $set_by );
        }
    }
}

sub reload_hook {
}

sub run_loop {
    my ($self)   = @_;
    my $device   = $self->{device};
    my $location = $self->{location};
    my $channel  = $self->{channel};
    my $pio      = "PIO";
    if ( defined $channel ) {
        $pio .= ".$channel";
    }
    my $mode      = $self->{mode};
    my $present   = $self->{present};
    my $active    = $self->{active};
    my $state     = $self->state();
    my $pio_state = $self->{pio_state};
    my $debug     = $self->{debug} || $main::Debug{owfs};
    &main::print_log(
        "Owfs_Switch::run_loop device: $device location: $location channel: $channel mode: $mode present: $present active: $active pio: $pio state: $state pio_state: $pio_state"
    ) if $debug;

    if ( ( $self->{active} == 0 ) && $self->{present} ) {
        if ( $mode == $PIO ) {
            if ( defined $pio_state and ( $state ne $pio_state ) ) {
                $self->SUPER::set( $pio, $pio_state, $self->{pend_set_by} );
                $self->{pend_set_by} = undef;
                &main::print_log(
                    "Owfs_Switch::run_loop set device: $device location: $location channel: $channel mode: $mode present: $present active: $active pio: $pio state: $state pio_state: $pio_state"
                ) if $debug;
            }
            else {
                &main::print_log(
                    "Owfs_Switch::run_loop get device: $device location: $location channel: $channel mode: $mode present: $present active: $active pio: $pio state: $state pio_state: $pio_state"
                ) if $debug;
                $self->SUPER::get($pio);
            }
        }
        elsif ( $mode == $SENSE ) {
            $self->SUPER::get("sensed.$channel");
        }
        elsif ( $mode == $LATCH ) {
            $self->SUPER::get("latch.BYTE");
        }
    }

    # reschedule the timer for next pass
    $self->{loop_timer}
      ->set( $self->{interval}, sub { Owfs_Switch::run_loop($self); } );
}

#=======================================================================================
#
# Owfs_DS18S20
#
# This package specifically handles the DS18S20 Thermometer
#
#=======================================================================================

=begin comment

 By default, the temperature unit of measure will be Celcius.  Use the owfs_uom_temp
 config_parm to control the desired temperature uom

 $main::config_parms{owfs_uom_temp}

 C Celcius
 F Fahrenheit
 K Kelvin
 R Rankine

Usage:

 $sensor = new Owfs_DS18S20 ( "<device_id>", <location>, <interval> );

 <device_id> - of the form family.address; identifies the one-wire device
 <location>  - ASCII string identifier providing a useful name for device_id
 <interval>  - Optional (defaults to 10).  Number of seconds between measurements.

 Example:

 $ds18S20 = new Owfs_DS18S20 ( "10.DB2506000000", "Living Room", 2 );

 my $temperature = get_temperature $ds18S20;

 or;

 if (my $temperature = said $sensor) {
   ...
 }

 or;

 if (my $temperature = state_now $sensor) {
   ...
 }

 if (my $temperature = state_changed $sensor) {
   ...
 }

 or;

 my $temperature = $sensor->state( );

=cut

package Owfs_DS18S20;
use strict;

@Owfs_DS18S20::ISA = ('Owfs_Item');

our @clients = ();
our $index   = 0;
our $timer   = undef;

sub new {
    my ( $class, $device, $location, $interval ) = @_;
    my $self = new Owfs_Item( $device, $location );
    bless $self, $class;

    $self->{interval} = 10;
    if ( defined $interval && ( $interval > 1 ) ) {
        $self->{interval} = $interval;
    }
    $self->{temperature} = undef;

    if ( !defined $timer ) {
        &::Reload_pre_add_hook( \&Owfs_DS18S20::reload_hook, 1 );
        $index = 0;
        $timer = new Timer;
    }

    if ( $timer->inactive() ) {
        $timer->set( $self->{interval}, sub { &Owfs_DS18S20::run_loop } );
    }

    push( @clients, $self );

    if ( $self->{interval} < $clients[0]->get_interval() ) {
        $clients[0]->set_interval( $self->{interval} );
    }

    return $self;
}

sub set_interval {
    my ( $self, $interval ) = @_;
    $self->{interval} = $interval if defined $interval;
}

sub get_interval {
    my ($self) = @_;
    return $self->{interval};
}

sub set {
    my ($self) = @_;
}

sub get {
    my ($self) = @_;
    return $self->state();
}

sub get_temperature {
    my ($self) = @_;
    return $self->state();
}

sub process_read_response {
    my ( $self, $token, $temperature ) = @_;
    my $device   = $self->{device};
    my $location = $self->{device};
    if ( defined $temperature ) {
        $temperature = $self->_chomp_plus($temperature);
        if ( $temperature =~ /^[-]?\d+(?:[.]\d+)?$/ ) {
            if ( $temperature ne $self->state() ) {
                $self->SUPER::process_read_response( $token, $temperature );
            }
            $self->{temperature} = $temperature;
            if ( $main::Debug{owfs} ) {
                &main::print_log(
                    "Owfs_DS18S20::process_read_response $device $location temperature: $temperature"
                ) if $main::Debug{owfs};
            }
        }
    }
    else {
        &main::print_log(
            "Owfs_DS18S20::process_read_response $device $location temperature: ERROR"
        );    # if $main::Debug{owfs};
    }
}

# This method is called when the response for a write request to owserver returns.
sub process_write_response {
    my ( $self, $response, $token, $value, $set_by ) = @_;
    my $device   = $self->{device};
    my $location = $self->{location};
    &main::print_log(
        "Owfs_DS18S20::process_write_response $device $location response: $response token: $token value: $value"
    ) if $main::Debug{owfs};
}

sub reload_hook {
    @clients = ();
    &main::print_log("Owfs_DS18S20::reload_hook") if $main::Debug{owfs};
    $timer->set( 10, sub { &Owfs_DS18S20::run_loop } );
}

sub run_loop {

    # exit if we don't have any clients.
    return unless scalar(@clients);

    # issue simultaneous to start a conversion
    if ( $index == 0 ) {
        my $self = $clients[0];
        &main::print_log("Owfs_DS18S20::run_loop index: $index simultaneous")
          if $main::Debug{owfs};

        #$self->_set_root ( "simultaneous/temperature", 1);
    }
    else {
        my $self = $clients[ $index - 1 ];
        if ( ( $self->{active} == 0 ) && $self->{present} ) {
            $self->SUPER::get("temperature");
        }
    }

    # udpate the index
    $index += 1;
    if ( $index > @clients ) {
        $index = 0;
    }

    # reschedule the timer for next pass
    $timer->set( $clients[0]->get_interval(), sub { &Owfs_DS18S20::run_loop } );
}

#=======================================================================================
#
# Owfs_DS2405
#
# This package specifically handles the DS2405 Relay / IO controller.
#
#=======================================================================================

=begin comment

Usage:

 $sensor = new Owfs_DS2405 ( "<device_id>", <location>, <interval> );

 <device_id> - of the form family.address; identifies the one-wire device
 <location>  - ASCII string identifier providing a useful name for device_id
 <interval>  - Optional (defaults to 2).  Number of seconds between reads of sensed.

 Examples:

 my $relay = new Owfs_DS2405_pio ( "20.DB2506000000", "Some Relay" );

 # Turn on relay
 $relay->set_pio("1");

 # Turn off relay
 $relay->set_pio("0");

 # Detect input transition
 my $doorbell = new Owfs_DS2405_sense ( "20.DB2506000000", "Front Door Bell", 1 );
 if ($doorbell->state_now( )) {
     print_log ("notice,,, someone is at the front door");
     speak (rooms=>"all", text=> "notice,,, someone is at the front door");
 }

=cut

package Owfs_DS2405;
use strict;

our $ON    = 'on';
our $OFF   = 'off';
our $PIO   = 0;
our $SENSE = 1;
our $LATCH = 2;

@Owfs_DS2405::ISA = ('Owfs_DS2405_pio');

sub new {
    my ( $class, $device, $location, $interval ) = @_;
    my $self = new Owfs_DS2405_pio( $device, $location, $interval );
    bless $self, $class;
    return $self;
}

@Owfs_DS2405_pio::ISA = ('Owfs_Switch');

sub new {
    my ( $class, $device, $location, $interval ) = @_;
    my $self = new Owfs_Switch( $device, $location, undef, $interval, $PIO );
    bless $self, $class;
    return $self;
}

@Owfs_DS2405_sense::ISA = ('Owfs_Switch');

sub new {
    my ( $class, $device, $location, $interval ) = @_;
    my $self = new Owfs_Switch( $device, $location, undef, $interval, $SENSE );
    bless $self, $class;
    return $self;
}

#=======================================================================================
#
# Owfs_DS2408
#
# This package specifically handles the DS2408 Relay / IO controller.
#
#=======================================================================================

=begin comment

Usage:

 $sensor = new Owfs_DS2408 ( "<device_id>", <location>, <channel>, <interval> );

 <device_id> - of the form family.address; identifies the one-wire device
 <location>  - ASCII string identifier providing a useful name for device_id
 <channel>   - "0", "1", "2", "3", "4", "5", "6", "7"
 <interval>  - Optional (defaults to 2).  Number of seconds between input samples.

 Examples:

 # RELAY
 my $relay = new Owfs_DS2408_pio ( "20.DB2506000000", "Some Relay", "0", 1 );
 $relay->set_pio("1");          # Turn on Relay
 $relay->set_pio("0");          # Turn off Relay
 my $state = $state->state( );  # 0: Relay off 1: Relay on

 # $LATCH
 my $doorbell = new Owfs_DS2408_latch ( "20.DB2506000000", "Front Door Bell", "1", 1 );
 if (my $state = said $doorbell) {
    print_log ("notice,,, someone is at the front door");
    speak (rooms=>"all", text=> "notice,,, someone is at the front door");
 }

 or

 if (my $state = state_now $doorbell) {
    print_log ("notice,,, someone is at the front door");
    speak (rooms=>"all", text=> "notice,,, someone is at the front door");
 }

 or

 if (my $state = state_changed $doorbell) {
    print_log ("notice,,, someone is at the front door");
    speak (rooms=>"all", text=> "notice,,, someone is at the front door");
 }

=cut

package Owfs_DS2408;
use strict;

our $ON    = 'on';
our $OFF   = 'off';
our $PIO   = 0;
our $SENSE = 1;
our $LATCH = 2;

@Owfs_DS2408::ISA = ('Owfs_DS2408_pio');

sub new {
    my ( $class, $device, $location, $channel, $interval ) = @_;
    my $self = new Owfs_DS2408_pio( $device, $location, $channel, $interval );

    #bless $self,$class;
    return $self;
}

package Owfs_DS2408_pio;
use strict;

our $ON    = 'on';
our $OFF   = 'off';
our $PIO   = 0;
our $SENSE = 1;
our $LATCH = 2;

@Owfs_DS2408_pio::ISA = ('Owfs_Switch');

sub new {
    my ( $class, $device, $location, $channel, $interval ) = @_;
    if ( ( $channel < 0 ) || ( $channel > 7 ) ) {
        &main::print_log(
            "Owfs_DS2408::new ERROR channel ($channel) out of range!");
    }
    my $self = new Owfs_Switch( $device, $location, $channel, $interval, $PIO );

    #bless $self,$class;
    return $self;
}

package Owfs_DS2408_sense;
use strict;

our $ON    = 'on';
our $OFF   = 'off';
our $PIO   = 0;
our $SENSE = 1;
our $LATCH = 2;

@Owfs_DS2408_sense::ISA = ('Owfs_Switch');

sub new {
    my ( $class, $device, $location, $channel, $interval ) = @_;
    if ( ( $channel < 0 ) || ( $channel > 7 ) ) {
        &main::print_log(
            "Owfs_DS2408::new ERROR channel ($channel) out of range!");
    }
    my $self =
      new Owfs_Switch( $device, $location, $channel, $interval, $SENSE );

    #bless $self,$class;
    return $self;
}

package Owfs_DS2408_latch;
use strict;

our $ON    = 'on';
our $OFF   = 'off';
our $PIO   = 0;
our $SENSE = 1;
our $LATCH = 2;

@Owfs_DS2408_latch::ISA = ('Owfs_Switch');

sub new {
    my ( $class, $device, $location, $channel, $interval ) = @_;
    if ( ( $channel < 0 ) || ( $channel > 7 ) ) {
        &main::print_log(
            "Owfs_DS2408::new ERROR channel ($channel) out of range!");
    }
    my $self =
      new Owfs_Switch( $device, $location, $channel, $interval, $LATCH );

    #bless $self,$class;
    return $self;
}

#=======================================================================================
#
# Owfs_DS2413
#
# This package specifically handles the DS2413 Dual Channel Addressable Switch.
#
#=======================================================================================

=begin comment

Usage:

 $sensor = new Owfs_DS2413 ( "<device_id>", <location>, <channel> , <interval> );

 <device_id> - of the form family.address; identifies the one-wire device
 <location>  - ASCII string identifier providing a useful name for device_id
 <channel>   - Channel identifier, "A" or "B"
 <interval>  - Optional (defaults to 10).  Number of seconds between input samples.

 Examples:

 # RELAY
 my $relay = new Owfs_DS2413 ( "20.DB2506000000", "Some Relay", "0", 0 );
 $relay->set( 1 ); # Turn on Relay
 $relay->set( 0 ); # Turn off Relay
 my $state = $state->state( );  # 0: Relay off 1: Relay on

 # $SENSE
 my $doorbell = new Owfs_DS2413_sense ( "20.DB2506000000", "Front Door Bell", "1", 1 );
 if (my $state = said $doorbell) {
    print_log ("notice,,, someone is at the front door");
    speak (rooms=>"all", text=> "notice,,, someone is at the front door");
 }

 or

 if (my $state = state_now $doorbell) {
    print_log ("notice,,, someone is at the front door");
    speak (rooms=>"all", text=> "notice,,, someone is at the front door");
 }

 or

 if (my $state = state_changed $doorbell) {
    print_log ("notice,,, someone is at the front door");
    speak (rooms=>"all", text=> "notice,,, someone is at the front door");
 }

 or

 my $state = $doorbell->state( )

=cut

package Owfs_DS2413;
use strict;

our $ON    = 'on';
our $OFF   = 'off';
our $PIO   = 0;
our $SENSE = 1;
our $LATCH = 2;

@Owfs_DS2413::ISA = ('Owfs_DS2413_pio');

sub new {
    my ( $class, $device, $location, $channel, $interval ) = @_;
    my $self = new Owfs_DS2413_pio( $device, $location, $channel, $interval );
    bless $self, $class;
    return $self;
}

package Owfs_DS2413_pio;
use strict;

our $ON    = 'on';
our $OFF   = 'off';
our $PIO   = 0;
our $SENSE = 1;
our $LATCH = 2;

@Owfs_DS2413_pio::ISA = ('Owfs_Switch');

sub new {
    my ( $class, $device, $location, $channel, $interval ) = @_;
    if ( ( $channel < 0 ) || ( $channel > 1 ) ) {
        &main::print_log(
            "Owfs_DS2413::new ERROR channel ($channel) out of range!");
    }
    my $self = new Owfs_Switch( $device, $location, $channel, $interval, $PIO );
    bless $self, $class;
    return $self;
}

package Owfs_DS2413_sense;
use strict;

our $ON    = 'on';
our $OFF   = 'off';
our $PIO   = 0;
our $SENSE = 1;
our $LATCH = 2;

@Owfs_DS2413_sense::ISA = ('Owfs_Switch');

sub new {
    my ( $class, $device, $location, $channel, $interval ) = @_;
    if ( ( $channel < 0 ) || ( $channel > 1 ) ) {
        &main::print_log(
            "Owfs_DS2413::new ERROR channel ($channel) out of range!");
    }
    my $self =
      new Owfs_Switch( $device, $location, $channel, $interval, $SENSE );
    bless $self, $class;
    return $self;
}

#=======================================================================================
#
# Owfs_DS2450
#
# This package specifically handles the DS2450 A/D Converter.
#
#=======================================================================================

=begin comment

Usage:

 $sensor = new Owfs_DS2450 ( "<device_id>", <location>, <channel>, <interval> );

 <device_id> - of the form family.address; identifies the one-wire device
 <location>  - ASCII string identifier providing a useful name for device_id
 <channel>   - "A", "B", "C", or "D"
 <interval>  - Optional (defaults to 10).  Number of seconds between measurements.

 Example:

 $ds2450 = new Owfs_DS2450 ( "20.DB2506000000", "Furnace Sensor", "A" );

 if (my $voltage = said $ds2450) {
   ...
 }

 or;

 if (my $voltage = state_now $ds2450) {
   ...
 }

 if (my $voltage = state_changed $ds2450) {
   ...
 }

 or;

 my $voltage = $ds2450->state( );

=cut

package Owfs_DS2450;
use strict;

@Owfs_DS2450::ISA = ('Owfs_Item');

our @clients = ();
our $index   = 0;
our $timer   = undef;

our $ON  = 'on';
our $OFF = 'off';

sub new {
    my ( $class, $device, $location, $channel, $interval ) = @_;
    my $self = new Owfs_Item( $device, $location );
    bless $self, $class;

    $self->{channel}  = $channel;
    $self->{interval} = 10;
    if ( defined $interval && ( $interval > 1 ) ) {
        $self->{interval} = $interval if defined $interval;
    }
    $self->{voltage} = undef;

    if ( !defined $timer ) {
        &::Reload_pre_add_hook( \&Owfs_DS2450::reload_hook, 1 );
        @clients = ();
        $index   = 0;
        $timer   = new Timer;
    }
    if ( $timer->inactive() ) {
        $timer->set( $self->{interval}, sub { &Owfs_DS2450::run_loop } );
    }

    push( @clients, $self );

    if ( $self->{interval} < $clients[0]->get_interval() ) {
        $clients[0]->set_interval( $self->{interval} );
    }

    return $self;
}

sub set_interval {
    my ( $self, $interval ) = @_;
    $self->{interval} = $interval if defined $interval;
}

sub get_interval {
    my ($self) = @_;
    return $self->{interval};
}

sub set {
    my ($self) = @_;
}

sub get {
    my ($self) = @_;
    return $self->state();
}

sub get_voltage {
    my ($self) = @_;
    return unless $self->get_present();
    return $self->state();
}

# This method is called when the read request is returned from owserver.
sub process_read_response {
    my ( $self, $token, $voltage ) = @_;
    my $device   = $self->{device};
    my $location = $self->{location};
    my $channel  = $self->{channel};
    if ( defined $voltage ) {
        $voltage = $self->_chomp_plus($voltage);
        if ( $voltage ne $self->state() ) {
            $self->SUPER::process_read_response( $token, $voltage );
        }
        $self->{voltage} = $voltage;
        &main::print_log(
            "Owfs_DS2450::process_read_response $device $location $channel voltage: $voltage"
        ) if $main::Debug{owfs};
    }
    else {
        &main::print_log(
            "Owfs_DS2450::process_read_response $device $location $channel ERROR"
        );    # if $main::Debug{owfs};
    }
}

# This method is called when the response for a write request to owserver returns.
sub process_write_response {
    my ( $self, $response, $token, $value, $set_by ) = @_;
    my $device   = $self->{device};
    my $location = $self->{location};
    &main::print_log(
        "Owfs_DS2450::process_write_response $device $location response: $response token: $token value: $value"
    ) if $main::Debug{owfs};
}

# This method is called whenever the object has been discovered.  Useful for initialization.
sub discovered {
    my ($self) = @_;
    my $channel = $self->{channel};
    $self->SUPER::set( "set_alarm/voltlow.$channel", "1.0" );
    $self->SUPER::set( "set_alarm/low.$channel",     "1" );
    $self->SUPER::set( "power",                      "1" );
    $self->SUPER::set( "PIO.$channel",               $ON );
}

sub reload_hook {
    @clients = ();
    &main::print_log("Owfs_DS2450::reload_hook") if $main::Debug{owfs};
    $timer->set( 10, sub { &Owfs_DS2450::run_loop } );
}

# This method runs using a timer, with an interval of interval timer.  Each
# pass of the timer will result in one A/D measurement reading.  All of the DS2450
# devices share this same timer loop.  The first iteration of the loop will execute
# a simultaneous voltage reading, to cause all A/D device to start a conversion at
# the same time.  The remaing passes are used to pick up the results from the
# simultaneous conversion.
sub run_loop {

    # exit if no clients
    return unless scalar(@clients);

    # issue simultaneous to start a conversion
    if ( $index == 0 ) {
        my $self = $clients[0];
        &main::print_log("Owfs_DS2450::run_loop $index simultaneous")
          if $main::Debug{owfs};
        $self->_set_root( "simultaneous/voltage", 1 );
    }
    else {
        my $self     = $clients[ $index - 1 ];
        my $channel  = $self->{channel};
        my $device   = $self->{device};
        my $location = $self->{location};
        my $active   = $self->{active};
        my $present  = $self->{present};
        &main::print_log(
            "Owfs_DS2450::run_loop $index $device $location channel: $channel present: $present active: $active"
        ) if $main::Debug{owfs};
        if ( ( $self->{active} == 0 ) && $self->{present} ) {
            $self->SUPER::get("volt.$channel");
        }
    }

    # udpate the index
    $index += 1;
    if ( $index > @clients ) {
        $index = 0;
    }

    # reschedule the timer for next pass
    $timer->set( $clients[0]->get_interval(), sub { &Owfs_DS2450::run_loop } );

}

1;
