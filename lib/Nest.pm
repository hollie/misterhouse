
=head1 B<Nest>

=head2 SYNOPSIS

This module allows MisterHouse to communicate with the public Nest API which 
currently allows interation with Nest Thermostats and Smoke/CO Detectors.  

=head2 CONFIGURATION

Nest uses OAuth technology to authorize access to your account.  The nice thing
is that at any point in the future, you can sign into your Nest account and 
revoke any access tokens that you have issued.

To start the authorization process, go to the following URL:
    
L<https://misterhouse-nest.appspot.com/>

Read everything on that page and follow the instructions.  At the end of the
process, the webpage will provide you with a line to add to your mh.private.ini
file.  It will be a long line! Copy the entire line and place it in your
mh.private.ini file:

  Nest_auth_token=<API token from Nest registration>

Create a Nest instance in the .mht file, or in user code:

.mht file:

  CODE, require Nest; #noloop 
  CODE, $nest = new Nest_Interface(); #noloop
  CODE, $myhouse = new Group(); #noloop
  CODE, $nest_thermo = new Nest_Thermostat('Entryway', $nest, 'f'); #noloop
  CODE, $nest_thermo_mode = new Nest_Thermo_Mode($nest_thermo); #noloop
  CODE, $nest_alarm = new Nest_Smoke_CO_Alarm('Kitchen', $nest); #noloop
  CODE, $nest_home = new Nest_Structure('Home', $nest); #noloop
  CODE, $myhouse->add($nest_thermo, $nest_thermo_mode, $nest_alarm, $nest_home); #noloop

Explanations of the parameters is contained below in the documentation for each
module.

=head2 OVERVIEW

Because this module uses the public Nest API, it should provide stable support
for a long time.  However, by relying on the public API, this module is also
limited to supplying only the features currently supported by Nest.  Currently
some features which are present on the device and the Nest website, such as
humidity, are not yet available in the API and as a result are not specifically
supported by this module.

The low level commands in this module were written with the exepectation of
future additions to the public Nest API.  The code should permit advanced users
to interact with any future additions to the API without requiring an update to
this module.

This module is broken down into a few parts: 
    
=head3 NEST_INTERFACE

This handles the interaction between the Nest API servers and MisterHouse.  
This is the object that is required.  An advanced user could interact with
the Nest API solely through this object.

=head3 NEST_GENERIC

This provides a generic base for building objects that receive data from the 
interface.  This object is inherited by all parent and child objects and
in most cases, a user will not need to worry about this object.

=head3 PARENT ITEMS

These currently include B<Nest_Smoke_CO_Alarm>, B<Nest_Thermostat>, and 
B<Nest_Structure>.  This classes provide more specific support for each of the 
current Nest type of objects. These objects provide all of the access needed to 
interact with each of the devices in a user friendly way.

=head3 CHILD ITEMS 

Currently these are named B<Nest_Thermo_>.... These are very specific objects 
that provide very specific support for individual features on the Nest 
Thermostats. I have in the past commonly referred to these as child objects.  
In general, the state of these objects reports the state of a single parameter 
on the thermostat.  A few of the objects also offer writable features that allow 
changing certain parameters on the thermostat.

=cut

package Nest;

# Used solely to provide a consistent logging feature

use strict;

#log levels
my $warn  = 1;
my $info  = 2;
my $trace = 3;

sub debug {
    my ( $self, $message, $level ) = @_;
    $level = 0 if $level eq '';
    my $line   = '';
    my @caller = caller(0);
    if ( $::Debug{'nest'} >= $level || $level == 0 ) {
        $line = " at line " . $caller[2] if $::Debug{'nest'} >= $trace;
        ::print_log( "[" . $caller[0] . "] " . $message . $line );
    }
}

package Nest_Interface;

=head1 B<Nest_Interface>

=head2 SYNOPSIS

This module allows MisterHouse to communicate with the public Nest API which 
currently allows interation with Nest Thermostats and Smoke/CO Detectors. 

=head2 CONFIGURATION

Nest uses OAuth technology to authorize access to your account.  The nice thing
is that at any point in the future, you can sign into your Nest account and 
revoke any access tokens that you have issued.

To start the authorization process, go to the following URL:
    
L<https://misterhouse-nest.appspot.com/>

Read everything on that page and follow the instructions.  At the end of the
process, the webpage will provide you with a line to add to your mh.private.ini
file.  It will be a long line! Copy the entire line and place it in your
mh.private.ini file:

  Nest_auth_token=<API token from Nest registration>

Create a Nest instance in the .mht file, or in user code:

.mht file:

  CODE, require Nest; #noloop 
  CODE, $nest = new Nest_Interface(); #noloop

=head2 DESCRIPTION

This handles the interaction between the Nest API servers and MisterHouse.  
This is the object that is required.  An advanced user could interact with
the Nest API solely through this object.

=head2 INHERITS

C<Nest>

=cut

@Nest_Interface::ISA = ('Nest');

use strict;

=head2 DEPENDENCIES

  JSON              - Used for encoding/decoding the JSON data
  IO::Socket::SSL   - SSL Used to establish a secure connection to Nest servers
  IO::Socket::INET  - Nest uses a RESTful Streaming protocol which requires a 
                      special code setup to keep the HTTP socket constantly open.
  IO::Select        - Used to manage the HTTP socket
  URI::URL          - Used for deciphering URLs
  HTTP::Response    - Used for handling the responses from Nest
  HTTP::Request     - Used for sending requests to Nest

=cut

use JSON;
use IO::Socket::SSL;
use IO::Socket::INET;
use IO::Select;
use URI::URL;
use HTTP::Response;
use HTTP::Request;

=head2 METHODS

=over

=item C<new($auth, $port_name, $url>

Creates a new Nest Interface.  The only required parameter is auth, which can
also be set using the INI parameter B<Nest_auth_token>.

port_name -  defaults to Nest.  If you are using multiple Nest Interfaces,
I would imagine this to be very rare.  Then the subsequent interfaces
must have a different port name.  You must also change the prefix of the
auth INI parameter to match the new port name.

url - I have no idea when this would be used.  But if you wanted to use
a different url than what Nest provides, maybe for testing or some beta
group, then you can provide the url here.

=cut

sub new {
    my ( $class, $auth, $port_name, $url ) = @_;
    my $self = {};
    $port_name = 'Nest'                                        if !$port_name;
    $url       = "https://developer-api.nest.com/.json"        if !$url;
    $auth      = $::config_parms{ $port_name . "_auth_token" } if !$auth;
    $$self{port_name}       = $port_name;
    $$self{url}             = $url;
    $$self{auth}            = $auth;
    $$self{reconnect_timer} = new Timer;
    $$self{write_process}   = new Process_Item;
    $$self{write_process}->set_timeout(30);
    $$self{write_process_active} = 0;
    $$self{write_process_queue}  = [];
    $$self{write_process_code}   = sub { $self->write_process_handler(); };
    $$self{enabled}              = 1;
    bless $self, $class;
    $self->connect_stream();
    ::MainLoop_pre_add_hook( sub { $self->check_for_data(); }, 'persistent' );
    return $self;
}

# Establishes the connection to Nest

sub connect_stream {
    my ( $self, $url ) = @_;
    $url = $$self{url} . "?auth=" . $$self{auth} if ( $url eq '' );
    $url = new URI::URL $url;

    if ( defined $$self{socket} ) {
        $$self{socket}->close;
        delete $$self{socket};
        $self->reconnect_delay( 1, $url );
        return;
    }

    $$self{socket} = IO::Socket::INET->new(
        PeerHost => $url->host,
        PeerPort => $url->port,
        Blocking => 0,
        Timeout  => 30,
    );

    unless ( $$self{socket} ) {
        $self->debug( "ERROR connecting to Nest server: " . $@ );
        $self->reconnect_delay();
        return;
    }

    my $select = IO::Select->new( $$self{socket} );    # wait until it connected
    if ( $select->can_write ) {
        $self->debug( "IO::Socket::INET connected", $info );
    }

    # upgrade socket to IO::Socket::SSL
    IO::Socket::SSL->start_SSL( $$self{socket}, SSL_startHandshake => 0 );

    # make non-blocking SSL handshake
    while (1) {
        if ( $$self{socket}->connect_SSL ) {           # will not block
            $self->debug( "IO::Socket::SSL connected", $info );
            last;
        }
        else {    # handshake still incomplete
            if ( $SSL_ERROR == SSL_WANT_READ ) {
                $select->can_read;
            }
            elsif ( $SSL_ERROR == SSL_WANT_WRITE ) {
                $select->can_write;
            }
            else {
                $self->debug(
                    "ERROR connecting to Nest server: " . $SSL_ERROR );
                $self->reconnect_delay();
                return;
            }
        }
    }

    # Request specific location
    my $request = HTTP::Request->new( 'GET', $url->full_path,
        [ "Accept", "text/event-stream", "Host", $url->host ] );
    $request->protocol('HTTP/1.1');
    unless ( $$self{socket}->syswrite( $request->as_string ) ) {
        $self->debug( "ERROR connecting to Nest server: " . $! );
        $self->reconnect_delay();
        return;
    }

    $$self{'keep-alive'} = time;
    return $$self{socket};
}

# Used to try reconnecting after a delay if there was an error

sub reconnect_delay {
    my ( $self, $seconds, $url ) = @_;
    my $action = sub { $self->connect_stream($url) };
    if ( !$seconds ) {
        $seconds = 60;
        $self->debug("Will try to connect again in 1 minute.");
    }
    $$self{reconnect_timer}->set( $seconds, $action );
}

# Run once per loop to check for data present on the connection

sub check_for_data {
    my ($self) = @_;
    if (   defined $$self{socket}
        && $$self{socket}->connected
        && ( time - $$self{'keep-alive'} < 70 ) )
    {
        # sysread will only read the contents of a single SSL frame
        if ( $$self{socket}->sysread( my $buf, 1024 ) ) {
            $$self{data} .= $buf;
            if ( $$self{data} =~ /^HTTP/ ) {    # Start of new stream
                my $r = HTTP::Response->parse($buf);
                if ( $r->code == 307 ) {

                    # This is a location redirect
                    $self->debug( "redirecting to " . $r->header('location'),
                        $trace );
                    $$self{socket} =
                      $self->connect_stream( $r->header('location') );
                }
                elsif ( $r->code == 401 ) {
                    $self->debug( "ERROR, your authorization was rejected. "
                          . "Please check your settings." );
                    $$self{enabled} = 0;
                }
                elsif ( $r->code == 200 ) {

                    # Successful response
                    $self->debug( "Successfully connected to stream", $warn );
                }
                else {
                    $self->debug( "ERROR, unable to connect stream. "
                          . "Response was: "
                          . $r->as_string );
                    $self->reconnect_delay();
                }
                $$self{data} = "";
            }
            elsif ( $buf =~ /\n\n$/ ) {

                # We reached the end of the message packet in an existing stream
                $self->debug( "Data :\n" . $$self{data}, $trace );

                # Split out event and data for processing
                my @lines = split( "\n", $$self{data} );
                my ( $event, $data );
                for (@lines) {

                    # Pull out events and data
                    my ( $key, $value ) = split( ":", $_, 2 );
                    if ( $key =~ /event/ ) {
                        $event = $value;
                    }
                    elsif ( $key =~ /data/ && defined($event) ) {
                        $data = $value;
                    }

                    if ( defined($event) && defined($data) ) {
                        $self->parse_data( $event, $data );
                        $event = '';
                        $data  = '';
                    }
                }

                # Clear data storage
                $$self{data} = "";
            }
        }
    }
    elsif ( $$self{reconnect_timer}->inactive && $$self{enabled} ) {

        # The connection died, or the keep-alive messages stopped, restart it
        $self->debug( "Connection died, restarting", $warn );
        $self->reconnect_delay(1);
    }
}

# If data is found on the connection with Nest, this parses out the data

sub parse_data {
    my ( $self, $event, $data ) = @_;
    if ( $event =~ /keep-alive/ ) {
        $$self{'keep-alive'} = time;
        $self->debug( "Keep Alive", $info );
    }
    elsif ( $event =~ /put/ ) {
        $$self{'keep-alive'} = time;

        #This is the first JSON packet received after connecting
        $$self{prev_JSON} = $$self{JSON};
        $$self{JSON}      = decode_json $data;
        if ( !defined $$self{prev_JSON}{data}{devices} ) {

            #this is the first run so convert the names to ids
            $self->convert_to_ids( $$self{monitor} );
        }
        $self->compare_json( $$self{JSON}, $$self{prev_JSON}, $$self{monitor} );

        #print "*** Object *** \n";
        #print Data::Dumper::Dumper( \$self);
        #print Data::Dumper::Dumper( \$self->{monitor});
        #print "*** Object *** \n";
    }
    elsif ( $event =~ /auth_revoked/ ) {

        # Sent when auth parameter is no longer valid
        # Accoring to Nest, the auth token is essentially non-expiring,
        # so this shouldn't happen.
        $self->debug("ERROR, your Nest authorization token has expired.");
        $$self{enabled} = 0;
    }
    return;
}

=item C<write_data($parent, $value, $data, $url)>

This is used to write parameters to the Nest servers.

    $parent   -   (alternative) a reference to the parent object (thermostat, 
                  smoke detector, structure) that this data should be written to
    $value    -   The name of the value to write
    $data     -   The data to be written
    $url      -   (alternative) the full url to be written to 
 
  
Either the parent or the URL must be defined.  If the url is defined, it 
will trump the parent.

Advanced users can use this function to directly write JSON data to Nest.  
Otherwise it is used by the more user friendly objects.

=cut

sub write_data {
    my ( $self, $parent, $value, $data, $url ) = @_;
    if ( $url eq '' ) {
        $url = 'https://developer-api.nest.com/';
        $url .= $$parent{class} . "/";
        $url .= $$parent{type} . "/" if ( $$parent{type} ne '' );
        $url .= $parent->device_id . "/";
        $url .= $value . "?auth=" . $$self{auth};
    }
    my $json = lc($data);

    #true false and numbers should not have quotes
    unless ( $json eq 'true' || $json eq 'false' || $json =~ /^\d+(\.\d+)?$/ ) {
        $json = '"' . $json . '"';
    }

    $self->debug( "writing $json to $url", $trace );

    # Use a process item to prevent blocking
    if ( !$$self{write_process_active} ) {
        $$self{write_process}
          ->set("&Nest_Interface::_write_data_process('$url','$json')");
        $$self{write_process}->start();
        $$self{write_process_active} = 1;

        # Add hook to check for completion of process
        ::MainLoop_pre_add_hook( $$self{write_process_code}, 'persistent' );
    }
    else {
        push(
            @{ $$self{write_process_queue} },
            "&Nest_Interface::_write_data_process('$url','$json')"
        );
    }
}

# This is run as a separate process to prevent blocking errors. Can't use get_url
# because it doesn't have the PUT method or the content-type header

sub _write_data_process {
    my ( $url, $json ) = @_;
    my $req = HTTP::Request->new( 'PUT', $url );
    $req->header( 'Content-Type' => 'application/json' );
    $req->content($json);
    $req->protocol('HTTP/1.1');
    my $lwp = LWP::UserAgent->new;
    my $r   = $lwp->request($req);
    if ( $r->code == 307 ) {

        # This is a location redirect
        ::print_log(
            "[Nest_Interface] redirecting to " . $r->header('location') )
          if $::Debug{'nest'} >= 3;
        return _write_data_process( $r->header('location'), $json );
    }
    ::file_write( "$::config_parms{data_dir}/nest.resp", $r->as_string() );
}

# This routine is set as a hook when a write process is running.  When the
# write process completes, this routine checks the contents of the response

sub write_process_handler {
    my ($self) = @_;
    if ( $$self{write_process}->done_now ) {
        my $resp_string = ::file_read("$::config_parms{data_dir}/nest.resp");
        unlink("$::config_parms{data_dir}/nest.resp");
        my $r = HTTP::Response->parse($resp_string);
        if ( $r->code == 401 ) {
            $self->debug( "ERROR, your authorization was rejected. "
                  . "Please check your settings." );
        }
        elsif ( $r->code == 200 ) {

            # Successful response
            $self->debug( "Successfully wrote data", $info );
        }
        else {
            my $content = decode_json $r->content;
            $self->debug( "ERROR, unable to write data to Nest server. "
                  . $r->status_line . " - "
                  . $$content{error} );
        }

        # Look see if there is a queue of write commands
        if ( scalar @{ $$self{write_process_queue} } ) {
            my $process = shift @{ $$self{write_process_queue} };
            $$self{write_process}->set($process);
            $$self{write_process}->start();
        }
        else {
            $$self{write_process_active} = 0;
            ::MainLoop_pre_drop_hook( $$self{write_process_code} );
        }
    }
}

=item C<print_devices()>

Prints the name and device_id of all devices found in the Nest account.

=cut

sub print_devices {
    my ($self) = @_;
    my $output = "The list of devices reported by Nest is:\n";
    for ( keys %{ $$self{JSON}{data}{devices} } ) {
        my $device_type = $_;
        $output .= "        $device_type =\n";
        for ( keys %{ $$self{JSON}{data}{devices}{$device_type} } ) {
            my $device_id = $_;
            my $device_name =
              $$self{JSON}{data}{devices}{$device_type}{$device_id}{name};
            $output .= "            Name: $device_name ID: $device_id\n";
        }
    }
    $self->debug($output);
}

=item C<print_structures()>

Prints the name and device_id of all structures found in the Nest account.

=cut

sub print_structures {
    my ($self) = @_;
    my $output = "The list of structures reported by Nest is:\n";
    for ( keys %{ $$self{JSON}{data}{structures} } ) {
        my $structure_id = $_;
        my $structure_name =
          $$self{JSON}{data}{structures}{$structure_id}{name};
        $output .= "        Name: $structure_name ID: $structure_id\n";
    }
    $self->debug($output);
}

=item C<register($parent, $value, $action)>

Used to register actions to be run if a specific JSON value changes.

    $parent   - The parent object on which the value should be monitored 
                (thermostat, smoke detector, structure)
    $value    - The parameter to monitor for changes
    $action   - A Code Reference to run when the json changes.  The code reference
                will be passed two arguments, the parameter name and value.

=cut

sub register {
    my ( $self, $parent, $value, $action ) = @_;
    push( @{ $$self{register} }, [ $parent, $value, $action ] );
}

# Walk through the JSON hash and looks for changes from previous json hash if a
# change is found, looks for children to notify and notifies them.

sub compare_json {
    my ( $self, $json, $prev_json, $monitor_hash ) = @_;
    while ( my ( $key, $value ) = each %{$json} ) {

        # Use empty hash reference is it doesn't exist
        my $prev_value = {};
        $prev_value = $$prev_json{$key} if exists $$prev_json{$key};
        my $monitior_value = {};
        $monitior_value = $$monitor_hash{$key} if exists $$monitor_hash{$key};
        if ( 'HASH' eq ref $value ) {
            $self->compare_json( $value, $prev_value, $monitior_value );
        }
        elsif ( $value ne $prev_value && ref $monitior_value eq 'ARRAY' ) {
            for my $action ( @{$monitior_value} ) {
                &$action( $key, $value );
            }
        }
    }
}

# Converts the names in the register hash to IDs, and then puts them into
# the monitor hash.

sub convert_to_ids {
    my ($self) = @_;
    for my $array_ref ( @{ $$self{register} } ) {
        my ( $parent, $value, $action ) = @{$array_ref};
        $self->debug( "Nest Initial data load convert_to_ids " . $value );
        my $device_id = $parent->device_id();
        if ( $$parent{type} ne '' ) {
            push(
                @{
                    $$self{monitor}{data}{ $$parent{class} }{ $$parent{type} }
                      {$device_id}{$value}
                },
                $action
            );
        }
        else {
            push(
                @{
                    $$self{monitor}{data}{ $$parent{class} }{$device_id}{$value}
                },
                $action
            );
        }
    }
    delete $$self{register};
}

=item C<client_version()>

Prints the Misterhouse Client Version. Client version of 2 is required for humidity and hvac_state. Returns -1 if unknown version, or if the data hasn't been parsed yet

=cut

sub client_version {
    my ($self) = @_;
    my $version = -1;
    $version = $$self{JSON}{data}{metadata}{client_version}
      if defined( $$self{JSON}{data}{metadata}{client_version} );
    return ($version);

}

package Nest_Generic;

=back

=head1 B<Nest_Generic>

=head2 SYNOPSIS

This is a generic module primarily meant to be inherited by higher level more
user friendly modules.  The average user should just ignore this module. 

=cut 

use strict;

=head2 INHERITS

C<Generic_Item>

=cut

@Nest_Generic::ISA = ( 'Generic_Item', 'Nest' );

=head2 METHODS

=over

=item C<new($interface, $parent, $monitor_hash>

Creates a new Nest_Generic.

    $interface    - The Nest_Interface through which this device can be found.
    $parent       - The parent interface of this object, if not specified the
                  the parent will be set to Self.
    $monitor_hash - A hash ref, {$value => $action}, where $value is the JSON 
                  value that should be monitored with $action equal to the code 
                  reference that should be run on changes.  The hash ref can
                  contain an infinite number of key value pairs.  If no action
                  is specified, it will use the default data_changed routine.

=cut

sub new {
    my ( $class, $interface, $parent, $monitor_hash ) = @_;
    my $self = new Generic_Item();
    bless $self, $class;
    $$self{interface} = $interface;
    $$self{parent}    = $parent;
    $$self{parent}    = $self if ( $$self{parent} eq '' );
    while ( my ( $monitor_value, $action ) = each %{$monitor_hash} ) {
        my $action = sub { $self->data_changed(@_); }
          if $action eq '';
        $$self{interface}->register( $$self{parent}, $monitor_value, $action );
    }
    return $self;
}

=item C<device_id()>

Returns the device_id of an object.

=cut

sub device_id {
    my ($self) = @_;
    my $type_hash;
    my $parent = $$self{parent};
    if ( $$self{type} ne '' ) {
        $type_hash =
          $$self{interface}{JSON}{data}{ $$self{class} }{ $$self{type} };
    }
    else {
        $type_hash = $$self{interface}{JSON}{data}{ $$self{class} };
    }
    for ( keys %{$type_hash} ) {
        my $device_id   = $_;
        my $device_name = $$type_hash{$device_id}{name};
        if ( $$parent{name} eq $device_id
            || ( $$parent{name} eq $device_name ) )
        {
            return $device_id;
        }
    }
    $self->debug(
        "ERROR, no device by the name " . $$parent{name} . " was found." );
    return 0;
}

=item C<data_changed()>

The default action to be called when the JSON data has changed.  In most cases 
we can ignore the value name and just set the state of the child to new_value.
More sophisticated children can hijack this method to do more complex tasks.

=cut

sub data_changed {
    my ( $self, $value_name, $new_value ) = @_;
    my ( $setby, $response );
    $self->debug( "Data changed called $value_name, $new_value", $info );
    if ( defined $$self{parent}{state_pending}{$value_name} ) {
        ( $setby, $response ) = @{ $$self{parent}{state_pending}{$value_name} };
        delete $$self{parent}{state_pending}{$value_name};
    }
    else {
        $setby = $$self{interface};
    }
    $self->set_receive( $new_value, $setby, $response );
}

=item C<set_receive()>

Handles setting the state of the object inside MisterHouse

=cut

sub set_receive {
    my ( $self, $p_state, $p_setby, $p_response ) = @_;
    $self->SUPER::set( $p_state, $p_setby, $p_response );
}

=item C<get_value($value)>

Returns the JSON data contained in value for this device.

=cut

sub get_value {
    my ( $self, $value ) = @_;
    my $device_id = $self->device_id;
    if ( $$self{type} ne '' ) {
        return $$self{interface}{JSON}{data}{ $$self{class} }{ $$self{type} }
          {$device_id}{$value};
    }
    else {
        return $$self{interface}{JSON}{data}{ $$self{class} }{$device_id}
          {$value};
    }
}

package Nest_Thermostat;

=back

=head1 B<Nest_Thermostat>

=head2 SYNOPSIS

This is a high level module for interacting with the Nest Thermostat.  It is
generally user friendly and contains many functions which are similar to other
thermostat modules.

The state of this object will be the ambient temperature reported by the 
thermostat.  This object does not accept set commands.  You can use all of the 
remaining C<Generic_Item> including c<state>, c<state_now>, c<tie_event> to 
interact with this object.

=head2 CONFIGURATION

Create a Nest thermostat instance in the .mht file:

.mht file:

  CODE, $nest_thermo = new Nest_Thermostat('Entryway', $nest, 'f'); #noloop

The arguments:

    1. The first argument can be either I<the name of the device> or the I<device id>.
       If using the name, this must be the exact verbatim name as listed on the Nest 
       website.  Alternatively, if you want to allow for future name changes without 
       breaking your installation, you can get the device id using the 
       L<print_devices()|Nest_Interface::print_devices> routine.
    2. The second argument is the interface object
    3. The third argument is either [f,c] and denotes the temperature scale you prefer

=cut 

use strict;

=head2 INHERITS

C<Nest_Generic>

=cut

@Nest_Thermostat::ISA = ('Nest_Generic');

=head2 METHODS

=over

=item C<new($name, $interface, $scale)>

Creates a new Nest_Generic.

    $name         - The name or device if of the Thermostat
    $interface    - The interface object
    $scale        - Either [c,f] denoting your prefered temperature scale


=cut

sub new {
    my ( $class, $name, $interface, $scale ) = @_;
    $scale = lc($scale);
    $scale = "f" unless ( $scale eq "c" );
    my $monitor_value = "ambient_temperature_" . $scale;
    my $self = new Nest_Generic( $interface, '', { $monitor_value => '' } );
    bless $self, $class;
    $$self{class}   = 'devices',
      $$self{type}  = 'thermostats',
      $$self{name}  = $name,
      $$self{scale} = $scale;
    return $self;
}

=item C<get_temp()>

Returns the current ambient temperature.

=cut

sub get_temp {
    my ($self) = @_;
    return $self->get_value( "ambient_temperature_" . $$self{scale} );
}

=item C<get_heat_sp()>

Returns the current heat setpoint for the combined heat-cool mode.

=cut

sub get_heat_sp {
    my ($self) = @_;
    return $self->get_value( "target_temperature_high_" . $$self{scale} );
}

=item C<get_cool_sp()>

Returns the current cool setpoint for the combined heat-cool mode.

=cut

sub get_cool_sp {
    my ($self) = @_;
    return $self->get_value( "target_temperature_low_" . $$self{scale} );
}

=item C<get_target_sp()>

Returns the current target setpoint for either the heat or cool mode.  The
combined heat-cool mode uses its own functions.

=cut

sub get_target_sp {
    my ($self) = @_;
    return $self->get_value( "target_temperature_" . $$self{scale} );
}

=item C<get_mode()>

Return the current mode.

=cut

sub get_mode {
    my ($self) = @_;
    return $self->get_value("hvac_mode");
}

=item C<get_fan_state()>

Return the current fan state.

=cut

sub get_fan_state {
    my ($self) = @_;
    return $self->get_value("fan_timer_active");
}

=item C<set_fan_state($state, $p_setby, $p_response)>

Sets the fan state to $state, must be [true,false].

=cut

=item C<get_humidity()>

Return the current humidity value.

=cut

sub get_humidity {
    my ($self) = @_;
    return $self->get_value("humidity");
}

=item C<get_hvac_state()>

Return the current thermostat state (heating, cooling, off).

=cut

sub get_hvac_state {
    my ($self) = @_;
    return $self->get_value("hvac_state");
}

sub set_fan_state {
    my ( $self, $state, $p_setby, $p_response ) = @_;
    $state = lc($state);
    if ( $state ne 'true' && $state ne 'false' ) {
        $self->debug("set_fan_state must be true or false");
        return;
    }
    $$self{interface}->write_data( $self, 'fan_timer_active', $state );
    $$self{state_pending}{fan_timer_active} = [ $p_setby, $p_response ];
}

=item C<set_target_temp($state, $p_setby, $p_response)>

Sets the target temp for the heat or cool mode to $state.

=cut

sub set_target_temp {
    my ( $self, $state, $p_setby, $p_response ) = @_;
    unless ( $state =~ /^\d+(\.\d+)?$/ ) {
        $self->debug("set_target_temp must be a number");
        return;
    }
    my $value = 'target_temperature_' . $$self{scale};
    $$self{interface}->write_data( $self, $value, $state );
    $$self{state_pending}{$value} = [ $p_setby, $p_response ];
}

=item C<set_target_temp_high($state, $p_setby, $p_response)>

Sets the heat target temp for the combined heat-cool mode to $state.

=cut

sub set_target_temp_high {
    my ( $self, $state, $p_setby, $p_response ) = @_;
    unless ( $state =~ /^\d+(\.\d+)?$/ ) {
        $self->debug("set_target_temp_high must be a number");
        return;
    }
    my $value = 'target_temperature_high_' . $$self{scale};
    $$self{interface}->write_data( $self, $value, $state );
    $$self{state_pending}{$value} = [ $p_setby, $p_response ];
}

=item C<set_target_temp_low($state, $p_setby, $p_response)>

Sets the cool target temp for the combined heat-cool mode to $state.

=cut

sub set_target_temp_low {
    my ( $self, $state, $p_setby, $p_response ) = @_;
    unless ( $state =~ /^\d+(\.\d+)?$/ ) {
        $self->debug("set_target_temp_low must be a number");
        return;
    }
    my $value = 'target_temperature_low_' . $$self{scale};
    $$self{interface}->write_data( $self, $value, $state );
    $$self{state_pending}{$value} = [ $p_setby, $p_response ];
}

=item C<set_hvac_mode($state, $p_setby, $p_response)>

Sets the mode to $state, must be [heat,cool,heat-cool,off]

=cut

sub set_hvac_mode {
    my ( $self, $state, $p_setby, $p_response ) = @_;
    $state = lc($state);
    if (   $state ne 'heat'
        && $state ne 'cool'
        && $state ne 'heat-cool'
        && $state ne 'off' )
    {
        $self->debug(
            "set_hvac_mode must be one of: heat, cool, heat-cool, or off. Not $state."
        );
        return;
    }
    $$self{state_pending}{hvac_mode} = [ $p_setby, $p_response ];
    $$self{interface}->write_data( $self, 'hvac_mode', $state );
}

package Nest_Thermo_Fan;

=back

=head1 B<Nest_Thermo_Fan>

=head2 SYNOPSIS

This is a very high level module for interacting with the Nest Thermostat Fan.
This type of object is often referred to as a child device.  It displays the
state of the fan and allows for enabling or disabling it.  The object inherits
all of the C<Generic_Item> methods, including c<set>, c<state>, c<state_now>, 
c<tie_event>.

=head2 CONFIGURATION

.mht file:

  CODE, $thermo_fan = new Nest_Thermo_Fan($nest_thermo); #noloop

The only argument required is the thermostat object.

=head2 INHERITS

C<Nest_Generic>

=cut

use strict;

@Nest_Thermo_Fan::ISA = ('Nest_Generic');

sub new {
    my ( $class, $parent ) = @_;
    my $self = new Nest_Generic( $$parent{interface}, $parent,
        { 'fan_timer_active' => '' } );
    $$self{states} = [ 'on', 'off' ];
    bless $self, $class;
    return $self;
}

sub set_receive {
    my ( $self, $p_state, $p_setby, $p_response ) = @_;
    my $state = "on";
    $state = "off" if ( $p_state eq 'false' );
    $self->SUPER::set( $state, $p_setby, $p_response );
}

sub set {
    my ( $self, $p_state, $p_setby, $p_response ) = @_;
    $p_state = "true"  if ( lc($p_state) eq 'on' );
    $p_state = "false" if ( lc($p_state) eq 'off' );
    $$self{parent}->set_fan_state( $p_state, $p_setby, $p_response );
}

package Nest_Thermo_Leaf;

=head1 B<Nest_Thermo_Leaf>

=head2 SYNOPSIS

This is a very high level module for interacting with the Nest Thermostat Leaf.
This type of object is often referred to as a child device.  It displays the
state of the leaf.  The object inherits all of the C<Generic_Item> methods, 
including c<state>, c<state_now>, c<tie_event>.

=head2 CONFIGURATION

.mht file:

  CODE, $thermo_leaf = new Nest_Thermo_Leaf($nest_thermo); #noloop

The only argument required is the thermostat object.

=head2 INHERITS

C<Nest_Generic>

=cut

use strict;

@Nest_Thermo_Leaf::ISA = ('Nest_Generic');

sub new {
    my ( $class, $parent ) = @_;
    my $self =
      new Nest_Generic( $$parent{interface}, $parent, { 'has_leaf' => '' } );
    bless $self, $class;
    return $self;
}

sub set_receive {
    my ( $self, $p_state, $p_setby, $p_response ) = @_;
    my $state = "on";
    $state = "off" if ( $p_state eq 'false' );
    $self->SUPER::set( $state, $p_setby, $p_response );
}

package Nest_Thermo_Humidity;

=head1 B<Nest_Thermo_Humidity>

=head2 SYNOPSIS

This is a very high level module for viewing with the Nest Thermostat Humidity value.
This type of object is often referred to as a child device.  It displays the
current humidity.  The object inherits all of the C<Generic_Item> methods, 
including c<state>, c<state_now>, c<tie_event>.

=head2 CONFIGURATION

.mht file:

  CODE, $thermo_humid = new Nest_Thermo_Humidity($nest_thermo); #noloop

The only argument required is the thermostat object.

=head2 INHERITS

C<Nest_Generic>

=cut

use strict;

@Nest_Thermo_Humidity::ISA = ('Nest_Generic');

sub new {
    my ( $class, $parent ) = @_;
    my $self =
      new Nest_Generic( $$parent{interface}, $parent, { 'humidity' => '' } );
    bless $self, $class;
    return $self;
}

package Nest_Thermo_HVAC_State;

=head1 B<Nest_Thermo_HVAC_State>

=head2 SYNOPSIS

This is a very high level module for viewing the Nest Thermostat operating state.
This type of object is often referred to as a child device.  It displays the
current status (heating, cooling, off).  The object inherits all of the C<Generic_Item> methods, 
including c<state>, c<state_now>, c<tie_event>.

=head2 CONFIGURATION

.mht file:

  CODE, $thermo_hvac_state = new Nest_Thermo_HVAC_State($nest_thermo); #noloop

The only argument required is the thermostat object.

=head2 INHERITS

C<Nest_Generic>

=cut

use strict;

@Nest_Thermo_HVAC_State::ISA = ('Nest_Generic');

sub new {
    my ( $class, $parent ) = @_;
    my $self =
      new Nest_Generic( $$parent{interface}, $parent, { 'hvac_state' => '' } );
    bless $self, $class;
    return $self;
}

package Nest_Thermo_Mode;

=head1 B<Nest_Thermo_Mode>

=head2 SYNOPSIS

This is a very high level module for interacting with the Nest Thermostat Mode.
This type of object is often referred to as a child device.  It displays the
mode of the thermostat and allows for setting the modes.  The object inherits
all of the C<Generic_Item> methods, including c<set>, c<state>, c<state_now>, 
c<tie_event>.

=head2 CONFIGURATION

.mht file:

  CODE, $thermo_mode = new Nest_Thermo_Mode($nest_thermo); #noloop

The only argument required is the thermostat object.

=head2 INHERITS

C<Nest_Generic>

=cut

use strict;

@Nest_Thermo_Mode::ISA = ('Nest_Generic');

sub new {
    my ( $class, $parent ) = @_;
    my $self =
      new Nest_Generic( $$parent{interface}, $parent, { 'hvac_mode' => '' } );
    $$self{states} = [ 'heat', 'cool', 'heat-cool', 'off' ];
    bless $self, $class;
    return $self;
}

sub set {
    my ( $self, $p_state, $p_setby, $p_response ) = @_;
    $self->debug( "Setting $p_state, $p_setby, $p_response", $info );
    $$self{parent}->set_hvac_mode( $p_state, $p_setby, $p_response );
}

=head1 B<Nest_Thermo_Target>

=head2 SYNOPSIS

This is a very high level module for interacting with the Nest Thermostat Target
Temperature.  This is used in either the heat or the cool modes.
This type of object is often referred to as a child device.  It displays the
setpoint of the thermostat and allows for setting the temperature.  The object inherits
all of the C<Generic_Item> methods, including c<set>, c<state>, c<state_now>, 
c<tie_event>.

=head2 CONFIGURATION

.mht file:

  CODE, $thermo_param = new Nest_Thermo_Target($nest_thermo); #noloop

The only argument required is the thermostat object.

=head2 INHERITS

C<Nest_Generic>

=cut

package Nest_Thermo_Target;
use strict;
@Nest_Thermo_Target::ISA = ('Nest_Generic');

sub new {
    my ( $class, $parent ) = @_;
    my $scale = $$parent{scale};
    my $self  = new Nest_Generic( $$parent{interface}, $parent,
        { 'target_temperature_' . $scale => '' } );
    $$self{states} = [ 'cooler', 'warmer' ];
    bless $self, $class;
    return $self;
}

sub set {
    my ( $self, $p_state, $p_setby, $p_response ) = @_;
    if ( lc($p_state) eq 'warmer' ) {
        $p_state = $$self{parent}->get_target_sp + 1;
    }
    elsif ( lc($p_state) eq 'cooler' ) {
        $p_state = $$self{parent}->get_target_sp - 1;
    }
    $$self{parent}->set_target_temp( $p_state, $p_setby, $p_response );
}

=head1 B<Nest_Thermo_Target_High>

=head2 SYNOPSIS

This is a very high level module for interacting with the Nest Thermostat High 
Target Temperature.  This is used only in the heat-cool mode.
This type of object is often referred to as a child device.  It displays the
setpoint of the thermostat and allows for setting the temperature.  The object inherits
all of the C<Generic_Item> methods, including c<set>, c<state>, c<state_now>, 
c<tie_event>.

=head2 CONFIGURATION

.mht file:

  CODE, $thermo_param = new Nest_Thermo_Target_High($nest_thermo); #noloop

The only argument required is the thermostat object.

=head2 INHERITS

C<Nest_Generic>

=cut

package Nest_Thermo_Target_High;
use strict;
@Nest_Thermo_Target_High::ISA = ('Nest_Generic');

sub new {
    my ( $class, $parent ) = @_;
    my $scale = $$parent{scale};
    my $self  = new Nest_Generic( $$parent{interface}, $parent,
        { 'target_temperature_high_' . $scale => '' } );
    $$self{states} = [ 'cooler', 'warmer' ];
    bless $self, $class;
    return $self;
}

sub set {
    my ( $self, $p_state, $p_setby, $p_response ) = @_;
    if ( lc($p_state) eq 'warmer' ) {
        $p_state = $$self{parent}->get_heat_sp + 1;
    }
    elsif ( lc($p_state) eq 'cooler' ) {
        $p_state = $$self{parent}->get_heat_sp - 1;
    }
    $$self{parent}->set_target_temp_high( $p_state, $p_setby, $p_response );
}

=head1 B<Nest_Thermo_Target_Low>

=head2 SYNOPSIS

This is a very high level module for interacting with the Nest Thermostat Low 
Target Temperature.  This is used only in the heat-cool mode.
This type of object is often referred to as a child device.  It displays the
setpoint of the thermostat and allows for setting the temperature.  The object inherits
all of the C<Generic_Item> methods, including c<set>, c<state>, c<state_now>, 
c<tie_event>.

=head2 CONFIGURATION

.mht file:

  CODE, $thermo_param = new Nest_Thermo_Target_Low($nest_thermo); #noloop

The only argument required is the thermostat object.

=head2 INHERITS

C<Nest_Generic>

=cut

package Nest_Thermo_Target_Low;
use strict;
@Nest_Thermo_Target_Low::ISA = ('Nest_Generic');

sub new {
    my ( $class, $parent ) = @_;
    my $scale = $$parent{scale};
    my $self  = new Nest_Generic( $$parent{interface}, $parent,
        { 'target_temperature_low_' . $scale => '' } );
    $$self{states} = [ 'cooler', 'warmer' ];
    bless $self, $class;
    return $self;
}

sub set {
    my ( $self, $p_state, $p_setby, $p_response ) = @_;
    if ( lc($p_state) eq 'warmer' ) {
        $p_state = $$self{parent}->get_cool_sp + 1;
    }
    elsif ( lc($p_state) eq 'cooler' ) {
        $p_state = $$self{parent}->get_cool_sp - 1;
    }
    $$self{parent}->set_target_temp_low( $p_state, $p_setby, $p_response );
}

=head1 B<Nest_Thermo_Away_High>

=head2 SYNOPSIS

This is a very high level module for interacting with the Nest Thermostat High 
Away Target Temperature.
This type of object is often referred to as a child device.  It displays the
setpoint of the thermostat and but cannot be changed.  The object inherits
all of the C<Generic_Item> methods, including c<state>, c<state_now>, 
c<tie_event>.

=head2 CONFIGURATION

.mht file:

  CODE, $thermo_param = new Nest_Thermo_Away_High($nest_thermo); #noloop

The only argument required is the thermostat object.

=head2 INHERITS

C<Nest_Generic>

=cut

package Nest_Thermo_Away_High;
use strict;
@Nest_Thermo_Away_High::ISA = ('Nest_Generic');

sub new {
    my ( $class, $parent ) = @_;
    my $scale = $$parent{scale};
    my $self  = new Nest_Generic( $$parent{interface}, $parent,
        { 'away_temperature_high_' . $scale => '' } );
    bless $self, $class;
    return $self;
}

=head1 B<Nest_Thermo_Away_Low>

=head2 SYNOPSIS

This is a very high level module for interacting with the Nest Thermostat High 
Away Target Temperature.
This type of object is often referred to as a child device.  It displays the
setpoint of the thermostat and but cannot be changed.  The object inherits
all of the C<Generic_Item> methods, including c<state>, c<state_now>, 
c<tie_event>.

=head2 CONFIGURATION

.mht file:

  CODE, $thermo_param = new Nest_Thermo_Away_Low($nest_thermo); #noloop

The only argument required is the thermostat object.

=head2 INHERITS

C<Nest_Generic>

=cut

package Nest_Thermo_Away_Low;
use strict;
@Nest_Thermo_Away_Low::ISA = ('Nest_Generic');

sub new {
    my ( $class, $parent ) = @_;
    my $scale = $$parent{scale};
    my $self  = new Nest_Generic( $$parent{interface}, $parent,
        { 'away_temperature_low_' . $scale => '' } );
    bless $self, $class;
    return $self;
}

package Nest_Smoke_CO_Alarm;

=head1 B<Nest_Smoke_CO_Alarm>

=head2 SYNOPSIS

This is a high level module for interacting with the Nest Smoke Alarm.  It is
generally user friendly.

The state of this object will be the combined state of both the CO and smoke 
alarm plus the battery state.  If everything it OK the state will be OK.  Any
emergency state will be listed first, followed by a warning state, followed by
a battery health warning.  You CANNOT set the state of this object, as the 
detector is a read only device.  You can use all of the the C<Generic_Item> 
methods, including c<set>, c<state>, c<state_now>, c<tie_event> to interact with
this object.

=head2 CONFIGURATION

Create a Nest smoke alarm instance in the .mht file:

.mht file:

  CODE, $nest_alarm = new Nest_Smoke_CO_Alarm('Kitchen', $nest); #noloop

The arguments:

    1. The first argument can be either I<the name of the device> or the I<device id>.
       If using the name, this must be the exact verbatim name as listed on the Nest 
       website.  Alternatively, if you want to allow for future name changes without 
       breaking your installation, you can get the device id using the 
       L<print_devices()|Nest_Interface::print_devices> routine.
    2. The second argument is the interface object

=cut 

use strict;

=head2 INHERITS

C<Nest_Generic>

=cut

@Nest_Smoke_CO_Alarm::ISA = ('Nest_Generic');

=head2 METHODS

=over

=item C<new($name, $interface)>

Creates a new Nest_Generic.

    $name         - The name or device if of the Thermostat
    $interface    - The interface object

=cut

sub new {
    my ( $class, $name, $interface ) = @_;
    my $self = new Nest_Generic(
        $interface,
        '',
        {
            'co_alarm_state'    => '',
            'smoke_alarm_state' => '',
            'battery_health'    => ''
        }
    );
    bless $self, $class;
    $$self{class}  = 'devices',
      $$self{type} = 'smoke_co_alarms',
      $$self{name} = $name,
      return $self;
}

sub data_changed {
    my ( $self, $value_name, $new_value ) = @_;
    $self->debug( "Data changed called $value_name, $new_value", $info );
    $$self{$value_name} = $new_value;
    my $state = '';
    if ( $$self{co_alarm_state} eq 'emergency' ) {
        $state .= 'Emergency - CO Detected - move to fresh air';
    }
    if ( $$self{smoke_alarm_state} eq 'emergency' ) {
        $state .= " / " if $state ne '';
        $state .= 'Emergency - Smoke Detected - move to fresh air';
    }
    if ( $$self{co_alarm_state} eq 'warning' ) {
        $state .= " / " if $state ne '';
        $state .= 'Warning - CO Detected';
    }
    if ( $$self{smoke_alarm_state} eq 'warning' ) {
        $state .= " / " if $state ne '';
        $state .= 'Warning - Smoke Detected';
    }
    if ( $$self{battery_health} eq 'replace' ) {
        $state .= " / " if $state ne '';
        $state .= 'Battery Low - replace soon';
    }
    $state = 'ok' if ( $state eq '' );
    $self->set_receive($state);
}

=item C<get_co()>

Returns the carbon monoxide alarm state. [ok,warning,emergency]

=cut

sub get_co {
    my ($self) = @_;
    return $self->get_value("co_alarm_state");
}

=item C<get_smoke()>

Returns the smoke alarm state. [ok,warning,emergency]

=cut

sub get_smoke {
    my ($self) = @_;
    return $self->get_value("smoke_alarm_state");
}

=item C<get_battery()>

Returns the detector battery health. [ok,replace]

=cut

sub get_battery {
    my ($self) = @_;
    return $self->get_value("battery_health");
}

##Home/Away is in the structure

package Nest_Structure;

=back

=head1 B<Nest_Structure>

=head2 SYNOPSIS

This is a high level module for interacting with the Nest Structure object.  It is
generally user friendly.

The state of this object will be set to the home/away state of the structure. You
can use all of the the C<Generic_Item> methods, including c<set>, c<state>, c<state_now>, 
c<tie_event> to interact with this object.

=head2 CONFIGURATION

Create a Nest structure instance in the .mht file:

.mht file:

  CODE, $nest_home = new Nest_Structure('Home', $nest); #noloop

The arguments:

    1. The first argument can be either I<the name of the structure> or the I<structure id>.
       If using the name, this must be the exact verbatim name as listed on the Nest 
       website.  Alternatively, if you want to allow for future name changes without 
       breaking your installation, you can get the device id using the 
       L<print_structures()|Nest_Interface::print_structures> routine.
    2. The second argument is the interface object

=cut 

use strict;

=head2 INHERITS

C<Nest_Generic>

=cut

@Nest_Structure::ISA = ('Nest_Generic');

=head2 METHODS

=over

=item C<new($name, $interface)>

Creates a new Nest_Generic.

    $name         - The name or device if of the Thermostat
    $interface    - The interface object

=cut

sub new {
    my ( $class, $name, $interface ) = @_;
    my $self = new Nest_Generic( $interface, '', { 'away' => '' } );
    bless $self, $class;
    $$self{class}    = 'structures',
      $$self{type}   = '',
      $$self{name}   = $name,
      $$self{states} = [ 'home', 'away' ];
    return $self;
}

=item C<get_away_status()>

Returns the state of the structure. [home,away]

=cut

sub get_away_status {
    my ($self) = @_;
    return $self->get_value("away");
}

=item C<set_away_status($state, $p_setby, $p_response)>

Sets the state of the structure.  $State must be [home,away].  This will cause
all devices inside this structure to change to the set state.

=cut

sub set_away_status {
    my ( $self, $state, $p_setby, $p_response ) = @_;
    $state = lc($state);
    if ( $state ne 'home' && $state ne 'away' ) {
        $self->debug("set_away_status must be either home or away.");
        return;
    }
    $$self{interface}->write_data( $self, 'away', $state );
    $$self{state_pending}{away} = [ $p_setby, $p_response ];
}

sub set {
    my ( $self, $p_state, $p_setby, $p_response ) = @_;
    $self->set_away_status( $p_state, $p_setby, $p_response );
}

#I did not add high level support for the ETA feature, although it can be
#set using the low level write_data function with a bit of work

=back

=head1 AUTHOR

Kevin Robert Keegan

=head1 SEE ALSO

http://developer.nest.com/

=head1 LICENSE

This program is free software; you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation; either version 2 of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more details.

You should have received a copy of the GNU General Public License along with this program; if not, write to the Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.

=cut
