
print "Returning Time: $Time_Now\n";

my $data = "<h3>Time: $Time_Now</h3>";
$data .= "Time: <b>$Time_Now</b>\n";
$data .= "Current Temperature: Indoor <b>$weather{TempIndoor}</b> degrees   Outdoor<b>$weather{TempOutdoor}</b> degrees";
$data .= "<br><IMG border=1 height=5 SRC=\"/graphics/appledot.gif\" width=$weather{TempIndoor}><br>";
$data .= "<br><IMG border=1 height=5 SRC=\"/graphics/appledot.gif\" width=$weather{TempOutdoor}><br>";
$data .= "<br><IMG border=1 height=5 SRC=\"/graphics/bluedot.gif\" width=$weather{HumidOutdoor}><br>";

return $data;
