#
# Browses, rather than executes, perl code
#
# Call like this:  http://localhost:8080/bin/browse.pl?/mh_url
#

my ($url) = @ARGV;

my ($file) = &http_get_local_file($url);
my $data   = &file_read($file, 0, 1);
$data =~ s/\n/\r/g;

return &html_page('', "<PRE>$data</PRE>");

