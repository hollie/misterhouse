#
# Browses, rather than executes, perl code
#
# Call like this:  http://localhost:8080/bin/browse.pl?/mh_url
#

my ($url) = @ARGV;

my ($file) = &http_get_local_file($url);
my $data   = &file_read($file);

# Why do we need this?  Seems like we might want \r+, 
# but that does not get rid of the extra lines?
$data =~ s/\n+//g;

return &html_page('', "<PRE>$data</PRE>");

