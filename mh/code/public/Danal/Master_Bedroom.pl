# Category = Master Bedroom

##################################################################
#  Master bedroom items & actions                                #
#                                                                #
#  By: Danal Estes, N5SVV                                        #
#  E-Mail: danal@earthling.net                                   #
#                                                                #
##################################################################

$Master_Ceiling_Light   = new X10_Item('M1');
$Master_Ceiling_Fan     = new X10_Item('M2');
$Master_Fireplace_Light = new X10_Item('M3');
$Debbie_Lamp            = new X10_Item('M4');
$Debbie_Fan             = new X10_Appliance('M5');
$Danal_Lamp             = new X10_Item('M6');
$Danal_Fan              = new X10_Appliance('M7');
$Master_TV              = new X10_Appliance('M8');

$Master_Bedroom  = new Group($Master_Ceiling_Light);
$Master_Bedroom -> add($Master_Ceiling_Fan);
$Master_Bedroom -> add($Master_Fireplace_Light);
$Master_Bedroom -> add($Debbie_Lamp);
$Master_Bedroom -> add($Debbie_Fan);
$Master_Bedroom -> add($Danal_Lamp);
$Master_Bedroom -> add($Danal_Fan);
$Master_Bedroom -> add($Master_TV);


$Master_Control  = new Serial_Item('XC1CJ','Reading');
$Master_Control -> add            ('XC1CK','Sleep');
$Master_Control -> add            ('XC2CJ','DanalRead');
$Master_Control -> add            ('XC2CK','DebbieRead');
$Master_Control -> add            ('XC3CJ','KitchenToggle');
$Master_Control -> add            ('XC3CK','AllOff');

if ($New_Minute) {
   if (time_now("$Time_Sunset - 0:30")) {
      print_log "Sunset at $Time_Sunset; now dusk, set up Master Bedroom for evening";
      set $Debbie_Lamp ON;  set $Danal_Lamp ON;
   }
   if (time_cron '0,5 8 * * 1-5') {
      print_log "8:00 AM on a weekday; set up Master Bedroom for ALL OFF";
      set $Debbie_Fan  OFF; set $Danal_Fan  OFF;
      set $Debbie_Lamp OFF; set $Danal_Lamp OFF;
      $Save{mode} = 'normal'; 
      &speak(mode => 'unmuted', text => "Djeeni is set to $Save{mode} speech mode");
   }
   if (time_cron '0,5 11 * * 0,6') {
      print_log "11:00 AM on a weekend; set up Master Bedroom for ALL OFF";
      set $Debbie_Fan  OFF; set $Danal_Fan  OFF;
      set $Debbie_Lamp OFF; set $Danal_Lamp OFF;
      $Save{mode} = 'normal'; 
      &speak(mode => 'unmuted', text => "Djeeni is set to $Save{mode} speech mode");
   }
}

if (state_now $Master_Control) {
   my $state = state $Master_Control;
   if ($state eq 'Reading') { 
      print_log "Master Bedroom Button 1 pushed ON - Set up for READING";
      set $Debbie_Lamp ON; set $Danal_Lamp ON;
      set $Debbie_Fan  ON; set $Danal_Fan  ON;
   }
   if ($state eq 'Sleep') { 
      print_log "Master Bedroom Button 1 pushed OFF - Set up for SLEEP";
      set $Debbie_Lamp OFF; set $Danal_Lamp OFF;
      set $Debbie_Fan  ON;  set $Danal_Fan  ON;
      $Save{mode} = 'mute'; 
      &speak(mode => 'unmuted', text => "Djeeni is set to $Save{mode} speech mode");

   }
   if ($state eq 'DanalRead') {
      print_log "Master Bedroom Button 2 pushed ON - Set up for Danal Only Reading";
      set $Debbie_Lamp OFF; set $Danal_Lamp ON;
      set $Debbie_Fan  ON;  set $Danal_Fan  ON;
   }
   if ($state eq 'DebbieRead') {
      print_log "Master Bedroom Button 2 pushed OFF - Set up for Debbie Only Reading";
      set $Debbie_Lamp ON; set $Danal_Lamp OFF;
      set $Debbie_Fan  ON; set $Danal_Fan  ON;
   }
   if ($state eq 'KitchenToggle') {
      print_log "Master Bedroom Button 3 pushed ON - No Function currently assigned, so do something interesting";
      ('on' eq state $Kitchen_Down_Light) ? set $Kitchen OFF : set $Kitchen ON;
   }
   if ($state eq 'AllOff') {
      print_log "Master Bedroom Button 3 pushed OFF - Everything OFF";
      set $Debbie_Lamp OFF; set $Danal_Lamp OFF;
      set $Debbie_Fan  OFF; set $Danal_Fan  OFF;
      $Save{mode} = 'normal'; 
      &speak(mode => 'unmuted', text => "Djeeni is set to $Save{mode} speech mode");

  }

}