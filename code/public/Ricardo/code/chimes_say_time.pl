# Category=Time

#@ Speaks time each hour

# written by Ricardo Arroyo (ricardo.arroyo@ya.com)
#

if ( $New_Hour and ( state $mode_mh eq 'normal' ) ) {
    speak "Son las $Time_Now del $Date_Now_Speakable.";
    speak "La temperatura exterior es de $Weather{TempOutdoor} grados";
}
