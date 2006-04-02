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
#@ To modify when this script is run (or to disable it), go to the 
#@ <a href=/bin/triggers.pl> triggers page </a>
#@ and modify the 'get stocks' trigger.

#&tk_label(\$Save{stock_data1});
#&tk_label(\$Save{stock_data2});

my @months = (
	    'January','Febuary','March','April','May','June',
	    'July','August','September','October','November','December');

my @stock_symbols = split ' ', $config_parms{stocks};
my %stocks;                     # This is where the data will be stored

# More info on how this magic url was derived can be found here:
#    http://www.padz.net/~djpadz/YahooQuote/
my $stock_url = 'http://quote.yahoo.com/d?f=snl1d1t1c1p2va2bapomwerr1dyj1x\&s=' . join('%20', @stock_symbols);
my @stock_keys = ('SName', 'LName', 'Last', 'Date', 'Time', 'Change', 'PChange',
                  'Volume', 'Avg Volume', 'Bid', 'Ask', 'Prev Close', 'Open',
                  'Day Range', '52-Week Range', 'EPS', 'P/E Ratio', 'Div Pay Date',
                  'Div/Share', 'Div Yield', 'Mkt Cap', 'Exchange');

$v_stock_quote = new Voice_Cmd '[Get, Read, Show] stock quotes', 'Ok';
$v_stock_quote-> set_info("Gets stock info from yahoo for these stocks: $config_parms{stocks}");
$v_stock_quote-> set_authority('anyone');
$f_stock_quote = new File_Item "$config_parms{data_dir}/web/stocks.html";
$p_stock_quote = new Process_Item("get_url $stock_url " . $f_stock_quote->name);


$state = said $v_stock_quote;

if ($state eq 'Get') {

    unless (&net_connect_check) {
        respond "Sorry, I can't update stock information, you are not logged onto the net";
        return;
    }
    print_log "Getting stock quotes for @stock_symbols";
    unlink $f_stock_quote->name;
    start $p_stock_quote;

}
elsif ($state eq 'Read' or $state eq 'Show') {

    respond ((($state eq 'Read')?'target=speak ':'') . $Save{stock_results});

}


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


if (done_now $p_stock_quote) {

    my $results;
    my $download_date;
    my $month;
    my $day;
    my $position;

    my @html = $f_stock_quote->read_all;

    delete $Save{stock_alert};
    foreach (@html) {
        tr/\"//d;          # Drop quotes
        my @data = split ',';
        my $stock = $data[0];
        my $i = 0;
        map{$stocks{$stock}{$stock_keys[$i++]} = $_} @data;
        $stocks{$stock}{PChange} =~ s/[-+%]//g;

        $stocks{$stock}{Date} =~ s|\/\d{4}||; # Drop the year ... should be obvious :)


	#this stuff was removed in last update, breaking my Web interface's ticker! :(
	#It's not the best formatted data, needs an update for a nicer looking ticker...

        $Save{stock_data1}  = "Quotes: $stocks{$stock}{Date} $stocks{$stock}{Time} " unless $results;
        $Save{stock_data2}  = 'Change:' unless $results;
        $Save{stock_data1} .= sprintf("%s:%.2f ", $stocks{$stock}{SName}, $stocks{$stock}{Last});
        $Save{stock_data2} .= sprintf("%s:%+.2f/%s ", $stocks{$stock}{SName}, $stocks{$stock}{Change}, $stocks{$stock}{PChange});

	#Some stocks are below a dollar, modify the display for dollars and cents.
        if ($stocks{$stock}{Last} < 1) {
            $stocks{$stock}{Last} =  ($stocks{$stock}{Last} * 100) . " cents"; }
        else {
            $stocks{$stock}{Last} =  (sprintf("%6.2f",$stocks{$stock}{Last})) . ' dollars';
        }

        if (my $t = $stocks{$stock}{Threshold}) {
            my $p = ($t =~ /%/ ? $t : 0);
            $p =~ s/%//;
            $t = 0 if $p;
            $stocks{$stock}{PChange} =~ s/^0*//;
            if (($t and $t < abs $stocks{$stock}{Change}) or ($p and $p < $stocks{$stock}{PChange})) {
                $Save{stock_alert} = "Market alert: " unless $Save{stock_alert};
                $Save{stock_alert} .= $stocks{$stock}{'Speak Name'} ? $stocks{$stock}{'Speak Name'} : $stocks{$stock}{LName};
                $Save{stock_alert} .= " has " . ($stocks{$stock}{Change} < 0 ? "fallen" : "risen");
                $Save{stock_alert} .= " $stocks{$stock}{PChange} percent to $stocks{$stock}{Last}";
            }
        }

	#Modify the change to cents as it sounds better.
        $stocks{$stock}{Change} =  ($stocks{$stock}{Change} * 100);
        $stocks{$stock}{Change2} = "down " . sprintf("%2.1f cents",$stocks{$stock}{Change}) if $stocks{$stock}{Change} < 0;
        $stocks{$stock}{Change2} = "up " . sprintf("%2.1f cents",$stocks{$stock}{Change}) if $stocks{$stock}{Change} > 0;
        $stocks{$stock}{Change2} = "unchanged "  if $stocks{$stock}{Change} eq 0;

	#Bring the elemets of the array into a sentence combined with  the above modifiers.
        $results .= sprintf("%15s at %s was %s, %s or %2.1f%%.\n",
                            $stocks{$stock}{SName},$stocks{$stock}{Time},
                            $stocks{$stock}{Last}, $stocks{$stock}{Change2}, $stocks{$stock}{PChange});

	#Sick of hearing the date for each stock, ripped out to say only once.
        $download_date = $stocks{$stock}{Date};

    }
    respond $Save{stock_alert} if $Save{stock_alert};

# And this:

  #Lets make the date sound half decent. - I'am sure there is an easier way but I come from a C background!
    $position = rindex($download_date, "/");
    $month = substr($download_date ,0, $position);
    $day = substr($download_date , $position + 1);
    $Save{stock_results} = 'On ' . $months[$month-1] . ' ' . $day . ",\n " . $results;

    print_log "Stock quotes retrieved"
}


if ($Reload and $Run_Members{'trigger_code'}) {
    eval qq(
        &trigger_set("time_cron '5 9-17 * * 1-5' and net_connect_check", 
          "run_voice_cmd 'Get stock quotes'", 'NoExpire', 'get stocks')
          unless &trigger_get('get stocks');
    );
}


# 27 Dec 05, David Norwood
# Someone else also added back the stock alerts in the last release.  I removed the duplicate code. 

# 29 Aug 05, David Norwood
# Added back the stock alerts.

# 24 April 05, Tony Hall
# Changed code as nothing was being displayed - Yahoo have added an extra field.
# Tested for both types of coding ie IBM and 'ibm.us'.
# Now works across world exchanges ie Australia.! i.e 'cuo.ax'. May need some mod to sound better for Pounds (UK).
# Displays Short Name  rather than Long Name, i.e extra field has been added to @stock_key.
# Added more voice support, to make it sound more natural.
# Will be adding back the alerts and a pretty up HTML interface to view stocks.
