# Shopping List
# Version 1.6
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
# If shopping_print_type is 'pipe':
# shopping_print will be fed an HTML file suitable for printing
# I suggest using html2ps to convert the html to postscript and then
# piping the output to lp
# e.g.
# shopping_print_type=pipe
# shopping_print=/usr/local/bin/html2ps | /usr/bin/lp
#
# If shopping_print_type is 'file':
# shopping print will be run with any occurance of _FILE_ replaced
# with a filename containing the shopping list in plain text
# e.g.
# shopping_print_type=file
# shopping_print=prfile32 _FILE_
#
# In the above example, prfile32 is assumed to be somewhere on your PATH.
# If not, supply a path to the executable and not just the executable.
#
# FYI, PrintFile http://www.lerup.com/printfile is a good way of
# printing text files from the Windows command line 
#
# shopping_columns determines how many items are displayed per column
# This is useful for tuning the output to match your screen resolution
#
# shopping_email determines which e-mail address will receive the 
# shopping list.  If blank, will default to net_mail_account_address
#
# Revision History:
# 
# Version 1.6: Matthew Williams
# - added checkbox on add items screen to allow a new item to be
#   immediately added to the shopping list
#
# Version 1.5: Matthew Williams
# - changed output of plain text files to be columns
#
# Version 1.4: Matthew Williams
# - added print_file_type to better support Windows environments
#
# Version 1.3: Matthew Williams
# - added "at store" button and related functionality
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
my $printCommandType=$config_parms{shopping_print_type};
$printCommandType='pipe' unless $printCommandType eq 'file';
my $printOutput=$file.'.output';
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
my $atShop=(($param{'action'} eq 'at shop') or ($param{'action'} eq 'remove items'));

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
		$html.=qq[<p>Item: <input type=text name="item" size=50></p><br>];
		$html.=qq[<p>Add to Shopping List Now: <input type=checkbox name="onlistnow"></p><br>];
		$html.=qq[<p><input type=submit name="action" value="add item">\n];
		$html.=qq[<input type=submit name="action" value="cancel"></p>\n];
		$html.=qq[</form>\n];
		$html.='';
		$html.=qq[</body></html>\n];
		return $html;
	}
	open (OLDLIST,$file) || return shoppingListError("$file: $!");
	my $duplicate=0;
	my $newvalue;
	if (defined ($param{'onlistnow'})) {
	  $newvalue=1;
	} else {
		$newvalue=0;
  }
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
					print NEWLIST "$param{'item'}=$newvalue\n";
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

if (($param{'action'} eq 'update list') or ($param{'action'} eq 'clear all') or ($param{'action'} eq 'remove items')) {
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
			if ($param{'action'} eq 'remove items') {
				$newVal=$param{$1} eq 'on' ? '0' : $2;
			}
			print NEWLIST "$1=".$newVal."\n"; next;};
		}
	close OLDLIST;
	close NEWLIST;
	rename $tempFile,$file;
	if ($param{'action'} eq 'clear all') {
		$html.="<h3>All Items Cleared</h3>\n";
	}
	if (not $atShop) {
		$html.= "<h3>List Updated</h3>\n";
	}
}

if ($printing) {
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

my $showAll=1;

$showAll=0 if $atShop==1;

if ($atShop) {
	$html.=qq[<h2>Shopping List At Shop</h2>];
	$html.=qq[<input type=submit name="action" value="cancel">];
}

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
			if ($atShop) {
				$sectionHeader=qq[</table><hr><h3>$1</h3><input type=submit name="action" value="remove items">\n];
				$sectionHeader.=qq[<input type=submit name="action" value="cancel"><table></p>\n];
			} else {
				$html.=qq[</table><input type=submit name="action" value="update list">\n];
				$html.=qq[<input type=submit name="action" value="print preview">\n];
				$html.=qq[<input type=submit name="action" value="print">\n];
				$html.=qq[<input type=submit name="action" value="e-mail">\n];
				$html.=qq[<input type=submit name="action" value="add item">\n];
				$html.=qq[<input type=submit name="action" value="at shop">\n];
				$html.=qq[<input type=submit name="action" value="cancel">\n];
				$html.=qq[<input type=submit name="action" value="clear all"></p>\n];
			$html.=qq[<hr><h3>$1</h3><table width="100%"><colgroup span="$numColumns" width="$columnWidth"><thead>\n];
			}
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
			my $checked;
			if ($atShop) {
				if ($value==0) {
					next;
				}
				$html.=$sectionHeader;
				$sectionHeader='';
				$checked=0;
			} else {
				$checked=$value;
			}
	
			if ($num % $numColumns == 0) {
				$html.='<tr>';
			}
			$num++;
			my $fieldname=$item;
			$fieldname =~ s/ /%20;/g;

			$html.=qq[<td width="$columnWidth"><input type=checkbox name="$item"]. ($checked ? ' checked' : '') . '>';
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
my $plainText=$html;

# Strip away HTML stuff from mailtext
$plainText =~ s/<h2.+?<\/h2>//gs;
$plainText =~ s/<h3>(.*?)<\/h3>/\n\*\* $1 \*\*/sg;
$plainText =~ s/<title.+?<\/title>//gs;
$plainText =~ s/<style.+?<\/style>//gs;
$plainText =~ s/<tr.*?>/\n/gs;
$plainText =~ s/(<td.+?)\n/$1   /gs;
$plainText =~ s/<.+?>//g;
$plainText =~ s/E-Mail List//g;
$plainText =~ s/^\n+//s;
$plainText =~ s/\n{3,}/\n\n/gs;
$plainText .= "\n";

if ($param{'action'} eq 'print') {
	if ($printCommandType eq 'pipe') {
		open (PRINTER, "| $printCommand") || return shoppingListError("$printCommand: $!");
		print PRINTER $html;
		close (PRINTER);
	} elsif ($printCommandType eq 'file') {
		open (PRINTER, "> $printOutput") || return shoppingListError("$printOutput: $!");
		print PRINTER $plainText;
		close PRINTER;
		$printCommand =~ s/_FILE_/$printOutput/g;
		system ($printCommand);
	}
}

if ($param {'action'} eq 'e-mail') {
  if (&net_connect_check) {
    my $mailtext=$html;

    &net_mail_send(subject => 'shopping list', 
                   text => $plainText,
                   to => $config_parms{shopping_email}
    );
  } else {
    $html .= "<h2>Internet connection down - e-mail NOT sent</h2>";
  }
}

return &html_page('', $html, '');
