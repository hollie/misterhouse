# Category = Entertainment

#@ Retrieves David Letterman's Top 10 List.

				# An example on how to get and process html from the net ... Lettermans top 10 list

my $f_top10_list = "$config_parms{data_dir}/web/top10_list.txt";
my $f_top10_html = "$config_parms{data_dir}/web/top10_list.html";

#$f_top10_html2 = new File_Item($f_top10_html); # Needed if we use run instead of process_item

#p_top10_list = new Process_Item("get_url http://marketing.cbs.com/lateshow/topten/ $f_top10_html");
#p_top10_list = new Process_Item("get_url http://marketing.cbs.com/network/tvshows/mini/lateshow/index.shtml $f_top10_html");
#p_top10_list = new Process_Item("get_url http://marketing.cbs.com/latenight/lateshow/# $f_top10_html");
#p_top10_list = new Process_Item("get_url http://www.cbs.com/latenight/lateshow/# $f_top10_html");
$p_top10_list = new Process_Item("get_url http://www.cbs.com/latenight/lateshow/top_ten/ $f_top10_html");

$v_top10_list  = new  Voice_Cmd('[Get,Read,Show] the top 10 list');
$v_top10_list -> set_info("This is David Lettermans famoust Top 10 List"); 

                                # Allow for an open access action
$v_top10_list2 = new  Voice_Cmd('{Display,What is} the top 10 list');
$v_top10_list2-> set_info("This is David Lettermans famoust Top 10 List"); 
$v_top10_list2-> set_authority('anyone');
$v_top10_list2-> tie_items($v_top10_list, 1, 'Show');

$state = said $v_top10_list;
speak    app => 'top10', text => $f_top10_list, display => 0 if $state eq 'Read';
respond  app => 'top10', text => $f_top10_list, time => 300, font => 'Times 25 bold', geometry => '+0+0', width => 72, height => 24
  if $state eq 'Show' or $state eq 'Read';


if (said $v_top10_list eq 'Get') {
                                # Do this only if we the file has not already been updated today and it is not empty
    if (-s $f_top10_html > 10 and
        time_date_stamp(6, $f_top10_html) eq time_date_stamp(6)) {
        print_log "Top 10 list is current";
#       set $v_top10_list 'Show';
        start $p_top10_list 'do_nothing';  # Fire the process with no-op, so we can still run the parsing code for debug
    }
    else {
        if (&net_connect_check) {
            print_log "Retrieving top10 list from the net ...";

                                # Use start instead of run so we can detect when it is done
            start $p_top10_list;
#           run "get_url http://marketing.cbs.com/lateshow/topten/ $f_top10_html";
#           set_watch $f_top10_html2;

#           $html = get 'http://marketing.cbs.com/lateshow/topten';
#           file_write("$config_parms{data_dir}/web/top10_list.html", $html);
        }
        else {
            speak "Sorry, you must be logged onto the net";
        }
    }            
    $leave_socket_open_passes = 200; # Tell web browser to wait for respond
}

if (done_now $p_top10_list) {
    my $html = file_read $f_top10_html;

    my $text = HTML::FormatText->new(lm => 0, rm => 150)->format(HTML::TreeBuilder->new()->parse($html));

                                # Delete &nbsb
    $text =~ s/\240/ /g;

                                # Delete text preceeding the list
#<tr valign="top"><td width="290" valign="top" align="center"><font class="toptentitle">Top Ten Signs You've Hired A Bad NFL Referee</font></td></tr>
#   $text =~ s/^.+?the Top Ten List for/The Top Ten list for/is;
#   $text =~ s/^.+?Top Ten/Top Ten/is;
    $text =~ s/^.+(Top Ten.+?.+10\.)/$1/is;

                                # Delete data past the last line: 1. xxxxx\n
    $text =~ s/(.+?\n\s *1\..+?)\n.+/$1\n/s;
                                # Add a period at the end of line, if needed
    $text =~ s/([^\.\?\!])\n/$1\.\n/g;
                                # Drop the (name) at the end of each line (name of presentor)
    $text =~ s/\(.+?\)[ \.]+\n/\n/g;
                                # Only one blank line per item.
    $text =~ s/\n\s+\n/\n\n/g;
                                # Make sure the number at the beginning as a space.
    $text =~ s/(\n[\d]+)\.?/$1\. /g;

    file_write($f_top10_list, $text);

    set $v_top10_list 'Show';
}

