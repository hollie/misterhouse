#!/usr/bin/perl                                                                                 
#
#
#
# 
#    bsobel@vipmail.com'
#    August 15, 2000
#
#    Hacked by David Mark to bypass duplicate Winamp code and provide an object-based
#    interface for all MP3 players.  Code for the different players should be moved into
#    this object eventually (no need for four mutually exclusive common code modules.)

use strict;

package Mp3Player;
@Mp3Player::ISA = ('Generic_Item');

my @mp3player_object_list;

sub new 
{
    my ($class, $address) = @_;

    my $self = {address => $address};
    bless $self, $class;

    push(@mp3player_object_list,$self);

    push(@{$$self{states}}, 'play', 'pause', 'stop', 'next song', 'previous song', 'shuffle', 'repeat', 'random song', 'volume up', 'volume down', 'clear list');

    return $self;
}

sub default_setstate
{
    my ($self, $state) = @_;
    print "Mp3Player set called: " . $self->{address} . " to " . $state . "\n" if $::Debug{mp3};
    mp3_player_control($state,$self->{address});
    return;
}

sub mp3_player_control 
{
    my ($command, $host) = @_;

    eval "&::mp3_control('$command', '$host')";

    warn "mp3_control:$@\n" if $@;

    return;

    $host = 'localhost' unless $host;

                                # Start winamp, if it is not already running (windows localhost only)
    &::sendkeys_find_window('winamp ', $::config_parms{mp3_program}) if $::OS_win and $host eq 'localhost';

    my $temp;
    my $url = "http://$host:$::config_parms{mp3_program_port}";
    if($command eq 'randomsong')
    {
        my $mp3_num_tracks = ::get "$url/getlistlength?p=$::config_parms{mp3_program_password}";
        my $song = int(rand($mp3_num_tracks));
        my $mp3_song_name  = ::get "$url/getplaylisttitle?p=$::config_parms{mp3_program_password}&a=$song";
        $mp3_song_name =~ s/[\n\r]//g;
        ::print_log "Now Playing $mp3_song_name";
        ::get "$url/stop?p=$::config_parms{mp3_program_password}";
        ::get "$url/setplaylistpos?p=$::config_parms{mp3_program_password}&a=$song";
        ::print_log filter_cr get "$url/play?p=$::config_parms{mp3_program_password}";
    }
    elsif($command =~ /playlist:/i)
    {
        my ($file) = $command =~ /playlist:(.+)/i;

        ::print_log ::filter_cr ::get "$url/DELETE?p=$::config_parms{mp3_program_password}";
        ::print_log ::filter_cr ::get "$url/PLAYFILE?p=$::config_parms{mp3_program_password}&a=$file";
        ::print_log ::filter_cr ::get "$url/PLAY?p=$::config_parms{mp3_program_password}";
    }
    elsif($command =~ /volume/i)
    {
        $temp = '';
        # 10 passes is about 20 percent 
        for my $pass (1 .. 10) 
        {
            $temp .= ::filter_cr ::get "$url/$command?p=$::config_parms{mp3_program_password}";
        }
    }
    else 
    {
#        ::print_log "$url/$command?p=$::config_parms{mp3_program_password}";
        $temp = ::filter_cr ::get "$url/$command?p=$::config_parms{mp3_program_password}";
    }
}

1;


