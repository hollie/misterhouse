
# Lists items, using custom icons if we have them

# Authority: anyone

my ( $html, $count );

for my $object_type (@Object_Types) {
    next if $object_type eq 'Voice_Cmd';    # Already covered under Category
                                            # Look for custom icon
    my $object_type2 = lc $object_type;
    $object_type2 =~ s/[: _\$]//g;
    my $h = "<td align='middle'>";

    # Use custom icons if they exist
    my $image = "/graphics/item-$object_type2.gif";
    my $name  = &pretty_object_name($object_type);

    if ( &http_get_local_file($image) ) {
        $h .=
          qq[<a href=list?$object_type><img src="$image" alt='$name' border="0"></a>\n];
    }

    # Create buttons with GD module if available
    elsif ( $Info{module_GD} ) {

        #        $name =~ s/ /%20/g;
        $h .=
          qq[<a href=list?$object_type><img src="/bin/button.pl?$name" alt='$name' border="0"></a>\n];
    }

    # Otherwise use text
    else {
        $h .=
          &html_active_href( "list?$object_type",
            &pretty_object_name($object_type) )
          . "\n";
    }
    $html .= $h . "</td>\n";
    $html .= "</tr><tr>\n" unless ++$count % 3;
}

#$html = "<html><body>\n<base target ='output'>\n" .
$html = "<html><body>\n" . &html_header('Browse Items') . "
<table width='100%' border='0'>
<center>
 <table cellSpacing=4 cellPadding=0 width='100%' border=0>  
<tr>$html</tr>
</table>
</center>
</table>
</body>
</html>";

return &html_page( '', $html );
