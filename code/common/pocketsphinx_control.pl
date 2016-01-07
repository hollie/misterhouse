# Category=Voice

#@ Provides Voice Recognition using the Carnegie Mellon University PocketSphinx VR System.
#@ You must first download and install SphinxBase and PocketSphinx from:
#@   http://cmusphinx.sourceforge.net

=begin comment

pocketsphinx_control.pl 

03/11/2012 Created by Jim Duda (jim@duda.tzo.com)

Use this module to control the PocketSphinx VR engine (currently Linux only)

RRequirements:

 Download and install Sphinxbase, PocketSphinx, and CMU Language Toolkit
 http://cmusphinx.sourceforge.net/wiki/download/

 Current Version Supported:
 PocketSphinx: 0.7
 SphinxBase:   0.7
 Cmuclmtk:     0.7

 When building SphinxBase, it will default to OSS, if you want ALSA (recommended) then you 
 need to add --with-alsa to the configure command.

Setup:

Install and configure all the above software.  Set these values in your mh.private.ini file
Note that all those marked as default are in mh.ini and need not be loaded unless truly different.
Enable the pocket_sphinx_control module in misterhouse setup (code/common).

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
@    - pocketsphinx_hmm               Pocketsphinx Human Markov Model directory location.
@    - pocketsphinx_rate              Audio Sample rate
@    - pocketsphinx_continuous        Program location for pocketsphinx_continuous
@    - pocketsphinx_dev               Audio device (multiple devices can be separated by "|")

=cut

use strict;

use PocketSphinx;

# Initialize the PocketSphinx library module

# noloop=start
&PocketSphinx_Control::startup();

# noloop=stop

# define some classes we need
$v_pocketsphinx_reset = new Voice_Cmd("reset pocket sphinx language files");
$v_pocketsphinx_awake = new Voice_Cmd(
    $config_parms{pocketsphinx_awake_phrase},
    $config_parms{pocketsphinx_awake_response}
);
$v_pocketsphinx_asleep = new Voice_Cmd(
    $config_parms{pocketsphinx_asleep_phrase},
    $config_parms{pocketsphinx_timeout_response}
);
$pocketsphinx_listener =
  new PocketSphinx_Listener( "$config_parms{pocketsphinx_dev}",
    $config_parms{pocketsphinx_rate} );
$t_awake_timer = new Timer;

# Set mode on startup and reload
if ( $Startup or $Reload ) {
    if ( $Save{vr_mode} eq 'awake' ) {
        if ( defined $v_pocketsphinx_awake ) {
            set $v_pocketsphinx_awake 1;
        }
    }
    elsif ( $Save{vr_mode} eq 'asleep' ) {
        if ( defined $v_pocketsphinx_asleep ) {
            set $v_pocketsphinx_asleep 1;
        }
    }
    print_log("PocketSphinx:: set to $Save{vr_mode}") if $Debug{pocketsphinx};
}

# process the VR awake phrase
if ( said $v_pocketsphinx_awake) {
    print_log("PocketSphinx:: VR mode set to awake") if $Debug{pocketsphinx};
    $Save{vr_mode} = 'awake';
    set $t_awake_timer $config_parms{pocketsphinx_awake_time}
      if ( exists $config_parms{pocketsphinx_awake_time} );
}

# Reset the timer so we stay in awake mode if VR is active
if (    $Save{vr_mode} eq 'awake'
    and &Voice_Cmd::said_this_pass
    and exists $config_parms{pocketsphinx_awake_time} )
{
    set $t_awake_timer $config_parms{pocketsphinx_awake_time}
      if ( exists $config_parms{pocketsphinx_awake_time} );
}

# process the VR asleep phrase
if ( said $v_pocketsphinx_asleep) {
    print_log("PocketSphinx:: VR mode set to asleep") if $Debug{pocketsphinx};
    $Save{vr_mode} = 'asleep';
}

# Go to asleep mode if no command have ben heard recently
if ( expired $t_awake_timer and $Save{vr_mode} eq 'awake' ) {
    print_log("PocketSphinx:: active mode timed out") if $Debug{pocketsphinx};
    set $v_pocketsphinx_asleep 1;
}

# reset the pocketsphinx language files to force a rebuild on next startup
if ( said $v_pocketsphinx_reset) {
    &PocketSphinx_Control::reset_language_files();
}
