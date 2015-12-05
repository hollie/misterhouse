use strict;

#---------------------------------------------------------------------------
#  Generate xml for mh objects, groups, categories, and variables
#---------------------------------------------------------------------------

# Called via the web server.  If no request, usage is returned.  Examples:
#   http://localhost:8080/sub?xml
#   http://localhost:8080/sub?xml(vars)
# You can also specify which objects, groups, categories, variables, etc to return (by default, all) Example:
#   http://me:8080/sub?xml(weather=TempIndoor|TempOutdoor)
# You can also specify which fields of objects are returned (by default, all) Example:
#   http://localhost:8080/sub?xml(groups=$All_Lights,fields=html)

# TODO
# add request types for speak, print, and error logs
# convert the xml_usage output from html to xml and modify the default.xsl
# add the truncate option to packages, vars, and other requests
# add more info to subs request

use HTML::Entities;    # So we can encode characters like <>& etc

sub xml {
    my ( $request, $options ) = @_;
    my ( $xml, $xml_types, $xml_groups, $xml_categories, $xml_vars,
        $xml_objects );

    return &xml_usage unless $request;

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

    print_log "xml: request=$request options=$options" if $Debug{xml};

    # List objects by type
    if ( $request{types} ) {
        $xml .= "  <types>\n";
        my @types;
        if ( $request{types}{members} and @{ $request{types}{members} } ) {
            @types = @{ $request{types}{members} };
        }
        else {
            @types = @Object_Types;
        }
        foreach my $type ( sort @types ) {
            print_log "xml: type $type" if $Debug{xml};
            $xml .= "    <type>\n      <name>$type</name>\n";
            unless ( $options{truncate} ) {
                $xml .= "      <objects>\n";
                foreach my $o ( sort &list_objects_by_type($type) ) {
                    $o = &get_object_by_name($o);
                    $xml .= &object_detail( $o, %fields );
                }
                $xml .= "      </objects>\n";
            }
            $xml .= "    </type>\n";
        }
        $xml .= "  </types>\n";
    }

    # List objects by groups
    if ( $request{groups} ) {
        $xml .= "  <groups>\n";
        my @groups;
        if ( $request{groups}{members} and @{ $request{groups}{members} } ) {
            @groups = @{ $request{groups}{members} };
        }
        else {
            @groups = &list_objects_by_type('Group');
        }
        foreach my $group ( sort @groups ) {
            print_log "xml: group $group" if $Debug{xml};
            my $group_object = &get_object_by_name($group);
            next unless $group_object;
            $xml .= "    <group>\n      <name>$group</name>\n";
            unless ( $options{truncate} ) {
                $xml .= "      <objects>\n";
                foreach my $object ( list $group_object) {
                    $xml .= &object_detail( $object, %fields );
                }
                $xml .= "      </objects>\n";
            }
            $xml .= "    </group>\n";
        }
        $xml .= "  </groups>\n";
    }

    # List voice commands by category
    if ( $request{categories} ) {
        $xml .= "  <categories>\n";
        my @categories;
        if ( $request{categories}{members}
            and @{ $request{categories}{members} } )
        {
            @categories = @{ $request{categories}{members} };
        }
        else {
            @categories = &list_code_webnames('Voice_Cmd');
        }
        for my $category ( sort @categories ) {
            print_log "xml: cat $category" if $Debug{xml};
            next if $category =~ /^none$/;
            $xml .= "    <category>\n      <name>$category</name>\n";
            unless ( $options{truncate} ) {
                $xml .= "      <objects>\n";
                foreach my $name ( sort &list_objects_by_webname($category) ) {
                    my ( $object, $type );
                    $object = &get_object_by_name($name);
                    $type   = ref $object;
                    print_log "xml: o $name t $type" if $Debug{xml};
                    next unless $type eq 'Voice_Cmd';
                    $xml .= &object_detail( $object, %fields );
                }
                $xml .= "      </objects>\n";
            }
            $xml .= "    </category>\n";
        }
        $xml .= "  </categories>\n";
    }

    # List objects
    if ( $request{objects} ) {
        $xml .= "  <objects>\n";
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
            $name = $o->get_object_name if $o->can("get_object_name");
            print_log "xml: object name=$name ref=" . ref $o if $Debug{xml};
            $xml .= &object_detail( $o, %fields );
        }
        $xml .= "  </objects>\n";
    }

    # List subroutines
    if ( $request{subs} ) {
        $xml .= "  <subs>\n    <vars>\n";
        if ( $request{subs}{members} and @{ $request{subs}{members} } ) {
            foreach my $member ( @{ $request{subs}{members} } ) {
                no strict 'refs';
                my $ref;
                eval "\$ref = \\$member";
                print_log "xml subs error: $@" if $@;
                $xml .= &walk_var( $ref, $member, 3, ('CODE') );
            }
        }
        else {
            my $ref = \%::;
            foreach my $key ( sort { lc $a cmp lc $b } keys %$ref ) {
                my $iref = ${$ref}{$key};
                $xml .= &walk_var( $iref, $key, 3, ('CODE') );
            }
        }
        $xml .= "    </vars>\n  </subs>\n";
    }

    # List packages
    if ( $request{packages} or $request{package} ) {
        $xml .= "  <packages>\n    <vars>\n";
        if ( $request{packages}{members} and @{ $request{packages}{members} } )
        {
            foreach my $member ( @{ $request{packages}{members} } ) {
                no strict 'refs';
                my ( $type, $base ) = $member =~ /^(.)(.*)/;
                my $ref;
                eval "\$ref = \\$member";
                print_log "xml packages error: $@" if $@;
                $xml .=
                  &walk_var( $ref, $member, 3, qw( SCALAR ARRAY HASH CODE ) );
            }
        }
        else {
            my $ref = \%::;
            foreach my $key ( sort { lc $a cmp lc $b } keys %$ref ) {
                next unless $key =~ /.+::$/;
                next if $key eq 'main::';
                my $iref = ${$ref}{$key};
                $xml .=
                  &walk_var( $iref, $key, 3, qw( SCALAR ARRAY HASH CODE ) );
            }
        }
        $xml .= "    </vars>\n  </packages>\n";
    }

    # List Global vars
    if ( $request{vars} or $request{var} ) {
        $xml .= "  <vars>\n";
        if (   ( $request{vars}{members} and @{ $request{vars}{members} } )
            or ( $request{var}{members} and @{ $request{var}{members} } ) )
        {
            foreach my $member ( @{ $request{vars}{members} },
                @{ $request{var}{members} } )
            {
                no strict 'refs';
                my ( $type, $name ) = $member =~ /^([\$\@\%\&])?(.+)/;
                my $ref;
                my $rtype = eval "ref \$$name if defined \$$name";
                print_log "xml: ref eval error = $@" if $@;

                #print_log "xml: $type $name $member $rtype";
                if ( $rtype and $type ) {
                    eval "\$ref = \\$type\{ \$$name \}";
                    $xml .= &walk_var( $ref, $name ) if $ref;
                }
                elsif ($type) {
                    eval "\$ref = \\$member";
                    $xml .= &walk_var( $ref, $name ) if $ref;
                }
                elsif ( $member =~ /.+::$/ ) {
                    eval "\$ref = \\\%$member";
                    $xml .=
                      &walk_var( $ref, $name, 2, qw( SCALAR ARRAY HASH CODE ) )
                      if $ref;
                }
                else {
                    eval "\$ref = $member";
                    $xml .= &walk_var( $ref, $name ) if $ref;
                }
                print_log "xml: assignment eval error = $@" if $@;
            }
        }
        else {
            my $ref = \%::;
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
                $xml .= &walk_var( $iref, $key );
            }
        }
        $xml .= "  </vars>\n";
    }

    # List print_log phrases
    if ( $request{print_log} ) {
        $xml .= "  <print_log>\n";
        my $time = ::print_log_current_time();
        $xml .= "    <time>$time</time>\n";
        my @log;
        $xml .= "    <text>\n";
        if ( $options{time}{active} ) {
            @log = ::print_log_since( $options{time}{members}[0] );
        }
        else {
            @log = ::print_log_since();
        }
        my $value = \@log;
        $value = encode_entities( $value, "\200-\377&<>" );
        foreach (@$value) {
            $_ = 'undef' unless defined $_;
            $xml .= "      <value>$_</value>\n";
        }
        $xml .= "    </text>\n";
        $xml .= "  </print_log>\n";
    }

    # List speak phrases
    if ( $request{print_speaklog} ) {
        $xml .= "  <print_speaklog>\n";
        my $time = ::print_speaklog_current_time();
        $xml .= "    <time>$time</time>\n";
        my @log;
        $xml .= "    <text>\n";
        if ( $options{time}{active} ) {
            @log = ::print_speaklog_since( $options{time}{members}[0] );
        }
        else {
            @log = ::print_speaklog_since();
        }
        my $value = \@log;
        $value = encode_entities( $value, "\200-\377&<>" );
        foreach (@$value) {
            $_ = 'undef' unless defined $_;
            $xml .= "      <value>$_</value>\n";
        }
        $xml .= "    </text>\n";
        $xml .= "  </print_speaklog>\n";
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
        $xml .= "  <$req>\n    <vars>\n";
        if ( $request{$req}{members} and @{ $request{$req}{members} } ) {
            foreach my $member ( @{ $request{$req}{members} } ) {
                my $iref = \${$ref}{$hash}{$member};

                #$iref = \$iref unless ref $iref;
                $xml .= &walk_var( $iref, "$hash\{$member\}", 3 );
            }
        }
        else {
            $xml .= &walk_var( ${$ref}{$hash}, $hash, 3 );
        }
        $xml .= "    </vars>\n  </$req>\n";
    }

    # Translate special characters
    $xml = encode_entities( $xml, "\200-\377&" );
    $options{xsl}{members}[0] = ''
      if exists $options{xsl}
      and not defined $options{xsl}{members}[0];
    return &xml_page( $xml, $options{xsl}{members}[0] );
}

sub walk_var {
    my ( $ref, $name, $indent, @types ) = @_;
    my ( $xml_vars, $iname, $iref );
    @types = qw( ARRAY HASH SCALAR ) unless @types;
    $indent = 2 unless defined $indent;
    my $type  = ref $ref;
    my $rtype = ref \$ref;
    $ref = "$type", $ref = \$ref, $type = 'SCALAR' if $type =~ /\:\:/;
    print_log "xml: r $ref n $name t $type rt $rtype" if $Debug{xml};
    return if $type eq 'REF';

    if ( $type eq 'GLOB' or $rtype eq 'GLOB' ) {
        foreach my $slot (@types) {
            my $iref = *{$ref}{$slot};
            next unless $iref;
            unless ($slot eq 'SCALAR'
                and not defined $$iref
                and ( *{$ref}{ARRAY} or *{$ref}{CODE} or *{$ref}{HASH} ) )
            {
                $xml_vars .= &walk_var( $iref, $name, $indent, @types );
            }
        }
        return $xml_vars;
    }

    my ( $iref, $iname );
    for ( my $i = $indent; $i--; $i > 0 ) { $xml_vars .= '  ' }
    $xml_vars .= "<var>\n";
    for ( my $i = $indent + 1; $i--; $i > 0 ) { $xml_vars .= '  ' }
    $name = encode_entities($name);

    if ( $type eq '' ) {
        my $value = $ref;
        $value = 'undef' unless defined $value;
        $value = encode_entities($value);
        $xml_vars .= "<name>$name</name><value>$value</value>\n";
    }
    elsif ( $type eq 'SCALAR' ) {
        my $value = $$ref;
        $value = 'undef' unless defined $value;
        $value = encode_entities($value);
        $xml_vars .= "<name>\$$name</name><value>$value</value>\n";
    }
    elsif ( $name =~ /.::$/ ) {
        $xml_vars .= "<name>$name</name>\n";
        foreach my $key ( sort keys %$ref ) {
            $iname = "$name$key";
            $iref  = ${$ref}{$key};
            $iref  = \${$ref}{$key} unless ref $iref;
            $xml_vars .= &walk_var( $iref, $iname, $indent + 1, @types );
        }
    }
    elsif ( $type eq 'ARRAY' ) {
        $xml_vars .= "<name>\@$name</name>\n";
        foreach my $key ( 0 .. @$ref - 1 ) {
            $iname = "$name\[$key\]";
            $iref  = \${$ref}[$key];
            $iref  = ${$ref}[$key] if ref $iref eq 'REF';
            $xml_vars .= &walk_var( $iref, $iname, $indent + 1, @types );
        }
    }
    elsif ( $type eq 'HASH' ) {
        $xml_vars .= "<name>\%$name</name>\n";
        foreach my $key ( sort keys %$ref ) {
            $iname = "$name\{'$key'\}";
            $iref  = \${$ref}{$key};
            $iref  = ${$ref}{$key} if ref $iref eq 'REF';
            $xml_vars .= &walk_var( $iref, $iname, $indent + 1, @types );
        }
    }
    elsif ( $type eq 'CODE' ) {
        $xml_vars .= "<name>\&$name</name>\n";
    }

    for ( my $i = $indent; $i--; $i > 0 ) { $xml_vars .= '  ' }
    $xml_vars .= "</var>\n";

    return $xml_vars;
}

sub object_detail {
    my ( $object, %fields ) = @_;
    return if exists $fields{none} and $fields{none};
    my $ref = ref \$object;
    return unless $ref eq 'REF';
    return if $object->can('hidden') and $object->hidden;
    $fields{all} = 1 unless %fields;
    my $object_name = $object->{object_name};
    my $xml_objects = "        <object>\n";
    $xml_objects .= "          <name>$object_name</name>\n";
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
            print_log "xml: object_dets f $f m $method v $value" if $Debug{xml};
        }
        elsif ( exists $object->{$f} ) {
            $value = $object->{$f};
            $value = encode_entities( $value, "\200-\377&<>" );
            print_log "xml: object_dets f $f ev $value" if $Debug{xml};
        }
        elsif ( $f eq 'html' and $object->can('get_type') ) {
            $value = "<!\[CDATA\["
              . &html_item_state( $object, $object->get_type ) . "\]\]>";
            print_log "xml: object_dets f $f" if $Debug{xml};
        }
        else {
            print_log "xml: object_dets didn't find $f" if $Debug{xml};
        }
        if ( ref $value eq 'ARRAY' ) {
            $xml_objects .= "          <$f>\n";
            foreach (@$value) {
                $_ = 'undef' unless defined $_;
                $xml_objects .= "            <value>$_</value>\n";
            }
            $xml_objects .= "          </$f>\n";
        }
        else {
            $xml_objects .= "          <$f>$value</$f>\n" if defined $value;
        }
    }
    $xml_objects .= "        </object>\n";
    return $xml_objects;
}

sub xml_page {
    my ( $xml, $xsl ) = @_;

    $xsl = '/lib/default.xsl' unless defined $xsl;

    # handle blank xsl name
    my $style;
    $style = qq|<?xml-stylesheet type="text/xsl" href="$xsl"?>| if $xsl;
    return <<eof;
HTTP/1.0 200 OK
Server: MisterHouse
Content-type: text/xml

<?xml version="1.0" encoding="utf-8" standalone="yes"?>
$style
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

sub xml_usage {
    my $html = <<eof;
HTTP/1.0 200 OK
Server: MisterHouse
Content-type: text/html

<html>
<head>
</head>

<body>
eof
    my @requests = qw( types groups categories config_parms socket_ports
      user_code weather save objects photos subs menus triggers packages vars );

    my %options = (
        xsl => {
            applyto => 'all',
            example => '|/lib/xml2js.xslt',
        },
        fields => {
            applyto => 'types|groups|categories|objects',
            example => 'state|set_by',
        },
        truncate => { applyto => 'types|groups|categories', },
    );
    foreach my $r (@requests) {
        my $url = "/sub?xml($r)";
        $html .= "<h2>$r</h2>\n<p><a href='$url'>$url</a></p>\n<ul>\n";
        foreach my $opt ( sort keys %options ) {
            if ( $options{$opt}{applyto} eq 'all' or grep /^$r$/,
                split /\|/, $options{$opt}{applyto} )
            {
                $url = "/sub?xml($r,$opt";
                if ( defined $options{$opt}{example} ) {
                    foreach ( split /\|/, $options{$opt}{example} ) {
                        print_log "xml: r $r opt $opt ex $_" if $Debug{xml};
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

#
# $Log: xml_server.pl,v $
# Revision 1.2  2004/09/25 20:01:20  winter
# *** empty log message ***
#
# Revision 1.1  2001/05/28 21:22:46  winter
# - 2.52 release
#
#
