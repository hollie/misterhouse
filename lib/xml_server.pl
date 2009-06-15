use strict;

#---------------------------------------------------------------------------
#  Generate xml for mh objects, groups, categories, and variables 
#---------------------------------------------------------------------------


                                # This is bad because config_parms contains passwords 
#Password_Allow{'&xml'}          = 'anyone';

#$test_xml = new Voice_Cmd 'Run xml test [1,2,3]';
#&xml if said $test_xml;

# Called via the web server.  If no request, xml for all types is returned.  Examples:
#   http://localhost:8080/sub?xml
#   http://localhost:8080/sub?xml(vars)

use HTML::Entities; # So we can encode characters like <>& etc
 
sub xml {
    my ($request, $options) = @_;
    my ($xml, $xml_types, $xml_groups, $xml_categories, $xml_widgets, $xml_vars, $xml_objects);

    $request = 'types,groups,categories,widgets,config_parms,weather,save,vars,objects' unless $request;
    my %request = map {$_, 1} split ',', $request;
    
    my ($show_type,$show_group); 
    ($show_type) = $options =~ /type=(\w+)/;
    ($show_group) = $options =~ /group=([\$_\w]+)/;

                                # List objects by type
    if ($request{types}) {
        for my $object_type (@Object_Types) {
            if (my @members = sort &list_objects_by_type($object_type)) {
                $xml_types .= "<object_type>\n  <name> $object_type</name>\n";
                $xml_types .= "  <members>@members</members>\n";
                $xml_types .= "</object_type>\n";
            }
        }
        $xml .= "<object_types>\n$xml_types</object_types>\n";
    }

                                # List objects by groups
    if ($request{groups}) {
        for my $group (&list_objects_by_type('Group')) {
            my $object = &get_object_by_name($group);
            if (my @members = list $object) {
                @members = map{$_->{object_name}} @members;
                $xml_groups .= "<group>\n  <name>$group</name>\n";
                $xml_groups .= "  <members>@members</members>\n";
                $xml_groups .= "</group>\n";
            }
        }
        $xml .= "<groups>\n$xml_groups</groups>\n";
    }

                                # List objects by category
    if ($request{categories}){
        for my $category (&list_code_webnames) {
            if (my @members = &list_objects_by_webname($category)) {
                $xml_categories .= "<category>\n  <name>$category</name>\n";
                $xml_categories .= "  <members>@members</members>\n";
                $xml_categories .= "</category>\n";
            }
        }
        $xml .= "<categories>\n$xml_categories</categories>\n";
    }        

                                # List objects
    if ($request{objects}) {
        my ($group_object, @group_members);
        $group_object = &get_object_by_name($show_group) if $show_group;
        @group_members  = map{$_->{object_name}} list $group_object if $group_object;
        for my $object_type (@Object_Types) {
            next if $show_type and ($object_type ne $show_type);
            $xml_objects .= "  <object_type>\n    <name>$object_type</name>\n";
            if (my @object_list = sort &list_objects_by_type($object_type)) {
                for my $object (map{&get_object_by_name($_)} @object_list) {
                    next if $object->{hidden};
                    my $object_name = $object->{object_name};
&::print_log($object->{object_name}, @group_members);
                    next if $show_group and (not grep /^$object_name$/, @group_members);
                    $xml_objects .= "    <object>\n";
                    $xml_objects .= "      <name>$object_name</name>\n";
                    $xml_objects .= "      <file>$object->{filename}</file>\n";
                    $xml_objects .= "      <category>$object->{category}</category>\n";
                    my $state = encode_entities($object->{state}, "\200-\377&<>");
                    $xml_objects .= "      <state>$state</state>\n";
#                    $xml_objects .= "      <set_by>" . $object->get_set_by . "</set_by>\n" if defined &$object->get_set_by;
                    $xml_objects .= "      <type>$object->{get_type}</type>\n";
                    $xml_objects .= "      <states>@{$object->{states}}</states>\n" if $object->{states};
                    $xml_objects .= "      <text>$object->{text}</text>\n" if $object->{text};
                    $xml_objects .= "      <html><!\[CDATA\[\n" . &html_item_state($object, $object->{get_type}) . "\]\]>\n      
</html>\n";
                    if ($object_type eq 'Timer') {
                        $xml_objects .= "      <seconds_remaining>" . $object->seconds_remaining . "</seconds_remaining>\n";
                    }
                    $xml_objects .= "    </object>\n";
                }
            }
            $xml_objects .= "  </object_type>\n";
        }
        $xml .= "<objects>\n$xml_objects</objects>\n";
    }

                                # List widgets
    if ($request{widgets}) {
        $xml .= "  <widgets>\n$xml_widgets\n  </widgets>\n";
    }

                                # List Weather hash values 
    if ($request{weather}) {
        $xml .= "  <weather>\n";
        foreach my $key (sort keys %Weather) { 
            my $tkey = $key; 
            $tkey =~ s/ /_/g;
            $tkey =~ s/#//g;
            $xml .= "   <$tkey>" . $Weather{$key} . "</$tkey>\n";
        }
        $xml .= "  </weather>\n";
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
    
    $xml  = "<misterhouse>\n$xml</misterhouse>";
    return &xml_page($xml);
}

sub xml_page {
    my ($xml) = @_;

#<!DOCTYPE document SYSTEM "misterhouse.dtd">
#<?xml version="1.0" standalone="no" ?>
#<?xml-stylesheet type="text/xsl" href="simpletest.xsl"?>

    return <<eof;
HTTP/1.0 200 OK
Server: MisterHouse
Content-type: text/xml

<?xml version="1.0" encoding="utf-8" standalone="yes"?>
$xml

eof

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

return 1;           # Make require happy

#
# $Log: xml_server.pl,v $
# Revision 1.2  2004/09/25 20:01:20  winter
# *** empty log message ***
#
# Revision 1.1  2001/05/28 21:22:46  winter
# - 2.52 release
#
#
