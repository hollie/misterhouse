#!/usr/bin/perl

use CGI;
my $query   = new CGI;
my $mode    = $query->param("mode");
my $hourOpt = $query->param("hourOpt");
my $minOpt  = $query->param("minOpt");
my $ampm    = $query->param("ampm");

my $alarmfile = "C:/mh/data/web/data_clock.txt";

my $alarmtime = file_read $alarmfile;

my $script_url = "/clock/index.pl";

print "Content-Type: text/html\n\n";

print "<html><Body bgcolor ='white'><font size='3' face='Arial'><body>";

if ( $mode ne "setdate" ) {

    print qq~


<HEAD>
<TITLE>CME House</TITLE>
<meta HTTP-EQUIV='Refresh' CONTENT='3600;URL=index.pl'>

<SCRIPT LANGUAGE='JavaScript'>
<!-- The JavaScript Source!! http://javascript.internet.com -->

<!-- Begin   function extract(h,m,s,type) {

var dn;
c1 = new Image(); c1.src = 'numbers2/c1.gif';
c2 = new Image(); c2.src = 'numbers2/c2.gif';
c3 = new Image(); c3.src = 'numbers2/c3.gif';
c4 = new Image(); c4.src = 'numbers2/c4.gif';
c5 = new Image(); c5.src = 'numbers2/c5.gif';
c6 = new Image(); c6.src = 'numbers2/c6.gif';
c7 = new Image(); c7.src = 'numbers2/c7.gif';
c8 = new Image(); c8.src = 'numbers2/c8.gif';
c9 = new Image(); c9.src = 'numbers2/c9.gif';
c0 = new Image(); c0.src = 'numbers2/c0.gif';
cb = new Image(); cb.src = 'numbers2/cb.gif';
cam = new Image(); cam.src = 'numbers2/cam.gif';
cpm = new Image(); cpm.src = 'numbers2/cpm.gif';
function extract(h,m,s,type) {
if (!document.images) return;
if (h <= 9) {
document.images.a.src = cb.src;
document.images.b.src = eval('c'+h+'.src');
}
else {
document.images.a.src = eval('c'+Math.floor(h/10)+'.src');
document.images.b.src = eval('c'+(h%10)+'.src');
}
if (m <= 9) {
document.images.d.src = c0.src;
document.images.e.src = eval('c'+m+'.src');
}
else {
document.images.d.src = eval('c'+Math.floor(m/10)+'.src');
document.images.e.src = eval('c'+(m%10)+'.src');
}
if (s <= 9) {
document.g.src = c0.src;
document.images.h.src = eval('c'+s+'.src');
}
else {
document.images.g.src = eval('c'+Math.floor(s/10)+'.src');
document.images.h.src = eval('c'+(s%10)+'.src');
}
if (dn == 'AM') document.j.src = cam.src;
else document.images.j.src = cpm.src;
}
function show3() {
if (!document.images)
return;
var Digital = new Date();
var hours = Digital.getHours();
var minutes = Digital.getMinutes();
var seconds = Digital.getSeconds();
dn = 'AM';
if ((hours >= 12) && (minutes >= 1) || (hours >= 13)) {
dn = 'PM';
hours = hours-12;
}
if (hours == 0)
hours = 12;
extract(hours, minutes, seconds, dn);
setTimeout('show3()', 1000);
}
//  End -->
</script>
</HEAD>

<BODY onLoad='show3()' bgcolor='#FFFFFF'>

<center><table width='500' border=0>
<tr><td><a href='/ia5/' target='_parent'><img src='img/logo.gif' alt='Reload Page' height=45 width=120 border='0'></a></td></tr>

<tr><td>
<center>
<img height=80 src='numbers2/cb.gif' width=50 name=a>
<img height=80 src='numbers2/cb.gif' width=50 name=b>
<img height=60 src='numbers2/colon.gif' width=34 name=c>
<img height=80 src='numbers2/cb.gif' width=50 name=d>
<img height=80 src='numbers2/cb.gif' width=50 name=e>
<img height=60 src='numbers2/colon.gif' width=30 name=f>
<img height=45 src='numbers2/cb.gif' width=30 name=g>
<img height=45 src='numbers2/cb.gif' width=30 name=h>
<img height=45 src='numbers2/cam.gif' width=30 name=j>
</center>
</td></tr>
<tr><td><hr></hr></td></tr>
<tr><td>
<center>
<form name=clock action=$script_url method=post>	
<input type=hidden name=mode and value=setdate>

<B><font size='6'><face='Arial'><FONT COLOR="#555555">Current Alarm: $alarmtime<br></font>
<font size='3'><select name=hourOpt onChange="alarmSet()" size=1>
<option value="00">00<option value="01">01<option value="02">02<option value="03">03
<option value="04">04<option value="05">05<option value="06">06<option selected value="07">07
<option value="08">08<option value="09">09<option value="10">10<option value="11">11
<option value="12">12
</option>
</select> 
<select name=minOpt onChange="alarmSet()" size=1>
<option value="00">00<option value="05">05<option value="10">10<option value="15">15
<option value="20">20<option value="25">25<option value="30">30<option value="35">35
<option value="40">40<option selected value="45">45<option value="50">50<option value="55">55
</option>
</select>

<input type=radio name=ampm value="AM" checked>AM
<input type=radio name=ampm value="PM">PM


<input type=submit value=setdate>\n</form>



</td></tr>
<tr><td>
<table width='100%' border=0>
<tr><td width='40%'><SCRIPT SRC='calendar.js'></SCRIPT></td><td>
<center><a href='/'  target='_top'> <img src='./maps/earth.jpg' width='250' height='120' border=0></a>
</td></tr></table>
</td></tr></table>
</BODY>
</HTML>
~;

}
else {

    print "<html><meta HTTP-EQUIV='Refresh' CONTENT='4;URL=index.html'>";
    print "<Body bgcolor ='white'><font size='6' face='Arial'><body>";
    print "<center><br><P>SET DATE TO $hourOpt:$minOpt $ampm";
    print "</body></html>";

    &file_write( $alarmfile, "$hourOpt:$minOpt $ampm" );

}

1;

