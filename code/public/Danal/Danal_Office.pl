# Category = Danal_Office

##################################################################
#  Danal's Office items & actions                                #
#                                                                #
#  By: Danal Estes, N5SVV                                        #
#  E-Mail: danal@earthling.net                                   #
#                                                                #
##################################################################

$Danal_Can_Light = new X10_Item('N1');

$Danal_Office = new Group($Danal_Can_Light);

#$Danal_office -> add($Danal_???);

$v_Danal_On  = new Voice_Cmd('Danals Office Lights On');
$v_Danal_Off = new Voice_Cmd('Danals Office Lights Off');

if ( said $v_Danal_On) {
    set $Danal_Can_Light ON;
}
if ( said $v_Danal_Off) {
    set $Danal_Can_Light OFF;
}

#if ($New_Minute) {
#   if (time_now("$Time_Sunset - 0:30")) {
#      print_log "Sunset at $Time_Sunset; now dusk, set up Danal's Office for evening";
#      set $Danal_Can_Light ON;
#   }
#} # End of New Minute code

