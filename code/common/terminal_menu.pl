# Category = MisterHouse

#@ Use a small terminal window (e.g. SSH on a mobile phone) to walk menus
#@ using the Terminal_Menu module.
#@ Use keys 1 to 9 to select menu entries, key 0 to go back in the menu
#@ hierarchy and key # to terminate the menu.

#############################################################################

=begin comment

INTRODUCTION
    This code enables users to browse Misterhouse menus in a terminal window 
    (or 'command line' for you Windows users).
    
    A menu looks something like this in the terminal:

                    +----------------------------+
                    |mh                          |
                    | [1] Appliances             |
                    | [2] Entertainment          |
                    | [3] Light                  |
                    | [4] MisterHouse            |
                    | [5] News                   |
                    | [6] Time                   |
                    | [7] Timers                 |
                    |                            |
                    |                            |
                    |                            |
                    |                            |
                    |Your choice:                |
                    +----------------------------+
                    |Press [*] for help          |
                    |                            |
                    |                            |
                    +----------------------------+

    I designed it so I can use SSH over GPRS on my mobile phone to access my
    Misterhouse installation. (I do not trust direct web/wap access but rather
    prefer the security of SSH; telnet.pl is too keyboard heavy for a 
    mobile phone).


TERMINAL_MENU COMPONENTS
    -)  User code (this file; $Pgm_Root/code/common/terminal_menu.pl)
    -)  The Terminal_Menu module ($Pgm_Root/lib/Terminal_Menu.pm)
    -)  A console program that connects to Misterhouse via TCP/IP 
        ($Pgm_Root/bin/terminalmenu-client.pl)
    
    NOTE: Terminal_Menu requires Misterhouse version 2.97 or newer! 
    (To make it run on older versions modify the &menu_run() lines in 
    Terminal_Menu.pm!) 

    
ADDING TERMINAL_MENU TO YOUR MISTERHOUSE INSTALLATION
    -)  If these files were not received with a Misterhouse package, copy
        them to the appropriate location in your Misterhouse installation:
        
        terminal_menu.pl       -> $Pgm_Root/code/common/terminal_menu.pl
                                  (or your private $code_dir)
        Terminal_Menu.pm       -> $Pgm_Root/lib/Terminal_Menu.pm
        terminalmenu-client.pl -> $Pgm_Root/bin/terminalmenu-client.pl
                                    (or better: anywhere in your PATH)
    
    -)  Create a menu file 'terminalmenu.menu' in your $code_dir and edit it.
        (NOTE: make sure to set the authority for all menu entries to 'anyone'!
        Please consult the Misterhouse documentation on how to create menus.)
    
    -)  Enable terminal_menu.pl by adding it to $data_dir/code_select.txt
    
    -)  Add the TCP/IP port for the server to your mh.private.ini:
        
            server_terminalmenu_port=29974
    
    -)  Restart Misterhouse
    
    -)  Launch terminalmenu-client.pl on the same machine that Misterhouse is 
        running. It will connect to Misterhouse and the menu should appear!
     

NAVIGATING THE MENUS
    Navigating the menus is carried out with only a few keys:

        1..9    Select a menu entry
        
        0       Back to the previous menu
        
        *       Toggle full screen view of the help text or the last response
                from Misterhouse. When in full screen mode, use '8' or '2' to 
                scroll up/down if more than one page is available.
        
        #       Quit (no questions asked...) 
        -       Quit (handy when using the PC numpad to navigate, no need
                      to move the hands over to the # key!) 
        
        ENTER   Show the next page of the current menu (in case not all 
                menu entries fit on the screen at once)


    Alternatively you can use arrow keys to navigate: 

        UP/DOWN Next/previous page of the menu, help page or response 
        
        LEFT    Back to the previous menu


USING TERMINAL_MENU FROM A CELL PHONE VIA SSH
    In order to conveniently access Misterhouse from my mobile phone via SSH, 
    I created a new user account on the machine that is running sshd (which 
    happens to be the same computer as Misterhouse is running on, but this is 
    not a requirement). 

    I added two lines to ~/.bash_profile of that user account to launch 
    terminalmenu-client.pl and 'logout' immediately afterwards:
    
        /usr/bin/terminalmenu-client.pl
        logout
    
    Using PuTTY for SymbianOS on my Nokia Series60 phone I can now SSH into
    Misterhouse over GPRS. The menu appears immediately after login. Navigating
    with the keypad of the phone is a breeze. As soon as I terminate the menu 
    by hitting the [#] key the connection is closed, saving time and money. 
    
    
    USING TERMINAL_MENU FROM ANOTHER COMPUTER IN YOUR HOME NETWORK
    You only need terminalmenu-client.pl on the other computer. Launch it
    with the following parameters
    
        terminalmenu-client.pl -s server [-p port]
    
    where 'server' is the DNS name or IP address of your Misterhouse machine.   


CUSTOMIZING TERMINAL_MENU
    Terminal_Menu can be customized in the following ways:
        -)  Border around the menu yes/no
        -)  Color for various elements on the screen
        
    Those modifications can be made either from within Misterhouse
    by modifying  terminal_menu.pl  or from the client by using command line 
    parameters when starting  terminalmenu-client.pl.
    
    Configuring Terminal_Menu within Misterhouse:
    
        $terminalmenu = new Terminal_Menu('terminal-menu');
        $terminalmenu->set('COMMAND-STRING1');
        $terminalmenu->set('COMMAND-STRING2');
    
    (Possible values for COMMAND-STRING are described below)
    
    Configuring Terminal_Menu from the client:
    
        terminalmenu-client.pl -c "COMMAND-STRING1,COMMAND-STRING2"
    
    The following commands are available:
    
        BORDER 0|1
            Switches the border around the menu on/off. Note that the border is 
            automatically turned off when the terminal size is less than 22x18
            characters.
        
        COLOR 0|1
            Switches color of the menu on/off. 
        
        COLOR element color-string
            Allows the user to change colors of individual elements of the menu.
            Elements that can be modified:
                HEADER          menu heading
                MENU            individual menu entries
                CHOICE          last chosen menu entry
                CHOICE_LABEL    label "Your choice:"
                RESPONSE        response of the last selected menu entry
                RESPONSE_LABEL  label for the response
                BORDER          border color
            'color-string' is a string comprising of the following values:
                clear, reset, dark, bold, underline, underscore, blink, 
                reverse, concealed, black, red, green, yellow, blue, magenta, 
                on_black, on_red, on_green, on_yellow, on_blue, on_magenta, 
                on_cyan, on_white
            Note that not all values may be supported by the terminal. Please 
            refer to the documentation of Term::ANSIColor for details.
        
        NUMPAD-LAYOUT pc|phone
            Telephones and PC utilize a different layout of the number pad: PC 
            have numbers 7/8/9 in the top row, while (mobile) phones have 1/2/3.
            Since the numbers 2 and 8 are used to scroll in zoomed mode,
            for sake of user friendlyness it is important to know whether the 
            client is a PC or a phone so that the proper scroll keys can be 
            used. 
            Default value is 'phone'.
    

MORE INFO            
    -) Read Terminal_Menu.pm
    -) Run  "terminalmenu-client.pl -h"  to see all available options.

            
BUGS / TODO
    -)  Add authentication support
    
    -)  Add timeout to close inactive connectsions
    
    -)  When actions are triggered in multiple clients at the same time
        then the response may be sent to the wrong client. This has to do
        with Misterhouse' architecture.
    
    -)  Can we use Telnet instead of the proprietary terminalmenu-client.pl?
    
    -)  Make Terminal_Menu accessible over Bluetooth


AUTHOR
    Werner Lane
    wl-opensource@gmx.net

        
SPECIAL THANKS TO
    Bruce Winter - MH
    Jason Sharpee - Numbered_Menu.pm, which this code is based on.
    Everyone contributing to Misterhouse
    Everyone else using Misterhouse

=cut

#############################################################################

use Terminal_Menu;

my %connections = ();
my $clientid    = 0;

$terminalmenu_server =
  new Socket_Item( undef, undef, 'server_terminalmenu', undef, undef, undef,
    "\n" );

#############################################################################
#############################################################################
if ($Reload) {
    print_log "Reloading terminal menu\n";

    menu_parse scalar file_read("$config_parms{code_dir}/terminalmenu.menu"),
      'terminal-menu';
}

#############################################################################
#############################################################################
if ( active_now $terminalmenu_server) {
    my $client_ip = $Socket_Ports{'server_terminalmenu'}{client_ip_address};
    my $client    = $Socket_Ports{'server_terminalmenu'}{socka};

    print_log "terminal_menu.pl: connection from $client_ip ($client)"
      if $Debug{'Terminal_Menu'};

    &new_connection($client) if ( not exists $connections{$client} );
}

#############################################################################
#############################################################################
if ( inactive_now $terminalmenu_server) {
    my $client_ip = $Socket_Ports{'server_terminalmenu'}{client_ip_address};
    print_log "terminal_menu.pl: session closed from $client_ip"
      if $Debug{'Terminal_Menu'};

    # Remove closed sockets
    my %active_clients = ();
    foreach my $client ( @{ $Socket_Ports{'server_terminalmenu'}{clients} } ) {
        $active_clients{ $$client[0] } = 1;
    }

    foreach my $client ( keys %connections ) {
        unless ( $active_clients{$client} ) {
            delete $connections{$client};
        }
    }
}

#############################################################################
#############################################################################
my $incoming_data;
my $color_toggle  = 1;
my $border_toggle = 1;
if ( defined( $incoming_data = said $terminalmenu_server) ) {
    my $client = $Socket_Ports{'server_terminalmenu'}{socka};

    &new_connection($client) if ( not exists $connections{$client} );

    # Implementing a new feature: when key 'c' is pressed then color/bw is
    # toggled; if key 'b' is pressed border is switched on/off.
    if ( $incoming_data =~ m/^c$/i ) {
        $color_toggle = $color_toggle ? 0 : 1;
        $connections{$client}{terminal_menu}->set("color $color_toggle");
        $connections{$client}{terminal_menu}->set("0");
    }
    elsif ( $incoming_data =~ m/^b$/i ) {
        $border_toggle = $border_toggle ? 0 : 1;
        $connections{$client}{terminal_menu}->set("border $border_toggle");
        $connections{$client}{terminal_menu}->set("0");
    }

    $connections{$client}{terminal_menu}->set($incoming_data);
}

#############################################################################
#############################################################################
sub new_connection {
    my ($client) = @_;

    ++$clientid;
    $connections{$client}{id} = $clientid;
    $connections{$client}{terminal_menu} =
      eval "new Terminal_Menu('terminal-menu');";
    $connections{$client}{terminal_menu}
      ->tie_event("send_to_client $clientid, \$state");
}

#############################################################################
#############################################################################
sub send_to_client {
    my ( $clientid, $state ) = @_;

    foreach my $client ( keys %connections ) {
        if ( $clientid == $connections{$client}{id} ) {
            set $terminalmenu_server $state, $client;
        }
    }
}

#############################################################################
#############################################################################
{
    foreach my $client ( keys %connections ) {
        $connections{$client}{terminal_menu}->loop();
    }
}
