# Shopping List
# Version 1.68
# Matthew Williams
#
# $Revision$
# $Date$
#
# This file should be placed in mh/web/bin.  I link to it through a my_mh page.
#
# If you want to be tricky, then this same script can be used to manage multiple lists.
# Just call the script this way: shopping_list.pl?listName=foobar
#
# Now, it will use the file pointer to by the mh param foobar_list
# The shopping_print... parameters are still used, regardless of which list is being processed.
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
# Version 1.68: Matthew Williams
# - added filter to list name to restrict file location to data directory
#
# Version 1.67: Matthew Williams
# - added html_page to all return statements so that correct HTTP headers
#   would be added.  (Safari in particular was sensitive to lack of headers).
#   Thanks to Howard Plato for discovering and helping to work out this bug.
#
# Version 1.66: Matthew Williams
# - added call to insert_keyboard within add_item (virtual_keyboard.pl
#   needs to be activated).
# - initial CSS margin-top values now specify pixels to comply with standard
#
# Version 1.65: Matthew Williams
# - now using html_page to send complete http headers
# - removed initial CR from html
#
# Version 1.64: Matthew Williams
# - added ability to manage multiple lists
#
# Version 1.63: Matthew Williams
# - changed form action from get to post
#
# Version 1.62: Matthew Williams
# - fixed some bad html that was breaking html2ps
# - pages now validate as strict HTML 4.01 (validator.w3.org)
# - note that this version was not publicly released
#
# Version 1.61: Matthew Williams
# - fixed bug in 1.6 functionality that prevented it from working when last
#   category was being chosen for new item
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

my $shoppinglistdebug = 0;
my %param;

foreach my $param (@ARGV) {
    $param =~ /^(.+)=(.+)$/ && do {
        $html .= "<p>$1 ** $2</p>\n" if $shoppinglistdebug;
        $param{$1} = $2;
      }
}

my $listName = $param{listName};
$listName =~ s![:/\\\.]!!g;    # don't allow illegal characters in filename
$listName = 'shopping' unless $listName;

my $prettyName = ucfirst($listName) . ' List';

my $file = $config_parms{"${listName}_list"};
$file = "$Pgm_Root/data/${listName}_list.txt" unless $file and -e $file;
my $printCommand     = $config_parms{shopping_print};
my $printCommandType = $config_parms{shopping_print_type};
$printCommandType = 'pipe' unless $printCommandType eq 'file';
my $printOutput = $file . '.output';
my $tempFile    = $file . '.temp';
my $action;
my $sectionHeader;

my $numColumns = $config_parms{shopping_columns};
$numColumns = 4 unless $numColumns;
my $columnWidth = 100 / $numColumns . '%';

my $html = qq[<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01//EN"
"http://www.w3.org/TR/html4/strict.dtd">
<html>
<head>
<title>$prettyName</title>
<style type="text/css">
p,a { font-family: helvetica;
    font-size: 10pt;
    margin:0; }
a { text-decoration: none; }
h3 { font-family: helvetica;
    font-size: 12pt;
    margin:0;
    margin-top: 10px;}
h4 { font-family: helvetica;
    font-size: 10pt;
    margin:0;
    margin-top: 10px;}
</style>
];
$html .= &insert_keyboard_style;
$html .= qq[
</head>
<body>
<form name="main" id="main" action="/bin/shopping_list.pl" method="post">
<input type="hidden" name="listName" value="$listName">
];

if ($shoppinglistdebug) {
    foreach my $key ( keys(%param) ) {
        $html .= "<p>$key ** $param{$key}</p>\n";
    }
}

sub shoppingListError {
    my ($message) = @_;
    return html_page(
        undef, qq[<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01//EN"
"http://www.w3.org/TR/html4/strict.dtd">
<html>
<head>
<title>$prettyName Error</title>
</head>
<body>
<h3>Internal Error in $prettyName Script</h3>
<h3>$message</h3>
</body>
</html>
]
    );
}

$param{'action'} = 'list' unless defined( $param{'action'} );
$param{'action'} = 'list' if $param{'action'} eq 'cancel';
my $printing = (
         ( $param{'action'} eq 'print' )
      or ( $param{'action'} eq 'print preview' )
      or ( $param{'action'} eq 'e-mail' )
);
my $atShop = (
         ( $param{'action'} eq 'at shop' )
      or ( $param{'action'} eq 'remove items' )
);

if ( $param{'action'} eq 'add item' ) {
    if ( ( $param{'category'} eq 'select' ) or ( $param{'item'} eq '' ) ) {
        $html .=
          qq[<p>Category: <select name="category">\n<option>select</option>\n];
        open( SHOPLIST, $file ) || return shoppingListError("$file: $!");
        while (<SHOPLIST>) {
            chomp;
            s/^\s*(.*?)\s*$/$1/;
            /^\[(.+)\]$/ && do { $html .= qq[<option>$1</option>\n]; next; };
        }
        close(SHOPLIST);
        $html .= qq[</select></p><p>&nbsp;</p>\n];
        $html .=
          qq[<p>Item: <input type="text" name="item" id="item" size=50></p><br>];
        $html .=
          qq[<p>Add to $prettyName Now: <input type="checkbox" name="onlistnow"></p><br>];
        $html .= qq[<p><input type="submit" name="action" value="add item">\n];
        $html .= qq[<input type="submit" name="action" value="cancel"></p>\n];
        $html .= qq[</form>\n];
        $html .= '';
        $html .= &insert_keyboard(
            { form => 'main', target => 'item', autocap => 'yes' } );
        $html .= qq[</body></html>\n];
        return html_page( undef, $html );
    }
    open( OLDLIST, $file ) || return shoppingListError("$file: $!");
    my $duplicate = 0;
    my $newvalue = $param{'onlistnow'} eq 'on' ? '1' : '0';
    $html .=
      "<p>Param onlistnow is $param{'onlistnow'} so newvalue is $newvalue</p>\n"
      if $shoppinglistdebug;

    while (<OLDLIST>) {
        chomp;
        s/^\s*(.*?)\s*$/$1/;
        /^(.+)=(.+)$/ && do {
            if ( $param{'item'} eq $1 ) {
                $duplicate = 1;
                last;
            }
        };
    }
    if ($duplicate) {
        $html .= qq[<h3>$param{'item'} already in list</h3>];
    }
    else {
        seek( OLDLIST, 0, 0 );
        open( NEWLIST, ">$tempFile" )
          || return shoppingListError("$tempFile: $!");
        my $foundCategory = 0;
        while (<OLDLIST>) {
            chomp;
            s/^\s*(.*?)\s*$/$1/;
            /^#/ && do { print NEWLIST "$_\n"; next };
            /^$/ && do { print NEWLIST "\n";   next };
            /^\[(.+)\]$/ && do {
                if ( $param{'category'} eq $1 ) {
                    $foundCategory = 1;
                    print NEWLIST "$_\n";
                    next;
                }
                if ($foundCategory) {
                    print NEWLIST "$param{'item'}=$newvalue\n";
                    $html .= "<p>$param{'item'}=$newvalue</p>\n"
                      if $shoppinglistdebug;
                    print NEWLIST "$_\n";
                    $foundCategory = 0;
                    next;
                }
                print NEWLIST "$_\n";
            };
            /^(.+)=(.+)$/ && do {
                print NEWLIST "$_\n";
                next;
            };
        }
        if ($foundCategory) {
            $html .= "<p>$param{'item'}=$newvalue</p>\n" if $shoppinglistdebug;
            print NEWLIST "$param{'item'}=$newvalue\n";
        }

        close(OLDLIST);
        close(NEWLIST);
        rename $tempFile, $file;
        $html .= qq[<h3>$param{'item'} added to $param{'category'}</h3>];
    }
    $html .= qq[<p>&nbsp;</p>];
    $html .= qq[<p><input type="submit" name="action" value="add item">\n];
    $html .= qq[<input type="submit" name="action" value="list"></p>\n];
    $html .= qq[</body></html>];
    return html_page( undef, $html );
}

if (   ( $param{'action'} eq 'update list' )
    or ( $param{'action'} eq 'clear all' )
    or ( $param{'action'} eq 'remove items' ) )
{
    open( OLDLIST, $file )        || return shoppingListError("$file: $!");
    open( NEWLIST, ">$tempFile" ) || return shoppingListError("$tempFile: $!");
    while (<OLDLIST>) {
        chomp;
        s/^\s*(.*?)\s*$/$1/;
        /^#/         && do { print NEWLIST "$_\n"; next };
        /^$/         && do { print NEWLIST "\n";   next };
        /^\[(.+)\]$/ && do { print NEWLIST "$_\n"; next; };
        /^(.+)=(.+)$/ && do {
            my $newVal = '0';
            if ( $param{'action'} eq 'update list' ) {
                $newVal = $param{$1} eq 'on' ? '1' : '0';
            }
            if ( $param{'action'} eq 'remove items' ) {
                $newVal = $param{$1} eq 'on' ? '0' : $2;
            }
            print NEWLIST "$1=" . $newVal . "\n";
            next;
        };
    }
    close OLDLIST;
    close NEWLIST;
    rename $tempFile, $file;
    if ( $param{'action'} eq 'clear all' ) {
        $html .= "<h3>All Items Cleared</h3>\n";
    }
    if ( not $atShop ) {
        $html .= "<h3>List Updated</h3>\n";
    }
}

if ($printing) {
    $html .= qq[<h2>$prettyName</h2>];
    if ( $param{'action'} eq 'print preview' ) {
        $html .= qq[<h4>Preview Only</h4>];
    }
    if ( $param{'action'} eq 'e-mail' ) {
        $html .= qq[<h4>E-Mail List</h4>\n];
    }
}

open( SHOPLIST, $file ) || return shoppingListError("$file: $!");
my $num = 0;

my $showAll = 1;

$showAll = 0 if $atShop == 1;

if ($atShop) {
    $html .= qq[<h2>$prettyName At Shop</h2>];
    $html .= qq[<p><input type="submit" name="action" value="remove items">];
    $html .= qq[<input type="submit" name="action" value="cancel"></p>];
}

my $firstSection = 1;
while (<SHOPLIST>) {
    chomp;
    s/^\s*(.*?)\s*$/$1/;    # clear whitespace before and after line
    /^#/ && do { next; };   # ignore blank lines
    /^\[(.+)\]$/ && do {    # we've found a new section
        $sectionHeader = '';
        $num           = 0;
        if ( !$firstSection ) {
            $sectionHeader .= "\n</tr>\n</table>\n";
        }
        $firstSection = 0;
        if ($printing) {
            $sectionHeader .= "\n<h3>$1</h3><table>\n\n";
        }
        else {
            if ($atShop) {
                $sectionHeader .=
                  qq[\n<hr><h3>$1</h3><p><input type="submit" name="action" value="remove items">];
                $sectionHeader .=
                  qq[<input type="submit" name="action" value="cancel"><p><table>\n];
            }
            else {
                $sectionHeader .=
                  qq[<p><input type="submit" name="action" value="update list">\n];
                $sectionHeader .=
                  qq[<input type="submit" name="action" value="print preview">\n];
                $sectionHeader .=
                  qq[<input type="submit" name="action" value="print">\n];
                $sectionHeader .=
                  qq[<input type="submit" name="action" value="e-mail">\n];
                $sectionHeader .=
                  qq[<input type="submit" name="action" value="add item">\n];
                $sectionHeader .=
                  qq[<input type="submit" name="action" value="at shop">\n];
                $sectionHeader .=
                  qq[<input type="submit" name="action" value="cancel">\n];
                $sectionHeader .=
                  qq[<input type="submit" name="action" value="clear all"></p>\n];
                $sectionHeader .=
                  qq[<hr><h3>$1</h3><table width="100%"><colgroup span="$numColumns" width="$columnWidth">\n];
            }
        }
        next;
    };
    /^(.+)=(.+)$/ && do {
        my ( $item, $value ) = ( $1, $2 );
        if ( $atShop and $value == 0 ) {
            next;
        }
        if ( $printing and $value == 0 ) {
            next;
        }
        $html .= $sectionHeader;
        $sectionHeader = '';
        if ( $num % $numColumns == 0 ) {
            if ( $num > 0 ) {
                $html .= "</tr>\n";
            }
            $html .= '<tr>';
        }
        $num++;
        my $checked = $value;    # only used when not printing

        if ($atShop) {
            $checked = 0;
        }

        # my $fieldname=$item;
        # $fieldname =~ s/ /%20;/g;

        if ($printing) {
            $html .= qq[<td><input type="checkbox">$item</td>\n];
        }
        else {
            $html .= qq[<td><input type="checkbox" name="$item"]
              . ( $checked ? ' checked' : '' ) . '>';
            $html .=
              qq[<a onClick="document.main.elements['$item'].checked=!document.main.elements['$item'].checked">$item</a></td>\n];
        }
      }
}
close(SHOPLIST);

$html .= '</tr></table></form></body></html>';
my $plainText = $html;

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

if ( $param{'action'} eq 'print' ) {
    if ( $printCommandType eq 'pipe' ) {
        open( PRINTER, "| $printCommand" )
          || return shoppingListError("$printCommand: $!");
        print PRINTER $html;
        close(PRINTER);
    }
    elsif ( $printCommandType eq 'file' ) {
        open( PRINTER, "> $printOutput" )
          || return shoppingListError("$printOutput: $!");
        print PRINTER $plainText;
        close PRINTER;
        $printCommand =~ s/_FILE_/$printOutput/g;
        system($printCommand);
    }
}

if ( $param{'action'} eq 'e-mail' ) {
    if (&net_connect_check) {
        my $mailtext = $html;

        &net_mail_send(
            subject => 'shopping list',
            text    => $plainText,
            to      => $config_parms{shopping_email}
        );
    }
    else {
        $html .= "<h2>Internet connection down - e-mail NOT sent</h2>";
    }
}

return html_page( undef, $html );
