
# Test File_Item read_next

$test_fileread1 = new Voice_Cmd 'Test file read [0,1,9999]';

$test_file = new File_Item "$Pgm_Root/data/remarks/personal_good.txt";

if ( $state = said $test_fileread1) {
    set_index $test_file $state;
    my $text = read_next $test_file;
    print_log "File data: $text";
}
