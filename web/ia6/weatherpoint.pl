# Category=Weather
# By Douglas J. Nakakihara, doug@dougworld.com
#
# Requires WeatherURL param in mh.ini set to your particular www.weatherpoint.com page.
# Just go there and enter your city or zipcode to get URL.
#

my $text;

my $f_weatherpoint_page = "$config_parms{data_dir}/web/weatherpoint.txt";
my $f_weatherpoint_html = "$config_parms{data_dir}/web/weatherpoint.html";
$p_weatherpoint_page = new Process_Item(
    "get_url \"$config_parms{weatherpointURL}\" \"$f_weatherpoint_html\"");
$v_get_weatherpoint = new Voice_Cmd('Get weather point');

if ( $Startup or $Reload ) {    # Used for testing

    #if ((time_cron '17 0,4,5,6,8,12,16,20 * * *' or $state = said $v_get_weatherpoint) and &net_connect_check) {

    print_log "Retrieving weatherpoint weather...";

    # Use start instead of run so we can detect when it is done
    start $p_weatherpoint_page;

}

if ( done_now $p_weatherpoint_page) {
    $text = file_read $f_weatherpoint_html;

    # Find beginning of table and replace table tag
    $text =~
      s/.+<b>5-Day Forecast.+?width=468>(.+)/<table border=0 cellpadding=0 cellspacing=0 width=500>$1/s;

    # Find last TH tag and add all needed closing tags
    $text =~ s/(.+)<\/th>.+/$1<\/th><\/tr><\/table>/s;

    # Add in full path for images
    $text =~ s/\/fore_pics/http:\/\/www.weatherpoint.com\/fore_pics/g;

    # Change all font sizes to size 1
    $text =~ s/size=./size=1/g;

    # Drop unneeded type faces
    $text =~ s/face="arial narrow,helvetica"//g;

    file_write( $f_weatherpoint_page, $text );
    print $text;
}
