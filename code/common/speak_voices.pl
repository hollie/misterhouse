# Category = Test

#@ Speaks a phrase using different voices for each word

=begin comment

This is a mostly useless piece code that will demonstrate using
a different voice to speak each word in a phrase.   
Inspired by dictionaraoke.org, where switching voices sounds
ok with music and when you know what the words will be,
here it sounds pretty unintelligible :)

Nice demonstration of reading and writing wav files though :)

=cut

$v_voices_speak_many = new Voice_Cmd 'Test speech with many voices [1,2,3]';

$f_deep_thoughts =
  new File_Item("$config_parms{data_dir}/remarks/deep_thoughts.txt");
$f_house_tagline =
  new File_Item("$config_parms{data_dir}/remarks/1100tags.txt");

if ( said $v_voices_speak_many) {
    my $state = $v_voices_speak_many->{state};

    # This works with XML enabled TTS engines (MSV5 and linux naturalvoices)
    if ( $state == 1 ) {
        speak voice => 'all', display => 30, text => read_next $f_deep_thoughts;
    }
    elsif ( $state == 2 ) {
        speak voice => 'all', text => read_next $f_house_tagline;
    }

    # This should work with all engines
    elsif ( $state == 3 ) {
        my $tagline = read_next $f_house_tagline;
        print_log "Speaking $tagline";
        my_use "Audio::Wav";    # Used to read and write wav files
        my $wav = new Audio::Wav;
        my ( $wav_read, $wav_write );
        my $wav_file1 = "$config_parms{data_dir}/mh_temp.wav";
        my $i         = 0;
        for my $word ( split ' ', $tagline ) {
            my $wav_file2 = "$config_parms{data_dir}/mh_temp" . $i++ . ".wav";
            print "Synthesizing $word\n";
            speak
              to_file     => $wav_file2,
              compression => 'none',
              text        => $word,
              async       => 0,
              voice       => 'next';
            $wav_read = $wav->read($wav_file2);
            $wav_write = $wav->write( $wav_file1, $wav_read->details() )
              unless $wav_write;
            $wav_write->write_raw( $wav_read->read_raw(100000) );
        }
        $wav_write->finish();
        speak $wav_file1;
    }
}
