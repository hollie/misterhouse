## Returns the HTML formated category grid

use ia7_utils;

my %default_cats = %{ia7_utils::get_cats()};

my $row = 1;
my $column = 1;
my $output = '';

foreach my $key (sort(keys %default_cats)){
	my $name = $key;
	$name =~ s/^\d*-//i;
	if ($column == 1){
		$output .= "<div class='row top-buffer'>\n";
		$output .= "\t<div class='col-sm-12 col-sm-offset-0 col-md-10 col-md-offset-1 col-lg-8 col-lg-offset-2'>\n";
	}
	$output .= "\t\t<div class='col-sm-4'>\n";
	$output .= "\t\t\t<a href='$default_cats{$key}{'link'}' class='btn btn-default btn-lg btn-block btn-category' role='button'><i class='fa $default_cats{$key}{'icon'} fa-2x fa-fw'></i> $name</a>\n";
	$output .= "\t\t</div>\n";
	if ($column == 3){
		$output .= "\t</div>\n</div>\n";
		$row++;
	}
	$column++;
	$column %= 3 if $column > 3;
}

return $output;