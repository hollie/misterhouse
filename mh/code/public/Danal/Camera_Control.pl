# Category = Camera

##################################################################
#  X10 Cameras                                                   #
#                                                                #
#  By: Danal Estes, N5SVV                                        #
#  E-Mail: danal@earthling.net                                   #
#                                                                #
##################################################################

$Cam_Front      = new X10_Item('F1');
$Cam_Back       = new X10_Item('F2');
$Cam_Drive      = new X10_Item('F3');

#$Danal_Office  = new Group($Danal_Can_Light);
#$Danal_office -> add($Danal_???);

$v_Cam_Front = new Voice_Cmd('Camera Front');
if (said $v_Cam_Front) {
  set $Cam_Front ON;
}

$v_Cam_Back = new Voice_Cmd('Camera Back');
if (said $v_Cam_Back) {
  set $Cam_Back ON;
}

$v_Cam_Drive = new Voice_Cmd('Camera Drive');
if (said $v_Cam_Drive) {
  set $Cam_Drive ON;
}




#if ($New_Minute) {
#   if (time_now("$Time_Sunset - 0:30")) {
#      print_log "Sunset at $Time_Sunset; now dusk, set up Danal's Office for evening";
#      set $Danal_Can_Light ON; 
#   }
#} # End of New Minute code



