# Category = Nag

##################################################################
#  Cat Box items & actions                                       #
#                                                                #
#  By: Danal Estes, N5SVV                                        #
#  E-Mail: danal@earthling.net                                   #
#                                                                #
##################################################################

$Cat_Box_Control  = new Serial_Item('XC4CJ');
$Cat_Box_Control -> add            ('XC4CK');
$Cat_Box_Control -> add            ('XC5CK');
$Cat_Box_Control -> add            ('XC5CJ');
$Cat_Box_Control -> add            ('XC6CK');
$Cat_Box_Control -> add            ('XC6CJ');

if (state_now $Cat_Box_Control) {
   my $state = state $Cat_Box_Control;
   if ($state eq 'XC4CJ') { 
      print_log "Cat Box Button 4 pushed ON - Cat Box Scooped for the day";
   }
   if ($state eq 'XC4CK') { 
      print_log "Cat Box Button 4 pushed OFF - Cat Box full change";
   }
   if ($state eq 'XC5CJ') {
      print_log "Cat Box Button 5 pushed ON";
   }
   if ($state eq 'XC5CK') {
      print_log "Cat Box Button 5 pushed OFF";
   }
   if ($state eq 'XC6CJ') {
      print_log "Cat Box Button 6 pushed ON";
   }
   if ($state eq 'XC6CK') {
      print_log "Cat Box Button 6 pushed OFF";
  }
}

if ($New_Minute and time_cron '1,16,31,46 18,19,20,21,22,23 * * *') {
   my ($date, $time, $state) = (state_log $Cat_Box_Control)[0] =~ /(\S+) (\S+) *(.*)/;
   use Time::ParseDate;
   my $tnow=parsedate('now');
   my $tcat=parsedate("$date $time");
   my $tdiff = $tnow - $tcat;
print_log "Cat Box Timers: Last date/time $date $time, seconds $tcat, secs now $tnow, diff $tdiff";

   if ($tdiff > 24*60*60) {
      print_log "Cat box not changed in 24 hours; speaking nag message";
	speak "Meeeoow, Change the cat box";
   }
}

