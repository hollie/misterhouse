# Category=Other

# tini is a serial/ibutton <-> tcpip interface
# More tini info at: 
#   http://www.ibutton.com/TINI/index.html
#
# This is not all that useful yet.  


                                # Periodically probe a Dallas Semi. TINI server for data

my $f_tini_web_html = "$config_parms{data_dir}/web/tini.html";
my $f_tini_web_data = "$config_parms{data_dir}/web/tini.data";
$p_tini_web = new Process_Item("get_url http://192.168.0.100 $f_tini_web_html");
$v_tini_web = new  Voice_Cmd('[Get,Read] TINI web data');
$v_tini_web-> set_info('This is not useful yet');

if (said $v_tini_web eq 'Get') {
    print_log "Tini data requested";
    start $p_tini_web;
}

if (done_now $p_tini_web) {
    my $html = file_read $f_tini_web_html;
    my ($temp, $time) = $html =~ / temperature (\S+).+ time (\S+)/;
    file_write($f_tini_web_data, "TINI time was $time, temperature was $temp");
    speak $f_tini_web_data;
}

speak $f_tini_web_data if said $v_tini_web eq 'Read';

