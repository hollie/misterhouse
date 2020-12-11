# Category = MisterHouse

#@ Use the pc keyboard to walk menus using the Numbered_Menu module
#@ Use keys + and - to start and stop the menu
#@ Use keys 0 and . to speak previous and next items

use Numbered_Menu;

# Use this to read a menu
#$nm  = new Numbered_Menu('Test', '/misterhouse/tc/test.menu', '2');

# Use this if we have parsed menus elsewhere (e.g. menu.pl)
$nm = new Numbered_Menu( 'default', undef, 2 );

$nm_keys = new Generic_Item;
$nm_keys->set($Keyboard) if $Keyboard;

if ($Reload) {
    $nm_keys->tie_items($nm);
    $nm_keys->tie_items( $nm, '97',  '1' );
    $nm_keys->tie_items( $nm, '98',  '2' );
    $nm_keys->tie_items( $nm, '99',  '3' );
    $nm_keys->tie_items( $nm, '100', '4' );
    $nm_keys->tie_items( $nm, '101', '5' );
    $nm_keys->tie_items( $nm, '102', '6' );
    $nm_keys->tie_items( $nm, '103', '7' );
    $nm_keys->tie_items( $nm, '104', '8' );
    $nm_keys->tie_items( $nm, '105', '9' );
    $nm_keys->tie_items( $nm, '96',  'previous' );    # Num key 0
    $nm_keys->tie_items( $nm, '110', 'next' );        # Num key .
    $nm_keys->tie_items( $nm, '109', 'stop' );        # Num key -
    $nm_keys->tie_items( $nm, '107', 'start' );       # Num key +
    $nm_keys->tie_items( $nm, '111', 'repeat' );      # Num key /
    $nm_keys->tie_items( $nm, '106', 'exit' );        # Num key *

    #   $nm_keys -> tie_event('print_log "Key  entered: $state"');
    $nm->tie_event('ivr_process_menu $state');
}

sub ivr_process_menu {
    my ($state) = @_;
    my ( $ivr_menu, $msg );
    $state = lc $state;
    $state =~ s/_/ /g;

    if ( $state =~ /^menu:(.*)/ ) {
        $ivr_menu = $1;
        $msg      = "$1 menu";
    }
    elsif ( $state =~ /^item:(.*):(.*)/ ) {
        if ( $1 eq '-' ) {
            $msg = "End of menu";
        }
        else {
            $msg = "Press $1, for $2";
        }
    }
    elsif ( $state =~ /^start/ ) {
        $msg = "Starting menu";
    }
    elsif ( $state =~ /^stop/ ) {
        $msg = "Stopping menu";
    }
    elsif ( $state =~ /^response:(.*)/ ) {
        $msg = $1;
    }
    if ($msg) {
        speak mode => 'stop';    # Stop previous speech
        speak $msg;
    }

    #	print_log "IVR menu: $ivr_menu: $state";
}
