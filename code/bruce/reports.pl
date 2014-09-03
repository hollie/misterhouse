# Category=Informational

#@ Generate gif files of mh server log files, showing number of hits and users.
#@  - requires gnuplot (see report_weblog for a pointer).

$v_report_weblog = new Voice_Cmd('Generate weblog reports');
$v_report_weblog->set_info(
    'Run report_weblog to summarize hits on the mh web server.  This is automatically run once a day'
);
$p_report_weblog = new Process_Item;

if ( said $v_report_weblog or time_now '5:05 AM' ) {
    print_log "Running report_weblog";
    set $p_report_weblog
      "report_weblog -ignore none -outdir $config_parms{data_dir}/logs -runid mh_month $config_parms{data_dir}/logs/server_http.$Year_Month_Now.log";
    start $p_report_weblog;
}

if ( done_now $p_report_weblog) {
    print_log "Copying weblog reports";
    copy( "$config_parms{data_dir}/logs/mh_month_dayhour.png",
        "//misterhouse/projects/logs" );
    copy( "$config_parms{data_dir}/logs/mh_month_day.png",
        "//misterhouse/projects/logs" );
    run "$config_parms{browser} http://misterhouse.net/stats.html";
}
