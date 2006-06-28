
# Category = eCommerce

#@ Check incoming email for sales.  Venues supported are: Amazon, Amazon Canada, Alibris and eBay
#@ NOTE: Does nothing with multiple-item sales (names are not on the subject line.)
#@ Results are announced and logged with the $cash_register object.
#@ Requires internet_mail.pl

#noloop=start
$cash_register = new Generic_Item;
$v_email_marketplace = new Voice_Cmd 'Process email sales';
$v_email_sales = new Voice_Cmd 'How many sales [today,this week,this month]';
my $daily_sales = 0;
my $weekly_sales = 0;
my $monthly_sales = 0;
&load_sales();
&tk_label_new(3,\$Save{marketplace_sales_day});
&tk_label_new(3,\$Save{marketplace_sales_week});
&tk_label_new(3,\$Save{marketplace_sales_month});
#noloop=stop





if (said $v_email_sales) {
	my $state = $v_email_sales->{state};
	my $message;

	if ($state eq 'today') {
		$message = "$daily_sales today.";
	}
	elsif ($state eq 'this week') {
		$message = "$weekly_sales this week.";
	}
	else {
		$message = "$monthly_sales this month.";
	}
	respond "app=cashier $message";
}



                                # get_email_scan_file and $p_get_email are created by internet_mail.pl
if (done_now $p_get_email and -e $get_email_scan_file or said $v_email_marketplace) {
    print "marketplace: checking $get_email_scan_file\n" if $Debug{email};
    my @msgs;
    my $total_sales = 0;
    for my $line (file_read $get_email_scan_file) {
	print "marketplace: mail =$line\n" if $Debug{email};
        my ($msg, $from, $to, $subject, $body) = $line =~ /Msg: (\d+) From:(.+?) To:(.+?) Subject:(.+?) Body:(.+)/;

	my $message = '';

        if ($subject =~ /^ *Sold, Ship Now\. (\d{5}) (.*)/i or $subject =~ /^ Sold -- Ship Now! (\d{5}) (.*)/i) {
            $message = "app=cashier $2 just sold on Amazon.";
	    set $cash_register $2;
	    print "marketplace: Found Amazon email: $subject\n" if $Debug{email};
	    $total_sales++;
        }
	elsif ($subject =~ /^ *eBay Store Inventory Sold: (.*) \(\d+\)/) {
            $message = "$1 just sold in eBay Store.";
	    set $cash_register $1;
	    print "marketplace: Found eBay store email: $subject\n" if $Debug{email};		
	    $total_sales++;
	}
	elsif ($subject =~ /^ *eBay Item Sold: (.*) \(\d+\)/) {
            $message = "$1 just sold on eBay.";
	    set $cash_register $1;
	    print "marketplace: Found eBay auction email: $subject\n" if $Debug{email};		
	    $total_sales++;
	}
	elsif ($subject =~ /^ *Alibris Purchase Notification # (\d+-\d+) - (.*)/) {
            $message = "$2 just sold on Alibris.";
	    set $cash_register $2;
	    print "marketplace: Found Alibris email: $subject\n" if $Debug{email};		
	    $total_sales++;
	}
	elsif ($subject =~ /^ *You've made a sale - Please ship your item/i) {
            $message = "Item just sold on Half.com.";
	    set $cash_register "Half.com item";
	    print "marketplace: Found Half email: $subject\n" if $Debug{email};
	    $total_sales++;
	}
	elsif ($subject =~ /^ *Sold -- ship now! \(\d+ listings\/(\d+) items\)/i or $subject =~ /^ *Sold -- ship now! \(\d+ listings\/(\d+) items\)/i) {
            $message = "$1 item(s) just sold on Amazon.";
	    set $cash_register "$1 Amazon item(s)";
	    print "marketplace: Found Amazon email: $subject\n" if $Debug{email};		
	    $total_sales += int($1);
	}
	speak "app=cashier $message" if ($message);
    }

    if ($total_sales) {
	$daily_sales += $total_sales;
	$weekly_sales += $total_sales;
	$monthly_sales += $total_sales;
	speak "app=cashier no_chime=1 $total_sales new sale(s). That's $daily_sales on the day, $weekly_sales for the week and $monthly_sales this month.";
	&persist_sales();
    }

}

sub persist_sales {
    $Save{marketplace_sales_day} = $daily_sales;
    $Save{marketplace_sales_week} = $weekly_sales;
    $Save{marketplace_sales_month} = $monthly_sales;
}

sub load_sales {
    $daily_sales = $Save{marketplace_sales_day} if $Save{marketplace_sales_day};
    $weekly_sales = $Save{marketplace_sales_week} if $Save{marketplace_sales_week};
    $monthly_sales = $Save{marketplace_sales_month} if $Save{marketplace_sales_month};
}


if ($New_Day) {
    $daily_sales = 0;
    &persist_sales();
}

if ($New_Week) {
    $weekly_sales = 0;
    &persist_sales();
}

if ($New_Month) {
    $monthly_sales = 0;
    &persist_sales();
}


