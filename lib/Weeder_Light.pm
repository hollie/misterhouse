
=begin comment
@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@

File:
	Weeder_Light.pm

Description:
   Monitors and controls a light through Weeder boards

Example Usage:
   $garage_light_detect = new Serial_Item('ACH', OFF      , 'weeder');
   $garage_light_detect       -> add     ('ACL', ON       , 'weeder');
   $garage_light_detect_cont = new Serial_Item('A!' , 'reset'  , 'weeder');
   $garage_light_detect_cont  -> add          ('ASC', 'init'   , 'weeder');
   $garage_light_detect_cont  -> add          ('ARC', 'status' , 'weeder');
   
   $garage_light_toggle = new Serial_Item('BCA500', 'press'  , 'weeder');
   $garage_light_toggle       -> add     ('B!'    , 'reset'  , 'weeder');
   $garage_light_toggle       -> add     ('BDAO'  , 'init'   , 'weeder');
   $garage_light_toggle       -> add     ('BRA'   , 'status' , 'weeder');
   $garage_light_toggle       -> add     ('BOA'   , 'open'   , 'weeder');
   $garage_light_toggle       -> add     ('BAC'   , 'closed' , 'weeder');
   
   use Weeder_Light;
   $garage_opener_light = new Weeder_Light($garage_light_detect, $garage_light_detect_cont, $garage_light_toggle);

   # To add this light to a group in your .mht file
   $All_Lights                          -> add($garage_opener_light);

NOTES:
   To properly use this object with floorplan.pl, set its location and room:
      # To set location on the floorplan
      $garage_opener_light                 -> set_fp_location(9,5,1,1);
      # To set which room the light is in
      $Garage                              -> add($garage_opener_light);

   Then add Weeder_Light in floorplan.pl as follows:

      if ($p_obj->isa('Light_Item') or
      $p_obj->isa('Fan_Light') or
      $p_obj->isa('Weeder_Light') or
           $p_obj->isa('X10_Item')) {

Author:
	Kirk Bauer
	kirk@kaybee.org

License:
	This free software is licensed under the terms of the GNU public license.

@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
=cut

use strict;

package Weeder_Light;

my @weeder_lights;

sub _check_states {
    foreach (@weeder_lights) {
        $_->_check_state();
    }
}

@Weeder_Light::ISA = ('Generic_Item');

sub new {
    my ( $class, $light_detect, $light_control, $light_toggle ) = @_;
    my $self = {};
    bless $self, $class;
    $$self{'detect'}  = $light_detect;
    $$self{'control'} = $light_control;
    $$self{'toggle'}  = $light_toggle;
    push @weeder_lights, $self;
    push( @{ $$self{states} }, 'on', 'off' );

    unless ( $#weeder_lights > 0 ) {
        &::MainLoop_post_add_hook( \&Weeder_Light::_check_states,
            'persistent' );
    }
    return $self;
}

sub _check_state {
    my ($self) = @_;
    if ($::New_Minute) {
        $self->{'control'}->set('status');
        select( undef, undef, undef, 0.025 );
    }
    if ( $::Startup or $::New_Day ) {
        $self->{'toggle'}->set('open');
        select( undef, undef, undef, 0.025 );
    }
    if (   ( $self->{'control'}->state_now eq 'reset' )
        or $::Startup
        or $::New_Day )
    {
        $self->{'control'}->set('init');
        select( undef, undef, undef, 0.025 );
        $self->{'control'}->set('status');
        select( undef, undef, undef, 0.025 );
    }
    if ( $self->{'detect'}->state_now eq main::OFF ) {
        $self->set_states_for_next_pass(main::OFF);
    }
    if ( $self->{'detect'}->state_now eq main::ON ) {
        $self->set_states_for_next_pass(main::ON);
    }
}

sub setstate_off {
    my ( $self, $substate ) = @_;
    main::print_log(
        "Weeder_Light: setstate_off, curr_state=" . $self->{'detect'}->state );
    if ( $self->{'detect'}->state ne main::OFF ) {
        main::print_log("Weeder_Light: turning light off");
        $self->{'toggle'}->set('press');
        my $timer = new Timer;
        set $timer 5, sub {
            main::print_log(
                "Weeder_Light: executing timer to check light status");
            $self->{'control'}->set('status');
        };
    }
}

sub setstate_on {
    my ( $self, $substate ) = @_;
    main::print_log(
        "Weeder_Light: setstate_on, curr_state=" . $self->{'detect'}->state );
    if ( $self->{'detect'}->state ne main::ON ) {
        main::print_log("Weeder_Light: turning light on");
        $self->{'toggle'}->set('press');
        my $timer = new Timer;
        set $timer 5, sub {
            main::print_log(
                "Weeder_Light: executing timer to check light status");
            $self->{'control'}->set('status');
        };
    }
}

