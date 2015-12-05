    #
    # Authority:Family

    #
    # MRU 2004.03.01 ver 1.01 - Pete Flaherty (pjf@cape.com) http://www.mraudrey.net
    # generate a table containing the playlist and highlight the current song
    #
    # MRU 2004.07.15 ver 1.02
    # Added Jump and Delete functionality to the playlist
    #

    my $titles  = &mp3_get_playlist();               #The list
    my $currPos = int( &mp3_get_playlist_pos() );    #The positoin
    my $serv    = $config_parms{http_server};

    my $Mp3List;
    $Mp3List =
      "<html><head><meta http-equiv='Refresh' content='120;url=/bin/mp3_applet_playlist.pl'><title>MisterHouse Jukebox Playlist</title>";
    $Mp3List = "$Mp3List    <script src='/bin/mp3_cookies.js'></script>";
    $Mp3List = "$Mp3List    <script src='/bin/mp3_ctrl.js'></script>";
    $Mp3List =
      "$Mp3List    </head><body background='http://localhost/Channels/.MisterHouse/background.gif' bgcolor='#ccffff'>";
    $Mp3List = "$Mp3List <script>";                  # LANGUAGE='JavaScript'>";

    #    $Mp3List = "$Mp3List   eraseCookie('Playlist');";
    $Mp3List = "$Mp3List var ListON = readCookie('Playlist');";

    #    $Mp3List = "$Mp3List document.write('coookie=' + ListON+'!');";
    $Mp3List = "$Mp3List  if ( ListON == 'CLOSE' ){ ";
    $Mp3List = "$Mp3List   eraseCookie('Playlist');";
    $Mp3List = "$Mp3List   parent.window.close();";
    $Mp3List = "$Mp3List  }";
    $Mp3List = "$Mp3List  ";
    $Mp3List = "$Mp3List //eraseCookie('Playlist'); ";
    $Mp3List = "$Mp3List //createCookie('Playlist','KILL','1');";
    $Mp3List = "$Mp3List //setTimeout('UpdateYou()', 2000);";
    $Mp3List = "$Mp3List </script>";
    $Mp3List =
      "$Mp3List <table  background='http://localhost/Channels/.Misterhouse/background.gif'> ";
    $Mp3List =
      "$Mp3List<TR><th><small>Track<br>(<u>del</u>)</small></th><th><small>Song Title<br>(<u>jump</u>)</small></th><th><small>Play<br>Time</small></th></TR><small>";

    #Check that we're using a list
    if ( @$titles == 0 ) {
        $Mp3List = $Mp3List . "There is no track in the playlist\n";
    }
    else {
        # Generate the table
        my $pos = 1;
        foreach my $item (@$titles) {
            my $Time = &mp3_get_playlist_timestr( $pos - 1 );
            my $Str =
              "                                                            ";
            $Str = substr( "$pos. $item", 1 );
            my $my_pos = $pos - 1;

            # <td><a href='/music/MP3_WebPlaylist.pl?Jump=$pos target=MP3_Playlist'>$pos. $item</a><right> .... $Time</right></td><tr>\n
            # Only highlight the current song otherwise just add to the list
            #  v 1.10 and Add a Track Jump URL
            if ( $pos - 1 == $currPos ) {
                $Mp3List = $Mp3List
                  . "<tr bgcolor='yellow'><td id=$pos><B>$pos</B></td><td><b>$item</b></td><td><b>$Time</b></td></tr>";
            }

            #		if ( $pos - 1 == $currPos ) { $Mp3List = $Mp3List ."<tr bgcolor='yellow'><td id=$pos><B>$pos</B></td><td><b>$item</b></td><td><b>$Time</b></td></tr>" ; }
            #		if ( $pos - 1 != $currPos ) { $Mp3List = $Mp3List ."<tr><td id=$pos><a target='invisi' href='$serv/SUB:mp3_playlist_delete(%22$my_pos%22)'$pos >$pos</a>\
            #								    </td><td><a target='invisi'href='$serv/SUB:mp3_set_playlist_pos(%22$my_pos%22)'>$item</a></td><td>$Time</td></tr>" ; }
            if ( $pos - 1 != $currPos ) {
                $Mp3List = $Mp3List
                  . "<tr><td id=$pos><a href='javascript:remove($my_pos)'> $pos </a>\
								           </td><td><a href='javascript:skipTo($my_pos)'>$item </a></td><td>$Time</td></tr>";
            }

            #		if ( $pos - 1 != $currPos ) { $Mp3List = $Mp3List ."<tr><td id=$pos><a target='invisi' href='$serv/SUB:mp3_playlist_delete(%22$my_pos%22)'$pos >$pos</a>\
            #								    </td><td><a target='invisi'href='$serv/SUB:mp3_set_playlist_pos(%22$my_pos%22)'>$item</a></td><td>$Time</td></tr>" ; }
            #		<a href='$serv/RUN:mp3_set_playlist_pos_$pos'>$pos</a>

            # Add a Delete Track

            $pos++;
        }
        $Mp3List = $Mp3List . "</table>";
    }

    $Mp3List = "$Mp3List</body></html>";

    return $Mp3List;
