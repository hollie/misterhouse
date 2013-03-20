=begin comment
@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@

Philips_Hue.pm - support for the Philips Hue devices

Info:

 Philips Hue:
  meethue.com
     
Usage:

 In your items.mht, add the Hue gateway and Hue devices like this:
 
   PHILIPS_HUE, <ipaddress_bridge>:<api_key>:<lamp_id>, kitchen_light, hue_gateway, Lights

e.g.:
   PHILIPS_HUE, 192.168.1.106:mytestusername:1, hue_1, Living
   
 Then in your code do something like:
      
   # Switch on the light if it is getting dark
   if (<condition_that_needs_to_be_met>) {
     $kitchen_light>set("ON");
   }
   
Limitations/TODO:
 Currently only supports switching a lamp on and off. Expect color changing support over the next days (famous last words :-)
 This text also needs to be updated to be compliant with the POD documentation format that is being implemented.
 
Dependencies:
 This code depends on the Perl module Device::Hue. This module is not published on CPAN yet at the time of writing.
 You can obtain it here for the time being:
  	https://github.com/hollie/hue-perl

Extra requirements:
 Detect the IP address of your bridge with the hue-discover script under examples of Device::Hue.
 Follow the instructions presented in that script to setup an API key.
 
License:
  This free software is licensed under the terms of the GNU public license.

Authors:
  Lieven Hollevoet  lieven@lika.be

@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
=cut

use strict;

package Philips_Hue;

@Philips_Hue::ISA = ('Generic_Item');

use Device::Hue;

sub new {
    my ($class, $p_address) = @_;
    my ($gateway, $apikey, $lamp_id) = $p_address =~ /(\S+):(\S+):(\S+)/;
    my $self = $class->SUPER::new();
    $$self{gateway} = 'http://' . $gateway;
    $$self{apikey}  = $apikey;
    $$self{lamp_id} = $lamp_id;
    
    $self->addStates ('on', 'off');
	
    return $self;
}


sub lamp_id {
    my ($self) = @_;
    return $$self{lamp_id};
}

sub addStates {
    my $self = shift;
    push(@{$$self{states}}, @_) unless $self->{displayonly};
}

sub default_setstate
{
    my ($self, $state, $substate, $set_by) = @_;
    
    #&::print_log("[xPL_Plugwise] setstate: $state");
    
    my $cmnd = ($state =~ /^off/i) ? 'off' : 'on';
    	
    return -1 if ($self->state eq $state); # Don't propagate state unless it has changed.
    
    &::print_log("[Hue] Request " . $self->get_object_name
		     . " turn " . $cmnd 
	    ) if $main::Debug{hue};
	
	&::print_log("settings: '" . $$self{gateway} . "' - '" . $$self{apikey} . "' - '" . $$self{lamp_id} . "' : '" . $cmnd. "'") if $main::Debug{hue};
	
    my $hue = new Device::Hue('bridge' => $$self{gateway}, 'key' => $$self{apikey}, 'debug' => 1);
    $hue->light($$self{lamp_id})->$cmnd;
	    
	return;
	
}
    
1;
