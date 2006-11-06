
# Package: OneWire_xAP
# $Date$
# $Revision$

=begin comment
@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@

Description:

	This package provides an interface to one-wire devices via the xAP
	(www.xapautomation.org) "connector": oxc (www.limings.net/xap/oxc)

Author:
	Gregg Liming
	gregg@limings.net

License:
	This free software is licensed under the terms of the GNU public license

Usage:
	Documentation on installing/configuring oxc is found in the oxc distribution.
	(Note: oxc currently relies on digitemp (www.digitemp.com).

        The xAP message convention assumes that the one-wire xAP connector, oxc,
        is addressed via the target: liming.oxc.house 

        Each "device" is subaddressed using the convention: :<type>.<name> where
        <type> can be temp, humid, etc and <name> is a user-definable name
        specfified in the oxc config.

     Declaration:

        If declaring via .mht:
        OWX,  house,   house_owx

        Where 'house' is the xap instance name and 'house_owx' is the object

	# declare the oxc "conduit" object
        $oxc = new OneWire_xAP;

	# create one or more AnalogSensor_Items that will be attached to the OneWire_xAP
        # See additional comments in AnalogSensor_Items for .mht based declaration

	$indoor_temp = new AnalogSensor_Item('indoor-t', 'temp');
	# 'indoor-t' is the device name, 'temp' is the sensor type
	$indoor_humid = new AnalogSensor_Item('indoor-h', 'humid');

	$ocx->add($indoor_temp, $indoor_humid);

	Information on using AnalogSensor_Items is contained within its
	corresponding package documentation

@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
=cut

use strict;

package OneWire_xAP;
@OneWire_xAP::ISA = ('Base_Item');

use BSC;


sub new {

	my ($class) = @_;
	my $self={};
	bless $self, $class;

	$$self{source_map} = {};
	return $self;
}

sub add {

	my ($self, $device) = @_;
	my $instance_name = "house"; # need to make this configurable
        if ($device) {
		push @{$$self{m_devices}}, $device;
		my $xap_address = "liming.oxc.$instance_name:" . lc $device->type
			. "." . $device->id;
		my $xap_item = new BSC_Item($xap_address);
		$$self{source_map}{$xap_item} = $device;
		$self->SUPER::add($xap_item); # add it so that it can set this obejct
	}
}

sub set {

	my ($self, $p_state, $p_setby, $p_response) = @_;

	for my $source ($self->find_members('BSC_Item')) {
		if ($source eq $p_setby) {
			print "text=" . $source->text . 
				" level=" . $source->level . "\n" if $::Debug{onewire};
			my $device = $$self{source_map}{$source};
                        # TO-DO: support other sensors types than just humid and temp
			if ($device->type eq 'humid') {
			# parse the data from the level member stripping % char
                           if ($source->level) {
                              if ($source->level =~ /\d+\/\d+/) {
                                 my ($humid1, $range) = $source->level =~ /^(\d+)\/(\d+)/;
                                 $device->measurement(100*($humid1/$range)) if (defined($humid1) and ($range));
                              } else {
			         my ($humid, $humid_scale) = $source->level =~ /^(-?\d*\.?\d*)\s*(\S*)/;
			         $device->measurement($humid) if defined($humid);
                              }
                           } elsif ($source->text) {
			      my ($humid, $humid_scale) = $source->text =~ /^(-?\d*\.?\d*)\s*(\S*)/;
			      $device->measurement($humid) if defined($humid);
                           }
			} elsif ($device->type eq 'temp') {
			# parse the data from the text member using the last char for scale
                        # TO-DO: perform conversion if temp_scale is not what device wants
				my ($temp, $temp_scale) = $source->text =~ /^(-?\d*\.?\d*)\s*(\S*)/;
				$device->measurement($temp) if defined($temp);
			}
			last; # we're done as only one setby
		}
	}
}

=begin comment
@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@

Description:

	This package provides a device-agnostic method of maintaining analog sensor
        measurement collection, contains derivative utilities and mechanisms for
        deriving state and/or associating action to sensor change.

Author:
	Gregg Liming
	gregg@limings.net

License:
	This free software is licensed under the terms of the GNU public license

Usage:

     Declaration:

        If declaring via .mht:
       
        ANALOG_SENSOR, indoor-t, indoor_temp, house_owx, Sensors, temp, hot_alarm=85, cold_alarm=62

 	'indoor-t' is an identifier for the sensor that some other software will
        require to associate sensor data to this item.  'temp' is the sensor
        type.  Currently, only 'temp' and 'humid' are supported.  Additional
        types will be added in the future. house_owx is the one-wire "conduit" that
        populates AnalogSensor_Items.  Sensors is a group.  The tag=value data
        following "temp" are tokens.  More info on use of tokens is described below.

        Alternatively, if declaring via code:

	$indoor_temp = new AnalogSensor_Item('indoor-t', 'temp');

     Operations:

	measurement(measurement,timestamp,skipdelta) - updates the measurement
		data maintained by this item if measurement, etc are provided;
		otherwise the last measurement value is returned.

	map_to_weather(weather_hash_memberi, graph_title) - copies any measurement 
                update to the Weather hash specified by weather_hash_member.
                If graph_title is supplied, it will replace the default graph title
                used by code/common/weather_rrd_update.pl to display titles.
                Note that if graph_title is used, then you must consistently use
                this with all sensors or specify the titles via the ini parm:
                weather_graph_sensor_names.

	get_average_change_rate(number_samples) - returns the average change
		rate over number_samples.  In general, number_samples should be
		> 1 since a very low delta time between previous and current
		measurement can make the change rate artificially high.
		Specifying longer numbers will provide more smoothing.  If
		fewer samples exist than number_samples, the existing number will
		be used. 

	apply_offset(offset) - applies an offset to the measurement value.  Enter
		a negative number to apply a negative offset.  This is useful to
		compensate for linear temperature shifts.

        token(tag,value) - adds "value" as a "token" to be evaluated during state
                and/or event condition checks; or, returns "token" if only "tag"
                is supplied.  A token is referenced in a condition
                using the syntax: $token_<tag> where <tag> is tag.  See 
                tie_state_condition example below.

	remove_token(tag) - removes the token from use. IMPORTANT: do not remove
                a token before first removing all conditions that depend on it.

	tie_state_condition(condition,state) - registers a condition and state value
		to be evaluated each measurement update.  If condition is true and
		the current item's state value is not "state", then the state value
		is changed to "state".  Note that tieing more than one condition
		to the same state--while supported--is discouraged as the first
		condition that "wins" is used; no mechanism exists to determine
		the order of condition evaluation.

		$indoor_temp->tie_state_condition('$measurement > 81 and $measurement < 84',hot);

                # use tokens to that the condition isn't "hardwired" to a constant
                $indoor_temp->token('danger_sp',85);
		$indoor_temp->tie_state_condition('$measurement > $token_danger_sp',dangerhot);

		In the above example, the state is changed to hot if it is not already hot AND
		the mesaurement is between 81 and 84. Similarly, the state is change to 
		dangerhot if the state is not already dangerhot and exceeds 85 degrees.
		Note that the state will not change if the measurement is greater than 84
		degrees--which is the "hot" condition--until it reaches the "dangerhot"
		condition.  This example illustrates a 1 degree hysteresis (actually, greater
		than 1 degree if the measurement updates do not provide tenths or greater
		precision).

		It is important to note in the above example that single quotes are used
		since the string "$measurement" must not be evaluated until the state
		condition is checked.  There are a number of "built-in" condition variables
		which are referenced via tokens.  The current set of tokens is:

		$measurement - the current measurement value
		$measurement_change - the difference between the previous value and the
			most recent value.  Note that this may be 0.
		$time_since_previous - the different in time between the previous value
			and the most recent value.  The resolution is milliseconds.
		$recent_change_rate - the average change rate over the last three samples
		$state - the state of the item

        measurement_change - returns the most current change of measurement values

	untie_state_condition(condition) - unregisters condition.  Unregisters all 
		conditions if condition is not provided.

	tie_event_condition(condition,event) - registers a condition and an event.
		See tie_state_condition for an explanation of condition.  event is
		the code or code reference to be evaluated if condition is true.
		Since tied event conditions are evaluated for every measurement update,
		be careful that the condition relies on change-oriented variables
		and/or that the internal logic of "event" ensure against more frequent
		execution than is desired.

	untie_event_condition(condition) - same as untie_state_condition except applied
		to tied event conditions.

	id(id) - sets id to id.  Returns id if id not present.

	type(type) - set type to type (temp or humid). Returns type if not present.

@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
=cut


package AnalogSensor_Item;
@AnalogSensor_Item::ISA = ('Generic_Item');

use Time::HiRes qw(gettimeofday);


sub new {

	my ($class, $p_id, $p_type, @p_tokens) = @_;
	my $self={};
	bless $self, $class;
	$self->id($p_id);
	$self->type($p_type);
	# maintain measurement member as it is like state
	$self->restore_data('m_measurement','m_timestamp','m_time_since_previous','m_measurement_change');
	$$self{m_max_records} = 10;
        for my $token (@p_tokens) {
           my ($tag, $value) = split(/=/,$token);
           if (defined($tag) and defined($value)) {
              print "[AnalogSensor_Item] Adding analog sensor token: $tag "
                  . "having value: $value\n" if $main::Debug{onewire};
              $self->token($tag, $value);
           }
        }
	return $self;
}

sub id {
	my ($self, $p_id) = @_;
	$$self{m_id} = $p_id if defined($p_id);
	return $$self{m_id};
}

sub type {
	my ($self, $p_type) = @_;
	$$self{m_type} = $p_type if $p_type;
	return $$self{m_type};
}

sub measurement {
	my ($self, $p_measurement, $p_timestamp, $p_skip_delta) = @_;
	my @measurement_records = ();
	@measurement_records = @{$$self{m_measurement_records}} if exists($$self{m_measurement_records});
	my $measurement_record = {};
	# check to see if @measurement_records exist; if not then attempt to restore
	#   from saved data
	if (!(@measurement_records)) {
		if ($$self{m_measurement}) {
			$measurement_record->{measurement} = $$self{m_measurement};
			$measurement_record->{timestamp} = $$self{m_timestamp};
			unshift @measurement_records, $measurement_record;
			$$self{m_measurement_records} = [ @ measurement_records ];
		}	
	}
	if (defined($p_measurement)) {
		$p_timestamp = gettimeofday() unless $p_timestamp; # get a timestamp if one not procided
		$p_measurement += $self->apply_offset if $self->apply_offset;
		$measurement_record->{measurement} = $p_measurement;
		$measurement_record->{timestamp} = $p_timestamp;
		# if we have a prior record, then compute the deltas
		if (!($p_skip_delta) && @measurement_records) {
			my $last_index = 0; #scalar(@measurement_records)-1;
			$$self{m_time_since_previous} = $p_timestamp -
				$measurement_records[$last_index]->{time_since_previous};
			$$self{m_measurement_change} = $p_measurement -
				$measurement_records[$last_index]->{measurement_change};
			# and update this record
			$measurement_record->{time_since_previous} = $$self{m_time_since_previous};
			$measurement_record->{measurement_change} = $$self{m_measurement_change};
		} else {
			$measurement_record->{time_since_previous} = 0;
			$measurement_record->{measurement_change} = 0;
		}
		unshift @measurement_records, $measurement_record;
		if (scalar(@measurement_records) > $$self{m_max_records}) {
			pop @measurement_records;
		}
# not sure the following is needed to prevent leaks
#		$$self{m_measurement_records} = undef;
		$$self{m_measurement_records} = [ @measurement_records ];
		$$self{m_measurement} = $p_measurement;
		$$self{m_timestamp} = $p_timestamp;
		$main::Weather{$self->map_to_weather} = $p_measurement 
                       if (defined($p_measurement) && ($self->map_to_weather));
		$self->check_tied_state_conditions();
	}

	return $$self{m_measurement};
}

sub get_average_change_rate {
	my ($self, $max_samples) = @_;
	my $subtotal = 0;
	my $duration = 0;
        my $max = $max_samples;
        $max = 1 unless $max_samples;
        my $index = 1;
	for my $measurement_record (@{$$self{m_measurement_records}}) {
		$subtotal += $measurement_record->{measurement_change};
		$duration += $measurement_record->{time_since_previous};
                last if $index = $max;
                $index++;
	}
	if ($duration != 0) {
		return ($subtotal/$duration);
	} else {
		return undef;
	}
}

sub measurement_change {
   my ($self) = @_;
   return $$self{m_measurement_change};
}

sub weather_to_rrd {
   my ($weather_ref) = @_;
   my $rrd_ref = lc $weather_ref;
   # this is totally ridiculous that RRD names are not the same as Weather hash refs
   # somebody was definitely not thinking
   if ($weather_ref eq 'tempoutdoor') {
       $rrd_ref = 'temp';
   } elsif ($weather_ref eq 'humidoutdoor') {
       $rrd_ref = 'humid';
   } elsif ($weather_ref eq 'tempindoor') {
       $rrd_ref = 'intemp';
   } elsif ($weather_ref eq 'humidindoor') {
       $rrd_ref = 'inhumid';
   } elsif ($weather_ref eq 'dewindoor') {
       $rrd_ref = 'indew';
   } elsif ($weather_ref eq 'dewoutdoor') {
       $rrd_ref = 'dew';
   } elsif ($weather_ref eq 'barom') {
       $rrd_ref = 'pressure';
   } elsif ($weather_ref eq 'windavgdir') {
       $rrd_ref = 'avgdir';
   } elsif ($weather_ref eq 'windgustdir') {
       $rrd_ref = 'dir';
   } elsif ($weather_ref eq 'windavgspeed') {
       $rrd_ref = 'avgspeed';
   } elsif ($weather_ref eq 'windgustspeed') {
       $rrd_ref = 'speed';
   } elsif ($weather_ref eq 'tempoutdoorapparent') {
       $rrd_ref = 'apparent';
   } elsif ($weather_ref eq 'rainrate') {
       $rrd_ref = 'rate';
   } elsif ($weather_ref eq 'raintotal') {
       $rrd_ref = 'rain';
   }
   return $rrd_ref; 
}

sub map_to_weather {
	my ($self, $p_hash_ref, $p_sensor_name) = @_;
	$$self{m_weather_hash_ref} = $p_hash_ref if $p_hash_ref;
        if ($p_sensor_name) {
          my $rrd_ref = &AnalogSensor_Item::weather_to_rrd(lc $p_hash_ref);
          my $sensor_names = $main::config_parms{weather_graph_sensor_names};
           if ($sensor_names) {
              if ($sensor_names !~ /$rrd_ref/i) {
                 $sensor_names .= ", $rrd_ref => $p_sensor_name";
                 $main::config_parms{weather_graph_sensor_names} = $sensor_names;
                 print "[AnalogSensor] weather_graph_sensor_names: $sensor_names\n" if $main::Debug{onewire};
              }
           } else {
              $main::config_parms{weather_graph_sensor_names} = "$rrd_ref => $p_sensor_name";
              print "[AnalogSensor] weather_graph_sensor_names: $main::config_parms{weather_graph_sensor_names}\n"
                 if $main::Debug{onewire};
           }
        }
	return $$self{m_weather_hash_ref};
}

sub apply_offset {
	my ($self, $p_offset) = @_;
	$$self{m_offset} = $p_offset if $p_offset;
	return $$self{m_offset};
}

sub token {
   my ($self, $p_token, $p_val) = @_;
   if ($p_token) {
      $$self{tokens}{$p_token} = $p_val if defined $p_val;
      return $$self{tokens}{$p_token} if $$self{tokens};
   }
}

sub remove_token {
   my ($self, $p_token) = @_;
   if ($p_token) {
      delete $$self{tokens}{$p_token} if exists $$self{tokens}{$p_token};
   }
}

sub tie_state_condition {
   my ($self, $condition, $state_key) = @_;
   return unless defined $state_key;
   $$self{tied_state_conditions}{$condition} = $state_key;
}

sub untie_state_condition {
   my ($self, $condition) = @_;
   if ($condition) {
      delete $self->{tied_state_conditions}{$condition}; 
   }
   else {
      delete $self->{tied_state_conditions}; # Untie em all
   }
}

sub check_tied_state_conditions {
   my ($self) = @_;
   # construct the tokens
   my $token_string = "";
   for my $token (keys %{$$self{tokens}}) {
      $token_string .= 'my $token_' . $token . ' = ' . $$self{tokens}{$token} . '; ';
   }
   print "[AnalogSensor] token_string: $token_string\n" if ($token_string) && $main::Debug{onewire};
   for my $condition (keys %{$$self{tied_state_conditions}}) {
      next if (defined $self->state && $$self{tied_state_conditions}{$condition} eq $self->state); 
      # expose vars for evaluating the condition
      my $measurement = $self->measurement;
      my $measurement_change = $self->{m_measurement_change};
      my $time_since_previous = $self->{m_time_since_previous};
      my $recent_change_rate = $self->get_average_change_rate(3);
      my $state = $self->state;
      my $result = ($token_string) ? eval($token_string . ' ' . $condition) : eval($condition);
      if ($@) {
         &::print_log("Problem encountered when evaluating " . $self->{object_name}
            . " condition: $condition");
         $self->untie_state_condition($condition);
      } elsif ($result) {
         $self->SUPER::set($$self{tied_state_conditions}{$condition});
         last;
      }
   }
}

sub tie_event_condition {
   my ($self, $condition, $event) = @_;
   return unless defined $event;
   $$self{tied_event_conditions}{$condition} = $event;
}

sub untie_event_condition {
   my ($self, $condition) = @_;
   if ($condition) {
      delete $self->{tied_event_conditions}{$condition}; 
   }
   else {
      delete $self->{tied_event_conditions}; # Untie em all
   }
}

sub check_tied_event_conditions {
   my ($self) = @_;
    # construct the tokens
   my $token_string = "";
   for my $token (keys %{$$self{tokens}}) {
      $token_string .= 'my $token_' . $token . ' = ' . $$self{tokens}{$token} . '; ';
   }
   print "[AnalogSensor] token_string: $token_string\n" if ($token_string) && $main::Debug{onewire};
   for my $condition (keys %{$$self{tied_event_conditions}}) {
      next if (defined $self->state && $$self{tied_event_conditions}{$condition} eq $self->state); 
      # expose vars for evaluating the condition
      my $measurement = $self->measurement;
      my $measurement_change = $self->{m_measurement_change};
      my $time_since_previous = $self->{m_time_since_previous};
      my $recent_change_rate = $self->get_average_change_rate(3);
      my $state = $self->state;
      my $result = ($token_string) ? eval($token_string . ' ' . $condition) : eval($condition);
      if ($@) {
         &::print_log("Problem encountered when evaluating " . $self->{object_name}
            . " condition: $condition");
         $self->untie_state_condition($condition);
      } elsif ($result) {
         my $code = $$self{tied_event_conditions}{$condition};
         eval($code);
         if ($@) {
            &::print_log("Problem encountered when executing event for " . 
               $self->{object_name} . " and condition: $condition");
         } 
      }
   }
}

1;
