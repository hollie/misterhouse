
# Category = Entertainment

#@ Plays the game of Bingo by speaking a set of bingo numbers at a timed interval.
#@ Use with a 75 number deck (B 1->15, I 16->30, etc).

$bingo_timer   = new Timer;
$bingo_control = new Voice_Cmd '[Start,Pause,Resume,Status] bingo';
$bingo_time    = new Voice_Cmd 'Set bingo time to [2,5,10,15,20]';

if ($state = state_now $bingo_time) {
    speak "app=bingo Ok, bingo timer set to $state seconds";
    $config_parms{bingo_time} = $state;
}

use vars qw(@bingo_card $bingo_count); # Avoid 'my' so we keep data between reloads

if ($state = said $bingo_control) {
    if ($state eq 'Start') {
        speak "app=bingo Get ready to Bingo!";
                                # Randomize the card
        @bingo_card = ();
        my $number = 1;
        for my $letter (qw(B I N G O)) {
            for (1 .. 15) {
                push @bingo_card, "$letter$number";
                $number++;
            }
        }
        randomize_list @bingo_card;
        $bingo_count = 0;
        print "Randomized list: @bingo_card\n" if $Debug{bingo};
        $config_parms{bingo_time} = 15 unless $config_parms{bingo_time};
        set $bingo_timer 2;
    }
    elsif ($state eq 'Pause') {
        speak "app=bingo Ok, break time";
        stop $bingo_timer;
        &display_bingo_status;
    }
    elsif ($state eq 'Status') {
        &display_bingo_status;
    }
    elsif ($state eq 'Resume') {
        speak "app=bingo Resuming the game";
        set $bingo_timer 2;
    }
}

if (expired $bingo_timer) {
    if ($bingo_count >= 75) {
        speak "app=bingo Bingo game is over";
        stop $bingo_timer;
    }
    else {
        speak app => 'bingo', text => $bingo_card[++$bingo_count - 1];
        set $bingo_timer $config_parms{bingo_time};
                                # Display the last few calls
        &display_bingo_status;
    }
}

sub display_bingo_status {
    my $i = $bingo_count-3; $i = 0 if $i < 0;
    my @previous = @bingo_card[$i .. $bingo_count-1];
    display app => 'bingo', text => "$bingo_count @previous";
}
