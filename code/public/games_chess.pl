# Category=VoiceChess
#
# Uses "sendkeys" (Thanks to David Norwood for his idea), which is a windows only (currently not in perl 5.6) way
# of controling other windows.
# This module works (and has been tested) with "Chessmaster 9000" (http://chessmaster.ubi.com/) as well as "Fritz 6"
# (see http://www.chessbase.com/ for this most famous chess game).
#
# Voice Chess sends your spoken chess moves (remotely) via mh's voice command to the chess program.
#
# To get it run smoothly do not forget:
#
# 1) That "Chessmaster9000" (or your favourite chess game) should already be up and running
# 2) In Chessmaster->Preferences->Notation you chose "algebraic" (after 2, 3 times the program will remember your new default setting.
# 3) You should activate Chessmaster's voice output to be able to listen to his own movements so that
#    you fully enjoy a "screenless" chessgame! (Chessmaster->Preferences->Sound->Spoken Move Announcements
# 4) Your move consists of three parts:
#    a) the piece to be moved
#    b) the new field's file (a, b,.. h)
#    c) the new field's rank (1, 2,.. 8)
# 5) If you capture a piece your move has to look like this: ed5 (if pawn on e captures d5)
# 6) For special kind of moves (O-O) see the bottom of this file
#
# Finally: Enjoy!
#
# NB: If the game engine pronounces its movements too fast (because he IS so fast) try to add to your play time - it will make
# him ponder longer (and definitly make him invincible ;-) ->A good value would be 30min/game.

#Replace with "Fritz 6", etc. to get your engine running with voice chess
my $chess_game = "Chessmaster";

my $move;

#Voice Commands for the individual chess pieces:
$voice_chess_pawn   = new Voice_Cmd 'pawn';
$voice_chess_knight = new Voice_Cmd 'knight';
$voice_chess_bishop = new Voice_Cmd 'bishop';
$voice_chess_rook   = new Voice_Cmd 'rook';
$voice_chess_queen  = new Voice_Cmd 'queen';
$voice_chess_king   = new Voice_Cmd 'king';

#Chess pieces variables
if ( said $voice_chess_pawn) {
    $move .= "";
}
if ( said $voice_chess_knight) {
    $move .= "N";
}
if ( said $voice_chess_bishop) {
    $move .= "B";
}
if ( said $voice_chess_rook) {
    $move .= "R";
}
if ( said $voice_chess_queen) {
    $move .= "Q";
}
if ( said $voice_chess_king) {
    $move .= "K";
}

#Chess movement variables part_alphabetical:
$chess_a = new Voice_Cmd 'file a';
if ( $state = said $chess_a) {
    $move .= "a";
    print_log($move);
}
$chess_b = new Voice_Cmd 'file b';
if ( $state = said $chess_b) {
    $move .= "b";
    print_log($move);
}
$chess_c = new Voice_Cmd 'file c';
if ( $state = said $chess_c) {
    $move .= "c";
    print_log($move);
}
$chess_d = new Voice_Cmd 'file d';
if ( $state = said $chess_d) {
    $move .= "d";
    print_log($move);
}
$chess_e = new Voice_Cmd 'file e';
if ( $state = said $chess_e) {
    $move .= "e";
    print_log($move);
}
$chess_f = new Voice_Cmd 'file f';
if ( $state = said $chess_f) {
    $move .= "f";
    print_log($move);
}
$chess_g = new Voice_Cmd 'file g';
if ( $state = said $chess_g) {
    $move .= "g";
    print_log($move);
}
$chess_h = new Voice_Cmd 'file h';
if ( $state = said $chess_h) {
    $move .= "h";
    print_log($move);
}

#Chess movement variables part_numerical:
$chess_moveto2 = new Voice_Cmd
  '[rank one,rank two,rank three,rank four,rank five,rank six,rank seven,rank eight]';

if ( $state = said $chess_moveto2) {

    if ( my $window = &sendkeys_find_window( $chess_game, $chess_game ) ) {
        if ( $state eq 'rank one' ) {
            $move .= "1";
            &SendKeys( $window, $move, 1, 500 );
            print_log($move);
            $move = "";
        }
    }
    if ( my $window = &sendkeys_find_window( $chess_game, $chess_game ) ) {
        if ( $state eq 'rank two' ) {
            $move .= "2";
            &SendKeys( $window, $move, 1, 500 );
            print_log($move);
            $move = "";
        }
    }
    if ( my $window = &sendkeys_find_window( $chess_game, $chess_game ) ) {
        if ( $state eq 'rank three' ) {
            $move .= "3";
            &SendKeys( $window, $move, 1, 500 );
            print_log($move);
            $move = "";
        }
    }
    if ( my $window = &sendkeys_find_window( $chess_game, $chess_game ) ) {
        if ( $state eq 'rank four' ) {
            $move .= "4";
            &SendKeys( $window, $move, 1, 500 );
            print_log($move);
            $move = "";
        }
    }
    if ( my $window = &sendkeys_find_window( $chess_game, $chess_game ) ) {
        if ( $state eq 'rank five' ) {
            $move .= "5";
            &SendKeys( $window, $move, 1, 500 );
            print_log($move);
            $move = "";
        }
    }
    if ( my $window = &sendkeys_find_window( $chess_game, $chess_game ) ) {
        if ( $state eq 'rank six' ) {
            $move .= "6";
            &SendKeys( $window, $move, 1, 500 );
            print_log($move);
            $move = "";
        }
    }
    if ( my $window = &sendkeys_find_window( $chess_game, $chess_game ) ) {
        if ( $state eq 'rank seven' ) {
            $move .= "7";
            &SendKeys( $window, $move, 1, 500 );
            print_log($move);
            $move = "";
        }
    }
    if ( my $window = &sendkeys_find_window( $chess_game, $chess_game ) ) {
        if ( $state eq 'rank eight' ) {
            $move .= "8";
            &SendKeys( $window, $move, 1, 500 );
            print_log($move);
            $move = "";
        }
    }
}

#Here is room for special movements:
$chess_kingside = new Voice_Cmd 'castle kingside';

if ( $state = said $chess_kingside) {
    if ( my $window = &sendkeys_find_window( $chess_game, $chess_game ) ) {
        $move = "o-o";
        &SendKeys( $window, $move, 1, 500 );
        print_log($move);
        $move = "";
    }
}

$chess_queenside = new Voice_Cmd 'castle queenside';

if ( $state = said $chess_queenside) {
    if ( my $window = &sendkeys_find_window( $chess_game, $chess_game ) ) {
        $move = "o-o-o";
        &SendKeys( $window, $move, 1, 500 );
        print_log($move);
        $move = "";
    }
}
