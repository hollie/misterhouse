# Category = Entertainment

#@ Retrieves David Letterman's Top 10 List.

# An example on how to get and process html from the net

#noloop=start
my $f_top10_list = "$config_parms{data_dir}/web/top10_list.txt";
my $f_top10_html = "$config_parms{data_dir}/web/top10_list.html";

#noloop=stop

$p_top10_list = new Process_Item(
    "get_url http://www.cbs.com/latenight/lateshow/top_ten/ $f_top10_html");

# *** Split these up for security (allow anyone to read)

$v_top10_list = new Voice_Cmd('[Get,Read,Check] the top 10 list');
$v_top10_list->set_info("This is David Letterman's famous Top 10 List");

if ( 'Read' eq said $v_top10_list) {
    my $text = file_read $f_top10_list;
    $v_top10_list->respond("app=top10 $text");
}
else {

    my $state = said $v_top10_list;

    if ( $state eq 'Get' or $state eq 'Check' ) {
        if (&net_connect_check) {
            $v_top10_list->respond(
                "app=top10 Retrieving Top 10 list from the Internet...");
            start $p_top10_list;
        }
        else {
            $v_top10_list->respond(
                "app=top10 Cannot retrieve Top 10 list while disconnected from the Internet."
            );
        }
    }

}

if ( done_now $p_top10_list) {
    my $html = file_read $f_top10_html;

    #   my $text = HTML::FormatText->new(lm => 0, rm => 150)->format(HTML::TreeBuilder->new()->parse($html));

    my $text = &html_to_text($html);

    # Delete &nbsb
    $text =~ s/\240/ /g;

    # Delete text preceeding the list
    #<tr valign="top"><td width="290" valign="top" align="center"><font class="toptentitle">Top Ten Signs You've Hired A Bad NFL Referee</font></td></tr>
    #   $text =~ s/^.+?the Top Ten List for/The Top Ten list for/is;
    #   $text =~ s/^.+?Top Ten/Top Ten/is;
    $text =~ s/^.+(Top Ten.+?.+10\.)/$1/is;

    # Delete data past the last line: 1. xxxxx\n
    $text =~ s/(.+?\n\s *1\..+?)\n.+/$1\n/s;

    #$text =~ s/\n//g;
    # Add a period at the end of line, if needed
    $text =~ s/([^\.\!\?\n])\n/$1\.\n/g;

    #	     s/([^\.\!\?])$/$1\./g
    # Drop the (name) at the end of each line (name of presentor)
    $text =~ s/\(.+?\)[ \.]+\n/\n/g;

    # Only one blank line per item.
    $text =~ s/\n\s+\n/\n\n/g;

    # Make sure the number at the beginning as a space.
    $text =~ s/(\n[\d]+)\.?/$1\. /g;

    file_write( $f_top10_list, $text );

    if ( $v_top10_list->{state} eq 'Check' ) {
        $v_top10_list->respond("app=top10 connected=0 important=1 $text");
    }
    else {
        $v_top10_list->respond("app=top10 connected=0 Top 10 list retrieved.");
    }
}

if ($Reload) {
    if ( $Run_Members{'internet_dialup'} ) {
        &trigger_set(
            "state_now \$net_connect eq 'connected'",
            "run_voice_cmd 'Get the Top 10 List'",
            'NoExpire',
            'get top 10 list'
        ) unless &trigger_get('get top 10 list');
    }
    else {
        &trigger_set(
            "time_cron '30 6 * * *' and net_connect_check",
            "run_voice_cmd 'Get the Top 10 List'",
            'NoExpire',
            'get top 10 list'
        ) unless &trigger_get('get top 10 list');
    }
}
