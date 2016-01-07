
=head1 B<net_gmail_utils>

=head2 SYNOPSIS

NONE

=head2 DESCRIPTION

Adds IMAP message scan and gmail sending ability.

Requires the following perl modules

  Mail::IMAPClient
  IO::Socket::SSL
  Email::Send;
  Email::Send::Gmail;
  Email::Simple;
  Email::Simple::Creator;
  Time::Zone

if the IMAP scan hangs before authenticating against the gmail account, reinstall the
IO::Socket::SSL

  v 0.1 - initial test concept, inspired by Pete's script - H. Plato - 2 June 2008
  v 0.2 - added pete's gmail send function, gmail list folders, better error checking

Todo:

 - parse unread messages
 - add body size ability to limit the download of large email messages
 - find out the size of a mailbox

=head2 INHERITS

B<NONE>

=head2 METHODS

=over

=item B<UnDoc>

=cut

#!/usr/bin/perl

package net_gmail_utils;

use Email::Send;
use Email::Send::Gmail;
use Email::Simple;
use Email::Simple::Creator;

sub send_gmail {

    my %parms = @_;
    my (
        $from,    $to,   $subject, $text, $port,
        $account, $mime, $baseref, $file, $filename
    );
    my ( $smtpusername, $smtppassword, $smtpencrypt );

    $port         = $parms{port};
    $account      = $parms{account};
    $from         = $parms{from};
    $to           = $parms{to};
    $subject      = "Email from Misterhouse";
    $subject      = $parms{subject} if ( defined $parms{subject} );
    $mime         = $parms{mime};
    $baseref      = $parms{baseref};
    $text         = $parms{text};
    $file         = $parms{file};
    $filename     = $parms{filename};
    $smtpusername = $parms{smtpusername};
    $smtpusername = $parms{gmail_account} if ( defined $parms{gmail_account} );
    $smtppassword = $parms{smtppassword};
    $smtppassword = $parms{password} if ( defined $parms{password} );

    #   my $priority= $parms{priority};
    #   $priority = 3 unless $priority;

    $account = $main::config_parms{net_mail_send_account} unless $account;
    $port = $main::config_parms{"net_mail_${account}_server_send_port"}
      unless ( defined $port );
    $port = 25 unless ( defined $port );
    $from = $main::config_parms{"net_mail_${account}_address"}
      unless ( defined $from );
    $to = $main::config_parms{"net_mail_${account}_address"}
      unless ( defined $to );

    my $timeout =
      $main::config_parms{"net_mail_${account}_server_send_timeout"};
    $timeout = 20 unless $timeout;

    $smtpusername = $main::config_parms{"net_mail_${account}_user"}
      unless $smtpusername;
    $smtppassword = $main::config_parms{"net_mail_${account}_password"}
      unless $smtppassword;

    $from = $smtpusername unless $from;

    #print "f=$from, t=$to, s=$subject, p=$port, u=$smtpusername, pw=$smtppassword, te=$text\n";

    # Note I had some issuse using the escaped $Address from above, and just hardcoded it in
    #  without the escapes for the sending section .... should be pretty easy to mod though

    my $email = Email::Simple->create(
        header => [
            From => $from,
            To   => $to,

            #  To	  => 'anotheraddress@hotmail.com',
            Subject => $subject,
        ],

        body => $text,
    );

    $email->header_set( 'X-Mailer' => 'net_gmail_utils mh v0.1 - pjf/hp 2008' );

    my $sender = Email::Send->new(
        {
            mailer      => 'Gmail',
            Port        => $port,
            mailer_args => [
                username => $smtpusername,
                password => $smtppassword,
            ]
        }
    );

    eval { $sender->send($email) };
    if ($@) {
        print "Error sending gmail email: $@";
        return;
    }
    $sender = '';
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

