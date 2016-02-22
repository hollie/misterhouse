
# - Disable local speech.   By default, it is now spoken by common/xAP_send.pl -> other mh clients.

&Speak_parms_add_hook( \&speak_disable, 0 ) if $Reload;

sub speak_disable {
    my ($parms_ref) = @_;

    $$parms_ref{no_speak} = 1
      unless $$parms_ref{card}
      or $$parms_ref{rooms}
      or $$parms_ref{file};    # Disable local speech

}
