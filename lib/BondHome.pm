
=head1 B<BondHome>


=head2 DESCRIPTION

Module for interfacing with the BondHome Hub to control devices configured in it.

=head2 CONFIGURATION

At minimum, you must define the Interface and one BondHome_Device object. 
This allows for the display and control of these objects as separate items 
in the MH interface and allows users to interact directly with these objects 
using the basic Generic_Item functions such as tie_event.


The BondHome_Device object is for tracking the state of and controlling
devices configured in the bondhome hub.

Misterhouse loads all devices and device commands from BondHome when it is started. 
You must reload the BondHome device and trigger and retrieve an auth token by setting the 
parent object to "GETTOKEN" with in 1 min after the reboot.

=head2 Interface Configuration

mh.private.ini configuration:

In order to allow for multiple BondHome Hubs, instance names are used.
the following are prefixed with the instance name (BondHome).



The IP of the BondHome Hub:
        BondHome_ip=192.168.1.50
		

Max command retry:
        BondHome_maxretry=4


=head2 Defining the Interface Object

In addition to the above configuration, you must also define the interface
object.  The object can be defined in the user code.

In user code:

   $BondHome = new BondHome('BondHome');

Wherein the format for the definition is:

   $BondHome = new BondHome(INSTANCE);

=head2 Device Object

        $BondHome_Device = new BondHome_Device('BondHome');

Wherein the format for the definition is:
        $BondHome_Device = new BondHome_Device(INSTANCE);

States:
Dynamic from the bond home



=head2 NOTES

An example mh.private.ini:

        BondHome_maxretry=4
        BondHome_ip=192.168.1.50


An example user code:

        #noloop=start
        use BondHome;
        $BondHome = new BondHome('BondHome');
        $MasterFan = new BondHome_Device('BondHome','MasterFan');
        #noloop=stop


=head2 INHERITS

L<Generic_Item>

=head2 METHODS

=over

=cut

package BondHome;
@BondHome::ISA = ('Generic_Item');

use Data::Dumper;
use JSON qw(decode_json);

sub new {
    my ( $class, $instance ) = @_;
    $instance = "BondHome" if ( !defined($instance) );
    ::print_log("Starting $instance instance of BondHome interface module");

    my $self = new Generic_Item();

    # Initialize Variables
    $$self{instance} = $instance;
    $$self{maxretry} = $::config_parms{ $instance . '_maxretry' };
    $$self{ip} = $::config_parms{ $instance . '_ip' };
    my $year_mon = &::time_date_stamp( 10, time );
    $$self{log_file} = $::config_parms{'data_dir'} . "/logs/BondHome.$year_mon.log";

    bless $self, $class;

    #Store Object with Instance Name
    $self->_set_object_instance($instance);
    $self->restore_data( 'token' );
	$$self{token} = '4b8d109022195f1b';
    @{$$self{states}} = ('gettoken','reboot','logdevs','reloadcache');
    return $self;
}

sub get_object_by_instance {
    my ($instance) = @_;
    return $Interfaces{$instance};
}

sub _set_object_instance {
    my ( $self, $instance ) = @_;
    $Interfaces{$instance} = $self;
}

sub init {

}

=item C<register()>

Used to associate child objects with the interface.

=cut

sub register {
    my ( $self, $object, $class ) = @_;
    if ( $object->isa('BondHome_Device') ) {
        ::print_log("Registering Child Object for BondHome Device");
		push @{ $self->{device_object} }, $object;
    }
}



sub set {
    my ( $self, $p_state, $p_setby, $p_response ) = @_;
    ::print_log( "[BOND] Unknown request " . $p_state . " for " . $self->get_object_name );
    if ( $p_state eq 'GETTOKEN' ) {
        ::print_log( "[BOND] Received request " . $p_state . " for " . $self->get_object_name );
        $self->SUPER::set( $p_state, $p_setby );
        $self->gettoken( $object, $class );
    }
    elsif ( $p_state eq 'REBOOT' ) {
        ::print_log( "[BOND] Received request " . $p_state . " for " . $self->get_object_name );
        $self->SUPER::set( $p_state, $p_setby );
	$self->reboot( $object, $class );
    }
    elsif ( $p_state eq 'LOGDEVS' ) {
        ::print_log( "[BOND] Received request " . $p_state . " for " . $self->get_object_name );
        $self->SUPER::set( $p_state, $p_setby );
	$self->logdevs( $object, $class );
    }
    elsif ( $p_state eq 'RELOADCACHE' ) {
        ::print_log( "[BOND] Received request " . $p_state . " for " . $self->get_object_name );
        $self->SUPER::set( $p_state, $p_setby );
	$self->reloadcache( $object, $class );
    }
    else {
	::print_log( "[BondHome] Unknown request " . $p_state . " for " . $self->get_object_name ); 
    }
}

 

sub devexists {
	my ( $self, $object, $devicename, $class ) = @_;
	my $ip = $$self{ip};
	my $token = $$self{token};

	unless ( $token ) { 
		::print_log ("[BOND] (Sub devexists) You must reboot the Bond Home and set the parent BondHome object to gettoken to get/set the token");
		return;
	}
	
	unless ( $self->{devicehash}->{devicename} ) {
		::print_log ("[BOND] There are no devices in cache, running reload cache ". $self->get_object_name );
		$self->reloadcache( $object, $class );
			
		#::print_log Dumper $self;

		unless ( $self->{devicehash}->{devicename} ) {
			::print_log ("[BOND] (Sub devexists) There are no devices in cache after reloading the cache, something went wrong");
			return;
		}
	}
	
	return 1 if ( exists $self->{devicehash}->{devicename}->{$devicename} ); 
	
	::print_log ( "[BOND] there is no device with the name \"$devicename\" configured on the BondHome Hub " . $self->get_object_name );
	return;
}


sub getdevstates {
	my ( $self, $object, $class ) = @_;
	my $token = $$self{token};
	my $devicename = $$object{devicename};
	
	unless ( $token ) { 
		::print_log "[BOND] (Sub getdevstates) You must reboot the Bond Home and set the parent BondHome object to gettoken to get/set the token";
		return;
	}
	
	unless ( $self->{devicehash}->{devicename} ) {
		::print_log "[BOND] There are no devices in cache, running reload cache";
		$self->reloadcache( $object, $class );
		
		unless ( $self->{devicehash}->{devicename} ) {
			::print_log "[BOND] (Sub getdevstates) There are no devices in cache after reloading the cache, something went wrong";
			return;
		}
	}
	

	my @states;
	foreach my $command (keys %{$self->{devicehash}->{devicename}->{$devicename}->{commands}->{name}} )  {
		push @states, cleanstring($command);
	}
	return @states;
}


sub sendcmd {
	my ( $self, $object, $devicename, $cmd, $class ) = @_;
	
	unless ( $$self{token} ) { 
		::print_log "[BOND] (Sub sendcmd) You must reboot the Bond Home and set the parent BondHome object to gettoken to get/set the token";
		return;
	}

	my $maxretry = $$self{maxretry};
	$devicename = cleanstring($devicename);
	$cmd = cleanstring($cmd);
	
	if ( $self->{devicehash}->{devicename}->{$devicename}->{commands}->{name}->{$cmd}->{id} ) {
        my $deviceid = $self->{devicehash}->{devicename}->{$devicename}->{id};
        my $cmdid = $self->{devicehash}->{devicename}->{device}->{commands}->{name}->{$cmd}->{id};
        for (0..$maxretry) {
			my $response = $self->bondcmd( $object, $class, "/v2/devices/$deviceid/commands/$cmdid/tx" );
			last if $response;
        }
	} else {
        ::print_log "[BOND] Invalid command: $cmd for " . $self->get_object_name;
	}

}

sub cleanstring {
	my ( $string ) = @_;
	$string = uc $string;
	$string =~ s/ //g;
	return $string;
}


sub reboot { 
	my ( $self, $object, $class ) = @_;
	my $token = $$self{token};
	unless ( $token ) { 
		::print_log "[BOND] (Sub reboot) You must reboot the Bond Home and set the parent BondHome object to gettoken to get/set the token";
		return;
	}
	$self->bondcmd( $object, $class, '/v2/sys/reboot' );
}


sub logdevs {
	my ( $self, $object, $class ) = @_;
	my $token = $$self{token};
	
	unless ( $token ) { 
		::print_log "[BOND] (Sub logdevs) You must reboot the Bond Home and set the parent BondHome object to gettoken to get/set the token";
		return;
	}
	
	unless ( $self->{devicehash}->{devicename} ) {
		::print_log "[BOND] There are no devices in cache, running reload cache";
		$self->reloadcache( $self, $object, $class );
	}
	foreach my $devicename (keys %{$self->{devicehash}->{devicename}}) {
			::print_log "[BOND] Device: $device";
			::print_log "[BOND] ---- Commands:";
			foreach my $command (keys %{$self->{devicehash}->{devicename}->{$devicename}->{commands}->{name}} )  {
					::print_log "[BOND] ---- $command";
			}
	}
}


sub gettoken { 
	my ( $self, $object, $class ) = @_;
	::print_log "[BOND] Getting Token";
	my $response = $self->bondcmd( $object, $class, '/v2/token' );
	my $message = $response->decoded_content;
	eval { $message = decode_json($message) };
	if ( $message->{locked} ) {
			::print_log "[BOND] You must reboot the Bond Home before running gettoken";
			return;
	}
	$$self{token} = $message->{token};
	delete $self->{devicehash} if $self->{devicehash};
	$self->{devicehash} = $self->getbonddevs( $object, $class);
}


sub reloadcache {
	my ( $self, $object, $class ) = @_;
 
	::print_log "[BOND] Reloading local device cache from Bond";
	delete $self->{devicehash}->{devicename} if $self->{devicehash}->{devicename};
	$self->getbonddevs( $object, $class ); 
}


sub getbonddevs {
 my ( $self, $object, $class ) = @_;
 my $maxretry = $$self{maxretry};
 my $token = $$self{token};
 my $response;
 unless ( $token ) { 
	::print_log "[BOND] (Sub getbonddevs) You must reboot the Bond Home and set the parent BondHome object to gettoken to get/set the token";
	return;
 }
 for (0..$maxretry) {
        $response = $self->bondcmd( $object, $class, '/v2/devices' );
 }
 return unless $response;
        my $message = $response->decoded_content;
        eval { $message = decode_json($message) };
		
	::print_log("[BOND] reloading MH device cache from bond");

        foreach my $deviceid (keys %{$message}) {
                next if $deviceid =~ /_/;
                for (0..$maxretry) {
                        $response = $self->bondcmd( $object, $class, "/v2/devices/$deviceid" );
                        last if $response;
                }
                next unless $response;
                my $message = $response->decoded_content;
                eval { $message = decode_json($message) };
                my $devicename = $message->{name};
                $self->{devicehash}->{devicename}->{$devicename}->{id}=$deviceid;
                #::print_log Dumper $message;
                my $response2;
                for (0..$maxretry) {
                        $response2 = $self->bondcmd( $object, $class, "/v2/devices/$deviceid/commands" );
                        last if $response2;
                }
                next unless $response2;
                my $message2 = $response2->decoded_content;
                eval { $message2 = decode_json($message2) };
                foreach my $cmdid (keys %{$message2}) {
                        next if $cmdid =~ /_/;
                        for (0..$maxretry) {
                                $response = $self->bondcmd( $object, $class, "/v2/devices/$deviceid/commands/$cmdid" );
                                last if $response;
                        }
                        next unless $response;
                        my $message = $response->decoded_content;
                        eval { $message = decode_json($message) };
                        $self->{devicehash}->{devicename}->{$devicename}->{commands}->{name}->{$message->{name}}->{id}=$cmdid;
                        #::print_log Dumper $$self{devicehash};
                }

        ::print_log "[BOND] \n\n<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<Next Device>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>\n\n" if $debug;
        }
}


sub bondcmd {
	my ( $self, $object, $class, $url ) = @_;
	use LWP::UserAgent;
	use HTTP::Request;
	my $ip = $$self{ip};
	my $token = $$self{token};
	my $userAgent = LWP::UserAgent->new();
	$userAgent->timeout(1);
	my $request;
	if ( ($url =~ /\/tx$/) or ($url =~ /\/reboot$/) ) {
		$request = HTTP::Request->new(PUT => 'http://'.$ip.$url);
		$request->content('{}');
	} else {
		$request = HTTP::Request->new(GET => 'http://'.$ip.$url);
	}
	
	unless ( $url =~ /\/token$/ ) {
		$request->header('Host' => "$ip");
		$request->header('BOND-Token' => "$token");
	}
	
	my $response = $userAgent->request($request);
	if ($response->is_error) {
		::print_log("[BOND] http request: http://$ip$url failed - ". $response->status_line);
		if ($response->status_line =~ /read timeout/) {
			::print_log("[BOND] retrying request: http://$ip$url");
		}
		return 0;
	}
	return $response;
}

=back

=head1 B<BondHome_Device>

=head2 SYNOPSIS

User code:

    $BondHome_Device = new BondHome_Device('BondHome');

     Wherein the format for the definition is:
    $BondHome_Device = new BondHome_Device(INSTANCE);

See C<new()> for a more detailed description of the arguments.


=head2 DESCRIPTION

 Configures a device from the BondHome to be controlled by MH.

=head2 INHERITS

L<Generic_Item>

=head2 METHODS

=over

=cut

package BondHome_Device;
@BondHome_Device::ISA = ('Generic_Item');

=item C<new( $instance, $devicename )>

Instantiates a new object.

$instance = The instance of the parent BondHome hub object that this device is found on

$devicename = The name of the device used on the bondhome hub

=cut


sub new {
    my ( $class, $instance, $devicename ) = @_;
    my $self = new Generic_Item();
    bless $self, $class;
    $$self{parent} = BondHome::get_object_by_instance($instance);
    $$self{parent}->register( $self, $class );
	$$self{devicename} = $devicename;
	
	$$self{parent}->devexists( $self, $devicename, $class );
	
	#@{ $$self{states} } = ('ON','OFF');
	@{ $$self{states} } = $$self{parent}->getdevstates( $self, $class );
	
    return $self;
}


sub set {
    my ( $self, $p_state, $p_setby, $p_response ) = @_;
     ::print_log( "[BOND] Unknown request " . $p_state . " for " . $self->get_object_name );
	
    if ( $self->validstate( $p_state ) ) {
        ::print_log( "[BondHome::Device] Received request " . $p_state . " for " . $self->get_object_name );
        $self->SUPER::set( $p_state, $p_setby );
		$$self{parent}->sendcmd( $self, $$self{devicename}, $cmd, $class )
    }
    else  {
        ::print_log( "[BondHome::Device] Received INVALID request " . $p_state . " for " . $self->get_object_name );
    }
}

sub validstate { 
	my ( $self, $p_state ) = @_;
	
	foreach my $state ( @{ $$self{states} } ) {
		if ( $state eq $p_state ) {
			return 1;
		}
	}
	return 0;
}


sub updatestates { 
	my ( $self, $class ) = @_;
	@{ $$self{states} } = $$self{parent}->getdevstates( $self, $class );
}

=back

=head2 INI PARAMETERS

=head2 NOTES

=head2 AUTHOR

Wayne Gatlin <wayne@razorcla.ws>

=head2 SEE ALSO

=head2 LICENSE

This program is free software; you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation; either version 2 of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more details.

You should have received a copy of the GNU General Public License along with this program; if not, write to the Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.

=cut

