#
# Authority:Family

#
# MRU 20040301 ver 1.01 - Pete Flaherty (pjf@cape.com) http://www.mraudrey.net
# generate a table containing the playlist and highlight the current song
#
#
my $Mp3List; 
    $Mp3List = "<html><head><meta http-equiv='Expires' content='-1'></head><body bgcolor='#ccffff'>";

    $Mp3List = "$Mp3List<table> ";
    my $titles = &mp3_get_playlist();			#The list
    my $currPos = int (&mp3_get_playlist_pos()) ;	#The positoin
	#Check that we're using a list
        if ( @$titles == 0 ) {
    	    $Mp3List =  $Mp3List . "There is no track in the playlist\n";
	}
	else {
	# Generate the table
	    my $pos = 1;
	    foreach my $item (@$titles) {
	        my $Time = &mp3_get_playlist_timestr( $pos - 1 );
	        my $Str = "                                                            ";
	        $Str = substr( "$pos. $item", 1 );
		# <td><a href=/music/MP3_WebPlaylist.pl?Jump=$pos target=MP3_Playlist>$pos. $item</a><right> .... $Time</right></td><tr>\n
		# Only highlight the current song otherwise just add to the list
		if ( $pos - 1 == $currPos ) { $Mp3List = $Mp3List ."<tr bgcolor='yellow'><td id=$pos><B>$pos</B></td><td><b>$item</b></td><td><b>$Time</b></td></tr>" ; }
		if ( $pos - 1 != $currPos ) { $Mp3List = $Mp3List ."<tr><td id=$pos>$pos</td><td>$item</td><td>$Time</td></tr>" ; }

	        $pos++;
	    }
	    $Mp3List = $Mp3List . "</table>" ;
	}

    $Mp3List = "$Mp3List</body></html>";
																
return $Mp3List ;