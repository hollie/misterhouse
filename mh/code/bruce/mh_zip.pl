# Category=MisterHouse

$v_zip_code = new  Voice_Cmd 'Zip up misterhouse source code';
$v_zip_code-> set_info('Zips up the current code to http://misterhouse.net/public/misterhouse_src_test.zip');

$v_zip_win  = new  Voice_Cmd 'Zip up misterhouse windows code';
$v_zip_win -> set_info('Compile and zip the windows mh.exe to http://misterhouse.net/public/misterhouse_win_test.zip');


$p_zip_code = new  Process_Item 'c:/misterhouse/bin/run_zip.bat test';

if (said $v_zip_code) {
    print_log 'Zipping up test code';
    start $p_zip_code;
}

if (done_now $p_zip_code) {
    speak 'Zip of source code is done';
    copy 'c:/misterhouse/upload/misterhouse_src_test.zip', '//misterhouse/public';
}


$p_zip_win1 = new  Process_Item 'c:/misterhouse/compile/compile.bat';
$p_zip_win2 = new  Process_Item 'c:/misterhouse/bin/run_zip_compiled.bat test';

if (said $v_zip_win) {
    print_log 'Zipping up windows code';
    start $p_zip_win1;
}

start $p_zip_win2 if done_now $p_zip_win1;
if (done_now $p_zip_win2) {
    speak 'Zip of windows code is done';
    copy 'c:/misterhouse/upload/misterhouse_win_test.zip', '//misterhouse/public';
}

