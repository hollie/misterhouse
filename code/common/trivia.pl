# Category = Entertainment

# $Date$
# $Revision$

#@ This module has trivia questions and answers.

my $f_trivia_question = "$config_parms{data_dir}/trivia_question.txt";
my $f_trivia_answer   = "$config_parms{data_dir}/trivia_answer.txt";

$v_trivia_next = new Voice_Cmd(
    'What is the [Current,next Science,next Entertainment,next Mixed,next Sports,next Random] trivia question'
);
$v_trivia_answer = new Voice_Cmd('What is the trivia answer');

$v_trivia_next->set_authority('anyone');
$v_trivia_answer->set_authority('anyone');

my $cat;

# Create trigger

if ($Reload) {
    &trigger_set(
        "time_cron '0 6 * * * '", "&trivia_next()",
        'NoExpire',               'refresh trivia'
    ) unless &trigger_get('refresh trivia');
}

sub uninstall_trivia {
    &trigger_delete('refresh trivia');
}

&trivia_next($cat) if $cat = said $v_trivia_next and $cat =~ /next /;

$v_trivia_next->respond("app=trivia $f_trivia_question") if said $v_trivia_next;
$v_trivia_answer->respond("app=trivia $f_trivia_answer")
  if said $v_trivia_answer;

sub trivia_next {
    my $cat = shift;
    $cat =~ s/next //;

    #   $cat = 'Science' unless $cat;
    #   $cat = 'Mixed'  unless $cat;
    $cat = 'Random' unless $cat;
    $cat = ucfirst $cat;
    if ( $cat eq 'Random' ) {
        my @cats = qw(Science Entertainment Mixed Sports);
        $cat = $cats[ int( (@cats) * rand ) ];
    }

    # *** Should change to user data folder once first-run data copy is in place
    # *** Should check user data folder first, then data folder

    my $data_dir = "$Pgm_Root/data/trivia";

    # Keep track of the current question number
    my $qn = $Save{"trivia.$cat.cnt"};
    $qn++;
    $qn = 0 if $qn >= 500;
    $qn = 0 if $qn >= 250 and $cat eq 'Mixed';
    $Save{"trivia.$cat.cnt"} = $qn;

    my $offset = 0 + 153 * ( $qn - 1 );

    open( INDATA, "$Pgm_Root/data/trivia/$cat.dat" )
      or die
      "Error, could not open trivia file $Pgm_Path/../data/$cat.dat:$!\n";
    open( QUESTION, ">$f_trivia_question" );
    open( ANSWER,   ">$f_trivia_answer" );

    # Read the data
    my $r;
    read( INDATA, $r, 30 );
    my $category = substr( $r, 0, 20 );
    print_log "Searching for question number $qn in $category database";

    # Get to the right question
    for ( my $i = 0; $i < $qn; $i++ ) {
        read( INDATA, $r, 153 );
    }

    # Format the output
    my $q = substr( $r, 0, 70 );
    my @a;
    $a[1] = &trivia_trim( substr( $r, 72,  20 ) ) . ".";
    $a[2] = &trivia_trim( substr( $r, 92,  20 ) ) . ".";
    $a[3] = &trivia_trim( substr( $r, 112, 20 ) ) . ".";
    $a[4] = &trivia_trim( substr( $r, 132, 20 ) ) . ".";
    my $an = substr( $r, 152, 1 );

    print QUESTION "Today's $cat trivia question:
 $q
  1: $a[1]
  2: $a[2]
  3: $a[3]
  4: $a[4]
One more time.
 $q
  1: $a[1]
  2: $a[2]
  3: $a[3]
  4: $a[4]
";

    print ANSWER "The $cat trivia answer is:
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
    @a = split( " ", $string );
    return join( " ", @a );
}
