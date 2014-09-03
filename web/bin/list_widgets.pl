
# Lists widgets and variables, using custom icons if we have them

# Authority: anyone

my ( $html, $count );

for my $type (
    'Widgets',          'Widgets_Label',
    'Widgets_Entry',    'Widgets_RadioButton',
    'Widgets_Checkbox', 'Vars_Global',
    'Vars_Save'
  )
{
    # Look for custom icon
    my $type2 = lc $type;
    $type2 =~ s/[: _\$]//g;
    my $h = "<td align='middle'>";

    # Use custom icons if they exist
    my $image = "/graphics/widget-$type2.gif";
    my $url   = lc $type;
    if ( &http_get_local_file($image) ) {
        $h .= qq[<a href=$url><img src="$image" alt='$type' border="0"></a>\n];
    }

    # Create buttons with GD module if available
    elsif ( $Info{module_GD} ) {
        my $name = &pretty_object_name($type);
        $h .=
          qq[<a href=$url><img src="/bin/button.pl?$name" alt='$name' border="0"></a>\n];
    }

    # Otherwise use text
    else {
        $h .= &html_active_href( "/$url", &pretty_object_name($type) ) . "\n";
    }
    $html .= $h . "</td>\n";
    $html .= "</tr><tr>\n" unless ++$count % 3;
}

#$html = "<html><body>\n<base target ='output'>\n" .
$html = "<html><body>\n" . &html_header('Browse Widgets and Variables') . "
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
