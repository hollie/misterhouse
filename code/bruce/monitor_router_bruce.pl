# Keep an eye on computer game time
#$check_web_time  = new Voice_Cmd 'Check [nick_game,nick_web,house_web,zack_web] time';
#$check_web_time -> set_info('Check to see who spent how much time was spent on the internet for the day');
#$check_web_time -> set_authority('anyone');
#tie_event $check_web_time 'speak sprintf "voice=male Todays $state time is %2.1f hours",  $Save{"router_time_$state"} / 60';

#$check_web_time2  = new Voice_Cmd 'Display [nick_web,nick_game,house_web,zack_web] time log';
#$check_web_time2 -> set_info('Review the internet usage logs');
#tie_event $check_web_time2 'display "$config_parms{data_dir}/logs/$state.$Year_Month_Now.log", 200, "$state log", "fixed"';
#tie_event $check_web_time2 'display "$config_parms{data_dir}/logs/$state.totals.log",       200, "$state totals", "fixed"';

#f ($New_Day) {
if ( time_now "11:59 pm" ) {
    for my $name ( ( 'halflife', 'nick_web', 'nick_game' ) ) {
        if ( $Save{"router_time_$name"} ) {
            $Save{"router_total_time_$name"} += $Save{"router_time_$name"};
            my $hour  = round $Save{"router_time_$name"} / 60,       1;
            my $hourt = round $Save{"router_total_time_$name"} / 60, 1;
            my $msg   = "Notice, $name time is $hour hours (total: $hourt)";
            logit "$config_parms{data_dir}/logs/$name.totals.log",
              "---------------------"
              if $New_Week;
            logit "$config_parms{data_dir}/logs/$name.totals.log", $msg;
        }
    }
}

# Reset times once a day
if ($New_Day) {
    for my $key ( keys %Save ) {
        $Save{$key} = 0 if $key =~ /^router_time/;
    }
    display "Reset data for %Save";
}

sub check_router_times {
    my ( $proto, $ip ) = @_;

    #   print "db $proto router hit to $ip\n";

    my $name = 'nick_web' if $proto eq 'TCP' and $ip eq '192.168.0.9';
    return unless $name;

    if ( $Time - $router_time_prev{$name} > 60 ) {
        $Save{"router_time_$name"}++;
        my $i = $Save{"router_time_$name"};
        my $hour = round $Save{"router_time_$name"} / 60, 1;
        $router_time_prev{$name} = $Time;

        #       print_log "$name time: $hour hours";
        #       print_log "Web $name time: $hour hours" unless $Save{"router_time_$name"} % 10;
        if ( $Save{"router_time_$name"} - $Save{"router_time_prev_$name"} > 15 )
        {
            $Save{"router_time_prev_$name"} = $Save{"router_time_$name"};
            my $name2 = $name;
            $name2 =~ tr/_/ /;
            my $msg = "Notice, $name2 time is $hour hours";
            if ( $hour > 2 ) {
                run "mhsend -host dm -speak $msg";
                speak voice => 'sam', rooms => 'all', text => $msg;
            }
            elsif ( time_greater_than '10 PM'
                and ( $Day ne 'Fri' and $Day ne 'Sat' ) )
            {
                speak
                  "voice=>female3 rooms=nick mode=unmuted Notice, $name2 detected after hours";
            }
            logit "$config_parms{data_dir}/logs/$name.$Year_Month_Now.log",
              $msg;
        }
    }
}

$check_web_hits = new Voice_Cmd 'Check web server hits';

if ( said $check_web_hits) {
    speak
      "$Save{server_hits_hour} web hits from $Save{server_clients_hour} clients in the last hour. "
      . "$Save{server_hits_day} web hits from $Save{server_clients_day} clients in the last day.";
}
