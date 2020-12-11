
# Category = MisterHouse

#@ Used with common/menu.pl, this is the stuff that is uniq to Bruce's House

# Use these to enable non-local access
# NOTE:  We don't have authorization menus yet,
#        for tellme.com menus, so you may
#        may want to turn these off, or only create
#        harmless menus.
$Password_Allow{'&menu_html'}         = 'anyone';
$Password_Allow{'&menu_wml'}          = 'anyone';
$Password_Allow{'&menu_vxml'}         = 'anyone';
$Password_Allow{'&menu_run'}          = 'anyone';
$Password_Allow{'&menu_run_response'} = 'anyone';

if ($Reread) {

    # Set default menus
    set_menu_default( 'main', 'Top',                        'default' );
    set_menu_default( 'main', 'Top|Main|Rooms|Living_Room', '127.0.0.1' );
    set_menu_default( 'main', 'Top|Main|Rooms|Living_Room', '192.168.0.2' );
    set_menu_default( 'main', 'Main|Rooms|Living Room',     '192.168.0.81' );
    set_menu_default( 'main', 'Main|Rooms|Living Room',     '192.168.0.82' );
    set_menu_default( 'main', 'Main|Rooms|Bedroom',         '192.168.0.83' );
}
