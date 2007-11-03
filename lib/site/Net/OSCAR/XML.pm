=pod

Net::OSCAR::XML -- XML functions for Net::OSCAR

We're doing the fancy-schmancy Protocol.xml stuff here, so I'll explain it here.

Protocol.xml contains a number of "OSCAR protocol elements".  One E<lt>defineE<gt> block
is one OSCAR protocol elemennt.

When the module is first loaded, Protocol.xml is parsed and two hashes are created,
one whose keys are the names the the elements and whose values are the contents
of the XML::Parser tree which represents the contents of those elements; the other
hash has a family/subtype tuple as a key and element names as a value.

To do something with an element, given its name, Net::OSCAR calls C<protoparse("element name")>.
This returns a C<Net::OSCAR::XML::Template> object, which has C<pack> and C<unpack> methods.
C<pack> takes a hash and returns a string of binary characters, and C<unpack> goes the
other way around.  The objects are cached, so C<protoparse> only has to do actual work once
for every protocol element.

=cut

package Net::OSCAR::XML;

$VERSION = '1.925';
$REVISION = '$Revision: 1.24 $';

use strict;
use vars qw(@ISA @EXPORT $VERSION);
use Carp;
use Data::Dumper;

use Net::OSCAR::TLV;
use Net::OSCAR::XML::Template;
our(%xmlmap, %xml_revmap, $PROTOPARSE_DEBUG, $NO_XML_CACHE);

require Exporter;
@ISA = qw(Exporter);
@EXPORT = qw(
	protoparse protobit_to_snac snac_to_protobit
);

$PROTOPARSE_DEBUG = 0;
$NO_XML_CACHE = 0;

sub _protopack($$;@);
sub _xmlnode_to_template($$);

sub load_xml(;$) {
	# Look for parsed-xml file
	if(!$NO_XML_CACHE) {
		foreach (@INC) {
			next unless -f "$_/Net/OSCAR/XML/Protocol.parsed-xml";

			open(XMLCACHE, "$_/Net/OSCAR/XML/Protocol.parsed-xml") or next;
			my $xmlcache = join("", <XMLCACHE>);
			close(XMLCACHE);

			my $xmlparse;
			eval $xmlcache or die "Coldn't load xml cache: $@\n";
			die $@ if $@;
			return parse_xml($xmlparse);
		}
	}

	eval {
		require XML::Parser;
	} or die "Couldn't load XML::Parser ($@)\n";
	die $@ if $@;

	my $xmlparser = new XML::Parser(Style => "Tree");

	my $xmlfile = "";
	if($_[0]) {
		$xmlfile = shift;
	} else {
		foreach (@INC) {
			next unless -f "$_/Net/OSCAR/XML/Protocol.xml";
			$xmlfile = "$_/Net/OSCAR/XML/Protocol.xml";
			last;
		}
		croak "Couldn't find Net/OSCAR/XML/Protocol.xml in search path: " . join(" ", @INC) unless $xmlfile;
	}

	open(XMLFILE, $xmlfile) or croak "Couldn't open $xmlfile: $!";
	my $xml = join("", <XMLFILE>);
	close XMLFILE;
	my $xmlparse = $xmlparser->parse($xml) or croak "Couldn't parse XML from $xmlfile: $@";

	parse_xml($xmlparse);
}

sub add_xml_data($) {
	my $xmlparse = shift;

	my @tags = @{$xmlparse->[1]}; # Get contents of <oscar>
	shift @tags;
	while(@tags) {
		my($name, $value);
		(undef, undef, $name, $value) = splice(@tags, 0, 4);
		next unless $name and $name eq "define";
	
		my %protobit = (xml => $value);
		my %attrs = %{$value->[0]};
		$protobit{$_} = $attrs{$_} foreach keys %attrs;
		$xml_revmap{$attrs{family}}->{$attrs{subtype}} = $attrs{name} if exists($attrs{family}) and exists($attrs{subtype});
		$xmlmap{$attrs{name}} = \%protobit;
	}
}

sub parse_xml($) {
	my $xmlparse = shift;

	%xmlmap = ();
	%xml_revmap = ();
	# We set the autovivification so that keys of xml_revmap are Net::OSCAR::TLV hashrefs.
	if(!tied(%xml_revmap)) {
		tie %xml_revmap, "Net::OSCAR::TLV", 'tie %$value, ref($self)';
	}

	add_xml_data($xmlparse);

	return 1;
}

sub _num_to_packlen($$) {
	my($type, $order) = @_;
	$order ||= "network";

	if($type eq "byte") {
		return ("C", 1);
	} elsif($type eq "word") {
		if($order eq "vax") {
			return ("v", 2);
		} else {
			return ("n", 2);
		}
	} elsif($type eq "dword") {
		if($order eq "vax") {
			return ("V", 4);
		} else {
			return ("N", 4);
		}
	}

	confess "Invalid num type: $type";
}

# Specification for OSCAR protocol template:
#	-Listref whose elements are hashrefs.
#	-Hashrefs have following keys:
#		type: "ref", "num", "data", or "tlvchain"
#		If type = "num":
#			packlet: Pack template letter (C, n, N, v, V)
#			len: Length of datum, in bytes
#			enum_byname: If this is an enum, map of names to values.
#			enum_byval: If this is an enum, map of values to names.
#		If type = "data":
#			Arbitrary data
#			If prefix isn't present, all available data will be gobbled.
#			len (optional): Size of datum, in bytes
#			null_terminated (optional): Data is terminated by a null (0x00) byte
#		If type = "ref":
#			name: Name of protocol bit to punt to
#		If type = "tlvchain":
#			subtyped: If true, this is a 'subtyped' TLV, as per Protocol.dtd.
#			prefix: If present, "count" or "length", and "packlet" and "len" will also be present.
#			items: Listref containing TLVs, hashrefs in format identical to these, with extra key 'num' (and 'subtype', for subtyped TLVs.)
#		value: If present, default value of this datum.
#		name: If present, name in parameter list that this datum gets.
#		count: If present, number of repetitions of this datum.  count==-1 represents
#			infinite.  If a count is present when unpacking, the data will be encapsulated in a listref.  If the user
#			wants to pass in multiple data when packing, they should do so via a listref.  Listref-encapsulated data with
#			too many elements for the 'count' will trigger an exception when packing.
#		prefix: If present, either "count" or "length", and indicates that datum has a prefix indicating its length.
#			prefix_packet, prefix_len: As per "num".
#
sub _xmlnode_to_template($$) {
	my($tag, $value) = @_;

	confess "Invalid value in xmlnode_to_template!" unless ref($value);
	my $attrs = shift @$value;

	my $datum = {};
	$datum->{name} = $attrs->{name} if $attrs->{name};
	$datum->{value} = "" if $attrs->{default_generate} and $attrs->{default_generate} ne "no";
	$datum->{value} = $value->[1] if @$value and $value->[1] =~ /\S/;

	$datum->{count} = $attrs->{count} if $attrs->{count};
	if($attrs->{count_prefix} || $attrs->{length_prefix}) {
		my($packlet, $len) = _num_to_packlen($attrs->{count_prefix} || $attrs->{length_prefix}, $attrs->{prefix_order});
		$datum->{prefix_packlet} = $packlet;
		$datum->{prefix_len} = $len;
		$datum->{prefix} = $attrs->{count_prefix} ? "count" : "length";
	}


	if($tag eq "ref") {
		$datum->{type} = "ref";
	} elsif($tag eq "byte" or $tag eq "word" or $tag eq "dword" or $tag eq "enum") {
		$datum->{type} = "num";

		my $enum = 0;
		if($tag eq "enum") {
			$tag = $attrs->{type};
			$enum = 1;
		}

		my($packlet, $len) = _num_to_packlen($tag, $attrs->{order});
		$datum->{packlet} = $packlet;
		$datum->{len} = $len;

		if($enum) {
			$datum->{enum_byname} = {};
			$datum->{enum_byval} = {};

			while(@$value) {
				my($subtag, $subval) = splice(@$value, 0, 2);
				next if $subtag eq "0";

				my $attrs = shift @$subval;
				my($name, $value, $default) = ($attrs->{name}, $attrs->{value}, $attrs->{default});
				$datum->{enum_byname}->{$name} = $value;
				$datum->{enum_byval}->{$value} = $name;
				$datum->{value} = $value if $default;
			}
		} else {
			$datum->{value} = $value->[1] if @$value;
		}
	} elsif($tag eq "data") {
		$datum->{type} = "data";
		$datum->{len} = $attrs->{length} if $attrs->{length};
		$datum->{pad} = $attrs->{pad} if exists($attrs->{pad});
		$datum->{null_terminated} = 1 if $attrs->{null_terminated} and $attrs->{null_terminated} eq "yes";

		while(@$value) {
			my($subtag, $subval) = splice(@$value, 0, 2);
			if($subtag eq "0") {
				$datum->{value} ||= $subval if $subval =~ /\S/;
				next;
			}

			my $item = _xmlnode_to_template($subtag, $subval);
			$datum->{items} ||= [];
			push @{$datum->{items}}, $item;
		}
	} elsif($tag eq "tlvchain") {
		$datum->{type} = "tlvchain";
		$datum->{len} = $attrs->{length} if $attrs->{length};
		$datum->{subtyped} = 1 if $attrs->{subtyped} and $attrs->{subtyped} eq "yes";

		my($subtag, $subval);

		while(@$value) {
			my($tlvtag, $tlvval) = splice(@$value, 0, 2);
			next if $tlvtag ne "tlv";
			my $tlvattrs = shift @$tlvval;

			my $item = {};
			$item->{type} = "data";
			$item->{name} = $tlvattrs->{name} if $tlvattrs->{name};
			$item->{num} = $tlvattrs->{type};
			$item->{subtype} = $tlvattrs->{subtype} if $tlvattrs->{subtype};
			$item->{count} = $tlvattrs->{count} if $tlvattrs->{count};
			$item->{value} = "" if $tlvattrs->{default_generate} and $tlvattrs->{default_generate} ne "no";
			$item->{items} = [];

			while(@$tlvval) {
				my($subtag, $subval) = splice(@$tlvval, 0, 2);
				next if $subtag eq "0";
				my $tlvitem = _xmlnode_to_template($subtag, $subval);

				push @{$item->{items}}, $tlvitem;
			}


			push @{$datum->{items}}, $item;
		}
	}

	return $datum;
}



our(%PROTOCACHE);
sub protoparse($$) {
	my ($oscar, $wanted) = @_;
	return $PROTOCACHE{$wanted}->set_oscar($oscar) if exists($PROTOCACHE{$wanted});

	my $xml = $xmlmap{$wanted}->{xml} or croak "Couldn't find requested protocol element '$wanted'.";

	confess "No oscar!" unless $oscar;

	my $attrs = shift @$xml;

	my @template = ();

	while(@$xml) {
		my $tag = shift @$xml;
		my $value = shift @$xml;
		next if $tag eq "0";
		push @template, _xmlnode_to_template($tag, $value);
	}

	return @template if $PROTOPARSE_DEBUG;	
	my $obj = Net::OSCAR::XML::Template->new(\@template);
	$PROTOCACHE{$wanted} = $obj;
	return $obj->set_oscar($oscar);
}



# Map a "protobit" (XML <define name="foo">) to SNAC (family => foo, subtype => bar)
sub protobit_to_snac($) {
	my $protobit = shift;
	confess "Unknown protobit $protobit" unless $xmlmap{$protobit};

	my %ret = %{$xmlmap{$protobit}};
	delete $ret{xml};
	return %ret;
}

# Map a SNAC (family => foo, subtype => bar) to "protobit" (XML <define name="foo">)
sub snac_to_protobit(%) {
	my(%snac) = @_;
	if($xml_revmap{$snac{family}} and $xml_revmap{$snac{family}}->{$snac{subtype}}) {
		return $xml_revmap{$snac{family}}->{$snac{subtype}};
	} elsif($xml_revmap{'-1'} and $xml_revmap{'-1'}->{$snac{subtype}}) {
		return $xml_revmap{'-1'}->{$snac{subtype}};
	} else {
		return undef;
	}
}

1;
