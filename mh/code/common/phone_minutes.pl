# Category = Phone

#@ Use this code file to monitor your phone minutes (currently Sprint and T-Mobile only).
#@ Set cell_phone_number (or cell_phone_username for tmobile) and cell_phone_password mh.ini parms.
#@ Set cell_phone_provider to tmobile if using T-Mobile, defaults to sprint.
#@ If not running the compiled mhe, you also must install the Crypt::SSLeay Perl module.

$p_phone_minutes =  new Process_Item;
$v_phone_minutes =  new Voice_Cmd('[Check,Read,Debug] phone minutes');
$v_phone_minutes -> set_info('Checks used and remaining cell phone minutes.');

run_voice_cmd 'Check phone minutes' if time_now '6 am';

my $tmobile_flag;

if ($state = said $v_phone_minutes) {
    if ($state eq 'Read') {
        my $msg = "You have $Save{phone_minutes_left} phone minutes left.";
        $msg .= " $Save{phone_minutes_left_day} per day for the next $Save{phone_minutes_days} days" if $Save{phone_minutes_left_day};
        speak $msg;
    }
    elsif ($state eq 'Check' and &net_connect_check) {
        my ($cmd1, $cmd2);
        if (lc $config_parms{cell_phone_provider} eq 'tmobile') {
            $cmd1    = qq[get_url "https://wipcore.t-mobile.com/login" ];
            $cmd1   .= qq[-post "txtMSISDN=$config_parms{cell_phone_number}&txtUserName=$config_parms{cell_phone_username}&txtPassword=$config_parms{cell_phone_password}&tmobile=true" ];
            $cmd1   .= qq[-cookie_file_out "$config_parms{data_dir}/web/phone_minutes.cookies" "$config_parms{data_dir}/web/phone_minutes1.html"];
            $cmd2    = qq[get_url "https://www.t-mobile.com/mytmobile/default.asp" ];
            $cmd2   .= qq[-cookie_file_in "$config_parms{data_dir}/web/phone_minutes.cookies" "$config_parms{data_dir}/web/phone_minutes2.html"];
            $tmobile_flag = 1;
        }
        elsif (lc $config_parms{cell_phone_provider} eq 'cingular') {
            my ($ac, $pref, $num) = $config_parms{cell_phone_number} =~ /(\d\d\d)(\d\d\d)(\d\d\d\d)/;
            my $post_data = "CTNAreaCode=$ac&CTNPrefix=$pref&CTNNumber=$num&PASS=$config_parms{cell_phone_password}";
            $post_data   .= "&event=forward&action=logIn&TF=N&NP=T&IDToken=$config_parms{cell_phone_number}";
            $cmd1    = qq[get_url "https://www.myaccount.cingular.com/DispatcherServlet" ];
            $cmd1   .= qq[-post "$post_data&name=/jsp/longTask.jsp" ];
            $cmd1   .= qq[-cookie_file_out "$config_parms{data_dir}/web/phone_minutes.cookies" "$config_parms{data_dir}/web/phone_minutes1.html" ];
                                # Not sure why -post doesn't work here?
#           $cmd2    = qq[get_url "https://www.myaccount.cingular.com/DispatcherServlet" -post "$post_data&name=/WAServletsLogin" ];
            $cmd2    = qq[get_url "https://www.myaccount.cingular.com/DispatcherServlet?$post_data&name=/WAServletsLogin" ];
            $cmd2   .= qq[-cookie_file_in "$config_parms{data_dir}/web/phone_minutes.cookies" "$config_parms{data_dir}/web/phone_minutes2.html"];
        }
                                # Default to sprint
        else {
            $cmd1    = qq[get_url "https://manage1.sprintpcs.com/Manage" ];
            $cmd1   .= qq[-post "min=$config_parms{cell_phone_number}&password=$config_parms{cell_phone_password}&action=doLogin&target=Login" ];
            $cmd1   .= qq[-cookie_file_out "$config_parms{data_dir}/web/phone_minutes.cookies" "$config_parms{data_dir}/web/phone_minutes1.html"];
            $cmd2    = qq[get_url "https://manage1.sprintpcs.com/Manage?target=MyCurrentUsage&action=current_usage" ];
            $cmd2   .= qq[-cookie_file_in "$config_parms{data_dir}/web/phone_minutes.cookies" "$config_parms{data_dir}/web/phone_minutes2.html"];
        }
        set $p_phone_minutes $cmd1, $cmd2;   # Run login url, then usage report url
        start $p_phone_minutes;
        print_log "Starting phone minutes check";
    }
}

use HTML::TableExtract;

if (done_now $p_phone_minutes or said $v_phone_minutes eq 'Debug') {
    if (lc $config_parms{cell_phone_provider} eq 'tmobile') {
        if ($tmobile_flag) {
            for (file_read "$config_parms{data_dir}/web/phone_minutes2.html") {
                if (/("https.*&action=unbilledSummary")/) {
                    set $p_phone_minutes qq[get_url $1 -cookie_file_in "$config_parms{data_dir}/web/phone_minutes.cookies" "$config_parms{data_dir}/web/phone_minutes2.html"];
                    $tmobile_flag = 0;
                    start $p_phone_minutes;
                }
            }
        }
        else {
            my $html = file_read "$config_parms{data_dir}/web/phone_minutes2.html";
            return unless $html;

            my $te = new HTML::TableExtract( headers => [qw(Feature Included Used Remaining)] );
            $te->parse($html);

            my @cell = $te->rows;
            $Save{phone_minutes_plan} = round $cell[2][1];
            $Save{phone_minutes_used} = round $cell[2][2];
            $Save{phone_minutes_left} = round $cell[2][3];
            $Save{phone_minutes_date} = $Time_Date;
            print_log "Phone minutes: plan=$Save{phone_minutes_plan} used=$Save{phone_minutes_used} left=$Save{phone_minutes_left}";
        }
    }
    elsif (lc $config_parms{cell_phone_provider} eq 'cingular') {
        my $html = file_read "$config_parms{data_dir}/web/phone_minutes2.html";
        my $te = new HTML::TableExtract( headers => [qw(Available Used)] );
        $te->parse($html);
        my @cell = $te->rows;
        $Save{phone_minutes_plan} = round $cell[1][0];
        $Save{phone_minutes_used} = round $cell[1][1];
        $Save{phone_minutes_left} = $cell[1][0] - $cell[1][1];
        $Save{phone_minutes_date} = $Time_Date;
        print_log "Phone minutes: plan=$Save{phone_minutes_plan} used=$Save{phone_minutes_used} left=$Save{phone_minutes_left}";
    }

# Example of Sprint's minutes remaining html data:
#  <td class="left"><strong>Invoice period:</strong></td><td class="right">November 25, 2004&nbsp;-&nbsp;December 24, 2004</td>
#  <td>MINUTES IN PLAN</td><td class="centerIt">1100</td><td class="centerIt">588</td><td class="centerIt">512</td><td class="last centerIt">0</td>
    else {
        for (file_read "$config_parms{data_dir}/web/phone_minutes2.html") {
            if (/Invoice period.+\;(.+)\<\/td/i) {
                $Save{phone_minutes_date_end} = round $1;
                $Save{phone_minutes_days} = round((str2time($1) - time) / (24*3600), 1);
            }
            if (/MINUTES IN PLAN.+?\>(\d+).+?\>(\d+).+?\>(\d+)/) {
                $Save{phone_minutes_plan} = round $1;
                $Save{phone_minutes_used} = round $2;
                $Save{phone_minutes_left} = round $3;
                $Save{phone_minutes_left_day} = round($3 / int(1 + $Save{phone_minutes_days}));
                $Save{phone_minutes_date} = $Time_Date;
                print_log "Phone minutes: plan=$1 used=$2 left=$3 days=$Save{phone_minutes_days} per_day=$Save{phone_minutes_left_day}";
            }
        }
    }

}


# lets allow the user to control via triggers

if ($Reload and $Run_Members{'trigger_code'}) {
    eval qq(
        &trigger_set("time_now '7 pm'", "run_voice_cmd 'Check phone minutes'", 'NoExpire', 'speak phone minutes')
          unless &trigger_get('speak phone minutes');
    );
}
