# Category = Entertainment

#@ This module plays Cuckoo style chimes on each hour. You must download
#@ <a href=http://misterhouse.sf.net/misterhouse_misc.zip>the misc. Misterhouse files zip archive</a>
#@ then unzip the wav files into a new "chimes" directory under your private "sounds" directory.
#@ Set the chime_volume parameter to set the volume for chimes.
#@ Set the chime_rooms parameter to specify in which rooms to play the chimes.

# 2001-09-28 David Norwood dnorwood2@yahoo.com
# 2006-05-26 Troy Carpenter fixed problem playing chime at midnight, made volume and rooms configurable

my $suff;

if ($New_Hour) {
    $suff = $Hour;
    $suff -= 12 if $Hour > 12;
    $suff = 12          if $Hour == 0;
    $suff = "0" . $suff if $suff < 10;

    # Build the hash
    my %parms = ( 'time' => '30', 'file' => "chimes/cuckoo$suff.wav" );
    $parms{volume} = $config_parms{chime_volume}
      if defined $config_parms{chime_volume};
    $parms{rooms} = $config_parms{chime_rooms}
      if defined $config_parms{chime_rooms};

    play(%parms);
}
