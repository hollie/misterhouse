
sub menu_frame {

    my $menu_group = shift @_;
    $menu_group = 'default' unless $menu_group;
    my $menu1 = $Menus{$menu_group}{menu_list}[0];
    my $menu2 = ${ $Menus{$menu_group}{$menu1}{items}[0] }{goto};
    my $menu3 = ${ $Menus{$menu_group}{$menu2}{items}[0] }{goto};
    $menu1 =~ s/ /%20/g;
    $menu2 =~ s/ /%20/g;
    $menu3 =~ s/ /%20/g;

    return "
<head><title>MrHouse Menu</title>
<meta name='robots' content='noindex, nofollow'>
<meta http-equiv='Refresh' content='600;url=/misc/photos.html'>
</head>
<frameset rows='*,100' framespacing=0 border=1>
 <frameset cols='*,*,*' framespacing=0 border=1>
  <frame src='/bin/menu.pl?list&$menu_group&$menu1&menu1' name='menu1' >
  <frame src='/bin/menu.pl?list&$menu_group&$menu2&menu2' name='menu2' >
  <frame src='/bin/menu.pl?list&$menu_group&$menu3&menu3' name='menu3' >
 </frameset>
 <frame src='speech'  name='speech' >
</frameset>
";
}

sub menu_list {
    my ( $menu_group, $menu, $frame ) = @_;
    $menu_group = 'default' unless $menu_group;
    $menu = $Menus{$menu_group}{menu_list}[0] unless $menu;

    my $target = $frame;
    $target++;
    $target = 'speech' if $target eq 'menu4';
    my $html = "<base target='$target'><table  width='100%'>\n";
    $html .=
      "<tr><td align='middle' bgColor='#cccccc'><font size='+3'>$menu</font></td></tr>\n";
    my $item = 0;
    my $ptr  = $Menus{$menu_group};
    for my $ptr2 ( @{ $$ptr{$menu}{items} } ) {
        my $html_item;
        my ( $href, $text );

        # Action item
        if ( $$ptr2{A} ) {

            # Multiple states
            if ( $$ptr2{Dstates} ) {
                $href   = "/bin/menu.pl?states&$menu_group&$menu&$item";
                $target = 'speech';
                $text   = $$ptr2{Dprefix};
                $text .= "...$$ptr2{Dsuffix}" if $$ptr2{Dsuffix};
            }

            # One state
            else {
                $href   = "/sub?menu_run($menu_group,$menu,$item,,h)";
                $target = 'speech';
                $text   = $$ptr2{D};
            }
        }
        elsif ( $$ptr2{R} ) {
            $href = "sub?menu_run($menu_group,$menu,$item,,h)";
            $text = $$ptr2{D};
        }

        # Menu item
        else {
            my $goto = $$ptr2{goto};
            print "dbx g=$goto.\n";
            next unless $goto;
            $href = "/bin/menu.pl?list&$menu_group&$goto&$target";
            $text = $goto;
        }
        $item++;

        #       $href =~ tr/ /_/;
        $href =~ s/ /%20/g;
        $text =~ s/ /%20/g;
        my $link = "<font size='+3'>$text</font>";
        if ( $Info{module_GD} ) {
            $link = "<img src='/bin/button.pl?$text' alt='$text' border='0'>";
        }
        $html .= "<tr><td align='middle' bgColor='#ffffff'>";
        $html .= "<a href='$href' target='$target'>$link</a></td></tr>\n";

    }
    $html .= "\n</table>";
    return $html;
}

sub menu_states {
    my ( $menu_group, $menu, $item ) = @_;
    my $ptr2 = $Menus{$menu_group}{$menu}{items}[$item];

    my $state = 0;
    my $html =
      "<table border=1 width='100%' height='100%'><tr><td>$$ptr2{Dprefix}</td>";
    for my $state_name ( @{ $$ptr2{Dstates} } ) {
        $html .=
          "<td><a href='/sub?menu_run($menu_group,$menu,$item,$state,h)' target='speech'>$state_name</a></td>\n";
        $state++;
    }
    $html .= "</table>";
    return $html;
}

my $func = shift;
my $html = '<html>';
if ( $func eq 'states' ) {
    $html = &menu_states(@ARGV);
}
elsif ( $func eq 'list' ) {
    $html = &menu_list(@ARGV);
}
else {
    $html = &menu_frame(@ARGV);
}

#return $html;
return &html_page( '', "<html>$html</html>" );

