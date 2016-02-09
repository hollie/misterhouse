
=head1 B<Ecobee>

=head2 SYNOPSIS

This module allows MisterHouse to communicate with the public Ecobee API which 
currently allows interaction with Ecobee's family of thermostats (ecobee3, Smart Si, 
EMS, EMS Si and white label Carrier Cor and Bryant Housewise). The current version 
of this module only supports the ecobee3, but can be extended to support the other 
thermostat models.

=head2 CONFIGURATION

Ecobee uses OAuth 2.0 to authorize access to devices associated with your account.  
The nice thing is that at any point in the future, you can sign into your Ecobee 
account and revoke any access tokens that you have issued.

To authorize API access for MisterHouse, you will need to perform two steps on
the Ecobee website. 

First: Sign up as a developer on the Ecobee Developer portal 
(L<https://www.ecobee.com/developers/>). This steps is required to create the 
API key used by the application. All thermostats registered with this with this 
API key (application) will be visible to MisterHouse, so for security reasons, you 
should create your own application and not use someone elses's API key as they will 
have access to your thermostats. Once signed up as a developer, the Developer 
Dashboard becomes available on the consumer portal 
(L<https://www.ecobee.com/home/ecobeeLogin.jsp>) and can be accessed by selecting 
I<DEVELOPER> from the three horizontal lines in the upper-right-hand part of the screen.
Create a new application. The name must be globally unique, but is arbitrary for how
MisterHouse interacts with it. Select Authorization Method I<ecobee PIN>, add any other
attributes you desire to include (these are not required), then select I<Create>.
Once your application is created, it will be visible in the left-hand part of the screen.
Click on this and it will reveal the API key. Copy this string as it is needed in your 
configuration.

Second: Add the API key string to your mh.private.ini file:

  Ecobee_api_key=<API key generated in the previous step>

Create an Ecobee instance in the .mht file, or is user code:

.mht file:

  CODE, require Ecobee; #noloop
  CODE, $ecobee = new Ecobee_Interface(); #noloop

Explanations of the parameters is contained below in the documentation for each
module.

=head2 OVERVIEW

The Ecobee public API is fairly comprehensive and allows access to the majority 
of the thermostat's features. Since release, Ecobee has been progressively been
adding and enhancing features. As such, functionality may change and require
updates to this module.

=head3 ECOBEE_INTERFACE

This handles the interaction between the Ecobee API servers and MisterHouse.  
This is the object that is required.  An advanced user could interact with
the Ecobee API solely through this object.

=head3 ECOBEE_GENERIC

This provides a generic base for building objects that receive data from the 
interface.  This object is inherited by all parent and child objects and
in most cases, a user will not need to worry about this object.

=head3 PARENT ITEMS

These currently include B<Ecobee_Thermostat> and B<Ecobee_Structure>
This classes provide more specific support for each of the current Ecobee 
type of objects. These objects provide all of the access needed to interact 
with each of the devices in a user friendly way.

=head3 CHILD ITEMS

Currently these are named B<Ecobee_Thermo_>.... These are very specific objects 
that provide very specific support for individual features on the Ecobee 
Thermostats. I have in the past commonly referred to these as child objects.  
In general, the state of these objects reports the state of a single parameter 
on the thermostat.  A few of the objects also offer writable features that allow 
changing certain parameters on the thermostat.

=cut

package Ecobee;

# Used solely to provide a consistent logging feature
#
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
    if ( $::Debug{'ecobee'} >= $level || $level == 0 ) {
        $line = " at line " . $caller[2] if $::Debug{'ecobee'} >= $trace;
        ::print_log( "[" . $caller[0] . "] " . $message . $line );
    }
}

#
#

package Ecobee_Interface;

@Ecobee_Interface::ISA = ('Generic_Item', 'Ecobee');

use strict;
use warnings;

use LWP::UserAgent;
use HTTP::Request::Common qw(POST);
use JSON::XS;
use Data::Dumper;
use URI::Escape;


# Notes:
#
# As of 1/31/2016 some API examples using cURL incorrectly show the authorize and token 
# endpoints as https://api.ecobee.com/1/authorize and https://api.ecobee.com/1/token. 
# However, these are actually https://api.ecobee.com/authorize https://api.ecobee.com/token.
# Other endpoints are versioned and appear to work correctly.

#todo
#


# -------------------- START OF SUBROUTINES --------------------
# --------------------------------------------------------------

our %rest;
$rest{authorize}         = "/authorize";
$rest{token}             = "/token";
$rest{thermostat}        = "/1/thermostat";
$rest{thermostatSummary} = "/1/thermostatSummary";
$rest{runtimeReport}     = "/1/runtimeReport";
$rest{group}             = "/1/group";

sub new {
    my ( $class, $api_key, $poll_interval, $port_name, $url ) = @_;
    my $self = {};
    $port_name       = 'Ecobee'                                      if !$port_name;
    $url             = "https://api.ecobee.com"                      if !$url;
    $poll_interval   = 60                                            if !$poll_interval;
    $api_key         = $::config_parms{ $port_name . "_api_key" } if !$api_key;
    $$self{port_name}         = $port_name;
    $$self{url}               = $url;
    $$self{poll_interval}     = $poll_interval;
    $$self{api_key}           = $api_key;
    $$self{data}              = undef;
    $$self{ready}             = 0;
    $$self{data}->{retry}     = 0;
    $$self{debug}             = 1;
    $$self{loglevel}          = 1;
    $$self{timeout}           = 15;
    $$self{polling_timer}     = new Timer;
    $$self{auth_check_timer}  = new Timer;
    $$self{token_check_timer} = new Timer;
    bless $self, $class;
 
    $self->restore_data('access_token','refresh_token');
    $self->_init();
    return $self;
}

# This is called every time the timer time elapses
sub _poll_check {
    my ($self) = @_;

    main::print_log("[Ecobee] _poll_check initiated");
    #main::run (sub {&Venstar_Colortouch::get_data($self)}); #spawn this off to run in the background
    $self->get_data();
}

sub get_data {
    my ($self) = @_;

    main::print_log("[Ecobee] get_data initiated");
    $self->poll;
    $self->process_data;
}

sub _init {
    my ($self) = @_;

    # Start a timer to check if we are authenticated
    my $action = sub { $self->_check_auth() };
    $$self{auth_check_timer}->set(1, $action);
}

# We need to do this asynchronously so we don't block execution that blocks the saved tokens from being restored
sub _check_auth {
   my ($self) = @_;
   #$$self{access_token} = undef;
   #$$self{refresh_token} = undef;
   # Check if we have cached access and refresh tokens
   if ((defined $$self{access_token}) && (defined $$self{refresh_token})) { 
       if (($$self{access_token} eq '') || ($$self{refresh_token} eq '')) {
          # The access_token or refresh_token are missing. Tell the user and wait
          main::print_log( "[Ecobee] Error: Missing tokens. Please reauthenticate the API key with the Ecobee portal");
          $self->_request_pin_auth();
       } else {
          # Ok, we have tokens. Make sure they are current, then go get the initial state of the device, then start the time to look for updates
          main::print_log( "[Ecobee] We have tokens, lets proceed");
          $self->_thermostat_summary();
          $self->_list_thermostats();
          #$self->print_devices();
          main::print_log( "[Ecobee] Office temp is " . $self->get_temp("Monet Thermostat", "Office") );
          # The basic details should be populated now so we can start to poll
          $$self{ready} = 1;
          my $action = sub { $self->_poll() };
          $$self{polling_timer}->set($$self{poll_interval}, $action);
       }
    } else {
       # If we don't have tokens, we need the user to request a PIN and we need to wait until they request it
       # The access_token or refresh_token are undefined. This is probably the first run. Tell the user and wait
       main::print_log( "[Ecobee] Error: Token variables undefined. Please authenticate the PIN with the Ecobee portal. A request for a new PIN will follow this message.");
       $self->_request_pin_auth();
    }
    # If we have tokens, go get the initial state of the device, then start the time to look for updates

}


# We don't have a valid set of tokens, so request a new PIN
sub _request_pin_auth {
    my ($self) = @_;
    my ($isSuccessResponse1, $keyparams) = $self->_get_JSON_data("GET", "authorize", "?response_type=ecobeePin&client_id=" . $$self{api_key} . "&scope=smartWrite");
    if (!$isSuccessResponse1) {
       # something has gone wrong, we should probably exit
       main::print_log( "[Ecobee]: Error, failed to get PIN! Have you entered a valid API key?");
    } else {
       # print the PIN to the log so the user knows what to enter
       main::print_log( "[Ecobee]: New PIN generated ->" . $keyparams->{ecobeePin} . "<-. You have " . $keyparams->{expires_in} . " minutes to add a new application with this PIN on the Ecobee website!");
       # loop until the user enters the PIN or the code expires
       my $action = sub { $self->_wait_for_tokens($keyparams->{ecobeePin},$keyparams->{code}, $keyparams->{interval}) };
       $$self{token_check_timer}->set($keyparams->{interval}, $action);
    }
}

# Poll for tokens
sub _wait_for_tokens {
    my ($self, $pin, $code, $interval) = @_;
    # check for token 
    my ($isSuccessResponse1, $tokenparams) = $self->_get_JSON_data("POST", "token", "?grant_type=ecobeePin&code=" . $code . "&client_id=" . $$self{api_key});
    if ($isSuccessResponse1 && defined $tokenparams->{access_token} && defined $tokenparams->{refresh_token}) {
       # save tokens
       $$self{access_token} = $tokenparams->{access_token};
       $$self{refresh_token} = $tokenparams->{refresh_token};
       $self->_check_auth();
    }
    # If expired, get a new PIN and start over
    if (defined $tokenparams->{error}) {
       if ($tokenparams->{error} eq "authorization_expired") {
          main::print_log( "[Ecobee]: Warning, PIN has expired, requesting new PIN." );
          $self->_request_pin_auth();
       } elsif ($tokenparams->{error} eq "authorization_pending") {
          main::print_log( "[Ecobee]: Authorization is still pending. Please add a new application with PIN ->" . $pin . "<- on Ecobee website before it expires." );
          my $action = sub { $self->_wait_for_tokens($pin, $code, $interval) };
          $$self{token_check_timer}->set($interval, $action);
       }
    } 
}

# We need to periodically refresh the tokens when they expire
sub _refresh_tokens {
    my ($self) = @_;
    main::print_log( "[Ecobee]: Refreshing tokens" );
    my ($isSuccessResponse1, $tokenparams) = $self->_get_JSON_data("POST", "token", "?grant_type=refresh_token&refresh_token=" . $$self{refresh_token} . "&client_id=" . $$self{api_key});
    if ($isSuccessResponse1) {
       main::print_log( "[Ecobee]: Refresh token response looks good" );
       $$self{access_token} = $tokenparams->{access_token};
       $$self{refresh_token} = $tokenparams->{refresh_token};
    } else {
       # We need to handle the case where the refresh token has expired and start a new PIN authorization request.
       main::print_log( "[Ecobee]: Uh, oh... Something went wrong with the refresh token request" );
       # It looks like the tokens are FUBAR. We need to re-authenticate
       $$self{access_token} = undef;
       $$self{refresh_token} = undef;
    }
}


=item C<_list_thermostats()>

Collects the initial settings and parameters for each device on the Ecobee account. 

=cut

sub _list_thermostats {
    my ($self) = @_;
    main::print_log( "[Ecobee]: Listing thermostats..." );
    my $headers = HTTP::Headers->new(
        'Content-Type' => 'text/json',
        'Authorization' => 'Bearer ' . $$self{access_token}
        );
    my $json_body = '{"selection":{"selectionType":"registered","selectionMatch":"","includeAlerts":"true","includeSettings":"true","includeEvents":"true","includeRuntime":"true","includeSensors":"true"}}';
    my ($isSuccessResponse1, $thermoparams) = $self->_get_JSON_data("GET", "thermostat", 
       '?format=json&body=' . uri_escape($json_body), $headers);
    if ($isSuccessResponse1) {
       main::print_log( "[Ecobee]: Thermostat response looks good." );
       foreach my $device (@{$thermoparams->{thermostatList}}) {
           # we need to inspect the runtime and remoteSensors
           foreach my $key (keys %{$device->{runtime}}) {
              $$self{data}{devices}{$device->{identifier}}{runtime}{$key} = $device->{runtime}{$key};
           }

           foreach my $index (@{$device->{remoteSensors}}) {
              # Since this is an array, the sensor order can vary. We need to save these into hashes so they can be indexed by ID
              $$self{data}{devices}{$device->{identifier}}{remoteSensorsHash}{$index->{id}}{id} = $index->{id};
              $$self{data}{devices}{$device->{identifier}}{remoteSensorsHash}{$index->{id}}{name} = $index->{name};
              $$self{data}{devices}{$device->{identifier}}{remoteSensorsHash}{$index->{id}}{type} = $index->{type};
              $$self{data}{devices}{$device->{identifier}}{remoteSensorsHash}{$index->{id}}{inUse} = $index->{inUse};
              foreach my $capability (@{$index->{capability}}) {
                 # capabilities can vary by sensor type
                 $$self{data}{devices}{$device->{identifier}}{remoteSensorsHash}{$index->{id}}{capability}{$capability->{id}}{id} = $capability->{id};
                 $$self{data}{devices}{$device->{identifier}}{remoteSensorsHash}{$index->{id}}{capability}{$capability->{id}}{type} = $capability->{type};
                 $$self{data}{devices}{$device->{identifier}}{remoteSensorsHash}{$index->{id}}{capability}{$capability->{id}}{value} = $capability->{value};
              }
           }
           # We need to do this for the configs and other stuff as well in this function
           main::print_log( "[Ecobee]: " . $$self{data}{devices}{$device->{identifier}}{name} . " ID is " . $$self{data}{devices}{$device->{identifier}}{identifier} );
       }
    } else {
       main::print_log( "[Ecobee]: Uh, oh... Something went wrong with the thermostat list request" );
    }
}


=item C<_get_runtime_with_sensors()>

Gets the runtime and sensor data

=cut

sub _get_runtime_with_sensors {
    my ($self) = @_;
    main::print_log( "[Ecobee]: Getting runtime and sensor data..." );
    my $headers = HTTP::Headers->new(
        'Content-Type' => 'text/json',
        'Authorization' => 'Bearer ' . $$self{access_token}
        );
    my $json_body = '{"selection":{"selectionType":"registered","selectionMatch":"","includeRuntime":"true","includeSensors":"true"}}';
    my ($isSuccessResponse1, $thermoparams) = $self->_get_JSON_data("GET", "thermostat",
       '?format=json&body=' . uri_escape($json_body), $headers);
    if ($isSuccessResponse1) {
       main::print_log( "[Ecobee]: Runtime response looks good." );
       foreach my $device (@{$thermoparams->{thermostatList}}) {
           # we need to inspect the runtime and remoteSensors
           foreach my $key (keys %{$device->{runtime}}) {
              if ($device->{runtime}{$key} ne $$self{data}{devices}{$device->{identifier}}{runtime}{$key}) {
                 main::print_log( "[Ecobee]: runtime parameter " . $key . " has changed from " . $$self{data}{devices}{$device->{identifier}}{runtime}{$key} . " to " . $device->{runtime}{$key});
              }
              $$self{data}{devices}{$device->{identifier}}{runtime}{$key} = $device->{runtime}{$key};
           }
           foreach my $index (@{$device->{remoteSensors}}) {
              # Since this is an array, the sensor order can vary. We need to save these into hashes so they can be indexed by ID
              $$self{data}{devices}{$device->{identifier}}{remoteSensorsHash}{$index->{id}}{id} = $index->{id};
              $$self{data}{devices}{$device->{identifier}}{remoteSensorsHash}{$index->{id}}{name} = $index->{name};
              $$self{data}{devices}{$device->{identifier}}{remoteSensorsHash}{$index->{id}}{type} = $index->{type};
              if (defined $$self{data}{devices}{$device->{identifier}}{remoteSensorsHash}{$index->{id}}{inUse}) {
                 if ($$self{data}{devices}{$device->{identifier}}{remoteSensorsHash}{$index->{id}}{inUse} ne $index->{inUse}) {
                    main::print_log( "[Ecobee]: " . $$self{data}{devices}{$device->{identifier}}{remoteSensorsHash}{$index->{id}}{name} . " (id " . $$self{data}{devices}{$device->{identifier}}{remoteSensorsHash}{$index->{id}}{id} . ") has changed from " . $$self{data}{devices}{$device->{identifier}}{remoteSensorsHash}{$index->{id}}{inUse} . " to " . $index->{inUse} );
                 }
              }
              $$self{data}{devices}{$device->{identifier}}{remoteSensorsHash}{$index->{id}}{inUse} = $index->{inUse};
              foreach my $capability (@{$index->{capability}}) {
                 # capabilities can vary by sensor type
                 $$self{data}{devices}{$device->{identifier}}{remoteSensorsHash}{$index->{id}}{capability}{$capability->{id}}{id} = $capability->{id};
                 $$self{data}{devices}{$device->{identifier}}{remoteSensorsHash}{$index->{id}}{capability}{$capability->{id}}{type} = $capability->{type};
                 if (defined $$self{data}{devices}{$device->{identifier}}{remoteSensorsHash}{$index->{id}}{capability}{$capability->{id}}{value}) {
                    if ($$self{data}{devices}{$device->{identifier}}{remoteSensorsHash}{$index->{id}}{capability}{$capability->{id}}{value} ne $capability->{value}) {
                       main::print_log( "[Ecobee]: " . $$self{data}{devices}{$device->{identifier}}{remoteSensorsHash}{$index->{id}}{name} . " (id " . $$self{data}{devices}{$device->{identifier}}{remoteSensorsHash}{$index->{id}}{id} . ":" . $capability->{id} . ") has changed from " . $$self{data}{devices}{$device->{identifier}}{remoteSensorsHash}{$index->{id}}{capability}{$capability->{id}}{value} . " to " . $capability->{value} );
                    }
                 }
                 $$self{data}{devices}{$device->{identifier}}{remoteSensorsHash}{$index->{id}}{capability}{$capability->{id}}{value} = $capability->{value};
              }
           }
           main::print_log( "[Ecobee]: " . $$self{data}{devices}{$device->{identifier}}{name} . " ID is " . $$self{data}{devices}{$device->{identifier}}{identifier} );
       }
    } else {
       main::print_log( "[Ecobee]: Uh, oh... Something went wrong with the runtime and sensor request" );
    }
}


=item C<_thermostat_summary()>

Collects the revision numbers from each device on the Ecobee account. Changes to the revision number tell us that something
has changed, and we need to request an update.

=cut

sub _thermostat_summary {
    my ($self) = @_;
    main::print_log( "[Ecobee]: Getting thermostat summary..." );
    my $headers = HTTP::Headers->new(
        'Content-Type' => 'text/json',
        'Authorization' => 'Bearer ' . $$self{access_token}
        );
    my $json_body = '{"selection":{"selectionType":"registered","selectionMatch":"","includeEquipmentStatus":true}}';
    my ($isSuccessResponse1, $thermoparams) = $self->_get_JSON_data("GET", "thermostatSummary", 
       '?json=' . uri_escape($json_body), $headers);
    if ($isSuccessResponse1) {
       main::print_log( "[Ecobee]: Thermostat response looks good. Found " . $thermoparams->{thermostatCount} . " thermostats" );
       foreach my $device (@{$thermoparams->{revisionList}}) {
          # format:
          # identifier:name:connected:thermoRev:alertsRev:runtimeRev:intervalRev
          # Example line:
          # 123456789101:MyStat:true:071223012334:080102000000:080102000000
          my @values = split(':',$device);
          $$self{data}{devices}{$values[0]}{identifier} = $values[0];
          $$self{data}{devices}{$values[0]}{name} = $values[1];

          if (defined $$self{data}{devices}{$values[0]}{connected}) {
             if ($$self{data}{devices}{$values[0]}{connected} ne $values[2]) {
                # This tells us if we are connected to the Ecobee servers
                main::print_log( "[Ecobee]: connected has changed from " . $$self{data}{devices}{$values[0]}{connected} . " to " . $values[2] );
             }
          }
          $$self{data}{devices}{$values[0]}{connected} = $values[2];

          if (defined $$self{data}{devices}{$values[0]}{thermoRev}) {
             if ($$self{data}{devices}{$values[0]}{thermoRev} != $values[3]) {   
                # This tells us that the thermostat program, hvac mode, settings or configuration has changed
                main::print_log( "[Ecobee]: thermoRev has changed from " . $$self{data}{devices}{$values[0]}{thermoRev} . " to " . $values[3] );
             }
          }
          $$self{data}{devices}{$values[0]}{thermoRev} = $values[3];

          if (defined $$self{data}{devices}{$values[0]}{alertsRev}) {
             if ($$self{data}{devices}{$values[0]}{alertsRev} != $values[4]) {
                # This tells us of a new alert is issued or an alert is modified (acked)
                main::print_log( "[Ecobee]: alertsRev has changed from " . $$self{data}{devices}{$values[0]}{alertsRev} . " to " . $values[4] );
             }
          }
          $$self{data}{devices}{$values[0]}{alertsRev} = $values[4];

          if (defined $$self{data}{devices}{$values[0]}{runtimeRev}) {
             if ($$self{data}{devices}{$values[0]}{runtimeRev} != $values[5]) {
                # This tells us when the thermostat has sent a new status message, or the equipment state or remote sensor readings have changed
                main::print_log( "[Ecobee]: runtimeRev has changed from " . $$self{data}{devices}{$values[0]}{runtimeRev} . " to " . $values[5] );
                $self->_get_runtime_with_sensors();
             }
          }
          $$self{data}{devices}{$values[0]}{runtimeRev} = $values[5];

          if (defined $$self{data}{devices}{$values[0]}{intervalRev}) {
             if ($$self{data}{devices}{$values[0]}{intervalRev} != $values[6]) {
                # This tells us that the thermostat has sent a new status message (every 15 minutes)
                main::print_log( "[Ecobee]: intervalRev has changed from " . $$self{data}{devices}{$values[0]}{intervalRev} . " to " . $values[6] );
             }
          }
          $$self{data}{devices}{$values[0]}{intervalRev} = $values[6];

          #main::print_log( "[Ecobee]: " . $$self{data}{devices}{$values[0]}{name} . " ID is " . $$self{data}{devices}{$values[0]}{identifier} .
          #     " connected is " . $$self{data}{devices}{$values[0]}{connected} );
       }
       # update the status for each device
       foreach my $device (@{$thermoparams->{statusList}}) {
          my %default_status = (
              'heatPump'     => 0, 
              'heatPump2'    => 0,
              'heatPump3'    => 0, 
              'compCool1'    => 0, 
              'compCool2'    => 0, 
              'auxHeat1'     => 0, 
              'auxHeat2'     => 0, 
              'auxHeat3'     => 0, 
              'fan'          => 0, 
              'humidifier'   => 0, 
              'dehumidifier' => 0, 
              'ventilator'   => 0, 
              'economizer'   => 0, 
              'compHotWater' => 0, 
              'auxHotWater'  => 0
          );
          my @values = split(':',$device);
          # we probably need to notify something if one of these changes
          $$self{data}{devices}{$values[0]}{status} = \%default_status;
          if (scalar @values > 1) {
              foreach my $index (1..$#values) {
                 $$self{data}{devices}{$values[0]}{status}{$values[$index]} = 1;
              }
          }
          #main::print_log( "[Ecobee]: " . $$self{data}{devices}{$values[0]}{name} . " fan is " . $$self{data}{devices}{$values[0]}{status}{fan} );
       }
    } else {
       main::print_log( "[Ecobee]: Uh, oh... Something went wrong with the thermostat list request" );
    }
}


sub _poll {
    my ($self) = @_;
    if ($$self{ready}) {
        $self->_thermostat_summary();
    }
    # reset the timer
    my $action = sub { $self->_poll() };
    $$self{polling_timer}->set($$self{poll_interval}, $action);
}

#------------------------------------------------------------------------------------
sub _get_JSON_data {
    my ( $self, $type, $endpoint, $args, $headers) = @_;

    my $ua = new LWP::UserAgent();
    $ua->timeout( $$self{timeout} );

    my $url = $$self{url};

    my $request = HTTP::Request->new( $type, $url . $rest{$endpoint} . $args, $headers );
    main::print_log( "[Ecobee]: Full request ->" . $request->as_string . "<-") if $$self{debug};

    my $responseObj = $ua->request($request);
    print $responseObj->content . "\n--------------------\n" if $$self{debug};

    my $responseCode = $responseObj->code;
    print 'Response code: ' . $responseCode . "\n" if $$self{debug};
    my $isSuccessResponse = $responseCode < 400;

    my $response;
    eval { $response = JSON::XS->new->decode( $responseObj->content ); };

    # catch crashes:
    if ($@) {
        print "[Ecobee]: ERROR! JSON parser crashed! $@\n";
        return ('0');
    }
    else {
        if ( !$isSuccessResponse ) {
            if (($endpoint eq "token") && ($responseCode == 401)) {
               # Don't bother printing an error as this is expected, because the user hasn't entered the PIN yet
            } elsif (($responseCode == 500) && (defined $response->{status}->{code})) {
                if ($response->{status}->{code} == 14) {
                    # Our tokens have expired, we must refresh them and try again
                    $self->_refresh_tokens();
                    # Update the token in the header first
                    $headers->header('Authorization' => 'Bearer ' . $$self{access_token});
                    return $self->_get_JSON_data($type, $endpoint, $args, $headers);
                } else {
                    main::print_log( "[Ecobee]: Warning, failed to get data. Response code $responseCode, error code " . $response->{status}->{code});
                }
            } else {
               main::print_log( "[Ecobee]: Warning, failed to get data. Response code $responseCode");
            } 
        }
        else {
           main::print_log( "[Ecobee]: Got a valid response.");
        }

        return ( $isSuccessResponse, $response );
    }
}


sub stop_timer {
    my ($self) = @_;

    if ( defined $self->{timer} ) {
        $self->{timer}->stop() if ( $self->{timer}->active() );
    }
    else {
        main::print_log( "[Venstar Colortouch:"
              . $self->{data}->{name}
              . "] Warning, stop_timer called but timer undefined" );
    }
}

sub start_timer {
    my ($self) = @_;

    if ( defined $self->{timer} ) {
        $self->{timer}->set( $self->{config}->{poll_seconds},
            sub { &Venstar_Colortouch::_poll_check($self) }, -1 );
    }
    else {
        main::print_log( "[Venstar Colortouch:"
              . $self->{data}->{name}
              . "] Warning, start_timer called but timer undefined" );
    }
}


#------------
# User access methods


=item C<print_devices()>

Prints the name and id of all devices found in the Ecobee account.

=cut

sub print_devices {
    my ($self) = @_;
    my $output = "The list of devices reported by Ecobee is:\n";
    foreach my $key (keys %{ $$self{data}{devices} } ) {
       $output .= "            Name:" . $$self{data}{devices}{$key}{name} . " ID: " . $$self{data}{devices}{$key}{identifier} . "\n";
    }
    $self->debug($output);
}

sub get_temp {
    my ($self,$device,$name) = @_;
    # Get the id of the given device
    my $d_id;
    foreach my $key (keys %{$$self{data}{devices}}) {
       if ($$self{data}{devices}{$key}{name} eq $device) {
          $d_id = $key;
          last;
       }
    }
    if ($d_id) {
       foreach my $key (keys %{$$self{data}{devices}{$d_id}{remoteSensorsHash}}) {
          if ($$self{data}{devices}{$d_id}{remoteSensorsHash}{$key}{name} eq $name) {
             return $$self{data}{devices}{$d_id}{remoteSensorsHash}{$key}{capability}{1}{value};
          }
       } 
       return 0;
    } else {
       return 0;
    }
}

#------------
# User control methods


1;
