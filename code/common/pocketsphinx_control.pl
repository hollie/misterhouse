# Category=Voice

#@ Provides Voice Recognition using the Carnegie Mellon University PocketSphinx VR System.
#@ You must first download and install SphinxBase and PocketSphinx from:
#@   http://cmusphinx.sourceforge.net

=begin comment

pocketsphinx_control.pl 

01/21/2007 Created by Jim Duda (jim@duda.tzo.com)

Use this module to control the PocketSphinx VR engine (currently Linux only)

Requirements:

 Download and install PocketSphinx 
 http://cmusphinx.sourceforge.net

 You need to install both SphinxBase and PocketSphinx.  When building SphinxBase, it will
 default to OSS, if you want ALSA (recommended) then you need to add --with-alsa to the 
 configure command.

 Download the CMU Sphinx dictionary file from here: 
 https://cmusphinx.svn.sourceforge.net/svnroot/cmusphinx/trunk/SphinxTrain/test/res/cmudict.0.6d

 Install the dictionary file in some useful place 
 example: /usr/local/share/pocketsphinx/model/lm/cmudict/cmudict.0.6d
 pocketsphinx_cmudict must match the location where the file is installed.

Setup:

Install and configure all the above software.  Set these values in your mh.private.ini file
Note that all those marked as default are in mh.ini and need not be loaded unless truly different.

 voice_cmd                    = pocketsphinx
 server_pocketsphinx_port     = 3235
 pocketsphinx_awake_phrase    = "mister house,computer"
 pocketsphinx_awake_response  = "yes master?"
 pocketsphinx_awake_time=300
 pocketsphinx_asleep_phrase={go to sleep,change to sleep mode}
 pocketsphinx_asleep_response=Ok, later.
 pocketsphinx_timeout_response=Later.

 pocketsphinx_cmudict     = "/usr/local/share/pocketsphinx/model/lm/cmudict/cmudict.0.6d"   # default
 pocketsphinx_hmm         = "/usr/local/share/pocketsphinx/model/hmm/wsj1"                  # default
 pocketsphinx_rate        = 16000                                                           # default
 pocketsphinx_continuous  = "/usr/local/bin/pocketsphinx_continuous"                        # default
 pocketsphinx_dev         = "default"                                                       # default

 Note: If using OSS instead of ALSA, pocketsphinx_device needs to be "/dev/dsp" or similiar.

@    - pocketsphinx_awake_phrase:     Command(s) that will switch mh into active 
@                                     mode (all commands recognized) from asleep mode.
@    - pocketsphinx_awake_response:   This is what is said (or played) when entering
@                                     awake mode
@    - pocketsphinx_awake_time:       Stay in awake mode for this many seconds after
@                                     the last command was heard.  Then it switches
@                                     to asleep mode. Set to 0 or blank to disable
@                                     (always stay in awake mode).
@    - pocketsphinx_asleep_phrase:    Command{s} to put mh into asleep mode.
@    - pocketsphinx_asleep_response:  This is what it said (or played) when entering
@                                     sleep mode
@    - pocketsphinx_timeout_response: This is what is said (or played) when the awake
@                                     timer expires.
@    - pocketsphinx_cmudict           Pocketsphinx full english dictionary file location.
@    - pocketsphinx_hmm               Pocketsphinx Human Markov Model directory location.
@    - pocketsphinx_rate              Audio Sample rate
@    - pocketsphinx_continues         Program location for pocketsphinx_continuous
@    - pocketsphinx_dev               Audio device (multiple devices can be separated by "|")

=cut

$p_sphinx = new Process_Item;

$v_pocketsphinx_awake  = new Voice_Cmd($config_parms{pocketsphinx_awake_phrase},$config_parms{pocketsphinx_awake_response});
$v_pocketsphinx_asleep = new Voice_Cmd($config_parms{pocketsphinx_asleep_phrase},$config_parms{pocketsphinx_timeout_response});

$pocketsphinx_server = new Socket_Item(undef, undef, 'server_pocketsphinx');

$pocketsphinx_awake_timer = new Timer;
$pocketsphinx_crash_timer = new Timer;

# Don't do anything if we are using non-sphinx vr engine
return unless $config_parms{voice_cmd} eq 'pocketsphinx';

#$Debug{pocketsphinx} = 1;
#$Debug{process} = 1;
#$Debug{voice} = 1;

my $sentence_file   = "$config_parms{data_dir}/pocketsphinx/current.sent";
my $lm_file         = "$config_parms{data_dir}/pocketsphinx/current.lm";
my $dictionary_file = "$config_parms{data_dir}/pocketsphinx/current.dic";
my $lm_log_file     = "$config_parms{data_dir}/pocketsphinx/build_lm.log";
my $sphinx_log_file = "$config_parms{data_dir}/pocketsphinx/pocketsphinx";

my $cmu_dict        = "/usr/local/share/pocketsphinx/model/lm/cmudict/cmudict.0.6d";
my $hmm_file        = "/usr/local/share/pocketsphinx/model/hmm/wsj1";
my $localhost       = "localhost";
my $localport       = 3235;
my $sample_rate     = 16000;
my $continuous      = "/usr/local/bin/pocketsphinx_continuous";
my $device          = "default";

$cmu_dict    = "$config_parms{pocketsphinx_cmudict}" if defined $config_parms{pocketsphinx_cmudict};
$hmm_file    = "$config_parms{pocketsphinx_hmm}"     if defined $config_parms{pocketsphinx_hmm};
$localport   = "$config_parms{server_pocketsphinx_port}"  if defined $config_parms{server_pocketsphinx_port};
$sample_rate = "$config_parms{pocketsphinx_sample_rate}" if defined $config_parms{pocketsphinx_sample_rate};
$continuous  = "$config_parms{pocketsphinx_continuous}"  if defined $config_parms{pocketsphinx_continuous};
$device      = "$config_parms{pocketsphinx_dev}"         if defined $config_parms{pocketsphinx_dev};

my $pocketsphinx_state;
my $pocketsphinx_disabled;
my $pocketsphinx_crash_cnt;

# initialize code module on startup or reload
if ($Startup or $Reload) {
  print_log "pocketsphinx:: initializing" if $Debug{pocketsphinx};
  stop $p_sphinx;
  mkdir ("$config_parms{data_dir}/pocketsphinx", 0777) unless -d "$config_parms{data_dir}/pocketsphinx";
  &build_sentence_file($sentence_file);
  $pocketsphinx_state = "build_lm";
  $pocketsphinx_disabled = 0;
  $pocketsphinx_crash_cnt = 0;
  if (!-e $cmu_dict) {
    print_log "pocketsphinx:: ERROR: file: $cmu_dict MISSING!!";
    $pocketsphinx_disabled = 1;
  }
  if (!-e $hmm_file) {
    print_log "pocketsphinx:: ERROR: file: $hmm_file MISSING!!";
    $pocketsphinx_disabled = 1;
  }
  Voice_Cmd::init_pocketsphinx (\&pocketsphinx_check_for_voice_command);
  print_log "pocketsphinx:: build_lm" if $Debug{pocketsphinx};
  set_errlog $p_sphinx "";
  set_output $p_sphinx "";
  set $p_sphinx "&build_lm ('$sentence_file','$lm_file','$lm_log_file')";
  start $p_sphinx;
}

# Set mode on startup and reload
if ($Reload) {
  if ($Save{vr_mode} eq 'awake') {
    set $v_pocketsphinx_awake 1;
  }
  elsif ($Save{vr_mode} eq 'asleep') {
    set $v_pocketsphinx_asleep 1;
  }
  print_log "Pocketsphinx:: set to $Save{vr_mode}" if $Debug{pocketsphinx};
}

# check to see of the pocketsphinx VR program has completed, check for short crashes (something is wrong)
if (done_now $p_sphinx) {
  print_log "pocketsphinx:: process_done: $pocketsphinx_state" if $Debug{pocketsphinx};
  if ($pocketsphinx_state eq 'run_sphinx') {
    my $runtime = $p_sphinx->runtime( );
    if ($runtime < 60) {
      $pocketsphinx_crash_cnt++;
      set $pocketsphinx_crash_timer 60;
      if ($pocketsphinx_crash_cnt > 10) {
        print_log "pocketsphinx:: ERROR: disabled because the pocketsphinx_continuous program exited too quickly ($runtime) ... check $sphinx_log_file.stderr";
        $pocketsphinx_disabled = 1;
      }
    } else {
      $pocketsphinx_crash_cnt = 0;
    }
  }
}

# exit if the code module is disabled
return if ($pocketsphinx_disabled);

if ($pocketsphinx_state eq "build_lm") {
  if (done $p_sphinx) {
    print_log "pocketsphinx:: build_dictionary" if $Debug{pocketsphinx};
    $pocketsphinx_state = "build_dictionary";
    set_errlog $p_sphinx "";
    set_output $p_sphinx "";
    set $p_sphinx "&build_dictionary('$sentence_file','$cmu_dict','$dictionary_file')";
    start $p_sphinx;
  }
}

# wait for build dictionary to be complete
if ($pocketsphinx_state eq "build_dictionary") {
  if (done $p_sphinx) {
    $pocketsphinx_state = "run_sphinx";
  }
}

# keep the pocketsphinx voice recognition program running externally
if ($pocketsphinx_state eq "run_sphinx") {
  if (done $p_sphinx && !$pocketsphinx_disabled && !active $pocketsphinx_crash_timer) {
    print_log "pocketsphinx:: run_sphinx" if $Debug{pocketsphinx};
    set_errlog $p_sphinx "$sphinx_log_file.stderr";
    set_output $p_sphinx "$sphinx_log_file.stdout";
    set_killsig $p_sphinx "TERM";
    my $command = join " ",
                  "pocketsphinx ",
                  "-host localhost",
                  "-port $localport",
                  "-log_file $sphinx_log_file",
                  "-sent_file $sentence_file",
                  "-lm_file $lm_file",
                  "-dict_file $dictionary_file",
                  "-hmm_file $hmm_file",
                  "-program $continuous",
                  "-device $device",
                  "-sample $sample_rate";
    print_log "pocketsphinx:: $command" if $Debug{pocketsphinx};
    set $p_sphinx $command;
    start $p_sphinx;
    speak "voice recognition system is now available and ready";
  }
}

# process the VR awake phrase
if (said $v_pocketsphinx_awake) {
  print_log "pocketsphinx:: VR mode set to awake" if $Debug{pocketsphinx};
  $Save{vr_mode} = 'awake';
  set $pocketsphinx_awake_timer $config_parms{pocketsphinx_awake_time} if $config_parms{pocketsphinx_awake_time};
}

# Reset the timer so we stay in awake mode if VR is active
if ($Save{vr_mode} eq 'awake' and &Voice_Cmd::said_this_pass and $config_parms{pocketsphinx_awake_time}) {
  set $pocketsphinx_awake_timer $config_parms{pocketsphinx_awake_time};
}

# process the VR asleep phrase
if (said $v_pocketsphinx_asleep) {
  print_log "pocketsphinx:: VR mode set to asleep" if $Debug{pocketsphinx};
  $Save{vr_mode} = 'asleep';
}

# Go to asleep mode if no command have ben heard recently
if (expired $pocketsphinx_awake_timer and $Save{vr_mode} eq 'awake') {
  print_log "pocketsphinx:: active mode timed out" if $Debug{pocketsphinx};
  set $v_pocketsphinx_asleep 1;
}

# check for any new voice command from external pocketsphinx client(s)
sub pocketsphinx_check_for_voice_command {
  my $text;
  if (my $tmp = said $pocketsphinx_server) {
    print_log "pocketsphinx:: said: $tmp" if $Debug{pocketsphinx};
    # search for awake phrase
    if ($Save{vr_mode} eq "asleep") {
      foreach ( split(/,/,$config_parms{pocketsphinx_awake_phrase}) ) {
        my $token = $_;
        #strip leading/trailing white space
        $token =~ s/^\s+//;
        $token =~ s/\s+$//;
        $token =~ s/[\{\}]//;
        $token = uc($token);
        if ($tmp eq $token) {
          $text = $tmp;
        }
        print_log "pocketsphinx:: tmp: $tmp text: $text token: $token" if $Debug{pocketsphinx};
     }
    } else {
      $text = $tmp;
    }
  }
  return $text;
}

#============================================================================================ 
# BUILD SENTENCE FILE
#============================================================================================ 
sub build_sentence_file {
  my ($sentence_file) = @_;
  #first write the sentence file
  open(OUTPUT,">$sentence_file");
  my @phrase_array =   &Voice_Cmd::voice_items('mh','no_category');
  foreach my $cmd (@phrase_array) {
    chomp $cmd;
    $cmd = uc($cmd);
    print OUTPUT "<s> $cmd </s>\n";
  }
  close OUTPUT;
}

#============================================================================================ 
# BUILD DICTIONARY FILE
#============================================================================================ 
sub build_dictionary {
  my ($sentence_file,$cmu_dict,$dictionary_file) = @_;

  #read the big dictionary into memory
  open (DICT,"$cmu_dict");
  my @dict;
  while(<DICT>){
    push(@dict,$_);
  }
  close (DICT);

  my @already_added;
  #now look for prounciations in the big dictionary
  open (DOUT,">$dictionary_file");
  open (DIN,"$sentence_file");
  while (<DIN>) {
    chomp $_;
    next unless $_ =~ /^<s> (.*) </s>$/;
    my $text=uc($1);
    #added Nov 15 2003: Shane C. Masony 
    #if there are multiple words in the text(like a phrase), we need to add them
    #so first, split by space, then make sure that these words have not been added
    #because identicle entries cause a hash error when sphinx loads them
    my @elements=split(" ",$text);
    foreach my $thisword (@elements){
       my $exists_flag=0;
       foreach my $existing_word (@already_added){
         if($thisword eq $existing_word){
           $exists_flag=1;
         }
       }
       if(!$exists_flag){
	 push(@already_added,$thisword);
         foreach my $input (@dict){
           if($input =~ /^$thisword[\s|\(]/){  #match $text\s and $text(
	     $input =~ /^(\S*)\s*(.*)$/;
             my $a = $1;
             my $b = $2;
             print DOUT "$a\t$b\n";
           }
         }
       }
    }
  }
  close (DIN);
  close (DOUT);
}

#============================================================================================ 
# BUILD LANGUAGE MODEL FILE
#============================================================================================ 


#/* ====================================================================
# * Copyright (c) 1996-2002 Alexander I. Rudnicky and Carnegie Mellon University.
# * All rights reserved.
# *
# * Redistribution and use in source and binary forms, with or without
# * modification, are permitted provided that the following conditions
# * are met:
# *
# * 1. Redistributions of source code must retain the above copyright
# *    notice, this list of conditions and the following disclaimer.
# *
# * 2. Redistributions in binary form must reproduce the above copyright
# *    notice, this list of conditions and the following disclaimer in
# *    the documentation and/or other materials provided with the
# *    distribution.
# *
# * 3. All copies, used or distributed, must preserve the original wording of
# *    the copyright notice included in the output file.
# *
# * This work was supported in part by funding from the Defense Advanced
# * Research Projects Agency and the CMU Sphinx Speech Consortium.
# *
# * THIS SOFTWARE IS PROVIDED BY CARNEGIE MELLON UNIVERSITY ``AS IS'' AND
# * ANY EXPRESSED OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO,
# * THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR
# * PURPOSE ARE DISCLAIMED.  IN NO EVENT SHALL CARNEGIE MELLON UNIVERSITY
# * NOR ITS EMPLOYEES BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
# * SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT
# * LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
# * DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
# * THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
# * (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
# * OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
# *
# * ====================================================================
# *
# */


#Pretty Good Language Modeler, now with unigram vector augmentation!

#The Pretty Good Language Modeler is intended for quick construction of small
#language models, typically as might be needed in application development. Depending
#on the version of Perl that you are running, a practical limitation is a
#maximum vocabulary size on the order of 1000-2000 words. The limiting factor
#is the number of n-grams observed, since each n-gram is stored as a hash key.
#(So smaller vocabularies may turn out to be a problem as well.)

#This package computes a stadard back-off language model. It differs in one significant
#respect, which is the computation of the discount. We adopt a "proportional" (or ratio)
#discount in which a certain percentage of probability mass is removed (typically 50%)
#from observed n-grams and redistributed over unobserved n-grams.

#Conventionally, an absolute discount would be used, however we have found that the
#proportional discount appears to be robust for extremely small languages, as might be
#prototyped by a developer, as opposed to based on a collected corpus. We have found that
#absolute and proportional discounts produce comparable recognition results with perhaps
#a slight advantage for proportional discounting. A more systematic investigation of
#this technique would be desirable. In any case it also has the virtue of using a very
#simple computation.



# NOTE: this is by no means an efficient implementation and performance will
# deteriorate rapidly as a function of the corpus size. Larger corpora should be
# processed using the toolkit available at http://www.speech.cs.cmu.edu/SLM_info.html

# [2feb96] (air)
# cobbles together a language model from a set of exemplar sentences.
# features: 1) uniform discounting, 2) no cutoffs
# the "+" version allows insertion of extra words into the 1gram vector

# [27nov97] (air)
# bulletproof a bit for use in conjunction with a cgi script

# [20000711] (air)
# made visible the discount parmeter

# [20011123] (air)
# cleaned-up version for distribution


#[20021130] Shane C. Mason (me@perlbox.org) 
#added structure for -o output filename switch

sub build_lm {

  # input parameters
  # quick_lm -s <sentence_file> [-w <word_file>] [-d discount]\n"); }
  my ($sentfile,$lm_file,$logfile,$wordfile,$discount) = @_;

  my $wflag;
  my $discount_mass;
  my $deflator;
  my $sent_cnt;
  my @word;
  my %unigram;
  my %alpha;
  my %bialpha;
  my %trigram;
  my %bigram;
  my $new;
  my %uniprob;
  my %biprob;

  $| = 1;  # always flush buffers

  open(LOG,">$logfile");
  open(IN,"$sentfile") or die("can't open $sentfile!\n");
  if (defined $wordfile) {
    open(WORDS,"$wordfile");
    $wflag = 1;
  } else {
    $wflag = 0; 
  }

  my $log10 = log(10.0);

  if (defined $discount) {
    if (($discount<=0.0) or ($discount>=1.0)) {
      print LOG "\discount value out of range: must be 0.0 < x < 1.0! ...using 0.5\n";
      $discount_mass = 0.5;  # just use default
    } else {
      $discount_mass = $discount;
    }
  } else {
    # Ben and Greg's experiments show that 0.5 is a way better default choice.
    $discount_mass = 0.5;  # Set a nominal discount...
  }
  $deflator = 1.0 - $discount_mass;

  # create count tables
  $sent_cnt = 0;
  while (<IN>) {
    s/^\s*//; s/\s*$//;
    if ( $_ eq "" ) { next; } else { $sent_cnt++; } # skip empty lines
    @word = split(/\s/);
    my $j;
    for ($j=0;$j<($#word-1);$j++) {
      $trigram{join(" ",$word[$j],$word[$j+1],$word[$j+2])}++;
      $bigram{ join(" ",$word[$j],$word[$j+1])}++;
      $unigram{$word[$j]}++;
    }
    # finish up the bi and uni's at the end of the sentence...
    $bigram{join(" ",$word[$j],$word[$j+1])}++;
    $unigram{$word[$j]}++;

    $unigram{$word[$j+1]}++;
  }
  close(IN);
  print LOG "$sent_cnt sentences found.\n";

  # add in any words
  if ($wflag) {
    $new = 0; 
    my $read_in = 0;
    while (<WORDS>) {
      s/^\s*//; s/\s*$//;
      if ( $_ eq "" ) { next; }  else { $read_in++; }  # skip empty lines
      if (! $unigram{$_}) { $unigram{$_} = 1; $new++; }
    }
    print LOG "tried to add $read_in word; $new were new words\n";
    close (WORDS);
  }
  if ( ($sent_cnt==0) && ($new==0) ) {
    print LOG "no input?\n";
    exit;
  }

  open(LM,">$lm_file") or die("can't open $lm_file for output!\n");   #scm -changed to lm_file

  my $preface = "";
  $preface .= "Language model created by QuickLM for perlbox-voice on ".`date`;
  $preface .= "Copyright (c) 1996-2002\nCarnegie Mellon University and Alexander I. Rudnicky\n\n";
  $preface .= "This model based on a corpus of $sent_cnt sentences and ".scalar (keys %unigram). " words\n";
  $preface .= "The (fixed) discount mass is $discount_mass\n\n";

  # compute counts
  my $unisum = 0; 
  my $uni_count = 0; 
  my $bi_count = 0; 
  my $tri_count = 0;
  foreach my $x (keys(%unigram)) { $uni_count++; $unisum += $unigram{$x}; }
  foreach my $x (keys(%bigram))  { $bi_count++; }
  foreach my $x (keys(%trigram)) { $tri_count++; }

  print LM $preface;
  print LM "\\data\\\n";
  print LM "ngram 1=$uni_count\n";
  if ( $bi_count > 0 ) { print LM "ngram 2=$bi_count\n"; }
  if ( $tri_count > 0 ) { print LM "ngram 3=$tri_count\n"; }
  print LM "\n";

  # compute uni probs
  foreach my $x (keys(%unigram)) {
    $uniprob{$x} = ($unigram{$x}/$unisum) * $deflator;
  }

  # compute alphas
  foreach my $y (keys(%unigram)) {
    my $w1 = $y;
    my $sum_denom = 0.0;
    foreach my $x (keys(%bigram)) {
      if ( substr($x,0,rindex($x," ")) eq $w1 ) {
        my $w2 = substr($x,index($x," ")+1);
        $sum_denom += $uniprob{$w2};
      }
    }
    $alpha{$w1} = $discount_mass / (1.0 - $sum_denom);
  }

  print LM "\\1-grams:\n";
  foreach my $x (sort keys(%unigram)) {
    printf LM "%6.4f %s %6.4f\n", log($uniprob{$x})/$log10, $x, log($alpha{$x})/$log10;
  }
  print LM "\n";

  #compute bi probs
  foreach my $x (keys(%bigram)) {
    my $w1 = substr($x,0,rindex($x," "));
    $biprob{$x} = ($bigram{$x}*$deflator)/$unigram{$w1};
  }

  #compute bialphas
  foreach my $x (keys(%bigram)) {
    my $w1w2 = $x;
    my $sum_denom = 0.0;
    foreach my $y (keys(%trigram)) {
      if (substr($y,0,rindex($y," ")) eq $w1w2 ) {
        my $w2w3 = substr($y,index($y," ")+1);
        $sum_denom += $biprob{$w2w3};
      }
    }
    $bialpha{$w1w2} = $discount_mass / (1.0 - $sum_denom);
  }

  # output the bigrams and trigrams (now that we have the alphas computed).
  if ( $bi_count > 0 ) {
    print LM "\\2-grams:\n";
    foreach my $x (sort keys(%bigram)) {
      printf LM "%6.4f %s %6.4f\n",
        log($biprob{$x})/$log10, $x, log($bialpha{$x})/$log10;
    }
    print LM "\n";
  }

  if ($tri_count > 0 ) {
    print LM "\\3-grams:\n";
    foreach my $x (sort keys(%trigram)) {
      my $w1w2 = substr($x,0,rindex($x," "));
      printf LM "%6.4f %s\n",
        log(($trigram{$x}*$deflator)/$bigram{$w1w2})/$log10, $x;
    }
    print LM "\n";
  }

  print LM "\\end\\\n";
  close(LM);

  print LOG "Language model completed at ",scalar localtime(),"\n";

  return "build_lm:: complete";
}



