
=begin comment
Larry Roudebush
Initial release GE/TCPi lights only 2015-11-01
Added Power Strip 8/30/15

In items.mht
Type Address Name Groups Other Info
Group A
WINK, 64684, Mstr BR NS L, All_Lights|LivingRoom(1;11), Light,

In your mh private.ini
Private MH.INI -> WinkUser = email address
WinkPassword = XXXXXXXXX

Add the below to \lib\read_table_a.pl
read_table_a.pl
elsif ($type eq "WINK"){
($address, $name, $grouplist, @other) = @item_info;
$other = join ', ', (map {"'$_'"} @other); # Quote data
$object = "Wink('$address',$other)";
if( ! $packages{Wink}++ ) { # first time for this object type?
$code .= "use Wink;\n";
&::MainLoop_pre_add_hook( \&Wink::GetDevicesAndStatus, 1 );
}
}
=cut

package Wink;
@Wink::ISA = ('Generic_Item');
require LWP::UserAgent;
use HTTP::Request;
use JSON;
use strict;

use Data::Dumper;

#my $baseUrl = "http://private-baa47-wink.apiary-mock.com";
my $baseUrl  = "https://winkapi.quirky.com";
my $allDev   = "/users/me/wink_devices";
my $getToken = "/oauth2/token";
my %objtypes = (
    5   => 'light_bulbs',
    15  => 'Hubs',
    73  => 'light_bulbs',
    24  => 'outlets',
    197 => 'light_bulbs',
);
my %statetypes = (
    light_bulbs => [
        'on',  'off', '5%',  '10%', '15%', '20%', '25%', '30%',
        '35%', '40%', '45%', '50%', '55%', '60%', '65%', '70%',
        '75%', '80%', '85%', '90%', '95%', '100%'
    ],
    outlets => [ 'on', 'off' ]
);

my ( $refresh_token, $access_token, $token_type, $data );

my $last_time;
my $rate  = 1;    #in minutes how often shall we get the status
my $debug = 0;    #set to 1 to force debug

sub new {
    my ( $class, $p_address ) = @_;
    my $self = $class->SUPER::new();
    bless $self, $class;
    $$self{lamp_id} = $class;
    $$self{address} = $p_address;
    $$self{upc_id}  = '';
    $$self{state}   = '';
    $$self{name}    = '';
    &startup;
    return $self;
}

sub startup {
    &::print_log(" Initializing Wink ") if $debug;
    $data = " {
        \n \"client_id\": \"quirky_wink_android_app\"
,\n \"client_secret\": \"e749124ad386a5a35c0ab554a4f2c045\"
,\n \"username\": \"$main::config_parms{WinkUser}\"
,\n \"password\": \"$main::config_parms{WinkPassword}\"
,\n \"grant_type\": \"password\"\n}";
    if ( exists $main::Debug{Wink} ) {
        $debug = ( $main::Debug{Wink} >= 1 ) ? 1 : $debug;
    }
}

sub getJsonArg {
    my ( $devid, $upc_id, $state ) = @_;
    my ( $arg, $bright, $pwrd );

    if ( getObjType($upc_id) eq "light_bulbs" ) {

        #Current: ON, New 50% —– Current: 50%, New off ———- Current: off, New on
        #{ 'desired_state': { 'brightness': 0.5, 'powered': True } }

        $pwrd = getProperWinkPwrdName($state);
        $bright = getProperBrightness( $pwrd, $state );
        $arg =
          "{\"desired_state\": {\"brightness\": \"$bright\", \"powered\": \"$pwrd\"}}";
        &::print_log("GetJasonArgs:$arg") if $debug;
    }
    elsif ( getObjType($upc_id) eq "powerstrips" ) {
        $pwrd = getProperWinkPwrdName($state);
        $arg  = "{\"desired_state\": {\"powered\": \"$pwrd\"}}";
        &::print_log("GetJasonArgs:$arg") if $debug;
    }
    return $arg;
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
    $url = $baseUrl . $url;
    my $ua = LWP::UserAgent->new;
    my $request = HTTP::Request->new( PUT => $url );
    $request->header( authorization => "$token_type $access_token" );
    $request->content_type("application/json");
    $request->content($data);
    my $response = $ua->request($request);

    if ( $response->is_success ) {
        &::print_log("Set Wink Object Success") if $debug;
        return 1;
    }
    else {
        &::print_log("Set Wink Object Failed");
        return 0;
    }
}

sub addStates {
    my $self = shift;
    push( @{ $$self{states} }, @_ );
}

sub addProperStates() {
    my ( $self, $upc_id ) = @_;

    my $arr = getObjStates( getObjType($upc_id) );
    &::print_log("addProperStates:UPC:$upc_id Arr:$arr") if $debug;
    if ( $arr eq "" ) { return; }
    &::print_log("addStates:CurrentStates:$$self{states}") if $debug;
    my $cs = $$self{states};
    foreach my $curst (@$cs) {
        &::print_log("addStates:Contains:$curst") if $debug;
    }

    foreach my $var (@$arr) {
        &::print_log("addStates:UPC:$upc_id Var:$var") if $debug;
        if ( grep( /^$var$/, @$cs ) ) {
            &::print_log("Value Exist, Ignore: $var") if $debug;
        }
        else {
            &::print_log("Value Does Not Exist: $var") if $debug;
            $self->addStates($var);
        }
    }
}

sub default_setstate {
    my ( $self, $state, $substate, $set_by ) = @_;
    my ( $bright, $pwrd );

    my $curr = $self->state;

    return -1
      if ( $self->state eq $state )
      ;    # Don't propagate state unless it has changed.

    #call the function to turn on/off light
    &::print_log("default_setstate:UPC:$$self{upc_id}, State $state")
      if $debug;
    setWinkDevice( $$self{address}, $$self{upc_id}, $state );

    return;
}

sub setWinkDevice {
    my ( $devid, $upc_id, $state ) = @_;
    getWinkToken();
    if ( $token_type ne "" ) {
        my $arg = getJsonArg( $devid, $upc_id, $state );
        my $url = getDeviceUrl( $devid, $upc_id );
        my $stat = putWinkData( $url, $arg );
        if ( $stat == 1 ) {
            &::print_log("Setting WINK $devid to State $state ->Success!")
              if $debug;
        }
        else {
            &::print_log("Setting WINK $devid to State $state ->FAILED!");
        }
    }
    else {
        &::print_log("Token Failure!");
    }
}

sub GetDevicesAndStatus {
    my $now_time = Time::HiRes::time;
    if ( ( $now_time - $last_time ) > ( 60 * $rate ) ) {
        &::print_log("Polling Device") if $debug;
        &PollDevice;
    }

}

sub PollDevice {
    my $url = $baseUrl . $allDev;
    getWinkToken();
    if ( $token_type eq "" ) { return; }
    my $ua = LWP::UserAgent->new;
    $ua->default_header( authorization => "$token_type $access_token" );
    my $response = $ua->get($url);
    if ( !$response->is_success ) {
        &::print_log("Wink Polling Device Failed");
        return;
    }
    my $decoded_json = decode_json( $response->content() );

    #my $ecoded_json = encode_json( $decoded_json->{data} );
    my $log_time = Time::HiRes::time;

    my $aref = $decoded_json->{data};
    &::file_write( "$main::config_parms{data_dir}/logs/wo.txt", Dumper($aref) )
      if $debug;

    #&::file_write("$main::config_parms{data_dir}/logs/woRaw.txt", $ecoded_json) if $debug;
    for my $href (@$aref) {
        if ( getObjType( $href->{upc_id} ) eq 'light_bulbs' ) {
            &SetDeviceInfo(
                $href->{light_bulb_id},
                $href->{name},
                $href->{upc_id},
                $href->{desired_state}{powered},
                $href->{desired_state}{brightness}
            );
        }
        elsif ( getObjType( $href->{upc_id} ) eq 'outlets' ) {
            my $nh = $href->{outlets};
            for my $otlt (@$nh) {
                &SetDeviceInfo( $otlt->{outlet_id}, $otlt->{name},
                    $href->{upc_id}, $otlt->{desired_state}{powered}, '' );
            }
        }
        elsif ( getObjType( $href->{upc_id} ) eq 'Hubs' ) {
            &::print_log("Wink Hub Found, UPC:$href->{upc_id} Ingnore.")
              if $debug;
        }
        else {
            &::print_log("Unkown WINK item found, UPC ID:$href->{upc_id}");
        }
    }
    $last_time = Time::HiRes::time;
}

sub SetDeviceInfo {
    my ( $devid, $name, $upc_id, $pwrd, $bright ) = @_;
    my $objfound = 0;
    for my $name ( &main::list_objects_by_type('Wink') ) {
        my $object = &main::get_object_by_name($name);
        if ( $object->{address} == $devid ) {
            &addProperStates( $object, $$object{upc_id} );
            $pwrd = getProperMHPwrdName($pwrd);
            if ( ( $bright ne '0' ) && ( $bright ne '1' ) && ( $bright ne '' ) )
            {
                $pwrd = $bright;
            }
            &::print_log(
                "SetDeviceInfo:$devid, $pwrd, $bright, $object->{state}")
              if $debug;

            if ( $object->{state} ne $pwrd ) {
                &::print_log("State is no match, updating…") if $debug;
                $object->{state} = $pwrd;
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
        &::print_log(
            "No entry found for Wink Item; DID:$devid Name:$name UPC Id:$upc_id"
        );
    }
}

sub getProperMHPwrdName {
    my ($pwd) = @_;
    if ( $pwd eq 'true' ) {
        return 'on';
    }
    else {
        return 'off';
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
    my $url = $baseUrl . $getToken;
    my $req = HTTP::Request->new( 'POST', $url );
    $req->header( 'Content-Type' => 'application/json' );
    $req->content($data);
    my $lwp      = LWP::UserAgent->new;
    my $response = $lwp->request($req);

    if ( $response->is_success ) {
        my $decoded_json = decode_json( $response->content() );
        $refresh_token = $decoded_json->{'data'}{'refresh_token'};
        $access_token  = $decoded_json->{'data'}{'access_token'};
        $token_type    = $decoded_json->{'data'}{'token_type'};
    }
    else {
        $refresh_token = "";
        $access_token  = "";
        $token_type    = "";
    }
}

1;
