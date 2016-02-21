# Category=APRS

# Roger Bille 2002-01-07

# This script will initiate APRS, open ports and monitor them.

$tnc_output =
  new Socket_Item( undef, undef, '192.168.75.2:14579' );    # Nordic feed
$tnc_output2 = new Socket_Item( undef, undef, '192.168.75.4:14579' )
  ;    # Special feed for AHub Statistics

#$tnc_test	 = new Socket_Item(undef, undef, '192.168.75.2:2023');		# Full feed
$tnc_ahubwx = new Socket_Item( undef, undef, 'ahubwest.net:23' )
  ;    # AHubWX Feed for AHub Statistics

unless ( active $tnc_output or not new_second 15 ) {
    print_log "Starting APRS connection to Nordic Feed";
    start $tnc_output;
    set $tnc_output "user SM5NRK-1 pass 18346 vers Perl 1.0\n\r";
}

unless ( active $tnc_output2 or not new_second 15 ) {
    print_log "Starting APRS connection to AHub Statistics Feed";
    start $tnc_output2;
    set $tnc_output2 "user SM5NRK-1 pass 18346 vers Perl 1.0\n\r";
}

#unless (active $tnc_test or not new_second 15) {
#	print_log "Starting APRS connection to Full feed for testing";
#	start $tnc_test;
#	set $tnc_test "user SM5NRK-1 pass 18346 vers Perl 1.0\n\r";
#}

unless ( active $tnc_ahubwx or not new_minute 5 ) {
    print_log "Starting APRS connection to AHubWX";
    start $tnc_ahubwx;
    $WXTime = "";
    set $tnc_ahubwx "user SM5NRK-1 pass 18346 vers Perl 1.0\n\r";
}

