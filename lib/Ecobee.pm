
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
  CODE, $ecobee_thermo = new Ecobee_Thermostat('First floor', $ecobee); #noloop
  CODE, $thermo_humid = new Ecobee_Thermo_Humidity($ecobee_thermo); #noloop
  CODE, $thermo_hvac_status = new Ecobee_Thermo_HVAC_Status($ecobee_thermo); #noloop
  CODE, $thermo_mode = new Ecobee_Thermo_Mode($ecobee_thermo); #noloop
  CODE, $thermo_climate = new Ecobee_Thermo_Climate($ecobee_thermo); #noloop

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

# Notes:
#
# As of 1/31/2016 some API examples using cURL incorrectly show the authorize and token
# endpoints as https://api.ecobee.com/1/authorize and https://api.ecobee.com/1/token.
# However, these are actually https://api.ecobee.com/authorize and https://api.ecobee.com/token.
# Other endpoints are versioned and appear to work correctly.

#todo
#
# -Child items that are registered for state changes are currently only updated after the
#  state changes post-initialization, and are are left at a default value on startup until
#  this happens
#
# -Add support for creating and cancelling vacations
#
# -Add support for creating/deleting/modifying climate settings
#
# -Reduce logging verbosity and use consistant logging format

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

@Ecobee_Interface::ISA = ( 'Generic_Item', 'Ecobee' );

use strict;
use warnings;

use LWP::UserAgent;
use HTTP::Request::Common qw(POST);
use JSON::XS;
use Data::Dumper;
use URI::Escape;
use Storable 'dclone';

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
    $port_name     = 'Ecobee'                                   if !$port_name;
    $url           = "https://api.ecobee.com"                   if !$url;
    $poll_interval = 60                                         if !$poll_interval;
    $api_key       = $::config_parms{ $port_name . "_api_key" } if !$api_key;
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

    $self->restore_data( 'access_token', 'refresh_token' );
    $self->_init();
    return $self;
}

sub _init {
    my ($self) = @_;

    # Start a timer to check if we are authenticated
    my $action = sub { $self->_check_auth() };
    $$self{auth_check_timer}->set( 1, $action );
}

# We need to do this asynchronously so we don't block execution that blocks the saved tokens from being restored
sub _check_auth {
    my ($self) = @_;

    #$$self{access_token} = undef;
    #$$self{refresh_token} = undef;
    # Check if we have cached access and refresh tokens
    if ( ( defined $$self{access_token} ) && ( defined $$self{refresh_token} ) ) {
        if ( ( $$self{access_token} eq '' ) || ( $$self{refresh_token} eq '' ) ) {

            # The access_token or refresh_token are missing. Tell the user and wait
            $self->debug("Error: Missing tokens. Please reauthenticate the API key with the Ecobee portal");
            $self->_request_pin_auth();
        }
        else {
            # Ok, we have tokens. Make sure they are current, then go get the initial state of the device, then start the time to look for updates
            $self->debug("We have tokens, lets proceed");
            $self->_thermostat_summary();    # This populates the revision numbers and operating state
            $self->_list_thermostats();      # This gets the full initial state of each thermostat
            $self->_get_groups();            # This gets the groups, their settings and the associated thermostats in each group

            ####
            # Testing functions here. These will be removed eventually
            ##
            #$self->print_devices();
            #main::print_log( "[Ecobee] actualTemperature is " . sprintf("%.1f", $self->get_temp("Monet Thermostat", "actualTemperature")/10) . " degrees F" );
            #main::print_log( "[Ecobee] desiredHeat is " . sprintf("%.1f", $self->get_desired_comfort("Monet Thermostat", "Heat")/10) . " degrees F" );
            #main::print_log( "[Ecobee] desiredCool is " . sprintf("%.1f", $self->get_desired_comfort("Monet Thermostat", "Cool")/10) . " degrees F" );
            #main::print_log( "[Ecobee] Office temp is " . sprintf("%.1f", $self->get_temp("Monet Thermostat", "Office")/10) . " degrees F" );
            #main::print_log( "[Ecobee] actualHumidity is " . $self->get_humidity("Monet Thermostat", "actualHumidity") . "%");
            #main::print_log( "[Ecobee] desiredHumidity is " . $self->get_desired_comfort("Monet Thermostat", "Humidity") . "%");
            #main::print_log( "[Ecobee] Humidity is " . $self->get_humidity("Monet Thermostat", "Monet Thermostat") . "%");
            #main::print_log( "[Ecobee] hvacMode is " . $self->get_setting("Monet Thermostat", "hvacMode") );
            #my $alerts = $self->get_alert("Monet Thermostat");
            #if ($alerts) {
            #   foreach my $key (keys %{$alerts}) {
            #      main::print_log( "[Ecobee] Alert " . $key . ": (\"" . $alerts->{$key}{text} . "\")" );
            #   }
            #}
            #my $events = $self->get_event("Monet Thermostat");
            #if ($events) {
            #   foreach my $key (keys %{$events}) {
            #      main::print_log( "[Ecobee] Event: $key" );
            #   }
            #}
            ####

            # The basic details should be populated now so we can start to poll
            $self->populate_monitor_hash( $$self{monitor} );
            $$self{ready} = 1;
            my $action = sub { $self->_poll() };
            $$self{polling_timer}->set( $$self{poll_interval}, $action );
        }
    }
    else {
        # If we don't have tokens, we need to get a PIN and wait until they user registers it
        # The access_token or refresh_token are undefined. This is probably the first run. Tell the user and wait
        $self->debug("Error: Token variables undefined. Please authenticate the PIN with the Ecobee portal. A request for a new PIN will follow this message.");
        $self->_request_pin_auth();
    }

    # If we have tokens, go get the initial state of the device, then start the time to look for updates

}

# We don't have a valid set of tokens, so request a new PIN
sub _request_pin_auth {
    my ($self) = @_;
    my ( $isSuccessResponse1, $keyparams ) =
      $self->_get_JSON_data( "GET", "authorize", "?response_type=ecobeePin&client_id=" . $$self{api_key} . "&scope=smartWrite" );
    if ( !$isSuccessResponse1 ) {

        # something has gone wrong, we should probably exit
        main::print_log("[Ecobee]: Error, failed to get PIN! Have you entered a valid API key?");
    }
    else {
        # print the PIN to the log so the user knows what to enter
        main::print_log( "[Ecobee]: New PIN generated ->"
              . $keyparams->{ecobeePin}
              . "<-. You have "
              . $keyparams->{expires_in}
              . " minutes to add a new application with this PIN on the Ecobee website!" );

        # loop until the user enters the PIN or the code expires
        my $action = sub {
            $self->_wait_for_tokens( $keyparams->{ecobeePin}, $keyparams->{code}, $keyparams->{interval} );
        };
        $$self{token_check_timer}->set( $keyparams->{interval}, $action );
    }
}

# Poll for tokens
sub _wait_for_tokens {
    my ( $self, $pin, $code, $interval ) = @_;

    # check for token
    my ( $isSuccessResponse1, $tokenparams ) =
      $self->_get_JSON_data( "POST", "token", "?grant_type=ecobeePin&code=" . $code . "&client_id=" . $$self{api_key} );
    if (   $isSuccessResponse1
        && defined $tokenparams->{access_token}
        && defined $tokenparams->{refresh_token} )
    {
        # save tokens
        $$self{access_token}  = $tokenparams->{access_token};
        $$self{refresh_token} = $tokenparams->{refresh_token};
        $self->_check_auth();
    }

    # If expired, get a new PIN and start over
    if ( defined $tokenparams->{error} ) {
        if ( $tokenparams->{error} eq "authorization_expired" ) {
            main::print_log("[Ecobee]: Warning, PIN has expired, requesting new PIN.");
            $self->_request_pin_auth();
        }
        elsif ( $tokenparams->{error} eq "authorization_pending" ) {
            main::print_log(
                "[Ecobee]: Authorization is still pending. Please add a new application with PIN ->" . $pin . "<- on Ecobee website before it expires." );
            my $action = sub { $self->_wait_for_tokens( $pin, $code, $interval ) };
            $$self{token_check_timer}->set( $interval, $action );
        }
    }
}

# We need to periodically refresh the tokens when they expire
sub _refresh_tokens {
    my ($self) = @_;
    $self->debug("Refreshing tokens");
    my ( $isSuccessResponse1, $tokenparams ) =
      $self->_get_JSON_data( "POST", "token", "?grant_type=refresh_token&refresh_token=" . $$self{refresh_token} . "&client_id=" . $$self{api_key} );
    if ($isSuccessResponse1) {
        $self->debug("Refresh token response looks good");
        $$self{access_token}  = $tokenparams->{access_token};
        $$self{refresh_token} = $tokenparams->{refresh_token};
    }
    else {
        # We need to handle the case where the refresh token has expired and start a new PIN authorization request.
        main::print_log("[Ecobee]: Uh, oh... Something went wrong with the refresh token request. Flushing tokens and requesting a new PIN");

        # It looks like the tokens are FUBAR. We need to re-authenticate
        $$self{access_token}  = undef;
        $$self{refresh_token} = undef;
        $$self{ready}         = 0;       # This disables polling until the issue can be corrected
        $self->_request_pin_auth();
    }
}

=item C<_list_thermostats()>

Collects the initial settings and parameters for each device on the Ecobee account. 

=cut

sub _list_thermostats {
    my ($self) = @_;
    $self->debug("Listing thermostats...");
    my $headers = HTTP::Headers->new(
        'Content-Type'  => 'text/json',
        'Authorization' => 'Bearer ' . $$self{access_token}
    );
    my $json_body =
      '{"selection":{"selectionType":"registered","selectionMatch":"","includeAlerts":"true","includeSettings":"true","includeEvents":"true","includeRuntime":"true","includeSensors":"true","includeProgram":"true"}}';
    my ( $isSuccessResponse1, $thermoparams ) = $self->_get_JSON_data( "GET", "thermostat", '?format=json&body=' . uri_escape($json_body), $headers );
    if ($isSuccessResponse1) {
        $self->debug("Thermostat response looks good.");
        foreach my $device ( @{ $thermoparams->{thermostatList} } ) {

            # we need to inspect the runtime and remoteSensors
            foreach my $key ( keys %{ $device->{runtime} } ) {
                $$self{data}{devices}{ $device->{identifier} }{runtime}{$key} =
                  $device->{runtime}{$key};
            }

            foreach my $index ( @{ $device->{remoteSensors} } ) {

                # Since this is an array, the sensor order can vary. We need to save these into hashes so they can be indexed by ID
                $$self{data}{devices}{ $device->{identifier} }{remoteSensorsHash}{ $index->{id} }{id}    = $index->{id};
                $$self{data}{devices}{ $device->{identifier} }{remoteSensorsHash}{ $index->{id} }{name}  = $index->{name};
                $$self{data}{devices}{ $device->{identifier} }{remoteSensorsHash}{ $index->{id} }{type}  = $index->{type};
                $$self{data}{devices}{ $device->{identifier} }{remoteSensorsHash}{ $index->{id} }{inUse} = $index->{inUse};
                foreach my $capability ( @{ $index->{capability} } ) {

                    # capabilities can vary by sensor type
                    $$self{data}{devices}{ $device->{identifier} }{remoteSensorsHash}{ $index->{id} }{capability}{ $capability->{id} }{id} = $capability->{id};
                    $$self{data}{devices}{ $device->{identifier} }{remoteSensorsHash}{ $index->{id} }{capability}{ $capability->{id} }{type} =
                      $capability->{type};
                    $$self{data}{devices}{ $device->{identifier} }{remoteSensorsHash}{ $index->{id} }{capability}{ $capability->{id} }{value} =
                      $capability->{value};
                }
            }

            # We need to do this for the settings as well
            foreach my $key ( keys %{ $device->{settings} } ) {
                $$self{data}{devices}{ $device->{identifier} }{settings}{$key} =
                  $device->{settings}{$key};
            }

            # Get the Alerts (provided as a JSON array)
            foreach my $index ( @{ $device->{alerts} } ) {
                foreach my $key ( keys %{$index} ) {
                    $$self{data}{devices}{ $device->{identifier} }{alertsHash}{ $index->{acknowledgeRef} }{$key} = $index->{$key};
                }
            }

            # We also need to get the Events (provided as a JSON array, but does not contain a unique ID so we have to create our own to make this a hash)
            foreach my $index ( @{ $device->{events} } ) {
                if ( exists $index->{holdClimateRef} ) {
                    $$self{data}{devices}{ $device->{identifier} }{eventsHash}{ $index->{type} . "-" . $index->{name} . "-" . $index->{holdClimateRef} } =
                      $index;
                }
                else {
                    $$self{data}{devices}{ $device->{identifier} }{eventsHash}{ $index->{type} . "-" . $index->{name} } = $index;
                }
            }

            # set to empty so we don't crash on dclone
            if ( scalar @{ $device->{events} } == 0 ) {
                my $non_event = { 'none' => { 'holdClimateRef' => 'none' } };
                $$self{data}{devices}{ $device->{identifier} }{eventsHash} =
                  $non_event;
            }

            # Save the program information as well. Note: the schedule and climate info are stored in arrays. Since we need to use this same format to
            # modify a schedule or climate, they will be retained in this format
            $$self{data}{devices}{ $device->{identifier} }{program} =
              $device->{program};

            $self->debug( $$self{data}{devices}{ $device->{identifier} }{name} . " ID is " . $$self{data}{devices}{ $device->{identifier} }{identifier} );
        }
    }
    else {
        main::print_log("[Ecobee]: Uh, oh... Something went wrong with the thermostat list request");
    }
}

=item C<_get_settings()>

Gets the current settings, events and program

=cut

sub _get_settings {
    my ($self) = @_;
    $self->debug("Getting settings, events and programs...");
    my $headers = HTTP::Headers->new(
        'Content-Type'  => 'text/json',
        'Authorization' => 'Bearer ' . $$self{access_token}
    );
    my $json_body = '{"selection":{"selectionType":"registered","selectionMatch":"","includeSettings":"true","includeEvents":"true","includeProgram":"true"}}';
    my ( $isSuccessResponse1, $thermoparams ) = $self->_get_JSON_data( "GET", "thermostat", '?format=json&body=' . uri_escape($json_body), $headers );
    if ($isSuccessResponse1) {
        $self->debug("Settings response looks good.");

        # We just asked for the settings this time
        foreach my $device ( @{ $thermoparams->{thermostatList} } ) {

            # Save the previous settings
            $$self{prev_data}{devices}{ $device->{identifier} }{settings} =
              dclone $$self{data}{devices}{ $device->{identifier} }{settings};

            foreach my $key ( keys %{ $device->{settings} } ) {
                if ( $device->{settings}{$key} ne $$self{data}{devices}{ $device->{identifier} }{settings}{$key} ) {
                    $self->debug( "Settings parameter "
                          . $key
                          . " has changed from "
                          . $$self{data}{devices}{ $device->{identifier} }{settings}{$key} . " to "
                          . $device->{settings}{$key} );
                }
                $$self{data}{devices}{ $device->{identifier} }{settings}{$key} =
                  $device->{settings}{$key};
            }

            # Compare the old with the new
            $self->compare_data(
                $$self{data}{devices}{ $device->{identifier} }{settings},
                $$self{prev_data}{devices}{ $device->{identifier} }{settings},
                $$self{monitor}{ $device->{identifier} }{settings}
            );

            # Save the previous events
            $$self{prev_data}{devices}{ $device->{identifier} }{eventsHash} =
              dclone $$self{data}{devices}{ $device->{identifier} }{eventsHash};

            # create a temporary hash to compare current and previous events
            my $temp_events;
            foreach my $index ( @{ $device->{events} } ) {
                if ( exists $index->{holdClimateRef} ) {
                    $temp_events->{ $index->{type} . "-" . $index->{name} . "-" . $index->{holdClimateRef} } = $index;
                }
                else {
                    $temp_events->{ $index->{type} . "-" . $index->{name} } =
                      $index;
                }
            }

            # Look for new events
            foreach my $key ( keys %{$temp_events} ) {
                unless ( defined $$self{data}{devices}{ $device->{identifier} }{eventsHash}{$key} ) {
                    $self->debug("New event added: $key");
                    $$self{data}{devices}{ $device->{identifier} }{eventsHash}{$key} = $temp_events->{$key};
                    if ( exists $$self{data}{devices}{ $device->{identifier} }{eventsHash}{'none'} ) {

                        # delete the none event if there is a real one
                        delete $$self{data}{devices}{ $device->{identifier} }{eventsHash}{'none'};
                    }
                }
            }

            # Look for deleted events
            foreach my $key ( keys %{ $$self{data}{devices}{ $device->{identifier} }{eventsHash} } ) {
                unless ( defined $temp_events->{$key} || ( $key eq 'none' ) ) {
                    $self->debug("Event deleted: $key");
                    delete $$self{data}{devices}{ $device->{identifier} }{eventsHash}{$key};
                }
            }

            # set to null so we don't crash on dclone
            if ( scalar @{ $device->{events} } == 0 ) {
                my $non_event = { 'none' => { 'holdClimateRef' => 'none' } };
                $$self{data}{devices}{ $device->{identifier} }{eventsHash} =
                  $non_event;
            }

            # Compare the old with the new
            $self->compare_data(
                $$self{data}{devices}{ $device->{identifier} }{eventsHash},
                $$self{prev_data}{devices}{ $device->{identifier} }{eventsHash},
                $$self{monitor}{ $device->{identifier} }{eventsHash}
            );

            # Save the previous program data
            $$self{prev_data}{devices}{ $device->{identifier} }{program} =
              dclone $$self{data}{devices}{ $device->{identifier} }{program};

            # Save the new program data
            $$self{data}{devices}{ $device->{identifier} }{program} =
              $device->{program};

            if ( $$self{data}{devices}{ $device->{identifier} }{program}{currentClimateRef} ne
                $$self{prev_data}{devices}{ $device->{identifier} }{program}{currentClimateRef} )
            {
                $self->debug( "currentClimateRef has changed from "
                      . $$self{prev_data}{devices}{ $device->{identifier} }{program}{currentClimateRef} . " to "
                      . $$self{data}{devices}{ $device->{identifier} }{program}{currentClimateRef} );
            }

            # Compare the old with the new
            $self->compare_data(
                $$self{data}{devices}{ $device->{identifier} }{program},
                $$self{prev_data}{devices}{ $device->{identifier} }{program},
                $$self{monitor}{ $device->{identifier} }{program}
            );
        }
    }
    else {
        main::print_log("[Ecobee]: Uh, oh... Something went wrong with the settings request");
    }
}

=item C<_get_alerts()>

Gets the current alerts

=cut

sub _get_alerts {
    my ($self) = @_;
    $self->debug("Getting alerts...");
    my $headers = HTTP::Headers->new(
        'Content-Type'  => 'text/json',
        'Authorization' => 'Bearer ' . $$self{access_token}
    );
    my $json_body = '{"selection":{"selectionType":"registered","selectionMatch":"","includeAlerts":"true"}}';
    my ( $isSuccessResponse1, $thermoparams ) = $self->_get_JSON_data( "GET", "thermostat", '?format=json&body=' . uri_escape($json_body), $headers );
    if ($isSuccessResponse1) {
        $self->debug("Alerts response looks good.");

        # We just asked for the settings this time
        foreach my $device ( @{ $thermoparams->{thermostatList} } ) {

            # Save the previous alerts
            $$self{prev_data}{devices}{ $device->{identifier} }{alertsHash} =
              dclone $$self{data}{devices}{ $device->{identifier} }{alertsHash};

            # Look for events that have been acked and are no longer in the array
            foreach my $key ( keys %{ $$self{data}{devices}{ $device->{identifier} }{alertsHash} } ) {
                my $matched = 0;
                foreach my $index ( @{ $device->{alerts} } ) {
                    if ( $key eq $index->{acknowledgeRef} ) {
                        $matched = 1;
                    }
                }
                if ( !$matched ) {

                    # Alert has been acked
                    $self->debug( "Alert $key: (\"" . $$self{data}{devices}{ $device->{identifier} }{alertsHash}{$key}{text} . "\") has  been acked." );
                    delete $$self{data}{devices}{ $device->{identifier} }{alertsHash}{$key};
                }
            }
            foreach my $index ( @{ $device->{alerts} } ) {
                if ( defined $$self{data}{devices}{ $device->{identifier} }{alertsHash}{ $index->{acknowledgeRef} } ) {

                    # Do we need to see if something has changed? All of the alert properties should be static and the alert dissappears from the JSON array once acked.
                }
                else {
                    # This is a new alert
                    $self->debug( "A new alert " . $index->{acknowledgeRef} . ": (\"" . $index->{text} . "\") has been generated." );
                    $$self{data}{devices}{ $device->{identifier} }{alertsHash}{ $index->{acknowledgeRef} } = $index;
                }
            }

            # Compare the old with the new
            #$self->compare_data( $$self{data}{devices}{$device->{identifier}}{alertsHash}, $$self{prev_data}{devices}{$device->{identifier}}{alertsHash}, $$self{monitor}{alertsHash} );
        }
    }
    else {
        main::print_log("[Ecobee]: Uh, oh... Something went wrong with the alerts request");
    }
}

=item C<_get_groups()>

Gets the group and grouping data for thermostats

=cut

sub _get_groups {
    my ($self) = @_;
    $self->debug("Getting groups...");
    my $headers = HTTP::Headers->new(
        'Content-Type'  => 'text/json',
        'Authorization' => 'Bearer ' . $$self{access_token}
    );
    my $json_body = '{"selection":{"selectionType":"registered"}}';
    my ( $isSuccessResponse1, $groupparams ) = $self->_get_JSON_data( "GET", "group", '?format=json&body=' . uri_escape($json_body), $headers );
    if ($isSuccessResponse1) {
        $self->debug("Groups response looks good.");
        foreach my $group ( @{ $groupparams->{groups} } ) {

            # groupRef is the unique ID
            $$self{data}{groups}{ $group->{groupRef} } = $group;
        }
    }
    else {
        main::print_log("[Ecobee]: Uh, oh... Something went wrong with the groups request");
    }
}

=item C<_get_runtime_with_sensors()>

Gets the runtime and sensor data

=cut

sub _get_runtime_with_sensors {
    my ($self) = @_;
    $self->debug("Getting runtime and sensor data...");
    my $headers = HTTP::Headers->new(
        'Content-Type'  => 'text/json',
        'Authorization' => 'Bearer ' . $$self{access_token}
    );
    my $json_body = '{"selection":{"selectionType":"registered","selectionMatch":"","includeRuntime":"true","includeSensors":"true"}}';
    my ( $isSuccessResponse1, $thermoparams ) = $self->_get_JSON_data( "GET", "thermostat", '?format=json&body=' . uri_escape($json_body), $headers );
    if ($isSuccessResponse1) {
        $self->debug("Runtime response looks good.");

        foreach my $device ( @{ $thermoparams->{thermostatList} } ) {

            # Save the previous runtime
            $$self{prev_data}{devices}{ $device->{identifier} }{runtime} =
              dclone $$self{data}{devices}{ $device->{identifier} }{runtime};

            # we need to inspect the runtime and remoteSensors
            foreach my $key ( keys %{ $device->{runtime} } ) {
                if ( $device->{runtime}{$key} ne $$self{data}{devices}{ $device->{identifier} }{runtime}{$key} ) {
                    main::print_log( "[Ecobee]: runtime parameter "
                          . $key
                          . " has changed from "
                          . $$self{data}{devices}{ $device->{identifier} }{runtime}{$key} . " to "
                          . $device->{runtime}{$key} );
                }
                $$self{data}{devices}{ $device->{identifier} }{runtime}{$key} =
                  $device->{runtime}{$key};
            }

            # Compare the old with the new
            #main::print_log( "[Ecobee]: runtime monitor -pre-");
            #print "*** Object *** \n";
            #print Data::Dumper::Dumper( \$self->{monitor});
            #print "*** Object *** \n";
            $self->compare_data(
                $$self{data}{devices}{ $device->{identifier} }{runtime},
                $$self{prev_data}{devices}{ $device->{identifier} }{runtime},
                $$self{monitor}{ $device->{identifier} }{runtime}
            );

            # Save the previous remoteSensorsHash
            $$self{prev_data}{devices}{ $device->{identifier} }{remoteSensorsHash} = dclone $$self{data}{devices}{ $device->{identifier} }{remoteSensorsHash};
            foreach my $index ( @{ $device->{remoteSensors} } ) {

                # Since this is an array, the sensor order can vary. We need to save these into hashes so they can be indexed by ID
                $$self{data}{devices}{ $device->{identifier} }{remoteSensorsHash}{ $index->{id} }{id}   = $index->{id};
                $$self{data}{devices}{ $device->{identifier} }{remoteSensorsHash}{ $index->{id} }{name} = $index->{name};
                $$self{data}{devices}{ $device->{identifier} }{remoteSensorsHash}{ $index->{id} }{type} = $index->{type};
                if ( defined $$self{data}{devices}{ $device->{identifier} }{remoteSensorsHash}{ $index->{id} }{inUse} ) {
                    if ( $$self{data}{devices}{ $device->{identifier} }{remoteSensorsHash}{ $index->{id} }{inUse} ne $index->{inUse} ) {
                        $self->debug( $$self{data}{devices}{ $device->{identifier} }{name}
                              . ", sensor "
                              . $$self{data}{devices}{ $device->{identifier} }{remoteSensorsHash}{ $index->{id} }{name} . " (id "
                              . $$self{data}{devices}{ $device->{identifier} }{remoteSensorsHash}{ $index->{id} }{id}
                              . ") has changed from "
                              . $$self{data}{devices}{ $device->{identifier} }{remoteSensorsHash}{ $index->{id} }{inUse} . " to "
                              . $index->{inUse} );
                    }
                }
                $$self{data}{devices}{ $device->{identifier} }{remoteSensorsHash}{ $index->{id} }{inUse} = $index->{inUse};
                foreach my $capability ( @{ $index->{capability} } ) {

                    # capabilities can vary by sensor type
                    $$self{data}{devices}{ $device->{identifier} }{remoteSensorsHash}{ $index->{id} }{capability}{ $capability->{id} }{id} = $capability->{id};
                    $$self{data}{devices}{ $device->{identifier} }{remoteSensorsHash}{ $index->{id} }{capability}{ $capability->{id} }{type} =
                      $capability->{type};
                    if ( defined $$self{data}{devices}{ $device->{identifier} }{remoteSensorsHash}{ $index->{id} }{capability}{ $capability->{id} }{value} ) {
                        if ( $$self{data}{devices}{ $device->{identifier} }{remoteSensorsHash}{ $index->{id} }{capability}{ $capability->{id} }{value} ne
                            $capability->{value} )
                        {
                            $self->debug( $$self{data}{devices}{ $device->{identifier} }{name}
                                  . ", sensor "
                                  . $$self{data}{devices}{ $device->{identifier} }{remoteSensorsHash}{ $index->{id} }{name}
                                  . ", capability "
                                  . $capability->{type} . " (id "
                                  . $$self{data}{devices}{ $device->{identifier} }{remoteSensorsHash}{ $index->{id} }{id} . ":"
                                  . $capability->{id}
                                  . ") has changed from "
                                  . $$self{data}{devices}{ $device->{identifier} }{remoteSensorsHash}{ $index->{id} }{capability}{ $capability->{id} }{value}
                                  . " to "
                                  . $capability->{value} );
                        }
                    }
                    $$self{data}{devices}{ $device->{identifier} }{remoteSensorsHash}{ $index->{id} }{capability}{ $capability->{id} }{value} =
                      $capability->{value};
                }

                # Compare the old with the new, but we need to handle this differently since it is nested (a child of a child)
                # $self->compare_data( $$self{data}{devices}{$device->{identifier}}{remoteSensorsHash}{$index->{id}}, $$self{prev_data}{devices}{$device->{identifier}}{remoteSensorsHash}{$index->{id}}, $$self{monitor}{remoteSensorsHash} );
            }
            $self->debug( $$self{data}{devices}{ $device->{identifier} }{name} . " ID is " . $$self{data}{devices}{ $device->{identifier} }{identifier} );
        }
    }
    else {
        main::print_log("[Ecobee]: Uh, oh... Something went wrong with the runtime and sensor request");
    }
}

=item C<_thermostat_summary()>

Collects the revision numbers from each device on the Ecobee account. Changes to the revision number tell us that something
has changed, and we need to request an update.

=cut

sub _thermostat_summary {
    my ($self) = @_;
    $self->debug("Getting thermostat summary...");
    my $headers = HTTP::Headers->new(
        'Content-Type'  => 'text/json',
        'Authorization' => 'Bearer ' . $$self{access_token}
    );
    my $json_body = '{"selection":{"selectionType":"registered","selectionMatch":"","includeEquipmentStatus":true}}';
    my ( $isSuccessResponse1, $thermoparams ) = $self->_get_JSON_data( "GET", "thermostatSummary", '?json=' . uri_escape($json_body), $headers );
    if ($isSuccessResponse1) {
        $self->debug( "Thermostat response looks good. Found " . $thermoparams->{thermostatCount} . " thermostats" );
        foreach my $device ( @{ $thermoparams->{revisionList} } ) {

            # format:
            # identifier:name:connected:thermoRev:alertsRev:runtimeRev:intervalRev
            # Example line:
            # 123456789101:MyStat:true:071223012334:080102000000:080102000000
            my @values = split( ':', $device );
            $$self{data}{devices}{ $values[0] }{identifier} = $values[0];
            $$self{data}{devices}{ $values[0] }{name}       = $values[1];

            if ( defined $$self{data}{devices}{ $values[0] }{connected} ) {
                if ( $$self{data}{devices}{ $values[0] }{connected} ne $values[2] ) {

                    # This tells us if we are connected to the Ecobee servers
                    $self->debug( "connected has changed from " . $$self{data}{devices}{ $values[0] }{connected} . " to " . $values[2] );
                }
            }
            $$self{data}{devices}{ $values[0] }{connected} = $values[2];

            if ( defined $$self{data}{devices}{ $values[0] }{thermoRev} ) {
                if ( $$self{data}{devices}{ $values[0] }{thermoRev} != $values[3] ) {

                    # This tells us that the thermostat program, hvac mode, settings or configuration has changed
                    $self->debug( "thermoRev has changed from " . $$self{data}{devices}{ $values[0] }{thermoRev} . " to " . $values[3] );
                    $self->_get_settings();
                }
            }
            $$self{data}{devices}{ $values[0] }{thermoRev} = $values[3];

            if ( defined $$self{data}{devices}{ $values[0] }{alertsRev} ) {
                if ( $$self{data}{devices}{ $values[0] }{alertsRev} != $values[4] ) {

                    # This tells us of a new alert is issued or an alert is modified (acked)
                    $self->debug( "alertsRev has changed from " . $$self{data}{devices}{ $values[0] }{alertsRev} . " to " . $values[4] );
                    $self->_get_alerts();
                }
            }
            $$self{data}{devices}{ $values[0] }{alertsRev} = $values[4];

            if ( defined $$self{data}{devices}{ $values[0] }{runtimeRev} ) {
                if ( $$self{data}{devices}{ $values[0] }{runtimeRev} != $values[5] ) {

                    # This tells us when the thermostat has sent a new status message, or the equipment state or remote sensor readings have changed
                    $self->debug( "runtimeRev has changed from " . $$self{data}{devices}{ $values[0] }{runtimeRev} . " to " . $values[5] );
                    $self->_get_runtime_with_sensors();
                }
            }
            $$self{data}{devices}{ $values[0] }{runtimeRev} = $values[5];

            if ( defined $$self{data}{devices}{ $values[0] }{intervalRev} ) {
                if ( $$self{data}{devices}{ $values[0] }{intervalRev} != $values[6] ) {

                    # This tells us that the thermostat has sent a new status message (every 15 minutes)
                    $self->debug( "intervalRev has changed from " . $$self{data}{devices}{ $values[0] }{intervalRev} . " to " . $values[6] );
                }
            }
            $$self{data}{devices}{ $values[0] }{intervalRev} = $values[6];

            #main::print_log( "[Ecobee]: " . $$self{data}{devices}{$values[0]}{name} . " ID is " . $$self{data}{devices}{$values[0]}{identifier} .
            #     " connected is " . $$self{data}{devices}{$values[0]}{connected} );
        }

        # update the status for each device
        foreach my $device ( @{ $thermoparams->{statusList} } ) {
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
            my $status_bit_LUT = {
                'heatPump'     => 0x0001,
                'heatPump2'    => 0x0002,
                'heatPump3'    => 0x0004,
                'compCool1'    => 0x0008,
                'compCool2'    => 0x0010,
                'auxHeat1'     => 0x0020,
                'auxHeat2'     => 0x0040,
                'auxHeat3'     => 0x0080,
                'fan'          => 0x0100,
                'humidifier'   => 0x0200,
                'dehumidifier' => 0x0400,
                'ventilator'   => 0x0800,
                'economizer'   => 0x1000,
                'compHotWater' => 0x2000,
                'auxHotWater'  => 0x4000
            };
            my @values = split( ':', $device );
            my @states;

            # populate the status vector
            my $statusvec = 0x0000;
            if ( scalar @values > 1 ) {
                @states = split( ',', $values[1] );
                foreach my $index ( 0 .. $#states ) {
                    $statusvec |= $status_bit_LUT->{ $states[$index] };
                    $self->debug( "Statusvec=$statusvec, key=" . $states[$index] . ", LUT=" . $status_bit_LUT->{ $states[$index] } );
                }
            }
            if ( exists $$self{data}{devices}{ $values[0] }{statusvec}{status} ) {
                $$self{prev_data}{devices}{ $values[0] }{statusvec} =
                  dclone $$self{data}{devices}{ $values[0] }{statusvec};

                # Since state_now doesn't fire for values of 0, we need to create this artificial "all off" state
                if ( $statusvec == 0 ) {
                    $$self{data}{devices}{ $values[0] }{statusvec}{status} =
                      0x8000;
                }
                else {
                    $$self{data}{devices}{ $values[0] }{statusvec}{status} =
                      $statusvec;
                }
                $self->compare_data(
                    $$self{data}{devices}{ $values[0] }{statusvec},
                    $$self{prev_data}{devices}{ $values[0] }{statusvec},
                    $$self{monitor}{ $values[0] }{statusvec}
                );
            }
            else {
                # Since state_now doesn't fire for values of 0, we need to create this artificial "all off" state
                if ( $statusvec == 0 ) {
                    $$self{data}{devices}{ $values[0] }{statusvec}{status} =
                      0x8000;
                }
                else {
                    $$self{data}{devices}{ $values[0] }{statusvec}{status} =
                      $statusvec;
                }
            }

            # we probably need to notify something if one of these changes
            if ( defined $$self{data}{devices}{ $values[0] }{status} ) {

                # Save the previous status
                $$self{prev_data}{devices}{ $values[0] }{status} =
                  dclone $$self{data}{devices}{ $values[0] }{status};

                # This isn't our first run, so see if something has changed
                my $matched;
                for my $stat ( keys %default_status ) {
                    if ( scalar @values > 1 ) {
                        $matched = 0;
                        foreach my $index ( 0 .. $#states ) {
                            if ( $states[$index] eq $stat ) {
                                $matched = 1;
                                if ( $$self{data}{devices}{ $values[0] }{status}{ $states[$index] } == 0 ) {
                                    $$self{data}{devices}{ $values[0] }{status}{ $states[$index] } = 1;
                                    $self->debug("Status $stat has changed from off to on");
                                }
                            }
                        }
                        if (   ( !$matched )
                            && ( $$self{data}{devices}{ $values[0] }{status}{$stat} == 1 ) )
                        {
                            $self->debug("C1 Status $stat has changed from on to off");
                        }
                    }
                    else {
                        if ( $$self{data}{devices}{ $values[0] }{status}{$stat} != 0 ) {
                            $$self{data}{devices}{ $values[0] }{status}{$stat} =
                              0;
                            $self->debug("C2 Status $stat has changed from on to off");
                        }
                    }
                }

                # Compare the old with the new. This may not work as-is. We also need to consider the initial value.
                #$self->compare_data( $$self{data}{devices}{$values[0]}{status}, $$self{prev_data}{devices}{$values[0]}{status}, $$self{monitor}{status} );
            }
            else {
                $$self{data}{devices}{ $values[0] }{status} = \%default_status;
                if ( scalar @values > 1 ) {
                    foreach my $index ( 0 .. $#states ) {
                        $$self{data}{devices}{ $values[0] }{status}{ $states[$index] } = 1;
                    }
                }
            }

            #main::print_log( "[Ecobee]: " . $$self{data}{devices}{$values[0]}{name} . " fan is " . $$self{data}{devices}{$values[0]}{status}{fan} );
        }
    }
    else {
        main::print_log("[Ecobee]: Uh, oh... Something went wrong with the thermostat list request");
    }
}

sub _poll {
    my ($self) = @_;
    if ( $$self{ready} ) {
        $self->_thermostat_summary();
    }

    # reset the timer
    my $action = sub { $self->_poll() };
    $$self{polling_timer}->set( $$self{poll_interval}, $action );
}

#------------------------------------------------------------------------------------
sub _get_JSON_data {
    my ( $self, $type, $endpoint, $args, $headers, $content ) = @_;

    my $ua = new LWP::UserAgent();
    $ua->timeout( $$self{timeout} );

    my $url = $$self{url};

    my $request = HTTP::Request->new( $type, $url . $rest{$endpoint} . $args, $headers );
    $request->content($content) if defined $content;
    $self->debug( "Full request ->" . $request->as_string . "<-" );

    my $responseObj = $ua->request($request);
    $self->debug( $responseObj->content . "\n--------------------" );

    my $responseCode = $responseObj->code;
    $self->debug( "Response code: " . $responseCode );
    my $isSuccessResponse = $responseCode < 400;

    my $response;
    eval { $response = JSON::XS->new->decode( $responseObj->content ); };

    # catch crashes:
    if ($@) {
        main::print_log("ERROR! JSON parser crashed! $@");
        return ('0');
    }
    else {
        if ( !$isSuccessResponse ) {
            if ( ( $endpoint eq "token" ) && ( $responseCode == 401 ) ) {

                # Don't bother printing an error as this is expected, because the user hasn't entered the PIN yet
            }
            elsif (( $responseCode == 500 )
                && ( defined $response->{status}->{code} ) )
            {
                if ( $response->{status}->{code} == 14 ) {

                    # Our tokens have expired, we must refresh them and try again
                    $self->_refresh_tokens();

                    # Update the token in the header first
                    $headers->header( 'Authorization' => 'Bearer ' . $$self{access_token} );
                    return $self->_get_JSON_data( $type, $endpoint, $args, $headers );
                }
                else {
                    main::print_log( "[Ecobee]: Warning, failed to get data. Response code $responseCode, error code " . $response->{status}->{code} );
                }
            }
            else {
                main::print_log("[Ecobee]: Warning, failed to get data. Response code $responseCode");
            }
        }
        else {
            $self->debug("Got a valid response.");
        }

        return ( $isSuccessResponse, $response );
    }
}

=item C<register($parent, $value)>

Used to register actions to be run if a specific value changes.

    $parent   - The parent object on which the value should be monitored 
                (thermostat, remote sensor, group)
    $value    - The nested hash to monitor for changes. The assigned value is a 
                Code Reference to run when the value changes.  The code reference
                will be passed two arguments, the parameter name and value.

=cut

sub register {
    my ( $self, $parent, $value ) = @_;

    #main::print_log( "[Ecobee]: interface registering value $value");
    push( @{ $$self{register} }, [ $parent, $value ] );
}

# Walk through the data hash and looks for changes from previous hash if a
# change is found, looks for children to notify and notifies them.

# This needs to be enhanced a bit from the original Nest version as we are also dealing
# with remote sensors that have the same set of properties that are associated with
# the same thermostat and the parameter names are not globally unique. As such, the
# monitor hash structure will be provided as a nested hash that is traversed with the
# data hash. Unlike the Nest, different data comes in at different times and would false
# trigger if run at the top level of the data hash each time as it would compare previously
# evaluated data each run

sub compare_data {
    my ( $self, $data, $prev_data, $monitor_hash ) = @_;
    $self->debug("Starting execution within compare_data()");
    while ( my ( $key, $value ) = each %{$data} ) {

        # Use empty hash reference is it doesn't exist
        my $prev_value = {};
        $prev_value = $$prev_data{$key} if exists $$prev_data{$key};
        my $monitor_value = {};
        $monitor_value = $$monitor_hash{$key} if exists $$monitor_hash{$key};

        #main::print_log( "[Ecobee]: key is $key, value is $value, prev_value is $prev_value, monitor_value is $monitor_value");
        if ( ref $value eq 'HASH' ) {
            $self->compare_data( $value, $prev_value, $monitor_value );
        }
        elsif ( ( $value ne $prev_value ) && ( ref $monitor_value eq 'ARRAY' ) ) {
            for my $action ( @{$monitor_value} ) {
                $self->debug("I am running action for key $key, value $value");
                &$action( $key, $value );
            }
        }
    }
}

# Populate the monitor_hash with device IDs and monitor values in the register for each device
sub populate_monitor_hash {
    my ($self) = @_;
    for my $array_ref ( @{ $$self{register} } ) {
        my ( $parent, $value ) = @{$array_ref};
        my $device_id = $parent->device_id();
        if ( $$parent{type} eq 'sensor' ) {
            my $sensor_id = $parent->sensor_id();
            $$self{monitor}{$device_id}{$sensor_id} =
              $self->_merge( $value, $$self{monitor}{$device_id}{$sensor_id} );
        }
        else {
            $$self{monitor}{$device_id} =
              $self->_merge( $value, $$self{monitor}{$device_id} );
        }
    }
    delete $$self{register};
}

# Merge the source into the dest. This is used to populate the monitor hash.
sub _merge {
    my ( $self, $source, $dest ) = @_;
    for my $key ( keys %{$source} ) {
        if ( 'ARRAY' eq ref $dest->{$key} ) {
            push @{ $dest->{$key} }, $source->{$key};
        }
        elsif ( 'HASH' eq ref $dest->{$key} ) {
            $self->_merge( $source->{$key}, $dest->{$key} );
        }
        else {
            $dest->{$key} = $source->{$key};
        }
    }
    return $dest;
}

#------------
# User access methods

=item C<print_devices()>

Prints the name and id of all devices found in the Ecobee account.

=cut

sub print_devices {
    my ($self) = @_;
    my $output = "The list of devices reported by Ecobee is:\n";
    foreach my $key ( keys %{ $$self{data}{devices} } ) {
        $output .= "            Name:" . $$self{data}{devices}{$key}{name} . " ID: " . $$self{data}{devices}{$key}{identifier} . "\n";
    }
    $self->debug($output);
}

=item C<get_temp()>

Returns the temperature of the named temperature sensor registered with the given device (thermostat)

=cut

sub get_temp {
    my ( $self, $device, $name ) = @_;

    # Get the id of the given device
    my $d_id;
    foreach my $key ( keys %{ $$self{data}{devices} } ) {
        if ( $$self{data}{devices}{$key}{name} eq $device ) {
            $d_id = $key;
            last;
        }
    }
    if ($d_id) {
        if ( $name eq "actualTemperature" ) {

            # This is a special case where we return the runtime actualTemperature property instead of a sensor value
            return $$self{data}{devices}{$d_id}{runtime}{actualTemperature};
        }
        else {
            foreach my $key ( keys %{ $$self{data}{devices}{$d_id}{remoteSensorsHash} } ) {
                if ( $$self{data}{devices}{$d_id}{remoteSensorsHash}{$key}{name} eq $name ) {
                    return $$self{data}{devices}{$d_id}{remoteSensorsHash}{$key}{capability}{1}{value};
                }
            }
            return 0;
        }
    }
    else {
        return 0;
    }
}

=item C<get_humidity()>

Returns the humidity of the named sensor registered with the given device (thermostat).
Currently only the main thermostat device, not the remote sensors have humidity

=cut

sub get_humidity {
    my ( $self, $device, $name ) = @_;

    # Get the id of the given device
    my $d_id;
    foreach my $key ( keys %{ $$self{data}{devices} } ) {
        if ( $$self{data}{devices}{$key}{name} eq $device ) {
            $d_id = $key;
            last;
        }
    }
    if ($d_id) {
        if ( $name eq "actualHumidity" ) {

            # This is a special case where we return the runtime actualHumidity property instead of a sensor value
            return $$self{data}{devices}{$d_id}{runtime}{actualHumidity};
        }
        else {
            foreach my $key ( keys %{ $$self{data}{devices}{$d_id}{remoteSensorsHash} } ) {
                if ( $$self{data}{devices}{$d_id}{remoteSensorsHash}{$key}{name} eq $name ) {
                    if ( $$self{data}{devices}{$d_id}{remoteSensorsHash}{$key}{capability}{2}{type} eq "humidity" ) {
                        return $$self{data}{devices}{$d_id}{remoteSensorsHash}{$key}{capability}{2}{value};
                    }
                    else {
                        # This sensor type doesn't have a humidity sensor. Only the main thermostat unit does
                        return 0;
                    }
                }
            }
            return 0;
        }
    }
    else {
        return 0;
    }
}

=item C<get_desired_comfort()>

Returns the given runtime property for desiredX comfort setting. Known properties are:

desiredHeat       => Heat
desiredCool       => Cool
desiredHumidity   => Humidity
desiredDehumidity => Dehumidity
desiredFanMode    => FanMode

=cut

sub get_desired_comfort {
    my ( $self, $device, $name ) = @_;

    # Get the id of the given device
    my $d_id;
    foreach my $key ( keys %{ $$self{data}{devices} } ) {
        if ( $$self{data}{devices}{$key}{name} eq $device ) {
            $d_id = $key;
            last;
        }
    }
    if ($d_id) {
        if ( defined $$self{data}{devices}{$d_id}{runtime}{ "desired" . $name } ) {
            return $$self{data}{devices}{$d_id}{runtime}{ "desired" . $name };
        }
        else {
            return 0;
        }
    }
    else {
        return 0;
    }
}

=item C<get_setting()>

Returns the given setting property.

=cut

sub get_setting {
    my ( $self, $device, $setting ) = @_;

    # Get the id of the given device
    my $d_id;
    foreach my $key ( keys %{ $$self{data}{devices} } ) {
        if ( $$self{data}{devices}{$key}{name} eq $device ) {
            $d_id = $key;
            last;
        }
    }
    if ($d_id) {
        if ( defined $$self{data}{devices}{$d_id}{settings}{$setting} ) {
            return $$self{data}{devices}{$d_id}{settings}{$setting};
        }
        else {
            return 0;
        }
    }
    else {
        return 0;
    }
}

=item C<get_alert()>

Returns either the given alert by the given $id, or all of them if $id is undefined

=cut

sub get_alert {
    my ( $self, $device, $id ) = @_;

    # Get the id of the given device
    my $d_id;
    foreach my $key ( keys %{ $$self{data}{devices} } ) {
        if ( $$self{data}{devices}{$key}{name} eq $device ) {
            $d_id = $key;
            last;
        }
    }
    if ($d_id) {
        if ( defined $id ) {
            if ( defined $$self{data}{devices}{$d_id}{alertsHash}{$id} ) {
                return $$self{data}{devices}{$d_id}{alertsHash}{$id};
            }
            else {
                # Normal return is a hashref, so this is probably unwise
                return 0;
            }
        }
        else {
            return $$self{data}{devices}{$d_id}{alertsHash};
        }
    }
    else {
        # Normal return is a hashref, so this is probably unwise
        return 0;
    }
}

=item C<get_event()>

Returns either the given event by the given $id, or all of them if $id is undefined

=cut

sub get_event {
    my ( $self, $device, $id ) = @_;

    # Get the id of the given device
    my $d_id;
    foreach my $key ( keys %{ $$self{data}{devices} } ) {
        if ( $$self{data}{devices}{$key}{name} eq $device ) {
            $d_id = $key;
            last;
        }
    }
    if ($d_id) {
        if ( defined $id ) {
            if ( defined $$self{data}{devices}{$d_id}{eventsHash}{$id} ) {
                return $$self{data}{devices}{$d_id}{eventsHash}{$id};
            }
            else {
                # Normal return is a hashref, so this is probably unwise
                return 0;
            }
        }
        else {
            return $$self{data}{devices}{$d_id}{eventsHash};
        }
    }
    else {
        # Normal return is a hashref, so this is probably unwise
        return 0;
    }
}

#------------
# User control methods

package Ecobee_Generic;

=back

=head1 B<Ecobee_Generic>

=head2 SYNOPSIS

This is a generic module primarily meant to be inherited by higher level more
user friendly modules.  The average user should just ignore this module. 

=cut 

use strict;

=head2 INHERITS

C<Generic_Item>

=cut

@Ecobee_Generic::ISA = ( 'Generic_Item', 'Ecobee' );

=head2 METHODS

=over

=item C<new($interface, $parent, $monitor_hash>

Creates a new Ecobee_Generic.
    $interface    - The Ecobee_Interface through which this device can be found.
    $parent       - The parent interface of this object, if not specified the
                  the parent will be set to Self.
    $monitor_hash - A hash ref, {$value => $action}, where $value is the JSON 
                  value that should be monitored with $action equal to the code 
                  reference that should be run on changes.  The hash ref can
                  contain an infinite number of key value pairs.  If no action
                  is specified, it will use the default data_changed routine.

=cut

sub new {
    my ( $class, $interface, $parent, $monitor_hash ) = @_;
    my $self = new Generic_Item();
    bless $self, $class;
    $$self{interface} = $interface;
    $$self{parent}    = $parent;
    $$self{parent}    = $self if ( $$self{parent} eq '' );

    my $monitor_value = $self->_delve($monitor_hash);
    $$self{interface}->register( $$self{parent}, $monitor_value );
    return $self;
}

=item C<_delve()>

Internal function to help populate the monitor_hash with action functions

=cut

sub _delve {
    my ( $self, $datahash ) = @_;
    while ( my ( $key, $value ) = each %{$datahash} ) {
        if ( ref $value eq 'HASH' ) {

            # We need to go deeper
            $self->_delve( $datahash->{$key} );
        }
        else {
            $value = [ sub { $self->data_changed(@_); } ] if $value eq '';
            $datahash->{$key} = $value;
        }
    }
    return $datahash;
}

=item C<data_changed()>

The default action to be called when the JSON data has changed.  In most cases 
we can ignore the value name and just set the state of the child to new_value.
More sophisticated children can hijack this method to do more complex tasks.

=cut

sub data_changed {
    my ( $self, $value_name, $new_value ) = @_;
    my ( $setby, $response );
    $self->debug("Data changed called $value_name, $new_value");
    if ( defined $$self{parent}{state_pending}{$value_name} ) {
        ( $setby, $response ) = @{ $$self{parent}{state_pending}{$value_name} };
        delete $$self{parent}{state_pending}{$value_name};
    }
    else {
        $setby = $$self{interface};
    }
    $self->set_receive( $new_value, $setby, $response );
}

=item C<set_receive()>

Handles setting the state of the object inside MisterHouse

=cut

sub set_receive {
    my ( $self, $p_state, $p_setby, $p_response ) = @_;
    $self->SUPER::set( $p_state, $p_setby, $p_response );
}

=item C<device_id()>

Returns the device_id of an object.

=cut

sub device_id {
    my ($self) = @_;
    my $type_hash;
    my $parent = $$self{parent};
    for my $device_id ( keys %{ $$self{interface}{data}{devices} } ) {
        if ( $$parent{name} eq $$self{interface}{data}{devices}{$device_id}{name} ) {
            return $device_id;
        }
    }
    $self->debug( "ERROR, no device by the name " . $$parent{name} . " was found." );
    return 0;
}

=item C<sensor_id()>

Returns the sensor_id of an object.

=cut

sub sensor_id {
    my ($self) = @_;
    my $type_hash;
    my $parent = $$self{parent};
    for my $device_id ( keys %{ $$self{interface}{data}{devices} } ) {
        if ( $$parent{name} eq $$self{interface}{data}{devices}{$device_id}{name} ) {
            foreach my $sensor_id ( keys %{ $$self{interface}{data}{devices}{$device_id}{remoteSensorsHash} } ) {
                if ( $$parent{sensor_name} eq $$self{interface}{data}{devices}{$device_id}{remoteSensorsHash}{$sensor_id}{name} ) {
                    return $sensor_id;
                }
            }
        }
    }
    $self->debug( "ERROR, no sensor by the name " . $$parent{sensor_name} . " was found on device " . $$parent{name} . "." );
    return 0;
}

=item C<get_value($value)>

Returns the data contained in value for this device.

=cut

sub get_value {
    my ( $self, $value ) = @_;
    my $device_id = $self->device_id;
    if ( defined $$self{interface}{data}{devices}{$device_id}{$value} ) {
        return $$self{interface}{data}{devices}{$device_id}{$value};
    }
    else {
        $self->debug("ERROR, no value for $value on device $device_id was found.");
        return 0;
    }
}

package Ecobee_Thermostat;

=back

=head1 B<Ecobee_Thermostat>

=head2 SYNOPSIS

This is a high level module for interacting with the Ecobee Thermostat.  It is
generally user friendly and contains many functions which are similar to other
thermostat modules.

The state of this object will be the ambient temperature reported by the 
thermostat.  This object does not accept set commands.  You can use all of the 
remaining C<Generic_Item> including c<state>, c<state_now>, c<tie_event> to 
interact with this object.

=head2 CONFIGURATION

Create an Ecobee thermostat instance in the .mht file:

.mht file:

  CODE, $ecobee_thermo = new Ecobee_Thermostat('Entryway', $ecobee); #noloop

The arguments:

    1. The first argument is the I<the name of the device>.
       The name must be the exact verbatim name as listed on the Ecobee 
       website.  
    2. The second argument is the interface object

=cut 

use strict;

=head2 INHERITS

C<Ecobee_Generic>

=cut

@Ecobee_Thermostat::ISA = ('Ecobee_Generic');

=head2 METHODS

=over

=item C<new($name, $interface)>

Creates a new Ecobee_Generic.

    $name         - The name of the Thermostat
    $interface    - The interface object

=cut

sub new {
    my ( $class, $name, $interface ) = @_;
    my $monitor_value;
    $monitor_value->{runtime}{actualTemperature} = '';
    my $self = new Ecobee_Generic( $interface, '', $monitor_value );
    bless $self, $class;
    $$self{class} = 'devices', $$self{type} = 'thermostats', $$self{name} = $name;
    return $self;
}

=item C<get_temp()>

Returns the current ambient temperature.

=cut

sub get_temp {
    my ($self)  = @_;
    my $runtime = $self->get_value("runtime");    # This returns a hashref with all the runtime properties
                                                  #$self->debug("The actualTemperature is " . $runtime->{actualTemperature} );
    return $runtime->{actualTemperature};
}

=item C<get_events()>

Returns the current events.

=cut

sub get_events {
    my ($self) = @_;
    my $eventshash = $self->get_value("eventsHash");    # This returns a hashref with all the events (including holds)
    if ( scalar keys %{$eventshash} > 0 ) {
        return $eventshash;
    }
    else {
        return;
    }
}

=item C<get_programs()>

Returns the current programs.

=cut

sub get_programs {
    my ($self) = @_;
    my $programs = $self->get_value("program");    # This returns a hashref with all the programs
    return $programs;
}

=item C<set_hvac_mode($state, $p_setby, $p_response)>

Sets the mode to $state, must be [heat,auxHeatOnly,cool,auto,off]

=cut

sub set_hvac_mode {
    my ( $self, $state, $p_setby, $p_response ) = @_;
    main::print_log("[Ecobee]: Attempting to set the thermostat mode to $state");
    $$self{interface}{polling_timer}->pause;
    $state = lc($state);
    if (   $state ne 'heat'
        && $state ne 'auxHeatOnly'
        && $state ne 'cool'
        && $state ne 'auto'
        && $state ne 'off' )
    {
        $self->debug("set_hvac_mode must be one of: heat, auxHeatOnly, cool, auto, or off. Not $state.");
        return;
    }
    $$self{state_pending}{hvacMode} = [ $p_setby, $p_response ];

    # Send the new mode to the API
    my $headers = HTTP::Headers->new(
        'Content-Type'  => 'text/json',
        'Authorization' => 'Bearer ' . $$self{interface}{access_token}
    );

    # Note: this will change all thermostats on the account to this mode. The selection needs to be more specific to control just one.
    #my $json_body = '{"selection":{"selectionType":"registered","selectionMatch":""},"thermostat":{"settings":{"hvacMode":"' . $state . '"}}}';
    # Note: This will only change the specific device (or devices if more than one is given in CSV format)
    my $json_body =
      '{"selection":{"selectionType":"thermostats","selectionMatch":"' . $self->device_id . '"},"thermostat":{"settings":{"hvacMode":"' . $state . '"}}}';
    my ( $isSuccessResponse1, $modeparams ) = $$self{interface}->_get_JSON_data( "POST", "thermostat", "?format=json", $headers, $json_body );
    if ($isSuccessResponse1) {
        $self->debug("Mode change response looks good");
    }
    else {
        main::print_log("[Ecobee]: Uh, oh... Something went wrong with the mode change request");
    }
    $$self{interface}{polling_timer}->resume;
}

=item C<set_hold($state, $p_setby, $p_response)>

Sets a hold for the properties defined in $state. $state format can be either a temperature hold or a 
climate hold. Temperature holds are in the format temperature_<holdType>_<heatHoldTemp>_<coolHoldTemp> and 
climate holds are in the format climate_<holdType>_<holdClimateRef>

=cut

sub set_hold {
    my ( $self, $state, $p_setby, $p_response ) = @_;
    $self->debug("Attempting to set a thermostat hold to $state");
    my @s_params = split( '_', $state );
    my $json_body;
    if ( ( $s_params[0] eq 'climate' ) && ( scalar @s_params == 3 ) ) {

        # climate hold
        $json_body =
            '{"selection":{"selectionType":"thermostats","selectionMatch":"'
          . $self->device_id
          . '"},"functions": [{"type":"setHold","params":{"holdType":"'
          . $s_params[1]
          . '","holdClimateRef":'
          . $s_params[2] . '}}]}';
    }
    elsif ( ( $s_params[0] eq 'temperature' ) && ( scalar @s_params == 4 ) ) {

        # temperature hold
        $json_body =
            '{"selection":{"selectionType":"thermostats","selectionMatch":"'
          . $self->device_id
          . '"},"functions": [{"type":"setHold","params":{"holdType":"'
          . $s_params[1]
          . '","heatHoldTemp":'
          . $s_params[2]
          . ',"coolHoldTemp":'
          . $s_params[3] . '}}]}';
    }
    else {
        # format is wrong
        $self->debug("set_hold state \"$state\" is invalid");
        return;
    }

    $$self{state_pending}{hold} = [ $p_setby, $p_response ];
    $$self{interface}{polling_timer}->pause;
    my $headers = HTTP::Headers->new(
        'Content-Type'  => 'text/json',
        'Authorization' => 'Bearer ' . $$self{interface}{access_token}
    );
    my ( $isSuccessResponse1, $holdparams ) = $$self{interface}->_get_JSON_data( "POST", "thermostat", "?format=json", $headers, $json_body );
    if ($isSuccessResponse1) {
        $self->debug("Set hold response looks good");
    }
    else {
        main::print_log("[Ecobee]: Uh, oh... Something went wrong with the set hold request");
    }
    $$self{interface}{polling_timer}->resume;
}

=item C<clear_hold()>

Clears the current thermostat hold.

=cut

sub clear_hold {
    my ($self) = @_;
    $self->debug("Attempting to clear thermostat hold");
    $$self{interface}{polling_timer}->pause;
    my $headers = HTTP::Headers->new(
        'Content-Type'  => 'text/json',
        'Authorization' => 'Bearer ' . $$self{interface}{access_token}
    );
    my $json_body =
        '{"selection":{"selectionType":"thermostats","selectionMatch":"'
      . $self->device_id
      . '"},"functions": [{"type":"resumeProgram","params":{"resumeAll":false}}]}';
    my ( $isSuccessResponse1, $holdparams ) = $$self{interface}->_get_JSON_data( "POST", "thermostat", "?format=json", $headers, $json_body );
    if ($isSuccessResponse1) {
        $self->debug("Clear hold response looks good");
    }
    else {
        main::print_log("[Ecobee]: Uh, oh... Something went wrong with the clear hold request");
    }
    $$self{interface}{polling_timer}->resume;
}

package Ecobee_Thermo_Humidity;

=head1 B<Ecobee_Thermo_Humidity>

=head2 SYNOPSIS

This is a very high level module for viewing with the Ecobee Thermostat Humidity value (actualHumidity)
This type of object is often referred to as a child device.  It displays the
current humidity.  The object inherits all of the C<Generic_Item> methods, 
including c<state>, c<state_now>, c<tie_event>.

=head2 CONFIGURATION

.mht file:

  CODE, $thermo_humid = new Ecobee_Thermo_Humidity($ecobee_thermo); #noloop

The only argument required is the thermostat object.

=head2 INHERITS

C<Ecobee_Generic>

=cut

use strict;

@Ecobee_Thermo_Humidity::ISA = ('Ecobee_Generic');

sub new {
    my ( $class, $parent ) = @_;
    my $monitor_value;
    $monitor_value->{runtime}{actualHumidity} = '';
    my $self = new Ecobee_Generic( $$parent{interface}, $parent, $monitor_value );
    bless $self, $class;
    return $self;
}

package Ecobee_Thermo_HVAC_Status;

=head1 B<Ecobee_Thermo_HVAC_Status>

=head2 SYNOPSIS

This is a very high level module for viewing the Ecobee Thermostat operating status (state).
This type of object is often referred to as a child device.  It displays the
current status (fan, auxHeat1, ventilator, etc) as a vector (bitfield) to convey all the 
status data as a single state value.  The object inherits all of the C<Generic_Item> methods, 
including c<state>, c<state_now>, c<tie_event>.

=head2 CONFIGURATION

.mht file:

  CODE, $thermo_hvac_status = new Ecobee_Thermo_HVAC_Status($ecobee_thermo); #noloop

The only argument required is the thermostat object.

=head2 INHERITS

C<Ecobee_Generic>

=cut

use strict;

@Ecobee_Thermo_HVAC_Status::ISA = ('Ecobee_Generic');

sub new {
    my ( $class, $parent ) = @_;
    my $monitor_value;
    $monitor_value->{statusvec}{status} = '';
    my $self = new Ecobee_Generic( $$parent{interface}, $parent, $monitor_value );
    bless $self, $class;
    return $self;
}

package Ecobee_Thermo_Mode;

=head1 B<Ecobee_Thermo_Mode>

=head2 SYNOPSIS

This is a very high level module for interacting with the Ecobee Thermostat Mode.
This type of object is often referred to as a child device.  It displays the
mode of the thermostat and allows for setting the modes.  The object inherits
all of the C<Generic_Item> methods, including c<set>, c<state>, c<state_now>, 
c<tie_event>.

=head2 CONFIGURATION

.mht file:

  CODE, $thermo_mode = new Ecobee_Thermo_Mode($ecobee_thermo); #noloop

The only argument required is the thermostat object.

=head2 INHERITS

C<Ecobee_Generic>

=cut

use strict;

@Ecobee_Thermo_Mode::ISA = ('Ecobee_Generic');

sub new {
    my ( $class, $parent ) = @_;
    my $monitor_value;
    $monitor_value->{settings}{hvacMode} = '';
    my $self = new Ecobee_Generic( $$parent{interface}, $parent, $monitor_value );
    $$self{states} = [ 'heat', 'auxHeatOnly', 'cool', 'auto', 'off' ];
    bless $self, $class;
    return $self;
}

sub set {
    my ( $self, $p_state, $p_setby, $p_response ) = @_;
    $self->debug( "Setting $p_state, $p_setby, $p_response", $info );
    $$self{parent}->set_hvac_mode( $p_state, $p_setby, $p_response );
}

package Ecobee_Thermo_Climate;

=head1 B<Ecobee_Thermo_Climate>

=head2 SYNOPSIS

This is a very high level module for interacting with the Ecobee Thermostat Climate.
This type of object is often referred to as a child device.  It displays the
climate value of the thermostat either by the active schedule, or by the ClimateRef
of an overriding hold.  The object inherits all of the C<Generic_Item> 
methods, including c<state>, c<state_now>, c<tie_event>.

=head2 CONFIGURATION

.mht file:

  CODE, $thermo_climate = new Ecobee_Thermo_Climate($ecobee_thermo); #noloop

The only argument required is the thermostat object.

=head2 INHERITS

C<Ecobee_Generic>

=cut

use strict;

@Ecobee_Thermo_Climate::ISA = ('Ecobee_Generic');

sub new {
    my ( $class, $parent ) = @_;
    my $monitor_value;
    $monitor_value->{program}{currentClimateRef}                   = '';
    $monitor_value->{eventsHash}{'hold-auto-home'}{holdClimateRef} = '';
    $monitor_value->{eventsHash}{'hold-auto-away'}{holdClimateRef} = '';
    $monitor_value->{eventsHash}{'none'}{holdClimateRef}           = '';
    my $self = new Ecobee_Generic( $$parent{interface}, $parent, $monitor_value );
    bless $self, $class;
    return $self;
}

# Holds with a holdClimateRef override the value in currentClimateRef
sub data_changed {
    my ( $self, $value_name, $new_value ) = @_;
    $self->debug("Data changed called $value_name, $new_value");
    my $state = '';
    if ( $value_name eq 'holdClimateRef' ) {
        if ( $new_value eq 'none' ) {

            # A hold ws cleared, so we need to set the value back to the currentClimateRef
            my $programs = $$self{parent}->get_programs;
            $state = $programs->{currentClimateRef};
        }
        else {
            $state = $new_value;
        }
    }
    else {
        # We need to check if there are any active holds with a holdClimateRef before changing the state
        my $events = $$self{parent}->get_events;
        if ( !exists $events->{'none'} ) {
            main::print_log("[Ecobee]: Not setting the state to $new_value because there is still an active hold");
            return;
        }
        else {
            $state = $new_value;
        }
    }
    if ( $self->{state} ne $state ) {
        $self->set_receive( $state, $$self{parent}{interface} );
    }
    else {
        $self->debug("Not setting the state to $state because that is already the current value");
    }
}

=back

=head1 AUTHOR

Brian Rudy
Originally based on Nest.pm by Kevin Robert Keegan

=head1 SEE ALSO

https://www.ecobee.com/developers/

=head1 LICENSE

This program is free software; you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation; either version 2 of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more details.

You should have received a copy of the GNU General Public License along with this program; if not, write to the Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.

=cut
