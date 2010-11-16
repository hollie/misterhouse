
# Authority: anyone

return "
<font face=\"Arial\">
<!-- <IMG SRC=\"/mh/graphics/$alarmactive->{state}.gif\">
<font size=-1>
ALARM: <b>$alarmactive->{state}</b><br>
</font> -->
Time: <b>$Time_Now</b>&nbsp;&nbsp;&nbsp;
Temperature: <b>$Weather{TempOutdoor}&deg;</b><br>
Wind: $Weather{Wind}.  Wind Chill is <b>$Weather{WindChill}&deg;</b><br>
Dew Point: <b>$Weather{DewOutdoor}&deg;</b>      Humidity: <b>$Weather{HumidOutdoor}%</b><br>
<!-- Wind: Out of the <b>$WXWindDirVoice</b> at <b>$WXWindSpeed</b> MPH. -->
<br>
</font>
<font face=\"Verdana\" size=-2>
Last Tracked: <b>$GPSSpeakString</b><br>
<!-- Last Weather: <b>$WXSpeakString</b><br> -->
Last Incoming Call: <b>$PhoneName ($PhoneNumber)</b>, on <b>$PhoneTime</b><br>
<br>
</font>
<font face=\"Helv\" size=-1>
<IMG SRC=\"/mh/graphics/lamp/$living_room_light->{state}.gif\">
Living Room: <b>$living_room_light->{state}</b>&nbsp;&nbsp;&nbsp;
<IMG SRC=\"/mh/graphics/lamp/$computer_room_light->{state}.gif\">
Computer Room: <b>$computer_room_light->{state}</b></br>
<IMG SRC=\"/mh/graphics/lamp/$bedroom_light->{state}.gif\">
Bedroom: <b>$bedroom_light->{state}</b>&nbsp;&nbsp;&nbsp;
<IMG SRC=\"/mh/graphics/lamp/$back_porch_light->{state}.gif\">
Back Porch: <b>$back_porch_light->{state}</b><br>
<IMG SRC=\"/mh/graphics/lamp/$kitchen_light->{state}.gif\">
Kitchen: <b>$kitchen_light->{state}</b><br>
<br>
</font>
<font face=\"Helv\" size=-2>
<IMG SRC=\"/mh/graphics/$projector->{state}.gif\">
Projector: <b>$projector->{state}</b>&nbsp;&nbsp;&nbsp;
<IMG SRC=\"/mh/graphics/$air_cond_fan->{state}.gif\">
A/C: <b>$air_cond_fan->{state}</b>&nbsp;&nbsp;&nbsp;
<IMG SRC=\"/mh/graphics/$circ_fan->{state}.gif\">
Circ Fan: <b>$circ_fan->{state}</b><br>
<IMG SRC=\"/mh/graphics/$boombox_bedroom->{state}.gif\">
Boombox: <b>$boombox_bedroom->{state}</b>&nbsp;&nbsp;&nbsp;
<IMG SRC=\"/mh/graphics/$bed_heater->{state}.gif\">
Bed Heater: <b>$bed_heater->{state}</b>&nbsp;&nbsp;&nbsp;
<IMG SRC=\"/mh/graphics/$request_music_stuff->{state}.gif\">
Music: <b>$request_music_stuff->{state}</b><br>
<IMG SRC=\"/mh/graphics/$thermostat_setback->{state}.gif\">
Thermostat Setback: <b>$thermostat_setback->{state}</b>&nbsp;&nbsp;&nbsp;<br>
<br>
<IMG SRC=\"/mh/graphics/$motion_detector_frontdoor->{state}.gif\">
Front Door Motion: <b>$motion_detector_frontdoor->{state}</b>&nbsp;&nbsp;&nbsp;
<IMG SRC=\"/mh/graphics/$motion_detector_backdoor->{state}.gif\">
Back Door Motion: <b>$motion_detector_backdoor->{state}</b><br>
<IMG SRC=\"/mh/graphics/$motion_detector_kitchen->{state}.gif\">
Kitchen Motion: <b>$motion_detector_kitchen->{state}</b>&nbsp;&nbsp;&nbsp;
<IMG SRC=\"/mh/graphics/$low_light_kitchen->{state}.gif\">
Kitchen Low Light: <b>$low_light_kitchen->{state}</b><br>
<IMG SRC=\"/mh/graphics/$motion_detector_garage->{state}.gif\">
Garage Motion: <b>$motion_detector_garage->{state}</b>&nbsp;&nbsp;&nbsp;
<IMG SRC=\"/mh/graphics/$low_light_garage->{state}.gif\">
Garage Low Light: <b>$low_light_garage->{state}</b>
</font>
";
