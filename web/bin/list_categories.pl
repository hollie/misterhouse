
# Lists categories, using custom icons if we have them

# Authority: anyone

my ( $html, $count );
for my $category ( &list_code_webnames('Voice_Cmd') ) {
    next if $category =~ /^none$/;

    my $category2 = lc $category;
    $category2 =~ s/[ _\$]//g;
    my $h = "<td align='middle'>";

    # Use custom icons if they exist
    my $image = "/graphics/category-$category2.gif";
    if ( &http_get_local_file($image) ) {
        $h .=
          qq[<a href=list?$category><img src="$image" alt='$category2' border="0"></a>\n];
    }

    # Create buttons with GD module if available
    elsif ( $Info{module_GD} ) {
        my $name = &pretty_object_name($category);
        $h .=
          qq[<a href=list?$category><img src="/bin/button.pl?$name" alt='$name' border="0"></a>\n];
    }

    # Otherwise use text
    else {
        $h .=
          &html_active_href( "list?$category", &pretty_object_name($category) )
          . "\n";
    }
    $html .= $h . "</td>\n";
    $html .= "</tr><tr>\n" unless ++$count % 3;
}

$html = "<html><body>\n<base target ='output'>\n"
  . &html_header('Browse Categories') . "
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
