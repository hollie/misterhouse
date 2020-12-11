# Category = Ocelot

=begin comment 

By David Norwood, dnorwood2@yahoo.com	

I am using one of the inputs for my rain gauge.  By default, the logging on the 
Ocelot doesn't tell you which input changed, which is lame. Here is how I
do it. I used the nxamsg program to add an ascii message "Rain" at position
0 on the Ocelot. I then added the following code to my Ocelot program using
oclc:


// report rain

if ( module_point("1/0", Turns_on) ) {
	transmit_ascii_string(0);
}


The following misterhouse code looks for the word "Rain" on the inputs and 
records it.  

=cut

$ocelot_raingauge = new Serial_Item 'Rain';

if ( state_now $ocelot_raingauge) {
    $Weather{RainTotal} += .01;
}
