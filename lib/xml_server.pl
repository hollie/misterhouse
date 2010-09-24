use strict;

#---------------------------------------------------------------------------
#  Generate xml for mh objects, groups, categories, and variables 
#---------------------------------------------------------------------------


			# This is bad because config_parms contains passwords 
#Password_Allow{'&xml'}		  = 'anyone';

# Called via the web server.  If no request, xml for all types is returned.  Examples:
#   http://localhost:8080/sub?xml
#   http://localhost:8080/sub?xml(vars)
# You can also specify which objects, groups, categories, variables, etc to return (by default, all) Example: 
#   http://me:8080/sub?xml(weather=TempIndoor|TempOutdoor)
# You can also specify which fields of objects are returned (by default, all) Example: 
#   http://localhost:8080/sub?xml(groups=$All_Lights,fields=html)

# TODO 
# The = operator isn't supported on all data types 
# There should be a usage data type that gives clickable examples 
# There should be a way to override the default xsl file 

use HTML::Entities; # So we can encode characters like <>& etc

my ($updates_only, %prev_weather);

sub xml {		
	my ($request, $options) = @_;
	my ($xml, $xml_types, $xml_groups, $xml_categories, $xml_widgets, $xml_vars, $xml_objects);

	$request = 'types,groups,categories,widgets,config_parms,weather,save,vars,objects' unless $request;
	my %request;
	foreach (split ',', $request) {
		my ($k, undef, $v) = /(\w+)(=([\w\|\$]+))?/;
		$request{$k}{active} = 1;
		$request{$k}{members} = [ split /\|/, $v ] if $k and $v;
	}
	  
	my %options;
	foreach (split ',', $options) {
		my ($k, undef, $v) = /(\w+)(=([\w\|\_]+))?/;
		$options{$k}{active} = 1;
		$options{$k}{members} = [ split /\|/, $v ] if $k and $v;
	}

	$updates_only = 0;
	$updates_only = 1 if $options{updates_only};

	my %fields; 
	if (exists $options{fields}{members}) {
		foreach (@{ $options{fields}{members} }) {
			$fields{$_} = 1;
		}
	}

			# List objects by type
	if ($request{types}) {
		my ($tmp_xml, $tmp_xml2);
		for my $object_type (sort @Object_Types) {
			next if exists $request{types}{members} and (not grep {$_ eq $object_type} @{ $request{types}{members} });
			foreach (sort &list_objects_by_type($object_type)) {	
				$_ = &get_object_by_name($_);
				$tmp_xml .= &object_detail($_, $updates_only, %fields);
			}
			if (! $updates_only or $tmp_xml) {
				$tmp_xml2 .= "\t\t<type>\n\t\t\t<name>$object_type</name>\n";
				$tmp_xml2 .= $tmp_xml;
				$tmp_xml2 .= "\t\t</type>\n";
			}
		}
		if (! $updates_only or $tmp_xml2) {
			$xml .= "\t<types>\n";
			$xml .= $tmp_xml2;
			$xml .= "\t</types>\n";
		}
	}

			# List objects by groups
	if ($request{groups}) {
		my ($tmp_xml, $tmp_xml2);
		for my $group (sort &list_objects_by_type('Group')) {
			next if exists $request{groups}{members} and (not grep {$_ eq $group} @{ $request{groups}{members} });
			my $group_object = &get_object_by_name($group);
			foreach (list $group_object) {
				$tmp_xml .= &object_detail($_, $updates_only, %fields);
			}
			if (! $updates_only or $tmp_xml) {
				$tmp_xml2 .= "\t\t<group>\n\t\t\t<name>$group</name>\n";
				$tmp_xml2 .= $tmp_xml;
				$tmp_xml2 .= "\t\t</group>\n";
			}
		}
		if (! $updates_only or $tmp_xml2) {
			$xml .= "\t<groups>\n";
			$xml .= $tmp_xml2;
			$xml .= "\t</groups>\n";
		}
	}

			# List voice commands by category
	if ($request{categories}){
		$xml .= "\t<categories>\n";
		for my $category (&list_code_webnames('Voice_Cmd')) {
			next if $category =~ /^none$/;
			next if exists $request{categories}{members} and (not grep {$_ eq $category} @{ $request{categories}{members} });
			$xml .= "\t\t<category>\n\t\t\t<name>$category</name>\n";
			foreach (sort &list_objects_by_webname($category)) {
				$_ = &get_object_by_name($_);
				$xml .= &object_detail($_, $updates_only, %fields);
			}
			$xml .= "\t\t</category>\n";
		}
		$xml .= "\t</categories>\n";
	}		

			# List objects
	if ($request{objects}) {
		my ($tmp_xml, $tmp_xml2);
		for my $object_type (@Object_Types) {
			if (my @object_list = sort &list_objects_by_type($object_type)) {
				foreach (map{&get_object_by_name($_)} @object_list) {
					next if $_->{hidden};
					$tmp_xml .= &object_detail($_, $updates_only, %fields);
				}
			}
		}
		if (! $updates_only or $tmp_xml) {
			$xml .= "\t<objects>\n";
			$xml .= $tmp_xml;
			$xml .= "\t</objects>\n";
		}
	}

			# List widgets
	if ($request{widgets}) {
		$xml .= "  <widgets>\n$xml_widgets\n  </widgets>\n";
	}

			# List Weather hash values 
	if ($request{weather}) {
		my $tmp_xml;
		foreach my $key (sort keys %Weather) { 
			next if exists $request{weather}{members} and (not grep {$_ eq $key} @{ $request{weather}{members} });
			my $tkey = $key; 
			$tkey =~ s/ /_/g;
			$tkey =~ s/#//g;
			if (! $updates_only or ! exists $prev_weather{$key} or $prev_weather{$key} ne $Weather{$key}) {
				$tmp_xml .= "   <$tkey>" . $Weather{$key} . "</$tkey>\n";
				$prev_weather{$key} = $Weather{$key} if $updates_only;
			}
		}
		if (! $updates_only or $tmp_xml) {
			$xml .= "  <weather>\n";
			$xml .= $tmp_xml;
			$xml .= "  </weather>\n";
		}
	}

			# List config_parms hash values 
	if ($request{config_parms}) {
		$xml .= "  <config_parms>\n";
		foreach my $key (sort keys %config_parms) { 
			my $tkey = $key; 
			$tkey =~ s/ /_/g;
			$tkey =~ s/#//g; 
			my $value = $config_parms{$key};
			$value = "<!\[CDATA\[\n$value\n\]\]>" if $value =~ /[<>&]/;
			$xml .= "   <$tkey>$value</$tkey>\n";
		}
		$xml .= "  </config_parms>\n";
	}

			# List Save hash values 
	if ($request{save}) {
		$xml .= "<  save>\n";
		foreach my $key (sort keys %Save) {
			my $tkey = $key; 
			$tkey =~ s/ /_/g;
			$tkey =~ s/#//g;
			$xml .= "   <$tkey>" . $Save{$key} . "</$tkey>\n";
		}
		$xml .= "  </save>\n";
	}
			# List Global vars
	if ($request{vars}) {
		for my $key (sort keys %main::) {
			# Assume all the global vars we care about are $Ab... 
			next if $key !~ /^[A-Z][a-z]/ or $key =~ /\:/;
			next if $key eq 'Save'; # Covered elsewhere
			next if $key eq 'Weather'; # Covered elsewhere
			next if $key eq 'Socket_Ports';
			no strict 'refs';
			if (defined $$key) {
				my $value = $$key;
				next if $value =~ /HASH/; # Skip object pointers
				$value = "<!\[CDATA\[\n$value\n\]\]>" if $value =~ /[<>&]/;
				$xml_vars .= "  <var>\$$key==$value</var>\n";
			} 
			elsif (defined %{$key}) {
				for my $key2 (sort eval "keys \%$key") {
					my $value = eval "\$$key\{'$key2'\}\n";
					$value = "<!\[CDATA\[\n$value\n\]\]>" if $value =~ /[<>&]/;
					$xml_vars .= "  <var>\$$key\{$key2\}=$value</var>\n";
				}				
			}
		}
		$xml .= "  <vars>\n$xml_vars  </vars>\n";
		} 

			# Translate special characters
	$xml = encode_entities($xml, "\200-\377&");
#   $xml =~ s/\+/\%2B/g; # Use hex 2B = +, as + will be translated to blanks
	
	return &xml_page($xml);
}

sub item_watcher {
	my $item_list = shift; 
	my $field = shift; 

	my @items = split ',', $item_list; 
	my ($xml, $tmp_xml); 
	foreach (@items) {
		next unless my ($item, $state) = m/(.+)=(.*)/;
		my $object  = &get_object_by_name($item);
		if ($state ne $object->state) {
			$tmp_xml .= &object_detail($object, 0, state => 1, $field => 1);
		}

	}
	if ($tmp_xml) {
		$xml .= "\t<objects>\n$tmp_xml\t</objects>\n";
			# Translate special characters
		$xml = encode_entities($xml, "\200-\377&");
		$xml = &xml_page($xml);
	}
	return $xml; 
}

sub object_detail {
	my ($object, $updates_only, %fields) = @_;
	return if defined $fields{none} and $fields{none};
	$fields{all} = 1 unless %fields;
	return if ($updates_only and ! $object->{state_now});
	my $object_name = $object->{object_name};
	my $xml_objects  = "\t\t\t<object>\n";
	$xml_objects .= "\t\t\t\t<name>$object_name</name>\n";
	$xml_objects .= "\t\t\t\t<filename>$object->{filename}</filename>\n" 			if $fields{all} or $fields{filename};
	$xml_objects .= "\t\t\t\t<category>$object->{category}</category>\n"		
		if ($fields{all} or $fields{category})		and exists $object->{category};
	$xml_objects .= "\t\t\t\t<rf_id>$object->{rf_id}</rf_id>\n"		
		if ($fields{all} or $fields{rf_id})			and exists $object->{rf_id};
	my $state = encode_entities($object->{state}, "\200-\377&<>");
	$xml_objects .= "\t\t\t\t<state>$state</state>\n"					if $fields{all} or $fields{state};
	$xml_objects .= "\t\t\t\t<set_by>" . $object->get_set_by . "</set_by>\n"	
		if ($fields{all} or $fields{set_by})		and exists $object->{get_set_by};
	$xml_objects .= "\t\t\t\t<type>$object->{get_type}</type>\n"			if $fields{all} or $fields{type};
	$xml_objects .= "\t\t\t\t<states>$object->{get_states}}</states>\n"			if $fields{all} or $fields{states};
	$xml_objects .= "\t\t\t\t<idle_time>" . $object->get_idle_time . "</idle_time>\n"	
		if ($fields{all} or $fields{idle_time})		and exists $object->{get_idle_time};
	$xml_objects .= "\t\t\t\t<text>$object->{text}</text>\n"				if $fields{all} or $fields{text};
	$xml_objects .= "\t\t\t\t<html><!\[CDATA\[" . &html_item_state($object, $object->{get_type}) . "\]\]>\n\t\t\t\t</html>\n"
														if $fields{all} or $fields{html};

	my @alt_fields = qw(seconds_remaining level);
	foreach my $field (@alt_fields) {
		next unless $fields{all} or $fields{$field};
		my $method = $field; 
		$method = 'get_' . $method unless exists $object->{$method};
		next unless exists $object->{$method};
		$xml_objects .= "\t\t\t\t<$field>$object->{$method}</$field>\n";
	}
	$xml_objects .= "\t\t\t</object>\n";
	return $xml_objects; 
}

sub xml_page {
	my ($xml) = @_;
	return if ($updates_only and ! $xml);

	return <<eof;
HTTP/1.0 200 OK
Server: MisterHouse
Content-type: text/xml

<?xml version="1.0" encoding="utf-8" standalone="yes"?>
<?xml-stylesheet type="text/xsl" href="/lib/default.xsl"?>
<misterhouse>
$xml</misterhouse>

eof

}

sub xml_entities_encode { 
	my $s = shift; 
	$s =~ s/\&/&amp;/g;
	$s =~ s/\</&lt;/g;
	$s =~ s/\>/&gt;/g;
	$s =~ s/\'/&apos;/g;
	$s =~ s/\"/&quot;/g;
	return $s;
}

sub svg_page {
	my ($svg) = @_;
	return <<eof;
HTTP/1.0 200 OK
Server: Homegrow
Content-type: image/svg+xml

$svg
eof

}

return 1;		   # Make require happy

#
# $Log: xml_server.pl,v $
# Revision 1.2  2004/09/25 20:01:20  winter
# *** empty log message ***
#
# Revision 1.1  2001/05/28 21:22:46  winter
# - 2.52 release
#
#
