# Category = Internet

#@ Use this code file to monitor your "My eBay" page -- including items you are
#@ watching, selling, bidding on, etc.  Note that anything you are bidding on
#@ should also be in your My eBay watch list as only items that you have bid
#@ on and are currently winning will have time-remaining announcements.
#@ Be sure to set the 'eBay_userid' and 'eBay_password' configuration options.
#@ You also must install the Crypt::SSLeay Perl module (I developed and tested
#@ with Crypt-SSLeay-0.51.tar.gz).  This was developed under Linux and may or
#@ may not work under Windows.  Set 'eBay_feedback_nag' to 1 to remind you to
#@ leave feedback once feedback has been left for you.

=begin comment

09/24/2004  Created by Kirk Bauer (kirk@kaybee.org)

NOTE: Depending on how much and how often eBay changes their site, this module
may have to be continuously maintained.  Yet I only use eBay occasionally, so
other people will have to let me know if something stops working and I'll try
to look into it.

# TODO: Lost items (parsing is just a guess now)

Example mh.ini settings:

@ Your eBay userid (leave empty to disable)
eBay_userid=ebay_id

@ Your eBay password (leave empty to disable)
eBay_password=password

@ The items within myEbay that you want to check.  Separate items with a pipe
@ character.  Valid values are: watching, bidding, won, selling, sold, unsold, lost.
eBay_check=watching|bidding|won|selling|sold|unsold|lost

@ If set to true, you will be nagged once per hour to leave feedback for items
@ where you have received feedback but have not left any.
eBay_feedback_nag=1

=cut

$v_check_ebay = new Voice_Cmd('Check eBay');
$v_check_ebay->set_info('Checks current eBay status');

$f_ebay_login1_headers =
  new File_Item "$config_parms{data_dir}/web/ebay_login1.headers";
$p_ebay_login1 = new Process_Item(
    qq[get_url -header "$f_ebay_login1_headers->{file}" "https://signin.ebay.com/ws2/eBayISAPI.dll?SignIn" "/dev/null" ]
);

$f_ebay_login2_html =
  new File_Item "$config_parms{data_dir}/web/ebay_login2.html";
$f_ebay_login2_headers =
  new File_Item "$config_parms{data_dir}/web/ebay_login2.headers";
my $url_ebay_login2 = 'https://signin.ebay.com/ws/eBayISAPI.dll?UsingSSL=1';
$p_ebay_login2 = new Process_Item;

$f_ebay_watching =
  new File_Item "$config_parms{data_dir}/web/ebay_watching.html";
my $url_ebay_watching =
  'http://my.ebay.com/ws/eBayISAPI.dll?MyeBay&LogUID=slidekb&CurrentPage=MyeBayWatching&ssPageName=STRK:ME:LNLK';
$p_ebay_watching = new Process_Item;

$f_ebay_bidding = new File_Item "$config_parms{data_dir}/web/ebay_bidding.html";
my $url_ebay_bidding =
  'http://my.ebay.com/ws/eBayISAPI.dll?MyeBay&LogUID=slidekb&CurrentPage=MyeBayBidding&ssPageName=STRK:ME:LNLK';
$p_ebay_bidding = new Process_Item;

$f_ebay_won = new File_Item "$config_parms{data_dir}/web/ebay_won.html";
my $url_ebay_won =
  'http://my.ebay.com/ws/eBayISAPI.dll?MyeBay&LogUID=slidekb&CurrentPage=MyeBayWon&ssPageName=STRK:ME:LNLK';
$p_ebay_won = new Process_Item;

$f_ebay_selling = new File_Item "$config_parms{data_dir}/web/ebay_selling.html";
my $url_ebay_selling =
  'http://my.ebay.com/ws/eBayISAPI.dll?MyeBay&LogUID=slidekb&CurrentPage=MyeBaySelling&ssPageName=STRK:ME:LNLK';
$p_ebay_selling = new Process_Item;

$f_ebay_sold = new File_Item "$config_parms{data_dir}/web/ebay_sold.html";
my $url_ebay_sold =
  'http://my.ebay.com/ws/eBayISAPI.dll?MyeBay&LogUID=slidekb&CurrentPage=MyeBaySold&ssPageName=STRK:ME:LNLK';
$p_ebay_sold = new Process_Item;

$f_ebay_unsold = new File_Item "$config_parms{data_dir}/web/ebay_unsold.html";
my $url_ebay_unsold =
  'http://my.ebay.com/ws/eBayISAPI.dll?MyeBay&LogUID=slidekb&CurrentPage=MyeBayUnsold&ssPageName=STRK:ME:LNLK';
$p_ebay_unsold = new Process_Item;

$f_ebay_lost = new File_Item "$config_parms{data_dir}/web/ebay_lost.html";
my $url_ebay_lost =
  'http://my.ebay.com/ws/eBayISAPI.dll?MyeBay&LogUID=slidekb&CurrentPage=MyeBayLost&ssPageName=STRK:ME:LNLK';
$p_ebay_lost = new Process_Item;

my $ebay_cookies;
my $post_ebay_login2 =
  "MfcISAPICommand=SignInWelcome&siteid=0&co_partnerId=2&UsingSSL=0&ru=&pp=&pa1=&pa2=&pa3=&i1=-1&pageType=-1&userid=$config_parms{eBay_userid}&pass=$config_parms{eBay_password}&keepMeSignInOption=1";

my $next_ebay_event          = 0;
my $ebay_logging_in          = 0;
my $ebay_last_error_reported = 0;
my (
    %ebay_watching, %ebay_bidding, %ebay_won,  %ebay_selling,
    %ebay_sold,     %ebay_unsold,  %ebay_lost, %ebay_end_times
);
my (
    %last_ebay_watching, %last_ebay_bidding, %last_ebay_won,
    %last_ebay_selling,  %last_ebay_sold,    %last_ebay_unsold,
    %last_ebay_lost
);

sub report_ebay_error($) {
    print_log "eBay Error: $_[0]";
    if ( ( $ebay_last_error_reported + 3600 ) < $Time ) {
        speak(
            rooms      => 'all',
            importance => 'notice',
            text       => "e-Bay Error: $_[0]"
        );
        $ebay_last_error_reported = $Time;
    }
}

if ( said $v_check_ebay) {
    my $proceed = 1;
    if (    $config_parms{eBay_userid}
        and $config_parms{eBay_password}
        and &net_connect_check )
    {
        if ( $ebay_logging_in > 0 ) {
            if ( ( $ebay_logging_in + 300 ) < $Time ) {
                &report_ebay_error("Previous eBay login failed, trying again");
            }
            else {
                $proceed = 0;
                print_log
                  "Allowing previous login attempt more time to complete";
            }
        }
        if ($proceed) {
            if ($ebay_cookies) {
                &get_ebay_data();
            }
            else {
                print_log "eBay: Logging in";
                $ebay_logging_in = $Time;
                unlink $f_ebay_login1_headers->name;
                print_log 'eBay executing '
                  . qq[get_url -header "$f_ebay_login1_headers->{file}" "https://signin.ebay.com/ws2/eBayISAPI.dll?SignIn" "/dev/null" ];
                start $p_ebay_login1;
            }
        }
    }
}

if ($Reload) {
    run_voice_cmd 'Check eBay';
}

if ( done_now $p_ebay_login1) {
    $ebay_cookies = &cookies_parse( $f_ebay_login1_headers, $ebay_cookies );
    unlink $f_ebay_login2_html->name;
    unlink $f_ebay_login2_headers->name;
    my $cookies = &cookies_generate($ebay_cookies);
    print_log 'eBay executing '
      . qq[get_url -header "$f_ebay_login2_headers->{file}" -cookies "$cookies" -post "$post_ebay_login2" "$url_ebay_login2" "$f_ebay_login2_html->{file}" ];
    $p_ebay_login2->set(
        qq[get_url -header "$f_ebay_login2_headers->{file}" -cookies "$cookies" -post "$post_ebay_login2" "$url_ebay_login2" "$f_ebay_login2_html->{file}" ]
    );
    $p_ebay_login2->start();
}

sub get_ebay_data {
    print_log "eBay: Getting data...";
    unless ( $config_parms{eBay_check} ) {
        $config_parms{eBay_check} =
          'watching|bidding|won|selling|sold|unsold|lost';
    }
    if ( $config_parms{eBay_check} =~ /\bwatching\b/ ) {

        # Update watching
        unlink $f_ebay_watching->name;
        my $cookies = &cookies_generate($ebay_cookies);
        $p_ebay_watching->set(
            qq[get_url -cookies "$cookies" "$url_ebay_watching" "$f_ebay_watching->{file}"]
        );
        $p_ebay_watching->start();
    }

    if ( $config_parms{eBay_check} =~ /\bbidding\b/ ) {

        # Update bidding
        unlink $f_ebay_bidding->name;
        my $cookies = &cookies_generate($ebay_cookies);
        $p_ebay_bidding->set(
            qq[get_url -cookies "$cookies" "$url_ebay_bidding" "$f_ebay_bidding->{file}"]
        );
        $p_ebay_bidding->start();
    }

    if ( $config_parms{eBay_check} =~ /\bwon\b/ ) {

        # Update wins
        unlink $f_ebay_won->name;
        my $cookies = &cookies_generate($ebay_cookies);
        $p_ebay_won->set(
            qq[get_url -cookies "$cookies" "$url_ebay_won" "$f_ebay_won->{file}"]
        );
        $p_ebay_won->start();
    }

    if ( $config_parms{eBay_check} =~ /\bselling\b/ ) {

        # Update selling
        unlink $f_ebay_selling->name;
        my $cookies = &cookies_generate($ebay_cookies);
        $p_ebay_selling->set(
            qq[get_url -cookies "$cookies" "$url_ebay_selling" "$f_ebay_selling->{file}"]
        );
        $p_ebay_selling->start();
    }

    if ( $config_parms{eBay_check} =~ /\bsold\b/ ) {

        # Update sold
        unlink $f_ebay_sold->name;
        my $cookies = &cookies_generate($ebay_cookies);
        $p_ebay_sold->set(
            qq[get_url -cookies "$cookies" "$url_ebay_sold" "$f_ebay_sold->{file}"]
        );
        $p_ebay_sold->start();
    }

    if ( $config_parms{eBay_check} =~ /\bunsold\b/ ) {

        # Update unsold
        unlink $f_ebay_unsold->name;
        my $cookies = &cookies_generate($ebay_cookies);
        $p_ebay_unsold->set(
            qq[get_url -cookies "$cookies" "$url_ebay_unsold" "$f_ebay_unsold->{file}"]
        );
        $p_ebay_unsold->start();
    }

    if ( $config_parms{eBay_check} =~ /\blost\b/ ) {

        # Update not won
        unlink $f_ebay_lost->name;
        my $cookies = &cookies_generate($ebay_cookies);
        $p_ebay_lost->set(
            qq[get_url -cookies "$cookies" "$url_ebay_lost" "$f_ebay_lost->{file}"]
        );
        $p_ebay_lost->start();
    }
}

if ( done_now $p_ebay_login2) {
    $ebay_cookies = &cookies_parse( $f_ebay_login2_headers, $ebay_cookies );
    foreach ( $f_ebay_login2_html->read_all() ) {
        if (/You\'re now signed in to eBay/) {
            $ebay_logging_in = 0;
            print_log "eBay: Login successful...";
            &get_ebay_data();
        }
    }
}

sub parse_ebay_html_line ($$$$) {
    my ( $lastitem, $hashref, $line, $type ) = @_;
    chomp($line);
    $line =~ s/\r$//;
    if ( $line =~ /^<form method="post" name="SignInForm"/ ) {

        # need to log in again
        undef $ebay_cookies;
        run_voice_cmd 'Check eBay';
        return 'NOT LOGGED IN';
    }
    elsif ( $line =~
        /<a href="http:\/\/cgi\.ebay\.com\/ws\/[^"]+&amp;item=(\d+)&amp;[^"]+">([^<]+)<\/a>/
      )
    {
        # watching/bidding/selling/unsold/(lost?) page: item number and title
        # won/sold page: item title
        if ( ( $type eq 'won' ) or ( $type eq 'sold' ) ) {
            unless ( $lastitem == $1 ) {
                &report_ebay_error(
                    "Parse Error: Item $1 does not match $lastitem");
            }
        }
        else {
            $lastitem = $1;
        }
        $hashref->{$lastitem}{'title'} = &html_decode($2);
        print_log "eBay: $type item $lastitem ($hashref->{$lastitem}{'title'})";
    }
    elsif ( $line =~
        /<a href="http:\/\/feedback\.ebay\.com\/[^"]+&amp;item=(\d+)&amp;[^"]+"><strong>([^<]+)<\/strong><\/a>/
      )
    {
        # Won page: item number and seller
        # Sold page: item number and buyer
        $lastitem = $1;
        if ( $type eq 'won' ) {
            $hashref->{$lastitem}{'seller'} = &html_decode($2);
            print_log
              "eBay: Seller for item $lastitem is $hashref->{$lastitem}{'seller'}"
              if $main::Debug{ebay};
        }
        elsif ( $type eq 'sold' ) {
            $hashref->{$lastitem}{'buyer'} = &html_decode($2);
            print_log
              "eBay: Buyer for item $lastitem is $hashref->{$lastitem}{'buyer'}"
              if $main::Debug{ebay};
        }
    }
    elsif ( $line =~
        /^<td align="right" class="([^"]+)" nowrap="true">(\$\d+\.\d+)</ )
    {
        # watching/bidding/selling page: price and status
        # Class is 'normal' if you have not bid yet
        # Class is 'failed' if you have bid and are losing
        # Class is 'success' if you are winning
        $hashref->{$lastitem}{'status'} = $1;
        $hashref->{$lastitem}{'price'}  = $2;
        print_log "eBay: Status for item $lastitem is $1" if $main::Debug{ebay};
        print_log "eBay: Price for item $lastitem is $2"  if $main::Debug{ebay};
    }
    elsif ( $line =~ /^<td align="right" nowrap="true">(\$\d+\.\d+)<\/td>/ ) {

        # bidding page: max price & shipping cost (max price first)
        # watching page: shipping cost
        # won page: sale price
        if (    ( $type eq 'bidding' )
            and ( not $hashref->{$lastitem}{'maxbid'} ) )
        {
            $hashref->{$lastitem}{'maxbid'} = $1;
            print_log "eBay: Max bid for item $lastitem is $1"
              if $main::Debug{ebay};
        }
        elsif ( $type eq 'watching' ) {
            $hashref->{$lastitem}{'shipping'} = $1;
            print_log "eBay: Shipping for item $lastitem is $1"
              if $main::Debug{ebay};
        }
        elsif ( ( $type eq 'won' ) or ( $type eq 'sold' ) ) {
            $hashref->{$lastitem}{'sale_price'} = $1;
            print_log "eBay: Sale price for item $lastitem is $1"
              if $main::Debug{ebay};
        }
    }
    elsif ( $line =~ /<td align="center"><Watchers>(\d+)<\/Watchers><\/td>/ ) {

        # selling: number of watchers
        $hashref->{$lastitem}{'watchers'} = $1;
        print_log "eBay: Number of watchers for item $lastitem is $1"
          if $main::Debug{ebay};
    }
    elsif ( $line =~ /^<td align="center">(\d+)<\/td>/ ) {

        # watching page: # of bids
        # selling page: # of bids (first) and number of questions
        # won/sold page: quantity won
        if (
               ( $type eq 'watching' )
            or
            ( ( $type eq 'selling' ) and ( not $hashref->{$lastitem}{'bids'} ) )
          )
        {
            $hashref->{$lastitem}{'bids'} = $1;
            print_log "eBay: Number of bids for item $lastitem is $1"
              if $main::Debug{ebay};
        }
        elsif ( ( $type eq 'won' ) or ( $type eq 'sold' ) ) {
            $hashref->{$lastitem}{'quantity'} = $1;
            print_log "eBay: Quantity you won for item $lastitem is $1"
              if $main::Debug{ebay};
        }
        elsif ( $type eq 'selling' ) {
            $hashref->{$lastitem}{'questions'} = $1;
            print_log "eBay: Number of questions for item $lastitem is $1"
              if $main::Debug{ebay};
        }
    }
    elsif ( $line =~
        /<a href="http:\/\/feedback\.ebay\.com\/[^"]+&amp;item=(\d+)&amp;[^"]+">([^<]+)<\/a>/
      )
    {
        # watching page: seller id
        # selling page: high bidder id
        unless ( $lastitem == $1 ) {
            &report_ebay_error("Parse Error: Item $1 does not match $lastitem");
        }
        if ( $type eq 'watching' ) {
            $hashref->{$lastitem}{'seller'} = &html_decode($2);
            print_log
              "eBay: Seller for item $lastitem is $hashref->{$lastitem}{'seller'}"
              if $main::Debug{ebay};
        }
        elsif ( $type eq 'selling' ) {
            $hashref->{$lastitem}{'high_bidder'} = &html_decode($2);
            print_log
              "eBay: High bidder for item $lastitem is $hashref->{$lastitem}{'high_bidder'}"
              if $main::Debug{ebay};
        }
    }
    elsif ( $line =~ /^\s+Ended$/ ) {
        $hashref->{$lastitem}{'days_left'}  = 0;
        $hashref->{$lastitem}{'hours_left'} = 0;
        $hashref->{$lastitem}{'mins_left'}  = 0;
        $hashref->{$lastitem}{'end_time'}   = 0;
    }
    elsif ( $line =~ /^<td align="right" class="[^"]*" nowrap>([^<]+)<\/td>/ ) {

        # watching/bidding/selling page: time left
        my $ends = $1;

        # Get rid of the "<" in "<1m"
        $ends =~ s/^&lt;//;
        if ( $ends =~ s/^\s*(\d+)d\s*// ) {
            $hashref->{$lastitem}{'days_left'} = $1;
        }
        else {
            $hashref->{$lastitem}{'days_left'} = 0;
        }
        if ( $ends =~ s/^\s*(\d+)h\s*// ) {
            $hashref->{$lastitem}{'hours_left'} = $1;
        }
        else {
            $hashref->{$lastitem}{'hours_left'} = 0;
        }
        if ( $ends =~ /^\s*(\d+)m\s*/ ) {
            $hashref->{$lastitem}{'mins_left'} = $1;
        }
        print_log
          "eBay: Days left for item $lastitem is $hashref->{$lastitem}{'days_left'}"
          if $main::Debug{ebay};
        print_log
          "eBay: Hours left for item $lastitem is $hashref->{$lastitem}{'hours_left'}"
          if $main::Debug{ebay};
        print_log
          "eBay: Minutes left for item $lastitem is $hashref->{$lastitem}{'mins_left'}"
          if $main::Debug{ebay};
        $hashref->{$lastitem}{'end_time'} =
          $Time +
          ( $hashref->{$lastitem}{'mins_left'} * 60 ) +
          ( $hashref->{$lastitem}{'hours_left'} * 3600 ) +
          ( $hashref->{$lastitem}{'days_left'} * 3600 * 24 );
    }
    elsif ( $line =~ /<img [^>]+ alt="([^"]+)" [^>]+>/ ) {
        if ( $1 eq 'Not Paid' ) {

            # Won/Sold page
            $hashref->{$lastitem}{'paid'} = '';
        }
        elsif ( $1 eq 'Payment Pending with PayPal' ) {

            # Won/Sold page
            $hashref->{$lastitem}{'paid'} = 'pending';
        }
        elsif ( $1 eq 'Paid' ) {

            # Won/Sold page
            $hashref->{$lastitem}{'paid'} = 'paid';
        }
        elsif ( $1 eq 'Feedback Not Left' ) {

            # Won/Sold page
            $hashref->{$lastitem}{'feedback_left'} = 0;
        }
        elsif ( $1 eq 'Feedback Left' ) {

            # Won/Sold page
            $hashref->{$lastitem}{'feedback_left'} = 1;
        }
        elsif ( $1 eq 'Feedback Not Received' ) {

            # Won/Sold page
            $hashref->{$lastitem}{'feedback_received'} = '';
        }
        elsif ( $1 =~ /^(.+) Feedback Received/ ) {

            # Won/Sold page (possible values 'Positive', 'Neutral'?, 'Negative'?)
            $hashref->{$lastitem}{'feedback_received'} = $1;
        }
        elsif ( $1 eq 'Buyer Has Not Completed Checkout' ) {

            # Sold page
            $hashref->{$lastitem}{'completed_checkout'} = 0;
        }
        elsif ( $1 eq 'Checkout Complete' ) {

            # Sold page
            $hashref->{$lastitem}{'completed_checkout'} = 1;
        }
        elsif ( $1 eq 'Not Shipped' ) {

            # Sold page
            $hashref->{$lastitem}{'shipped'} = 0;
        }
        elsif ( $1 eq 'Shipped' ) {

            # Sold page
            $hashref->{$lastitem}{'shipped'} = 1;
        }
    }
    return $lastitem;
}

if ($New_Minute) {
    my $remaining = 0;
    if ( $next_ebay_event > 0 ) {
        $remaining = $next_ebay_event - $Time;
    }
    if ( $remaining and ( $remaining < ( 60 * 15 ) ) ) {

        # Check every minute when something has less than 15 minutes remaining
        run_voice_cmd 'Check eBay';
    }
    elsif ( $remaining and ( $remaining < ( 60 * 60 ) ) ) {

        # Check every 10 minutes when less than one hour remaining
        if ( ( $Minute % 10 ) == 5 ) {
            run_voice_cmd 'Check eBay';
        }
    }
    elsif ( $remaining and ( $remaining < ( 60 * 60 * 4 ) ) ) {

        # Check every 15 minutes when less than 4 hours remaining
        if ( ( $Minute % 15 ) == 5 ) {
            run_voice_cmd 'Check eBay';
        }
    }
    elsif ( $remaining and ( $remaining < ( 60 * 60 * 16 ) ) ) {

        # Check every 30 minutes when less than 16 hours remaining
        if ( ( $Minute % 30 ) == 5 ) {
            run_voice_cmd 'Check eBay';
        }
    }
    else {
        # Default is to check every hour
        if ( $Minute == 5 ) {
            run_voice_cmd 'Check eBay';
        }
    }
}

sub speak_time($) {
    my $seconds = $_[0];
    my $ret     = '';
    my ( $min, $hours, $days ) = ( 0, 0, 0 );
    if ( $min = int( $seconds / 60 ) ) {
        $seconds = ( $seconds - ( 60 * $min ) );
    }
    if ( $hours = int( $min / 60 ) ) {
        $min = ( $min - ( 60 * $hours ) );
    }
    if ( $days = int( $hours / 60 ) ) {
        $hours = ( $hours - ( 24 * $days ) );
    }
    if ( $days > 0 ) {
        $ret .= "$days days, ";
    }
    if ( $hours > 0 ) {
        $ret .= "$hours hours, ";
    }
    if ( $min > 0 ) {
        $ret .= "$min minutes";
    }
    $ret =~ s/, $//;
    $ret = 'less than 1 minute' unless $ret;
    return $ret;
}

sub check_ebay_end_times($$$) {
    my ( $less_than, $frequency, $importance ) = @_;
    foreach my $item ( keys %ebay_end_times ) {
        if ( $ebay_end_times{$item} and $ebay_end_times{$item}{'end_time'} ) {
            my $ends_in = $ebay_end_times{$item}{'end_time'} - $Time;
            print_log
              "eBay: checking item $ebay_end_times{$item}{'title'}, $ends_in, $less_than"
              if $main::Debug{ebay};
            if ( ( $ends_in > 0 ) and ( $ends_in < $less_than ) ) {
                print_log
                  "eBay: checking item $ebay_end_times{$item}{'title'}, $ebay_end_times{$item}{'last_reported'}, $frequency"
                  if $main::Debug{ebay};
                if (
                    not $ebay_end_times{$item}{'last_reported'}
                    or ( ( $Time - $ebay_end_times{$item}{'last_reported'} ) >=
                        $frequency )
                  )
                {
                    speak(
                        rooms      => 'all',
                        importance => $importance,
                        text =>
                          "e-Bay Notice: item '$ebay_end_times{$item}{'title'}' that you are $ebay_end_times{$item}{'activity'} ends in "
                          . &speak_time($ends_in)
                    );
                    print_log
                      "eBay item $item ($ebay_end_times{$item}{'title'}) ends in "
                      . &speak_time($ends_in);
                    $ebay_end_times{$item}{'last_reported'} = $Time;
                }
            }
        }
    }
}

if ($New_Minute) {
    &check_ebay_end_times( 300,       60,   'important' );
    &check_ebay_end_times( 600,       120,  'important' );
    &check_ebay_end_times( 3600,      900,  'important' );
    &check_ebay_end_times( 3600 * 4,  1800, 'notice' );
    &check_ebay_end_times( 3600 * 24, 3600, 'notice' );
}

sub check_end_time($$$) {
    my ( $item, $hashref, $activity ) = @_;
    if ( $hashref->{$item}{'end_time'} ) {
        if (   ( $next_ebay_event <= 0 )
            or ( $next_ebay_event > $hashref->{$item}{'end_time'} ) )
        {
            $next_ebay_event = $hashref->{$item}{'end_time'};
        }
    }
    $ebay_end_times{$item}{'end_time'} = $hashref->{$item}{'end_time'};
    if ( $hashref->{$item}{'title'} ) {
        $ebay_end_times{$item}{'title'} = $hashref->{$item}{'title'};
    }
    if ( not $ebay_end_times{$item}{'activity'}
        or ( $ebay_end_times{$item}{'activity'} eq 'watching' ) )
    {
        $ebay_end_times{$item}{'activity'} = $activity;
    }
}

if ( done_now $p_ebay_watching) {
    my $lastitem = 0;
    if ( $ebay_watching{'populated'} ) {
        %last_ebay_watching = %ebay_watching;
    }
    %ebay_watching = ();
    $ebay_watching{'populated'} = 1;
    foreach ( $f_ebay_watching->read_all() ) {
        $lastitem =
          &parse_ebay_html_line( $lastitem, \%ebay_watching, $_, 'watching' );
        if ( $lastitem eq 'NOT LOGGED IN' ) {
            %ebay_watching = ();
            last;
        }
    }
    my $count = 0;
    foreach my $item ( keys %ebay_watching ) {
        next if $item eq 'populated';
        $count++;

        # 'shipping' will be undefined if fixed shipping cost was not specified for item
        foreach ( 'title', 'status', 'price', 'bids', 'seller', 'end_time' ) {
            unless ( defined( $ebay_watching{$item}{$_} ) ) {
                &report_ebay_error(
                    "Parse error for item $item, value '$_' not found!");
            }
        }
        &check_end_time( $item, \%ebay_watching, 'watching' );
        if ( $last_ebay_watching{'populated'} and $last_ebay_watching{$item} ) {
            if ( $last_ebay_watching{$item}{'price'} ne
                $ebay_watching{$item}{'price'} )
            {
                speak(
                    rooms      => 'all',
                    importance => 'notice',
                    text =>
                      "e-Bay Notice: The price of item '$ebay_watching{$item}{'title'}' has changed to $ebay_watching{$item}{'price'}"
                );
                print_log
                  "The price of eBay item $item ($ebay_watching{$item}{'title'}) has changed to $ebay_watching{$item}{'price'}";
            }
            if (    ( $ebay_watching{$item}{'end_time'} == 0 )
                and ( $last_ebay_watching{$item}{'end_time'} > 0 ) )
            {
                speak(
                    rooms      => 'all',
                    importance => 'notice',
                    text =>
                      "e-Bay Notice: Auction for item '$ebay_watching{$item}{'title'}' has ended"
                );
                print_log
                  "The auction of eBay item $item ($ebay_watching{$item}{'title'}) has ended";
            }
        }
        elsif ( $last_ebay_watching{'populated'}
            and not $last_ebay_watching{$item} )
        {
            # New item showed up
            speak(
                rooms      => 'all',
                importance => 'notice',
                text =>
                  "e-Bay Notice: I am now watching item '$ebay_watching{$item}{'title'}'"
            );
            print_log
              "I am now watching eBay item $item ($ebay_watching{$item}{'title'})";
        }
    }
    print_log "eBay: You are watching $count items.";
}

if ( done_now $p_ebay_bidding) {
    my $lastitem = 0;
    if ( $ebay_bidding{'populated'} ) {
        %last_ebay_bidding = %ebay_bidding;
    }
    %ebay_bidding = ();
    $ebay_bidding{'populated'} = 1;
    foreach ( $f_ebay_bidding->read_all() ) {
        $lastitem =
          &parse_ebay_html_line( $lastitem, \%ebay_bidding, $_, 'bidding' );
        if ( $lastitem eq 'NOT LOGGED IN' ) {
            %ebay_bidding = ();
            last;
        }
    }
    my $count = 0;
    foreach my $item ( keys %ebay_bidding ) {
        next if $item eq 'populated';
        $count++;

        # 'shipping' will be undefined if fixed shipping cost was not specified for item
        foreach ( 'title', 'status', 'price', 'maxbid', 'end_time' ) {
            unless ( defined( $ebay_bidding{$item}{$_} ) ) {
                &report_ebay_error(
                    "Parse error for item $item, value '$_' not found!");
            }
        }
        if ( $last_ebay_bidding{$item}{'status'} eq 'success' ) {
            &check_end_time( $item, \%ebay_bidding, 'winning' );
        }
        if ( $last_ebay_bidding{'populated'} and $last_ebay_bidding{$item} ) {
            if ( $last_ebay_bidding{$item}{'status'} ne
                $ebay_bidding{$item}{'status'} )
            {
                if ( $last_ebay_bidding{$item}{'status'} eq 'success' ) {
                    speak(
                        rooms      => 'all',
                        importance => 'important',
                        text =>
                          "e-Bay Notice: You are no longer winning item '$ebay_bidding{$item}{'title'}'"
                    );
                    print_log
                      "You are no longer winning eBay item $item ($ebay_bidding{$item}{'title'})";
                }
            }
        }
        elsif ( $last_ebay_bidding{'populated'}
            and not $last_ebay_bidding{$item} )
        {
            # New item showed up
            if ( $ebay_bidding{$item}{'status'} eq 'success' ) {
                speak(
                    rooms      => 'all',
                    importance => 'notice',
                    text =>
                      "e-Bay Notice: You have bid on item '$ebay_bidding{$item}{'title'}' and you are winning"
                );
                print_log
                  "You have bid on eBay item $item ($ebay_bidding{$item}{'title'}) and you are winning";
            }
            else {
                speak(
                    rooms      => 'all',
                    importance => 'notice',
                    text =>
                      "e-Bay Notice: You have bid on item '$ebay_bidding{$item}{'title'}' and you are not winning"
                );
                print_log
                  "You have bid on eBay item $item ($ebay_bidding{$item}{'title'}) and you are not winning";
            }
        }
    }
    print_log "eBay: You are bidding on $count items.";
}

if ( done_now $p_ebay_selling) {
    my $lastitem = 0;
    if ( $ebay_selling{'populated'} ) {
        %last_ebay_selling = %ebay_selling;
    }
    %ebay_selling = ();
    $ebay_selling{'populated'} = 1;
    foreach ( $f_ebay_selling->read_all() ) {
        $lastitem =
          &parse_ebay_html_line( $lastitem, \%ebay_selling, $_, 'selling' );
        if ( $lastitem eq 'NOT LOGGED IN' ) {
            %ebay_selling = ();
            last;
        }
    }
    my $count = 0;
    foreach my $item ( keys %ebay_selling ) {
        next if $item eq 'populated';
        $count++;
        foreach (
            'title',       'status',   'price',     'bids',
            'high_bidder', 'watchers', 'questions', 'end_time'
          )
        {
            unless ( defined( $ebay_selling{$item}{$_} ) ) {
                &report_ebay_error(
                    "Parse error for item $item, value '$_' not found!");
            }
        }
        &check_end_time( $item, \%ebay_selling, 'selling' );
        if ( $last_ebay_selling{'populated'} and $last_ebay_selling{$item} ) {
            if ( $last_ebay_selling{$item}{'price'} ne
                $ebay_selling{$item}{'price'} )
            {
                speak(
                    rooms      => 'all',
                    importance => 'notice',
                    text =>
                      "e-Bay Notice: The price of item '$ebay_selling{$item}{'title'}' has changed to $ebay_selling{$item}{'price'} (high bidder is $ebay_selling{$item}{'high_bidder'})"
                );
                print_log
                  "The price of eBay item $item ($ebay_selling{$item}{'title'}) has changed to $ebay_selling{$item}{'price'} (high bidder is $ebay_selling{$item}{'high_bidder'})";
            }
            if ( $last_ebay_selling{$item}{'watchers'} <
                $ebay_selling{$item}{'watchers'} )
            {
                speak(
                    rooms      => 'all',
                    importance => 'notice',
                    text =>
                      "e-Bay Notice: There are now $ebay_selling{$item}{'watchers'} people watching item '$ebay_selling{$item}{'title'}'"
                );
                print_log
                  "There are now $ebay_selling{$item}{'watchers'} people watching eBay item $item ($ebay_selling{$item}{'title'})";
            }
            if ( $last_ebay_selling{$item}{'questions'} <
                $ebay_selling{$item}{'questions'} )
            {
                speak(
                    rooms      => 'all',
                    importance => 'notice',
                    text =>
                      "e-Bay Notice: There are new questions about item '$ebay_selling{$item}{'title'}' ($ebay_selling{$item}{'questions'} pending)"
                );
                print_log
                  "There are new questions about eBay item $item ($ebay_selling{$item}{'title'}) ($ebay_selling{$item}{'questions'} pending)";
            }
            if ( $last_ebay_selling{$item}{'status'} ne
                $ebay_selling{$item}{'status'} )
            {
                if ( $ebay_selling{$item}{'status'} eq 'success' ) {
                    speak(
                        rooms      => 'all',
                        importance => 'important',
                        text =>
                          "e-Bay Notice: item '$ebay_selling{$item}{'title'}' is now going to sell"
                    );
                    print_log
                      "eBay item $item ($ebay_selling{$item}{'title'}) is now going to sell";
                }
            }
        }
        elsif ( $last_ebay_selling{'populated'}
            and not $last_ebay_selling{$item} )
        {
            # New item showed up
            speak(
                rooms      => 'all',
                importance => 'notice',
                text =>
                  "e-Bay Notice: You are now selling item '$ebay_selling{$item}{'title'}'"
            );
            print_log
              "You are now selling eBay item $item ($ebay_selling{$item}{'title'})";
        }
    }
    print_log "eBay: You are selling $count items.";
}

if ( done_now $p_ebay_won) {
    my $lastitem = 0;
    if ( $ebay_won{'populated'} ) {
        %last_ebay_won = %ebay_won;
    }
    %ebay_won = ();
    $ebay_won{'populated'} = 1;
    foreach ( $f_ebay_won->read_all() ) {
        $lastitem = &parse_ebay_html_line( $lastitem, \%ebay_won, $_, 'won' );
        if ( $lastitem eq 'NOT LOGGED IN' ) {
            %ebay_won = ();
            last;
        }
    }
    my $count = 0;
    foreach my $item ( keys %ebay_won ) {
        next if $item eq 'populated';
        $count++;
        foreach (
            'seller', 'quantity', 'sale_price',
            'title',  'paid',     'feedback_left',
            'feedback_received'
          )
        {
            unless ( defined( $ebay_won{$item}{$_} ) ) {
                &report_ebay_error(
                    "Parse error for item $item, value '$_' not found!");
            }
        }
        if ( $last_ebay_won{'populated'} and $last_ebay_won{$item} ) {
            if ( $last_ebay_won{$item}{'feedback_received'} ne
                $ebay_won{$item}{'feedback_received'} )
            {
                if ( $ebay_won{$item}{'feedback_received'} eq 'Positive' ) {
                    speak(
                        rooms      => 'all',
                        importance => 'notice',
                        text =>
                          "e-Bay Notice: You have received positive feedback for item '$ebay_won{$item}{'title'}'"
                    );
                    print_log
                      "You have received positive feedback for eBay item $item ($ebay_won{$item}{'title'})";
                }
                else {
                    speak(
                        rooms      => 'all',
                        importance => 'important',
                        text =>
                          "e-Bay Notice: Warning, you have received $ebay_won{$item}{'feedback_received'} feedback for item '$ebay_won{$item}{'title'}'"
                    );
                    print_log
                      "Warning, you have received $ebay_won{$item}{'feedback_received'} feedback for eBay item $item ($ebay_won{$item}{'title'})";
                }
            }
        }
        elsif ( $last_ebay_won{'populated'} and not $last_ebay_won{$item} ) {

            # New item showed up
            speak(
                rooms      => 'all',
                importance => 'important',
                text =>
                  "e-Bay Notice: You won item '$ebay_won{$item}{'title'}' for $ebay_won{$item}{'sale_price'}"
            );
            print_log
              "You won eBay item $item ($ebay_won{$item}{'title'}) for $ebay_won{$item}{'sale_price'}";
        }
    }
    print_log "eBay: You have won $count items.";
}

if ( done_now $p_ebay_sold) {
    my $lastitem = 0;
    if ( $ebay_sold{'populated'} ) {
        %last_ebay_sold = %ebay_sold;
    }
    %ebay_sold = ();
    $ebay_sold{'populated'} = 1;
    foreach ( $f_ebay_sold->read_all() ) {
        $lastitem = &parse_ebay_html_line( $lastitem, \%ebay_sold, $_, 'sold' );
        if ( $lastitem eq 'NOT LOGGED IN' ) {
            %ebay_sold = ();
            last;
        }
    }
    my $count = 0;
    foreach my $item ( keys %ebay_sold ) {
        next if $item eq 'populated';
        $count++;
        foreach (
            'buyer',             'quantity',           'sale_price',
            'title',             'paid',               'feedback_left',
            'feedback_received', 'completed_checkout', 'shipped'
          )
        {
            unless ( defined( $ebay_sold{$item}{$_} ) ) {
                &report_ebay_error(
                    "Parse error for item $item, value '$_' not found!");
            }
        }
        if ( $last_ebay_sold{'populated'} and $last_ebay_sold{$item} ) {
            if ( $last_ebay_sold{$item}{'paid'} ne $ebay_sold{$item}{'paid'} ) {
                if ( $ebay_sold{$item}{'paid'} eq 'pending' ) {
                    speak(
                        rooms      => 'all',
                        importance => 'notice',
                        text =>
                          "e-Bay Notice: A PayPal payment for item '$ebay_sold{$item}{'title'}' is pending and needs to be accepted or denied"
                    );
                    print_log
                      "A PayPal payment for eBay item $item ($ebay_sold{$item}{'title'}) is pending and needs to be accepted or denied";
                }
                elsif ( $ebay_sold{$item}{'paid'} eq 'paid' ) {
                    speak(
                        rooms      => 'all',
                        importance => 'notice',
                        text =>
                          "e-Bay Notice: The buyer has paid for item '$ebay_sold{$item}{'title'}'"
                    );
                    print_log
                      "The buyer has paid for eBay item $item ($ebay_sold{$item}{'title'})";
                }
            }
            if ( $last_ebay_sold{$item}{'feedback_received'} ne
                $ebay_sold{$item}{'feedback_received'} )
            {
                if ( $ebay_sold{$item}{'feedback_received'} eq 'Positive' ) {
                    speak(
                        rooms      => 'all',
                        importance => 'notice',
                        text =>
                          "e-Bay Notice: You have received positive feedback for item '$ebay_sold{$item}{'title'}'"
                    );
                    print_log
                      "You have received positive feedback for eBay item $item ($ebay_sold{$item}{'title'})";
                }
                else {
                    speak(
                        rooms      => 'all',
                        importance => 'important',
                        text =>
                          "e-Bay Warning: You have received $ebay_sold{$item}{'feedback_received'} feedback for item '$ebay_sold{$item}{'title'}'"
                    );
                    print_log
                      "Warning, you have received $ebay_sold{$item}{'feedback_received'} feedback for eBay item $item ($ebay_sold{$item}{'title'})";
                }
            }
            if ( $last_ebay_sold{$item}{'completed_checkout'} !=
                $ebay_sold{$item}{'completed_checkout'} )
            {
                speak(
                    rooms      => 'all',
                    importance => 'notice',
                    text =>
                      "e-Bay Notice: The buyer has completed checkout for item '$ebay_sold{$item}{'title'}'"
                );
                print_log
                  "The buyer has completed checkout for eBay item $item ($ebay_sold{$item}{'title'}) is pending and needs to be accepted or denied";
            }
        }
        elsif ( $last_ebay_sold{'populated'} and not $last_ebay_sold{$item} ) {

            # New item showed up
            speak(
                rooms      => 'all',
                importance => 'notice',
                text =>
                  "e-Bay Notice: You sold item '$ebay_sold{$item}{'title'}' for $ebay_sold{$item}{'sale_price'} to $ebay_sold{$item}{'buyer'}"
            );
            print_log
              "You sold eBay item $item ($ebay_sold{$item}{'title'}) for $ebay_sold{$item}{'sale_price'} to $ebay_sold{$item}{'buyer'}";
        }
    }
    print_log "eBay: You have sold $count items.";
}

if ( done_now $p_ebay_unsold) {
    my $lastitem = 0;
    if ( $ebay_unsold{'populated'} ) {
        %last_ebay_unsold = %ebay_unsold;
    }
    %ebay_unsold = ();
    $ebay_unsold{'populated'} = 1;
    foreach ( $f_ebay_unsold->read_all() ) {
        $lastitem =
          &parse_ebay_html_line( $lastitem, \%ebay_unsold, $_, 'unsold' );
        if ( $lastitem eq 'NOT LOGGED IN' ) {
            %ebay_unsold = ();
            last;
        }
    }
    my $count = 0;
    foreach my $item ( keys %ebay_unsold ) {
        next if $item eq 'populated';
        $count++;
        foreach ('title') {
            unless ( defined( $ebay_unsold{$item}{$_} ) ) {
                &report_ebay_error(
                    "Parse error for item $item, value '$_' not found!");
            }
        }
        if ( $last_ebay_unsold{'populated'} and not $last_ebay_unsold{$item} ) {

            # New item showed up
            speak(
                rooms      => 'all',
                importance => 'notice',
                text =>
                  "e-Bay Notice: You did not sell item '$ebay_unsold{$item}{'title'}'"
            );
            print_log
              "You did not sell eBay item $item ($ebay_unsold{$item}{'title'})";
        }
    }
    print_log "eBay: You have not sold $count items.";
}

if ( done_now $p_ebay_lost) {
    my $lastitem = 0;
    if ( $ebay_lost{'populated'} ) {
        %last_ebay_lost = %ebay_lost;
    }
    %ebay_lost = ();
    $ebay_lost{'populated'} = 1;
    foreach ( $f_ebay_lost->read_all() ) {
        $lastitem = &parse_ebay_html_line( $lastitem, \%ebay_lost, $_, 'lost' );
        if ( $lastitem eq 'NOT LOGGED IN' ) {
            %ebay_lost = ();
            last;
        }
    }
    my $count = 0;
    foreach my $item ( keys %ebay_lost ) {
        next if $item eq 'populated';
        $count++;
        foreach ('title') {
            unless ( defined( $ebay_lost{$item}{$_} ) ) {
                &report_ebay_error(
                    "Parse error for item $item, value '$_' not found!");
            }
        }
        if ( $last_ebay_lost{'populated'} and not $last_ebay_lost{$item} ) {

            # New item showed up
            speak(
                rooms      => 'all',
                importance => 'important',
                text =>
                  "e-Bay Notice: You did not win item '$ebay_lost{$item}{'title'}'"
            );
            print_log
              "You did not win eBay item $item ($ebay_lost{$item}{'title'})";
        }
    }
    print_log "eBay: You have not won $count items.";
}

if ( $New_Hour and $config_parms{eBay_feedback_nag} ) {
    foreach my $item ( keys %ebay_sold ) {
        next if $item eq 'populated';
        if ( $ebay_sold{$item}{'feedback_received'}
            and not $ebay_sold{$item}{'feedback_left'} )
        {
            speak(
                rooms      => 'all',
                importance => 'notice',
                text =>
                  "e-Bay Feedback Reminder: You have received feedback for item '$ebay_sold{$item}{'title'}' but have not left any yourself"
            );
            print_log
              "You have received feedback for eBay item $item ($ebay_sold{$item}{'title'}) but have not left any yourself";
        }
    }
    foreach my $item ( keys %ebay_won ) {
        next if $item eq 'populated';
        if ( $ebay_won{$item}{'feedback_received'}
            and not $ebay_won{$item}{'feedback_left'} )
        {
            speak(
                rooms      => 'all',
                importance => 'notice',
                text =>
                  "e-Bay Feedback Reminder: You have received feedback for item '$ebay_won{$item}{'title'}' but have not left any yourself"
            );
            print_log
              "You have received feedback for eBay item $item ($ebay_won{$item}{'title'}) but have not left any yourself";
        }
    }
}
