
# Lists groups, using custom icons if we have them

# Authority: anyone

my ( $html, $count );
for my $group ( sort &list_objects_by_type('Group') ) {

    my $h    = "<td align='middle'>";
    my $name = &pretty_object_name($group);

    # No need to list empty groups
    my $object = &get_object_by_name($group);
    if ( $object and $object->can('list') ) {
        next unless grep !$$_{hidden}, list $object;
    }

    # Use custom icons if they exist, else GD if installed, else simply text $name
    my $link   = $name;
    my $group2 = lc $group;
    $group2 =~ s/[ _\$]//g;
    my $image = "/graphics/group-$group2.gif";
    if ( &http_get_local_file($image) ) {
        $link = qq|<img src="$image" alt='$name' border="0">|;
    }
    elsif ( $Info{module_GD} ) {
        $link = qq|<img src="/bin/button.pl?$name" alt='$name' border="0">|;
    }

    my $href = "list?group=$group";
    $href = "/bin/list_buttons.pl?$group" if $Info{module_GD};
    $h    .= qq[<a href='$href'>$link</a>\n];
    $html .= $h . "</td>\n";
    $html .= "</tr><tr>\n" unless ++$count % 3;
}

#html = "<html><body>\n<base target ='output'>\n" .
$html = "<html><body>\n" . &html_header('Browse Groups') . "
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
