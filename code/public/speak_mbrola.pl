
# This is an example of how to to TTS with the mbrola speech engine
# To use this, use this mh.ini parm:  voice_text = &speak_mbrola
# Note:  All the speak parms (e.g. volume, voice, etc) are available in %parms

sub speak_mbrola {
    my %parms = @_;
    if ( $parms{to_file} ) {
        print "Sending text to $parms{to_file}\n";
        file_write '/tmp/sp.pho', $parms{text};
        my $mpath = '/home/users/usto/eHouse/mbrola';
        system(
            "$mpath/txt2pho/txt2pho -p $mpath/txt2pho/data/ -f -o i /tmp/sp.pho >o /tmp/spOut.pho"
        );
        system(
            "mbrola -v 0.7 -e $mpath/voices/de3/de3 /tmp/spOut.pho $parms{to_file}"
        );
        sleep(6);
    }
    else {
        # Do nothing, since you have no sound card
        print "Text not spoken: $parms{text}\n";
    }
}
