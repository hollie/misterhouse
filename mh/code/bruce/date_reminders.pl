# Category=Informational

$plant_talk = new File_Item("$config_parms{data_dir}/remarks/list_plant_talk.txt");
speak("rooms=all voice=female The plants want to be watered.  They gave me the following message:" .
      &Voice_Text::set_voice('male', read_next $plant_talk)) if time_cron('20 12,16,18 * * 0');

$cat_talk = new File_Item("$config_parms{data_dir}/remarks/list_cat_talk.txt");
speak(rooms => 'all', text => "Notice, " . read_next $cat_talk) if time_cron('40 18,20 * * 0,4');

#speak("rooms=all It is now sunset at $sunset") if $Time_Now == $Time_Sunset;

if (time_cron('05 16,18,20 * * 0,2,4')) {
    my @nick_reminders = 
      ('you know what to do', 'time for the double D', 'Mister Clean is looking for you',
       'can you spell htab?', 'thaats right, its not your birthday, your birthday', 
       'time to sink or swim', 'time for your moment of Zen', 'guess what day of the week it is today?',
       'you have your choice, you can eat scaloped potatoes, or you can do that thing you are supposed to do');
    speak "rooms=all $Time_Now.  Nick, " . $nick_reminders[int rand @nick_reminders];
}

my $years;
if (time_cron('0 8,10,14,18,22 4 11 *')) {
    $years = $Year - 1953;
    $years .= &speakify_numbers($years);
    speak("Listen up everybody.  Today is Mal & Beth's $years anniversary ... remember to give them a call!");
}

if (time_cron('0 8,10,14,18,22 31 8 *')) {
    $years = $Year - 1958;
    $years .= &speakify_numbers($years);
    speak("Listen up everybody.  Today is John & Donna's $years anniversary ... remember to give them a call!");
}

if (time_cron('0 8,10,14,18,22 8 6 *')) {
    $years = $Year - 1928;
    $years .= &speakify_numbers($years);
    speak("Listen up everybody.  Today is Mal's $years  birthday ... remember to give him a call!");
}

if (time_cron('0 8,10,14,18,22 18 5 *')) {
    $years = $Year - 1932;
    $years .= &speakify_numbers($years);
    speak("Listen up everybody.  Today is Beth's $years  birthday ... remember to give him a call!");
}

if (time_cron('0 8,10,14,18,22 7 9 *')) {
    $years = $Year - 1934;
    $years .= &speakify_numbers($years);
    speak("Listen up everybody.  Today is Johnny's $years  birthday ... remember to give him a call!");
}

if (time_cron('0 8,10,14,18,22 1 6 *')) {
    $years = $Year - 1940;
    $years .= &speakify_numbers($years);
    speak("Listen up everybody.  Today is Donna's $years  birthday ... remember to give her a call!");
}



