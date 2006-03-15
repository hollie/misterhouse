
# A simple page counter.
# Called with:  <!--#include file=/bin/counter?page_name"-->
# For an example, see web/ia5/menu.shtml

# Authority: anyone


my $page = shift;

$page = 'default' unless $page;

return "HTTP/1.0 200 OK\n\n" . 'Page Views: ' . ++$Save{"web_count_$page"};


