
# Category = MisterHouse

#@ This code loads all the .menu files in your code dirs, for use with various menu interfaces like
#@ <a href="/bin/menu.pl">/bin/menu.pl</a>.

=begin comment

 This code will read all .menu files in your code_dirs.
 Then you can walk thru the menus with any of these:

  Web browser:        http://localhost/sub?menu_html
  WAP phone:          http://localhost/sub?menu_wml
  Tellme.com phone:   http://localhost/sub?menu_vxml  
  LCD keypads:        see mh/code/bruce/lcd.pl for an example
  Audible feedback:   see mh/code/public/audible_menu.* for an example
  Numberic keyboard:  see mh/code/common/keyboard_numbered_menu.pl

 See the 'Customizing the Menu interfaces' section mh/docs/mh.*  for more info.

 See code/bruce/menu_bruce.pl for additional user specific menu code.

=cut

# Use these to enable non-local access
# NOTE:  We don't have authorization menus yet,
#        for tellme.com menus, so you may
#        may want to turn these off, or only create
#        harmless menus.
#$Password_Allow{'&menu_html'}          = 'anyone';
#$Password_Allow{'&menu_wml'}           = 'anyone';
#$Password_Allow{'&menu_vxml'}          = 'anyone';
#$Password_Allow{'&menu_run'}           = 'anyone';
#$Password_Allow{'&menu_run_response'}  = 'anyone';

if ($Reread) {
    print_log 'Rereading .menu code files.';

    # Create a menu with all mh voice commands
    #   my $menu_mh = menu_create "$config_parms{code_dir}/mh.menu";
    my $menu_mh = menu_create "$Code_Dirs[0]/mh.menu";

    # Find all .menu files
    my %file_paths = &file_read_dir(@Code_Dirs);
    for my $member ( keys %file_paths ) {
        next unless $member =~ /(\S+).menu$/i;
        next if $config_parms{no_load} and $member =~ /$config_parms{no_load}/i;
        menu_parse scalar file_read( $file_paths{$member} ), $1;
    }

    # Set default menus, based on ip addresses
    set_menu_default( 'main', 'Top', 'default' )
      ;    # Default to top of main for unknown ip address

    #   set_menu_default('main', 'Top|Main|Rooms|Living Room',   '127.0.0.1');
    #   set_menu_default('main', 'Main|Rooms|Living Room', '192.168.0.81');
    #   set_menu_default('main', 'Main|Rooms|Bedroom',     '192.168.0.83');
}

# Monitor wap and vxml sessions
if ( $Http{loop} == $Loop_Count ) {
    if ( $Http{request} =~ /menu_wml/ ) {
        play 'wap';    # Defined in event_sounds.pl
        my $msg =
          "WAP call from $Http{'User-Agent'}, $Http{'x-up-subno'} $Http{request}";

        #       display $msg, 0;        # See if this can be used for security
        logit "$config_parms{data_dir}/logs/menu_wml.$Year_Month_Now.log", $msg;
    }
    if ( $Http{request} =~ /menu_vxml/ ) {
        play 'tell_me';    # Defined in event_sounds.pl
        my $msg = "Tellme call: $Http{request}";
        print_log $msg;
        logit "$config_parms{data_dir}/logs/menu_vxml.$Year_Month_Now.log",
          $msg;
    }
}
