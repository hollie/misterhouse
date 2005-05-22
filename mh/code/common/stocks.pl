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
                  'Day Range', '52-Week Range', 'EPS', 'P/E Ratio', 'Div Pay Rate',
                  'Div/Share', 'Div Yield', 'Mkt Cap', 'Exchange');

my $f_stock_quote = "$config_parms{data_dir}/web/stocks.html";

$v_stock_quote = new Voice_Cmd '[Update, Get, Read] stock quotes', 'Ok';
$v_stock_quote-> set_info("Gets stock info from yahoo for these stocks: $config_parms{stocks}");
$v_stock_quote-> set_authority('anyone');
$p_stock_quote = new Process_Item "get_url $stock_url $f_stock_quote";
$f_stock_quote = new File_Item "$config_parms{data_dir}/web/stocks.html";


$state = said $v_stock_quote;

if($state eq 'Update' or $state eq 'Get') {

#Not sure how this works, I have left it in for historical reason, however I would like to find if the Net is up #before connecting as it drops the data from stocks.html

    unless (&net_connect_check) {
        speak "Sorry, I can't update stock information, you are not logged onto the net";
        return;
    }
    print_log "Getting stock quotes for @stock_symbols";
    unlink $f_stock_quote->name;
    start $p_stock_quote;

}

if($state eq 'Read') {

    my $results;
    my $download_date;
    my $month;
    my $day;
    my $position;
        
    my @html = $f_stock_quote->read_all;
    
    foreach (@html) {
        tr/\"//d;          # Drop quotes
        my @data = split ',';
        my $stock = @data;
        my $i = 0;
        map{$stocks{$stock}{$stock_keys[$i++]} = $_} @data;
        $stocks{$stock}{Date} =~ s|\/\d{4}||; # Drop the year ... should be obvious :)

	#Some stocks are below a dollar, modify the display for dollars and cents.
		if ($stocks{$stock}{Last} < 1) {
	    $stocks{$stock}{Last} =  ($stocks{$stock}{Last} * 100) . " cents"; }
	else {
	      $stocks{$stock}{Last} =  sprintf("\$%6.3f",$stocks{$stock}{Last});} 
	
	#Modify the change to cents as it sounds better.  	
	$stocks{$stock}{Change} =  ($stocks{$stock}{Change} * 100);      
	$stocks{$stock}{Change} = "down " . sprintf("\%4.1f cents",$stocks{$stock}{Change}) if $stocks{$stock}{Change} < 0;
	$stocks{$stock}{Change} = "up " . sprintf("\%4.1f cents",$stocks{$stock}{Change}) if $stocks{$stock}{Change} > 0;
	$stocks{$stock}{Change} = "not changed "  if $stocks{$stock}{Change} eq 0;
	
	#Bring the elemets of the array into a sentence combined with  the above modifiers.
        $results .= sprintf("%15s at %s was %s, %s or %2.1f\%.\n",
                            $stocks{$stock}{SName},$stocks{$stock}{Time},
			    $stocks{$stock}{Last}, $stocks{$stock}{Change}, $stocks{$stock}{PChange});
	
	#Sick of hearing the date for each stock, ripped out to say only once.    
	$download_date = $stocks{$stock}{Date};
      }
      
     #Lets make the date sound half decent. - I'am sure there is an easier way but I come from a C background! 
     $position = rindex($download_date, "/"); 
     $month = substr($download_date ,0, $position);
     $day = substr($download_date , $position + 1);
     
     speak   "On " . $months[$month-1] . " ". $day . ",\n " . $results;
     
}


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

# 24 April 05, Tony Hall
# Changed code as nothing was being displayed - Yahoo have added an extra field. 
# Tested for both types of coding ie IBM and 'ibm.us'.
# Now works across world exchanges ie Australia.! i.e 'cuo.ax'. May need some mod to sound better for Pounds (UK).
# Displays Short Name  rather than Long Name, i.e extra field has been added to @stock_key.
# Added more voice support, to make it sound more natural.  
# Will be adding back the alerts and a pretty up HTML interface to view stocks.
