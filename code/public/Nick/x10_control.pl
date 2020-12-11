# Allow for control with an X10 palmpad
$x10_control = new Serial_Item( 'XN9NK', 'Play' );
$x10_control->add( 'XN9NJ', 'Stop' );
$x10_control->add( 'XNANK', 'Check time' );
$x10_control->add( 'XNANJ', 'Act smart' );
$x10_control->add( 'XNBNK', 'Next Song' );
$x10_control->add( 'XNBNJ', 'Previous Song' );
$x10_control->add( 'XNFNK', 'Volume up' );
$x10_control->add( 'XNFNJ', 'Volume down' );

$april_fools = new File_Item("../data/remarks/april_fools.txt");

if ( $state = state_now $x10_control) {
    print_log "Running x10 control $state";
    if ( $state eq 'Check time' ) {
        run_voice_cmd "What is my computer time";
    }
    elsif ( $state eq 'Act smart' ) {
        speak( read_next $april_fools);
    }
    else {
        run_voice_cmd "set mp3 player to $state";
    }
}

