# Category = Phone

#@ Use this code file to monitor your phone minutes (currently Sprint only).
#@ Set cell_phone_number and cell_phone_password mh.ini parms.
#@ If not running the compiled mhe, you also must install the Crypt::SSLeay Perl module.

$p_phone_minutes =  new Process_Item;
$v_phone_minutes =  new Voice_Cmd('[Check,Read] phone minutes');
$v_phone_minutes -> set_info('Checks used and remaining cell phone minutes.');

run_voice_cmd 'Check phone minutes' if time_now '6 am';

if ($state = said $v_phone_minutes) {
    if ($state eq 'Read') {
        speak "You have $Save{phone_minutes_left} phone minutes left";
    }
    elsif (&net_connect_check) {
        my $dir = "$config_parms{data_dir}/web";

        my $cmd1 = qq[get_url "https://manage1.sprintpcs.com/Manage" ];
        $cmd1   .= qq[-post "min=$config_parms{cell_phone_number}&password=$config_parms{cell_phone_password}&action=doLogin&target=Login" ];
        $cmd1   .= qq[-cookie_file_out "$dir/phone_minutes.cookies" "$dir/phone_minutes1.html"];

        my $cmd2 = qq[get_url "https://manage1.sprintpcs.com/Manage?target=MyCurrentUsage&action=current_usage" ];
        $cmd2   .= qq[-cookie_file_in "$dir/phone_minutes.cookies" "$dir/phone_minutes2.html"];

        set $p_phone_minutes $cmd1, $cmd2;   # Run login url, then usage report url
        start $p_phone_minutes;
        print_log "Starting phone minutes check";
    }
}

# Example of minutes remaining html data:
#  <td>MINUTES IN PLAN</td><td class="centerIt">1100</td><td class="centerIt">588</td><td class="centerIt">512</td><td class="last centerIt">0</td>

if (done_now $p_phone_minutes) {
    for (file_read "$config_parms{data_dir}/web/phone_minutes2.html") {
        if (/MINUTES IN PLAN.+?\>(\d+).+?\>(\d+).+?\>(\d+)/) {
            $Save{phone_minutes_plan} = $1;
            $Save{phone_minutes_used} = $2;
            $Save{phone_minutes_left} = $3;
            $Save{phone_minutes_date} = $Time_Date;
            print_log "Phone minutes: plan=$1 used=$2 left=$3";
        }
    }
}

if (time_now '7 pm' and $Save{phone_minutes_left} < 10) {
   speak "app=notice Notice, you have $Save{phone_minutes_left} minutes left on this month's phone time";
}
