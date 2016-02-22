# my $wxcondx = file_read "$Pgm_Root/data/web/weather_conditions.txt";
#<font face=arial size=5 color=lime>
#<b>Time: $Time_Now&nbsp;&nbsp;&nbsp; $Date_Now</b><br>
#<font face=arial size=4 color=lime>
#</font>

my $tr_office_motion  = seconds_remaining_now $timer_office_motion;
my $tr_lr_motion      = seconds_remaining_now $timer_lr_motion;
my $tr_jack_motion    = seconds_remaining_now $timer_jack_motion;
my $tr_ryan_motion    = seconds_remaining_now $timer_ryan_motion;
my $tr_kitchen_motion = seconds_remaining_now $timer_kitchen_motion;
my $tr_garage_motion  = seconds_remaining_now $timer_garage_motion;
my $tr_outside_motion = seconds_remaining_now $timer_outside_motion;

my $tsl_office  = time_diff( $last_motion_office,  $Time, 'minute', 'numeric' );
my $tsl_kitchen = time_diff( $last_motion_kitchen, $Time, 'minute', 'numeric' );

my $office     = sprintf( "%4d f", $Save{office_temp} );
my $livingroom = sprintf( "%4d f", $Save{livingroom_temp} );

return "
<br><br>
<FORM>
<table width=100% cellpadding=2 cellspacing=2 columns=4>

<tr>
<td bgcolor=silver align=left colspan=6><font face=arial size=2 color=black><b>LIGHTS</b></font></td>
</tr>

<tr>
<td bgcolor=gray width=25 align=center><IMG SRC=\"/graphics/$office_lamp->{state}.gif\"></td>
<td bgcolor=gray><font face=arial size=2 color=black><b>Office Lamp: $office_lamp->{state}</b>&nbsp;&nbsp;&nbsp;</font>
</td>

<td bgcolor=gray width=25 align=center><IMG SRC=\"/graphics/$office_stereo->{state}.gif\"></td>
<td bgcolor=gray><font face=arial size=2 color=black><b>Office Stereo: $office_stereo->{state}</b>&nbsp;&nbsp;&nbsp;</font></td>
</tr>

<tr>
<td bgcolor=gray width=25 align=center><IMG SRC=\"/graphics/$br_lamp_ron->{state}.gif\"</td>
<td bgcolor=gray><font face=arial size=2 color=black><b>Ron's Lamp: $br_lamp_ron->{state}</b>&nbsp;&nbsp;&nbsp;</font></td>

<td bgcolor=gray width=25 align=center><IMG SRC=\"/graphics/$br_lamp_susan->{state}.gif\"</td>
<td bgcolor=gray><font face=arial size=2 color=black><b>Susan's Lamp: $br_lamp_susan->{state}</b>&nbsp;&nbsp;&nbsp;</font></td>
</tr>

<tr>
<td bgcolor=gray width=25 align=center><IMG SRC=\"/graphics/$ryans_lamp->{state}.gif\"</td>
<td bgcolor=gray><font face=arial size=2 color=black><b>Ryan's Lamp: $ryans_lamp->{state}</b>&nbsp;&nbsp;&nbsp;</font></td>

<td bgcolor=gray width=25 align=center><IMG SRC=\"/graphics/$jacks_lamp->{state}.gif\"</td>
<td bgcolor=gray><font face=arial size=2 color=black><b>Jack's Lamp: $jacks_lamp->{state}</b>&nbsp;&nbsp;&nbsp;</font></td>
</tr>

<tr>
<td bgcolor=gray width=25 align=center><IMG SRC=\"/graphics/$lr_lamp_right->{state}.gif\"</td>
<td bgcolor=gray><font face=arial size=2 color=black><b>Living Room Right: $lr_lamp_right->{state}</b>&nbsp;&nbsp;&nbsp;</font></td>

<td bgcolor=gray width=25 align=center><IMG SRC=\"/graphics/$lr_lamp_left->{state}.gif\"</td>
<td bgcolor=gray><font face=arial size=2 color=black><b>Living Room Left: $lr_lamp_left->{state}</b>&nbsp;&nbsp;&nbsp;</font></td>
</tr>

<tr>
<td bgcolor=gray width=25 align=center><IMG SRC=\"/graphics/$lr_lamp_front->{state}.gif\"</td>
<td bgcolor=gray><font face=arial size=2 color=black><b>Living Room Front: $lr_lamp_front->{state}</b>&nbsp;&nbsp;&nbsp;</font></td>

<td bgcolor=gray width=25 align=center><IMG SRC=\"/graphics/$kitchen_lamp->{state}.gif\"</td>
<td bgcolor=gray><font face=arial size=2 color=black><b>Kitchen Lamp: $kitchen_lamp->{state}</b>&nbsp;&nbsp;&nbsp;</font></td>
</tr>

<tr>
<td bgcolor=gray width=25 align=center><IMG SRC=\"/graphics/$floodlights->{state}.gif\"</td>
<td bgcolor=gray><font face=arial size=2 color=black><b>Outside Floodlights: $floodlights->{state}</b>&nbsp;&nbsp;&nbsp;</font></td>

<td bgcolor=gray width=25 align=center><IMG SRC=\"/graphics/$office_fan->{state}.gif\"></td>
<td bgcolor=gray><font face=arial size=2 color=black><b>Office Fan:  $office_fan->{state}</b>&nbsp;&nbsp;&nbsp;</font></td>
</tr>

</table>
<br>
<table width=100% cellpadding=2 cellspacing=2 columns=6>


<tr>
<td bgcolor=silver align=left colspan=6><font face=arial size=2 color=black><b>MOTION DETECTORS</b></font></td>
</tr>

<tr>
<td bgcolor=gray width=25 align=center><IMG SRC=\"/graphics/$motion_ryan->{state}.gif\"</td>
<td bgcolor=gray><font face=arial size=2 color=black><b>Ryan's Room </b>&nbsp;&nbsp;&nbsp;</font></td>

<td bgcolor=gray width=25 align=center><IMG SRC=\"/graphics/$motion_jack->{state}.gif\"</td>
<td bgcolor=gray><font face=arial size=2 color=black><b>Jack's Room </b>&nbsp;&nbsp;&nbsp;</font></td>

<td bgcolor=gray width=25 align=center><IMG SRC=\"/graphics/$motion_office->{state}.gif\"></td>
<td bgcolor=gray><font face=arial size=2 color=black><b>Office </b>&nbsp;&nbsp;&nbsp;</font></td>
</tr>


<tr>
<td bgcolor=gray width=25 align=center><IMG SRC=\"/graphics/$motion_lr->{state}.gif\"</td>
<td bgcolor=gray><font face=arial size=2 color=black><b>Living Room </b>&nbsp;&nbsp;&nbsp;</font></td>

<td bgcolor=gray width=25 align=center><b><IMG SRC=\"/graphics/$motion_kitchen->{state}.gif\"></b></td>
<td bgcolor=gray><font face=arial size=2 color=black><b>Kitchen </b>&nbsp;&nbsp;&nbsp;</font></td>

<td bgcolor=gray width=25 align=center><IMG SRC=\"/graphics/$motion_front_yard->{state}.gif\"</td>
<td bgcolor=gray><font face=arial size=2 color=black><b>Front Yard </b>&nbsp;&nbsp;&nbsp;</font></td>
</tr>

<tr>
<td bgcolor=gray width=25 align=center><IMG SRC=\"/graphics/$motion_garage->{state}.gif\"</td>
<td bgcolor=gray><font face=arial size=2 color=black><b>Garage </b>&nbsp;&nbsp;&nbsp;</font></td>

<td bgcolor=gray width=25 align=center></td>
<td bgcolor=gray><font face=arial size=2 color=black><b></b>&nbsp;&nbsp;&nbsp;</font></td>

<td bgcolor=gray width=25 align=center></td>
<td bgcolor=gray><font face=arial size=2 color=black><b></b>&nbsp;&nbsp;&nbsp;</font></td>
</tr>

</table>

</form>

";

# $Tk_objects{label_uptime_mh} &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;$Tk_objects{label_uptime_cpu}  &nbsp;&nbsp;&nbsp;&nbsp;&nbsp; $Tk_objects{label_cpu_used}
