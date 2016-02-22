#!/usr/bin/perl

use CGI;
my $query   = new CGI;
my $mode    = $query->param("mode");
my $hourOpt = $query->param("hourOpt");
my $minOpt  = $query->param("minOpt");
my $ampm    = $query->param("ampm");

my $alarmfile = "C:/mh/data/web/data_clock.txt";

my $script_url = "alarm.pl";

print "Content-Type: text/html\n\n";

print "<html><Body bgcolor ='white'><font size='3' face='Arial'><body>";

if ( $mode ne "setdate" ) {

    print qq~
	

<form name=clock action=$script_url method=post>	
<input type=hidden name=mode and value=setdate>

Current Alarm: $alarmfile OR $hourOpt:$minOpt $ampm
<select name=hourOpt onChange="alarmSet()" size=1>
<option value="00">00<option value="01">01<option value="02">02<option value="03">03
<option value="04">04<option value="05">05<option value="06">06<option selected value="07">07
<option value="08">08<option value="09">09<option value="10">10<option value="11">11
<option value="12">12
</option>
</select> 
<select name=minOpt onChange="alarmSet()" size=1>
<option selected value="00">00<option value="05">05<option value="10">10<option value="15">15
<option value="20">20<option value="25">25<option value="30">30<option value="35">35
<option value="40">40<option value="45">45<option value="50">50<option value="55">55
</option>
</select>

<input type=radio name=ampm value="AM" checked>AM
<input type=radio name=ampm value="PM">PM


<input type=submit value=setdate>\n</form>


~;
}
else {

    print "<br><P>SET DATE TO $hourOpt:$minOpt $ampm";

    &file_write( $alarmfile, "$hourOpt:$minOpt $ampm" );

}
print "</body></html>";

1;
