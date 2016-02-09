# Category=Music

#@ Monitor a ShoutCast streaming audio server for winamp clients

=begin comment


There are 2 ways to doing this:
  - tail the log file with the said File_Item method
  - connect a socket to the server

If using the server method, you need to specify if you are
using the older 1.0 version, as the format of the data change
(newer versions us http data streams so you can monitor server
status with a web browser).

I had problems with the server on 1.1 on linux.
Version 1.5 works fine with the server method.

If using the server method, add these parms to your mh.ini:
    shoutcast_version=1.1
    shoutcast_server=ip_address:8000
    shoutcast_password=your_password

If using the log method, you only need this parm:
    shoutcast_log=d:\shoutcast\sc_serv.log

Info on how to set up a shoutcast server is at:
   http://mp3spy.com/server

=cut

# Make sure shoutcast player is running
#run_voice_cmd 'Set house mp3 player to playlist bruce_20' if $Startup;

# Check to see if the winamp shoutcast player is playing or connected
#  - this requires the httpq winamp plugin
$v_shoutcast_check = new Voice_Cmd 'Check the shoutcast player';
$v_shoutcast_check->set_info(
    'Will check the status the shoutcast winamp player and server');

$v_shoutcast_connect =
  new Voice_Cmd '[Connect,Disconnect] the shoutcast player';
$v_shoutcast_connect->set_info(
    'Use this to connect or disconnect the shoutcast winamp player from the shoutcast server'
);

my $sc_player_url;
if ($Reload) {
    $temp = 'localhost' unless $temp = $config_parms{shoutcast_player};
    $sc_player_url = "http://$temp:$config_parms{mp3_program_port}";
}

if ( said $v_shoutcast_check) {

    # 0 => stopped, 1 => playing, 3 => paused
    $temp =
      '  playing='
      . filter_cr get
      "$sc_player_url/isplaying?p=$config_parms{mp3_program_password}";
    $temp .= ',  time='
      . int(
        (
            filter_cr get
              "$sc_player_url/getoutputtime?p=$config_parms{mp3_program_password}&a=0"
        ) / 60000
      );
    $temp .=
      ' minutes,  status='
      . filter_cr get
      "$sc_player_url/shoutcast_status?p=$config_parms{mp3_program_password}";
    print_log "Shoutcast data: $temp";
}

if ( $state = said $v_shoutcast_connect) {
    print_log "Connectiong to $sc_player_url";
    my $status = filter_cr get
      "$sc_player_url/shoutcast_status?p=$config_parms{mp3_program_password}";
    if ( $state eq 'Connect' ) {
        if ( $status =~ /sent/ ) {
            print_log "Shoutcast player already connected: $status";
        }
        else {
            $status = filter_cr get
              "$sc_player_url/shoutcast_connect?p=$config_parms{mp3_program_password}";
            print_log "Shoutcast connect status: $status";
        }
    }
    else {
        if ( $status eq 'Disconnected.' ) {
            print_log "Shoutcast player already disconnected";
        }
        else {
            $status = filter_cr get
              "$sc_player_url/shoutcast_connect?p=$config_parms{mp3_program_password}";
            print_log "Shoutcast disconnect status: $status";
        }
    }
}

# Open the port ... check periodically, in case server was restarted.

$shoutcast_server =
  new Socket_Item( undef, undef, $config_parms{shoutcast_server}, 'shoutcast' );
$shoutcast_log = new File_Item( $config_parms{shoutcast_log} );

$v_shoutcast_server = new Voice_Cmd '[Start,Stop] the shoutcast server monitor';
$v_shoutcast_server->set_info(
    'The shoutcast server monitor announces when new listeners come');

print "Shoutcast server close\n"     if inactive_now $shoutcast_server;
print "Shoutcast server started\n"   if active_now $shoutcast_server;
print_log "Shoutcast server close"   if inactive_now $shoutcast_server;
print_log "Shoutcast server started" if active_now $shoutcast_server;

if (    ( $Startup or new_minute 15 or said $v_shoutcast_server eq 'Start' )
    and $config_parms{shoutcast_server}
    and !active $shoutcast_server
    and ( state $v_shoutcast_server ne 'Stop' ) )
{

    #   speak 'Shoutcast monitor started' unless $Startup;

    print_log
      "Starting a connection to the shoutcast server $config_parms{shoutcast_server}";
    start $shoutcast_server;

    # Use HTTP with shoutcast 1.1+
    my $temp = <<eof;
GET /admin.cgi?pass=$config_parms{shoutcast_password}&mode=viewlog&viewlog=tail HTTP/1.1
User-Agent: Mozilla/4.0 (compatible; MisterHouse)
Connection: Keep-Alive
eof

    # Use TAILLOG with shoutcast 1.0
    $temp = "TAILLOG $config_parms{shoutcast_password}"
      if $config_parms{shoutcast_version} eq '1.0';

    #   print "\n\n dbx $config_parms{shoutcast_version} temp=$temp\n";
    set $shoutcast_server $temp;

}

if ( said $v_shoutcast_server eq 'Stop' ) {
    speak 'Monitor stopped';
    stop $shoutcast_server;
}

# Now monitor the server log
my ( %shoutcast_clients, $shoutcast_record );

if (   $config_parms{shoutcast_server} and $state = said $shoutcast_server
    or $config_parms{shoutcast_log}
    and $New_Second
    and $state = said $shoutcast_log)
{
    # Can somehow get multiple reports on one record ... us only the last one.
    #<12/30/00@07:16:59> [dest: 192.168.0.2] connection closed (15 seconds) (UID: 78)[L: 0]<12/30/00@14:40:14> [dest: 192.168.0.2] starting stream (UID: 84)[L: 1]...
    # Greedy ... will only keep the last one
    # Ignore data on startup ... it has buffer of old listeners
    #   if ($Time > (30 + $Time_Startup_time) and
    if (    $Loop_Count > 200
        and $state =~ s/.+dest:/dest:/ )
    {
        #       print "db t=$Time,$Time_Startup_time s=$state\n";
        $shoutcast_record = $state;
        my ($ip_address) = $shoutcast_record =~ /: ?(\S+)\]/;

        # Ignore status at startup
        net_domain_name_start 'shoutcast', $ip_address if $Loop_Count > 10;
        print_log "Shoutcast record: $shoutcast_record ip=$ip_address";
    }
}

# This will be true when the DNS lookup started above finishes
if ( my ( $domain_name, $name_short ) = net_domain_name_done 'shoutcast' ) {
    my ( $ip_address, $status ) =
      $shoutcast_record =~ /: ?(\S+)\] ([^\(\[\,]+)/;

    #   my $Save{shoutcast_users} = $1 if $shoutcast_record =~ /\((\d+)\/\d+/; # looking for the first number here: (1/4)
    $Save{shoutcast_users} = $1
      if $shoutcast_record =~
      /\[L: *(\d+)/;    # looking for the first number here: [L: 1]

    print_log
      "shoutcast users=$Save{shoutcast_users} domain=$domain_name, status=$status, ip=$ip_address, r=$shoutcast_record";

    $name_short =~ s/[\d\.]/ /g;    # Get rid of digits and dots
    $name_short = 'unknown'
      if $name_short =~ /^ *$/ or is_local_address $ip_address;

    my $msg =
      ( $status =~ /starting stream/ )
      ? "DJ as a new listener.  There are now $Save{shoutcast_users} listeners."
      : "DJ now has $Save{shoutcast_users} listeners.";

    #  IP forwarded, so we no longer have the ip address of the listener, so skip the name part
    #   my $msg = plural_check "DJ now has $Save{shoutcast_users} listeners.";
    #   $msg .= ($status =~ /starting stream/) ? '  Hello to ' : '  Goodbye ';
    #   $msg .=  $name_short;

    $msg = "The DJ is dead.  $name_short is sad" if $status =~ /unavailable/;

    my $time_since_last_visit = $Time - $shoutcast_clients{$name_short}{time};

    #   print "db sc time $time_since_last_visit, $shoutcast_clients{$name_short}{time}\n";
    $shoutcast_clients{$name_short}{time} = $Time;
    $shoutcast_clients{$name_short}{hits}++;

    # Set our 'have listeners' led
    my $led = $Save{shoutcast_users} ? 2 : 0;
    get "http://piano/cgi-bin/SetLEDState?$led";

    if (    $time_since_last_visit > 20
        and $config_parms{internet_speak_flag} ne 'none'
        and $name_short ne 'local' )
    {
        #       speak "rooms=all $msg";
        speak "voice=female $msg";
    }
    else {
        print_log $msg;
    }

    #   display("$Time_Now: $msg", 0);
    logit( "$config_parms{data_dir}/logs/shoutcast_server.$Year_Month_Now.log",
        "domain=$domain_name ip=$ip_address status=$status count=$Save{shoutcast_users}"
    );
}

# Give listeners some chatter to listen to
#$dj_tagline = new  File_Item "$config_parms{data_dir}/remarks/1100tags.txt";
#speak "card=3 DJ says: <voice required='gender=male2'/>" . read_next $dj_tagline if $Save{shoutcast_users} and new_minute;
#peak card => 3,  volume => 200, text => "DJ says: " . &Voice_Text::set_voice('male2', read_next $dj_tagline) if $Save{shoutcast_users} and new_minute;
#speak rooms => 'DJ',  volume => 200, text => "DJ says: " . &Voice_Text::set_voice('male2', read_next $dj_tagline) if $Save{shoutcast_users} and new_minute;

# Make sure we are syncronized
#run_voice_cmd 'Set the house mp3 player to Play' if $Reload;

# Server V 1.7.1
#<12/22/00@10:32:37> [dest: 192.168.0.2] starting stream (UID: 4)[L: 1].
#                     dest: 192.168.0.2] server unavailable, disconnecting
# Old server version

#<07/17/99@20:17:43> [dest: 200.200.200.2] starting stream
#<07/17/99@20:33:43> [dest: 200.200.200.2] connection closed (sent 0 bytes total)
#<07/18/99@16:14:34> [dest] 1/4 users

#<01/15/100@21:48:33> [http:200.200.200.5] REQ:"/" (Mozilla/4.07 [en] (X11; I; Linux 2.2.10 i686))
#<01/15/100@21:54:10> [dest: 200.200.200.3] starting stream (1/32)
#<01/15/100@21:54:21> [dest: 200.200.200.3] connection closed (sent 40878 bytes total) (0/32)
#<01/15/100@21:54:23> [dest: 200.200.200.3] starting stream (1/32)
#<01/15/100@21:54:31> [dest: 200.200.200.3] connection closed (sent 33388 bytes total) (0/32)
