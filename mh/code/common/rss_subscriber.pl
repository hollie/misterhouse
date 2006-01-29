# Category = Media

#@ Use this script to automatically download enclosures in RSS feeds (like podcasts) or 
#@ torrent files for your favorite TV shows.  
#@ Works well with btlauchmany.py, which is part of the <a href=http://www.bittorrent.com/>standard bittorrent package</a>.
#@ Item titles in the RSS file must match one of the comma separated regular expressions
#@ in the rss_regexps ini parameter in order to be downloaded. 
#@ Alternatively, you can specify a regular expression that applies to a particular feed
#@ by appending a space and the pattern to the feed address in the rss_feeds ini parameter. 
#@ All files are downloaded to the directory specified by the torrent_dir ini parameter. 
#@ To modify when this script is run (or to disable it), go to the 
#@ <a href=/bin/triggers.pl> triggers page </a>
#@ and modify the 'get rss files' trigger.

# 03/14/05 created by David Norwood (dnorwood2@yahoo.com)					
# 09/23/05 added support for podcasts and other feeds with enclosures (dnorwood2@yahoo.com)
# 12/23/05 fixed a bug parsing the feed list (dnorwood2@yahoo.com)					

use XML::RAI;
use XML::RAI::Enclosure;
        

my $rss_feeds = '
	http://arctangent.net/~formatc/dd.rss,
	http://torrentspy.com/rss.asp,
	http://isohunt.com/js/rss.php?ihq=bullshit+&op=and&iht=,
	http://del.icio.us/rss/popular/system:media:video .,
';
my @feeds;
my $regexps = 'family.guy,daily.show';
my $torrent_dir = "$config_parms{data_dir}/videos";
my $rss_dbm_file ="$config_parms{data_dir}/rss_file_downloads.dbm";

$p_rss_file_feed = new Process_Item;
$p_rss_file_download = new Process_Item;
$v_rss_file_feed =  new  Voice_Cmd('Get RSS subscribed files');
$v_rss_file_feed -> set_authority('anyone');

if ($Reload) {
	$v_rss_file_feed->set_icon('nostat.gif');
	$rss_feeds = $config_parms{rss_file_feeds} if $config_parms{rss_file_feeds};
	$rss_feeds =~ s/^\s*//;
	@feeds = split /\s*,\s*/, $rss_feeds;
	$torrent_dir = "$config_parms{torrent_dir}" if "$config_parms{torrent_dir}";
	mkdir "$torrent_dir", 0777 unless -d "$torrent_dir";
	$Included_HTML{'Media'} .= '<!--#include code="&rss_update_html"-->' . "\n\n\n";
}

if (state_now $v_rss_file_feed) {
	my ($i, @cmds);
	foreach my $feed (@feeds) {
		$i++;
		my ($link, $regex) = split /\s+/, $feed;
		push @cmds, "get_url '$link' $config_parms{data_dir}/rss_feed_$i.xml";
		unlink "$config_parms{data_dir}/rss_feed_$i.xml";
	}
	set $p_rss_file_feed @cmds;
	start $p_rss_file_feed;
}

if (done_now $p_rss_file_feed) {
	my $i;
	foreach my $feed (@feeds) {
		$i++;
		my ($link, $regex) = split /\s+/, $feed;
		&rss_file_process($link, "$config_parms{data_dir}/rss_feed_$i.xml", $regex);
	}
}

my (@rss_file_download_queue, $current_file);
if (done_now $p_rss_file_download) {
	dbm_write($rss_dbm_file, $current_file, time) if -f "$torrent_dir/$current_file" and not -z "$torrent_dir/$current_file";
}

if (done $p_rss_file_download and @rss_file_download_queue) { 
	my $args = shift @rss_file_download_queue;
	($current_file) = $args =~ /^.*\/(.*?)'$/;
print "d $args\n";
	set $p_rss_file_download 'get_url ' . $args; 
	start $p_rss_file_download;
	print_log "getting $current_file";
}

	
sub rss_file_process {
	my $url = shift;
	my $xml = shift;
	my $reg = shift;
	$regexps = $config_parms{rss_file_regexps} if $config_parms{rss_file_regexps};
	$regexps = $reg if $reg;
	my $list; 
	@{$list->{data}} = ();
	my @itemslist = ();
	return unless -f $xml;
	my $first = file_head $xml, 3; 
	unless ($first =~ /\<\?xml/i or $first =~ /\<rss/i) {
		print_log "$xml does not appear to be an XML file";
		return; 
	}
	my $tmp = file_read $xml; 
	$tmp =~ s/\<\/item\>\<item\>/\<\/item\>\n\<item\>/gi; 
	my $feed;
	print_log($@), return unless eval '$feed = XML::RAI->parse($tmp)';
	my $count = $feed->item_count();
	print_log "Loaded $count item(s) from RSS feed $xml";
	foreach my $item ( @{$feed->items} ) {
		my $title = $item->title;
		my $issued = $item->issued;
		my $link = $item->link;
		my $file;
		# Handle items with enclosure(s), like podcasts 
		foreach my $regexp (split(",", $regexps)) {
			if ($title =~ /$regexp/xi) {
				foreach my $enc (XML::RAI::Enclosure->load($item)) {
					$link = $enc->url;
					($file) = $link =~ /.*\/(.+?)$/;
					print_log "$file already downloaded" if read_dbm($rss_dbm_file, $file);
					print_log "$file already queued" if grep {$_ eq "'$link' '$torrent_dir/$file'"} @rss_file_download_queue;
					unless (read_dbm($rss_dbm_file, $file) or grep {$_ eq "'$link' '$torrent_dir/$file'"} @rss_file_download_queue) {
						push @rss_file_download_queue, "'$link' '$torrent_dir/$file'";
						print_log "queued $file";
					}
					$link = "";
				}
			}
		}
		next unless $link; 
		# Assume items without enclosures are torrent files 
		@itemslist = ( @itemslist, [ $title, $issued, $link ], );
		foreach my $regexp (split(",", $regexps)) {
			if ($title =~ /$regexp/xi) {
				# hack to fix isohunt's links 
				$link =~ s|rss.isohunt.com/btDetails.php\?ihq=.*\&id=|isohunt.com/download.php?mode=bt&id=|;
				# hack to fix torrentspy's links 
				$link =~ s/torrentspy.com\/torrent\/(\d+).*/torrentspy.com\/download.asp?id=$1/;
				$link =~ s/directory.asp\?mode=torrentdetails\&/download.asp?/;
				$link =~ s/ /+/g;
				$link =~ s/\'/%27/g;
				my $file = "$title.torrent";
				$file =~ s/\// - /g;
				$file =~ s/\(/\[/g;
				$file =~ s/\)/\]/g;
				$file =~ s/'//g;
				print_log "$file already downloaded" if read_dbm($rss_dbm_file, $file);
				print_log "$file already queued" if grep {$_ eq "'$link' '$torrent_dir/$file'"} @rss_file_download_queue;
				unless (read_dbm($rss_dbm_file, $file) or grep {$_ eq "'$link' '$torrent_dir/$file'"} @rss_file_download_queue) {
					push @rss_file_download_queue, "'$link' '$torrent_dir/$file'";
					print_log "queued $file";
				}
			}
		}
	}
	@{$list->{data}} = ( @itemslist );
}

sub rss_update_html {
}

# lets allow the user to control via triggers

if ($Reload and $Run_Members{'trigger_code'}) { 
    eval qq(
        &trigger_set('\$New_Hour and net_connect_check', 
          "run_voice_cmd 'Get RSS subscribed files'", 'NoExpire', 'get rss files') 
          unless &trigger_get('get rss files');
    );
}
