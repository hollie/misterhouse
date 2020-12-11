
=begin comment

From Bill Sobel on 01/2003:

Define the computers in your mht file.  For example:

WAKEONLAN, 00:01:02:03:04:01,           BillsOfficeComputer,WakeableComputers
WAKEONLAN, 00:01:02:03:04:02,           AngelasOfficeComputer,WakeableComputers

The 'address' definition is the computers MAC address. 

This works by transmiting the wake on lan magic packet on the MH subnet (we can add
directed broadcast support if needed, but I suspect the normal
255.255.255.255 broadcasat will handle the MH users just fine).

Most new computers support this.  I found with the cost of power here in California, it was
well cost effective to get the right drivers and make this all work.  I try
to only keep the server and the mh machine 'on' all the time and kill of the
others into hibernate unless needed.


>I also tried your wakeup script.  I found 2 computers here that almost work
>with that.  Your code does indeeded wake them up, but so does almost any
>other lan traffic :(    I turned on the bios 'wake/resume on lan' optoins
>and tried setting various wake on lan options from XP, including the one
>that says 'wake only from a managed something or other' on the far right tab
>of my ethernet properties menu, but I suspect what I need is a utility that
>somehow sets something on the card?   And it works only from suspend mode,
>not off or hibernate mode, right?

On my two Dell systems the MS provided NIC driver didn't support setting the
card to just wake on magic packet (it woke on any traffic as yours did, and
with my print server broadcasting announcements, well lets just say it
didn't work as expected!).  In my case I had a 3com nic so I had to install
the current driver from 3com.  That added an updated settings tab in the
driver properties that included a zillion settings including all the
different wake settings.

As far as suspend vs hibernate, it depends on what sleep state (s1-s5) your
system goes into when you hibernate, it has to be in a mode that still
provides just a tad of power to the nic.  Generally wol should work on
hibernated systems (thats how I use it here).

=cut

use WakeOnLan;

$BillsOfficeComputer->set("on") if time_now '7 am';

