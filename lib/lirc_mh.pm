
=head1 B<lirc_mh>

=head2 SYNOPSIS

To enable this module, you'll need to create the lirc_client socket in your user code like hthis (replace IP:port with your setup):

  use lirc_mh;
  $lirc_client = new  Socket_Item(undef, undef, '192.168.2.12:8765','lirc','tcp','record');

Then,  add code to start the socket:

  if ($Startup) {
    start $lirc_client;
  }

Finally, create an IR_Item like this example:

  # need this to get around default map in IR_Item.pm
  my %map = qw(
  );

  $VCR = new IR_Item 'sony_vcr1', '', 'lirc', \%map;
  # enumerate the states for VCR
  my $vcr_state_list = "0,1,2,3,4,5,6,7,9,8,enter,x2,|<<,>>|,tv/vid,slow,rec,menu,setup,sp_ep,power,display,input_sel,on,off";
  # voice commands
  $v_vcr_remote           = new  Voice_Cmd("SONY_VCR1 [$vcr_state_list]");

  # send IR command when we get a voice command
  if ($state = said $v_vcr_remote) {
     print_log "Setting Sony VCR to $state";
     set $VCR $state;
  }

Here's some example code to receive IR:

  if (my $msg = said $lirc_client) {
     print_log "Lirc message received: $msg";
     my ($code,$act,$key,$remote) = ($msg =~ /([^ ]+) +([^ ]+) +([^ ]+) +([^ ]+) */);
     # do something useful here
  }


=head2 DESCRIPTION

Misterhouse interface for lirc

=head2 INHERITS

B<>

=head2 METHODS

=over

=item B<UnDoc>

=cut

package lirc_mh;
use strict;

sub send {
    my $device  = lc shift;
    my $command = lc shift;

    print "Lirc_mh::send: Device: $device Cmd: $command\n"
      if $main::Debug{lirc};

    if ( $command =~ / / ) {
        my @fields = split / /, $command;
        print "Lirc_mh::send: sending SEND_ONCE $device $command"
          if $main::Debug{lirc};

        my $repeat = @fields[1];

        print "Lirc_mh::send Sending $command $repeat times\n"
          if $main::Debug{lirc};
        set $main::lirc_client "SEND_ONCE $device $command";
    }
    else {
        print "Lirc_mh::send: Sending SEND_ONCE $device $command"
          if $main::Debug{lirc};
        set $main::lirc_client "SEND_ONCE $device $command\n";
    }
    return;
}

sub status {
    set $main::lirc_client "LIST\n";
    return;
}

sub test_code {
    my $device  = shift;
    my $command = shift;
    print "device $device command $command\n";
}

1;

=back

=head2 INI PARAMETERS

NONE

=head2 AUTHOR

Adapted by David Satterfield

=head2 SEE ALSO

NONE

=head2 LICENSE

This program is free software; you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation; either version 2 of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more details.

You should have received a copy of the GNU General Public License along with this program; if not, write to the Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.

=cut

