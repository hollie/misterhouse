package Net::Jabber::Debug;

=head1 NAME

Net::Jabber::Debug - Jabber Debug Library

=head1 SYNOPSIS

  Net::Jabber::Debug is a module that provides a developer easy access
  to logging debug information.

=head1 DESCRIPTION

  Debug is a helper module for the Net::Jabber modules.  It provides
  the Net::Jabber modules with an object to control where, how, and
  what is logged.

=head2 Basic Functions

    $Debug = new Net::Jabber::Debug();

    $Debug->Init(level=>2,
	         file=>"stdout",
  	         header=>"MyScript");

    $Debug->Log("Connection established");

=head1 METHODS

=head2 Basic Functions

    new(hash) - creates the Debug object.  The hash argument is passed
                to the Init function.  See that function description
                below for the valid settings.

    Init(level=>integer,  - initializes the debug object.  The level
         file=>string,      determines the maximum level of debug
         header=>string,    messages to log:
         setdefault=>0|1,     0 - Base level Output (default)
         usedefault=>0|1)     1 - High level API calls
                              2 - Low level API calls
                            The file determines where the debug log
                            goes.  You can either specify a path to
                            a file, or "stdout" (the default).  "stdout"
                            tells Debug to send all of the debug info
                            sent to this object to go to stdout.
                            header is a string that will preappended
                            to the beginning of all log entries.  This
                            makes it easier to see what generated the
                            log entry (default is "Debug").
                            setdefault saves the current filehandle
                            and makes it available for other Debug
                            objects to use.  To use the default set
                            usedefault to 1.

    Log0(array) - Logs the elements of the array at the corresponding
    Log1(array)   debug level.  If you pass in a reference to an
    Log2(array)   array or hash then they are printed in a readable
                  way.

=head1 EXAMPLE

  $Debug = new Net::Jabber:Debug(level=>2,
                                 header=>"Example");

    $Debug->Log0("test");

    $Debug->Log2("level 2 test");

    $hash{a} = "atest";
    $hash{b} = "btest";

    $Debug->Log1("hashtest",\%hash);

  You would get the following log:

    Example: test
    Example: level 2 test
    Example: hashtest { a=>"atest" b=>"btest" }

  If you has set the level to 1 instead of 2 you would get:

    Example: test
    Example: hashtest { a=>"atest" b=>"btest" }

=head1 AUTHOR

By Ryan Eatmon in May of 2000 for http://jabber.org.

=head1 COPYRIGHT

This module is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

require 5.003;
use strict;
use FileHandle;
use vars qw($VERSION %HANDLES $DEFAULT $DEFAULTLEVEL);

$VERSION = "1.0013";

sub new {
  my $proto = shift;
  my $self = { };
  bless($self, $proto);

  $self->Init(@_);

  $self->{VERSION} = $VERSION;

  return $self;
}


##############################################################################
#
# Init - opens the fielhandle and initializes the Debug object.
#
##############################################################################
sub Init {
  my $self = shift;

  my %args;
  while($#_ >= 0) { $args{ lc pop(@_) } = pop(@_); }


  delete($args{file}) if (lc($args{file}) eq "stdout");

  $args{setdefault} = 0 if !exists($args{setdefault});
  $args{usedefault} = 0 if !exists($args{usedefault});
  
  if (($args{usedefault} == 1) && ($Net::Jabber::Debug::DEFAULT ne "")) {
    $args{setdefault} = 0;

    $self->{LEVEL} = $Net::Jabber::Debug::DEFAULTLEVEL;
    $self->{HANDLE} = $Net::Jabber::Debug::DEFAULT;

  } else { 
    $self->{LEVEL} = 0;
    $self->{LEVEL} = $args{level} if exists($args{level});
    
    $self->{HANDLE} = new FileHandle(">&STDOUT");
    $self->{HANDLE}->autoflush(1);
    if (exists($args{file})) {
      if (exists($Net::Jabber::Debug::HANDLES{$args{file}})) {
	$self->{HANDLE} = $Net::Jabber::Debug::HANDLES{$args{file}};
	$self->{HANDLE}->autoflush(1);
      } else {
	if (-e $args{file}) {
	  if (-w $args{file}) {
	    $self->{HANDLE} = new FileHandle(">$args{file}");
	    if (defined($self->{HANDLE})) {
	      $self->{HANDLE}->autoflush(1);
	      $Net::Jabber::Debug::HANDLES{$args{file}} = $self->{HANDLE};
	    } else {
	      print STDERR "ERROR: Debug filehandle could not be opened.\n";
	      print STDERR"        Debugging disabled.\n";
	      print STDERR "       ($!)\n";
	      $self->{LEVEL} = -1;
	    }
	  } else {
	    print STDERR "ERROR: You do not have permission to write to $args{file}.\n";
	    print STDERR"        Debugging disabled.\n";
	    $self->{LEVEL} = -1;
	  }
	} else {
	  $self->{HANDLE} = new FileHandle(">$args{file}");
	  if (defined($self->{HANDLE})) {
	    $self->{HANDLE}->autoflush(1);
	    $Net::Jabber::Debug::HANDLES{$args{file}} = $self->{HANDLE};
	  } else {
	    print STDERR "ERROR: Debug filehandle could not be opened.\n";
	    print STDERR"        Debugging disabled.\n";
	    print STDERR "       ($!)\n";
	    $self->{LEVEL} = -1;
	  }
	}
      }
    }
  }
  if ($args{setdefault} == 1) {
    $Net::Jabber::Debug::DEFAULT = $self->{HANDLE};
    $Net::Jabber::Debug::DEFAULTLEVEL = $self->{LEVEL};
  } 

  $self->{HEADER} = "Debug";
  $self->{HEADER} = $args{header} if exists($args{header});
}


##############################################################################
#
# Log - takes the limit and the array to log and logs them
#
##############################################################################
sub Log {
  my $self = shift;
  my $level = shift;
  my (@args) = @_;

  return if ($level > $self->{LEVEL});

  my $fh = $self->{HANDLE};

  my $string = $self->{HEADER}.":";

  my $arg;
  foreach $arg (@args) {
    if (ref($arg) eq "HASH") {
      $string .= " {";
      my $key;
      foreach $key (sort {$a cmp $b} keys(%{$arg})) {
	$string .= " ".$key."=>'".$arg->{$key}."'";
      }
      $string .= " }";
    } else {
      if (ref($arg) eq "ARRAY") {
	$string .= " [ ".join(" ",@{$arg})." ]";
      }	else {
	$arg =~ s/^\s+//;
	$arg =~ s/\s+$//;
	$string .= " ".$arg;
      }
    }
  }
  print $fh "$string\n";
}


##############################################################################
#
# Log0 - logs the array at debug level 0
#
##############################################################################
sub Log0 {
  my $self = shift;
  $self->Log(0,@_);
}


##############################################################################
#
# Log1 - logs the array at debug level 1
#
##############################################################################
sub Log1 {
  my $self = shift;
  $self->Log(1,@_);
}


##############################################################################
#
# Log2 - logs the array at debug level 2
#
##############################################################################
sub Log2 {
  my $self = shift;
  $self->Log(2,@_);
}


##############################################################################
#
# GetHandle - returns the filehandle being used by this object.
#
##############################################################################
sub GetHandle {
  my $self = shift;
  return $self->{HANDLE};
}


##############################################################################
#
# GetLevel - returns the debug level used by this object.
#
##############################################################################
sub GetLevel {
  my $self = shift;
  return $self->{LEVEL};
}


1;
