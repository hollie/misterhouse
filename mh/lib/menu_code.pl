use strict;

use vars qw(%Menus %lcd_data %lcd_keymap);

#---------------------------------------------------------------------------
#  menu_parse will parse the menu into %Menus
#---------------------------------------------------------------------------

sub menu_parse {
    my ($template, $menu_group) = @_;
    $menu_group = 'default' unless $menu_group;

    my (%menus, $menu, $index, %voice_cmd_list);
    $Menus{$menu_group} = \%menus;

                                # Find all the valid Voice_Cmd text
    for my $object (map {&get_object_by_name($_)} &list_objects_by_type('Voice_Cmd')) {
        $voice_cmd_list{$$object{text}} = $object;
    }


    my $menu_states_cnt = 'states0';
    for (split /\n/, $template) {
        my ($type, $data) = $_ =~ /^\s*(\S+)\:\s*(.+?)\s*$/;
        next if /^\s*\#/;       # Ignore comments
        $data =~ s/\s+\#.+//;   # Ignore comments
                                # Pull out 'start menu' records:  M: Lights 
        if ($type eq 'M') {
            $menu = $data;
            $index = -1;
            if ($menus{$menu}) {
                print "\nWarning, duplicate menu: $menu\n\n";
            }
            else {
                push @{$menus{menu_list}}, $menu;
            }
        }
                                # Pull out 'select,action,response' records:  A: Left bedroom light $state
        elsif ($type) {
            $index++ if $type eq 'D';
            $menus{$menu}{items}[$index]{$type} = $data;
#           print "db m=$menu i=$index type=$type d=$data.\n";
        }
        else {
            print "Menu parsing error: $_\n" unless /^\s*$/;
        }
                                # States can be found in item text and Action/Response records
        my ($prefix, $states, $suffix) = $data =~ /(.*)\[(.+)\](.*)/;
        if ($states) {
            $menus{$menu}{items}  [$index]{$type . 'prefix'}  = $prefix;
            $menus{$menu}{items}  [$index]{$type . 'suffix'}  = $suffix;
            @{$menus{$menu}{items}[$index]{$type . 'states'}} = split ',', $states;

                                # Create a states menu for each unique set of states
            if ($type eq 'D') {
                unless ($menus{menu_list_states}{$states}) {
                    $menus{menu_list_states}{$states} = ++$menu_states_cnt;
                    $menus{$menu_states_cnt}{states}  = $states;
                    push @{$menus{menu_list}}, $menu_states_cnt;
                    my $i = 0;
                    for my $state (split ',', $states) {
                        $menus{$menu_states_cnt}{items}[$i]{D}    = $state;
                        $menus{$menu_states_cnt}{items}[$i]{A}    = 'state_select';
                        $menus{$menu_states_cnt}{items}[$i]{goto} = 'prev';
                        $i++;
                    }
                }
                $menus{$menu}{items}[$index]{'Dstates_menu'} = $menu_states_cnt;
            }
        }            
    }
                                # Setup actions and goto for each state
    my %unused_menus = %menus;
    for $menu (@{$menus{menu_list}}) {
        for my $ptr (@{$menus{$menu}{items}}) {

                                # Default action = display if no action and the display matches a voice command
            if (!$$ptr{A} and $voice_cmd_list{$$ptr{D}}) {
                $$ptr{A} = $$ptr{D};
                @{$$ptr{Astates}} = @{$$ptr{Dstates}} if $$ptr{Dstates};
            }

                                # Allow for: turn fan [on,off]
            my $i = 0;
            if ($$ptr{Astates}) {
                for my $state (@{$$ptr{Astates}}) {
                    $$ptr{actions}[$i++] = "$$ptr{Aprefix}'$state'$$ptr{Asuffix}";
                }
            }
                                # Allow for: set $object $state
            elsif ($$ptr{Dstates}) {
                for my $state (@{$$ptr{Dstates}}) {
                    my $action = $$ptr{A};
                    $action =~ s/\$state/'$state'/;
                    $$ptr{actions}[$i++] = $action;
                }
            }

                                # Now verify that all menus exist and are used
                                # Also set default goto if needed

                                # Explicit goto menu is given
            if ($$ptr{goto} and $menus{$$ptr{goto}}) {
                delete $unused_menus{$$ptr{goto}};
            }
                                # The display text matches a submenu
            elsif ($menus{$$ptr{D}}) {
                $$ptr{goto} = $$ptr{D};
                delete $unused_menus{$$ptr{goto}};
            }
                                # For an action, stay on the goto menu by default
            elsif ($$ptr{A}) {
                $$ptr{goto} = $menu;
                delete $unused_menus{$$ptr{goto}};
            }
                                # For a response only, stay on the goto menu by default
            elsif ($$ptr{R}) {
                $$ptr{goto} = $menu;
                delete $unused_menus{$$ptr{goto}};
            }
            else {
                print "\nWarning, goto menu not found: menu=$menu goto=$$ptr{goto} text=$$ptr{D}\n\n" unless
                    $$ptr{goto} eq 'prev';
            }
        }
    }

    delete $unused_menus{menu_list_states};
    delete $unused_menus{menu_list};
    delete $unused_menus{$menus{menu_list}[0]};
    for (sort keys %unused_menus) {print "\nWarning, these menus were unused: $_\n\n" unless /^states\d+$/};

                                # Do a depth first level count
    my @menus_list = &menu_submenus($menu_group, $menus{menu_list}[0], 99, 1);
    my $level = 0;
    for my $ptr (@menus_list) {
        for my $menu (@{$ptr}) {
            $menus{$menu}{level} = $level unless defined $menus{$menu}{level};
        }
        $level++;
    }
                                # Create a sorted menu list
    @{$menus{menu_list_sorted}} = sort {$menus{$a}{level} <=> $menus{$b}{level}} @{$menus{menu_list}};

}

                                # Find just one level of submenus
sub menu_submenu {
    my ($menu_group, $menu) = @_;
    my (@menus, %menus_seen);
    for my $ptr (@{$Menus{$menu_group}{$menu}{items}}) {
        my $menu_sub;
        if ($$ptr{A}) {
            $menu_sub = $$ptr{Dstates_menu} if $$ptr{Dstates_menu};
        }
        else {
            $menu_sub = $$ptr{goto}
        }
        next unless $menu_sub;
        unless ($menus_seen{$menu_sub}++) {
            push @menus, $menu_sub;
            $Menus{$menu_group}{$menu_sub}{parent} = $menu; # Track just the first parent ?
        }
    }
    return @menus;
}

                                # Find nn levels of submenus, grouped by levels
sub menu_submenus {
    my ($menu_group, $menu, $levels, $levelized) = @_;
    my (@menus_list, %menus_seen);
    my @menus_left = ($menu);
    while (@menus_left) {
        push @menus_list, [@menus_left];
        my @menus_next;
        for my $menu (@menus_left) {
            push @menus_next, &menu_submenu($menu_group, $menu) unless $menus_seen{$menu}++;
        }
        @menus_left = @menus_next;
    }
    if ($levelized) {
        return @menus_list;
    }
    else {
        my @menus_total;
        for my $ptr (@menus_list) {
            push @menus_total, @{$ptr};
        }
        return @menus_total;
    }
}


#---------------------------------------------------------------------------
#  menu_create will create a menu for all voice commands
#---------------------------------------------------------------------------

sub menu_create {
    my ($file) = @_;
    my $menu_top = "# This is an auto-generated file.  Rename it before you edit it, then update menu.pl to point to it\nM: mh\n";
    my $menu;
    for my $category (sort &list_code_webnames('Voice_Cmd')) {
        $menu_top .= "  D: $category\n";
        $menu     .= "M: $category\n";
        for my $object_name (sort &list_objects_by_webname($category)) {
            my $object = &get_object_by_name($object_name);
            next unless $object and $object->isa('Voice_Cmd');
            my $authority = $object->get_authority;
#           next unless $authority =~ /anyone/ or 
#                       $config_parms{tellme_pin} and $Cookies{vxml_cookie} eq $config_parms{tellme_pin};
            $menu .= sprintf "  D: %-50s  # %-25s %10s\n", $$object{text}, $object_name, $authority;
        }
    }
    &file_write($file, $menu_top . $menu);
    return $menu_top . $menu;
}    

#---------------------------------------------------------------------------
#  menu_run will be called to execute menu actions
#---------------------------------------------------------------------------

sub menu_run {
    my ($menu_group, $menu, $item, $state, $format) = split ',', $_[0] if $_[0];
    logit "$config_parms{data_dir}/logs/menu_run.log", 
          "f=$format ip=$Socket_Ports{http}{client_ip_address} mg=$menu_group m=$menu i=$item s=$state";
    my $action = '';
    my $ptr = $Menus{$menu_group}{$menu}{items}[$item];
    if (defined $state and $$ptr{actions}) {
        $action = $$ptr{actions}[$state];
    }
    else {
        $action = $$ptr{A};
    }
    if ($action) {
        my $cmd = $action;
        $cmd =~ s/\'//g;        # Drop the '' quotes around state if a voice cmd
        my $msg = "menu_run: g=$menu_group m=$menu i=$item s=$state => action: $action";
        print_log  $msg;
        print     "$msg\n";
        unless (&run_voice_cmd($cmd)) {
            eval $action;
            print "Error in menu_run: m=$menu i=$item s=$state action=$action error=$@\n" if $@;
        }
    }
    $state = $$ptr{Dstates}[$state] if defined $state and $$ptr{Dstates};
    my $response = $$ptr{R};
    $Menus{last_response_menu}       = $menu;
    $Menus{last_response_menu_group} = $menu_group;
    if ($response and $response eq 'last_response') {
        if ($format eq 'l') {
            $Menus{last_response_loop} = $Loop_Count + 3;
        }
                                # Everything else comes via http_server
        else {
            return "menu_run_response($response,$format)"
        }
    }
    else {
        eval "\$response = qq[$response]" if $response; # Allow for var substitution
        return &menu_run_response($response, $format);
    }
}

sub menu_run_response {
    my ($response, $format) = @_;
    ($response, $format) = split ',', $response unless $format; # only 1 arg if called via http last response
    $response = &last_response if $response and $response eq 'last_response';
    if ($format and $format eq 'w') {
        $response = 'All done' unless $response;
        $response = "<card><p>$response</p></card>";
        $response =  qq|<template><do type="accept" label="Prev."><prev/></do></template>\n| . $response;
        return &wml_page($response);
    }
    elsif ($format and $format eq 'v') {
        $response = 'All done' unless $response;
        my $http_root = "http://$config_parms{http_server}:$config_parms{http_port}";
        my $goto      = "$http_root/sub?menu_vxml($Menus{last_response_menu_group})#$Menus{last_response_menu}";
        my $vxml = qq|<form><block><audio>$response</audio><goto next='$goto'/></block></form>|;
        return &vxml_page($vxml);
    }
    elsif ($format and $format eq 'h') {
        $response = 'All done' unless $response;
        return &html_page('Menu Results', $response);
    }
    else {
        return $response;
    }
}

#---------------------------------------------------------------------------
#  menu_html creates the web browser menu interface
#---------------------------------------------------------------------------

sub menu_html {
    my ($menu_group, $menu) = split ',', $_[0] if $_[0];
    $menu_group = 'default' unless $menu_group;
    $menu       = $Menus{$menu_group}{menu_list}[0] unless $menu;

    my $html;
    my $item = 0;
    my $ptr = $Menus{$menu_group};
    for my $ptr2 (@{$$ptr{$menu}{items}}) {
        my $goto = $$ptr2{goto};
                                # Action item
        if ($$ptr2{A}) {
                                # Multiple states
            if ($$ptr2{Dstates}) {
                $html .= "    <li> $$ptr2{Dprefix}\n";
                my $state = 0;
                for my $state_name (@{$$ptr2{Dstates}}) {
                    $html .= "      <a href='/sub?menu_run($menu_group,$menu,$item,$state,h)'>$state_name</a>, \n";
                    $state++;
                }
                $html .= "    $$ptr2{Dsuffix}\n";
            }
                                # One state
            else {
                $html .= "    <li><a href='/sub?menu_run($menu_group,$menu,$item,,h)'>$$ptr2{D}</a>\n";
            }
        }
        elsif ($$ptr2{R}) {
            $html .= "    <li><a href='/sub?menu_run($menu_group,$menu,$item,,h)'>$$ptr2{D}</a>\n";
        }

                                # Menu item
        else {
            $html .= "    <li><a href='/sub?menu_html($menu_group,$goto)'>$goto</a>\n";
        }
        $item++;
    }
    return &html_page($menu, $html);
}

#---------------------------------------------------------------------------
#  menu_wml creates the wml (for WAP enabled cell phones) menu interface
#  You can test it here:  http://www.gelon.net
#  Others listed here: http://www.palowireless.com/wap/browsers.asp
#---------------------------------------------------------------------------

sub menu_wml {
    my ($menu_group, $menu_start) = split ',', $_[0] if $_[0];
    $menu_group = 'default' unless $menu_group;
    $menu_start = $Menus{$menu_group}{menu_list}[0] unless $menu_start;
    logit "$config_parms{data_dir}/logs/menu_wml.log", 
          "ip=$Socket_Ports{http}{client_ip_address} mg=$menu_group m=$menu_start";

    my (@menus, @cards);

                                # Get a list of all menus, by level
    @menus = &menu_submenus($menu_group, $menu_start, 99);
                                # Now build all the cards
    @cards = &menu_wml_cards($menu_group, @menus);

                                # See how many cards will fit in a 1400 character deck.
    my ($i, $length);
    $i = $length = 0;
    while ($i <= $#cards and $length < 1400) {
        $length += length $cards[$i++];
    }
    $i -= 2;                    # The template card is extra

#   print "db2 mcnt=$#menus ccnt=$#cards i=$i l=$length m=@menus, c=@cards.\n";

                                # This time build only for the requested cards that fit
    @cards = &menu_wml_cards($menu_group, @menus[0..$i]);

    return &wml_page("@cards");

}

sub menu_wml_cards {
    my ($menu_group, @menus) = @_;
    my (%menus, @cards);

    %menus = map {$_, 1} @menus;

    my $template = qq|<template><do type="prev" label="Prev."><prev/></do></template>\n|;
    push @cards, $template;

    for my $menu (@menus) {
        my $wml = "\n <card id='$menu'>\n";
                                # Save the menu name in a var (unless it is a states menu)
        unless ($menu =~ /^states\d+$/) {
            $wml .= "  <onevent type='onenterforward'><refresh>\n";
            $wml .= "    <setvar name='prev_menu' value='$menu'/>\n";
            $wml .= "  </refresh></onevent>\n";
        }
        $wml .= "  <p>$menu\n  <select name='prev_value'>\n";
        my $item = 0;
        for my $ptr (@{$Menus{$menu_group}{$menu}{items}}) {
                                # Action item
            if ($$ptr{A}) {
                                # Multiple states -> goto a state menu
                if ($$ptr{Dstates}) {
                    my $goto = $$ptr{'Dstates_menu'};
                    $goto = ($menus{$goto}) ? "#$goto" : "/sub?menu_wml($menu_group,$goto)";
                    $wml .= "    <option value='$item' onpick='$goto'>$$ptr{Dprefix}..$$ptr{Dsuffix}</option>\n";
                }
                                # States menu
                elsif ($$ptr{A} eq 'state_select') {
                    $wml .= "    <option onpick='/sub?menu_run($menu_group,\$prev_menu,\$prev_value,$item,w)'>$$ptr{D}</option>\n";
                }
                                # One state
                else {
                    $wml .= "    <option onpick='/sub?menu_run($menu_group,$menu,$item,,w)'>$$ptr{D}</option>\n";
                }
                $item++;
            }
            elsif ($$ptr{R}) {
                $wml .= "    <option onpick='/sub?menu_run($menu_group,$menu,$item,,w)'>$$ptr{D}</option>\n";
            }
                                # Menu item
            else {
                my $goto = $$ptr{goto};
                $goto = ($menus{$goto}) ? "#$goto" : "/sub?menu_wml($menu_group,$goto)";
                $wml .= "    <option onpick='$goto'>$$ptr{D}</option>\n";
            }
        }
        $wml .= "   </select></p>\n </card>\n";
        push @cards, $wml;
    }
    return @cards;
}


#---------------------------------------------------------------------------
#  menu_vxml creates the vxml (for WAP enabled cell phones) menu interface
#---------------------------------------------------------------------------

sub menu_vxml {
    my ($menu_group, $menu_start) = split ',', $_[0] if $_[0];
    $menu_group = 'default'                         unless $menu_group;
    $menu_start = $Menus{$menu_group}{menu_list}[0] unless $menu_start;
    logit "$config_parms{data_dir}/logs/menu_vxml.log",
          "ip=$Socket_Ports{http}{client_ip_address} mg=$menu_group m=$menu_start";

                                # Get a list of all menus, then build vxml forms
    my @menus     = &menu_submenus  ($menu_group, $menu_start, 99);
    my @forms     = &menu_vxml_forms($menu_group, @menus);
    my $greeting  = &vxml_audio('greeting', 'Welcome to Mister House', 'tellme_welcome.wav', "#$menu_start");
    my $vxml_vars = "<var name='prev_menu'/>\n<var name='prev_item'/>\n";
    return &vxml_page($vxml_vars . $greeting . "@forms");
}

sub menu_vxml_forms {
    my ($menu_group, @menus) = @_;
    my (%menus, @forms);
    my $http_root =  "http://$config_parms{http_server}:$config_parms{http_port}";

    for my $menu (@menus) {

        my ($menu_parent, $prompt);
        if ($menu =~ /^states/) {
            $prompt = "Speak $Menus{$menu_group}{$menu}{states}";
            $prompt =~ tr/,/ /;
        }
        else {
            $prompt = "Speak a $menu command";
            $menu_parent = $Menus{$menu_group}{$menu}{parent};
        }

        my (@grammar, @action, @goto);
        my $item = 0;
        for my $ptr (@{$Menus{$menu_group}{$menu}{items}}) {
            my ($grammar, $action, $goto);
            $grammar = $$ptr{D};
                                # Action item
            if ($$ptr{A}) {
                                # Multiple states
                if ($$ptr{Dstates}) {
                    $grammar = "$$ptr{Dprefix} $$ptr{Dsuffix}";
                    $goto    = "#$$ptr{Dstates_menu}";
                    $action .= qq|<assign name="prev_menu"  expr="'$menu'"/>\n|;
                    $action .= qq|<assign name="prev_item"  expr="'$item'"/>\n|;
                }
                                # States menu
                elsif ($$ptr{A} eq 'state_select') {
                    $goto = "$http_root/sub?menu_run($menu_group,{prev_menu},{prev_item},$item,v)";
                }
                                # One state
                else {
                    $goto = "$http_root/sub?menu_run($menu_group,$menu,$item,,v)";
                }
            }
            elsif ($$ptr{R}) {
                $goto = "$http_root/sub?menu_run($menu_group,$menu,$item,,v)";
            }
                                # Menu item
            else {
                $goto = "#$$ptr{goto}";
            }
            push @grammar, $grammar;
            push @action,  $action;
            push @goto,    $goto;
            $item++;
        }
        push @forms, &vxml_form(prompt => $prompt, name => $menu, prev => $menu_parent,
                                grammar => \@grammar, action => \@action, goto => \@goto);
    }
    return @forms;
}


#---------------------------------------------------------------------------
#  menu_lcd* populate the %lcd_data array for use by LCD interfaces with keypads
#---------------------------------------------------------------------------
                                # This loads in a menu and refreshes the LCD display data
sub menu_lcd_load {
    my ($menu) = @_;
    $menu = $lcd_data{menu_name}                        unless $menu;
    $menu = $Menus{$lcd_data{menu_group}}{menu_list}[0] unless $menu;

                                # Reset menu only if it is a new one (keep old cursor and state)
    unless ($lcd_data{menu_name} eq $menu) {
        my $ptr = $Menus{$lcd_data{menu_group}}{$menu};
        my $i = -1;
        for my $ptr2 (@{$$ptr{items}}) {
            $lcd_data{menu}[++$i] = $$ptr2{D};
        }
                                # Set initial cursor and display location to 0,0 if a new menu
        $lcd_data{cx} = $lcd_data{cy} = $lcd_data{dx} = $lcd_data{dx} = 0;
        $lcd_data{menu_cnt}  = $i;
        $lcd_data{state}     = -1;
        $lcd_data{menu_ptr}  = $ptr;
        $lcd_data{menu_name} = $menu;
    }
    &menu_lcd_refresh;          # Refresh the display data
}

                                # This will refresh the LCD Display records
                                # And position the cursor scroll line if needed
sub menu_lcd_refresh {
    for my $i (0 .. $lcd_data{dy_max}) {

        my $row  = $lcd_data{dy} + $i;
                                # Use a blank if there is no menu entry for this row
        my $data = ($row <= $lcd_data{menu_cnt}) ? $lcd_data{menu}[$row] : ' ';
        my $l = length $data;

        if ($row == $lcd_data{cy}) {
                                # Keep cursor within current line
            $lcd_data{cx} = $l if $lcd_data{cx} > $l;
            substr($data, $lcd_data{cx}, 1) = '#';

                                # Check to see if this line needs scrolling
            if ($lcd_data{dx}) {
                $data = '<' . substr $data, ($lcd_data{dx} + 4);
            }
        }
        substr($data, $lcd_data{dx_max}, 1) = '>' if ($l - $lcd_data{dx} - 2) > $lcd_data{dx_max};
        $lcd_data{display}[$i] = $data;
    }
    $lcd_data{refresh} = 1;
}

                                # Monitor keypad data (allow for computer keyboard simulation)
sub menu_lcd_navigate {
    my ($key) = @_;
    $key = $lcd_keymap{$key} if $lcd_keymap{$key};

    my $menu = $lcd_data{menu_name};
    my $ptr = $lcd_data{menu_ptr}{items}[$lcd_data{cy}];
    
                                # See if we need to scroll the display window
    if ($key eq 'up') {
        $lcd_data{cy}-- unless $lcd_data{cy} == 0;
        if ($lcd_data{cy} < $lcd_data{dy}) {
            $lcd_data{dy} = $lcd_data{cy};
        }
    }
    elsif ($key eq 'down') {
        $lcd_data{cy}++ unless $lcd_data{cy} == $lcd_data{menu_cnt};
        if ($lcd_data{cy} > ($lcd_data{dy} + $lcd_data{dy_max})) {
            $lcd_data{dy} =  $lcd_data{cy} - $lcd_data{dy_max};
        }
    }
    elsif ($key eq 'left') {
                                # For action state menus, scroll to the previous state
        if ($$ptr{Dstates}) {
            if (--$lcd_data{state} >= 0) {
                &menu_lcd_curser_state($ptr);
            }
            else {
                $lcd_data{state} = -1;
                $lcd_data{cx}    =  0;
            }
        }
        else {
            $lcd_data{cx} -= 5;
            $lcd_data{cx}  = 0 if $lcd_data{cx} < 0;
        }
        if ($lcd_data{cx} < $lcd_data{dx}) {
            $lcd_data{dx} = $lcd_data{cx};
        }
    }
    elsif ($key eq 'right') {
                                # For action state menus, scroll to the next state
        if ($$ptr{Dstates}) {
            if (++$lcd_data{state} < @{$$ptr{Dstates}}) {
                &menu_lcd_curser_state($ptr);
            }
            else {
                $lcd_data{state} = @{$$ptr{Dstates}};
                $lcd_data{cx}    = length $lcd_data{menu}[$lcd_data{cy}];
            }
        }
        else {
            my $l = length($lcd_data{menu}[$lcd_data{cy}]);
            $lcd_data{cx} += 5;
            $lcd_data{cx} = $l if $lcd_data{cx} > $l;
        }
                                # Scroll the display if needed
        if ($lcd_data{cx} > ($lcd_data{dx} + $lcd_data{dx_max})) {
            $lcd_data{dx} =  $lcd_data{cx} - $lcd_data{dx_max};
        }
    }
                                # Run action or display next menu
    elsif ($key eq 'enter') {
        if ($$ptr{A}) {
            my $response = &menu_run("$lcd_data{menu_group},$menu,$lcd_data{cy},$lcd_data{state},l");
            if ($response) {
                &menu_lcd_display($response, $menu);
            }
            else {
                &menu_lcd_load($lcd_data{menu_name});
            }
        }
        elsif ($$ptr{R}) {
            my $response = &menu_run("$lcd_data{menu_group},$menu,$lcd_data{cy},$lcd_data{state},l");
            if ($response) {
                &menu_lcd_display($response, $menu);
            }
            else {
                &menu_lcd_load($lcd_data{menu_name});
            }
        }
        else {
            push @{$lcd_data{menu_history}}, $menu;
            push @{$lcd_data{menu_history_cy}}, $lcd_data{cy};
            push @{$lcd_data{menu_history_dy}}, $lcd_data{dy};
            &menu_lcd_load($$ptr{D});
        }
        return;
    }
    elsif ($key eq 'exit') {
        if (my $menu = pop @{$lcd_data{menu_history}}) {
            &menu_lcd_load($menu);
            $lcd_data{cy} = pop @{$lcd_data{menu_history_cy}};
            $lcd_data{dy} = pop @{$lcd_data{menu_history_dy}};
        }
    }
    &menu_lcd_refresh;  # Refresh the display data data
}

sub menu_lcd_display {
    my ($response, $menu) = @_;
    $Text::Wrap::columns = 20;
    @{$lcd_data{display}} = split "\n", wrap('', '', $response);
    $lcd_data{menu_cnt}  = @{$lcd_data{menu}} - 1;
    $lcd_data{menu_name} = 'response';
    $lcd_data{cx} = $lcd_data{cy} = $lcd_data{dx} = $lcd_data{dy} = 0;
    push @{$lcd_data{menu_history}}, $menu if $menu;
    $lcd_data{refresh} = 1;
}

sub menu_lcd_curser_state {
    my ($ptr) = @_;
    my $state_name = $$ptr{Dstates}[$lcd_data{state}];
    if ($$ptr{D} =~ /([\[,]\Q$state_name\E[,\]])/) {
        $lcd_data{cx} = 1 + index $$ptr{D}, $1;
    }
}

return 1;

