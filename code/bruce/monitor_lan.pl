
# Category=Internet

#@ Disable some code if we connect to IBM and disable the local LAN
#@ Otherwise, mh will pause, looking for local lan addresses on IBM's intranet

$lan_code = new Voice_Cmd '[enable,disable] local lan code';

if ( $state = said $lan_code) {
    for my $member (
        'monitor_shoutcast', 'lcd',
        'audrey',            'monitor_mh',
        'speak_proxy',       'monitor_house_im'
      )
    {
        #       $state = (($Run_Members{$member}) ? 'disable' : 'enable') if $state eq 'toggle';
        if ( $state eq 'disable' ) {
            print_log "Disabling local lan code file $member";

            #            $code_members_off{$member} = 1;
            $Run_Members{$member} = 0;
        }
        else {
            print_log "Enabling local lan code file $member";

            #            delete $code_members_off{$member};
            $Run_Members{$member} = 1;
        }
    }
    speak "Local lan code was ${state}d";
}

# Automatically enable/disable, depending if we
# are running the vpn nortel client (i.e. local lan is down)
# active_programs is set in monitor_programs.pl
if ( my $pgms = state_now $active_programs) {

    #   print "\ndb p=$pgms\n";
    my $disable_lan = 1 if $pgms =~ /extranet/i;
    my $lan_enabled = 0;
    for my $member ( 'monitor_shoutcast', 'lcd', 'audrey' ) {
        $lan_enabled = 1 if $Run_Members{$member};
    }

    #   if ($disable_lan and state $lan_code eq 'enaable') {
    if ( $disable_lan and $lan_enabled ) {
        run_voice_cmd 'disable local lan code';
    }
    if ( !$disable_lan and !$lan_enabled ) {
        run_voice_cmd 'enable local lan code';
    }
}

