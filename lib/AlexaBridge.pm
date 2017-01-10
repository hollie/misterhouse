package AlexaBridge;

@AlexaBridge::ISA = ('Generic_Item');

use Carp;
use IO::Socket::INET;
use Socket;
use IO::Socket::Multicast;



use constant SSDP_IP => "239.255.255.250";
use constant SSDP_PORT => 1900;
use constant CRLF => "\015\012";

use constant DEFAULT_HTTP_PORT => 8085;
use constant DEFAULT_LEASE_TIME => 1800;
use constant DEFAULT_NOTIFICATION_PORT => 50000;
use constant DEFAULT_PORT_COUNT => 0;

my ($LOCAL_IP, $LOCAL_MAC) = &DiscoverAddy unless ( (defined($::config_parms{'alexaMac'})) && (defined($::config_parms{'alexaHttpIp'})) );
$LOCAL_IP = $::config_parms{'alexaHttpIp'} if defined($::config_parms{'alexaHttpIp'});
$LOCAL_MAC = $::config_parms{'alexaMac'} if defined($::config_parms{'alexaMac'});

my $AlexaGlobal;

sub startup {
  	unless ($::config_parms{'alexa_enable'}) { return }
	&open_port();
	&::MainLoop_pre_add_hook( \&AlexaBridge::check_for_data, 1 );
}

sub open_port {

       my $AlexaHttpPortCount = $::config_parms{'alexaHttpPortCount'} || DEFAULT_PORT_COUNT;
       if ($AlexaHttpPortCount) { 
	 $AlexaHttpPortCount = ($AlexaHttpPortCount - 1); 
         for my $count (0..$AlexaHttpPortCount) {
 	   my $AlexaHttpPort = $::config_parms{'alexaHttpPort'} || DEFAULT_HTTP_PORT;
           $AlexaHttpPort = ($AlexaHttpPort + $count);
           my $AlexaHttpName = 'alexaServer'.$count;
           &http_ports($AlexaHttpName, $AlexaHttpPort);
           $AlexaGlobal->{http_sockets}->{$AlexaHttpName} = new Socket_Item( undef, undef, $AlexaHttpName );
	   $AlexaGlobal->{http_sockets}->{$AlexaHttpName}->{port} = $AlexaHttpPort;
           &main::print_log ("Alexa open_port: p=$AlexaHttpPort pn=$AlexaHttpName s=$AlexaHttpName\n")
           if $main::Debug{alexa};
         }

         $AlexaGlobal->{http_sender}->{'alexa_http_sender'} = new Socket_Item('alexa_http_sender', undef, $::config_parms{'http_server'}.':'.$::config_parms{'http_port'}, 'alexa_http_sender', 'tcp', 'raw');
        }

 	my $notificationPort = $::config_parms{'alexa_notification_port'} || DEFAULT_NOTIFICATION_PORT;


	my $ssdpNotificationName = 'alexaSsdpNotification';
        $ssdpNotificationSocket = new IO::Socket::INET->new(
						Proto     => 'udp',
						LocalPort  => $notificationPort) 
						|| &main::print_log( "\nError:  Could not start a udp alexa multicast notification sender on $notificationPort: $@\n\n" ) && return;
    
	setsockopt($ssdpNotificationSocket,
				getprotobyname('ip'),
				IP_MULTICAST_TTL,
				pack 'I', 4);
	$::Socket_Ports{$ssdpNotificationName}{protocol} = 'udp';
	$::Socket_Ports{$ssdpNotificationName}{datatype} = 'raw';
	$::Socket_Ports{$ssdpNotificationName}{port}     = $notificationPort;
	$::Socket_Ports{$ssdpNotificationName}{sock}     = $ssdpNotificationSocket;
	$::Socket_Ports{$ssdpNotificationName}{socka} 	 = $ssdpNotificationSocket;  # UDP ports are always "active"
	$AlexaGlobal->{'ssdp_send'} = new Socket_Item( undef, undef, $ssdpNotificationName );

        printf " - creating %-15s on %3s %5s %s\n", $ssdpNotificationName, 'udp', $notificationPort;	
	&main::print_log ("Alexa open_port: p=$notificationPort pn=$ssdpNotificationName s=".$AlexaGlobal->{'ssdp_send'} ."\n")
        if $main::Debug{alexa};
	
	
	my $ssdpListenName = 'alexaSsdpListen';
	my $ssdpListenSocket = new IO::Socket::Multicast->new(
						LocalPort => SSDP_PORT,
						Proto     => 'udp',
						Reuse     => 1) 
						|| &main::print_log( "\nError:  Could not start a udp alexa multicast listen server on ". SSDP_PORT .$@ ."\n\n" ) && return;
	$ssdpListenSocket->mcast_add(SSDP_IP);
	$::Socket_Ports{$ssdpListenName}{protocol} = 'udp';
	$::Socket_Ports{$ssdpListenName}{datatype} = 'raw';
	$::Socket_Ports{$ssdpListenName}{port}     = SSDP_PORT;
	$::Socket_Ports{$ssdpListenName}{sock}     = $ssdpListenSocket;
	$::Socket_Ports{$ssdpListenName}{socka} 	  = $ssdpListenSocket;  # UDP ports are always "active"						   
	$AlexaGlobal->{'ssdp_listen'} = new Socket_Item( undef, undef, $ssdpListenName );					   

   	printf " - creating %-15s on %3s %5s %s\n", $ssdpListenName, 'udp', SSDP_PORT;
        &main::print_log ("Alexa open_port: p=$ssdpPort pn=$ssdpListenName s=" .$AlexaGlobal->{'ssdp_listen'} ."\n")
        if $main::Debug{alexa};

    return 1;
}


sub http_ports { 
	  my ( $AlexaHttpName, $AlexaHttpPort ) = @_;
          my $AlexaHttpSocket = new IO::Socket::INET->new(
                                                Proto     => 'tcp',
                                                LocalPort  => $AlexaHttpPort,
                                                Reuse     => 1,
                                                Listen    => 10)
                                                || &main::print_log( "\nError:  Could not start a tcp $AlexaHttpName on $AlexaHttpPort: $@\n\n" ) && return;

        $::Socket_Ports{$AlexaHttpName}{protocol} = 'tcp';
        $::Socket_Ports{$AlexaHttpName}{datatype} = 'raw';
        $::Socket_Ports{$AlexaHttpName}{port}     = $AlexaHttpPort;
        $::Socket_Ports{$AlexaHttpName}{sock}     = $AlexaHttpSocket;
        $::Socket_Ports{$AlexaHttpName}{socka}    = $AlexaHttpSocket;
	printf " - creating %-15s on %3s %5s %s\n", $AlexaHttpName, 'tcp', $AlexaHttpPort;
}

sub check_for_data {
  my $alexa_http_sender = $AlexaGlobal->{http_sender}->{'alexa_http_sender'};
  my $alexa_ssdp_listen = $AlexaGlobal->{ssdp_listen};
  #foreach my $AlexaHttpName ( keys %{$AlexaGlobal->{http_sockets}} ) {
   my $AlexaHttpName = 'alexaServer0';
   my $alexa_listen = $AlexaGlobal->{http_sockets}{$AlexaHttpName};  
    if ( $alexa_listen && ( my $alexa_data = said $alexa_listen ) ) {
          #&main::print_log( "[Alexa] Info: Data - $alexa_data" );
	  $alexa_http_sender->start unless $alexa_http_sender->active;
	  $alexa_http_sender->set($alexa_data);
	
    }
   &_sendHttpData($alexa_listen, $alexa_http_sender);

  # }



  my $alexa_ssdp_listen = $AlexaGlobal->{ssdp_listen};
    if ( $alexa_ssdp_listen && ( my $ssdp_data = said $alexa_ssdp_listen) ) {
	my $peer = $::Socket_Ports{'alexaSsdpListen'}{from_ipport};
	&_receiveSSDPEvent($ssdp_data, $peer);
    }
}


sub _sendHttpData {
  my ($alexa_listen, $alexa_http_sender) = @_;
      if ( $alexa_http_sender && ( my $alexa_sender_data = said $alexa_http_sender ) ) {
          $alexa_listen->set($alexa_sender_data);
     }
}
	
sub _receiveSSDPEvent {
		my ( $buf, $peer ) = @_;


        if ($buf !~ /\015?\012\015?\012/) {
                return;
        }

        $buf =~ s/^(?:\015?\012)+//;  # ignore leading blank lines
        if (!($buf =~ s/^(\S+)[ \t]+(\S+)(?:[ \t]+(HTTP\/\d+\.\d+))?[^\012]*\012//)) {
                # Bad header
                return;
        }

        my $method = $1;
        if ($method ne 'M-SEARCH') {
                # We only care about searches
                return;
        }
		
		my $target;
	        &main::print_log ("[Alexa] Debug: SSDP IN - $buf \n") if $main::Debug{'alexa'} >= 3;	
		if ( $buf =~ /ST: urn:Belkin:device:\*\*.*/ ) { &_sendSearchResponse($peer) }
		elsif ( $buf =~ /ST: urn:schemas-upnp-org:device:basic:1.*/ ) { &_sendSearchResponse($peer) }
		elsif ( $buf =~ /ST: ssdp:all.*/ ) { &_sendSearchResponse($peer,'all') }
                elsif ( $buf =~ /ST:ssdp:all.*/ ) { &_sendSearchResponse($peer,'all') }
}



sub _sendSearchResponse {
 my ($peer,$type) = @_;
 my $count = 0;
 my $selfname = (&main::list_objects_by_type('AlexaBridge'))[0];
 my $self = ::get_object_by_name($selfname);
 my $alexa_ssdp_send = $AlexaGlobal->{'ssdp_send'};
 my $mac = $LOCAL_MAC;


	 foreach my $port ( (sort keys %{$self->{child}->{'ports'}}) ) {
 	      next unless ( $self->{child}->{$port} );
	      my $socket = handle $alexa_ssdp_send;
	      my $output;
	      if ($type eq 'all') { 
		$output = "HTTP/1.1 200 OK\r\n";
		$output .= 'HOST: 239.255.255.250:1900'."\r\n";
		$output .= 'CACHE-CONTROL: max-age=100'."\r\n";
		$output .= 'EXT: '."\r\n";
		$output .= 'LOCATION: http://'.$LOCAL_IP.':'.$port.'/description.xml' ."\r\n";
		#$output .= 'LOCATION: http://'.$::config_parms{'alexaHttpIp'}.':'.$port.'/upnp/alexa-mh-bridge'.$count.'/setup.xml' ."\r\n";
		$output .= 'SERVER: Linux/3.14.0 UPnP/1.0 IpBridge/1.15.0' ."\r\n";
		$output .= 'hue-bridgeid: B827EBFFFE'.uc((substr $mac, -6))."\r\n";
		$output .= 'ST: upnp:rootdevice' ."\r\n";
		$output .= 'USN: uuid:'.$mac.'::upnp:rootdevice' ."\r\n";
		$output .= "\r\n";
		&main::print_log ("[Alexa] Debug: SSDP OUT - $output \n") if $main::Debug{'alexa'} >= 3;
		send($socket, $output, 0, $peer);

		$output = "HTTP/1.1 200 OK\r\n";
		$output .= 'HOST: 239.255.255.250:1900'."\r\n";
		$output .= 'CACHE-CONTROL: max-age=100'."\r\n";
		$output .= 'EXT: '."\r\n";
		$output .= 'LOCATION: http://'.$LOCAL_IP.':'.$port.'/description.xml' ."\r\n";
		#$output .= 'LOCATION: http://'.$::config_parms{'alexaHttpIp'}.':'.$port.'/upnp/alexa-mh-bridge'.$count.'/setup.xml' ."\r\n";
		$output .= 'SERVER: Linux/3.14.0 UPnP/1.0 IpBridge/1.15.0' ."\r\n";
		$output .= 'hue-bridgeid: B827EBFFFE'.uc((substr $mac, -6))."\r\n";
		$output .= 'ST: uuid:2f402f80-da50-11e1-9b23-'.lc($mac)."\r\n";
		$output .= 'USN: uuid:2f402f80-da50-11e1-9b23-001e06'.$mac."\r\n";
		$output .= "\r\n";
		&main::print_log ("[Alexa] Debug: SSDP OUT - $output \n") if $main::Debug{'alexa'} >= 3;
		send($socket, $output, 0, $peer);
	      }

		$output = "HTTP/1.1 200 OK\r\n";
		$output .= 'HOST: 239.255.255.250:1900'."\r\n";
		$output .= 'CACHE-CONTROL: max-age=100'."\r\n";
		$output .= 'EXT: '."\r\n";
		$output .= 'LOCATION: http://'.$LOCAL_IP.':'.$port.'/description.xml' ."\r\n";
		#$output .= 'LOCATION: http://'.$::config_parms{'alexaHttpIp'}.':'.$port.'/upnp/alexa-mh-bridge'.$count.'/setup.xml' ."\r\n";
		$output .= 'SERVER: Linux/3.14.0 UPnP/1.0 IpBridge/1.15.0' ."\r\n";
		$output .= 'hue-bridgeid: B827EBFFFE'.uc((substr $mac, -6))."\r\n";
		$output .= 'ST: urn:schemas-upnp-org:device:basic:1'."\r\n";
		$output .= 'USN: uuid:2f402f80-da50-11e1-9b23-'.lc($mac)."\r\n";
		$output .= "\r\n";
		&main::print_log ("[Alexa] Debug: SSDP OUT - $output \n") if $main::Debug{'alexa'} >= 3;
        	send($socket, $output, 0, $peer);

		$count++;
	  }
}

sub process_http {

 unless ($::config_parms{'alexa_enable'}) { return 0 }
 my ( $uri, $request_type, $body, $socket, %Http ) = @_;

 unless ( ($uri =~ /^\/upnp\//) || ($uri =~ /^\/api/ ) || ($uri =~ /^\/description.xml$/) ) { return 0 } # Added for performance

 my $selfname = (&main::list_objects_by_type('AlexaBridge'))[0];
 my $self = ::get_object_by_name($selfname);
 unless ($self) { &main::print_log( "[Alexa] Error: No AlexaBridge parent object found" ); return 0 }

 use HTTP::Date qw(time2str);
 use IO::Compress::Gzip qw(gzip);

  #get the port from the host header
 my @uris = split(/\//, $uri);
 my $host = $Http{'Host'};
 my $port;
 if ( $host =~ /(.*):(\d+)/ ) {
    $host = $1;
    $port = $2;
  } 
 elsif ( $host =~ /(\d+)/ ) {
    $host = $1;
    $port = '80';
  }
 elsif ( $host =~ /(\w+)/ ) {
    $host = $1;
    $port = '80';
  }
 
my $xmlmessage = qq[<?xml version="1.0"?>
<root xmlns="urn:schemas-upnp-org:device-1-0">
<specVersion>
<major>1</major>
<minor>0</minor>
</specVersion>
<URLBase>http://$LOCAL_IP:$port/</URLBase>
<device>
<deviceType>urn:schemas-upnp-org:device:basic:1</deviceType>
<friendlyName>Amazon-Echo-MH-Bridge ($LOCAL_IP)</friendlyName>
<manufacturer>Royal Philips Electronics</manufacturer>
<manufacturerURL>http://misterhouse.sourceforge.net/</manufacturerURL>
<modelDescription>Hue Emulator for Amazon Echo bridge</modelDescription>
<modelName>Philips hue bridge 2012</modelName>
<modelNumber>929000226503</modelNumber>
<modelURL>https://github.com/hollie/misterhouse</modelURL>
<serialNumber>amazon-mh-bridge0</serialNumber>
<UDN>uuid:amazon-mh-bridge0</UDN>
<serviceList>
<service>
<serviceType>(null)</serviceType>
<serviceId>(null)</serviceId>
<controlURL>(null)</controlURL>
<eventSubURL>(null)</eventSubURL>
<SCPDURL>(null)</SCPDURL>
</service>
</serviceList>
<presentationURL>index.html</presentationURL>
<iconList>
<icon>
<mimetype>image/png</mimetype>
<height>48</height>
<width>48</width>
<depth>24</depth>
<url>hue_logo_0.png</url>
</icon>
<icon>
<mimetype>image/png</mimetype>
<height>120</height>
<width>120</width>
<depth>24</depth>
<url>hue_logo_3.png</url>
</icon>
</iconList>
</device>
</root>];

 
my $AlexaObjects;
 if ( $self->{child}->{$port} ) { 
  # use Data::Dumper;
   $AlexaObjects = $self->{child}->{$port};
   #&main::print_log( Data::Dumper->Dumper($AlexaObjects) );
 }
 else {
   &main::print_log( "[Alexa] Error: No Matching object for port ( $port )" ); 
   $output = "HTTP/1.0 404 Not Found\r\nServer: MisterHouse\r\nCache-Control: no-cache\r\n\r\n";
   return $output;
 }

&main::print_log ("[Alexa] Debug: Port: ( $port ) URI: ( $uri ) Body: ( $body ) Type: ( $request_type ) \n") if $main::Debug{'alexa'};

        if ( ( ($uri =~ /^\/upnp\/.*\/setup.xml$/) || ($uri =~ /^\/description.xml$/) ) && (lc($request_type) eq "get") ) {
                         my $output = "HTTP/1.1 200 OK\r\n";
                         $output .= "Server: MisterHouse\r\n";
                         $output .= 'Access-Control-Allow-Origin: *'."\r\n";
                         $output .= 'Access-Control-Allow-Methods: POST, GET, OPTIONS, DELETE, PUT'."\r\n";
                         $output .= 'Access-Control-Max-Age: 3600'."\r\n";
                         $output .= 'Access-Control-Allow-Headers: Origin, X-Requested-With, Content-Type, Accept'."\r\n";
                         $output .= 'X-Application-Context: application'."\r\n";
                         $output .= 'Content-Type: application/xml;charset=UTF-8'."\r\n";
                         $output .= "Content-Length: ". (length $xmlmessage) ."\r\n";
                         $output .= "Date: ". time2str(time)."\r\n";
                         $output .= "\r\n";
                         $output .= $xmlmessage;
			 &main::print_log ("[Alexa] Debug: MH Response $xmlmessage \n") if $main::Debug{'alexa'} >= 2;
                         return $output;
        }
        elsif ( ($uri =~ /^\/api/) && (lc($request_type) eq "post") ) {
                        my $content = qq[\[{"success":{"username":"lights"}}\]];
                        my $output = "HTTP/1.1 200 OK\r\n";
                        $output .= "Server: MisterHouse\r\n";
                        $output .= 'Access-Control-Allow-Origin: *'."\r\n";
                        $output .= 'Access-Control-Allow-Methods: POST, GET, OPTIONS, DELETE, PUT'."\r\n";
                        $output .= 'Access-Control-Max-Age: 3600'."\r\n";
                        $output .= 'Access-Control-Allow-Headers: Origin, X-Requested-With, Content-Type, Accept'."\r\n";
                        $output .= 'X-Application-Context: application'."\r\n";
                        $output .= 'Content-Type: application/json;charset=UTF-8'."\r\n";
                        $output .= "Content-Length: ". (length $content) ."\r\n";
                        $output .= "Date: ". time2str(time)."\r\n";
                        $output .= "\r\n";
                        $output .= $content;
			&main::print_log ("[Alexa] Debug: MH Response $output \n") if $main::Debug{'alexa'} >= 2;
                        return $output;
        }
        elsif ( ($uri =~ /^\/api\/.*\/lights\/(.*)\/state$/) && (lc($request_type) eq "put") ) {
                        my $output;
                        my $deviceID = $1;
                        my $state = undef;
			$body =~ s/: /:/g;
                        if ( $body =~ /\"(on)\":(true)/ ) { $state = 'on' }
                        elsif ( $body =~ /\"(on)\":(false)/ ) { $state = 'off' }
                        elsif ( $body =~ /\"(off)\":(true)/ ) { $state = 'off' }
                        elsif ( $body =~ /\"(off)\":(false)/ ) { $state = 'on' }
                        if ( $body =~ /\"(bri)\":(\d+)/ ) { $state = $2 }
			my $content = qq[\[{"success":{"/lights/$deviceID/state/$1":$2}}\]];
			&main::print_log ("[Alexa] Debug: MH Got request ( $1 - $2 ) to Set device ( $deviceID ) to ( $state )\n") if $main::Debug{'alexa'};

                        if ( ($AlexaObjects->{'uuid'}->{$deviceID}) && (defined($state)) ) {
				&get_set_state($self, $AlexaObjects, $deviceID, 'set', $state);

                                $output = "HTTP/1.1 200 OK\r\n";
                                $output .= "Server: MisterHouse\r\n";
                                $output .= 'Access-Control-Allow-Origin: *'."\r\n";
                                $output .= 'Access-Control-Allow-Methods: POST, GET, OPTIONS, DELETE, PUT'."\r\n";
                                $output .= 'Access-Control-Max-Age: 3600'."\r\n";
                                $output .= 'Access-Control-Allow-Headers: Origin, X-Requested-With, Content-Type, Accept'."\r\n";
                                $output .= 'X-Application-Context: application'."\r\n";
                                $output .= 'Content-Type: text/plain;charset=UTF-8'."\r\n";
                                $output .= "Content-Length: ". (length $content) ."\r\n";
                                $output .= "Date: ". time2str(time)."\r\n";
                                $output .= "\r\n";
                                $output .= $content;
                         } else {
                                 $output = "HTTP/1.0 404 Not Found\r\nServer: MisterHouse\r\nCache-Control: no-cache\r\n";
				 &main::print_log("[Alexa] Error: No Matching object for UUID ( $deviceID )") unless ($AlexaObjects->{'uuid'}->{$deviceID});
                                 &main::print_log("[Alexa] Error: Missing State from PUT for object with UUID ( $deviceID )") unless (defined($state));
				 &main::print_log ("[Alexa] Debug: MH Response $output \n") if $main::Debug{'alexa'};
				 return $output;
                        }
			&main::print_log ("[Alexa] Debug: MH Response $output \n") if $main::Debug{'alexa'} >= 2;
			return $output;
			#print $socket $output; # print direct to the socket so it does not close.
			#&main::http_process_request($socket); # we know there will be another request so get it in the same tcp session.
			#return ' ';
                }
        elsif ( ($uri =~ /^\/api\/.*/) && (lc($request_type) eq "get") ) {
                        my $count = 0;
                        my $content; my $name; my $statep1; my $statep2; my $statep3; my $statep4; my $delm; my $output;
			my $end = '';
                        if (defined $uris[4]) {
	                      if ( ($uris[3] eq 'lights') && ($AlexaObjects->{'uuid'}->{$uris[4]}) ) {
                         	$uuid = $uris[4];
                         	$name = $AlexaObjects->{'uuid'}->{$uuid}->{'name'};
				my $state = &get_set_state($self, $AlexaObjects, $uuid,'get');
                         	$statep1 = qq[{"state":{$state,"hue":15823,"sat":88,"effect":"none","ct":313,"alert":"none","colormode":"ct","reachable":true,"xy":\[0.4255,0.3998\]},"type":"Extended color light","name":"];
                         	$statep2 = qq[","modelid":"LCT001","manufacturername":"Philips","uniqueid":"$uuid","swversion":"65003148","pointsymbol":{"1":"none","2":"none","3":"none","4":"none","5":"none","6":"none","7":"none","8":"none"}}];
                         	$content = $statep1.$name.$statep2;
                         	$count = 1;
                       	      }
			      elsif ( $uris[3] eq 'lights' ) {
				 &main::print_log("[Alexa] Error: No Matching object for UUID ( $uris[4] )");
                                 $output = "HTTP/1.0 404 Not Found\r\nServer: MisterHouse\r\nCache-Control: no-cache\r\n";
				 &main::print_log ("[Alexa] Debug: MH Response $output \n") if $main::Debug{'alexa'};
                                 return $output;
			      }
                              elsif ( ($uris[3] eq 'groups') && ($AlexaObjects->{'groups'}->{$uris[4]}) ) {
                        	 $name = $AlexaObjects->{'groups'}->{$uris[4]}->{'name'};
                         	 $content = qq[{"action": {"on": true,"hue": 0,"effect": "none","bri": 100,"sat": 100,"ct": 500,"xy": \[0.5, 0.5\]},"lights": \["1","2"\],"state":{"any_on":true,"all_on":true}"type":"Room","class":"Other","name":"$name"}];
                           	 $count = 1;
                     	      }
			}
			elsif (defined $uris[3]) {
                       		if ( $uris[3] eq 'lights' ) {
                         	  foreach my $uuid ( keys %{$AlexaObjects->{'uuid'}} ) {
                                	$name = $AlexaObjects->{'uuid'}->{$uuid}->{'name'};
                               		next unless $name;
					my $state = &get_set_state($self, $AlexaObjects, $uuid,'get');
                                  	$statep1 = qq[{"];
                                  	$statep2 = qq[":{"state":{$state,"reachable":true},"type":"Extended color light","name":"];
                                  	$statep3 = qq[","modelid":"LCT001","manufacturername":"Philips","swversion":"65003148"}];
                                  	$end = qq[}];
                                  	$delm = qq[,"];
	                                if ($count >= 1) { $content = $content.$delm.$uuid.$statep2.$name.$statep3 }
        	                        else { $content = $statep1.$uuid.$statep2.$name.$statep3 }
                                	$count++;
                        	  }
                        	}
	                        elsif ( $uris[3] eq 'groups' ) {
        	                   $statep1 = qq[{"];
                	           $statep2 = qq[":"];
                        	   $end = qq["}];
                        	   $delm = qq[","];
                     		    foreach my $id ( keys %{$AlexaObjects->{'groups'}} ) {
                                	$name = $AlexaObjects->{'groups'}->{$id}->{'name'};
                               		 next unless $name;
                                	 $statep1 = qq[{"$id": {"name": "$name","lights": \["1","2"\],"type": "LightGroup","action": {"on": true,"bri": 254,"hue": 10000,"sat": 254,"effect": "none","xy": \[0.5,0.5\],"ct": 250,"alert": "select","colormode": "ct"}}];
                                	 $delim = qq[,];
                               		 $statep2 = qq["$id": {"name": "$name","lights": \["3","4"\],"type": "LightGroup","action": {"on": true,"bri": 153,"hue": 4345,"sat": 254,"effect": "none","xy": \[0.5,0.5\],"ct": 250,"alert": "select","colormode": "ct"}}];
                               		 $end = qq[}];
                            		 if ($count >= 1) { $content = $content.$delim.$statep2 }
                                	 else { $content = $statep1 }
                                	 $count++;
                        	     }
                       		 }
			 }
                        elsif (defined $uris[2]) {
                         foreach my $uuid ( keys %{$AlexaObjects->{'uuid'}} ) {
 	                        $name = $AlexaObjects->{'uuid'}->{$uuid}->{'name'};
				next unless $name;
                                my $state = &get_set_state($self, $AlexaObjects, $uuid,'get');
	                        $statep1 = qq[{"lights":{"];
        	                $statep2 = qq[":{"state":{$state,"reachable":true},"type":"Extended color light","name":"]; # dis
                	        $statep3 = qq[","modelid":"LCT001","manufacturername":"Philips","swversion":"65003148"}]; #
                        	$end = qq[}}];
                        	$delm = qq[,"];
                                if ($count >= 1) { $content = $content.$delm.$uuid.$statep2.$name.$statep3 }
                                else { $content = $statep1.$uuid.$statep2.$name.$statep3 }
                                $count++;
                         }
                        }
                        if ($count >= 1) {
                                $content = $content.$end;
				$debugcontent = $content if $main::Debug{'alexa'} >= 2;
				$content = &_Gzip($content,$Http{'Accept-Encoding'});
                                $output = "HTTP/1.1 200 OK\r\n";
                                $output .= "Server: MisterHouse\r\n";
                                $output .= 'Access-Control-Allow-Origin: *'."\r\n";
                                $output .= 'Access-Control-Allow-Methods: POST, GET, OPTIONS, DELETE, PUT'."\r\n";
                                $output .= 'Access-Control-Max-Age: 3600'."\r\n";
                                $output .= 'Access-Control-Allow-Headers: Origin, X-Requested-With, Content-Type, Accept'."\r\n";
                                $output .= 'X-Application-Context: application'."\r\n";
                                $output .= 'Content-Type: application/json;charset=UTF-8'."\r\n";
				$output .= "Content-Encoding: gzip\r\n" if ($Http{'Accept-Encoding'} =~ m/gzip/);
                                $output .= "Content-Length: ". (length $content) ."\r\n";
                                $output .= "Date: ". time2str(time)."\r\n";
                                $output .= "\r\n";
                                $output .= $content;
                        } else {
                                 my $output = "HTTP/1.0 404 Not Found\r\nServer: MisterHouse\r\nCache-Control: no-cache\r\n";
                        }
			&main::print_log ("[Alexa] Debug: MH Response $debugcontent \n") if $main::Debug{'alexa'} >= 2;
                        return $output;
         }
         else { return 0 }
}

sub _Gzip {
 my ($content_raw, $Encoding) = @_;
 my $content;
  if ( $Encoding =~ m/gzip/ && ((length $content_raw) >= 1) ) { 
    gzip \$content_raw => \$content;
  }
  else { $content = $content_raw; } 
 return $content;
}

sub DiscoverAddy {
   use Net::Address::Ethernet qw( :all );
   my @a = get_addresses(@_);
   foreach my $adapter (@a) {
    # print $adapter->{sIP}."\n";
    # print $adapter->{sEthernet}."\n";
    # print "____________________\n";
     next unless ($adapter->{iActive} eq 1);
     next if ($adapter->{sEthernet} eq '');
     next if ($adapter->{sIP} =~ /127\.0\.0\.1/);
     my $Mac = $adapter->{sEthernet};
     $Mac =~ s/://g;
     return ($adapter->{sIP},$Mac);
   }
}

sub get_set_state {
     my ( $self, $AlexaObjects, $uuid, $action, $state ) = @_;
     my $name = $AlexaObjects->{'uuid'}->{$uuid}->{'name'};
     my $realname = $AlexaObjects->{'uuid'}->{$uuid}->{'realname'};
     my $sub = $AlexaObjects->{'uuid'}->{$uuid}->{'sub'};
     my $statesub = $AlexaObjects->{'uuid'}->{$uuid}->{'statesub'};
     $state = $AlexaObjects->{'uuid'}->{$uuid}->{lc($state)} if $AlexaObjects->{'uuid'}->{$uuid}->{lc($state)};
     if ( $state =~ /\d+/ ) { $state = &roundoff($state / 2.54) }
      &main::print_log ("[Alexa] Debug: get_set_state ($uuid $action $state) : name: $name  realname: $realname sub: $sub state: $state\n") if $main::Debug{'alexa'};
       if ( $realname =~ /^\$/ ) {
           my $object = ::get_object_by_name( $realname );
		return qq["on":true,"bri":254] unless defined $object;
		if ( $action eq 'get' ) {
		     my $cstate = $object->$statesub;
		     $cstate =~ s/\%//;
		     my $level = '254';
                     my $type = $object->get_type();
		     my $debug = "[Alexa] Debug: get_state (actual object state: $cstate) - (object type: $type) - ";
		     my $return; 
		     if ( $object->can('state_level') ) {
			my $l = $object->level;
			$l =~ s/\%//;
			if  ( $l =~ /\d+/ ) {
			  $level = ( &roundoff(($l) * 2.54) ); 
			  $debug .= "(level: $level) - ";
			}
		      }
                     if ( lc($type) =~ /x10/ ) {
                         if ( ($cstate =~ /\d+/) || ($cstate =~ /dim/) || ($cstate =~ /bright/) ) { $cstate = 'on' }
			 $debug .= "(determined state: $cstate) - ";
                     }
		     if ( lc($AlexaObjects->{'uuid'}->{$uuid}->{'on'}) eq lc($cstate) ) { $return = qq["on":true,"bri":$level] }
		     elsif ( lc($AlexaObjects->{'uuid'}->{$uuid}->{'off'}) eq lc($cstate) ) { $return = qq["on":false,"bri":$level] }
		     elsif ( $cstate =~ /\d+/ ) { $return = qq["on":true,"bri":].&roundoff($cstate * 2.54) }
		     else { $return = qq["on":true,"bri":$level] }
		     &main::print_log ( "$debug returning - $return\n" ) if $main::Debug{'alexa'};
		     return $return;	
		  } 
		elsif ( $action eq 'set' ) {
		    my $end;
		    #if ($object->$statesub =~ /\%/) { $end = '%' }
		    if ( $object->can('state_level') && $state =~ /\d+/ ) { $end = '%'}
       		    &main::print_log ("[Alexa] Debug: setting object ( $realname ) to state ( $state$end )\n") if $main::Debug{'alexa'};
          	    $object->$sub($state.$end);
		    return;
		}
       }
       elsif ( $sub =~ /^run_voice_cmd$/ ) {
	     if ( $action eq 'set' ) {
                 $realname =~ s/#/$state/;
	         &main::print_log ("[Alexa] Debug: running voice command: ( $realname )\n") if $main::Debug{'alexa'};
                 &main::run_voice_cmd("$realname");
		 return;
	     }
             elsif ( $action eq 'get' ) {
	         return qq["on":true,"bri":254];
	     }
	   
       }
       elsif ( ref($sub) eq 'CODE' ) {
	   if ( $action eq 'set' ) {
	   	&main::print_log ("[Alexa] Debug: running sub: $sub( $state ) \n") if $main::Debug{'alexa'};  
             	&{$sub}($state);
		return;
	   }
	   elsif ( $action eq 'get' ) {
	     	return qq["on":true,"bri":254];
	   }
       }
}

sub get_state { 
my ( $self, $object, $statesub ) = @_;
       my $cstate = $object->$statesub;
       $cstate =~ s/\%//;
       my $type = $object->get_type();
       my $debug = "[Alexa] Debug: get_state (actual object state: $cstate) - (object type: $type) - ";
       if ( lc($type) =~ /x10/ ) { 
	if ( ($state =~ /\d+/) || ($state =~ /dim/) || ($state =~ /bright/) ) { $cstate = 'on' }  
       } 
       $debug .= "(determined state: $cstate) - ";
   return $cstate;
} 


sub roundoff
{
  my $num = shift;
  my $roundto = shift || 1;

  return int($num/$roundto+0.5)*$roundto;
}

sub new {
   my ($class) = @_;
   my $self = new Generic_Item();
   bless $self, $class;
   return $self;
}
 
sub register { 
   my ( $self, $child ) = @_;
   $self->{child} = $child;
}

package AlexaBridge_Item;

@AlexaBridge_Item::ISA = ('Generic_Item');
use Storable;

sub new {
   my ($class, $parent) = @_;
   my $self = new Generic_Item();
   my $file = $::config_parms{'data_dir'}.'/alexa_temp.saved_id';
   bless $self, $class;
   $parent->register($self);
     foreach my $AlexaHttpName ( keys %{$AlexaGlobal->{http_sockets}} ) {
  	my $AlexaHttpPort = $AlexaGlobal->{http_sockets}->{$AlexaHttpName}->{port};
        $self->{'ports'}->{$AlexaHttpPort} = 0;
      }
    if ( ($::config_parms{'alexaHttpPortCount'} eq 0) && ($::config_parms{'alexaHttpPort'}) ) {   
      $self->{'ports'}->{$::config_parms{'alexaHttpPort'}} = 0; # This is to disable all MH proxy ports and use an external proxy port via Apache
    } 
    else { $self->{'ports'}->{$::config_parms{'http_port'}} = 0; } 
     if (-e $file) {
 	my $restoredhash = retrieve($file);
 	$self->{idmap} = $restoredhash->{idmap};
     } else { $self->{idmap} }
   return $self;
}

sub add {
  my ($self, $realname, $name, $sub, $on, $off, $statesub) = @_;

  return unless defined $realname;
  my $fullname;
  my $cleanname = $realname;
  $cleanname =~ s/\$//g;
  $cleanname =~ s/ //g;
  $cleanname =~ s/#//g;
  $cleanname =~ s/\\//g;
  $cleanname =~ s/&//g;

  if ( defined($name) ) {
      $fullname = $cleanname.'.'.$name;
   }
   else { 
      $fullname = $cleanname.'.'.$cleanname;
   }
  #use Data::Dumper;  
  my $uuid = $self->uuid($fullname);

 foreach my $port ( (sort keys %{$self->{'ports'}}) ) {
    my $size = keys %{$self->{$port}->{'uuid'}};
    next if ($size eq 60);
    $self->{$port}->{'uuid'}->{$uuid}->{'realname'}=$realname;
    $self->{$port}->{'uuid'}->{$uuid}->{'name'}=$name || $cleanname;
    $self->{$port}->{'uuid'}->{$uuid}->{'sub'}=$sub || 'set';
    $self->{$port}->{'uuid'}->{$uuid}->{'on'}=lc($on) || 'on';
    $self->{$port}->{'uuid'}->{$uuid}->{'off'}=lc($off) || 'off';
    $self->{$port}->{'uuid'}->{$uuid}->{'statesub'}=$statesub || 'state';
    last;
 }

   # $self->{8080}->{'uuid'}->{3}->{'realname'}=$realname;
   # $self->{8080}->{'uuid'}->{3}->{'name'}=$name || $cleanname;
   # $self->{8080}->{'uuid'}->{3}->{'sub'}=$sub || 'set';
   # $self->{8080}->{'uuid'}->{3}->{'on'}=$on || 'on';
   # $self->{8080}->{'uuid'}->{3}->{'off'}=$off || 'off';
   # $self->{8080}->{'uuid'}->{3}->{'statesub'}=$statesub || 'state';

# Testing groups, saw the Echo hit /api/odtQdwTaiTjPgURo4ZyEtGfIqRgfSeCm1fl2AMG2/groups/0 
#$self->{'groups'}->{0}->{'name'}='group0';
#$self->{'groups'}->{0}->{'realname'}='$light0';
#$self->{'groups'}->{0}->{'sub'}='set';
#$self->{'groups'}->{0}->{'on'}='on';
#$self->{'groups'}->{0}->{'off'}='off';
#$self->{'groups'}->{1}->{'name'}='group1';
#$self->{'groups'}->{1}->{'realname'}='$light1';
#$self->{'groups'}->{1}->{'sub'}='set';
#$self->{'groups'}->{1}->{'on'}='on';
#$self->{'groups'}->{1}->{'off'}='off';
#$self->{'groups'}->{2}->{'name'}='group2';
#$self->{'groups'}->{2}->{'realname'}='$light2';
#$self->{'groups'}->{2}->{'sub'}='set';
#$self->{'groups'}->{2}->{'on'}='on';
#$self->{'groups'}->{2}->{'off'}='off';
  #&main::print_log( Data::Dumper->Dumper($self->{'uuid'}) );
}

sub get_objects { 
 my ($self) = @_;
 return $self->{'uuid'};
}

sub uuid { 
 my ($self, $name) = @_;
 my $file = $::config_parms{'data_dir'}.'/alexa_temp.saved_id';
 return $self->{'idmap'}->{objects}->{$name} if ($self->{'idmap'}->{objects}->{$name});

 my $highid;
 my $missing;
 my $count = $::config_parms{'alexaUuidStart'} || 1;
   foreach my $object (keys %{$self->{idmap}->{objects}}) {
     my $currentid = $self->{idmap}->{objects}->{$object};
     $highid = $currentid if ( $currentid > $highid );
     $missing = $count unless ( $self->{'idmap'}->{ids}->{$count} ); #We have a number that has no value 
     $count++;
   }
 $highid++;

$highid = $missing if ( defined($missing) ); # Reuse numbers for deleted objects to keep the count from growning for ever. 

$self->{'idmap'}->{objects}->{$name} = $highid;
$self->{'idmap'}->{ids}->{$highid} = $name;

my $idmap->{'idmap'} = $self->{'idmap'};
store $idmap, $file;
return $highid;
 
# use Data::UUID;
#	$ug    = Data::UUID->new;
#	$uuid   = $ug->to_string( ( $ug->create_from_name(NameSpace_DNS, $name) ) );
#	$uuid =~ s/\D//g;
#        $uuid =~ s/-//g;
#	$uuid = (substr $uuid, 0, 9);
#	return lc($uuid);
}

sub isDeleted {
 my ($self, $uuid) = @_;
 my $count;
 foreach my $port ( (sort keys %{$self->{'ports'}}) ) {
  $count++ if ( $self->{$port}->{'uuid'}->{$uuid} );
 }
 return 1 unless $count;
 return 0;
}

1;

