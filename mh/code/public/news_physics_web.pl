#Category=News
#  Physics Web News Stories Archive
my $f_physics_web = "$config_parms{data_dir}/web/physics_web.txt";
my $f_physics_web_html = "$config_parms{data_dir}/web/physics_web.html";

#$f_physics_web2_html2 = new File_Item($f_physics_web2_html); # Needed if we use run instead of process_item

$p_physics_web = new Process_Item("get_url http://physicsweb.org/archive/news $f_physics_web_html");
$v_physics_web = new  Voice_Cmd('[Get,Read,Show] physics_web');

speak($f_physics_web)   if said $v_physics_web eq 'Read';
display($f_physics_web) if said $v_physics_web eq 'Show';

if (said $v_physics_web eq 'Get') {

    # Do this only if we the file has not already been updated today and it is not empty
    if (0 and -s $f_physics_web_html > 10 and
        time_date_stamp(6, $f_physics_web_html) eq time_date_stamp(6)) {
        print_log "physics_web news is current";
        display $f_physics_web;
    }
    else {
        if (&net_connect_check) {
            print_log "Retrieving Physics Web News Stories from the net ...";

            # Use start instead of run so we can detect when it is done
            start $p_physics_web;
        }        
    }            
}

if (done_now $p_physics_web) {
    my $html = file_read $f_physics_web_html;                           
    my ( $text, $count);

    $text = "Physics Web News items: \n";
    for (file_read "$f_physics_web_html") {

#	if (m!<a href=.+of News';return true;">(<font color=blue>)??(\w)+</!){
#		$text .= "$1\n";
#		$text =~ s!</?\w>!!g;
#	}
	

#	if ((m!(\[\d.+)<\w>!)and $count <3){
	if ((m!(\[\d.+)!)and $count <3){
		$text .= "$1\n";
		$text =~ s!</?\w>!!g;
		$count++;
	}
  
      }
    $text =~ s![/[|\]]!!g;
    $text =~ s!\(.+\)!!g;
    file_write($f_physics_web, $text);
    display $f_physics_web;
}

