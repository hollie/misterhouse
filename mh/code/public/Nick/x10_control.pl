                                # Allow for control with an X10 palmpad
$mp3_start = new  Serial_Item('XN9NK', 'Play');
$mp3_start ->add             ('XN9NJ', 'Stop');
$mp3_start ->add             ('XNBNK', 'Next Song');
$mp3_start ->add             ('XNBNJ', 'Previous Song');
$mp3_start ->add             ('XNANK', 'Volume up');
$mp3_start ->add             ('XNANJ', 'Volume down');
 
if($state = state_now $mp3_start) {
    unless ($OS_win) {
        speak "Sorry, no mp3 client for this OS yet";
        return;
    }
    print_log "Setting mp3 to $state";
    run_voice_cmd "set mp3 player to $state";
}
