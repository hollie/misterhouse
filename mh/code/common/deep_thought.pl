# Category = Entertainment

#@ Adds ability to request creative, goofy, and fun sayings.

my $f_deep_thought = "$config_parms{data_dir}/remarks/deep_thought.txt";
$f_deep_thoughts     = new File_Item("$config_parms{data_dir}/remarks/deep_thoughts.txt");
$v_deep_thought      = new  Voice_Cmd('[What is,Read,Display] the deep thought');
$v_deep_thought_next = new  Voice_Cmd('[What is,Read,Display] the next deep thought');
$v_deep_thought-> set_info('The deep thoughts are creative, goofy, and fun sayings from SNL (I think)');
$v_deep_thought_next-> set_authority('anyone');

$temp = join(',', &Voice_Text::list_voices);  # noloop
$v_deep_thought_voice = new Voice_Cmd "Speak deep thought with voice [$temp,random,next]";
$v_deep_thought_voice-> set_authority('anyone');

fileit($f_deep_thought, read_next $f_deep_thoughts) if said $v_deep_thought_next or $v_deep_thought_voice;

if ($state = said $v_deep_thought or $state = said $v_deep_thought_next) {
    respond app => 'deep_thought', text => $f_deep_thought if $state eq 'Read';
    display $f_deep_thought if $state eq 'What is';
    display text => $f_deep_thought, if $state eq 'Display';
}

speak voice => $state, text => $f_deep_thought if $state = said $v_deep_thought_voice;


$house_tagline = new  File_Item("$config_parms{data_dir}/remarks/1100tags.txt");
$v_house_tagline = new  Voice_Cmd('Read the house tagline', 'house tagline');
$v_house_tagline-> set_info('These are goofy one line taglines');
$v_house_tagline-> set_authority('anyone');
respond(app => 'tagline', text => read_next $house_tagline) if said $v_house_tagline;


