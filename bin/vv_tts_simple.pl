#!/usr/bin/perl
# -*- Perl -*-

#---------------------------------------------------------------------
#
# File: viavoiceTTS.pl
#
# Description: Perl wrapper script for Misterhouse and ViaVoiceTTS
#
#-----------------------------------------------------------------------

use strict;

use ViaVoiceTTS;
use Audio::Mixer;

package ViaVoiceTTS;

use Getopt::Long;
my %parms;
&GetOptions( \%parms, 'to_file=s', 'voice=s', 'volume=s', 'right=s', 'left=s' );

my $text = shift @ARGV;

print
  "VOICE! t=$text v=$parms{voice} f=$parms{to_file} r=$parms{right} l=$parms{left}\n";

if ( $parms{to_file} ) {
    print "Saving text to $parms{to_file}\n";
    my $h = eciNew() or die "ViaVoice: Unable to connect";
    unlink $parms{to_file};
    eciSetOutputFilename( $h, $parms{to_file} )
      or warn "ViaVoice: Unable to set output file: $parms{to_file}";
    eciAddText( $h, $text ) or warn "ViaVoice Unable to add text";
    eciSynthesize($h) or warn "ViaVoice Unable to synthesize text";
    while ( eciSpeaking($h) ) { };    # Wait till done
}
else {
    my $tts = new ViaVoiceTTS();
    &ViaVoiceTTS::setVoice( $tts, $parms{voice} );
    if ( defined $parms{right} ) {
        &ViaVoiceTTS::speak( $tts, $text, $parms{left}, $parms{right} );
    }
    else {
        &ViaVoiceTTS::speak( $tts, $text );
    }
}
