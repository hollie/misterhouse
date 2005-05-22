# Category = Media

#@ Use this script to automatically download torrent files for your favorite TV shows.  
#@ Works well with btlauchmany.py, which is part of the <a href=http://www.bittorrent.com/>standard bittorrent package</a>.
#@ This script could probably easily be modified to also download podcasts.

# 03/14/05 created by David Norwood (dnorwood2@yahoo.com)					

use XML::RAI;

	
my $feeds = 'http://unrealtorrents.com/rss.php,http://www.btefnet.com/backend.php,http://arctangent.net/~formatc/dd.rss,http://torrentspy.com/rss.asp';
my $regexps = 'family.guy,daily.show';
my $torrent_dir = "$config_parms{data_dir}/videos";
my $rss_dbm_file ="$config_parms{data_dir}/rss_file_downloads.dbm";

$p_rss_file_feed = new Process_Item;
$p_rss_file_download = new Process_Item;
$v_rss_file_feed =  new  Voice_Cmd('Get RSS subscribed files');
$v_rss_file_feed -> set_authority('anyone');

if ($Reload) {
	$v_rss_file_feed->set_icon('nostat.gif');
	$feeds = $config_parms{rss_file_feeds} if $config_parms{rss_file_feeds};
	$regexps = $config_parms{rss_file_regexps} if $config_parms{rss_file_regexps};
	$torrent_dir = "$config_parms{torrent_dir}" if "$config_parms{torrent_dir}";
	mkdir "$torrent_dir", 0777 unless -d "$torrent_dir";
	$Included_HTML{'Media'} .= '<!--#include code="&rss_update_html"-->' . "\n\n\n";
}

if (state_now $v_rss_file_feed) {
	my ($i, @cmds);
	foreach (split ',', $feeds) {
		$i++;
		push @cmds, "get_url '$_' $config_parms{data_dir}/rss_feed_$i.xml";
		unlink "$config_parms{data_dir}/rss_feed_$i.xml";
	}
	set $p_rss_file_feed @cmds;
	start $p_rss_file_feed;
}

if (done_now $p_rss_file_feed) {
	my ($i);
	foreach (split ',', $feeds) {
		$i++;
		&rss_file_process($_, "$config_parms{data_dir}/rss_feed_$i.xml");
	}
}

my (@rss_file_download_queue, $current_file);
if (done_now $p_rss_file_download) {
	dbm_write($rss_dbm_file, $current_file, time) if -f "$torrent_dir/$current_file" and not -z "$torrent_dir/$current_file";
}

if (done $p_rss_file_download and @rss_file_download_queue) { 
	my $args = shift @rss_file_download_queue;
	($current_file) = $args =~ /^.*\/(.*?)'$/;
	set $p_rss_file_download 'get_url ' . $args; 
	start $p_rss_file_download;
	print_log "getting $current_file";
}

	
sub rss_file_process {
	my $url = shift;
	my $xml = shift;
	my $list; 
	@{$list->{data}} = ();
	my @itemslist = ();
	return unless -f $xml;
	my $first = file_read $xml; 
	$first = file_read $xml; 
	unless ($first =~ /\<\?xml/i or $first =~ /\<rss/i) {
		print_log "$xml does not appear to be an XML file";
		return; 
	}
	my $feed = XML::RAI->parsefile($xml);
	my $count = $feed->item_count();
	print_log "Loaded $count item(s) from RSS feed $xml";
	foreach my $item ( @{$feed->items} ) {
		my $title = $item->title;
		my $issued = $item->issued;
		my $link = $item->link;
		@itemslist = ( @itemslist, [ $title, $issued, $link ], );
		foreach my $regexp (split(",", $regexps)) {
			if ($title =~ /$regexp/xi) {
# print "$title $issued $link r=$regexp[$e]\n";
				if ($link =~ /\.torrent/i) {
					my $file = "$title.torrent";
					$file =~ s/'//g;
					unless (read_dbm($rss_dbm_file, $file)) {
						push @rss_file_download_queue, "'$link' '$torrent_dir/$file'";
						print_log "queued $file";
					}
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
        &trigger_set('\$New_Hour and net_connect_check', "run_voice_cmd 'Get RSS subscribed files'", 'NoExpire', 'get rss files') 
          unless &trigger_get('get rss files');
    );
}
