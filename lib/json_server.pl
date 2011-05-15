use strict;

#---------------------------------------------------------------------------
#  Generate json for mh objects, groups, categories, and variables
#---------------------------------------------------------------------------

# Called via the web server.  If no request, usage is returned.  Examples:
#   http://localhost:8080/sub?json
#   http://localhost:8080/sub?json(vars)
# You can also specify which objects, groups, categories, variables, etc to return (by default, all) Example:
#   http://me:8080/sub?json(weather=TempIndoor|TempOutdoor)
# You can also specify which fields of objects are returned (by default, all) Example:
#   http://localhost:8080/sub?json(groups=$All_Lights,fields=html)

# TODO
# add request types for speak, print, and error logs
# add the truncate option to packages, vars, and other requests
# add more info to subs request

use HTML::Entities;    # So we can encode characters like <>& etc
use JSON;

sub json {
	my ( $request, $options ) = @_;
	my ( %json, $json, $json_types, $json_groups, $json_categories, $json_vars,
		$json_objects );

	return &json_usage unless $request;

	my %request;
	foreach ( split ',', $request ) {
		my ( $k, undef, $v ) = /(\w+)(=(.+))?/;
		$request{$k}{active} = 1;
		$request{$k}{members} = [ split /\|/, $v ] if $k and $v;
	}

	my %options;
	foreach ( split ',', $options ) {
		my ( $k, undef, $v ) = /(\w+)(=(.+))?/;
		$options{$k}{active} = 1;
		$options{$k}{members} = [ split /\|/, $v ] if $k and $v;
	}

	my %fields;
	foreach ( @{ $options{fields}{members} } ) {
		$fields{$_} = 1;
	}

	print_log "json: request=$request options=$options" if $Debug{json};

	# List objects by type
	if ( $request{types} ) {
		my @types;
		my $name;
		if ( $request{types}{members} and @{ $request{types}{members} } ) {
			@types = @{ $request{types}{members} };
		}
		else {
			@types = @Object_Types;
		}
		foreach my $type ( sort @types ) {
			print_log "json: type $type" if $Debug{json};
			unless ( $options{truncate} ) {
				foreach my $object ( sort &list_objects_by_type($type) ) {
					$object = &get_object_by_name($object);
					$name   = $object->{object_name};
					$json{'types'}{$type}{$name} =
					  &json_object_detail( $object, %fields );
				}
			}
		}
	}

	# List objects by groups
	if ( $request{groups} ) {
		my @groups;
		my $name;
		if ( $request{groups}{members} and @{ $request{groups}{members} } ) {
			@groups = @{ $request{groups}{members} };
		}
		else {
			@groups = &list_objects_by_type('Group');
		}
		foreach my $group ( sort @groups ) {
			print_log "json: group $group" if $Debug{json};
			my $group_object = &get_object_by_name($group);
			next unless $group_object;
			unless ( $options{truncate} ) {
				foreach my $object ( list $group_object) {
					$name = $object->{object_name};
					$json{'groups'}{$group}{$name} =
					  &json_object_detail( $object, %fields );
				}
			}
		}
	}

	# List voice commands by category
	if ( $request{categories} ) {
		my @categories;
		my $name;
		if ( $request{categories}{members}
			and @{ $request{categories}{members} } )
		{
			@categories = @{ $request{categories}{members} };
		}
		else {
			@categories = &list_code_webnames('Voice_Cmd');
		}
		for my $category ( sort @categories ) {
			print_log "json: cat $category" if $Debug{json};
			next if $category =~ /^none$/;
			unless ( $options{truncate} ) {
				foreach my $name ( sort &list_objects_by_webname($category) ) {
					my ( $object, $type );
					$object = &get_object_by_name($name);
					$name   = $object->{object_name};
					$type   = ref $object;
					print_log "json: o $name t $type" if $Debug{json};
					next unless $type eq 'Voice_Cmd';
					$json{categories}{$category}{$name} =
					  &json_object_detail( $object, %fields );
				}
			}
		}
	}

	# List objects
	if ( $request{objects} ) {
		my @objects;
		if ( $request{objects}{members} and @{ $request{objects}{members} } ) {
			@objects = @{ $request{objects}{members} };
		}
		else {
			foreach my $object_type (@Object_Types) {
				push @objects, &list_objects_by_type($object_type);
			}
		}
		foreach my $o ( map { &get_object_by_name($_) } sort @objects ) {
			next unless $o;
			my $name = $o;
			$name = $o->{object_name};
			print_log "json: object name=$name ref=" . ref $o if $Debug{json};
			$json{objects}{$name} = &json_object_detail( $o, %fields );
		}
	}

	# List subroutines
	if ( $request{subs} ) {
		my $name;
		if ( $request{subs}{members} and @{ $request{subs}{members} } ) {
			foreach my $member ( @{ $request{subs}{members} } ) {
				no strict 'refs';
				my $ref;
				eval "\$ref = \\$member";
				print_log "json subs error: $@" if $@;
				$json{subs}{$member} = &json_walk_var( $ref, $member, ('CODE') );
				print_log Dumper(%json) if $Debug{json};
			}
		}
		else {
			my $ref = \%::;
			foreach my $key ( sort { lc $a cmp lc $b } keys %$ref ) {
				my $iref = ${$ref}{$key};
				$json{subs}{$key} = &json_walk_var( $iref, $key, ('CODE') );
			}
		}
	}

	# List packages
	if ( $request{packages} or $request{package} ) {
		if ( $request{packages}{members} and @{ $request{packages}{members} } )
		{
			foreach my $member ( @{ $request{packages}{members} } ) {
				no strict 'refs';
				my ( $type, $base ) = $member =~ /^(.)(.*)/;
				my $ref;
				eval "\$ref = \\$member";
				print_log "json packages error: $@" if $@;
				$json{packages}{$member} =
				  &json_walk_var( $ref, $member, qw( SCALAR ARRAY HASH CODE ) );
			}
		}
		else {
			my $ref = \%::;
			foreach my $key ( sort { lc $a cmp lc $b } keys %$ref ) {
				next unless $key =~ /.+::$/;
				next if $key eq 'main::';
				my $iref = ${$ref}{$key};
				my ($k, $r) = &json_walk_var( $iref, $key, qw( SCALAR ARRAY HASH CODE ) );
				$json{packages}{$k} = $r if $k ne "";
			}
		}
	}

	# List Global vars
	if ( $request{vars} or $request{var} ) {
		if (   ( $request{vars}{members} and @{ $request{vars}{members} } )
			or ( $request{var}{members} and @{ $request{var}{members} } ) )
		{

			foreach my $member ( @{ $request{vars}{members} },
				@{ $request{var}{members} } )
			{
				no strict 'refs';
				my ( $type, $name ) = $member =~ /^([\$\@\%\&])?(.+)/;
				my $ref;
				my @types = ("\$","\@","\%", "\&");
				my $rtype;
				my $var;
				my $valid=0;
				foreach (@types){
					$type = $_;
					$var = $_ .$name;
					if (eval "defined $var"){
						$rtype = eval "ref $var";
						$member = $var;
						$valid=1;
						last;
					}
				}
				unless( $valid == 1 ){
					$json{vars}{$name} = "Undefined";
					$type=undef;
					$rtype=undef;
				}
				if ( $rtype and $type ) {
					eval "\$ref = \\$type\{ \$$name \}";
					$json{vars} = &json_walk_var( $ref, $name ) if $ref;
				}
				elsif ($type) {
					eval "\$ref = \\$member";
					my %res;
					if ($ref){
						 my ($k, $r) = &json_walk_var( $ref, $name );
						 $json{vars}{$k} = $r;
					}
				}
				elsif ( $member =~ /.+::$/ ) {
					eval "\$ref = \\\%$member";
					$json{vars} =
					  &json_walk_var( $ref, $name,
						qw( SCALAR ARRAY HASH CODE ) )
					  if $ref;
				}
				elsif ($valid == 1) {
					eval "\$ref = $member";
					$json{vars} = &json_walk_var( $ref, $name ) if $ref;
				}
				print_log "json: assignment eval error = $@" if $@;
			}
		}
		else {
			my $ref = \%::;
			my %json_vars;
			foreach my $key ( sort { lc $a cmp lc $b } keys %$ref ) {
				next unless $key =~ /^[[:print:]]+$/;
				next if $key =~ /::$/;
				next if $key =~ /^.$/;
				next if $key =~ /^__/;
				next if $key =~ /^_</;
				next if $key eq 'ARGV';
				next if $key eq 'CARP_NOT';
				next if $key eq 'ENV';
				next if $key eq 'INC';
				next if $key eq 'ISA';
				next if $key eq 'SIG';
				next if $key eq 'config_parms';    # Covered elsewhere
				next if $key eq 'Menus';           # Covered elsewhere
				next if $key eq 'photos';          # Covered elsewhere
				next if $key eq 'Save';            # Covered elsewhere
				next if $key eq 'Socket_Ports';    # Covered elsewhere
				next if $key eq 'triggers';        # Covered elsewhere
				next if $key eq 'User_Code';       # Covered elsewhere
				next if $key eq 'Weather';         # Covered elsewhere
				my $iref = ${$ref}{$key};

				# this is for constants
				$iref = $$iref if ref $iref eq 'SCALAR';
				%json_vars = ( %json_vars, &json_walk_var( $iref, $key ) );
			}
			$json{vars} = \%json_vars;
		}
	}

	# List hash values
	foreach my $hash (
		qw( config_parms Menus photos Save Socket_Ports triggers
		User_Code Weather )
	  )
	{
		my $req = lc $hash;
		my $ref = \%::;
		next unless $request{$req};
		if ( $request{$req}{members} and @{ $request{$req}{members} } ) {
			foreach my $member ( @{ $request{$req}{members} } ) {
				my $iref = \${$ref}{$hash}{$member};
				%json = &json_walk_var( $iref, "$hash\{$member\}" );
			}
		}
		else {
			%json = &json_walk_var( ${$ref}{$hash}, $hash );
		}
	}
	print_log Dumper(%json) if $Debug{json};
    $json = JSON->new->allow_nonref;
	# Translate special characters
	$json = $json->pretty->encode( \%json );
	return &json_page($json);
}

sub json_walk_var {
	my ( $ref, $name, @types ) = @_;
	my ( %json_vars, $iname, $iref );
	@types = qw( ARRAY HASH SCALAR ) unless @types;
	my $type  = ref $ref;
	my $rtype = ref \$ref;
	my $json_vars;
	$ref = "$type", $ref = \$ref, $type = 'SCALAR' if $type =~ /\:\:/;
	print_log "json: r $ref n $name t $type rt $rtype" if $Debug{json};
	return if $type eq 'REF';


	if ( $type eq 'GLOB' or $rtype eq 'GLOB' ) {
		foreach my $slot (@types) {
			my $iref = *{$ref}{$slot};
			next unless $iref;
			unless ($slot eq 'SCALAR'
				and not defined $$iref
				and ( *{$ref}{ARRAY} or *{$ref}{CODE} or *{$ref}{HASH} ) )
			{
					%json_vars = &json_walk_var( $iref, $name, @types );
			}
		}
		return %json_vars;
	}

	my ( $iref, $iname );
	$name = encode_entities($name);

	if ( $type eq '' ) {
		my $value = $ref;
		$value            = undef unless defined $value;
		return ( "$name", $value );
	}
	elsif ( $type eq 'SCALAR' ) {
		my $value = $$ref;
		$value                = undef unless defined $value;
		if ($name =~ m/::(.*?)$/){
			$name = $1;
		}
		if ($name =~ m/\[(\d+?)\]$/) {
			my $index = $1;
			return $index, $value;
		} elsif ($name =~ m/.*?\{'(.*?)'\}$/) {
			my $cls = $1;
			if ($cls =~ m/\}\{/){
				my @values = split('\'}{\'', $cls);
				foreach my $val (@values) {
					$value = "Unusable Object" if ref $value;
					return $val, $value;
				}
			} else {
				return "$cls", $value;
			}
		} else {
			return ( "$name", $value );
		}
	}
    elsif ( $name =~ /.::$/ ) {
        foreach my $key ( sort keys %$ref ) {
            $iname = "$name$key";
            $iref  = ${$ref}{$key};
            $iref  = \${$ref}{$key} unless ref $iref;
            my ($k, $r) = &json_walk_var( $iref, $iname, @types );
            $json_vars{$name} = $r if $k ne "";
        }
    }
    elsif ( $type eq 'ARRAY' ) {
        foreach my $key ( 0 .. @$ref - 1 ) {
            $iname = "$name\[$key\]";
            $iref  = \${$ref}[$key];
            $iref  = ${$ref}[$key] if ref $iref eq 'REF';
            my ($k, $r) = &json_walk_var( $iref, $iname, @types );
           	$json_vars{$name}{$k} = $r;
        }
    }
    elsif ( $type eq 'HASH' ) {
        foreach my $key ( sort keys %$ref ) {
            $iname = "$name\{'$key'\}";
            $iref  = \${$ref}{$key};
            $iref  = ${$ref}{$key} if ref $iref eq 'REF';
           	my ($k, $r) = &json_walk_var( $iref, $iname, @types );
           	$json_vars{$name}{$key} = $r;       	
        }
    }
	elsif ( $type eq 'CODE' ) {
	}
	print_log Dumper(%json_vars ) if $Debug{json};
	return %json_vars;
}

sub json_object_detail {
	my ( $object, %fields ) = @_;
	return if exists $fields{none} and $fields{none};
	my $ref = ref \$object;
	return unless $ref eq 'REF';
	return if $object->can('hidden') and $object->hidden;
	$fields{all} = 1 unless %fields;
	my $object_name = $object->{object_name};
	my %json_objects;
	my @f = qw( category filename measurement rf_id set_by
	  state states state_log type
	  idle_time text html seconds_remaining level);

	foreach my $f ( sort @f ) {
		next unless $fields{all} or $fields{$f};
		my $value;
		my $method = $f;
		if (
			$object->can($method)
			or ( ( $method = 'get_' . $method )
				and $object->can($method) )
		  )
		{
			if ( $f eq 'states' or $f eq 'state_log' ) {
				my @a = $object->$method;
				$value = \@a;
			}
			else {
				$value = $object->$method;
				$value = encode_entities( $value, "\200-\377&<>" );
			}
			print_log "json: object_dets f $f m $method v $value"
			  if $Debug{json};
		}
		elsif ( exists $object->{$f} ) {
			$value = $object->{$f};
			$value = encode_entities( $value, "\200-\377&<>" );
			print_log "json: object_dets f $f ev $value" if $Debug{json};
		}
		elsif ( $f eq 'html' and $object->can('get_type') ) {
			$value = "<!\[CDATA\["
			  . &html_item_state( $object, $object->get_type ) . "\]\]>";
			print_log "json: object_dets f $f" if $Debug{json};
		}
		else {
			print_log "json: object_dets didn't find $f" if $Debug{json};
		}
		if ( ref $value eq 'ARRAY' ) {
			my $i = 0;
			foreach (@$value) {
				$_ = 'No Value' unless defined $_;
				$json_objects{$f}{$i} = $_;
				$i = $i + 1;
			}
		}
		else {
			$json_objects{$f} = $value if defined $value;
		}
	}
	return \%json_objects;
}

sub json_page {
	my ($json) = @_;

	$json =~ s/\$|\%|\&|\@//g;
	return <<eof;
HTTP/1.0 200 OK
Server: MisterHouse
Content-type: application/json

$json
eof

}

sub json_entities_encode {
	my $s = shift;
	$s =~ s/\&/&amp;/g;
	$s =~ s/\</&lt;/g;
	$s =~ s/\>/&gt;/g;
	$s =~ s/\'/&apos;/g;
	$s =~ s/\"/&quot;/g;
	return $s;
}

sub json_usage {
	my $html = <<eof;
HTTP/1.0 200 OK
Server: MisterHouse
Content-type: text/html

<html>
<head>
</head>

<body>
<h2>JSON Server</h2>
eof
	my @requests = qw( types groups categories config_parms socket_ports
	  user_code weather save objects photos subs menus triggers packages vars );

	my %options = (
		fields => {
			applyto => 'types|groups|categories|objects',
		},
	);
	foreach my $r (@requests) {
		my $url = "/sub?json($r)";
		$html .= "<h2>$r</h2>\n<p><a href='$url'>$url</a></p>\n<ul>\n";
		foreach my $opt ( sort keys %options ) {
			if ( $options{$opt}{applyto} eq 'all' or grep /^$r$/,
				split /\|/, $options{$opt}{applyto} )
			{
				$url = "/sub?json($r,$opt";
				if ( defined $options{$opt}{example} ) {
					foreach ( split /\|/, $options{$opt}{example} ) {
						print_log "json: r $r opt $opt ex $_" if $Debug{json};
						$html .= "<li><a href='$url=$_)'>$url=$_)</a></li>\n";
					}
				}
				else {
					$html .= "<li><a href='$url)'>$url)</a></li>\n";
				}
			}
		}
		$html .= "</ul>\n";
	}
	$html .= <<eof;
</body>
</html>
eof

	return $html;
}

return 1;    # Make require happy
