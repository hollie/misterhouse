<SCRIPT LANGUAGE="JavaScript">
<!-- Begin
function clock() {
if (!document.layers && !document.all) return;
var digital = new Date();
var hours = digital.getHours();
var minutes = digital.getMinutes();
var seconds = digital.getSeconds();
var amOrPm = "AM";
if (hours > 11) amOrPm = "PM";
if (hours > 12) hours = hours - 12;
if (hours == 0) hours = 12;
if (minutes <= 9) minutes = "0" + minutes;
if (seconds <= 9) seconds = "0" + seconds;
dispTime = "<font size='2'><b>&nbsp" + hours + ":" + minutes + ":" + seconds + " " + amOrPm + "&nbsp</b></font>";
if (document.layers) {
document.layers.jclock.document.write(dispTime);
document.layers.jclock.document.close();
}
else
if (document.all)
jclock.innerHTML = dispTime;
setTimeout("clock()", 1000);
}
//  End -->
</script>
