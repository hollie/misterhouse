#Category=Inline

#Controls the Inline video scan doubler:
# http://www.inlineinc.com/tech/manuals/pdf/1424man.pdf

$inline = new Video_InLine;

$v_inline_ch = new Voice_Cmd('Set Inline to channel [1,2,3,4]');
if ( $state = said $v_inline_ch) {
    $inline->channel($state);
}
$v_inline_input = new Voice_Cmd('Set Inline input type to [SVideo,Composite]');
if ( $state = said $v_inline_input) {
    $inline->input($state);
}
$v_inline_screen = new Voice_Cmd('[Blank,Unblank] Inline screen');
if ( $state = said $v_inline_screen) {
    $inline->screen($state);
}
$v_inline_panel = new Voice_Cmd('[Enable,Disable] Inline Buttons');
if ( $state = said $v_inline_panel) {
    $inline->panel($state);
}
$v_inline_save = new Voice_Cmd('Save Inline Settings');
if ( $state = said $v_inline_save) {
    $inline->save;
}
$v_inline_sharp =
  new Voice_Cmd('[Increase,Decrease, Default] Inline Sharpness');
if ( $state = said $v_inline_sharp) {
    $inline->sharp($state);
}
$v_inline_brightp =
  new Voice_Cmd('[Increase,Decrease, Default] Inline Brightness');
if ( $state = said $v_inline_sharp) {
    $inline->bright($state);
}
$v_inline_hue = new Voice_Cmd('[Increase,Decrease, Default] Inline Hue');
if ( $state = said $v_inline_hue) {
    $inline->hue($state);
}
$v_inline_contrast =
  new Voice_Cmd('[Increase,Decrease, Default] Inline Contrast');
if ( $state = said $v_inline_contrast) {
    $inline->contrast($state);
}
$v_inline_saturation =
  new Voice_Cmd('[Increase,Decrease, Default] Inline Saturation');
if ( $state = said $v_inline_saturation) {
    $inline->saturation($state);
}
$v_inline_scan = new Voice_Cmd('Set Inline to [Single,Double] Scan');
if ( $state = said $v_inline_scan) {
    $inline->scan($state);
}
$v_inline_message = new Voice_Cmd('Send InLine Message');
if ( $state = said $v_inline_message) {
    $inline->message("This is a test");
}

