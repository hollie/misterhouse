# Returns an HTML formated page listing the sub pages within a category

use URI::Escape;

my $output;
my %args;
my ($args_string) = @ARGV;

if ($args_string =~ /=/) {
	if (my ($keyword, $value) = $args_string =~ /(\S+)=([^&]*)/) {
		$value =  uri_unescape($value);
		$args{$keyword} = $value;
	}
}
$output = ia7_utils::print_header("Browse " . $args{'category'});
$output .= ia7_utils::print_category($args{'category'});

return $output;