# Category=Informational

speak('rooms=all Nick, remember to take your stinky meat pictures') if time_cron('15,30,45 19 * * *');
 
speak('rooms=all Remember to take out the garbage') if time_cron('0 17,19 * * 4');

$plant_talk = new File_Item("$config_parms{data_dir}/remarks/list_plant_talk.txt");
speak("rooms=all The plants want to be watered.  They gave me the following message:" .
	read_next $plant_talk) if time_cron('20 12,16,18 * * 0');

speak("rooms=all The milkman should be here in a few minutes.") if time_cron('45 6 * * 2');

speak("rooms=all It is now $Time_Now") if time_cron('0 10-21 * * *');

#speak("rooms=all It is now sunset at $sunset") if $Time_Now == $Time_Sunset;

speak("rooms=all $Time_Now.  Remember to kill the dirt sometime today.") if
    time_cron('05 16,18,20 * * 3');
#   time_cron('05 13,15,17 * * 0') or


my $years;
if (time_cron('0 8,10,14,18,22 4 11 *')) {
    $years = $Year - 1956;
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

speak("Ho, Ho, Ho, Merry Christmas.") if time_cron('0 10,14,18,22 25 12 *');

speak("Happy, happy, new year one and all.") if time_cron('0 10,14,18,22 1 1 *');

speak("Yearly notice: Remember to write down car mileage") if time_cron('0 9,12,20 00 12 *');


