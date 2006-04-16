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


if ($Reload) {
    add_sound movement1    => 'sound_nature/02.wav',       volume => 10;
    add_sound movement2    => 'sound_nature/02.wav',       volume => 100;
    add_sound unauthorized => 'sound_nature/31.wav',       volume => 20;
    add_sound 3            => 'sound_nature/65.wav',       volume => 20;
    add_sound 4            => 'sound_nature/avairy.wav',   volume => 20;
    add_sound barcode_scan => 'sound_nature/bird.wav',     volume => 20;
    add_sound mh_problem   => 'sound_nature/bird1.wav',    volume => 20;
#   add_sound mh_pause     => 'sound_nature/bird1.wav',    volume => 20;
    add_sound mh_pause     => 'none',                      volume => 20;
    add_sound 7            => 'sound_nature/bird2.wav',    volume => 20;
    add_sound wap          => 'sound_nature/bird3.wav',    volume => 20;
    add_sound tell_me      => 'sound_nature/birds.wav',    volume => 20;
    add_sound 10           => 'sound_nature/chirp.wav',    volume => 20;
    add_sound router_hit   => 'sound_nature/frog.wav',     volume =>  2;
    add_sound 12           => 'sound_nature/frog3.wav',    volume => 20;
    add_sound 13           => 'sound_nature/h4560sh.wav',  volume => 20;
    add_sound 14           => 'sound_nature/kirtland.wav', volume => 20;
    add_sound router_new   => 'sound_nature/loon.wav',     volume => 20;
    add_sound 16           => 'sound_nature/octap95.wav',  volume => 20;
    add_sound 17           => 'sound_nature/parakeet.wav', volume => 20;
    add_sound 18           => 'sound_nature/ribbit.wav',   volume => 10;
    add_sound 19           => 'sound_nature/wren.wav',     volume => 20;
    add_sound timer        => 'sound_nature/gonge.wav',    volume => 100, rooms => 'all', time => 3 ;
    add_sound timer2       => 'sound_nature/gonge.wav',    volume => 40,  rooms => 'all_and_out', time => 3 ;
}

# Allow for an optional file

if ($config_parms{event_sounds_file} and 
    ($New_Minute and file_changed($config_parms{event_sounds_file}) or $Reload)) {
    print "Reading event sounds data ($Date_Now $Time_Now): $config_parms{event_sounds_file}.\n";
#    @Sounds = ();
    open(SOUNDSDATA, $config_parms{event_sounds_file});
    while(<SOUNDSDATA>) {
        unless (/^#/ or /^\s+$/ or !$_) {	    
            print " - $_";
            chomp $_;
	    eval "add_sound " . $_;
        }
    }
    close(SOUNDSDATA);
}

$sound_list_v     = new Voice_Cmd '[List,List all,Stop listing] event sounds';
$sound_list_timer = new Timer;

my @sound_files;
$state = said $sound_list_v;
if ($state =~ /List/) {
    @sound_files = sort keys %Sounds;
    @sound_files = grep !/^\d+$/, @sound_files unless $state eq 'List all';
    set $sound_list_timer 1;
    print_log "Starting event sound list for: @sound_files";
}
if (expired $sound_list_timer) {
    my $key = pop @sound_files;
    print_log "Playing $key => $Sounds{$key}{file}";
    speak $key;
    select undef, undef, undef, 1;
    play $key;
    set $sound_list_timer 1 if @sound_files;
}
set $sound_list_timer 0 if $state eq 'Stop listing';

