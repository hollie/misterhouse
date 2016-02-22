# Category=Informational

#@ Announces misc. reminders.

$plant_talk =
  new File_Item("$config_parms{data_dir}/remarks/list_plant_talk.txt");
speak(
    "rooms=all voice=Claire The plants want to be watered.  They gave me the following message:"
      . &Voice_Text::set_voice( 'male', read_next $plant_talk) )
  if time_cron('20 12,16,18 * * 0');

$cat_talk = new File_Item("$config_parms{data_dir}/remarks/list_cat_talk.txt");

# speak(voice=>'Audrey', rooms => 'all', text => "Notice, " . read_next $cat_talk) if time_cron('40 18,20 * * 0,4');

#speak("rooms=all It is now sunset at $sunset") if $Time_Now == $Time_Sunset;

#if (time_cron('05 16,18,20 * * 0,2,4')) {
if ( time_cron('05 18,20 * * 0,3') ) {
    my @nick_reminders = (
        'you know what to do',
        'time for the double D',
        'Mister Clean is looking for you',
        'can you spell htab?',
        'thaats right, its not your birthday, your birthday',
        'time to sink or swim',
        'time for your moment of Zen',
        'guess what day of the week it is today?',
        'you have your choice, you can eat scaloped potatoes, or you can do that thing you are supposed to do'
    );

    #   speak "rooms=all voice=Charles $Time_Now.  Nick, " . $nick_reminders[int rand @nick_reminders];
}

sub speak_anniversary {
    my ( $year, $person, $type ) = @_;
    my $years = &speakify_numbers( $Year - $year );
    speak(
        "voice=Claire Listen up everybody.  Today is ${person}'s $years $type!"
    );
}

&speak_anniversary( 1953, 'Mal & Beth', 'anniversary' )
  if ( time_cron('0 8,10,14,18,22  4 11 *') );
&speak_anniversary( 1958, 'John & Donna', 'anniversary' )
  if ( time_cron('0 8,10,14,18,22 31  8 *') );
&speak_anniversary( 1928, 'Mal', 'birthday' )
  if ( time_cron('0 8,10,14,18,22  8  6 *') );
&speak_anniversary( 1932, 'Beth', 'birthday' )
  if ( time_cron('0 8,10,14,18,22 18  5 *') );
&speak_anniversary( 1934, 'Johnny', 'birthday' )
  if ( time_cron('0 8,10,14,18,22  7  9 *') );
&speak_anniversary( 1940, 'Donna', 'birthday' )
  if ( time_cron('0 8,10,14,18,22  1  6 *') );
&speak_anniversary( 1959, 'Laurie', 'birthday' )
  if ( time_cron('0 8,10,14,18,22 22  4 *') );
&speak_anniversary( 1958, 'Bruce', 'birthday' )
  if ( time_cron('0 8,10,14,18,22  8  7 *') );

