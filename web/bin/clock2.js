<SCRIPT LANGUAGE="JavaScript">
<!-- Begin
var serverdiff;
var dayarr='Sun,Mon,Tue,Wed,Thu,Fri,Sat'.split(',');
var montharr='Jan,Feb,Mar,Apr,May,Jun,Jul,Aug,Sep,Oct,Nov,Dec'.split(',');

var ns4 = (document.layers);
var ie4 = (document.all && !document.getElementById);
var ie5 = (document.all && document.getElementById);
var ns6 = (!document.all && document.getElementById);

function clock() {
  serverdiff=0;
  var digital = new Date();
  if (servertimestr) {
    var servertime = new Date(servertimestr);
    serverdiff = digital-servertime;
  }
  dotime();
}
function dotime() {
  var digital = new Date();
  digital = new Date(digital-serverdiff);
  if (!ns4) {
    writeclock(digital);
    setTimeout("dotime()", 1000);
  }
}
function writeclock(dobj) {
  var dayow = dayarr[dobj.getDay()];
  var month = montharr[dobj.getMonth()];
  var day = dobj.getDate();
  var hours = dobj.getHours();
  var minutes = dobj.getMinutes();
  var seconds = dobj.getSeconds();
  var amOrPm = "AM";
  if (hours > 11) amOrPm = "PM";
  if (hours > 12) hours = hours - 12;
  if (hours == 0) hours = 12;
  if (minutes <= 9) minutes = "0" + minutes;
  if (seconds <= 9) seconds = "0" + seconds;
  dispDate = "<font size='3'><b>" + dayow + ",&nbsp;" + month + "&nbsp;" + day + "</b></font>";
  dispTime = "<font size='3'><b>" + hours + ":" + minutes + ":" + seconds + " " + amOrPm + "&nbsp;</b></font>";

  if (ie4) {
    if (dateused) {jdate.innerHTML=dispDate;}
    jclock.innerHTML = dispTime;
  } else if (ie5) {
    if (dateused) {jdate.innerHTML=dispDate;}
    jclock.innerHTML=dispTime;
  } else if (ns6) {
    document.getElementById('jclock').innerHTML=dispTime;
  }


}
//  End -->
</script>
