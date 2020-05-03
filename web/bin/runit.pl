return &runit(@ARGV);

sub runit {
    my ($cmd) = "@_";

    #print_log "-------------------- Original Command: $cmd";
    $cmd =~ s/_/ /g;

    #print_log "-------------------- Manipulated Command: $cmd";
    # Look for exact command matches
    if ( &process_external_command( $cmd, 1, 'android', 'speak' ) ) {
        print_log "-------------------- Exact Command Match $cmd";
        return &html_page( '', 'done' );
    }

    # added by Brian: STRIP out articles and then check for exact command match
    $cmd =~ s/the //g;
    $cmd =~ s/to //g;
    $cmd =~ s/turn //g;

    $cmd =~ s/an //g;
    $cmd =~ s/make //g;
    $cmd =~ s/switch //g;

    if ( &process_external_command( $cmd, 1, 'android', 'speak' ) ) {
        print_log "-------------------- Exact Command Match removing articles $cmd";
        return &html_page( '', 'done' );
    }

    # Look for nearest fuzzy match
    my $cmd1 = &phrase_match1($cmd);
    print_log "-------------------- Fuzzy Command Match $cmd1";
    &process_external_command( $cmd1, 1, 'android', 'speak' );
    return &html_page( '', 'done' );

    #                               # Added by Brian: Give up
    #    print_log "-------------------- No command found $cmd";
    #    play('file' => 'c:\mh\sounds\log.wav');
    #    return &html_page('', 'No command found');

}
