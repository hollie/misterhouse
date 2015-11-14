# Category = MisterHouse

#@ This module sends all spoken text and the names of played
#@ sound files to a remote machine. This other machine needs
#@ to be running voice_client.pl, have TTS software installed,
#@ and have the wav files locally. Supports up to three connections.
#@
#@ Add the following lines to your mh.private.ini file:
#@
#@ server_voice_1_port = 23 # Or whatever port you wish
#@ server_voice_1_password = yourpassword1

=begin comment

voice_server.pl
 1.1 Added ping and auto-reload - TD - 11/14/2001
 1.0 Original version by Tim Doyle <tim@greenscourt.com>
     using telnet.pl as an example - 10/31/2001

This script hooks into MisterHouse's speak and play routines to send all
spoken text as well as the names of sound files played out over a socket 
to a remote machine. Simply place this script into your code directory, 
reload MH, and follow the instructions in voice_client.pl. You can 
duplicate the code as many times as you need - one connection per code set.

Add the following lines to your mh.private.ini file:

server_voice_1_port      = 23        # Or whatever port you wish
server_voice_2_port      = 231       # Or whatever port you wish
server_voice_3_port      = 232       # Or whatever port you wish

optional:

server_voice_1_password  = yourpassword1
server_voice_2_password  = yourpassword2
server_voice_3_password  = yourpassword3

I've picked port 23 (telnet) as one of my ports so I can get through the 
firewall at work.

=cut

my $authorized_1 = 0;
my ( $password_1, $user_1, $data_1 );

#$voice_server_1 = new Socket_Item("Connected to MisterHouse Voice Server 1\r\n", 'Welcome', 'server_voice_1');
$voice_server_1 = new Socket_Item( "\r\n", 'Welcome', 'server_voice_1' );
$timer_disconnect_1 = new Timer;

if ( ($Reload) && ( active $voice_server_1) ) {
    set $voice_server_1 'RELOAD';
    stop $voice_server_1;
}

if ( ($New_Minute) && ( active $voice_server_1) ) {
    set $voice_server_1 'PING';
}

if ( active_now $voice_server_1) {
    print_log "Voice server 1 connected";
    set $voice_server_1 'Welcome';
    set $timer_disconnect_1 5000, 'disconnect_voice_1';
}

if ( inactive_now $voice_server_1) {
    print_log "Voice server 1 closed";
    $authorized_1 = 0;
}

if ( $data_1 = said $voice_server_1) {
    if ( $data_1 =~ /Authorization: Basic (\S+)/ ) {
        set $timer_disconnect_1 0;
        ( $user_1, $password_1 ) = split( ':', unpack( "u", $1 ) );
        if ( $password_1 ne $config_parms{server_voice_1_password} ) {
            &disconnect_voice_1;
        }
        else {
            $authorized_1 = 1;

            #            set $voice_server_1 "Password authorized";
            set $voice_server_1 " ";
        }
    }
}

sub disconnect_voice_1 {

    #    set $voice_server_1 "Password missing or invalid. Disconnecting.";
    set $voice_server_1 " ";
    sleep 1;
    stop $voice_server_1;
}

&Speak_pre_add_hook( \&speak_to_others_1 ) if $Reload;

sub speak_to_others_1 {
    if ( ( active $voice_server_1) && ( $authorized_1 == 1 ) ) {
        my %parms = @_;
        set $voice_server_1 "$parms{text}";
    }
}

&Play_post_add_hook( \&play_to_others_1 ) if $Reload;

sub play_to_others_1 {
    if ( ( active $voice_server_1) && ( $authorized_1 == 1 ) ) {
        my %parms = @_;
        set $voice_server_1 "PLAY: $parms{fileplayed}";
    }
}

#---------------------------------------------------------------------------------------------------------------

my $authorized_2 = 0;
my ( $password_2, $user_2, $data_2 );

$voice_server_2 =
  new Socket_Item( "Connected to MisterHouse Voice Server 2\r\n",
    'Welcome', 'server_voice_2' );
$timer_disconnect_2 = new Timer;

if ( ($Reload) && ( active $voice_server_2) ) {
    set $voice_server_2 'RELOAD';
    stop $voice_server_2;
}

if ( ($New_Minute) && ( active $voice_server_2) ) {
    set $voice_server_2 'PING';
}

if ( active_now $voice_server_2) {
    print_log "Voice server 2 connected";
    set $voice_server_2 'Welcome';
    set $timer_disconnect_2 5000, 'disconnect_voice_2';
}

if ( inactive_now $voice_server_2) {
    print_log "Voice server 2 closed";
    $authorized_2 = 0;
}

if ( $data_2 = said $voice_server_2) {
    if ( $data_2 =~ /Authorization: Basic (\S+)/ ) {
        set $timer_disconnect_2 0;
        ( $user_2, $password_2 ) = split( ':', unpack( "u", $1 ) );
        if ( $password_2 ne $config_parms{server_voice_2_password} ) {
            &disconnect_voice_2;
        }
        else {
            $authorized_2 = 1;
            set $voice_server_2 "Password authorized";
        }
    }
}

sub disconnect_voice_2 {
    set $voice_server_2 "Password missing or invalid. Disconnecting.";
    sleep 1;
    stop $voice_server_2;
}

&Speak_pre_add_hook( \&speak_to_others_2 ) if $Reload;

sub speak_to_others_2 {
    if ( ( active $voice_server_2) && ( $authorized_2 == 1 ) ) {
        my %parms = @_;
        set $voice_server_2 "$parms{text}";
    }
}

&Play_post_add_hook( \&play_to_others_2 ) if $Reload;

sub play_to_others_2 {
    if ( ( active $voice_server_2) && ( $authorized_2 == 1 ) ) {
        my %parms = @_;
        set $voice_server_2 "PLAY: $parms{fileplayed}";
    }
}

#---------------------------------------------------------------------------------------------------------------

my $authorized_3 = 0;
my ( $password_3, $user_3, $data_3 );

$voice_server_3 =
  new Socket_Item( "Connected to MisterHouse Voice Server 3\r\n",
    'Welcome', 'server_voice_3' );
$timer_disconnect_3 = new Timer;

if ( ($Reload) && ( active $voice_server_3) ) {
    set $voice_server_3 'RELOAD';
    stop $voice_server_3;
}

if ( ($New_Minute) && ( active $voice_server_3) ) {
    set $voice_server_3 'PING';
}

if ( active_now $voice_server_3) {
    print_log "Voice server 3 connected";
    set $voice_server_3 'Welcome';
    set $timer_disconnect_3 5000, 'disconnect_voice_3';
}

if ( inactive_now $voice_server_3) {
    print_log "Voice server 3 closed";
    $authorized_3 = 0;
}

if ( $data_3 = said $voice_server_3) {
    if ( $data_3 =~ /Authorization: Basic (\S+)/ ) {
        set $timer_disconnect_3 0;
        ( $user_3, $password_3 ) = split( ':', unpack( "u", $1 ) );
        if ( $password_3 ne $config_parms{server_voice_3_password} ) {
            &disconnect_voice_3;
        }
        else {
            $authorized_3 = 1;
            set $voice_server_3 "Password authorized";
        }
    }
}

sub disconnect_voice_3 {
    set $voice_server_3 "Password missing or invalid. Disconnecting.";
    sleep 1;
    stop $voice_server_3;
}

&Speak_pre_add_hook( \&speak_to_others_3 ) if $Reload;

sub speak_to_others_3 {
    if ( ( active $voice_server_3) && ( $authorized_3 == 1 ) ) {
        my %parms = @_;
        set $voice_server_3 "$parms{text}";
    }
}

&Play_post_add_hook( \&play_to_others_3 ) if $Reload;

sub play_to_others_3 {
    if ( ( active $voice_server_3) && ( $authorized_3 == 1 ) ) {
        my %parms = @_;
        set $voice_server_3 "PLAY: $parms{fileplayed}";
    }
}
