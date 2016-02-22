# ----------------------------------------------------------------------------
# vsEmail Module
# Copyright (c) 2000 Jason M. Hinkle. All rights reserved. This module is
# free software; you may redistribute it and/or modify it under the same
# terms as Perl itself.
# For more information see: http://www.verysimple.com/scripts/
#
# LEGAL DISCLAIMER:
# This software is provided as-is.  Use it at your own risk.  The
# author takes no responsibility for any damages or losses directly
# or indirectly caused by this software.
#
# This module incorporates code from Mail::Sendmail 0.77 by Milivoj Ivkovic,
# which is based off of sendmail 1.21 by Christian Mallwitz.  See package
# below for further details.
# ----------------------------------------------------------------------------

package vsEmail;
require 5.000;
$VERSION = "1.11";
$ID      = "vsEmail.pm";

=head1 NAME

vsEmail - interface to both sendmail and SMTP email

=head1 SYNOPSIS

	my $objMessage = new vsEmail(
		SendmailPath => "/usr/sbin/sendmail",
		HtmlMode => 0,
		From => "email\@address.com",
		To => "email\@address.com",
		Subject => "Subject",
	);
	$objMessage->Message("Message Line 1");
	$objMessage->AppendToMessage("Message Line 2");
	$objMessage->Send;

	# - OR -

	my $objMessage = new vsEmail(
		SmtpServer => "localhost",
		HtmlMode => 1,
		From => "email\@address.com",
		To => "email\@address.com",
		Subject => "Subject",
	);
	$objMessage->Message("<B>Message Line 1</B><br>");
	$objMessage->AppendToMessage("Message Line 2<br>");
	$objMessage->AppendToMessage("<hr>");
	$objMessage->Send;

=head1 DESCRIPTION

vsEmail.pm provides an object oriented interface for sending email messages
in plain text or HTML format using either Sendmail or SMTP.

=head1 USAGE

Refer to http://www.verysimple.com/scripts/ for more information.

=head1 AUTHOR

Jason M. Hinkle

=head1 COPYRIGHT

Copyright (c) 2000 Jason M. Hinkle.  All rights reserved.
This module is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 SEE ALSO

This module incorporates SendMail 0.77 by Milivoj Ivkovic for SMTP
functionality.  See POD below for details:

=cut

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
sub new {

    # ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    my $class = shift;
    my (%parameters) = @_;
    my ($param);
    my $this = {
        SmtpServer   => "",
        SendMailPath => "",
        HtmlMode     => "",
        From         => "",
        ReplyTo      => "",
        To           => "",
        Cc           => "",
        Subject      => "",
        Message      => "",
        Log          => "",
    };
    bless $this;

    # set the initial paramenters if they were specified
    foreach $param ( keys(%parameters) ) {
        $this->{$param} = $parameters{$param};
    }
    return $this;
}

# ###########################################################################
# # PUBLIC PROPERTIES
# ###########################################################################

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
sub Version {

    # ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    return $VERSION;
}

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
sub SmtpServer {

    # ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    my $this     = shift;
    my $newValue = shift;
    if ( defined($newValue) ) {
        $this->{'SmtpServer'} = $newValue;
    }
    else {
        return $this->{'SmtpServer'};
    }
}

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
sub SendmailPath {

    # ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    my $this     = shift;
    my $newValue = shift;
    if ( defined($newValue) ) {
        $this->{'SendmailPath'} = $newValue;
    }
    else {
        return $this->{'SendmailPath'};
    }
}

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
sub HtmlMode {

    # ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    my $this     = shift;
    my $newValue = shift;
    if ( defined($newValue) ) {
        $this->{'HtmlMode'} = $newValue;
    }
    else {
        return $this->{'HtmlMode'};
    }
}

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
sub From {

    # ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    my $this     = shift;
    my $newValue = shift;
    if ( defined($newValue) ) {
        $this->{'From'} = $newValue;
    }
    else {
        return $this->{'From'};
    }
}

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
sub ReplyTo {

    # ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    my $this     = shift;
    my $newValue = shift;
    if ( defined($newValue) ) {
        $this->{'ReplyTo'} = $newValue;
    }
    else {
        return $this->{'ReplyTo'};
    }
}

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
sub To {

    # ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    my $this     = shift;
    my $newValue = shift;
    if ( defined($newValue) ) {
        $this->{'To'} = $newValue;
    }
    else {
        return $this->{'To'};
    }
}

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
sub Cc {

    # ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    my $this     = shift;
    my $newValue = shift;
    if ( defined($newValue) ) {
        $this->{'Cc'} = $newValue;
    }
    else {
        return $this->{'Cc'};
    }
}

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
sub Subject {

    # ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    my $this     = shift;
    my $newValue = shift;
    if ( defined($newValue) ) {
        $this->{'Subject'} = $newValue;
    }
    else {
        return $this->{'Subject'};
    }
}

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
sub Message {

    # ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    my $this     = shift;
    my $newValue = shift;
    if ( defined($newValue) ) {
        $this->{'Message'} = $newValue;
    }
    else {
        return $this->{'Message'};
    }
}

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
sub Log {

    # ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    my $this = shift;
    return $this->{'Log'};
}

# ###########################################################################
# # PUBLIC METHODS
# ###########################################################################

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
sub AppendToMessage {

    # ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    my $this     = shift;
    my $newValue = shift;
    if ( defined($newValue) ) {
        $this->{'Message'} .= $newValue;
        return 1;
    }
    else {
        return 0;
    }
}

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
sub Send {

    # ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    my $this         = shift;
    my $sendmailPath = $this->SendmailPath;

    # check for required variables
    unless ( $this->ValidAddress( $this->To )
        && $this->ValidAddress( $this->From ) )
    {
        $this->{'Log'} .= "Invalid email address.\n";
        return 0;
    }

    if ($sendmailPath) {
        if ( -r $sendmailPath ) {

            # send message using sendmail
            open( MAIL, "|$sendmailPath -t" );
            print MAIL "To: " . $this->To . "\n";
            print MAIL "Cc: " . $this->Cc . "\n" if ( $this->Cc );
            print MAIL "Reply-To: " . $this->ReplyTo . "\n"
              if ( $this->ReplyTo );
            print MAIL "From: " . $this->From . "\n";
            print MAIL "Subject: " . $this->Subject . "\n";
            if ( $this->HtmlMode ) {
                print MAIL "Content-type: text/html\n";
            }
            else {
                print MAIL "Content-type: text/plain\n";
            }
            print MAIL "X-Mailer: " . $this->Version . "\n";
            print MAIL "\n";
            print MAIL $this->Message;
            close(MAIL);
            $this->{'Log'} = $sendmailPath . "\n";
            $this->{'Log'} .= "Date: " . vsSmtpMail::time_to_date() . "\n";
            $this->{'Log'} .= "To: " . $this->To . "\n";
            $this->{'Log'} .= "From: " . $this->From . "\n";
            $this->{'Log'} .= "Subject: " . $this->Subject . "\n";
            return 1;
        }
        elsif ( -e $sendmailPath ) {
            $this->{'Log'} = "Permission denied on '" . $sendmailPath . "'. \n";
            return 0;
        }
        else {
            $this->{'Log'} =
              "Sendmail was not found at '" . $sendmailPath . "'.\n";
            return 0;
        }
    }
    else {
        # send the message using the SMTP server module
        my (%smtpMessage);
        $smtpMessage{'Smtp'}         = $this->SmtpServer;
        $smtpMessage{'Content-type'} = "text/html" if ( $this->HtmlMode );
        $smtpMessage{'To'}           = $this->To;
        $smtpMessage{'Cc'}           = $this->Cc;
        $smtpMessage{'From'}         = $this->From;
        $smtpMessage{'Subject'}      = $this->Subject;
        $smtpMessage{'Message'}      = $this->Message;

        if ( vsSmtpMail::sendmail(%smtpMessage) ) {
            $this->{'Log'} = $vsSmtpMail::log;
            return 1;
        }
        else {
            $this->{'Log'} = $vsSmtpMail::log;
            return 0;
        }
    }
}

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
sub ValidAddress {

    # ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    my $this    = shift;
    my $address = shift;
    if (
        ( $address =~ /(@.*@)|(\.\.)|(@\.)|(\.@)|(^\.)/ )
        || ( $address !~
            /^.+\@(\[?)[a-zA-Z0-9\-\.]+\.([a-zA-Z]{2,3}|[0-9]{1,3})(\]?)$/ )
      )
    {
        return 0;
    }
    else {
        return 1;
    }
}

1;

# ###########################################################################
# ###########################################################################
package vsSmtpMail;

# ###########################################################################
# ###########################################################################
# Mail::Sendmail by Milivoj Ivkovic <mi@alma.ch>
# see embedded POD documentation after __END__
# or http://alma.ch/perl/mail.htm
# ###########################################################################

# ---------------------------------------------------------------------------
# additional note from j.hinkle: this library has been embedded into the
# vsEmail module to keep things simple for the webmaster.
# (renamed vsSmtpMail to avoid any potential namespace conflicts)
# It may be wise to migrate the guts of this mod to rely on MailTools instead.
# since this mod hides the smpt interface, it shouldn't make a difference if
# the internal workings are changed down the road.
# ---------------------------------------------------------------------------

=head1 NAME

vsSmtpMail v. 0.77 - Simple platform independent mailer

=cut

$VERSION = '0.77';

# *************** Configuration you may want to change *******************
# You probably want to set your SMTP server here (unless you specify it in
# every script), and leave the rest as is. See pod documentation for details

%mailcfg = (

    # List of SMTP servers:
    'smtp' => [qw( localhost )],

    #'smtp'    => [ qw( mail.mydomain.com ) ], # example

    'from' => '',    # default sender e-mail, used when no From header in mail

    'mime' => 1,     # use MIME encoding by default

    'retries' => 1,  # number of retries on smtp connect failure
    'delay'   => 1,  # delay in seconds between retries

    'tz'    => '',   # only to override automatic detection
    'port'  => 25,   # change it if you always use a non-standard port
    'debug' => 0     # prints stuff to STDERR
);

# *******************************************************************

require Exporter;
use vars qw(
  $VERSION
  @ISA
  @EXPORT
  @EXPORT_OK
  %mailcfg
  $default_smtp_server
  $default_smtp_port
  $default_sender
  $TZ
  $use_MIME
  $address_rx
  $debug
  $log
  $error
  $retry_delay
  $connect_retries
);

use Socket;
use Time::Local;    # for automatic time zone detection

# use MIME::QuotedPrint if available and configured in %mailcfg
eval("use MIME::QuotedPrint");

$mailcfg{'mime'} &&= ( !$@ );

@ISA       = qw(Exporter);
@EXPORT    = qw(&sendmail);
@EXPORT_OK = qw(
  %mailcfg
  time_to_date
  $default_smtp_server
  $default_smtp_port
  $default_sender
  $TZ
  $address_rx
  $debug
  $log
  $error
);

# regex for e-mail addresses where full=$1, user=$2, domain=$3
# see pod documentation about this regex

my $word_rx = '[\x21\x23-\x27\x2A-\x2B\x2D\w\x3D\x3F]+';
my $user_rx = $word_rx                                     # valid chars
  . '(?:\.' . $word_rx . ')*'    # possibly more words preceded by a dot
  ;
my $dom_rx = '\w[-\w]+(?:\.\w[-\w]+)*';       # less valid chars in domain names
my $ip_rx  = '\[\d{1,3}(?:\.\d{1,3}){3}\]';

$address_rx = '\b((' . $user_rx . ')\@(' . $dom_rx . '\b|' . $ip_rx . '))';
;                                             # v. 0.4

sub time_to_date {

    # convert a time() value to a date-time string according to RFC 822

    my $time = $_[0] || time();               # default to now if no argument

    my @months = qw(Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec);
    my @wdays  = qw(Sun Mon Tue Wed Thu Fri Sat);

    my ( $sec, $min, $hour, $mday, $mon, $year, $wday, $yday, $isdst ) =
      localtime($time);

    $TZ ||= $mailcfg{'tz'};

    if ( $TZ eq "" ) {

        # offset in hours
        my $offset  = sprintf "%.1f", ( timegm(localtime) - time ) / 3600;
        my $minutes = sprintf "%02d", ( $offset - int($offset) ) * 60;
        $TZ = sprintf( "%+03d", int($offset) ) . $minutes;
    }
    return join( " ",
        ( $wdays[$wday] . ',' ),
        $mday, $months[$mon],
        $year + 1900,
        sprintf( "%02d", $hour ) . ":" . sprintf( "%02d", $min ), $TZ );
}    # end sub time_to_date

sub sendmail {

    # original sendmail 1.21 by Christian Mallwitz.
    # Modified and 'modulized' by mi@alma.ch

    $error = '';
    $log   = "vsSmtpMail v. $VERSION - " . scalar( localtime() ) . "\n";

    local $_;
    local $/ = "\015\012";

    my (
        %mail,       $k,         $smtp,    $server,   $port,
        $connected,  $localhost, $message, $fromaddr, $recip,
        @recipients, $to,        $header,
    );

    sub fail {

        # things to do before returning a sendmail failure
        print STDERR @_ if $^W;
        $error .= join( " ", @_ ) . "\n";
        close S;
        return 0;
    }

    # all config keys to lowercase, to prevent typo errors
    foreach $k ( keys %mailcfg ) {
        if ( $k =~ /[A-Z]/ ) {
            $mailcfg{ lc($k) } = $mailcfg{$k};
        }
    }

    # redo hash, arranging keys case etc...
    while (@_) {

        # arrange keys case
        $k = ucfirst lc( shift @_ );

        if ( !$k and $^W ) {
            warn
              "Received false mail hash key: \'$k\'. Did you forget to put it in quotes?\n";
        }

        $k =~ s/\s*:\s*$//o
          ;    # kill colon (and possible spaces) at end, we add it later.
        $mail{$k} = shift @_;
    }

    $smtp = $mail{'Smtp'} || $mail{'Server'} || $default_smtp_server;

    unshift @{ $mailcfg{'smtp'} }, $smtp
      if ( $smtp and $mailcfg{'smtp'}->[0] ne $smtp );

    # delete non-header keys, so we don't send them later as mail headers
    # I like this syntax, but it doesn't seem to work with AS port 5.003_07:
    # delete @mail{'Smtp', 'Server'};
    # so instead:
    delete $mail{'Smtp'};
    delete $mail{'Server'};

    $mailcfg{'port'} =
      $mail{'Port'} || $default_smtp_port || $mailcfg{'port'} || 25;
    delete $mail{'Port'};

    # for backward compatibility only
    $mailcfg{'retries'} = $connect_retries if defined($connect_retries);
    $mailcfg{'delay'}   = $retry_delay     if defined($retry_delay);

    {    # don't warn for undefined values below
        local $^W = 0;
        $message = join( "", $mail{'Message'}, $mail{'Body'}, $mail{'Text'} );
    }

    # delete @mail{'Message', 'Body', 'Text'};
    delete $mail{'Message'};
    delete $mail{'Body'};
    delete $mail{'Text'};

    # Extract 'From:' e-mail address

    $fromaddr = $mail{'From'} || $default_sender || $mailcfg{'from'};
    unless ( $fromaddr =~ /$address_rx/ ) {
        return fail("Bad or missing From address: \'$fromaddr\'");
    }
    $fromaddr = $1;

    # add Date header if needed
    $mail{Date} ||= time_to_date();
    $log .= "Date: $mail{Date}\n";

    # cleanup message, and encode if needed
    $message =~ s/^\./\.\./gom;    # handle . as first character
    $message =~ s/\r\n/\n/go
      ;    # normalize line endings, step 1 of 2 (next step after MIME encoding)

    $mail{'Mime-version'} ||= '1.0';
    $mail{'Content-type'} ||= 'text/plain; charset="iso-8859-1"';

    unless ( $mail{'Content-transfer-encoding'}
        || $mail{'Content-type'} =~ /multipart/io )
    {
        if ( $mailcfg{'mime'} ) {
            $mail{'Content-transfer-encoding'} = 'quoted-printable';
            $message = encode_qp($message);
        }
        else {
            $mail{'Content-transfer-encoding'} = '8bit';
            if ( $message =~ /[\x80-\xFF]/o ) {
                $error .=
                  "MIME::QuotedPrint not present!\nSending 8bit characters, hoping it will come across OK.\n";
                warn "MIME::QuotedPrint not present!\n",
                  "Sending 8bit characters, hoping it will come across OK.\n"
                  if $^W;
            }
        }
    }

    $message =~ s/\n/\015\012/go;    # normalize line endings, step 2.

    # Get recipients
    {                                # don't warn for undefined values below
        local $^W = 0;
        $recip = join( ", ", $mail{To}, $mail{Cc}, $mail{Bcc} );
    }

    delete $mail{'Bcc'};

    @recipients = ();
    while ( $recip =~ /$address_rx/go ) {
        push @recipients, $1;
    }
    unless (@recipients) {
        return fail("No recipient!");
    }

    # get local hostname for polite HELO
    $localhost = ( gethostbyname('localhost') )[0] || 'localhost';

    foreach $server ( @{ $mailcfg{'smtp'} } ) {

        # open socket needs to be inside this foreach loop on Linux,
        # otherwise all servers fail if 1st one fails !??! why?
        unless ( socket S, AF_INET, SOCK_STREAM, ( getprotobyname 'tcp' )[2] ) {
            return fail("socket failed ($!)");
        }

        print "- trying $server\n" if $mailcfg{'debug'} > 1;

        #print "<b>" . $server. "</b><p>";

        $server =~ s/\s+//go;    # remove spaces just in case of a typo
            # extract port if server name like "mail.domain.com:2525"
        ( $server =~ s/:(.+)$//o ) ? $port = $1 : $port = $mailcfg{'port'};
        $smtp = $server;    # save $server for use outside foreach loop

        my $smtpaddr = inet_aton $server;
        unless ($smtpaddr) {
            $error .= "$server not found\n";
            next;           # next server
        }

        my $retried = 0;    # reset retries for each server
        while (
            (
                not $connected = connect S, pack_sockaddr_in( $port, $smtpaddr )
            )
            and ( $retried < $mailcfg{'retries'} )
          )
        {
            $retried++;
            $error .= "connect to $server failed ($!)\n";
            print "- connect to $server failed ($!)\n" if $mailcfg{'debug'} > 1;
            print "retrying in $mailcfg{'delay'} seconds...\n";
            sleep $mailcfg{'delay'};
        }

        if ($connected) {
            print "- connected to $server\n" if $mailcfg{'debug'} > 3;
            last;
        }
        else {
            $error .= "connect to $server failed\n";
            print "- connect to $server failed, next server...\n"
              if $mailcfg{'debug'} > 1;
            next;    # next server
        }
    }

    unless ($connected) {
        return fail("connect to $smtp failed ($!) no (more) retries!");
    }

    {
        local $^W = 0;    # don't warn on undefined variables
                          # Add info to log variable
        $log .=
            "Server: $smtp Port: $port\n"
          . "From: $fromaddr\n"
          . "Subject: $mail{Subject}\n" . "To: ";
    }

    my ($oldfh) = select(S);
    $| = 1;
    select($oldfh);

    chomp( $_ = <S> );
    if ( /^[45]/ or !$_ ) {
        return fail("Connection error from $smtp on port $port ($_)");
    }

    print S "HELO $localhost\015\012";
    chomp( $_ = <S> );
    if ( /^[45]/ or !$_ ) {
        return fail("HELO error ($_)");
    }

    print S "mail from: <$fromaddr>\015\012";
    chomp( $_ = <S> );
    if ( /^[45]/ or !$_ ) {
        return fail("mail From: error ($_)");
    }

    foreach $to (@recipients) {
        if ($debug) { print STDERR "sending to: <$to>\n"; }
        print S "rcpt to: <$to>\015\012";
        chomp( $_ = <S> );
        if ( /^[45]/ or !$_ ) {
            $log .= "!Failed: $to\n    ";
            return fail("Error sending to <$to> ($_)\n");
        }
        else {
            $log .= "$to\n    ";
        }
    }

    # start data part
    print S "data\015\012";
    chomp( $_ = <S> );
    if ( /^[45]/ or !$_ ) {
        return fail("Cannot send data ($_)");
    }

    # print headers
    foreach $header ( keys %mail ) {
        $mail{$header} =~ s/\s+$//o;    # kill possible trailing garbage
        print S "$header: ", $mail{$header}, "\015\012";
    }

    #- test diconnecting from network here, to see what happens
    #- print STDERR "DISCONNECT NOW!\n";
    #- sleep 4;
    #- print STDERR "trying to continue, expecting an error... \n";

    # send message body
    print S "\015\012", $message, "\015\012.\015\012";

    chomp( $_ = <S> );
    if ( /^[45]/ or !$_ ) {
        return fail("message transmission failed ($_)");
    }

    # finish
    print S "quit\015\012";
    $_ = <S>;
    close S;

    return 1;
}    # end sub sendmail

1;
__END__

=head1 SYNOPSIS

  use vsSmtpMail;

  %mail = ( To      => 'you@there.com',
            From    => 'me@here.com',
            Message => "This is a very short message"
           );

  sendmail(%mail) or die $vsSmtpMail::error;

  print "OK. Log says:\n", $vsSmtpMail::log;

=head1 DESCRIPTION

Simple platform independent e-mail from your perl script. Only requires
Perl 5 and a network connection.

After struggling for some time with various command-line mailing programs
which never did exactly what I wanted, I put together this Perl only
solution.

vsSmtpMail contains mainly &sendmail, which takes a hash with the
message to send and sends it. It is intended to be very easy to setup and
use.

=head1 INSTALLATION

=over 4

=item Best

perl -MCPAN -e "install vsSmtpMail"

=item Traditional

    perl Makefile.PL
    make
    make test
    make install

=item Manual

Copy Sendmail.pm to Mail/ in your Perl lib directory.

    (eg. c:\Perl\lib\Mail\, c:\Perl\site\lib\Mail\,
     /usr/lib/perl5/site_perl/Mail/, ... or whatever it
     is on your system)

=item ActivePerl's PPM

ppm install --location=http://alma.ch/perl/ppm Mail-Sendmail

But this way you don't get a chance to have a look at other files (Changes, 
Todo, test.pl, ...) and PPM doesn't run the test script (test.pl).

=back

At the top of Sendmail.pm, set your default SMTP server, unless you specify
it with each message, or want to use the default.

Install MIME::QuotedPrint. This is not required but strongly recommended.

=head1 FEATURES

Automatic time zone detection, Date: header, MIME quoted-printable encoding 
(if MIME::QuotedPrint installed), all of which can be overridden.

Internal Bcc: and Cc: support (even on broken servers)

Allows real names in From: and To: fields

Doesn't send unwanted headers, and allows you to send any header(s) you
want

Configurable retries and use of alternate servers if your mail server is
down

Good plain text error reporting

=head1 LIMITATIONS

Headers are not encoded, even if they have accented characters.

Since the whole message is in memory (twice!), it's not suitable for 
sending very big attached files.

The SMTP server has to be set manually in Sendmail.pm or in your script,
unless you can live with the default (localhost or Compuserve's
smpt.site1.csi.com).

=head1 CONFIGURATION

=over 4

=item Default SMTP server(s)

This is probably all you want to configure. It is usually done through
I<$mailcfg{smtp}>, which you can edit at the top of the Sendmail.pm file.
This is a reference to a list of SMTP servers. You can also set it from
your script:

C<unshift @{$vsSmtpMail::mailcfg{'smtp'}} , 'my.mail.server';>

Alternatively, you can specify the server in the I<%mail> hash you send
from your script, which will do the same thing:

C<$mail{smtp} = 'my.mail.server';>

A future version will try to set useful defaults for you during the
Makefile.PL.

=item Other configuration settings

See I<%mailcfg> under L<"DETAILS"> below for other configuration options.

=back

=head1 DETAILS

=head2 sendmail()

sendmail is the only thing exported to your namespace by default

C<sendmail(%mail) || print "Error sending mail: $vsSmtpMail::error\n";>

It takes a hash containing the full message, with keys for all headers,
body, and optionally for another non-default SMTP server and/or port.

It returns 1 on success or 0 on error, and rewrites
C<$vsSmtpMail::error> and C<$vsSmtpMail::log>.

Keys are NOT case-sensitive.

The colon after headers is not necessary.

The Body part key can be called 'Body', 'Message' or 'Text'. The SMTP
server key can be called 'Smtp' or 'Server'.

The following headers are added unless you specify them yourself:

    Mime-version: 1.0
    Content-type: 'text/plain; charset="iso-8859-1"'

    Content-transfer-encoding: quoted-printable
    or (if MIME::QuotedPrint not installed)
    Content-transfer-encoding: 8bit

    Date: [string returned by time_to_date()]

The following are not exported by default, but you can still access them
with their full name, or request their export on the use line like in:
C<use vsSmtpMail qw($address_rx time_to_date);>

=head2 vsSmtpMail::time_to_date()

convert time ( as from C<time()> ) to an RFC 822 compliant string for the
Date header. See also L<"%vsSmtpMail::mailcfg">.

=head2 $vsSmtpMail::error

When you don't run with the B<-w> flag, the module sends no errors to
STDERR, but puts anything it has to complain about in here. You should
probably always check if it says something.

=head2 $vsSmtpMail::log

A summary that you could write to a log file after each send

=head2 $vsSmtpMail::address_rx

A handy regex to recognize e-mail addresses.

A correct regex for valid e-mail addresses was written by one of the judges
in the obfuscated Perl contest... :-) It is quite big. This one is an
attempt to a reasonable compromise, and should accept all real-world
internet style addresses. The domain part is required and comments or
characters that would need to be quoted are not supported.

  Example:
    $rx = $vsSmtpMail::address_rx;
    if (/$rx/) {
      $address=$1;
      $user=$2;
      $domain=$3;
    }

=head2 %vsSmtpMail::mailcfg

This hash contains all configuration options. You normally edit it once (if
ever) in Sendmail.pm and forget about it, but you could also access it from
your scripts. For readability, I'll assume you have imported it.

The keys are not case-sensitive: they are all converted to lowercase before
use. Writing C<$mailcfg{Port} = 2525;> is OK: the default $mailcfg{port}
(25) will be deleted and replaced with your new value of 2525.

=over 4

=item $mailcfg{smtp}

C<$mailcfg{smtp} = [qw(localhost smtp.site1.csi.com)];>

This is a reference to a list of smtp servers, so if your main server is
down, the module tries the next one. If one of your servers uses a special
port, add it to the server name with a colon in front, to override the
default port (like in my.special.server:2525).

Default: localhost and smtp.site1.csi.com (which seems to be an open relay)

=item $mailcfg{from}

C<$mailcfg{from} = 'Mailing script me@mydomain.com';>

From address used if you don't supply one in your script. Should not be of
type 'user@localhost' since that may not be valid on the recipient's
host.

Default: undefined.

=item $mailcfg{mime}

C<$mailcfg{mime} = 1;>

Set this to 0 if you don't want any automatic MIME encoding. You normally
don't need this, the module should 'Do the right thing' anyway.

Default: 1;

=item $mailcfg{retries}

C<$mailcfg{retries} = 1;>

How many times should the connection to the same SMTP server be retried in
case of a failure.

Default: 1;

=item $mailcfg{delay}

C<$mailcfg{delay} = 1;>

Number of seconds to wait between retries. This delay also happens before
trying the next server in the list, if the retries for the current server
have been exhausted. For CGI scripts, you want few retries and short delays
to return with a results page before the http connection times out. For
unattended scripts, you may want to use many retries and long delays to
have a good chance of your mail being sent even with temporary failures on
your network.

Default: 1 (second);

=item $mailcfg{tz}

C<$mailcfg{tz} = '+0800';>

Normally, your time zone is set automatically, from the difference between
C<time()> and C<gmtime()>. This allows you to override automatic detection
in cases where your system is confused (such as some Win32 systems in zones
which do not use daylight savings time: see Microsoft KB article Q148681)

Default: undefined (automatic detection at run-time).

=item $mailcfg{port}

C<$mailcfg{port} = 25;>

Port used when none is specified in the server name.

Default: 25.

=item $mailcfg{debug}

C<$mailcfg{debug} => 0;>

Prints stuff to STDERR. Not used much, and what is printed may change
without notice. Don't count on it.

Default: 0;

=back

=head2 $vsSmtpMail::VERSION

The package version number (you can not import this one)

=head2 Configuration variables from previous versions

The following global variables were used in version 0.74 for configuration. They should still work, but will not in a future version (unless you complain loudly). Please use I<%mailcfg> if you need to access the configuration from your scripts.

=over 4

=item $vsSmtpMail::default_smtp_server

=item $vsSmtpMail::default_smtp_port

=item $vsSmtpMail::default_sender

=item $vsSmtpMail::TZ

=item $vsSmtpMail::connect_retries

=item $vsSmtpMail::retry_delay

=item $vsSmtpMail::use_MIME

This one couldn't really be used in the previous version, so I just dropped it.
It is replaced by I<$mailcfg{mime}> which works.

=back

=head1 ANOTHER EXAMPLE

  use vsSmtpMail;

  print "Testing vsSmtpMail version $vsSmtpMail::VERSION\n";
  print "Default server: $vsSmtpMail::mailcfg{smtp}->[0]\n";
  print "Default sender: $vsSmtpMail::mailcfg{from}\n";

  %mail = (
      #To      => 'No to field this time, only Bcc and Cc',
      #From    => 'not needed, use default',
      Bcc     => 'Someone <him@there.com>, Someone else her@there.com',
      # only addresses are extracted from Bcc, real names disregarded
      Cc      => 'Yet someone else <xz@whatever.com>',
      # Cc will appear in the header. (Bcc will not)
      Subject => 'Test message',
      'X-Mailer' => "vsSmtpMail version $vsSmtpMail::VERSION",
  );


  $mail{Smtp} = 'special_server.for-this-message-only.domain.com';
  $mail{'X-custom'} = 'My custom additionnal header';
  $mail{'mESSaGE : '} = "The message key looks terrible, but works.";
  # cheat on the date:
  $mail{Date} = vsSmtpMail::time_to_date( time() - 86400 ),

  if (sendmail %mail) { print "Mail sent OK.\n" }
  else { print "Error sending mail: $vsSmtpMail::error \n" }

  print "\n\$vsSmtpMail::log says:\n", $vsSmtpMail::log;

=head1 CHANGES

Many changes and bug-fixes since version 0.74. In short: less code, more 
functionality and docs. See the F<Changes> file.

=head1 AUTHOR

Milivoj Ivkovic mi@alma.ch or ivkovic@csi.com

=head1 NOTES

MIME::QuotedPrint is used by default on every message if available. It 
allows reliable sending of accented characters, and also takes care of 
too long lines (which can happen in HTML mails). It is available in the 
MIME-Base64 package at http://www.perl.com/CPAN/modules/by-module/MIME/ or 
through PPM.

Look at http://alma.ch/perl/Mail-Sendmail-FAQ.htm for additional info 
(CGI, examples of sending attachments, HTML mail etc...)

You can use it freely. (Someone complained this is too vague. So, more
precisely: do whatever you want with it, but be warned that terrible things
will happen to you if you use it badly, like for sending spam, claiming you
wrote it alone, or ...?)

I would appreciate a short (or long) e-mail note if you use this (and even
if you don't, especially if you care to say why). And of course,
bug-reports and/or suggestions are welcome.

Last revision: 27.03.99. Latest version should be available at
http://alma.ch/perl/mail.htm , and a few days later on CPAN.

=cut

