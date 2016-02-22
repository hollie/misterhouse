#!/usr/bin/perl
# -*- Perl -*-

#---------------------------------------------------------------------
#
# File: vv_tts.pl
#
# Description: Perl wrapper script for Misterhouse and ViaVoiceTTS
# Author: Dave Lounsberry, dave.lounsberry@gmail.com
# Change log:
#
# $Date$
# $Revision$
#-----------------------------------------------------------------------

use strict;

my ( $Pgm_Path, $Pgm_Name, $Version, $Pgm_Root );

#use vars '$Pgm_Root';           # So we can see it in eval var subs in read_parms

BEGIN {
    ($Version) =
      q$Revision$ =~ /: (\S+)/;   # Note: revision number is auto-updated by cvs
    ( $Pgm_Path, $Pgm_Name ) = $0 =~ /(.*)[\\\/](.+)\.?/;
    ($Pgm_Name) = $0 =~ /([^.]+)/, $Pgm_Path = '.' unless $Pgm_Name;
    $Pgm_Root = "$Pgm_Path/..";
    eval "use lib '$Pgm_Path/../lib', '$Pgm_Path/../lib/site'"
      ;                           # Use BEGIN eval to keep perl2exe happy
}

use Getopt::Long;
my %parms;
my $cmd;
if (
    !&GetOptions(
        \%parms,           "h",
        "help",            "debug",
        "nomixer",         "text=s",
        "voice=s",         "text_first",
        "volume=s",        "play_volume=s",
        "voice_volume=s",  "default_volume=s",
        "prescript=s",     "postscript=s",
        "play=s",          "playcmd=s",
        "default_sound=s", 'to_file=s',
        "pa_control",      "xcmd_file=s",
        "rooms=s",         "default_room=s",
        "engine=s"
    )
    or @ARGV
    or $parms{h}
    or $parms{help}
  )
{
    print <<eof;

$Pgm_Name (version $Version) perl wrapper for TTS

  Usage:

    $Pgm_Name [options]

      -h                    => This help text
      -help                 => This help text
      -debug                => Turn on some debugging messages
      -text "xxx"           => text to speak
      -engine xxx           => backend TTS engine (viavoice | festival | theta | swift)
      -playcmd xxx          => full path to play command
      -default_sound xxx    => default sound file 
      -default_volume xxx   => default volume when -volume not set
      -play xxx             => sound file to play
      -text_first           => speak text before playing sound, default is sound then text
      -volume xxx           => volume setting for both play and voice unless specified
      -play_volume xxx      => play volume setting
      -voice_volume xxx     => voice volume setting
      -voice xxx            => voice #
      -prescript xxx	    => full path to script to run BEFORE playing and speaking
      -postscript xxx	    => full path to script to run AFTER playing and speaking
      -nomixer              => do not use built in mixer support
      -to_file xxx          => output sound to xxx file
      -pa_control           => turn on pa control
      -xcmd_file xxx        => full path to misterhouse command file
      -rooms                => speak to rooms (needs voice_cmd)
      -default_room         => default room to speak


  Example:
    $Pgm_Name -text 'text to speak.'
    $Pgm_Name -playcmd /usr/bin/play -play magic.wav -text 'text to speak.'

eof

    exit;
}

my $lockfile = "/tmp/.vv_tts-lock";
my $cnt      = 0;
unless ( $parms{engine} ) {
    $parms{engine} = 'festival';
}
if ( $parms{engine} eq 'viavoice' ) {
    eval "use ViaVoiceTTS";
    if ($@) {
        printf( "\n%s: ViaVoiceTTS not installed, exiting.\n\n", $Pgm_Name );
        exit;
    }
    else {

        package ViaVoiceTTS;
    }
}
while ( stat($lockfile) && $cnt < 120 ) {

    # printf("%s: lockfile exists, sleep ($cnt of 60)\n",$Pgm_Name,$cnt);
    sleep(1);
    if ( $cnt++ == 120 ) {
        printf( "%s: timed out waiting for lock, lets go anyway.\n",
            $Pgm_Name );
    }
}

open( LOCK, "> $lockfile" );    # don't die because we will speak anyway.
print LOCK "\n";
close(LOCK);

my $old_vol    = 0;
my $old_pcm    = 0;
my $have_mixer = 0;

unless ( $parms{nomixer} ) {
    eval "use Audio::Mixer";
    if ($@) {
        printf(
            "\n%s: Audio::Mixer not installed ... volume control is disabled\n\n",
            $Pgm_Name );
    }
    else {
        $have_mixer = 1;
    }
}

if ( $parms{pa_control} and $parms{xcmd_file} ) {
    if ( $parms{rooms} ) {
        write_xcmd_file( $parms{xcmd_file}, $parms{rooms} );
    }
    elsif ( $parms{default_room} ) {
        write_xcmd_file( $parms{xcmd_file}, $parms{default_room} );
    }
    while ( -f $parms{xcmd_file} ) {

        #printf ("%s: waiting for xcmd_file to disappear\n",$Pgm_Name);
        sleep(1);
    }
}

if ( $parms{prescript} ) {
    $cmd = $parms{prescript};
    printf( "%s: running prescript, %s\n", $Pgm_Name, $cmd ) if $parms{debug};
    system($cmd);
}

&save_vol if $have_mixer;

if ( $parms{text_first} ) {
    &speak_text;
    &play_sound;
}
else {
    &play_sound;
    &speak_text;
}

&restore_vol if $have_mixer;

if ( $parms{postscript} ) {
    $cmd = $parms{postscript};
    printf( "%s: running postscript, %s\n", $Pgm_Name, $cmd ) if $parms{debug};
    system($cmd);
}

if ( $parms{pa_control} and $parms{xcmd_file} ) {
    write_xcmd_file( $parms{xcmd_file}, "off" );
    while ( -f $parms{xcmd_file} ) {

        #printf ("%s: waiting for xcmd_file to disappear\n",$Pgm_Name);
        sleep(1);
    }
}

unlink($lockfile);

exit;

sub play_sound() {
    if ( $parms{playcmd} and $parms{play} ne 'none' ) {
        if ($have_mixer) {
            if ( $parms{play_volume} ) {
                printf(
                    "%s: using play_volume($parms{play_volume}) for play sound\n",
                    $Pgm_Name )
                  if $parms{debug};
                &set_vol( $parms{play_volume} );
            }
            elsif ( $parms{volume} ) {
                printf( "%s: using volume ($parms{volume}) for play sound\n",
                    $Pgm_Name )
                  if $parms{debug};
                &set_vol( $parms{volume} );
            }
            elsif ( $parms{default_volume} ) {
                printf(
                    "%s: using default_volume ($parms{default_volume}) for play sound\n",
                    $Pgm_Name )
                  if $parms{debug};
                &set_vol( $parms{default_volume} );
            }
        }
        if ( $parms{play} ) {
            $cmd = $parms{playcmd} . " " . $parms{play};
        }
        elsif ( $parms{default_sound} ) {
            $cmd = $parms{playcmd} . " " . $parms{default_sound};
        }
        printf( "%s: running play cmd: %s\n", $Pgm_Name, $cmd )
          if $parms{debug};
        system($cmd);
    }
    return;
}

sub speak_text {
    if ( $parms{text} ) {
        if ($have_mixer) {
            if ( $parms{voice_volume} ) {
                printf(
                    "%s: using voice_volume($parms{voice_volume}) for voice\n",
                    $Pgm_Name )
                  if $parms{debug};
                &set_vol( $parms{voice_volume} );
            }
            elsif ( $parms{volume} ) {
                printf( "%s: using volume ($parms{volume}) for voice\n",
                    $Pgm_Name )
                  if $parms{debug};
                &set_vol( $parms{volume} );
            }
            elsif ( $parms{default_volume} ) {
                printf(
                    "%s: using default_volume ($parms{default_volume}) for voice\n",
                    $Pgm_Name )
                  if $parms{debug};
                &set_vol( $parms{default_volume} );
            }
        }
        printf( "%s: text = $parms{text}\n", $Pgm_Name ) if $parms{debug};
        printf( "%s: to_file = $parms{to_file}\n", $Pgm_Name )
          if $parms{to_file} && $parms{debug};

        if ( $parms{engine} =~ /viavoice/i ) {
            if ( $parms{to_file} ) {
                unlink $parms{to_file};
                my $h = eciNew() or die "ViaVoice: Unable to connect";
                eciSetOutputFilename( $h, $parms{to_file} )
                  or warn
                  "ViaVoice: Unable to set output file: $parms{to_file}";
                eciAddText( $h, $parms{text} )
                  or warn "ViaVoice Unable to add text";
                eciSynthesize($h) or warn "ViaVoice Unable to synthesize text";
                while ( eciSpeaking($h) ) { }
                eciDelete($h);
            }
            else {
                printf( "%s: running viavoice tts engine\n", $Pgm_Name )
                  if $parms{debug};
                $parms{text} = "`v" . $parms{voice} . " " . $parms{text}
                  if $parms{voice};    # Does not work with to_file??
                ViaVoiceTTS::eciSpeakText( $parms{text}, 1 );
            }
        }
        elsif ( $parms{engine} =~ /festival/i ) {
            if ( $parms{to_file} ) {
                unlink $parms{to_file};
                printf( "%s: running festival tts engine\n", $Pgm_Name )
                  if $parms{debug};
                open( FEST,
                    "| festival_client --ttw --output $parms{to_file}" );
                print FEST qq[$parms{text}];
                close(FEST);
            }
            else {
                printf( "%s: running festival tts engine\n", $Pgm_Name )
                  if $parms{debug};
                open( FEST, "| festival --tts" );
                print FEST qq[$parms{text}];
                close(FEST);
            }
        }
        elsif ( $parms{engine} =~ /theta|swift/i ) {
            if ( $parms{to_file} ) {
                unlink $parms{to_file};

                # I'm not sure what needs to go here
            }
            else {
                printf( "%s: running $parms{engine} tts engine\n", $Pgm_Name )
                  if $parms{debug};
                system("$parms{engine} \'$parms{text}\'");

            }
        }
    }
    return;
}

sub set_vol {
    my ($level) = @_;

    printf( "%s: setting volume to $level\n", $Pgm_Name ) if $parms{debug};
    for ( my $i = 0; $i <= 5; $i++ ) {
        Audio::Mixer::set_cval( 'vol', $level );
        Audio::Mixer::set_cval( 'pcm', $level );
        my ($svol) = &check_vol;

        #return if ($svol == $level);
        return if ( $svol <= $level + 1 ) && ( $svol >= $level - 1 );
        printf( "%s: current vol($svol) != level($level)\n", $Pgm_Name )
          if $parms{debug};
        sleep(1);
    }
    return;
}

sub check_vol {
    my @vol     = Audio::Mixer::get_cval('vol');
    my @pcm     = Audio::Mixer::get_cval('pcm');
    my $cur_vol = ( $vol[0] + $vol[1] ) / 2;
    my $cur_pcm = ( $pcm[0] + $pcm[1] ) / 2;
    printf( "%s: checking vol,pcm settings ($cur_vol, $cur_pcm)\n", $Pgm_Name )
      if $parms{debug};
    return ( ( $cur_vol + $cur_pcm ) / 2 );
}

sub save_vol {
    my @vol = Audio::Mixer::get_cval('vol');
    my @pcm = Audio::Mixer::get_cval('pcm');
    $old_vol = ( $vol[0] + $vol[1] ) / 2;
    $old_pcm = ( $pcm[0] + $pcm[1] ) / 2;
    printf( "%s: saving current vol,pcm settings ($old_vol,$old_pcm)\n",
        $Pgm_Name )
      if $parms{debug};
    return;
}

sub restore_vol {
    printf( "%s: restoring old vol,pcm settings ($old_vol, $old_pcm)\n",
        $Pgm_Name )
      if $parms{debug};
    Audio::Mixer::set_cval( 'vol', $old_vol );
    Audio::Mixer::set_cval( 'pcm', $old_pcm );
    return;
}

sub write_xcmd_file {
    my ( $xcmd_file, $rooms ) = @_;
    printf( "%s: opening xcmd_file:$xcmd_file\n", $Pgm_Name ) if $parms{debug};
    printf( "%s: writing to xcmd_file, rooms:$rooms\n", $Pgm_Name )
      if $parms{debug};
    open( CMDFILE, "> $xcmd_file" );   # don't die because we will speak anyway.
    print CMDFILE "set pa speaker to $rooms\n";
    close(CMDFILE);
    return;
}
