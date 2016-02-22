
# Category = Entertainment

#@ Plays the game of Bingo by speaking a set of bingo numbers at a timed interval.
#@ Use with a 75 number deck (B 1->15, I 16->30, etc).

$t_bingo_timer   = new Timer;
$v_bingo_control = new Voice_Cmd '[Start,Pause,Resume,Status,] Bingo';
$v_bingo_time    = new Voice_Cmd 'Set bingo time to [2,5,10,15,20]';

use vars qw(@bingo_card $bingo_count)
  ;    # *** Is this really the best way to persist?

if ( state_now $v_bingo_time) {
    respond("app=bingo Bingo timer set to "
          . $v_bingo_time->{state}
          . " seconds." );
    $config_parms{bingo_time} = $state;
}

if ( said $v_bingo_control) {
    if ( $v_bingo_control->{state} eq 'Start' ) {
        $v_bingo_control->respond("app=bingo Get ready to Bingo!");

        # Randomize the card
        @bingo_card = ();
        my $number = 1;
        for my $letter (qw(B I N G O)) {
            for ( 1 .. 15 ) {
                push @bingo_card, "$letter $number";
                $number++;
            }
        }
        randomize_list @bingo_card;
        $bingo_count = 0;
        print "Randomized list: @bingo_card\n" if $Debug{bingo};
        $config_parms{bingo_time} = 15 unless $config_parms{bingo_time};
        set $t_bingo_timer 2;
    }
    elsif ( $v_bingo_control->{state} eq 'Pause' ) {
        $v_bingo_control->respond("app=bingo Bed time for Bingo!");
        stop $t_bingo_timer;
    }
    elsif ( $v_bingo_control->{state} eq 'Status' ) {
        &display_bingo_status;
    }
    elsif ( $v_bingo_control->{state} eq 'Pause' ) {
        $v_bingo_control->respond("app=bingo Resuming the game...");
        set $t_bingo_timer 2;
    }
    else {
        $v_bingo_control->respond("app=bingo Housey housey! Bingo!! Bingo!!");
        stop $t_bingo_timer;
    }
}

if ( expired $t_bingo_timer) {
    if ( $bingo_count >= 75 ) {
        $v_bingo_control->respond("app=bingo connected=0 Bingo game is over.");
        stop $t_bingo_timer;
    }
    else {
        $v_bingo_control->respond("app=bingo $bingo_card[++$bingo_count - 1]");
        set $t_bingo_timer $config_parms{bingo_time};
        &display_bingo;
    }
}

sub display_bingo {
    display
      app         => 'bingo',
      text        => "$bingo_count. $bingo_card[$bingo_count - 1] ",
      window_name => 'Bingo',
      append      => 'top';
}

sub display_bingo_status {
    my $i = $bingo_count - 3;
    $i = 0 if $i < 0;
    my @previous = $bingo_card[ $i .. $bingo_count - 1 ];
    if ( $#previous != -1 ) {
        display app => 'bingo', text => "@previous";
    }
    else {
        display app => 'bingo', text => "No game in progress.";
    }
}
