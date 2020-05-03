
=begin comment
Larry Roudebush
Initial release GE/TCPi lights only 2015-11-01
Added Power Strip 8/30/15

In items.mht
Type		Address				Name				Groups							Other Info
Group A
WINK,		64684,	Mstr BR NS L,			All_Lights|LivingRoom(1;11),  	Light,

In your mh private.ini
Private MH.INI -> WinkUser =  email address 
					WinkPassword = XXXXXXXXX
					
Upon your first run, you can review the file "$main::config_parms{data_dir}/logs/wraw.txt""
This file will tell you all of your devices and the upc code.  It is in raw json format.
If a device is not listed in the below, it can be added.  In the event a device is added to
%objtypes, the type of device and states needs to be added as well.  Also the subs getJsonArg
and PollDevice may need to be reviewed as well.  I still want to track the calls from the smartphone 
since this application has local access to the hub, but I have not had a chance to do packet snooping.

Some information about wink that is not supported  by wink can be found here: https://winkathome.net/Home.aspx


=cut

package Wink;
@Wink::ISA = ('Generic_Item');
require LWP::UserAgent;
use HTTP::Request;
use JSON;
use strict;

#use Parallel::ForkManager;
#use LWP::Parallel;

use Data::Dumper;

#my $baseUrl 	= "http://private-baa47-wink.apiary-mock.com";
my $baseUrl = "https://winkapi.quirky.com";

#my $baseUrl  	= "https://192.168.1.3:8888";

my $tknUrl = "https://winkapi.quirky.com";

#my $tknUrl 		= "https://192.168.1.3:8888";

my $allDev   = "/users/me/wink_devices";
my $getToken = "/oauth2/token";
my %objtypes = (
    5  => 'light_bulbs',
    15 => 'Hubs'           #Model Name:HUB 				UPC CODE:840410102358
    , 73  => 'light_bulbs'        #Model Name:GE Light Bulb 		UPC CODE:ge_zigbee
    , 24  => 'outlets'            #Model Name:Pivot Power Genius 	UPC CODE:814434017226
    , 181 => 'ignore'             #Model Name:Tapt 				UPC CODE:tapt
    , 184 => 'sensor_pods'        #Model Name:Tripper 			UPC CODE:840410105953
    , 197 => 'light_bulbs'        #Model Name:Cree light bulb 	UPC CODE:cree_zigbee5
    , 200 => 'binary_switches'    #Model Name:Binary Switch 		UPC CODE:JASCO_ZWAVE_BINARY_POWER
    , 203 => 'light_bulbs'        #Model Name:Dimmer 				UPC CODE:JASCO_ZWAVE_DIMMER
    ,
    250 => 'gangs',
    277 => 'binary_switches'      #Model Name:Tapt 				UPC CODE:tapt_binary_switch
    , 278 => 'buttons'            #Model Name:Tapt Button 		UPC CODE:tapt_button
    , 508 => 'ignore'             #Model Name:Gateway 			UPC CODE:tcp_gateway
    , 546 => 'light_bulbs'        #Model Name:A19 Lighting Kit 	UPC CODE:tcp_led_a19_11w
);
my %statetypes = (
    light_bulbs => [
        'on',  'off', '5%',  '10%', '15%', '20%', '25%', '30%', '35%', '40%', '45%', '50%',
        '55%', '60%', '65%', '70%', '75%', '80%', '85%', '90%', '95%', '100%'
    ],
    outlets         => [ 'on',   'off' ],
    binary_switches => [ 'on',   'off' ],
    gangs           => [ 'on',   'off' ],
    sensor_pods     => [ 'open', 'closed' ]
);

my ( $refresh_token, $access_token, $token_type, $data, $tokenExpire );

my $GetFileTime;
my $ReadFileTime;
my $wfile = "$main::config_parms{data_dir}/logs/wraw.txt";
my $rate  = 1;                                               #in minutes how often shall we get the status
my $debug = 0;                                               #set to 1 to force debug

sub new {
    my ( $class, $p_address ) = @_;
    my $self = $class->SUPER::new();
    bless $self, $class;
    $$self{lamp_id} = $class;
    $$self{address} = $p_address;
    $$self{upc_id}  = '';
    $$self{state}   = '';
    $$self{name}    = '';

    #&::print_log("Class:$class, Address:$p_address");
    &startup;
    return $self;
}

sub startup {
    &::print_log("Initializing Wink") if $debug;
    $ReadFileTime = Time::HiRes::time;
    $GetFileTime  = Time::HiRes::time;
    $data         = "{\n    \"client_id\": \"quirky_wink_android_app\"
				,\n    \"client_secret\": \"e749124ad386a5a35c0ab554a4f2c045\"
				,\n    \"username\": \"$main::config_parms{WinkUser}\"
				,\n    \"password\": \"$main::config_parms{WinkPassword}\"
				,\n    \"grant_type\": \"password\"\n}";
    if ( exists $main::Debug{Wink} ) {
        $debug = ( $main::Debug{Wink} >= 1 ) ? 1 : $debug;
    }
}

#in the event of new items being added the below sub maybe needed to change to handle these types of items
sub getJsonArg {
    my ( $devid, $upc_id, $state ) = @_;
    my ( $arg, $bright, $pwrd );

    $pwrd = getProperWinkPwrdName($state);

    if ( getObjType($upc_id) eq "light_bulbs" ) {
        $bright = getProperBrightness( $pwrd, $state );
        $arg = "{\"desired_state\": {\"brightness\": \"$bright\", \"powered\": \"$pwrd\"}}";
        &::print_log("GetJasonArgs:$arg") if $debug;
    }
    elsif ( ( getObjType($upc_id) eq "outlets" ) or ( getObjType($upc_id) eq "binary_switches" ) ) {
        $arg = "{\"desired_state\": {\"powered\": \"$pwrd\"}}";
        &::print_log("GetJasonArgs:$arg") if $debug;
    }
    else {
        &::print_log("Could not establish JasonArgs for UPC:$upc_id, Device ID:$devid");
        $arg = "";
    }
    return $arg;
}

#in the event of new items being added the below sub maybe needed to change to handle these types of items
sub PollDevice {
    my $decoded_json = decode_json( getDataFromFile() );
    my $aref         = $decoded_json->{data};
    if ( $aref eq "" ) { return; }
    if ( ref($aref) ne 'ARRAY' ) {
        &::print_log("While poling device, an array was not found");
        return;
    }
    &::file_write( "$main::config_parms{data_dir}/logs/wo.txt", Dumper($aref) );

    for my $href (@$aref) {
        if ( getObjType( $href->{upc_id} ) eq 'light_bulbs' ) {
            &SetDeviceInfo( $href->{light_bulb_id}, $href->{name}, $href->{upc_id}, $href->{desired_state}{powered}, $href->{desired_state}{brightness} );

            #&::print_log("Type:".getObjType( $href->{upc_id} ).", ID:$href->{light_bulb_id}, NAME:$href->{name}, UPC:$href->{upc_id}, STATE:$href->{desired_state}{powered}");
        }
        elsif ( getObjType( $href->{upc_id} ) eq 'outlets' ) {
            my $nh = $href->{outlets};
            for my $otlt (@$nh) {
                &SetDeviceInfo( $otlt->{outlet_id}, $otlt->{name}, $href->{upc_id}, $otlt->{desired_state}{powered}, '' );

                #&::print_log("Type:".getObjType( $href->{upc_id} ).", ID:$otlt->{outlet_id}, NAME:$href->{name}, UPC:$href->{upc_id}, STATE:$href->{desired_state}{powered}");
            }
        }
        elsif ( getObjType( $href->{upc_id} ) eq 'binary_switches' ) {
            &SetDeviceInfo( $href->{binary_switch_id}, $href->{name}, $href->{upc_id}, $href->{desired_state}{powered}, '' );

            #&::print_log("Type:".getObjType( $href->{upc_id} ).", ID:$href->{binary_switch_id}, NAME:$href->{name}, UPC:$href->{upc_id}, STATE:$href->{desired_state}{powered}");
        }
        elsif ( getObjType( $href->{upc_id} ) eq 'sensor_pods' ) {
            &SetDeviceInfo( $href->{sensor_pod_id}, $href->{name}, $href->{upc_id}, $href->{last_reading}{opened}, '' );

            #&::print_log("Type:".getObjType( $href->{upc_id} ).", ID:$href->{sensor_pod_id}, NAME:$href->{name}, UPC:$href->{upc_id}, STATE:$href->{last_reading}{opened}");
        }
        elsif ( getObjType( $href->{upc_id} ) eq 'buttons' ) {
            &SetDeviceInfo( $href->{button_id}, $href->{name}, $href->{upc_id}, $href->{last_reading}{pressed}, '' );

            #&::print_log("Type:".getObjType( $href->{upc_id} ).", ID:$href->{button_id}, NAME:$href->{name}, UPC:$href->{upc_id}, STATE:$href->{last_reading}{pressed}");
        }
        elsif ( getObjType( $href->{upc_id} ) eq 'gangs' ) {
            &SetDeviceInfo( $href->{gang_id}, $href->{name}, $href->{upc_id}, $href->{last_reading}{pressed}, '' );

            #&::print_log("Type:".getObjType( $href->{upc_id} ).", ID:$href->{button_id}, NAME:$href->{name}, UPC:$href->{upc_id}, STATE:$href->{last_reading}{pressed}");

        }
        elsif ( ( getObjType( $href->{upc_id} ) eq 'Hubs' ) || ( getObjType( $href->{upc_id} ) eq 'ignore' ) ) {

            #&::print_log("Type:".getObjType( $href->{upc_id} ).", Model:$href->{model_name}, NAME:$href->{name}, UPC:$href->{upc_id}, STATE:$href->{desired_state}{powered}");
            &::print_log("Wink Hub Found, UPC:$href->{upc_id}  Ingnore.") if $debug;
        }
        else {
            &::print_log("Unkown WINK item found, UPC ID:$href->{upc_id}");
            &::print_log("UPC:$href->{upc_id} Model Name:$href->{model_name} UPC CODE:$href->{upc_code}");

            #&::file_write("$main::config_parms{data_dir}/logs/woRaw.txt",  $ecoded_json);
            &::file_write( "$main::config_parms{data_dir}/logs/wo.txt", Dumper($aref) );
        }
    }
}

sub getUpdatedDataFile {
    my $url = $baseUrl . $allDev;
    getWinkToken();
    if ( $token_type eq "" ) { return; }

    #my $pm=new Parallel::ForkManager(10);
    #$pm->start and next;
    my $ua = LWP::UserAgent->new;

    #my $ua = LWP::UserAgent::POE->new();
    $ua->default_header( authorization => "$token_type $access_token" );
    my $response = $ua->get($url);
    if ( $response->is_success() ) {
        open my $fh, ">", $wfile;
        print $fh $response->content();
        close $fh;
    }
    else {
        &::print_log("Wink Polling Device Failed");
        &::print_log( "Response:" . Dumper( $response->content() ) );
        clearTokens();
    }

    #$pm->finish;
    #POE::Kernel->run();
}

sub clearTokens {
    $refresh_token = "";
    $access_token  = "";
    $token_type    = "";
    &::print_log("Clearing wink tokens!");
}

sub getDataFromFile {
    my $json;

    local $/;    #Enable 'slurp' mode
    open my $fh, "<", $wfile;
    $json = <$fh>;
    close $fh;
    if ( $json eq "" ) {
        &::print_log("Empty Wink File Found!");
        return;
    }
    return $json;
}

sub getProperBrightness {
    my ( $pwrd, $bright ) = @_;
    if ( ( $pwrd eq 'off' ) || ( $pwrd eq 'false' ) ) {
        $bright = '0';
    }
    elsif ( ( $pwrd eq 'on' ) || ( $pwrd eq 'true' ) ) {
        $bright = '1';
    }
    else {
        if ( $bright > 1 ) {
            $bright = $bright / 100;
        }
        else {
            $bright = $bright;
        }
    }
    return $bright;
}

sub getProperWinkPwrdName {
    my ($pwrd) = @_;
    &::print_log("getProperWinkPwrdName:$pwrd") if $debug;
    if ( $pwrd eq 'off' ) {
        return "false";
    }
    else {
        return "true";
    }
}

sub getDeviceUrl {
    my ( $devid, $upc_id ) = @_;
    my $obj = getObjType($upc_id);
    return "/$obj/$devid";
}

sub putWinkData {
    my ( $url, $data ) = @_;
    my $retVal;
    $url = $baseUrl . $url;

    #my $pm=new Parallel::ForkManager(10);
    #$pm->start and next;
    my $ua = LWP::UserAgent->new;
    my $request = HTTP::Request->new( PUT => $url );
    $request->header( authorization => "$token_type $access_token" );
    $request->content_type("application/json");
    $request->content($data);
    my $response = $ua->request($request);
    if ( $response->is_success ) {
        &::print_log("Set Wink Object Success") if $debug;
        $retVal = 1;
    }
    else {
        &::print_log("Set Wink Object Failed");
        &::print_log("Response:$response->content()");
        $retVal = 0;
    }

    #$pm->finish;
    return $retVal;
}

sub addStates {
    my $self = shift;
    push( @{ $$self{states} }, @_ );
}

sub addProperStates() {
    my ( $self, $upc_id ) = @_;

    my $arr = getObjStates( getObjType($upc_id) );

    if ( $arr eq "" ) { return; }

    my $cs = $$self{states};
    foreach my $var (@$arr) {
        if ( grep( /^$var$/, @$cs ) ) {

            #&::print_log("Value Exist, Ignore: $var") if $debug;
        }
        else {
            #&::print_log("Value Does Not Exist: $var") if $debug;
            $self->addStates($var);
        }
    }
}

sub default_setstate {
    my ( $self, $state, $substate, $set_by ) = @_;
    my ( $bright, $pwrd );

    my $curr = $self->state;

    return -1 if ( $self->state eq $state );    # Don't propagate state unless it has changed.
    if ( $set_by eq 'WINK' ) {
        &::print_log("State set by wink:UPC:$$self{upc_id}, State $state") if $debug;
        return;
    }

    #call the function to turn on/off light
    &::print_log("default_setstate:UPC:$$self{upc_id}, State $state") if $debug;
    setWinkDevice( $$self{address}, $$self{upc_id}, $state );

    return;
}

sub setWinkDevice {
    my ( $devid, $upc_id, $state ) = @_;
    getWinkToken();
    if ( $token_type ne "" ) {
        my $arg = getJsonArg( $devid, $upc_id, $state );
        my $url = getDeviceUrl( $devid, $upc_id );
        if ( ( $arg eq '' ) || ( $url eq '' ) ) { return -1; }
        my $stat = putWinkData( $url, $arg );
        if ( $stat == 1 ) {
            &::print_log("Setting WINK $devid to State $state ->Success!") if $debug;
        }
        else {
            &::print_log("Setting WINK $devid to State $state ->FAILED! $url, $arg");
            clearTokens();
        }
    }
    else {
        &::print_log("Could not set token!");
        clearTokens();
    }
}

sub GetDevicesAndStatus {
    my $now_time = Time::HiRes::time;
    if ( ( $now_time - $GetFileTime ) > ( 60 * $rate ) ) {

        #&::print_log("Polling Device");
        #get the new file
        &getUpdatedDataFile();
        $GetFileTime = Time::HiRes::time;
    }

    #read changed data
    if ( -e $wfile ) {
        if ( ( Time::HiRes::stat($wfile) )[9] != $ReadFileTime ) {
            $ReadFileTime = ( Time::HiRes::stat($wfile) )[9];

            #&::print_log("Reading file");
            &PollDevice;
        }
    }
}

sub SetDeviceInfo {
    my ( $devid, $name, $upc_id, $pwrd, $bright ) = @_;
    my $objfound = 0;
    for my $name ( &main::list_objects_by_type('Wink') ) {
        my $object = &main::get_object_by_name($name);
        if ( $object->{address} == $devid ) {
            &addProperStates( $object, $$object{upc_id} );
            $pwrd = getProperMHPwrdName( $pwrd, $upc_id );
            if ( ( $bright ne '0' ) && ( $bright ne '1' ) && ( $bright ne '' ) ) { $pwrd = $bright; }
            &::print_log("SetDeviceInfo:$devid, $pwrd, $bright, $object->{state}") if $debug;

            if ( $object->{state} ne $pwrd ) {
                &::print_log("State is no match, updating...") if $debug;
                $object->set( $pwrd, 'WINK' );

                #$object->{state} = $pwrd;
            }
            if ( $object->{name} ne $name ) {
                $object->{name} = $name;
            }
            if ( $object->{upc_id} ne $upc_id ) {
                $object->{upc_id} = $upc_id;
            }
            $objfound = 1;
        }
    }
    if ( $objfound == 0 ) {

        #my $class = 'Wink';
        #my $self = $class->SUPER::new();
        #bless $self, $class;
        #$$self{lamp_id} = $class;
        #$$self{address} = $devid;
        #$$self{upc_id}  = $upc_id;
        #$$self{state}   = '';
        #$$self{name}    = $name;#$test=~s/ /-/g;
        #&::print_log("No entry found for Wink Item; DID:$devid Name:$name UPC Id:$upc_id, Item Added!");
    }
}

sub getProperMHPwrdName {
    my ( $pwd, $upc_id ) = @_;
    if ( getObjType($upc_id) eq "sensor_pods" ) {
        if ( $pwd eq 'true' ) {
            return 'open';
        }
        else {
            return 'closed';
        }
    }
    else {
        if ( $pwd eq 'true' ) {
            return 'on';
        }
        else {
            return 'off';
        }
    }
}

sub property_changed {
    my ( $self, $property, $new_value, $old_value ) = @_;
    &::print_log("$self, $property, $new_value, $old_value") if $debug;
}

sub getObjStates {
    my $objType = shift;
    for my $key ( keys %statetypes ) {
        my $value = $statetypes{$key};
        if ( $key eq $objType ) {
            return $value;
        }
    }
    return "";
}

sub getObjType {
    my $upc_id = shift;
    for my $key ( keys %objtypes ) {
        my $value = $objtypes{$key};
        if ( $key eq $upc_id ) {
            ;
            return $value;
        }
    }
    return "UNDEFINED";
}

sub getWinkToken {
    my $url = $tknUrl . $getToken;
    if ( ( $refresh_token ne '' ) && ( $access_token ne '' ) ) {
        return;
    }
    my $req = HTTP::Request->new( 'POST', $url );
    $req->header( 'Content-Type' => 'application/json' );
    $req->content($data);
    my $lwp      = LWP::UserAgent->new;
    my $response = $lwp->request($req);

    if ( $response->is_success ) {
        my $decoded_json = decode_json( $response->content() );
        my $aref         = $decoded_json->{data};
        &::file_write( "$main::config_parms{data_dir}/logs/woHdrRaw.txt",  $response->headers()->as_string );
        &::file_write( "$main::config_parms{data_dir}/logs/woHdrRaw2.txt", Dumper($aref) );
        $refresh_token = $decoded_json->{'data'}{'refresh_token'};
        $access_token  = $decoded_json->{'data'}{'access_token'};
        $token_type    = $decoded_json->{'data'}{'token_type'};
        $tokenExpire   = $decoded_json->{'data'}{'expires'};
        &::print_log("Refresh Token: $refresh_token, Access Token: $access_token, Token Type:$token_type");
    }
    else {
        &::print_log("Could not get wink token.");
        &::print_log("Response:$response->content()");
        $refresh_token = "";
        $access_token  = "";
        $token_type    = "";
    }
}

sub refreshWinkToken {
    my $url = $tknUrl . $getToken;
    if ( ( $refresh_token ne '' ) && ( $access_token ne '' ) ) {
        return;
    }
    my $req = HTTP::Request->new( 'POST', $url );
    $req->header( 'Content-Type' => 'application/json' );
    my $refData = "{\n  \"client_id\": \"quirky_wink_android_app\"
				   ,\n 	\"client_secret\": \"e749124ad386a5a35c0ab554a4f2c045\"
				   ,\n	\"grant_type\": \"refresh_token\"
				   ,\n 	\"refresh_token\": \"$refresh_token\"\n}";
    $req->header( 'Content-Type' => 'application/json' );
    $req->content($refData);
    my $lwp      = LWP::UserAgent->new;
    my $response = $lwp->request($req);

    if ( $response->is_success ) {
        my $decoded_json = decode_json( $response->content() );
        my $aref         = $decoded_json->{data};
        &::file_write( "$main::config_parms{data_dir}/logs/woHdrRaw.txt",  $response->headers()->as_string );
        &::file_write( "$main::config_parms{data_dir}/logs/woHdrRaw2.txt", Dumper($aref) );
        $refresh_token = $decoded_json->{'data'}{'refresh_token'};
        $access_token  = $decoded_json->{'data'}{'access_token'};
        $token_type    = $decoded_json->{'data'}{'token_type'};
        $tokenExpire   = $decoded_json->{'data'}{'expires'};
        &::print_log("Refresh Token: $refresh_token, access token: $access_token");
    }
    else {
        &::print_log("Response:$response->content()");
        $refresh_token = "";
        $access_token  = "";
        $token_type    = "";
    }

}

1;
