package Nest_Interface;

use strict;
use JSON;
use IO::Socket::SSL;
use IO::Socket::INET;
use IO::Select;
use URI::URL;
use HTTP::Response;
use HTTP::Request;

@Nest::ISA = ('Socket_Item');

sub new {
    my ($class, $port_name, $url) = @_;
    my $self = {};
    $port_name = 'Nest' if !$port_name;
    $$self{port_name} = $port_name;
    $$self{url} = $url;
    $$self{children} = [];
  	bless $self, $class;
  	$self->connect_stream($$self{url});
  	return $self;
}

sub connect_stream {
    my ($self, $url) = @_;
    $url = new URI::URL $url;
    
    if (defined $$self{socket}) {
        $$self{socket}->close;
    }
    
    $$self{socket} = IO::Socket::INET->new(
        PeerHost => $url->host, PeerPort => $url->port, Blocking => 0
    ) or die $@; # first create simple N-B socket with IO::Socket::INET
    
  	my $select = IO::Select->new($$self{socket}); # wait until it connected
    if ($select->can_write) {
        ::print_log "[Nest Interface] IO::Socket::INET connected";
    }
    
    # upgrade socket to IO::Socket::SSL
    IO::Socket::SSL->start_SSL($$self{socket}, SSL_startHandshake => 0);
    
    # make non-blocking SSL handshake
    while (1) {
        if ($$self{socket}->connect_SSL) { # will not block
            ::print_log "[Nest Interface] IO::Socket::SSL connected";
            last;
        }
        else { # handshake still incomplete
            #::print_log "[Nest Interface] IO::Socket::SSL not connected yet";
            if ($SSL_ERROR == SSL_WANT_READ) {
                $select->can_read;
            }
            elsif ($SSL_ERROR == SSL_WANT_WRITE) {
                $select->can_write;
            }
            else {
                die "[Nest Interface] IO::Socket::SSL unknown error: ", $SSL_ERROR;
            }
        }
    }
    
    # Request specific location
    my $request = HTTP::Request->new(
        'GET', 
        $url->full_path, 
        ["Accept", "text/event-stream", "Host", $url->host]
    );
    $request->protocol('HTTP/1.1');
    #print "requesting data:\n" . $request->as_string;
    $$self{socket}->syswrite($request->as_string) or die $!;
    
    # The first frame seems to always be the HTTP response without content
    if ($select->can_read && $$self{socket}->sysread(my $buf, 1024)) {
        my $r = HTTP::Response->parse( $buf );
        if ($r->code == 307){
            # This is a location redirect
            $$self{socket}->close;
            print "redirecting to " . $r->header( 'location' ) . "\n";
            $$self{socket} = $self->connect_stream($r->header( 'location' ));
        }
        elsif ($r->code == 401){
            die ("Error, your authorization was rejected.  Please check your settings.");
        }
        elsif ($r->code == 200){
            # Successful response
            print "Success: \n" .  $r->as_string . "\n";
            $$self{'keep-alive'} = time;
        }
        else {
            die (
                "Error unable to connect to stream response was: \n".
                $r->as_string
            );
        }
    }

    return $$self{socket};
}

sub check_for_data {
	my ($self) = @_;
    if ($$self{socket}->connected && (time - $$self{'keep-alive'} < 70)) {
    	# sysread will only read the contents of a single SSL frame
    	if ($$self{socket}->sysread(my $buf, 1024)){
    	    $$self{data} .= $buf;
    	    if ($buf =~ /\n\n$/){
    	        # We reached the end of the message packet
    	        ::print_log("[Nest Data]" . $$self{data});
    	        
    	        # Split out event and data for processing
    	        my @lines = split("\n", $$self{data});
    	        my ($event, $data);
    	        for (@lines){
    	            # Pull out events and data
    	            my ($key, $value) = split(":", $_,2);
    	            if ($key =~ /event/){
    	                $event = $value;
    	            }
    	            elsif ($key =~ /data/ && defined($event)){
    	                $data = $value;
    	            }
    	            
    	            if (defined($event) && defined($data)){
    	                $self->parse_data($event, $data);
    	                $event = '';
    	                $data = '';
    	            }
    	        }
    	        
    	        # Clear data storage
    	        $$self{data} = "";
    	    }
    	}
    }
    else {
        # The connection died, or the keep-alive messages stopped, restart it
        ::print_log("[Nest Interface] Connection died, restarting");
        $self->connect_stream($$self{url});
    }
}

sub parse_data {
    my ($self, $event, $data) = @_;
    if ($event =~ /keep-alive/){
        $$self{'keep-alive'} = time;
        ::print_log("[Nest Keep Alive]");
    }
    elsif ($event =~ /put/){
        $$self{'keep-alive'} = time;
        #This is the first JSON packet received after connecting
        $$self{prev_JSON} = $$self{JSON};
        $$self{JSON} = decode_json $data;
        if (!defined $$self{prev_JSON}){
            #this is the first run so convert the names to ids
            $self->convert_to_ids($$self{monitor});
        }
        $self->compare_json($$self{JSON}, $$self{prev_JSON}, $$self{monitor});
    }
    elsif ($event =~ /auth_revoked/){
        # Sent when auth parameter is no longer valid
        # Accoring to Nest, the auth token is essentially non-expiring,
        # so this shouldn't happen.
        die ("[Nest] The Nest authorization token has expired");
    }
    return;
}

sub print_devices {
    my ($self) = @_;
    my $output = "[Nest] The list of devices reported by Nest is:\n";
    for (keys %{$$self{JSON}{data}{devices}}){
        my $device_type = $_;
        $output .= "        $device_type =\n";
        for (keys %{$$self{JSON}{data}{devices}{$device_type}}){
            my $device_id = $_;
            my $device_name = $$self{JSON}{data}{devices}{$device_type}
                {$device_id}{name};
            $output .= "            Name: $device_name ID: $device_id\n";
        }
    }
    ::print_log($output);
}

sub print_structures {
    my ($self) = @_;
    my $output = "[Nest] The list of structures reported by Nest is:\n";
    for (keys %{$$self{JSON}{data}{structures}}){
        my $structure_id = $_;
        my $structure_name = $$self{JSON}{data}{structures}{$structure_id}{name};
        $output .= "        Name: $structure_name ID: $structure_id\n";
    }
    ::print_log($output);
}

# Used to register actions to take when a specific JSON value changes
# the variables $value and $state will be expanded on eval and will
# contain the name of the value that has changed and its new state

sub register {
    my ($self, $parent, $object, $value, $action) = @_;
    push (@{$$self{register}}, [$parent, $object, $value,$action]);
}

# Walk through the JSON hash and looks for changes from previous json hash if a 
# change is found, looks for children to notify and notifies them.

sub compare_json {
    my ($self, $json, $prev_json, $monitor_hash) = @_;
    while (my ($key, $value) = each %{$json}) {
        # Use empty hash reference is it doesn't exist      
        my $prev_value = {};
        $prev_value = $$prev_json{$key} if exists $$prev_json{$key};
        my $monitior_value = {};
        $monitior_value = $$monitor_hash{$key} if exists $$monitor_hash{$key};
        if ('HASH' eq ref $value) {
            $self->compare_json($value, $prev_value, $monitior_value);
        }
        elsif ($value ne $prev_value && ref $monitior_value eq 'ARRAY') {
            for my $action (@{$monitior_value}){
                ::print_log("[Nest] eval'ing $action");
                package main;
                eval($action);
			    ::print_log("[Nest] error in evaling action: " . $@)
					if $@;
				package Nest_Interface;
            }
        }
    }    
}

##Converts the names in the register hash to IDs, and then puts them into
# the monitor hash.

sub convert_to_ids {
    my ($self) = @_;
    for my $array_ref (@{$$self{register}}){
        my ($parent, $object, $value, $action) = @{$array_ref};
        my $device_id = $parent->device_id();
        if ($action eq ''){
            $action = $object->get_object_name . '->data_changed($key,$value)';
        }
        if ($$parent{type} ne '') {
            push(@{$$self{monitor}{data}{$$parent{class}}{$$parent{type}}{$device_id}{$value}},$action);
        }
        else {
            push(@{$$self{monitor}{data}{$$parent{class}}{$device_id}{$value}},$action);  
        }
    }
    delete $$self{register};
}

package Nest_Child;

use strict;

@Nest_Child::ISA = ('Generic_Item');

sub new {
    my ($class, $interface, $parent, $monitor_hash) = @_;
	my $self = new Generic_Item();
	bless $self, $class;
    $$self{interface} = $interface;
    $$self{parent} = $parent;
    $$self{parent} = $self if ($$self{parent} eq '');
    while (my ($monitor_value, $action) = each %{$monitor_hash}){
	    $$self{interface}->register($$self{parent}, $self, $monitor_value, $action);
	}
  	return $self;
}

sub device_id {
    my ($self) = @_;
    my $type_hash;
    my $parent = $$self{parent};
    if ($$self{type} ne '') {
        $type_hash = $$self{interface}{JSON}{data}{$$self{class}}{$$self{type}};
    }
    else {
        $type_hash = $$self{interface}{JSON}{data}{$$self{class}};
    }
    for (keys %{$type_hash}){
        my $device_id = $_;
        my $device_name = $$type_hash{$device_id}{name};
        if ($$parent{name} eq $device_id || ($$parent{name} eq $device_name)) {
            return $device_id;
        }
    }
    ::print_log("[Nest] ERROR, no device by the name " . $$parent{name} . " was found.");
    return 0;
}

# Called by data_updated if data has changed.  In most cases we can ignore the
# value name and just set the state of the child to new_value more sophisticated
# children can hijack this method to do more complex tasks

sub data_changed {
    my ($self, $value_name, $new_value) = @_;
    ::print_log("[Nest] Data changed called $value_name, $new_value");
    $self->set_receive($new_value);
}

sub set_receive {
	my ($self, $p_state, $p_setby, $p_response) = @_;
	$self->SUPER::set($p_state, $p_setby, $p_response);
}

sub get_value {
    my ($self, $value) = @_;
    my $device_id = $self->device_id;
    if ($$self{type} ne '') {
        return $$self{interface}{JSON}{data}{$$self{class}}{$$self{type}}{$device_id}{$value};
    }
    else {
        return $$self{interface}{JSON}{data}{$$self{class}}{$device_id}{$value};
    }
}

package Nest_Thermostat;

use strict;

@Nest_Thermostat::ISA = ('Nest_Child');

sub new {
    my ($class, $name, $interface, $scale) = @_;
    $scale = lc($scale);
    $scale = "f" unless ($scale eq "c");
    my $monitor_value = "ambient_temperature_" . $scale;
    my $self = new Nest_Child($interface, '', {$monitor_value=>''});
    bless $self, $class;
    $$self{class} = 'devices', 
    $$self{type} = 'thermostats',
    $$self{name} = $name,
    $$self{scale} = $scale;
  	return $self;
}

sub get_temp {
    my ($self) = @_;
    return $self->get_value("ambient_temperature_" . $$self{scale});
}

# Used in the combined Heat - Cool Mode Only

sub get_heat_sp {
    my ($self) = @_;
    return $self->get_value("target_temperature_high_" . $$self{scale});
}

# Used in the combined Heat - Cool Mode Only

sub get_cool_sp {
    my ($self) = @_;
    return $self->get_value("target_temperature_low_" . $$self{scale});
}

# Used in either the Heating or Cooling mode

sub get_target_sp {
    my ($self) = @_;
    return $self->get_value("target_temperature_" . $$self{scale});
}

sub get_mode {
    my ($self) = @_;
    return $self->get_value("hvac_mode");
}

#sub get_fan_mode, can we just look at fan_timeout and see if expired?

#Oddity, the humidity is listed on the Nest website, but there is no
#api access listed or reported for it yet

# Similarly, the api doesn't tell us if the device is heating or cooling atm

package Nest_Thermo_Fan;

#FAN [on,off how long?] (on, off)

use strict;

@Nest_Thermo_Fan::ISA = ('Nest_Child');

sub new {
    my ($class, $parent) = @_;
    my $self = new Nest_Child(
        $$parent{interface}, 
        $parent,
        {'fan_timer_active'=>''}
    );
  	bless $self, $class;
  	return $self;
}

sub set_receive {
	my ($self, $p_state, $p_setby, $p_response) = @_;
	my $state = "on";
	$state = "off" if ($p_state eq 'false');
	$self->SUPER::set($state, $p_setby, $p_response);
}

package Nest_Thermo_Leaf;

#Leaf [on,off]

use strict;

@Nest_Thermo_Leaf::ISA = ('Nest_Child');

sub new {
    my ($class, $parent) = @_;
    my $self = new Nest_Child(
        $$parent{interface}, 
        $parent,
        {'has_leaf'=>''}
    );
  	bless $self, $class;
  	return $self;
}

sub set_receive {
	my ($self, $p_state, $p_setby, $p_response) = @_;
	my $state = "on";
	$state = "off" if ($p_state eq 'false');
	$self->SUPER::set($state, $p_setby, $p_response);
}

package Nest_Thermo_Mode;

#Mode [current] (heat, cool, off, heat/cool)

use strict;

@Nest_Thermo_Mode::ISA = ('Nest_Child');

sub new {
    my ($class, $parent) = @_;
    my $self = new Nest_Child(
        $$parent{interface}, 
        $parent,
        {'hvac_mode'=>''}
    );
  	bless $self, $class;
  	return $self;
}

#Target temp [temp] (warmer, cooler)

package Nest_Thermo_Target;
use strict;
@Nest_Thermo_Target::ISA = ('Nest_Child');

sub new {
    my ($class, $parent) = @_;
    my $scale = $$parent{scale};
    my $self = new Nest_Child(
        $$parent{interface}, 
        $parent,
        {'target_temperature_' . $scale => ''}
    );
  	bless $self, $class;
  	return $self;
}

#Target high for heat-cool [temp] (warmer, cooler)
package Nest_Thermo_Target_High;
use strict;
@Nest_Thermo_Target_High::ISA = ('Nest_Child');

sub new {
    my ($class, $parent) = @_;
    my $scale = $$parent{scale};
    my $self = new Nest_Child(
        $$parent{interface}, 
        $parent,
        {'target_temperature_high_' . $scale => ''}
    );
  	bless $self, $class;
  	return $self;
}

#Target low for heat-cool [temp] (warmer, cooler)
package Nest_Thermo_Target_Low;
use strict;
@Nest_Thermo_Target_Low::ISA = ('Nest_Child');

sub new {
    my ($class, $parent) = @_;
    my $scale = $$parent{scale};
    my $self = new Nest_Child(
        $$parent{interface}, 
        $parent,
        {'target_temperature_low_' . $scale => ''}
    );
  	bless $self, $class;
  	return $self;
}

#Target high for heat-cool [temp] (warmer, cooler)
package Nest_Thermo_Away_High;
use strict;
@Nest_Thermo_Away_High::ISA = ('Nest_Child');

sub new {
    my ($class, $parent) = @_;
    my $scale = $$parent{scale};
    my $self = new Nest_Child(
        $$parent{interface}, 
        $parent,
        {'away_temperature_high_' . $scale => ''}
    );
  	bless $self, $class;
  	return $self;
}

#Target low for heat-cool [temp] (warmer, cooler)
package Nest_Thermo_Away_Low;
use strict;
@Nest_Thermo_Away_Low::ISA = ('Nest_Child');

sub new {
    my ($class, $parent) = @_;
    my $scale = $$parent{scale};
    my $self = new Nest_Child(
        $$parent{interface}, 
        $parent,
        {'away_temperature_low_' . $scale => ''}
    );
  	bless $self, $class;
  	return $self;
}

package Nest_Smoke_CO_Alarm;

use strict;

@Nest_Smoke_CO_Alarm::ISA = ('Nest_Child');

sub new {
    my ($class, $name, $interface) = @_;
    my $self = new Nest_Child($interface, '', {
                            'co_alarm_state'=>'',
                            'smoke_alarm_state'=>'',
                            'battery_health'=>''
                        });
    bless $self, $class;
    $$self{class} = 'devices', 
    $$self{type} = 'smoke_co_alarms',
    $$self{name} = $name,
  	return $self;
}

sub data_changed {
    my ($self, $value_name, $new_value) = @_;
    ::print_log("[Nest_Smoke_CO_Alarm] Data changed called $value_name, $new_value");
    $$self{$value_name} = $new_value;
    my $state = '';
    if ($$self{co_alarm_state} eq 'emergency'){
        $state .= 'Emergency - CO Detected - move to fresh air';
    }
    if ($$self{smoke_alarm_state} eq 'emergency'){
        $state .= " / " if $state ne '';
        $state .= 'Emergency - Smoke Detected - move to fresh air';
    }
    if ($$self{co_alarm_state} eq 'warning'){
        $state .= " / " if $state ne '';
        $state .= 'Warning - CO Detected';
    }
    if ($$self{smoke_alarm_state} eq 'warning'){
        $state .= " / " if $state ne '';
        $state .= 'Warning - Smoke Detected';
    }
    if ($$self{battery_health} eq 'replace'){
        $state .= " / " if $state ne '';
        $state .= 'Battery Low - replace soon';
    }
    $state = 'ok' if ($state eq '');
    $self->set_receive($state);
}

sub get_co {
    my ($self) = @_;
    return $self->get_value("co_alarm_state");
}

sub get_smoke {
    my ($self) = @_;
    return $self->get_value("smoke_alarm_state");
}

sub get_battery {
    my ($self) = @_;
    return $self->get_value("battery_health");
}

##Home/Away is in the structure

package Nest_Structure;

use strict;

@Nest_Structure::ISA = ('Nest_Child');

sub new {
    my ($class, $name, $interface) = @_;
    my $self = new Nest_Child($interface, '', {'away'=>''});
    bless $self, $class;
    $$self{class} = 'structures', 
    $$self{type} = '',
    $$self{name} = $name,
  	return $self;
}

sub get_away_status {
    my ($self) = @_;
    return $self->get_value("away");
}