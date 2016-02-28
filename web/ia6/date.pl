my $html;

my @months = (
    'January', 'February', 'March',     'April',   'May',      'June',
    'July',    'August',   'September', 'October', 'November', 'December'
);
my @days = (
    'Sunday',   'Monday', 'Tuesday', 'Wednesday',
    'Thursday', 'Friday', 'Saturday'
);
my ( $sec, $min, $hour, $day, $month, $year, $day2 ) =
  ( localtime(time) )[ 0, 1, 2, 3, 4, 5, 6 ];

#if ($day < 10) { $day = "0$day"; }
$year += "1900";

$html = "<font size='3'>";
$html .= "<b>$days[$day2], $months[$month] $day, $year</b>";
$html .= "</font>";
return $html;
