# Category=other
##  Command script to send remote control commands to VDR
##  The key mappings are for a UR81A remote control but it can be
##  easily modified by changing the mapping below.
##  This script assumes you have VDR installed and SVDRP installed on port 2001.
##  The VDR machine does not have to be the same as the X10 machine -- just change
##  the $vdr_backend to the correct server.

##  By using the VDR plugins for MP3's and DVD's this can be a complete A/V solution.

##  VDR -- http://www.cadsoft.de/vdr/

## By Norm Dressler norm@dressler.ca

my %vdr_commands = (
    'up'      => "Up",
    'down'    => "Down",
    'menu'    => "Menu",
    'enter'   => "Ok",
    'exit'    => "Back",
    'left'    => "Left",
    'right'   => "Right",
    'display' => "Red",
    'return'  => "Green",
    'title'   => "Yellow",
    'pc'      => "Blue",
    0         => "0",
    1         => "1",
    2         => "2",
    3         => "3",
    4         => "4",
    5         => "5",
    6         => "6",
    7         => "7",
    8         => "8",
    9         => "9",
    'play'    => "Play",
    'pause'   => "Pause",
    'stop'    => "Stop",
    'record'  => "Record",
    'FF'      => "FastFwd",
    'rew'     => "FastRew",
    'ch+'     => "Channel+",
    'ch-'     => "Channel-",
    'power'   => "Power",
    'vol+'    => "Volume+",
    'vol-'    => "Volume-",
    'ab'      => "Mute",
);

my $vdr_backend = 'localhost:2001';

$vdr =
  new Socket_Item( undef, undef, $vdr_backend, 'vdr', 'tcp', 'rawout', "\r\n" );

$Remote = new X10_MR26;

if ( exists $vdr_commands{$state} ) {
    print_log "VDR key $state pressed!";
    my $cmd = "hitk " . $vdr_commands{$state};
    if ( !active $vdr) { start $vdr }
    if ( active $vdr) {
        set $vdr $cmd;
        print_log "VDR Command $cmd Sent!";
    }
}

