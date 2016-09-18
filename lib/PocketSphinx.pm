
=head1 B<PocketSphinx_Control>

=head2 SYNOPSIS

NONE

=head2 DESCRIPTION

Use this module to control the PocketSphinx VR engine (currently Linux only)

Requirements:

Download and install Sphinxbase, PocketSphinx, and CMU Language Toolkit
http://cmusphinx.sourceforge.net/wiki/download/

 Current Version Supported:
 PocketSphinx: 0.7
 SphinxBase:   0.7
 Cmuclmtk:     0.7

When building SphinxBase, it will default to OSS, if you want ALSA (recommended) then you
need to add --with-alsa to the configure command.

Install and configure all the above software.  Set these values in your mh.private.ini file
Note that all those marked as default are in mh.ini and need not be loaded unless truly different.
Enable the pocket_sphinx_control module in misterhouse setup (code/common).

=head2 INHERITS

B<Generic_Item>

=head2 METHODS

=over

=cut

use strict;

package PocketSphinx_Control;

@PocketSphinx_Control::ISA = ('Generic_Item');

use Process_Item;
use Voice_Cmd;
use Timer;
use File::Compare;

my $PocketSphinx_state;
my $p_sphinx       = undef;
my $s_pocketsphinx = undef;

my $sentence_file = "$main::config_parms{data_dir}/pocketsphinx/current.sent";
my $lm_file       = "$main::config_parms{data_dir}/pocketsphinx/current.lm.DMP";
my $lm_log_file   = "$main::config_parms{data_dir}/pocketsphinx/build_lm.log";
my $hmm_file   = "/usr/local/share/pocketsphinx/model/hmm/en_US/hub4wsj_sc_8k";
my $awake_time = 300;

sub startup {
    if ( not defined $s_pocketsphinx
        and exists $main::config_parms{server_pocketsphinx_port} )
    {
        &main::print_log("PocketSphinx_Control:: initializing")
          if $main::Debug{pocketsphinx};

        # Setup VR mode
        $main::config_parms{voice_cmd} = "pocketsphinx";

        # Create a socket for the external VR program to communicate to
        $s_pocketsphinx =
          new Socket_Item( undef, undef, 'server_pocketsphinx' );

        # Setup our callback to get voice commands from the socket
        Voice_Cmd::init_pocketsphinx( \&said );

        #$main::Debug{pocketsphinx} = 1;
        #$main::Debug{process} = 1;
        #$main::Debug{voice} = 1;

        # we need to killall the pocketsphinx processes until I figure out how to get
        # store_object_data working for library modules.
        # system ("killall pocketsphinx");

        # Create some classes we need
        $p_sphinx = new Process_Item;
        my $friendly_name = "PocketSphinx_Control_p_sphinx";
        &main::store_object_data( $p_sphinx, 'Process_Item', $friendly_name,
            $friendly_name );
        $PocketSphinx_state = "idle";

        # Now build the language models from the various voice commands.
        stop $p_sphinx;
        mkdir( "$main::config_parms{data_dir}/pocketsphinx", 0777 )
          unless -d "$main::config_parms{data_dir}/pocketsphinx";

        # Insure we have all the files we need, if so, start the process
        $hmm_file = "$main::config_parms{pocketsphinx_hmm}"
          if exists $main::config_parms{pocketsphinx_hmm};
        if ( !-e $hmm_file ) {
            &main::print_log(
                "PocketSphinx_Control:: ERROR: file: $hmm_file MISSING!!");
        }
        else {
            &::MainLoop_pre_add_hook( \&PocketSphinx_Control::state_machine,
                'persistent' );
            &::Reload_pre_add_hook( \&PocketSphinx_Control::restart,
                'persistent' );
        }
    }
}

=item C<_trim>

Trim leading and trailing spaces

=cut

sub _trim {
    my $string = shift;
    $string =~ s/^\s+//;
    $string =~ s/\s+$//;
    return $string;
}

=item C<restart>

Shut down the process before we restart

=cut

sub restart {
    $p_sphinx->stop();
}

=item C<said>

Check for any new voice command from external pocketsphinx client(s)

=cut

sub said {
    my $text;
    if ( my $tmp = said $s_pocketsphinx) {
        &main::print_log("PocketSphinx_Control:: said: $tmp")
          if $main::Debug{pocketsphinx};

        # search for awake phrase
        if ( $main::Save{vr_mode} eq "asleep" ) {
            foreach (
                split( /,/, $main::config_parms{pocketsphinx_awake_phrase} ) )
            {
                my $token = $_;

                #strip leading/trailing white space
                $token =~ s/^\s+//;
                $token =~ s/\s+$//;
                $token =~ s/[\{\}]//;
                $token = lc($token);
                if ( $tmp eq $token ) {
                    $text = $tmp;
                }
                &main::print_log(
                    "PocketSphinx_Control:: tmp: $tmp text: $text token: $token"
                ) if $main::Debug{pocketsphinx};
            }
        }
        else {
            $text = $tmp;
        }
    }
    return $text;
}

sub state_machine {
    my ($self) = @_;
    if ( $main::Startup or $main::Reload or ( $PocketSphinx_state eq "reset" ) )
    {
        &build_sentence_file($sentence_file);
        $PocketSphinx_state = "build_lm";
        &main::print_log("PocketSphinx_Control:: build_lm")
          if $main::Debug{pocketsphinx};
        set_errlog $p_sphinx
          "$main::config_parms{data_dir}/pocketsphinx/build_lm.stderr";
        set_output $p_sphinx
          "$main::config_parms{data_dir}/pocketsphinx/build_lm.stdout";
        my $pgm_root = "/usr/local/bin";
        if ( $self->{continuous} =~ /(\S+)\/pocketsphinx/ ) {
            $pgm_root = $1;
        }
        my $data_root = "$main::config_parms{data_dir}/pocketsphinx/current";
        set $p_sphinx
          "&PocketSphinx_Control::build_lm ('$pgm_root','$data_root','$lm_log_file')";
        start $p_sphinx;
    }

    # wait for build_lm to complete
    if ( $PocketSphinx_state eq "build_lm" ) {
        if ( done $p_sphinx) {
            &main::print_log("PocketSphinx_Control:: run_sphinx")
              if $main::Debug{pocketsphinx};
            $PocketSphinx_state = "run_sphinx";
            set_errlog $p_sphinx "";
            set_output $p_sphinx "";
        }
    }
}

sub get_state {
    return $PocketSphinx_state;
}

sub reset_language_files {
    my ($self) = @_;
    $PocketSphinx_state = "reset";
    $self->{disabled} = 0;
}

=item C<build_sentence_file>

BUILD SENTENCE FILE

=cut

sub build_sentence_file {
    my ($sentence_file) = @_;

    #first write the sentence file
    open( OUTPUT, ">$sentence_file" );
    my @phrase_array = &Voice_Cmd::voice_items( 'mh', 'no_category' );
    @phrase_array = sort(@phrase_array);
    foreach my $cmd (@phrase_array) {
        chomp $cmd;
        $cmd = lc($cmd);
        print OUTPUT "<s> $cmd </s>\n";
    }
    close OUTPUT;
}

=item C<build_lm>

BUILD LANGUAGE MODEL FILE

1) Prepare a reference text that will be used to generate the language model. 
The language model toolkit expects its input to be in the form of normalized text files, 
with utterances delimited by <s> and </s> tags. A number of input filters are available 
for specific corpora such as Switchboard, ISL and NIST meetings, and HUB5 transcripts. 
The result should be the set of sentences that are bounded by the start and end sentence 
markers: <s> and </s>. 

Here's an example:

  <s> generally cloudy today with scattered outbreaks of rain and drizzle persistent and heavy at times </s>
  <s> some dry intervals also with hazy sunshine especially in eastern parts in the morning </s>
  <s> highest temperatures nine to thirteen Celsius in a light or moderate mainly east south east breeze </s>
  <s> cloudy damp and misty today with spells of rain and drizzle in most places much of this rain will be 
  light and patchy but heavier rain may develop in the west later </s>

2) Generate the vocabulary file. This is a list of all the words in the file:

  text2wfreq < weather.txt | wfreq2vocab > weather.tmp.vocab

3) You may want to edit the vocabulary file to remove words (numbers, misspellings, names). 
If you find misspellings, it is a good idea to fix them in the input transcript.

4) If you want a closed vocabulary language model (a language model that has no provisions 
for unknown words), then you should remove sentences from your input transcript that contain
words that are not in your vocabulary file.

5) Generate the arpa format language model with the commands:

  % text2idngram -vocab weather.vocab -idngram weather.idngram < weather.closed.txt
  % idngram2lm -vocab_type 0 -idngram weather.idngram -vocab \
     weather.vocab -arpa weather.arpa

6) Generate the CMU binary form (DMP)

  % sphinx_lm_convert -i weather.arpa -o weather.lm

  /usr/local/bin/text2wfreq < current.sent | /usr/local/bin/wfreq2vocab > current.vocab
  text2idngram -vocab current.vocab -idngram current.idngram < current.sent
  /usr/local/bin/idngram2lm -vocab_type 0 -idngram current.idngram -vocab current.vocab -arpa current.arpa
  /usr/local/bin/sphinx_lm_convert -i current.arpa -o current.lm

=cut

sub build_lm {

    # input parameters
    # quick_lm -s <sentence_file> [-w <word_file>] [-d discount]\n"); }
    my ( $pgm_root, $data_root, $logfile ) = @_;

    my $binary = "$pgm_root/sphinx_lm_convert";
    if ( !-e $binary ) {
        &main::print_log(
            "PocketSphinx Control:: ERROR: file: $binary MISSING!!");
        &main::print_log(
            "PocketSphinx Control:: Did you forget to install the Cmuclmtk?");
    }

    open( LOG, ">$logfile" );

    my $cmd =
      "$pgm_root/text2wfreq < $data_root.sent | $pgm_root/wfreq2vocab > $data_root.vocab";
    print LOG "$cmd\n";
    system $cmd;

    $cmd =
      "$pgm_root/text2idngram -vocab $data_root.vocab -idngram $data_root.idngram < $data_root.sent";
    print LOG "$cmd\n";
    system $cmd;

    $cmd =
      "$pgm_root/idngram2lm -vocab_type 0 -idngram $data_root.idngram -vocab $data_root.vocab -arpa $data_root.arpa";
    print LOG "$cmd\n";
    system $cmd;

    $cmd =
      "$pgm_root/sphinx_lm_convert -i $data_root.arpa -o $data_root.lm.DMP";
    print LOG "$cmd\n";
    system $cmd;

    close(LOG);

}

=back

=head2 INI PARAMETERS

  voice_cmd                    = pocketsphinx                   # REQUIRED
  server_pocketsphinx_port     = 3235                           # REQUIRED
  pocketsphinx_awake_phrase    = "mister house,computer"        # optional
  pocketsphinx_awake_response  = "yes master?"                  # optional
  pocketsphinx_awake_time=300                                   # optional
  pocketsphinx_asleep_phrase={go to sleep,change to sleep mode} # optional
  pocketsphinx_asleep_response=Ok, later.
  pocketsphinx_timeout_response=Later.

  pocketsphinx_hmm         = /usr/local/share/pocketsphinx/model/hmm/en_US/hub4wsj_sc_8k   # default
  pocketsphinx_rate        = 16000                                                         # default
  pocketsphinx_continuous  = /usr/local/bin/pocketsphinx_continuous                        # default
  pocketsphinx_dev         = default                                                       # default

Note: If using OSS instead of ALSA, pocketsphinx_device needs to be "/dev/dsp" or similiar.

  - pocketsphinx_awake_phrase:     Command(s) that will switch mh into active
                                   mode (all commands recognized) from asleep mode.
  - pocketsphinx_awake_response:   This is what is said (or played) when entering
                                   awake mode
  - pocketsphinx_awake_time:       Stay in awake mode for this many seconds after
                                   the last command was heard.  Then it switches
                                   to asleep mode. Set to 0 or blank to disable
                                   (always stay in awake mode).
  - pocketsphinx_asleep_phrase:    Command{s} to put mh into asleep mode.
  - pocketsphinx_asleep_response:  This is what it said (or played) when entering
                                   sleep mode
  - pocketsphinx_timeout_response: This is what is said (or played) when the awake
                                   timer expires.
  - pocketsphinx_hmm               Pocketsphinx Human Markov Model directory location.
  - pocketsphinx_rate              Audio Sample rate
  - pocketsphinx_continuous        Program location for pocketsphinx_continuous
  - pocketsphinx_dev               Audio device (multiple devices can be separated by "|")

=head2 AUTHOR

01/21/2007 Created by Jim Duda (jim@duda.tzo.com)

=head2 SEE ALSO

NONE

=head2 LICENSE

This program is free software; you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation; either version 2 of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more details.

You should have received a copy of the GNU General Public License along with this program; if not, write to the Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.

=cut

=head1 B<PocketSphinx_Listner>

=head2 SYNOPSIS

NONE

=head2 DESCRIPTION

NONE

=head2 INHERITS

B<Generic_Item>

=head2 METHODS

=over

=cut

package PocketSphinx_Listener;

@PocketSphinx_Listener::ISA = ('Generic_Item');

=item C<new>

Constructor

=cut

sub new {
    my ( $class, $device, $sample_rate, $listening, $speak ) = @_;
    my $self = {};
    bless $self, $class;

    &main::print_log("PocketSphinx_Listener:: initialization $device")
      if $main::Debug{pocketsphinx};

    # default the device if not defined
    if ( not defined $device ) {
        $device = "default";
        $device = "$main::config_parms{pocketsphinx_dev}"
          if exists $main::config_parms{pocketsphinx_dev};
    }

    # default the sample_rate if not defined
    if ( not defined $sample_rate ) {
        $sample_rate = 16000;
        $sample_rate = "$main::config_parms{pocketsphinx_sample_rate}"
          if exists $main::config_parms{pocketsphinx_sample_rate};
    }

    # load device and sample_rate parameters if available
    $self->{device}      = $device;
    $self->{sample_rate} = $sample_rate;

    # do we want to start listening upon startup?  we default to true
    if ( defined $listening ) {
        $self->{listening} = $listening;
    }
    else {
        $self->{listening} = 1;
    }

    # do we want to speak when ready to accepts commands?  we default to false
    if ( defined $speak ) {
        $self->{speak} = $speak;
    }
    else {
        $self->{speak} = 0;
    }

    # create some necessary classes
    $self->{p_sphinx} = new Process_Item;
    my $friendly_name = "PocketSphinx_Listener_p_sphinx_$device";
    &main::store_object_data( $self->{p_sphinx}, 'Process_Item',
        $friendly_name, $friendly_name );
    $self->{t_crash_timer} = new Timer;
    $self->{t_speak_timer} = new Timer;

    # file names from the Control portion
    $self->{log_file} =
      "$main::config_parms{data_dir}/pocketsphinx/pocketsphinx";
    $self->{sentence_file} =
      "$main::config_parms{data_dir}/pocketsphinx/current.sent";
    $self->{lm_file} =
      "$main::config_parms{data_dir}/pocketsphinx/current.lm.DMP";

    # run parameters
    $self->{hmm_file} =
      "/usr/local/share/pocketsphinx/model/hmm/en_US/hub4wsj_sc_8k";
    $self->{continuous} = "/usr/local/bin/pocketsphinx_continuous";
    $self->{host}       = "localhost";
    $self->{port}       = 3235;
    $self->{hmm_file}   = "$main::config_parms{pocketsphinx_hmm}"
      if exists $main::config_parms{pocketsphinx_hmm};
    $self->{continuous} = "$main::config_parms{pocketsphinx_continuous}"
      if exists $main::config_parms{pocketsphinx_continuous};
    $self->{port} = "$main::config_parms{server_pocketsphinx_port}"
      if exists $main::config_parms{server_pocketsphinx_port};

    # runtime maintenance
    $self->{disabled}  = 0;
    $self->{crash_cnt} = 0;
    &::MainLoop_pre_add_hook( \&PocketSphinx_Listener::state_machine,
        undef, $self );
    &::Reload_pre_add_hook( \&PocketSphinx_Listener::restart, undef, $self );
    &::Speak_parms_add_hook( \&PocketSphinx_Listener::speak, 0 );

    return $self;
}

=item C<set_hmm_file>

Set functions

=cut

sub set_hmm_file {
    my ( $self, $file ) = @_;
    $self->{hmm_file} = $file if -e $file;
}

sub set_sample_rate {
    my ( $self, $sample_rate ) = @_;
    $self->{sample_rate} = $sample_rate;
}

=item C<_trim>

Trim leading and trailing spaces

=cut

sub _trim {
    my $string = shift;
    $string =~ s/^\s+//;
    $string =~ s/\s+$//;
    return $string;
}

=item C<restore_string>

We need to save the persistent information for the Process_Item p_sphinx object between restart 
and startup such that we can safely kill any running pocketsphinx processes.  We'll save the
persistent information in restore_data and eval to play it out and restore the object 
information.

=cut

sub restore_string {
    &main::print_log("PocketSphinx_Listener:: restore_string called")
      if $main::Debug{pocketsphinx};
    my ($self)         = @_;
    my $restore_string = '';
    my $restore_data   = &_trim( $self->{p_sphinx}->restore_string() );
    $restore_data =~ s/\->/\$self\->{p_sphinx}\->/g;
    $restore_string .=
      $self->{object_name} . "->{restore_data} = q#$restore_data#;\n";
    $restore_string .= $self->{object_name} . "->restore();\n"
      if $self->{p_sphinx}->pid();
    return $restore_string;
}

=item C<restore>

Restore will be called on startup or restart such that we can play out the information
contained in p_shpinx_state, which represents the persistent data for the Process_Item
object.

=cut

sub restore {
    my ($self) = @_;
    my $restore_data = $self->{restore_data};
    &main::print_log("PocketSphinx_Listener:: restore_string: $restore_data")
      if $main::Debug{pocketsphinx};
    eval $restore_data;
    &main::print_log(
        "PocketSphinx_Listener:: restore: Error in Persistent data restore: $@\n"
    ) if $@;
    $self->{p_sphinx}->stop();
}

=item C<restart>

Shut down the process before we restart

=cut

sub restart {
    my ($self) = @_;
    $self->{p_sphinx}->stop();
}

=item C<speak>

Update speak parameters based upon context

=cut

sub speak {
    my ( $self, $parms_ref ) = @_;
    &main::print_log("PocketSphinx_Listener::speak called!!")
      if $main::Debug{pocketsphinx};
    my @rooms = split ',', lc $parms_ref->{rooms};
    foreach my $room (@rooms) {
        &main::print_log("PocketSphinx_Listener::speak room: $room\n");
    }
    if ( exists $self->{speak_room} ) {
        if ( !$self->{t_crash_timer}->active() ) {
            delete $self->{speak_room};
        }
        else {
            push @rooms, $self->{speak_room};
            $parms_ref->{rooms} = join ",", @rooms;
            my @rooms = split ',', lc $parms_ref->{rooms};
            foreach my $room (@rooms) {
                &main::print_log("PocketSphinx_Listener::speak room: $room\n")
                  if $main::Debug{pocketsphinx};
            }
            $self->{t_speak_timer}->set(60);
        }
    }
}

=item C<set_speak_room>

Define the speaking room

=cut

sub set_speak_room {
    my ( $self, $room ) = @_;
    $self->{speak_room} = $room;
    &main::print_log("PocketSphinx_Listener::set_speak_room room: $room\n")
      if $main::Debug{pocketsphinx};
    $self->{t_speak_timer}->set(60);
}

=item C<start_listner>

Allow the listener to startup on the next pass of the state_machine maintenance thread.

=cut

sub start_listener {
    my ($self) = @_;
    $self->{listening} = 1;
    &main::print_log("PocketSphinx_Listener:: start_listener $self->{device}")
      if $main::Debug{pocketsphinx};
}

=item C<stop_listner>

Stop any active listener program currently running

=cut

sub stop_listener {
    my ($self) = @_;
    $self->{p_sphinx}->stop() if ( !$self->{p_sphinx}->done() );
    $self->{listening} = 0;
    &main::print_log("PocketSphinx_Listener:: stop_listener $self->{device}")
      if $main::Debug{pocketsphinx};
}

=item C<state_machine>

The state_machine loop runs once each pass of misterhouse.  This is basically a maitanance thread
which insures that the listener is running, since it has been known to crash on its own.  We keep
a count of restarts to avoid thrashing since the crashes could be caused by bad configuration.

=cut

sub state_machine {
    my ($self) = @_;

    # check to see of the pocketsphinx VR program has completed, check for short crashes (something is wrong)
    if ( $self->{p_sphinx}->done_now() ) {
        &main::print_log(
            "PocketSphinx_Listener:: process_done: $self->{device}")
          if $main::Debug{pocketsphinx};
        if ( &PocketSphinx_Control::get_state() eq 'run_sphinx' ) {
            my $runtime = $self->{p_sphinx}->runtime();
            if ( $runtime < 60 ) {
                $self->{crash_cnt}++;
                $self->{t_crash_timer}->set(60);
                if ( $self->{crash_cnt} > 10 ) {
                    &main::print_log(
                        "PocketSphinx_Listener:: $self->{device} ERROR: disabled because the pocketsphinx_continuous program exited too quickly ($runtime) ... check $self->{log_file}_$self->{device}.stderr"
                    );
                    $self->{disabled} = 1;
                }
            }
            else {
                $self->{crash_cnt} = 0;
            }
        }
    }

    # keep the pocketsphinx voice recognition program running externally
    if ( &PocketSphinx_Control::get_state() eq "run_sphinx" ) {
        if (   $self->{p_sphinx}->done()
            && !$self->{disabled}
            && $self->{listening}
            && !$self->{t_crash_timer}->active() )
        {
            &main::print_log(
                "PocketSphinx_Listener:: run_sphinx $self->{device}")
              if $main::Debug{pocketsphinx};
            $self->{p_sphinx}
              ->set_errlog("$self->{log_file}_$self->{device}.stderr");
            $self->{p_sphinx}
              ->set_output("$self->{log_file}_$self->{device}.stdout");
            $self->{p_sphinx}->set_killsig("TERM");
            my $command = join " ",
              "pocketsphinx ",
              "-host $self->{host}",
              "-port $self->{port}",
              "-log_file $self->{log_file}",
              "-sent_file $self->{sentence_file}",
              "-lm_file $self->{lm_file}",
              "-hmm_file $self->{hmm_file}",
              "-program $self->{continuous}",
              "-device $self->{device}",
              "-sample $self->{sample_rate}";
            &main::print_log("PocketSphinx_Listener:: $self->{device} $command")
              if $main::Debug{pocketsphinx};
            $self->{p_sphinx}->set($command);
            $self->{p_sphinx}->start();

            if ( $self->{speak} ) {
                &main::speak(
                    "voice recognition system is now available and ready");
            }
        }
    }
}

1;

=back

=head2 INI PARAMETERS

NONE

=head2 AUTHOR

01/21/2007 Created by Jim Duda (jim@duda.tzo.com)

=head2 SEE ALSO

NONE

=head2 LICENSE

This program is free software; you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation; either version 2 of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more details.

You should have received a copy of the GNU General Public License along with this program; if not, write to the Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.

=cut

