# Category = Entertainment

#@ This module plays Cuckoo style chimes on each
#@ quarter hour. You must download BigBenSounds.zip from:
#@  http://www.bamafolks.com/~randy/freeware/chimes/
#@  or http://alan.firebin.net/cuckoos.tar
#@ then unzip the contents into a new "chimes" directory
#@ under your existing "sounds" directory.

# 2001-09-28 David Norwood dnorwood2@yahoo.com

my $suff;

if ($New_Hour) {
	$suff = $Hour;
	$suff -= 12 if $Hour > 12;
	$suff = "0" . $suff if $suff < 10;
	play (time => 30, volume => 100, file => "chimes/cuckoo" . $suff . ".wav");
}
