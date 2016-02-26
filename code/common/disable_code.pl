# Category = MisterHouse

#@ Adds the 'enable/disable xyz code file' commands and persists disabled module list

# Allow for turning on/off code members

my $code_members_list = join ',', sort keys %Run_Members;
my %code_members_off;

if ($Reload) {
    for my $member ( split ',', $Save{code_members_off} ) {
        print_log
          "Member $member has been disabled.  Re-enable with 'toggle code member $member'";
        $code_members_off{$member}++;
        $Run_Members{$member} = 0;
    }
}

$v_toggle_run_members =
  new Voice_Cmd "[Disable,Enable,List status of] all code files";
$v_toggle_run_members->set_info(
    'Use this for debug.  Turns all code files on or off');

if ( $state = said $v_toggle_run_members) {
    print_log "$state all code members";
    my $new_state = ( $state eq 'Disable' ) ? 0 : 1;
    undef %code_members_off if $new_state;
    my ( $list, $cnt1, $cnt2 );
    $cnt1 = $cnt2 = 0;
    for my $member ( sort keys %Run_Members ) {
        $cnt1++;
        next if $member eq 'disable_code' or $member eq 'mh_control';
        if ( $state eq 'List status of' ) {
            unless ( $Run_Members{$member} ) {
                $list .= ",$member";
                $cnt2++;
            }
        }
        else {
            $Run_Members{$member} = $new_state;
            $code_members_off{$member} = 1 unless $new_state;
        }
    }
    print_log "$cnt2 of $cnt1 members are disabled:  $list"
      if $state eq 'List status of';
    $Save{code_members_off} = join ',', sort keys %code_members_off;
}

$v_toggle_run_member = new Voice_Cmd "Toggle code member [$code_members_list]";
$v_toggle_run_member->set_info('Toggle a code member file on or off');

if ( my $member = said $v_toggle_run_member) {
    if ( $code_members_off{$member} ) {
        print_log "Member $member was toggled On";
        delete $code_members_off{$member};
        $Run_Members{$member} = 1;
    }
    else {
        print_log "Member $member was toggled Off";
        $code_members_off{$member} = 1;
        $Run_Members{$member}      = 0;
    }
    $Save{code_members_off} = join ',', sort keys %code_members_off;
}

# Allow for disabling each member for a period of time
my ( @disable_members, $disable_member, $disable_member_time );

$disable_code =
  new Voice_Cmd 'Disable code test [.01,.1,.3,.6,1,10,60,300] minutes';
$disable_code->set_info(
    'Use this to debug problems by sequentially turning off code files');
$disable_code_timer = new Timer;

if ( $state = said $disable_code) {
    @disable_members = sort keys %Run_Members;
    set $disable_code_timer .1;
    $disable_member_time = $state;
}

if ( expired $disable_code_timer) {
    $Run_Members{$disable_member} = 1 if $disable_member;
    shift @disable_members if $disable_members[0] eq 'disable_code';
    if ( $disable_member = shift @disable_members ) {
        $Run_Members{$disable_member} = 0;
        set $disable_code_timer 60 * $disable_member_time;
        my $msg = "Disabling code member $disable_member";
        print "db $msg\n";
        print_log $msg;
        display
          text        => "$Time_Date: $msg\n",
          time        => 0,
          window_name => 'disable_code',
          append      => 'top';
    }
    else {
        print_log 'Disable code test finished';
    }
}

# If you have a 24x7 internet connection, you can use this to
# debug time loss problems (from internet_time.pl)

#run_voice_cmd 'Set the clock via the internet' if
#    expired $disable_code_timer and $disable_member_time > .01;

