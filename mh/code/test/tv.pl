# Category=TV

$TV  = new IR_Item 'TV';
$VCR = new IR_Item 'VCR', '3digit';

my  $tv_states = 'power,on,off,mute,vol+,vol-,ch+,ch-';
my $vcr_states = $tv_states . 'record,play,puase,stop,ff,rew';

set_states  $TV split ',', $tv_states;
set_states $VCR split ',', $vcr_states;

$v_tv_control = new  Voice_Cmd("tv [$tv_states]");
$v_tv_control-> set_info('Controls the bedroom TV.');

if ($state = said $v_tv_control) {
    print_log "Setting TV to $state";
    set $TV $state;
#   run "ir_cmd TV,MUTE";
}

$v_vcr_control = new  Voice_Cmd("vcr [vcr_states]");
$v_vcr_control-> set_info('Controls the bedroom VCR');

if ($state = said $v_vcr_control) {
    print_log "Setting VCR to $state";
    set $VCR $state;
}


#speak('rooms=all Red Alert!  Voyager, the tv series, starts in one minute.  Be there.') if time_cron('59 19 * * 3');
#speak('rooms=all Warning all parents.  Disturbing show of paper idiots on in 1 minute.') if time_cron('59 20 * * 3');


#&tk_entry('TV key', \$Save{ir_key}, 'VCR key', \$Save{vcr_key});
if (my $state = $Tk_results{'TV key'}) {
                                # Use this to test/tune the placement of your ir xmiters
    if ($state eq 'test') {
        unless (new_second 5) {
            print_log "Testing IR TV interface";
            set $TV 'ch+';
        }
    }
    else {
        print_log "Setting TV key to $state";
        set $TV $state;
        undef $Tk_results{'TV key'};
    }
}
if (my $state = $Tk_results{'VCR key'}) {
                                # Use this to test/tune the placement of your ir xmiters
    if ($state eq 'test') {
        unless (new_second 5) {
            print_log "Testing IR VCR interface";
            set $VCR 'ch+';
        }
    }
    else {
        print_log "Setting VCR key to $state";
        set $VCR $state;
        undef $Tk_results{'VCR key'};
    }
}

