# $Id$
# Documentation and Copyright exist after __END__

package CDDB;
require 5.001;

use strict;
use vars qw($VERSION);
use Carp;

$VERSION = '1.15';

BEGIN {
  if ($^O eq 'MSWin32') {
    eval 'sub USING_WINDOWS () { 1 }';
  }
  else {
    eval 'sub USING_WINDOWS () { 0 }';
  }
}

use IO::Socket;
use Sys::Hostname;

# A list of known freedb servers.  I've stopped using Gracenote's CDDB
# because they never return my e-mail about becoming a developer.  To
# top it off, they've started denying CDDB.pm users.  TODO: Fetch the
# list from freedb.freedb.org, which is a round-robin for all the
# others anyway.

my @cddbp_hosts = (
  [ 'localhost'         => 8880 ],
  [ 'freedb.freedb.org' => 8880 ],
  [ 'us.freedb.org',    => 8880 ],
  [ 'ca.freedb.org',    => 8880 ],
  [ 'ca2.freedb.org',   => 8880 ],
  [ 'uk.freedb.org'     => 8880 ],
  [ 'no.freedb.org'     => 8880 ],
  [ 'de.freedb.org'     => 8880 ],
  [ 'at.freedb.org'     => 8880 ],
  [ 'freedb.freedb.de'  => 8880 ],
);

#------------------------------------------------------------------------------
# Determine whether we can submit changes by e-mail.

my $imported_mail = 0;
eval {
  require Mail::Internet;
  require Mail::Header;
  require MIME::QuotedPrint;
  $imported_mail = 1;
};

#------------------------------------------------------------------------------
# Determine whether we can use HTTP for requests and submissions.

my $imported_http = 0;
eval {
  require LWP;
  require HTTP::Request;
  $imported_http = 1;
};

#------------------------------------------------------------------------------
# Send a command.  If we're not connected, try to connect first.
# Returns 1 if the command is sent ok; 0 if there was a problem.

sub command {
  my $self = shift;
  my $str = join(' ', @_);

  unless ($self->{handle}) {
    $self->connect() or return 0;
  }

  $self->debug_print(0, '>>> ', $str);

  my $len = length($str .= "\x0D\x0A");

  local $SIG{PIPE} = 'IGNORE' unless ($^O eq 'MacOS');
  return 0 unless(syswrite($self->{handle}, $str, $len) == $len);
  return 1;
}

#------------------------------------------------------------------------------
# Retrieve a line from the server.  Uses a buffer to allow for
# ungetting lines.  Returns the next line or undef if there is a
# problem.

sub getline {
  my $self = shift;

  if (@{$self->{lines}}) {
    my $line = shift @{$self->{lines}};
    $self->debug_print(0, '<<< ', $line);
    return $line;
  }

  my $socket = $self->{handle};
  return unless defined $socket;

  my $fd = fileno($socket);
  return unless defined $fd;

  vec(my $rin = '', $fd, 1) = 1;
  my $timeout = $self->{timeout} || undef;
  my $frame   = $self->{frame};

  until (@{$self->{lines}}) {

    # Fail if the socket is inactive for the timeout period.  Fail
    # also if sysread returns nothing.

    return unless select(my $rout=$rin, undef, undef, $timeout);
    return unless defined sysread($socket, my $buf='', 1024);

    $frame .= $buf;
    my @lines = split(/\x0D?\x0A/, $frame);
    $frame = (
      (length($buf) == 0 || substr($buf, -1, 1) eq "\x0A")
      ? ''
      : pop(@lines)
    );
    push @{$self->{lines}}, @lines;
  }

  $self->{frame} = $frame;

  my $line = shift @{$self->{lines}};
  $self->debug_print(0, '<<< ', $line);
  return $line;
}

#------------------------------------------------------------------------------
# Receive a server response, and parse it into its numeric code and
# text message.  Return the code's first character, which usually
# indicates the response class (ok, error, information, warning,
# etc.).  Returns undef on failure.

sub response {
  my $self = shift;
  my ($code, $text);

  my $str = $self->getline();

  return unless defined($str);

  # Fail if the line we get isn't the proper format.
  return unless ( ($code, $text) = ($str =~ /^(\d+)\s*(.*?)\s*$/) );

  $self->{response_code} = $code;
  $self->{response_text} = $text;
  substr($code, 0, 1);
}

#------------------------------------------------------------------------------
# Accessors to retrieve the last response() call's code and text
# separately.

sub code {
  my $self = shift;
  $self->{response_code};
}

sub text {
  my $self = shift;
  $self->{response_text};
}

#------------------------------------------------------------------------------
# Helper to print stuff for debugging.

sub debug_print {
  my $self = shift;

  # Don't bother if not debugging.
  return unless $self->{debug};

  my $level = shift;
  my $text = join('', @_);
  print STDERR $text, "\n";
}

#------------------------------------------------------------------------------
# Read data until it's terminated by a single dot on its own line.
# Two dots at the start of a line are replaced by one.  Returns an
# ARRAY reference containing the lines received, or undef on error.

sub read_until_dot {
  my $self = shift;
  my @lines;

  while ('true') {
    my $line = $self->getline() or return;
    last if ($line =~ /^\.$/);
    $line =~ s/^\.\././;
    push @lines, $line;
  }

  \@lines;
}

#------------------------------------------------------------------------------
# Create an object to represent one or more cddbp sessions.

sub new {
  my $type = shift;
  my %param = @_;

  # Attempt to suss our hostname.
  my $hostname = &hostname();

  # Attempt to suss our login ID.
  my $login = $param{Login} || $ENV{LOGNAME} || $ENV{USER};
  if (not defined $login) {
    if (USING_WINDOWS) {
      carp(
        "Can't get login ID.  Use Login parameter or " .
        "set LOGNAME or USER environment variable.  Using default login " .
        "ID 'win32usr'"
      );
      $login = 'win32usr';
    }
    else {
      $login = getpwuid($>)
        or croak(
          "Can't get login ID.  " .
          "Set LOGNAME or USER environment variable and try again: $!"
        );
    }
  }

  # Debugging flag.
  my $debug = $param{Debug};
  $debug = 0 unless defined $debug;

  # Choose a particular cddbp host.
  my $host = $param{Host};
  $host = '' unless defined $host;

  # Choose a particular cddbp port.
  my $port = $param{Port};
  $port = 8880 unless $port;

  # Choose a particular cddbp submission address.
  my $submit_to = $param{Submit_Address};
  $submit_to = 'freedb-submit@freedb.org' unless defined $submit_to;

  # Change the cddbp client name.
  my $client_name = $param{Client_Name};
  $client_name = 'CDDB.pm' unless defined $client_name;

  # Change the cddbp client version.
  my $client_version = $param{Client_Version};
  $client_version = $VERSION unless defined $client_version;

  # Change the cddbp protocol level.
  my $cddb_protocol = $param{Protocol_Version};
  $cddb_protocol = 1 unless defined $cddb_protocol;

  # Mac Freaks Got Spaces!  Augh!
  $login =~ s/\s+/_/g;

  my $self = bless {
    hostname      => $hostname,
    login         => $login,
    mail_from     => undef,
    mail_host     => undef,
    libname       => $client_name,
    libver        => $client_version,
    cddbmail      => $submit_to,
    debug         => $debug,
    host          => $host,
    port          => $port,
    cddb_protocol => $cddb_protocol,
    lines         => [],
    frame         => '',
    response_code => '000',
    response_text => '',
  }, $type;

  $self;
}

#------------------------------------------------------------------------------
# Disconnect from a cddbp server.  This is needed sometimes when a
# server decides a session has performed enough requests.

sub disconnect {
  my $self = shift;
  if ($self->{handle}) {
    $self->command('quit');     # quit
    $self->response();          # wait for any response
    delete $self->{handle};     # close the socket
  }
  else {
    $self->debug_print( 0, '--- disconnect on unconnected handle' );
  }
}

#------------------------------------------------------------------------------
# Connect to a cddbp server.  Connecting and disconnecting are done
# transparently and are performed on the basis of need.  Furthermore,
# this routine will cycle through servers until one connects or it has
# exhausted all its possibilities.  Returns true if successful, or
# false if failed.

sub connect {
  my $self = shift;
  my $cddbp_host;

  # Try to get our hostname yet again, in case it failed during the
  # constructor call.
  unless (defined $self->{hostname}) {
    $self->{hostname} = &hostname() or croak "can't get hostname: $!";
  }

  # The handshake loop tries to complete an entire connection
  # negociation.  It loops until success, or until HOST returns
  # because all the hosts have failed us.

HANDSHAKE:
  while ('true') {

    # The host loop tries each possible host, in order.

HOST:
    while ('true') {

      # Hard disconnect here to prevent recursion.
      delete $self->{handle};

      # If no host has been selected, cycle to the next one in the
      # list.  This destroys that list as it goes, but a successful
      # connection later will restore the good host to the list.
      # TODO: give bad hosts extra chances in case there are transient
      # network problems.
      if ($self->{host} eq '') {

        # None of the servers worked.  Time to leave.
        unless (@cddbp_hosts) {
          $self->debug_print( 0, "--- all cddbp servers failed to answer" );
          warn "No cddb protocol servers answer.  Is your network OK?\n"
            unless $self->{debug};
          return;
        }

        $cddbp_host = shift(@cddbp_hosts);
        ($self->{host}, $self->{port}) = @$cddbp_host;
      }

      # Assign the host we selected, and attempt a connection.
      $self->debug_print(
        0,
        "=== connecting to $self->{host} port $self->{port}"
      );
      $self->{handle} = new IO::Socket::INET(
        PeerAddr => $self->{host},
        PeerPort => $self->{port},
        Proto    => 'tcp',
        Timeout  => 30,
      );

      # The host did not answer.  Clean up after the failed attempt
      # and cycle to the next host.
      unless (defined $self->{handle}) {
        $self->debug_print(
          0,
          "--- error connecting to $self->{host} port $self->{port}: $!"
        );
        delete $self->{handle};
        $self->{host} = $self->{port} = '';
        next HOST;
      }

      # The host accepted our connection.  We'll push it back on the
      # list of known cddbp hosts so it can be tried later.  And we're
      # done with the host list cycle for now.
      $self->debug_print(
        0,
        "+++ successfully connected to $self->{host} port $self->{port}"
      );
      push(@cddbp_hosts, $cddbp_host);
      last HOST;
    }

    # This should not occur.
    die unless defined $self->{handle};

    # Turn off buffering on the socket handle.
    select((select($self->{handle}), $|=1)[0]);

    # Get the server's banner message.  Try reconnecting if it's bad.
    my $code = $self->response();
    if ($code != 2) {
      $self->debug_print(
        0, "--- bad cddbp response: ",
        $self->code(), ' ', $self->text()
      );
      next HANDSHAKE;
    }

    # Say hello, and wait for a response.
    $self->command(
      'cddb hello',
       $self->{login}, $self->{hostname},
       $self->{libname}, $self->{libver}
    );
    $code = $self->response();
    if ($code == 4) {
      $self->debug_print(
        0, "--- the server denies us: ",
        $self->code(), ' ', $self->text()
      );
      return;
    }
    if ($code != 2) {
      $self->debug_print(
        0, "--- the server didn't handshake: ",
        $self->code(), ' ', $self->text()
      );
      next HANDSHAKE;
    }

    # Set the protocol level.
    if ($self->{cddb_protocol} != 1) {
      $self->command( 'proto', $self->{cddb_protocol} );
      $code = $self->response();
      if ($code != 2) {
        $self->debug_print(
          0, "--- can't set protocol level ",
          $self->{cddb_protocol}, ' ',
          $self->code(), ' ', $self->text()
        );
        return;
      }
    }

    # If we get here, everything succeeded.
    return 1;
  }
}

# Destroying the cddbp object disconnects from the server.

sub DESTROY {
  my $self = shift;
  $self->disconnect();
}

###############################################################################
# High-level cddbp functions.

#------------------------------------------------------------------------------
# Get a list of available genres.  Returns an array of genre names, or
# undef on failure.

sub get_genres {
  my $self = shift;
  my @genres;

  $self->command('cddb lscat');
  my $code = $self->response();
  return unless $code;

  if ($code == 2) {
    my $genres = $self->read_until_dot();
    return @$genres if defined $genres;
    return;
  }

  $self->debug_print(
    0, '--- error listing categories: ',
    $self->code(), ' ', $self->text()
  );
  return;
}

#------------------------------------------------------------------------------
# Calculate a cddbp ID based on a text table of contents.  The text
# format was chosen because it was straightforward and easy to
# generate.  In a scalar context, this returns just the cddbp ID.  In
# a list context it returns several things: a listref of track
# numbers, a listref of track lengths (MM:SS format), a listref of
# track offsets (in seconds), and the disc's total playing time in
# seconds.  In either context it returns undef on failure.

sub calculate_id {
  my $self = shift;
  my @toc = @_;

  my (
    $seconds_previous, $seconds_first, $seconds_last, $cddbp_sum,
    @track_numbers, @track_lengths, @track_offsets,
  );

  foreach my $line (@toc) {
    my ($track, $mm_begin, $ss_begin, $ff_begin) = split(/\s+/, $line, 4);
    my $frame_offset = (($mm_begin * 60 + $ss_begin) * 75) + $ff_begin + 150;
    my $seconds_begin = int($frame_offset / 75);

    if (defined $seconds_previous) {
      my $elapsed = $seconds_begin - $seconds_previous;
      push(
        @track_lengths,
        sprintf("%02d:%02d", int($elapsed / 60), $elapsed % 60)
      );
    }
    else {
      $seconds_first = $seconds_begin;
    }

    # Track 999 was chosen for the lead-out information.
    if ($track == 999) {
      $seconds_last = $seconds_begin;
      last;
    }

    # Track 1000 was chosen for error information.
    if ($track == 1000) {
      $self->debug_print( 0, "error in TOC: $ff_begin" );
      return;
    }

    map { $cddbp_sum += $_; } split(//, $seconds_begin);
    push @track_offsets, $frame_offset;
    push @track_numbers, sprintf("%03d", $track);
    $seconds_previous = $seconds_begin;
  }

  # Calculate the ID.  Whee!
  my $id = sprintf(
    "%08x",
    (($cddbp_sum % 255) << 24)
    | (($seconds_last - $seconds_first) << 8)
    | scalar(@track_offsets)
  );

  # In list context, we return several things.  Some of them are
  # useful for generating filenames or playlists (the padded track
  # numbers).  Others are needed for cddbp queries.
  return (
    $id, \@track_numbers, \@track_lengths, \@track_offsets, $seconds_last
  ) if wantarray();

  # Just return the cddbp ID in scalar context.
  return $id;
}

#------------------------------------------------------------------------------
# Parse cdinfo's output so calculate_id() can eat it.

sub parse_cdinfo {
  my ($self, $command) = @_;
  open(FH, $command) or croak "could not open `$command': $!";

  my @toc;
  while (<FH>) {
    if (/(\d+):\s+(\d+):(\d+):(\d+)/) {
      my @track = ($1,$2,$3,$4);
      $track[0] = 999 if /leadout/;
      push @toc, "@track";
    }
  }
  close FH;
  return @toc;
}

#------------------------------------------------------------------------------
# Get a list of discs that match a particular CD's table of contents.
# This accepts the TOC information as returned by calculate_id().  It
# will also accept information in mp3 format, but I forget what that
# is.  Pudge asked for it, so he'd know.

sub get_discs {
  my $self = shift;
  my ($id, $offsets, $total_seconds) = @_;

  # Accept the TOC in CDDB.pm format.
  my ($track_count, $offsets_string);
  if (ref($offsets) eq 'ARRAY') {
    $track_count = scalar(@$offsets);
    $offsets_string = join ' ', @$offsets;
  }

  # Accept the TOC in mp3 format, for pudge.
  else {
    $offsets =~ /^(\d+?)\s+(.*)$/;
    $track_count = $1;
    $offsets_string = $2;
  }

  # Make repeated attempts to query the server.  I do this to drive
  # the hidden server cycling.
  my $code;

ATTEMPT:
  while ('true') {

    # Send a cddbp query command.
    $self->command(
      'cddb query', $id, $track_count,
      $offsets_string, $total_seconds
    ) or return;

    # Get the response.  Try again if the server is temporarly
    # unavailable.
    $code = $self->response();
    next ATTEMPT if $self->code() == 417;
    last ATTEMPT;
  }

  # Return undef if there's a problem.
  return unless defined $code and $code == 2;

  # Single matching disc.
  if ($self->code() == 200) {
    my ($genre, $cddbp_id, $title) = (
      $self->text() =~ /^(\S+)\s*(\S+)\s*(.*?)\s*$/
    );
    return [ $genre, $cddbp_id, $title ];
  }

  # No matching discs.
  return if $self->code() == 202;

  # Multiple matching discs.
  # 210 Found exact matches, list follows (...)   [proto>=4]
  # 211 Found inexact matches, list follows (...) [proto>=1]
  if ($self->code() == 210 or $self->code() == 211) {
    my $discs = $self->read_until_dot();
    return unless defined $discs;

    my @matches;
    foreach my $disc (@$discs) {
      my ($genre, $cddbp_id, $title) = ($disc =~ /^(\S+)\s*(\S+)\s*(.*?)\s*$/);
      push(@matches, [ $genre, $cddbp_id, $title ]);
    }

    return @matches;
  }

  # What the heck?
  $self->debug_print(
    0, "--- unknown cddbp response: ",
    $self->code(), ' ', $self->text()
  );
  return;
}

#------------------------------------------------------------------------------
# A little helper to combine list-context calculate_id() with
# get_discs().

sub get_discs_by_toc {
  my $self = shift;
  my (@info, @discs);
  if (@info = $self->calculate_id(@_)) {
    @discs = $self->get_discs(@info[0, 3, 4]);
  }
  @discs;
}

#------------------------------------------------------------------------------
# A little helper to get discs from an existing query string.
# Contributed by Ron Grabowski.

sub get_discs_by_query {
  my ($self, $query) = @_;
  my (undef, undef, $cddbp_id, $tracks, @offsets) = split /\s+/, $query;
  my $total_seconds = pop @offsets;
  my @discs = $self->get_discs($cddbp_id, \@offsets, $total_seconds);
  return @discs;
}

#------------------------------------------------------------------------------
# Retrieve the database record for a particular genre/id combination.
# Returns a moderately complex hashref representing the cddbp record,
# or undef on failure.

sub get_disc_details {
  my $self = shift;
  my ($genre, $id) = @_;

  # Because cddbp only allows one detail query per connection, we
  # force a disconnect/reconnect here if we already did one.
  if (exists $self->{'got tracks before'}) {
    $self->disconnect();
    $self->connect() or return;
  }
  $self->{'got tracks before'} = 'yes';

  $self->command('cddb read', $genre, $id);
  my $code = $self->response();
  if ($code != 2) {
    $self->debug_print(
      0, "--- cddbp host could not read the disc record: ",
      $self->code(), ' ', $self->text()
    );
    return;
  }

  my $track_file;
  unless (defined($track_file = $self->read_until_dot())) {
    $self->debug_print( 0, "--- cddbp disc record interrupted" );
    return;
  }

  # Parse that puppy.
  return parse_xmcd_file($track_file, $genre);
}

# Arf!

sub parse_xmcd_file {
  my ($track_file, $genre) = @_;

  my %details = (
    offsets => [ ],
    seconds => [ ],
  );
  my $state = 'beginning';
  foreach my $line (@$track_file) {
    # Keep returned so-called xmcd record...
    $details{xmcd_record} .= $line . "\n";

    if ($state eq 'beginning') {
      if ($line =~ /track\s*frame\s*off/i) {
        $state = 'offsets';
      }
      next;
    }

    if ($state eq 'offsets') {
      if ($line =~ /^\#\s*(\d+)/) {
        push @{$details{offsets}}, $1;
        next;
      }
      $state = 'headers';
      # This passes through on purpose.
    }

    # This is not an elsif on purpose.
    if ($state eq 'headers') {
      if ($line =~ /^\#/) {
        $line =~ s/\s+/ /g;
        if (my ($header, $value) = ($line =~ /^\#\s*(.*?)\:\s*(.*?)\s*$/)) {
          $details{lc($header)} = $value;
        }
        next;
      }
      $state = 'data';
      # This passes through on purpose.
    }

    # This is not an elsif on purpose.
    if ($state eq 'data') {
      next unless (
        my ($tag, $idx, $val) = ($line =~ /^\s*(.+?)(\d*)\s*\=\s*(.+?)\s*$/)
      );
      $tag = lc($tag);

      if ($idx ne '') {
        $tag .= 's';
        $details{$tag} = [ ] unless exists $details{$tag};
        $details{$tag}->[$idx] .= $val;
        $details{$tag}->[$idx] =~ s/^\s+//;
        $details{$tag}->[$idx] =~ s/\s+$//;
        $details{$tag}->[$idx] =~ s/\s+/ /g;
      }
      else {
        $details{$tag} .= $val;
        $details{$tag} =~ s/^\s+//;
        $details{$tag} =~ s/\s+$//;
        $details{$tag} =~ s/\s+/ /g;
      }
    }
  }

  # Translate disc offsets into seconds.  This builds a virtual track
  # 0, which is the time from the beginning of the disc to the
  # beginning of the first song.  That time's used later to calculate
  # the final track's length.

  my $last_offset = 0;
  foreach (@{$details{offsets}}) {
    push @{$details{seconds}}, int(($_ - $last_offset) / 75);
    $last_offset = $_;
  }

  # Create the final track length from the disc length.  Remove the
  # virtual track 0 in the process.

  my $disc_length = $details{"disc length"};
  $disc_length =~ s/ .*$//;

  my $first_start = shift @{$details{seconds}};
  push(
    @{$details{seconds}},
    $disc_length - int($details{offsets}->[-1] / 75) + 1 - $first_start
  );

  # Add the genre, if we have it.
  $details{genre} = $genre;

  return \%details;
}

###############################################################################
# Evil voodoo e-mail submission stuff.

#------------------------------------------------------------------------------
# Return true/false whether the libraries needed to submit discs are
# present.

sub can_submit_disc {
  my $self = shift;
  $imported_mail;
}

#------------------------------------------------------------------------------
# Build an e-mail address, and return it.  Caches the last built
# address, and returns that on subsequent calls.

sub get_mail_address {
  my $self = shift;
  return $self->{mail_from} if defined $self->{mail_from};
  return $self->{mail_from} = $self->{login} . '@' . $self->{hostname};
}

#------------------------------------------------------------------------------
# Build an e-mail host, and return it.  Caches the last built e-mail
# host, and returns that on subsequent calls.

sub get_mail_host {
  my $self = shift;

  return $self->{mail_host} if defined $self->{mail_host};

  if (exists $ENV{SMTPHOSTS}) {
    $self->{mail_host} = $ENV{SMTPHOSTS};
  }
  elsif (defined inet_aton('mail')) {
    $self->{mail_host} = 'mail';
  }
  else {
    $self->{mail_host} = 'localhost';
  }
  return $self->{mail_host};
}

# Build a cddbp disc submission and try to e-mail it.

sub submit_disc {
  my $self = shift;
  my %params = @_;

  croak(
    "submit_disc needs Mail::Internet, Mail::Header, and MIME::QuotedPrint"
  ) unless $imported_mail;

  # Try yet again to fetch the hostname.  Fail if we cannot.
  unless (defined $self->{hostname}) {
    $self->{hostname} = &hostname() or croak "can't get hostname: $!";
  }

  # Validate the required submission fields.  XXX Duplicated code.
  (exists $params{Genre})       or croak "submit_disc needs a Genre";
  (exists $params{Id})          or croak "submit_disc needs an Id";
  (exists $params{Artist})      or croak "submit_disc needs an Artist";
  (exists $params{DiscTitle})   or croak "submit_disc needs a DiscTitle";
  (exists $params{TrackTitles}) or croak "submit_disc needs TrackTitles";
  (exists $params{Offsets})     or croak "submit_disc needs Offsets";
  (exists $params{Revision})    or croak "submit_disc needs a Revision";
  if (exists $params{Year}) {
    unless ($params{Year} =~ /^\d{4}$/) {
      croak "submit_disc needs a 4 digit year";
    }
  }
  if (exists $params{GenreLong}) {
    unless ($params{GenreLong} =~ /^([A-Z][a-zA-Z0-9]*\s?)+$/) {
      croak(
        "GenreLong must start with a capital letter and contain only " .
        "letters and numbers"
      );
    }
  }

  # Try to find a mail host.  We could probably grab the MX record for
  # the current machine, but that would require yet more strange
  # modules.  TODO: Use Net::DNS if it's available (why not?) and just
  # bypass it if it isn't installed.

  $self->{mail_host} = $params{Host} if exists $params{Host};
  my $host = $self->get_mail_host();

  # Override the sender's e-mail address with whatever was specified
  # during the object's constructor call.
  $self->{mail_from} = $params{From} if exists $params{From};
  my $from = $self->get_mail_address();

  # Build the submission's headers.
  my $header = new Mail::Header;
  $header->add( 'MIME-Version' => '1.0' );
  $header->add( 'Content-Type' => 'text/plain; charset=iso-8859-1' );
  $header->add( 'Content-Disposition' => 'inline' );
  $header->add( 'Content-Transfer-Encoding' => 'quoted-printable' );
  $header->add( From    => $from );
  $header->add( To      => $self->{cddbmail} );
  $header->add( Subject => "cddb $params{Genre} $params{Id}" );

  # Build the submission's body.
  my @message_body = (
    '# xmcd',
    '#',
    '# Track frame offsets:',
    map({ "#\t" . $_; } @{$params{Offsets}}),
    '#',
    '# Disc length: ' . (hex(substr($params{Id},2,4))+2) . ' seconds',
    '#',
    "# Revision: " . $params{Revision},
    '# Submitted via: ' . $self->{libname} . ' ' . $self->{libver},
    '#',
    'DISCID=' . $params{Id},
    'DTITLE=' . $params{Artist} . ' / ' . $params{DiscTitle},
  );

  # add year and genre
  if (exists $params{Year}) {
    push @message_body, 'DYEAR='.$params{Year};
  }
  if (exists $params{GenreLong}) {
    push @message_body, 'DGENRE='.$params{GenreLong};
  }

  # Dump the track titles.
  my $number = 0;
  foreach my $title (@{$params{TrackTitles}}) {
    my $copy = $title;
    while ($copy ne '') {
      push( @message_body, 'TTITLE' . $number . '=' . substr($copy, 0, 69));
      substr($copy, 0, 69) = '';
    }
    $number++;
  }

  # Dump extended information.
  push @message_body, 'EXTD=';
  push @message_body, map { "EXTT$_="; } (0..--$number);
  push @message_body, 'PLAYORDER=';

  # Translate the message body to quoted printable.  TODO: How can I
  # ensure that the quoted printable characters are within ISO-8859-1?
  # The cddbp submissions daemon will barf if it's not.
  foreach my $line (@message_body) {
    $line .= "\n";
    $line = MIME::QuotedPrint::encode_qp($line);
  }

  # Bundle the headers and body into an Internet mail.
  my $mail = new Mail::Internet(
    undef,
    Header => $header,
    Body   => \@message_body,
  );

  # Try to send it using the "mail" utility.  This is commented out:
  # it strips the MIME headers from the message, invalidating the
  # submission.

  #eval {
  #  die unless $mail->send( 'mail' );
  #};
  #return 1 unless $@;

  # Try to send it using "sendmail".
  eval {
    die unless $mail->send( 'sendmail' );
  };
  return 1 unless $@;

  # Try to send it by making a direct SMTP connection.
  eval {
    die unless $mail->send( smtp => Server => $host );
  };
  return 1 unless $@;

  # Augh!  Everything failed!
  $self->debug_print( 0, '--- could not find a way to submit a disc' );
  return;
}

###############################################################################
1;
__END__

=head1 NAME

CDDB.pm - a high-level interface to cddb protocol servers (freedb and CDDB)

=head1 SYNOPSIS

  use CDDB;

  ### Connect to the cddbp server.
  my $cddbp = new CDDB( Host  => 'freedb.freedb.org', # default
                        Port  => 8880,                # default
                        Login => $login_id,           # defaults to %ENV's
                      ) or die $!;

  ### Retrieve known genres.
  my @genres = $cddbp->get_genres();

  ### Calculate cddbp ID based on MSF info.
  my @toc = ( '1    0  2 37',           # track, CD-i MSF (space-delimited)
              '999  1 38 17',           # lead-out track MSF
              '1000 0  0 Error!',       # error track (don't include if ok)
            );
  my ($cddbp_id,      # used for further cddbp queries
      $track_numbers, # padded with 0's (for convenience)
      $track_lengths, # length of each track, in MM:SS format
      $track_offsets, # absolute offsets (used for further cddbp queries)
      $total_seconds  # total play time, in seconds (for cddbp queries)
     ) = $cddbp->calculate_id(@toc);

  ### Query discs based on cddbp ID and other information.
  my @discs = $cddbp->get_discs($cddbp_id, $track_offsets, $total_seconds);
  foreach my $disc (@discs) {
    my ($genre, $cddbp_id, $title) = @$disc;
  }

  ### Query disc details (usually done with get_discs() information).
  my $disc_info     = $cddbp->get_disc_details($genre, $cddbp_id);
  my $disc_time     = $disc_info->{'disc length'};
  my $disc_id       = $disc_info->{discid};
  my $disc_title    = $disc_info->{dtitle};
  my @track_offsets = @{$disc_info->{offsets}};
  my @track_seconds = @{$disc_info->{seconds}};
  my @track_titles  = @{$disc_info->{ttitles}};
  # other information may be returned... explore!

  ### Submit a disc via e-mail. (Requires MailTools)

  die "can't submit a disc (no mail modules; see README)"
    unless $cddbp->can_submit_disc();

  # These are useful for prompting the user to fix defaults:
  print "I will send mail through: ", $cddbp->get_mail_host(), "\n";
  print "I assume your e-mail address is: ", $cddbp->get_mail_address(), "\n";

  # Actually submit a disc record.
  $cddbp->submit_disc
    ( Genre       => 'classical',
      Id          => 'b811a20c',
      Artist      => 'Various',
      DiscTitle   => 'Cartoon Classics',
      Offsets     => $disc_info->{offsets},   # array reference
      TrackTitles => $disc_info->{ttitles},   # array reference
      From        => 'login@host.domain.etc', # will try to determine
    );

=head1 DESCRIPTION

CDDB protocol (cddbp) servers provide compact disc information for
programs that need it.  This allows such programs to display disc and
track titles automatically, and it provides extended information like
liner notes and lyrics.

This module provides a high-level Perl interface to cddbp servers.
With it, a Perl program can identify and possibly gather details about
a CD based on its "table of contents" (the disc's track times and
offsets).

Disc details have been useful for generating CD catalogs, naming mp3
files, printing CD liners, or even just playing discs in an automated
jukebox.

=head1 PUBLIC METHODS

=over 4

=item new PARAMETERS

Creates a high-level interface to a cddbp server, returning a handle
to it.  The handle is not a filehandle.  It is an object.  The new()
constructor provides defaults for just about everything, but
everything is overrideable if the defaults aren't appropriate.

The interface will not actually connect to a cddbp server until it's
used, and a single cddbp interface may actually make several
connections (to possibly several servers) over the course of its use.

The new() constructor accepts several parameters, all of which have
reasonable defaults.

B<Host> and B<Port> describe the cddbp server to connect to.  These
default to 'freedb.freedb.org' and 8880, which is a multiplexor for
all the other freedb servers.

B<Protocol_Version> sets the cddbp version to use.  CDDB.pm will not
connect to servers that don't support the version specified here.  The
requested protocol version defaults to 1 if omitted.

B<Login> is the login ID you want to advertise to the cddbp server.
It defaults to the login ID your computer assigns you, if that can be
determined.  The default login ID is determined by the presence of a
LOGNAME or USER environment variable, or by the getpwuid() function.
On Windows systems, it defaults to "win32usr" if no default method can
be found and no Login parameter is set.

B<Submit_Address> is the e-mail address where new disc submissions go.
This defaults to 'freedb-submit@freedb.org'.

B<Client_Name> and B<Client_Version> describe the client software used
to connect to the cddbp server.  They default to 'CDDB.pm' and
CDDB.pm's version number.  If developers change this, please consult
freedb's web site for a list of client names already in use.

B<Debug> enables verbose operational information on STDERR when set to
true.  It's normally not needed, but it can help explain why a program
is failing.  If someone finds a reproduceable bug, the Debug output
and a test program would be a big help towards having it fixed.

=item get_genres

Takes no parameters.  Returns a list of genres known by the cddbp
server, or undef if there is a problem retrieving them.

=item calculate_id TOC

The cddb protocol defines an ID as a hash of track lengths and the
number of tracks, with an added checksum. The most basic information
required to calculate this is the CD table of contents (the CD-i track
offsets, in "MSF" [Minutes, Seconds, Frames] format).

Note however that there is no standard way to acquire this information
from a CD-ROM device.  Therefore this module does not try to read the
TOC itself.  Instead, developers must combine CDDB.pm with a CD
library which works with their system.  The AudioCD suite of modules
is recommended: it has system specific code for MacOS, Linux and
FreeBSD.  CDDB.pm's author has used external programs like dagrab to
fetch the offsets.  Actual CDs aren't always necessary: the author has
heard of people generating TOC information from mp3 file lengths.

That said, see parse_cdinfo() for a routine to parse "cdinfo" output
into a table of contents list suitable for calculate_id().

calculate_id() accepts TOC information as a list of strings.  Each
string contains four fields, separated by whitespace:

offset 0: the track number

Track numbers start with 1 and run sequentially through the number of
tracks on a disc.  Note: data tracks count on hybrid audio/data CDs.

CDDB.pm understands two special track numbers.  Track 999 holds the
lead-out information, which is required by the cddb protocol.  Track
1000 holds information about errors which have occurred while
physically reading the disc.

offset 1: the track start time, minutes field

Tracks are often addressed on audio CDs using "MSF" offsets.  This
stands for Minutes, Seconds, and Frames (fractions of a second).  The
combination pinpoints the exact disc frame where a song starts.

Field 1 contains the M part of MSF.  It is ignored for error tracks,
but it still must contain a number.  Zero is suggested.

offset 2: the track start time, seconds field

This field contains the S part of MSF.  It is ignored for error
tracks, but it still must contain a number.  Zero is suggested.

offset 3: the track start time, frames field

This field contains the F part of MSF.  For error tracks, it contains
a description of the error.

Example track file.  Note: the comments should not appear in the file.

     1   0  2 37  # track 1 starts at 00:02 and 37 frames
     2   1 38 17  # track 2 starts at 01:38 and 17 frames
     3  11 57 30  # track 3 starts at 11:57 and 30 frames
     ...
   999  75 16  5  # leadout starts at 75:16 and  5 frames

Track 1000 should not be present if everything is okay:

  1000   0  0  Error reading TOC: no disc in drive

In scalar context, calculate_id() returns just the cddbp ID.  In a
list context, it returns an array containing the following values:

  ($cddbp_id, $track_numbers, $track_lengths, $track_offsets, $total_seconds)
    = $cddbp->calculate_id(@toc);

  print( "cddbp ID      = $cddbp_id\n",        # b811a20c
         "track numbers = @$track_numbers\n",  # 001 002 003 ...
         "track lengths = @$track_lengths\n",  # 01:36 10:19 04:29 ...
         "track offsets = @$track_offsets\n",  # 187 7367 53805 ...
         "total seconds = $total_seconds\n",   # 4514
       );

CDDBP_ID

The 0th returned value is the hashed cddbp ID, required for any
queries or submissions involving this disc.

TRACK_NUMBERS

The 1st returned value is a reference to a list of track numbers, one
for each track (excluding the lead-out), padded to three characters
with leading zeroes.  These values are provided for convenience, but
they are not required by cddbp servers.

TRACK_LENGTHS

The 2nd returned value is a reference to a list of track lengths, one
for each track (excluding the lead-out), in HH:MM format.  These
values are returned as a convenience.  They are not required by cddbp
servers.

TRACK_OFFSETS

The 3rd returned value is a reference to a list of absolute track
offsets, in frames.  They are calculated from the MSF values, and they
are required by get_discs() and submit_disc().

TOTAL_SECONDS

The 4th and final value is the total playing time for the CD, in
seconds.  The get_discs() function needs it.

=item get_discs CDDBP_ID, TRACK_OFFSETS, TOTAL_SECONDS

get_discs() asks the cddbp server for a summary of all the CDs
matching a given cddbp ID, track offsets, and total playing time.
These values can be retrieved from calculade_id().

  my @id_info       = $cddbp->calculate_id(@toc);
  my $cddbp_id      = $id_info->[0];
  my $track_offsets = $id_info->[3];
  my $total_seconds = $id_info->[4];

get_discs() returns an array of matching discs, each of which is
represented by an array reference.  It returns an empty array if the
query succeeded but did not match, and it returns undef on error.

  my @discs = $cddbp->get_discs( $cddbp_id, $track_offsets, $total_seconds );
  foreach my $disc (@discs) {
    my ($disc_genre, $disc_id, $disc_title) = @$disc;
    print( "disc id    = $disc_id\n",
           "disc genre = $disc_genre\n",
           "disc title = $disc_title\n",
         );
  }

DISC_GENRE is the genre this disc falls into, as determined by whoever
submitted or last edited the disc.  The genre is required when
requesting a disc's details.  See get_genres() for how to retrieve a
list of cddbp genres.

CDDBP_ID is the cddbp ID of this disc.  Cddbp servers perform fuzzy
matches, returning near misses as well as direct hits on a cddbp ID,
so knowing the exact ID for a disc is important when submitting
changes or requesting a particular near-miss' details.

DISC_TITLE is the disc's title, which may help a human to pick the
correct disc out of several close mathches.

=item get_discs_by_toc TOC

This function acts as a macro, combining calculate_id() and
get_discs() calls into one function.  It takes the same parameters as
calculate_id(), and it returns the same information as get_discs().

=item get_discs_by_query QUERY_STRING

Fetch discs by a pre-built cddbp query string.  Some disc querying
programs report this string, and get_discs_by_query() is a convenient
way to use that.

Cddb protocol query strings look like:

  cddb query $cddbp_id $track_count @offsets $total_seconds

=item get_disc_details DISC_GENRE, CDDBP_ID

This function fetches a disc's detailed information from a cddbp
server.  It takes two parameters: the DISC_GENRE and the CDDP_ID.
These parameters usually come from a call to get_discs().

The disc's details are returned in a reference to a fairly complex
hash.  It includes information normally stored in comments.  The most
common entries in this hash include:

  $disc_details = get_disc_details( $disc_genre, $cddbp_id );

$disc_details->{"disc length"}

The disc length is commonly stored in the form "### seconds", where
### is the disc's total playing time in seconds.  It may hold other
time formats.

$disc_details->{discid}

This is a rehash (get it?) of the cddbp ID.  It should match the
CDDBP_ID given to get_disc_details().

$disc_details->{dtitle}

This is the disc's title.  I do not know whether it will match the one
returned by get_discs().

$disc_details->{offsets}

This is a reference to a list of absolute disc track offsets, similar
to the TRACK_OFFSETS returned by calculate_id().

$disc_details->{seconds}

This is a reference to a list of track length, in seconds.

$disc_details->{ttitles}

This is a reference to a list of track titles.  These are the droids
you are looking for.

$disc_details->{"processed by"}

This is a comment field identifying the name and version of the cddbp
server which accepted and entered the disc record into the database.

$disc_details->{revision}

This is the disc record's version number, used as a sanity check
(semaphore?) to prevent simultaneous revisions.  Revisions start at 0
for new submissions and are incremented for every correction.  It is
the responsibility of the submitter (be it a person or a program using
CDDB.pm) to provide a correct revision number.

$disc_details->{"submitted via"}

This is the name and version of the software that submitted this cddbp
record.  The main intention is to identify records that are submitted
by broken software so they can be purged or corrected.

$disc_details->{xmcd_record}

The xmcd_record field contains a copy of the entire unprocessed cddbp
response that generated all the other fields.

$disc_details->{genre}

This is merely a copy of DISC_GENRE, since it's otherwise not possible
to determine it from the hash.

=item parse_xmcd_file XMCD_FILE_CONTENTS, [GENRE]

Parses an array ref of lines read from an XMCD file into the
disc_details hash described above.  If the GENRE parameter is set it
will be included in disc_details.

=item can_submit_disc

Returns true or false, depending on whether CDDB.pm has enough
dependent modules to submit discs.  If it returns false, you are
missing Mail::Internet, Mail::Header, or MIME::QuotedPrint.

=item get_mail_address

Returns what CDDB.pm thinks your e-mail address is, or what it was
last set to.  It was added to fetch the default e-mail address so
users can see it and have an opportunity to correct it.

  my $mail_from = $cddb->get_mail_address();
  print "New e-mail address (or blank to keep <$mail_from>): ";
  my $new_mail_from = <STDIN>;
  $new_mail_from =~ s/^\s+//;
  $new_mail_from =~ s/\s+$//;
  $new_mail_from =~ s/\s+/ /g;
  $mail_from = $new_mail_from if length $new_mail_from;

  $cddbp->submit_disc( ...,
                       From => $mail_from,
                     );

=item get_mail_host

Returns what CDDB.pm thinks your SMTP host is, or what it was last set
to.  It was added to fetch the default e-mail transfer host so users
can see it and have an opportunity to correct it.

  my $mail_host = $cddb->get_mail_host();
  print "New e-mail host (or blank to keep <$mail_host>): ";
  my $new_mail_host = <STDIN>;
  $new_mail_host =~ s/^\s+//;
  $new_mail_host =~ s/\s+$//;
  $new_mail_host =~ s/\s+/ /g;
  $mail_host = $new_mail_host if length $new_mail_host;

  $cddbp->submit_disc( ...,
                       Host => $mail_host,
                     );

=item parse_cdinfo CDINFO_FILE

Generates a table of contents suitable for calculate_id() based on the
output of a program called "cdinfo".  CDINFO_FILE may either be a text
file, or it may be the cdinfo program itself.

  my @toc = parse_cdinfo("cdinfo.txt"); # read cdinfo.txt
  my @toc = parse_cdinfo("cdinfo|");    # run cdinfo directly

The table of contents can be passed directly to calculate_id().

=item submit_disc DISC_DETAILS

submit_disc() submits a disc record to a cddbp server.  Currently it
only uses e-mail, although it will try different ways to send that.
It returns true or false depending on whether it was able to send the
submission e-mail.

The rest of CDDB.pm will work without the ability to submit discs.
While cddbp submissions are relatively rare, most CD collections will
have one or two discs not present in the system.  Please submit new
discs to the system: the amazing number of existing discs got there
because others submitted them before you needed them.

submit_disc() takes six required parameters and two optional ones.
The parameters are named, like hash elements, and can appear in any
order.

Genre => DISC_GENRE

This is the disc's genre.  It must be one of the genres that the
server knows.  See get_genres().

Id => CDDBP_ID

This is the cddbp ID that identifies the disc.  It should come from
calculate_id() if this is a new submission, or from get_disc_details()
if this is a revision.

Artist => DISC_ARTIST

This is the disc's artist, a freeform text field describing the party
responsible for the album.  It will need to be entered from the disc's
notes for new submissions, or it can come from get_disc_details() on
subsequent revisions.

DiscTitle => DISC_TITLE

This is the disc's title, a freeform text field describing the album.
It must be entered from the disc's notes for new submissions.  It can
come from get_disc_details() on subsequent revisions.

Offsets => TRACK_OFFSETS

This is a reference to an array of absolute track offsets, as provided
by calculate_id().

TrackTitles => TRACK_TITLES

This is a reference to an array of track titles, either entered by a
human or provided by get_disc_details().

From => EMAIL_ADDRESS

This is the disc submitter's e-mail address.  It's not required, and
CDDB.pm will try to figure one out on its own if an address is
omitted.  It may be more reliable to provide your own, however.

The default return address may not be a deliverable one, especially if
CDDB.pm is being used on a dial-up machine that isn't running its own
MTA.  If the current machine has its own MTA, problems still may occur
if the machine's Internet address changes.

Host => SMTP_HOST

This is the SMTP host to contact when sending mail.  It's not
required, and CDDB.pm will try to figure one out on its own.  It will
look at the SMTPHOSTS environment variable is not defined, it will try
'mail' and 'localhost' before finally failing.

=back

=head1 PRIVATE METHODS

Documented as being not documented.

=head1 EXAMPLES

Please see the cddb.t program in the t (tests) directory.  It
exercises every aspect of CDDB.pm, including submissions.

=head1 BUGS

There are no known bugs, but see the README for things that need to be
done.

=head1 CONTACT AND COPYRIGHT

Copyright 1998-2002 Rocco Caputo.  All rights reserved.  This program
is free software; you can redistribute it and/or modify it under the
same terms as Perl itself.

Rocco may be contacted at rcaputo@cpan.org.

=cut
