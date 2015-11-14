#!/usr/bin/perl
#############################################################################
#
# test program for writing/reading STDOUT/STDIN
#  - this allows mh to interact with another program using
#    STDIN and STDOUT.  Note, mh will hang if it looks
#    for data from TEST_IN and there is none.
#
#  - maybe could be used to control linux mp3 player mpg123 -R ??
#
#############################################################################

use IPC::Open2;

if ($Reload) {
    print "opening open2 test driver\n";
    open2( *TEST_IN, *TEST_OUT, 'perl /misterhouse/test/test_open2_driver' );
}

$v_open2_test = new Voice_Cmd 'Test the open2 handle';

my $i;
if ( $state = said $v_open2_test) {
    $i++;
    print_log "Seting open2 driver to $i";
    print TEST_OUT "Test set to $i\n";
    print_log "Reading response";
    my $output = <TEST_IN>;
    print_log "output =$output";
}
