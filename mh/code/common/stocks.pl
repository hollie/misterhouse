# Category = Informational

#@ Stock Quote Lookup Module.
#@ Add the following to your INI file: stocks = IBM MS CISCO

my @stock_symbols = split ' ', $config_parms{stocks};
my %stocks;                     # This is where the data will be stored

# More info on how this magic url was derived can be found here:
#    http://www.padz.net/~djpadz/YahooQuote/
my $stock_url = 'http://quote.yahoo.com/d?f=snl1d1t1c1p2va2bapomwerr1dyj1x&s=';
my @stock_keys = ('Name', 'Last', 'Date', 'Time', 'Change', 'PChange',
                  'Volume', 'Avg Volume', 'Bid', 'Ask', 'Prev Close', 'Open',
                  'Day Range', '52-Week Range', 'EPS', 'P/E Ratio', 'Div Pay Rate',
                  'Div/Share', 'Div Yield', 'Mkt Cap', 'Exchange');

$v_stock_quote = new Voice_Cmd '[Show,Update] stock quotes', 'Ok, here are the latest prices';
$v_stock_quote-> set_info("Gets stock info from yahoo for these stocks: $config_parms{stocks}");
$v_stock_quote-> set_authority('anyone');

if ($state = said $v_stock_quote) {
    unless (&net_connect_check) {
        speak "Sorry, you are not logged onto the net";
        return;
    }
    print_log "Getting stock quotes for @stock_symbols";
    my $html = get $stock_url . join('%20', @stock_symbols);
    $html =~ tr/\"//d;          # Drop quotes
    my $results;
    for (split("\n", $html)) {
        my @data = split ',';
        my $stock = shift @data;
        my $i = 0;
        map{$stocks{$stock}{$stock_keys[$i++]} = $_} @data;
        $stocks{$stock}{Date} =~ s|\/\d{4}||; # Drop the year ... should be obvious :)
        $Save{stock_data1}  = "Stocks: $stocks{$stock}{Date} $stocks{$stock}{Time} " unless $results;
        $Save{stock_data2}  = 'Change:' unless $results;
        $Save{stock_data1} .= sprintf("%s:%.2f ", $stock, $stocks{$stock}{Last});
        $Save{stock_data2} .= sprintf("%s:%+.2f/%s ", $stock, $stocks{$stock}{Change}, $stocks{$stock}{PChange});
        $results .= sprintf("%15s was at \$%6.2f on %s %s.  Changed \$%+4.2f/%s.\n",
                            $stocks{$stock}{Name}, $stocks{$stock}{Last},
                            $stocks{$stock}{Time}, $stocks{$stock}{Date},
                            $stocks{$stock}{Change}, $stocks{$stock}{PChange});
    }
    display $results, 60, 'Latest Stock Quotes', 'fixed' if $state eq 'Show';
}

#&tk_label(\$Save{stock_data1});
#&tk_label(\$Save{stock_data2});


