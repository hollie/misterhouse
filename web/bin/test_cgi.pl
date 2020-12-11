#!/usr/bin/perl 

print "Content-Type: text/html\n\n";

print "<html><body>\n";
print "<h2>Hello World from mh test_cgi.pl</h2>";

print "<p/><h4>POST Data:</h4>\n<p>";
while ( my ( $key, $value ) = each %HTTP_ARGV ) {
    print "$key=$value<br>\n";
}
print "</p>\n";

print "<p/><h4>Query Data:</h4>\n<p>";
while ( my ( $key, $value ) = each %Http ) {
    print "$key=$value<br>\n";
}
print "</p>\n";

#print "<p/><h4>HTTP Content:</h4>\n<p>$HTTP_CONTENT</p>\n\n";

open E, "> /tmp/e";

#print E $HTTP_CONTENT;
close E;

print "<h4>stdin\n<pre>\n";
while (<STDIN>) {
    print "$_\n";
}

print "</pre>\n";

print "</body></html>\n";
