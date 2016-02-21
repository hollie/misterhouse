my ( $function, @parms ) = @ARGV;
my $numsteps = 5;
my $bars     = 10;
my $perbar   = 100 / $bars;

if ( $function eq 'cddb_list' ) {
    return &get_cdinfo('do_cddb_list');
}
elsif ( $function eq 'do_cddb_list' ) {
    return &do_cddb_list();
}
elsif ( $function eq 'direct_rip' ) {
    return &get_cdinfo('track_edit');
}
elsif ( $function eq 'track_edit' ) {
    return &track_edit();
}
elsif ( $function eq 'start_rip' ) {
    return &start_rip();
}
elsif ( $function eq 'abort' ) {
    return &abort( $parms[0] );
}
elsif ( $function eq 'delete' ) {
    return &delete( $parms[0] );
}
elsif ( $function eq 'view_log' ) {
    return &view_log( $parms[0] );
}
elsif ( $function eq 'resume_rip' ) {
    return &resume_rip( $parms[0] );
}
elsif ( $function eq 'confirm_files' ) {
    return &confirm_files();
}
else {
    return &main_page();
}

sub abort {
    my $cddbid = $_[0];
    my $dir    = &mp3Rip_abort($cddbid);
    my $html   = &html_header("Misterhouse mp3Rip: Aborted Rip $cddbid");
    $html .= "<P> <B>The MP3 Rip process has been aborted.</B>\n";
    $html .=
      "<P> The data will be stored as an incomplete process and you can delete it or try to resume.\n";
    if ( -d $dir ) {
        $html .=
          "<P> The directory '$dir' exists and may contain a partially ripped CD.  You may want to examine this directory manually to see if any manual actions are necessary.\n";
    }
    $html .= "<P><a href=\"?\">Return to the mp3Rip Homepage</a>.\n";
    $html .=
      "<hr><P><i>Questions, bugs, comments, suggestions related to the Misterhouse mp3Rip system?  Contact <a href=\"mailto:kirk\@kaybee.org\">Kirk Bauer</a></i>\n";
    return &html_page( "Misterhouse mp3Rip: Aborted Rip $cddbid", $html );
}

sub delete {
    my $cddbid = $_[0];
    my $dir    = &mp3Rip_delete_partial($cddbid);
    my $html   = &html_header("Misterhouse mp3Rip: Deleted Partial $cddbid");
    $html .= "<P> <B>The partial MP3 Rip data has been deleted.</B>\n";
    if ( -d $dir ) {
        $html .=
          "<P> The directory '$dir' exists and may contain a partially ripped CD.  You may want to examine this directory manually and delete the MP3s if they are not valid.\n";
    }
    $html .= "<P><a href=\"?\">Return to the mp3Rip Homepage</a>.\n";
    $html .=
      "<hr><P><i>Questions, bugs, comments, suggestions related to the Misterhouse mp3Rip system?  Contact <a href=\"mailto:kirk\@kaybee.org\">Kirk Bauer</a></i>\n";
    return &html_page( "Misterhouse mp3Rip: Deleted Partial $cddbid", $html );
}

sub show_percent_bar {
    my $percent = $_[0];
    my $html    = '';
    $percent =~ s/%$//;
    $html .= "<table border=1 width=100%><tr>\n";
    for ( my $i = 1; $i <= $bars; $i++ ) {
        if ( ( $percent + ( $perbar / 2 ) ) >= ( $i * $perbar ) ) {
            $html .= "<td width=$perbar% bgcolor=green>&nbsp;</td>\n";
        }
        else {
            $html .= "<td width=$perbar%>&nbsp;</td>\n";
        }
    }
    $html .= "</tr></table>\n";
    return $html;
}

sub resume_rip {
    my $cddbid = $_[0];
    my $ret    = &mp3Rip_attempt_reattach_and_restart($cddbid);
    unless ($ret) {
        &mp3Rip_clean($cddbid);
        $ret = &mp3Rip_attempt_reattach_and_restart($cddbid);
    }
    my $html = &html_header("Misterhouse mp3Rip: Attempting to Resume");
    unless ($ret) {
        $html .=
          "<P><span style=\"color:red\"><B>ERROR: Could not resume rip!  View log to see what is wrong and/or delete the entry and start over. </B></span>\n";
        $html .= "<P><A href=\"?\">Return to mp3Rip Homepage</A>\n";
        return &html_page( "Misterhouse mp3Rip: Failed to Resume", $html );
    }
    $html .=
      "<P> <B>The MP3 Rip is in progress.</B> <P>Since this disc was somehow lost by the system before, you should monitor the progress closely to verify it is completing sucessfully. \n";
    $html .=
      "<P><a href=\"?\">Return to the mp3Rip Homepage to check the status</a>.\n";
    $html .=
      "<hr><P><i>Questions, bugs, comments, suggestions related to the Misterhouse mp3Rip system?  Contact <a href=\"mailto:kirk\@kaybee.org\">Kirk Bauer</a></i>\n";
    return &html_page( "Misterhouse mp3Rip: Rip Resumed", $html );
}

sub view_log {
    my $cddbid = $_[0];
    my $html   = &html_header("Misterhouse mp3Rip Log Viewer: CDDBID $cddbid");
    $html .=
      "<P><B>NOTE</B>: Most recent log entry is at the top of the page (i.e. the log entry is displayed in reversed order)\n";
    $html .= "<P><A href=\"?\">Return to mp3Rip Homepage</A>\n";
    if ( -f "$config_parms{mp3Rip_work_dir}/$cddbid.log" ) {
        $html = qq|
<meta http-equiv="refresh" content="10">
$html
<pre>
|;
        foreach (
            reverse &main::file_read(
                "$config_parms{mp3Rip_work_dir}/$cddbid.log") )
        {
            $html .= "$_\n";
        }
    }
    elsif ( -f "$config_parms{mp3Rip_archive_dir}/$cddbid.log" ) {
        $html .=
          "<P><B>NOTE</B>: This is an archived log file as the ripping process is complete.<P><pre>\n";
        foreach (
            reverse &main::file_read(
                "$config_parms{mp3Rip_archive_dir}/$cddbid.log") )
        {
            $html .= "$_\n";
        }
    }
    $html .= "</pre>\n";
    $html .=
      "<hr><P><i>Questions, bugs, comments, suggestions related to the Misterhouse mp3Rip system?  Contact <a href=\"mailto:kirk\@kaybee.org\">Kirk Bauer</a></i>\n";
    return &html_page( "Misterhouse mp3Rip Log Viewer: CDDBID $cddbid", $html );
}

sub get_cdinfo {
    &mp3Rip_get_cdinfo();
    my $html =
      &html_header("Misterhouse mp3Rip Step 1/$numsteps: Retrieving CD Info");
    $html = qq|
<meta http-equiv="refresh" content="30">
$html
<P><B>Retrieving CD information...</B>
<P><a href="?$_[0]">Click to continue</A>
|;
    $html .=
      "<hr><P><i>Questions, bugs, comments, suggestions related to the Misterhouse mp3Rip system?  Contact <a href=\"mailto:kirk\@kaybee.org\">Kirk Bauer</a></i>\n";
    return &html_page(
        "Misterhouse mp3Rip Step 1/$numsteps: Retrieving CD Info", $html );
}

sub verify_cdinfo {
    unless (&mp3Rip_is_cdinfo_ready) {
        my $html = "<meta http-equiv=\"refresh\" content=\"5\">$_[1]\n";
        $html .= "<P><B>Still processing... please wait.</B>\n";
        return $html;
    }
    my ( $cddbid, $track_numbers, $track_lengths, $total_seconds ) =
      &mp3Rip_parse_cdinfo();
    unless ($track_numbers) {
        my $html .=
          "<P><span style=\"color:red\"><B>ERROR READING CD INFORMATION!</B></span>\n";
        $html .= "<P>Things to check:</P>\n<UL>\n";
        $html .= "   <LI> Is there a CD in the drive?\n";
        $html .=
          "   <LI> Try running '$config_parms{mp3Rip_cdinfo}' as the Misterhouse user ('$ENV{USER}') to see if it is working okay. \n";
        $html .= "</UL>\n";
        $html .=
          "<P><a href=\"?$_[0]\">Click here when you are ready to try again</a>\n";
        return $html;
    }
    return ( undef, $cddbid, $track_numbers, $track_lengths, $total_seconds );
}

sub confirm_files {
    my %names;
    my @tracks;
    foreach (@parms) {
        my ( $name, $value ) = split( /=/, $_, 2 );
        $name =~ s/track(\d\D)/track0$1/;
        if ( ( $value eq 'on' ) and ( $name =~ s/^track(\d+)-rip/$1/ ) ) {
            push @tracks, $name;
        }
        else {
            $names{$name} = $value;
        }
    }
    my $html = &html_header("Misterhouse mp3Rip Step 4/$numsteps: Filenames");
    unless (@tracks) {
        $html .=
          "<P><span style=\"color:red\"><B>NO TRACKS SELECTED!</B></span>\n";
        $html .=
          "<P>Hit the Back button on your browser and select one or more tracks to rip.\n";
        return &html_page( "Misterhouse mp3Rip Step 4/$numsteps: Filenames",
            $html );
    }
    $html .=
      "<form method=POST action=\"?start_rip\"><P><B>IMPORTANT</B>: The following directory should not exist or at least be empty since existing files might be deleted or overwritten!<P><table border=1>\n";
    my $dir =
      &mp3Rip_get_dir_name( $names{'genre'}, $names{'artist'},
        $names{'album'} );
    $html .=
        "<tr><td bgcolor='9999CC'>Directory</td><td><input name=dir size="
      . ( length($dir) * 1.5 )
      . " value=\"$dir\"></td></tr>\n";
    foreach my $track ( sort @tracks ) {
        my $trackname = &mp3Rip_get_filename(
            $track,
            $names{"track${track}artist"},
            $names{"track${track}title"},
            $names{'album'}, $names{'genre'}
        );
        $html .=
          "<tr><td bgcolor='9999CC'>Track $track</td><td><input name=track$track-file size="
          . ( length($trackname) * 1.5 )
          . " value=\"$trackname\"></td></tr>\n";
    }
    $html .=
      "<tr><td align=center colspan=2><input type=submit value=\"Proceed to Step 5/$numsteps: Ripping CD\"></td></tr>\n";
    $html .= "</table>\n";
    $html .= "<input type=hidden name=tracks value=\"@tracks\">\n";
    $html .= "<input type=hidden name=album value=\"$names{'album'}\">\n";
    $html .= "<input type=hidden name=genre value=\"$names{'genre'}\">\n";
    $html .= "<input type=hidden name=artist value=\"$names{'artist'}\">\n";
    $html .= "<input type=hidden name=year value=\"$names{'year'}\">\n";
    $html .= "<input type=hidden name=cddbid value=\"$names{'cddbid'}\">\n";

    foreach my $track (@tracks) {
        $html .= "<input type=hidden name=\"track${track}title\" value=\""
          . $names{"track${track}title"} . "\">\n";
        $html .= "<input type=hidden name=\"track${track}artist\" value=\""
          . $names{"track${track}artist"} . "\">\n";
        $html .= "<input type=hidden name=\"track${track}comment\" value=\""
          . $names{"track${track}comment"} . "\">\n";
        $html .= "<input type=hidden name=\"track${track}length\" value=\""
          . $names{"track${track}length"} . "\">\n";
    }
    $html .= "</form>\n";
    $html .=
      "<hr><P><i>Questions, bugs, comments, suggestions related to the Misterhouse mp3Rip system?  Contact <a href=\"mailto:kirk\@kaybee.org\">Kirk Bauer</a></i>\n";
    return &html_page( "Misterhouse mp3Rip Step 4/$numsteps: Filenames",
        $html );
}

sub start_rip {
    my $error = &mp3Rip_start_rip(@parms);
    my $html  = &html_header("Misterhouse mp3Rip Step 5/$numsteps: Ripping CD");
    if ($error) {
        $html .= "<P><span style=\"color:red\"><B>ERROR: $error!</B></span>\n";
        return &html_page( "Misterhouse mp3Rip Step 5/$numsteps: Ripping CD",
            $html );
    }
    $html .=
      "<P> <B>The MP3 Rip is in progress.</B><P><a href=\"?\">Return to the mp3Rip Homepage to check the status</a>.\n";
    $html .=
      "<hr><P><i>Questions, bugs, comments, suggestions related to the Misterhouse mp3Rip system?  Contact <a href=\"mailto:kirk\@kaybee.org\">Kirk Bauer</a></i>\n";
    return &html_page( "Misterhouse mp3Rip Step 5/$numsteps: Ripping CD",
        $html );
}

my $default_artist  = '';
my $artist_size     = 30;
my $max_track_count = 0;

sub do_select_row {
    my ( $special, $label, $name, @list ) = @_;
    my $default = '';
    my $size    = 30;
    foreach (@list) {
        $size = length($_) if ( length($_) > $size );
        $_ =~ s/&/&amp;/;
    }
    $default = $list[0] if @list;
    if ( $special eq 'artist' ) {
        $default_artist = $default;
        $artist_size    = $size;
    }
    my $html = "<tr>";
    if ( $special eq 'track' ) {
        my $shortname = $name;
        $shortname =~ s/title$//;
        $html .=
          "<td align=center bgcolor='9999CC'><input type=checkbox checked name=\"${shortname}-rip\"></td>\n";
        $html .= "<td>$label</td><td>";
    }
    else {
        $html .= "<td bgcolor='9999CC'>$label</td><td>";
    }
    $html .= "<input size=$size name=\"$name\" value=\"$default\"";
    if ( $special eq 'artist' ) {
        $html .= " onChange=\"update_artists(this.value);\"";
    }
    $html .= ">\n";
    if ( $#list > 0 ) {
        $html .= "&nbsp;<small><I>Other Options:</I></small>&nbsp;\n";
        $html .= "<select onChange=\"$name.value = this.value;";
        if ( $special eq 'artist' ) {
            $html .= " update_artists(this.value);";
        }
        $html .= "\">";
        for ( my $i = 0; $i <= $#list; $i++ ) {
            if ( $i == 0 ) {
                $html .= "<option selected>$list[$i]\n";
            }
            else {
                $html .= "<option>$list[$i]\n";
            }
        }
        $html .= "</select>\n";
    }
    if ( $special eq 'track' ) {
        my $shortname = $name;
        $shortname =~ s/title$//;
        my $id = $label;
        $id =~ s/^\s*(\d+)\s+.*$/$1/;
        $html .=
          "</td><td><input id=$id name=\"${shortname}artist\" size=$artist_size value=\"$default_artist\">\n";
        $html .=
          "</td><td align=center><input size=30 name=\"${shortname}comment\">\n";
    }
    if ( $special eq 'artist' ) {
        $html .=
          "<small><I>(Changes are also applied to tracks below)</I></small>\n";
    }
    $html .= "</td></tr>\n";
    return $html;
}

sub fix_caps {
    my @ret;
    foreach (@_) {
        my $fixed = &mp3Rip_check_caps($_);
        unless ( $fixed eq $_ ) {
            push @ret, $fixed;
        }
        push @ret, $_;
    }
    return (@ret);
}

sub remove_dups {
    for ( my $i = 0; $i <= $#_; $i++ ) {
        for ( my $j = 0; $j <= $#_; $j++ ) {
            if ( $_[$i] eq $_[$j] ) {
                unless ( $i == $j ) {
                    splice @_, $i, 1;
                    $i--;
                    last;
                }
            }
        }
    }
    return (@_);
}

sub track_edit {
    my %selected;
    foreach (@parms) {
        if (s/=on$//) {
            $selected{$_}++;
        }
    }
    my $html =
      &html_header("Misterhouse mp3Rip Step 3/$numsteps: Finalize Naming");
    my ( $error, $cddbid, $track_numbers, $track_lengths, $total_seconds ) =
      &verify_cdinfo( 'track_edit', $html );
    if ($error) {
        return &html_page(
            "Misterhouse mp3Rip Step 3/$numsteps: Finalize Naming", $error );
    }
    my %combined;
    my $entrycount = -1;
    $max_track_count = $#{@$track_numbers} + 1;
    foreach my $disc ( &mp3Rip_get_cddb_discs() ) {
        if ( $selected{ $disc->[1] } ) {
            my ( $genre, $artist, $album, @tracks ) =
              &mp3Rip_get_disc_details($disc);
            my $trackcount = 0;
            $entrycount++;
            $combined{'genre'}->[$entrycount]  = $genre;
            $combined{'artist'}->[$entrycount] = $artist;
            $combined{'album'}->[$entrycount]  = $album;
            foreach (@tracks) {
                $trackcount++;
                $combined{'tracks'}->[$trackcount]->[$entrycount] = $_;
            }
        }
    }
    $html .=
      "<P>For each row, type in or modify the value in the text box or make a selection from the list, if applicable.\n";
    $html .= "<P><B><big>Disc Info</big></B>\n";
    $html .= "<script>\n";
    $html .= "function update_artists(val) {\n";
    $html .= "   for (a = 1; a <= $max_track_count; a++) {\n";
    $html .= "      obj = document.getElementById(a); obj.value = val;\n";
    $html .= "   }\n";
    $html .= "}\n";
    $html .= "</script>\n";
    $html .=
      "<form method=POST action=\"?confirm_files\"><input type=hidden name=cddbid value=\"$cddbid\"><table border=1>\n";
    $html .=
      &do_select_row( '', 'Genre', 'genre',
        &remove_dups( @{ $combined{'genre'} } ),
        '------------', sort( &mp3Rip_get_id3_genres() ) );
    $html .=
      &do_select_row( 'artist', 'Artist', 'artist',
        &remove_dups( &fix_caps( @{ $combined{'artist'} } ) ) );
    $html .=
      &do_select_row( '', 'Album', 'album',
        &remove_dups( &fix_caps( @{ $combined{'album'} } ) ) );
    $html .= &do_select_row( '', 'Year', 'year' );
    $html .= "</table>\n";
    $html .= "<P><B><big>Track Info</big></B>\n";
    $html .= "<table border=1>\n";
    $html .=
      "<tr bgcolor='9999CC'><th>Rip?</th><th>Track</th><th>Track Title</th><th>Track Artist</th><th>Track Comment</th></tr>\n";

    foreach ( my $i = 1; $i <= ( $#{@$track_numbers} + 1 ); $i++ ) {
        $html .= &do_select_row( 'track', "$i ($track_lengths->[$i-1])",
            "track${i}title",
            &remove_dups( &fix_caps( @{ $combined{'tracks'}->[$i] } ) ) );
    }
    $html .=
      "</table><P><input type=submit value='Proceed to Step 4/$numsteps: Filenames'>\n";
    foreach ( my $i = 1; $i <= ( $#{@$track_numbers} + 1 ); $i++ ) {
        $html .= "<input type=hidden name=\"track${i}length\" value=\""
          . $track_lengths->[ $i - 1 ] . "\">\n";
    }
    $html .= "</form>\n";
    $html .= "<P><a href=\"?do_cddb_list\">Go back to Step 2</A>\n";
    $html .=
      "<hr><P><i>Questions, bugs, comments, suggestions related to the Misterhouse mp3Rip system?  Contact <a href=\"mailto:kirk\@kaybee.org\">Kirk Bauer</a></i>\n";
    return &html_page( "Misterhouse mp3Rip Step 3/$numsteps: Finalize Naming",
        $html );
}

sub do_cddb_list {
    my $html = &html_header("Misterhouse mp3Rip Step 2/$numsteps: CDDB List");
    my ( $error, $cddbid, $track_numbers, $track_lengths, $total_seconds ) =
      &verify_cdinfo( 'cddb_list', $html );
    if ($error) {
        return &html_page( "Misterhouse mp3Rip Step 2/$numsteps: CDDB List",
            $error );
    }
    $html .= "<B>Audio CD Found</B><UL>\n";
    $html .=
      "<LI><B>Total Length</B>: " . &mp3Rip_format_time($total_seconds) . "\n";
    $html .=
      "<LI><B>Number of Tracks</B>: " . ( $#{@$track_numbers} + 1 ) . "\n";
    $html .=
      "</UL><P>Select at least one CDDB entry to pre-populate your CD info.  If you select more than one you will be presented with a list box for each item on the next page.  You will still be able to make manual changes as well.\n";
    $html .=
      "<P>If you don't select any discs below, you will have to manually enter information about this CD.\n";
    $html .= "<form method=POST action=\"?track_edit\"><table border=1>\n";
    $html .=
      "<tr bgcolor='9999CC'><th>Select?</th><th>Genre</th><th>Artist / Album</th><th>CDDB DiscID</th></tr>\n";

    foreach my $disc ( &mp3Rip_get_cddb_discs() ) {
        my ( $genre, $cddbid, $album ) = @$disc;
        $genre = &mp3Rip_convert_genre_to_id3($genre);
        $album =~ s/&/&amp;/;
        $html .=
          "<tr><td align=center><input name=\"$cddbid\" type=checkbox checked></td><td align=center>$genre</td><td align=center>$album</td><td align=center>$cddbid</td></tr>\n";
    }
    $html .=
      "<tr><td colspan=4><input type=submit value='Proceed to Step 3/$numsteps: Finalize Naming'></td></tr>\n";
    $html .= "</table></form>\n";
    $html .=
      "<P><B>TIP</B>: Select all discs that appear to match your CD so you will have a wider variety of choices on the next page.\n";
    $html .=
      "<hr><P><i>Questions, bugs, comments, suggestions related to the Misterhouse mp3Rip system?  Contact <a href=\"mailto:kirk\@kaybee.org\">Kirk Bauer</a></i>\n";
    return &html_page( "Misterhouse mp3Rip Step 2/$numsteps: CDDB List",
        $html );
}

sub main_page {
    my $html = &html_header('Misterhouse mp3Rip Home');
    $html = "<meta http-equiv=\"refresh\" content=\"30\">$html\n";
    if ( &mp3Rip_cd_drive_in_use() ) {
        $html .=
          "<P>NOTE: Your CDROM drive is currently in use.  You will not be able to start a new CD until the current ripping process has finished with the drive (but you <I>can</I> start a new CD while others CDs are in the compressing stage).<P>\n";
    }
    else {
        $html .= qq|
<B>Start Ripping a new CD</B>
<P>Insert an audio CD in your CDROM drive and proceed by selecting a link below.
It is recommended that you use CDDB to automatically retrieve information about
your disc.
<P><B>NOTE</B>: You can start a new CD even if one or more discs are in the compression stage below.
<ul>
<li><B><A href="?cddb_list">Rip CD using CDDB</A></B>
<li><B><A href="?direct_rip">Rip CD manually</A></B>
</ul>
|;
    }

    my @pending = &mp3Rip_get_pending();
    if (@pending) {
        $html .= "<table border=1>\n";
        $html .=
          "<tr bgcolor='9999CC'><th colspan=7>Ripping in Progress</th></tr>\n";
        $html .=
          "<tr bgcolor='9999CC'><th>CDDBID</th><th>Artist</th><th>Album Title</th><th>Current Activity</th><th>Rip Status</th><th>Compress Status</th><th>Actions</th></tr>\n";
        foreach (@pending) {
            my (
                $cddbid,          $artist,
                $album,           $current,
                $rip_status,      $rip_percent,
                $compress_status, $compress_percent,
                $rip_time,        $rip_predicted_remaining,
                $compress_time,   $compress_predicted_remaining
            ) = @$_;
            $html .=
              "<tr><td align=center>$cddbid</td><td align=center>$artist</td><td align=center>$album</td>\n";
            $html .=
              "<td align=center>$current</td><td align=center>$rip_status\n";
            $html .= "<br />Elapsed: " . &mp3Rip_format_time($rip_time);
            $html .= "<br />Remaining: "
              . &mp3Rip_format_time($rip_predicted_remaining);
            $html .= &show_percent_bar($rip_percent);
            $html .= "</td><td align=center>$compress_status\n";
            $html .= "<br />Elapsed: " . &mp3Rip_format_time($compress_time);
            $html .= "<br />Remaining: "
              . &mp3Rip_format_time($compress_predicted_remaining);
            $html .= &show_percent_bar($compress_percent);
            $html .= "</td>\n";
            $html .=
              "<td align=center><a href=\"?view_log&$cddbid\">View Log</a><br /><a href=\"?abort&$cddbid\">Abort</a></tr>\n";
        }
        $html .= "</table>\n";
    }

    my @incomplete = &mp3Rip_get_incomplete();
    if (@incomplete) {
        $html .= "<P><table border=1>\n";
        $html .=
          "<tr bgcolor='9999CC'><th colspan=5>Incomplete CDs</th></tr>\n";
        $html .=
          "<tr bgcolor='9999CC'><th>CDDBID</th><th>Artist</th><th>Album Title</th><th>Status</th><th>Actions</th></tr>\n";
        foreach (@incomplete) {
            my ( $cddbid, $artist, $album, $status ) = @$_;
            $html .=
              "<tr><td>$cddbid</td><td>$artist</td><td>$album</td><td>$status</td><td>\n";
            $html .= "<a href=\"?view_log&$cddbid\">View Log</a>&nbsp;\n";
            $html .= "<a href=\"?resume_rip&$cddbid\">Resume</a>&nbsp;\n";
            $html .= "<a href=\"?delete&$cddbid\">Delete</a>\n";
            $html .= "</td></tr>\n";
        }
        $html .= "</table>\n";
    }

    my @completed = &mp3Rip_get_recently_completed();
    if (@completed) {
        $html .= "<P><table border=1>\n";
        $html .=
          "<tr bgcolor='9999CC'><th colspan=4>Recently Completed CDs</th></tr>\n";
        foreach (@completed) {
            $html .= "<tr><td>$_</td></tr>\n";
        }
        $html .= "</table>\n";
    }

    $html .=
      "<hr><P><i>Questions, bugs, comments, suggestions related to the Misterhouse mp3Rip system?  Contact <a href=\"mailto:kirk\@kaybee.org\">Kirk Bauer</a></i>\n";
    return &html_page( 'Misterhouse mp3Rip Home', $html );
}

