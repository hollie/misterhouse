
=begin comment

From Andrew Drummond on 04/2002:

Here's a mh module that some people may be interested in. It allows the
control of a dss receiver through its data port on the back (DB15/DB9 or
RJ45 depending on your model). Simple cable instructions are included in the
gz file attached.


I have stopped working on as I now only have a directivo with no data port.
I am currently working on a directivo version that uses ppp over serial and
the directivo bash hack.


This module has not been heavily tested and two things to watch out for is
my multiple unit support (completely untested as I only had on receiver) and
secondly getting information back using said is iffy at best, it was
designed the way it is so as not to delay mh while waiting for a reply from
the dss receiver (can take as long as four - six seconds in some cases).


Provides serial port control of most dss receivers. Has not been well tested but works for me.

Cable Wiring 


Computer------------|---DirecTV Receiver------------------------------- 
DE9F 	DB25F 	Sig |	Sig 	DE9M 	DA15M 	Modular 4P4C 	      |
-----------------------------------------------------------------------
5 	7 	Gnd |	Gnd 	5 	13 	1 
2 	3 	RxD |	TxD 	2 	14 	2  
3 	2 	TxD |	RxD 	3 	6 	4  
                

Pin one on the modular 4p4c connector is left most pin when the clip is down
and the opening is to the back (see below)
       
          ____________
          |           |
 1	------------  |--
 2	------------  | |
 3	------------  | |
 4	------------  | |
          |           |--
          -------------


This module was created using information from 
www.pcmx.net/dtvcon/ and www.isd.net/mevenmo/sonydsscodes.html

=cut

my $state_test;
my $said_dss;
$test = new Voice_Cmd(
    "dss to [GetTime,GetChannel,FoxE,FoxW,COM,SetChannel 284,SetChannel 382,SetChannel 383]"
);

$dss = new dss_interface( undef, undef, 'dss' );
$dss->add( "SetChannel 388", "FoxE" );
$dss->add( "SetChannel 389", "FoxW" );
$dss->add( "SetChannel 249", "COM" );

$state_test = state_now $test;
print "$state_test \n" if $state_test;
set $dss "$state_test" if $state_test;

$said_dss = said $dss;
print "DSS replied with $said_dss\n" if $said_dss;

