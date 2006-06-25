
# Category = eCommerce

#@ Check incoming email for sales.  Venues supported are: Amazon, Amazon Canada, Alibris and eBay
#@ NOTE: Does nothing with multiple-item sales (names are not on the subject line.)
#@ Results are announced and logged with the $CashRegister object.
#@ Requires internet_mail.pl

$cash_register = new Generic_Item;
$v_email_marketplace = new Voice_Cmd 'Process email sales';

                                # get_email_scan_file and $p_get_email are created by internet_mail.pl
if (done_now $p_get_email and -e $get_email_scan_file or said $v_email_marketplace) {
    print "marketplace: checking $get_email_scan_file\n" if $Debug{email};
    my @msgs;
    for my $line (file_read $get_email_scan_file) {
	print "marketplace: mail =$line\n" if $Debug{email};
        my ($msg, $from, $to, $subject, $body) = $line =~ /Msg: (\d+) From:(.+?) To:(.+?) Subject:(.+?) Body:(.+)/;

        if ($subject =~ /^ *Sold, Ship Now\. (\d{5}) (.*)/i or $subject =~ /^Sold -- Ship Now! (\d{5}) (.*)/i) {
            speak "app=cashier $2 just sold on Amazon.";
	    set $cash_register $2;
	    print "marketplace: Found Amazon email: $subject\n" if $Debug{email};
        }
	elsif ($subject =~ /^ *eBay Store Inventory Sold: (.*) \(\d+\)/) {
            speak "app=cashier $1 just sold in eBay Store.";
	    set $cash_register $1;
	    print "marketplace: Found eBay store email: $subject\n" if $Debug{email};		
	}
	elsif ($subject =~ /^ *eBay Item Sold: (.*) \(\d+\)/) {
            speak "app=cashier $1 just sold on eBay.";
	    set $cash_register $1;
	    print "marketplace: Found eBay auction email: $subject\n" if $Debug{email};		
	}
	elsif ($subject =~ /^ *Alibris Purchase Notification # (\d+-\d+) - (.*)/) {
            speak "app=cashier $2 just sold on Alibris.";
	    set $cash_register $2;
	    print "marketplace: Found Alibris email: $subject\n" if $Debug{email};		
	}

    }
}
