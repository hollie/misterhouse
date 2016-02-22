
$^W = 0;    # Avoid redefined sub msgs

# Authority: anyone

# Setup up default options
my $menu_keys      = $config_parms{html_menu_keys} or 1;
my $menu_key_index = -1;
my $menu_buttons   = $Info{module_GD};

$menu_keys    = $Cookies{menu_keys}    if defined $Cookies{menu_keys};
$menu_buttons = $Cookies{menu_buttons} if defined $Cookies{menu_buttons};

# The menu_keys keyboard shortcut Javascript only works on
# IE and NS (does not work on Audrey or MSCE 3.0)
my $browser = $Http{'User-Agent'};
my $menu_keys_allowed = 1 if $browser eq 'MSIE' or $browser eq 'Netscape6';
$menu_keys = 0 unless $menu_keys_allowed;

# Generate and return the html
my ($html);
if (@ARGV) {
    my $menu_group = shift @ARGV;
    my $menus      = shift @ARGV;
    my $menu       = shift @ARGV;
    my $item       = shift @ARGV;

    # xy gets tacked on by http_server.pl, so might be in item slot
    my $xy = shift @ARGV;
    $xy = $item unless defined $item;
    my ( $x, $y ) = $xy =~ /(\d+)|(\d+)/;

    #   print "dbx1 m=$menu_group, m=$menus, m=$menu, i=$item, xy=$xy, x=$x\n";

    if ( !$menu_group or $menu_group eq 'Top' or $menus eq 'Top' ) {
        $html = &menu_list_top();
    }
    elsif ( $menu_group eq 'help' ) {
        $html = &menu_help;
    }
    else {
        $html = &menu_list( $menu_group, $menus, $menu, $item );
    }
}
else {
    # Set default startup based on browser ip
    # So we can have room dependent appliances
    my ( $menu_group, $menus );
    ( $menu_group, $menus ) =
      &get_menu_default( $Socket_Ports{http}{client_ip_address} );
    ( $menu_group, $menus ) = &get_menu_default('default') unless $menu_group;
    $menus .= "Top|$Menus{$menu_group}{_menu_list}[0]"
      if $menu_group and !$menus;
    $menu_group = "Top" unless $menu_group;
    $html = &menu_frame( $menu_group, $menus );
}

return &html_page( '', "<html>$html</body></html>" );

sub menu_frame {
    my ( $menu_group, $menus ) = @_;
    my $arg = "$menu_group" if $menu_group;
    $arg .= "&$menus" if $menus;
    return "
<head><title>MrHouse Menu</title>
<meta name='robots' content='noindex, nofollow'>
<meta http-equiv='Refresh' content='600;url=/misc/photos.html'>
</head>
<frameset rows='*,100' framespacing=0 border=0>
 <frame src='/bin/menu.pl?$arg' name='menu' >
 <frame src='speech'  name='speech' >
</frameset>
";
}

sub menu_help {
    my $html = qq[
<h3>Keyboard control</h3>
<ul>
<li>Use the 4 keys L through ENTER
<li>L -> Previous page
<li>; -> Previous button
<li>' -> Next button
<li>Enter -> Select current button
</ul>
<h3>Button (Text Link) color index</h3>
<ul>
<li> White  (Black) -> Goto that menu
<li> Blue   (Blue) -> Run that command
<li> Green  (Bold Green) -> Toggle item from On to Off
<li> Yellow (Yellow) -> Toggle item from Dim to Off
<li> Gray   (Italic Gray) -> Toggle item from Off to On
<li> Pink   (Red) -> Toggle item from Unknown to On
<li> On dimable buttons, the middle part of the button toggles, and the left/right parts dim/brighten

</ul>
<h3>Turn off webmute to disable browser wav files
];
    return $html;
}

# Top level will be a list of all menu groups
sub menu_list_top {
    my $html .= menu_button('Top') . "<hr>\n";
    for my $menu_group ( sort keys %Menus ) {
        next
          unless $Menus{$menu_group}{_menu_list}
          and @{ $Menus{$menu_group}{_menu_list} } > 0;    # Skip empty menus
        next if $menu_group eq 'menu_data';
        $html .= &menu_button( $menu_group, "/bin/menu.pl?$menu_group" );
        $html .= "&nbsp;&nbsp;&nbsp;&nbsp;" unless $menu_buttons;
    }
    $html .=
      'No menus defined.  Enable menu.pl in the <a href="/bin/code_select.pl">common code selector</a>'
      unless %Menus > 1;
    return &html_top . $html;
}

sub menu_list {
    my ( $menu_group, $menus, $menu_with_state, $item_with_state ) = @_;

    $menus = "Top|$Menus{$menu_group}{_menu_list}[0]" unless $menus;
    my @menus = split '\|', $menus;

    my $html;

    # Create an index of previous menus
    my $menus_prev1 = '';
    for my $menu_prev (@menus) {
        if ($menus_prev1) {
            $html .=
              ($menu_buttons)
              ? "<img src='/graphics/arrow1.gif'>\n"
              : "&nbsp;&nbsp;&nbsp;&nbsp;";
            $menus_prev1 .= '|';
        }
        $menus_prev1 .= $menu_prev;

        #       $html .= &menu_button($menu_prev, ($menu_prev eq $menus[-1]) ? '' : "/bin/menu.pl?$menu_group&$menus_prev1");
        $html .=
          &menu_button( $menu_prev, "/bin/menu.pl?$menu_group&$menus_prev1" );
    }
    $html .= "<hr>\n";

    #  $html .= "<tr><td align='middle' bgColor='#cccccc'><font size='+2'>$menu</font></td></tr>\n<tr><td>";

    # Now list all Items in the current menu
    my $item = 0;
    my $ptr  = $Menus{$menu_group};
    my $menu = pop @menus;

    #   print "dbx1 mg=$menu_group m=$menu p=$ptr\n";
    for my $ptr2 ( @{ $$ptr{$menu}{items} } ) {
        my ( $href, $text );
        my $target = '';

        # Action item
        if ( $$ptr2{A} ) {

            # Multiple states
            if ( $$ptr2{Dstates} ) {
                $href = "/bin/menu.pl?$menu_group&$menus&$menu&$item";
                $text = $$ptr2{Dprefix};
                $text .= "...$$ptr2{Dsuffix}" if $$ptr2{Dsuffix};
            }

            # One state
            else {
                $href   = "sub?menu_run($menu_group,$menu,$item,,h)";
                $text   = $$ptr2{D};
                $target = 'speech';
            }
        }

        # Response Item
        elsif ( $$ptr2{R} ) {
            $href   = "sub?menu_run($menu_group,$menu,$item,,h)";
            $text   = $$ptr2{D};
            $target = 'speech';
            $target = 'main' if $$ptr2{R} =~ /^href=/i;
        }

        # Menu item
        else {
            my $goto = $$ptr2{goto};
            next unless $goto;
            $href = "/bin/menu.pl?$menu_group&$menus|$goto";
            $text = $goto;
        }
        my $color =
          ( $target eq 'speech' or $target eq 'main' ) ? 'blue' : 'white';

        # Use an active button if 2 states and tied to an object
        my $states = @{ $$ptr2{Dstates} } if $$ptr2{Dstates};
        my $action = $$ptr2{A};

        if ( $states >= 1 and $action =~ /^ *set +(\$\S+)/ and eval "ref $1" ) {
            $html .=
              &menu_button2( $1, $text, $menu_group, $menus, $menu, $item );
        }
        else {
            $html .= &menu_button( $text, $href, $target, $color );
        }
        $html .= "&nbsp;&nbsp;&nbsp;&nbsp;" unless $menu_buttons;
        $item++;
    }

    #   $html .= "\n";
    $html .= "<hr>\n";
    $html .= &menu_states( $menu_group, $menu_with_state, $item_with_state )
      if $menu;
    return &html_top . $html;
}

sub menu_states {
    my ( $menu_group, $menu, $item ) = @_;
    my $ptr2 = $Menus{$menu_group}{$menu}{items}[$item];
    return unless $ptr2;
    my $buttons = ( @{ $$ptr2{Dstates} } > 4 ) ? 0 : 1;
    my $border = ( $buttons and $menu_buttons ) ? 0 : 1;

    #   my $html = "<hr><BASE TARGET='speech'>\n";
    my $html =
      "<table border=$border width='100%'><tr><td><b>$$ptr2{Dprefix}</b></td>";
    my $state = 0;
    for my $state_name ( @{ $$ptr2{Dstates} } ) {
        my $href = "sub?menu_run($menu_group,$menu,$item,$state,h)";
        $href =~ s/ /%20/g;
        if ($buttons) {
            $html .= "<td>"
              . &menu_button( $state_name, $href, 'speech', 'blue' )
              . "</td>\n";
        }
        else {
            $html .=
                "<td><a target='speech' href='$href'>$state_name "
              . &key_pointer
              . "</a></td>\n";
        }
        $state++;
    }
    $html .= "</table>";
    return $html;
}

sub menu_button {
    my ( $text, $href, $target, $color ) = @_;
    $color = 'white' unless $color;
    my $text2 = $text;
    if ($menu_buttons) {
        $text2 =~ s/ /%20/g;
        $text2 =~ s/\+/%2B/g;
    }
    $href =~ s/ /%20/g;
    $color = 'black' if $color eq 'white' and !$menu_buttons;
    my $link;
    if ($menu_buttons) {

        # This would give a direct image link, but not needed?  Caching works fine on cgi script
        #       $link = &html_file(undef, "../web/bin/button.pl", "$text&&text&&none&&$color&&1</b>", 1);
        $link = "/bin/button.pl?$text2&text&none&$color";
        $link = "<img src='$link' alt='$text' border='0'>";
    }
    else {
        #       $link  = "<img border=0 alt='ball' src=/graphics/ball1.gif>";
        $link .= "<font color='$color' size='+2'>$text</font>";
    }

    $link .= &key_pointer;
    $target = ($target) ? "target='$target'" : '';
    return "<a $target id=a$menu_key_index href='$href'>$link</a>\n" if $href;
    return $link;
}

# This is called for active toggle buttons
sub menu_button2 {
    my ( $object_name, $text, $menu_group, $menus, $menu, $item ) = @_;
    my $object = &get_object_by_name($object_name);
    my $state  = state $object;
    $state = state_level $object if $object->isa('X10_Item');

    my $text2 = $text;
    $text2 =~ s/ /%20/g;
    $text2 =~ s/\+/%2B/g;

    my ( $color, $link );
    $color = 'red';
    $color = 'pink' if $menu_buttons;
    $color = 'gray' if $state eq 'off';
    $color = 'green' if $state eq 'on';
    $color = 'yellow' if $state eq 'dim';

    #   $color = 'yellow' if $state eq 'dim' and $menu_buttons;

    if ($menu_buttons) {
        my $ismap = 'ISMAP';

        # This would give a direct image link, but not needed?  Caching works fine on cgi script
        #       $link = &html_file(undef, "../web/bin/button.pl", "$text&&text&&$state&&$color&&1</b>", 1);
        $link = "/bin/button.pl?$text2&text&$state&$color";
        $link = "<img src='$link' alt='$text' $ismap border='0'>";
    }
    else {
        $text = "<b>$text</b>" if $state eq 'on' or $state eq 'dim';
        $text = "<i>$text</i>" if $state eq 'off';

        #       $link  = "<img  border=0 alt='ball' src=/graphics/ball1.gif>";
        $link .= "<font color='$color' size='+2'>$text</font>";
    }

    $link .= &key_pointer;
    my $state_next = ( $state eq 'off' ) ? 'on' : 'off';

    #   my $href = "sub?menu_run($menu_group,$menu,$item,$state_next,hr,/bin/menu.pl?$menu_group&$menus)";
    # &button_action is in mh/code/common/html_functions.pl
    # Need the function form, not the .pl form, since the argument has ? and & in it
    my $href =
      "sub?button_action($object_name,$state_next,/bin/menu.pl?$menu_group&$menus)";
    $href =~ s/ /%20/g;
    return "<a id=a$menu_key_index href='$href'>$link</a>\n";
}

sub key_pointer {
    $menu_key_index++;
    return unless $menu_keys;
    return
      "<img style='Display:None' border=0 alt='pointer' Id=i$menu_key_index src=/graphics/pointer1.gif>";
}

sub html_top {

    # no-cache not needed?
    #   my $html = qq[<head><meta http-equiv="Cache-control" content="no-cache" forua="true"/></head>\n];
    my $html = "<head></head><body bgcolor='#ffffff'>\n";

    #   $html =~ s|<head>|<head><meta forua="true" http-equiv="Cache-Control" content="max-age=999"/>\n|;

    if ($menu_keys) {
        my $script = "<script src='/bin/menu_keys.js'></script>\n"
          . "<script>\nvar last_key = $menu_key_index;\n</script>\n";
        $html =~ s/<head>/<head>$script/;
        $html =~ s/body /body onload='load(); self.focus()' /;
    }

    $html .= "<table border=0 width='100%'><tr>\n";
    $html .= "<td align=left>"
      . &html_file( undef, '../web/bin/set_cookie.pl',
        'menu_keys&&<b>Keyboard Control</b>', 1 )
      . "</td>\n"
      if $menu_keys_allowed;
    $html .= "<td align=left>"
      . &html_file( undef, '../web/bin/set_cookie.pl',
        'menu_buttons&&<b>Buttons</b>', 1 )
      . "</td>\n";
    $html .= "<td align=left>"
      . &html_file( undef, '../web/bin/set_cookie.pl',
        'webmute&&<b>Webmute</b>&&&&/bin/menu.pl', 1 )
      . "</td>\n";
    $html .=
      "<td><a href=/bin/menu.pl?help><font size=+1>Help</font></a></td>\n";
    $html .= "</tr></table>\n";
    return $html;
}
