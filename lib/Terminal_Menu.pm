
=begin comment
#############################################################################

FILE
    Terminal_Menu.pm

    
DESCRIPTION
    Module that interfaces with a console program running in a terminal 
    window and navigates a specified menu using numbered selections.
    This module was particularily designed for communicating with small 
    terminal screens over TCP/IP, such as when using SSH on a mobile phone 
    via GPRS.

    
USAGE
    Note: requires Misterhouse version 2.97 or newer! 
    (To make it run on older versions modify the &menu_run() lines 
    in Terminal_Menu.pm!) 

        
        use Terminal_Menu;
        
        $terminalmenu_server = new Socket_Item(undef, undef, 
                    'server_terminalmenu', undef, undef, undef, "\n");
        $terminalmenu = new Terminal_Menu('terminal-menu');
        
        if ($Reload) {
            my $menufile = "$config_parms{code_dir}/terminalmenu.menu";
            menu_create $menufile;
            menu_parse scalar file_read($menufile), 'terminal-menu';
            $terminalmenu->tie_event("set \$terminalmenu_server \$state");
        }
        
        my $incoming_data;
        if (defined($incoming_data = said $terminalmenu_server)) {
            $terminalmenu->set($incoming_data);
        }
        
        $terminalmenu->loop();

    
    Note: don't forget to specify the port number in your mh.private.ini:
    
        server_terminalmenu_port=29974

        
    See  code/common/terminal_menu.pl  for a more elaborate implementation 
    that can handle multiple clients at once (the code above also 
    accepts multiple clients, but all clients act on the same menu...).


    
TECHNICAL INFO: THE TERMINAL_MENU PROTOCOL
    Terminal_Menu.pm communicates with a client program (e.g 
    terminalmenu-client.pl) with a simple command structure.
    
    One command is sent per line (i.e. commands are terminated with "\n").
    Commands are case insensitive.
    
    
    Commands from Terminal_Menu.pm to the client:

        GETSIZE
            Asks the client to return its current size (width and height in 
            number of characters). The client answers with a "SIZE" command.
        
        CLEARSCREEN
            Clears the terminal window of the client and positions the 
            cursor on the left top (0, 0).
        
        CURSORPOS x y
            Positions the cursor at a given position x and y. A subsequent
            "PRINT" command outputs at the new location.
            The left-top of the terminal window is (x=0, y=0).
        
        PRINT "text" "color-string"
            Causes the client to print "text" to the terminal window, using
            the color spcified in "color-string". The format of "color-string"
            is described in Term::ANSIColor.
        
        NEWLINE
            Causes the client to print "\n". The cursor position is updated
            accordingly.
        
        EXIT
            Asks the client to terminate immediately.
    
    
    Commands from the client to Terminal_Menu.pm:
        
        [0..9,*,#,-]
            The corresponding key has been pressed on the client.
            
        ENTER
            The enter key has been pressed on the client.
        
        UP, DOWN, LEFT, RIGHT
            The corresponding arrow key has been pressed on the client.
        
        SIZE x y
            Informs Terminal_Menu of the size of the client's terminal 
            window. Sent by the client immediately after startup and
            whenever the size of the terminal has changed.
    

BUGS / TODO
    -)  No authentication support
    
    -)  Add timeout to close inactive connectsions
    
    -)  When actions are triggered in multiple clients at the same time
        then the response may be sent to the wrong client. This has to do
        with Misterhouse' architecture.
    
    -)  The loop() method needs to be called once a misterhouse-loop. This
        is an ugly hack but necessary due to make responses work properly
        (other menu libraries supplied with Misterhouse are using the same
        hack)


AUTHOR
    Werner Lane
    wl-opensource@gmx.net


LICENSE
    This free software is licensed under the terms of the GNU public license.


SPECIAL THANKS TO
    Bruce Winter - MH
    Jason Sharpee - Numbered_Menu.pm, which this code is based on.
    Everyone contributing to Misterhouse
    Everyone else using Misterhouse

#############################################################################
=cut

use strict;

package Terminal_Menu;

@Terminal_Menu::ISA = qw(Generic_Item);

use Text::Wrap qw(wrap $columns);

# Enable debugging by setting $::Debug{'Terminal_Menu'} to a value >1:
#  1: only external methods and important messages
#  2: internal methods

# $::Debug{'Terminal_Menu'} = 2;

use constant HELPTEXT => <<"__EOT__";
[1]..[9] Select a menu entry

[*] Toggle full screen response view. When in full screen mode, use [8] or [2] to scroll

[0] Back to the previous menu

[#] Quit 

[ENTER] Show next page of the current menu (in case not all menu entries fit on the screen at once)


Alternatively you can use arrow keys to navigate: 

UP/DOWN: Next/previous page of the menu or response 

LEFT: Back to the previous menu
__EOT__

#****************************************************************************
#****************************************************************************
# Public methods
#****************************************************************************
#****************************************************************************

#############################################################################
# new($p_menugroup)
#
# Creates a new Terminal Menu instance.
#
# Parameters:
#  $p_menugroup: The name of the menu (must have already been loaded).
#                If not specified, the name 'default' is used.
#############################################################################
sub new {
    my ( $class, $p_menugroup ) = @_;
    my $self = {};

    bless $self, $class;

    $$self{menugroup} = $p_menugroup || 'default';

    # User configurable elements (via set())
    $$self{useborder}            = 1;
    $$self{usecolor}             = 1;
    $$self{color_header}         = 'bold red';
    $$self{color_menu}           = '';
    $$self{color_choice_label}   = 'magenta';
    $$self{color_choice}         = 'reverse bold magenta';
    $$self{color_response_label} = 'bold green';
    $$self{color_response}       = '';
    $$self{color_border}         = '';

    # end of user configurable elements

    $$self{terminal_width}  = 80;
    $$self{terminal_height} = 25;
    $$self{cursor_x}        = 0;
    $$self{cursor_y}        = 0;
    $$self{border}          = 1;    # Internal flag indicating whether a border
                                    #  should be drawn around the menu.
                                    #  Composite of 'border' flag and terminal
                                    #  size.

    $$self{menuDepth}   = 0;        # Current depth
    $$self{currentmenu} = [];       # All entries of the current menu
    $$self{menu_offset} = 0;        # offset for multi page menu scrolling
    $$self{menu_morepages} =
      0;    # 1 = there is more than one page for the current menu
    $$self{menu_elements} = 0;    # number of menu elements that currently
                                  #  fit on one screen

    $$self{key_layout} = 'phone'; # Defines the layout of the number pad

    $$self{choice}   = undef;     # last selected menu entry
    $$self{response} = undef;     # last response from Misterhouse

    $$self{zoomed}           = 0; # 1 = Response is zoomed (full screen)
    $$self{zoomed_offset}    = 0; # offset for multi page response scrolling
    $$self{zoomed_morepages} = 0; # Flag indicating whether there are more
                                  #  pages left to show in the full screen
                                  #  response view

    $$self{cmd} = '';   # Temporary buffer for the strings towards the terminal.
    $$self{last_response_loop} = 0;

    &::print_log(
        "Terminal_Menu.pm: new \$p_menugroup=$p_menugroup \$self=$self")
      if $::Debug{'Terminal_Menu'};

    # The first thing that the terminalmenu-client does is send the screen
    # size; hence we only update when we received the "SIZE w h" info via
    # $self->set().

    #     $$self{menus} = $main::Menus{$$self{menugroup}};
    #     my $menu = $$self{menus};
    #
    #     $$self{menuCurrent} = ${$$menu{_menu_list}}[0];

    #     $self->_select_menu(${$$menu{_menu_list}}[0]);

    return $self;
}

#############################################################################
# set($state, $setby)
#
# This function handles input from the connected terminal.
# $state is either a single character (= key pressed by the user), or a
# string forming a command.
#
# The following commands are available:
#
#   UP, DOWN, LEFT, RIGHT, ENTER
#     The arrow keys or ENTER key has been pressed on the keyboard.
#
#   SIZE width height
#     Width and Height of the terminal window. Sent by terminalmenu-client.pl
#     after startup or when the terminal has been resized.
#
#   BORDER 0|1
#     Switches the border around the menu on/off. Note that the border is
#     automatically turned off when the terminal size is less than 22x17
#     characters.
#
#   COLOR 0|1
#     Switches color of the menu on/off.
#
#   COLOR element color-string
#     Allows the user to change colors of individual elements of the menu.
#     Elements that can be modified:
#       HEADER          menu heading
#       MENU            individual menu entries
#       CHOICE          last chosen menu entry
#       CHOICE_LABEL    label "Your choice:"
#       RESPONSE        response of the last selected menu entry
#       RESPONSE_LABEL  label for the response
#       BORDER          border color
#     'color-string' is a string comprising of the following values:
#       clear, reset, dark, bold, underline, underscore, blink, reverse,
#       concealed, black, red, green, yellow, blue, magenta, on_black,
#       on_red, on_green, on_yellow, on_blue, on_magenta, on_cyan, on_white
#     Note that not all values may be supported by the terminal. Please refer
#     to the documentation of Term::ANSIColor for details.
#
#   NUMPAD-LAYOUT pc|phone
#     Telephones and PC utilize a different layout of the number pad: PC have
#     numbers 7/8/9 in the top row, while (mobile) phones have 1/2/3.
#     Since the numbers 2 and 8 are used to scroll in zoomed mode,
#     for sake of user friendlyness it is important to know whether the
#     client is a PC or a phone so that the proper scroll keys can be used.
#     Default value is 'phone'.
#
#############################################################################
sub set {
    my ( $self, $state, $setby ) = @_;

    &::print_log("Terminal_Menu.pm: set \$state=$state, \$setby=$setby)")
      if $::Debug{'Terminal_Menu'};

    my $updatescreen = 0;

    # Menu loaded properly? If not, try to load it now
    # This is necessary because the menu may not have parsed yet when
    # the module is instantiated -- although not the cleanest design...
    if ( not defined $$self{menus} ) {
        $$self{menus} = $main::Menus{ $$self{menugroup} };
        my $menu = $$self{menus};
        $$self{menuCurrent} = ${ $$menu{_menu_list} }[0];
        $updatescreen = 1;
    }

    if ( $state =~ m/^SIZE\s+(\d+)\s+(\d+)\s*$/i ) {
        $$self{terminal_width}  = $1;
        $$self{terminal_height} = $2;
        $$self{border} =
          (       $$self{useborder}
              and $$self{terminal_width} >= 22
              and $$self{terminal_height} >= 18 ) ? 1 : 0;
        $updatescreen = 1;
    }
    elsif ( $state =~ m/^BORDER\s+(\d+)\s*$/i ) {
        $$self{useborder} = $1;
        $$self{border} =
          (       $$self{useborder}
              and $$self{terminal_width} >= 22
              and $$self{terminal_height} >= 18 ) ? 1 : 0;
        $updatescreen = 1;
    }
    elsif ( $state =~ m/^COLOR\s+(\d+)\s*$/i ) {
        $$self{usecolor} = $1;
        $updatescreen = 1;
    }
    elsif ( $state =~ m/^COLOR\s+(\S+)\s+(.+)$/i ) {
        my ( $entry, $color ) = ( $1, $2 );

        my @colorcodes =
          qw(clear reset dark bold underline underscore blink reverse concealed black red green yellow blue magenta on_black on_red on_green on_yellow on_blue on_magenta on_cyan on_white);
        foreach my $c ( split( /\s/, $color ) ) {
            if ( not grep( /$c/i, @colorcodes ) ) {
                &::print_log(
                    "Terminal_Menu.pm: Color string \"$color\" not valid ($state). Please consult documentation of Term\:\:ANSIColor."
                );
                return;
            }
        }

        if ( exists $$self{ 'color_' . lc($entry) } ) {
            $$self{ 'color_' . lc($entry) } = $color;
        }
        else {
            &::print_log(
                "Terminal_Menu.pm: Color entry \"$entry\" not valid ($state).");
        }
    }
    elsif ( $state =~ m/^NUMPAD-LAYOUT\s+(\S+)\s*$/i ) {
        $$self{key_layout} = lc($1);
    }
    elsif ( $state eq "#" or $state eq "-" ) {
        $self->_send_to_terminal("clearscreen");
        $self->_send_to_terminal("print \"Bye bye!\" \"$$self{color_header}\"");
        $self->_send_to_terminal("newline");
        $self->_send_to_terminal("exit");
        $self->_flush_terminal();
    }
    elsif ( $$self{zoomed} ) {
        $self->_handle_zoomed($state);
    }
    else {
        $self->_handle_normal($state);
    }

    if ($updatescreen) {
        if ( $$self{zoomed} ) {
            $self->_draw_screen();
        }
        else {
            $self->_select_menu( $$self{menuCurrent} );
        }
    }
}

#############################################################################
# loop()
#
# This function must be called at least once a Misterhouse-loop, otherwise
# responses will not be shown properly.
#
# This is a dirty hack but necessary due to the current architecture of
# Misterhouse (or at least as I understand it... LCD menu and Numbered_Menu
# use the same hack)
#############################################################################
sub loop {
    my ($self) = @_;

    if (    $$self{last_response_loop}
        and $$self{last_response_loop} <= $main::Loop_Count )
    {
        $$self{last_response_loop} = 0;

        $self->_response( &main::last_response() );
    }
}

#****************************************************************************
#****************************************************************************
# Private methods
#****************************************************************************
#****************************************************************************

#############################################################################
# _select_menu($p_menu)
#
# Selects and draws a menu level given by $p_menu onto the terminal.
#############################################################################
sub _select_menu {
    my ( $self, $p_menu ) = @_;

    &::print_log("Terminal_Menu.pm: _select_menu \$self=$self \$p_menu=$p_menu")
      if $::Debug{'Terminal_Menu'} > 1;

    if ( not defined $p_menu ) {
        &::print_log(
            "Terminal_Menu.pm: _select_menu: Menu not defined. Did you forget to load it? Does the menu file exist at all?"
        );
        $self->_send_to_terminal(
            "print \"Menu undefined; Please check your Misterhouse configuration.\" \"bold red\""
        );
        $self->_send_to_terminal("newline");
        $self->_flush_terminal();
        return;
    }

    my $menus = $$self{menus};

    $$self{menuCurrent} = $p_menu;
    ${ $$self{menuList} }[ $$self{menuDepth} ] = $p_menu;

    return
      unless defined $$menus{ $$self{menuCurrent} };   # Guard against bad menus
    $$self{itemCount} = @{ $$menus{ $$self{menuCurrent} }{items} };

    my $menu_name = undef;
    if ( $$self{menuCurrent} =~ /^states/ ) {
        my $l_menuPrevious = ${ $$self{menuList} }[ $$self{menuDepth} - 1 ];
        my $l_itemPrevious = ${ $$self{itemList} }[ $$self{menuDepth} - 1 ];
        my $item = ${ $$menus{$l_menuPrevious}{items} }[ $l_itemPrevious - 1 ];

        if ( $$item{A} and $$item{Dstates} ) {
            $menu_name = $$item{Dprefix} . '...' . $$item{Dsuffix};
        }
    }
    else {
        $menu_name = $$self{menuCurrent};
    }

    if ( defined $menu_name ) {
        $$self{response}       = undef;
        $$self{choice}         = undef;
        $$self{menu_morepages} = 0;
        $$self{menu_offset}    = 0;

        $menu_name =~ s/_/ /g;    # Replace '_' with spaces
        $$self{currentmenu} = [$menu_name];

        my $i = 0;
        my $item_name;
        while ( $i < $$self{itemCount} ) {
            my $item = ${ $$menus{ $$self{menuCurrent} }{items} }[$i];
            if ( $$item{A} and $$item{Dstates} ) {
                $item_name = $$item{Dprefix} . '...' . $$item{Dsuffix};
            }
            else {
                $item_name = $$item{D};
            }

            $item_name =~ s/_/ /g;    # Replace '_' with spaces
            push @{ $$self{currentmenu} }, $item_name;
            $i++;
        }

        $self->_draw_screen();
    }
}

#############################################################################
# _select_item($p_item)
#
# Selects item with index $p_item from the current menu.
#############################################################################
sub _select_item {
    my ( $self, $p_item ) = @_;

    &::print_log("Terminal_Menu.pm: _select_item \$self=$self \$p_item=$p_item")
      if $::Debug{'Terminal_Menu'} > 1;

    return if ( !$p_item || $p_item > $$self{itemCount} );

    my $menus = $$self{menus};

    $$self{response}    = undef;
    $$self{itemCurrent} = $p_item;
    ${ $$self{itemList} }[ $$self{menuDepth} ] = $p_item;
    my $item = ${ $$menus{ $$self{menuCurrent} }{items} }[ $p_item - 1 ];

    ###############
    # Action
    if ( $$item{A} ) {
        if ( $$item{Dstates} ) {
            $$self{menuDepth}++;
            $self->_select_menu( $$item{'Dstates_menu'} );
        }
        elsif ( $$item{A} eq 'state_select' ) {
            my $l_item = $p_item - 1;
            my $l_itemPrevious =
              ${ $$self{itemList} }[ $$self{menuDepth} - 1 ] - 1;
            my $l_menuPrevious = ${ $$self{menuList} }[ $$self{menuDepth} - 1 ];

            #           my $response = &::menu_run("$$self{menugroup},$l_menuPrevious,$l_itemPrevious,$l_item,l");      # v2.96 and lower
            my $response =
              &::menu_run( $$self{menugroup}, $l_menuPrevious, $l_itemPrevious,
                $l_item, 'l' );    # v2.97 and higher
            if ($response) {
                $self->_response($response);
            }
            else {
                $$self{last_response_loop} = $::Loop_Count + 3;
            }
        }
        else {
            my $l_item = $$self{itemCurrent} - 1;

            #           my $response = &::menu_run("$$self{menugroup},$$self{menuCurrent},$l_item,,l");           # v2.96 and lower
            my $response =
              &::menu_run( $$self{menugroup}, $$self{menuCurrent}, $l_item,
                undef, "l" );    # v2.97 and higher
            if ($response) {
                $self->_response($response);
            }
            else {
                $$self{last_response_loop} = $::Loop_Count + 3;
            }
        }
    }
    ###############
    # Response
    elsif ( $$item{R} ) {
        my $l_item = $$self{itemCurrent} - 1;

        #       my $response = &::menu_run("$$self{menugroup},$$self{menuCurrent},$l_item,,l");           # v2.96 and lower
        my $response =
          &::menu_run( $$self{menugroup}, $$self{menuCurrent}, $l_item, undef,
            "l" );    # v2.97 and higher
        if ($response) {
            $self->_response($response);
        }
        else {
            $$self{last_response_loop} = $::Loop_Count + 3;
        }
    }
    ###############
    # Menu
    else {
        $$self{menuDepth}++;
        $self->_select_menu( $$item{D} );
    }
}

#############################################################################
# _exit_menu()
#
# Goes a level up in the menu hierachy.
#############################################################################
sub _exit_menu {
    my ($self) = @_;

    &::print_log("Terminal_Menu.pm: _exit_menu \$self=$self")
      if $::Debug{'Terminal_Menu'} > 1;

    --$$self{menuDepth} if ( $$self{menuDepth} > 0 );
    $self->_select_menu( ${ $$self{menuList} }[ $$self{menuDepth} ] );
}

#############################################################################
# _response()
#
# Shows the response of the selected action on the terminal.
#############################################################################
sub _response {
    my ( $self, $response ) = @_;

    &::print_log(
        "Terminal_Menu.pm: _response \$self=$self \$response=$response")
      if $::Debug{'Terminal_Menu'} >= 2;

    $$self{response} = $response;

    # When the response contains more than 1 line or is wider than the
    # terminal window then show it in "zoom mode" immediately
    if (
        defined $$self{response}
        and ( $$self{response} =~ m/\n/s
            or length( $$self{response} ) > $$self{terminal_width} )
      )
    {
        $$self{zoomed}        = 1;
        $$self{zoomed_offset} = 0;
        $self->_draw_screen();
    }
    else {
        $self->_draw_choice() unless $$self{zoomed};
        $self->_draw_response();
        $self->_flush_terminal();
    }
}

#############################################################################
# _handle_normal()
#
# Handles user input from the terminal when the response is not zoomed (full
# screen).
#############################################################################
sub _handle_normal {
    my ( $self, $cmd ) = @_;

    my $scroll_by = $$self{terminal_height} - 5;
    $scroll_by = 1 if $scroll_by < 1;
    $scroll_by = 9 if $scroll_by > 9;

    if ( $cmd eq "*" ) {
        $$self{zoomed}        = 1;
        $$self{zoomed_offset} = 0;
        $self->_draw_screen();
    }
    elsif ( $cmd eq "ENTER" or $cmd eq "DOWN" or $cmd eq "RIGHT" ) {
        if ( $$self{menu_morepages} ) {
            $$self{menu_offset} += $scroll_by;
            $$self{menu_offset} = 0
              if ( $$self{menu_offset} >
                ( scalar( @{ $$self{currentmenu} } ) - 2 ) );
            $self->_draw_screen();
        }
    }
    elsif ( $cmd eq "UP" ) {
        if ( $$self{menu_morepages} ) {
            $$self{menu_offset} -= $scroll_by;
            $$self{menu_offset} = 0 if ( $$self{menu_offset} < 0 );
            $self->_draw_screen();
        }
    }
    elsif ( $cmd eq "0" or $cmd eq "LEFT" ) {
        $self->_exit_menu();
    }
    elsif ( $cmd =~ m/^[1-9]$/ ) {
        $$self{choice} = $cmd;
        if ( not $$self{menu_morepages} or $cmd <= $$self{menu_elements} ) {
            $cmd += $$self{menu_offset};
            $self->_select_item($cmd);
        }
    }
}

#############################################################################
# _handle_zoomed()
#
# Handles user input from the terminal when the response is zomed (full
# screen).
#############################################################################
sub _handle_zoomed {
    my ( $self, $cmd ) = @_;

    my $scroll_by = $$self{terminal_height} - 2;
    $scroll_by -= 2 if $$self{border};
    $scroll_by = 1 if $scroll_by < 1;

    my ( $up, $down ) = ( '', '' );
    ( $up, $down ) = ( '8', '2' ) if $$self{key_layout} eq 'pc';
    ( $up, $down ) = ( '2', '8' ) if $$self{key_layout} eq 'phone';

    if ( $cmd eq '*' or $cmd eq '0' or $cmd eq 'LEFT' ) {
        $$self{zoomed} = 0;
        $self->_draw_screen();
    }
    elsif ( $cmd eq $up or $cmd eq 'UP' ) {
        $$self{zoomed_offset} -= $scroll_by;
        $$self{zoomed_offset} = 0 if ( $$self{zoomed_offset} < 0 );
        $self->_draw_screen();
    }
    elsif ( $cmd eq $down or $cmd eq 'DOWN' ) {
        if ( $$self{zoomed_morepages} ) {
            $$self{zoomed_offset} += $scroll_by;
            $self->_draw_screen();
        }
    }
}

#############################################################################
# _draw_screen()
#
# Redraws the complete screen.
#############################################################################
sub _draw_screen {
    my ($self) = @_;

    $self->_send_to_terminal("clearscreen");
    $self->_draw_border();
    $self->_draw_menu()   unless $$self{zoomed};
    $self->_draw_choice() unless $$self{zoomed};
    $self->_draw_response();
    $self->_flush_terminal();
}

#############################################################################
# _draw_border()
#
# Draws the border around the menu if enabled.
#############################################################################
sub _draw_border {
    my ($self) = @_;

    return unless $$self{border};

    $self->_draw_v_line(0);
    $self->_draw_v_line( $$self{terminal_width} - 1 );
    $self->_draw_h_line(0);
    $self->_draw_h_line( $$self{terminal_height} - 1 );

    if ( not $$self{zoomed} ) {
        my $y = $$self{terminal_height} - 2;
        $y = 14 if $y > 14;
        $self->_draw_h_line($y);
    }
}

#############################################################################
# _draw_h_line($y)
#
# Draws a horizontal line at $y (first line = 0).
#############################################################################
sub _draw_h_line {
    my ( $self, $y ) = @_;

    my $line = '+' . ( '-' x ( $$self{terminal_width} - 2 ) ) . '+';

    $self->_send_to_terminal("cursorpos 0 $y");
    $self->_send_to_terminal("print \"$line\" \"$$self{color_border}\"");
}

#############################################################################
# _draw_v_line($x)
#
# Draws a horizontal line at $x (first column = 0).
#############################################################################
sub _draw_v_line {
    my ( $self, $x ) = @_;

    foreach ( 0 .. ( $$self{terminal_height} - 1 ) ) {
        $self->_send_to_terminal("cursorpos $x $_");
        $self->_send_to_terminal("print \"|\" \"$$self{color_border}\"");
    }
}

#############################################################################
# _draw_menu()
#
# Draws the current menu. If the menu does not fit on the screen it is
# split into several pages.
#############################################################################
sub _draw_menu {
    my ($self) = @_;

    my @menu = @{ $$self{currentmenu} };

    my $max_menu_height = $$self{terminal_height} - 4;
    $max_menu_height = 1 if $max_menu_height < 1;

    my $header = shift @menu;

    my ( $x, $y ) = $$self{border} ? ( 1, 1 ) : ( 0, 0 );

    $self->_send_to_terminal("cursorpos $x $y");
    $self->_send_to_terminal("print \"$header\" \"$$self{color_header}\"");
    ++$y;

    --$max_menu_height if ( $max_menu_height < scalar @menu );
    $max_menu_height = 1 if $max_menu_height < 1;
    $max_menu_height = 9 if $max_menu_height > 9;

    my $i       = 0;
    my $element = 1;
    foreach my $entry (@menu) {
        next if ( $i++ < $$self{menu_offset} );
        $entry = $self->_pad_and_trim( $entry, 5 );
        $self->_send_to_terminal("cursorpos $x $y");
        $self->_send_to_terminal(
            "print \" [$element] $entry\" \"$$self{color_menu}\"");
        ++$y;
        last if $element >= $max_menu_height;
        $element++;
    }

    $$self{menu_morepages} = 0;
    if ( $element < scalar @menu ) {
        $$self{menu_morepages} = 1;
        $$self{menu_elements}  = $element;
        $self->_send_to_terminal("cursorpos $x $y");
        $self->_send_to_terminal(
            "print \" [ENTER]=more...\" \"$$self{color_menu}\"");
    }
}

#############################################################################
# _draw_choice()
#
# Draws the prompt "Your choice" below the menu.
#############################################################################
sub _draw_choice {
    my ($self) = @_;

    my $choice_x = $$self{border} ? 1 : 0;
    my $choice_y = $$self{terminal_height} - 3;
    $choice_y = 12 if $choice_y > 12;
    $choice_y += 1 if $$self{border};

    if ( $choice_y < 3 ) {
        if ( defined $$self{choice} ) {
            $self->_send_to_terminal(
                "cursorpos " . ( $$self{terminal_width} - 1 ) . " 0" );
            $self->_send_to_terminal(
                "print \"$$self{choice}\" \"$$self{color_choice}\"");
            $self->_send_to_terminal("cursorpos $$self{terminal_width} 0");
        }
    }
    else {
        $self->_send_to_terminal("cursorpos $choice_x $choice_y");
        $self->_send_to_terminal(
            "print \"Your choice: \" \"$$self{color_choice_label}\"");
        if ( defined $$self{choice} ) {
            my ( $x, $y ) = ( $$self{cursor_x}, $$self{cursor_y} );
            $self->_send_to_terminal(
                "print \"$$self{choice}\" \"$$self{color_choice}\"");
            $self->_send_to_terminal("cursorpos $x $y");
        }
    }
}

#############################################################################
# _draw_response()
#
# Draws the response of the last action on the screen, either below the
# menu or full screen. If no response is pending then the help message
# is shown.
#############################################################################
sub _draw_response {
    my ($self) = @_;

    $$self{zoomed}
      ? $self->_draw_zoomed_response()
      : $self->_draw_normal_response();
}

#############################################################################
# _draw_normal_response()
#
# Draws the first line of the response of the last action on the screen
# below the menu. If no response is pending than a message "Press [*] for
# help" is shown.
#############################################################################
sub _draw_normal_response {
    my ($self) = @_;

    my $response_x = $$self{border} ? 1 : 0;
    my $response_y = $$self{terminal_height} - 2;
    $response_y = 14 if $response_y > 14;
    $response_y += 1 if $$self{border};

    my $response = $$self{response};
    my $heading  = 'Result:';

    if ( not defined $response ) {
        $heading  = 'Press [*] for help';
        $response = '';
    }
    else {
        # If the text contains multiple lines just show the first one, but
        # add an indication that there is more text
        if ( $response =~ m/\n/s ) {
            $response =~ s/\n.*//s;
            $response .= ' ...';
            $heading = "Result: [*]=zoom";
        }
        elsif ( length($response) > $$self{terminal_width} ) {
            $heading = "Result: [*]=zoom";
        }
    }

    $heading  = $self->_pad_and_trim($heading);
    $response = $self->_pad_and_trim($response);

    my ( $x, $y ) = ( $$self{cursor_x}, $$self{cursor_y} );
    $self->_send_to_terminal("cursorpos $response_x $response_y");
    $self->_send_to_terminal(
        "print \"$heading\" \"$$self{color_response_label}\"");
    $response_y += 1;
    $self->_send_to_terminal("cursorpos $response_x $response_y");
    $self->_send_to_terminal("print \"$response\" \"$$self{color_response}\"");
    $self->_send_to_terminal("cursorpos $x $y");
}

#############################################################################
# _draw_zoomed_response()
#
# Draws the response of the last action or help message on the screen using
# all available space. If the text does not fit on the screen it is split
# into several pages.
#############################################################################
sub _draw_zoomed_response {
    my ($self) = @_;

    my $response_x = $$self{border} ? 1 : 0;
    my $response_y = $$self{border} ? 1 : 0;

    my $response = defined $$self{response} ? $$self{response} : HELPTEXT;

    my ( $up, $down ) = ( '', '' );
    ( $up, $down ) = ( '8', '2' ) if $$self{key_layout} eq 'pc';
    ( $up, $down ) = ( '2', '8' ) if $$self{key_layout} eq 'phone';

    $self->_send_to_terminal("cursorpos $response_x $response_y");
    $self->_send_to_terminal(
        "print \"Result: [*]=back\" \"$$self{color_response_label}\"");

    $Text::Wrap::columns = $$self{terminal_width} - ( $$self{border} ? 2 : 0 );
    my @lines = split( "\n", Text::Wrap::wrap( '', '', $response ) );

    my $i = 0;
    foreach my $line (@lines) {
        next if ( $i++ < $$self{zoomed_offset} );
        $response_y++;
        $self->_send_to_terminal("cursorpos $response_x $response_y");
        $self->_send_to_terminal("print \"$line\" \"$$self{color_response}\"");
        last
          if ( $$self{cursor_y} >=
            $$self{terminal_height} - 1 - ( $$self{border} ? 1 : 0 ) );
    }

    if ( $$self{zoomed_offset} ) {
        $self->_send_to_terminal(
            "cursorpos " . ( $$self{terminal_width} - 3 ) . " 0" );
        $self->_send_to_terminal("print \"[$up]\" \"$$self{color_border}\"");
        $self->_send_to_terminal(
            "cursorpos " . ( $$self{terminal_width} - 2 ) . " 0" );
    }

    $$self{zoomed_morepages} = 0;
    if ( $i < scalar @lines ) {
        $$self{zoomed_morepages} = 1;
        $self->_send_to_terminal( "cursorpos "
              . ( $$self{terminal_width} - 3 ) . " "
              . ( $$self{terminal_height} - 1 ) );
        $self->_send_to_terminal("print \"[$down]\" \"$$self{color_border}\"");
        $self->_send_to_terminal( "cursorpos "
              . ( $$self{terminal_width} - 2 ) . " "
              . ( $$self{terminal_height} - 1 ) );
    }
}

#############################################################################
# _pad_and_trim($text, $indent)
#
#
#
#############################################################################
sub _pad_and_trim {
    my ( $self, $text, $indent ) = @_;

    $indent = 0 if not defined $indent;

    $text .= ' ' x
      ( $$self{terminal_width} - length($text) - ( $$self{border} ? 1 : 0 ) );
    $text = substr( $text, 0,
        $$self{terminal_width} - $indent - ( $$self{border} ? 2 : 0 ) );

    return $text;
}

#############################################################################
# _send_to_terminal($cmd)
#
# Puts the given terminal commands into a buffer. It also updates the
# cursor position accordingly.
#############################################################################
sub _send_to_terminal {
    my ( $self, $cmd ) = @_;

    if ( $cmd =~ m/^clearscreen$/i ) {
        $$self{cursor_x} = 0;
        $$self{cursor_y} = 0;
    }
    elsif ( $cmd =~ m/^cursorpos\s+(\d+)\s+(\d+)$/i ) {
        $$self{cursor_x} = $1;
        $$self{cursor_y} = $2;
    }
    elsif ( $cmd =~ m/^print\s+\"(.*?)\"\s+\"(.*?)\"$/i ) {
        $$self{cursor_x} += length($1);
        my $text = $1;
        my $color = $$self{usecolor} ? $2 : '';

        if ( $$self{cursor_x} > $$self{terminal_width} ) {
            my $x = $$self{cursor_x} - $$self{terminal_width};
            $text = substr $text, 0, -$x;
        }
        $cmd = "print \"$text\" \"$color\"";
    }
    elsif ( $cmd =~ m/^newline$/i ) {
        $$self{cursor_x} = 0;
        $$self{cursor_y}++;
    }

    $$self{cmd} .= $cmd . "\n";
}

#############################################################################
# _flush_terminal()
#
# Sends any pending commands to the terminal.
#############################################################################
sub _flush_terminal {
    my ($self) = @_;

    chomp $$self{cmd};
    $self->set_states_for_next_pass( $$self{cmd} );
    $$self{cmd} = '';
}

#############################################################################
# DESTROY()
#
# Called when the object is removed (e.g. the terminal closed).
#############################################################################
sub DESTROY {
    my ($self) = @_;
    &::print_log("Terminal_Menu.pm: DESTROY \$self=$self)")
      if $::Debug{'Terminal_Menu'};
}

&::print_log("Terminal_Menu.pm: Module loaded") if $::Debug{'Terminal_Menu'};
1;

