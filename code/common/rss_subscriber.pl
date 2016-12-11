# Category = Media

#@ Use this script to automatically download enclosures in RSS feeds (like podcasts) or
#@ torrent files for your favorite TV shows.
#@ Works well with btlauchmany.py, which is part of the <a href=http://www.bittorrent.com/>standard bittorrent package</a>.
#@ Item titles in the RSS file must match one of the comma separated regular expressions
#@ in the rss_file_regexps ini parameter in order to be downloaded.
#@ Use the rss_file_regexps_reject ini parameter to specify patterns you want to reject.
#@ Alternatively, you can specify a regular expression that applies to a particular feed
#@ by appending a space and the pattern to the feed address in the rss_file_feeds ini parameter.
#@ All files are downloaded to the directory specified by the torrent_dir ini parameter
#@ or you can specify a directory that applies to a particular feed by appending a space
#@ and a directory after the optional regular expression field in the feed entries.
#@ To modify when this script is run (or to disable it), go to the
#@ <a href=/bin/triggers.pl>triggers page</a>
#@ and modify the 'get rss files' trigger.
#@ See <a href=/list?Media>The Media Category Page</a> for a summary of the feeds.

# 03/14/05 created by David Norwood (dnorwood2@yahoo.com)
# 09/23/05 added support for podcasts and other feeds with enclosures (dnorwood2@yahoo.com)
# 12/23/05 fixed a bug parsing the feed list (dnorwood2@yahoo.com)
# 02/19/06 added support for individual directories for each feed (dnorwood2@yahoo.com)
# 06/09/06 added feed summary web page, other minor changes (dnorwood2@yahoo.com)
# 07/22/06 feeds are now processed in the background on *nix, so Misterhouse doesn't pause (dnorwood2@yahoo.com)

use XML::RAI;
use XML::RAI::Enclosure;

my $rss_feeds = '
	http://torrentbox.com/rssfeed.php,
	http://www.mininova.org/rss.xml?cat=8,
	http://seedler.org/en/rss.xml bullshit,
	http://newtorrents.info/rss.php?cat=tv,
	http://arctangent.net/~formatc/dd.rss,
	http://torrentspy.com/rss.asp,
	http://del.icio.us/rss/popular/system:media:video .,
';

#	http://www.torrentportal.com/rssfeed.php?cat=3,
#	http://isohunt.com/js/rss.php?ihq=bullshit+&op=and&iht=,

#noloop=start
my @feeds;
my $regexps        = 'family.guy,daily.show';
my $regexps_reject = 'spanish,french,perditos,season';
my $rss_dbm_file   = "$config_parms{data_dir}/rss_file_downloads.dbm";

$p_rss_file_feed     = new Process_Item;
$p_rss_file_download = new Process_Item;
$v_rss_file_feed     = new Voice_Cmd('Get RSS subscribed files');
$v_rss_file_feed->set_authority('anyone');

$regexps_reject = $config_parms{rss_file_regexps_reject}
  if $config_parms{rss_file_regexps_reject};
$v_rss_file_feed->set_icon('nostat.gif');
$rss_feeds = $config_parms{rss_file_feeds} if $config_parms{rss_file_feeds};
$rss_feeds =~ s/^\s*//;
@feeds = split /\s*,\s*/, $rss_feeds;
$Included_HTML{'Media'} .= '<!--#include code="&rss_update_html"-->' . "\n\n\n";

#noloop=stop

if ( state_now $v_rss_file_feed) {
    my ( $i, @cmds );
    foreach my $feed (@feeds) {
        $i++;
        my ( $link, $regex ) = split /\s+/, $feed;
        push @cmds, "get_url '$link' $config_parms{data_dir}/rss_feed_$i.xml";
        unlink "$config_parms{data_dir}/rss_feed_$i.xml";
    }
    set $p_rss_file_feed @cmds;
    $v_rss_file_feed->respond('app=syndicate Retrieving syndicated feeds...');

    start $p_rss_file_feed;
}

$p_rss_file_process_all = new Process_Item "&rss_file_process_all";
if ( done_now $p_rss_file_feed) {
    &rss_file_process_all;

    #	$OS_win ? &rss_file_process_all : start $p_rss_file_process_all;
}

my ( @rss_file_download_queue, $current_file );
if ( done_now $p_rss_file_download) {
    dbm_write( $rss_dbm_file, $current_file, time )
      if -f "$current_file" and not -z "$current_file";
}

$p_rss_file_download->stop if $Reload;

if ( @rss_file_download_queue and done $p_rss_file_download) {
    my $args = shift @rss_file_download_queue;
    ($current_file) = $args =~ /^.* \'(.*?)'$/;
    set $p_rss_file_download 'get_url ' . $args;
    start $p_rss_file_download;
    print_log "getting $current_file";
}

sub rss_file_process_all {
    my $i;
    foreach my $feed (@feeds) {
        $i++;
        my ( $link, $regex, $dir ) = split /\s+/, $feed;
        &rss_file_process( $link, "$config_parms{data_dir}/rss_feed_$i.xml",
            $regex, $dir );
    }
    $v_rss_file_feed->respond(
        'app=syndicate connected=0 Feed processing completed.');
}

sub rss_file_process {
    my $url = shift;
    my $xml = shift;
    my $reg = shift;
    my $dir = shift;
    $regexps = $config_parms{rss_file_regexps}
      if $config_parms{rss_file_regexps};
    $regexps = $reg if $reg;
    my $torrent_dir = "$config_parms{data_dir}/videos";
    $torrent_dir = "$config_parms{torrent_dir}" if "$config_parms{torrent_dir}";
    $torrent_dir =~ s/\/$//;
    $torrent_dir .= '/' . $dir if $dir and $dir !~ /^\//;
    $torrent_dir = $dir if $dir and $dir =~ /^\//;
    mkdir "$torrent_dir", 0777 unless -d "$torrent_dir";
    my $list;
    @{ $list->{data} } = ();
    my @itemslist = ();
    return unless -f $xml;
    my $first = file_head $xml, 3;

    unless ( $first =~ /\<\?xml/i or $first =~ /\<rss/i ) {
        print_log "$xml does not appear to be an XML file";
        return;
    }
    my $tmp = file_read $xml;
    $tmp =~ s/\<\/item\>\<item\>/\<\/item\>\n\<item\>/gi;
    my $feed;
    print_log($@), return unless eval '$feed = XML::RAI->parse($tmp)';
    my $count = $feed->item_count();
    print_log "Loaded $count item(s) from RSS feed $xml";
    my ( $db, %DBM );
    $db = tie( %DBM, 'DB_File', $rss_dbm_file )
      or print "\nError, can not open dbm file $rss_dbm_file: $!";

    foreach my $item ( @{ $feed->items } ) {
        my $title  = $item->title;
        my $issued = $item->issued;
        my $link   = $item->link;
        my $file;

        # Handle items with enclosure(s), like podcasts
        foreach my $regexp ( split( ",", $regexps ) ) {
            if ( $title =~ /$regexp/xi and not &check_regexps_reject($title) ) {
                foreach my $enc ( XML::RAI::Enclosure->load($item) ) {
                    $link = $enc->url;
                    ($file) = $link =~ /.*\/(.+?)$/;
                    $file =~ s/\.mp3\?(.+)/$1.mp3/;

                    # fix for mininova
                    $file = "$title.torrent" if $file =~ /^\d+$/;
                    print_log "$file currently downloading"
                      if $current_file eq "$torrent_dir/$file";
                    print_log "$file already downloaded"
                      if $DBM{"$torrent_dir/$file"};
                    print_log "$file already queued"
                      if grep { $_ eq "'$link' '$torrent_dir/$file'" }
                      @rss_file_download_queue;
                    unless ( $current_file eq "$torrent_dir/$file"
                        or $DBM{"$torrent_dir/$file"}
                        or grep { $_ eq "'$link' '$torrent_dir/$file'" }
                        @rss_file_download_queue )
                    {
                        push @rss_file_download_queue,
                          "'$link' '$torrent_dir/$file'";
                        print_log "queued $file";
                    }
                    $link = "";
                }
            }
        }
        next unless $link;

        # Assume items without enclosures are torrent files
        @itemslist = ( @itemslist, [ $title, $issued, $link ], );
        foreach my $regexp ( split( ",", $regexps ) ) {
            if ( $title =~ /$regexp/xi and not &check_regexps_reject($title) ) {

                # hack to fix isohunt's links
                $link =~
                  s|rss.isohunt.com/btDetails.php\?ihq=.*\&id=|isohunt.com/download.php?mode=bt&id=|;
                $link =~ s|isohunt.com/torrent_details|isohunt.com/download|;

                # hack to fix torrentportal's links
                $link =~
                  s|torrentportal.com/details/|torrentportal.com/download/|;

                # hack to fix torrentspy's links
                $link =~
                  s|torrentspy.com/torrent/(\d+)/.*|torrentspy.com/download.asp?id=$1|;

                # hack to fix newtorrents' links
                $link =~
                  s|newtorrents.info/torrent/(\d+)/.*|newtorrents.info/down.php?id=$1|;

                # hack to fix seedler's links
                $link =~
                  s|seedler.org/en/html/info/|seedler.org/download.x?id=|;

                # hack to fix isohunt's links
                $link =~
                  s|isohunt.com/btDetails.php.*id=|isohunt.com/dl.php?id=|;

                # hack to fix mininova's links
                $link =~ s|mininova.org/tor/|mininova.org/get/|;

                # hack to fix some bad links, can't use &escape because most are already escaped
                $link =~ s/ /+/g;
                $link =~ s/\'/%27/g;
                my $file = "$title.torrent";

                # Remove or escape problematic filename characters
                $file =~ s/\[/\(/ if $file =~ /car talk/i;
                $file =~ s/\]/\)/ if $file =~ /car talk/i;
                $file =~ s/ *\[.*?\] *//g;
                $file =~ s/\// - /g;
                $file =~ s/\?//g;
                $file =~ s/\(/\[/g;
                $file =~ s/\)/\]/g;
                $file =~ s/'//g;
                $file =~ s/"//g;
                $file =~ s/\|//g;
                $file =~ s/\://g;
                $file =~ s/\?//g;
                $file =~ s/ +$//g;
                print_log "$file currently downloading"
                  if $current_file eq "$torrent_dir/$file";
                print_log "$file already downloaded"
                  if $DBM{"$torrent_dir/$file"};
                print_log "$file already queued"
                  if grep { $_ eq "'$link' '$torrent_dir/$file'" }
                  @rss_file_download_queue;

                unless ( $current_file eq "$torrent_dir/$file"
                    or $DBM{"$torrent_dir/$file"}
                    or grep { $_ eq "'$link' '$torrent_dir/$file'" }
                    @rss_file_download_queue )
                {
                    push @rss_file_download_queue,
                      "'$link' '$torrent_dir/$file'";
                    print_log "queued $file";
                }
            }
        }
    }
    @{ $list->{data} } = (@itemslist);
    untie $db;
}

sub check_regexps_reject {
    my $title = shift;
    foreach my $regexp ( split( ",", $regexps_reject ) ) {
        if ( $title =~ /$regexp/xi ) {
            return 1;
        }
    }
    return 0;
}

sub rss_update_html {
    my $i;
    my $html;
    foreach my $feed (@feeds) {
        $i++;
        my ( $link, $regex, $dir ) = split /\s+/, $feed;
        $html .=
          &rss_file_html_format( $link,
            "$config_parms{data_dir}/rss_feed_$i.xml",
            $regex, $dir );
    }
    return $html;
}

sub rss_file_html_format {
    my $url = shift;
    my $xml = shift;
    my $reg = shift;
    my $dir = shift;
    my $html;
    return "RSS feed <a href=$url>$url</a> not yet downloaded.<p>"
      unless -f $xml;
    return unless -f $xml;
    my $first = file_head $xml, 3;

    unless ( $first =~ /\<\?xml/i or $first =~ /\<rss/i ) {
        return
          "RSS feed <a href=$url>$url</a> does not appear to be an XML file.<p>";
    }
    my $tmp = file_read $xml;
    $tmp =~ s/\<\/item\>\<item\>/\<\/item\>\n\<item\>/gi;
    my $feed;
    return ($@) unless eval '$feed = XML::RAI->parse($tmp)';
    my $channel = $feed->channel;
    my $link    = $feed->channel->link;
    my $title   = $feed->channel->title;
    $html .= qq|
<table bgcolor="#000000" border="0" width="200"><tr><td>
<TABLE CELLSPACING="1" CELLPADDING="4" BGCOLOR="#FFFFFF" BORDER=0 width="100%">
  <tr>
  <td valign="middle" align="center" bgcolor="#EEEEEE"><font color="#000000" face="Arial,Helvetica"><B><a href="$link">$title</a> <a href="$url">RSS</a></B></font></td></tr>
<tr><td>
|;

    #	print_log "ch $channel->{'link'} ch $channel->link" . $feed->{'channel'}->{'link'} ;

    # print channel image
    if ( $feed->image ) {
        my $url    = $feed->image->url;
        my $height = $feed->image->height;
        my $width  = $feed->image->width;
        $html .= qq|
<center>
<p><a href="$url"><img src="$url" border="0"
|;
        $html .= " width=\"$width\""   if $width;
        $html .= " height=\"$height\"" if $height;
        $html .= "></a></center><p>\n";
    }
    my $count = $feed->item_count();
    print_log "Loaded $count item(s) from RSS feed $xml";

    # print the channel items

    foreach my $item ( @{ $feed->items } ) {
        my $title       = $item->title;
        my $issued      = $item->issued;
        my $link        = $item->link;
        my $description = $item->description;
        $title =~ s/ ?\>$//;
        $description =~ s/ ?\>$//;
        $html .= "<li><a href=\"$link\">$title</a><BR>\n";
        $html .= "$description<BR>\n" if $description;
        foreach my $enc ( XML::RAI::Enclosure->load($item) ) {
        }
    }

    $html .= qq|
</td>
</TR>
</TABLE>
</td></tr></table>
|;

    return $html;
}

# lets allow the user to control via triggers

if ($Reload) {
    &trigger_set(
        '$New_Hour and net_connect_check',
        "run_voice_cmd 'Get RSS subscribed files'",
        'NoExpire',
        'get rss files'
    ) unless &trigger_get('get rss files');
}
