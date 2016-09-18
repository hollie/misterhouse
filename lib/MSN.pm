
=head1 B<MSN>

=head2 SYNOPSIS

Example usage:

  $client->connect('username','password', '', {
      Status  => \&Status,
      Answer  => \&Answer,
      Message => \&Message,
      Join    => \&Join}  , 0 );

  while (1) {
      print '.';
      select undef, undef, undef, .1;
      $client->process(0);
  }

=head2 DESCRIPTION

Downloaded from:   http://www.wiredbots.com/tutorial.html  http://adamswann.com/library/2002/msn-perl/

Protocol info:  http://www.hypothetic.org/docs/msn/

Related project that uses MSN.pm with different mods here:  http://webmessenger.sourceforge.net

Changes:

  04/27/2002 : Bruce Winter (bruce@misterhouse.net)
  Split &process out of &connect, so we can make it non-blocking.

=head2 INHERITS

B<NONE>

=head2 METHODS

=over

=item B<UnDoc>

=cut

package MSN;
use strict;

use IO::Socket;
use IO::Select;

#use DBI;
use Digest::MD5 qw(md5 md5_hex md5_base64);

my (
    @Calls,    $Handle,     $Host,   $TrID,   $Port,
    $Password, $CustomName, %Ignore, $Status, $Debug,
    %Socks,    $Master,     $Funcs
);

$TrID = 0;
$Port = 1863;

$Debug = 1;

my $Select = IO::Select->new();

sub new {
    my $proto = shift;
    my $type  = shift || 'NS';
    my $class = ref($proto) || $proto;
    my $self  = {};
    bless( $self, $class );
    $self->{Type} = $type;
    return $self;
}

sub send {
    my $self = shift;
    my ( $cmd, $data ) = @_;
    unless ($cmd) {
        die "MSN->send: No command specified!\n";
    }
    my $datagram = $cmd . ' ' . $TrID++ . ' ' . $data . "\r\n";

    unless ( $self->{Socket} ) {
        print "MSN.pm error:  Not active Socket\n";
        return;
    }

    $self->{Socket}->print($datagram);
    chomp($datagram);

    my $fn = $self->{Socket}->fileno;
    writelog("($fn)TX: $datagram") if ($Debug);
    return length($datagram);
}

sub sendraw {
    my $self = shift;
    my ( $cmd, $data ) = @_;
    unless ($cmd) {
        die "MSN->send: No command specified!\n";
    }

    my $datagram = $cmd . ' ' . $TrID++ . ' ' . $data;
    $self->{Socket}->print($datagram);
    chomp($datagram);
    my $fn = $self->{Socket}->fileno;
    writelog("($fn)SENDRAW: $datagram") if ($Debug);
    return length($datagram);
}

sub sendmsg {
    my $self = shift;
    my ($response) = @_;

    my $header =
      qq{MIME-Version: 1.0\nContent-Type: text/plain; charset=UTF-8\nX-MMS-IM-Format: FN=MS%20Shell%20Dlg; EF=; CO=0; CS=0; PF=0\n\n};

    $header .= $response;
    $header =~ s/\n/\r\n/gs;
    $self->sendraw( 'MSG', 'N ' . length($header) . "\r\n" . $header );
}

sub writelog {
    my $data = shift;
    if ($Debug) {
        print $data, "\n";
    }

    open LOG, ">>/tmp/msn.log";
    print LOG scalar( localtime() ), " ", $data, "\n";
    close LOG;

    return;
}

sub buddyadd {
    my $self = shift;
    my ( $username, $fname ) = @_;
    $self->{Buddies}->{$username}->{FName} = $fname;
    unless ( defined( $self->{Buddies}->{$username}->{Status} ) ) {
        $self->{Buddies}->{$username}->{Status}     = 'NONE';
        $self->{Buddies}->{$username}->{LastChange} = time;
    }
    return 1;
}

sub buddyname {
    my $self = shift;
    my ($username) = @_;
    return $self->{Buddies}->{$username}->{FName};
}

sub call {
    my $self = shift;
    my ($handle) = @_;
    $self->send( 'XFR', 'SB' );
    push( @Calls, $handle );
}

sub buddystatus {
    my $self = shift;
    my ( $username, $status ) = @_;
    if ($status) {
        if ( defined $$Funcs{Status} ) {
            &{ $$Funcs{Status} }( $self, $username, $status );
        }

        $self->{Buddies}->{$username}->{Status}     = $status;
        $self->{Buddies}->{$username}->{LastChange} = time;

        # V2 Employee Handling
        open OUT, ">/tmp/msn.status";
        print OUT time, "\n";
        foreach ( keys %{ $self->{Buddies} } ) {
            print OUT "$_ ", $self->{Buddies}->{$_}->{Status}, " ",
              $self->{Buddies}->{$username}->{LastChange}, "\n";
        }
        close OUT;
    }

    return $self->{Buddies}->{$username}->{Status};
}

sub connect {
    my $self = shift;
    $Handle   = shift;
    $Password = shift;

    #  $Host = shift || 'msgr-ns14.msgr.hotmail.com';
    $Host = shift || 'messenger.hotmail.com';
    $Funcs = shift;
    my $timeout = shift;
    unless ( $Handle && $Password ) {
        die "MSN->connect(Username,Password, [server])\n";
    }

    # Create the socket and add to the Select object.
    $self->{Socket} = IO::Socket::INET->new(
        PeerAddr => $Host,
        PeerPort => $Port,
        Proto    => 'tcp'
    ) or die "$!";
    $Master = $self;
    $Select->add( $self->{Socket} );

    # Map this socket to an object.
    $Socks{ $self->{Socket}->fileno } = \$self;

    # Kick off the conversation!!!
    $self->send( 'VER', 'MSNP2' );    # Get version info (we only suport MSNP2)

    $self->process($timeout);
}

sub process {
    my ( $self, $timeout ) = @_;
    while ( my @ready = $Select->can_read($timeout) ) {
        my $fh;
        foreach $fh (@ready) {

            unless ( $_ = $fh->getline() ) {
                $Select->remove($fh);
                delete( $Socks{ $fh->fileno } );
                next;
            }

            my $self = $Socks{ $fh->fileno };

            s/[\r\n]//g;
            my $fn = $fh->fileno;
            writelog("($fn)RX: $_") if ($Debug);

            my ( $cmd, @data ) = split( / /, $_ );
            if ( $cmd eq 'VER' ) {
                $$self->send('INF');
            }
            elsif ( $cmd eq 'INF' ) {
                $$self->send( 'USR', 'MD5 I ' . $Handle );
            }
            elsif ( $cmd eq 'USR' ) {
                if ( $data[1] eq 'MD5' && $data[2] eq 'S' ) {
                    my $digest = md5( $data[3] . $Password ) . md5($Password);
                    $digest = unpack( "H" . length($digest), $digest );
                    $$self->send( 'USR', 'MD5 S ' . $digest );
                }
                elsif ( $data[1] eq 'OK' ) {
                    if ( $Calls[0] ) {
                        $$self->send( 'CAL', @Calls );
                    }
                    else {
                        $Handle     = $data[2];
                        $CustomName = $data[3];
                        $$self->send( 'CHG', 'NLN' );
                        $$self->send( 'SYN', '0' );
                    }
                }
                else {
                    die "Unsupported authentication method: \"",
                      &join( " ", @data ), "\"\n";
                }
            }
            elsif ( $cmd eq 'XFR' ) {
                if ( $data[1] eq 'NS' ) {
                    ( $Host, $Port ) = split( /:/, $data[2] );
                    $$self->{Socket}->close();
                    $Select->remove( $$self->{Socket} );
                    delete( $Socks{ $$self->{Socket}->fileno } );

                    $$self->{Socket} = IO::Socket::INET->new(
                        PeerAddr => $Host,
                        PeerPort => 1863,
                        Proto    => 'tcp'
                    ) or die "$!";
                    $Select->add( $$self->{Socket} );
                    $Socks{ $$self->{Socket}->fileno } = $self;
                    $$self->send( 'VER', 'MSNP2' );
                }
                elsif ( $data[1] eq 'SB' ) {
                    if ( $Calls[0] ) {
                        my ( $h, undef ) = split( /:/, $data[2] );
                        $$self->{Sessions}->{ $Calls[0] } = MSN->new('SB');
                        $$self->{Sessions}->{ $Calls[0] }->{Socket} =
                          IO::Socket::INET->new(
                            PeerAddr => $h,
                            PeerPort => $Port,
                            Proto    => 'tcp'
                          ) or die "$!";

                        # Add the new connection to the Select structure.
                        $Select->add(
                            $$self->{Sessions}->{ $Calls[0] }->{Socket} );
                        $Socks{ $$self->{Sessions}->{ $Calls[0] }->{Socket}
                              ->fileno } = \$$self->{Sessions}->{ $Calls[0] };
                        $$self->{Sessions}->{ $Calls[0] }->{Key} = $data[4];
                        $$self->{Sessions}->{ $Calls[0] }
                          ->send( 'USR', $Handle . ' ' . $data[4] );
                        $$self->{Sessions}->{ $Calls[0] }->{Type}   = 'SB';
                        $$self->{Sessions}->{ $Calls[0] }->{Handle} = $Calls[0];

                    }
                    else {
                        die
                          "Huh? Recieved XFR SB request, but there are no pending calls!\n";
                    }
                }
            }
            elsif ( $cmd eq 'JOI' ) {
                if ( defined $$Funcs{Join} ) {
                    &{ $$Funcs{Join} }( $self, $$self->{Handle} );
                }
            }
            elsif ( $cmd eq 'BYE' ) {
                print "MSN.pm received a BYE.\n";
                $Select->remove( $$self->{Socket} );
                delete( $Master->{Sessions}->{ $data[1] } );
            }
            elsif ( $cmd eq 'CAL' ) {

                #   print "data[1] = $data[2]\n";

                #   $$self->sendmsg("What's up doc?");
            }
            elsif ( $cmd eq 'RNG' ) {
                my ( $sid, $addr, undef, $key, $chandle, $cname ) = @data;
                my ( $h, undef ) = split( /:/, $addr );
                $$self->{Sessions}->{$chandle} = MSN->new('SB');
                $$self->{Sessions}->{$chandle}->{Socket} =
                  IO::Socket::INET->new(
                    PeerAddr => $h,
                    PeerPort => $Port,
                    Proto    => 'tcp'
                  ) or die "$!";
                $Select->add( $$self->{Sessions}->{$chandle}->{Socket} );
                $Socks{ $$self->{Sessions}->{$chandle}->{Socket}->fileno } =
                  \$$self->{Sessions}->{$chandle};
                $$self->{Sessions}->{$chandle}->{Key}    = $key;
                $$self->{Sessions}->{$chandle}->{Handle} = $chandle;
                $$self->{Sessions}->{$chandle}
                  ->send( 'ANS', "$Handle $key $sid" );
            }
            elsif ( $cmd eq 'ANS' ) {
                my ($response) = @data;

                if ( defined $$Funcs{Answer} ) {
                    &{ $$Funcs{Answer} }( $self, $response )
                      ;    # bbw Added $response
                }

            }
            elsif ( $cmd eq 'MSG' ) {
                my ( $user, $friendly, $length ) = @data;
                my $msg;
                my $response;
                $fh->read( $msg, $length );
                unless ( $msg =~ m{Content-Type: text/x-msmsgscontrol}s ) {
                    $msg = stripheader($msg);
                    if ( $$self->{Type} eq 'SB' ) {
                        if ( defined $$Funcs{Message} ) {
                            &{ $$Funcs{Message} }
                              ( $self, $user, $friendly, $msg );
                        }

                        #                  if ($msg =~ /seen/is) {
                        #                     $msg =~ /seen (.*?)/is;
                        #                     if ($1) {
                        #                        $response = "Huh?  Seen who?";
                        #                     } else {
                        #                        $response = "Here's who I've seen:";
                        #                     }
                        #                  } else {
                        #                     $response = "No comprende."
                        #                  }
                        #                  $$self->sendmsg($response);
                    }
                }
            }
            elsif ( $cmd eq 'LST' ) {
                next unless ( $data[1] eq 'FL' );
                $$self->buddyadd( $data[5], $data[6] );
            }
            elsif ( $cmd eq 'NLN' ) {
                $$self->buddystatus( $data[1], $data[0] );
            }
            elsif ( $cmd eq 'ILN' ) {
                print "recv'd ILN\n\n";

                #$$self->buddystatus($data[2], $data[1]);
            }
            elsif ( $cmd eq 'FLN' ) {
                $$self->buddystatus( $data[0], 'FLN' );
            }
            elsif ( $cmd =~ /[0-9]+/ ) {
                writelog( "ERROR: " . converterror($cmd) );
            }
            elsif ( $cmd eq 'ADD' ) {

                #my $sta = "$data[2]";

                #$$self->buddystatus($emai, $usernam);
                #print "data3: $data[3]\ndata4: $data[4]\n\n";
                my $hhh = 'FL ' . $data[3] . ' ' . $data[4] . '0';
                $$self->send( 'ADD', $hhh );

                # sleep(1);
                my $hhha = 'AL ' . $data[3] . ' ' . $data[4];
                $$self->send( 'ADD', $hhha );

                #print "first..\n";
                # my $hhhz = "NLN $emai $usernam";
                # $$self->send('NLN', $hhhz);
                # print "second..\n";
                #ADD 384
                #ADD 384 FL $email gondaba@hotmail.com 0
                #$$self->buddyadd($emai, $usernam);
                #$$self->send('', "$sta $emai $userna"');
                #ILN 256 NLN f3er@hotmail.com ffffff
                #$$self->send('BPR', $emai, 'PHH');
                #$$self->send('BPR', $emai, 'PHW');
                #$$self->send('BPR', $emai, 'PHM');
                #$$self->send('BPR', $emai, 'MOB', 'N');

            }
            else {
                print "RECIEVED UNKNOWN: $cmd @data\n\n";
            }
        }
    }
}

sub converterror {
    my $err = shift;
    my %errlist;
    $errlist{200} = 'ERR_SYNTAX_ERROR';
    $errlist{201} = 'ERR_INVALID_PARAMETER';
    $errlist{205} = 'ERR_INVALID_USER';
    $errlist{206} = 'ERR_FQDN_MISSING';
    $errlist{207} = 'ERR_ALREADY_LOGIN';
    $errlist{208} = 'ERR_INVALID_USERNAME';
    $errlist{209} = 'ERR_INVALID_FRIENDLY_NAME';
    $errlist{210} = 'ERR_LIST_FULL';
    $errlist{215} = 'ERR_ALREADY_THERE';
    $errlist{216} = 'ERR_NOT_ON_LIST';
    $errlist{218} = 'ERR_ALREADY_IN_THE_MODE';
    $errlist{219} = 'ERR_ALREADY_IN_OPPOSITE_LIST';
    $errlist{280} = 'ERR_SWITCHBOARD_FAILED';
    $errlist{281} = 'ERR_NOTIFY_XFR_FAILED';
    $errlist{300} = 'ERR_REQUIRED_FIELDS_MISSING';
    $errlist{302} = 'ERR_NOT_LOGGED_IN';
    $errlist{500} = 'ERR_INTERNAL_SERVER';
    $errlist{501} = 'ERR_DB_SERVER';
    $errlist{510} = 'ERR_FILE_OPERATION';
    $errlist{520} = 'ERR_MEMORY_ALLOC';
    $errlist{600} = 'ERR_SERVER_BUSY';
    $errlist{601} = 'ERR_SERVER_UNAVAILABLE';
    $errlist{602} = 'ERR_PEER_NS_DOWN';
    $errlist{603} = 'ERR_DB_CONNECT';
    $errlist{604} = 'ERR_SERVER_GOING_DOWN';
    $errlist{707} = 'ERR_CREATE_CONNECTION';
    $errlist{711} = 'ERR_BLOCKING_WRITE';
    $errlist{712} = 'ERR_SESSION_OVERLOAD';
    $errlist{713} = 'ERR_USER_TOO_ACTIVE';
    $errlist{714} = 'ERR_TOO_MANY_SESSIONS';
    $errlist{715} = 'ERR_NOT_EXPECTED';
    $errlist{717} = 'ERR_BAD_FRIEND_FILE';
    $errlist{911} = 'ERR_AUTHENTICATION_FAILED';
    $errlist{913} = 'ERR_NOT_ALLOWED_WHEN_OFFLINE';
    $errlist{920} = 'ERR_NOT_ACCEPTING_NEW_USERS';
    return ( $errlist{$err} );
}

sub stripheader {
    my ($msg) = shift;
    $msg =~ s/\r//gs;
    $msg =~ s/^.*?\n\n//s;
    return $msg;
}

return 1;

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

