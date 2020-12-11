
# Category=Music

#@ This script is a reference holder for the streaming service parameter used with
#@  the mp3 'now playing' applet and associated  MP3 player.
#@ handles the changing of the URL that you may set your MP3 Player to stream to.
#@ Enable mp3.pl to manage the MP3 database.
#@ This script requires mp3.pl and a player program. You'll need to set that progream up
#@ to stream off to a server.
#@
#@ Set mp3_stream_server_port to where your streaming server can be found by client players.  For example,
#@   mp3_stream_server_prot=http://streams.your.com:8010/
my $mp3_stream_server_port = $config_parms{mp3_stream_server_port};
