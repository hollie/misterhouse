
# Called from shtml files to list Items with big buttons.  For example:
#    <a href="/ia5/lights/list_items.pl?$Outside">

# Authority: anyone

my ($list_name) = @ARGV;

my ( $html, $i, @objects );

unless ( @objects = &list_objects_by_type($list_name) ) {

    # Check if it is a Group object
    my $object_name = $list_name;
    $object_name = '$' . $object_name unless $object_name =~ /^\$/;
    if ( my $object = &get_object_by_name($object_name) ) {
        @objects = list $object;
        @objects = map { $_->{object_name} } @objects;
    }
}

for my $item (@objects) {
    my $name   = &pretty_object_name($item);
    my $object = &get_object_by_name($item);
    next if $object->{hidden};
    my $state     = lc $$object{state};
    my $state_new = ( $state eq 'on' ) ? 'off' : 'on';
    my $icon      = $state;
    if ( $state =~ /[\+\-\d\%]+/ ) {
        $icon = 'dim';
    }
    elsif ( $state ne 'on' and $state ne 'off' ) {
        $icon = 'dim';    # Need a new icon here
    }
    $icon =
      "<a href='/SET;&referer(/bin/list_buttons2.pl|$list_name)?$item=$state_new'><img src='/graphics/button_$icon.gif' alt='$name $state' border=0></a>";

    $html .= "
  <td align='left'   width='12%'></td>
  <td align='right'  width='13%'>$icon</td>
  <td align='middle' width='20%' bgColor='#cccccc'><b>$name</b><br>
&nbsp<a href='SET;&html_state_log($item)'>Log</a></b></td>
";
    $html .= "</tr><tr>\n" unless ++$i % 2;
}

#$html = "<html><body>\n<base target ='output'>\n" .
$html = "<html><body>\n" . &html_header("Control $list_name") . "
<br>
<table width='100%' border='0'>
<center>
 <table cellSpacing=4 cellPadding=0 width='100%' border=0>  
$html
</table>
</center>
</table>
</body>
</html>";

return &html_page( '', $html );

