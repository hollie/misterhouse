#!/usr/bin/perl                                                                                 
#
#
# This uses only:
#  - httpq  (a winamp plugin, available at: http://karv.dyn.dhs.org/winamp or http://gulf.uvic.ca/~karvanit/winamp/)
#
# This just turns the player on,off,pause, etc.  Mp3Control.pm controls 
# starting the mp3 player with a list of songs or a playlist
#
# 
#    bsobel@vipmail.com'
#    August 15, 2000
#
#

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

    # See http://gulf.uvic.ca/~karvanit/winamp/commands.html
    push(@{$$self{states}}, 'play', 'pause', 'stop', 'next', 'prev', 'shuffle', 'repeat', 'randomsong', 'volumeup', 'volumedown');

    return $self;
}

sub set
{
    my ($self, $state) = @_;

    print "Mp3Control set called: " . $self->{address} . " to " . $state . "\n";
    winamp_control($state,$self->{address});
    return &Generic_Item::set($self, $state);
}

sub winamp_control 
{
    my ($command, $host) = @_;

    $host = 'localhost' unless $host;
    ::print_log "Setting $host winamp to $command";

                                # Start winamp, if it is not already running (windows localhost only)
    &::sendkeys_find_window('winamp', $::config_parms{mp3_program}) if $::OS_win and $host eq 'localhost';

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

        ::print_log "Winamp playlist file=$file";
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
        ::print_log "Winamp (httpq) set to $command: $temp";
    }
    else 
    {
        ::print_log "$url/$command?p=$::config_parms{mp3_program_password}";
        $temp = ::filter_cr ::get "$url/$command?p=$::config_parms{mp3_program_password}";
        ::print_log "Winamp set to $command: $temp";
    }
}

1;


