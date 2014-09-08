# Category=Test

#@ Test pushing data to a java web applet in mh/web/tattler
#@   - set mh.ini parm:  server_tattler = 7010

# Tattler applet from: http://www.projectplasma.com/tattler/index.html

my $tattler_deep_thoughts = "$config_parms{data_dir}/remarks/deep_thought.txt";

$server_tattler = new Socket_Item( undef, undef, 'server_tattler' );

my $count;
if ( active_now $server_tattler) {
    $count = 0;
    print_log 'New tattler applet connection';
    set $server_tattler
      'Welcome to the MisterHouse tattler server.  You should get 3 taglines, one every 10 seconds.';
}

if ( active $server_tattler and new_second 10 ) {
    if ( $count++ >= 3 ) {
        set $server_tattler
          "Thanks for dropping bye.  Socket will now be closed.  Refresh the page to recycle.";
        print_log "Tattler socket closed";
        stop $server_tattler;
    }
    else {
        print_log "Sending test data to tattler applet";
        set $server_tattler ( read_next $tattler_deep_thoughts);

        #       set $server_tattler (read_next $house_tagline);
    }

}

