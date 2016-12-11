
if ($Reload) {

    #   add_sound router_new   => 'sound_trek2.wav',     volume => 20;
    add_sound router_new => 'none';
    add_sound
      mh_pause => 'none',
      volume   => 20;       # Need a less irritating default sound here

    #   add_sound timer        => 'sound_nature/gonge.wav',    volume => 100, rooms => 'all', time => 3 ;
    #   add_sound timer2       => 'sound_nature/gonge.wav',    volume => 40,  rooms => 'all_and_out', time => 3 ;
    add_sound timer  => 'sound_nature/gonge.wav', volume => 10, time => 3;
    add_sound timer2 => 'sound_nature/gonge.wav', volume => 10, time => 3;
}
