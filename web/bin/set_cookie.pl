
# Authority: anyone

# Use this one for a radiobutton form to toggle the cookie

my ( $string, $text, $target ) = @ARGV;
$text =~ s/%20/ /g if $text;

# Set the cookie and refresh the page
if ( $string =~ /=/ ) {
    my $cookie;
    if ( my ( $keyword, $state ) = $string =~ /(\S+)=(\S+)/ ) {
        $cookie = "Set-Cookie: $keyword=$state ; ; path=/;\n";
    }

    # Audrey browser is a pain:
    #  - With No Response, it returns a blank screen, rather than leaving the original screen alone.
    #  - Referer, it goes to the main page, since Audrey does not store full Referer path.
    #  - Can not easily pass referer in from the html form .
    #  - So simply give a back button

    if ( $Http{'User-Agent'} eq 'Audrey' ) {
        return <<eof;
HTTP/1.0 200 OK
Content-Type: text/html
$cookie

<a href='javascript:history.go(-1)'><img src='/ia5/images/back.gif' border=0>
eof
    }
    else {
        return <<eof;
HTTP/1.0 301 Moved Temporarily
Location:$Http{Referer}
$cookie

eof
        return <<eof;
HTTP/1.0 204 No Response
Server: MisterHouse
Content-Type: text/html
Cache-control: no-cache
$cookie

eof
    }
}

# Return a form that allows the cookie to be set or unset
else {
    my ( $checked_on, $checked_off );
    $checked_on = $checked_off = '';

    # Allow for unchecked, if no cookie present
    #   print "db s=$string t=$text t=$target c=$Cookies{$string}\n";
    if ( defined $Cookies{$string} ) {
        $checked_on  = 'checked' if $Cookies{$string};
        $checked_off = 'checked' if !$Cookies{$string};
    }
    my $html = "<form action='/bin/set_cookie.pl' ";
    $html .= "target='$target' " if $target;
    $html .= ">\n$text\n"        if $text;
    $html .=
      "   <input type='radio' name='$string' value='0' $checked_off onClick='form.submit()'>Off\n";
    $html .=
      "   <input type='radio' name='$string' value='1' $checked_on  onClick='form.submit()'>On\n";
    $html .= "</form>\n";

    # Checkboxes do not return values when not checked :(
    #   $html = "<input type='checkbox' name='$string' value='1' $checked onClick='form.submit()'>";
    return $html;
}

