# Category=Weather

#@ Teset getting weather data using Geo??WeatherNOAA

use Geo::WeatherNOAA;
$test_weather =
  new Voice_Cmd("Get weather test for [New York,Portland,Baltimore]");
$test_weather->set_info('Test finding weather for a few different cities');

if ( my $city = said $test_weather) {
    print_log "Getting weather for $city\n";
    $state = "NY" if $city eq 'New York';
    $state = "OR" if $city eq 'Portland';
    $state = "MD" if $city eq 'Baltimore';
    display print_current( $city, $state, undef, undef, undef, 1 );
}
