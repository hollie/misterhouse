
=begin comment

From Dave Lounsberry on 10/2002

It's a hack using xcmd_file but back when I did it, I could not figure out a
better way considering vv_tts.pl is running externally and has no way of
controlling misterhouse. The catch is since vv_tts.pl does it's own
sound and voice threading the pa_control setting must go along with it
otherwise the desired results are usually not be achieved when more than
one event fires at the same time. 

It requires two additonal mh.ini settings:
	vv_tts_pa_control=1   (have vv_tts.pl run voice_cmd 'set pa control to $room'
	vv_tts_default_room = xxxx (default room for vv_tts when controlling pa and room not specified). 

My rooms are really different combinations of rooms. I find this way is
is easier to maintain (and code against) than the bit/byte stuff. For
example my items.mht entries are as follows:

SERIAL,   BR,    weeder_b,      Relays,           status
SERIAL,   BW00000, pa_speaker,  Relays|PA_System, off
SERIAL,   BW10000, pa_speaker,  Relays|PA_System, office
SERIAL,   BW01000, pa_speaker,  Relays|PA_System, dining
SERIAL,   BW00100, pa_speaker,  Relays|PA_System, garage
SERIAL,   BW00010, pa_speaker,  Relays|PA_System, master
SERIAL,   BW00001, pa_speaker,  Relays|PA_System, outside
SERIAL,   BW11110, pa_speaker,  Relays|PA_System, all
SERIAL,   BW11111, pa_speaker,  Relays|PA_System, all_in_and_out
SERIAL,   BW11100, pa_speaker,  Relays|PA_System, all_parents_asleep

=cut

my $speakers =
  "default,garage,dining,office,master,all,outside,all_in_and_out,all_parents_asleep,off";
$v_pa_control = new Voice_Cmd("Set pa speaker to [$speakers]");
if ( $state = said $v_pa_control) {
    my $room = $state;
    if ( $state eq 'default' ) {
        $room = "all"
          ; # add more code here to determine default according to outside occupation.
    }
    set $pa_speaker $room;
    print_log "setting pa_speaker to $room";
}

