
=head1 B<BondHome>


=head2 DESCRIPTION

Module for interfacing with the BondHome Hub to control IR/RF devices such as fans.

=head2 CONFIGURATION

At minimum, you must define the BondHome_ip in the mh.private.ini and the Interface
object. Once they are configured you can restart MH, once MH is back up restart the Bond Hub, 
next set the Bond Hub interface object to "GetToken" within a few min after the Bond Hub reboot. 
Once the token is successfuly retreved, set the Bond Hub interface object to "LogDevs"
and copy the device code from the MH logs and paste into a MH .mht file in your code directory. 
You will need all the devices preconfigured in the BondHome Hub because MH pulls them including the names from it.
The BondHome_Device objects allow for the display and control of these objects as separate items 
in the MH interface and allows users to interact directly with these objects 
using the basic Generic_Item functions such as tie_event.


The BondHome_Device object is for tracking the state of and controlling
devices configured in the BondHome hub through the BondHome app and stored in 
the local BondHome hub database. These devices are pulled from the BondHome Hub 
with the local api.

Misterhouse loads all devices and device commands from BondHome when it is started. 
You must reload the BondHome device and trigger and retrieve an auth token by setting the 
parent object to "GetToken" with in a few min after the reboot.

The BondHome_Manual object is for manually recording remote signals and sending them from Misterhouse.
This bypasses the BondHome Hub database and just tells the BondHome Hub what signal to transmit directly. 
To record a signal, set the Bond Hub interface object to ScanRF or ScanIR depending on what kind of remote 
you are recording. Once scan is enabled, put the remote close to the hub and push the button you want to 
record a few times and watch for the hub lights to change colors (This is the same process as the initial hub setup
through the app). Next set the Bond Hub interface object to ScanCheck and the .mht code for the recorded 
command will be logged, update the device name IE: MasterFan and the command name IE: PowerOff and 
paste the code in your .mht file.

=head2 Interface Configuration

mh.private.ini configuration:

In order to allow for multiple BondHome Hubs, instance names are used.
the following are prefixed with the instance name (BondHome).



The IP of the BondHome Hub:
        BondHome_ip=192.168.1.50
		

Max command retrys when a command fails to send to the BondHome Hub:
        BondHome_maxretry=4


=head2 Defining the Interface Object

In addition to the above configuration, you must also define the interface
object.  The object can be defined in the user code.

In user code:

   $BondHomeHub = new BondHome('BondHome');

Wherein the format for the definition is:

   $BondHomeHub = new BondHome(INSTANCE);

States:
GetToken,Reboot,LogDevs,ReloadCache,LogVersion,ScanRF,ScanIR,ScanStop,ScanCheck



=head2 NOTES

An example mh.private.ini:

        BondHome_maxretry=4
        BondHome_ip=192.168.1.50


An example user code:

        #noloop=start
		
        use BondHome;
		
        $BondHomeHub = new BondHome('BondHome');
		
        $MasterFan = new BondHome_Device('BondHome','MasterFan');
		
		$TV = new BondHome_Manual('BondHome');
		$TV->addcmd('power', '38', 'OOK', 'hex', '40000', '1', '00000<snip>');
		
        #noloop=stop
		
		
An example .mht code:
		BONDHOME,           BondHome,           BondHome
		BONDHOME_DEVICE,    masterfan,          BondHome,           masterfan
		BONDHOME_DEVICE,    guestfan,           BondHome,           guestfan


		BONDHOME_MANUAL,     TV,           BondHome
		BONDHOME_MANUAL_CMD, TV,  power, 38, OOK, hex, 40000, 1, 0000000<snip>


=head2 INHERITS

L<Generic_Item>

=head2 METHODS

=over

=cut

package BondHome;
@BondHome::ISA = ('Generic_Item');

use Data::Dumper;
use JSON;

sub new {
    my ( $class, $instance ) = @_;
    $instance = "BondHome" if ( !defined($instance) );
    ::print_log("Starting $instance instance of BondHome interface module");

    my $self = new Generic_Item();

    # Initialize Variables
    $$self{instance} = $instance;
    $$self{maxretry} = $::config_parms{ $instance . '_maxretry' } || 4;
    $$self{ip} = $::config_parms{ $instance . '_ip' };
    my $year_mon = &::time_date_stamp( 10, time );
    $$self{log_file} = $::config_parms{'data_dir'} . "/logs/BondHome.$year_mon.log";
	$$self{token_file} = $::config_parms{'data_dir'} . "/.bh-$instance";

    bless $self, $class;

    #Store Object with Instance Name
    $self->_set_object_instance($instance);
    #$self->restore_data( 'token' );
	$$self{token} = $self->get_data($$self{token_file}); #The normal restore_data happens after new is called, so we have to save to a file.
    @{$$self{states}} = ('GetToken','Reboot','LogDevs','ReloadCache', 'LogVersion', 'ScanRF', 'ScanIR', 'ScanStop', 'ScanCheck');
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
        ::print_log("Registering BondHome Device Child Object");
	push @{ $self->{device_object} }, $object;
	} elsif ( $object->isa('BondHome_Manual') ) {
        ::print_log("Registering BondHome Manual Child Object" );
	push @{ $self->{manual_object} }, $object;
    }
}
 


sub set {
    my ( $self, $p_state, $p_setby, $p_response ) = @_;
    if ( uc $p_state eq 'GETTOKEN' ) {
        ::print_log( "[BondHome] Received request " . $p_state . " for " . $self->get_object_name );
        $self->SUPER::set( $p_state, $p_setby );
        $self->gettoken( $object, $class );
    } elsif ( uc $p_state eq 'REBOOT' ) {
        ::print_log( "[BondHome] Received request " . $p_state . " for " . $self->get_object_name );
        $self->SUPER::set( $p_state, $p_setby );
		return unless $self->tokencheck;
		$self->bondcmd( $class, '/v2/sys/reboot', 'PUT', '{}' );
    } elsif ( uc $p_state eq 'LOGDEVS' ) {
        ::print_log( "[BondHome] Received request " . $p_state . " for " . $self->get_object_name );
        $self->SUPER::set( $p_state, $p_setby );
		$self->logdevs( $object, $class );
    } elsif ( uc $p_state eq 'LOGVERSION' ) {
        ::print_log( "[BondHome] Received request " . $p_state . " for " . $self->get_object_name );
        $self->SUPER::set( $p_state, $p_setby );
		return unless $self->tokencheck;
		::print_log "[BondHome] version ".$self->bondcmd( $class, '/v2/sys/version', 'GET')->{_content};	
    } elsif ( uc $p_state eq 'RELOADCACHE' ) {
        ::print_log( "[BondHome] Received request " . $p_state . " for " . $self->get_object_name );
        $self->SUPER::set( $p_state, $p_setby );
		return unless $self->tokencheck;
        ::print_log "[BondHome] Reloading local device cache from Bond";
        delete $self->{devicehash}->{devicename} if $self->{devicehash}->{devicename};
        $self->getbonddevs( $object, $class );
		foreach my $child ( @{ $self->{device_object} } ) { 
			$child->updatestates($class);
		}
    } elsif ( uc $p_state eq 'SCANRF' ) {
		$self->scan('RF',$class );
	} elsif ( uc $p_state eq 'SCANIR' ) {
		$self->scan('IR',$class );
	} elsif ( uc $p_state eq 'SCANSTOP' ) {
		$self->scan('STOP',$class );
	} elsif ( uc $p_state eq 'SCANCHECK' ) {
		$self->scan('CHECK',$class );
	} else {
		::print_log( "[BondHome] Unknown request " . $p_state . " for " . $self->get_object_name ); 
    }
}

sub tokencheck { 
	my ( $self ) = @_;
	unless ( $$self{token} ) { 
		::print_log "[BondHome] You must reboot the Bond Home and set the parent BondHome object to gettoken to get/set the token";
		return;
	}
	return 1; 
} 

sub devexists {
	my ( $self, $object, $class ) = @_;
	my $token = $$self{token};
	my $devicename = $$object{devicename};

	return unless $self->tokencheck;
	
	unless ( $self->{devicehash}->{devicename} ) {
		::print_log ("[BondHome] There are no devices in cache, running reload cache ". $self->get_object_name );
		$self->getbonddevs( $object, $class );
			
		unless ( $self->{devicehash}->{devicename} ) {
			::print_log ("[BondHome] (Sub devexists) There are no devices in cache after reloading the cache, something went wrong");
			return;
		}
	}
	
	return 1 if ( exists $self->{devicehash}->{devicename}->{$devicename} ); 
	
	::print_log ( "[BondHome] there is no device with the name \"$devicename\" configured on the BondHome Hub " . $self->get_object_name );
	return;
}


sub getdevstates {
	my ( $self, $object, $class ) = @_;
	my $token = $$self{token};
	my $devicename = $$object{devicename};
	
	return unless $self->tokencheck;
	
	unless ( $self->{devicehash}->{devicename} ) {
		::print_log "[BondHome] There are no devices in cache, running reload cache";
		$self->getbonddevs( $object, $class );
		
		unless ( $self->{devicehash}->{devicename} ) {
			::print_log "[BondHome] (Sub getdevstates) There are no devices in cache after reloading the cache, something went wrong";
			return;
		}
	}
	

	my @states;
	my @speeds;
	foreach my $command (keys %{$self->{devicehash}->{devicename}->{$devicename}->{commands}->{name}} )  {
		push @states, ucfirst($command);
		if ( normalize($command) =~ /speed(\d)/ ) {
			push @speeds, $1;
        }
	}
	@speeds = sort @speeds;
	push @states, @speeds;
	return @states;
}


sub normalize {
	my ( $string ) = @_;
	$string = lc $string;
	$string =~ s/ //g;
	return $string;
}

sub get_data {
	my ( $self, $file ) = @_;
	if( -e $file ) {
		open my $FH, '<', $file or ::print_log "[BondHome] failed to open token file $!";
		while (my $line = <$FH>) {
			$line  =~ s/^\s+//;
			$line  =~ s/\s+$//;
			if ( length($line) > 1 ) { 
				close $FH;
				return $line;
			}
		}
		close $FH;
	}
}


sub save_data {
	my ( $self, $file, $data ) = @_;
	::print_log "[BondHome] saving token to $file";
	open my $FH, '>', $file or ::print_log "[BondHome] failed to save token to file $!";
	print $FH $data;
	close($FH);
}


sub scan { 
	my ( $self, $type, $class ) = @_;
	my $token = $$self{token};
	my $instance = $$self{instance};
	my $http;
	my $content;
	my $url = '/v2/signal/scan';
	
	if ($type eq 'IR') {
		$http = 'PUT';
		$content = '{ "freq": 38, "modulation": "OOK" }';
	} elsif ($type eq 'RF') {
		$http = 'PUT';
		$content = '{ "modulation": "OOK" }'; #RF all frequencies 	
	} elsif ($type eq 'STOP') { 
		$http = 'DELETE';
	} elsif ($type eq 'CHECK') { 
		$http = 'GET';
	}

	return unless $self->tokencheck;
	
	my $response = $self->bondcmd( $class, $url, $http, $content );
	
	#BONDHOME_MANUAL,     masterfan,           BondHome
    #BONDHOME_MANUAL_CMD, masterfan,  power, 434000, OOK, cq, 1000, 12, 110100110110H

	
	if ($type eq 'CHECK') {
		return unless $response;
		my $message = $response->decoded_content;
		eval { $message = decode_json($message) };
		if ( $message->{success} ) { 
			my $response2 = $self->bondcmd( $class, $url.'/signal', 'GET' );
			return unless $response2;
			my $message2 = $response2->decoded_content;
			eval { $message2 = decode_json($message2) };
			
			::print_log "[BondHome] Listing mht code for manual device command";
			my $msg = "\nBONDHOME_MANUAL,    dev_name_update_me,           $instance";
			$msg .= "\nBONDHOME_MANUAL_CMD,  dev_name_update_me, cmd_name_update_me, ".$message2->{freq}.", ".$message2->{modulation}.", ".$message2->{encoding}.", ".$message2->{bps}.", ".$message2->{reps}.", ".$message2->{data};
			::print_log $msg;	
		} elsif ( $message->{running} ) {
			::print_log "[BondHome] Scan is still running and no signals have been seen";
		} else {
			::print_log "[BondHome] Scan has timed out and no signals have been seen";
		}
	}
}



sub logdevs {
	my ( $self, $object, $class ) = @_;
	my $token = $$self{token};
	my $instance = $$self{instance};
	my $name = $self->get_object_name;
	$name =~ s/\$//;
	
	return unless $self->tokencheck;
	
	unless ( $self->{devicehash}->{devicename} ) {
		::print_log "[BondHome] There are no devices in cache, running reload cache";
		$self->getbonddevs( $object, $class );
	}
	::print_log "[BondHome] Listing mht code for Bond devices";
	my $message = "\nBONDHOME,           $name,           $instance";
	foreach my $devicename (keys %{$self->{devicehash}->{devicename}}) {
		$message .= "\nBONDHOME_DEVICE,    $devicename,           $instance,           $devicename";
	}
	::print_log $message;
}


sub gettoken { 
	my ( $self, $object, $class ) = @_;
	::print_log "[BondHome] Getting Token";
	my $response = $self->bondcmd( $class, '/v2/token', 'GET' );
	my $message = $response->decoded_content;
	eval { $message = decode_json($message) };
	if ( $message->{locked} ) {
			::print_log "[BondHome] You must reboot the Bond Home before running gettoken";
			return;
	}
	$$self{token} = $message->{token};
	my $token = $message->{token};
	$self->save_data( $$self{token_file}, $token );
	::print_log "[BondHome] Got Token: $$self{token}" if $$self{token};
	delete $self->{devicehash} if $self->{devicehash};
	$self->{devicehash} = $self->getbonddevs( $object, $class);
}


sub reloadcache {
	my ( $self, $object, $class ) = @_;
 
	::print_log "[BondHome] Reloading local device cache from Bond";
	delete $self->{devicehash}->{devicename} if $self->{devicehash}->{devicename};
	$self->getbonddevs( $object, $class ); 
}


sub getbonddevs {
 my ( $self, $class ) = @_;
 my $maxretry = $$self{maxretry};
 my $token = $$self{token};
 my $response;
 return unless $self->tokencheck;
 for (0..$maxretry) {
        $response = $self->bondcmd( $class, '/v2/devices', 'GET' );
 }
 return unless $response;
        my $message = $response->decoded_content;
        eval { $message = decode_json($message) };
		
	::print_log("[BondHome] reloading MH device cache from bond");

        foreach my $deviceid (keys %{$message}) {
                next if $deviceid =~ /_/;
                for (0..$maxretry) {
                        $response = $self->bondcmd( $class, "/v2/devices/$deviceid", 'GET' );
                        last if $response;
                }
                next unless $response;
                my $message = $response->decoded_content;
                eval { $message = decode_json($message) };
                my $devicename = normalize($message->{name});
                $self->{devicehash}->{devicename}->{$devicename}->{id}=$deviceid;
				
				foreach my $action ( @{$message->{actions}} ) {
					next if ( $action =~ /^Set/ ); #Skip the Set actions because they require arguments. 
					next if ( $action =~ /^IncreaseSpeed/ ); #Skip the IncreaseSpeed actions because they require arguments.
					next if ( $action =~ /^DecreaseSpeed/ ); #Skip the DecreaseSpeed actions because they require arguments.
					$self->{devicehash}->{devicename}->{$devicename}->{commands}->{name}->{normalize($action)}->{action}=$action;
				}
                #::print_log Dumper $message;
                my $response2;
                for (0..$maxretry) {
                        $response2 = $self->bondcmd( $class, "/v2/devices/$deviceid/commands", 'GET' );
                        last if $response2;
                }
                next unless $response2;
                my $message2 = $response2->decoded_content;
                eval { $message2 = decode_json($message2) };
                foreach my $cmdid (keys %{$message2}) {
                        next if $cmdid =~ /_/;
                        for (0..$maxretry) {
                                $response = $self->bondcmd( $class, "/v2/devices/$deviceid/commands/$cmdid", 'GET' );
                                last if $response;
                        }
                        next unless $response;
                        my $message = $response->decoded_content;
                        eval { $message = decode_json($message) };
						my $cmdname = normalize($message->{name});
                        $self->{devicehash}->{devicename}->{$devicename}->{commands}->{name}->{$cmdname}->{id}=$cmdid;
                        #::print_log Dumper $$self{devicehash};
                }

        ::print_log "[BondHome] \n\n<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<Next Device>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>\n\n" if $debug;
        }
}



sub sendcmd {
        my ( $self, $object, $cmdname, $class, $argument ) = @_;

        return unless $self->tokencheck;

        my $maxretry = $$self{maxretry};
        my $devicename = $$object{devicename};
        $cmdname = normalize($cmdname);

        if ( exists $self->{devicehash}->{devicename}->{$devicename}->{commands}->{name}->{$cmdname}->{id} ) {
        	my $deviceid = $self->{devicehash}->{devicename}->{$devicename}->{id};
        	my $cmdid = $self->{devicehash}->{devicename}->{$devicename}->{commands}->{name}->{$cmdname}->{id};
        	for (0..$maxretry) {
        		my $response = $self->bondcmd( $class, "/v2/devices/$deviceid/commands/$cmdid/tx", 'PUT', '{}' );
        		last if $response;
        	}
		} elsif ( exists $self->{devicehash}->{devicename}->{$devicename}->{commands}->{name}->{$cmdname}->{action} ) {
			my $deviceid = $self->{devicehash}->{devicename}->{$devicename}->{id};
			my $action = $self->{devicehash}->{devicename}->{$devicename}->{commands}->{name}->{$cmdname}->{action};
			if ( $argument ) { 
				$argument = '{"argument": '.$argument.'}'; 
			} else { 
				$argument = '{}';
			}
			for (0..$maxretry) {
        		my $response = $self->bondcmd( $class, "/v2/devices/$deviceid/actions/$action", 'PUT', $argument );
        		last if $response;
        	}
        } else {
                ::print_log "[BondHome] Invalid command: $cmdname for " . $self->get_object_name;
        }

}


sub bondcmd {
	my ( $self, $class, $url, $function, $content ) = @_;
	use LWP::UserAgent;
	use HTTP::Request;
	my $ip = $$self{ip};
	my $token = $$self{token};
	my $userAgent = LWP::UserAgent->new();
	$userAgent->timeout(1);
	my $request;
	
	if ( $function eq 'PUT' ) {
		$request = HTTP::Request->new(PUT => 'http://'.$ip.$url);
		$request->content($content);
	} elsif ( $function eq 'POST' ) {
		$request = HTTP::Request->new(POST => 'http://'.$ip.$url);
		$request->content($content);
	} elsif ( $function eq 'DELETE' ) {
		$request = HTTP::Request->new(DELETE => 'http://'.$ip.$url);
	} elsif ( $function eq 'GET' ) {
		$request = HTTP::Request->new(GET => 'http://'.$ip.$url);
	}
	
	unless ( $url =~ /\/token$/ ) {
		$request->header('Host' => "$ip");
		$request->header('BOND-Token' => "$token");
	}
	
	#::print_log("[BondHome] request: ".Dumper $request);
	my $response = $userAgent->request($request);
	if ($response->is_error) {
		::print_log("[BondHome] http request: http://$ip$url failed - ". $response->status_line ." ". $response ->decoded_content);
		if ($response->status_line =~ /read timeout/) {
			::print_log("[BondHome] retrying request: http://$ip$url");
		}
		return 0;
	}
	return $response;
}

=back

=head1 B<BondHome_Device>

=head2 SYNOPSIS

User code:

    $LivingRoomFan = new BondHome_Device('BondHome','livingroomfan');

     Wherein the format for the definition is:
    $BondHome_Device = new BondHome_Device(INSTANCE,BondHomeDeviceName);
	
States:
Dynamic from BondHome Hub

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
	$$self{devicename} = normalize($devicename);
	
	$$self{parent}->devexists( $self, $class );
	
	@{ $$self{states} } = $$self{parent}->getdevstates( $self, $class );
	
	return $self;
}


sub set {
    my ( $self, $p_state, $p_setby, $p_response ) = @_;
	
    $p_state = normalize($p_state);
	if ( $p_state =~ /^\d+$/ ) {
			$p_state = "speed$p_state";
	}
    if ( $self->validstate( $p_state ) ) {
        ::print_log( "[BondHome::Device] Received request " . $p_state . " for " . $self->get_object_name );
        $self->SUPER::set( $p_state, $p_setby );
		$$self{parent}->sendcmd( $self, normalize($p_state), $class );
    }
    else  {
        ::print_log( "[BondHome::Device] Received INVALID request " . $p_state . " for " . $self->get_object_name );
    }
}

sub validstate { 
	my ( $self, $p_state ) = @_;
	
	foreach my $state ( @{ $$self{states} } ) {
		if ( normalize($state) eq $p_state ) {
			return $p_state;
		}
		
	}
	return 0;
}

sub getcmd {
        my ( $self, $cmd ) = @_;

        foreach my $state ( @{ $$self{states} } ) {
                if ( normalize($state) =~ /$cmd/ ) {
                        return normalize($state);
                }
        }
        return 0;
}


sub updatestates { 
	my ( $self, $class ) = @_;
	@{ $$self{states} } = $$self{parent}->getdevstates( $self, $class );
}


sub normalize {
        my ( $string ) = @_;
        $string = lc $string;
        $string =~ s/ //g;
        return $string;
}


=back

=head1 B<BondHome_Manual>

=head2 SYNOPSIS

User code:

    $LivingRoomFan = new BondHome_Manual('BondHome');

     Wherein the format for the definition is:
    $BondHomeManualObject = new BondHome_Manual(INSTANCE);
	
	 Add discovered commands with:
	$LivingRoomFan->addcmd('power', '434000', 'OOK', 'cq', '1000', '12', '110100110110H');
	
	 Wherein the format for the definition is:
	$BondHomeManualObject->addcmd(CommandName, Frequency, Modulation, Encoding, Bps, Reps, Data);
	
mht file code:

	BONDHOME_MANUAL,     LivingRoomFan,           BondHome
	
     Wherein the format for the definition is:
	BONDHOME_MANUAL,     ObjectName,           INSTANCE
	
	 Add discovered commands with:
	BONDHOME_MANUAL_CMD, LivingRoomFan,  power, 434000, OOK, cq, 1000, 12, 110100110110H
	
	 Wherein the format for the definition is:
	BONDHOME_MANUAL_CMD, BondHomeManualObject, CommandName, Frequency, Modulation, Encoding, Bps, Reps, Data
	
States:
Created from the BondHome addcmd sub routine


See C<new()> for a more detailed description of the arguments.


=head2 DESCRIPTION

 Configures a device from the BondHome to be controlled by MH.

=head2 INHERITS

L<Generic_Item>

=head2 METHODS

=over

=cut

package BondHome_Manual;
@BondHome_Manual::ISA = ('Generic_Item');

=item C<new( $instance )>

Instantiates a new object.

$instance = The instance of the parent BondHome hub object that this device is found on


=cut

use Data::Dumper;
use JSON;

sub new {
	my ( $class, $instance ) = @_;
	my $self = new Generic_Item();
	bless $self, $class;
	$$self{parent} = BondHome::get_object_by_instance($instance);
	$$self{parent}->register( $self, $class );
	@{$$self{states}} = (' ');
	
	return $self;
}


sub set {
    my ( $self, $p_state, $p_setby, $p_response ) = @_;
	
    $p_state = normalize($p_state);
	if ( exists $self->{devicehash}->{commands}->{name}->{$p_state} ) {
        ::print_log( "[BondHome::Manual] Received request " . $p_state . " for " . $self->get_object_name );
		
		my $content;
		$content->{freq} = $self->{devicehash}->{commands}->{name}->{$p_state}->{freq};
		$content->{modulation} = $self->{devicehash}->{commands}->{name}->{$p_state}->{modulation};
		$content->{data} = $self->{devicehash}->{commands}->{name}->{$p_state}->{data};
		$content->{encoding} = $self->{devicehash}->{commands}->{name}->{$p_state}->{encoding};
		$content->{bps} = $self->{devicehash}->{commands}->{name}->{$p_state}->{bps};
		$content->{reps} = $self->{devicehash}->{commands}->{name}->{$p_state}->{reps};
		$content->{use_scan}='false';
		
		$content = encode_json($content);
		#::print_log( "[BondHome::Manual] content: $content" );
		$$self{parent}->bondcmd( $class, '/v2/signal/tx', 'PUT', $content );
		
        $self->SUPER::set( $p_state, $p_setby );

    }
    else  {
        ::print_log( "[BondHome::Manual] Received INVALID request " . $p_state . " for " . $self->get_object_name );
    }
}


sub addcmd {
	my ($self, $cmdname, $frequency, $modulation, $encoding, $bps, $reps, $data) = @_;
	
	#::print_log "[BondHome::Manual] ". Dumper Dumper $self;
	::print_log( "[BondHome::Manual] adding new command $cmdname" );
	$cmdname = normalize($cmdname);
	$self->{devicehash}->{commands}->{name}->{$cmdname}->{modulation} = $modulation;
	$self->{devicehash}->{commands}->{name}->{$cmdname}->{data} = $data;
	$self->{devicehash}->{commands}->{name}->{$cmdname}->{freq} = $frequency;
	$self->{devicehash}->{commands}->{name}->{$cmdname}->{encoding} = $encoding;
	$self->{devicehash}->{commands}->{name}->{$cmdname}->{bps} = $bps;
	$self->{devicehash}->{commands}->{name}->{$cmdname}->{reps} = $reps;

	$self->{ 'cmdtimer' } = ::Timer::new();
    $self->{ 'cmdtimer' }->set(
								5,
								sub { $self->updatestates; }
								);
	
}


sub updatestates { 
	my ( $self ) = @_;
	my @speeds;
	foreach my $command (keys %{$self->{devicehash}->{commands}->{name}} )  {
		push @{ $$self{states} }, ucfirst($command);
		if ( normalize($command) =~ /speed(\d)/ ) {
			push @speeds, $1;
        }
	}
	@speeds = sort @speeds;
	push @{ $$self{states} }, @speeds;	
	
}


sub normalize {
        my ( $string ) = @_;
        $string = lc $string;
        $string =~ s/ //g;
        return $string;
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

