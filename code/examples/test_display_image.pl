$test_pic_v = new Voice_Cmd 'Test display picture [1,2,3,4,5]';

if ( $state = said $test_pic_v) {
    print_log
      "Running display picture test $state on $config_parms{html_dir}/graphics";
    display "$config_parms{html_dir}/graphics/funny_face.gif" if $state == 1;
    display "$config_parms{html_dir}/graphics/funny_face.jpg" if $state == 2;
}
