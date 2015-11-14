#!/usr/bin/perl -w
use strict;
use File::Copy;
$| = 1;

my %data;
my $data_file = $ARGV[0];

sub UnformatTime ($) {
    my $time = $_[0];
    my $ret  = 0;
    if ( $time =~ s/(\d\d)$// ) {
        $ret += $1;
    }
    if ( $time =~ s/(\d\d):$// ) {
        $ret += ( $1 * 60 );
    }
    if ( $time =~ /(\d+):$/ ) {
        $ret += ( $1 * 3600 );
    }
    return $ret;
}

sub do_substitution($) {
    my ( $cmd, $macro, $value ) = @_;
    if ( $value =~ /'/ ) {
        $value =~ s/\\/\\\\/g;
        $value =~ s/"/\\"/g;
        $value =~ s/`/\\`/g;
        $value =~ s/\$/\\\$/g;
        $value = "\"$value\"";
    }
    else {
        $value = "'$value'";
    }
    $macro = "__${macro}__";
    $cmd =~ s/$macro/$value/g;
    return $cmd;
}

sub FormatTime ($) {
    my $time = $_[0];
    my ( $min, $hours ) = ( 0, 0 );
    if ( $min = int( $time / 60 ) ) {
        $time = ( $time - ( 60 * $min ) );
    }
    if ( $hours = int( $min / 60 ) ) {
        $min = ( $min - ( 60 * $hours ) );
    }
    $time =~ s/^(\d)$/0$1/;
    $min =~ s/^(\d)$/0$1/;
    if ($hours) {
        return ("$hours:$min:$time");
    }
    else {
        return ("$min:$time");
    }
}

sub compress_track {
    my ($track) = @_;
    my $input   = "$data{wav_dir}/$data{cddbid}/$track.wav";
    my $output  = "$data{dir}/" . $data{"track$track-file"};
    my $length  = $data{"track${track}length"};
    my $cmd     = $data{mp3_encoder};
    $cmd = &do_substitution( $cmd, 'song',    $data{"track${track}title"} );
    $cmd = &do_substitution( $cmd, 'artist',  $data{"track${track}artist"} );
    $cmd = &do_substitution( $cmd, 'album',   $data{'album'} );
    $cmd = &do_substitution( $cmd, 'year',    $data{'year'} );
    $cmd = &do_substitution( $cmd, 'comment', $data{"track${track}comment"} );
    $track =~ s/^0+//;
    $cmd = &do_substitution( $cmd, 'track',    $track );
    $cmd = &do_substitution( $cmd, 'genre',    $data{'genre'} );
    $cmd = &do_substitution( $cmd, 'genrestr', $data{'genrestr'} );
    $cmd = &do_substitution( $cmd, 'input',    $input );
    $cmd = &do_substitution( $cmd, 'output',   "$output.tmp" );
    print "Compressing track $track to $output (length: $length seconds)\n";
    print "Running command '$cmd'\n";
    my $starttime = time();

    unless ( system($cmd) == 0 ) {
        die "FATAL: The command '$cmd' failed: check the log file.\n";
    }
    unless ( -s "$output.tmp" ) {
        die
          "FATAL: The command '$cmd' produced a zero-length output file: $output.\n";
    }
    my $totaltime = &FormatTime( time() - $starttime );
    move( "$output.tmp", $output );
    system( 'chmod', 'a+r', $output );
    print
      "Done compressing track $track to $output (compress time: $totaltime)\n";
}

sub rip_track {
    my ($track) = @_;
    my $output  = "$data{wav_dir}/$data{cddbid}/$track.wav";
    my $cmd     = $data{cdripper};
    my $length  = $data{"track${track}length"};
    $track =~ s/^0+//;
    $cmd = &do_substitution( $cmd, 'output', "$output.tmp" );
    $cmd = &do_substitution( $cmd, 'track',  $track );
    print "Ripping track $track to $output (length: $length seconds)\n";
    print "Running command '$cmd'\n";
    my $starttime = time();

    unless ( system($cmd) == 0 ) {
        die "FATAL: The command '$cmd' failed: check the log file.\n";
    }
    unless ( -s "$output.tmp" ) {
        die
          "FATAL: The command '$cmd' produced a zero-length output file: $output.\n";
    }
    my $totaltime = &FormatTime( time() - $starttime );
    move( "$output.tmp", $output );
    print "Done ripping track $track to $output (rip time: $totaltime)\n";
}

sub compress_tracks {
    my @tracks;
    foreach (@_) {
        unless ( -f $data{dir} . '/' . $data{"track$_-file"} ) {
            push @tracks, $_;
        }
    }
    print "Compressing " . ( $#tracks + 1 ) . " tracks\n";
    foreach (@tracks) {
        &compress_track($_);
    }
}

sub rip_tracks {
    my @tracks;
    foreach (@_) {
        unless ( -f "$data{wav_dir}/$data{cddbid}/$_.wav" ) {
            push @tracks, $_;
        }
    }
    print "Ripping " . ( $#tracks + 1 ) . " tracks\n";
    foreach (@tracks) {
        &rip_track($_);
    }
}

# Read data file
my $total_seconds = 0;
open( DATA, $data_file )
  or die("FATAL: Could not open data file '$data_file' for reading: $!\n");
while ( my $line = <DATA> ) {
    chomp($line);
    my ( $name, $val ) = split( /=/, $line, 2 );
    if ( $name =~ /track\d+length/ ) {
        $val = &UnformatTime($val);
        $total_seconds += $val;
    }
    $data{$name} = $val;
}
close DATA;

print "Artist: $data{artist}\n";
print "Album: $data{album}\n";
print "Output Directory: $data{dir}\n";
print "Total Length: $total_seconds seconds\n";

my @tracks = split( /\s+/, $data{tracks} );
print "total tracks: " . ( $#tracks + 1 ) . "\n";

unless ( -d "$data{wav_dir}/$data{cddbid}" ) {
    system( 'mkdir', '-p', "$data{wav_dir}/$data{cddbid}" );
}

print "CD Drive In Use\n";
&rip_tracks(@tracks);
print "CD Drive Not In Use\n";

if ( $data{eject} ) {
    system( $data{eject} );
}

unless ( -d $data{dir} ) {
    system( 'mkdir', '-p', $data{dir} );
    my $dir = $data{dir};
    system( 'chmod', 'a+rx', $dir );
    while ( $dir =~ s/^(.+)\/[^\/]+$/$1/ ) {
        system( 'chmod', 'a+rx', $dir );
    }
}

&compress_tracks(@tracks);

system( 'rm', '-rf', "$data{wav_dir}/$data{cddbid}" );

if ( $data{disc_data_file} ) {

    # Write disc data file
    if ( open( DATA, ">$data{dir}/$data{disc_data_file}" ) ) {
        print DATA "cddbid=$data{cddbid}\n";
        print DATA "artist=$data{artist}\n";
        print DATA "album=$data{album}\n";
        print DATA "year=$data{year}\n";
        foreach ( keys %data ) {
            if (/\d+(title|artist|comment)$/) {
                print DATA "$_=$data{$_}\n";
            }
        }
        close DATA;
    }
    else {
        print
          "WARNING: Could not save disc data in file '$data{disc_data_file}': $!\n";
    }
}

# Be sure to sleep for a sec before exit so that our log entry
# is received by Misterhouse before we exit
print "Rip Completed\n";
sleep 5;
exit 0;
