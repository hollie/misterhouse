# Category = Kitchen

##################################################################
#  Dining Room items & actions                                   #
#                                                                #
#  By: Danal Estes, N5SVV                                        #
#  E-Mail: danal@earthling.net                                   #
#                                                                #
##################################################################

$Kitchen_Island_Light     = new X10_Item('K1');
$Kitchen_Down_Light       = new X10_Item('K2');
#$Kitchen_Sink_Light       = new X10_Item('K3');
$Kitchen_Cook_Light       = new X10_Item('K4');
#$Kitchen_Butler_Light     = new X10_Item('K5');
$Kitchen_Breakfast_Light  = new X10_Item('K6');
$Kitchen_UcabRight_Light  = new X10_Item('K7');
#$Kitchen_UcabLeft_Light   = new X10_Item('K8');
$Kitchen_UcabDesk_Light   = new X10_Item('K9');
#$Kitchen_UcabButler_Light = new X10_Item('KA');
#$Kitchen_UcabIsland_Light = new X10_Item('KB');

$Dining_Plant_Light       = new X10_Appliance('KF');

$Kitchen            = new Group($Kitchen_Island_Light,
                                $Kitchen_Down_Light,
                                $Kitchen_UcabRight_Light,
                                $Kitchen_UcabDesk_Light);

$Kitchen_rmt        = new Group($Kitchen_UcabRight_Light,					  
                                $Kitchen_UcabDesk_Light);
my $state;

if ($state = state_now $Kitchen_Island_Light) {
   print_log "Kitchen Island Light State = $state, pass = $Loop_Count";
   set $Kitchen_rmt ON if $state eq 'on';
   set $Kitchen OFF if $state eq 'double off';
}

if ($state = state_now $Kitchen_Down_Light) {
   print_log "Kitchen Down Light State = $state, pass = $Loop_Count";
   set $Kitchen_rmt ON if $state eq 'on';
   set $Kitchen OFF if $state eq 'double off';
}

if (my $state = state_now $DSC_Alarm) {
  if ($state eq 'Disarmed' and $Dark) {set $Kitchen_rmt ON};
  if ($state eq 'Armed') {
    my $mode = mode $DSC_Alarm;
    if ($mode eq 'Away') {set $Kitchen OFF};
  }  
}
#  Note: A DSC alarm system will always arm in "AWAY" mode
#        unless at least one zone is defined as "Stay/Away".
#        I defined an unused zone as stay/away.  Further note
#        DSC will arm in STAY (even if you request AWAY) unless
#        one delay zone is violated during exit delay.

if ($New_Minute) {
   if (time_cron '0 6 * * *') {
      print_log "6:00 AM; Turn Plant Lights ON";
      set $Dining_Plant_Light ON;
   }
   if (time_cron '0 23 * * *') {
      print_log "11:00 PM; Turn Plant Lights OFF";
      set $Dining_Plant_Light OFF;
   }
}


