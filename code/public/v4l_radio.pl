
# Category = Radio

=begin comment
			
v4l_radio.pl 

06/30/2002 Created by David Norwood (dnorwood2@yahoo.com)

This script adds streaming radio functionality to Misterhouse systems running Linux.  

Requirements:

- misterhouse: http://www.misterhouse.net
- An FM tuner card supported by video4linux 
- A kernel that supports v4l1 or v4l2 and a driver for your card (probably bttv)
    RedHat 7.2 was sufficient for me, but you can get the latest here: http://bytesex.org/bttv/
- radio: http://bytesex.org/xawtv/
- ffmpeg and ffserver: http://ffmpeg.sourceforge.net/

Setup:

Install and configure all the above software.  Copy this script into your misterhouse 
code directory.   

Set the following parameter in your private mh.ini file.  

v4l_radio_stations=KCLU 88.30 KUSC 91.55 Arrow 93.10 KLOS 95.50

Restart misterhouse, browse to http://localhost:8080/mh4, and click on Radio.  

=cut

my %stations =
  qw(KCLU 88.30 KUSC 91.55 Arrow 93.10 KLOS 95.50 KOCP 95.85 KLSX 97.10
  K-Earth 101.10 KROQ 102.30 KMZT 105.10 Power106 105.90);
my $state;

$v4l_radio = new Voice_Cmd 'Streaming radio [Stop]';
$v4l_radio_vol =
  new Voice_Cmd 'Local output [Mute gain,Unmute gain,Volume up,Volume down]';
$v4l_radio_stations =
  new Voice_Cmd 'Play [' . join( ',', ( keys %stations ) ) . ']';
$v4l_radio_streamer_process = new Process_Item;
$v4l_radio_encoder_process  = new Process_Item;
$v4l_radio_tuner_process    = new Process_Item;

if ($Reload) {
    %stations = split ' ', $config_parms{v4l_radio_stations}
      if defined $config_parms{v4l_radio_stations};
    set $v4l_radio_streamer_process 'killall ffserver', 'ffserver';
    set $v4l_radio_encoder_process 'killall ffmpeg',    'sleep 2',
      'ffmpeg -vn  http://localhost:8090/feed1.ffm';
    $Included_HTML{Radio} =
      '<a href="/data/shoutcast-playlist.pls">Start listening</a>';
    my $ip = `/sbin/ifconfig eth0`;
    my ($address) = $ip =~ /.*inet addr:([0-9\.]*)\s.*/;
    open PLS, "> $config_parms{data_dir}/shoutcast-playlist.pls";
    print PLS "
[playlist]
numberofentries=1
File1=http://$address:8090/test.mp2
Title1= Misterhouse Streaming Radio
Length1=-1
Version=2
";
    close PLS;
}

if ( my $station = said $v4l_radio_stations) {
    print_log "Streaming radio station $station $stations{$station}\n";
    start $v4l_radio_streamer_process if done $v4l_radio_streamer_process;
    start $v4l_radio_encoder_process  if done $v4l_radio_encoder_process;
    set $v4l_radio_tuner_process "radio -qf $stations{$station}";
    start $v4l_radio_tuner_process;
}

if ( $state = said $v4l_radio) {
    if ( $state eq 'Stop' or $state eq 'Disable' ) {
        print_log "Stopping streaming radio\n";
        stop $v4l_radio_encoder_process unless done $v4l_radio_encoder_process;
        stop $v4l_radio_streamer_process
          unless done $v4l_radio_streamer_process;
        set $v4l_radio_tuner_process "radio -qm";
        start $v4l_radio_tuner_process;
    }
}

if ( $state = said $v4l_radio_vol) {
    if ( $state eq 'Mute gain' ) {
        print_log "Muting local output\n";
        Audio::Mixer::set_cval( 'line', 0 );
    }
    elsif ( said $v4l_radio_vol eq 'Unmute gain' ) {
        print_log "Unmuting local output\n";
        Audio::Mixer::set_cval( 'line', 40 );
    }
    elsif ( $state eq 'Volume down' ) {
        change_vol( 'vol', '-10' );
    }
    elsif ( $state eq 'Volume up' ) {
        change_vol( 'vol', '10' );
    }
}

sub change_vol {
    my ( $ctrl, $change ) = @_;
    my @vol             = Audio::Mixer::get_cval($ctrl);
    my $volume_previous = ( $vol[0] + $vol[1] ) / 2;
    Audio::Mixer::set_cval( $ctrl, $volume_previous + $change );
}

