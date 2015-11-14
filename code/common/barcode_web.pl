# Category=Barcode

#@ Takes data from barcode_scan.pl and points to relevant web sites

# Allow anyone web access to the results
$Password_Allow{'&barcode_web_results'} = 'anyone' if $Reload;

sub barcode_web_results {
    return file_read "$config_parms{html_dir}/misc/barcode_search.html", 1;
}

return unless 'web' eq state $barcode_mode or !state $barcode_mode;

if ( my $scan = state_now $barcode_data) {
    my ( $type, $code, $isbn ) = split ' ', $scan;

    $code = substr $code, 0, 13;

    # Build a web page with search options
    my $html;
    $html .=
      "<head><META HTTP-EQUIV='pragma' CONTENT='nocache'</meta></head>\n";

    #   $html .= "<META HTTP-EQUIV='expires' CONTENT='0'>\n";
    $html .= "<base target='other'>\n";
    $html .= "<h3>$Time_Date Barcode scan</h3>\n";
    $html .= "<li>UPC: $type $code  $isbn</li>\n";

    # If a book, fire the browser to Amazon
    if ($isbn) {
        $html .=
          "<li><a href=http://www.amazon.com/exec/obidos/ISBN=$isbn>Amazon.com</a>\n";
        $html .=
          "<li><a href=http://search.borders.com/fcgi-bin/db2www/search/search.d2w/Details?"
          . "code=$isbn&mediaType=Book&searchType=ISBNUPC>Borders.com</a>\n";
        $html .=
          "<li><a href=http://shop.barnesandnoble.com/BookSearch/search.asp?ISBN=$isbn>Barnes & Nobel</a>\n";
        $html .=
          "<li><a href=http://www.price-hunter.net/booksearch/bottom.cgi?isbn=$isbn>Price-hunter price search</a>\n";
    }

    # If a UPC ...
    else {
        #       $html .= "<li><a href=http://www.barpoint.com/frame.cfm?UPCNumber=$code>BarPoint: Most anything</a>\n";
        $html .=
          "<li><a href=http://search.borders.com/fcgi-bin/db2www/search/search.d2w/Details?"
          . "code=$code&mediaType=Music&searchType=ISBNUPC>Music search at borders.com</a>";
        $html .=
          "<li><a href=http://search.borders.com/fcgi-bin/db2www/search/search.d2w/Details?"
          . "code=$code&mediaType=Video&searchType=ISBNUPC>Video search at borders.com</a>";
        $html .=
          "<li><a href=http://www.upcdatabase.com/item.pl?upc=$code>UPC search at upcdatabase.com</a>";
        $html .=
          "<li><a href=http://wwwapps.ups.com/etracking/tracking.cgi?tracknums_displayed=5"
          . "&TypeOfInquiryNumber=T&HTMLVersion=4.0&InquiryNumber1=$code>UPS Tracking</a>\n";
        $html .=
          "<li><a href=http://fedex.com/cgi-bin/tracking?action=track&language=english&cntry_code=us "
          . "&tracknumbers=$code>FedEx Tracking</a>\n";
    }

    # Not sure how to force a browser refresh here
    my $html_file = "$config_parms{html_dir}/misc/barcode_search.html";
    file_write $html_file, $html;

    #   browser $html_file;
    #   browser "http://localhost:$config_parms{http_port}/barcode_search.html";
}

# Examples
# .0.cGen.ENr7CNz1DNPXCxDWCa.  IBN 9781565922433 1565922433  Book:  Perl Cookbook
# .0.fHmc.C3P1E3P7CNf7CxbZ.    UPA 096898128230              Video: Sneakers
# .0.fHmc.C3r0Dhr3DxD3Dxf3.    UPA 077774644624              CD:    Abbey Road
