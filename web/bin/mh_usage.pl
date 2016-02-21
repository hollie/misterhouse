
# Called from this page:  http://misterhouse.net/usage.html

# Authority: anyone

my ( $city, $state, $name ) = @ARGV;
$city =~ s/city=//;
$state =~ s/state=//;
$name =~ s/name=//;

my $msg;
unless ( $city and $state ) {
    $msg = "City and State/Country not filled in, so no data was sent.";
}
else {
    $msg =
      "Usage data logged:\n\n  city=$city state/country=$state name=$name\n";
    $msg .= "\nThanks!\n";
    display $msg, 0, "$Time_Date: Usage survey";
    logit "$config_parms{data_dir}/mh_usage.txt",
      "city=$city state=$state name=$name";
}

return html_page '', $msg;
