=head1 B<json_server>

=head2 SYNOPSIS

Called via the web server.  If no request, usage is returned.  Examples:

  http://localhost:8080/sub?json
  http://localhost:8080/sub?json(vars)

You can also specify which objects, groups, categories, variables, etc to return (by default, all) Example:

  http://me:8080/sub?json(weather=TempIndoor|TempOutdoor)

You can also specify which fields of objects are returned (by default, all) Example:

  http://localhost:8080/sub?json(groups=$All_Lights,fields=html)

=head2 DESCRIPTION

Generate json for mh objects, groups, categories, and variables

TODO

  add request types for speak, print, and error logs
  add the truncate option to packages, vars, and other requests
  add more info to subs request

=head2 INHERITS

B<NONE>

=head2 METHODS

=over

=item B<UnDoc>

=cut

use strict;

use HTML::Entities;    # So we can encode characters like <>& etc
use JSON;
use IO::Compress::Gzip qw(gzip);

sub json {
	my ( $method, $path, $args ) = @_;
	my ( %json, %json_data, $json_vars, $json_objects);
	my $output_time = ::get_tickcount();

	# Remove leading and trailing slashes
	$path =~ s/^\/|\/$//g;
	my @path = split ('/', $path);

	my %args;
	foreach ( split '&', $args ) {
		my ( $k, undef, $v ) = /(\w+)(=(.+))?/;
		$args{$k} = [ split /,/, $v ] ;
	}

	print_log "json: method= $method path=$path args=$args" if $Debug{json};

	# List known types
	if ($path[0] eq 'types' || $path[0] eq '') {
		my @types = @Object_Types;
		$json_data{'types'} = [];
		foreach my $type ( sort @types ) {
			print_log "json: type $type" if $Debug{json};
			push($json_data{'types'}, $type);
		}
	}

	# List known groups
	if ($path[0] eq 'groups' || $path[0] eq '') {
		my @groups = &list_objects_by_type('Group');
		$json_data{'groups'} = [];
		foreach my $group ( sort @groups ) {
			print_log "json: group $group" if $Debug{json};
			$group =~ s/\$|\%|\&|\@//g;
			push($json_data{'groups'}, $group);
		}
	}

	# List known categories
	if ($path[0] eq 'categories' || $path[0] eq '') {
		my @categories = &list_code_webnames('Voice_Cmd');
		$json_data{'categories'} = [];
		for my $category ( sort @categories ) {
			print_log "json: cat $category" if $Debug{json};
			push($json_data{'categories'}, $category);
		}
	}

	# List objects
	if ($path[0] eq 'objects' || $path[0] eq '') {
		# Group memberships are stored only as group->item associations
		# This converts that to items->groups 
		my $object_group = json_group_field();
		my @objects;
		foreach my $object_type (list_object_types()) {
			push @objects, &list_objects_by_type($object_type);
		}
		foreach my $o ( map { &get_object_by_name($_) } sort @objects ) {
			next unless $o;
			my $name = $o;
			$name = $o->{object_name};
			$name =~ s/\$|\%|\&|\@//g;
			print_log "json: object name=$name ref=" . ref $o if $Debug{json};
			if (my $data = &json_object_detail( $o, \%args, $object_group )){
				$json_data{objects}{$name} = $data;
			}
		}
	}

	# List subroutines
	if ($path[0] eq 'subs' || $path[0] eq '') {
		my $name;
		my $ref = \%::;
		foreach my $key ( sort { lc $a cmp lc $b } keys %$ref ) {
			my $iref = ${$ref}{$key};
			$json_data{subs}{$key} = &json_walk_var( $iref, $key, ('CODE') );
		}
	}

	# List packages
	if ($path[0] eq 'packages' || $path[0] eq '') {
		my $ref = \%::;
		foreach my $key ( sort { lc $a cmp lc $b } keys %$ref ) {
			next unless $key =~ /.+::$/;
			next if $key eq 'main::';
			my $iref = ${$ref}{$key};
			my ($k, $r) = &json_walk_var( $iref, $key, qw( SCALAR ARRAY HASH CODE ) );
			$json_data{packages}{$k} = $r if $k ne "";
		}

	}

	# List Global vars
	if ($path[0] eq 'vars' || $path[0] eq '') {
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
		$json_data{vars} = \%json_vars;
	}

	# List print_log phrases
	if ( $path[0] eq 'print_log' || $path[0] eq '' ) {
		my @log;
		my $name;
		my $time = $args{time}[0];
		if ($args{time} 
			&& int($time) < int(::print_log_current_time())){
			#Only return messages since time
			@log = ::print_log_since($time);
		} elsif (!$args{time}) {
			@log = ::print_log_since();
		}
		if (scalar(@log) > 0) {
			$json_data{'print_log'} = [];
			push($json_data{'print_log'}, @log);
		}
	}

	# List hash values
	foreach my $hash (
		qw( config_parms Menus photos Save Socket_Ports triggers
		User_Code Weather )
	  ){
	  	if ( $path[0] eq $hash || $path[0] eq '' ) {
			my $req = lc $hash;
			my $ref = \%::;
			$json_data{$hash} = {json_walk_var(${$ref}{$hash},$hash)}->{$hash};
	  	}
	}
	
	print_log Dumper(%json) if $Debug{json};
	if ((!$args{long_poll}) || %json){
		#Insert time, used to determine if things have changed
		$json{meta}{time} = $output_time;
		#Insert the query we were sent, for debugging and updating
		$json{meta}{request} = \@path;
		$json{meta}{options} =  \%args;		
		#Merge in appropriate Data and Data
		if (scalar(@path) > 0) {
			%json = %{json_get_sub_element(\@path, \%json_data, \%json)};
		}
		else {
			$json{data} = \%json_data;
		}
		
	    my $json_raw = JSON->new->allow_nonref;
		# Translate special characters
		$json_raw = $json_raw->pretty->encode( \%json );
		return &json_page($json_raw);
	}
	return;
}

sub json_get_sub_element {
	my ($element_ref, $json_ref, $out_ref, $error_path) = @_;
	$error_path = "/" unless $error_path;
	my $path = shift(@{$element_ref});
	$error_path .= $path . "/";
	if (ref $json_ref eq 'HASH' && exists $json_ref->{$path}){
		if (scalar(@{$element_ref}) > 0){
			return json_get_sub_element($element_ref, $json_ref->{$path}, $out_ref, $error_path);
		}
		else {
			#This is the end of the line
			$out_ref->{data} = $json_ref->{$path};
			return $out_ref;
		}
	}
	else {
		#Error this path is invalid
		$out_ref->{error} = {
			'msg' 		=> 'Path does not exist.',
			'detail' 	=> $error_path
		};
		return $out_ref;
	}
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
	my ( $object, $args, $object_group ) = @_;
	my %fields;
	foreach ( @{ $args->{fields} } ) {
		$fields{$_} = 1;
	}
	return if exists $fields{none} and $fields{none};
	my $ref = ref \$object;
	return unless $ref eq 'REF';
	return if $object->can('hidden') and $object->hidden;
	$fields{all} = 1 unless %fields;
	my $object_name = $object->{object_name};
	
	my $time = $args->{time}[0];
	if ($time > 0){
		if (!($object->can('get_idle_time'))){
			#Items that do not have an idle time do not get reported at all in updates
			return;
		}
		elsif ($object->get_idle_time eq ''){
			#Items that have NEVER been set to a state have a null idle time
			return;
		}
		elsif (int($time) >= (int(::get_tickcount) - ($object->get_idle_time*1000))) {
			#Should get_tickcount be replaced with output_time??
			#Object has not changed since time, so return undefined
			return;
		}
	}

	my %json_objects;
	my @f = qw( category filename measurement rf_id set_by
	  state states state_log type label sort_order
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
		$json_objects{$f} = $value if defined $value;
	}

	$json_objects{groups} = $object_group->{$object_name} if defined $object_group->{$object_name};
	return \%json_objects;
}

sub json_group_field {
	my %object_group;
	
	my @groups = &list_objects_by_type('Group');
	foreach my $group ( sort @groups ) {
		my $group_object = &get_object_by_name($group);
		foreach my $object ( 
			$group_object->list(undef, undef,1)
			) {
			my $name = $object->{object_name};
			$group =~ s/\$|\%|\&|\@//g;
			push (@{$object_group{$name}}, $group);
		}
	}
	
	return \%object_group;
}

sub json_page {
	my ($json_raw) = @_;
	my $json;
	gzip \$json_raw => \$json;

	return <<eof;
HTTP/1.0 200 OK
Server: MisterHouse
Content-type: application/json
Content-Encoding: gzip

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
	  user_code weather save objects photos subs menus triggers packages vars print_log);

	my %args = (
		fields => {
			applyto => 'types|groups|categories|objects',
		},
		time => {
			applyto => 'print_log',
		}
	);
	foreach my $r (@requests) {
		my $url = "/sub?json($r)";
		$html .= "<h2>$r</h2>\n<p><a href='$url'>$url</a></p>\n<ul>\n";
		foreach my $opt ( sort keys %args ) {
			if ( $args{$opt}{applyto} eq 'all' or grep /^$r$/,
				split /\|/, $args{$opt}{applyto} )
			{
				$url = "/sub?json($r,$opt";
				if ( defined $args{$opt}{example} ) {
					foreach ( split /\|/, $args{$opt}{example} ) {
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

