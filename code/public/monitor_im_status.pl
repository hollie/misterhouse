# Category = Other

$Save{steve_at_work} = 0 unless $Save{steve_at_work};
my $timer_steve_leave_work = new Timer();

if ( expired $timer_steve_leave_work) { &im_status_steve_changed; }

sub im_status {
    my ( $user, $status, $status_old, $pgm ) = @_;
    if ( lc $user eq 'aimscreenname1' or lc $user eq 'aimscreenname2' ) {
        $Save{steve_work_aim} = $user;
        if ( $status eq 'on' and $Save{steve_at_work} == 0 ) {
            $Save{steve_at_work} = 1;
            &im_status_steve_changed
              unless
              active $timer_steve_leave_work; #Don't notify if I login within 5 minutes
            unset $timer_steve_leave_work;
        }
        if ( $status eq 'off' and $Save{steve_at_work} == 1 ) {
            $Save{steve_at_work} = 0;
            set $timer_steve_leave_work 300
              ;    #make sure I logoff for at least 5 minutes
        }
    }
}

sub im_status_steve_changed {
    if ( $Save{steve_at_work} == 1 ) {
        net_im_send(
            pgm  => 'aol',
            to   => $Save{steve_work_aim},
            text => 'Welcome to work!'
        );
        play "room=kitchen aim/ring.wav";
        speak "Notice, Steve just logged on to the computer at work."
          if state $mode_occupied eq 'wife';
    }
    else {
        print_log "Steve is leaving work\n";
        if (    time_cron '* 16,17,18,19 * * *'
            and state $mode_occupied eq 'wife' )
        {
            speak "Notice, Steve is on his way home. Better get dinner ready!";
        }
        else {
            speak "Notice, Steve has logged off the computer at work.";
        }
    }
}

sub work_notify_steve {
    my $msg = "@_";
    &net_im_send( pgm => "AOL", to => $Save{steve_work_aim}, text => $msg )
      if $Save{steve_at_work} == 1;

    #print "Steve not at work, not sending: $msg \n" if $Save{steve_at_work}!=1
}
