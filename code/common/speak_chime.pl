
# Category = MisterHouse

#@ Adds an announcement chime prior to to any time-based speech,
#@ to avoid startle-ization (technical term for being surprised)

# NOTE: Do not rely on global $Respond_Target as it is not 100% accurate (and silly in this context.)
# Use chime, force_chime and no_chime to control chimes (or lack thereof) explicitly.

# chime - name of sound event or file (default is $config_parms{sound_speak_chime})
# no_chime - no chime
# force_chime - always chimes

# If you call speak or respond in code, think about what you are doing.  Is it an interactive response or not?
# If the latter two are not passed, the global $Respond_Target is referenced as in past versions (and chimes grow more sporadic as traffic increases.)

&Speak_pre_add_hook( \&speak_chime ) if $Reload;

sub speak_chime {
    my %parms = &parse_func_parms(@_);
    my $chime;

    # Only chime on time-based events, not
    # interactive events like tk/web/email/IM/vr triggered
    print
      "db speak_chime respond=$Respond_Target app=$parms{app} t=$parms{text}\n"
      if $main::Debug{chime};

    if ( !$parms{force_chime} ) {

        #return if $parms{app} eq 'router'; # *** Set router app to no_chime in mh.ini
        return if $parms{nolog};
        return if $parms{mode} eq 'mute';
        return if $parms{no_chime};
    }

    $chime = $parms{chime};

    if (   !defined $Respond_Target
        or $Respond_Target eq ''
        or $Respond_Target eq 'unknown'
        or $Respond_Target =~ /usercode/i
        or $Respond_Target eq 'time'
        or $parms{force_chime} )
    {
        my $file = $chime || $config_parms{sound_speak_chime};
        my $vol = $config_parms{sound_speak_chime_volume} || 100;

        # *** Yecch!  Remove and put in mh.ini file
        $file = 'sound_trek1.wav' unless $file;
        play volume => $vol, file => $file;
        &sleep_time(400);

    }
}
