
=begin comment

NAME         : rss_logs.pl
AUTHOR       : amauri viguera (amauri@viguera.net)
DESCRIPTION  : Create rss "feeds" for print, error and phone logs.

The module only creates the xml files, which should be rss compliant.  

Tested with Booby, DesktopSidebar, Mozilla, FeedReader, and Bloglines.
Mozilla's rss reader sidebar seems to cache the entries regardless, at least under win32.
Booby seems to like caching even though magpie's cache is turned off. * shrug *

MH.ini parameters :
 - rss_maxitems=[integer]
    max number of items to process in the log (helpful for those HUGE files :)
 - rss_image=[url]
    url to the image used for the feed.
 - debug=rss on your private ini will enable progress chatter 

To allow access from external readers, add rss_logs.pl to your data_dir/password_allow file.

For the sake of simplicity, this module requires XML::RSS. 
I'm sure that there are many more ways of doing this, and that the XML produced
is not 100% compliant, but considering what it's used for at least it's not all
that bad, is it? :)

Point your RSS reader to urls like this:

   http://localhost:8080/bin/rss_logs.pl?phone
   http://localhost:8080/bin/rss_logs.pl?speak
   http://localhost:8080/bin/rss_logs.pl?print (default)

You must enable the phone_logs.pl common code script before you can view the 
phone logs rss feed.   

If you want static files, (e.g. serving files from another web server), you can
create static xml feeds with code like this:

 if (time_cron('55,25 * * * *')) {
   file_write "$config_parms{data_dir}/web/rss_phone.xml", &html_file(undef, '../web/bin/rss_logs.pl', 'phone', 1);
   file_write "$config_parms{data_dir}/web/rss_speak.xml", &html_file(undef, '../web/bin/rss_logs.pl', 'speak', 1);
   file_write "$config_parms{data_dir}/web/rss_print.xml", &html_file(undef, '../web/bin/rss_logs.pl', 'print', 1);
 }


=cut

print "rss_logs.pl: args=@ARGV\n" if $Debug{rss};

my ( $log, $article ) = @ARGV;

use vars '%rss_logs_data';

if ($article) {
    return &html_page( "RSS $log article $article",
        "Log: $log<br>Article: $article<br>$rss_logs_data{$log}{$article}" );
}
else {
    return &rss_log($log);
}

sub rss_log {
    my ($log) = @_;

    # take off the cache buster added by google gadgets
    $log =~ s/\?.*//;
    $log = "print" unless $log;

    $config_parms{rss_maxitems} = 100 unless $config_parms{rss_maxitems};
    $config_parms{rss_image} = "http://misterhouse.sourceforge.net/mh_logo.gif"
      unless $config_parms{rss_image};
    $config_parms{rss_image} =
        "http://$config_parms{http_server}"
      . ":$config_parms{http_port}/ia5/images/mhlogo.gif"
      if $config_parms{http_server}
      and $config_parms{http_port}
      and not $config_parms{rss_image};

    use XML::RSS;
    my $rss = new XML::RSS( version => '2.0' );
    $rss->channel(
        title => "mh $log log",
        link  => "http://$config_parms{http_server}:$config_parms{http_port}",

        #                 pubDate      => &time2str(),   # RFC 822 format
        description => "misterhouse $log log feed"
    );

    # might be a good idea to leave this out until you have a suitable image
    # depending on the aggregator, this might not even be rendered, but consider yourself warned :)
    $rss->image(
        title       => 'misterhouse',
        url         => $config_parms{rss_image},
        link        => 'http://misterhouse.net',
        width       => 88,
        height      => 31,
        description => 'misterhouse'
    );

    # still working on the link for each item. can we follow this particular item for more detail?
    # maybe hook up phone number entry -> address book lookup, etc. obviously TODO
    my $rss_link =
      "http://$config_parms{http_server}:$config_parms{http_port}/bin/rss_logs.pl?$log&";

    print "\tparsing $log log\n" if $Debug{rss};
    my $article = 0;
    if ( $log eq 'phone' ) {

        # Copied from phone_in.pl.
        my @logs = &read_phone_logs1('callerid');
        my @calls = &read_phone_logs2( 100, @logs );

        # Create rss item from each line in log
        for my $r (@calls) {
            $article++;
            my ( $time_date, $num, $name, $line, $type ) =
              $r =~ /date=(.+) number=(.+) name=(.+) line=(.*) type=(.*)/;
            ( $time_date, $num, $name ) = $r =~ /(.+\d+:\d+:\d+) (\S+) (.+)/
              unless $name;
            next unless $num;
            my $time_date2 = &str2time($time_date);
            my $time_date3 = &time2str($time_date2);    # RFC 822 format

            #           print "db t=$time_date t2=$time_date2 t3=$time_date3\n";
            $rss->add_item(
                title   => $time_date,
                link    => $rss_link . $article,
                pubDate => $time_date3,
                description =>
                  "Incoming call from $num ($name). line=$line type=$type."
            );
            $rss_logs_data{$log}{$article} = $r;
            last if $article >= $config_parms{rss_maxitems};
        }
    }
    else {
        # Reverse logdata to show newest items first
        for
          my $line ( reverse file_read "$config_parms{data_dir}/logs/$log.log" )
        {
            next unless $line;
            $article++;
            my ( $time_date, $data ) = $line =~ /(.+ [AP]M) (.+)$/;
            my $time_date2 = &str2time($time_date);
            my $time_date3 = &time2str($time_date2);    # RFC 822 format

            # still undecided on the format...
            # right now the easiest way is date/time and a snippet for the title
            # and the rest of the line (complete log entry) in the description.
            # Many more properties can be added to each item. look at XML::RSS for info
            my $title = "$time_date :: " . substr( $data, 0, 30 );
            $rss->add_item(
                title       => $title,
                link        => $rss_link . $article,
                pubDate     => $time_date3,
                description => $data
            );
            $rss_logs_data{$log}{$article} = $line;
            last if $article >= $config_parms{rss_maxitems};
        }
    }

    print "completed processing log file. processed $article items.\n"
      if $Debug{rss};

    my $xml = $rss->as_string;

    # These are examples of including style sheets so browsers can browse formated feeds ... maybe not a good idea?
    #   my $style = '<?xml-stylesheet type="text/xsl" href="/rss10.xsl"?>';
    #   my $style = '<?xml-stylesheet type="text/css" href="http://www.blogger.com/styles/atom.css"?>';
    #   $xml =~ s/^(\<\?xml .+)/$1\n$style\n/;
    print "db xml=$xml\n" if $Debug{rss};

    return &mime_header( 'xml', 0, length $xml ) . $xml;
}
