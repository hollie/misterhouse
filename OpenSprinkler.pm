package OpenSprinkler;

use strict;
use warnings;

use LWP::UserAgent;
use HTTP::Request::Common qw(POST);
use JSON::XS;
use Data::Dumper;




# $os1        = new OpenSprinkler('192.168.0.100','md5-password',poll);
#
# $os_wl = new OpenSprinkler_Waterlevel($os1);
# $os_rs = new OpenSprinkler_Rainstatus($os1);
# $front_garden   = new OpenSprinkler_Station($os1,0,60);
#
# $os1_comm		= new OpenSprinkler_Comm($os1);
# methods
#	-set disable
#	-reboot
#	-reset
#   - get_waterlevel


#todo 
# - log runtimes. Maybe into a dbm file? log_runtimes method with destination.
#?? disabling the opensprinkler doesn't turn off the stations?
#?? parse return codes better, 
#?? print logs
# # make the data poll non-blocking, turn off timer
#
# State can only be set by stat. Set mode will change the mode.


@OpenSprinkler::ISA = ('Generic_Item');


# -------------------- START OF SUBROUTINES --------------------
# --------------------------------------------------------------

our %rest;

$rest{get_vars} = "jc";
$rest{set_vars} = "cv";

$rest{get_options} = "jo";
$rest{set_options} = "co";
$rest{station_info} = "jn";
$rest{get_stations} = "js";
$rest{set_stations} = "cs";
$rest{test_station} = "cm";

$rest{get_log} = "jl";


our %result;
$result{1} = "success";
$result{2} = "unauthorized";
$result{3} = "mismatch";
$result{4} = "data missing";
$result{5} = "out of Range";
$result{6} = "data format";
$result{7} = "error page not found"; 
$result{8} = "not permitted";
$result{9} = "unknown error";

sub new {
   my ($class, $host,$pwd,$poll) = @_;
   my $self = {};
   bless $self, $class;
   $self->{data} = undef;
   $self->{child_object} = undef;
   $self->{config}->{cache_time} = 5; #TODO fix cache timeouts
   $self->{config}->{cache_time} = $::config_params{OpenSprinkler_config_cache_time} if defined $::config_params{OpenSprinkler_config_cache_time};
   $self->{config}->{tz} = $::config_params{time_zone}; #TODO Need to figure out DST for print runtimes
   $self->{config}->{poll_seconds} = 10;
   $self->{config}->{poll_seconds} = $poll if ($poll);
   $self->{config}->{poll_seconds} = 1 if ($self->{config}->{poll_seconds} < 1);
   $self->{updating} = 0;
   $self->{data}->{retry} = 0;
   $self->{data}->{stations} = ();
   $self->{host} = $host; 
   $self->{password} = $pwd;       
   $self->{debug} = 0;
   $self->{loglevel} = 1;
   $self->{timeout} = 4; #300;
   push(@{$$self{states}}, 'enabled', 'disabled');   

   $self->_init;
   $self->{timer} = new Timer;
   $self->start_timer;
   return $self;
}

sub _poll_check {
  my ($self) = @_;
    #main::print_log("[OpenSprinkler] _poll_check initiated");
    #main::run (sub {&VOpenSprinkler::get_data($self)}); #spawn this off to run in the background
    $self->get_data();
}

sub get_data {
  my ($self) = @_;
    #main::print_log("[OpenSprinkler] get_data initiated");
  $self->poll;
  $self->process_data;
}

sub _init {
  my ($self) = @_;

  my ($isSuccessResponse1,$osp) = $self->_get_JSON_data('get_options');

  if ($isSuccessResponse1) {

    if ($osp) { #->{fwv} > 213) {
    
      main::print_log("[OpenSprinkler] OpenSprinkler found (v$osp->{hwv} / $osp->{fwv})");
      my ($isSuccessResponse2,$stations) = $self->_get_JSON_data('station_info');
	  for my $index (0 .. $#{$stations->{snames}}) {
    	#print "$index: $stations->{snames}[$index]\n";
    	$self->{data}->{stations}->[$index]->{name} = $stations->{snames}[$index];
	  }      
		# Check to see if station is disabled, Bitwise operation
		for my $stn_dis ( 0 .. $#{$stations->{stn_dis}}) {
  			my $bin = sprintf "%08b", $stations->{stn_dis}[$stn_dis];
  			for my $bit ( 0 .. 7) {
  				my $station_id = (($stn_dis * 8) + $bit);
  				my $disabled =  substr $bin,(7-$bit),1;
  				$self->{data}->{stations}->[$station_id]->{status} = ($disabled == 0 ) ? "enabled" : "disabled";
  			}
		}
#print Dumper $self;	  		
		$self->{previous}->{info}->{waterlevel} = $osp->{wl};
		$self->{previous}->{info}->{rs} = "init";
		$self->{previous}->{info}->{state} = "disabled";
		$self->{previous}->{info}->{adjustment_method} = "init";
		$self->{previous}->{info}->{rain_sensor_status} = "init";
		$self->{previous}->{info}->{sunrise} = 0;
		$self->{previous}->{info}->{sunset} = 0;
      if ($self->poll()) {
        main::print_log("[OpenSprinkler] Data Successfully Retrieved");
        $self->{active} = 1;
    	$self->print_info();
    	$self->set($self->{data}->{info}->{state},'poll');

      } else {
        main::print_log("[OpenSprinkler] Problem retrieving initial data");
        $self->{active} = 0;
        return ('1');
      }

     } else {
       main::print_log("[OpenSprinkler] Unknown device " . $self->{host});
       $self->{active} = 0;
       return ('1');
    }

   } else {
    main::print_log("[OpenSprinkler] Error. Unable to connect to " . $self->{host});
    $self->{active} = 0;
    return ('1');
   }
}

sub poll {
  my ($self) = @_;
  
  main::print_log("[OpenSprinkler] Polling initiated") if ($self->{debug});
    
  		my ($isSuccessResponse1,$vars) = $self->_get_JSON_data('get_vars');
  		my ($isSuccessResponse2,$options) = $self->_get_JSON_data('get_options');
  		my ($isSuccessResponse3,$stations) = $self->_get_JSON_data('get_stations');

  
  		if ($isSuccessResponse1 and $isSuccessResponse2 and $isSuccessResponse3) {
    		$self->{data}->{name} = $vars->{loc};
    		$self->{data}->{loc} = $vars->{loc};
	   		$self->{data}->{options} = $options;
    		$self->{data}->{vars} = $vars;
    		$self->{data}->{info}->{state} = ($vars->{en} == 0 ) ? "disabled" : "enabled";
			$self->{data}->{info}->{waterlevel} = $options->{wl};
			$self->{data}->{info}->{adjustment_method} = ($options->{uwt} == 0) ? "manual" : "zimmerman";
			$self->{data}->{info}->{rain_sensor_status} = ($vars->{rs} == 0) ? "off" : "on";
			$self->{data}->{info}->{sunrise} = $vars->{sunrise};
			$self->{data}->{info}->{sunset} = $vars->{sunset};

	 		for my $index (0 .. $#{$stations->{sn}}) {
    			print "$index: $stations->{sn}[$index]\n" if ($self->{debug});
    			$self->{data}->{stations}->[$index]->{state} = ($stations->{sn}[$index] == 0 ) ? "off" : "on";
	  		} 
    		$self->{data}->{nstations} = $stations->{nstations};
    		$self->{data}->{timestamp} = time;
    		$self->{data}->{retry} = 0;
#print Dumper $self;
    		if (defined $self->{child_object}->{comm}) {
    			if ($self->{child_object}->{comm}->state() ne "online") {
	  		       main::print_log "[OpenSprinkler] Communication Tracking object found. Updating..." if ($self->{loglevel});
	  		       $self->{child_object}->{comm}->set("online",'poll');
	  		   }
	  	    }
    		return ('1');
  		} else {
  			main::print_log("[OpenSprinkler] Problem retrieving poll data from " . $self->{host});
  			$self->{data}->{retry}++;
  			if (defined $self->{child_object}->{comm}) {
  			   if ($self->{child_object}->{comm}->state() ne "offline") {
	  		      main::print_log "[OpenSprinkler] Communication Tracking object found. Updating..." if ($self->{loglevel});
	  		      $self->{child_object}->{comm}->set("offline",'poll');
	  		   }
	  	    }
    		return ('0');
  		}

}

#------------------------------------------------------------------------------------
sub _get_JSON_data {
  my ($self, $mode, $cmd) = @_;

  unless  ($self->{updating}) {
    $cmd = "" unless ($cmd);
    $self->{updating} = 1;
    my $ua = new LWP::UserAgent(keep_alive=>1);
    $ua->timeout($self->{timeout});

    my $host = $self->{host};
    my $password = $self->{password};
    print "Opening http://$host/$rest{$mode}?pw=$password$cmd...\n" if ($self->{debug});
    my $request = HTTP::Request->new(GET => "http://$host/$rest{$mode}?pw=$password$cmd");
    #$request->content_type("application/x-www-form-urlencoded");

    my $responseObj = $ua->request($request);
    print $responseObj->content."\n--------------------\n" if $self->{debug};
 
    my $responseCode = $responseObj->code;
    print 'Response code: ' . $responseCode . "\n" if $self->{debug};
    my $isSuccessResponse = $responseCode < 400;
    $self->{updating} = 0;
    if (! $isSuccessResponse ) {
	main::print_log("[OpenSprinkler] Warning, failed to get data. Response code $responseCode");
    if (defined $self->{child_object}->{comm}) {
      	if ($self->{child_object}->{comm}->state() ne "offline") {
	    main::print_log "[OpenSprinkler] Communication Tracking object found. Updating..." if ($self->{loglevel});
	    $self->{child_object}->{comm}->set("offline",'poll');
	    }
	}
	return ('0');
    } else {
       if (defined $self->{child_object}->{comm}) {
       	 if ($self->{child_object}->{comm}->state() ne "online") {
	        main::print_log "[OpenSprinkler] Communication Tracking object found. Updating..." if ($self->{loglevel});
	        $self->{child_object}->{comm}->set("online",'poll');
	      }
	   }
	} 
	my $response;   
    eval {
      $response = JSON::XS->new->decode ($responseObj->content);
    };
  # catch crashes:
  if($@){
    print "[OpenSprinkler] ERROR! JSON parser crashed! $@\n";
    return ('0');
  } else {
    my $result_code = 9;
    $result_code = $response->{"result"} if (defined $response->{"result"});
    print "[OpenSpinkler] JSON fetch operation result is " .$result{$result_code} . "\n" if (($self->{loglevel}) or ($result_code != 1));
    return ($isSuccessResponse, $result{$result_code})
  }
  	} else {
		main::print_log("[OpenSprinkler] Warning, not fetching data due to operation in progress");
		return ('0');
	}
}

sub register {
   my ($self, $object, $type, $number ) = @_;
   #my $name;
   #$name = $$object{object_name};  #TODO: Why can't we get the name of the child object?
   if (lc $type eq "station") {
      &main::print_log("[OpenSprinkler] Registering station $number child object"); 
      $self->{child_object}->{station}->{$number} = $object;
      $object->set_label($self->{data}->{stations}->[$number]->{name});
   } else {
      &main::print_log("[OpenSprinkler] Registering $type child object"); 

   		$self->{child_object}->{$type} = $object;
   	}

   }

sub stop_timer {
  my ($self) = @_;
  
  if (defined $self->{timer}) {  
    $self->{timer}->stop() if ($self->{timer}->active());
  } else {
  	main::print_log("[OpenSprinkler] Warning, stop_timer called but timer undefined");
  }
}

sub start_timer {
  my ($self) = @_;
  
  if (defined $self->{timer}) {  
     $self->{timer}->set($self->{config}->{poll_seconds}, sub {&OpenSprinkler::_poll_check($self)}, -1);
    } else {
  	main::print_log("[OpenSprinkler] Warning, start_timer called but timer undefined");
  }
}

sub print_info {
	my ($self) = @_;
	
	my (@state,@enabled,@rd,@rs,@pwenabled);
	$state[0] = "off";
	$state[1] = "on";
	$enabled[1] = "ENABLED";
	$enabled[0] = "DISABLED";
	$pwenabled[0] = "ENABLED";
	$pwenabled[1] = "DISABLED";
	$rd[0] = "rain delay is currently in effect";
	$rd[1] = "no rain delay";
	$rs[0] = "rain is detected from rain sensor";
	$rs[1] = "no rain detected";

	main::print_log("[OpenSprinkler] Device Hardware v" . $self->{data}->{options}->{hwv} . " with firmware " . $self->{data}->{options}->{fwv});
	main::print_log("[OpenSprinkler] *Mode is " . $self->{data}->{info}->{state});
	main::print_log("[OpenSprinkler] Time Zone is " . $self->get_tz());
	main::print_log("[OpenSprinkler] NTP Sync " . $state[$self->{data}->{options}->{ntp}]);
	main::print_log("[OpenSprinkler] Use DHCP " . $state[$self->{data}->{options}->{dhcp}]);
	main::print_log("[OpenSprinkler] Number of expansion boards " . $self->{data}->{options}->{ext});
	main::print_log("[OpenSprinkler] Station delay time " . $self->{data}->{options}->{sdt});
	main::print_log("[OpenSprinkler] Master station " . $self->{data}->{options}->{mas});
	main::print_log("[OpenSprinkler] master on time " . $self->{data}->{options}->{mton});
	main::print_log("[OpenSprinkler] master off time " . $self->{data}->{options}->{mtof});
	main::print_log("[OpenSprinkler] Rain Sensor " . $state[$self->{data}->{options}->{urs}]);	
	main::print_log("[OpenSprinkler] *Water Level " . $self->{data}->{info}->{waterlevel});
	main::print_log("[OpenSprinkler] Password is " . $pwenabled[$self->{data}->{options}->{ipas}]);
	main::print_log("[OpenSprinkler] Device ID " . $self->{data}->{options}->{devid}) if defined ($self->{data}->{options}->{devid});
	main::print_log("[OpenSprinkler] LCD Contrast " . $self->{data}->{options}->{con});
	main::print_log("[OpenSprinkler] LCD Backlight " . $self->{data}->{options}->{lit});
	main::print_log("[OpenSprinkler] LCD Dimming " . $self->{data}->{options}->{dim});
	main::print_log("[OpenSprinkler] Relay Pulse Time " . $self->{data}->{options}->{rlp}) if defined ($self->{data}->{options}->{rlp});
	main::print_log("[OpenSprinkler] *Weather adjustment Method " . $self->{data}->{info}->{adjustment_method});
	main::print_log("[OpenSprinkler] Logging " . $enabled[$self->{data}->{options}->{lg}]);
	main::print_log("[OpenSprinkler] Zone expansion boards " . $self->{data}->{options}->{dexp});
	main::print_log("[OpenSprinkler] Max zone expansion boards " . $self->{data}->{options}->{mexp});
	
	main::print_log("[OpenSprinkler] Device Time " . localtime($self->{data}->{vars}->{devt}));
	main::print_log("[OpenSprinkler] Number of 8 station boards " . $self->{data}->{vars}->{nbrd});
	main::print_log("[OpenSprinkler] Rain delay " . $self->{data}->{vars}->{rd});
	main::print_log("[OpenSprinkler] *Rain sensor status " . $self->{data}->{info}->{rain_sensor_status});
	main::print_log("[OpenSprinkler] Location " . $self->{data}->{vars}->{loc});
	main::print_log("[OpenSprinkler] Wunderground key " . $self->{data}->{vars}->{wtkey});
	main::print_log("[OpenSprinkler] *Sun Rises at " . $self->get_sunrise());
	main::print_log("[OpenSprinkler] *Sun Sets at " . $self->get_sunset());

}

sub process_data {
	my ($self) = @_;
	# Main core of processing
	# set state of self for state
	# for any registered child selfs, update their state if 
	
	
	for my $index (0 .. $#{$self->{data}->{stations}}) {
		next if ($self->{data}->{stations}->[$index]->{status} eq "disabled"); 
		my $previous = "init";
		$previous = $self->{previous}->{data}->{stations}->[$index]->{state} if (defined $self->{previous}->{data}->{stations}->[$index]->{state});
		if ($previous ne $self->{data}->{stations}->[$index]->{state}) {
	  		main::print_log("[OpenSprinkler] Station $index $self->{data}->{stations}->[$index]->{name} changed from $previous to $self->{data}->{stations}->[$index]->{state}") if ($self->{loglevel});
	  		$self->{previous}->{data}->{stations}->[$index]->{state} = $self->{data}->{stations}->[$index]->{state};
	  		if (defined $self->{child_object}->{station}->{$index}) {
	  			main::print_log "Child object found. Updating..." if ($self->{loglevel});
	  			$self->{child_object}->{station}->{$index}->set($self->{data}->{stations}->[$index]->{state},'poll');
	  		}
		}
	}
	
	if ($self->{previous}->{info}->{state} ne $self->{data}->{info}->{state}) {
	  main::print_log("[OpenSprinkler] State changed from $self->{previous}->{info}->{state} to $self->{data}->{info}->{state}") if ($self->{loglevel});
	  $self->{previous}->{info}->{state} = $self->{data}->{info}->{state};
	  $self->set($self->{data}->{info}->{state},'poll');
	}
	
	if ($self->{previous}->{info}->{waterlevel} != $self->{data}->{info}->{waterlevel}) {
	  main::print_log("[OpenSprinkler] Waterlevel changed from $self->{previous}->{info}->{waterlevel} to $self->{data}->{info}->{waterlevel}") if ($self->{loglevel});
	  $self->{previous}->{info}->{waterlevel} = $self->{data}->{info}->{waterlevel};
	  if (defined $self->{child_object}->{waterlevel}) {
	  	main::print_log "Child object found. Updating..." if ($self->{loglevel});
	  	$self->{child_object}->{waterlevel}->set($self->{data}->{info}->{waterlevel},'poll');
	  }
	}

	if ($self->{previous}->{info}->{rain_sensor_status} ne $self->{data}->{info}->{rain_sensor_status}) {
	  main::print_log("[OpenSprinkler] Rain Sensor changed from $self->{previous}->{info}->{rain_sensor_status} to $self->{data}->{info}->{rain_sensor_status}") if ($self->{loglevel});
	  $self->{previous}->{info}->{rain_sensor_status} = $self->{data}->{info}->{rain_sensor_status};
	  if (defined $self->{child_object}->{rain_sensor_status}) {
	  	main::print_log "Child object found. Updating..." if ($self->{loglevel});
	  	$self->{child_object}->{rain_sensor_status}->set($self->{data}->{info}->{rain_sensor_status},'poll');
	  }
	}

	if ($self->{previous}->{info}->{sunset} != $self->{data}->{info}->{sunset}) {
	  main::print_log("[OpenSprinkler] Sunset changed to " . $self->get_sunset()) if ($self->{loglevel});
	  $self->{previous}->{info}->{sunset} = $self->{data}->{info}->{sunset};
	}

	if ($self->{previous}->{info}->{sunrise} != $self->{data}->{info}->{sunrise}) {
	  main::print_log("[OpenSprinkler] Sunrise changed to " . $self->get_sunrise()) if ($self->{loglevel});
	  $self->{previous}->{info}->{sunrise} = $self->{data}->{info}->{sunrise};
	}
	
	if ($self->{previous}->{info}->{adjustment_method} ne $self->{data}->{info}->{adjustment_method}) {
	  main::print_log("[OpenSprinkler] Adjustment Method changed from $self->{previous}->{info}->{adjustment_method} to $self->{data}->{info}->{adjustment_method}") if ($self->{loglevel});
	  $self->{previous}->{info}->{adjustment_method} = $self->{data}->{info}->{adjustment_method};
	}
		
}


sub print_logs {
	my ($self) = @_;
    my ($isSuccessResponse1,$data) = get_JSON_data($self->{host},'runtimes');

   for my $tstamp (0..$#{$data->{runtimes}}) {
   
     print $data->{runtimes}[$tstamp]->{ts} . " -> ";
     print scalar localtime (($data->{runtimes}[$tstamp]->{ts}) - ($self->{config}->{tz}*60*60+1));
     main::print_log("\tCooling: " . $data->{runtimes}[$tstamp]->{cool1});
     main::print_log("\tHeating: " . $data->{runtimes}[$tstamp]->{heat1});
     main::print_log("\tCooling 2: " . $data->{runtimes}[$tstamp]->{cool2}) if $data->{runtimes}[$tstamp]->{cool2};
     main::print_log("\tHeating 2: " . $data->{runtimes}[$tstamp]->{heat2}) if $data->{runtimes}[$tstamp]->{heat2};
     main::print_log("\tAux 1: " . $data->{runtimes}[$tstamp]->{aux1}) if $data->{runtimes}[$tstamp]->{aux1};
     main::print_log("\tAux 2: " . $data->{runtimes}[$tstamp]->{aux2}) if $data->{runtimes}[$tstamp]->{aux2};
     main::print_log("\tFree Cooling: " . $data->{runtimes}[$tstamp]->{fc}) if $data->{runtimes}[$tstamp]->{fc};
          
   }
}

sub get_station {
  my ($self,$number) = @_;

  return ($self->{data}->{stations}->[$number]->{state});

}

sub set_station {

  my ($self,$station,$state,$time) = @_;

  return if (lc $state eq $self->{state});

  #print "db: set_station state=$state, station=$station time=$time\n";
  my $cmd = "&sid=" . $station;
  if (lc $state eq "on") {
  	$cmd .= "&en=1&t=" . $time;
  } else {
    $cmd .= "&en=0";
  }
  my ($isSuccessResponse,$status) = $self->_get_JSON_data('test_station',$cmd);
  if ($isSuccessResponse) {
   #print "DB status=$status\n";
    if ($status eq "success") { #todo parse return value
      $self->poll;
      return (1);
    } else {
        main::print_log("[OpenSprinkler] Error. Could not set station to $state");
        return (0);
    }
  } else {
     main::print_log("[OpenSprinkler] Error. Could not send data to OpenSprinkler");
  	return (0);
  }

}

sub get_sunrise {
  my ($self) = @_;
# add in nice calc, minutes since midnight
  my $AMPM = "AM";
  my $hour = int ($self->{data}->{vars}->{sunrise} / 60);
  my $minute = $self->{data}->{vars}->{sunrise} % 60;
  if ($hour > 12) {
  	$hour = $hour - 12;
  	$AMPM= "PM";
  }
  
  return ("$hour:$minute $AMPM");
}

sub get_sunset {
  my ($self) = @_;
  my $AMPM = "AM";
  my $hour = int($self->{data}->{vars}->{sunset} / 60);
  my $minute = $self->{data}->{vars}->{sunset} % 60;
  if ($hour > 12) {
  	$hour = $hour - 12;
  	$AMPM= "PM";
  }
  
  return ("$hour:$minute $AMPM");
}


sub get_tz {
   my ($self) = @_;
   my $tz = ($self->{data}->{options}->{tz} - 48) / 4;
   if ($tz >= 0 ) {
     $tz = "GMT+$tz";
   } else {
     $tz = "GMT$tz";
    }
	return ($tz);
}

sub reboot {
  	my ($self) = @_;
  
  	my $cmd = "&rbt=1";
  	my ($isSuccessResponse,$status) = $self->_get_JSON_data('set_vars',$cmd);
  
	return ($status);
}

sub reset {
  	my ($self) = @_;
  
  	my $cmd = "&rsn=1";
  	my ($isSuccessResponse,$status) = $self->_get_JSON_data('set_vars',$cmd);
  
	return ($status);
}

sub  get_waterlevel {
	my ($self) = @_;
	
	return ($self->{data}->{info}->{waterlevel});
}

sub  get_rainstatus {
	my ($self) = @_;
	
	return ($self->{data}->{info}->{rain_sensor_status});
}

sub set_rain_delay {
  	my ($self,$hours) = @_;
  
  	my $cmd = "&rsn=$hours";
  	my ($isSuccessResponse,$status) = $self->_get_JSON_data('set_vars',$cmd);
  
	return ($status);
}

sub set {
   my ($self,$p_state,$p_setby) = @_;

	if ($p_setby eq 'poll') {
        $self->SUPER::set($p_state);
    } else {

  		return if (lc $p_state eq $self->{state});
    	my $en;
		if ((lc $p_state eq "enabled") || (lc $p_state eq "on")) {
	  		$en = 1;
		} elsif ((lc $p_state eq "disabled") || (lc $p_state eq "off")) {
			$en = 0;
		} else {
	     	main::print_log("[OpenSprinkler] Error. Unknown state $p_state");
	     	return (0);
		}

   		my $cmd = "&en=" . $en;

  		my ($isSuccessResponse,$status) = $self->_get_JSON_data('set_vars',$cmd);
  		if ($isSuccessResponse) {
    		if ($status eq "success") { #todo parse return value
      			$self->poll;
      			return (1);
    		} else {
        		main::print_log("[OpenSprinkler] Error. Could not set state to $p_state");
        		return (0);
    		}
  		} else {
     		main::print_log("[OpenSprinkler] Error. Could not send data to OpenSprinkler");
  			return (0);
 		 }
	}
}    



package OpenSprinkler_Station;

@OpenSprinkler_Station::ISA = ('Generic_Item');

sub new
{
   my ($class,$object, $number, $on_timeout) = @_;

   my $self={};
   bless $self,$class;

   $$self{master_object} = $object;
   $$self{station} = $number;
   push(@{$$self{states}}, 'on','off');
   $$self{on_timeout} = 3600; #default to an hour for 'on'
   $$self{on_timeout} = $on_timeout * 60 if $on_timeout;
   $object->register($self,'station',$number);
   $self->set($object->get_station($number),'poll');
   return $self;

}

sub set {
   my ($self,$p_state,$p_setby,$time_override) = @_;

	if ($p_setby eq 'poll') {
    #print "db: setting by poll to $p_state\n";
        $self->SUPER::set($p_state);
    } else {
#bounds check, add in time_override
		my $time = $$self{on_timeout};
		$time = $time_override if ($time_override);
        $$self{master_object}->set_station($$self{station},$p_state,$time);
    }
}


package OpenSprinkler_Comm;

@OpenSprinkler_Comm::ISA = ('Generic_Item');

sub new {
   my ($class,$object) = @_;

   my $self={};
   bless $self,$class;

   $$self{master_object} = $object;
   push(@{$$self{states}}, 'online','offline');
	SUPER::set('offline');
   $object->register($self,'comm');
   return $self;

}

sub set {
   my ($self,$p_state,$p_setby) = @_;

	if ($p_setby eq 'poll') {
        $self->SUPER::set($p_state);
    } 
} 

package OpenSprinkler_Waterlevel;

@OpenSprinkler_Waterlevel::ISA = ('Generic_Item');

sub new {
   my ($class,$object) = @_;

   my $self={};
   bless $self,$class;

   $$self{master_object} = $object;
   $object->register($self,'waterlevel');
   $self->set($object->get_waterlevel,'poll');

   return $self;

}

sub set {
   my ($self,$p_state,$p_setby) = @_;

	if ($p_setby eq 'poll') {
        $self->SUPER::set($p_state);
    } 
} 

package OpenSprinkler_Rainstatus;

@OpenSprinkler_Rainstatus::ISA = ('Generic_Item');

sub new {
   my ($class,$object) = @_;

   my $self={};
   bless $self,$class;

   $$self{master_object} = $object;
   $object->register($self,'rain_sensor_status');
   $self->set($object->get_rainstatus,'poll');
   return $self;

}

sub set {
   my ($self,$p_state,$p_setby) = @_;

	if ($p_setby eq 'poll') {
        $self->SUPER::set($p_state);
    } 
} 

1;
