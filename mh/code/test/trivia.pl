# Category=Informational

my $f_trivia_question = "$Pgm_Path/../data/trivia/trivia_question.txt";
my $f_trivia_answer   = "$Pgm_Path/../data/trivia/trivia_answer.txt";

$v_trivia_question = new  Voice_Cmd('[What is,Display] the trivia question?');
$v_trivia_answer   = new  Voice_Cmd('[What is,Display] the trivia answer?');
$v_trivia_next1    = new  Voice_Cmd('What is the next [Science,Entertainment,Mixed,Sports] trivia question?');
$v_trivia_next2    = new  Voice_Cmd('Display the next [Science,Entertainment,Mixed,Sports] trivia question?');

my $cat;
if ($cat = said $v_trivia_next1 or $cat = said $v_trivia_next2 or
    time_cron '0 6 * * * ') {
    $cat = 'Mixed' unless $cat;
    @ARGV = ($cat);		# Pass catagory to the 'do'ed program
    do "$Pgm_Path/trivia";      # Use do so we can run from compiled mh, without perl installed
    print_log "Trivia question has been refreshed";
}

speak   $f_trivia_question if said $v_trivia_question eq 'What is' or said $v_trivia_next1;
speak   $f_trivia_answer   if said $v_trivia_answer eq 'What is';

display $f_trivia_question if said $v_trivia_question eq 'Display' or said $v_trivia_next2;
display $f_trivia_answer   if said $v_trivia_answer eq 'Display';
