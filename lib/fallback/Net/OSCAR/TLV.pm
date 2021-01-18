=pod

Net::OSCAR::TLV -- tied hash for OSCAR TLVs

Keys in hashes tied to this class will be treated as numbers.
This class also preserves the ordering of its keys.

=cut

package Net::OSCAR::TLV;

$VERSION = '1.925';
$REVISION = '$Revision: 1.31 $';

use strict;
use vars qw($VERSION @EXPORT @ISA);

require Exporter;
@ISA = qw(Exporter);
@EXPORT = qw(tlv);

# Extra arguments: an optional scalar which modifies the behavior of $self->{foo}->{bar} = "baz"
# Iff foo doesn't exist, the scalar will be evaluated and assigned as the value of foo.
# So, instead of having foo be {bar => "baz"} , it could be another TLV.
# It will be given the key bar.
sub new {
	my $pkg = shift;
	my $self = $pkg->TIEHASH(@_);
}


sub getorder {
	my $self = shift;
	return map { (unpack("n", $_))[0] } @{$self->{ORDER}};
}

sub setorder {
	my $self = shift;

	# Anything not specified gets shoved at the end
	my @end = grep { my $inbud = $_; not grep { $_ eq $inbud } @_ } @{$self->{ORDER}};

	@{$self->{ORDER}} = map { pack("n", 0+$_) } @_;
	push @{$self->{ORDER}}, @end;
}

sub TIEHASH {
	my $class = shift;
	my $self = { DATA => {}, ORDER => [], CURRKEY => -1, AUTOVIVIFY => shift};
	return bless $self, $class;
}

sub FETCH {
	my($self, $key) = @_;
	$self->{DATA}->{pack("n", 0+$key)};
}

sub STORE {
	my($self, $key, $value) = @_;
	my($normalkey) = pack("n", 0+$key);

	#print STDERR "Storing: ", Data::Dumper->Dump([$value], ["${self}->{$key}"]);
	if(!exists $self->{DATA}->{$normalkey}) {
		if(
			$self->{AUTOVIVIFY} and
			ref($value) eq "HASH" and
			!tied(%$value) and
			scalar keys %$value == 0
		) {
			#print STDERR "Autovivifying $key: $self->{AUTOVIVIFY}\n";
			eval $self->{AUTOVIVIFY};
			#print STDERR "New value: ", Data::Dumper->Dump([$self->{DATA}->{$normalkey}], ["${self}->{$key}"]);
		} else {
			#print STDERR "Not autovivifying $key.\n";
			#print STDERR "No autovivify.\n" unless $self->{AUTOVIVIFY};
			#printf STDERR "ref(\$value) eq %s\n", ref($value) unless ref($value) eq "HASH";
			#print STDERR "tied(\%\$value)\n" unless !tied(%$value);
			#printf STDERR "scalar keys \%\$value == %d\n", scalar keys %$value unless scalar keys %$value == 0;
		}
		push @{$self->{ORDER}}, $normalkey;
	} else {
		#print STDERR "Not autovivifying $key: already exists\n";
	}
	$self->{DATA}->{$normalkey} = $value;
	return $value;
}

sub DELETE {
	my($self, $key) = @_;
	my($packedkey) = pack("n", 0+$key);
	delete $self->{DATA}->{$packedkey};
	for(my $i = 0; $i < scalar @{$self->{ORDER}}; $i++) {
		next unless $packedkey eq $self->{ORDER}->[$i];
		splice(@{$self->{ORDER}}, $i, 1);

		# What if the user deletes a key while iterating?  We need to correct for the new index.
		if($self->{CURRKEY} != -1 and $i <= $self->{CURRKEY}) {
			$self->{CURRKEY}--;
		}

		last;
	}
}

sub CLEAR {
	my $self = shift;
	$self->{DATA} = {};
	$self->{ORDER} = [];
	$self->{CURRKEY} = -1;
	return $self;
}

sub EXISTS {
	my($self, $key) = @_;
	my($packedkey) = pack("n", 0+$key);
	return exists $self->{DATA}->{$packedkey};
}

sub FIRSTKEY {
	$_[0]->{CURRKEY} = -1;
	goto &NEXTKEY;
}

sub NEXTKEY {
	my ($self) = @_;

	my $currkey = ++$self->{CURRKEY};
	if($currkey >= scalar @{$self->{ORDER}}) {
		return wantarray ? () : undef;
	}

	my $packedkey = $self->{ORDER}->[$currkey];
	my($key) = unpack("n", $packedkey);
	return wantarray ? ($key, $self->{DATA}->{$packedkey}) : $key;
}


sub tlv(;@) {
	my %tlv = ();
	tie %tlv, "Net::OSCAR::TLV";
	while(@_) { my($key, $value) = (shift, shift); $tlv{$key} = $value; }
	return \%tlv;
}


1;
