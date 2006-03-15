From Robert Mann on 11/2003

I went at it another way.  Here are my files maybe we can merge the good and
strip the bad and figure out the best way to handle this.
The way I did it comprises of a server on MH and AGI for Asterisk.  It uses a
TCP connection and can be on different servers or the same server.  I like the
idea of actually using xAP and will start experimenting with it a little and see
if I can get up to speed.

With this code you get CallerID, DTMF, and External Commands.  Now please note
that I hacked the heck out of the CallerID and DTMF logging to suit my needs as
I wanted more info like the Line the caller was calling or called in to.

CallerID: A user calls in to your Asterisk PBX machine and this information gets
forwarded to MisterHouse and in this implementation gets logged in to the proper
files with some non standard formatting that I use and it also speaks the caller
to the house.

DTMF: A user inside the house on an extension attached to your Asterisk PBX
calls someone else either on the inside or an outside line and this information
is then forwarded to MisterHouse and gets logged in to the proper files again
with some non standard formatting that I use.

Command: A user is able to pick up any extension in the house or call in from
the outside (Be careful you know what you are doing here) and can run any
command you have set up by typing in its extension number and MisterHouse will
execute that command and send the respond  message back to Asterisk where it is
made in to a wav file and sent out which ever channel you are using.  So I can
say Command: Close the garage door Response=yes and it will close my garage door
then tell me something on the phone like "The garage door is now closed" using
the Cepstral or Festival engine on your Asterisk server.

* NOTE * NOTE * NOTE * NOTE * NOTE * NOTE * NOTE * NOTE * NOTE * NOTE * NOTE *
NOTE
This code is not ready for the big-time.  Although my mileage with this code is
good yours may vary.  Look at the code and manipulate it until we have had a
chance to standardize it, sterilize it, and strip all the excess from it.  This
is more a example of how to make an interface between Asterisk and MisterHouse
rather then a working implementation to be used by all.  My hope is that there
is enough of us here now to actually make a working example for all to use and
to get Asterisk out there a little more in the MisterHouse community as it is a
perfect addition to anyone's Home Automation project.

Place the Asterisk.pl in your misterhouse user code directory.
Place the MisterHouse.agi in your asterisk servers agi-bin.  Mine is
/var/lib/asterisk/agi-bin

Look in both the Asterisk.pl and MisterHouse.agi for instructions on setting
these files up.  For MisterHouse it is a matter of adding some mh.ini entries
and for the Asterisk side you need to modify the MisterHouse.agi for what ever
username, password, ip address of misterhouse and port you set up in the mh.ini
file.

If you want to see what is happening you can add more debug code but some is
already in place.  For MisterHouse start with debug of 'asterisk' and in the
MisterHouse.agi file you can change $verbose = 0; to $verbose = 1;

Some sample extensions.conf entries would look like the following.

To issue commands to MisterHouse use the following.  This simply runs
process_external_commands so anything you can normally do with the external
commands in MisterHouse will work.  If you are expecting a response from
MisterHouse use Response=yes otherwise use Response=no.  If you put yes and no
response is received from misterhouse the script will have to timeout before
moving to the proper priority in the extensions.conf file.
[misterhouse]
; MisterHouse commands
exten                   => 8000,1,Playback(/var/lib/asterisk/voice_menus/8000)
exten                   => 8001,1,AGI(MisterHouse.agi,"Command: Open the garage
door Response=yes")
exten                   => 8002,1,AGI(MisterHouse.agi,"Command: Close the garage
door Response=yes")
exten                   => 8003,1,AGI(MisterHouse.agi,"Command: Computer room
ceiling fan toggle Respond=yes")
exten                   => 8004,1,AGI(MisterHouse.agi,"Command: Computer room
ceiling fan on Response=yes")
exten                   => 8005,1,AGI(MisterHouse.agi,"Command: Computer room
ceiling fan off Response=yes")

For CallerID you can use something like the following.  I add the CallerID just
before the Dial to which ever extension you are sending the caller to.  You can
get creative here.  I just placed it there.
[inbound-home]
; When someone calls the home line they are directed through this.
exten                   => fax,1,Dial(${FAX})
exten                   => s,1,Zapateller(answer|nocallerid)
exten                   => s,2,PrivacyManager
exten                   => s,3,AGI(MisterHouse.agi,"CallerID")
exten                   => s,4,Dial(${LINE1_INSIDE},20)
exten                   => s,5,Voicemail2(u2000)
exten                   => s,6,Hangup
exten                   => s,105,Voicemail2(b2000)
exten                   => s,106,Hangup

For DTMF you can use something like the following.  This is placed in a macro
that calls the different extensions but you can place it
anywhere you have the code to call extensions.  The important thing here is the
placement.  Notice the DTMF: ${MACRO_EXTEN} this is because when you are
forwarded to a Macro your extension becomes s instead of the actual extension.
If you are not using Macros like this you can just have DTMF instead of DTMF:
${MACRO_EXTEN}
[macro-oneline]
; Standard [extensions] dialing
exten                   => s,1,Answer
exten                   => s,2,AGI(MisterHouse.agi,"DTMF: ${MACRO_EXTEN}")
exten                   => s,3,Dial(${ARG1},20)
exten                   => s,4,Voicemail2(u${MACRO_EXTEN})
exten                   => s,5,Hangup
exten                   => s,104,Voicemail2(b${MACRO_EXTEN})
exten                   => s,105,Hangup

Good luck and I welcome your comments and suggestions.  I am by no means an
expert and have just tried to do the best I can at this time.

Robert Mann
mh@easyway.com

