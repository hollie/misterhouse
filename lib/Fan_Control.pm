=begin comment
@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@

File:
	Fan_Control.pm

Description:
	Allows control of Hampton Bay RF ceiling fans with appropriate custom
   hardware, as described at http://www.linux.kaybee.org:81/tabs/fancontrol/

Author:
	Kirk Bauer
	kirk@kaybee.org

License:
	This free software is licensed under the terms of the GNU public license.

Usage:
   This module is included from Misterhouse.  Just place it in your user code
   directory (code_dir in your config file).  You must then add the following
   configuration items to your mh.ini:
      fancontrol_module=Fan_Control
      fancontrol_host=localhost
      fancontrol_port=3412

   These direct Misterhouse to connect to the fan control daemon, which you
   must have running for the fan control to work.  Here are some example
   .mht entries (assuming your Misterhouse is using the proper patches):

      FANLIGHT,   fr,     fr_fan_light,           Inside_Lights|All_Lights|FamilyRoom(9;7)FANLIGHT,   mb,     mb_fan_light,           Inside_Lights|All_Lights|MasterBed(7;8)
      FANLIGHT,   dr,     dr_fan_light,           Inside_Lights|All_Lights|LivingRoom(5;5)FANLIGHT,   patio,  patio_fan_light,        Inside_Lights|All_Lights|BackPorch(10;4)FANMOTOR,   fr,     fr_fan_motor,           Fans
      FANMOTOR,   mb,     mb_fan_motor,           Fans
      FANMOTOR,   dr,     dr_fan_motor,           Fans
      FANMOTOR,   patio,  patio_fan_motor,        Fans

   Currently, a FANLIGHT can be set to 'on' or 'off'.  A FANMOTOR can be set to
   'off', 'low', 'med', 'high'.

TODO:
   Need to add support for dimming (the daemon does not yet support this either)

Special Thanks to: 
	Bruce Winter - Misterhouse

@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
=cut

use strict;

package Fan_Control;

@Fan_Control::ISA = ('Generic_Item');

my $fan_socket = undef;
my %fan_control_lights;

sub startup {
   if (not $fan_socket and $main::config_parms{fancontrol_host} and $main::config_parms{fancontrol_port}) {
      my $port = "$main::config_parms{fancontrol_host}:$main::config_parms{fancontrol_port}";
      $fan_socket = new Socket_Item(undef, undef, $port, 'fancontrol', 'tcp', 'record');
      start $fan_socket;
      &::MainLoop_pre_add_hook(\&Fan_Control::check_for_data, 'persistent');
   }
}

sub check_for_data {
   if ((not active $fan_socket) and (($main::Second % 6) == 0) and $::New_Second) {
      start $fan_socket;
   }
   if (my $msg = said $fan_socket) {
      if ($msg =~ /fan (\S+) light (\S+)/) {
         if ($fan_control_lights{$1}) {
            #print STDERR "Setting fan $1 to state", lc $2, "\n";
            #&main::print_log("Setting fan $1 to state" . lc($2));
            if ($fan_control_lights{$1}->{'already_set'}) {
               $fan_control_lights{$1}->set_states_for_next_pass(lc($2), 'remote');
            } else {
               $fan_control_lights{$1}->{'already_set'} = 1;
               $fan_control_lights{$1}->set_states_for_next_pass(lc($2));
            }
         }
      }
   }
}

package Fan_Light;

@Fan_Light::ISA = ('Generic_Item');

sub new
{
	my ($class, $name) = @_;
	my $self={};
	bless $self,$class;
   $$self{'name'} = $name;
   $fan_control_lights{$name} = $self;
   push(@{$$self{states}}, 'on', 'off');
	return $self;
}

sub setstate_off {
   my ($self, $substate) = @_;
   set $fan_socket "fan $$self{'name'} light off";
}

sub setstate_on {
   my ($self, $substate) = @_;
   set $fan_socket "fan $$self{'name'} light on";
}

package Fan_Motor;

@Fan_Motor::ISA = ('Generic_Item');

sub new
{
	my ($class, $name) = @_;
	my $self={};
	bless $self,$class;
   $$self{'name'} = $name;
   $$self{'off_timer'} = new Timer();
   push(@{$$self{states}}, 'off', 'low', 'med', 'high');
	return $self;
}

sub delay_off {
   my ($self, $delay) = @_;
   $$self{'off_timer'}->set($delay, $self);
}

sub setstate_off {
   my ($self) = @_;
   set $fan_socket "fan $$self{'name'} motor off";
   $$self{'off_timer'}->stop();
}

sub setstate_low {
   my ($self) = @_;
   set $fan_socket "fan $$self{'name'} motor low";
   $$self{'off_timer'}->stop();
}

sub setstate_med {
   my ($self) = @_;
   set $fan_socket "fan $$self{'name'} motor med";
   $$self{'off_timer'}->stop();
}

sub setstate_high {
   my ($self) = @_;
   set $fan_socket "fan $$self{'name'} motor high";
   $$self{'off_timer'}->stop();
}

1;

