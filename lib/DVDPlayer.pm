
=head1 B<DVDPlayer>

=head2 SYNOPSIS

NONE

=head2 DESCRIPTION

Use with WinDVD 6
Optionally define path to WinDVD in ini file as dvd_program.  Will find last installed WinDVD app by default.  Local only at the moment, so address is always "localhost" will be xAP-enabled in future...

=head2 INHERITS

B<Generic_Item>

=head2 METHODS

=over

=item B<UnDoc>

=cut

#!/usr/bin/perl

use strict;
use Win32::TieRegistry 0.20 ( Delimiter => "/", ArrayValues => 0 )
  ;    # used to find installed WinDVD

package DVDPlayer;
@DVDPlayer::ISA = ('Generic_Item');

my @dvdplayer_object_list;

my $title;    # *** These two should be $self hash.
my $mode;

my $windvd_path;

use vars '$Registry';

sub find_program_path {
    if ( $::config_parms{dvd_program} ) {
        return $::config_parms{dvd_program};
    }
    else {
        unless ($windvd_path) {
            $windvd_path = $Registry->{
                'Classes/Applications/Windvd.exe/shell/open/command//'};
            $windvd_path = $1 if $windvd_path =~ /"(.*?)"/;
            $windvd_path =~
              s/\x20"*\%\d"*//g;   # remove parameter templates (%1, "%2", etc.)
        }
        return $windvd_path;
    }

}

sub new {
    my ( $class, $address ) = @_;

    my $self = { address => $address };
    bless $self, $class;

    push( @dvdplayer_object_list, $self );

    push(
        @{ $$self{states} },
        'play',             'pause',          'stop',
        'rewind',           'fast forward',   'step',
        'skip forward',     'instant replay', 'full screen',
        'root menu',        'title menu',     'volume down',
        'volume up',        'mute',           'brightness up',
        'brightness down',  'chapter',        'next chapter',
        'previous chapter', 'on',             'off',
        '0',                '1',              '2',
        '3',                '4',              '5',
        '6',                '7',              '8',
        '9',                'angle',          'audio',
        'subtitle',         'unzoom',         'pan',
        'bookmark',         'capture',        'on',
        'off'
    );
    return $self;
}

sub default_setstate {
    my ( $self, $state ) = @_;
    print "DVD Player set to " . $state . "\n" if $::Debug{windvd};
    windvd_control( $state, $self->{address} );
    return;
}

sub get_title {
    return $title;
}

sub get_mode {
    return $mode;
}

sub windvd_control {
    my ($command) = @_;
    my $windvd_path;

    $windvd_path = find_program_path();

    if ( $command =~ /^play "(.*)"/ ) {

        # run command line
        print(  "DVDPlayer::windvd_control: Running "
              . qq[$windvd_path "$::config_parms{dvd_archives_folder}\\video_ts\\VTS_01_0.ifo"]
              . "\n" )
          if $::Debug{windvd};

        # *** Find the IFO!

        &::run(
            qq|"$windvd_path" "$::config_parms{dvd_archives_folder}\\$1\\video_ts\\VTS_01_0.ifo"|
        );

        $title = $1;

    }
    else {

        # *** move to running function below

        my $window;
        my $fresh;
        my $retries = 0;

        # Start windvd, if it is not already running (localhost only)

        while ( $retries++ < 3 and !$window ) {
            print "Trying to find WinDVD attempt #$retries\n"
              if $::Debug{windvd};
            $window =
              &::sendkeys_find_window( 'Intervideo WinDVD', $windvd_path );
        }

        $fresh = $retries;

        my $result;

        if ($window) {
            print "Found WinDVD window: $window\n"  if $::Debug{windvd};
            print "Sending DVD command: $command\n" if $::Debug{windvd};

            if ( $command eq 'play' ) {
                $result = &::SendKeys( $window, '\\RET\\', 1 );
                $mode   = 1;
                $title  = undef if $fresh;
            }
            elsif ( $command eq 'stop' ) {
                $result = &::SendKeys( $window, '\\END\\', 1 );
                $mode = 0;
            }
            elsif ( $command eq 'pause' ) {
                $result = &::SendKeys( $window, ' ', 1 );
                $mode = 3;
            }
            elsif ( $command eq 'previous chapter' ) {
                $result = &::SendKeys( $window, '\\PGUP\\', 1 );
            }
            elsif ( $command eq 'next chapter' ) {
                $result = &::SendKeys( $window, '\\PGDN\\', 1 );
            }
            elsif ( $command eq 'up' ) {
                $result = &::SendKeys( $window, '\\UP\\', 1 );
            }
            elsif ( $command eq 'down' ) {
                $result = &::SendKeys( $window, '\\DOWN\\', 1 );
            }
            elsif ( $command eq 'left' ) {
                $result = &::SendKeys( $window, '\\LEFT\\', 1 );
            }
            elsif ( $command eq 'right' ) {
                $result = &::SendKeys( $window, '\\RIGHT\\', 1 );
            }
            elsif ( $command eq 'controls' ) {
                $result = &::SendKeys( $window, 'q', 1 );
            }
            elsif ( $command eq 'subtitle' ) {
                $result = &::SendKeys( $window, 's', 1 );
            }
            elsif ( $command eq 'mute' ) {
                $result = &::SendKeys( $window, 'm', 1 );
            }
            elsif ( $command eq 'bookmark' ) {
                $result = &::SendKeys( $window, 'k', 1 );
            }
            elsif ( $command eq 'capture' ) {
                $result = &::SendKeys( $window, 'p', 1 );
            }
            elsif ( $command eq 'chapter' ) {
                $result = &::SendKeys( $window, 'c', 1 );
            }
            elsif ( $command eq 'audio' ) {
                $result = &::SendKeys( $window, 'a', 1 );
            }
            elsif ( $command eq 'angle' ) {
                $result = &::SendKeys( $window, 'g', 1 );
            }
            elsif ( $command eq 'title menu' ) {
                $result = &::SendKeys( $window, 't', 1 );
            }
            elsif ( $command eq 'on' ) {
                $result = 1;
            }
            elsif ( $command eq 'off' ) {
                $result = &::SendKeys( $window, '\\ALT+\\\\F4\\\\ALT-\\', 1 );
            }
            elsif ( $command eq 'root menu' ) {
                $result = &::SendKeys( $window, '\\CTRL+\\m\\CTRL-\\', 1 );
            }
            elsif ( $command =~ /^rew/i ) {
                $result = &::SendKeys( $window, 'r', 1 );
            }
            elsif ( $command eq 'fast forward' or $command =~ /^ff/i ) {
                $result = &::SendKeys( $window, 'f', 1 );
            }
            elsif ( $command eq 'skip forward' ) {
                $result = &::SendKeys( $window, '\\CTRL+\\q\\CTRL-\\', 1 );
            }
            elsif ( $command eq 'instant replay' ) {
                $result = &::SendKeys( $window, '\\CTRL+\\mb\\CTRL-\\', 1 );
            }
            elsif ( $command eq 'step' ) {
                $result = &::SendKeys( $window, 'n', 1 );
            }
            elsif ( $command eq 'eject' ) {
                $result = &::SendKeys( $window, 'e', 1 );
            }
            elsif ( $command eq 'volume up' ) {
                $result =
                  &::SendKeys( $window, '\\SHIFT+\\\\UP\\\\SHIFT-\\', 1 );
            }
            elsif ( $command eq 'volume down' ) {
                $result =
                  &::SendKeys( $window, '\\SHIFT+\\\\DOWN\\\\SHIFT-\\', 1 );
            }
            elsif ( $command eq 'brightness up' ) {
                $result = &::SendKeys( $window, '\\SHIFT+\\+\\SHIFT-\\', 1 );
            }
            elsif ( $command eq 'brightness down' ) {
                $result = &::SendKeys( $window, '-', 1 );
            }
            elsif ( $command eq 'off' ) {
                $result = &::SendKeys( $window, 'x', 1 );
            }
            elsif ( $command eq 'full screen' ) {
                $result = &::SendKeys( $window, 'z', 1 );
            }
            elsif ( $command eq 'unzoom' ) {
                $result = &::SendKeys( $window, 'u', 1 );
            }
            elsif ( $command eq 'pan' ) {
                $result = &::SendKeys( $window, 'i', 1 );
            }
            elsif ( $command =~ /(\d)/ ) {    #numeric keys select chapters
                $result = &::SendKeys( $window, $1, 1 );
            }
            warn "DVDPlayer::windvd_control:Unable to execute command:$command"
              unless ($result);
        }
        else {
            warn "DVDPlayer::windvd_control:Unable to start DVD player";
        }
    }
}

# start process, sendkeys, etc. (see new Winamp code)

sub dvd_running {

}

1;

=back

=head2 INI PARAMETERS

NONE

=head2 AUTHOR

UNK

=head2 SEE ALSO

NONE

=head2 LICENSE

This program is free software; you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation; either version 2 of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more details.

You should have received a copy of the GNU General Public License along with this program; if not, write to the Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.

=cut

