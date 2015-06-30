use strict;
use warnings;
use experimental 'smartmatch';
use PLCBUS;

package PLCBUS_Item;
@PLCBUS_Item::ISA = ('Generic_Item');

sub _logd ($$) {
    return unless ( $::Debug{plcbus_module} && $::Debug{plcbus_module} > 1 );
    my ( $self, @msg ) = @_;
    $self->_log(@msg);
}

sub _log {
    return unless $::Debug{plcbus_module};
    my ( $self, @msg ) = @_;
    PLCBUS::_log("$self->{name}: @msg");
}

sub new {
    my ( $class, $name, $home, $unit, $grouplist ) = @_;
    my $self = {};
    bless $self, $class;
    $self->{home} = $home;
    $self->{unit} = $unit;
    $self->{name} = $name;
    $self->{groups} = $grouplist;
    my @default_states =
        qw|on off bright dim |;
    $self->set_states(@default_states);
    $self->_logd("ctor $self->{name} home: $self->{home} unit: $self->{unit}");
    PLCBUS->instance()->add_device($self);
    $self->restore_data('phase_override');
    $self->generate_voice_commands();
    return $self;
}

sub generate_voice_commands
{
    my ($self) = @_;
    $self->_log("Generating Voice commands");
    my $object_string;
    my $name = $self->{name};

    my $varlist;
    my $vc_pref = $name;
    $vc_pref =~ tr/_/ /;

    my $voice_cmds = $self->get_voice_cmds();

    foreach (sort keys %$voice_cmds) {
        my $vc_var_name = "\$${name}_$_";
        $varlist .= " $vc_var_name";
        $object_string .= "$vc_var_name  = new Voice_Cmd '$vc_pref $voice_cmds->{$_}[0]';\n";
        $object_string .= "$vc_var_name -> tie_event('" . $voice_cmds->{$_}[1] . "');\n";
        $object_string .= ::store_object_data("$vc_var_name", 'Voice_Cmd', 'PLCBUS', 'PLCBUS');
    }
    $object_string = "use vars qw($varlist);\n" . $object_string;
    #$self->_log("\n\n$object_string");

    #Evaluate the resulting object generating string
    package main;
    eval $object_string;
    die "Error in PLCBUS item voice command genertion: $@\n" if $@;
    package PLCBUS_Item;
}

sub get_voice_cmds {
    my ($self) = @_;
    my $object_name = $self->{name};
    my %voice_cmds = (
        'change_state' => ['[on,off,status req,get signal strength,get noise strength,1 phase,3 phase,use mh ini phase mode]', "\$$object_name->set(\$state)"],
        'bright_025' => [ 'presetdim to 25% within [0,1,2,3,4,5,6,7,8,9,10]s',  "\$$object_name->preset_dim_from_voice_cmd( 25, \$state)"],
        'bright_050' => [ 'presetdim to 50% within [0,1,2,3,4,5,6,7,8,9,10]s',  "\$$object_name->preset_dim_from_voice_cmd( 50, \$state)"],
        'bright_075' => [ 'presetdim to 75% within [0,1,2,3,4,5,6,7,8,9,10]s',  "\$$object_name->preset_dim_from_voice_cmd( 75, \$state)"],
        'bright_100' => [ 'presetdim to 100% within [0,1,2,3,4,5,6,7,8,9,10]s', "\$$object_name->preset_dim_from_voice_cmd(100, \$state)"],
        'bright_cmd' => [ 'bright [25,50,75,100]%', "\$$object_name->command(\"bright\", \$state, 1)"],
        'dim_cmd' => [ 'dim [25,50,75,100]%', "\$$object_name->command(\"dim\", \$state, 1)"],
    );

    return \%voice_cmds;
}

sub handle_incoming {
    my ( $self, $c ) = @_;
    my $msg;
    if ( $c->{cmd} eq "status_on" ) {
        $msg = "On " . $c->{d1};
        $self->_set("on","PLCBUSInc");
    }
    elsif ( $c->{cmd} eq "status_off" ) {
        $msg = "Off";
        $self->_set("off","PLCBUSInc");
    }
    elsif ( $c->{cmd} eq "report_signal_strength" ) {
        $msg = "Signal strength is " . $c->{d1};
    }
    elsif ( $c->{cmd} eq "report_noise_strength" ) {
        $msg = "Noise is " . $c->{d1};
    }

    if ($msg) {
        &::speak("$self->{name} $msg") if $::config_parms{plcbus_speak};
        $self->_log($msg);
    }
}

sub _set {
    my ( $self, $new_state, $setby, $respond ) = @_;
    my $prev = $self->{state};
    $prev = 'undef' if ( !$prev );

    if ( $new_state ne $prev ) {
        my $msg = "'$prev' => '$new_state'";
        $msg .= ", set by $setby" if $setby;
        $msg .= ", respond $respond" if $respond;
        $self->_logd($msg);
        $self->SUPER::set($new_state, $setby, $respond);
    }
}

sub preset_dim_from_voice_cmd(){
    my ( $self, $brightness, $faderate) = @_;
    my $msg = "change preset brightness to $brightness% at a faderate of $faderate seconds for $self->{name} was requested";
    ::respond ("$msg");
    $self->preset_dim($brightness, $faderate);
}

sub preset_dim {
    my ( $self, $bright_percent, $fade_rate_secs ) = @_;

    my $msg = "preset dim $bright_percent% $fade_rate_secs";
    $self->_log($msg);
    $self->command('presetdim', $bright_percent, $fade_rate_secs);
}

my @light_cmds = [ "on", "off", "bright", "dim" ];
my @plc_cmds = [ "status req", "blink",
        "get signal strength",
        "get noise strength"
    ];

sub set {
    my ( $self, $new_state, $setby, $respond ) = @_;

    my $l = "set $new_state ";
    $l .= "from $setby "      if $setby;
    $l .= "respond $respond " if $respond;
    $self->_logd($l);

    if ($new_state ~~ @light_cmds) {
        if ( $new_state ne $self->{state} ) {
            $self->command($new_state); 
        }
        else { 
            $self->_logd("Already in state $new_state"); 
        }
        if ($new_state eq "on" or $new_state eq "off"){
            $self->_set($new_state, $setby, $respond);
        }
    }
    elsif ( $new_state ~~ @plc_cmds ) {
        $new_state =~ s/ /_/g;
        $self->command($new_state); 
    }
    elsif ( $new_state =~ /(.*) phase/ ) {
        if ( $1 =~ /.*mh ini.*/ ) {
            delete $self->{phase_override};
            $self->_log("removed phase mode override.");
        }
        else {
            $self->{phase_override} = $1;
            $self->_log("switched to '$self->{phase_override}' phase mode.");
        }
    }
    else {
        $self->_log("do not know what to do with state '$new_state'");
        return 0;
    }
}

sub command {
    my ( $self, $cmd, $d1, $d2 ) = @_;
    my $msg = "$cmd";
    $msg .= " d1=$d1" if $d1;
    $msg .= " d2=$d2" if $d2;
    $self->_logd("send '$msg'");
    my $home = $self->{home};
    my $unit = $self->{unit};
    PLCBUS->instance()
        ->queue_command(
        { home => $home, unit => $unit, cmd => $cmd, d1 => $d1, d2 => $d2 } );
}

sub _is_three_phase(){
    my ($self) = @_;
    my $mode ;
    if ($self->{phase_override}){
        $mode = $self->{phase_override};
        $self->_logd("using module specific phase mode '$mode'");
    }
    else{
        $mode = $::config_parms{plcbus_phase_mode};
        if(! $mode ){
            $self->_log("Phase mode not defined in mh.ini. Asuming 1-Phase");
            return 0;
        }
    }

    if($mode != 1 && $mode != 3 ) {
        $self->_log("Phase mode '$mode' unknown. Asuming 1-Phase");
        return 0;
    }
    elsif ($mode == 1){
        return 0;
    }
    elsif ($mode == 3) {
        return 1;
    }
}

package PLCBUS_LightItem;
@PLCBUS_LightItem::ISA = ( 'PLCBUS_Item');

package PLCBUS_2026;
@PLCBUS_2026::ISA = ( 'PLCBUS_LightItem');

package PLCBUS_2263;
@PLCBUS_2263::ISA = ( 'PLCBUS_LightItem');

package PLCBUS_Scene;
@PLCBUS_Scene::ISA = ( 'PLCBUS_Item');

1;
