
=head1 B<Audible_Menu>

=head2 SYNOPSIS

NONE

=head2 DESCRIPTION

This module uses text-to-speech and input from one or two switches to provide access to the Misterhouse menu system for people with severe physical disabilities.

=head2 INHERITS

B<Generic_Item>

=head2 METHODS

=item B<UnDoc>

=cut

use strict;

package Audible_Menu;
@Audible_Menu::ISA = ('Generic_Item');

sub new {
    my ( $class, $menu_group, $delay, $enter, $exit ) = @_;
    $menu_group = 'default' unless $menu_group;
    my $self = { menu_group => $menu_group };
    print "Creating audible menu";

    $$self{dy_max}      = 0;
    $$self{dx_max}      = 999;
    $$self{delay}       = $delay || 5;
    $$self{active}      = 0;
    $$self{noExit}      = $exit ? 0 : 1;
    $$self{exit}        = $exit ? $exit : 0;
    $$self{enter}       = $enter ? $enter : 0;
    $$self{pendingExit} = 0;

    # Create other sub objects
    $$self{keypad} = new main::Generic_Item;

    $$self{input} = new main::Serial_Item;
    $$self{input}->add($enter) if $enter;
    $$self{input}->add($exit)  if $exit;

    $$self{timer} = new main::Timer;

    # Use a posthook, so the menus get parsed first on startup
    &::MainLoop_post_add_hook( \&Audible_Menu::process, 0, $self );

    bless $self, $class;
    return $self;
}

sub load {
    my ( $self, $menu ) = @_;
    &main::menu_lcd_load( $self, $menu );
}

# Check for incoming button push
sub check_key {
    my ($self) = @_;
    my $key;

    return unless $key = $$self{input}->state_now or $key = $main::Keyboard;
    $key = lc chr $key if $key =~ /^\d+$/ and $key > 2 and $main::OS_win;

    #   print "$key\n";
    my $ptr = $$self{menu_ptr}{items}[ $$self{cy} ];

    if ( $key eq $$self{enter} ) {
        if ( $$self{active} ) {
            if ( $$self{pendingExit} ) {
                $$self{pendingExit} = 0;
                &main::menu_lcd_navigate( $self, 'exit' );
                $$self{cy}         = 0;
                $$self{menu_state} = 0;
                $$self{active}     = 0;
                $self->speak_next;
            }
            else {
                if ( !$$ptr{A} ) {
                    &main::menu_lcd_navigate( $self, 'enter' );
                    $$self{cy}         = 0;
                    $$self{menu_state} = 0;
                    $$self{active}     = 0;
                    $self->speak_next;
                }
                else {
                    &main::menu_lcd_navigate( $self, 'enter' );
                }
            }
        }
        else {
            $self->speak_next;
        }
    }
    if ( $key eq $$self{exit} ) {
        if ( $$self{active} ) {
            if (
                $#{ $$self{menu_history} } >= 0 and    # if in submenu and
                $$self{cy} < 1 and                     # at top and
                $$self{menu_state} <= 0                # at first state
              )
            {
                &main::menu_lcd_navigate( $self, 'exit' );
                $$self{cy}         = 0;
                $$self{menu_state} = 0;
                $$self{active}     = 0;
                $self->speak_next;
            }
            else {
                $$self{active} = 0;
            }
        }
        else {
            $$self{cy}         = 0;
            $$self{menu_state} = 0;
            $$self{active}     = 0;
            $self->speak_next;
        }
    }
}

# Speak next menu item
sub speak_next {
    my ($self) = @_;
    my $text;
    $$self{refresh} = 0;
    my $menu = $$self{menu_name};

    if ( $menu eq 'response' ) {
        $text = &main::last_response;
        $text =~ s.^\d+/\d+/\d+ \d+:\d+:\d+ [AP]M ..;    # remove timestamp
        &main::speak($text);
        &main::menu_lcd_navigate( $self, 'exit' );
        $$self{active} = 0;
        return;
    }

    if ( $$self{pendingExit} ) {
        $$self{pendingExit} = 0;
        &main::speak("End of menu");
        $$self{active} = 0;
        return;
    }

    if ( $$self{active} and !$self->advance ) {
        if ( $$self{noExit} and $#{ $$self{menu_history} } >= 0 ) {
            &main::speak("Previous menu");
            $$self{pendingExit} = 1;
            $$self{timer}->set( $$self{delay} );
            return;
        }
        &main::speak("End of menu");
        $$self{active} = 0;
        return;
    }
    my $ptr = $$self{menu_ptr}{items}[ $$self{cy} ];

    #print "$menu state $$self{menu_state} of $#{$$ptr{Dstates}} cy $$self{cy}";

    if ( $$ptr{Dstates} and $#{ $$ptr{Dstates} } > 0 ) {
        $text =
            $$ptr{Dprefix}
          . $$ptr{Dstates}[ $$self{menu_state} ]
          . $$ptr{Dsuffix};
    }
    else {
        $text = $$ptr{D};
    }

    &main::speak($text);
    $$self{timer}->set( $$self{delay} );
    $$self{active} = 1;
}

# Advance to next menu item unless at end
sub advance {
    my ($self) = @_;
    $$self{refresh} = 0;
    my $menu = $$self{menu_name};
    my $ptr  = $$self{menu_ptr}{items}[ $$self{cy} ];

    if (
        ( $$self{cy} >= $$self{menu_cnt} ) and    # if at bottom and
        (
            !( $$ptr{Dstates} and $#{ $$ptr{Dstates} } > 0 )
            or                                    # not multi-state
            ( $$self{menu_state} >= $#{ $$ptr{Dstates} } )
        )
      )
    {                                             # or at last state
        $$self{cy}         = 0;
        $$self{menu_state} = 0;
        return 0;
    }

    if ( ( $$ptr{Dstates} and $#{ $$ptr{Dstates} } > 0 )
        and $$self{menu_state} < $#{ $$ptr{Dstates} } )
    {
        &main::menu_lcd_navigate( $self, 'right' );
    }
    else {
        &main::menu_lcd_navigate( $self, 'down' );
        $$self{menu_state} = 0;
    }
    return 1;
}

# This is called on every pass to check for
# input and speak if active and it's time.
sub process {
    my ($self) = @_;
    my $timer = $$self{timer};

    $self->load if $main::Reread;    # Loads the first menu

    # Check for incoming key data
    $self->check_key;

    # If timer has expired, speak next item
    $self->speak_next if expired $timer and $$self{active};

    # Speak delayed last response text
    if (    $main::Menus{menu_data}{last_response_loop}
        and $main::Menus{menu_data}{last_response_loop} <= $main::Loop_Count )
    {
        $main::Menus{menu_data}{last_response_loop} = 0;
        $self->speak_next;
    }

}

1;

=back

=head2 INI PARAMETERS

NONE

=head2 AUTHOR

By David Norwood, dnorwood2@yahoo.com for Misterhouse, http://www.misterhouse.net by Bruce Winter and many contributors

=head2 SEE ALSO

See mh/code/public/audible_menu.pl for example usage.

=head2 LICENSE

This program is free software; you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation; either version 2 of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more details.

You should have received a copy of the GNU General Public License along with this program; if not, write to the Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.

=cut

