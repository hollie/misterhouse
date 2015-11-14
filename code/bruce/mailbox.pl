# Category=none

#@ Monitors the mailbox sensor across the street

speak "Wireless sensor 1 has been triggered" if OPENED eq state_now $wireless1;

$timer_mailbox1 = new Timer();
$timer_mailbox2 = new Timer();

if ( OPENED eq state_now $mailbox and inactive $timer_mailbox2) {
    speak("rooms=all A Message from your mailbox");
    sleep 2;    # Yucky ... see if this enables playing of wave file.
    play( "rooms" => "all", "file" => "Mail_*.wav" );

    # Set the 'new mail' reminder
    if (    inactive $timer_mailbox1
        and inactive $timer_mailbox2
        and time_greater_than("10:00")
        and time_less_than("6:00 PM") )
    {
        speak "mail reminder has been set";
        set $timer_mailbox2 30 * 60,
          'speak("rooms=all Notice, you have mail in the mailbox")', 8;
    }
}

# If we used the front door recently, assume we got the mail
if (   state_now $garage_door
    or state_now $garage_entry_door
    or state_now $entry_door
    or state_now $front_door)
{
    set $timer_mailbox1 300;
    unset $timer_mailbox2;
}
