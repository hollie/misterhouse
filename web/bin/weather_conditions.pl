# $Revision$
# $Date$

# Simple script to return current weather conditions.
# Useful for getting mh stored weather info into other programs.
# Note that the data is returned as plain text, not HTML
#
# by Matthew Williams

my $weather = qq[HTTP/1.0 200 OK
Server: MisterHouse
Content-Type: text/plain
Cache-Control: no-cache

];

if ( $Weather{Summary_Long} ) {
    $weather .= $Weather{Summary_Long};
}
else {
    $weather = 'unknown - enable a weather module';
}

return $weather;
