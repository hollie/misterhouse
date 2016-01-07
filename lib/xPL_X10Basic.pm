
=begin comment
@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@

xPL_X10Basic.pm - basic support for X10 messages over xPL
  $Date$
  $Revision$

Info:

  This module allows to support X10 basic messages over xPL.
     
Usage:

 In your items.mht, add the squeezebox devices like this:
 
   XPL_X10BASIC, xpl_device_id:instance, object_name, group_name
   
 e.g.
   XPL_X10BASIC, hollie-x10gate.downstairs:uplight, uplight, Lights
   
License:
  This free software is licensed under the terms of the GNU public license.

Authors:
  Roger Simon, added to git by Lieven Hollevoet based on a mail on the mailing list

@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
=cut

use strict;

package xPL_X10Basic;
use base qw(xPL_Item);

sub new {
    my ( $class, $p_source, $p_type, $p_statekey ) = @_;
    my ( $source, $deviceid ) = $p_source =~ /(\S+):(\S+)/;
    $source = $p_source unless $source;
    my $self = $class->SUPER::new($source);
    $$self{type} = $p_type if $p_type;
    my $statekey = $p_statekey;
    $statekey = 'command';
    $self->SUPER::class_name('x10.basic');
    $$self{state_monitor} = "x10.basic : $statekey";
    $self->SUPER::device_monitor("device=$deviceid") if defined $deviceid;
    return $self;
}

sub send_on {
    my ($self) = @_;
    $self->SUPER::send_cmnd(
        'x10.basic' => {
            'device'  => '$deviceid',
            'command' => 'on'
        }
    );
}

sub send_off {
    my ($self) = @_;
    $self->SUPER::send_cmnd(
        'x10.basic' => {
            'device'  => '$deviceid',
            'command' => 'off'
        }
    );
}

sub rts10_on {
    my ($self) = @_;
    $self->SUPER::send_cmnd(
        'x10.basic' => {
            'device'   => '$deviceid',
            'command'  => 'on',
            'protocol' => 'rts10'
        }
    );
}

sub rts10_off {
    my ($self) = @_;
    $self->SUPER::send_cmnd(
        'x10.basic' => {
            'device'   => '$deviceid',
            'command'  => 'off',
            'protocol' => 'rts10'
        }
    );
}

1;
