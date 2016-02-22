
=head1 B<CID_Server>

=head2 SYNOPSIS

Example initialization:

  use CID_Server;
  $cid_interface1 = new Telephony_Interface(...);
  $cid_item       = new CID_Lookup($cid_interface1);
  $cid_log        = new CID_Log($cid_item);
  $cid_server     = new CID_Server($cid_item);

=head2 DESCRIPTION

Takes caller ID information and transmits it to network aware CID clients

=head2 INHERITS

B<Telephony_Item>

=head2 METHODS

=over

=item B<UnDoc>

=cut

use strict;

my ( @CID_Server_yac_objects, $hooks_added );

use Acid;    # For server CID data to Audry Acid client

package CID_Server;

@CID_Server::ISA = ('Telephony_Item');

sub new {
    my ( $class, $p_Telephony ) = @_;
    my $self = {};

    bless $self, $class;

    $p_Telephony->tie_items( $self, 'cid' ) if defined $p_Telephony;

    unless ( $hooks_added++ ) {
        &::MainLoop_pre_add_hook( \&CID_Server::check_requests, 1 );
    }

    return $self;
}

sub set {
    my ( $self, $p_state, $p_setby ) = @_;
    print "CID_Server set:$p_state\n" if $main::Debug{cid_server};

    if ( $p_state =~ /^CID/i ) {
        if ( lc $p_setby->category() ne 'reject' ) {

            # Service YAC clients
            for my $current_object (@CID_Server_yac_objects) {
                print
                  "CID_Server set calling $current_object->{client_address}\n"
                  if $main::Debug{cid_server};
                $current_object->set( 'cid:'
                      . $p_setby->cid_name() . '~'
                      . $p_setby->formated_number() );
            }

            # Service Acid clients
            &Acid::write( &Acid::CID_TYPE_INCOMING_CALL(),
                $p_setby->cid_name(), $p_setby->formated_number() );

            # Send xAP/xPL data, if xAP/xPL port is opened
            if ( $main::Socket_Ports{'xap_send'} ) {

                #		my $caller = $cid_announce->parse_format($p_setby, '$format1', $::config_parms{local_area_code});
                &xAP::send(
                    'xAP',
                    'CID.Incoming',
                    'CID.Incoming' => {
                        Type           => 'Voice',
                        DateTime       => &::time_date_stamp(20),
                        Phone          => $p_setby->formated_number(),
                        Name           => $p_setby->cid_name(),
                        RNNumber       => 'Available',
                        RNName         => 'Available',
                        Formatted_Date => $::Date_Now,
                        Formatted_Time => $::Time_Now
                    }
                );
                &xPL::sendXpl(
                    '*.*',
                    'CID.BASIC' => {
                        CallType => 'INBOUND',
                        Phone    => $p_setby->formated_number(),
                        CLN      => $p_setby->cid_name()
                    }
                );
            }

        }

    }
    $self->SUPER::set($p_state);
}

sub check_requests {
    if ($::New_Second) {    # Check for new subscribers

        #       print "Checking for acid requests\n";
        &Acid::read();
    }
}

package CID_Server_YAC;

@CID_Server_YAC::ISA = ('Generic_Item');

sub new {
    my ( $class, $client_address ) = @_;
    my $self = {};
    $$self{state}                = '';
    $$self{client_address}       = $client_address;
    $$self{states_casesensitive} = 1;
    bless $self, $class;
    push @CID_Server_yac_objects, $self;
    return $self;
}

sub setstate_cid {
    my ( $self, $substate ) = @_;
    print "CID_Server_YAC ip=$self->{client_address} data:$substate\n"
      if $main::Debug{cid_server};

    if ( $main::config_parms{yacserver_inline} ) {

        # Timeout => 0,  # Does not help with 2 second pauses on unavailable  addresses :(
        if (
            my $sock = new IO::Socket::INET->new(
                PeerAddr => $self->{client_address},
                PeerPort => '10629',
                Proto    => 'tcp'
            )
          )
        {
            $sock->autoflush(1);

            my $yakmessage = '@CALL' . $substate;
            print "CID_Server_YAC socket set:$yakmessage\n"
              if $main::Debug{cid_server};
            print $sock $yakmessage . "\0";
            close $sock;
        }
        else {
            print "CID_Server_YAC set socket creation failed\n";
        }
    }
    else {
        #       my $YacServerProcess = new Process_Item(qq|send_ip_msg $self->{client_address}:10629 "$state"|);
        #       start $YacServerProcess;
        my $yakmessage = '@CALL' . $substate;
        &main::run( qq|send_ip_msg $self->{client_address}:10629 "$yakmessage"|,
            1 );
    }
}

#
# $Log: CID_Server.pm,v $
# Revision 1.4  2004/06/06 21:38:44  winter
# *** empty log message ***
#
# Revision 1.3  2004/02/01 19:24:35  winter
#  - 2.87 release
#
#

1;

=back

=head2 INI PARAMETERS

NONE

=head2 AUTHOR

Bill Sobel
bsobel@vipmail.com

=head2 SEE ALSO

For example see code/common/callerid.pl

=head2 LICENSE

This program is free software; you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation; either version 2 of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more details.

You should have received a copy of the GNU General Public License along with this program; if not, write to the Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.

=cut

