
=head1 B<AoGSmartHome_Items>

=head2 DESCRIPTION

This module provides support for the Actions on Google Smart Home
provider.

=head2 CONFIGURATION

The AoGSmartHome_Items object holds the configured Misterhouse
objects that are presented to the Actions on Google Smart Home
provider.

=head2 mh.private.ini Configuration

# All options

 aog_enable = 1                 # Enable the module
 aog_auth_path = /oauth         # OAuth URI
 aog_fulfillment_url = /aog     # Fulfillment URI
 aog_client_id = <client ID>    # OAuth client ID
 aog_oauth_token_file = xxxxxx  # OAuth token file
 aog_project_id = xxxxxxx       # Google project ID
 aog_uuid_start = x		# UUID start
 aog_agentuserid = xxxxx        # Agent User ID (optional but recommended)

=head2 Defining the Primary Object

The object can be defined in the user code or in a .mht file.

In mht:

AOGSMARTHOME_ITEMS, <object name>

ie:

 AOGSMARTHOME_ITEMS, AoGSmartHomeItems

Or in user code:

<object name> = new AoGSmartHome_Items();

ie:

 $AoGSmartHomeItems = new AoGSmartHome_Items();

=head2 NOTES

The most important part of the configuration is mapping the objects/code
you want to present to the Actions on Google Smart Home Provider. This
allows the user to map pretty much anything in MisterHouse to the
Actions on Google Smart Home Provider.

 AOGSMARTHOME_ITEM, <actual object name>, <friendly name>, <sub used to
 change the object state>, <State mapped to AoG Smart Home ON command>,
 <State mapped to AoG Smart Home OFF command>, <sub used to get the
 object state>

<actual object name> - This is the only required parameter. If you are
good with the defaults, you can add an object like:

# In MHT

 AOGSMARTHOME_ITEM, AoGSmartHomeItems, light1 

# or in user code

 $AoGSmartHomeItems->add('$light1');         

<name you want Echo/GH to see> - This defaults to using the <actual
object name> without the $. If want to change the name you say to the
Echo/GH to control the object, you can define it here. You can also make
aliases for objects so it's easier to remember.

<sub used to change the object state> - This defaults to 'set' which
works for most objects. You can also put a code reference or
'run_voice_cmd'.

<State mapped to Echo/GH on command> - If you want to set an object to
something other than 'on' when you say 'on' to the Echo/GH, you can define
it here. Defaults to 'on'.

<State mapped to Echo/GH OFF command> - If you want to set an object to
something other than 'off' when you say 'off' to the Echo/GH, you can
define it here. Defaults to 'off'.

<sub used to get the object state> - If your object uses a custom sub to
get the state, define it here. Defaults to 'state' which works for most
objects.


The dim % is the actual number you say to Alexa, so if you say "Alexa,Set
Light 1 to 75 %" then the dim % value will be 75.

The module supports 300 devices which is the max supported by the Echo 

=head2 Complete Examples

MHT examples:
 
 AOGSMARTHOME_ITEMS, AoGSmartHomeItems
 AOGSMARTHOME_ITEM, AoGSmartHomeItems, light1 light1, set, on, off, state  # these are the defaults
 AOGSMARTHOME_ITEM, AoGSmartHomeItems, light1   # same as the line above
 AOGSMARTHOME_ITEM, AoGSmartHomeItems, light3, Test_Light_3   # if you want to change the name you say
 AOGSMARTHOME_ITEM, AoGSmartHomeItems, testsub, Test_Sub, \&testsub
# "!" will be replaced with the action ( on/off/<level number> ), so if you say "turn on test voice" then the module will run run_voice_cmd("test voice on")
 AOGSMARTHOME_ITEM, AoGSmartHomeItems, test_voice_!, Test_Voice, run_voice_cmd

User code examples:

 $AoGSmartHomeItems = new AoGSmartHome_Items();
 $AoGSmartHomeItems->add('$light1','light1','set','on','off','state');  # This is the same as $AoGSmartHomeItems->add('$light1')

To change the name of an object to a more natural name that you would say to the Echo/GH:

 $AoGSmartHomeItems->add('$GarageHall_light_front','Garage_Hall_light');

To map a voice command, '!' is replaced by the Echo/GH command (on/off/dim%).
My actual voice command in MH is "set night mode on", so I configure it like:

 $AoGSmartHomeItems->add('set night mode !','NightMode','run_voice_cmd');   

 If I say "Alexa, Turn on Night Mode",  run_voice_cmd("set night mode on") is run in MH.

To configure a user code sub:
The actual name (argument 1) can be anything.
A code ref must be used.
When the sub is run 2 arguments are passed to it: Argument 1 is (state or set) Argument 2 is: (on/off/<dim % interger>).

# Mht file

 AOGSMARTHOME_ITEM, AoGSmartHomeItems, testsub, Test_Sub, &testsub

# User Code

 $AoGSmartHomeItems->add('testsub','Test_Sub',\&testsub);  # say "Alexa, Turn on Test Sub",  &testsub('set','on') is run in MH.


# I have an Insteon thermostat, the Insteon object name is $thermostat and I configured it like:

 AOGSMARTHOME_ITEM, AoGSmartHomeItems, thermostat, Heat, heat_setpoint, on, off, get_heat_sp

# say "Alexa, Set Heat to 73",  $thermostat->heat_setpoint("73") is run in MH.

 AOGSMARTHOME_ITEM, AoGSmartHomeItems, thermostat, Cool, cool_setpoint, on, off, get_cool_sp

In order to be able to say things like "Alexa, set thermostat up by 2", a sub must be created in user code
When the above is said to the Echo, it first gets the current state, then subtracts or adds the amount that was said. 

 sub temperature {
   my ($type, $state) = @_;

   # $type is state or set
   # $state is the number, on, off, etc

   # we are changing heat and cool so just return a static number, we just need the diff
   # because the Echo will add or subtact the amount that was said to it.
   # so if we say "set thermostat up by 2", 52 will be returned in $state   
   if ($type eq 'state') { return 50; }

   return '' unless ($state =~ /\d+/); Make sure we have a number
   return '' if ($state > 65); # Dont allow changes over 15
   return '' if ($state < 35); # Dont allow changes over 15
   my ( $heatsp, $coolsp );
   $state = ($state - 50); # subtract the amount we return above to get the actual amount to change.
   $coolsp = ((state $thermo_setpoint_c) + $state);
   $heatsp = ((state $thermo_setpoint_h) + $state);
   # The Insteon thermostat has an issue when setting both heat and cool at the same time, so the timer is a work around.
   $alexa_temp_timer = new Timer;
   $thermostat->cool_setpoint($coolsp);
   set $alexa_temp_timer '7', sub { $thermostat->heat_setpoint($heatsp) }
 }

# Map our new temperature sub in the .mht file so the Echo/Google Home can discover it 

 AOGSMARTHOME_ITEM, AoGSmartHomeItems, thermostat, thermostat, &temperature

I have a script that I use to control my AV equipment and I can run it via
ssh, so I made a voice command in MH:

 $v_set_tv_mode = new Voice_Cmd("set tv mode [on,off,hbo,netflix,roku,directtv,xbmc,wii]");
 $p_set_tv_mode = new Process_Item;
 if (my $state = said $v_set_tv_mode) {
         set $p_set_tv_mode "/usr/bin/ssh wayne\@192.168.1.10 \"sudo /usr/local/HomeAVControl/bin/input_change $state\"";
         start $p_set_tv_mode;
 }

I added the following to my .mht file:

 AOGSMARTHOME_ITEM, AoGSmartHomeItems, set_tv_mode_!, DirectTv, run_voice_cmd, directtv, directtv
 AOGSMARTHOME_ITEM, AoGSmartHomeItems, set_tv_mode_!, Roku, run_voice_cmd, roku, roku
 AOGSMARTHOME_ITEM, AoGSmartHomeItems, set_tv_mode_!, xbmc, run_voice_cmd, xbmc, xbmc
 AOGSMARTHOME_ITEM, AoGSmartHomeItems, set_tv_mode_!, wii, run_voice_cmd, wii, wii
 AOGSMARTHOME_ITEM, AoGSmartHomeItems, set_tv_mode_!, Hbo, run_voice_cmd, hbo, hbo
 AOGSMARTHOME_ITEM, AoGSmartHomeItems, set_tv_mode_!, Netflix, run_voice_cmd, netflix, netflix

=head2 INHERITS

L<Generic_Item>

Storable

=head2 METHODS

=over

=cut

package AoGSmartHome_Items;

@AoGSmartHome_Items::ISA = ('Generic_Item');

use Data::Dumper;
use Storable qw(nstore retrieve);

#--------------Logging and debugging functions----------------------------------------

sub break_long_str {
    my ($self, $str, $prefix, $maxlength) = @_;
    my $result;

    $result = '';
    $str = $str || '';
    while( length( $str ) > $maxlength ) {
        my $l = 0;
        my $i;
        for( $i=0; $i<length($str) && $l<$maxlength; ++$i,++$l ) {
            if( substr( $str, $i, 1 ) eq "\n" ) {
                $l = 0;
            }
        }
        $result .= $prefix;
        $result .= substr( $str, 0, $i );
        $str = substr( $str, $i );
        $prefix = '....  ';
    }
    if( $str ) {
        $result .= $prefix;
        $result .= $str;
    }
    return $result;
}

sub log {
    my ($self, $str, $prefix) = @_;

    if( !defined( $prefix ) ) {
        $prefix = '[AoG]: ';
    }
    $str = $self->break_long_str( $str, $prefix, 300 );

    &main::print_log( $str );
}

sub debug {
    my( $self, $level, $str ) = @_;
    if( $main::Debug{aog} >= $level ) {
        $level = 'D' if $level == 0;
        $self->log( $str, "[AoG] D$level: " );
    }
}

sub error {
    my ($self, $str, $level ) = @_;
    $self->log( $self, $str, "[AoG] ERROR: " );
}

sub dump {
    my( $self, $obj, $maxdepth ) = @_;
    $obj = $obj || $self;
    $maxdepth = $maxdepth || 2;
    my $dumper = Data::Dumper->new( [$obj] );
    $dumper->Maxdepth( $maxdepth );
    return $dumper->Dump();
}

#----------------------------------------------------------------------------------------------

sub get_mh_object {
    my ($self, $realname) = @_;
    my $mh_object = ::get_object_by_name($realname);
    if( !defined $mh_object ) {
	$self->error( "Invalid device $realname; ignoring AoG item." );
    }
    return $mh_object;
}

sub set_state {
    my ( $self, $item, $state ) = @_;

    my $name     = $item->{'name'};
    my $realname = $item->{'realname'};
    my $sub      = $item->{'sub'};

    # Map state if there is a mapping defined
    $state = $item->{ lc($state) } if $item->{ lc($state) };

    $self->debug( 2, "set_state(name='$name' realname='$realname' sub='$sub' state='$state')" );

    if ( $sub =~ /^voice[_-]cmd:\s*(.+)\s*$/ ) {
        my $voice_cmd = $1;

	$voice_cmd =~ s/[#!]/$state/;

	$self->debug( 1, "running voice command \'$voice_cmd\'" );

	&main::run_voice_cmd("$voice_cmd");

	return;
    }
    elsif ( ref $sub eq 'CODE' ) {
        my $mh_object = $self->get_mh_object($realname);
	return undef if !defined $mh_object;

	$self->debug( 1, "running sub $sub(set, $state)" );

	&{$sub}($mh_object, $state, 'AoGSmartHome');
	return;
    }
    else {
        #
        # Treat as a MisterHouse object, using $sub as the 'set' function.
        #

        my $mh_object = $self->get_mh_object($realname);
	return undef if !defined $mh_object;

	if ( $mh_object->can('is_dimmable') && $mh_object->is_dimmable && $state =~ /\d+/ ) {
	    $state = $state . '%';
	}

	$self->debug( 1, "setting object $realname to state '$state'" );

	$mh_object->$sub( $state, 'AoGSmartHome' );

	return;
    }
}

sub get_state {
    my ( $self, $item ) = @_;

    my $name     = $item->{'name'};
    my $realname = $item->{'realname'};
    my $sub      = $item->{'sub'};
    my $statesub = $item->{'statesub'};

    $self->debug( 2, "get state(name='$name' realname='$realname' statesub='$statesub')" );

    if ( $sub =~ /^voice[_-]cmd:\s*(.+)\s*$/ ) {
        my $voice_cmd = $1;

	# FIXME -- "get" on voice command? Hhhmmm
	$self->error( "get_state called on a voice command $realname" );
	return qq["on":true,"bri":254];
    }
    elsif ( ref $statesub eq 'CODE' ) {
        my $mh_object = $self->get_mh_object($realname);
	return undef if !defined $mh_object;

	my $debug = "get_state() running sub: $statesub('$realname') - ";
	my $state = &{$statesub}($mh_object);
	$self->debug( 1, "$debug returning - $state" );
	return $state;
    }
    else {
        #
        # Treat as a MisterHouse object, using $statesub as the 'state' function.
        #

        my $mh_object = $self->get_mh_object($realname);
	return undef if !defined $mh_object;

	my $cstate = $mh_object->$statesub();
	$cstate =~ s/\%//;
	my $type  = $mh_object->get_type();
	my $debug = "get state($realname) -- actual object state: $cstate, object type: $type, ";

	if ( $type =~ /X10/i ) {
	    $cstate = 'on' if $cstate =~ /\d+/ || $cstate =~ /dim/ || $cstate =~ /bright/;
	    $debug .= "determined state: $cstate, ";
	}

	$debug .= "$debug returning $cstate";

	$self->debug( 1, $debug );

	return $cstate;
    }
}

sub get_state_list {
    my ( $self, $mode ) = @_;

    my $name		= $mode->{'name'};
    my $realname	= $mode->{'realname'};
    my $sub		= $mode->{'sub'};
    my $statelistsub    = $mode->{'statelistsub'};

    $self->debug( 2, "get_state_list(name='$name' realname='$realname' sub='$sub')" );

    if ( ref $statelistsub eq 'CODE' ) {
        my $mh_object = $self->get_mh_object($realname);
	if( !defined $mh_object ) {
	    $mh_object = $realname;
	}

	my $debug = "get_state_list() running sub: $statelistsub('$realname') - ";
	my @statelist = &{$statelistsub}($mh_object);
	$self->debug( 1, "$debug returning - @statelist" );
	return (@statelist);
    }
    else {
        #
        # Treat as a MisterHouse object, using $statelistsub as the 'statelist' function.
        #

        my $mh_object = $self->get_mh_object($realname);
	return undef if !defined $mh_object;

	my $debug = "get_state_list() running sub: $statelistsub('$realname') - ";
	my @statelist = $mh_object->$statelistsub();
	$self->debug( 1, "$debug returning - @statelist" );
	return (@statelist);
    }
}

sub new {
    my ($class) = @_;

    my $self = new Generic_Item();
    bless $self, $class;

    my $file = $::config_parms{'data_dir'} . '/aogsmarthome_temp.saved_id';
    if ( -e $file ) {
        my $restoredhash = retrieve($file);
        $self->{idmap} = $restoredhash->{idmap};

	$self->debug( 1, "dumping persistent IDMAP:\n" . $self->dump( $self->{idmap} ) );
    }

    return $self;
}

=item C<add()>

Presents MisterHouse objects, subs, or voice coommands to the Actions on
Google Smart Home API.

add('<actual object name>', '<friendly object name>',
'<subroutine used to change the object state>',
'<State mapped to AoG Smart Home ON command>',
'<State mapped to AoG Smart Home OFF command>',
'<subroutine used to get the object state>'
'<Aog Smart Home device type>);

=cut

sub add {
    my ( $self, $realname, $name, $sub, $on, $off, $statesub, $dev_properties ) = @_;
    my ($type, $room); # AoG Smart Home Provider device properties


    if( !$realname ) {
	$self->error( "Realname must be specified for persistent idmap; ignoring AoG item." );
	return;
    }
	
    if ( !$name ) {
        $name = $realname;
        $name =~ s/\$//g;
        $name =~ s/_/ /g;    # Otherwise the Google Assistant will say
                             # "kitchen-underscore-light" instead of
                             # "kitchen light".
        $name =~ s/#//g;
        $name =~ s/\\//g;
        $name =~ s/&//g;
    }

    if ($dev_properties) {
	foreach (split /\s*:\s*/, $dev_properties) {
	    my ($parm, $value) = split /\s*=\s*/;

	    if ($parm eq 'type') {
		$type = $value;

		# Check that the type is a supported one
		if( $type ne 'light' && $type ne 'scene' && $type ne 'switch'
		&&  $type ne 'outlet'&& $type ne 'thermostat' && $type ne 'select'
		) {
		    $self->error( "Invalid device type '$type'; ignoring AoG item." );
		    return;
		}
	    } elsif ($parm eq 'room') {
		$room = $value;
	    } else {
		$self->error( "Invalid device property '$parm'; ignoring AoG item." );
		return;
	    }
	}
    };
    $type = lc($type) || 'light';

    my $uuid = $self->uuid($realname);

    if( $type eq 'select' ) {
	$self->add_mode_trait( $realname, $realname, 'Mode', $sub, undef, $statesub, 0 );
    }
    $self->{'uuids'}->{$uuid}->{'realname'} = $realname;
    $self->{'uuids'}->{$uuid}->{'name'}     = $name;
    $self->{'uuids'}->{$uuid}->{'sub'}      = $sub || 'set';
    $self->{'uuids'}->{$uuid}->{'on'}       = lc($on) || 'on';
    $self->{'uuids'}->{$uuid}->{'off'}      = lc($off) || 'off';
    $self->{'uuids'}->{$uuid}->{'statesub'} = $statesub || 'state';
    $self->{'uuids'}->{$uuid}->{'statelistsub'} = 'get_states';
    # If no device type is provided we default to 'light'
    $self->{'uuids'}->{$uuid}->{'type'}     = $type;
    $self->{'uuids'}->{$uuid}->{'room'}     = $room if $room;
    $self->debug( 2, "Added AOG device:\n    " . $self->dump( $self->{'uuids'}->{$uuid} ) );
}

=item C<add_mode_trait()>

Presents MisterHouse objects, subs, or voice coommands to the Actions on
Google Smart Home API.

add('<actual object name>', '<friendly object name>',
'<subroutine used to change the object state>',
'<State mapped to AoG Smart Home ON command>',
'<State mapped to AoG Smart Home OFF command>',
'<subroutine used to get the object state>'
'<Aog Smart Home device type>);

=cut

sub add_mode_trait {
    my ( $self, $itemname, $modename, $name, $sub, $statelistsub, $statesub, $ordered ) = @_;
    my ($type, $room); # AoG Smart Home Provider device properties


    $self->debug( 2, "Adding AOG mode trait '$modename' as ($name) to $itemname:\n    " . $self->dump( $mode ) );
    my $uuid = $self->{'idmap'}->{objects}->{$itemname};
    if( !$itemname  ||  !$uuid ) {
	$self->error( "Add_mode_trait -- Itemname for existing AoG item must be specified; ignoring AoG mode." );
	return;
    }
	
    if ( !$name ) {
        $name = $modename;
        $name =~ s/\$//g;
        $name =~ s/_/ /g;    # Otherwise the Google Assistant will say
                             # "kitchen-underscore-light" instead of
                             # "kitchen light".
        $name =~ s/#//g;
        $name =~ s/\\//g;
        $name =~ s/&//g;
    }
    my $keyname = lc($name) . '_key';

    my $mode = {};

    $mode->{'realname'}		= $modename;
    $mode->{'name'}		= $name;
    $mode->{'keyname'}		= $keyname;
    $mode->{'sub'}		= $sub || 'set_now';
    $mode->{'statelistsub'}	= $statelistsub || 'get_states';
    $mode->{'statesub'}		= $statesub  || 'state';
    $mode->{'ordered'}		= $ordered || 0;

    $self->{'uuids'}->{$uuid}->{modes} = {} if !defined $self->{'uuids'}->{$uuid}->{modes};
    $self->{'uuids'}->{$uuid}->{modes}->{$keyname} = $mode;

    $self->debug( 2, "Added AOG mode trait '$modename' to $itemname:\n    " . $self->dump( $mode ) );
}

=item C<sync()>

Generates an action.devices.SYNC fulfillment response.

=cut

sub sync {
    my ( $self, $body ) = @_;

    my $response = <<EOF;
{
 "requestId": "$body->{'requestId'}",
 "payload": {
EOF

    if (defined $::config_parms{'aog_agentuserid'}) {
	$response .= <<EOF;
  "agentUserId": "$::config_parms{'aog_agentuserid'}",
EOF
    }

    $response .= <<EOF;
  "devices": [
EOF

    foreach my $uuid ( keys %{ $self->{'uuids'} } ) {
        my $type = $self->{'uuids'}->{$uuid}->{'type'};

	$self->debug( 1, "Object added: $self->{'uuids'}->{$uuid}->{'realname'}" );
        if ( $type eq 'light' ) {
            $response .= <<EOF;
   {
    "id": "$uuid",
    "type": "action.devices.types.LIGHT",
    "traits": [
     "action.devices.traits.OnOff",
EOF

	    # Check whether the light is dimmable so we can communicate that
	    # the device has the "Brightness" trait. Done by calling
	    # is_dimmable method on the object.

	    my $mh_object = $self->get_mh_object($self->{'uuids'}->{$uuid}->{'realname'});
	    return undef if !defined $mh_object;

	    if( $mh_object->can('is_dimmable') && $mh_object->is_dimmable ) {
		$response .= <<EOF;
     "action.devices.traits.Brightness",
EOF
	    }
	    $response .= $self->sync_modes_trait( $uuid );

	    $response =~ s/,$//;    # Remove extra ','

	    $response .= <<EOF;
    ],
    "name": {
     "name": "$self->{'uuids'}->{$uuid}->{'name'}"
    },
    "willReportState": false,
EOF

	    if (exists $self->{'uuids'}->{$uuid}->{'room'}) {
		$response .= <<EOF;
    "roomHint": "$self->{'uuids'}->{$uuid}->{'room'}",
EOF
	    }
	    $response .= $self->sync_modes( $uuid );

	    $response =~ s/,$//;    # Remove extra ','

	    $response .= <<EOF;
   },
EOF
        }
	elsif ( $type eq 'switch' || $type eq 'outlet' ) {
	    #
	    # action.devices.types.SWITCH and action.devices.types.OUTLET
	    # are basically the same type of device; as far as I can
	    # tell the only difference is the icon they get in the apps.
	    #

	    $type = uc $type;
	    if( $self->{'uuids'}->{$uuid}->{modes} ) {
		$type = 'DRYER';
	    }

            $response .= <<EOF;
   {
    "id": "$uuid",
    "type": "action.devices.types.$type",
    "traits": [
EOF
	    $response .= $self->sync_modes_trait( $uuid );
            $response .= <<EOF;
     "action.devices.traits.OnOff"
    ],
    "name": {
     "name": "$self->{'uuids'}->{$uuid}->{'name'}"
    },
    "willReportState": false,
EOF

	    if (exists $self->{'uuids'}->{$uuid}->{'room'}) {
		$response .= <<EOF;
    "roomHint": "$self->{'uuids'}->{$uuid}->{'room'}",
EOF
	    }
	    $response .= $self->sync_modes( $uuid );

	    $response =~ s/,$//;    # Remove extra ','

	    $response .= <<EOF;
   },
EOF
        } elsif ( $type eq 'thermostat') {
	    my $mh_object = $self->get_mh_object($self->{'uuids'}->{$uuid}->{'realname'});
	    return undef if !defined $mh_object;

	    if (!$mh_object->isa('Insteon::Thermostat') ) {
		$self->error( "'$self->{'uuids'}->{$uuid}->{'realname'}' is an unsupported thermostat; ignoring AoG item.");
		next;
	    }

            $response .= <<EOF;
   {
    "id": "$uuid",
    "type": "action.devices.types.THERMOSTAT",
    "traits": [
     "action.devices.traits.TemperatureSetting"
    ],
    "name": {
     "name": "$self->{'uuids'}->{$uuid}->{'name'}"
    },
    "willReportState": true,
    "attributes": {
     "availableThermostatModes": "off,heat,cool,on,heatcool,fan-only",
     "thermostatTemperatureUnit": "F"
    },
EOF

	    if (exists $self->{'uuids'}->{$uuid}->{'room'}) {
		$response .= <<EOF;
    "roomHint": "$self->{'uuids'}->{$uuid}->{'room'}",
EOF
	    }

	    $response =~ s/,$//;    # Remove extra ','

	    $response .= <<EOF;
   },
EOF
	}
        elsif ( $type eq 'scene' ) {
            $response .= <<EOF;
   {
    "id": "$uuid",
    "type": "action.devices.types.SCENE",
    "traits": [
EOF
            $response .= <<EOF;
     "action.devices.traits.Scene"
    ],
    "name": {
     "name": "$self->{'uuids'}->{$uuid}->{'name'}"
    },
    "willReportState": false,
    "attributes": {
     "sceneReversible": false
    }
   },
EOF
        } elsif ( $type eq 'select' ) {
            $response .= <<EOF;
   {
    "id": "$uuid",
    "type": "action.devices.types.DRYER",
    "traits": [
     "action.devices.traits.Modes"
    ],
    "name": {
     "name": "$self->{'uuids'}->{$uuid}->{'name'}"
    },
    "willReportState": false,
EOF
	    $response .= $self->sync_modes( $uuid );
	    $response =~ s/,$//;    # Remove extra ','
	    $response .= <<EOF;
   },
EOF
	}
    }

    $response =~ s/,$//;    # Remove extra ','

    $response .= <<EOF;
  ]
 }
}
EOF

    $self->debug( 2, "action.devices.SYNC response:\n$response" );

    return &main::json_page($response);
}

sub sync_modes_trait {
    my ($self, $uuid ) = @_;
    my $response = '';

    if( !defined $self->{'uuids'}->{$uuid}->{modes} ) {
	return $response;
    }
    $response .= <<EOF;
     "action.devices.traits.Modes",
EOF
    return $response;
}

sub sync_modes {
    my ($self, $uuid, $do_attributes_clause ) = @_;
    my $response = '';

    $do_attributes_clause = 1 if !defined $do_attributes_clause;
    if( !defined $self->{'uuids'}->{$uuid}->{modes} ) {
	return $response;
    }

    # $response = main::read_file( '\tmp\attrs.txt' ) . "\n";
    # return $response;


    my @mode_list = values %{$self->{'uuids'}->{$uuid}->{modes}};
    $self->debug( 2, "Syncing modes on  AOG device:\n    " . $self->dump( $self->{'uuids'}->{$uuid} ) );
    $self->debug( 2, "   mode_list:  " . $self->dump( @mode_list ) );

    if( $do_attributes_clause ) {
	$response .= <<EOF;
    "attributes": {
EOF
    }
    $response .= <<EOF;
        "availableModes": [
EOF

    for my $mode (@mode_list) {
	my @statelist = $self->get_state_list( $mode );
	if( scalar(@statelist) == 0 ) {
	    $self->error( "Invalid mode -- no state list $mode->{'realname'}; ignoring AoG item." );
            next;
	}
	$response .= <<EOF;
           {
            "name": "$$mode{keyname}",
	    "name_values": [
	      {
	        "name_synonym": [
	          "$$mode{name}"
	        ],
	        "lang": "en"
	      }
	    ],
	    "settings": [
EOF
	foreach my $state (@statelist) {
	    $response .= <<EOF;
	      {
	        "setting_name": "${state}_key",
	        "setting_values": [
		   {
		     "setting_synonym": [
		        "${state}"
		     ],
		     "lang": "en"
		   }
	        ]
	      },
EOF
	}
	$response =~ s/,$//;

	my $ordered = 'false';
	if( $mode->{ordered} ) {
	    $ordered = 'true';
	}
	$response .= <<EOF;
             ],
	     "ordered": $ordered
           },
EOF
    }
    $response =~ s/,$//;

    $response .= <<EOF;
        ]
EOF

    if( $do_attributes_clause ) {
	    $response .= <<EOF;
    },
EOF
    }
    $self->debug( 2, "sync_modes response: \n$response" );
    return $response;
}

=item C<query()>

Generates an action.devices.QUERY fulfillment response.

=cut

sub query {
    my ( $self, $body ) = @_;

    my $response = <<EOF;
{
 "requestId": "$body->{'requestId'}",
 "payload": {
  "devices": {
EOF

    foreach my $device ( @{ $body->{'inputs'}->[0]->{'payload'}->{'devices'} } ) {
	my $uuid = $device->{'id'}; # Makes things easier below...

        if ( !exists $self->{'uuids'}->{$uuid} ) {
	    $self->error( "No device id $uuid found");
            $response .= <<EOF;
   "$uuid": {
    "errorCode": "deviceNotFound"
   },
EOF
            next;
        }

        if ( $self->{'uuids'}->{$uuid}->{'type'} eq 'scene' ) {
            $response .= <<EOF;
   "$uuid": {
EOF
	    $response .= $self->query_modes( $uuid );
            $response .= <<EOF;
    "online": true
   },
EOF
            next;
        }
        elsif ( $self->{'uuids'}->{$uuid}->{'type'} eq 'thermostat' ) {
	    my $mh_object = $self->get_mh_object($self->{'uuids'}->{$uuid}->{'realname'});
	    return undef if !defined $mh_object;

	    if ($mh_object->isa('Insteon::Thermostat') ) {
		my $mode = lc($mh_object->get_mode());
		$mode = 'heatcool' if ($mode =~ /auto/);

		my $activeThermostatMode = lc($mh_object->get_status);
		my $fanmode = lc($mh_object->get_fan_mode);
		if ($activeThermostatMode =~ /cooling/) { 
			$activeThermostatMode = 'cool';
		} elsif ($activeThermostatMode =~ /heating/) { 
			$activeThermostatMode = 'heat';
		} elsif ( ( $fanmode =~ /always on/) and ( $activeThermostatMode =~ /off/ ) ) {
			$activeThermostatMode = 'fan-only';
		} else { 
			$activeThermostatMode = 'none';
		}

		my $temp_setpoint;
		if ($mode eq 'cool') {
		    $temp_setpoint = '"thermostatTemperatureSetpoint": '. &FtoC($mh_object->get_cool_sp).',';
		} elsif ($mode eq 'heat') {
		    $temp_setpoint = '"thermostatTemperatureSetpoint": '. &FtoC($mh_object->get_heat_sp).',';
		} elsif ($mode eq 'heatcool') {
		     $temp_setpoint = '"thermostatTemperatureSetpointHigh": '. &FtoC($mh_object->get_cool_sp).','."\n";
		     $temp_setpoint .= '"thermostatTemperatureSetpointLow": '. &FtoC($mh_object->get_heat_sp).',';
		}
		
		my $temp_ambient = &FtoC($mh_object->get_temp);
		my $thermostatHumidityAmbient = $mh_object->get_humid;
		
		$response .= <<EOF;
   "$uuid": {
    "online": true,
    "thermostatMode": "$mode",
    "activeThermostatMode": "$activeThermostatMode",
    $temp_setpoint
    "thermostatTemperatureAmbient": $temp_ambient,
    "thermostatHumidityAmbient": $thermostatHumidityAmbient,
    "status": "SUCCESS"
   },
EOF
	    }
	    # No "else" -- unsupported thermostats are not included in
	    # "sync" response

	    next;
        }
        elsif ( $self->{'uuids'}->{$uuid}->{'type'} eq 'select' ) {
	    my $mh_object = $self->get_mh_object($self->{'uuids'}->{$uuid}->{'realname'});
	    next if !defined $mh_object;

	    my $devstate = get_state( $self, $self->{'uuids'}->{$uuid} );
	    if ( !defined $devstate ) {
		$self->error( "Device $self->{'uuids'}->{$uuid}->{'realname'} has no state; ignoring AoG item.");
		$response .= <<EOF;
   "$uuid": {
    "errorCode": "deviceNotFound"
   },
EOF
		next;
	    }
	    my $mode_query = $self->query_modes( $uuid );
	    $response .= <<EOF;
   "$uuid": {
     "online": true,
     "status": "SUCCESS", 
EOF
	    $response .= $self->query_modes( $uuid );
	    $response =~ s/,$//;    # Remove extra ','
	    $response .= <<EOF;
   },
EOF
	    next;
	} else {
	    #
	    # The device is a light, a switch, or an outlet.
	    #
    
	    my $devstate = get_state( $self, $self->{'uuids'}->{$uuid} );
	    if ( !defined $devstate ) {
		$self->error( "Device $self->{'uuids'}->{$uuid}->{'realname'} has no state; ignoring AoG item.");
		$response .= <<EOF;
   "$uuid": {
    "errorCode": "deviceNotFound"
   },
EOF
		next;
	    }

	    $response .= <<EOF;
   "$uuid": {
     "status": "SUCCESS",
     "online": true,
EOF

	    # Check whether the device is on so we can populate the "on" state
	    # for the "OnOff" trait. A device is also "on" if the brightness level
	    # is non-zero. Note that all lights have the "OnOff" trait so we
	    # unconditionally send the "on" state.
	    my $on = $devstate eq "on" || $devstate > 0 ? 'true' : 'false';
    
	    $response .= <<EOF;
     "on": $on,
EOF

	    # If the device is dimmable we provided the "Brightness" trait, so we
	    # have to supply the "brightness" state.

	    my $mh_object = $self->get_mh_object($self->{'uuids'}->{$uuid}->{'realname'});
	    return undef if !defined $mh_object;

	    if( $mh_object->can('is_dimmable') && $mh_object->is_dimmable ) {
    
		# INSTEON devices return "on" or "off". The AoG "Brightness" trait
		# expects needs "100" or "0", so we adjust here accordingly.
		if ($devstate eq 'on'  ||  $devstate eq 'on_fast') {
		    $devstate = 100;
		} elsif ($devstate eq 'off'  ||  $devstate eq 'off_fast') {
		    $devstate = 0;
		}
    
		$response .= <<EOF;
    "brightness": $devstate,
EOF
	    }

	    $response .= $self->query_modes( $uuid );
	    $response =~ s/,$//;    # Remove extra ','

	    $response .= <<EOF;
   },
EOF
	}
    }

    $response =~ s/,$//;    # Remove extra ','

    $response .= <<EOF;
  }
 }
}
EOF

    $self->debug( 2, "action.devices.QUERY response: \n$response" );

    return &main::json_page($response);
}

sub query_modes {
    my ( $self, $uuid, $exclude ) = @_;
    my $response = '';

    if( !defined $self->{'uuids'}->{$uuid}->{modes} ) {
	$self->debug( 2, "query_modes for device $uuid, excluding '$exclude' -- no modes defined" );
	return $response;
    }

    my @modelist = values %{$self->{'uuids'}->{$uuid}->{modes}};
    $self->debug( 2, "Querying modes on  AOG device:\n    " . $self->dump( $self->{'uuids'}->{$uuid} ) );
    $self->debug( 2, "   modelist:  " . $self->dump( @modelist ) );
    $response .= <<EOF;
      "currentModeSettings": {
EOF
    foreach my $mode (@modelist) {
	if( $mode->{'keyname'} eq $exclude ) {
	    $self->debug( 2, "Skipping '$exclude' in response" );
	    next;
	}
	my $devstate = get_state( $self, $mode );
	if ( !defined $devstate ) {
	    $self->error( "Device $mode->{'realname'} has no state; ignoring AoG item.");
	    next;
	}
	$response .= <<EOF;
        "$$mode{keyname}": "${devstate}_key",
EOF
    }
    $response =~ s/,$//;    # Remove extra ','
    $response .= <<EOF;
      },
EOF
    return $response;
}

sub FtoC { 
	my ( $F ) = @_;
	return ( ($F - 32) * 5/9 );
	#return sprintf "%.0f", ( ($F - 32) * 5/9 );
}

sub CtoF { 
	my ( $F ) = @_;
	#return ( (9 * $F/5) + 32 );
	return sprintf "%.0f", ( (9 * $F/5) + 32 );

}

sub execute_OnOff {
    my ( $self, $command ) = @_;

    my $response = '   {
    "ids": [';

    my $turn_on;

    if( $command->{'execution'}->[0]->{'params'}->{'on'} == 1
    ||  $command->{'execution'}->[0]->{'params'}->{'on'} eq "true"
    ) {
	$turn_on = 1;
    } else {
	$turn_on = 0;
    }

    foreach my $device ( @{ $command->{'devices'} } ) {
	$self->debug( 1, "Received execute onoff command for $device->{'id'} -- " . $command->{'execution'}->[0]->{'params'}->{'on'} );
        set_state( $self, $self->{'uuids'}->{$device->{'id'}}, $turn_on ? 'on' : 'off' );
	$response .= qq["$device->{'id'}",];
    }

    # Remove extra ',' at the end
    $response =~ s/,$//;

    $response .= "],\n";

    $response .= <<EOF;
    "status": "SUCCESS"
   },
EOF

    return $response;
}

sub execute_SetModes {
    my ( $self, $command ) = @_;
    my $response = '';

    foreach my $device ( @{ $command->{'devices'} } ) {
	$self->debug( 1, "Received execute command on $device->{id}: " . $self->dump($command->{'execution'}->[0]->{'params'}->{'updateModeSettings'}) );
	foreach my $modekey ( keys %{$command->{'execution'}->[0]->{'params'}->{'updateModeSettings'}} ) {
	    my $newvalue = $command->{'execution'}->[0]->{'params'}->{'updateModeSettings'}->{$modekey};
	    $newvalue =~ s/_key$//;
	    set_state( $self, $self->{'uuids'}->{$device->{'id'}}->{modes}->{$modekey}, $newvalue );
	}
        $response .= <<EOF;
   {
    "ids": [
      "$device->{'id'}"
    ],
    "status": "SUCCESS",
    "states": {
      "online": true,
EOF

        #########
	# note that MH items don't get their new state right away, so using query_modes doesn't get
	#      the right state.  It is possible to make this work by using the set_now function, rather than
	#      set -- hence the default for modes set sub is set_now.
	#########
	# However, there seems to be a bug in google home that if you use the UI to set one mode,
	# all other modes on the device forget their state in the google home graph.  It doesn't matter
	# if you return those other mode states on the execute call or not.
	#########
	if( 0 ) {
        } elsif( 1 ) {
            $response .= $self->query_modes( $device->{'id'} );
	} else {
	    $response .= <<EOF;
      "currentModeSettings": {
EOF
	    foreach my $modekey ( keys %{$command->{'execution'}->[0]->{'params'}->{'updateModeSettings'}} ) {
		my $newvalue = $command->{'execution'}->[0]->{'params'}->{'updateModeSettings'}->{$modekey};
		$response .= <<EOF;
	    "$modekey": "$newvalue",
EOF
	    }
	    $response =~ s/,$//;
	    $response .= <<EOF;
      },
EOF

	}

	$response =~ s/,$//;
	$response .= <<EOF;
    }
   },
EOF
    }

    # Remove extra ',' at the end
    $response =~ s/,$//;

    return $response;
}

sub execute_BrightnessAbsolute {
    my ( $self, $command ) = @_;

    my $response = '   {
    "ids": [';

    my $brightness = $command->{'execution'}->[0]->{'params'}->{'brightness'};

    foreach my $device ( @{ $command->{'devices'} } ) {
        set_state( $self, $self->{'uuids'}->{$device->{'id'}}, $brightness);
	$response .= qq["$device->{'id'}",];
    }

    # Remove extra ',' at the end
    $response =~ s/,$//;

    $response .= "],\n";

    $response .= <<EOF;
    "status": "SUCCESS"
   },
EOF

    return $response;
}

sub execute_ActivateScene {
    my ( $self, $command ) = @_;

    my $response = '   {
    "ids": [';

    foreach my $device ( @{ $command->{'devices'} } ) {
        set_state( $self, $self->{'uuids'}->{$device->{'id'}});
	$response .= qq["$device->{'id'}",];
    }

    # Remove extra ',' at the end
    $response =~ s/,$//;

    $response .= "],\n";

    $response .= <<EOF;
    "status": "SUCCESS"
   },
EOF

    return $response;
}

sub execute_ThermostatX {
    my ( $self, $command, $exec_command ) = @_;

    my $response;

    my $execution_command = $command->{'execution'}->[0]->{'command'};

    foreach my $device ( @{ $command->{'devices'} } ) {
	my $realname = $self->{'uuids'}->{$device->{'id'} }->{'realname'};

	my $mh_object = $self->get_mh_object($realname);
	return undef if !defined $mh_object;

	if ($mh_object->isa('Insteon::Thermostat') ) {
	    my $mode = lc($mh_object->get_mode);
	    $mode = 'heatcool' if ($mode =~ /auto/);

	    if ( $execution_command =~ /TemperatureSetpoint/ ) {
		$self->debug( 1,"Setting temp: ".&CtoF($command->{'execution'}->[0]->{'params'}->{'thermostatTemperatureSetpoint'}) );
		my $setpoint = &CtoF($command->{'execution'}->[0]->{'params'}->{'thermostatTemperatureSetpoint'});
		if ( $mode eq 'cool') {
		    $mh_object->cool_setpoint($setpoint);
		} elsif( $mode eq 'heat') {
		    $mh_object->heat_setpoint($setpoint);
		}
	    } elsif ( $execution_command =~ /ThermostatTemperatureSetRange/ ) {
		$self->debug( 1, "Setting cool: ".&CtoF($command->{'execution'}->[0]->{'params'}->{'thermostatTemperatureSetpointHigh'})." Heat: ".&CtoF($command->{'execution'}->[0]->{'params'}->{'thermostatTemperatureSetpointLow'}));
		$mh_object->cool_setpoint( &CtoF($command->{'execution'}->[0]->{'params'}->{'thermostatTemperatureSetpointHigh'}) );
		$mh_object->heat_setpoint( &CtoF($command->{'execution'}->[0]->{'params'}->{'thermostatTemperatureSetpointLow'}) );
	    } elsif ( $execution_command =~ /ThermostatSetMode/ ) {
		my $mode = $command->{'execution'}->[0]->{'params'}->{'thermostatMode'};
		$mode = 'auto' if ($mode =~ /heatcool/);
		$mh_object->mode($mode);
	    }

	    $mode = lc($mh_object->get_mode);
	    $mode = 'heatcool' if ($mode =~ /auto/);
	    my $activeThermostatMode = lc($mh_object->get_status());
	    my $fanmode = lc($mh_object->get_fan_mode);
	    if ($activeThermostatMode =~ /cooling/) {
            	$activeThermostatMode = 'cool';
	    } elsif ($activeThermostatMode =~ /heating/) {
            	$activeThermostatMode = 'heat';
	    } elsif ( ( $fanmode =~ /always on/) and ( $activeThermostatMode =~ /off/ ) ) {
            	$activeThermostatMode = 'fan-only';
            } else {
            	$activeThermostatMode = 'none';
            }

            my $temp_setpoint;
            if ($mode eq 'cool') {
            	$temp_setpoint = '"thermostatTemperatureSetpoint": '. &FtoC($mh_object->get_cool_sp).',';
            } elsif ($mode eq 'heat') {
            	$temp_setpoint = '"thermostatTemperatureSetpoint": '. &FtoC($mh_object->get_heat_sp).',';
            } elsif ($mode eq 'heatcool') {
            	$temp_setpoint = '"thermostatTemperatureSetpointHigh": '. &FtoC($mh_object->get_cool_sp).','."\n";
            	$temp_setpoint .= '"thermostatTemperatureSetpointLow": '. &FtoC($mh_object->get_heat_sp).',';
            }  

	    my $temp_ambient = &FtoC($mh_object->get_temp);
	    my $thermostatHumidityAmbient = $mh_object->get_humid;

	    $response .= "   {";
	    $response .= <<EOF
    "ids": ["$device->{'id'}"],
    "status": "SUCCESS",
    "states": {
     "thermostatMode": "$mode",
     "activeThermostatMode": $activeThermostatMode,
     $temp_setpoint
     "thermostatTemperatureAmbient": $temp_ambient,
     "thermostatHumidityAmbient": $thermostatHumidityAmbient
    }
  },
EOF
	}
	# No "else" -- unsupported thermostats are not included in
	# "sync" response
    }

    # Remove extra ',' at the end
    $response =~ s/,$//;

    return $response;
}

=item C<execute()>

Generates an action.devices.EXECUTE fulfillment response.

=cut

#
# Implement the action.devices.EXECUTE fulfillment hook.
#
# Our strategy consists of sending all the commands at once, and then
# coming back to check if the command was successful.
#
sub execute {
    my ( $self, $body ) = @_;
    my %desired_states;

    my $response = <<EOF;
{
 "requestId": "$body->{'requestId'}",
 "payload": {
  "commands": [
EOF

    $self->debug( 2,  "Aog received execute request:\n    " . $self->dump( $body, 0 ) );;
    #
    # First, send the commands to all the devices specified in the request.
    #
    foreach my $command ( @{ $body->{'inputs'}->[0]->{'payload'}->{'commands'} } ) {
        my $execution_command = $command->{'execution'}->[0]->{'command'};

        if ( $execution_command eq "action.devices.commands.OnOff" ) {
            $response .= execute_OnOff( $self, $command );
        }
        elsif ( $execution_command eq "action.devices.commands.BrightnessAbsolute" ) {
            $response .= execute_BrightnessAbsolute( $self, $command );
        }
        elsif ( $execution_command eq "action.devices.commands.SetModes" ) {
            $response .= execute_SetModes( $self, $command );
        }
        elsif ( $execution_command eq "action.devices.commands.ActivateScene" ) {
            $response .= execute_ActivateScene( $self, $command );
        }
        elsif ( $execution_command =~ /^action\.devices\.commands\.Thermostat.+$/ ) {
	    $response .= execute_ThermostatX( $self, $command );
	}
    }

    # Remove extra ',' at the end
    $response =~ s/,$//;

    $response .= <<EOF;
  ]
 }
}
EOF

    $self->debug( 2, "action.devices.EXECUTE response: \n$response" );

    return &main::json_page($response);
}

sub uuid {
    my ( $self, $name ) = @_;

    return $self->{'idmap'}->{objects}->{$name}
      if exists $self->{'idmap'}->{objects}->{$name};

    my $highid;
    my $missing;
    my $count = $::config_parms{'aog_uuid_start'} || 1;

    foreach my $object ( keys %{ $self->{idmap}->{objects} } ) {
        my $currentid = $self->{idmap}->{objects}->{$object};
        $highid = $currentid if ( $currentid > $highid );
        $missing = $count unless ( $self->{'idmap'}->{ids}->{$count} );    # We have a number that has no value
        $count++;
    }
    $highid++;

    $highid = $missing if defined $missing;                                # Reuse numbers for deleted objects to keep the count from growning for ever.

    $self->{'idmap'}->{objects}->{$name} = $highid;
    $self->{'idmap'}->{ids}->{$highid}   = $name;

    my $idmap->{'idmap'} = $self->{'idmap'};

    my $file = $::config_parms{'data_dir'} . '/aogsmarthome_temp.saved_id';
    nstore $idmap, $file;

    return $highid;

    # use Data::UUID;
    #	$ug    = Data::UUID->new;
    #	$uuid   = $ug->to_string( ( $ug->create_from_name(NameSpace_DNS, $name) ) );
    #	$uuid =~ s/\D//g;
    #        $uuid =~ s/-//g;
    #	$uuid = (substr $uuid, 0, 9);
    #	return lc($uuid);
}

1;

=back

=head2 NOTES

=head2 AUTHOR

Eloy Paris <peloy@chapus.net> based heavily on AlexaBridge.pm by Wayne Gatlin <wayne@razorcla.ws>

=head2 SEE ALSO

=head2 LICENSE

This program is free software; you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation; either version 2 of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more details.

You should have received a copy of the GNU General Public License along with this program; if not, write to the Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.

=cut
