
# Category = Entertainment

#@ This code speaks insults.   You can use the mh.ini speak_apps parms to alternate
#@ the insults between different voices and/or sound cards.  For example:
#@ speak_apps = insult1 => voice=Charles card=1/2, insult2 => voice=Audrey card=3/4 .
#@ You can use the speak_insult_file parm to change from the not-too-foul-mouthed default file in data/remarks/insults1.txt
#@ You can see a video of this code allowing my 2 robots to insult each other
#@ at <a href=http://misterhouse.net/public/robot/>misterhouse.net/public/robot/</a>.

$f_insult = new File_Item(
    &file_default(
        $config_parms{speak_insult_file},
        "$config_parms{data_dir}/remarks/insults1.txt"
    )
);

$v_insult1 = new Voice_Cmd('Speak an insult');
$v_insult1->set_authority('anyone');

$v_insult1->set_info('Speaks an insult');
$v_insult2 = new Voice_Cmd '[Start,Stop] speaking insults';
$v_insult2->set_info(
    'Starts/stops a sequence of insults, optionally alternating between voices/cards'
);

$Misc{insult}{flag} = 1 if said $v_insult2 eq 'Start';
$Misc{insult}{flag} = 0 if said $v_insult2 eq 'Stop';

# Start speaking after prev speech is done.
if ( ( $Misc{insult}{flag} == 1 and !&Voice_Text::is_speaking('any') )
    or said $v_insult1)
{
    $Misc{insult}{flag} = 2 if $Misc{insult}{flag} == 1;
    $Misc{insult}{robot} =
      ( $Misc{insult}{robot} eq 'insult1' ) ? 'insult2' : 'insult1';
    my $text = read_random $f_insult;
    speak app => $Misc{insult}{robot}, text => $text;
    display
      window_name => 'insults',
      text        => "$Misc{insult}{robot}: $text\n\n",
      time        => 0,
      font        => 'Times 25 bold',
      append      => 'top',
      geometry    => '+0+0',
      width       => 80,
      height      => 25;
}

# Detect when we started speaking.
if ( $Misc{insult}{flag} == 2 and &Voice_Text::is_speaking('any') ) {
    $Misc{insult}{flag} = 3;
}

# Detect when we done speaking, then restart
if ( $Misc{insult}{flag} == 3 and !&Voice_Text::is_speaking('any') ) {
    &eval_with_timer( '$Misc{insult}{flag} = 1', 2 );
    $Misc{insult}{flag} = 0;
}
