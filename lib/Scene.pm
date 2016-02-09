
=head1 B<Scene>

=head2 SYNOPSIS

Declaration:

The following entries belong in the .mht file

  # declare the scene item
  SCENE, family_room_movie, All_Lights|Scenes

  # add members to the scene
  SCENE_MEMBER, x10_family_light, family_room_movie, 70%, 78%

The first percentage is the "on-level" and extends from 0% to 100%;
it is set to 100% if ommitted.  For non-dimmable items, it must
be 0%, off, 100% or on.

The second percentage is the ramp-rate (see table below);
it is optional and can be unique.  It must be omitted if the
device doest not support fade/ramp rates

States:

  'on'       - all scene members are set to their scene on values and with
               optional ramp rate.  The mh items' state is also set to mirror
               the scene's control
  'off'      - all scene members are set off
  'brighten' - all scene members' state is incremented
  'dim'      - all scene members' state is decremented
  'resume'   - resume is a special state that allows a resumption
               of the original states of the scene's member lights.

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

=head2 DESCRIPTION

Generic Scene base class

=head2 INHERITS

B<Generic_Item>

=head2 METHODS

=over

=cut

package Scene;

use strict;

@Scene::ISA = ('Generic_Item');

sub new {
    my ( $class, $scene_address ) = @_;
    my $self = {};
    bless $self, $class;

    return $self;
}

=item C<add($x10sl_light, $on_level, $ramp_rate)>

Adds a scene member

Note that this does NOT automatically enroll the scene
at the device level.  $on_level and ramp_rate must both be
expressed in percentage.  See ramp rate table below for ramp rate
mapping.  $ramp_rate is optional.

TO-DO: ensure that new member doesn't already exist

=cut

sub add {
    my ( $self, $obj, $on_level, $ramp_rate ) = @_;
    if ( ref $obj ) {
        if ( $$self{members} && $$self{members}{$obj} ) {
            print "[scene] An object ("
              . $obj->{object_name}
              . ") already exists "
              . "in this scene.  Aborting add request.\n"
              if $main::Debug{scene};
            return;
        }
        $on_level = '100%' unless $on_level;
        $$self{members}{$obj}{on_level}  = $on_level;
        $$self{members}{$obj}{object}    = $obj;
        $$self{members}{$obj}{ramp_rate} = $ramp_rate if defined $ramp_rate;
    }
}

=item C<remove_member($x10sl_light)>

Removes a member at the device level.  Consider only using this method sparingly and possibly via Voice_Command.

Unenrolls member(s) from scene

Deletes (object) member if passed in; otherwise, deletes all members

=cut

sub remove_member {
    my ( $self, $member ) = @_;
    if ( $$self{members} ) {
        for my $obj_ref ( keys %{ $$self{members} } ) {
            my $obj = $$self{members}{$obj_ref}{object};
            if ( $obj and ( !( defined($member) ) or ( $obj eq $member ) ) ) {

                #             $obj->set('remove from scene',$self);
                #             $$self{scene_item}->set('manual');
                delete( $$self{members}{$obj_ref} );
                last if $member;
            }
            else {
                &::print_log(
                    "Unable to add object to scene " . $self->{object_name} );
            }
        }
    }
}

=item C<remove_all_members()>

Removes all members defined for a scene at the device level.
Consider only using this method sparingly and possibly via Voice_Command.

Convenience method as invoking a null arg remove_member isn't obvious

=cut

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

=item C<resume>

Allows a restore of members' original state values; no restore occurs if 
the scene has not been set on prior to a resume

=cut

sub resume {
    my ($self) = @_;
    if ( $$self{members} ) {
        for my $obj_ref ( keys %{ $$self{members} } ) {
            my $obj            = $$self{members}{$obj_ref}{object};
            my $original_state = $$self{members}{$obj_ref}{original_state};
            if ( ref $obj and defined $original_state ) {
                $obj->set( $original_state, $self );
                print "[scene] Restore object ("
                  . $obj->{object_name}
                  . ") state to scene "
                  . $self->{object_name} . "\n"
                  if $main::Debug{scene};
            }
            else {
                my $obj_name = ($obj) ? $obj->{object_name} : 'unknown';
                print
                  "[scene] Unable to restore object ($obj_name) state to scene ("
                  . $self->{object_name} . ")\n"
                  if $main::Debug{scene};
            }
        }
    }
}

sub set {
    my ( $self, $p_state, $p_setby, $p_response ) = @_;

    my $is_cascade = 0;

    # if is_cascade, then we're re-entering a second time (via the tied scene_item)
    # is_cascade used to avoid duplicate/unnecessary actions
    if ( $p_setby eq $self ) {
        $is_cascade = 1;
    }
    return
      if !($is_cascade)
      && &main::check_for_tied_filters( $self, $p_state, $p_setby );

    if ( lc($p_state) eq 'on' ) {
        for my $obj_ref ( keys %{ $$self{members} } ) {
            my $obj = $$self{members}{$obj_ref}{object};
            if ($obj) {

                # maintain original state to provide resume capability; but, only on "set on"
                $$self{members}{$obj_ref}{original_state} = $obj->state;

                # sync the value for the on_level to the object (as it's not communicated)
                #                $obj->set_receive($$self{members}{$obj_ref}{on_level}, $self);
                $obj->set( $$self{members}{$obj_ref}{on_level}, $self );
                print "[scene] Setting "
                  . $obj->{object_name} . " to "
                  . $$self{members}{$obj_ref}{on_level}
                  . " for scene: "
                  . $self->{object_name} . "\n"
                  if $main::Debug{scene};
            }
            else {
                print "[scene] Unable to maintain scene ("
                  . $self->{object_name}
                  . ") state for object\n"
                  if $main::Debug{scene};
            }
        }
    }
    elsif ( $p_state eq 'off' or $p_state eq 'brighten' or $p_state eq 'dim' ) {
        for my $obj_ref ( keys %{ $$self{members} } ) {
            my $obj = $$self{members}{$obj_ref}{object};
            if ($obj) {

                #                $obj->set_receive($p_state, $self);
                $obj->set( $p_state, $self );
                print "[scene] Setting "
                  . $obj->{object_name} . " to "
                  . $p_state
                  . " for scene: "
                  . $self->{object_name} . "\n"
                  if $main::Debug{scene};
            }
            else {
                print "[scene] Unable to maintain scene ("
                  . $self->{object_name}
                  . ") state for object\n"
                  if $main::Debug{scene};
            }
        }
    }

    # create a "special" setby name as the tied_items in the main loop would otherwise
    # prohibit using $self if the passed $p_setby is not an object; if it is an object
    # then preserve as the setby chain needs to be maintained
    my $m_setby =
      ( ref $p_setby ) ? $p_setby : "scene [" . $self->{object_name} . "]";
    if ( $p_state eq 'on' ) {
        print "[scene] Setting scene (" . $self->{object_name} . ") on\n"
          if $main::Debug{scene};
    }
    elsif ( $p_state eq 'off' ) {
        print "[scene] Setting scene (" . $self->{object_name} . ") off\n"
          if $main::Debug{scene};
    }
    elsif ( $p_state eq 'brighten' ) {
        print "[scene] Setting scene (" . $self->{object_name} . ") brighten\n"
          if $main::Debug{scene};
    }
    elsif ( $p_state eq 'dim' ) {
        print "[scene] Setting scene (" . $self->{object_name} . ") dim\n"
          if $main::Debug{scene};
    }
    elsif ( $p_state eq 'resume' ) {
        $self->resume();
        print "[scene] Setting scene (" . $self->{object_name} . ") resume\n"
          if $main::Debug{scene};
    }
    elsif ( $p_state eq 'manual' ) {
    }

    $self->SUPER::set( $p_state, $p_setby, $p_response )
      if ( $p_state eq 'on'
        or $p_state eq 'off'
        or $p_state eq 'brighten'
        or $p_state eq 'dim'
        or $p_state eq 'resume'
        or $p_state eq 'manual' );
}

=back

=head2 INI PARAMETERS

NONE

=head2 AUTHOR

Jason Sharpee  jason@sharpee.com

Based on X10_SCENE.pm from:  Gregg Liming  gregg@limings.net

=head2 SEE ALSO

NONE

=head2 LICENSE

This program is free software; you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation; either version 2 of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more details.

You should have received a copy of the GNU General Public License along with this program; if not, write to the Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.

=cut

