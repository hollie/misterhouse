=head1 B<raZberry>

=head2 SYNOPSIS

In user code:

    use raZberry.pm;
    $razberry_controller  = new raZberry('192.168.0.100',1);
    $razberry_comm		  = new raZberry_comm($razberry_controller);
    $family_room_fan      = new raZberry_dimmer($razberry_controller,'2-0-38','force_update');

So far only raZberry_dimmer is a working child object

In items.mht:

    TBD
    
=head2 DESCRIPTION

  Uses w

=head3 LINKING ZWAVE devices

Devices need to first linked inside the razberry using the included web interface.

=head3 STATE REPORTED IN MisterHouse

The Razberry is polled on a regular basis in order to update local objects. By default, 
the razberry is polled every 5 seconds

=head3 SENSOR STATE CHILD OBJECT

Each device class will need a child object, as the controller object is just a gateway
to the hardware. Currently the only working device is a razberry_dimmer, and has only
been tested with the leviton fan

There is also a communication object to allow for alerting and monitoring of the
razberry controller.

=head2 NOTES



=head2 BUGS



=head2 METHODS

=over

=cut

use strict;

package raZberry;

use warnings;

use LWP::UserAgent;
use HTTP::Request::Common qw(POST);
use JSON::XS;
use Data::Dumper;

#todo 
# - dump_all_devices to see everything raZberry knows

@raZberry::ISA = ('Generic_Item');


# -------------------- START OF SUBROUTINES --------------------
# --------------------------------------------------------------
my %zway_system;
$zway_system{version} = "2";
$zway_system{delim}{1} = ":";
$zway_system{delim}{2} = "-";
$zway_system{id}{1} = "1";
$zway_system{id}{2} = "2";

my $zway_vdev="ZWayVDev_zway";

our %rest;
$rest{api} = "";
$rest{devices} = "devices";
$rest{on} = "command/on";
$rest{off} = "command/off";
$rest{level} = "command/exact?level=";
$rest{force_update} = "devices";

sub new {
   my ($class, $addr, $poll) = @_;
   my $self = {};
   bless $self, $class;
   $self->{data} = undef;
   $self->{child_object} = undef;
   $self->{config}->{poll_seconds} = 5;
   $self->{config}->{poll_seconds} = $poll if ($poll);
   $self->{config}->{poll_seconds} = 1 if ($self->{config}->{poll_seconds} < 1);
   $self->{updating} = 0;
   $self->{data}->{retry} = 0;
   my ($host,$port) = (split /:/,$addr)[0,1];
   $self->{host} = $host;
   $self->{port} = 8083;
   $self->{port} = $port if ($port);        
   $self->{debug} = 0;
   $self->{lastupdate} = undef;
   $self->{timeout} = 5; #300;


   $self->{timer} = new Timer;
   $self->start_timer;
   return $self;
}



sub poll {
  my ($self) = @_;
  
  &main::print_log("[raZberry] Polling initiated") if ($self->{debug});
  my $cmd = "";
  $cmd = "?since=" . $self->{lastupdate} if (defined $self->{lastupdate});
  &main::print_log("[raZberry] cmd=$cmd") if ($self->{debug} > 1);
  
   for my $dev (keys %{$self->{data}->{force_update}}) {
    	&main::print_log("[raZberry] Forcing update to device $dev to account for local changes") if ($self->{debug});
    	my $cmd;
    	my ($devid,$instance,$class) = (split /-/,$dev)[0,1,2];
    	$cmd = "%5B" . $devid . "%5D.instances%5B" . $instance . "%5D.commandClasses%5B" . $class ."%5D.Get()";
    	&main::print_log("cmd=$cmd") if ($self->{debug} > 1);
    	my ($isSuccessResponse0,$status) = _get_JSON_data($self, 'force_update', $cmd);
    	unless ($isSuccessResponse0) {
  			&main::print_log("[raZberry] Error: Problem retrieving data from " . $self->{host});
  			$self->{data}->{retry}++;
    		return ('0');
    	}
     }
     
    for my $dev (keys %{$self->{data}->{ping}}) {
    	&main::print_log("[raZberry] Keep_alive: Pinging device $dev...");# if ($self->{debug});
    	&main::print_log("ping_dev $dev");# if ($self->{debug});
	}
    
  	 my ($isSuccessResponse1,$devices) = _get_JSON_data($self, 'devices', $cmd);
     print Dumper $devices if ($self->{debug} > 1);  
  	 if ($isSuccessResponse1) {
  		  $self->{lastupdate} = $devices->{data}->{updateTime};  		
  		  foreach my $item (@{$devices->{data}->{devices}}) {  		    
  		      &main::print_log("Found:" . $item->{id} . " with level " . $item->{metrics}->{level} . " and updated " . $item->{updateTime} . ".") if ($self->{debug});
  		      my ($id) = (split /_/,$item->{id})[2];
print "id=$id\n";
  		      $self->{data}->{devices}->{$id}->{level} = $item->{metrics}->{level};
  		      $self->{data}->{devices}->{$id}->{updateTime} = $item->{updateTime};
  		      $self->{data}->{devices}->{$id}->{devicetype} = $item->{deviceType};
  		      $self->{data}->{devices}->{$id}->{location} = $item->{location};
  		      $self->{data}->{devices}->{$id}->{title} = $item->{metrics}->{title};
  		      $self->{data}->{devices}->{$id}->{icon} = $item->{metrics}->{icon};
  		      
  		      if (defined $self->{child_object}->{$id}) {
			    &main::print_log("[raZberry] Child object detected: Controller Level:[" . $item->{metrics}->{level} . "] Child Level:[" . $self->{child_object}->{$id}->level() . "]") if ($self->{debug} > 1);
  		        $self->{child_object}->{$id}->set($item->{metrics}->{level},'poll') if ($self->{child_object}->{$id}->level() ne $item->{metrics}->{level});
  		        }
  		      
  		      }
  		} else {
  			&main::print_log("[raZberry] Problem retrieving data from " . $self->{host});
  			$self->{data}->{retry}++;
    		return ('0');
  		}
    return ('1');
}


sub set_dev {
  my ($self,$device,$mode) = @_;
  
  &main::print_log("[raZberry] Setting $device to $mode") if ($self->{debug});
  my $cmd;
  
  my ($action,$lvl) = (split /=/,$mode)[0,1];
  if (defined $rest{$action}) {
  	$cmd = "/$zway_vdev" . "_" . $device . "/$rest{$action}";
  	$cmd .= "$lvl" if $lvl;
  	&main::print_log("[raZberry] sending command $cmd") if ($self->{debug} > 1);    
  	my ($isSuccessResponse1,$status) = _get_JSON_data($self, 'devices', $cmd);
    unless ($isSuccessResponse1) {
  			&main::print_log("[raZberry] Problem retrieving data from " . $self->{host});
    		return ('0');
    	}

   print Dumper $status if ($self->{debug} > 1);  
   }

}

sub ping_dev {
  	my ($self,$device) = @_;
  	#curl --globoff "http://mhip:8083/ZWaveAPI/Run/devices[x].SendNoOperation()"
  	my ($devid,$instance,$class) = (split /-/,$device)[0,1,2];
  	&main::print_log("[raZberry] Pinging device $device ($devid)...") if ($self->{debug});
	my $cmd;
    $cmd = "/devices%5B" . $devid . "%5D.SendNoOperation()";
	&main::print_log("ping cmd=$cmd");# if ($self->{debug} > 1);
   	my ($isSuccessResponse0,$status) = _get_JSON_data($self, 'ping', $cmd);
   	unless ($isSuccessResponse0) {
  		&main::print_log("[raZberry] Error: Problem retrieving data from " . $self->{host});
  		$self->{data}->{retry}++;
    	return ('0');
    } 
    return ($status);
}

sub update_dev {
}

#------------------------------------------------------------------------------------
sub _get_JSON_data {
  my ($self,$mode,$cmd) = @_;

  unless  ($self->{updating}) {
  
    $self->{updating} = 1;
    my $ua = new LWP::UserAgent(keep_alive=>1);
    $ua->timeout($self->{timeout});

    my $host = $self->{host};
    my $port = $self->{port};
    my $params = "";
    $params = $cmd if ($cmd);
    my $method = "ZAutomation/api/v1";
    $method = "ZWaveAPI/Run" if (($mode eq "force_update") or ($mode eq "ping"));
    &main::print_log("[raZberry] contacting http://$host:$port/$method/$rest{$mode}$params") if ($self->{debug});

    my $request = HTTP::Request->new(GET => "http://$host:$port/$method/$rest{$mode}$params");
    $request->content_type("application/x-www-form-urlencoded");

    my $responseObj = $ua->request($request);
    print $responseObj->content."\n--------------------\n" if ($self->{debug} > 1);
 
    my $responseCode = $responseObj->code;
    print 'Response code: ' . $responseCode . "\n" if ($self->{debug} > 1);
    my $isSuccessResponse = $responseCode < 400;
    $self->{updating} = 0;
    if (! $isSuccessResponse ) {
	   &main::print_log("[raZberry] Warning, failed to get data. Response code $responseCode");
	   if (defined $self->{child_object}->{comm}) {
	   	   if ($self->{child_object}->{comm}->state() ne "offline") {
	          main::print_log "Communication Tracking object found. Updating from " . $self->{child_object}->{comm}->state() . " to offline..." if ($self->{loglevel});
	          $self->{child_object}->{comm}->set("offline",'poll');
	       }
	    }
	return ('0');
    }
    if (defined $self->{child_object}->{comm}) {
	    if ($self->{child_object}->{comm}->state() ne "online") {
	       main::print_log "Communication Tracking object found. Updating from " . $self->{child_object}->{comm}->state() . " to online..." if ($self->{loglevel});
	       $self->{child_object}->{comm}->set("online",'poll');
	       }
	    }
    return ('1') if (($mode eq "force_update") or ($mode eq "ping")); #these come backs as nulls, so just return.
    my $response = JSON::XS->new->decode ($responseObj->content);
    return ($isSuccessResponse, $response)
  
  	} else {
		&main::print_log("[raZberry] Warning, not fetching data due to operation in progress");
		return ('0');
	}
}

sub stop_timer {
  my ($self) = @_;
  
  $self->{timer}->stop;
}

sub start_timer {
  my ($self) = @_;
  
  $self->{timer}->set($self->{config}->{poll_seconds}, sub {&raZberry::poll($self)}, -1);
}

sub display_all_devices {
  my ($self) = @_;
  print "--------Start of Devices--------\n";  
  for my $id (keys %{$self->{data}->{devices}}) {
  
    print "RaZberry Device $id\n";
    print "\t level:\t\t $self->{data}->{devices}->{$id}->{level}\n";
    print "\t updateTime:\t " . localtime ($self->{data}->{devices}->{$id}->{updateTime}) . "\n";
    print "\t deviceType:\t $self->{data}->{devices}->{$id}->{devicetype}\n";
    print "\t location:\t $self->{data}->{devices}->{$id}->{location}\n";
    print "\t title:\t\t $self->{data}->{devices}->{$id}->{title}\n";
    print "\t icon:\t\t $self->{data}->{devices}->{$id}->{icon}\n\n";
  }
  print "--------End of Devices--------\n";
}

sub get_dev_status {
  my ($self,$id) = @_;
  if (defined $self->{data}->{devices}->{$id}) {

  return $self->{data}->{devices}->{$id}->{level};
  
  } else {
  
  &main::print_log("[raZberry] Warning, unable to get status of device $id");
  return 0;
  }

}

sub register {
   my ($self, $object, $dev, $options ) = @_;
   if (lc $dev eq 'comm') {
      &main::print_log("[raZberry] Registering Communication object to controller"); 
      $self->{child_object}->{'comm'} = $object;
   } else {
      &main::print_log("[raZberry] Registering Device ID $dev to controller"); 
      $self->{child_object}->{$dev} = $object;
      if ($options =~ m/force_update/) {
         $self->{data}->{force_update}->{$dev} = 1;
         &main::print_log("[raZberry] Forcing Controller to contact Device $dev at each poll"); 
      }
      if ($options =~ m/keep_alive/) {
         $self->{data}->{ping}->{$dev} = 1;
         &main::print_log("[raZberry] Forcing Controller to ping Device $dev at each poll"); 
      }      
   }
}


package raZberry_dimmer;

@raZberry_dimmer::ISA = ('Generic_Item');

sub new {
   my ($class,$object,$devid,$options) = @_;

   my $self={};
   bless $self,$class;
   push(@{$$self{states}}, 'off','low','med','high','on','10%', '20%', '30%','40%','50%','60%','70%','80%','90%');

   $$self{master_object} = $object;
   $$self{devid} = $devid;

   $object->register($self,$devid,$options);
   #$self->set($object->get_dev_status,$devid,'poll');
   $self->{level} = "";
   $self->{debug} = $object->{debug};
   return $self;

}

sub set {
   my ($self,$p_state,$p_setby) = @_;

   if ($p_setby eq 'poll') {
   		$self->{level} = $p_state;
   		my $n_state;
   		if ($p_state == 100) {
   		   $n_state = "on";
   		} elsif ($p_state == 0) {
   		   $n_state = "off";
   		} elsif ($p_state == 5) {
   		   $n_state = "low"; 
   		} elsif ($p_state == 50) {
   		   $n_state = "med"; 
     		} elsif ($p_state == 95) {
   		   $n_state = "high"; 	
   		} else {
   		   $n_state .= "$p_state%";
   		}
   		main::print_log("[raZberry_dimmer] Setting value to $n_state. Level is " . $self->{level}) if ($self->{debug});

        $self->SUPER::set($n_state);
    } else {
	   if ((lc $p_state eq "off") or (lc $p_state eq "on")) {
           $$self{master_object}->set_dev($$self{devid},$p_state);
       } elsif (lc $p_state eq "low") {
       	   $$self{master_object}->set_dev($$self{devid},"level=5");
       } elsif (lc $p_state eq "med") {
       	   $$self{master_object}->set_dev($$self{devid},"level=55");
        } elsif (lc $p_state eq "high") {
       	   $$self{master_object}->set_dev($$self{devid},"level=95");  
       } elsif (($p_state eq "100%") or ($p_state =~ m/^\d{1,2}\%$/)) {
			my ($n_state) = ($p_state =~ /(\d+)%/);
			$$self{master_object}->set_dev($$self{devid},"level=$n_state");
	   } else {
	        main::print_log("[raZberry_dimmer] Error. Unknown set state $p_state");
	   }
    }
}

sub level {
  my ($self) = @_;
  
  return ($self->{level});
}

sub ping {
	my ($self) = @_;
	
	$$self{master_object}->ping_dev($$self{devid});
}

package raZberry_comm;

@raZberry_comm::ISA = ('Generic_Item');

sub new
{
   my ($class,$object) = @_;

   my $self={};
   bless $self,$class;

   $$self{master_object} = $object;
   push(@{$$self{states}}, 'online','offline');
   $object->register($self,'comm');
   return $self;

}

sub set {
   my ($self,$p_state,$p_setby) = @_;

	if ($p_setby eq 'poll') {
        $self->SUPER::set($p_state);
    } 
} 


1;
