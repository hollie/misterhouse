# Category = Entertainment

#@ This module plays Westminster style chimes on each
#@ quarter hour. You must download BigBenSounds.zip from:
#@ http://www.bamafolks.com/~randy/freeware/chimes/
#@ then unzip the contents into a new "chimes" directory
#@ under your existing "sounds" directory.

# 2001-09-28 David Norwood dnorwood2@yahoo.com

my $suff;

if ( time_cron "0,15,30,45 * * * *" ) {
    if ( $Minute == 0 ) {
        $suff = $Hour;
        $suff -= 12 if $Hour > 12;
        $suff = 12 if $Hour == 0;
    }
    else {
        $suff = $Minute;
    }
    play( time => 60, volume => 20, file => "chimes/west" . $suff . ".wav" );
}
