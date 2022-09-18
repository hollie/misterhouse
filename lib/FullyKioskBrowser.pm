=head1 DESCRIPTION

This creates a device item to remote control any Android device with FullyKiosBrowser installed (see
https://www.fully-kiosk.com/)

Implemented features:

    - Turn display on/off
    - Use text to speech on device
    - Play audio from url
    - With mqtt enalbed
        - get remote on/off updates from device
        - watch the battery level
        - use device as a motion sensor
        - foreground/brackground app state

=head1 mh.private.ini

For for verbose logging set

    debug=fullykiosk:1

in mh.private.ini

=head1 USAGE

Everything has to be defined in user code, there is no items.mht support for now

In user code create a FullyKioskBrowser item:

    #noloop=start
    use FullyKioskBrowser;
    $Device1 = new FullyKioskBrowser("10.121.117.81:2323", "password", $mqttBorker);
    #noloop=stop

or without MQTT support (no remote updates/no motion detection)

    #noloop=start
    use FullyKioskBrowser;
    $Device2 = new FullyKioskBrowser("10.121.117.81:2323", "password");
    #noloop=stop

Turn display on/off:

    set $Device1 'on' if state_now $motionsensor eq ON;
    set $Device1 'off' if state_now $motionsensor eq OFF;

use text to speech on device

    $Device1->say("The time is $Time_Now", 'en') if time_cron '30,35,40,45,50 6 * * 1-5';

play audio from URL

    $Device1->play("http://fileserver/audio/bing.mp3");

check battery level every 15min (Battery_Level is only available with mqtt enabled)

    $Device1->say("Battery low", 'en') if new_minute(15) and $Device1->{Battery_Level} < 20;

Motion detection:
to use fully kiosk motion detection feature (only with mqtt enabled, motion detection has to be enabled in fully kiosk)

    #noloop=start
    $Device1 = new FullyKioskBrowser("10.121.117.81:2323", "password", $mqttBorker);
    $Device1_Motion = new Motion_Item;
    $Device1->attache_motion_item($Device1_Motion);
    #noloop=stop
    #

Check FullyKiosk foreground/background state:
To check wether FullyKiosk is currently the app in use you can check the
`App_State` property. It is either 'foreground' or 'background'. Note, this
requieres mqtt to be enabled

    # only turn off screen if FullyKiosk is the active app
    set $Device1 'off' $Device1->{App_State} eq 'foreground';

=head1 METHODS

=cut

use warnings;
use strict;
use URI::Escape;
use mqtt;
use Scalar::Util 'blessed';

package FullyKioskBrowser;
@FullyKioskBrowser::ISA = ('Generic_Item');

=head2 C<new(url, password [, mqtt_broker])>

creates a new instance of a fully browser item.

C<url> connectioninformation for the device eg. "192.168.0.55:2323"

C<password> remote configuration password for fully kios

C<mqtt_broker> optional mqtt broker item. Required if you want to use the fully kiosk motion detection feature within
mister house. This is also usefull if your fully kiosk device is controled directly on the device or through anything
else. With MQTT enabled the mister house item will be updated if the device state is changed. This expects a mister
house C<MQTT_BROKER> item.

=cut

sub new {
    my $class = shift;
    my $self  = {
        _host        => shift,
        _password    => shift,
        _mqtt_broker => shift,
        _init        => 0,
        state        => "unknown",
    };
    $self->{_base_url}    = "http://$self->{_host}/?type=json&password=$self->{_password}";
    $self->{_result_file} = "$::config_parms{data_dir}/fullykioskbrowser_$self->{_host}.json";
    $self->{_process}     = new Process_Item();
    $self->{_process}->set_output($self->{_result_file});
    $self->{_work}        = ();
    bless $self, $class;
    &::MainLoop_post_add_hook(\&FullyKioskBrowser::process_check, 0, $self);
    $self->set_states("on", "off");
    $self->SUPER::set("not_initialized");
    &::print_log("FullyKiosk[$self->{_host}]: item created") if $::Debug{fullykiosk};
    $self->send_request("getDeviceInfo");    # polls device info an initializes
    $self->{App_State} = 'background';
    return $self;
}

=head2 C<attach_motion_item(motion_item)>

Attaches a C<Motion_Item> to this fully kiosk item. The motion item is trigger when a motion event is recieved from from
FullyKioskBrowser creates a new instance of a fully browser item.

Requiers MQTT and motion detection enabled in FullyKioskBrowser

=cut

sub attach_motion_item {
    my ($self, $motion_item) = @_;
    if (!$motion_item) {
        &::print_log("FullyKiosk[$self->{_host}]: motion item missing");
        return;
    }
    if (!Scalar::Util::blessed($motion_item)) {
        &::print_log("FullyKiosk[$self->{_host}]: motion item not blessed, has to be a 'Motion_Item'");
        return;
    }
    if (!$motion_item->isa('Motion_Item')) {
        &::print_log("FullyKiosk[$self->{_host}]: motion item is not a 'Motion_Item'");
        return;
    }
    $self->{_motion} = $motion_item;
    &::print_log("FullyKiosk[$self->{_host}]: $self->{_motion}->{object_name} motion item attached") if $::Debug{fullykiosk};
}

sub set {
    my ($self, $state, $by) = @_;
    if (!$self->{_init}) {
        &main::print_log("FullyKiosk[$self->{_host}]: not init, can not set state '$state'");
        return;
    }

    &main::print_log("FullyKiosk[$self->{_host}]: change to '$state'") if $::Debug{fullykiosk};
    my $cmd = 'screenOff';
    $cmd = 'screenOn' if $state eq 'on';
    $self->send_request("$cmd");
    $by = __PACKAGE__ unless $by;
    $self->SUPER::set("setting_$state", $by);
}

=head2 C<say(text [, lang])>

C<text> Text to speak

C<lang> optional language to use. Default is english 'en'

=cut

sub say {
    my ($self, $text, $locale) = @_;
    &main::print_log("FullyKiosk[$self->{_host}]: say '$text', locale=$locale") if $::Debug{fullykiosk};
    $locale = "en" unless $locale;
    $text   = URI::Escape::uri_escape($text);
    $self->send_request("textToSpeech", text => $text, locale => $locale);
}

sub play {
    my ($self, $url) = @_;
    &main::print_log("FullyKiosk[$self->{_host}]: play '$url'") if $::Debug{fullykiosk};
    $self->send_request("playSound", url => $url);
}

sub process_check {
    my ($self) = @_;

    if ($self->{_process}->done_now()) {
        $self->handle_request_result();
    }
    if ($self->{_mqtt} and my $json = $self->{_mqtt}->state_now()) {
        $self->handle_mqtt_event($json);
    }
    if ($::New_Minute && !$self->{_init}) {
        $self->send_request("getDeviceInfo");
    }

    $self->check_queue();
}

sub handle_mqtt_event {
    my ($self, $data) = @_;
    my $json;
    eval { $json = JSON::XS->new->decode($data); };
    if ($@) {
        &::print_log("FullyKiosk[$self->{_host}]: got invalid JSON from mqtt: $@");
        &::print_log("FullyKiosk[$self->{_host}]: bad JSON: $data");
        return;
    }
    my $ev = $json->{event};
    if (!$ev) {
        &::print_log("FullyKiosk[$self->{_host}]: MQTT event type missing: '$data'") if $::Debug{fullykiosk};
        return;
    }

    if ($ev eq "screenon" && $self->{state} ne 'on') {
        &::print_log("FullyKiosk[$self->{_host}]: MQTT screen '$self->{state}' => 'on'") if $::Debug{fullykiosk};
        $self->SUPER::set('on', $self->{_mqtt});
    }
    elsif ($ev eq "screenoff" && $self->{state} ne 'off') {
        &::print_log("FullyKiosk[$self->{_host}]: MQTT screen '$self->{state}' => 'off'") if $::Debug{fullykiosk};
        $self->SUPER::set('off', $self->{_mqtt});
    }
    elsif ($ev eq "onbatterylevelchanged"
        && $self->{Battery_Level} != int($json->{level}))
    {
        $self->{Battery_Level} = int($json->{level});
        &::print_log("FullyKiosk[$self->{_host}]: battery level now '$self->{Battery_Level}'") if $::Debug{fullykiosk};
    }
    elsif ($ev eq "onmotion" && $self->{_motion}) {
        $self->{_motion}->set('motion', $self);
    }
    elsif (($ev eq "background" or $ev eq "foreground")
            and $self->{App_State} ne $ev){
            # cant tell wether this event is actually from hiding fullykiosk or from turning the screen off
            # so we need to pool the device information
            &::print_log("FullyKiosk[$self->{_host}]: MQTT '$ev' changed, have to poll device information") if $::Debug{fullykiosk};
            $self->send_request("getDeviceInfo");
    }

    #  else {
    #      &::print_log("FullyKiosk[$self->{_host}]: MQTT?? $data") if $::Debug{fullykiosk};
    #  }
}

sub send_request {
    my ($self, $cmd, %parms) = @_;

    my $geturl = "get_url '$self->{_base_url}&cmd=$cmd";
    if (%parms) {
        foreach my $key (keys %parms) {
            $geturl .= "&$key=$parms{$key}";
        }
    }
    $geturl .= "'";

    if (!$self->{_process}->done())
    {
        &main::print_log("FullyKiosk[$self->{_host}]: have to queue '$geturl'") if $::Debug{fullykiosk};
        push @{$self->{_work}}, [ $cmd, $geturl ] ;
    }
    else{
        $self->_sendIt($cmd, $geturl);
    }
}

sub check_queue{
    my ($self)  = @_;
    return if (!$self->{_process}->done()) ;
    my $w = shift @{$self->{_work}};
    return if( !$w);

    my ($cmd, $geturl) = @{$w};

    if ($cmd){
        &main::print_log("FullyKiosk[$self->{_host}]: run queued '$cmd'") if $::Debug{fullykiosk};
       $self->_sendIt($cmd, $geturl); 
    }
}


sub _sendIt{
    my ($self, $cmd, $geturl) = @_;
    &main::print_log("FullyKiosk[$self->{_host}]: run $cmd: $geturl") if $::Debug{fullykiosk};
    $self->{_last_cmd} = $cmd;
    $self->{_process}->set($geturl);
    $self->{_process}->start();
}

sub handle_request_result {
    my ($self) = @_;
    my $data = &main::file_read($self->{_result_file});
    if (!$data) {
        $self->{_init}         = 0;
        $self->{Battery_Level} = undef;
        $self->SUPER::set("error", __PACKAGE__);
        return;
    }
    my $json;
    eval { $json = JSON::XS->new->decode($data); };
    if ($@) {
        &::print_log("$self->{_host} error for command: '$self->{_last_cmd}'");
        &::print_log("$self->{_host} got invalid JSON data: $@");
        &::print_log("$self->{_host} bad JSON: $data");
        $self->{_init}         = 0;
        $self->{Battery_Level} = undef;
        $self->SUPER::set("error_bad_data", __PACKAGE__);
        return;
    }

    $self->{_init} = 1;
    my $last_cmd = $self->{_last_cmd};
    $self->{_last_cmd} = undef;

    my $status = $json->{status};
    if ($status && $status ne "OK") {
        $self->{state} = $last_cmd . '_error';
        &::print_log("FullyKiosk[$self->{_host}]: ERROR: $data");
        return;
    }
    else
    {
        &::print_log("FullyKiosk[$self->{_host}]: '$last_cmd' OK") if $::Debug{fullykiosk};
    }

    my $by =__PACKAGE__ ."-command-" . $last_cmd;
    if ($last_cmd eq "getDeviceInfo") {
        $self->{_settings}     = $json;
        $self->{_deviceId}     = $json->{deviceId};
        $self->{Battery_Level} = int($json->{batteryLevel});
        my $s = $json->{screenOn} ? 'on' : 'off';
        $self->SUPER::set($s, $by);

        my $package = $json->{packageName};
        my $foregroundPackage = $json->{foreground};
        if ($package and $foregroundPackage) {
            if ($package eq $foregroundPackage) {
                $self->{App_State} = 'foreground';
            }
            else{
                $self->{App_State} = 'background';
            }
        }
        &::print_log("FullyKiosk[$self->{_host}]: id='$self->{_deviceId}' display='$s' battery='$self->{Battery_Level}' App_State='$self->{App_State}'") if $::Debug{fullykiosk};

        $self->send_request("listSettings");    # settings will be checked for mqtt settings
    }
    elsif ($last_cmd eq "listSettings") {
        if ($json->{mqttEnabled} && $self->{_mqtt_broker}) {
            my $topic = $json->{mqttEventTopic};
            $topic =~ s/\$event/+/;
            $topic =~ s/\$deviceId/$self->{_deviceId}/;
            &::print_log("FullyKiosk[$self->{_host}]: MQTT topic '$topic'") if $::Debug{fullykiosk};
            $self->{_mqtt} = new mqtt_Item($self->{_mqtt_broker}, $topic);
            $self->{_mqtt}->{object_name} = $self->get_object_name() . "_mqtt";
        }
    }
    elsif ($last_cmd eq "screenOn" && $self->{state} ne 'on') {
        &::print_log("FullyKiosk[$self->{_host}]: REST '$self->{state}' => 'on'") if $::Debug{fullykiosk};
        $self->SUPER::set('on', $by);
    }
    elsif ($last_cmd eq "screenOff" && $self->{state} ne 'off') {
        &::print_log("FullyKiosk[$self->{_host}]: REST '$self->{state}' => 'off'") if $::Debug{fullykiosk};
        $self->SUPER::set('off', $by);
    }
}

1;
