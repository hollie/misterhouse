# $Revision$
# $Date$

# Simple script to return current weather conditions.
# Useful for getting mh stored weather info into other programs.
# Note that the data is returned as plain text, not HTML
#
# by Matthew Williams

my $weather;

if ( $Weather{Summary_Long} ) {
    $weather .= $Weather{Summary_Long};
}
else {
    $weather = 'unknown - enable a weather module';
}

    my $output = "HTTP/1.1 200 OK\r\n";
    $output .= "Server: MisterHouse\r\n";
    $output .= "Content-type: text/plain\r\n";
    $output .= "Connection: close\r\n" if &http_close_socket;
    $output .= "Content-Length: " . ( length $weather ) . "\r\n";
    $output .= "Cache-Control: no-cache\r\n";
    $output .= "Date: " . time2str(time) . "\r\n";
    $output .= "\r\n";
    $output .= $weather;

return $output;
