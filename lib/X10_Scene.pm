
# Package: X10SL_Scene
# $Date$
# $Revision$

=begin comment
@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@

Description:

        This package provides a "convenience" class for creating and controlling
        X10 (SwitchLinc family) scenes.

Compatibility:

        Tested to work w/ the V2 KeypadLinc, SwitchLinc and LampLinc modules.
        It should work w/ prior versions of the same modules with the possible
        exception of separately controllable scene member ramp rates.

Author:

        Gregg Liming
        gregg@limings.net

License:

        This free software is licensed under the terms of the GNU public license.

Usage:

    Declaration:

        The following entries belong in the .mht file
        # declare the scene item
        X10_SCENE, A3, my_scene,  All_Lights|Scenes

        # add members to the scene; currently they *must* be X10SL-type items
        X10_SCENE_MEMBER, some_X10xL_light, my_scene, 70%, 87%
        # The first percentage is the "on-level" and extends from 0% to 100%;
        #    it is set to 100% if ommitted.  For X10_Appliancelincs, it must
        #    be 0%, off, 100% or on.
        # The second percentage is the ramp-rate (see table below); 
        #    it is optional and can be unique.  It must be omitted if an
        #    X10_Applicancelinc

        
    States:

        'on' - all scene members are set to their scene on values and with
                optional ramp rate.  The mh items' state is also set to mirror
                the scene's control
        'off' - all scene members are set off
        'brighten' - all scene members' state is incremented
        'dim' - all scene members' state is decremented
        'resume' -  resume is a special (non-x10) state that allows a resumption 
                of the original states of the scene's member lights.

    Operations:

        add($x10sl_light, $on_level, $ramp_rate) - adds a scene member
                Note that this does NOT automatically enroll the scene
                at the device level.  $on_level and ramp_rate must both be
                expressed in percentage.  See ramp rate table below for ramp rate
                mapping.  $ramp_rate is optional.

        remove_member($x10sl_light) - removes a member at the device level.  Consider
                only using this method sparingly and possibly via Voice_Command.

        remove_all_members() - removes all members defined for a scene at the device level.
                Consider only using this method sparingly and possibly via Voice_Command.

        enroll() - enroles the scene members using X10SL-specific commands.
                BE VERY CAREFUL when using this command as it is possible to 
                create orphaned scene members if you choose to change the 
                members added (via add) prior to removing the member.
                In addition, there exists some possibility of mis-enrolling 
                the scene members if excess X10 traffic occurs during initialization.
                Consider only using this method sparingly and possibly via Voice_Command.
                This method is not required if you have an alternate method of 
                enrolling scenes (e.g., a hardware scene controller).

    Ramp rate table:

        Ramp rates must currently expressed in percentage form.  The table below
        maps percentage to ramp duration.

        100% -  0.1s       65% -  26s       29% - 150s
         97% -  0.2s       61% -  28s       26% - 180s
         94% -  0.3s       58% -  30s       23% - 210s
         90% -  0.5s       55% -  32s       19% - 240s
         87% -  2.0s       52% -  34s       16% - 270s
         84% -  4.5s       48% -  38s       13% - 300s
         81% -  6.5s       45% -  43s       10% - 360s
         77% -  8.5s       42% -  47s        6% - 420s
         74% - 19.0s       39% -  60s        3% - 480s
         71% - 21.5s       35% -  90s        0% - 540s
         68% - 23.5s       32% - 120s

    Special Considerations:

        If using in conjuction with lights managed by Light_Items, various properties of
        the Light_Item such as "on_state" and "delay_off" may need to be stored, separately
        managed and restored.  Use of scene->tie_event and scene->tie_filter can be used
        within usercode to gain access to scene and scene member states.

        If control over a scene item will be "mapped" via usercode (vice directly controlled
        by a X10SL-compatible controller), then consider mapping the "off" part of the control
        to the resume method to avoid making all lights turn off.  For example,

        if ($some_button->state_now eq ON) {
           $my_scene->set(ON);
        } elsif ($some_button->state_now eq OFF) {
           $my_scene->set('resume');
        }


@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
=cut

package X10SL_Scene;

use strict;

@X10SL_Scene::ISA = ('Generic_Item');

sub new {
    my ( $class, $scene_address ) = @_;
    my $self = {};
    bless $self, $class;

    my $scene_item = new X10_Item($scene_address);
    $$self{scene_item} = $scene_item;
    $$self{scene_item}->tie_items($self);

    return $self;
}

# TO-DO: ensure that new member doesn't already exist
sub add {
    my ( $self, $obj, $on_level, $ramp_rate ) = @_;
    if ( ref $obj ) {
        if ( $obj->{x10_id} ) {
            if ( $$self{members} && $$self{members}{$obj} ) {
                print "[x10_scene] An x10 object ("
                  . $obj->{obj_id}
                  . ") already exists "
                  . "in this scene.  Aborting add request.\n"
                  if $main::Debug{x10_scene};
                return;
            }
            if (   $obj->isa('X10_Switchlinc')
                or $obj->isa('X10_Lamplinc')
                or $obj->isa('X10_Appliancelinc')
                or $obj->isa('X10_Keypadlinc') )
            {
                $on_level = '100%' unless $on_level;
                $$self{members}{$obj}{on_level}  = $on_level;
                $$self{members}{$obj}{object}    = $obj;
                $$self{members}{$obj}{ramp_rate} = $ramp_rate
                  if $ramp_rate and !( $obj->isa('X10_Appliancelinc') );
            }
            else {
                &::print_log( "The x10 object ("
                      . $obj->{x10_id}
                      . ") is not a member of "
                      . "the switchlinc family and cannot be added to this scene!"
                );
            }
        }
        else {
            &::print_log( "Unable to add object to scene "
                  . $self->{object_name}
                  . " because it does not have an x10 address" );
        }
    }
}

# unenrolls member(s) from scene
# deletes (object) member if passed in; otherwise, deletes all members

sub remove_member {
    my ( $self, $member ) = @_;
    if ( $$self{members} ) {
        for my $x10_obj_ref ( keys %{ $$self{members} } ) {
            my $x10_obj = $$self{members}{$x10_obj_ref}{object};
            if ( $x10_obj
                and ( !( defined($member) ) or ( $x10_obj eq $member ) ) )
            {
                $x10_obj->set( 'remove from scene', $self );
                $$self{scene_item}->set('manual');
                delete( $$self{members}{$x10_obj_ref} );
                last if $member;
            }
            else {
                &::print_log(
                    "Unable to add object to scene " . $self->{object_name} );
            }
        }
    }
}

# convenience method as invoking a null arg remove_member isn't obvious
sub remove_all_members {
    my ($self) = @_;
    $self->remove_member();
}

sub get_member_on_level {
    my ( $self, $obj ) = @_;

    # OFF is the default
    my $on_level = 'off';
    if ( $$self{members} && $$self{members}{$obj} ) {
        $on_level = $$self{members}{$obj}{on_level}
          if $$self{members}{$obj}{on_level};
    }
    return $on_level;
}

sub enroll {
    my ($self) = @_;
    if ( $$self{members} ) {
        for my $x10_obj_ref ( keys %{ $$self{members} } ) {
            my $x10_obj = $$self{members}{$x10_obj_ref}{object};
            if ($x10_obj) {

                # first, set the on-level for the target device, it will be used as the
                # default value during the add to scene enrollment
                print "[x10_scene] enrolling: "
                  . $x10_obj->{object_name}
                  . " with on_level: "
                  . $$self{members}{$x10_obj_ref}{on_level} . "\n"
                  if $main::Debug{x10_scene};
                $x10_obj->set( $$self{members}{$x10_obj_ref}{on_level}, $self );
                $x10_obj->set( 'add to scene',                          $self );
                $$self{scene_item}->set('manual');

                # now, set the ramp_rate if it was passed in on add
                # TO-DO - also validate that x10_obj isa X10_Switchlinc, X10_Keypadlinc or X10_Lamplinc
                if ( $$self{members}{$x10_obj_ref}{ramp_rate} ) {

                    # first, set the ramp rate for the target device; it will be used as the
                    # default value during the set scene ramp rate operation
                    print "[x10_scene] setting: "
                      . $x10_obj->{object_name}
                      . " during enroll with ramp_rate: "
                      . $$self{members}{$x10_obj_ref}{ramp_rate} . "\n"
                      if $main::Debug{x10_scene};
                    $x10_obj->set( $$self{members}{$x10_obj_ref}{ramp_rate},
                        $self );
                    $x10_obj->set( 'set scene ramp rate', $self );
                    $$self{scene_item}->set('manual');
                }
            }
            else {
                &::print_log(
                    "Unable to add object to scene " . $self->{object_name} );
            }
        }
    }
}

# allows a restore of members' original state values; no restore occurs if
# the scene has not been set on prior to a resume
sub resume {
    my ($self) = @_;
    if ( $$self{members} ) {
        for my $x10_obj_ref ( keys %{ $$self{members} } ) {
            my $x10_obj        = $$self{members}{$x10_obj_ref}{object};
            my $original_state = $$self{members}{$x10_obj_ref}{original_state};
            if ( ref $x10_obj and defined $original_state ) {
                $x10_obj->set( $original_state, $self );
                print "[x10_scene] Restore object ("
                  . $x10_obj->{object_name}
                  . ") state to scene "
                  . $self->{object_name} . "\n"
                  if $main::Debug{x10_scene};
            }
            else {
                my $obj_name = ($x10_obj) ? $x10_obj->{object_name} : 'unknown';
                print
                  "[x10_scene] Unable to restore object ($obj_name) state to scene ("
                  . $self->{object_name} . ")\n"
                  if $main::Debug{x10_scene};
            }
        }
    }
}

sub set {
    my ( $self, $p_state, $p_setby, $p_response ) = @_;

    my $is_cascade = 0;

    # if is_cascade, then we're re-entering a second time (via the tied scene_item)
    # is_cascade used to avoid duplicate/unnecessary actions
    if (
           $p_setby eq $$self{scene_item}
        && $p_setby->can('get_set_by')
        && (   ( ref $p_setby->get_set_by )
            or
            ( $p_setby->get_set_by eq "scene [" . $self->{object_name} . "]" ) )
      )
    {
        $is_cascade = 1;
    }
    return
      if !($is_cascade)
      && &main::check_for_tied_filters( $self, $p_state, $p_setby );

    if ( $p_setby eq $$self{scene_item} ) {
        if ( $p_state eq 'on' ) {
            for my $x10_obj_ref ( keys %{ $$self{members} } ) {
                my $x10_obj = $$self{members}{$x10_obj_ref}{object};
                if ($x10_obj) {

                    # maintain original state to provide resume capability; but, only on "set on"
                    $$self{members}{$x10_obj_ref}{original_state} =
                      $x10_obj->state;

                    # sync the value for the on_level to the x10 object (as it's not communicated)
                    $x10_obj->set_receive(
                        $$self{members}{$x10_obj_ref}{on_level}, $self );
                    print "[x10_scene] Setting "
                      . $x10_obj->{object_name} . " to "
                      . $$self{members}{$x10_obj_ref}{on_level}
                      . " for scene: "
                      . $self->{object_name} . "\n"
                      if $main::Debug{x10_scene};
                }
                else {
                    print "[x10_scene] Unable to maintain scene ("
                      . $self->{object_name}
                      . ") state for object\n"
                      if $main::Debug{x10_scene};
                }
            }
        }
        elsif ($p_state eq 'off'
            or $p_state eq 'brighten'
            or $p_state eq 'dim' )
        {
            for my $x10_obj_ref ( keys %{ $$self{members} } ) {
                my $x10_obj = $$self{members}{$x10_obj_ref}{object};
                if ($x10_obj) {
                    $x10_obj->set_receive( $p_state, $self );
                    print "[x10_scene] Setting "
                      . $x10_obj->{object_name} . " to "
                      . $p_state
                      . " for scene: "
                      . $self->{object_name} . "\n"
                      if $main::Debug{x10_scene};
                }
                else {
                    print "[x10_scene] Unable to maintain scene ("
                      . $self->{object_name}
                      . ") state for object\n"
                      if $main::Debug{x10_scene};
                }
            }
        }
    }
    else {
        # create a "special" setby name as the tied_items in the main loop would otherwise
        # prohibit using $self if the passed $p_setby is not an object; if it is an object
        # then preserve as the setby chain needs to be maintained
        my $m_setby =
          ( ref $p_setby ) ? $p_setby : "scene [" . $self->{object_name} . "]";
        if ( $p_state eq 'on' ) {
            $$self{scene_item}->set( 'on', $m_setby );
            print "[x10_scene] Setting scene ("
              . $self->{object_name}
              . ") on\n"
              if $main::Debug{x10_scene};
        }
        elsif ( $p_state eq 'off' ) {
            $$self{scene_item}->set( 'off', $m_setby );
            print "[x10_scene] Setting scene ("
              . $self->{object_name}
              . ") off\n"
              if $main::Debug{x10_scene};
        }
        elsif ( $p_state eq 'brighten' ) {
            $$self{scene_item}->set( 'brighten', $m_setby );
            print "[x10_scene] Setting scene ("
              . $self->{object_name}
              . ") brighten\n"
              if $main::Debug{x10_scene};
        }
        elsif ( $p_state eq 'dim' ) {
            $$self{scene_item}->set( 'dim', $m_setby );
            print "[x10_scene] Setting scene ("
              . $self->{object_name}
              . ") dim\n"
              if $main::Debug{x10_scene};
        }
        elsif ( $p_state eq 'resume' ) {
            $self->resume();
            print "[x10_scene] Setting scene ("
              . $self->{object_name}
              . ") resume\n"
              if $main::Debug{x10_scene};
        }
        elsif ( $p_state eq 'manual' ) {
            $$self{scene_item}->set('manual');
        }
    }
    $self->SUPER::set( $p_state, $p_setby, $p_response )
      if ( $p_state eq 'on'
        or $p_state eq 'off'
        or $p_state eq 'brighten'
        or $p_state eq 'dim'
        or $p_state eq 'resume'
        or $p_state eq 'manual' );
}

