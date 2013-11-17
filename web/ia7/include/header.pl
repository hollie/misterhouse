## Returns a formated html page header

use URI::Escape;

my $output;
my ($args_string) = @ARGV;
my %args;


if ($args_string =~ /=/) {
	if (my ($keyword, $value) = $args_string =~ /(\S+)=([^&]*)/) {
		$value =  uri_unescape($value);
		$args{$keyword} = $value;
	}
}


$output =<<END;

<!DOCTYPE html>
<html><head><title>$args{'title'}</title>
	<meta name="viewport" content="width=device-width, initial-scale=1.0">
	
	<!--Font Awesome-->
	<link href="//netdna.bootstrapcdn.com/font-awesome/4.0.3/css/font-awesome.min.css" rel="stylesheet">
	
	<!--Bootstrap-->
	<!-- Latest compiled and minified CSS -->
	<link rel="stylesheet" href="//netdna.bootstrapcdn.com/bootstrap/3.0.2/css/bootstrap.min.css">
	
	<!-- Optional theme -->
	<link rel="stylesheet" href="//netdna.bootstrapcdn.com/bootstrap/3.0.2/css/bootstrap-theme.min.css">
	
	<!-- Latest compiled and minified JavaScript -->
	<script src="//netdna.bootstrapcdn.com/bootstrap/3.0.2/js/bootstrap.min.js"></script>
	<style type="text/css">
	.btn-category {
	  overflow: hidden;
	  text-overflow: ellipsis;
	  white-space: no-wrap;
	  text-align: left;
	  padding-left: 15px;
	  padding-right: 15px;
	}
	.top-buffer { margin-top:20px; }
	.col-center {text-align: center;}
	</style>
</head>
<body>
END

$output .= "<div class='row top-buffer'>\n";
$output .= "\t<div class='col-sm-12 col-sm-offset-0 col-md-10 col-md-offset-1 col-lg-8 col-lg-offset-2'>\n";
$output .= "\t\t<div class='col-sm-4'>\n";
$output .= "\t\t\t<a href='/ia5/'>\n";
$output .= "\t\t\t<img src='images/mhlogo.gif' alt='Reload Page' alt='Reload' border='0'>\n";
$output .= "\t\t\t</a>\n";
$output .= "\t\t</div>\n";
$output .= "\t</div>\n</div>\n";

return $output;