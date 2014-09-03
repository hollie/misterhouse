# Category=MisterHouse

#@ Adds sounds which are associated with specific events. For
#@ example, a gong is played when a timer does off.

# Correlate event sounds to sound files
# Great site for finding sounds:
#   http://www.findsounds.com
#   http://dgl.microsoft.com/
#
# These sounds are used via play.  For example:
#    play 'movement1' if state_now $movement_sensor;
#

# Read in sound configuration via event_sounds_file
if (
    $config_parms{event_sounds_file}
    and (  $New_Minute and file_changed( $config_parms{event_sounds_file} )
        or $Reload )
  )
{
    &print_log(
        "Reading event sounds data from $config_parms{event_sounds_file}");

    open( SOUNDSDATA, $config_parms{event_sounds_file} );
    while (<SOUNDSDATA>) {
        unless ( /^#/ or /^\s+$/ or !$_ ) {
            print " - $_";
            chomp $_;
            eval "add_sound " . $_;
        }
    }
    &print_log("Finished reading event sounds data");
    close(SOUNDSDATA);
}

$sound_list_v     = new Voice_Cmd '[List,List all,Stop listing] event sounds';
$sound_list_timer = new Timer;

my @sound_files;
$state = said $sound_list_v;
if ( $state =~ /List/ ) {
    @sound_files = sort keys %Sounds;
    @sound_files = grep !/^\d+$/, @sound_files unless $state eq 'List all';
    set $sound_list_timer 1;
    print_log "Starting event sound list for: @sound_files";
}
if ( expired $sound_list_timer) {
    my $key = pop @sound_files;
    print_log "Playing $key => $Sounds{$key}{file}";
    speak $key;
    select undef, undef, undef, 1;
    play $key;
    set $sound_list_timer 1 if @sound_files;
}
set $sound_list_timer 0 if $state eq 'Stop listing';

