#!/usr/bin/perl
# -*- Perl -*-

#---------------------------------------------------------------------
#
# File: vv_tts.pl
#     
# Description: Perl wrapper script for Misterhouse and ViaVoiceTTS
# Author: Dave Lounsberry, dbl@dittos.yi.org
# Change log:
#
#-----------------------------------------------------------------------

use strict;

my ($Pgm_Path, $Pgm_Name, $Version, $Pgm_Root);
#use vars '$Pgm_Root';           # So we can see it in eval var subs in read_parms
use TTSClass;
package TTSClass;

BEGIN {
    ($Version) = q$Revision$ =~ /: (\S+)/; # Note: revision number is auto-updated by cvs
    ($Pgm_Path, $Pgm_Name) = $0 =~ /(.*)[\\\/](.+)\.?/;
    ($Pgm_Name) = $0 =~ /([^.]+)/, $Pgm_Path = '.' unless $Pgm_Name;
    $Pgm_Root = "$Pgm_Path/..";
    eval "use lib '$Pgm_Path/../lib', '$Pgm_Path/../lib/site'"; # Use BEGIN eval to keep perl2exe happy
}


use Getopt::Long;
my %parms;
if (!&GetOptions(\%parms, "h", "help", "text=s", "prescript=s", "postscript=s", "play=s", "playcmd=s", "default_sound=s") or
    @ARGV or $parms{h} or $parms{help} ) {
    print<<eof;

$Pgm_Name (version $Version) perl wrapper for TTS

  Usage:

    $Pgm_Name [options]

      -h                    => This help text
      -help                 => This help text
      -text "xxx"           => text to speak
      -playcmd xxx          => full path to play command
      -default_sound xxx    => default sound file 
      -play xxx             => sound file to play
      -prescript xxx	    => full path to script to run BEFORE playing and speaking
      -postscript xxx	    => full path to script to run AFTER playing and speaking

  Example:
    $Pgm_Name -text 'text to speak.'
    $Pgm_Name -playcmd /usr/bin/play -play magic.wav -text 'text to speak.'

eof

  exit;
}

my $lockfile = "/tmp/.vv_tts-lock";
my $cnt = 0;
while ( stat($lockfile) && $cnt < 60) {
	# printf("%s: lockfile exists, sleep ($cnt of 60)\n",$Pgm_Name,$cnt);
	sleep(1);
	if ($cnt++ == 60) {
		printf("%s: timed out waiting for lock, lets go anyway.\n",$Pgm_Name);
	}
}
		
open(LOCK, "> $lockfile");	 # don't die because we will speak anyway.
print LOCK "\n";
close(LOCK);

system($parms{prescript}) if $parms{prescript};
if ($parms{playcmd} and $parms{play} ne 'none') {
	if ($parms{play}) {
		system($parms{playcmd}. " " . $parms{play});
	} elsif ( $parms{default_sound}) {
		system($parms{playcmd}. " " . $parms{default_sound});
	}
}

TTSClass::eciSpeakText($parms{text},1);

system($parms{postscript}) if $parms{postscript};

unlink($lockfile);

exit;
