
# Category = MisterHouse

#@ Adds an announcement chime prior to to any time based speech,
#@ to avoid startle-ization (technical term for being surprised)

#run_voice_cmd 'What time is it' if new_second 20;

&Speak_pre_add_hook(\&speak_chime) if $Reload;

sub speak_chime {
    my %parms = @_;
                                # Only chime on time-based events, not
                                # interactive events like tk or web triggered
    print "db speak_chime respond=$Respond_Target app=$parms{app} t=$parms{text}\n" if $Debug{'speak'};
    $Respond_Target = 'unknown' unless $Respond_Target;
    return if $parms{app} eq 'router';
    return unless $Respond_Target eq 'unknown';
    if (!$Respond_Target or $Respond_Target eq 'unknown' or $Respond_Target eq 'time') {
        my $file = $config_parms{sound_speak_chime};
        my $vol  = $config_parms{sound_speak_chime_volume};
        $file = 'sound_trek1.wav' unless $file;
        play volume=>$vol, file=>$file;
        &sleep_time(400);    
    }
}
