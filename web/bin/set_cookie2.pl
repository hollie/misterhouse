
# Authority: anyone

# Use this one for .gif based buttons to toggle the cookie

my ($string) = @ARGV;

# Set the cookie and refresh the page
if ( $string =~ /=/ ) {
    my $cookie;
    if ( my ( $keyword, $state ) = $string =~ /(\S+)=(\S*)/ ) {

        #       print "Debug c=$keyword s=$state\n";
        $cookie = "Set-Cookie: $keyword=$state ; ; path=/;\r\n";
    }

    # Audrey browser is a pain:
    #  - With No Response, it returns a blank screen, rather than leaving the original screen alone.
    #  - Referer, it goes to the main page, since Audrey does not store full Referer path.
    #  - Can not easily pass referer in from the html form .
    #  - So simply give a back button


    if ( $Http{'User-Agent'} eq 'Audrey' ) {
    my $body = <<eof;
<a href='javascript:history.go(-1)'><img src='/ia5/images/back.gif' border=0>
eof
    my $output = "HTTP/1.1 200 OK\r\n";
    $output .= "Server: MisterHouse\r\n";
    $output .= "Content-type: text/html\r\n";
    $output .= "Connection: close\r\n" if &http_close_socket;
    $output .= "Content-Length: " . ( length $body ) . "\r\n";
    $output .= "Date: " . time2str(time) . "\r\n";
    $output .= $cookie;
    $output .= "\r\n";
    $output .= $body;
    return $output;
    }
    else {
        return <<eof;
HTTP/1.1 301 Moved Temporarily
Location:$Http{Referer}
Connection: close
$cookie

eof
        return <<eof;
HTTP/1.1 204 No Response
Server: MisterHouse
Content-Type: text/html
Connection: close
Cache-control: no-cache
$cookie

eof
    }
}

# Return a href with image to be toggled on, off, or unset
else {
    my ( $checked_on, $checked_off );

    # Allow for unchecked, if no cookie present

    # Toggle state
    my $state1 = ( $Cookies{$string} ) ? 'on' : 'off';
    my $state2 = ( $Cookies{$string} ) ? 0    : 1;
    $state1 = 'unset' unless defined $Cookies{$string};
    $state2 = '' if defined $Cookies{$string} and $Cookies{$string} eq '0';

    my $image = "/graphics/${string}_${state1}.gif";
    return "<a href='/bin/set_cookie2.pl?$string=$state2'><img src='$image' alt='$string $state1' border=0></a>\n";
}

