# Demo / Debugging aid for Stanley Garage Door Status hardware via CM11 interface.

use vars '$door1_old', '$door2_old', '$door3_old';
$garage_doors = new X10_Garage_Door('B');

# Returned state is "bbbdccc"
# "bbb" is 1=door enrolled, 0=enrolled, indexed by door # (i.e. 123)
# "d" is door that caused transmission, numeric 1, 2, or 3
# "ccc" is C=Closed, O=Open, indexed by door #

if (state_now $garage_doors) {
   my $state = state $garage_doors;
   my ($en1, $en2, $en3, $which, $door1, $door2, $door3);

   ($en1, $en2, $en3, $which, $door1, $door2, $door3) = $state =~ /(\S)(\S)(\S)(\S)(\S)(\S)(\S)/;

   print "\n\n   Garage Door Transmission Received\n";
   print "State=$state\n";

   my %table_dcode = qw(O Open C Closed);
   print "Transmission from $which\n";
   print "Door 1 state is $table_dcode{$door1}\n" if $en1;
   print "Door 2 state is $table_dcode{$door2}\n" if $en2;
   print "Door 3 state is $table_dcode{$door3}\n" if $en3;
   print "\n";

   if ($which eq '1') {
      if ($door1 eq $door1_old) {
         print "Door 1 timer or retransmit update, door1 $table_dcode{$door1}\n";
      }  else {
         print "Door 1 status change, old $table_dcode{$door1_old}, new $table_dcode{$door1}\n";
         speak "Door 1 is $table_dcode{$door1}";
      }
   }

   if ($which eq '2') {
      if ($door2 eq $door2_old) {
         print "Door 2 timer or retransmit update, door2 $table_dcode{$door2}\n";
      }  else {
         print "Door 2 status change, old $table_dcode{$door2_old}, new $table_dcode{$door2}\n";
         speak "Door 2 is $table_dcode{$door2}";
      }
   }

   if ($which eq '3') {
      if ($door3 eq $door3_old) {
         print "Door 3 timer or retransmit update, door3 $table_dcode{$door3}\n";
      }  else {
         print "Door 3 status change, old $table_dcode{$door3_old}, new $table_dcode{$door3}\n";
         speak "Door 3 is $table_dcode{$door3}";
      }
   }

   $door1_old = $door1;
   $door2_old = $door2;
   $door3_old = $door3;
}


# Prove we can query garage door data asynchronously

$test_button = new Serial_Item('XB4');
if (state_now $test_button) {

   my $state2 = state $garage_doors;
   my ($en1, $en2, $en3, $which, $door1, $door2, $door3);
   ($en1, $en2, $en3, $which, $door1, $door2, $door3) = $state2 =~ /(\S)(\S)(\S)(\S)(\S)(\S)(\S)/;

   print "\n\n Button B4 pushed - Garage Status Query\n";
   print "Garage Door State=$state2\n";

   my %table_dcode = qw(O Open C Closed);
   print "door 1 state is $table_dcode{$door1}\n" if $en1;
   print "door 2 state is $table_dcode{$door2}\n" if $en2;
   print "door 3 state is $table_dcode{$door3}\n" if $en3;
   print "\n";
   

}
