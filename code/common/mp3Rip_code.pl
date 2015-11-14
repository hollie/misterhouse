# Category = Music

#@ Use this code file to be able to rip MP3s from audio CDs through the
#@ Misterhouse web interface.  To enable this code, make sure your system is
#@ setup as described in <a href='/bin/browse.pl?/docs/mp3Rip_system_setup.txt'>mp3Rip_system_setup.txt</a>
#@ and review and modify the mp3Rip_* parms in mh.ini.
#@ Then click <a href="/misc/mp3Rip.pl">here</a> or click on the MP3 Music category button and
#@ click on the "Rip a CD using mp3Rip" at the bottom of the page.

=begin comment

09/19/2004  Created by Kirk Bauer (kirk@kaybee.org)

Here are the mh.ini parms, along with help text.  Copy to your private mh.ini

@ This is the directory in which mp3Rip keeps small working files.
@ It must exist and be writable by the Misterhouse user.
mp3Rip_work_dir=$config_parms{data_dir}/mp3Rip

@ This is the directory where the small logs and data files for completed
@ CDs are copied.  It must exist and be writable by the Misterhouse user.
mp3Rip_archive_dir=$config_parms{data_dir}/mp3Rip/completed

@ This is the directory in which your ripped CDs are placed.  Note that
@ sub-directories will be created under this as specified in the
@ 'mp3Rip_default_dir_name' setting.  This directory should exist and
@ be writable by the Misterhouse user.
mp3Rip_mp3_dir=/mnt/mp3s/mp3disks

@ This is a temporary directory where the large WAV files are stored until
@ they can be encrypted.  This directory should have around 700MB free for
@ each CD you want to rip at the same time.  It should exist and be writable
@ by your Misterhouse user.
mp3Rip_wav_dir=/mnt/mp3Rip

@ This optional setting, if defined, will cause the data from CDDB, possibly
@ modified by you on the web page, to be stored in this file inside of the
@ directory containing the MP3s.  This is in addition to any information
@ stored in ID3 tags if your MP3 ripper supports this.
mp3Rip_disc_data_file=.cddb-info

@ This optional setting, if defined, will cause mp3Rip to keep a master logfile
@ showing each CD that is ripped.
mp3Rip_log_file=$config_parms{data_dir}/mp3Rip/mp3Rip.log

@ This is actually only used in other configuration items below for convenience.
@ If you use a different CDROM device you can change it here.  This device must
@ be readable by the Misterhouse user and you may have to add something like
@ this in /etc/rc.d/rc.local to keep it that way:
@    chmod a+r /dev/cdrom
mp3Rip_cdrom_device=/dev/cdrom

@ The 'cd-info' program is required for mp3Rip operations and you will probably
@ have to install it as described in docs/mp3Rip_system_setup.txt.
mp3Rip_cdinfo=/usr/local/sbin/cd-info --cdrom-device=$config_parms{mp3Rip_cdrom_device}

@ A program that can read WAV files off of audio CDs is required.  I use
@ cdparanoia and it is probably already on your system, but you can also
@ use something else.  When this program is used, the __track__ and __output__
@ "macros" below are replaced with the actual track number and output WAV file.
@ If you get other rippers working for mp3Rip, please let me know: kirk@kaybee.org.
mp3Rip_cdripper=/usr/bin/cdparanoia -w -d $config_parms{mp3Rip_cdrom_device} __track__ __output__

@ This optional setting, if defined, will be used to eject the CDROM immediately
@ after the reading of WAV files is complete so that you can proceed to the next
@ CD while the first CD is being compressed.
mp3Rip_eject=eject $config_parms{mp3Rip_cdrom_device}

@ An audio compression program is required by mp3Rip.  I use the 'lame' MP3
@ encoder which you will probably have to install on your system as described
@ in docs/mp3Rip_system_setup.txt.  At a minimum, you must have the __input__ and
@ __output__ macros in your command below as these will be replaced with the
@ input and output files when the program is being used.  You can also specify
@ any encoder-specific quality flags to the encoder as I have here.  For lame,
@ I use '-V1' for high-quality variable-bitrate, -mj for joint-stereo mode,
@ -b128 for a bitrate of 128 , and -q2 for fairly high-quality encoding.
@
@ The rest of the "macros" below are for inserting ID3 tags into the output
@ file.  These will be replaced with quoted actual values for the compression
@ process.  The following fields are supported:
@    __song__: The song's title
@    __artist__: The artist
@    __album__: The album's title
@    __year__: The year the album was released
@    __comment__: An ID3 comment for the song
@    __track__: The track number of the song
@    __genre__: The numerical ID3 genre identifier
@    __genrestr__: The genre string
@
@ If you get other compressors working for mp3Rip, please send me your
@ mp3Rip_mp3_encoder line at kirk@kaybee.org.

# Ogg Vorbis
#mp3Rip_mp3_encoder=/usr/bin/oggenc -q 5 -t __song__ -a __artist__ -l __album__ -c YEAR=__year__ -c COMMENT=__comment__ -N __track__ -G __genrestr__ -o __output__ __input__

# Lame MP3 encoder
mp3Rip_mp3_encoder=/usr/local/bin/lame -V1 -mj -h -b128 -q2 --tt __song__ --ta __artist__ --tl __album__ --ty __year__ --tc __comment__ --tn __track__ --tg __genre__ __input__ __output__

@ This is the default format for your directory names.  mp3Rip assumes you will
@ have a separate directory under the mp3Rip_mp3_dir for each CD.  My default
@ is to have a directory for each genre, then a directory for each artist, and
@ finally a directory for each album by that artist.  But you can change this
@ as you see fit using any or all of: __genre__, __artist__, and __album__.
@ Note that you can change this default on a per-disc basis while going through
@ the pre-ripping process on the Misterhouse web page.
mp3Rip_default_dir_name=__genre__/__artist__/__album__

@ This is the default filename for each track from a CD.  Make sure the file
@ extension here matches the output format of your audio encoder.  I only
@ use three macros in my default with the 2-digit track (__track__) followed
@ by the artist (__artist__) and followed by the song title (__song__).  You
@ can also use the __genre__ and __album__ macros if you so desire.
mp3Rip_default_mp3_name=__track__-__artist__-__song__.mp3

@ Set this to 1 if you want the genre to always be lowercased when used
@ in directory and filenames.
mp3Rip_genre_lowercase=1

@ This is a list of words that you do NOT want capitalized in your
@ song/album titles and artist names.  After mp3Rip gets the CDDB data,
@ it will go through and check the capitalization.  If it corrects
@ anything, it will add this corrected version of the track/title/artist
@ to your list of choices so you can choose it if you like it better than
@ the choices offered by CDDB.  Each word in this list must begin with
@ a capital letter and be separated by a pipe (|).
mp3Rip_first_letter_caps_ignore_list=As|On|In|By|The|Of|A|An|And|Or|To


@ NOTE: All of the following only affect the pre-generated directory and
@ file names.  These are generated based off your modified CDDB data combined
@ with your patterns specified above in mp3Rip_default_dir_name and
@ mp3Rip_default_mp3_name.  This does not affect the ID3 tags and you still
@ have the opportunity to fine-tune these during the ripping process.

@ If set to 1, any parenthesis will be removed from the auto-generated filenames
@ and directory names (which you have the chance to change per-cd).
mp3Rip_files_no_parens=1

@ If set to 1, any square brackets will be removed from the auto-generated
@ filenames and directory names (which you have the chance to change per-cd).
mp3Rip_files_no_square_brackets=1

@ If set to 1, any curly braces will be removed from the auto-generated
@ filenames and directory names (which you have the chance to change per-cd).
mp3Rip_files_no_curly_brackets=1

@ If set to 1, all spaces will be converted to underscores in the auto-generated
@ filenames and directory names (which you have the chance to change per-cd).
mp3Rip_files_no_spaces=1

@ If set to 1, all ampersand and plus characters will be converted
@ to the word 'and' preceeded and followed by a space or undrescore
@ (depending on the value of mp3Rip_files_no_spaces).
mp3Rip_files_ampersand_or_plus_to_and=1

@ If set to 1, any reference such as "Disc1" or "Disk 2" or the like will be
@ formatted as " - Disc X".
mp3Rip_files_format_disc_number=1

@ If set to 1, any special characters, particularly those that need to be
@ escaped when used at the bash prompt, are removed from the automatically
@ generated file and directory names.
mp3Rip_files_no_special_chars=1



=cut

use CDDB;
use File::Copy;

my @id3_genres = (
    'Blues',                  'Classic Rock',
    'Country',                'Dance',
    'Disco',                  'Funk',
    'Grunge',                 'Hip-Hop',
    'Jazz',                   'Metal',
    'New Age',                'Oldies',
    'Other',                  'Pop',
    'R&B',                    'Rap',
    'Reggae',                 'Rock',
    'Techno',                 'Industrial',
    'Alternative',            'Ska',
    'Death Metal',            'Pranks',
    'Soundtrack',             'Euro-Techno',
    'Ambient',                'Trip-Hop',
    'Vocal',                  'Jazz+Funk',
    'Fusion',                 'Trance',
    'Classical',              'Instrumental',
    'Acid',                   'House',
    'Game',                   'Sound Clip',
    'Gospel',                 'Noise',
    'Alt. Rock',              'Bass',
    'Soul',                   'Punk',
    'Space',                  'Meditative',
    'Instrumental Pop',       'Instrumental Rock',
    'Ethnic',                 'Gothic',
    'Darkwave',               'Techno-Industrial',
    'Electronic',             'Pop-Folk',
    'Eurodance',              'Dream',
    'Southern Rock',          'Comedy',
    'Cult',                   'Gangsta Rap',
    'Top 40',                 'Christian Rap',
    'Pop/Funk',               'Jungle',
    'Native American',        'Cabaret',
    'New Wave',               'Psychedelic',
    'Rave',                   'Showtunes',
    'Trailer',                'Lo-Fi',
    'Tribal',                 'Acid Punk',
    'Acid Jazz',              'Polka',
    'Retro',                  'Musical',
    'Rock & Roll',            'Hard Rock',
    'Folk',                   'Folk/Rock',
    'National Folk',          'Swing',
    'Fast-Fusion',            'Bebob',
    'Latin',                  'Revival',
    'Celtic',                 'Bluegrass',
    'Avantgarde',             'Gothic Rock',
    'Progressive Rock',       'Psychedelic Rock',
    'Symphonic Rock',         'Slow Rock',
    'Big Band',               'Chorus',
    'Easy Listening',         'Acoustic',
    'Humour',                 'Speech',
    'Chanson',                'Opera',
    'Chamber Music',          'Sonata',
    'Symphony',               'Booty Bass',
    'Primus',                 'Porn Groove',
    'Satire',                 'Slow Jam',
    'Club',                   'Tango',
    'Samba',                  'Folklore',
    'Ballad',                 'Power Ballad',
    'Rhythmic Soul',          'Freestyle',
    'Duet',                   'Punk Rock',
    'Drum Solo',              'A Cappella',
    'Euro-House',             'Dance Hall',
    'Goa',                    'Drum & Bass',
    'Club-House',             'Hardcore',
    'Terror',                 'Indie',
    'BritPop',                'Negerpunk',
    'Polsk Punk',             'Beat',
    'Christian Gangsta Rap',  'Heavy Metal',
    'Black Metal',            'Crossover',
    'Contemporary Christian', 'Christian Rock',
    'Merengue',               'Salsa',
    'Thrash Metal',           'Anime',
    'JPop',                   'Synthpop'
);

my %cddb_to_id3 = (
    'data'       => 'Other',
    'folk'       => 'Folk',
    'jazz'       => 'Jazz',
    'misc'       => 'Other',
    'rock'       => 'Rock',
    'country'    => 'Country',
    'blues'      => 'Blues',
    'newage'     => 'New Age',
    'reggae'     => 'Reggae',
    'classical'  => 'Classical',
    'soundtrack' => 'Soundtrack'
);

my ( $cddbp, @discs, @toc, @incomplete, $cd_drive_in_use, @recently_completed );
my (
    $cddbid,        $track_numbers, $track_lengths,
    $track_offsets, $total_seconds, @data_tracks
);
my (
    $get_cdinfo_process, %file_watchers, %rip_pids,
    %ripper_data,        %incomplete_status
);

if ($Reload) {
    $cd_drive_in_use    = 0;
    $get_cdinfo_process = new Process_Item(
        "$config_parms{mp3Rip_cdinfo} > $config_parms{mp3Rip_work_dir}/cd-info.curr"
    );
    $cddbp = new CDDB;
    print_log "mp3Rip: cddbids still being processed: $Save{'mp3Rip_pending'}"
      if $main::Debug{mp3Rip};
    foreach ( split( /\s+/, $Save{'mp3Rip_pending'} ) ) {
        &mp3Rip_attempt_reattach_and_restart($_);
    }
    @incomplete = ();
    if ( opendir( MP3RIPWORKDIR, "$config_parms{mp3Rip_work_dir}/" ) ) {
        while ( my $entry = readdir(MP3RIPWORKDIR) ) {
            next if $entry =~ /^\./;
            if ( $entry =~ /^(.+)\.data$/ ) {
                my $cddbid = $1;
                unless ( $Save{'mp3Rip_pending'} =~ /$cddbid/ ) {
                    print_log "mp3Rip($cddbid): Found stray data file"
                      if $main::Debug{mp3Rip};
                    push @incomplete, $cddbid;
                }
            }
        }
        closedir MP3RIPWORKDIR;
    }
}

sub mp3Rip_cd_drive_in_use {
    return $cd_drive_in_use;
}

sub mp3Rip_attempt_reattach_and_restart {
    my ($cddbid) = @_;
    print_log "mp3Rip($cddbid): attempting to reattach" if $main::Debug{mp3Rip};
    unless ( &mp3Rip_reattach_rip_process($cddbid) ) {
        print_log "mp3Rip($cddbid): failed to reattach" if $main::Debug{mp3Rip};
        unless ( &mp3Rip_start_ripper_process($cddbid) ) {
            print_log "mp3Rip($cddbid): failed to restart"
              if $main::Debug{mp3Rip};
            &mp3Rip_remove_pending($cddbid);
            return 0;
        }
    }
    return 1;
}

sub mp3Rip_remove_pending {
    my ($cddbid) = @_;
    print_log
      "mp3Rip($cddbid): Process no longer running (pending=$Save{'mp3Rip_pending'})"
      if $main::Debug{mp3Rip};
    $Save{'mp3Rip_pending'} =~ s/\s*$cddbid\s*/ /;
    $Save{'mp3Rip_pending'} =~ s/\s+$//;
    $Save{'mp3Rip_pending'} =~ s/^\s+//;
    print_log "mp3Rip($cddbid): After (pending=$Save{'mp3Rip_pending'})"
      if $main::Debug{mp3Rip};
    if ( $file_watchers{$cddbid} ) {
        delete $file_watchers{$cddbid};
    }
    if ( $rip_pids{$cddbid} ) {
        delete $rip_pids{$cddbid};
    }
}

sub mp3Rip_get_incomplete {
    my @ret;
    foreach (@incomplete) {
        my $entry;
        $entry->[0] = $_;
        $entry->[1] = &mp3Rip_read_key_from_data_file( $_, 'artist' );
        $entry->[2] = &mp3Rip_read_key_from_data_file( $_, 'album' );
        if ( $incomplete_status{$_} ) {
            $entry->[3] = $incomplete_status{$_};
        }
        else {
            $entry->[3] = 'UNKNOWN';
        }
        push @ret, $entry;
    }
    return (@ret);
}

sub mp3Rip_get_pending {
    my @ret;
    foreach ( split( /\s+/, $Save{'mp3Rip_pending'} ) ) {
        my $entry;
        $entry->[0] = $_;
        $entry->[1] = $ripper_data{$_}->{'artist'};
        $entry->[2] = $ripper_data{$_}->{'album'};
        $entry->[3] = $ripper_data{$_}->{'current'};
        $entry->[4] =
          "$ripper_data{$_}->{'rip_done_count'} / $ripper_data{$_}->{'total_tracks'} Complete";
        if ( $ripper_data{$_}->{'total_length'} ) {
            $entry->[5] = int(
                (
                    $ripper_data{$_}->{'rip_done_length'} /
                      $ripper_data{$_}->{'total_length'}
                ) * 100
            );
            $entry->[5] .= '%';
        }
        if ( defined( $ripper_data{$_}->{'compress_done_count'} ) ) {
            $entry->[6] =
              "$ripper_data{$_}->{'compress_done_count'} / $ripper_data{$_}->{'total_tracks'} Complete";
        }
        else {
            $entry->[6] = 'Not Started';
        }
        if ( $ripper_data{$_}->{'total_length'} ) {
            $entry->[7] = int(
                (
                    $ripper_data{$_}->{'compress_done_length'} /
                      $ripper_data{$_}->{'total_length'}
                ) * 100
            );
            $entry->[7] .= '%';
        }
        if ( $ripper_data{$_}->{'rip_time'} ) {
            $entry->[8] = $ripper_data{$_}->{'rip_time'};
        }
        if ( $ripper_data{$_}->{'rip_predicted_remaining'} ) {
            $entry->[9] = $ripper_data{$_}->{'rip_predicted_remaining'};
        }
        if ( $ripper_data{$_}->{'compress_time'} ) {
            $entry->[10] = $ripper_data{$_}->{'compress_time'};
        }
        if ( $ripper_data{$_}->{'compress_predicted_remaining'} ) {
            $entry->[11] = $ripper_data{$_}->{'compress_predicted_remaining'};
        }
        for ( my $i = 0; $i <= 11; $i++ ) {
            $entry->[$i] = 'Unknown' unless $entry->[$i];
        }
        push @ret, $entry;
    }
    return (@ret);
}

sub mp3Rip_start_watching {
    my ($cddbid) = @_;
    if ( $ripper_data{$cddbid} ) {
        delete $ripper_data{$cddbid};
    }
    $ripper_data{$cddbid}->{'finished'} = 0;
    $ripper_data{$cddbid}->{'restart'}  = 1;
    my $watcher = new File_Item "$config_parms{mp3Rip_work_dir}/$cddbid.log";
    if ( $watcher->exist() ) {
        my @lines = $watcher->read_all();
        my $count = 0;
        foreach (@lines) {
            $count++;
            &mp3Rip_process_log_entry( $cddbid, $_ );
        }
        $watcher->set_index($count);
    }
    $watcher->set_watch();
    $file_watchers{$cddbid} = $watcher;
    return 1;
}

sub mp3Rip_get_pid {
    my ($cddbid) = @_;
    unless ( open( MP3RIPPID, "$config_parms{mp3Rip_work_dir}/$cddbid.pid" ) ) {
        return 0;
    }
    my $pid = <MP3RIPPID>;
    close MP3RIPPID;
    chomp($pid);
    return $pid;
}

sub mp3Rip_reattach_rip_process {
    my ($cddbid) = @_;
    print_log "mp3Rip($cddbid): mp3Rip_reattach_rip_process()"
      if $main::Debug{mp3Rip};
    my $pid = &mp3Rip_get_pid($cddbid);
    unless ($pid) {
        print_log "mp3Rip($cddbid): failed to open PID file"
          if $main::Debug{mp3Rip};
        return 0;
    }
    print_log "mp3Rip($cddbid): Got PID '$pid'" if $main::Debug{mp3Rip};
    return 0 unless $pid;

    # Make sure the process is still running
    return 0 unless ( -d "/proc/$pid" );
    print_log "mp3Rip($cddbid): PID '$pid' still running"
      if $main::Debug{mp3Rip};
    return &mp3Rip_start_watching($cddbid);
}

sub mp3Rip_start_ripper_process {
    my ($cddbid) = @_;
    print_log "mp3Rip($cddbid): mp3Rip_start_ripper_process()"
      if $main::Debug{mp3Rip};
    return 0 unless &mp3Rip_start_watching($cddbid);
    if (
        $ripper_data{$cddbid}
        and ( $ripper_data{$cddbid}->{'finished'}
            or not $ripper_data{$cddbid}->{'restart'} )
      )
    {
        &mp3Rip_remove_pending($cddbid);
        return 0;
    }
    else {
        # Start with a wrapper script so that if Misterhouse restarts the process keeps running
        my $rip_process = new Process_Item(
            "mp3Rip $config_parms{mp3Rip_work_dir}/$cddbid.data $config_parms{mp3Rip_work_dir}/$cddbid.log $config_parms{mp3Rip_work_dir}/$cddbid.pid"
        );
        $rip_process->start();
    }
    if ( $config_parms{mp3Rip_log_file} ) {
        if ( open( MP3RIPLOG, ">>$config_parms{mp3Rip_log_file}" ) ) {
            my $log_entry = "$Time_Date: [$cddbid] Starting ripping process.";
            print MP3RIPLOG "$log_entry\n";
            close MP3RIPLOG;
        }
    }
    unless ( $ripper_data{$cddbid} and $ripper_data{$cddbid}->{'current'} ) {
        $ripper_data{$cddbid}->{'current'} = 'Starting';
    }
    &mp3Rip_make_pending($cddbid);
    return 1;
}

sub mp3Rip_start_rip {
    my $cddbid   = '';
    my $genrestr = '';
    foreach (@_) {
        if (/cddbid=(.+)$/) {
            $cddbid = $1;
        }
        elsif (/^genre=(.+)$/) {
            $genrestr = $1;
            for ( my $i = 0; $i <= $#id3_genres; $i++ ) {
                if ( $1 eq $id3_genres[$i] ) {
                    s/^.*$/genre=$i/;
                }
            }
        }
    }
    unless ($cddbid) {
        return "No cddbid found!";
    }
    print_log
      "mp3Rip($cddbid): mp3Rip_start_rip(pending=$Save{'mp3Rip_pending'})"
      if $main::Debug{mp3Rip};
    if ( $Save{'mp3Rip_pending'} =~ /$cddbid/ ) {
        return "There is already a rip in progress for $cddbid";
    }
    unless (
        open( MP3RIPDATA, ">$config_parms{mp3Rip_work_dir}/$cddbid.data" ) )
    {
        return
          "Could not create file: $config_parms{mp3Rip_work_dir}/$cddbid.data";
    }
    foreach (@_) {
        print MP3RIPDATA "$_\n";
    }
    if ($genrestr) {
        print MP3RIPDATA "genrestr=$genrestr\n";
    }
    print MP3RIPDATA "eject=$config_parms{mp3Rip_eject}\n";
    print MP3RIPDATA "wav_dir=$config_parms{mp3Rip_wav_dir}\n";
    print MP3RIPDATA "cdripper=$config_parms{mp3Rip_cdripper}\n";
    print MP3RIPDATA "mp3_encoder=$config_parms{mp3Rip_mp3_encoder}\n";
    if ( $config_parms{mp3Rip_disc_data_file} ) {
        print MP3RIPDATA
          "disc_data_file=$config_parms{mp3Rip_disc_data_file}\n";
    }
    close(MP3RIPDATA);
    unlink("$config_parms{mp3Rip_work_dir}/$cddbid.log");
    &mp3Rip_start_ripper_process($cddbid);
    return '';
}

sub mp3Rip_get_dir_name {
    my ( $genre, $artist, $album ) = @_;
    if ( $config_parms{mp3Rip_genre_lowercase} ) {
        $genre = lc($genre);
    }
    $genre  = &mp3Rip_convert_to_filename($genre);
    $artist = &mp3Rip_convert_to_filename($artist);
    $album  = &mp3Rip_convert_to_filename($album);
    my $ret = $config_parms{mp3Rip_default_dir_name};
    $ret =~ s/__genre__/$genre/;
    $ret =~ s/__artist__/$artist/;
    $ret =~ s/__album__/$album/;
    return "$config_parms{mp3Rip_mp3_dir}/$ret";
}

sub mp3Rip_get_filename {
    my ( $track, $artist, $title, $album, $genre ) = @_;
    if ( $config_parms{mp3Rip_genre_lowercase} ) {
        $genre = lc($genre);
    }
    $track =~ s/^(\d)$/0$1/;
    $artist = &mp3Rip_convert_to_filename($artist);
    $title  = &mp3Rip_convert_to_filename($title);
    my $ret = $config_parms{mp3Rip_default_mp3_name};
    $ret =~ s/__genre__/$genre/;
    $ret =~ s/__album__/$album/;
    $ret =~ s/__artist__/$artist/;
    $ret =~ s/__song__/$title/;
    $ret =~ s/__track__/$track/;
    return $ret;
}

sub mp3Rip_get_id3_genres {
    return (@id3_genres);
}

sub mp3Rip_fix_underscores {
    my $name = $_[0];

    # Turn '-_' or '_-' or '_-_' or : into '-'
    $name =~ s/(_-_)|(-_)|(_-)|\:/-/g;

    # Get rid of multiple __ or -- in a row
    $name =~ s/--+/-/g;
    $name =~ s/__+/_/g;

    return $name;
}

sub mp3Rip_drop_non_ascii {
    my $name = $_[0];
    $name =~ tr/\xa0\xa1\xa6\xa8\xa9\xaa\xae\xb0\xb2\xb3\xb4/ !|"CaRo23'/;
    $name =~ s/(\xa2\xa3\xa4\xa5)/\$/g;
    $name =~ s/\xab/<</g;
    $name =~ tr/\xb5\xb6\xb7\xb8\xb9\xba\xbf/uP.,1o?/;
    $name =~ s/\xa7/ Sec /g;
    $name =~ s/\xb1/+\/-/g;
    $name =~ s/\xbb/>>/g;
    $name =~ s/\xbc/1\/4/g;
    $name =~ s/\xbd/1\/2/g;
    $name =~ s/\xbe/3\/4/g;
    $name =~ s/[\xc0-\xc5]/A/g;
    $name =~ s/\xc6/AE/g;
    $name =~ s/\xc7/C/g;
    $name =~ s/[\xc8-\xcb]/E/g;
    $name =~ s/[\xcc-\xcf]/I/g;
    $name =~ s/\xd0/D/g;
    $name =~ s/\xd1/N/g;
    $name =~ s/[\xd2-\xd6]/O/g;
    $name =~ s/\xd7/x/g;
    $name =~ s/\xd8/0/g;
    $name =~ s/[\xd9-\xdc]/U/g;
    $name =~ s/\xdd/Y/g;
    $name =~ s/\xde/P/g;
    $name =~ s/\xdf/B/g;
    $name =~ s/[\xe0-\xe5]/a/g;
    $name =~ s/\xe6/ae/g;
    $name =~ s/\xe7/c/g;
    $name =~ s/[\xe8-\xeb]/e/g;
    $name =~ s/[\xec-\xef]/i/g;
    $name =~ s/\xf0/o/g;
    $name =~ s/\xf1/n/g;
    $name =~ s/[\xf2-\xf6]/o/g;
    $name =~ s/\xf7/\//g;
    $name =~ s/\xf8/o/g;
    $name =~ s/[\xf9-\xfc]/u/g;
    $name =~ s/\xfd/y/g;
    $name =~ s/\xfe/p/g;
    $name =~ s/\xff/y/g;

    # Drop any remaining non-ascii characters
    $name =~ tr/\x20-\x7e//cd;
    return $name;
}

sub mp3Rip_convert_to_filename {
    my $name = $_[0];

    $name = &mp3Rip_drop_non_ascii($name);

    # Forward slashes / back slashes -> hyphen
    $name =~ s=/\\=-=g;

    if ( $config_parms{mp3Rip_files_no_parens} ) {

        # Turn ' (blah)' into '-blah'
        $name =~ s/\((.*)\)/-$1/g;
        $name =~ s/[()]//g;
    }

    if ( $config_parms{mp3Rip_files_no_square_brackets} ) {

        # Turn ' [blah]' into '-blah'
        $name =~ s/\[(.*)\]/-$1/g;
        $name =~ s/[\[\]]//g;
    }

    if ( $config_parms{mp3Rip_files_no_curly_brackets} ) {

        # Turn ' {blah}' into '-blah'
        $name =~ s/\{(.*)\}/-$1/g;
        $name =~ s/[{}]//g;
    }

    if ( $config_parms{mp3Rip_files_ampersand_or_plus_to_and} ) {

        # Turn '&' or '+' into 'and'
        $name =~ s/\s*[&+]\s*/ and /g;
    }

    if ( $config_parms{mp3Rip_files_no_spaces} ) {

        # Turn spaces into underscores
        $name =~ s/ /_/g;
        $name =~ s/^_+//;
        $name =~ s/_+$//;
        $name = &mp3Rip_fix_underscores($name);
    }
    else {
        $name =~ s/\s+/ /g;
        $name =~ s/^\s+//;
        $name =~ s/\s+$//;
    }

    if ( $config_parms{mp3Rip_files_no_special_chars} ) {
        $name =~ tr/\x21-\x27//d;
        $name =~ tr/\x3a-\x40//d;
        $name =~ tr/\x2a\x2c\x2e\x2f\x5c\x5e\x60\x7c\x7e//d;
    }

    if ( $config_parms{mp3Rip_files_format_disc_number} ) {

        # Rename any form of disk or disc to Disc
        $name =~ s/\b(disk|disc)\b/Disc/ig;
        $name =~ s/Disc(\d+)/Disc_$1/;
    }

    $name = &mp3Rip_fix_underscores($name);

    return ($name);
}

sub mp3Rip_check_caps($) {
    my $name = $_[0];
    open( DEBUG, ">>/tmp/debug" );
    print DEBUG "Begin: [$name]\n";

    $name = &mp3Rip_drop_non_ascii($name);

    # Capitalize first letters
    $name =~ s/(^|\s+)(.)/$1 . uc($2)/e;

    # Make sure the, of, a, an, from are not caps
    while ( $name =~
        s/\s+($config_parms{mp3Rip_first_letter_caps_ignore_list})\s+/' ' . lc($1) . ' '/e
      )
    {
        1;
    }

    print DEBUG "End  : [$name]\n";
    close DEBUG;
    return ($name);
}

sub mp3Rip_get_cdinfo {
    @discs = ();
    unlink("$config_parms{mp3Rip_work_dir}/cd-info.curr");
    mkdir("$config_parms{mp3Rip_work_dir}");
    $get_cdinfo_process->start();
}

sub mp3Rip_is_cdinfo_ready {
    return $get_cdinfo_process->done();
}

sub mp3Rip_parse_cdinfo {
    unless ( -s "$config_parms{mp3Rip_work_dir}/cd-info.curr" ) {
        return ( undef, undef, undef );
    }

    # Look for data tracks
    @data_tracks = ();
    unless ( open( CDINFO, "$config_parms{mp3Rip_work_dir}/cd-info.curr" ) ) {
        return ( undef, undef, undef );
    }
    while ( my $line = <CDINFO> ) {
        if ( $line =~ /^\s*(\d+): \d\d:\d\d:\d\d\s+\d+\s+data/ ) {
            my $track = $1;
            $track =~ s/^(\d)$/0$1/;
            $track =~ s/^(\d\d)$/0$1/;
            push @data_tracks, $track;
        }
    }
    close CDINFO;

    my @toc =
      $cddbp->parse_cdinfo("$config_parms{mp3Rip_work_dir}/cd-info.curr");
    unless (@toc) {
        return ( undef, undef, undef );
    }
    ( $cddbid, $track_numbers, $track_lengths, $track_offsets, $total_seconds )
      = $cddbp->calculate_id(@toc);
    unless ($cddbid) {
        return ( undef, undef, undef );
    }

    # Remove data tracks
    for ( my $i = 0; $i <= $#{@$track_numbers}; $i++ ) {
        foreach (@data_tracks) {
            if ( $track_numbers->[$i] eq $_ ) {
                splice @$track_numbers, $i, 1;
            }
        }
    }
    print_log "mp3Rip($cddbid): track numbers = @$track_numbers"
      if $main::Debug{mp3Rip};
    print_log "mp3Rip($cddbid): track lengths = @$track_lengths"
      if $main::Debug{mp3Rip};
    print_log "mp3Rip($cddbid): total seconds = $total_seconds"
      if $main::Debug{mp3Rip};
    return ( $cddbid, $track_numbers, $track_lengths, $total_seconds );
}

sub mp3Rip_convert_genre_to_id3 {
    return $cddb_to_id3{ $_[0] } if $cddb_to_id3{ $_[0] };
    return $_[0];
}

sub mp3Rip_get_cddb_discs {
    unless (@discs) {

        # It seems I have to disconnect and reconnect for each new CD
        $cddbp->disconnect();
        $cddbp->connect();
        @discs = $cddbp->get_discs( $cddbid, $track_offsets, $total_seconds );
    }
    return @discs;
}

sub mp3Rip_get_disc_details {
    my ( $genre, $cddbid, $title ) = @{ $_[0] };
    my $disc_info = $cddbp->get_disc_details( $genre, $cddbid );
    my $artist = $disc_info->{dtitle};
    $artist =~ s/ \/ .+$//;
    my $album = $disc_info->{dtitle};
    $album =~ s/^.+ \/ //;
    return ( &mp3Rip_convert_genre_to_id3($genre),
        $artist, $album, @{ $disc_info->{ttitles} } );
}

sub mp3Rip_read_key_from_data_file {
    my ( $cddbid, $key ) = @_;
    my $ret = '';
    open( MP3RIPDATAFILE, "$config_parms{mp3Rip_work_dir}/$cddbid.data" );
    while ( my $line = <MP3RIPDATAFILE> ) {
        chomp($line);
        if ( $line =~ s/^$key=// ) {
            $ret = $line;
            last;
        }
    }
    close MP3RIPDATAFILE;
    return $ret;
}

sub mp3Rip_clean {
    my ($cddbid) = @_;
    my $dir = &mp3Rip_read_key_from_data_file( $cddbid, 'dir' );
    unlink("$config_parms{mp3Rip_work_dir}/$cddbid.log");
    unlink("$config_parms{mp3Rip_work_dir}/$cddbid.pid");
    unless (
            $ripper_data{$cddbid}
        and $ripper_data{$cddbid}->{'total_tracks'}
        and $ripper_data{$cddbid}->{'rip_done_count'}
        and ( $ripper_data{$cddbid}->{'rip_done_count'} ==
            $ripper_data{$cddbid}->{'total_tracks'} )
      )
    {
        if ( opendir( MP3RIPWAVDIR, "$config_parms{mp3Rip_wav_dir}/$cddbid" ) )
        {
            while ( my $entry = readdir(MP3RIPWAVDIR) ) {
                next if $entry =~ /^\./;
                unlink "$config_parms{mp3Rip_wav_dir}/$cddbid/$entry";
            }
            close MP3RIPWAVDIR;
        }
    }
    if ( opendir( MP3RIPWAVDIR, "$dir" ) ) {
        while ( my $entry = readdir(MP3RIPWAVDIR) ) {
            next if $entry =~ /^\./;
            unlink "$dir/$entry";
        }
        close MP3RIPWAVDIR;
    }
    if ( $ripper_data{$cddbid} ) {
        delete $ripper_data{$cddbid};
    }
}

sub mp3Rip_abort {
    my ($cddbid) = @_;
    $ripper_data{$cddbid}->{'restart'} = 0;
    print_log "mp3Rip($cddbid): Aborted" if $main::Debug{mp3Rip};
    my $dir = &mp3Rip_read_key_from_data_file( $cddbid, 'dir' );
    push @incomplete, $cddbid unless grep( /$cddbid/, @incomplete );
    $incomplete_status{$cddbid} = $ripper_data{$cddbid}->{'current'};

    #unlink("$config_parms{mp3Rip_work_dir}/$cddbid.log");
    unlink("$config_parms{mp3Rip_work_dir}/$cddbid.pid");
    if ( $rip_pids{$cddbid} ) {
        if ( -d "/proc/$rip_pids{$cddbid}" ) {
            my $kill = new Process_Item(
                "kill $rip_pids{$cddbid} ; sleep 5 ; kill -9 $rip_pids{$cddbid}"
            );
            $kill->start();
        }
    }
    &mp3Rip_handle_ripper_exit($cddbid);
    return $dir;
}

sub mp3Rip_delete_partial {
    my ($cddbid) = @_;
    &mp3Rip_remove_partial_entry($cddbid);
    my $dir = &mp3Rip_read_key_from_data_file( $cddbid, 'dir' );
    unlink("$config_parms{mp3Rip_work_dir}/$cddbid.log");
    unlink("$config_parms{mp3Rip_work_dir}/$cddbid.data");
    unlink("$config_parms{mp3Rip_work_dir}/$cddbid.pid");
    if ( $ripper_data{$cddbid} ) {
        delete $ripper_data{$cddbid};
    }
    return $dir;
}

sub mp3Rip_remove_partial_entry {
    my ($cddbid) = @_;
    for ( my $i = 0; $i <= $#incomplete; $i++ ) {
        if ( $incomplete[$i] eq $cddbid ) {
            splice @incomplete, $i, 1;
            last;
        }
    }
}

sub mp3Rip_make_pending {
    my ($cddbid) = @_;
    print_log
      "mp3Rip($cddbid): mp3Rip_make_pending(before=$Save{'mp3Rip_pending'})"
      if $main::Debug{mp3Rip};
    unless ( $Save{'mp3Rip_pending'} =~ /$cddbid/ ) {
        $Save{'mp3Rip_pending'} .= " $cddbid";
        $Save{'mp3Rip_pending'} =~ s/^\s+//;
    }
    print_log
      "mp3Rip($cddbid): mp3Rip_make_pending(after=$Save{'mp3Rip_pending'})"
      if $main::Debug{mp3Rip};
    &mp3Rip_remove_partial_entry($cddbid);
}

sub mp3Rip_get_recently_completed {
    return (@recently_completed);
}

sub mp3Rip_rip_complete {
    my ($cddbid) = @_;
    $ripper_data{$cddbid}->{'current'} = 'Finished';
    my $total_time =
      &mp3Rip_format_time( $ripper_data{$cddbid}->{'rip_time'} +
          $ripper_data{$cddbid}->{'compress_time'} );
    my $log_entry =
      "$Time_Date: [$cddbid] Finished $ripper_data{$cddbid}->{'album'} by $ripper_data{$cddbid}->{'artist'} (Total Time: $total_time, $ripper_data{$cddbid}->{'total_tracks'} Tracks in $ripper_data{$cddbid}->{'dir'})";
    push @recently_completed, $log_entry;
    if ( $config_parms{mp3Rip_log_file} ) {
        if ( open( MP3RIPLOG, ">>$config_parms{mp3Rip_log_file}" ) ) {
            print MP3RIPLOG "$log_entry\n";
            close MP3RIPLOG;
        }
    }
    $ripper_data{$cddbid}->{'finished'} = 1;
    $ripper_data{$cddbid}->{'restart'}  = 0;
    unlink("$config_parms{mp3Rip_work_dir}/$cddbid.pid");
    if ( $config_parms{mp3Rip_archive_dir} ) {
        mkdir("$config_parms{mp3Rip_archive_dir}");
        move(
            "$config_parms{mp3Rip_work_dir}/$cddbid.log",
            "$config_parms{mp3Rip_archive_dir}/$cddbid.log"
        );
        move(
            "$config_parms{mp3Rip_work_dir}/$cddbid.data",
            "$config_parms{mp3Rip_archive_dir}/$cddbid.data"
        );
    }
    else {
        unlink("$config_parms{mp3Rip_work_dir}/$cddbid.log");
        unlink("$config_parms{mp3Rip_work_dir}/$cddbid.data");
    }
    &mp3Rip_remove_pending($cddbid);
}

sub mp3Rip_format_time ($) {
    my $time = $_[0];
    return $time unless $time =~ /^\d+$/;
    my ( $min, $hours ) = ( 0, 0 );
    if ( $min = int( $time / 60 ) ) {
        $time = ( $time - ( 60 * $min ) );
    }
    if ( $hours = int( $min / 60 ) ) {
        $min = ( $min - ( 60 * $hours ) );
    }
    $time =~ s/^(\d)$/0$1/;
    $min =~ s/^(\d)$/0$1/;
    if ($hours) {
        return ("$hours:$min:$time");
    }
    else {
        return ("$min:$time");
    }
}

sub mp3Rip_unformat_time ($) {
    my $time = $_[0];
    my $ret  = 0;
    if ( $time =~ s/(\d\d)$// ) {
        $ret += $1;
    }
    if ( $time =~ s/(\d\d):$// ) {
        $ret += ( $1 * 60 );
    }
    if ( $time =~ /(\d+):$/ ) {
        $ret += ( $1 * 3600 );
    }
    return $ret;
}

sub mp3Rip_process_log_entry {
    my ( $cddbid, $line ) = @_;
    if ( $line eq 'Rip Completed' ) {
        &mp3Rip_rip_complete($cddbid);
    }
    elsif ( $line eq 'CD Drive In Use' ) {
        $cd_drive_in_use = 1;
    }
    elsif ( $line eq 'CD Drive Not In Use' ) {
        $cd_drive_in_use = 0;
    }
    elsif ( $line =~ /^Output Directory: (.+)/ ) {
        $ripper_data{$cddbid}->{'dir'} = $1;
    }
    elsif ( $line =~ /^Artist: (.+)/ ) {
        $ripper_data{$cddbid}->{'artist'} = $1;
    }
    elsif ( $line =~ /^Album: (.+)/ ) {
        $ripper_data{$cddbid}->{'album'} = $1;
    }
    elsif ( $line =~ /^Total Length: (\d+) seconds/ ) {
        $ripper_data{$cddbid}->{'total_length'} = $1;
    }
    elsif ( $line =~ /^total tracks: (\d+)/ ) {
        $ripper_data{$cddbid}->{'rip_done_count'} = 0
          unless $ripper_data{$cddbid}->{'rip_done_count'};
        $ripper_data{$cddbid}->{'rip_done_length'} = 0
          unless $ripper_data{$cddbid}->{'rip_done_count'};
        $ripper_data{$cddbid}->{'compress_done_count'} = undef
          unless $ripper_data{$cddbid}->{'compress_done_count'};
        $ripper_data{$cddbid}->{'compress_done_length'} = 0
          unless $ripper_data{$cddbid}->{'compress_done_count'};
        $ripper_data{$cddbid}->{'rip_time'} = 0
          unless $ripper_data{$cddbid}->{'rip_time'};
        $ripper_data{$cddbid}->{'compress_time'} = 0
          unless $ripper_data{$cddbid}->{'compress_time'};
        $ripper_data{$cddbid}->{'total_tracks'} = $1;
    }
    elsif ( $line =~ /^Ripping track (\d+) to .+ \(length: (\d+) seconds\)/ ) {
        $ripper_data{$cddbid}->{'current'} =
          "Ripping track $1 (" . &mp3Rip_format_time($2) . ')';
        $ripper_data{$cddbid}->{'current_length'} = $2;
    }
    elsif (
        $line =~ /^Compressing track (\d+) to .+ \(length: (\d+) seconds\)/ )
    {
        $ripper_data{$cddbid}->{'current'} =
          "Compressing track $1 (" . &mp3Rip_format_time($2) . ')';
        $ripper_data{$cddbid}->{'compress_done_count'} = 0
          unless $ripper_data{$cddbid}->{'compress_done_count'};
        $ripper_data{$cddbid}->{'current_length'} = $2;
    }
    elsif ( $line =~ /^Done ripping track (\d+) to .+ \(rip time: (.+)\)/ ) {
        $ripper_data{$cddbid}->{'rip_done_count'} = $1;
        $ripper_data{$cddbid}->{'rip_done_length'} +=
          $ripper_data{$cddbid}->{'current_length'};
        $ripper_data{$cddbid}->{'rip_time'} += &mp3Rip_unformat_time($2);
        if ( $ripper_data{$cddbid}->{'rip_done_count'} ==
            $ripper_data{$cddbid}->{'total_tracks'} )
        {
            $ripper_data{$cddbid}->{'rip_predicted_remaining'} = 'Finished';
        }
        elsif ( $ripper_data{$cddbid}->{'rip_done_length'} ) {
            $ripper_data{$cddbid}->{'rip_predicted_total'} = int(
                $ripper_data{$cddbid}->{'total_length'} * (
                    $ripper_data{$cddbid}->{'rip_time'} /
                      $ripper_data{$cddbid}->{'rip_done_length'}
                )
            );
            $ripper_data{$cddbid}->{'rip_predicted_remaining'} =
              $ripper_data{$cddbid}->{'rip_predicted_total'} -
              $ripper_data{$cddbid}->{'rip_time'};
        }
    }
    elsif (
        $line =~ /^Done compressing track (\d+) to .+ \(compress time: (.+)\)/ )
    {
        $ripper_data{$cddbid}->{'compress_done_count'} = $1;
        $ripper_data{$cddbid}->{'compress_done_length'} +=
          $ripper_data{$cddbid}->{'current_length'};
        $ripper_data{$cddbid}->{'compress_time'} += &mp3Rip_unformat_time($2);
        if ( $ripper_data{$cddbid}->{'compress_done_count'} ==
            $ripper_data{$cddbid}->{'total_tracks'} )
        {
            $ripper_data{$cddbid}->{'compress_predicted_remaining'} =
              'Finished';
        }
        elsif ( $ripper_data{$cddbid}->{'compress_done_length'} ) {
            $ripper_data{$cddbid}->{'compress_predicted_total'} = int(
                $ripper_data{$cddbid}->{'total_length'} * (
                    $ripper_data{$cddbid}->{'compress_time'} /
                      $ripper_data{$cddbid}->{'compress_done_length'}
                )
            );
            $ripper_data{$cddbid}->{'compress_predicted_remaining'} =
              $ripper_data{$cddbid}->{'compress_predicted_total'} -
              $ripper_data{$cddbid}->{'compress_time'};
        }
    }
    elsif ( $line =~ s/^FATAL: // ) {
        $ripper_data{$cddbid}->{'restart'} = 0;
        $ripper_data{$cddbid}->{'current'} = $line;
        &mp3Rip_abort($cddbid);
    }
    else {
        print_log "mp3Rip($cddbid): Got unknown line: " . $line
          if $main::Debug{mp3Rip};
    }
    chomp($line);
}

sub mp3Rip_handle_ripper_exit {
    my ($cddbid) = @_;
    if ( $rip_pids{$cddbid} ) {
        delete $rip_pids{$cddbid};
    }
    unless ( $ripper_data{$cddbid}->{'finished'} ) {
        if ( $ripper_data{$cddbid}->{'restart'} ) {
            return &mp3Rip_attempt_reattach_and_restart($_);
        }
    }
    &mp3Rip_remove_pending($cddbid);
    $cd_drive_in_use = 0;
}

# Watch the progress of any ongoing ripping processes...
foreach my $cddbid ( keys %file_watchers ) {
    unless ( $rip_pids{$cddbid} ) {
        if ( -f "$config_parms{mp3Rip_work_dir}/$cddbid.pid" ) {
            my $pid = &mp3Rip_get_pid($cddbid);
            print_log "mp3Rip($cddbid): Got pid $pid" if $main::Debug{mp3Rip};
            $rip_pids{$cddbid} = $pid;
        }
    }
    if ( $file_watchers{$cddbid}->changed() ) {
        my $index = $file_watchers{$cddbid}->get_index();
        my $line  = $file_watchers{$cddbid}->read_next_tail();
        while ( $index != $file_watchers{$cddbid}->get_index() ) {
            &mp3Rip_process_log_entry( $cddbid, $line );
            last unless $file_watchers{$cddbid};
            $index = $file_watchers{$cddbid}->get_index();
            $line  = $file_watchers{$cddbid}->read_next_tail();
        }
        $file_watchers{$cddbid}->set_watch() if $file_watchers{$cddbid};
    }
}
foreach ( keys %rip_pids ) {
    unless ( -d "/proc/$rip_pids{$_}" ) {
        &mp3Rip_handle_ripper_exit($_);
    }
}
