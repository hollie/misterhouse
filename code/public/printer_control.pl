#category Printer

=begin comment
  From Paul Wilkinson on 4/30/2001

I have attached a small module that I wrote to control my laser printer
using an X10 appliance module and monitoring the linux printer queue
status file.  The script turns on the printer when it detects a change
in the status file (presumably this means a job has just been queued)
and turns the printer off 5 minutes after the last change (presumably
the print job has finished).

=cut

$ptimer  = new Timer;
$printer = new X10_ITEM('A3')   # Change to suit your printer's appliance module

  #The name of your printer status file
  #NOTE: This file is typically only readable by daemon & lp
  #You may need to add world read permissions to this file and it's parent
  #directories
  my $pstatus = "/var/spool/lpd/lexmark-PS110/status.lexmark-PS110";

if ( file_changed($pstatus) ) {
    print "Printer On for print job\n";
    set $printer "on";
    set $ptimer 5 * 60,
      'print "Printer off after 5mins.\n"; set $printer "off"';

}
