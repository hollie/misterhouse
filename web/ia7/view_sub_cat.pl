# Returns an HTML formated page listing the sub pages within a category

use ia7_utils;
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

my %sub_cats = %{ia7_utils::get_sub_cats()};

$output .= ia7_utils::print_header('MrHouse Home');

my $column = 1;

foreach my $key (sort(keys %sub_cats)){
	if ($sub_cats{$key}{'category'} ne $args{'category'}){
		next;
	}
	my $name = $key;
	$name =~ s/^\d*-//i;
	if ($column == 1){
		$output .= "<div class='row top-buffer'>\n";
		$output .= "\t<div class='col-sm-12 col-sm-offset-0 col-md-10 col-md-offset-1 col-lg-8 col-lg-offset-2'>\n";
	}
	$output .= "\t\t<div class='col-sm-4'>\n";
	$output .= "\t\t\t<a href='$sub_cats{$key}{'link'}' class='btn btn-default btn-lg btn-block btn-category' role='button'><i class='fa $sub_cats{$key}{'icon'} fa-2x fa-fw'></i> $name</a>\n";
	$output .= "\t\t</div>\n";
	if ($column == 3){
		$output .= "\t</div>\n</div>\n";
	}
	$column++;
	$column %= 3 if $column > 3;
}

return $output;