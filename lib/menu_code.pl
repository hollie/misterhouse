
=head1 B<{menu_code}>

=head2 SYNOPSIS

NONE

=head2 DESCRIPTION

NONE

=head2 INHERITS

B<NONE>

=head2 METHODS

=over

=cut

use strict;

use vars qw(%Menus);

=item C<menu_parse>

Parse the menu into %Menus

=cut

sub menu_parse {
    my ( $template, $menu_group ) = @_;
    $menu_group = 'default' unless $menu_group;

    my ( %menus, $menu, $index, %voice_cmd_list );
    $Menus{$menu_group} = \%menus;

    # Find all the valid Voice_Cmd text
    for my $object ( map { &get_object_by_name($_) }
        &list_objects_by_type('Voice_Cmd') )
    {
        # Pick first of {a,b} enumerations (e.g. {tell me,what is} )
        my $text = $$object{text};
        $text =~ s/\{([^,]+).+?\}/$1/g;
        $voice_cmd_list{ lc $text } = $object;    # Make it case insensitive
    }

    my $menu_states_cnt = 'states0000';
    for ( split /\n/, $template ) {
        next unless /\S/;                         # Ignore blank lines
        next if /^\s*\#/;                         # Ignore comments
        my ( $type, $data ) = $_ =~ /^\s*(\S+)\:\s*(.+?)\s*$/;
        $data =~ s/\s+\#.+//;                     # Ignore comments

        # Pull out 'start menu' records:  M: Lights
        if ( $type eq 'M' ) {
            $menu = $data;
            $menu =~
              s/ /_/g;    # Blanks will mess up wml (and vxml and html?) menus
                # Reset index.  Allow for menus in different sections/files
            $index = -1;
            $index = @{ $menus{$menu}{items} } - 1
              if $menus{$menu} and $menus{$menu}{items};

            if ( $menus{$menu} ) {

                # We get these when we split menus between files
                #               print "\nWarning, duplicate menu: $menu\n\n";
            }
            else {
                push @{ $menus{_menu_list} }, $menu;
            }
        }
        elsif ($type) {

            # Allow for menu level parms like P: if speced before any items
            if ( $type ne 'D' and $index == -1 ) {
                $menus{$menu}{"default:$type"} = $data;
            }

            # Pull out 'select,action,response' records:  A: Left bedroom light $state
            else {
                $index++ if $type eq 'D';
                $menus{$menu}{items}[$index]{$type} = $data;
            }

            #           print "db m=$menu i=$index type=$type d=$data.\n";
        }
        else {
            print "Menu parsing error: $_\n" unless /^\s*$/;
        }

        # States can be found in item text and Action/Response records
        my ( $prefix, $states, $suffix ) = $data =~ /(.*)\[(.+)\](.*)/;

        if ($states) {
            $menus{$menu}{items}[$index]{ $type . 'prefix' } = $prefix;
            $menus{$menu}{items}[$index]{ $type . 'suffix' } = $suffix;
            @{ $menus{$menu}{items}[$index]{ $type . 'states' } } = split ',',
              $states;

            # Create a states menu for each unique set of states
            if ( $type eq 'D' ) {
                unless ( $menus{_menu_list_states}{$states} ) {
                    $menus{_menu_list_states}{$states} = ++$menu_states_cnt;
                    $menus{$menu_states_cnt}{states} = $states;
                    push @{ $menus{_menu_list} }, $menu_states_cnt;
                    my $i = 0;
                    for my $state ( split ',', $states ) {
                        $menus{$menu_states_cnt}{items}[$i]{D} = $state;
                        $menus{$menu_states_cnt}{items}[$i]{A} = 'state_select';
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
    for $menu ( @{ $menus{_menu_list} } ) {
        for my $ptr ( @{ $menus{$menu}{items} } ) {

            # Default action = display if no action and the display matches a voice command
            if ( !$$ptr{A} and $voice_cmd_list{ lc $$ptr{D} } ) {
                $$ptr{A} = $$ptr{D};
                @{ $$ptr{Astates} } = @{ $$ptr{Dstates} } if $$ptr{Dstates};
                $$ptr{Aprefix} = $$ptr{Dprefix};
                $$ptr{Asuffix} = $$ptr{Dsuffix};
            }

            # Allow for: turn fan [on,off]
            my $i = 0;
            if ( $$ptr{Astates} ) {
                for my $state ( @{ $$ptr{Astates} } ) {
                    $$ptr{actions}[ $i++ ] =
                      "$$ptr{Aprefix}'$state'$$ptr{Asuffix}";
                }
            }

            # Allow for: set $object $state
            elsif ( $$ptr{Dstates} ) {
                for my $state ( @{ $$ptr{Dstates} } ) {
                    my $action = $$ptr{A};
                    $action =~ s/\$state/'$state'/;
                    $$ptr{actions}[ $i++ ] = $action;
                }
            }

            # Now verify that all menus exist and are used
            # Also set default goto if needed

            my $temp = $$ptr{D};
            $temp =~ s/ /_/g;

            # Explicit goto menu is given
            if ( $$ptr{goto} and $menus{ $$ptr{goto} } ) {
                delete $unused_menus{ $$ptr{goto} };
            }

            # The display text matches a submenu
            elsif ( $menus{$temp} ) {
                $$ptr{goto} = $temp;
                delete $unused_menus{ $$ptr{goto} };
            }

            # For an action, stay on the goto menu by default
            elsif ( $$ptr{A} ) {
                $$ptr{goto} = $menu;
                delete $unused_menus{ $$ptr{goto} };
            }

            # For a response only, stay on the goto menu by default
            elsif ( $$ptr{R} ) {
                $$ptr{goto} = $menu;
                delete $unused_menus{ $$ptr{goto} };
            }
            else {
                print
                  "\nWarning, goto menu not found: menu=$menu goto=$$ptr{goto} text=$$ptr{D}\n\n"
                  unless $$ptr{goto} eq 'prev';
            }
        }
    }

    delete $unused_menus{_menu_list_states};
    delete $unused_menus{_menu_list};
    delete $unused_menus{ $menus{_menu_list}[0] };
    for ( sort keys %unused_menus ) {
        print "\nWarning, these menus were unused: $_\n\n" unless /^states\d+$/;
    }

    # Do a depth first level count
    my @menus_list =
      &menu_submenus( $menu_group, $menus{_menu_list}[0], 99, 1 );
    my $level = 0;
    for my $ptr (@menus_list) {
        for my $menu ( @{$ptr} ) {
            $menus{$menu}{level} = $level unless defined $menus{$menu}{level};
        }
        $level++;
    }

    # Create a sorted menu list
    @{ $menus{_menu_list_sorted} } =
      sort { $menus{$a}{level} <=> $menus{$b}{level} } @{ $menus{_menu_list} };

    return $Menus{$menu_group};
}

=item C<menu_submenu>

Find just one level of submenus

=cut

sub menu_submenu {
    my ( $menu_group, $menu ) = @_;
    my ( @menus, %menus_seen );
    for my $ptr ( @{ $Menus{$menu_group}{$menu}{items} } ) {
        my $menu_sub;
        if ( $$ptr{A} ) {
            $menu_sub = $$ptr{Dstates_menu} if $$ptr{Dstates_menu};
        }
        else {
            $menu_sub = $$ptr{goto};
        }
        next unless $menu_sub;
        unless ( $menus_seen{$menu_sub}++ ) {
            push @menus, $menu_sub;

            # Track just the first parent ?
            $Menus{$menu_group}{$menu_sub}{parent} = $menu
              unless $menu eq $menu_sub;
        }
    }
    return @menus;
}

=item <menu_submenus>

Find nn levels of submenus, grouped by levels

=cut

sub menu_submenus {
    my ( $menu_group, $menu, $levels, $levelized ) = @_;
    my ( @menus_list, %menus_seen );
    my @menus_left = ($menu);
    while (@menus_left) {
        push @menus_list, [@menus_left];
        my @menus_next;
        for my $menu (@menus_left) {
            push @menus_next, &menu_submenu( $menu_group, $menu )
              unless $menus_seen{$menu}++;
        }
        @menus_left = @menus_next;
    }
    if ($levelized) {
        return @menus_list;
    }

    # Return all menus for all levels in one list
    else {
        my ( @menus_total, %menus_seen );
        for my $ptr (@menus_list) {

            #           print "db1 m=@{$ptr}\n";
            for my $menu ( @{$ptr} ) {
                push @menus_total, $menu unless $menus_seen{$menu}++;
            }
        }
        return @menus_total;
    }
}

=item C<menu_create>

Create a menu for all voice commands

=cut

sub menu_create {
    my ($file) = @_;
    my $menu_top =
      "# This is an auto-generated file.  Rename it before you edit it, then update menu.pl to point to it\nM: mh\n";
    my $menu;
    for my $category ( sort &list_code_webnames('Voice_Cmd') ) {
        $menu_top .= "  D: $category\n";
        $menu     .= "M: $category\n";
        for my $object_name ( sort &list_objects_by_webname($category) ) {
            my $object = &get_object_by_name($object_name);
            next unless $object and $object->isa('Voice_Cmd');
            my $authority = $object->get_authority;

            #           next unless $authority =~ /anyone/ or
            #                       $config_parms{tellme_pin} and $Cookies{vxml_cookie} eq $config_parms{tellme_pin};

            # Pick first of {a,b} enumerations (e.g. {tell me,what is} )
            my $text = $$object{text};
            $text =~ s/\{([^,]+).+?\}/$1/g;

            $menu .= sprintf "  D: %-50s  # %-25s %10s\n", $text, $object_name,
              $authority;
        }
    }
    &file_write( $file, $menu_top . $menu );
    return $menu_top . $menu;
}

=item C<menu_run>

Called to execute menu actions

  $format:  v->vxml,  h->html, hn->html no_response,  w->wml,  l->lcd

=cut

sub menu_run {

    #   my ($menu_group, $menu, $item, $state, $format, $referer) = split ',', $_[0] if $_[0];
    my ( $menu_group, $menu, $item, $state, $format, $referer ) = @_;

    my ( $action, $cmd );
    my $ptr = $Menus{$menu_group}{$menu}{items}[$item];
    if ( defined $state and $$ptr{actions} ) {
        $action = $$ptr{actions}[$state];
    }
    else {
        $action = $$ptr{A};
    }
    my $authority = $$ptr{P};
    my $display   = $$ptr{D};
    my $response  = $$ptr{R};
    $response = $Menus{$menu_group}{$menu}{'default:R'} unless $response;

    $action    = '' unless defined $action;      # Avoid uninit warnings
    $state     = '' unless defined $state;
    $format    = '' unless defined $format;
    $authority = '' unless defined $authority;
    $display   = '' unless defined $display;
    $response  = '' unless defined $response;

    $Menus{menu_data}{response_format} = $format;

    # Allow anyone to run set_authority('anyone') commands
    my $ref;
    if ( $cmd = $action ) {
        $cmd =~ s/\'//g;    # Drop the '' quotes around state if a voice cmd
        ($ref) = &Voice_Cmd::voice_item_by_text( lc($cmd) );
    }
    $authority = $ref->get_authority       unless $authority or !$ref;
    $authority = $Password_Allow{$display} unless $authority;
    $authority = $Password_Allow{$cmd}     unless $authority;
    $authority = $Menus{$menu_group}{$menu}{'default:P'} unless $authority;
    $authority = '' unless $authority;

    $Socket_Ports{http}{client_ip_address} = ''
      unless $Socket_Ports{http}{client_ip_address};
    my $msg =
      "menu_run: a=$Authorized,$authority f=$format ip=$Socket_Ports{http}{client_ip_address} mg=$menu_group m=$menu i=$item s=$state a=$action r=$response";

    #   print "$msg\n";
    logit "$config_parms{data_dir}/logs/menu_run.log", $msg;

    unless ( &authority_check($authority) ) {
        if ( $format eq 'v' ) {
            my $vxml =
              qq|<form><block><audio>Sorry, authorization required to run $action</audio><goto next='_lastanchor'/></block></form>|;
            return &vxml_page($vxml);
        }

        # If wap cell phone id is not in the list, prompt for the password
        elsif ( $format eq 'w' ) {
            unless (
                $Http{'x-up-subno'} and grep $Http{'x-up-subno'} eq $_,
                split( /[, ]/, $config_parms{password_allow_phones} )
              )
            {
                return &html_password('browser')
                  ;    # wml requires browser login ... no form/cookies for now
            }
        }
        elsif ( $format eq 'l' ) {
            return 'Not authorized';
        }
        else {
            return &html_password('')
              ; # Html can take cookies or browser ... default to mh.ini password_menu
        }
    }

    if ($action) {
        my $msg =
          "menu_run: g=$menu_group m=$menu i=$item s=$state => action: $action";
        print_log $msg;
        my $setby = ( lc $format =~ /^h/i ) ? 'web' : 'notweb';
        $setby .= " [$Socket_Ports{http}{client_ip_address}]"
          if $Socket_Ports{http}{client_ip_address} and $setby eq 'web';
        unless (
            ( $setby eq 'notweb' )
            ? &run_voice_cmd($cmd)
            : &run_voice_cmd( $cmd, 'mh', $setby )
          )
        {
            #           package main;   # Need this if we had this code in a package
            eval $action;
            print
              "Error in menu_run: m=$menu i=$item s=$state action=$action error=$@\n"
              if $@;
        }
    }

    $Menus{menu_data}{last_response_menu}       = $menu;
    $Menus{menu_data}{last_response_menu_group} = $menu_group;

    if ( $response and lc $response eq 'none' and $format eq 'l' ) {
        return;
    }

    if ( $format and $format eq 'hr' ) {

        #  Default to referer.  Also make sure we have a full path, starting with http
        $Http{Referer} =~ m|(http://\S+?)/|;
        $referer = $1 . $referer unless $referer =~ /^http/;
        $referer =~ s/&&/&/
          ; # These got doubled up in http_server ... need them as single (e.g. /bin/menu.pl?main&Top|Main|Rooms)
        $referer =~ s/ /%20/g;
        return &http_redirect($referer);
    }

    # Substitute $state
    if ( length($state) > 0 and $state >= 0 ) {
        my $t_state;
        $t_state = $$ptr{Dstates}[$state] if $$ptr{Dstates};
        $t_state = $$ptr{Astates}[$state] if $$ptr{Astates};
        if ( defined $t_state ) {
            $state = $t_state;
        }
        $response = "Set to $state" unless $response;
    }

    if ( $response and $response =~ /^eval (.+)/ ) {
        print "Running eval on: $1\n";
        $response = eval $1;
    }
    elsif ($response) {
        eval
          "\$response = qq[$response]";   # Allow for var substitution of $state
    }

    if ( !$response or $response eq 'last_response' ) {
        if ( $format eq 'l' ) {
            $Menus{menu_data}{last_response_loop} = $Loop_Count + 3;
            return;
        }

        # Everything else comes via http_server
        else {
            return "menu_run_response('last_response','$format')";
        }
    }

    return &menu_run_response( $response, $format );
}

sub menu_run_response {
    my ( $response, $format ) = @_;
    ( $response, $format ) = split ',', $response
      unless $format;    # only 1 arg if called via http last response
    $response = &last_response if $response and $response eq 'last_response';
    $response = 'all done' unless $response;
    if ( $format and $format eq 'w' ) {
        $response =~ s/& /&amp; /g;
        my $wml =
          qq|<head><meta forua="true" http-equiv="Cache-Control" content="max-age=0"/></head>\n|;
        $wml .=
          qq|<template><do type="accept" label="Prev."><prev/></do></template>\n|;
        $wml .= qq|<card><p>$response</p></card>|;
        return &wml_page($wml);
    }
    elsif ( $format and $format eq 'v' ) {

        #       my $http_root = "http://$config_parms{http_server}:$config_parms{http_port}";
        my $http_root = '';    # Full url is no longer required :)
        my $goto =
          "${http_root}sub?menu_vxml($Menus{menu_data}{last_response_menu_group})#$Menus{menu_data}{last_response_menu}";

        #       print "db1 gt=$goto\n";
        my $vxml =
          qq|<form><block><audio>$response</audio><goto next='$goto'/></block></form>|;

        #       my $vxml = qq|<form><block><audio>$response</audio><goto expr="'$goto'"/></block></form>|;
        return &vxml_page($vxml);
    }
    elsif ( $format and $format eq 'h' ) {
        return &html_no_response() if $response =~ /no[ _]response/i;
        return &http_redirect($1)  if $response =~ /^href=(.+)/i;
        return &html_page( '', $response );
    }
    else {
        return $response;
    }
}

=item C<menu_html>

Creates the web browser menu interface

=cut

sub menu_html {
    my ( $menu_group, $menu ) = @_;
    ( $menu_group, $menu ) = split ',', $menu_group unless defined $menu;

    ($menu_group) = &get_menu_default('default') unless $menu_group;
    $menu = $Menus{$menu_group}{_menu_list}[0] unless $menu;
    $menu = 'Top' unless $menu;

    my $html = "<h1>";
    my $item = 0;
    my $ptr  = $Menus{$menu_group};

    for my $ptr2 ( @{ $$ptr{$menu}{items} } ) {
        my $goto = $$ptr2{goto};

        # Action item
        if ( $$ptr2{A} ) {

            # Multiple states
            if ( $$ptr2{Dstates} ) {
                $html .= "    <li> $$ptr2{Dprefix}\n";
                my $state = 0;
                for my $state_name ( @{ $$ptr2{Dstates} } ) {
                    $html .=
                      "      <a href='/sub?menu_run($menu_group,$menu,$item,$state,h)'>$state_name</a>, \n";
                    $state++;
                }
                $html .= "    $$ptr2{Dsuffix}\n";
            }

            # One state
            else {
                $html .=
                  "    <li><a href='/sub?menu_run($menu_group,$menu,$item,,h)'>$$ptr2{D}</a>\n";
            }
        }
        elsif ( $$ptr2{R} ) {
            $html .=
              "    <li><a href='/sub?menu_run($menu_group,$menu,$item,,h)'>$$ptr2{D}</a>\n";
        }

        # Menu item
        else {
            $html .=
              "    <li><a href='/sub?menu_html($menu_group,$goto)'>$goto</a>\n";
        }
        $item++;
    }
    return &html_page( $menu, $html );
}

=item C<menu_wml>

Creates the wml (for WAP enabled cell phones) menu interface.  You can test it here:  http://www.gelon.net  or http://wapsilon.com.  Others listed here: http://www.palowireless.com/wap/browsers.asp

=cut

sub menu_wml {
    my ( $menu_group, $menu_start ) = @_;
    ( $menu_group, $menu_start ) = split ',', $menu_group
      unless defined $menu_start;

    ($menu_group) = &get_menu_default('default') unless $menu_group;
    $menu_start = $Menus{$menu_group}{_menu_list}[0] unless $menu_start;
    logit "$config_parms{data_dir}/logs/menu_wml.log",
      "ip=$Socket_Ports{http}{client_ip_address} mg=$menu_group m=$menu_start";

    my ( @menus, @cards );

    # Get a list of all menus, by level
    @menus = &menu_submenus( $menu_group, $menu_start, 99 );

    # Now build all the cards
    @cards = &menu_wml_cards( $menu_group, @menus );

    # See how many cards will fit in a 1400 character deck.
    my ( $i, $length );
    $i = $length = 0;
    while ( $i <= $#cards and $length < 1400 ) {
        $length += length $cards[ $i++ ];
    }
    $i -= 2;    # The template card is extra

    # This time build only for the requested cards that fit
    @cards = &menu_wml_cards( $menu_group, @menus[ 0 .. $i ] );

    #   print "db2 mcnt=$#menus ccnt=$#cards i=$i l=$length m=@menus, c=@cards.\n";

    return &wml_page("@cards");

}

sub menu_wml_cards {
    my ( $menu_group, @menus ) = @_;
    my ( %menus, @cards );

    %menus = map { $_, 1 } @menus;

    # Dang, can not get a prev button when using select??
    my $template =
      qq|<template><do type="prev" label="Prev1"><prev/></do></template>\n|;

    #                            qq|<do type="accept" label="Prev2"><prev/></do></template>\n|;
    push @cards, $template;

    for my $menu (@menus) {
        my $wml = "\n <card id='$menu'>\n";

        # Save the menu name in a var (unless it is a states menu)
        $wml .= "  <onevent type='onenterforward'><refresh>\n";
        if ( $menu =~ /^states\d+$/ ) {
            $wml .= qq|    <setvar name='prev_value' value="\$my_value"/>\n|;
        }
        else {
            $wml .= qq|    <setvar name='prev_menu'  value='$menu'/>\n|;
        }
        $wml .= "  </refresh></onevent>\n";

        $wml .= "  <p>$menu\n  <select name='my_value'>\n";

        # ivalue=0 does not seem to change anything
        #                              <select name='prev_value' ivalue='0'>
        # Not sure what select grouping does
        #   <optgroup title='test1'>
        #   </optgroup>

        my $item = 0;
        for my $ptr ( @{ $Menus{$menu_group}{$menu}{items} } ) {

            # Action item
            if ( $$ptr{A} ) {

                # Multiple states -> goto a state menu
                if ( $$ptr{Dstates} ) {
                    my $goto = $$ptr{'Dstates_menu'};
                    $goto =
                      ( $menus{$goto} )
                      ? "#$goto"
                      : "/sub?menu_wml($menu_group,$goto)";
                    $wml .=
                      "    <option value='$item' onpick='$goto'>$$ptr{Dprefix}..$$ptr{Dsuffix}</option>\n";
                }

                # States menu
                elsif ( $$ptr{A} eq 'state_select' ) {
                    $wml .=
                      "    <option onpick='/sub?menu_run($menu_group,\$prev_menu,\$prev_value,$item,w)'>$$ptr{D}</option>\n";
                }

                # One state
                elsif ( $$ptr{A} eq 'set_password' ) {
                    $wml .=
                      "    <option onpick='/SET_PASSWORD'>Set Password</option>\n";
                }
                else {
                    $wml .=
                      "    <option onpick='/sub?menu_run($menu_group,$menu,$item,,w)'>$$ptr{D}</option>\n";
                }
            }
            elsif ( $$ptr{R} ) {
                $wml .=
                  "    <option onpick='/sub?menu_run($menu_group,$menu,$item,,w)'>$$ptr{D}</option>\n";
            }

            # Menu item
            else {
                my $goto = $$ptr{goto};
                $goto =
                  ( $menus{$goto} )
                  ? "#$goto"
                  : "/sub?menu_wml($menu_group,$goto)";
                $wml .=
                  "    <option value='$item' onpick='$goto'>$$ptr{D}</option>\n";
            }
            $item++;
        }
        $wml .= "   </select></p>\n </card>\n";
        push @cards, $wml;
    }
    return @cards;
}

=item C<menu_vxml>

Creates the vxml (for WAP enabled cell phones) menu interface

=cut

sub menu_vxml {
    my ( $menu_group, $menu_start ) = @_;
    ( $menu_group, $menu_start ) = split ',', $menu_group
      unless defined $menu_start;

    ($menu_group) = &get_menu_default('default') unless $menu_group;
    $menu_start = $Menus{$menu_group}{_menu_list}[0] unless $menu_start;
    logit "$config_parms{data_dir}/logs/menu_vxml.log",
      "ip=$Socket_Ports{http}{client_ip_address} mg=$menu_group m=$menu_start";

    # Get a list of all menus, then build vxml forms
    my @menus = &menu_submenus( $menu_group, $menu_start, 99 );
    my @forms = &menu_vxml_forms( $menu_group, @menus );
    my $greeting = &vxml_audio(
        'greeting',                 'Welcome to Mister House',
        '/misc/tellme_welcome.wav', "#$menu_start"
    );
    my $vxml_vars = "<var name='prev_menu'/>\n<var name='prev_item'/>\n";
    return &vxml_page( $vxml_vars . $greeting . "@forms" );
}

sub menu_vxml_forms {
    my ( $menu_group, @menus ) = @_;
    my ( %menus, @forms );

    #   my $http_root =  "http://$config_parms{http_server}:$config_parms{http_port}/";
    my $http_root = '';    # Full url is no longer required :)

    for my $menu (@menus) {

        my ( $menu_parent, $prompt );
        if ( $menu =~ /^states/ ) {
            $prompt = "Speak $Menus{$menu_group}{$menu}{states}";
            $prompt =~ tr/,/ /;
        }
        else {
            $prompt      = "Speak a $menu command";
            $menu_parent = $Menus{$menu_group}{$menu}{parent};
        }

        my ( @grammar, @action, @goto );
        my $item = 0;
        for my $ptr ( @{ $Menus{$menu_group}{$menu}{items} } ) {
            my ( $grammar, $action, $goto );
            $grammar = $$ptr{D};

            # Action item
            if ( $$ptr{A} ) {

                # Multiple states
                if ( $$ptr{Dstates} ) {
                    $grammar = "$$ptr{Dprefix} $$ptr{Dsuffix}";
                    $goto    = "#$$ptr{Dstates_menu}";
                    $action .= qq|<assign name="prev_menu"  expr="'$menu'"/>\n|;
                    $action .= qq|<assign name="prev_item"  expr="'$item'"/>\n|;
                }

                # States menu
                elsif ( $$ptr{A} eq 'state_select' ) {

                    #                   $goto = "${http_root}sub?menu_run($menu_group,{prev_menu},{prev_item},$item,v)";
                    # db1x
                    $goto =
                      "${http_root}sub?menu_run($menu_group,' + prev_menu + ',' + prev_item + ',$item,v)";
                }

                # One state
                else {
                    $goto =
                      "${http_root}sub?menu_run($menu_group,$menu,$item,,v)";
                }
            }
            elsif ( $$ptr{R} ) {
                $goto = "${http_root}sub?menu_run($menu_group,$menu,$item,,v)";
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
        push @forms,
          &vxml_form(
            prompt  => $prompt,
            name    => $menu,
            prev    => $menu_parent,
            grammar => \@grammar,
            action  => \@action,
            goto    => \@goto
          );
    }
    return @forms;
}

=item C<menu_lcd_load>

This loads in a menu and refreshes the LCD display data

=cut

sub menu_lcd_load {
    my ( $lcd, $menu ) = @_;
    $menu = $$lcd{menu_name} unless $menu;
    $menu = $Menus{ $$lcd{menu_group} }{_menu_list}[0] unless $menu;
    return unless $menu;

    # Reset menu only if it is a new one (keep old cursor and state)
    unless ( $$lcd{menu_name} and $$lcd{menu_name} eq $menu ) {
        my $ptr = $Menus{ $$lcd{menu_group} }{$menu};
        my $i   = -1;
        for my $ptr2 ( @{ $$ptr{items} } ) {
            $$lcd{menu}[ ++$i ] = $$ptr2{D};
        }

        # Set initial cursor and display location to 0,0 if a new menu
        $$lcd{cx} = $$lcd{cy} = $$lcd{dy} = 0;
        $$lcd{menu_cnt}   = $i;
        $$lcd{menu_state} = -1;
        $$lcd{menu_ptr}   = $ptr;
        $$lcd{menu_name}  = $menu;
    }
    &menu_lcd_refresh($lcd);    # Refresh the display data
}

=item C<menu_lcd_refresh>

This will refresh the LCD Display records and position the cursor scroll line if needed

=cut

sub menu_lcd_refresh {
    my ($lcd) = @_;
    for my $i ( 0 .. $$lcd{dy_max} ) {

        my $row = $$lcd{dy} + $i;

        # Use a blank if there is no menu entry for this row
        my $data = ( $row <= $$lcd{menu_cnt} ) ? $$lcd{menu}[$row] : ' ';
        my $l = length $data;

        # Do extra stuff on cursor line
        if ( $row == $$lcd{cy} ) {

            # Set cursor marker
            $$lcd{cx} = $l if $$lcd{cx} > $l;
            substr( $data, $$lcd{cx}, 1 ) = '#';

            # If the line does not fit, center the text on the cursor
            my $x = 0;
            if ( $l > $$lcd{dx_max} ) {
                $x = $$lcd{cx} - $$lcd{dx_max} / 2;
                if ( $x > 1 ) {
                    $data = '<' . substr $data, $x;
                }
                else {
                    $x = 0;
                }
            }
        }
        substr( $data, $$lcd{dx_max}, 1 ) = '>'
          if length($data) > $$lcd{dx_max};
        $$lcd{display}[$i] = $data;
    }
    $$lcd{refresh} = 1;
}

=item C<menu_lcd_navigate>

Monitor keypad data (allow for computer keyboard simulation)

=cut

sub menu_lcd_navigate {
    my ( $lcd, $key ) = @_;
    $key = $$lcd{keymap}->{$key} if $$lcd{keymap}->{$key};

    my $menu = $$lcd{menu_name};
    my $ptr = $$lcd{menu_ptr}{items}[ $$lcd{cy} ] unless $menu eq 'response';

    # See if we need to scroll the display window
    if ( $key eq 'up' ) {
        $$lcd{cy}-- unless $$lcd{cy} == 0;
        if ( $$lcd{cy} < $$lcd{dy} ) {
            $$lcd{dy} = $$lcd{cy};
        }
        &menu_lcd_curser_state( $lcd, $$lcd{menu_ptr}{items}[ $$lcd{cy} ] )
          ;    # Move cursor to the same state
    }
    elsif ( $key eq 'down' ) {
        $$lcd{cy}++ unless $$lcd{cy} == $$lcd{menu_cnt};
        if ( $$lcd{cy} > ( $$lcd{dy} + $$lcd{dy_max} ) ) {
            $$lcd{dy} = $$lcd{cy} - $$lcd{dy_max};
        }
        &menu_lcd_curser_state( $lcd, $$lcd{menu_ptr}{items}[ $$lcd{cy} ] )
          ;    # Move cursor to the same state
    }
    elsif ( $key eq 'left' ) {

        # For action state menus, scroll to the previous state
        if ( $ptr and $$ptr{Dstates} ) {
            $$lcd{menu_state}--;
            &menu_lcd_curser_state( $lcd, $ptr );
        }
        else {
            $$lcd{cx} -= 5;
            $$lcd{cx} = 0 if $$lcd{cx} < 0;
        }
    }
    elsif ( $key eq 'right' ) {

        # For action state menus, scroll to the next state
        if ( $ptr and $$ptr{Dstates} ) {
            $$lcd{menu_state}++;
            &menu_lcd_curser_state( $lcd, $ptr );
        }
        else {
            my $l = length( $$lcd{menu}[ $$lcd{cy} ] );
            $$lcd{cx} += 5;
            $$lcd{cx} = $l if $$lcd{cx} > $l;
        }
    }
    elsif ( $key eq 'enter' ) {
        $Menus{menu_data}{last_response_object} = $lcd;

        # Run an action
        $Authorized = 'family';    # So &authority_check passes
        if ( $ptr and $$ptr{A} ) {

            #           my $response = &menu_run("$$lcd{menu_group},$menu,$$lcd{cy},$$lcd{menu_state},l");
            my $response =
              &menu_run( $$lcd{menu_group}, $menu, $$lcd{cy},
                $$lcd{menu_state}, 'l' );
            if ($response) {
                &menu_lcd_display( $lcd, $response, $menu );
            }
        }

        # Display a response
        elsif ( $ptr and $$ptr{R} ) {
            my $response =
              &menu_run( $$lcd{menu_group}, $menu, $$lcd{cy},
                $$lcd{menu_state}, 'l' );
            if ($response) {
                &menu_lcd_display( $lcd, $response, $menu );
            }
        }

        # Load next menu
        elsif ($ptr) {
            push @{ $$lcd{menu_history} }, $menu;
            push @{ $$lcd{menu_states} }, join $;, $$lcd{cx}, $$lcd{cy},
              $$lcd{dy}, $$lcd{menu_state};
            &menu_lcd_load( $lcd, $$ptr{D} );
        }

        # Nothing to do (e.g. response display)
        else {
        }
        return;
    }
    elsif ( $key eq 'exit' ) {
        if ( my $menu = pop @{ $$lcd{menu_history} } ) {
            &menu_lcd_load( $lcd, $menu );
            ( $$lcd{cx}, $$lcd{cy}, $$lcd{dy}, $$lcd{menu_state} ) =
              split $;, pop @{ $$lcd{menu_states} };
        }
    }
    else {
        return;    # Do not refresh the display if nothing changed
    }
    &menu_lcd_refresh($lcd);    # Refresh the display data data
}

sub menu_lcd_display {
    my ( $lcd, $response, $menu ) = @_;
    push @{ $$lcd{menu_history} }, $menu if $menu;
    push @{ $$lcd{menu_states} }, join $;, $$lcd{cx}, $$lcd{cy}, $$lcd{dy},
      $$lcd{menu_state};
    $Text::Wrap::columns = 20;

    #   @{$$lcd{display}} = split "\n", wrap('', '', $response);
    @{ $$lcd{menu} } = split "\n", wrap( '', '', $response );
    $$lcd{menu_cnt}  = @{ $$lcd{menu} } - 1;
    $$lcd{menu_name} = 'response';
    $$lcd{cx}        = $$lcd{cy} = $$lcd{dy} = 0;
    &menu_lcd_refresh($lcd);    # Refresh the display data data
}

sub menu_lcd_curser_state {
    my ( $lcd, $ptr ) = @_;

    # State = -1 means cursor at start of line
    if ( $$lcd{menu_state} < 0 ) {
        $$lcd{menu_state} = -1;
        $$lcd{cx}         = 0;
        return;
    }

    # Limit to maximium state
    if ( $$lcd{menu_state} > $#{ $$ptr{Dstates} } ) {
        $$lcd{menu_state} = $#{ $$ptr{Dstates} };
    }

    my $state_name = $$ptr{Dstates}[ $$lcd{menu_state} ];
    if ( $state_name and $$ptr{D} =~ /([\[,]\Q$state_name\E[,\]])/ ) {
        $$lcd{cx} = 1 + index $$ptr{D}, $1;
    }
}

=item C<menu_format_list>

Format a list of things, based on format

=cut

sub menu_format_list {
    my ( $format, @list ) = @_;

    if ( $format eq 'w' ) {
        return
            '<select><option>'
          . join( "</option>\n<option>", @list )
          . '</option></select>';
    }
    elsif ( $format eq 'h' ) {
        return join( "<br>\n", @list );
    }
    else {
        return join( "\n", @list );
    }
}

=item C<set_menu_default>

Call this to set default menus

=cut

sub set_menu_default {
    my ( $menu_group, $menu, $address ) = @_;
    $Menus{menu_data}{defaults}{$address} = join $;, $menu_group, $menu;
}

sub get_menu_default {
    my ($address) = @_;
    my ( $menu_group, $menus ) = split $;,
      $Menus{menu_data}{defaults}{$address};

    # Safeguard, in case the default was mis-specified.
    # Auto-generated mh.menu  group will always be there.
    $menu_group = 'mh' unless $Menus{$menu_group};
    return ( $menu_group, $menus );
}

return 1;

#
# $Log: menu_code.pl,v $
# Revision 1.16  2005/10/02 17:24:47  winter
# *** empty log message ***
#
# Revision 1.15  2005/01/23 23:21:46  winter
# *** empty log message ***
#
# Revision 1.14  2003/07/06 17:55:12  winter
#  - 2.82 release
#
# Revision 1.13  2003/03/09 19:34:42  winter
#  - 2.79 release
#
# Revision 1.12  2002/11/10 01:59:57  winter
# - 2.73 release
#
# Revision 1.11  2002/08/22 04:33:20  winter
# - 2.70 release
#
# Revision 1.10  2002/07/01 22:25:29  winter
# - 2.69 release
#
# Revision 1.9  2002/05/28 13:07:52  winter
# - 2.68 release
#
# Revision 1.8  2001/12/16 21:48:41  winter
# - 2.62 release
#
# Revision 1.7  2001/10/21 01:22:32  winter
# - 2.60 release
#
# Revision 1.6  2001/08/12 04:02:58  winter
# - 2.57 update
#
#

=back

=head2 INI PARAMETERS

NONE

=head2 AUTHOR

UNK

=head2 SEE ALSO

NONE

=head2 LICENSE

This program is free software; you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation; either version 2 of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more details.

You should have received a copy of the GNU General Public License along with this program; if not, write to the Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.

=cut

