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

use HTML::Entities;    # So we can encode characters like <>& etc

sub xml {
    my ( $request, $options ) = @_;
    my ( $xml, $xml_types, $xml_groups, $xml_categories, $xml_widgets,
        $xml_vars, $xml_objects );

    $request =
      'types,groups,categories,widgets,config_parms,weather,save,vars,objects'
      unless $request;
    my %request;
    foreach ( split ',', $request ) {
        my ( $k, undef, $v ) = /(\w+)(=([\w\|\$]+))?/;
        $request{$k}{active} = 1;
        $request{$k}{members} = [ split /\|/, $v ] if $k and $v;
    }

    my %options;
    foreach ( split ',', $options ) {
        my ( $k, undef, $v ) = /(\w+)(=([\w\|\_]+))?/;
        $options{$k}{active} = 1;
        $options{$k}{members} = [ split /\|/, $v ] if $k and $v;
    }

    my %fields;
    if ( exists $options{fields}{members} ) {
        foreach ( @{ $options{fields}{members} } ) {
            $fields{$_} = 1;
        }
    }

    # List objects by type
    if ( $request{types} ) {
        my ( $tmp_xml, $tmp_xml2 );
        for my $object_type ( sort @Object_Types ) {
            next
              if exists $request{types}{members}
                  and ( not grep { $_ eq $object_type }
                      @{ $request{types}{members} } );
            foreach ( sort &list_objects_by_type($object_type) ) {
                $_ = &get_object_by_name($_);
                $tmp_xml .= &object_detail( $_, %fields );
            }
            if ( $tmp_xml ) {
                $tmp_xml2 .= "\t\t<type>\n\t\t\t<name>$object_type</name>\n";
                $tmp_xml2 .= $tmp_xml;
                $tmp_xml2 .= "\t\t</type>\n";
            }
        }
        if ( $tmp_xml2 ) {
            $xml .= "\t<types>\n";
            $xml .= $tmp_xml2;
            $xml .= "\t</types>\n";
        }
    }

    # List objects by groups
    if ( $request{groups} ) {
        my ( $tmp_xml, $tmp_xml2 );
        for my $group ( sort &list_objects_by_type('Group') ) {
            next
              if exists $request{groups}{members}
                  and
                  ( not grep { $_ eq $group } @{ $request{groups}{members} } );
            my $group_object = &get_object_by_name($group);
            foreach ( list $group_object) {
                $tmp_xml .= &object_detail( $_, %fields );
            }
            if ( $tmp_xml ) {
                $tmp_xml2 .= "\t\t<group>\n\t\t\t<name>$group</name>\n";
                $tmp_xml2 .= $tmp_xml;
                $tmp_xml2 .= "\t\t</group>\n";
            }
        }
        if ( $tmp_xml2 ) {
            $xml .= "\t<groups>\n";
            $xml .= $tmp_xml2;
            $xml .= "\t</groups>\n";
        }
    }

    # List voice commands by category
    if ( $request{categories} ) {
        $xml .= "\t<categories>\n";
        for my $category ( &list_code_webnames('Voice_Cmd') ) {
            next if $category =~ /^none$/;
            next
              if exists $request{categories}{members}
                  and ( not grep { $_ eq $category }
                      @{ $request{categories}{members} } );
            $xml .= "\t\t<category>\n\t\t\t<name>$category</name>\n";
            foreach ( sort &list_objects_by_webname($category) ) {
                $_ = &get_object_by_name($_);
                $xml .= &object_detail( $_, %fields );
            }
            $xml .= "\t\t</category>\n";
        }
        $xml .= "\t</categories>\n";
    }

    # List objects
    if ( $request{objects} ) {
        my ( $tmp_xml, $tmp_xml2 );
        for my $object_type (@Object_Types) {
            if ( my @object_list = sort &list_objects_by_type($object_type) ) {
                foreach ( map { &get_object_by_name($_) } @object_list ) {
                    next if $_->{hidden};
                    $tmp_xml .= &object_detail( $_, %fields );
                }
            }
        }
        if ( $tmp_xml ) {
            $xml .= "\t<objects>\n";
            $xml .= $tmp_xml;
            $xml .= "\t</objects>\n";
        }
    }

    # List widgets
    if ( $request{widgets} ) {
        $xml .= "  <widgets>\n$xml_widgets\n  </widgets>\n";
    }

    # List Weather hash values
    if ( $request{weather} ) {
        my $tmp_xml;
        foreach my $key ( sort keys %Weather ) {
            next
              if exists $request{weather}{members}
                  and
                  ( not grep { $_ eq $key } @{ $request{weather}{members} } );
            my $tkey = $key;
            $tkey =~ s/ /_/g;
            $tkey =~ s/#//g;
            $tmp_xml .= "   <$tkey>" . $Weather{$key} . "</$tkey>\n";
        }
        if ( $tmp_xml ) {
            $xml .= "  <weather>\n";
            $xml .= $tmp_xml;
            $xml .= "  </weather>\n";
        }
    }

    # List config_parms hash values
    if ( $request{config_parms} ) {
        $xml .= "  <config_parms>\n";
        foreach my $key ( sort keys %config_parms ) {
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
    if ( $request{save} ) {
        $xml .= "<  save>\n";
        foreach my $key ( sort keys %Save ) {
            my $tkey = $key;
            $tkey =~ s/ /_/g;
            $tkey =~ s/#//g;
            $xml .= "   <$tkey>" . $Save{$key} . "</$tkey>\n";
        }
        $xml .= "  </save>\n";
    }

    # List Global vars
    if ( $request{vars} ) {
        $xml_vars .= &walk_var('%::', 2, '' );
        $xml .= "  <vars>\n$xml_vars  </vars>\n";
    }
    # Translate special characters
    $xml = encode_entities( $xml, "\200-\377&" );
    return &xml_page($xml);
}

sub walk_var {
    my ( $var, $indent, $xml_vars ) = @_;
    my ( @elements, $name, $e );
    no strict 'refs';
    $name = substr $var, 1;
    if ( $var =~ /^@/ ) {
        foreach my $key ( 0 .. @$name - 1 ) {
            print_log "v $var n $name k $key";
            push @elements, "$name\[$key\]";
        }
    }
    elsif ( $var =~ /^%/ ) {
        foreach my $key ( sort keys %$name ) {
            next unless $key =~ /^[[:print:]]+$/;
            if ( $var eq '%::' ) {
                next if $key =~ /::$/;
                next if $key eq 'Save';           # Covered elsewhere
                next if $key eq 'ENV';            # Covered elsewhere
                next if $key eq 'Weather';        # Covered elsewhere
                next if $key eq 'Http';           # Covered elsewhere
                last if $key eq 'END';
                next if $key eq 'Socket_Ports';
                $e = $key;
            }
            else {
                $e = "$name\{$key\}";
            }
            print_log "v $var n $name k $key e $e";
            push @elements, $e;
        }
    }
    else { 
        return;
    }
    foreach my $name ( @elements ) { 
        foreach my $slot ( qw( ARRAY HASH SCALAR ) ) {
            my $v = *{ $name }{$slot};
            next unless defined $v;
            $name = encode_entities( $name, "\200-\377&<>" );
            if ( $slot eq 'SCALAR' ) {
                my $value = $$v;
                next if ref $v eq 'REF' or $value =~ /HASH/
                  or ( ! defined $$v and *{ $name }{HASH} )
                  or ( ! defined $$v and *{ $name }{CODE} );
                $value = 'undef' unless defined $value;
                $value = "<!\[CDATA\[\n$value\n\]\]>" if $value =~ /[<>&]/;
                for ( my $i = $indent; $i--; $i > 0 ) { $xml_vars .= '  ' }
                $xml_vars .= "<var>\$$name=$value</var>\n";
            }
            elsif ( $slot eq 'ARRAY' ) {
                for ( my $i = $indent; $i--; $i > 0 ) { $xml_vars .= '  ' }
                $xml_vars .= "<var>\@$name\n";
                $xml_vars .= &walk_var( "\@$name", $indent + 1, $xml_vars );
                for ( my $i = $indent; $i--; $i > 0 ) { $xml_vars .= '  ' }
                $xml_vars .= "</var>\n";
            }
            elsif ( $slot eq 'HASH' ) {
                for ( my $i = $indent; $i--; $i > 0 ) { $xml_vars .= '  ' }
                $xml_vars .= "<var>\%$name\n";
                $xml_vars .= &walk_var( "\%$name", $indent + 1, $xml_vars );
                for ( my $i = $indent; $i--; $i > 0 ) { $xml_vars .= '  ' }
                $xml_vars .= "</var>\n";
            }
        }
    }
    return $xml_vars;
}

sub object_detail {
    my ( $object, %fields ) = @_;
    return if exists $fields{none} and $fields{none};
    return if $object->can('hidden') and $object->hidden;
    $fields{all} = 1 unless %fields;
    my $object_name = $object->{object_name};
    my $xml_objects = "\t\t\t<object>\n";
    $xml_objects .= "\t\t\t\t<name>$object_name</name>\n";
    my @f = qw(object_name filename category rf_id state set_by type
      states idle_time text html seconds_remaining level);
    foreach my $f (@f) {
        next unless $fields{all} or $fields{$f};
        my $value;
        my $method = $f;
        if ($object->can($method) or (($method = 'get_' . $method) and 
          $object->can($method))) {
            $value = $object->{$method};
            $value = encode_entities( $value, "\200-\377&<>" );
        }
        elsif (exists $object->{$f}) {
            $value = $object->{$f};
            $value = encode_entities( $value, "\200-\377&<>" );
        }
        elsif ($f eq 'html' and $object->can('get_type')) {
            $value = "<!\[CDATA\["
              . &html_item_state( $object, $object->{get_type} )
              . "\]\]>\n";
        }
        $xml_objects .= "\t\t\t\t<$f>$value</$f>\n";
    }
    $xml_objects .= "\t\t\t</object>\n";
    return $xml_objects;
}

sub xml_page {
    my ($xml) = @_;

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
