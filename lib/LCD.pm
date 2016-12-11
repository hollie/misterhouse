
=head1 B<LCD>

=head2 SYNOPSIS

  my %lcd_keymap1 = ( N => 'up', I => 'down', M => 'left', H => 'right', F => 'exit', K => 'enter', L => 'left', G => 'right');
  my %lcd_keymap2 = ( 38=> 'up', 40=> 'down', 37=> 'left', 39=> 'right', 17=> 'exit', 96=> 'enter') ;

  $lcd1 = new LCD  'lcdproc', '192.168.0.5:13666', '4x20', 'default', \%lcd_keymap1;
  $lcd2 = new LCD 'keyboard',               undef, '4x20', 'mh',      \%lcd_keymap2;

=head2 DESCRIPTION

Send and receive data to LCD type displays with keypads

=head2 INHERITS

B<NONE>

=head2 METHODS

=over

=item C<new($type, $port, $size, $menu_group, $keymap)>

  $type:  Either lcdproc or keyboard.
  $port:  The ip:port of where lcdproc is running.
  $size:  ROWSxCOLUMNS of the LCD display.
  $menu_group:  The menu parsed by menu_parse (see Menu section of this doc).
  $keymap: A has that translates keys to usable names.

=cut

use strict;

package LCD;

sub new {
    my ( $class, $type, $port, $size, $menu_group, $keymap_ptr ) = @_;
    $menu_group = 'default' unless $menu_group;

    my $self = { type => $type, port => $port, menu_group => $menu_group };

    $size = '4x20' unless $size;
    my @s = split 'x', $size;
    $$self{dy_max} = $s[0] - 1;
    $$self{dx_max} = $s[1] - 1;
    $$self{keymap} = $keymap_ptr;

    # Create other sub objects
    $$self{keypad} = new main::Generic_Item;
    $$self{keypad}->set_casesensitive();
    $$self{timer} = new main::Timer;

    if ( $type eq 'lcdproc' ) {
        $$self{object} =
          new main::Socket_Item( undef, undef, $port, 'lcdproc' );
    }

    # lcdserial is Ian Davidson's code for talking to his custom
    # rf lcd device.  It could be generalized for other serial
    # attached lcd devices.  More info on Ian's lcd here:
    #  http://www.galeforce9.btinternet.co.uk/RF_LCD_REMOTE.htm
    elsif ( $type eq 'lcdserial' ) {
        $$self{object} = new main::Serial_Item( undef, undef, $port );
    }

    # Use a posthook, so the menus get parsed first on startup
    &::MainLoop_post_add_hook( \&LCD::process, 0, $self );

    bless $self, $class;
    return $self;
}

=item C<start>

Connect to the LCD.  Automatically called on startup

=cut

sub start {
    my ($self) = @_;
    my $object = $$self{object};
    if ( $$self{type} eq 'lcdproc' ) {
        unless ( active $object) {
            &main::print_log("Starting lcdproc port $$self{port}");
            start $object;
        }
        set $object "\nhello\n";
        my $data;
        $data = "client_set name {MisterHouse)}\n";
        $data .= "screen_add mh1\n";
        for my $i ( 1 .. 1 + $$self{dy_max} ) {
            $data .= "widget_add mh1 $i string\n";
        }
        set $object $data;
    }

}

=item C<stop>

Disconnect the LCD.

=cut

sub stop {
    my ($self) = @_;
    my $object = $$self{object};
    if ( $$self{type} eq 'lcdproc' ) {
        if ( active $object) {
            &main::print_log("Stopping lcdproc port $$self{port}");
            stop $object;
        }
    }
}

=item C<load($menu)>

Load menu $menu.  Default menu is the first one.

=cut

sub load {
    my ( $self, $menu ) = @_;
    &main::menu_lcd_load( $self, $menu );
}

=item C<check_key>

Returns whatever key is keyed in

=cut

# Check for incoming key or info from the lcd
sub check_key {
    my ($self) = @_;
    my $object = $$self{object};
    if ( $$self{type} eq 'lcdproc' ) {
        if ( my $data = $object->said ) {

            # Seens to not be needed, maybe never was needed?
            #           $data = substr $data, 1;   # The first byte is 0!!??
            if ( $data =~ /^key.(\S)/ ) {
                set_key $self $1;
            }
            return $data;
        }
    }
    elsif ( $$self{type} eq 'lcdserial' ) {
        if ( my $data = $object->said ) {
            if ( $data =~ /UUUUUA/ ) {
                my $key_is = substr( $', 0, 1 );
                $key_is = "B" if $key_is eq "*";
                $key_is = "E" if $key_is eq "#";
                set_key $self $key_is;

                #print "incoming=$key_is \n";
            }

            #print "data is: $data";
        }
    }
    elsif ( $$self{type} eq 'keyboard' ) {
        $self->set_key($main::Keyboard) if defined $main::Keyboard;
    }

}

# Send display data to the lcd
sub send_display {
    my ($self) = @_;
    $$self{refresh} = 0;
    my $object = $$self{object};

    if ( $$self{type} eq 'lcdproc' ) {

        # Sometimes we loose the socket connection, so restart
        unless ( $object->active ) {
            print "\n\ndb LCD.pm lcdproc not active ... restarting\n\n";
            $self->start;
        }

        # Send only changed lines
        my ( $data, $line );
        for my $i ( 0 .. $$self{dy_max} ) {
            $line = $$self{display}[$i];
            $line = ' ' unless $line;
            $line =~ s/\n.*//s;    # Use only the first line of data
            my $j = $i + 1;
            $data .= "widget_set mh1 $j 1 $j {$line}\n"
              unless defined $$self{display_prev}[$i]
              and $line eq $$self{display_prev}[$i];
            $$self{display_prev}[$i] = $line;
        }
        $object->set($data) if $data;
    }
    elsif ( $$self{type} eq 'lcdserial' ) {
        my ( $lcd_header, $lcd_footer, $line_pos );
        $lcd_header = "UUUUU" . chr(16);
        $lcd_footer = chr(16) . chr(16);

        # Send only changed lines
        my ( $data, $line );
        for my $i ( 0 .. $$self{dy_max} ) {
            $line = $$self{display}[$i];
            $line = ' ' unless $line;
            $line =~ s/\n.*//s;    # Use only the first line of data
            my $j = $i + 1;
            $line_pos = chr(254) . chr(1) . chr(254) . chr(128) if $j == 1;
            $line_pos = chr(254) . chr(192) if $j == 2;
            $data .= "$lcd_header" . "$line_pos" . "{$line}" . "$lcd_footer"
              unless defined $$self{display_prev}[$i]
              and $line eq $$self{display_prev}[$i];
            $$self{display_prev}[$i] = $line;
        }

        #print "$object  $data \n";
        $object->set($data) if $data;
    }

    elsif ( $$self{type} eq 'keyboard' ) {
        my $sep = '_' x $$self{dx_max};
        print "$sep\n";
        for my $i ( 0 .. $$self{dy_max} ) {
            print "$$self{display}[$i]\n";
        }
        print "$sep\n";
    }
}

=item C<set(@data)>

Sends @data to the LCD, one line per list element

=cut

# Set the data to display
sub set {
    my ( $self, @data ) = @_;
    @{ $$self{display} } = @data;
    $$self{refresh} = 1;
}

=item C<set_key($key)>

Simulates the keyboard being pressed with $key

=cut

# Set the key entered
sub set_key {
    my ( $self, $data ) = @_;
    $$self{keypad}->set($data);
}

# Echo the key entered
sub said_key {
    my ($self) = @_;
    my $state = $$self{keypad}->said;
    $$self{timer}->set(10) if defined $state;
    return $state;
}

=item C<inactive>

Returns true if no key has been pressed in 10 seconds.

=cut

# Check for recent key activity
sub inactive {
    my ($self) = @_;
    my $timer = $$self{timer};
    return inactive $timer;
}

# This is called on every pass to check for key data
# and update the display.
sub process {
    my ($self) = @_;
    my $key;

    $self->start if $main::Startup;
    $self->load  if $main::Reread;    # Loads the first lcd menu

    # Check for incoming key data
    $self->check_key;

    # Process key data
    &main::menu_lcd_navigate( $self, $key )
      if defined( $key = $self->said_key );

    # If refresh needed, send new data to the display
    $self->send_display if $$self{refresh};

    # Displayed delayed last response text
    if (    $main::Menus{menu_data}{last_response_loop}
        and $main::Menus{menu_data}{last_response_loop} <= $main::Loop_Count )
    {
        $main::Menus{menu_data}{last_response_loop} = 0;

        #       &main::menu_lcd_display($self, &main::last_response, $main::Menus{menu_data}{last_response_menu});
        &main::menu_lcd_display( $main::Menus{menu_data}{last_response_object},
            &main::last_response, $main::Menus{menu_data}{last_response_menu} );
    }

}

1;

=back

=head2 INI PARAMETERS

NONE

=head2 AUTHOR

UNK

=head2 SEE ALSO

An example is in mh/code/bruce/lcd.pl. To use simulate an LCD keypad with your pc keyboard, use mh/code/bruce/lcd_keyboard.pl.

=head2 LICENSE

This program is free software; you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation; either version 2 of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more details.

You should have received a copy of the GNU General Public License along with this program; if not, write to the Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.

=cut

#
# $Log: LCD.pm,v $
# Revision 1.8  2003/04/20 21:44:07  winter
#  - 2.80 release
#
# Revision 1.7  2003/03/09 19:34:41  winter
#  - 2.79 release
#
# Revision 1.6  2002/05/28 13:07:51  winter
# - 2.68 release
#
# Revision 1.5  2001/12/16 21:48:41  winter
# - 2.62 release
#
# Revision 1.4  2001/09/23 19:28:11  winter
# - 2.59 release
#
# Revision 1.3  2001/08/12 04:02:58  winter
# - 2.57 update
#
#
