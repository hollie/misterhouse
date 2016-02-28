
=head1 B<AudiotronPlayer>

=head2 SYNOPSIS

NONE

=head2 DESCRIPTION

This uses only:

  - httpq  (a winamp plugin, available at: http://karv.dyn.dhs.org/winamp or http://gulf.uvic.ca/~karvanit/winamp/)

This just turns the player on,off,pause, etc.  Mp3Control.pm controls starting the mp3 player with a list of songs or a playlist

=head2 INHERITS

B<Generic_Item>

=head2 METHODS

=over

=item B<UnDoc>

=cut

#!/usr/bin/perl
use strict;

package AudiotronPlayer;
@AudiotronPlayer::ISA = ('Generic_Item');

my @audiotronplayer_object_list;

sub new {
    my ( $class, $address ) = @_;

    my $self = { address => $address };
    bless $self, $class;

    push( @audiotronplayer_object_list, $self );

    # See http://gulf.uvic.ca/~karvanit/winamp/commands.html
    push(
        @{ $$self{states} },
        'play',     'pause',      'stop',   'next',
        'prev',     'random',     'repeat', 'randomsong',
        'volumeup', 'volumedown', 'clear'
    );

    print "AudiotronPlayer $address created" . "\n";

    #my $apimsgurl = "http://" . $self->{address} . "/apimsg.asp?line1=";
    #::get $apimsgurl . "Misterhouse startup&line2=Audiotron initizalized";

    return $self;
}

sub default_setstate {
    my ( $self, $state, $substate ) = @_;

    print "Audiotron set called: "
      . $self->{address} . " to "
      . $state . ":"
      . $substate . " ";

    my $apiwebpassword = '';
    $apiwebpassword = "admin:" . $main::config_parms{AudiotronWebPassword} . "@"
      if $main::config_parms{AudiotronWebPassword};

    my $apicmdurl =
      "http://" . $apiwebpassword . $self->{address} . "/apicmd.asp?cmd=";

    my $apiqfile =
      "http://" . $apiwebpassword . $self->{address} . "/apiqfile.asp?type=";

    if ( $state eq 'randomsong' ) {
        ;
    }
    elsif ( $state =~ /playlist/i ) {
        my ($file) = $substate;

        #my ($BasePath, $BaseName) = $file =~ /^(.*)[\\\/](.*)/i;

        $self->{audiotron_last_type} = 'List';

        #$self->{audiotron_last_entry} = $BaseName;
        $self->{audiotron_last_entry} = $file;
        print "Playlist: "
          . $apiqfile
          . $self->{audiotron_last_type}
          . "&file="
          . $self->{audiotron_last_entry};
        print ::filter_cr ::get $apiqfile
          . $self->{audiotron_last_type}
          . "&file="
          . $self->{audiotron_last_entry};
    }
    elsif ( $state =~ /volume/i ) {

        #print  ::filter_cr ::get $apicmdurl . "volume&arg=0";
    }
    elsif ( $state eq "clear" ) {
        print ::filter_cr ::get $apicmdurl . "clear";
    }
    elsif ( $state eq "play" ) {
        if (   $self->{audiotron_last_entry} eq undef
            or $self->{audiotron_last_entry} eq '' )
        {
            $self->set("stop");
            $self->set("clear");
            $self->set("random:on");
            $self->set("repeat:on");
            $self->{audiotron_last_type}  = 'List';
            $self->{audiotron_last_entry} = 'Background';
            print "Playlist: "
              . $apiqfile
              . $self->{audiotron_last_type}
              . "&file="
              . $self->{audiotron_last_entry};
            print ::filter_cr ::get $apiqfile
              . $self->{audiotron_last_type}
              . "&file="
              . $self->{audiotron_last_entry};
        }

        print ::filter_cr ::get $apicmdurl . "play";
    }
    elsif ( $state eq "pause" and $substate eq "on" ) {
        print ::filter_cr ::get $apicmdurl . "pause&arg=1";
    }
    elsif ( $state eq "pause" and $substate eq "off" ) {
        print ::filter_cr ::get $apicmdurl . "pause&arg=-1";
    }
    elsif ( $state eq "pause" ) {
        print ::filter_cr ::get $apicmdurl . "pause&arg=0";
    }
    elsif ( $state eq "stop" ) {
        print ::filter_cr ::get $apicmdurl . "stop";
    }
    elsif ( $state eq "next" ) {
        print ::filter_cr ::get $apicmdurl . "next";
    }
    elsif ( $state eq "prev" ) {
        print ::filter_cr ::get $apicmdurl . "prev";
    }
    elsif ( ( $state eq "shuffle" or $state eq "random" )
        and $substate eq "on" )
    {
        print ::filter_cr ::get $apicmdurl . "random&arg=1";
    }
    elsif ( ( $state eq "shuffle" or $state eq "random" )
        and $substate eq "off" )
    {
        print ::filter_cr ::get $apicmdurl . "random&arg=-1";
    }
    elsif ( $state eq "shuffle" or $state eq "random" ) {
        print ::filter_cr ::get $apicmdurl . "random&arg=0";
    }
    elsif ( $state eq "repeat" and $substate eq "on" ) {
        print ::filter_cr ::get $apicmdurl . "repeat&arg=1";
    }
    elsif ( $state eq "repeat" and $substate eq "off" ) {
        print ::filter_cr ::get $apicmdurl . "repeat&arg=-1";
    }
    elsif ( $state eq "repeat" ) {
        print ::filter_cr ::get $apicmdurl . "repeat&arg=0";
    }

    print "\n";
}

1;

=back

=head2 INI PARAMETERS

NONE

=head2 AUTHOR

bsobel@vipmail.com, August 15, 2000

=head2 SEE ALSO

NONE

=head2 LICENSE

This program is free software; you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation; either version 2 of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more details.

You should have received a copy of the GNU General Public License along with this program; if not, write to the Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.

=cut

