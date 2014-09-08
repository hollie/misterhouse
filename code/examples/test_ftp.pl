
# Shows different ways of doing ftp commands

$v_test_ftp = new Voice_Cmd 'Test ftp [get,put]';

if ( $state = said $v_test_ftp) {
    print_log "Testing ftp $state";
    my $rc = net_ftp(
        file        => 'c:/junk1.txt',
        file_remote => 'incoming/junk1.txt',
        command     => $state,
        server      => 'misterhouse.net',
        user        => 'anonymous',
        password    => 'bruce@misterhouse.net'
    );
    print_log "net_ftp delete results: $rc";
}

$v_test_ftpb = new Voice_Cmd 'Test background ftp [get,put]';
$p_test_ftpb = new Process_Item;

if ( $state = said $v_test_ftpb) {
    print_log "Testing background ftp $state";

    # Process cmds that start with & are assumed
    # to be internal subroutine and are run with eval
    # Currently this only works on unix systems.
    set $p_test_ftpb
      "&main::net_ftp(file => 'c:/junk1.txt', file_remote => 'incoming/junk1.txt',"
      . "command => '$state', server => 'misterhouse.net',"
      . "user => 'anonymous', password => 'bruce\@misterhouse.net')";
    start $p_test_ftpb;
    print_log "net_ftp $state command started";
}

if ( done_now $p_test_ftpb) {
    print_log "Ftp command done";
}

$v_test_ftpb2 = new Voice_Cmd 'Test external ftp [get,put]';
if ( $state = said $v_test_ftpb2) {
    print_log "Testing external ftp $state";
    set $p_test_ftpb
      "net_ftp -file c:/junk1.txt -file_remote incoming/junk1.txt "
      . "-command $state -server misterhouse.net "
      . "-user anonymous -password bruce\@misterhouse.net";
    start $p_test_ftpb;
    print_log "net_ftp $state command started";
}
