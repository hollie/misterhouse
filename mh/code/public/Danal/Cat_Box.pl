# Category = Nag

##################################################################
#  Cat Box items & actions                                       #
#                                                                #
#  By: Danal Estes, N5SVV                                        #
#  E-Mail: danal@earthling.net                                   #
#                                                                #
##################################################################

$Cat_Box_Control  = new Serial_Item('XC4CJ','Scoop');
$Cat_Box_Control -> add            ('XC4CK','Full');
$Cat_Box_Control -> add            ('XC5CK','5on');
$Cat_Box_Control -> add            ('XC5CJ','5off');
$Cat_Box_Control -> add            ('XC6CK','6on');
$Cat_Box_Control -> add            ('XC6CJ','6off');

$Cat_Box_Reminder = new X10_Item('JG');

if (state_now $Cat_Box_Control) {
   my $state = state $Cat_Box_Control;
   if ($state eq 'Scoop') { 
      print_log "Cat Box Button 4 pushed ON - Cat Box Scooped for the day";
      set $Cat_Box_Reminder OFF;
   }
   if ($state eq 'Full') { 
      print_log "Cat Box Button 4 pushed OFF - Cat Box full change";
      set $Cat_Box_Reminder OFF;
   }
   if ($state eq '5on') {
      print_log "Cat Box Button 5 pushed ON";
   }
   if ($state eq '5off') {
      print_log "Cat Box Button 5 pushed OFF";
   }
   if ($state eq '6on') {
      print_log "Cat Box Button 6 pushed ON";
   }
   if ($state eq '6off') {
      print_log "Cat Box Button 6 pushed OFF";
  }
}

if ($New_Minute and time_cron '1,16,31,46 12,13,14,15,16,17,18,19,20,21,22,23 * * *') {
   my ($date, $time, $state) = (state_log $Cat_Box_Control)[0] =~ /(\S+) (\S+) *(.*)/;
   use Time::ParseDate;
   my $tnow=parsedate('now');
   my $tcat=parsedate("$date $time");
   my $tdiff = $tnow - $tcat;
print_log "Cat Box Timers: Last date/time $date $time, seconds $tcat, secs now $tnow, diff $tdiff";

   if ($tdiff > 18*60*60) {
      print_log "Cat box not changed today; speaking nag message";
	speak "Djeeni says: Meeeoow, Change the cat box";
      set $Cat_Box_Reminder ON if 'on' ne state $Cat_Box_Reminder;
   }
   if ($tdiff > 42*60*60) {
	speak "Really!";
   }
   if ($tdiff > 64*60*60) {
	speak "It Stinks!";
   }
}

