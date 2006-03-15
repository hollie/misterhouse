
From Jason Sharpee on 11/2003:

I finished a "low-tech" xAP approach at intergration between Asterisk and 
MH.  The attached mhcommand.agi will allow you to send commands (voice, 
etc) to the MH instance listening via UDP (on the same segment?) with the 
mh_command.pl (I sent to the list earlier) enabled within MH.

To use simply:

exten => 201,1,AGI(mhcommand.agi,turn family light on)

I also included my cepstral.agi for using their tts within asterisk for 
the response if any from running the command.  The cepstral.agi can be 
called like:

exten => 201,1,AGI(cepstral.agi,Hi this is a test TTS message)

It currently has a problem if the text is greater than a certain amount of 
bytes (over 100) Possibly because of the passed command line to the theta 
engine.  Anyone care to help me out and make it create file and read? (My 
weather forecast gets cut off)

This code is very "quick and dirty" so if you would like to make 
corrections / improvements, PLEASE DO! :)
