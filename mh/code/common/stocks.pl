# Category = Informational

#@ Stock Quote Lookup Module.
#@ Add the following to your INI file: stocks = IBM MSFT CSCO.
#@ Stock price changes will be announced if the stocks_thresholds parameter is set 
#@ and the change exceeds the threshold.  Thresholds can be a point value or a 
#@ percentage value.  If the parameter contains a single value, the threshold 
#@ applies to all stocks.  Alternatively, you can set a different one for each 
#@ symbol like this: stocks_thresholds = IBM:5 MSFT:5% CSCO:15%.
#@ You can map stock symbols into more pronounceable words using the 
#@ stocks_names parameter like this: stocks_names = CSCO:Cisco_Systems.

my @stock_symbols = split ' ', $config_parms{stocks};
my %stocks;                     # This is where the data will be stored

# More info on how this magic url was derived can be found here:
#    http://www.padz.net/~djpadz/YahooQuote/
my $stock_url = 'http://quote.yahoo.com/d?f=snl1d1t1c1p2va2bapomwerr1dyj1x\&s=' . join('%20', @stock_symbols);
my @stock_keys = ('Name', 'Last', 'Date', 'Time', 'Change', 'PChange',
                  'Volume', 'Avg Volume', 'Bid', 'Ask', 'Prev Close', 'Open',
                  'Day Range', '52-Week Range', 'EPS', 'P/E Ratio', 'Div Pay Rate',
                  'Div/Share', 'Div Yield', 'Mkt Cap', 'Exchange');

$v_stock_quote = new Voice_Cmd '[Show,Update] stock quotes', 'Ok, here are the latest prices';
$v_stock_quote-> set_info("Gets stock info from yahoo for these stocks: $config_parms{stocks}");
$v_stock_quote-> set_authority('anyone');
$f_stock_quote = new File_Item "$config_parms{data_dir}/web/stocks.html";
$p_stock_quote = new Process_Item("get_url $stock_url " . $f_stock_quote->name);

if ($Reload) {
    if ($config_parms{stocks_thresholds} =~ /^[\d\.%]+$/) {
        my $gthresh = $config_parms{stocks_thresholds};
        foreach (@stock_symbols) {
            $stocks{$_}{Threshold} = $gthresh; 
        }
    }
    else {
        foreach (split ' ', $config_parms{stocks_thresholds}) {
            my ($stock, $thresh) = split ':', $_;
            $stocks{$stock}{Threshold} = $thresh; 
        }
    }
    foreach (split ' ', $config_parms{stocks_names}) {
        my ($stock, $name) = split ':', $_;
        $stocks{$stock}{'Speak Name'} = $name; 
        $stocks{$stock}{'Speak Name'} =~ s/_/ /g; 
    }
}

if ($state = said $v_stock_quote) {
    unless (&net_connect_check) {
        speak "Sorry, you are not logged onto the net";
        return;
    }
    print_log "Getting stock quotes for @stock_symbols";
    unlink $f_stock_quote->name;
    &respond_wait;  # Tell web browser to wait for respond
    start $p_stock_quote; 
}

if (done_now $p_stock_quote) {
    delete $Save{stock_alert};
    my $results;
    my @html = $f_stock_quote->read_all;
    foreach (@html) {
        tr/\"//d;          # Drop quotes
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
        $stocks{$stock}{PChange} =~ s/[-+%]//g;
        if (my $t = $stocks{$stock}{Threshold}) {
            my $p = ($t =~ /%/ ? $t : 0);
            $p =~ s/%//;
            $t = 0 if $p;
            if (($t and $t < $stocks{$stock}{Change}) or ($p and $p < $stocks{$stock}{PChange})) {
                $Save{stock_alert} = "Market alert: " unless $Save{stock_alert};
                $Save{stock_alert} .= $stocks{$stock}{'Speak Name'} ? $stocks{$stock}{'Speak Name'} : $stocks{$stock}{Name};
                $Save{stock_alert} .= " has " . ($stocks{$stock}{Change} < 0 ? "fallen" : "risen");
                $Save{stock_alert} .= " $stocks{$stock}{PChange} percent to $stocks{$stock}{Last}. ";
            }
        }
    }
    respond $Save{stock_alert} if $Save{stock_alert};
    display $results, 60, 'Latest Stock Quotes', 'fixed' if $state eq 'Show';
}

#&tk_label(\$Save{stock_data1});
#&tk_label(\$Save{stock_data2});

# Instead of controling with internet_data.pl, lets allow the user to control via triggers

#$Flags{internet_data_cmds}{'Update stock quotes'}++ if ($Startup or $Reload);

if ($Reload and $Run_Members{'trigger_code'}) { 
    if ($Run_Members{'internet_dialup'}) { 
        eval qq(
            &trigger_set("state_now \$net_connect eq 'connected'", "run_voice_cmd 'Update stock quotes'", 'NoExpire', 'get stocks') 
              unless &trigger_get('get stocks');
        );
    }
    else {
        eval qq(
            &trigger_set("time_cron '5 9-13 * * 1-5' and net_connect_check", "run_voice_cmd 'Update stock quotes'", 'NoExpire', 'get stocks') 
              unless &trigger_get('get stocks');
        );
    }
}
