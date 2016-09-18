
# Category=Voice

$voice_reset = new Voice_Cmd 'Reset M S Voice';
$voice_reset->set_info(
    'This is needed to work around a MSVoice bug.  Use it if it stops responding'
);

if ( said $voice_reset) {
    unlink
      'c:/Program Files/Common Files/Microsoft Shared/SpeechEngines/MSCSR/amengpc.env';
    print_log 'File was reset.  Restart MSVoice';
}
