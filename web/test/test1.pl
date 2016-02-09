
use vars '%weather';    # In case this is not defined

my $data = "<h3>Time: $Time_Now</h3>";

print "Testing http .pl argument passint\n";
my $arg1 = shift;
my $arg2 = shift;
$data .= "Arg1=$arg1<br>\n";
$data .= "Arg2=$arg2<br>\n";

print "Returning Time: $Time_Now\n";

$data .= "Time: <b>$Time_Now</b>\n";
$data .=
  "Current Temperature: Indoor <b>$weather{TempIndoor}</b> degrees   Outdoor<b>$weather{TempOutdoor}</b> degrees";
$data .=
  "<br><IMG border=1 height=5 SRC=\"/graphics/appledot.gif\" width=$weather{TempIndoor}><br>";
$data .=
  "<br><IMG border=1 height=5 SRC=\"/graphics/appledot.gif\" width=$weather{TempOutdoor}><br>";
$data .=
  "<br><IMG border=1 height=5 SRC=\"/graphics/bluedot.gif\" width=$weather{HumidOutdoor}><br>";

return $data;
