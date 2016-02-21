# Category = Entertainment

#@ Adds ability to request creative, goofy, and fun sayings (well, goofy anyway)
#@ Quotes are from early 90's SNL.

#noloop=start
my $f_deep_thought = "$config_parms{data_dir}/remarks/deep_thought.txt";
$f_deep_thoughts =
  new File_Item("$config_parms{data_dir}/remarks/deep_thoughts.txt");
$v_deep_thought      = new Voice_Cmd('What is the deep thought');
$v_deep_thought_next = new Voice_Cmd('What is the next deep thought');
$v_deep_thought->set_info(
    'The deep thoughts are creative, goofy, and fun sayings from SNL');
$v_deep_thought_next->set_authority('anyone');

my $temp_deep_thought = join( ',', &Voice_Text::list_voices );
$v_deep_thought_voice = new Voice_Cmd
  "Speak deep thought with voice [$temp_deep_thought,random,next]";
$v_deep_thought_voice->set_authority('anyone');

$house_tagline = new File_Item("$config_parms{data_dir}/remarks/1100tags.txt");
$v_house_tagline = new Voice_Cmd( 'Read the house tagline', 'house tagline' );
$v_house_tagline->set_info('These are goofy one line taglines');
$v_house_tagline->set_authority('anyone');

$v_deep_thought->tie_event('&read_deep_thought($v_deep_thought)');
$v_deep_thought_next->tie_event('&read_deep_thought($v_deep_thought_next)');
$v_deep_thought_voice->tie_event(
    '&read_deep_thought($v_deep_thought_voice, $state)');

#noloop=stop

# Update to next deep thought

fileit( $f_deep_thought, read_next $f_deep_thoughts)
  if said $v_deep_thought_next or said $v_deep_thought_voice;

# Tied to deep thought voice commands

sub read_deep_thought {
    my $object = shift;
    my $voice  = shift;
    $object->respond( ( ($voice) ? "voice=$voice " : '' ) . $f_deep_thought );
}

# Reads a different tagline each time (need some better taglines!)

$v_house_tagline->respond( "app=tagline" . read_next $house_tagline)
  if said $v_house_tagline;
