# Category = Entertainment

#@ Adds ability to request creative, goofy, and fun sayings.

my $f_deep_thought = "$config_parms{data_dir}/remarks/deep_thought.txt";
$f_deep_thoughts     = new File_Item("$config_parms{data_dir}/remarks/deep_thoughts.txt");
$v_deep_thought      = new  Voice_Cmd('[What is,Read,Display] the deep thought');
$v_deep_thought_next = new  Voice_Cmd('[What is,Read,Display] the next deep thought');
$v_deep_thought-> set_info('The deep thoughts are creative, goofy, and fun sayings from SNL (I think)');
$v_deep_thought_next-> set_authority('anyone');

fileit($f_deep_thought, read_next $f_deep_thoughts) if said $v_deep_thought_next;

if ($state = said $v_deep_thought or $state = said $v_deep_thought_next) {
    speak   app => 'deep_thought', text => $f_deep_thought if $state eq 'Read';
    display $f_deep_thought if $state eq 'What is';
    display text => $f_deep_thought, font => 25 if $state eq 'Display';
}

$house_tagline = new  File_Item("$config_parms{data_dir}/remarks/1100tags.txt");
$v_house_tagline = new  Voice_Cmd('Read the house tagline', 'house tagline');
$v_house_tagline-> set_info('These are goofy one line taglines');
$v_house_tagline-> set_authority('anyone');
speak(app => 'tagline', text => read_next $house_tagline) if said $v_house_tagline;
