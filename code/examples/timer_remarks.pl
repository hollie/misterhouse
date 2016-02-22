
# An example of how to add some character to your timer reminders :)

$v_laundry_timer = new Voice_Cmd('Laundry timer [on,off]');
$v_laundry_timer->set_info(
    'Set a 35 minute timer to remind when the cloths are washed/dried');

$timer_laundry = new Timer;

if (   $state = said $v_laundry_timer
    or $state = state_now $laundry_timer)
{
    if ( $state eq ON ) {
        play( 'rooms' => 'shop', 'file' => 'cloths_started.wav' );

        # Speak a reminder 5 times, every 35 minutes
        set $timer_laundry 35 * 60, \&laundry_reminder, 5;
    }
    else {
        speak 'rooms=shop The laundry timer has been turned off.';
        set $timer_laundry 0;
    }
}

sub laundry_reminder {
    my @laundry_reminders = (
        'are ready for enlightenment',
        'are seeking proof of lint',
        'would like to hire a maid',
        'think you have fallen asleep',
        'are done with timeout',
        'would like to play in the mud',
        'have hired a hit man for that stupid snuggly bear',
        'think fabric softeners are for little girls',
        'have burned up on reentry',
        'are lost in the Bermuda triangle',
        'are eating spaghetti',
        'just saw Elvis',
        'just turned into that ugly guy from Threes Company',
        'are having dinner',
        'are electrocuting each other with static'
    );
    speak "rooms=all The laundry clothes "
      . $laundry_reminders[ int rand @laundry_reminders ];
}

