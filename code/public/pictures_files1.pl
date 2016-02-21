# Category=Pictures

=begin comment

From Robert Rozman on 04/2002

I'm attaching the code that I modified to act as a picture album viewer. You
simply put jpegs into separate directories under main picture directory -
build command will build playlists and then you can see them with modified
tk_photos.pl (I've maded out of latest add on for Tk picture viewing).

In mh.ini I have:
# Category = Pictures

@
@ This parm points the utilities to work with PHOTO PICTURES files
@
@ Pictures directory pointer used by media_player_control_control.pl
@
@

pictures_playlist_dir=d:/pictures_playlists
photoframe_url=/index.html
picture_time =10


I hope someone will find this scripts useful - search feature is still
untouched (I have some more for video collection, but would like to clean
code a little bit).


=cut

# Allow for loading playlists

# noloop=start      This directive allows this code to be run on startup/reload
my $pictures_file      = "$config_parms{data_dir}/pictures.dbm";
my $pictures_menu_file = "$config_parms{code_dir}/pictures.menu";
use vars qw($picturesnames %picturesfiles);
undef $picturesnames;
%picturesfiles = ();
( $picturesnames, %picturesfiles ) = &pictures_files;

use vars '@tk_photos';  # This will be persistent across passes and code reloads

# noloop=stop

# Build and search an Video database.
# Build the pictures database
$v_pictures_build_list = new Voice_Cmd '[Build,Load] the pictures database', '';
$v_pictures_build_list->set_info(
    "Builds/loads an pictures database for these directories: $config_parms{pictures_playlist_dir}"
);

$p_pictures_build_list = new Process_Item;

( $picturesnames, %picturesfiles ) = &pictures_files
  if 'Load' eq said $v_pictures_build_list;

my %pictures_dbm;
my %counts;

if ( 'Build' eq said $v_pictures_build_list) {
    undef $picturesnames;
    %picturesfiles = ();

    speak "Ok, rebuilding";
    unlink $pictures_file;

    # first search for individual files
    my @dirs = split ',', $config_parms{pictures_dir};
    print_log "Updating pictures database for @dirs";
    my $dir_name;
    foreach $dir_name (@dirs) {
        print_log "Updating pictures database in $dir_name";
        &read_pictures_dir($dir_name);
    }

    # first search for playlist files
    @dirs = split ',', $config_parms{pictures_playlist_dir};
    print_log "Updating pictures database for @dirs";
    foreach $dir_name (@dirs) {
        print_log "Updating pictures database in $dir_name";
        &read_pictures_playlist_dir($dir_name);
    }

    ( $picturesnames, %picturesfiles ) = &pictures_files;
    speak "pictures database build is done";
    print_log "Current pictures files:$picturesnames";
    &pictures_menu_create($pictures_menu_file);

    run_voice_cmd 'Parse menus';

}

sub pictures_files {

    my %data = dbm_read "$pictures_file";

    # Find the playlist files
    my ( $picturesnames1, %picturesfiles1 );
    undef $picturesnames1;
    %picturesfiles1 = ();

    #    return '', '', '' unless $pictures_dbm{file};
    for my $key ( sort keys %data ) {

        #        print_log "\nReading file:$key in path:$data{$key}\n";

        my $name = ucfirst lc $key;

        #        print_log "\nRenaming file:\'$key\' to \'$name\'\n";
        #	print_log  "DBM: KEY=$key VALUE=$data{$key}\n";
        my ($path) = ( $data{$key} =~ /[0-9]* (.*)/ );

        #	print_log  "Corrected DBM: KEY=$key VALUE=$path\n";

        $picturesnames1 .= $name . ',';

        #        print_log "\npicturesnames:$picturesnames1\n";
        $picturesfiles1{$name} = $path;
    }

    return 'none_found' unless $picturesnames1;
    chop $picturesnames1;    # Drop last ,
    print "pictures files: $picturesnames1 \n";

    #    print_log "pictures files:$picturesnames1\n";
    return $picturesnames1, %picturesfiles1;
}

$v_pictures_playlist1 =
  new Voice_Cmd("Set house picture player to file [$picturesnames]");
set_icon $v_pictures_playlist1 'playlist';

if ( $state = said $v_pictures_playlist1 ) {

    #    my $file_to_play = &dbm_read($pictures_file, $state);
    my $file_to_play = $picturesfiles{$state};
    @tk_photos = file_read $file_to_play;
    print_log "Playing pictures file:$state in path $file_to_play \n";

    run_voice_cmd 'Start the photo slideshow';
}

sub read_pictures_dir {
    my ($dir) = @_;
    print "  - Reading files in $dir\n";
    $counts{dir}++;
    opendir( picturesDIR, $dir )
      or do { print "Error in dir open: $!\n"; return };
    my @files = readdir picturesDIR;
    print "db files=@files\n";
    close picturesDIR;

    for my $file ( sort @files ) {
        next if $file eq '.' or $file eq '..';
        $file = "$dir/$file";
        &read_pictures_dir($file), next if -d $file;

        #       next if $file eq '.' or $file eq '..' or $file !~ /\.pictures$/i;
        #        open(picturesFILE, $file) or print "Error in in file open: $!\n";
        #    	print_log "Considering:$file\n";

        if ( $file =~ /.*\.(jpg|JPG)/i ) {
            my ( $fname, $dummy ) = ( $file =~ /(.*)\.(jpg|JPG)/i );
            ($fname) = ( $fname =~ m!.*/([^/]+)$! );
            $counts{file}++;
            print_log "DBM:$fname|$file\n";
            logit_dbm( $pictures_file, $fname, $file );
        }
    }
}

sub read_pictures_playlist_dir {
    my ($dir) = @_;
    print "  - Reading files in $dir\n";
    $counts{dir}++;
    opendir( picturesDIR, $dir )
      or do { print "Error in dir open: $!\n"; return };
    my @files = readdir picturesDIR;
    print "db files=@files\n";
    close picturesDIR;

    for my $file ( sort @files ) {
        next if $file eq '.' or $file eq '..' or $file =~ /.*\.txt/;

        my $ffname = $file;
        $file = "$dir/$file";
        my $playlist_file = $file . '.txt';
        unlink $playlist_file;

        opendir( picturesDIR, $file )
          or do { print "Error in dir open: $!\n"; return };
        my @files = readdir picturesDIR;
        print "db files=@files\n";
        close picturesDIR;

        my $playlist;
        for my $v_file ( sort @files ) {
            next if $v_file eq '.' or $v_file eq '..';
            $playlist = $playlist . "$ffname\\$v_file \n";
        }

        file_write $playlist_file, $playlist;
        $counts{file}++;
        print_log "DBM:$ffname|$file\n";
        logit_dbm( $pictures_file, $ffname, $playlist_file );
    }
}

sub pictures_search {
    my ($pictures_search) = @_;

    my %data = dbm_read "$pictures_file";

    # Find the playlist files
    my $picturesnames1;
    undef $picturesnames1;

    for my $key ( sort keys %data ) {

        #        print_log "\nReading file:$key in path:$data{$key}\n";

        my $name = ucfirst lc $key;

        if ( $name =~ /$pictures_search/i ) {
            print_log "Found $name in DBM\n";
            $picturesnames1 .= $name . ',';
        }
    }

    return 'none_found' unless $picturesnames1;
    return $picturesnames1;
}

sub pictures_menu_create {
    my ($file) = @_;
    my $menu_top =
      "# This is an auto-generated file.  Rename it before you edit it, then update pictures_files.pl to point to it\n\n";
    my $menu;
    $menu = "M: Pictures\n";
    $menu .= "  D: Picture Player\n";
    $menu .= "  D: Albums\n";
    $menu .= "  D: Pictures database\n";
    $menu .= "M: Picture Player\n";
    $menu .= "   D: Picture_player [Start,Stop,Next,Previous]\n";
    $menu .= "      A: [Start,Stop,Next,Previous] the photo slideshow\n";
    $menu .= "M: Albums\n";
    $menu .= "   D: Album file [$picturesnames]\n";
    $menu .= "	A: Set house picture player to file [$picturesnames]\n";
    $menu .= "M: Pictures database\n";
    $menu .= "   D: Pictures database [Build,Load]\n";
    $menu .= "	A: [Build,Load] the pictures database\n";
    unlink $file;
    &file_write( $file, $menu_top . $menu );
    return $menu_top . $menu;
}

