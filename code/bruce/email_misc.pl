
# Send comic email once a day

#$p_resize_comic = new Process_Item;

if (time_cron '2 5 * * *') {
    my $file = sprintf "../../web/comics/Doonesbury-%4d.%02d.%02d.gif", $Year, $Month, $Mday;
#    set $p_resize_comic "convert -resize 1000x600 $file /tmp/comic.png";
#    start $p_resize_comic;
#}
#
#if (done_now $p_resize_comic) {
    &net_mail_send(subject => "Doonesbury for " . time_date_stamp(),
		   file => $file,
		   debug => 1);
}

