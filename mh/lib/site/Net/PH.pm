#
# Copyright (c) 1995-1997 Graham Barr <gbarr@ti.com> and
# Alex Hristov <hristov@slb.com>. All rights reserved. This program is free
# software; you # can redistribute it and/or modify it under the same terms
# as Perl itself.

package Net::PH;

require 5.001;

use strict;
use vars qw(@ISA $VERSION);
use Carp;

use Socket 1.3;
use IO::Socket;
use Net::Cmd;
use Net::Config;

$VERSION = do { my @r=(q$Revision$=~/\d+/g); sprintf "%d."."%02d"x$#r,@r};
@ISA     = qw(Exporter Net::Cmd IO::Socket::INET);

sub new
{
 my $pkg  = shift;
 my $host = shift if @_ % 2;
 my %arg  = @_; 
 my $hosts = defined $host ? [ $host ] : $NetConfig{ph_hosts};
 my $ph;

 my $h;
 foreach $h (@{$hosts})
  {
   $ph = $pkg->SUPER::new(PeerAddr => ($host = $h), 
			  PeerPort => $arg{Port} || 'csnet-ns(105)',
			  Proto    => 'tcp',
			  Timeout  => defined $arg{Timeout}
					? $arg{Timeout}
					: 120
			 ) and last;
  }

 return undef
	unless defined $ph;

 ${*$ph}{'net_ph_host'} = $host;

 $ph->autoflush(1);

 $ph->debug(exists $arg{Debug} ? $arg{Debug} : undef);

 $ph;
}

sub status
{
 my $ph = shift;

 $ph->command('status')->response;
 $ph->code;
}

sub login
{
 my $ph = shift;
 my($user,$pass,$encrypted) = @_;
 my $resp;

 $resp = $ph->command("login",$user)->response;

 if(defined($pass) && $resp == CMD_MORE)
  {
   if($encrypted)
    {
     my $challenge_str = $ph->message;
     chomp($challenge_str);
     Net::PH::crypt::crypt_start($pass);
     my $cryptstr = Net::PH::crypt::encryptit($challenge_str);

     $ph->command("answer", $cryptstr);
    }
   else
    {
     $ph->command("clear", $pass);
    }
   $resp = $ph->response;
  }

 $resp == CMD_OK;
}

sub logout
{
 my $ph = shift;

 $ph->command("logout")->response == CMD_OK;
}

sub id
{
 my $ph = shift;
 my $id = @_ ? shift : $<;

 $ph->command("id",$id)->response == CMD_OK;
}

sub siteinfo
{
 my $ph = shift;

 $ph->command("siteinfo");

 my $ln;
 my %resp;
 my $cur_num = 0;

 while(defined($ln = $ph->getline))
  {
   $ph->debug_print(0,$ln)
     if ($ph->debug & 2);
   chomp($ln);
   my($code,$num,$tag,$data);

   if($ln =~ /^-(\d+):(\d+):(?:\s*([^:]+):)?\s*(.*)/o)
    {
     ($code,$num,$tag,$data) = ($1, $2, $3 || "",$4);
     $resp{$tag} = bless [$code, $num, $tag, $data], "Net::PH::Result";
    }
   else
    {
     $ph->set_status($ph->parse_response($ln));
     return \%resp;
    }
  }

 return undef;
}

sub query
{
 my $ph = shift;
 my $search = shift;

 my($k,$v);

 my @args = ('query', _arg_hash($search));

 push(@args,'return',_arg_list( shift ))
	if @_;

 unless($ph->command(@args)->response == CMD_INFO)
  {
   return $ph->code == 501
	? []
	: undef;
  }

 my $ln;
 my @resp;
 my $cur_num = 0;

 my($last_tag);

 while(defined($ln = $ph->getline))
  {
   $ph->debug_print(0,$ln)
     if ($ph->debug & 2);
   chomp($ln);
   my($code,$idx,$num,$tag,$data);

   if($ln =~ /^-(\d+):(\d+):\s*([^:]*):\s*(.*)/o)
    {
     ($code,$idx,$tag,$data) = ($1,$2,$3,$4);
     my $num = $idx - 1;

     $resp[$num] ||= {};

     $tag = $last_tag
	unless(length($tag));

     $last_tag = $tag;

     if(exists($resp[$num]->{$tag}))
      {
       $resp[$num]->{$tag}->[3] .= "\n" . $data;
      }
     else
      {
       $resp[$num]->{$tag} = bless [$code, $idx, $tag, $data], "Net::PH::Result";
      }
    }
   else
    {
     $ph->set_status($ph->parse_response($ln));
     return \@resp;
    }
  }

 return undef;
}

sub change
{
 my $ph = shift;
 my $search = shift;
 my $make = shift;

 $ph->command(
	"change", _arg_hash($search),
	"make",   _arg_hash($make)
 )->response == CMD_OK;
}

sub _arg_hash
{
 my $hash = shift;

 return $hash
	unless(ref($hash));

 my($k,$v);
 my @r;

 while(($k,$v) = each %$hash)
  {
   my $a = $v;
   $a =~ s/\n/\\n/sog;
   $a =~ s/\t/\\t/sog;
   $a = '"' . $a . '"'
	if $a =~ /\W/;
   push(@r, "$k=$a");   
  }
 join(" ", @r);
}

sub _arg_list
{
 my $arr = shift;

 return $arr
	unless(ref($arr));

 my $v;
 my @r;

 foreach $v (@$arr)
  {
   my $a = $v;
   $a =~ s/\n/\\n/sog;
   $a =~ s/\t/\\t/sog;
   $a = '"' . $a . '"'
	if $a =~ /\W/;
   push(@r, $a);   
  }

 join(" ",@r);
}

sub add
{
 my $ph = shift;
 my $arg = @_ > 1 ? { @_ } : shift;

 $ph->command('add', _arg_hash($arg))->response == CMD_OK;
}

sub delete
{
 my $ph = shift;
 my $arg = @_ > 1 ? { @_ } : shift;

 $ph->command('delete', _arg_hash($arg))->response == CMD_OK;
}

sub force
{
 my $ph = shift; 
 my $search = shift;
 my $force = shift;

 $ph->command(
	"change", _arg_hash($search),
	"force",  _arg_hash($force)
 )->response == CMD_OK;
}


sub fields
{
 my $ph = shift;

 $ph->command("fields", _arg_list(\@_));

 my $ln;
 my %resp;
 my $cur_num = 0;

 while(defined($ln = $ph->getline))
  {
   $ph->debug_print(0,$ln)
     if ($ph->debug & 2);
   chomp($ln);
   my($code,$num,$tag,$data,$last_tag);

   if($ln =~ /^-(\d+):(\d+):\s*([^:]*):\s*(.*)/o)
    {
     ($code,$num,$tag,$data) = ($1,$2,$3,$4);

     $tag = $last_tag
	unless(length($tag));

     $last_tag = $tag;

     if(exists $resp{$tag})
      {
       $resp{$tag}->[3] .= "\n" . $data;
      }
     else
      {
       $resp{$tag} = bless [$code, $num, $tag, $data], "Net::PH::Result";
      }
    }
   else
    {
     $ph->set_status($ph->parse_response($ln));
     return \%resp;
    }
  }
 return undef;
}

sub quit
{
 my $ph = shift;

 $ph->close
	if $ph->command("quit")->response == CMD_OK;
}

##
## Net::Cmd overrides
##

sub parse_response
{
 return ()
    unless $_[1] =~ s/^(-?)(\d\d\d):?//o;
 ($2, $1 eq "-");
}

sub debug_text { $_[2] =~ /^(clear)/i ? "$1 ....\n" : $_[2]; }

package Net::PH::Result;

sub code  { shift->[0] }
sub value { shift->[1] }
sub field { shift->[2] }
sub text  { shift->[3] }

package Net::PH::crypt;

##
#	'cryptit.pl'
#
#	Description:	perl port of Steven Dorner's cryptit.c
#
#					Allows password encryption for CCSO
#					qi server.
#
#	Author:			Broc Seib
#	       			Purdue University Computing Center
#	Date:			Thu Nov  7 21:17:46 EST 1996
#					Tue Nov 12 16:04:36 EST 1996
##

##
#
#  This software is based upon 'cryptit.c', Copyright (C) 1988 by
#  Steven Dorner and the University of Illinois Board of Trustees,
#  and by CSNET.
#
#  The development of this software is independent of any of the
#  aforementioned parties. No warranties of any kind are expressed
#  or implied.
#
#  Author of this perl library 'cryptit.pl' may be contacted:
#
#	Broc Seib bseib@purdue.edu  Network Systems Programmer
#	1408 Mathematical Sciences  Instructional Computing Division
#	W Lafayette, IN 47907-1408  Purdue University Computing Center
#	
##

use Math::BigInt;
use	integer;

##
#	CONSTANTS
#

use vars qw($c1 $c2 $c3 $c4 @cr $n1 $n2
	    $ROTORSZ $MASK $ERR $REPORT $BUGZ
	    @t1 @t2 @t3 $i $k );

BEGIN {
	$ROTORSZ = 256;
	$MASK = 255;
	$BUGZ = 0;		# to set debug output level
	$ERR = "";
	$REPORT = "$ERR\nPlease report this bug to bseib\@purdue.edu.\n";
}
#
##


##
#	Routine:		crypt_start
#					&crypt_start($passwd);
#
#	Description:	Initializes the crypt tables based on a passwd.
#
#	Author:			Broc Seib
#	       			Purdue University Computing Center
#	Date:			Thu Nov  7 21:33:37 EST 1996
##
sub crypt_start # (char *pass)
{
	my	$pw = $_[0] if $_[0];
	my	($ic, $i, $k, $temp, $random, $buf, $lbuf);
	my	$seed;
	my	($signed_seed, $sign);
	my	$b32 = new Math::BigInt '4294967296';
	my	$b31 = new Math::BigInt '2147483648';

	$n1 = 0;
	$n2 = 0;

	##
	#	init tables to zero
	#
	for ($i = 0; $i < $ROTORSZ; $i++) {
		$t1[$i] = $t2[$i] = $t3[$i] = 0;
	}
	#
	##

	##
	#	create a "random" set of chars, DES-based on your passwd,
	#	using the same passwd as salt.
	#
	$buf = crypt($pw, $pw);	# should return a 13 char str to $buf
	$lbuf = length($buf);
	return(-1) if ($lbuf <= 0); # caller didn't supply a passwd
	#
	#	using a seeded pseudo random num gen, fill in the tables
	#	with "random" guk.
	#
	$seed = new Math::BigInt '123';		# where did 123 come from, Steve? :-)
	for ($i = 0; $i < $lbuf; $i++) {
		$seed = ($seed * ord(substr($buf,$i,1)) + $i) % $b32;
	}
	for ($i = 0; $i < $ROTORSZ; $i++) {
		$t1[$i] = $i;
	}

	for ($i = 0; $i < $ROTORSZ; $i++) {
		print STDERR "\n" if ($BUGZ > 1);
		$seed = (5 * $seed + ord(substr($buf,($i % $lbuf),1))) % $b32;
		printf(STDERR "seed: %08lx\n",$seed) if ($BUGZ > 1);
		if ($seed >= $b31) {
			$sign = -1;
			$signed_seed = ($seed - $b32);
		} else {
			$sign = 1;
			$signed_seed = ($seed);
		}
		printf(STDERR "sgsd: %08lx\n",$signed_seed) if ($BUGZ > 1);
		$random = $sign * int($signed_seed % '65521');
		printf(STDERR "ran1: %08lx\n",$random) if ($BUGZ > 1);
		$k = $ROTORSZ - 1 - $i;
		$ic = ($random & $MASK) % ($k + 1);
		printf(STDERR " ic1: %08lx\n",$ic) if ($BUGZ > 1);
		$random = ($random >> 8) & $MASK;
		printf(STDERR "ran2: %08lx\n",$random) if ($BUGZ > 1);
		$temp = $t1[$k];
		$t1[$k] = $t1[$ic];
		$t1[$ic] = $temp;
		next if ($t3[$k] != 0);
		unless ($k) {
			$ERR = "[0] Can't % by zero. \$k=$k";
			die $REPORT;
		}
		$ic = ($random & $MASK) % $k;
		printf(STDERR " ic2: %08lx\n",$ic) if ($BUGZ > 1);
		while ($t3[$ic] != 0) {
			unless ($k) {
				$ERR = "[1] Can't % by zero. \$k=$k";
				die $REPORT;
			}
			$ic = ($ic + 1) % $k;
			printf(STDERR " ic3: %08lx\n",$ic) if ($BUGZ > 1);
		}
		$t3[$k] = $ic;
		$t3[$ic] = $k;
	}
	for ($i = 0; $i < $ROTORSZ; $i++) {
		$t2[$t1[$i] & $MASK] = $i;
	}
	#
	##

	##
	#	if in debug mode, print the crypt tables
	#
	&print_t(@t1) if $BUGZ;
	&print_t(@t2) if $BUGZ;
	&print_t(@t3) if $BUGZ;
	#
	##

	##
	#	return value undefined
	#
	undef;
	#
	##
}


##
#	Routine:		encryptit
#					($len,$crypt_str) = &encryptit($plain_str);
#
#	Description:	Encrypts a string given the current state of
#					the encryption tables, as setup by &crypt_start().
#					The plain string is passed in, A length scalar is
#					returned, representing the length of the encrypted
#					string. The encrypted string also contains a length
#					byte as the first byte. The crypt string is returned
#					as the second return array element.
#
#	Author:			Broc Seib
#	       			Purdue University Computing Center
#	Date:			Thu Nov  7 23:00:44 EST 1996
##
sub encryptit
{
	my	$plain_str = $_[0] if $_[0];
	my	$crypt_str;
	my	($x, @cr);

	print STDERR $plain_str,"\n" if $BUGZ;

	##
	#	for each letter in the plain str, create a
	#	byte for part of the crypt str. They will actually
	#	be remapped into a 6bit character set, thus growing
	#	in length by a factor of a third. It is advised to pass
	#	in a string that is a length multiple of three.
	#
	for ($i=0;$i<length($plain_str);$i++) {
		$x = ord(substr($plain_str,$i,1)) + $n1;
		$x = $t1[$x & $MASK] + $n2;
		$x = $t3[$x & $MASK] - $n2;
		$x = $t2[$x & $MASK] - $n1;
		$x = ($x & $MASK);
		push (@cr, $x);
		$n1 = ($n1 + 1) % $ROTORSZ;
		$n2 = ($n2 + 1) % $ROTORSZ unless ($n1);
	}
	#
	##

	##
	#	convert this list of bytes into printable string
	#	and return it along with str length
	#
	$crypt_str =  &encode(@cr);
	return (length($crypt_str),$crypt_str);
	#
	##
}


##
#	Routine:		encode
#
#	Description:	Encodes a list of bytes into a printable string.
#					The printable characters are in a set of 64
#					beginning with ASCII '#'. Only 6 bits are needed
#					per character, so a set of 3 chars incoming are
#					converted into 4 chars outgoing. The beginning
#					length byte represents the number of eight bit
#					chars coming in, not the number of six bit chars
#					going out.
#
#	Author:			Broc Seib
#	       			Purdue University Computing Center
#	Date:			Thu Nov  7 23:41:36 EST 1996
##
sub encode
{
	my	@cr = @_ if @_;		# the crypt char list;
	my	$str;
	my	($c1, $c2, $c3, $c4);
	my	@ts;				# stands for "threesome"

	$str = &ENC($#cr + 1);		# length byte

	@ts = splice(@cr,0,3);		# grab first three from list
	while ($#ts == 2) {			# right size
		$c1 = int(  $ts[0] / 4);
		$c2 = int( ($ts[0] % 4) * 16 + (int($ts[1] / 16) % 16) );
		$c3 = int( ($ts[1] % 16) * 4 + (int($ts[2] / 64) % 4 ) );
		$c4 = int( ($ts[2] % 64) );
		$str = $str . &ENC($c1) . &ENC($c2) . &ENC($c3) . &ENC($c4);
		@ts = splice(@cr,0,3);	# grab next three from list
	}

	$str;	# return encoded string
}


sub ENC {
	my	$c = $_[0] if $_[0];
	return sprintf("%c",(($c % 64) + ord('#')) );
}

sub SetDebugMode {
	$BUGZ = $_[0];
}

sub print_t {
    my $i = 0;
    my @t = @_;
    foreach (@t) {
        printf(STDERR "%02x",$_);
        unless (++$i % 32) {
            print STDERR "\n";
        } else {
            print STDERR ":" unless ($i % 4);
        }
    }
    print STDERR "\n";
}

##
#	EOF
##
1;

__END__

=head1 NAME

Net::PH - CCSO Nameserver Client class

=head1 SYNOPSIS

    use Net::PH;
    
    $ph = Net::PH->new("some.host.name",
                       Port    => 105,
                       Timeout => 120,
                       Debug   => 0);

    if($ph) {
        $q = $ph->query({ field1 => "value1" },
                        [qw(name address pobox)]);
    
        if($q) {
        }
    }
    
    # Alternative syntax
    
    if($ph) {
        $q = $ph->query('field1=value1',
                        'name address pobox');
    
        if($q) {
        }
    }

=head1 DESCRIPTION

C<Net::PH> is a class implementing a simple Nameserver/PH client in Perl
as described in the CCSO Nameserver -- Server-Client Protocol. Like other
modules in the Net:: family the C<Net::PH> object inherits methods from
C<Net::Cmd>.

=head1 CONSTRUCTOR

=over 4

=item new ( [ HOST ] [, OPTIONS ])

    $ph = Net::PH->new("some.host.name",
                       Port    => 105,
                       Timeout => 120,
                       Debug   => 0
                      );

This is the constructor for a new Net::PH object. C<HOST> is the
name of the remote host to which a PH connection is required.

If C<HOST> is not given, then the C<SNPP_Host> specified in C<Net::Config>
will be used.

C<OPTIONS> is an optional list of named options which are passed in
a hash like fashion, using key and value pairs. Possible options are:-

B<Port> - Port number to connect to on remote host.

B<Timeout> - Maximum time, in seconds, to wait for a response from the
Nameserver, a value of zero will cause all IO operations to block.
(default: 120)

B<Debug> - Enable the printing of debugging information to STDERR

=back

=head1 METHODS

Unless otherwise stated all methods return either a I<true> or I<false>
value, with I<true> meaning that the operation was a success. When a method
states that it returns a value, failure will be returned as I<undef> or an
empty list.

=over 4

=item query( SEARCH [, RETURN ] )

    $q = $ph->query({ name => $myname },
		    [qw(name email schedule)]);
    
    foreach $handle (@{$q}) {
	foreach $field (keys %{$handle}) {
            $c = ${$handle}{$field}->code;
            $v = ${$handle}{$field}->value;
            $f = ${$handle}{$field}->field;
            $t = ${$handle}{$field}->text;
            print "field:[$field] [$c][$v][$f][$t]\n" ;
	}
    }

    

Search the database and return fields from all matching entries.

The C<SEARCH> argument is a reference to a HASH which contains field/value
pairs which will be passed to the Nameserver as the search criteria.

C<RETURN> is optional, but if given it should be a reference to a list which
contains field names to be returned.

The alternative syntax is to pass strings instead of references, for example

    $q = $ph->query('name=myname',
		    'name email schedule');

The C<SEARCH> argument is a string that is passed to the Nameserver as the 
search criteria.

C<RETURN> is optional, but if given it should be a string which will
contain field names to be returned.

Each match from the server will be returned as a HASH where the keys are the
field names and the values are C<Net::PH:Result> objects (I<code>, I<value>, 
I<field>, I<text>).

Returns a reference to an ARRAY which contains references to HASHs, one
per match from the server.

=item change( SEARCH , MAKE )

    $r = $ph->change({ email => "*.domain.name" },
                     { schedule => "busy");

Change field values for matching entries.

The C<SEARCH> argument is a reference to a HASH which contains field/value
pairs which will be passed to the Nameserver as the search criteria.

The C<MAKE> argument is a reference to a HASH which contains field/value
pairs which will be passed to the Nameserver that
will set new values to designated fields.

The alternative syntax is to pass strings instead of references, for example

    $r = $ph->change('email="*.domain.name"',
                     'schedule="busy"');

The C<SEARCH> argument is a string to be passed to the Nameserver as the 
search criteria.

The C<MAKE> argument is a string to be passed to the Nameserver that
will set new values to designated fields.

Upon success all entries that match the search criteria will have
the field values, given in the Make argument, changed.

=item login( USER, PASS [, ENCRYPT ])

    $r = $ph->login('username','password',1);

Enter login mode using C<USER> and C<PASS>. If C<ENCRYPT> is given and
is I<true> then the password will be used to encrypt a challenge text 
string provided by the server, and the encrypted string will be sent back
to the server. If C<ENCRYPT> is not given, or I<false> the the password 
will be sent in clear text (I<this is not recommended>)

=item logout()

    $r = $ph->logout();

Exit login mode and return to anonymous mode.

=item fields( [ FIELD_LIST ] )

    $fields = $ph->fields();
    foreach $field (keys %{$fields}) {
        $c = ${$fields}{$field}->code;
        $v = ${$fields}{$field}->value;
        $f = ${$fields}{$field}->field;
        $t = ${$fields}{$field}->text;
        print "field:[$field] [$c][$v][$f][$t]\n";
    }

Returns a reference to a HASH. The keys of the HASH are the field names
and the values are C<Net::PH:Result> objects (I<code>, I<value>, I<field>,
I<text>).

C<FIELD_LIST> is a string that lists the fields for which info will be
returned.

=item add( FIELD_VALUES )

    $r = $ph->add( { name => $name, phone => $phone });

This method is used to add new entries to the Nameserver database. You
must successfully call L<login> before this method can be used.

B<Note> that this method adds new entries to the database. To modify
an existing entry use L<change>.

C<FIELD_VALUES> is a reference to a HASH which contains field/value
pairs which will be passed to the Nameserver and will be used to 
initialize the new entry.

The alternative syntax is to pass a string instead of a reference, for example

    $r = $ph->add('name=myname phone=myphone');

C<FIELD_VALUES> is a string that consists of field/value pairs which the
new entry will contain.

=item delete( FIELD_VALUES )

    $r = $ph->delete('name=myname phone=myphone');

This method is used to delete existing entries from the Nameserver database.
You must successfully call L<login> before this method can be used.

B<Note> that this method deletes entries to the database. To modify
an existing entry use L<change>.

C<FIELD_VALUES> is a string that serves as the search criteria for the
records to be deleted. Any entry in the database which matches this search 
criteria will be deleted.

=item id( [ ID ] )

    $r = $ph->id('709');

Sends C<ID> to the Nameserver, which will enter this into its
logs. If C<ID> is not given then the UID of the user running the
process will be sent.

=item status()

Returns the current status of the Nameserver.

=item siteinfo()

    $siteinfo = $ph->siteinfo();
    foreach $field (keys %{$siteinfo}) {
        $c = ${$siteinfo}{$field}->code;
        $v = ${$siteinfo}{$field}->value;
        $f = ${$siteinfo}{$field}->field;
        $t = ${$siteinfo}{$field}->text;
        print "field:[$field] [$c][$v][$f][$t]\n";
    }

Returns a reference to a HASH containing information about the server's 
site. The keys of the HASH are the field names and values are
C<Net::PH:Result> objects (I<code>, I<value>, I<field>, I<text>).

=item quit()

    $r = $ph->quit();

Quit the connection

=back

=head1 Q&A

How do I get the values of a Net::PH::Result object?

    foreach $handle (@{$q}) {
        foreach $field (keys %{$handle}) {
            $my_code  = ${$q}{$field}->code;
            $my_value = ${$q}{$field}->value;
            $my_field = ${$q}{$field}->field;
            $my_text  = ${$q}{$field}->text;
        }
    }

How do I get a count of the returned matches to my query?

    $my_count = scalar(@{$query_result});

How do I get the status code and message of the last C<$ph> command?

    $status_code    = $ph->code;
    $status_message = $ph->message;

=head1 SEE ALSO

L<Net::Cmd>

=head1 AUTHORS

Graham Barr <gbarr@ti.com>
Alex Hristov <hristov@slb.com>

=head1 ACKNOWLEDGMENTS

Password encryption code ported to perl by Broc Seib <bseib@purdue.edu>,
Purdue University Computing Center.

Otis Gospodnetic <otisg@panther.middlebury.edu> suggested
passing parameters as string constants. Some queries cannot be 
executed when passing parameters as string references.

        Example: query first_name last_name email="*.domain"

=head1 COPYRIGHT

The encryption code is based upon cryptit.c, Copyright (C) 1988 by
Steven Dorner and the University of Illinois Board of Trustees,
and by CSNET.

All other code is Copyright (c) 1996-1997 Graham Barr <gbarr@ti.com>
and Alex Hristov <hristov@slb.com>. All rights reserved. This program is
free software; you can redistribute it and/or modify it under the same
terms as Perl itself.

=cut
