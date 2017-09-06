
=head1 B<raZberry> v2.1.1

=head2 SYNOPSIS

In user code:
	
    	use raZberry;
    	$razberry_controller  	= new raZberry('10.0.1.1',10);
    	$razberry_comm			= new raZberry_comm($razberry_controller);
    	$room_fan      			= new raZberry_dimmer($razberry_controller,'2','force_update');
    	$room_blind	  			= new raZberry_blind($razberry_controller,'3','digital');
    	$front_lock				= new raZberry_lock($razberry_controller,'4');
    	$thermostat				= new raZberry_thermostat($razberry_controller,'5');
    	$temp_sensor			= new raZberry_temp_sensor($razberry_controller,'5');
		$door_sensor			= new raZberry_binary_sensor($razberry_controller,'7');
		$garage_light			= new raZberry_switch($razberry_controller,'6');
		$remote_1				= new raZberry_battery($razberry_controller,12);


raZberry(<ip address>,<poll time>|'push');
raZberry_<child>(<controller>,<device id>,<options>)


In items.mht:

RAZBERRY_CONTROLLER,	ip_address, controller_name, group,	poll time/'push', options
RAZBERRY_DIMMER,		device_id,	name,		 	 group,	controller_name, options
RAZBERRY_SWITCH,		device_id,	name,		 	 group,	controller_name, options
RAZBERRY_BLIND,			device_id,	name,		 	 group,	controller_name, options
RAZBERRY_LOCK,			device_id,	name,		 	 group,	controller_name, options
RAZBERRY_THERMOSTAT,	device_id,	name,		 	 group,	controller_name, options
RAZBERRY_TEMP_SENSOR,	device_id,	name,		 	 group,	controller_name, options
RAZBERRY_BINARY_SENSOR,	device_id,	name,		 	 group,	controller_name, options

RAZBERRY_GENERIC,       device_id,  name,            group, controller_name, options
    * Note GENERIC requires the full device ID, ie 2-0-48-1
RAZBERRY_VOLTAGE,       device_id,  name,            group, controller_name, options
    * Note VOLTAGE is a multiattribute device, so device_id can only be the major number

for example:

RAZBERRY_CONTROLLER,	10.0.1.1, razberry_controller,	zwave
RAZBERRY_BLIND,			4, 	      main_blinds, 			HVAC|zwave, razberry_controller, battery

for specifying controller options;

RAZBERRY_CONTROLLER,	10.0.1.1, razberry_controller,	zwave, push ,'user=admin,password=bob'


=head2 DESCRIPTION


=head3 INCLUDING ZWAVE devices

Devices need to first included inside the razberry zwave network using the included web interface.

=head3 STATE REPORTED IN MisterHouse

The Razberry is polled on a regular basis in order to update local objects. By default, 
the razberry is polled every 5 seconds.

Update for local control use the 'niffler' plug in. This saves forcing a local device
status every poll.

=head3 CHILD OBJECTS

Each device class will need a child object, as the controller object is just a gateway
to the hardware. 

There is also a communication object to allow for alerting and monitoring of the
razberry controller.

=head2 RaZberry v2 AUTHENTICATION

Works and tested with v2.0.0. It _should_ also work with v1.7.4.
For later versions, Z_Way has introduced authentication. raZberry v2.0 supports this via two methods:

1: Enable anonymous authentication:
- Create a room named devices, and assign all ZWay devices to that room
- Create a user named anonymous with role anonymous
- Edit user anonymous and allow access to room devices

2: Create a new user and give it the admin role. Credentials can be stored in MH either in the mh.private.ini,
or on a per controller basis.

Then in the controller definition, provide the username and password:
$razberry_controller  	= new raZberry('10.0.1.1',10,"user=user,password=pwd");


=head2 v2 PUSH or POLL. Only tested in version raZberry 2.3.0
Using the HTTPGet automation module, this will 'push' a status change to MH rather than the constant polling. Use the following
URL for updating: http://mh:port/SUB;razberry_push(%DEVICE%,%VALUE%)

If the razberry or mh get out of sync, $controller->poll can be issued to get the latest states.

Only one razberry controller can be the push source, due to only a single controller object that can be linked to the web service.

=head2 MH.INI CONFIG PARAMS

raZberry_timeout
raZberry_poll_seconds
raZberry_user
raZberry_password

=head2 BUGS


=head2 OTHER
http calls can cause pauses. There are a few possible options around this;
- push output to a file and then read the file. This is generally how other modules work.


=head2 CHANGELOG
v2.1.0
- added support for secondary controllers

v2.0.2
- added generic_item support for loggers

v2.0.1
- added full poll for getting battery data

v2.0
- added in authentication method for razberry 2.1.2+ support
- supports a push method when used in conjunction with the HTTPGet automation module
- displays some controller information at startup

v1.6
- added in digital blinds, battery item (like a remote)

v1.5
- added in binary sensors

v1.4
- added in thermostat

v1.3
- added in locks
- added in ability to add and remove lock users

v1.2
- added in ability to 'ping' device
- added a check to see if the device is 'dead'. If dead it will attempt a ping for
  X attempts a Y seconds apart.


=over

=cut

use strict;
our $push_obj;

package raZberry;

use warnings;

use LWP::UserAgent;
use HTTP::Request::Common qw(POST);
use HTTP::Cookies;
use JSON qw(decode_json);

#use Data::Dumper;

@raZberry::ISA = ('Generic_Item');

# -------------------- START OF SUBROUTINES --------------------
# --------------------------------------------------------------
my %zway_system;
$zway_system{version}  = "2";
$zway_system{delim}{1} = ":";
$zway_system{delim}{2} = "-";
$zway_system{id}{1}    = "1";
$zway_system{id}{2}    = "2";

my $zway_vdev   = "ZWayVDev_zway";
my $zway_suffix = "-0-38";
our $push_obj = "";

our %rest;
$rest{api}           = "";
$rest{devices}       = "devices";
$rest{on}            = "command/on";
$rest{off}           = "command/off";
$rest{up}            = "command/up";
$rest{down}          = "command/down";
$rest{stop}          = "command/stop";
$rest{open}          = "command/open";
$rest{close}         = "command/close";
$rest{closed}        = "command/close";
$rest{level}         = "command/exact?level=";
$rest{force_update}  = "devices";
$rest{ping}          = "devices";
$rest{isfailed}      = "devices";
$rest{usercode_data} = "devices";
$rest{usercode}      = "devices";
$rest{controller}    = "Data/*";

sub new {
    my ( $class, $addr, $poll, $options ) = @_;
    my $self = new Generic_Item();
    bless $self, $class;
    &main::print_log("[raZberry]: v2.1.1 Controller Initializing...");
    $self->{data}                   = undef;
    $self->{child_object}           = undef;
    $self->{config}->{poll_seconds} = 5;
    $self->{config}->{poll_seconds} = $main::config_parms{raZberry_poll_seconds}
      if ( defined $main::config_parms{raZberry_poll_seconds} );
    $self->{push} = 0;

    if ( ( defined $poll ) and ( lc $poll eq 'push' ) ) {
        $self->{push} = 1;
        $self->{config}->{poll_seconds} = 1800;    #poll the raZberry every 30 minutes if we are using the push method
    }
    else {
        $self->{config}->{poll_seconds} = $poll if ( defined $poll );
        $self->{config}->{poll_seconds} = 1     if ( $self->{config}->{poll_seconds} < 1 );
    }
    $self->{updating} = 0;
    $self->{data}->{retry} = 0;
    my ( $host, $port ) = ( split /:/, $addr )[ 0, 1 ];
    $self->{host}  = $host;
    $self->{port}  = 8083;
    $self->{port}  = $port if ($port);
    $self->{debug} = 0;
    ( $self->{debug} ) = ( $options =~ /debug=(\d+)/i ) if ( ( defined $options ) and ( $options =~ m/debug=/i ) );
    $self->{debug}           = $main::Debug{razberry} if ( defined $main::Debug{razberry} );
    $self->{lastupdate}      = undef;
    $self->{timeout}         = 2;
    $self->{timeout}         = $main::config_parms{raZberry_timeout} if ( defined $main::config_parms{raZberry_timeout} );
    $self->{status}          = "";
    $self->{controller_data} = ();
    &main::print_log("[raZberry:" . $self->{host} . "]: options are $options") if ( ( $self->{debug} ) and ( defined $options ) );

    $self->{username} = "";
    $options =~ s/username\=/user\=/i if ( defined $options );
    $self->{username} = $main::config_parms{raZberry_user}     if ( defined $main::config_parms{raZberry_user} );
    $self->{password} = $main::config_parms{raZberry_password} if ( defined $main::config_parms{raZberry_password} );
    ( $self->{username} ) = ( $options =~ /user\=([a-zA-Z0-9]+)/i )     if ( ( defined $options ) and ( $options =~ m/user\=/i ) );
    ( $self->{password} ) = ( $options =~ /password\=([a-zA-Z0-9]+)/i ) if ( ( defined $options ) and ( $options =~ m/password\=/i ) );
    if ( ( $push_obj eq "" ) and ( $self->{push} ) ) {
        &main::print_log("[raZberry:" . $self->{host} . "]: Push method selected");
        &main::print_log("[raZberry:" . $self->{host} . "]: The HTTPGet Automation module needs to be installed for push to work");
        &main::print_log("[raZberry:" . $self->{host} . "]: URL is http://mh:port/SUB;razberry_push(%DEVICE%,%VALUE%)");
        $push_obj = \%{$self};
    }
    else {
        &main::print_log("[raZberry:" . $self->{host} . ": Push method already in use on other object") if ($push_obj);
        &main::print_log("[raZberry:" . $self->{host} . "]: Poll method selected");
    }
    if ( $self->{username} ) {
        $self->{cookie_jar} = HTTP::Cookies->new( {} );
        $self->login;
    }
    
    ${$self->{controllers}->{objects}}[0] = $self;
    $self->{controllers}->{backup} = 0;
    $self->{controllers}->{failover_time} = 0;
    $self->{controllers}->{failover_threshold} = 120;
    
    $self->get_controllerdata;
    $self->{timer} = new Timer;
    $self->poll;
    $self->start_timer;
    $self->{generate_voice_cmds} = 0;    
    &::Reload_post_add_hook( \&raZberry::generate_voice_commands, 1, $self );
    &main::print_log("[raZberry:" . $self->{host} . "]: Controller Initialization Complete");
    return $self;
}

sub login {
    my ($self) = @_;

    my $ua = new LWP::UserAgent( keep_alive => 1 );
    $ua->timeout( $self->{timeout} );
    $ua->cookie_jar( $self->{cookie_jar} );
    $ua->default_header( 'Accept'       => "application/json" );
    $ua->default_header( 'Content-Type' => "application/json" );

    my $host = $self->{host};
    my $port = $self->{port};
    &main::print_log("[raZberry:" . $self->{host} . "]: Attempting to authenticate to host");
    &main::print_log("[raZberry:" . $self->{host} . "]: with user:" . $self->{username} . " password: " . $self->{password} ) if ( $self->{debug} );

    my $request = HTTP::Request->new( POST => "http://$host:$port/ZAutomation/api/v1/login" );
    my $json = '{"form": true, "login": "' . $self->{username} . '", "password": "' . $self->{password} . '", "keepme": false, "default_ui": 1}';
    $request->content($json);
    my $responseObj = $ua->request($request);
    $self->{cookie_jar}->extract_cookies($responseObj);
    $self->{cookie_jar}->save;

    #print Dumper $self->{cookie_jar};
    #print $json . "\n";
    #print $responseObj->content . "\n--------------------\n";
    if ( $responseObj->code > 400 ) {
        $self->{login_success} = 0;
        &main::print_log("[raZberry:" . $self->{host} . "]: Error attempting to authenticate to $host");
        &main::print_log("[raZberry:" . $self->{host} . "]: Code is " . $responseObj->code . " and content is " . $responseObj->content );
    }
    else {
        &main::print_log("[raZberry:" . $self->{host} . "]: Successful authentication.");
        $self->{login_success} = 1;
    }
}

sub get_controllerdata {
    my ($self) = @_;
    my ( $isSuccessResponse1, $controller_data ) = _get_JSON_data( $self, 'controller' );
    if ($isSuccessResponse1) {

        #print Dumper $controller_data;
        $self->{controller_data} = $controller_data->{controller}->{data};
        &main::print_log("[raZberry:" . $self->{host} . "]: Controller found");
        &main::print_log("[raZberry:" . $self->{host} . "]: Chip version:\t\t" . $self->{controller_data}->{ZWaveChip}->{value} );
        &main::print_log("[raZberry:" . $self->{host} . "]: Software version:\t" . $self->{controller_data}->{softwareRevisionVersion}->{value} );
        &main::print_log("[raZberry:" . $self->{host} . "]: API version:\t\t" . $self->{controller_data}->{APIVersion}->{value} );
        &main::print_log("[raZberry:" . $self->{host} . "]: SDK version:\t\t" . $self->{controller_data}->{SDK}->{value} );
    }
    else {
        &main::print_log( "[raZberry:" . $self->{host} . "]: Problem getting controller data" );
        $self->controller_failover;
    }
}

sub add_backup_controller {
    my ($self,$object) = @_;
    
    my $secondary_address = $object->{host} . ":" . $object->{port};
    push @{$self->{controllers}->{objects}}, $object;
    $self->{controllers}->{backup}++;
    &main::print_log("[raZberry:" . $self->{host} . "]: Adding backup controller [" . $self->{controllers}->{backup} . "] $secondary_address");
    #if backup > 1 then also give the backup a backup.

}

sub change_controller {
    my ($self,$obj_index) = @_;
    
    return unless ($self->{controllers}->{backup});
    if (defined $obj_index) {
        my $host = ${$self->{controllers}->{objects}}[$obj_index]->{host};
        &main::print_log("[raZberry:" . $self->{host} . "]: Changing controller to [$obj_index] $host");
        for my $dev ( keys %{ $self->{child_object} }) {
            unless (lc $dev eq 'comm') {
               &main::print_log("[raZberry:" . $self->{host} . "]: Moving child object $dev to new controller "); 
                $self->{child_object}->{$dev}->{master_object} = ${$self->{controllers}->{objects}}[$obj_index];
                my $options = "";
                $options .= "force_update," if (defined $self->{data}->{force_update}->{$dev});
                $options .= "keep_alive" if (defined $self->{data}->{ping}->{$dev});                
                ${$self->{controllers}->{objects}}[$obj_index]->register($self->{child_object}->{$dev},$dev,$options);
                &main::print_log("[raZberry:" . $self->{host} . "]: Updating controller to state " . $self->{child_object}->{$dev}->state);
#TODO: check if the new controller needs to be updated so that states are in sync with MH
                $self->deregister($dev);
            }
        }
    }   
}

sub controller_failover {
    my ($self,$cmd) = @_;
    return unless ($self->{controllers}->{backup});
        
    #activate controller [1] if defined. in the future can add multiple backups
    &main::print_log("[raZberry:" . $self->{host} . "]: Activating backup controller");
    $self->change_controller(1);
    $self->{controllers}->{failover_time} = $main::tickcount;

    if ($cmd) {
        &main::print_log("[raZberry:" . $self->{host} . "]: Retrying command");
        ${$self->{controllers}->{objects}}[1]->_get_json_data($cmd);
    }
}

sub controller_failback {
    my ($self,$options) = @_;
    return unless ($self->{controllers}->{backup});
    return unless ($self->{controllers}->{failover_time});
    
    if (($options eq 'force') or ($main::tickcount - $self->{controllers}->{failover_time} > $self->{controllers}->{failover_threshold})) {
        #current controller is online but wait for $self->{failback_time} to expire prevent flapping
        &main::print_log("[raZberry:" . $self->{host} . "]: Activating primary controller");
        $self->change_controller(0);
        $self->{controllers}->{failover_time} = 0;
    }

}

sub poll {
    my ( $self, $option ) = @_;

    $option = "" unless ( defined $option );
    &main::print_log("[raZberry:" . $self->{host} . "]: Polling initiated") if ( $self->{debug} );
    my $cmd = "";
    $cmd = "?since=" . $self->{lastupdate} if ( defined $self->{lastupdate} );
    $cmd = "" if ( lc $option eq "full" );
    &main::print_log("[raZberry:" . $self->{host} . "]: cmd=$cmd") if ( $self->{debug} > 1 );

    for my $dev ( keys %{ $self->{data}->{force_update} } ) {
        &main::print_log("[raZberry:" . $self->{host} . "]: Forcing update to device $dev to account for local changes") if ( $self->{debug} );
        $self->update_dev($dev);
    }

    for my $dev ( keys %{ $self->{data}->{ping} } ) {
        &main::print_log("[raZberry:" . $self->{host} . "]: Keep_alive: Pinging device $dev...");    # if ($self->{debug});
        &main::print_log("[raZberry:" . $self->{host} . "]: ping_dev $dev");                         # if ($self->{debug});
                                                                               #$self->ping_dev($dev);
    }

    my ( $isSuccessResponse1, $devices ) = _get_JSON_data( $self, 'devices', $cmd );

    #    print Dumper $devices if ( $self->{debug} > 1 );
    if ($isSuccessResponse1) {
        $self->{lastupdate} = $devices->{data}->{updateTime};
        foreach my $item ( @{ $devices->{data}->{devices} } ) {
            &main::print_log("[raZberry:" . $self->{host} . "]: Found:" . $item->{id} . " with level " . $item->{metrics}->{level} . " and updated " . $item->{updateTime} . "." )
              if ( $self->{debug} );

            #my ($id) = ( split /_/, $item->{id} )[2];
            my ($id) = ( split /_/, $item->{id} )[-1];    #always just get the last element
            print "id=$id\n" if ( $self->{debug} > 1 );
            &main::print_log("[raZberry:" . $self->{host} . "]: WARNING: device $id level is undefined")
              if ( ( !defined $item->{metrics}->{level} ) or ( lc $item->{metrics}->{level} eq "undefined" ) );
            my $battery_dev = 0;
            $battery_dev = 1 if ( $id =~ m/-0-128$/ );
            my $voltage_dev = 0;
            $voltage_dev = 1 if ( $id =~ m/-0-50-\d$/ );

            if ($battery_dev) {                           #for a battery, set a different object
                $self->{data}->{devices}->{$id}->{battery_level} = $item->{metrics}->{level};
            }
            elsif ($voltage_dev) {
                &main::print_log("[raZberry:" . $self->{host} . "]: Voltage Device found");
            }
            else {
                $self->{data}->{devices}->{$id}->{level} = $item->{metrics}->{level};
            }
            $self->{data}->{devices}->{$id}->{updateTime} = $item->{updateTime};
            $self->{data}->{devices}->{$id}->{devicetype} = $item->{deviceType};
            $self->{data}->{devices}->{$id}->{location}   = $item->{location};
            $self->{data}->{devices}->{$id}->{title}      = $item->{metrics}->{title};
            $self->{data}->{devices}->{$id}->{icon}       = $item->{metrics}->{icon};

            #thermostat data items
            $self->{data}->{devices}->{$id}->{units} = $item->{metrics}->{scaleTitle}
              if ( defined $item->{metrics}->{scaleTitle} );
            $self->{data}->{devices}->{$id}->{temp_min} = $item->{metrics}->{min}
              if ( defined $item->{metrics}->{min} );
            $self->{data}->{devices}->{$id}->{temp_max} = $item->{metrics}->{max}
              if ( defined $item->{metrics}->{max} );

            $self->{status} = "online";

            if ( defined $self->{child_object}->{$id} ) {
                if ($battery_dev) {
                    &main::print_log("[raZberry:" . $self->{host} . "]: Child object detected: Battery Level:["
                          . $item->{metrics}->{level}
                          . "] Child Level:["
                          . $self->{child_object}->{$id}->battery_level()
                          . "]" )
                      if ( $self->{debug} > 1 );
                    my $data;
                    $data->{battery_level} = $item->{metrics}->{level};
                    $self->{child_object}->{$id}->update_data( $data );    #be able to push other data to objects for actions
                }
                else {
                    &main::print_log("[raZberry:" . $self->{host} . "]: Child object detected: Controller Level:["
                          . $item->{metrics}->{level}
                          . "] Child Level:["
                          . $self->{child_object}->{$id}->level()
                          . "]" )
                      if ( $self->{debug} > 1 );
                    $self->{child_object}->{$id}->set( $item->{metrics}->{level}, 'poll' )
                      if ( ( $self->{child_object}->{$id}->level() ne $item->{metrics}->{level} )
                        and !( $id =~ m/-0-128$/ ) );
                    $self->{child_object}->{$id}->update_data( $self->{data}->{devices}->{$id} );    #be able to push other data to objects for actions
                }
            }
        }
    }
    else {
        &main::print_log("[raZberry:" . $self->{host} . "]: Problem retrieving data from controller" );
        $self->{data}->{retry}++;
        return ('0');
    }
    return ('1');
}

sub set_dev {
    my ( $self, $device, $mode ) = @_;

    &main::print_log("[raZberry:" . $self->{host} . "]: set_dev Setting $device to $mode")
      if ( $self->{debug} );
    my $cmd;

    my ( $action, $lvl ) = ( split /=/, $mode )[ 0, 1 ];
    if ( defined $rest{$action} ) {
        $cmd = "/$zway_vdev" . "_" . $device . "/$rest{$action}";
        $cmd .= "$lvl" if $lvl;
        &main::print_log("[raZberry:" . $self->{host} . "]: sending command $cmd")
          if ( $self->{debug} > 1 );
        my ( $isSuccessResponse1, $status ) = _get_JSON_data( $self, 'devices', $cmd );
        unless ($isSuccessResponse1) {
            &main::print_log( "[raZberry]: Problem retrieving data from " . $self->{host} );
            return ('0');
        }

        #        print Dumper $status if ( $self->{debug} > 1 );
    }

}

sub ping_dev {
    my ( $self, $device ) = @_;

    #curl --globoff "http://mhip:8083/ZWaveAPI/Run/devices[x].SendNoOperation()"
    my ( $devid, $instance, $class ) = ( split /-/, $device )[ 0, 1, 2 ];
    &main::print_log("[raZberry:" . $self->{host} . "]: Pinging device $device ($devid)...")
      if ( $self->{debug} );
    my $cmd;
    $cmd = "%5B" . $devid . "%5D.SendNoOperation()";
    &main::print_log("ping cmd=$cmd");    # if ($self->{debug} > 1);
    my ( $isSuccessResponse0, $status ) = _get_JSON_data( $self, 'ping', $cmd );
    unless ($isSuccessResponse0) {
        &main::print_log( "[raZberry]: Error: Problem retrieving data from " . $self->{host} );
        $self->{data}->{retry}++;
        return ('0');
    }
    return ($status);
}

sub isfailed_dev {

    #"http://mhip:8083/ZWaveAPI/Run/devices[x].data.isFailed.value"
    my ( $self, $device ) = @_;
    my ( $devid, $instance, $class ) = ( split /-/, $device )[ 0, 1, 2 ];
    &main::print_log("[raZberry:" . $self->{host} . "]: Checking $device ($devid)...")
      if ( $self->{debug} );
    my $cmd;
    $cmd = "%5B" . $devid . "%5D.data.isFailed.value";
    &main::print_log("isFailed cmd=$cmd");    # if ($self->{debug} > 1);
    my ( $isSuccessResponse0, $status ) = _get_JSON_data( $self, 'isfailed', $cmd );

    unless ($isSuccessResponse0) {
        &main::print_log( "[raZberry]: Error: Problem retrieving data from " . $self->{host} );
        $self->{data}->{retry}++;
        return ('error');
    }
    return ($status);
}

sub update_dev {
    my ( $self, $device ) = @_;
    my $cmd;
    my ( $devid, $instance, $class ) = ( split /-/, $device )[ 0, 1, 2 ];
    $cmd = "%5B" . $devid . "%5D.instances%5B" . $instance . "%5D.commandClasses%5B" . $class . "%5D.Get()";
    &main::print_log("[raZberry:" . $self->{host} . "]: Getting local state from $device ($devid)...")
      if ( $self->{debug} );
    &main::print_log("cmd=$cmd") if ( $self->{debug} > 1 );
    my ( $isSuccessResponse0, $status ) = _get_JSON_data( $self, 'force_update', $cmd );
    unless ($isSuccessResponse0) {
        &main::print_log( "[raZberry]: Error: Problem retrieving data from " . $self->{host} );
        $self->{data}->{retry}++;
        return ('0');
    }
    return ($status);
}

#------------------------------------------------------------------------------------
sub _get_JSON_data {
    my ( $self, $mode, $cmd ) = @_;

    unless ( $self->{updating} ) {

        $self->{updating} = 1;
        my $ua = new LWP::UserAgent( keep_alive => 1 );
        $ua->timeout( $self->{timeout} );
        $ua->cookie_jar( $self->{cookie_jar} ) if ( $self->{username} );
        my $host   = $self->{host};
        my $port   = $self->{port};
        my $params = "";
        $params = $cmd if ($cmd);
        my $method = "ZAutomation/api/v1";
        $method = "ZWaveAPI/Run"
          if ( ( $mode eq "force_update" )
            or ( $mode eq "ping" )
            or ( $mode eq "isfailed" )
            or ( $mode eq "usercode" )
            or ( $mode eq "usercode_data" ) );
        $method = "ZWaveAPI" if ( $mode eq "controller" );
        &main::print_log("[raZberry:" . $self->{host} . "]: contacting http://$host:$port/$method/$rest{$mode}$params") if ( $self->{debug} );

        my $request = HTTP::Request->new( GET => "http://$host:$port/$method/$rest{$mode}$params" );
        $request->content_type("application/x-www-form-urlencoded");

        #if unauthenticated, then try another login attempt.
        my $connect_req = 0;
        my $responseObj;
        my $responseCode;
        do {
            $responseObj = $ua->request($request);
            print $responseObj->content . "\n--------------------\n" if ( $self->{debug} > 1 );
            $responseCode = $responseObj->code;
            print 'Response code: ' . $responseCode . "\n" if ( $self->{debug} > 1 );
            if ( ( $responseCode == 401 ) and ( !$connect_req ) ) {
                &main::print_log("[raZberry:" . $self->{host} . "]: ReAuthenticating...");
                $self->login;
                $connect_req = 1;
            }
            else {
                $connect_req = 2;
            }
        } until ( $connect_req == 2 );

        my $isSuccessResponse = $responseCode < 400;
        $self->{updating} = 0;
        if ( !$isSuccessResponse ) {
            &main::print_log("[raZberry:" . $self->{host} . "]: Warning, failed to get data. Response code $responseCode");
            if ( defined $self->{child_object}->{comm} ) {
                if ( $self->{status} eq "online" ) {
                    $self->{status} = "offline";
                    main::print_log "[raZberry]: Communication Tracking object found. Updating from "
                      . $self->{child_object}->{comm}->state()
                      . " to offline..."
                      if ( $self->{loglevel} );
                    $self->{child_object}->{comm}->set( "offline", 'poll' );
                    $self->controller_failover($cmd);
                }
            }
            return ('0');
        }
        $self->controller_failback;
        if ( defined $self->{child_object}->{comm} ) {
            if ( $self->{status} eq "offline" ) {
                $self->{status} = "online";
                main::print_log "[raZberry]: Communication Tracking object found. Updating from " . $self->{child_object}->{comm}->state() . " to online..."
                  if ( $self->{loglevel} );
                $self->{child_object}->{comm}->set( "online", 'poll' );
            }
        }
        return ('1')
          if ( ( $mode eq "force_update" )
            or ( $mode eq "ping" )
            or ( $mode eq "usercode" ) );    #these come backs as nulls which crashes JSON::XS, so just return.
        return ( $responseObj->content ) if ( $mode eq "isfailed" );

        #        my $response = JSON::XS->new->decode( $responseObj->content );
        my $response;
        eval {
            $response = decode_json( $responseObj->content );    #HP, wrap this in eval to prevent MH crashes
        };
        if ($@) {
            &main::print_log("[raZberry:" . $self->{host} . "]: WARNING: decode_json failed for returned data");
            return ( "0", "" );
        }
        return ( $isSuccessResponse, $response )

    }
    else {
        &main::print_log("[raZberry:" . $self->{host} . "]: Warning, not fetching data due to operation in progress");
        return ('0');
    }
}

sub stop_timer {
    my ($self) = @_;

    $self->{timer}->stop;
}

sub start_timer {
    my ($self) = @_;

    $self->{timer}->set( $self->{config}->{poll_seconds}, sub { &raZberry::poll($self) }, -1 );
}

sub display_all_devices {
    my ($self) = @_;
    print "--------Start of Devices--------\n";
    for my $id ( keys %{ $self->{data}->{devices} } ) {

        print "RaZberry Device $id\n";
        print "\t level:\t\t $self->{data}->{devices}->{$id}->{level}\n" if (defined $self->{data}->{devices}->{$id}->{level});
        print "\t updateTime:\t " . localtime( $self->{data}->{devices}->{$id}->{updateTime} ) . "\n";
        print "\t deviceType:\t $self->{data}->{devices}->{$id}->{devicetype}\n";
        print "\t location:\t $self->{data}->{devices}->{$id}->{location}\n" if (defined $self->{data}->{devices}->{$id}->{location});
        print "\t title:\t\t $self->{data}->{devices}->{$id}->{title}\n";
        print "\t icon:\t\t $self->{data}->{devices}->{$id}->{icon}\n\n";
    }
    print "--------End of Devices--------\n";
}

sub get_dev_status {
    my ( $self, $id ) = @_;
    if ( defined $self->{data}->{devices}->{$id} ) {

        return $self->{data}->{devices}->{$id}->{level};

    }
    else {

        &main::print_log("[raZberry:" . $self->{host} . "]: Warning, unable to get status of device $id");
        return 0;
    }

}

sub register {
    my ( $self, $object, $dev, $options ) = @_;
    if ( lc $dev eq 'comm' ) {
        &main::print_log("[raZberry:" . $self->{host} . "]: Registering Communication object to controller");
        $self->{child_object}->{'comm'} = $object;
    }
    else {
        #TODO
        my $type = $object->{type};
        $type = "Digital " . $type
          if ( ( defined $options ) and ( $options =~ m/digital/ ) );
        &main::print_log("[raZberry:" . $self->{host} . "]: Registering " . $type . " Device ID $dev to controller " );
        $self->{child_object}->{$dev} = $object;
        $self->{lastupdate} = 0;
        if ( defined $options ) {
            if ( $options =~ m/force_update/ ) {
                $self->{data}->{force_update}->{$dev} = 1;
                &main::print_log("[raZberry:" . $self->{host} . "]: Forcing Controller to contact Device $dev at each poll");
            }
            if ( $options =~ m/keep_alive/ ) {
                $self->{data}->{ping}->{$dev} = 1;
                &main::print_log("[raZberry:" . $self->{host} . "]: Forcing Controller to ping Device $dev at each poll");
            }
        }
    }
}

sub deregister {
    my ( $self, $dev) = @_;
    
    return unless (defined $self->{child_object}->{$dev});
    my $type = $self->{child_object}->{$dev}->{type};
    &main::print_log("[raZberry:" . $self->{host} . "]: Deregistering " . $type . " Device ID $dev on controller" );
    delete $self->{child_object}->{$dev};
    delete $self->{data}->{force_update}->{$dev} if (defined $self->{data}->{force_update}->{$dev});
    delete $self->{data}->{ping}->{$dev} if (defined $self->{data}->{ping}->{$dev});

}

sub main::razberry_push {
    my ( $dev, $level ) = @_;

    my ($id) = ( split /_/, $dev )[-1];    #always just get the last element

    #Filter out some non-items
    return if ( ( $dev =~ m/^InfoWidget_/ )
        or ( $dev =~ m/^BatteryPolling_/ ) );

    &main::print_log("[raZberry]: HTTP Push update received for device: $dev, id: $id and level: $level");

    #my $obj = &main::get_object_by_name($object);
    if ( $push_obj eq "" ) {
        &main::print_log("[raZberry]: ERROR, Push control not enabled on this controller.");

    }
    elsif ( $dev =~ m/^ZWayVDev_zway_/ ) {
        if ( defined $push_obj->{child_object}->{$id} ) {
            if ( $dev =~ m/\-0\-\50\-\d$/ ) {
                ( my $subdev ) = ( $dev =~ /\-0\-50\-(\d)$/ );
                &main::print_log( '[raZberry]: Calling $push_obj->{child_object}->{' . $id . '}->set_level( ' . $level . ", $subdev );" );
            }
            else {
                &main::print_log( '[raZberry]: Calling $push_obj->{child_object}->{' . $id . '}->set( ' . $level . ", 'push' );" );
                $push_obj->{child_object}->{$id}->set( $level, 'push' );
            }
        }
        else {
            &main::print_log("[raZberry]: ERROR, child object id $id not found!");
        }

    }
    else {
        &main::print_log("[raZberry]: ERROR, only ZWayVDev devices supported for push");
    }

}

sub print_command_queue {
    my ($self) = @_;
    main::print_log( "[raZberry:" . $self->{host} . "]: ------------------------------------------------------------------" );
    my $commands = scalar @{ $self->{cmd_queue} };
    my $name = "$commands commands";
    $name = "empty" if ($commands == 0);
    main::print_log( "[raZberry:" . $self->{host} . "]: Current Command Queue: $name" );
    for my $i ( 1 .. $commands ) {
        main::print_log( "[raZberry:" . $self->{host} . "]: Command $i: " . @{ $self->{cmd_queue} }[$i - 1] );
    }
    main::print_log( "[raZberry:" . $self->{host} . "]: ------------------------------------------------------------------" );
    
}

sub purge_command_queue {
    my ($self) = @_;
    my $commands = scalar @{ $self->{cmd_queue} };
    main::print_log( "[raZberry:" . $self->{host} . "]: Purging Command Queue of $commands commands" );
    @{ $self->{cmd_queue} } = ();
}

sub generate_voice_commands {
    my ($self) = @_;
    unless ($self->{generate_voice_cmds}) {

         my $object_string;
         my $object_name = $self->get_object_name;
         &main::print_log("[raZberry:" . $self->{host} . "]: Generating Voice commands for Controller $object_name");

         my $voice_cmds = $self->get_voice_cmds();
         my $i          = 1;
         foreach my $cmd ( keys %$voice_cmds ) {

             #get object name to use as part of variable in voice command
             my $object_name_v = $object_name . '_' . $i . '_v';
             $object_string .= "use vars '${object_name}_${i}_v';\n";

             #Convert object name into readable voice command words
             my $command = $object_name;
             $command =~ s/^\$//;
             $command =~ tr/_/ /;

             #Initialize the voice command with all of the possible device commands
             $object_string .= $object_name . "_" . $i . "_v  = new Voice_Cmd '$command $cmd';\n";

             #Tie the proper routine to each voice command
             $object_string .= $object_name . "_" . $i . "_v -> tie_event('" . $voice_cmds->{$cmd} . "');\n\n";    #, '$command $cmd');\n\n";

             #Add this object to the list of raZberry Voice Commands on the Web Interface
             $object_string .= ::store_object_data( $object_name_v, 'Voice_Cmd', 'raZberry', 'Controller_commands' );
             $i++;
         }

         #Evaluate the resulting object generating string
         package main;
         eval $object_string;
         print "Error in razBerry voice command string: $@\n" if $@;

         package raZberry;
    }
}

sub get_voice_cmds {
    my ($self) = @_;

    my %voice_cmds = (
        'Print devices to print log'                    => $self->get_object_name . '->display_all_devices',
        'Print Command Queue to print log'              => $self->get_object_name . '->print_command_queue',
        'Purge Command Queue'                           => $self->get_object_name . '->purge_command_queue',
        'Initiate controller failover'                  => $self->get_object_name . '->controller_failover',
        'Initiate controller failback'                  => $self->get_object_name . '->controller_failback(\"force\")'       
    );
#    if ($self->{controllers}->{backup}) {
#        $voice_cmds{'Initiate controller failover'} => $self->get_object_name . '->controller_failover';
#        $voice_cmds{'Initiate controller failback'} => $self->get_object_name . '->controller_failback(\'force\')';
#   }
        
    return \%voice_cmds;
}


package raZberry_dimmer;

@raZberry_dimmer::ISA = ('Generic_Item');

sub new {
    my ( $class, $object, $devid, $options ) = @_;

    my $self = new Generic_Item();
    bless $self, $class;
    push( @{ $$self{states} }, 'off', 'low', 'med', 'high', 'on', '10%', '20%', '30%', '40%', '50%', '60%', '70%', '80%', '90%' );

    $$self{master_object} = $object;
    $devid = $devid . $zway_suffix if ( $devid =~ m/^\d+$/ );
    $$self{devid} = $devid;
    $$self{type}  = "Dimmer";
    $object->register( $self, $devid, $options );

    #$self->set($object->get_dev_status,$devid,'poll');
    $self->{level} = "";
    $self->{debug} = $object->{debug};
    return $self;

}

sub set {
    my ( $self, $p_state, $p_setby ) = @_;

    if ( defined $p_setby and ( ( $p_setby eq 'poll' ) or ( $p_setby eq 'push' ) ) ) {
        $self->{level} = $p_state;
        my $n_state;
        if ( $p_state == 100 ) {
            $n_state = "on";
        }
        elsif ( $p_state == 0 ) {
            $n_state = "off";
        }
        elsif ( $p_state == 5 ) {
            $n_state = "low";
        }
        elsif ( $p_state == 50 ) {
            $n_state = "med";
        }
        elsif ( $p_state == 95 ) {
            $n_state = "high";
        }
        else {
            $n_state .= "$p_state%";
        }
        main::print_log( "[raZberry_dimmer] Setting value to $n_state. Level is " . $self->{level} )
          if ( $self->{debug} );

        $self->SUPER::set($n_state);
    }
    else {
        if ( ( lc $p_state eq "off" ) or ( lc $p_state eq "on" ) ) {
            $$self{master_object}->set_dev( $$self{devid}, $p_state );
        }
        elsif ( lc $p_state eq "low" ) {
            $$self{master_object}->set_dev( $$self{devid}, "level=5" );
        }
        elsif ( lc $p_state eq "med" ) {
            $$self{master_object}->set_dev( $$self{devid}, "level=55" );
        }
        elsif ( lc $p_state eq "high" ) {
            $$self{master_object}->set_dev( $$self{devid}, "level=95" );
        }
        elsif ( ( $p_state eq "100%" ) or ( $p_state =~ m/^\d{1,2}\%$/ ) ) {
            my ($n_state) = ( $p_state =~ /(\d+)%/ );
            $$self{master_object}->set_dev( $$self{devid}, "level=$n_state" );
        }
        else {
            main::print_log("[raZberry_dimmer] Error. Unknown set state $p_state");
        }
    }
}

sub level {
    my ($self) = @_;

    return ( $self->{level} );
}

sub ping {
    my ($self) = @_;

    $$self{master_object}->ping_dev( $$self{devid} );
}

sub isfailed {
    my ($self) = @_;

    $$self{master_object}->isfailed_dev( $$self{devid} );
}

sub update_data {
    my ( $self, $data ) = @_;
}

package raZberry_switch;

@raZberry_switch::ISA = ('Generic_Item');

sub new {
    my ( $class, $object, $devid, $options ) = @_;

    my $self = new Generic_Item();
    bless $self, $class;
    push( @{ $$self{states} }, 'off', 'on', );

    $$self{master_object} = $object;
    $devid = $devid . "-0-37" if ( $devid =~ m/^\d+$/ );
    $$self{devid} = $devid;
    $$self{type}  = "Switch";
    $object->register( $self, $devid, $options );

    #$self->set($object->get_dev_status,$devid,'poll');
    $self->{level} = "";
    $self->{debug} = $object->{debug};
    return $self;

}

sub set {
    my ( $self, $p_state, $p_setby ) = @_;

    if ( defined $p_setby && ( ( $p_setby eq 'poll' ) or ( $p_setby eq 'push' ) ) ) {
        if ( lc $p_state eq "on" ) {
            $self->{level} = 100;
        }
        elsif ( lc $p_state eq "off" ) {
            $self->{level} = 0;
        }

        main::print_log( "[raZberry_switch] Setting value to $p_state. Level is " . $self->{level} )
          if ( $self->{debug} );
        $self->SUPER::set($p_state);
    }
    else {
        if ( ( lc $p_state eq "off" ) or ( lc $p_state eq "on" ) ) {
            $$self{master_object}->set_dev( $$self{devid}, $p_state );
        }
        else {
            main::print_log("[raZberry_switch] Error. Unknown set state $p_state");
        }
    }
}

sub level {
    my ($self) = @_;

    return ( $self->{level} );
}

sub ping {
    my ($self) = @_;

    $$self{master_object}->ping_dev( $$self{devid} );
}

sub isfailed {
    my ($self) = @_;

    $$self{master_object}->isfailed_dev( $$self{devid} );
}

sub update_data {
    my ( $self, $data ) = @_;
}

package raZberry_blind;

#tested with somfy zrtsi and somfy zwave blinds
# To pair a somfy zwave blind:
# https://www.youtube.com/watch?v=8mTF8uF7jnE
# 1. Put the shade in pairing mode. Hold down motor button until flashes, green, then amber
#    then the shade will jog.
# 2. On the razberry start inclusion mode
# 3. On the blind, press and hold the motor button until flashing green then let go
# 4. The shade will jog, and then be included.
# -------
# Then add the zwave battery remotes as a secondary for local control.
# 1. On the razberry start inclusion mode
# 2. with a paperclip press and hold the button in the hole in the back until the remote lights flash
# 3. At the blind, use the paperclip to do a 'quick tap' in the hole in the back of the remote. The light should flash
# 4. On the blind, press and hold the motor button until flashing green then let go
# 5. The shade will jog, and the remote will control the blind.

@raZberry_blind::ISA = ('Generic_Item');

sub new {
    my ( $class, $object, $devid, $options ) = @_;

    my $self = new Generic_Item();
    bless $self, $class;

    $$self{master_object} = $object;
    my $devid_battery = $devid . "-0-128";
    $devid = $devid . $zway_suffix if ( $devid =~ m/^\d+$/ );
    $$self{devid} = $devid;
    $$self{type}  = "Blind";
    $object->register( $self, $devid, $options );

    #$self->set($object->get_dev_status,$devid,'poll');
    $self->{level}   = "";
    $self->{debug}   = $object->{debug};
    $self->{digital} = 0;
    $self->{digital} = 1
      if ( ( defined $options ) and ( $options =~ m/digital/i ) );
    if ( $self->{digital} ) {
        push( @{ $$self{states} }, 'down', '10%', '20%', '30%', '40%', '50%', '60%', '70%', '80%', '90%', 'up' );
    }
    else {
        push( @{ $$self{states} }, 'down', 'stop', 'up' );
    }
    $self->{battery} = 1
      if ( ( defined $options ) and ( $options =~ m/battery/i ) );
    if ( $self->{battery} ) {
        $$self{battery_level} = "";
        $$self{devid_battery} = $devid_battery;
        $$self{type}          = "Blind.Battery";

        $object->register( $self, $devid_battery, $options );

        $self->{battery_alert}        = 0;
        $self->{battery_poll_seconds} = 12 * 60 * 60;
        $self->{battery_timer}        = new Timer;
        $self->_battery_timer;
    }

    return $self;

}

sub set {
    my ( $self, $p_state, $p_setby ) = @_;

    if ( defined $p_setby && ( ( $p_setby eq 'poll' ) or ( $p_setby eq 'push' ) ) ) {
        $self->{level} = $p_state;
        my $n_state;
        if ( $p_state == 0 ) {
            $n_state = "down";
        }
        else {
            if ( $self->{digital} ) {
                if ( $p_state >= 99 ) {
                    $n_state = "up";
                }
                else {
                    $n_state = "$p_state%";
                }
            }
            else {
                $n_state = "up";
            }
        }

        # stop level?
        main::print_log( "[raZberry_blind] Setting value to $n_state. Level is " . $self->{level} )
          if ( $self->{debug} );
        $self->SUPER::set($n_state);
    }
    else {
        if ( $self->{digital} ) {
            if ( lc $p_state eq "down" ) {
                $$self{master_object}->set_dev( $$self{devid}, $p_state );
            }
            elsif ( lc $p_state eq "up" ) {
                $$self{master_object}->set_dev( $$self{devid}, "level=100" );
            }
            elsif ( ( $p_state eq "100%" ) or ( $p_state =~ m/^\d{1,2}\%$/ ) ) {
                my ($n_state) = ( $p_state =~ /(\d+)%/ );
                $$self{master_object}->set_dev( $$self{devid}, "level=$n_state" );
            }
            else {
                main::print_log("[raZberry_blind] Error. Unknown set state $p_state");
            }
        }
        elsif (( lc $p_state eq "up" )
            or ( lc $p_state eq "down" )
            or ( lc $p_state eq "stop" ) )
        {
            $$self{master_object}->set_dev( $$self{devid}, $p_state );
        }
        else {
            main::print_log("[raZberry_blind] Error. Unknown set state $p_state");
        }
    }
}

sub level {
    my ($self) = @_;

    return ( $self->{level} );
}

sub ping {
    my ($self) = @_;

    $$self{master_object}->ping_dev( $$self{devid} );
}

sub isfailed {
    my ($self) = @_;

    $$self{master_object}->isfailed_dev( $$self{devid} );
}

sub update_data {
    my ( $self, $data ) = @_;
    if ( defined $data->{battery_level} ) {
        &main::print_log( "[raZberry_blind] Setting battery value to " . $data->{battery_level} . "." )
          if ( $self->{debug} );
        $self->{battery_level} = $data->{battery_level};
    }
}

sub battery_check {
    my ($self) = @_;
    unless ( $self->{battery} ) {
        main::print_log("[raZberry_blind] ERROR, battery option not defined on this object");
        return;
    }

    if ( ( $self->{battery_level} eq "" ) or ( !defined $self->{battery_level} ) ) {
        $$self{master_object}->poll("full");
        if ( ( $self->{battery_level} eq "" ) or ( !defined $self->{battery_level} ) ) {
            main::print_log("[raZberry_blind] INFO Battery level currently undefined");
            return;
        }
    }
    main::print_log( "[raZberry_blind] INFO Battery currently at " . $self->{battery_level} . "%" );
    if ( ( $self->{battery_level} < 30 ) and ( $self->{battery_alert} == 0 ) ) {
        $self->{battery_alert} = 1;
        main::speak("Warning, Zwave blind battery has less than 30% charge");
    }
    else {
        $self->{battery_alert} = 0;
    }
    return $self->{battery_level};
}

sub _battery_timer {
    my ($self) = @_;

    $self->{battery_timer}->set( $self->{battery_poll_seconds}, sub { &raZberry_blind::battery_check($self) }, -1 );
}

sub battery_level {
    my ($self) = @_;
#    $$self{master_object}->poll("full") if ( ( $self->{battery_level} eq "" ) or ( !defined $self->{battery_level} ) );
    return ( $self->{battery_level} );
}

package raZberry_lock;

#only tested with Kwikset 914

@raZberry_lock::ISA = ('Generic_Item');

#use Data::Dumper;

sub new {
    my ( $class, $object, $devid, $options ) = @_;

    my $self = new Generic_Item();
    bless $self, $class;
    push( @{ $$self{states} }, 'locked', 'unlocked' );

    $$self{master_object} = $object;
    my $devid_battery = $devid . "-0-128";
    $devid = $devid . "-0-98" if ( $devid =~ m/^\d+$/ );
    $$self{devid}         = $devid;
    $$self{devid_battery} = $devid_battery;
    $$self{type}          = "Lock.Battery";
    $object->register( $self, $devid_battery, $options );
    $$self{type} = "Lock";
    $object->register( $self, $devid, $options );

    #$self->set($object->get_dev_status,$devid,'poll');
    $self->{level}                = "";
    $self->{battery_level}        = "";
    $self->{user_data_delay}      = 10;
    $self->{battery_alert}        = 0;
    $self->{battery_poll_seconds} = 12 * 60 * 60;
    $self->{battery_timer}        = new Timer;
    $self->{debug}                = $object->{debug};
    $self->_battery_timer;
    return $self;
}

sub set {
    my ( $self, $p_state, $p_setby ) = @_;

    # if level is open/closed its the state. if level is a number its the battery
    # object states are locked and unlocked, but zwave sees close and open
    my %map_states;
    $p_state = "locked"   if ( lc $p_state eq "lock" );
    $p_state = "unlocked" if ( lc $p_state eq "unlock" );
    $map_states{close}    = "locked";
    $map_states{open}     = "unlocked";
    $map_states{locked}   = "close";
    $map_states{unlocked} = "open";

    if ( defined $p_setby && ( ( $p_setby eq 'poll' ) or ( $p_setby eq 'push' ) ) ) {
        main::print_log( "[raZberry_lock] Setting value to $p_state: " . $map_states{$p_state} . ". Battery Level is " . $self->{battery_level} )
          if ( $self->{debug} );
        if ( ( $p_state eq "open" ) or ( $p_state eq "close" ) ) {
            $self->SUPER::set( $map_states{$p_state} );
        }
        elsif ( ( $p_state >= 0 ) or ( $p_state <= 100 ) ) {    #battery level
            $self->{level} = $p_state;
        }
        else {
            main::print_log("[raZberry_lock] Unknown value $p_state in poll set");
        }

    }
    else {
        if ( ( lc $p_state eq "locked" ) or ( lc $p_state eq "unlocked" ) ) {
            $$self{master_object}->set_dev( $$self{devid}, $map_states{$p_state} );
        }
        else {
            main::print_log( "[raZberry_lock] Error. Unknown set state " . $map_states{$p_state} );
        }
    }
}

sub level {
    my ($self) = @_;

    return ( $self->{level} );
}

sub battery_level {
    my ($self) = @_;
#    $$self{master_object}->poll("full") if ( ( $self->{battery_level} eq "" ) or ( !defined $self->{battery_level} ) );
    return ( $self->{battery_level} );
}

sub ping {
    my ($self) = @_;

    $$self{master_object}->ping_dev( $$self{devid} );
}

sub isfailed {
    my ($self) = @_;

    $$self{master_object}->isfailed_dev( $$self{devid} );
}

sub update_data {
    my ( $self, $data ) = @_;
    if ( defined $data->{battery_level} ) {
        &main::print_log( "[raZberry_lock] Setting battery value to " . $data->{battery_level} . "." )
          if ( $self->{debug} );
        $self->{battery_level} = $data->{battery_level};
    }
}

sub battery_check {
    my ($self) = @_;
    if ( ( $self->{battery_level} eq "" ) or ( !defined $self->{battery_level} ) ) {
        $$self{master_object}->poll("full");
        if ( ( $self->{battery_level} eq "" ) or ( !defined $self->{battery_level} ) ) {
            main::print_log("[raZberry_lock] INFO Battery level currently undefined");
            return;
        }
    }
    &main::print_log( "[raZberry_lock] INFO Battery currently at " . $self->{battery_level} . "%" );
    if ( ( $self->{battery_level} < 30 ) and ( $self->{battery_alert} == 0 ) ) {
        $self->{battery_alert} = 1;
        &main::speak("Warning, Zwave lock battery has less than 30% charge");
    }
    else {
        $self->{battery_alert} = 0;
    }
    return $self->{battery_level};
}

sub enable_user {
    my ( $self, $userid, $code ) = @_;
    my ($status) = 0;

    $status = $self->_control_user( $userid, $code, "1" );

    #delay for the lock to process the code and then read in the users
    main::eval_with_timer( sub { &raZberry_lock::_update_users($self) }, $self->{user_data_delay} );
    return ($status);
}

sub disable_user {
    my ( $self, $userid ) = @_;
    my ($status) = 0;
    my $code = "1234";
    main::print_log("[raZberry_lock] WARN user $userid is not in user table")
      unless ( defined $self->{users}->{$userid}->{status} );
    $status = $self->_control_user( $userid, $code, "0" );

    #delay for the lock to process the code and then read in the users
    main::eval_with_timer( sub { &raZberry_lock::_update_users($self) }, $self->{user_data_delay} );
    return ($status);
}

sub is_user_enabled {
    my ( $self, $userid ) = @_;
    my $return = 0;
    $return = $self->{users}->{$userid}->{status}
      if ( defined $self->{users}->{$userid}->{status} );
    return $return;
}

sub print_users {
    my ( $self, $force ) = @_;

    $self->_update_users
      unless ( ( defined $self->{users} ) or ( lc $force eq "force" ) );
    foreach my $key ( keys %{ $self->{users} } ) {
        my $status = "enabled";
        $status = "disabled" if ( $self->{users}->{$key}->{status} == 0 );
        main::print_log("[raZberry_lock] User: $key Status: $status");
    }
}

sub _battery_timer {
    my ($self) = @_;

    $self->{battery_timer}->set( $self->{battery_poll_seconds}, sub { &raZberry_lock::battery_check($self) }, -1 );
}

sub _control_user {
    my ( $self, $userid, $code, $control ) = @_;

    #curl --globoff "http://rasip:8083/ZWaveAPI/Run/devices[x].UserCode.Set(userid,code,control)"

    my $cmd;
    my ( $devid, $instance, $class ) = ( split /-/, $self->{devid} )[ 0, 1, 2 ];
    $cmd = "%5B" . $devid . "%5D.UserCode.Set(" . $userid . "," . $code . "," . $control . ")";
    &main::print_log("[raZberry]: Enabling usercodes $userid ($devid)...")
      if ( $self->{debug} );
    &main::print_log("cmd=$cmd") if ( $self->{debug} > 1 );
    my ( $isSuccessResponse0, $status ) = &raZberry::_get_JSON_data( $self->{master_object}, 'usercode', $cmd );
    unless ($isSuccessResponse0) {
        &main::print_log( "[raZberry]: Error: Problem retrieving data from " . $self->{host} );
        $self->{data}->{retry}++;
        return ('0');
    }
}

sub _update_users {
    my ( $self, $device ) = @_;

    #curl --globoff "http://192.168.0.155:8083/ZWaveAPI/Run/devices[7].UserCode.data"
    my $cmd;
    my ( $devid, $instance, $class ) = ( split /-/, $self->{devid} )[ 0, 1, 2 ];
    $cmd = "%5B" . $devid . "%5D.UserCode.Get()";
    &main::print_log("[raZberry]: Getting local usercodes ($devid)...")
      if ( $self->{debug} );
    &main::print_log("cmd=$cmd") if ( $self->{debug} > 1 );
    my ( $isSuccessResponse0, $status ) = &raZberry::_get_JSON_data( $self->{master_object}, 'usercode', $cmd );
    unless ($isSuccessResponse0) {
        &main::print_log( "[raZberry]: Error: Problem retrieving data from " . $self->{host} );
        $self->{data}->{retry}++;
        return ('0');
    }
    $cmd = "%5B" . $devid . "%5D.UserCode.data";
    &main::print_log("[raZberry]: Downloading local usercodes from $devid...")
      if ( $self->{debug} );
    &main::print_log("cmd=$cmd") if ( $self->{debug} > 1 );
    my ( $isSuccessResponse1, $response ) = &raZberry::_get_JSON_data( $self->{master_object}, 'usercode_data', $cmd );
    unless ($isSuccessResponse1) {
        &main::print_log( "[raZberry]: Error: Problem retrieving data from " . $self->{host} );
        $self->{data}->{retry}++;
        return ('0');
    }

    #    print Dumper $response if ( $self->{debug} > 1 );
    foreach my $key ( keys %{$response} ) {
        if ( $key =~ m/^[0-9]*$/ ) {    #a number, so a user code
            $self->{users}->{"$key"}->{status} = $response->{"$key"}->{status}->{value};
        }
    }

    return ('1');
}

package raZberry_comm;

@raZberry_comm::ISA = ('Generic_Item');

sub new {

    my ( $class, $object ) = @_;

    my $self = new Generic_Item();
    bless $self, $class;

    $$self{master_object} = $object;
    push( @{ $$self{states} }, 'online', 'offline' );
    $object->register( $self, 'comm' );
    return $self;

}

sub set {
    my ( $self, $p_state, $p_setby ) = @_;

    if ( defined $p_setby && ( ( $p_setby eq 'poll' ) or ( $p_setby eq 'push' ) ) ) {
        $self->SUPER::set($p_state);
    }
}

sub update_data {
    my ( $self, $data ) = @_;
}

package raZberry_thermostat;

@raZberry_thermostat::ISA = ('Generic_Item');

sub new {
    my ( $class, $object, $devid, $options, $deg ) = @_;

    my $self = new Generic_Item();
    bless $self, $class;
    if ( ( defined $deg ) and ( lc $deg eq "f" ) ) {
        push( @{ $$self{states} }, 60, 61, 62, 63, 64, 65, 66, 67, 68, 69, 70, 71, 72, 73, 74, 75, 76, 77, 78, 79, 80 );
        $self->{units}    = "F";
        $self->{min_temp} = 58;
        $self->{max_temp} = 80;

    }
    else {
        push( @{ $$self{states} }, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 16, 27, 28, 29, 30 );
        $self->{units}    = "C";
        $self->{min_temp} = 10;
        $self->{max_temp} = 30;
    }

    $$self{master_object} = $object;
    $devid = $devid . "-0-67" if ( $devid =~ m/^\d+$/ );
    $$self{devid} = $devid;
    $$self{type}  = "Thermostat";

    $object->register( $self, $devid, $options );

    $self->{level} = "";

    $self->{debug} = $object->{debug};
    return $self;

}

sub set {
    my ( $self, $p_state, $p_setby ) = @_;
    if ( defined $p_setby && ( ( $p_setby eq 'poll' ) or ( $p_setby eq 'push' ) ) ) {
        $self->{level} = $p_state;
        $self->SUPER::set($p_state);
    }
    else {
        if (   ( $p_state < $self->{min_temp} )
            or ( $p_state > $self->{max_temp} ) )
        {
            main::print_log( "[raZberry]: WARNING not setting level to $p_state since out of bounds " . $self->{min_temp} . ":" . $self->{max_temp} );
        }
        else {
            $$self{master_object}->set_dev( $$self{devid}, "level=$p_state" );
        }
    }
}

sub level {
    my ($self) = @_;

    return ( $self->{level} );
}

sub ping {
    my ($self) = @_;

    $$self{master_object}->ping_dev( $$self{devid} );
}

sub get_units {
    my ($self) = @_;

    return ( $self->{units} );
}

sub isfailed {
    my ($self) = @_;

    $$self{master_object}->isfailed_dev( $$self{devid} );
}

sub update_data {
    my ( $self, $data ) = @_;

    #if units is F then rescale states

    if ( $data->{units} =~ m/F/ ) {
        @{ $$self{states} } = ( 58, 59, 60, 61, 62, 63, 64, 65, 66, 67, 68, 69, 70, 71, 72, 73, 74, 75, 76, 77, 78, 79, 80 );
    }
    $self->{min_temp} = $data->{temp_min};
    $self->{max_temp} = $data->{temp_max};
    main::print_log( "In set, units = " . $data->{units} . " max = " . $data->{temp_max} . " min = " . $data->{temp_min} )
      if ( $self->{debug} );

}

package raZberry_temp_sensor;

@raZberry_temp_sensor::ISA = ('Generic_Item');

sub new {
    my ( $class, $object, $devid, $options ) = @_;

    my $self = new Generic_Item();
    bless $self, $class;

    $$self{master_object} = $object;
    $devid = $devid . "-0-49-1" if ( $devid =~ m/^\d+$/ );
    $$self{devid} = $devid;
    $$self{type}  = "Thermostat Sensor";

    $object->register( $self, $devid, $options );

    $self->{debug} = $object->{debug};
    return $self;

}

sub set {
    my ( $self, $p_state, $p_setby ) = @_;
    if ( defined $p_setby && ( ( $p_setby eq 'poll' ) or ( $p_setby eq 'push' ) ) ) {
        $self->{level} = $p_state;

        $self->SUPER::set($p_state);
    }
}

sub level {
    my ($self) = @_;

    return ( $self->{level} );
}

sub ping {
    my ($self) = @_;

    $$self{master_object}->ping_dev( $$self{devid} );
}

sub isfailed {
    my ($self) = @_;

    $$self{master_object}->isfailed_dev( $$self{devid} );
}

sub update_data {
    my ( $self, $data ) = @_;
}

package raZberry_binary_sensor;
@raZberry_binary_sensor::ISA = ('Generic_Item');

sub new {
    my ( $class, $object, $devid, $options ) = @_;

    my $self = new Generic_Item();
    bless $self, $class;

    #push( @{ $$self{states} }, 'on', 'off'); I'm not sure we should set the states here, since it's not a controlable item?

    $$self{master_object} = $object;
    $devid = $devid . "-0-48-1" if ( $devid =~ m/^\d+$/ );
    $$self{type}  = "Binary Sensor";
    $$self{devid} = $devid;
    $object->register( $self, $devid, $options );

    #$self->set($object->get_dev_status,$devid,'poll');
    $self->{level} = "";
    $self->{debug} = $object->{debug};
    return $self;

}

sub level {
    my ($self) = @_;

    return ( $self->{level} );
}

sub ping {
    my ($self) = @_;

    $$self{master_object}->ping_dev( $$self{devid} );
}

sub isfailed {
    my ($self) = @_;

    $$self{master_object}->isfailed_dev( $$self{devid} );
}

sub update_data {
    my ( $self, $data ) = @_;
}

package raZberry_openclose;
@raZberry_openclose::ISA = ('raZberry_binary_sensor');

sub new {
    my ( $class, $object, $devid, $options ) = @_;

    my $self = $class->SUPER::new( $object, $devid, $options );

    #$$self{states} =  ();
    #push( @{ $$self{states} }, 'open', 'closed');
    return $self;
}

sub set {
    my ( $self, $p_state, $p_setby ) = @_;

    if ( defined $p_setby && ( ( $p_setby eq 'poll' ) or ( $p_setby eq 'push' ) ) ) {
        $self->{level} = $p_state;
        my $n_state;
        if ( $p_state eq "on" ) {
            $n_state = "open";
        }
        else {
            $n_state = "closed";
        }
        main::print_log( "[raZberry]: Setting openclose value to $n_state. Level is " . $self->{level} )
          if ( $self->{debug} );
        $self->SUPER::set($n_state);
    }
    else {
        main::print_log("[raZberry]: ERROR Can not set state $p_state for openclose");
    }
}

package raZberry_battery;

@raZberry_battery::ISA = ('Generic_Item');

sub new {
    my ( $class, $object, $devid, $options ) = @_;

    my $self = new Generic_Item();
    bless $self, $class;
    push( @{ $$self{states} }, 'locked', 'unlocked' );

    $$self{master_object} = $object;
    $devid = $devid . "-0-128" if ( $devid =~ m/^\d+$/ );
    $$self{devid} = $devid;
    $$self{type}  = "Battery";

    $object->register( $self, $devid, $options );

    #$self->set($object->get_dev_status,$devid,'poll');
    $self->{battery_level}        = "";
    $self->{battery_alert}        = 0;
    $self->{battery_poll_seconds} = 12 * 60 * 60;
    $self->{battery_timer}        = new Timer;
    $self->{debug}                = $object->{debug};

    #    $self->_battery_timer;
    return $self;
}

sub battery_level {
    my ($self) = @_;
#    $$self{master_object}->poll("full") if ( ( $self->{battery_level} eq "" ) or ( !defined $self->{battery_level} ) );
    return ( $self->{battery_level} );
}

sub ping {
    my ($self) = @_;

    $$self{master_object}->ping_dev( $$self{devid} );
}

sub isfailed {
    my ($self) = @_;

    $$self{master_object}->isfailed_dev( $$self{devid} );
}

sub update_data {
    my ( $self, $data ) = @_;
    $self->{battery_level} = $data->{battery_level};
    $self->SUPER::set( $self->{battery_level} );

}

sub battery_check {
    my ($self) = @_;
    if ( ( $self->{battery_level} eq "" ) or ( !defined $self->{battery_level} ) ) {
        $$self{master_object}->poll("full");
        if ( ( $self->{battery_level} eq "" ) or ( !defined $self->{battery_level} ) ) {
            main::print_log("[raZberry_battery] INFO Battery level currently undefined");
            return;
        }
    }
    main::print_log( "[raZberry_battery] INFO Battery currently at " . $self->{battery_level} . "%" );
    if ( ( $self->{battery_level} < 30 ) and ( $self->{battery_alert} == 0 ) ) {
        $self->{battery_alert} = 1;
        main::speak("Warning, Zwave battery has less than 30% charge");
    }
    else {
        $self->{battery_alert} = 0;
    }
    return $self->{battery_level};
}

package raZberry_voltage;
@raZberry_voltage::ISA = ('Generic_Item');

sub new {
    my ( $class, $object, $devid, $options ) = @_;

    my $self = new Generic_Item();
    bless $self, $class;

    #ZWayVDev_zway_x-0-50-0 - Power Meter kWh
    #ZWayVDev_zway_x-0-50-1 - RGB setting of the switch LED
    #ZWayVDev_zway_x-0-50-2 - Power Sensor W
    #ZWayVDev_zway_x-0-50-4 - Voltage Sensor V
    #ZWayVDev_zway_x-0-50-5 - Current Sensor A
    #push( @{ $$self{states} }, 'on', 'off'); I'm not sure we should set the states here, since it's not a controlable item?

    unless ( $devid =~ m/^\d+$/ ) {
        $$self{master_object} = $object;
        $$self{type}          = "Multilevel Voltage";
        $$self{devid}         = $devid;
        $object->register( $self, $devid . "-0-50-0", $options );
        $object->register( $self, $devid . "-0-50-1", $options );
        $object->register( $self, $devid . "-0-50-2", $options );
        $object->register( $self, $devid . "-0-50-4", $options );
        $object->register( $self, $devid . "-0-50-5", $options );

        #$self->set($object->get_dev_status,$devid,'poll');
        $self->{level}->{0} = "";
        $self->{debug} = $object->{debug};
    }
    else {
        main::print_log("[raZberry_voltage] ERROR, Voltage can only be a major dev id");

    }
    return $self;

}

sub level {
    my ( $self, $attr ) = @_;

    $attr = 0 unless ($attr);
    if ( defined $self->{level}->{$attr} ) {
        return ( $self->{level} );
    }
    else {
        main::print_log("[raZberry_voltage] ERROR, unknown attribute $attr");
        return (0);
    }
}

sub set_level {
    my ( $self, $value, $attr ) = @_;

    $attr = 0 unless ($attr);
    $self->{level}->{$attr} = $value;

}

sub ping {
    my ($self) = @_;

    $$self{master_object}->ping_dev( $$self{devid} );
}

sub isfailed {
    my ($self) = @_;

    $$self{master_object}->isfailed_dev( $$self{devid} );
}

sub update_data {
    my ( $self, $data ) = @_;
}

package raZberry_generic;
@raZberry_generic::ISA = ('Generic_Item');

sub new {
    my ( $class, $object, $devid, $options ) = @_;

    my $self = new Generic_Item();
    bless $self, $class;

    $$self{master_object} = $object;
    $$self{type}          = "Generic";
    $$self{devid}         = $devid;
    $object->register( $self, $devid, $options );

    #$self->set($object->get_dev_status,$devid,'poll');
    $self->{level} = "";
    $self->{debug} = $object->{debug};
    return $self;

}

sub level {
    my ($self) = @_;

    return ( $self->{level} );
}

sub ping {
    my ($self) = @_;

    $$self{master_object}->ping_dev( $$self{devid} );
}

sub isfailed {
    my ($self) = @_;

    $$self{master_object}->isfailed_dev( $$self{devid} );
}

sub update_data {
    my ( $self, $data ) = @_;
}
