# Shopping List
# Version 1.2
# Matthew Williams
#
# This file should be placed in mh/web/bin.  I link to it through a my_mh page.
#
# file pointed to by shopping_list should be populated like Windows .ini files
# with [categories] in square brackets and items=0
# e.g.
# [Fruits and Vegetables]
# Lettuce=0
# Tomatoes=0
# [Desserts]
# Cake=0
#
# shopping_print will be fed an HTML file suitable for printing
# I suggest using html2ps to convert the html to postscript and then
# piping the output to lp
# e.g.
# shopping_print=/usr/local/bin/html2ps | /usr/bin/lp
#
# shopping_columns determines how many items are displayed per column
# This is useful to tuning the output to match your screen resolution
#
# shopping_email determines which e-mail address will receive the 
# shopping list.  If blank, will default to net_mail_account_address
#
# Revision History:
# 
# Version 1.2: Matthew Williams
# - added section headers to printed output
# - added ability to send list to an e-mail address
#
# Version 1.1: Matthew Williams
# - changed "modify" button to "update list" to prevent confusion
# 
# Version 1.0: Matthew Williams
# - intial release
#

my $file=$config_parms{shopping_list};
$file = "$Pgm_Root/data/shopping_list.txt" unless $file and -e $file;
my $printCommand=$config_parms{shopping_print};
my $tempFile=$file.'.temp';
my $action;
my $sectionHeader;
my $param;
my %param;

my $numColumns=$config_parms{shopping_columns};
$numColumns=4 unless $numColumns;
my $columnWidth=100/$numColumns.'%';

foreach $param (@ARGV) {
	$param =~ /^(.+)=(.+)$/ && do {
		$html.="$1 $2\n";
		$param{$1}=$2;
		}
}

sub shoppingListError {
	my ($message)=@_;
	return qq[
<html>
<head>
<title>Shopping List Error</title>
</head>
<body>
<h3>Internal Error in Shopping List Script</h3>
<h3>$message</h3>
</body>
</html>
];
}

$param{'action'}='list' unless defined($param{'action'});
$param{'action'}='list' if $param{'action'} eq 'cancel';
my $printing=(($param{'action'} eq 'print') or ($param{'action'} eq 'print preview') or ($param{'action'} eq 'e-mail'));


$html=qq[
<html>
<head>
<title>Shopping List</title>
<style type="text/css">
p,a { font-family: helvetica;
    font-size: 10pt;
    margin:0; }
a { text-decoration: none; }
h3 { font-family: helvetica;
    font-size: 12pt;
    margin:0;
    margin-top: 10;}
h4 { font-family: helvetica;
    font-size: 10pt;
    margin:0;
    margin-top: 10;}
</style>
</head>
<body>
<form name="main">
];

if ($param{'action'} eq 'add item') {
	if (($param{'category'} eq 'select') or ($param{'item'} eq '')) {
		$html.=qq[<p>Category: <select name="category">\n<option>select</option>\n];
		open (SHOPLIST,$file) || return shoppingListError("$file: $!");
		while (<SHOPLIST>) {
			chomp;
			s/^\s*(.*?)\s*$/$1/;
			/^\[(.+)\]$/ && do { $html.= qq[<option>$1</option>\n]; next; };
		}
		close (SHOPLIST);
		$html.=qq[</select></p><p>&nbsp;</p>\n];
		$html.=qq[<p>Item: <input type=text name="item" size=50></p>\n];
		$html.=qq[<p>&nbsp;</p><input type=submit name="action" value="add item">\n];
		$html.=qq[<input type=submit name="action" value="cancel"></p>\n];
		$html.=qq[</form>\n];
		$html.='';
		$html.=qq[</body></html>\n];
		return $html;
	}
	open (OLDLIST,$file) || return shoppingListError("$file: $!");
	my $duplicate=0;
	while (<OLDLIST>)
		{
		chomp;
		s/^\s*(.*?)\s*$/$1/;
		/^(.+)=(.+)$/ && do {
			if ($param{'item'} eq $1) {
				$duplicate=1;
				last;
			}
		};
	}
	if ($duplicate) {
		$html.=qq[<h3>$param{'item'} already in list</h3>];
	} else {
		seek (OLDLIST,0,0);
		open (NEWLIST,">$tempFile") || return shoppingListError("$tempFile: $!");
		my $foundCategory=0;
		while (<OLDLIST>) {
			chomp;
			s/^\s*(.*?)\s*$/$1/;
			/^#/ && do { print NEWLIST "$_\n"; next };
			/^$/ && do { print NEWLIST "\n"; next };
			/^\[(.+)\]$/ && do {
				if ($param{'category'} eq $1) {
					$foundCategory=1;
					print NEWLIST "$_\n";
					next;
				}
				if ($foundCategory) {
					print NEWLIST "$param{'item'}=0\n";
					print NEWLIST "$_\n";
					$foundCategory=0;
					next;
				}
				print NEWLIST "$_\n";
			};
			/^(.+)=(.+)$/ && do {
				print NEWLIST "$_\n"; next;
			};
		}
		if ($foundCategory) {
			print NEWLIST "$param{'item'}=0\n";
		}

		close (OLDLIST);
		close (NEWLIST);
		rename $tempFile,$file;
		$html.=qq[<h3>$param{'item'} added to $param{'category'}</h3>];
	}
	$html.=qq[<p>&nbsp;</p>];
	$html.=qq[<p><input type=submit name="action" value="add item">\n];
	$html.=qq[<input type=submit name="action" value="list"></p>\n];
	$html.=qq[</body></html>];
	return $html;
}

if (($param{'action'} eq 'update list') or ($param{'action'} eq 'clear all')) {
	open (OLDLIST,$file) || return shoppingListError("$file: $!");
	open (NEWLIST,">$tempFile") || return shoppingListError("$tempFile: $!");
	while (<OLDLIST>) {
		chomp;
		s/^\s*(.*?)\s*$/$1/;
		/^#/ && do { print NEWLIST "$_\n"; next };
		/^$/ && do { print NEWLIST "\n"; next };
		/^\[(.+)\]$/ && do { print NEWLIST "$_\n"; next; };
		/^(.+)=(.+)$/ && do {
			my $newVal='0';
			if ($param{'action'} eq 'update list') {
				$newVal=$param{$1} eq 'on' ? '1' : '0';
			}
			print NEWLIST "$1=".$newVal."\n"; next;};
		}
	close OLDLIST;
	close NEWLIST;
	rename $tempFile,$file;
	if ($param{'action'} eq 'clear all') {
		$html.="<h3>All Items Cleared</h3>\n";
	}
	$html.= "<h3>List Updated</h3>\n";
}

if ( $printing) {
	$html.=qq[<h2>Shopping List</h2>];
	if ($param{'action'} eq 'print preview') {
		$html.=qq[<h4>Preview Only<h4>];
	}
	if ($param{'action'} eq 'e-mail') {
		$html.=qq[<h4>E-Mail List<h4>\n];
	}
	$html.='<table>';
}

open (SHOPLIST, $file) || return shoppingListError("$file: $!");
my $num=0;
while (<SHOPLIST>)
	{
	chomp;
	s/^\s*(.*?)\s*$/$1/;
	/^#/ && do { next; };
	/^#/ && do { next; };
	/^\[(.+)\]$/ && do {
		if ($printing) {
			$sectionHeader="\n</table><h3>$1</h3><table>\n\n";
		} else {
		$html.=qq[</table><input type=submit name="action" value="update list">\n];
		$html.=qq[<input type=submit name="action" value="print preview">\n];
		$html.=qq[<input type=submit name="action" value="print">\n];
		$html.=qq[<input type=submit name="action" value="e-mail">\n];
		$html.=qq[<input type=submit name="action" value="add item">\n];
		$html.=qq[<input type=submit name="action" value="cancel">\n];
		$html.=qq[<input type=submit name="action" value="clear all"></p>\n];
			$html.=qq[<hr><h3>$1</h3><table width="100%"><colgroup span="$numColumns" width="$columnWidth"><thead>\n];
			$num=0;
			}
		next;
	};
	/^(.+)=(.+)$/ && do {
		my ($item, $value)=($1,$2);
		if ($printing) {
			if ($value==1) {
				$html.=$sectionHeader;
				$sectionHeader='';
				if ($num % $numColumns == 0) {
					$html.='<tr>';
				}
				$num++;
				$html.=qq[<td><input type=checkbox>$item\n];
			}
		} else {
			if ($num % $numColumns == 0) {
				$html.='<tr>';
			}
			$num++;
			my $fieldname=$item;
			$fieldname =~ s/ /%20;/g;
			$html.=qq[<td width="$columnWidth"><input type=checkbox name="$item"]. ($value ? ' checked' : '') . '>';
			$html.=qq[<a onClick="document.main.elements['$item'].checked=!document.main.elements['$item'].checked">$item</a>\n];
		}
		next;
	}
}
close (SHOPLIST);

if (!$printing) {
	$html .= "</table></form>\n";
}

$html.='</body></html>';
if ($param{'action'} eq 'print') {
	open (PRINTER, "| $printCommand") || return shoppingListError("$printCommand: $!");
	print PRINTER $html;
	close (PRINTER);
}

if ($param {'action'} eq 'e-mail') {
  if (&net_connect_check) {
    my $mailtext=$html;
    $mailtext =~ s/<h2.+?<\/h2>//gs;
    $mailtext =~ s/<h3>(.*?)<\/h3>/\*\* $1 \*\*/sg;
    $mailtext =~ s/<title.+?<\/title>//gs;
    $mailtext =~ s/<style.+?<\/style>//gs;
    $mailtext =~ s/<.+?>//g;
    $mailtext =~ s/E-Mail List//g;
    $mailtext =~ s/^\n+//s;
    &net_mail_send(subject => 'shopping list', 
                   text => $mailtext,
                   to => $config_parms{shopping_email}
    );
  } else {
    $html .= "<h2>Internet connection down - e-mail NOT sent</h2>";
  }
}

return &html_page('', $html, '');
