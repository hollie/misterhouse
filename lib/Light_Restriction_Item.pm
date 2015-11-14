
=head1 B<Light_Restriction_Item>

=head2 SYNOPSIS

Example initialization:

  # noloop=start
  use Light_Restriction_Item;
  my $only_when_dark = new Light_Restriction_Item();
  $only_when_dark->attach_scalar(\$Dark);
  # noloop=stop

  $om_auto_master_bath_light->add($om_motion_master_bath,
  $om_presence_master_bath, $only_when_dark);

Input states:

  # To enable the tied light
  set $test_restrict ON;
  set $test_restrict 'light_ok';

  # To disable the tied light
  set $test_restrict OFF;
  set $test_restrict 'no_light';

Output states:  State is either 'light_ok' or 'no_light'

Attaching to a scalar:  You can attach to a scalar to automatically allow or disallow lights based on its value.  Any number of "light ok" values are allowed:

  # Light can turn on when $Dark is true
  # (defaults to true when no OK values are given)
  $only_when_dark->attach_scalar(\$Dark);

  # Light can turn on when the current second is 0-9
  $test_restrict->attach_scalar(\$Second, 0, 1, 2, 3, 4, 5, 6 , 7, 8, 9);

Obviously the scalar could be your own variable and you can use whatever logic you desire to determine its value and whatever frequency you desire.  The value is checked once every second.

Attaching to a hash:  Although you can attach to a hash entry by doing this:

  $only_when_dark->attach_scalar(\$hash_name{hash_key});

Sometimes this reference becomes invalid.  In particular, the %Save hash is sometimes reloaded and the references to the values change.  So, I recommend attaching to hash values as follows:

  $only_when_dark->attach_hash_key(\%hash_name, 'hash_key');

As with the functions above and below, these parameters can be followed by a list of any number of "okay" values.

Attaching to an object:  You can attach to another object to automatically allow or disallow  lights based on its state.  Any number of "light ok" values are allowed:

  # Only allow lights to turn on when mode_occupied is 'home'
  $only_when_home->attach_object($mode_occupied, 'home');

  # Only allow lights to turn on when mode_sleeping is 'nobody'
  $only_when_awake->attach_object($mode_sleeping, 'nobody');

=head2 DESCRIPTION

Use this object with predictive/automatic lighting (i.e. Occupancy_Monitor.pm and Light_Item.pm) to place certain restrictions on when lights should and should not come on.

=head2 INHERITS

B<Base_Item>

=head2 METHODS

=over

=item B<UnDoc>

=cut

use strict;
use Base_Item;

package Light_Restriction_Item;

@Light_Restriction_Item::ISA = ('Base_Item');

my @CheckScalars;
my @CheckStartup;

sub initialize {
    my ($self) = @_;
    $$self{m_write}            = 0;
    $$self{state}              = 'light_ok';
    $$self{'hash_ref'}         = undef;
    $$self{'hash_key'}         = undef;
    $$self{'scalar_ref'}       = undef;
    $$self{'ok_values'}        = undef;
    $$self{'last_watched_val'} = undef;
    $$self{'attached_object'}  = undef;
}

sub _check_values {
    if ( $main::Startup or $main::Reload ) {
        foreach (@CheckStartup) {
            if ( $$_{'attached_object'} ) {
                &::print_log(
                    "$$_{object_name}: Checking attached object after startup")
                  if $main::Debug{occupancy};
                $_->_check_watched_value( $$_{'attached_object'}->state() );
            }
        }
    }
    if ($main::New_Second) {
        foreach (@CheckScalars) {
            $_->_check_scalar();
        }
    }
}

sub _check_scalar {
    my ($self) = @_;
    if ( ref $$self{'scalar_ref'} ) {
        $self->_check_watched_value( ${ $$self{'scalar_ref'} } );
    }
    elsif ( ref $$self{'hash_ref'} and $$self{'hash_key'} ) {
        $self->_check_watched_value(
            $$self{'hash_ref'}->{ $$self{'hash_key'} } );
    }
}

sub _check_watched_value ($$) {
    my ( $self, $value ) = @_;
    if ( $value ne $$self{'last_watched_val'} ) {
        &::print_log(
            "$$self{object_name}: New value $value different than $$self{last_watched_val}"
        ) if $main::Debug{occupancy};
        $$self{'last_watched_val'} = $value;
        if ( $$self{'ok_values'} ) {
            foreach ( @{ $$self{'ok_values'} } ) {
                if ( $$self{'last_watched_val'} eq $_ ) {

                    # New scalar value is one of the OK ones
                    &::print_log(
                        "$$self{object_name}: New value $value matches ok values: light_ok"
                    ) if $main::Debug{occupancy};
                    unless ( $self->state() eq 'light_ok' ) {
                        $self->SUPER::set('light_ok');
                    }
                    return;
                }
            }
        }
        else {
            if ( $$self{'last_watched_val'} ) {
                unless ( $self->state() eq 'light_ok' ) {
                    &::print_log(
                        "$$self{object_name}: New value $value is true: light_ok"
                    ) if $main::Debug{occupancy};
                    $self->SUPER::set('light_ok');
                }
                return;
            }
        }
        &::print_log("$$self{object_name}: no_light")
          if $main::Debug{occupancy};
        unless ( $self->state() eq 'no_light' ) {
            $self->SUPER::set('no_light');
        }
    }
}

sub finish_attach {
    my ( $self, @ok_values ) = @_;
    if (@ok_values) {
        @{ $$self{'ok_values'} } = ();
        push @{ $$self{'ok_values'} }, @ok_values;
    }
    else {
        $$self{'ok_values'} = undef;
    }
    if ( ( $#CheckScalars == -1 ) and ( $#CheckStartup == -1 ) ) {
        &::MainLoop_pre_add_hook( \&Light_Restriction_Item::_check_values, 1 );
    }
}

sub attach_object {
    my ( $self, $p_obj, @ok_values ) = @_;
    $$self{'attached_object'} = $p_obj;
    $p_obj->tie_items($self);
    $self->finish_attach(@ok_values);
    foreach (@CheckStartup) {
        return if ( $_ eq $self );
    }
    push @CheckStartup, $self;
    $self->_check_watched_value( $p_obj->state() );
}

sub attach_hash_key {
    my ( $self, $hash_ref, $hash_key, @ok_values ) = @_;
    if ( ref $hash_ref ) {
        $$self{'hash_ref'} = $hash_ref;
        $$self{'hash_key'} = $hash_key;
        $self->finish_attach(@ok_values);
        foreach (@CheckScalars) {
            return if ( $_ eq $self );
        }
        push @CheckScalars, $self;
    }
    else {
        print
          "ERROR: Light_Restriction_Item::attach_hash_key() called with a non-reference first parameter!\n";
    }
}

sub attach_scalar {
    my ( $self, $scalar_ref, @ok_values ) = @_;
    if ( ref $scalar_ref ) {
        $$self{'scalar_ref'} = $scalar_ref;
        $self->finish_attach(@ok_values);
        foreach (@CheckScalars) {
            return if ( $_ eq $self );
        }
        push @CheckScalars, $self;
    }
    else {
        print
          "ERROR: Light_Restriction_Item::attach_scalar() called with a non-reference first parameter!\n";
    }
}

sub set {
    my ( $self, $p_state, $p_setby, $p_response ) = @_;
    my $l_state;

    if ( $p_setby and ( $p_setby eq $$self{'attached_object'} ) ) {

        # Our tied object's state changed...
        $self->_check_watched_value($p_state) if $p_state;
    }
    else {
        if ( $p_state eq 'on' ) {
            $l_state = 'light_ok';
        }
        elsif ( $p_state eq 'off' ) {
            $l_state = 'no_light';
        }
        else {
            $l_state = $p_state;
        }
        $self->SUPER::set( $l_state, $p_setby, $p_response );
    }

}

1;

=back

=head2 INI PARAMETERS

NONE

=head2 AUTHOR

Kirk Bauer  kirk@kaybee.org

Special Thanks to:  Jason Sharpee jason@sharpee.com  (for Occupancy_Monitor.pm, Light_Item.pm, Presence_Item.pm, etc)

=head2 SEE ALSO

NONE

=head2 LICENSE

This program is free software; you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation; either version 2 of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more details.

You should have received a copy of the GNU General Public License along with this program; if not, write to the Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.

=cut

