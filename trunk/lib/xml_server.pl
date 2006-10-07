use strict;

#---------------------------------------------------------------------------
#  Generate xml for mh objects
#---------------------------------------------------------------------------

#Password_Allow{'&xml'}          = 'anyone';

#$test_xml = new Voice_Cmd 'Run xml test [1,2,3]';
#&xml if said $test_xml;

# Called via the web server.  If no request, xml for all types is returned.  Examples:
#   http://localhost:8080/sub?xml
#   http://localhost:8080/sub?xml(vars)

use HTML::Entities; # So we can encode characters like <>& etc
 
sub xml {
    my ($request) = @_;
    my ($xml, $xml_types, $xml_groups, $xml_categories, $xml_widgets, $xml_vars, $xml_objects);

    $request = 'types,groups,categories,widgets,vars,objects' unless $request;
    my %request = map {$_, 1} split ',', $request;
    

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
        for my $object_type (@Object_Types) {
#           $xml_objects .= "<object_type>\n  <name> $object_type</name>\n";
            if (my @object_list = sort &list_objects_by_type($object_type)) {
                for my $object (map{&get_object_by_name($_)} @object_list) {
                    next if $object->{hidden};
                    $xml_objects .= "<object>";
                    $xml_objects .= "  <name>$object->{object_name}</name>";
                    $xml_objects .= "  <file>$object->{filename}</file>";
                    $xml_objects .= "  <category>$object->{category}</category>";
                    my $state = encode_entities($object->{state}, "\200-\377&<>");
                    $xml_objects .= "  <state>$state</state>";
                    $xml_objects .= "  <states>@{$object->{states}}</states>" if $object->{states};
                    $xml_objects .= "  <text>$object->{text}</text>" if $object->{text};
                    $xml_objects .= "</object>\n";
                }
            }
#           $xml_objects .= "</object_type>\n";
        }
        $xml .= "<objects>\n$xml_objects</objects>\n";
    }

                                # List widgets
    if ($request{widgets}) {
        $xml .= "<widgets>\n$xml_widgets</widgets>\n";
    }

                                # List Save vars
    if ($request{vars}) {
        for my $key (sort keys %Save) {
            my $value = ($Save{$key}) ? $Save{$key} : '';
            $xml_vars .= "<var>\$Save{$key}=$value</var>\n";
        }

                                # List Global vars
        for my $key (sort keys %main::) {
                                # Assume all the global vars we care about are $Ab... 
            next if $key !~ /^[A-Z][a-z]/ or $key =~ /\:/;
            next if $key eq 'Save'; # Covered elsewhere
            next if $key eq 'Socket_Ports';
            no strict 'refs';
            if (defined $$key) {
                my $value = $$key;
                next if $value =~ /HASH/; # Skip object pointers
                $xml_vars .= "<var>\$$key==$value</var>\n";
            } 
            elsif (defined %{$key}) {
                for my $key2 (sort eval "keys \%$key") {
                    my $value = eval "\$$key\{'$key2'\}\n";
                    $xml_vars .= "<var>\$$key\{$key2\}=$value</var>\n";
                }
            }
        }
        $xml .= "<vars>\n$xml_vars</vars>\n";
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

    return <<eof;
HTTP/1.0 200 OK
Server: MisterHouse
Content-type: text/xml

<?xml version="1.0" ?>
<?xml-stylesheet type="text/xsl" href="simpletest.xsl"?>
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
