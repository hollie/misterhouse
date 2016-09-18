
# Category=Web_Functions

#@ Misc web functions

# This is called by web/bin/status_line.pl
sub web_status_line {
    my $html;
    $html .= qq[&nbsp;<img src='/ia5/images/car.gif' border=0>];
    $html .=
      qq[&nbsp;$Save{'aprs_whereis2_the car'}/$Save{'aprs_whereis2_the van'}\n];
    return $html;
}

