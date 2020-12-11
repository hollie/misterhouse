# Category=Music
# mp3_control_x10.pl allows for the house mp3 player to be controlled using X10 codes
# of your choice eg using an "8 in 1" or keychain remote.
# Author: Richard Phillips, god@ninkasi.com
# V1.0 - 5 Jan 2002 - created
# V2.0 - 23 March 2003 - major modification to allow use with any misterhouse player
# module by using standard run commands rather than dedicated xmms commands
# In other words, this should now work whether you use winamp or xmms or.....
#
# To use this, you will probably need to change the X10 house codes to match
# whatever your remote may be using. Also, you will need to change the playlists
# to whatever are your favourites

# define the keys
$mp3remote = new Serial_Item( 'XP7PK', 'mp3-pause' );
$mp3remote->add( 'XP7PJ', 'mp3-play' );
$mp3remote->add( 'XP8PK', 'mp3-back' );
$mp3remote->add( 'XP8PJ', 'mp3-fwd' );
$mp3remote->add( 'XP9PJ', 'mp3-volup' );
$mp3remote->add( 'XP9PK', 'mp3-voldn' );
$mp3remote->add( 'XPBPK', 'mp3-1' );
$mp3remote->add( 'XPBPJ', 'mp3-2' );
$mp3remote->add( 'XPCPK', 'mp3-3' );
$mp3remote->add( 'XPCPJ', 'mp3-4' );
$mp3remote->add( 'XPDPK', 'mp3-5' );
$mp3remote->add( 'XPDPJ', 'mp3-6' );

run_voice_cmd 'Set the house mp3 player to pause'
  if state_now $mp3remote eq 'mp3-pause';
run_voice_cmd 'Set the house mp3 player to play'
  if state_now $mp3remote eq 'mp3-play';
run_voice_cmd 'Set the house mp3 player to Next Song'
  if state_now $mp3remote eq 'mp3-fwd';
run_voice_cmd 'Set the house mp3 player to Previous Song'
  if state_now $mp3remote eq 'mp3-back';
run_voice_cmd 'Set the house mp3 player to Volume Up'
  if state_now $mp3remote eq 'mp3-volup';
run_voice_cmd 'Set the house mp3 player to Volume Down'
  if state_now $mp3remote eq 'mp3-voldn';

# Now for the playlists - change the name in the lines below to match
# your favourites. Note - do not include the .pls or .m3u extension
# Note also that below it says "Set house" rather than "Set the house" as
# it does above - this is not a typo [ well, not mine anyway ;-) ] but
# is required because this is how the various modules this program uses
# require commands to be sent to them......
run_voice_cmd 'Set house mp3 player to playlist portishead'
  if state_now $mp3remote eq 'mp3-1';
run_voice_cmd 'Set house mp3 player to playlist julielondon'
  if state_now $mp3remote eq 'mp3-2';
run_voice_cmd 'Set house mp3 player to playlist ellafitzgerald'
  if state_now $mp3remote eq 'mp3-3';
run_voice_cmd 'Set house mp3 player to playlist sarahvaughn'
  if state_now $mp3remote eq 'mp3-4';
run_voice_cmd 'Set house mp3 player to playlist assortedjazz'
  if state_now $mp3remote eq 'mp3-5';
run_voice_cmd 'Set house mp3 player to playlist mozart'
  if state_now $mp3remote eq 'mp3-6';
