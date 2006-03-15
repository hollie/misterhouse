
# This web page example is from Brian Klier.  It is called from statuspannel.shtml

return "
<IMG SRC=\"/mh/graphics/$alarmactive->{state}.gif\">
<font size=-1>
ALARM: <b>$alarmactive->{state}</b><br>
<!--<IMG SRC=\"/mh/graphics/$needatt->{state}.gif\">
NEED OF ATTENTION: <b>$needatt->{state}</b><br>-->
</font>
Time: <b>$Time_Now</b>&nbsp;&nbsp;&nbsp;
Temperature: <b>$CurrentTemp&deg;</b>
<IMG border=1 height=7 SRC=\"/mh/graphics/appledot.gif\" width=$CurrentTemp><br>
Wind: <b>$WXWindDirVoice</b> at <b>$WXWindSpeed</b> MPH.<br>
<br>
<font size=-1>
Last Tracked: <b>$GPSSpeakString</b><br>
Last Weather: <b>$WXSpeakString</b><br>
Last Incoming Call: <b>$PhoneName ($PhoneNumber)</b>, at <b>$PhoneTime</b> on <b>$PhoneDate</b><br>
<br>
<IMG SRC=\"/mh/graphics/lamp/$living_room->{state}.gif\">
Living Room: <b>$living_room->{state}</b>&nbsp;&nbsp;&nbsp;
<IMG SRC=\"/mh/graphics/lamp/$front_entryway->{state}.gif\">
Front Entryway: <b>$front_entryway->{state}</b></br>
<IMG SRC=\"/mh/graphics/lamp/$bedroom_lamp->{state}.gif\">
Bedroom: <b>$bedroom_lamp->{state}</b>&nbsp;&nbsp;&nbsp;
<IMG SRC=\"/mh/graphics/lamp/$back_porch_light->{state}.gif\">
Back Porch: <b>$back_porch_light->{state}</b><br>
<IMG SRC=\"/mh/graphics/lamp/$kitchen_light->{state}.gif\">
Kitchen: <b>$kitchen_light->{state}</b><br>
<br>
<font size=-1>
<IMG SRC=\"/mh/graphics/$projector->{state}.gif\">
Projector: <b>$projector->{state}</b>&nbsp;&nbsp;&nbsp;
<IMG SRC=\"/mh/graphics/$air_cond_fan->{state}.gif\">
Air Conditioner: <b>$air_cond_fan->{state}</b>&nbsp;&nbsp;&nbsp;
<IMG SRC=\"/mh/graphics/$circ_fan->{state}.gif\">
Floor Fan: <b>$circ_fan->{state}</b><br>
<IMG SRC=\"/mh/graphics/$boombox_bedroom->{state}.gif\">
Boombox: <b>$boombox_bedroom->{state}</b>&nbsp;&nbsp;&nbsp;
<IMG SRC=\"/mh/graphics/$bed_heater->{state}.gif\">
Bed Heater: <b>$bed_heater->{state}</b>&nbsp;&nbsp;&nbsp;
<IMG SRC=\"/mh/graphics/$request_music_stuff->{state}.gif\">
Music: <b>$request_music_stuff->{state}</b><br>
<br>
<IMG SRC=\"/mh/graphics/$motion_detector_frontdoor->{state}.gif\">
Entryway Motion: <b>$motion_detector_frontdoor->{state}</b>&nbsp;&nbsp;&nbsp;
<IMG SRC=\"/mh/graphics/$motion_detector_backdoor->{state}.gif\">
Back Door Motion: <b>$motion_detector_backdoor->{state}</b><br>
<IMG SRC=\"/mh/graphics/$motion_detector_kitchen->{state}.gif\">
Kitchen Motion: <b>$motion_detector_kitchen->{state}</b>&nbsp;&nbsp;&nbsp;
<IMG SRC=\"/mh/graphics/$low_light_kitchen->{state}.gif\">
Kitchen Low Light: <b>$low_light_kitchen->{state}</b><br>
<IMG SRC=\"/mh/graphics/$motion_detector_living_room->{state}.gif\">
Living Room Motion: <b>$motion_detector_living_room->{state}</b>&nbsp;&nbsp;&nbsp;
<IMG SRC=\"/mh/graphics/$low_light_living_room->{state}.gif\">
Living Room Low Light: <b>$low_light_living_room->{state}</b><br>
<IMG SRC=\"/mh/graphics/$motion_detector_garage->{state}.gif\">
Garage Motion: <b>$motion_detector_garage->{state}</b>&nbsp;&nbsp;&nbsp;
<IMG SRC=\"/mh/graphics/$low_light_garage->{state}.gif\">
Garage Low Light: <b>$low_light_garage->{state}</b>
</font>
";

