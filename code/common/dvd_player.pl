# Category=Entertainment

#@ Set dvd_program to DVD player program path. For example:
#@   dvd_program=C:\program files\intervideo\dvd6\windvd.exe # NOTE spaces are allowed
#@ Set dvd_archives_folder to folder with ripped DVD's.
#@   dvd_archives_folder=F:\archives\dvds
#@ Set dvd_favorites to list of favorite DVD's.
#@   dvd_favorites=Hulk,Indiana Jones and the Last Crusade,King Kong

# WinDVD only for now (tested with v6.)

use DVDPlayer;

#***Don't even create these objects if no WinDVD (look for above by default)  Do nothing on Linux
$dvd_player  = new DVDPlayer();
$dvd_marquee = new Generic_Item;

#&tk_entry('DVD', $dvd_marquee);
#noloop=start
my %dvd_states = (
    play               => 'play',
    stop               => 'stop',
    pause              => 'pause',
    rewind             => 'rewind',
    'fast forward'     => 'fast forward',
    step               => 'step',
    'skip forward'     => 'skip forward',
    'instant replay'   => 'instant replay',
    'root menu'        => 'root menu',
    'title menu'       => 'title menu',
    'volume up'        => 'vol +',
    'volume down'      => 'vol -',
    mute               => 'mute',
    unzoom             => 'unzoom',
    pan                => 'pan',
    angle              => 'angle',
    subtitle           => 'subtitle',
    'previous chapter' => 'previous chapter',
    'next chapter'     => 'next chapter',
    'eject'            => 'eject',
    'brightness up'    => 'brightness up',
    'brightness down'  => 'brightness down',
    on                 => 'on',
    off                => 'off',
    'full screen'      => 'full screen'
);
my $dvd_states;
$dvd_states = join( ',', keys %dvd_states );

#***Point voice commands to error messages if objects not created!
#***Set info, icons? Use info in help
$v_dvd_control = new Voice_Cmd( "DVD movie [$dvd_states]", 0 );
$v_dvd_movie =
  new Voice_Cmd( "Show DVD movie [$config_parms{dvd_favorites}]", 0 );
$v_dvd_attractions = new Voice_Cmd( "What is showing on DVD", 0 );
$v_dvd_help        = new Voice_Cmd( "DVD movie help",         0 );
$f_dvd             = new File_Item("$Pgm_Path/dvd.txt");
$p_dvd = new Process_Item("dir_to_file $config_parms{dvd_drive} dvd.txt");

#noloop=stop

sub refresh_marquee {
    start $p_dvd;
}

# *** trigger

&refresh_marquee() if $Reload;

if ( done_now $p_dvd) {

    my $dir = read_all $f_dvd;

    my ($title) = $dir =~ /volume in drive.*is (\S*)/i;

    $title =~ s/_/\x20/g;
    $title = ucfirst( lc($title) );

    set $dvd_marquee $title;
    unlink $f_dvd->{name};
}

if ( $state = said $v_dvd_help) {
    my @commands = join( ', ', sort keys %dvd_states );
    &respond("app=movie Commands are: @commands");
}
if ( $state = said $v_dvd_attractions) {
    &refresh_marquee();
    &respond( "app=movie mode=rotates $config_parms{dvd_favorites}"
          . ( ( $dvd_marquee->{state} ) ? " plus $dvd_marquee->{state}" : '' )
    );
}
if ( $state = said $v_dvd_control) {
    &refresh_marquee() if $state eq 'play';
    &respond( "app=dvd " . ucfirst($state) );
    &dvd_control($state);
}
if ( $state = said $v_dvd_movie) {
    &respond("app=movie $state Now Showing");
    &dvd_movie($state);
}

sub dvd_control {
    my ($command) = @_;
    set $dvd_player $dvd_states{$command};
}

sub dvd_movie {
    my ($movie) = @_;
    set $dvd_marquee $movie;
    set $dvd_player "play \"$movie\"";
}
