# Category=Test

$v_test_dropdown = new Voice_Cmd(
    'Set dropdown thermostat to [65,66,67,68,69,70,71,72,73,74,75,76,78,79,80]'
);
$v_test_dropdown->set_info('Test of the dropdown widget');
$v_test_dropdown->set_web_style('dropdown');
if ( $state = said $v_test_dropdown) {
    speak( text => "Dropdown widget changed to $state degrees." );
}

$v_test_radio = new Voice_Cmd(
    'Set radio thermostat to [65,66,67,68,69,70,71,72,73,74,75,76,78,79,80]');
$v_test_radio->set_info('Test of the radio widget');
$v_test_radio->set_web_style('radio');
if ( $state = said $v_test_radio) {
    speak( text => "Radio widget changed to $state degrees." );
}

$v_test_url = new Voice_Cmd(
    'Set url thermostat to [65,66,67,68,69,70,71,72,73,74,75,76,78,79,80]');
$v_test_url->set_info('Test of the url widget');
$v_test_url->set_web_style('url');
if ( $state = said $v_test_url) {
    speak( text => "URL widget changed to $state degrees." );
}
