# Category=Informational

my $f_trivia_question = "$config_parms{data_dir}/trivia_question.txt";
my $f_trivia_answer   = "$config_parms{data_dir}/trivia_answer.txt";

$v_trivia_next1    = new  Voice_Cmd('What is the [Current,next Science,next Entertainment,next Mixed,next Sports] trivia question');
$v_trivia_next2    = new  Voice_Cmd('Display the [Current,next Science,next Entertainment,next Mixed,next Sports] trivia question');
$v_trivia_answer   = new  Voice_Cmd('[What is,Display] the trivia answer');

$v_trivia_next2   -> set_authority('anyone');
$v_trivia_answer  -> set_authority('anyone');

my $cat;
if (($cat = said $v_trivia_next1 or $cat = said $v_trivia_next2) and $cat =~ /next / or
    time_cron '0 6 * * * ') {
    $cat =~ s/next //;
    $cat = 'Mixed' unless $cat;
    @ARGV = ($cat);		# Pass catagory to the 'do'ed program
#   do "$Pgm_Path/trivia";      # Use do so we can run from compiled mh, without perl installed
    &trivia_next($cat);
    print_log "Trivia question has been refreshed";
}

speak   $f_trivia_question if said $v_trivia_next1;
speak   $f_trivia_answer   if said $v_trivia_answer eq 'What is';

display $f_trivia_question if said $v_trivia_next2;
display $f_trivia_answer   if said $v_trivia_answer eq 'Display';


sub trivia_next {
    my $cat = shift;
    $cat = 'Science' unless $cat;
    $cat = ucfirst $cat;

    my $data_dir = "$Pgm_Path/../data/trivia";

                                # Keep track of where the current question number
    my $qn = $Save{"trivia.$cat.cnt"};
    $qn++;
    $qn = 0 if $qn >= 500;
    $qn = 0 if $qn >= 250 and $cat eq 'Mixed';
    $Save{"trivia.$cat.cnt"} = $qn;

    my $offset = 0 + 153*($qn-1);

    open (INDATA,   "$Pgm_Path/../data/trivia/$cat.dat") or die "Error, could not open trivia file $Pgm_Path/../data/$cat.dat:$!\n";
    open (QUESTION, ">$f_trivia_question");
    open (ANSWER,   ">$f_trivia_answer");

                                # Read the data
    my $r;
    read (INDATA, $r, 30);
    my $category = substr($r, 0, 20);
    print_log "Searching for question number $qn in $category database";

                                # Get to the right question
    for (my $i = 0; $i < $qn; $i++){
        read (INDATA, $r, 153);
    }

                                # Format the output
    my $q = substr($r, 0, 70);
    my @a;
    $a[1] = &trivia_trim(substr($r,  72, 20)) . ".";
    $a[2] = &trivia_trim(substr($r,  92, 20)) . ".";
    $a[3] = &trivia_trim(substr($r, 112, 20)) . ".";
    $a[4] = &trivia_trim(substr($r, 132, 20)) . ".";
    my $an= substr($r, 152, 1);
    
    print  QUESTION "Todays Trivia Question.
 $q
  1: $a[1]
  2: $a[2]
  3: $a[3]
  4: $a[4]
One more time.  The Trivia Question is:
 $q
  1: $a[1]
  2: $a[2]
  3: $a[3]
  4: $a[4]
";

    print  ANSWER "The trivia answer is:
  $an: $a[$an]

Once again, the trivia answer is:
  $an: $a[$an].
";

    close INDATA;
    close QUESTION;
    close ANSWER;

}

sub trivia_trim {
    my ($string) = @_;
    my (@a);
    @a = split(" ", $string);
    return join(" ",@a);
}

