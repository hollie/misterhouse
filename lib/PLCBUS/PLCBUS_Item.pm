use strict;
use warnings;
use experimental 'smartmatch';
use PLCBUS ;
package PLCBUS_Item;
@PLCBUS_Item::ISA = ('Generic_Item');
our %plcbus_items_table;
sub _logd ($$) {
    return unless ($::Debug{plcbus_module} && $::Debug{plcbus_module} > 1);
    my ($self, @msg) = @_;
    $self->_log(@msg) 
}
sub _log{
    return unless $::Debug{plcbus_module};
    my ($self, @msg) = @_;
    PLCBUS::_log("$self->{name}: @msg");
}

sub new {
    my ($class, $name, $home,$unit) = @_;
    my $self = { };
    bless $self, $class;
    $self->{home} = $home;
    $self->{unit} = $unit;
    $self->{name} = $name;
    $self->set_states( qw |on off bright dim blink status_req get_signal_strength get_noise_strength 1_phase 3_phase use_mh_ini_phase_mode |);
    $self->_logd("ctor $self->{name} home: $self->{home} unit: $self->{unit}"); 
    PLCBUS->instance()->add_device($self);
    $self->restore_data('phase_override');
    return $self;
}

    sub handle_incoming {
    my ($self, $c) = @_;
    my $msg ;
    if ($c->{cmd} eq "status_on"){
        $msg = "On " . $c->{d1};
        $self->_set("on");
    }
    elsif ($c->{cmd} eq "status_off"){
        $msg = "Off";
        $self->_set("off");
    }
    elsif ($c->{cmd} eq "report_signal_strength"){
        $msg = "Signal strength is " .$c->{d1};
    }
    elsif ($c->{cmd} eq "report_noise_strength"){
        $msg = "Noise is " . $c->{d1};
    }

    if ($msg){
        &::speak("$self->{name} $msg") if $::config_parms{plcbus_speak};
        $self->_log($msg);
    }
}

sub _set {
    my ($self, $new_state) = @_;
    my $prev = $self->state;
    $prev = 'undef' if (!$prev);

    if ($new_state ne $prev){
        $self->_logd("'$prev' => '$new_state'");
        $self->SUPER::set("$new_state");
    }
}

sub set {
    my ($self, $new_state) = @_;
    if ($new_state ~~ [ "on", "off" ] ){
        $self->_set($new_state);
        $self->command($new_state);
    }
    elsif ($new_state ~~ [  "bright", "dim",
                            "status req", "blink",
                            "get signal strength",
                            "get noise strength" ]){
        $new_state =~ s/ /_/g;
        $self->command($new_state);
    }
    elsif ($new_state =~ /(.*) phase/){
        if ( $1 =~ /.*mh ini.*/){
            delete $self->{phase_override};
            $self->_log("removed phase mode override.");
        }
        else{
            $self->{phase_override} = $1;
            $self->_log("switched to '$self->{phase_override}' phase mode.");
        }
    }
    else
    {
        $self->_log("do not know what to do with state '$new_state'");
        return 0;
    }
}

sub command {
    my ($self, $cmd, $d1, $d2) = @_;
    my $msg = "$cmd";
    $msg .= " d1=$d1" if $d1;
    $msg .= " d2=$d2" if $d2;
    $self->_logd("send '$msg'");
    my $home = $self->{home};
    my $unit = $self->{unit};
    PLCBUS->instance()->queue_command( { home => $home, unit => $unit, cmd => $cmd, d1=> $d1, d2 => $d2});
}
package PLCBUS_1141;
@PLCBUS_1141::ISA = ('PLCBUS_Item');

package PLCBUS_4825;
@PLCBUS_4825::ISA = ('PLCBUS_Item');

## sub new {
##     my ($class, $name, $home,$unit) = @_;
##     my $self = { };
##     bless $self, $class;
##     $self->{home} = $home;
##     $self->{unit} = $unit;
##     $self->{name} = $name;
## #    $self->set_states( qw ||);
##     $self->_logd("ctor $self->{name} home: $self->{home} unit: $self->{unit}"); 
##     PLCBUS->instance()->add_device($self);
##     return $self;
## }
#sub _set { }

package PLCBUS_2026;
@PLCBUS_2026::ISA = ('PLCBUS_Item');

package PLCBUS_2263;
@PLCBUS_2263::ISA = ('PLCBUS_Item');

package PLCBUS_Scene;
@PLCBUS_Scene::ISA = ('PLCBUS_Item');
sub new {
    my ($class, $name, $home,$unit) = @_;
    my $self = { };
    bless $self, $class;
    $self->{home} = $home;
    $self->{unit} = $unit;
    $self->{name} = $name;
    $self->set_states( qw |on off bright dim|);
    $self->_logd("ctor $self->{name} home: $self->{home} unit: $self->{unit}"); 
    PLCBUS->instance()->add_device($self);
    return $self;
}
#sub _set { }


1;
