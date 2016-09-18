# Category=MisterHouse
#
# mh_restart.pl will restart Mister House at a specific time each day - useful if
# you are having some issues with memory leaks or frankly just want to make
# sure that if ever there ARE any issues they may be dealt with automatically
# without you having to worry about it.....

# Author: Richard Phillips, god@ninkasi.com
# V1.0 - 25 March 2003 - released

# If you want, you can also assign a key on an RF remote to restart
# the server on command - unlikely you'd want to do this other than
# for testing purposes. Or to show off to your geek friends. Very sad.
# Might I suggest getting a hobby... ;-)
# In the example below, the house code is "P" and
# the unit is "10". There are two settings so that either the ON or OFF
# command will do the same thing.

# $death_remote = new Serial_Item('XPAPK', 'restart');
# $death_remote -> add	('XPAPJ', 'restart');
# run_voice_cmd 'Restart Mister House' if state_now $death_remote eq 'restart';

# Anyhow, on to the actual code - just change the time below to suit if you
# are usually playing with Mister House at 3am.... did I mention getting
# a hobby? ;-)

if ( time_now '3:00AM' ) {
    print_log "It's time to restart MisterHouse!";
    run_voice_cmd 'Restart Mister House';
}

# Note - naturally to get the most from this you need to have Mister House
# set to restart automatically. You can do this with a batch file in dos/win
# or a shell script in linux. Examples already come with misterhouse eg mhl
# but just fyi:

# For example in linux create a file called mhstart and put the following in it:

# #!/bin/bash
#
# number=0
# while [ $number -lt 1000 ]; do
#        /home/mh/misterhouse/bin/mh -tk 0 -code_dir /home/mh/richard
#        number=$((number + 1 ))
# done

# Then flag it as executable eg "chmod 777 mhstart"

# Or in windows create a text file using notepad, call it something like
# "mhstart.bat" or "mhstart.cmd" and put the following in it:

# :top
# c:\mh\mh -tk 0 -code_dir c:\mh\mycode
# goto top

# Obviously, change the directories and other options to suit your setup. Cheers.
