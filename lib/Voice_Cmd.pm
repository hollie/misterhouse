package Voice_Cmd;

=head1 NAME

B<Voice_Cmd>

=head1 SYNOPSIS

  $v_backyard_light = new  Voice_Cmd 'Backyard Light [on,off]';
  set $backyard_light $state if $state = said $v_backyard_light;

  $v_test1 = new Voice_Cmd '{turn,set} the {living,famliy} room {light,lights} [on,off]';
  $v_test2 = new Voice_Cmd '{Please, } tell me the time';
  $v_test3 = new Voice_Cmd '{What time is it,Tell me the time}';
  $v_fan   = new Voice_Cmd 'Fan [on,off]', 'Ok, I turned the fan $v_indoor_fountain->{said}';
  $v_fan   = new Voice_Cmd 'Fan [on,off]', 'Ok, I turned the fan %STATE%';

In addition to the said command on a specific object, you can use &Voice_Cmd::said_this_pass to detect which command was spoken this pass and &Voice_Cmd::noise_this_pass to detect if noise was detected this pass (this function currently only works with viavoice).

  if (my $speak_num = &Voice_Cmd::said_this_pass) {
    my $text = &Voice_Cmd::text_by_num($speak_num);
    print_log "spoken text: $speak_num, $text";
  }

  if (my $text = &Voice_Cmd::noise_this_pass) {
    print_log "Noise detected" if $text eq 'Noise';
  }

=head1 DESCRIPTION

Use the Voice_Cmd object to create voice commands. Even without a Voice Recognition engine installed, this is useful as these commands can also be run from the Tk, web, telnet, and file interfaces.

=head1 INHERITS

B<Generic_Item>

=head1 METHODS

=over

=cut

@Voice_Cmd::ISA = ('Generic_Item');

use strict;

use HTML::Entities;    # So we can encode characters like <>& etc

my ($cmd_num);
my (
    %cmd_by_num,      %cmd_state_by_num, %cmd_num_by_text,
    %cmd_text_by_num, %cmd_text_by_vocab
);
my ( %cmd_word_list, %cmd_vocabs );
my ( $Vcmd_ms, $Vmenu_ms, $Vcmd_viavoice, $Vcmd_sphinx2, $Vcmd_pocketsphinx );
my (
    $last_cmd_time, $last_cmd_num, $last_cmd_num_confirm,
    $last_cmd_flag, $noise_this_pass
);

my $confirm_timer = &Timer::new();

my $waiting_for_command_num;

sub wait_for_command {
    $_ = shift;
    $waiting_for_command_num = ( ($_) ? $cmd_num_by_text{ lc($_) } : undef );
}

sub init {

    if ( $main::config_parms{voice_cmd} =~ /ms/i and $main::OS_win ) {
        print "Creating MS VR object\n";
        $Win32::OLE::Warn = 1;    # Warn if ole fails

        #       $Win32::OLE::Warn = 3;   # Die  if ole fails
        $Vcmd_ms  = &create_voice_command_object;
        $Vmenu_ms = &create_voice_command_menu_object(
            'application' => 'Misterhouse',
            'state'       => 'Main State'
        ) if $Vcmd_ms;
    }
    if ( $main::config_parms{voice_cmd} =~ /viavoice/i ) {
        my $port =
          "$main::config_parms{viavoice_host}:$main::config_parms{viavoice_port}";
        print "Creating Viavoice command object on $port\n";
        $Vcmd_viavoice =
          new main::Socket_Item( undef, undef, $port, 'viavoice' );

        #       buffer $Vcmd_viavoice 1;
        start $Vcmd_viavoice;

        # Defined an empty vocab ... will use addtovocab for all phrases
        &definevocab('mh');

        # Defined the confirmation vocab
        &definevocab( 'mh_confirm', 'yes', 'no' );
        &disablevocab('mh_confirm');
        &mic('on');
    }
    if ( $main::config_parms{voice_cmd} =~ /sphinx2/i ) {
        my $port = $main::config_parms{sphinx2_host} . ':'
          . $main::config_parms{sphinx2_port};
        print "Creating Sphinx2 command object on $port\n";

        #$Vcmd_sphinx2 = new  Socket_Item(undef, undef, 'server_sphinx2');
        $Vcmd_sphinx2 = new main::Socket_Item( undef, undef, $port, 'sphinx2' );
        start $Vcmd_sphinx2;
    }

}

# The pocketsphinx code file provides a callback reference to fetch the next voice command
sub init_pocketsphinx {
    ($Vcmd_pocketsphinx) = @_;
}

sub reset {
    if ($Vcmd_viavoice) {

        # Allow for new phrases to be added
        $Vcmd_viavoice->set("addtovocab");
        select undef, undef, undef,
          .1;    # Need this for now to avoid viavoice_server 'no data' error
        $Vcmd_viavoice->set("mh");
        undef %cmd_text_by_vocab;    # Only add new commands on reload
    }
    else {
        undef %cmd_num_by_text;
        undef %cmd_by_num;
        &remove_voice_cmds
          unless $main::Startup
          ; # Must reload here, or cmd_by_num gets messed up (unless it is startup in which case it is empty)
    }
}

sub is_active {
    return $Vmenu_ms->{Active};
}

sub activate {
    if ($Vcmd_ms) {
        $Vmenu_ms->{Active} = 1;    # Called after all voice commands are added

        #       print "\n\nError in Speech VR object.  ", Win32::OLE->LastError(), "\n\n";
        $Vcmd_ms->{CommandSpoken} = 0; # In case any lingering command was there
    }
    if ($Vcmd_viavoice) {

        # Close the addtovocab session
        #  - vocabularies are enabled by default, so no need to enable
        $Vcmd_viavoice->set("");

        # Add words from other, non-default vocabularies
        for my $vocab ( sort keys %cmd_text_by_vocab ) {

            # Only need to define a new vocab once per session
            unless ( $cmd_vocabs{$vocab} ) {
                &definevocab($vocab);
                $cmd_vocabs{$vocab}++;
            }

            my $count = @{ $cmd_text_by_vocab{$vocab} };
            print "Adding $count words for vocab=$vocab\n";
            &addtovocab( $vocab, @{ $cmd_text_by_vocab{$vocab} } );

            &disablevocab($vocab);    # Disabled by default
        }
    }
    if ( $Vcmd_sphinx2 and $Vcmd_sphinx2->active ) {
        $Vcmd_sphinx2->set('NEWVOCAB');
        for my $phrase ( &voice_items( 'mh', 'no_category' ) ) {
            select undef, undef, undef, .001;    #Don't know if necessary
            $Vcmd_sphinx2->set($phrase);
        }
        $Vcmd_sphinx2->set('ENDNEWVOCAB');
    }
}

sub deactivate {
    return unless $Vcmd_ms;
    $Vmenu_ms->{Active} = 0;    # Called after all voice commands are added
}

sub create_voice_command_object {

    return unless $main::OS_win;

    #   print "Creating MS voice VR object\n";

    $Vcmd_ms = Win32::OLE->new('Speech.VoiceCommand');

    unless ($Vcmd_ms) {
        print "\n\nError, could not create Speech VR object.  ",
          Win32::OLE->LastError(), "\n\n";
        return;
    }

    $Vcmd_ms->Register("Local PC");
    if ( Win32::OLE->LastError() ) {
        print "\n\nError, could not Register MS Speech VR object\n";
        delete $main::config_parms{voice_cmd};    # Disable for future reloads
        return;
    }

    print "Awakening speech command.  Currently it is at ", $Vcmd_ms->{Awake},
      "\n"
      if $main::Debug{voice};
    $Vcmd_ms->{Awake} = 1;
    return $Vcmd_ms;
}

sub create_voice_command_menu_object {
    my (%parms) = @_;

    # From speech.h file:
    #/ dwFlags parameter of IVoiceCmd::MenuCreate
    #define  VCMDMC_CREATE_TEMP     0x00000001
    #define  VCMDMC_CREATE_NEW      0x00000002
    #define  VCMDMC_CREATE_ALWAYS   0x00000004
    #define  VCMDMC_OPEN_ALWAYS     0x00000008
    #define  VCMDMC_OPEN_EXISTING   0x00000010
    #   $Vmenu_ms = $Vcmd_ms->MenuCreate($parms{'application'}, $parms{'state'}, 1033, "US English", hex(1)) or
    unless (
        $Vmenu_ms = $Vcmd_ms->MenuCreate(
            $parms{'application'}, $parms{'state'}, 1033, "US English", 4
        )
      )
    {
        print "\nError, could not create Vmenu:", Win32::OLE->LastError(), "\n";
        return;
    }

    $Vmenu_ms->{Active} = 0;    # Needs to be off when we first add commands

    return $Vmenu_ms;
}

sub check_for_voice_cmd {

    # Turn on VR, if text is done speaking
    #    if ($Vcmd_ms) {
    #        print ($Vmenu_ms->{Active}) ? '.' : '-';
    #        if ($Vmenu_ms->{Active} and &Voice_Text::is_speaking) {
    #            print "db vr off\n";
    #            $Vmenu_ms->{Active} = 0;
    #        }
    #        if (!$Vmenu_ms->{Active} and !&Voice_Text::is_speaking) {
    #            print "db vr on\n";
    #            $Vmenu_ms->{Active} = 1;
    #        }
    #       $Vmenu_ms->{Active} = 1 unless $Vmenu_ms->{Active};
    #    }

    my ( $ref, $number, $said, $cmd_heard, $cmd, $action );
    $noise_this_pass = 0;

    if ($Vcmd_ms) {
        $number = $Vcmd_ms->CommandSpoken;

        #$self->{text_by_state}{$state} = $cmd;

        #	$cmd_heard = undef;

    }

    #   if ($Vcmd_viavoice and my $text = said $Vcmd_viavoice) {
    if ( $Vcmd_viavoice and my $text = said $Vcmd_viavoice) {

        # If we get a lot of stuff, throw it away
        # ... probably just stored up junk
        #       return if length($text) > 100;

        $text = substr( $text, 1 )
          ;    # Drop the leading 00 byte (not sure why we get that)

        # Drop the prefix, if present
        my $prefix = $main::config_parms{voice_cmd_prefix};
        $text =~ s/Said: $prefix /Said: / if $prefix;

        $noise_this_pass = $text;

        #       ($cmd_heard) = $text =~ /^Said: (.+)/;
        ($cmd_heard) = $text =~
          /Said: (.+)/;    # Patch from the list ... not sure why this is needed

        if ( defined $cmd_heard ) {
            $noise_this_pass = 0;
            $number          = $cmd_num_by_text{$cmd_heard};

            # Check to see if we are confirming a previous command
            if ( &Timer::active($confirm_timer) and $last_cmd_num_confirm ) {
                undef $number;
                if ( $cmd_heard eq 'yes' ) {
                    &main::speak("Command confirmed");
                    $number = $last_cmd_num_confirm;
                }
                elsif ( $cmd_heard eq 'no' ) {
                    &main::speak("Command aborted");
                }
                else {
                    &main::speak(
                        "Error in the confirm vocabulary. Contact support.");
                }
                $last_cmd_num_confirm = 0;
                &Timer::unset($confirm_timer);
                &disablevocab('mh_confirm');
                &enablevocab('mh');
            }

            # Check for confirm yes/no request
            elsif ( $cmd_by_num{$number}->{confirm} ) {
                &main::speak("Confirm with a yes or a no");
                &disablevocab('mh');    # Should change this to @current_vocab
                &enablevocab('mh_confirm');
                $action = "&Voice_Cmd::disablevocab('mh_confirm'); ";
                $action .= "&Voice_Cmd::enablevocab('mh'); ";
                $action .= "&main::speak('Confirmation timed out'); ";
                &Timer::set( $confirm_timer, 10, $action );
                $last_cmd_num_confirm = $number;
                $number               = 0;
            }

        }
        print "db vv: n=$number cmd=$cmd_heard text=$text.\n"
          if $main::Debug{voice};
    }
    if ( $Vcmd_sphinx2 and my $text = said $Vcmd_sphinx2) {
        $text =~ s/\n//g;    #For some odd reason we get the odd \n stuck here.
        $cmd_heard = lc $text;
        $number    = $cmd_num_by_text{$cmd_heard};
        print "db sphinx2: n=$number cmd=$cmd_heard text=$text.\n"
          if $main::config_parms{debug} eq 'voice';
    }

    if ($Vcmd_pocketsphinx) {
        my $text = &$Vcmd_pocketsphinx();
        $text =~ s/\n//g;    #For some odd reason we get the odd \n stuck here.
        $cmd_heard = lc $text;
        $number    = $cmd_num_by_text{$cmd_heard};
        print "db pocketsphinx: n=$number cmd=$cmd_heard text=$text.\n"
          if $main::config_parms{debug} eq 'voice';
    }

    # Set states, if a command was triggered
    $last_cmd_flag = 0;

    if ( $number
        and
        ( !$waiting_for_command_num or $waiting_for_command_num eq $number ) )
    {
        $waiting_for_command_num = undef;
        $ref                     = $cmd_by_num{$number};
        $said                    = $cmd_state_by_num{$number};
        $cmd                     = $ref->{text};

        if ( $said eq 'reserved' ) {
            $cmd =~ s/\[.*\]//;
            $said = '1';
        }
        else {
            $cmd =~ s/\[.*\]/$said/;
        }
        $cmd = lc($cmd);    # get ready to pack into recognition response

        $said = '1'
          if !
          defined
          $said;    # Some Voice_Cmds have blank saids.  But allow for 0 state

        # This could be set for either the current or next pass ... next pass is easier

        if ( $main::Disabled_Commands{ lc($cmd) } ) {
            &main::respond('Command is disabled.');
        }
        else {
            &Generic_Item::set_states_for_next_pass( $ref, $said, 'vr' )
              if $cmd;
        }

        if ($cmd) {
            print "Voice cmd num=$number ref=$ref said=$said cmd=$cmd\n"
              if $main::Debug{voice};

            #       $ref->{said}  = $said;
            #       $ref->{state} = $said;

            $Vcmd_ms->{CommandSpoken} = 0 if $Vcmd_ms;
            $last_cmd_time            = &main::get_tickcount;
            $last_cmd_num             = $number;
            $last_cmd_flag            = $number;

            # Echo command response
            my $response = $cmd_by_num{$number}->{response};
            $response = $main::config_parms{voice_cmd_response}
              unless defined $response;
            if ( defined $response ) {

                # Allow for something like: 'Ok, I turned it %STATE%'

                $cmd_heard = $cmd
                  unless $cmd_heard;    # did nothing before except "Ok, "

                $response =~ s/%STATE%/$said/g if $said ne '1';
                $response =~ s/%HEARD%/$cmd_heard/g;

                # Allow for something like: 'Ok, I turned it $v_indoor_fountain->{said}'
                #            package main;       # Avoid having to prefix vars with main::
                #            eval "\$response  = qq[$response]";
                #            package Voice_Cmd;
                &main::speak( no_chime => 1, text => $response ) if $response;
            }
        }
        else {
            &main::speak(
                'no_chime=1 Voice command not found. Please restart Misterhouse and try again.'
            );
        }

    }
}

# This will set voice items for the NEXT pass ... do not want it active
# for the current pass, because we do not know where we are in the user code loop
sub set {
    my ( $self, $state, $set_by, $no_log, $respond ) = @_;
    $set_by = 'unknown' unless $set_by;

    my $cmd = $self->{text_by_state}{$state};

    #   if ($$self{disabled}) { *** Does not work properly (disables all states)
    if ( $main::Disabled_Commands{ lc($cmd) } ) {    # ***
        &main::print_log(
            "Disabled command not run: $self->{text_by_state}{$state}");
        return;
    }
    return if &main::check_for_tied_filters( $self, $state );

    # Cannot do this!  Respond_Target is shared by everything and its brother!
    # if app passes explicit targets, then they are passed along and eventually responded to
    # otherwise set_by is used

    #    $respond = $main::Respond_Target unless $respond; # Pass default target along
    if ( $$self{xap_target} ) {
        my $xap_target = $$self{xap_target};
        my $xap_mh_prefix =
          &xAP::get_mh_vendor_info() . '.' . &xAP::get_mh_device_info();

        # prepend the xAP prefix if it doesn't have it
        if ( $xap_target !~ /^$xap_mh_prefix/i ) {
            $xap_target =
              $xap_mh_prefix . "." . $xap_target . &xAP::XAP_REAL_DEVICE_NAME;
        }
        &xAP::sendXap(
            $$self{xap_target},
            'command.external',
            'command.external' => {
                'command' => $self->{text_by_state}{$state},
                'targets' => $respond
            }
        );
        &main::print_log("Sending: $self->{text_by_state}{$state}")
          unless $no_log;
    }
    else {
        &Generic_Item::set_states_for_next_pass( $self, $state, $set_by,
            $respond );
        &main::print_log("Running: $self->{text_by_state}{$state}")
          unless $no_log;
        print "db1 set voice cmd $self to $state set_by=$set_by r=$respond\n"
          if $main::Debug{voice};
    }
}

sub remove_voice_cmds {
    if ($Vmenu_ms) {
        $Vmenu_ms->{Active} = 0;
        my ( $vitems_removed, $number );
        $vitems_removed = 0;
        print "Removing MS voice items... ";
        foreach $number ( keys %cmd_by_num ) {
            $Vmenu_ms->Remove($number);
            $vitems_removed++;
            delete $cmd_by_num{$number};
        }
        $cmd_num = 0;    # Reset cmd num counter
        print "$vitems_removed voice commands were removed\n"
          if $vitems_removed;
    }
    if ($Vcmd_viavoice) {
        print "Undefining the Misterhouse ViaVoice vocabulary ... ";
        &mic('off');
        $Vcmd_viavoice->set("undefinevocab");
        select undef, undef, undef,
          .1;    # Need this for now to avoid viavoice_server 'no data' error
        $Vcmd_viavoice->set("mh");
        select undef, undef, undef,
          .1;    # Need this for now to avoid viavoice_server 'no data' error
        undef %cmd_by_num;
        undef %cmd_num_by_text;
        print "done\n";
    }
}

#    $Vmenu_ms->{Active} = 0;
#    $Vmenu_ms->{Active} = 1;
#    $Vcmd_ms->{CommandSpoken} = 0;

sub voice_item_by_text {
    my ($text) = @_;
    $text = &_clean_text_string($text);
    my $cmd_num = $cmd_num_by_text{$text};

    #   print "dbvc text=$text cn=$cmd_num ref=$cmd_by_num{$cmd_num} cs=$cmd_state_by_num{$cmd_num}\n";
    if ($cmd_num) {
        my $ref = $cmd_by_num{$cmd_num};
        return ( $ref, $cmd_state_by_num{$cmd_num}, $ref->{vocab} );
    }
    else {
        return undef;
    }
}

sub voice_items {
    my ( $vocab, $list ) = @_;

    $vocab = 'mh' unless $vocab;    # Default

    #   my @cmd_list = sort {$cmd_num_by_text{$a} <=> $cmd_num_by_text{$b}} keys %cmd_num_by_text;
    my @cmd_list = keys %cmd_num_by_text;

    if ( $list and $list eq 'no_category' ) {
        return @cmd_list;
    }

    # Add the filename to the list, so we can do better grep searches
    my @cmd_list2;
    for my $cmd (@cmd_list) {
        my ( $ref, $said, $vocab_cmd ) = &voice_item_by_text($cmd);
        next unless $vocab eq $vocab_cmd;

        #       my $filename  = $ref->{filename};
        my $category = $ref->{category};
        $category = '' unless $category;    # Avoid uninitialized warning
        push( @cmd_list2, "$category: $cmd" );
    }
    return sort { uc $a cmp uc $b } @cmd_list2;
}

=item C<new($command, $response, $confirm, $vocabulary)>

$command - can be a simple string (e.g. 'What time is it') or it can include a list of 'states' (e.g. 'Turn the light [on,off]').  The state enumeration group is a comma delimited string surrounded with [].  In addition to one state enumeration group, you can specify any number of phrase enumeration groups.  These are comma delimited strings surrounded by {} (e.g. 'Turn the {family room,downstairs} TV [on,off]').  Use this when you have several different ways to describe the same thing.

$response - is the text or wave file that will be played back when the VR engine detects this command.  If not defined, the mh.ini parm voice_cmd_response parm is used (default is "Ok, %HEARD%").  You can put %STATE%, %HEARD%, or any variable in the response string and have it substituted/evaluated when the response is spoken.

$confirm - is either 0 or 1 (default is 0).  If set to 1, then mh will ask 'Confirm with a yes or a no'.  If yes or no is not heard within 10 seconds, the command is aborted.

$vocabulary - allows you to define multiple vocabularies.  You can then use these functions to enable and disable the vocabularies:

  &Voice_Cmd::enablevocab($vocabulary)
  &Voice_Cmd::disablevocab($vocabulary)

Vocabularies are enabled by default.  The default vocabulary is 'misterhouse'.  See mh/code/bruce/viavoice_control.pl for examples.  This code allows you to switch between 'awake', 'asleep', and 'off' VR modes.

NOTE: Currently only the viavoice VR engine (mh.ini parm voice_cmd=viavoice)  will use the $response, $confirm, and $vocabulary_name options.  We may be able to create a viavoice_server for windows, but that would probably not be free like it is on linux.  If you have a linux box on your network, you can have your windows mh use the linux viavoice_server process.

=cut

sub new {
    my ( $class, $text, $response, $confirm, $vocab ) = @_;
    $vocab = 'mh' unless $vocab;    # default

    # Avoid ? ... they are a pain in html and vxml
    # *** This needs to go--?'s can be encoded by http_server!
    $text =~ s/\?//g;

    my $self = {
        text     => $text,
        response => $response,
        confirm  => $confirm,
        vocab    => $vocab,
        state    => ''
    };
    &_register($self);
    bless $self, $class;
    return $self;
}

my ( @data, $index1, $index2, $index_last );

sub _register {
    my ($self) = @_;
    my $text   = $self->{text};
    my $vocab  = $self->{vocab};
    my $info =
      $self->{info};    # Dang, info gets set AFTER we define the object :(
    $info  = ''   unless $info;
    $vocab = "mh" unless $vocab;
    my $description = "$text: $info\n";

    #   print "Voice_Cmd text: $text\n";

    # Break phrase into [] {} chunks
    my ( $index_state, $i );
    undef @data;
    $i = 0;
    while ( $text =~ /([\[\{]?)([^\[\{\]\}]+)([\]\}]?)/g ) {
        my ( $l, $m, $r ) = ( $1, $2, $3 );
        print
          "Warning, unmatched brackets in Voice_Cmd text: text=$text l=$l m=$m r=$r\n"
          if $l  and !$r
          or !$l and $r;
        @{ $data[$i]{text} } = ($l) ? split( / *, */, $m, 999 ) : ($m);
        $data[$i]{last} = scalar @{ $data[$i]{text} } - 1;
        if ( $l eq '[' ) {
            print
              "Warning, more than one [] state bracket in Voice_Cmd text: i=$i l=$l r=$r text=$text\n"
              if $index_state;
            $index_state = $i;
        }
        $i++;
    }

    # Iterate over all [] () groups
    $index_last = $i - 1;
    $index1     = $index2 = 0;
    $i          = 0;
    while (1) {
        my $cmd = '';
        for my $j ( 0 .. $index_last ) {
            $data[$j]{index} = 0 unless $data[$j]{index};
            $cmd .= $data[$j]{text}[ $data[$j]{index} ];
        }
        $cmd =~ s/ +/ /g;  # Delete double blanks so 'set {the,} light on' works

        my $state = $data[$index_state]{text}[ $data[$index_state]{index} ]
          if defined $index_state;

        # These commands have no real states ... there is no enumeration
        #  - avoid saving the whole name as state.  Too much for state_log displays
        # Leave state=0 alone!
        $state = 'reserved'
          if !defined $state
          or $state eq ''
          or $state eq $text;

        my $cmd_num = &_register2( $self, $cmd, $vocab, $description );
        $self->{text_by_state}{$state} = $cmd;
        $cmd_state_by_num{$cmd_num} = $state;

        $self->{disabled} = 1 if $main::Disabled_Commands{ lc $cmd };

        print "cmd_num=$cmd_num cmd=$cmd state=$state\n" if $main::Debug{voice};
        last if &_increment_indexes > $index_last;
    }
}

sub _increment_indexes {

    # Check if we are done with this group
    if ( $data[$index1]{index} < $data[$index1]{last} ) {

        # Increment the next entry in this group
        $data[$index1]{index}++;
    }
    else {
        # Check if we need to increment index2
        if ( $index1 == $index2 ) {

            # Reset indexes and increment index2
            for my $k ( 0 .. $index1 ) {
                $data[$k]{index} = 0;
            }
            $index1 = 0;

            # Find the next unused index2 group entry
            while (1) {
                last if ++$index2 > $index_last;
                last if $data[$index2]{index} < $data[$index2]{last};
            }
            $data[$index2]{index}++;
        }
        else {
            # Find the next unused index1 group entry
            while (1) {
                last if ++$index1 > $index_last;
                last if $data[$index1]{index} < $data[$index1]{last};
            }
            $index2 = $index1 if $index1 > $index2;

            # Reset indexes and index1
            $data[$index1]{index}++;
            for my $k ( 0 .. $index1 - 1 ) {
                $data[$k]{index} = 0;
            }
            $index1 = 0;
        }
    }
    return $index2;
}

sub _register2 {
    my ( $self, $text, $vocab, $des ) = @_;
    $text = &_clean_text_string($text);
    push( @{ $self->{texts} }, $text );    # e.g. tellme_menu.pl

    # With viavoice, only add at startup or when adding a new command
    #  - point to new Voice_Cmd object pointer
    if ( $Vcmd_viavoice and $cmd_num_by_text{$text} ) {
        $cmd_by_num{ $cmd_num_by_text{$text} } = $self;
        return $cmd_num_by_text{$text};
    }

    #   return $cmd_num_by_text{$text} if $cmd_num_by_text{$text};
    $cmd_num++;
    if ( $cmd_num_by_text{$text} ) {
        my $cmd = $cmd_by_num{ $cmd_num_by_text{$text} };
        print
          "\n\nWarning, duplicate Voice_Cmd Text: $text   Cmd: $$cmd{text}\n\n";
    }
    print "db cmd=$cmd_num text=$text vocab=$vocab.\n" if $main::Debug{voice};

    #   $cmd_file_by_text{$main::item_file_name} = $cmd_num;	# Yuck!
    #   if ($Vmenu_ms and $Vmenu_ms->Add($cmd_num, $text, $vocab, $des)) {

    # Allow for a prefix word
    my $prefix = $main::config_parms{voice_cmd_prefix};
    my $text_vr = ($prefix) ? "$prefix $text" : $text;

    # Always re-add the ms voice cmd
    if ($Vmenu_ms) {

        #	    print "Voice cmd num=$cmd_num text=$text v=$vocab des=$des\n";
        $Vmenu_ms->Add( $cmd_num, $text_vr, $vocab, $des ) if $text;
        print Win32::OLE->LastError() if Win32::OLE->LastError(0);
    }

    # If it is not in the default vocabulary, save it and add it later
    if ( $Vcmd_viavoice and $Vcmd_viavoice->active ) {
        if ( $vocab eq '' or $vocab eq 'mh' ) {
            $Vcmd_viavoice->set($text_vr);

            # We need better handshaking here ... not a delay!
            select undef, undef, undef, .0002
              ;    # Need this for now to avoid viavoice_server 'no data' error

            #           select undef, undef, undef, .0001; # Need this for now to avoid viavoice_server 'no data' error
        }
        else {
            push( @{ $cmd_text_by_vocab{$vocab} }, $text_vr );
        }
    }

    $cmd_num_by_text{$text} = $cmd_num;

    $cmd_text_by_num{$cmd_num} = $text;
    $cmd_by_num{$cmd_num}      = $self;

    # Create a word list we can use for command list searches
    for my $word ( split( ' ', $text ) ) {
        $cmd_word_list{$word}++;
    }

    return $cmd_num;
}

sub _clean_text_string {
    my ($text) = @_;
    $text = lc($text);
    $text =~ s/[\'\"]//g;    # Deletes quotes
    $text =~ s/^ +//;        # Delete leading  blanks
    $text =~ s/ $//;         # Delete trailing blanks
    return $text;
}

=item C<set_order>

Contols the order that the commands are listed in web Category list.  The default is alphabetically by file, then by name.

=cut

sub set_order {
    return unless $main::Reload;
    my ( $self, $order ) = @_;
    $self->{order} = $order;
}

sub get_last_cmd_time {
    return $last_cmd_time;
}

sub get_last_cmd {
    return $last_cmd_num;
}

sub said_this_pass {
    return $last_cmd_flag;
}

sub noise_this_pass {
    return $noise_this_pass;
}

sub text_by_num {
    my ($num) = @_;
    return $cmd_text_by_num{$num};
}

sub word_list {
    return sort keys %cmd_word_list;
}

sub mic {
    return unless $Vcmd_viavoice;
    my ($state) = @_;

    #   return if $main::Save{vr_mic} eq $state;
    #   $main::Save{vr_mic} = $state;

    #   &main::print_log("Mike $state");
    unless ( $state eq 'on' or $state eq 'off' ) {
        warn "Error, Voice_Cmd::mic must be set to on or off: $state";
        return;
    }
    select undef, undef, undef,
      .1;    # Need this for now to avoid viavoice_server 'no data' error
    $Vcmd_viavoice->set( "mic" . $state );
}

sub definevocab {
    return unless $Vcmd_viavoice;
    my ( $vocab, @phrases ) = @_;
    select undef, undef, undef,
      .1;    # Need this for now to avoid viavoice_server 'no data' error
    $Vcmd_viavoice->set("definevocab");
    select undef, undef, undef,
      .1;    # Need this for now to avoid viavoice_server 'no data' error
    $Vcmd_viavoice->set($vocab);
    select undef, undef, undef,
      .1;    # Need this for now to avoid viavoice_server 'no data' error
    for my $phrase (@phrases) {
        $Vcmd_viavoice->set($phrase);
    }
    select undef, undef, undef,
      .1;    # Need this for now to avoid viavoice_server 'no data' error
    $Vcmd_viavoice->set('');
}

sub addtovocab {
    return unless $Vcmd_viavoice;
    my ( $vocab, @phrases ) = @_;
    $Vcmd_viavoice->set("addtovocab");
    select undef, undef, undef,
      .5;    # Need this for now to avoid viavoice_server 'no data' error
    $Vcmd_viavoice->set($vocab);
    for my $phrase (@phrases) {
        $Vcmd_viavoice->set($phrase);
        select undef, undef, undef,
          .001;    # Need this for now to avoid viavoice_server 'no data' error
    }
    $Vcmd_viavoice->set('');
}

sub enablevocab {
    return unless $Vcmd_viavoice;
    my ($vocab) = @_;
    $Vcmd_viavoice->set("enablevocab");
    select undef, undef, undef,
      .1;          # Need this for now to avoid viavoice_server 'no data' error
    $Vcmd_viavoice->set($vocab);
    select undef, undef, undef,
      .1;          # Need this for now to avoid viavoice_server 'no data' error
    $Vcmd_viavoice->set('');
}

sub disablevocab {
    return unless $Vcmd_viavoice;
    my ($vocab) = @_;
    $Vcmd_viavoice->set("disablevocab");
    select undef, undef, undef,
      .1;          # Need this for now to avoid viavoice_server 'no data' error
    $Vcmd_viavoice->set($vocab);
    select undef, undef, undef,
      .1;          # Need this for now to avoid viavoice_server 'no data' error
    $Vcmd_viavoice->set('');
}

sub android_xml {
    my ( $self, $depth, $fields, $num_tags, $attributes ) = @_;
    my @f = qw( text );
    my $xml_objects =
      $self->SUPER::android_xml( $depth, $fields, $num_tags + scalar(@f),
        $attributes );
    my $prefix = '  ' x $depth;

    foreach my $f (@f) {
        next unless $fields->{all} or $fields->{$f};

        my $method = $f;
        my $value;
        if (
            $self->can($method)
            or ( ( $method = 'get_' . $method )
                and $self->can($method) )
          )
        {
            $value = $self->$method;
            $value = encode_entities( $value, "\200-\377&<>" );
        }
        elsif ( exists $self->{$f} ) {
            $value = $self->{$f};
            $value = encode_entities( $value, "\200-\377&<>" );
        }

        $value = "" unless defined $value;
        $xml_objects .=
          $self->android_xml_tag( $prefix, $f, $attributes, $value );
    }
    return $xml_objects;
}

1;

=back

=head1 INHERITED METHODS

=over

=item C<said>

Is true for the one pass after the command was issued.  If the command was built from a list of possible states, then said returns the state that matches.

=item C<state>

Returns the same thing as said, except it is valid for all passes, not just the pass after the command was issued.

=item C<set_icon>

Point to the icon member you want the web interface to use.  See the 'Customizing the web interface' section of this document for details.

=back

=head1 INI PARAMETERS

NONE

=head1 AUTHOR

UNK

=head1 SEE ALSO

See mh/code/examples/Voice_Cmd_enumeration.pl for more Voice_Cmd examples
See mh/code/bruce/lcdproc.pl for more examples.

=head1 LICENSE

This program is free software; you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation; either version 2 of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more details.

You should have received a copy of the GNU General Public License along with this program; if not, write to the Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.

=cut

#
# $Log: Voice_Cmd.pm,v $
# Revision 1.47  2004/07/18 22:16:37  winter
# *** empty log message ***
#
# Revision 1.46  2003/11/23 20:26:01  winter
#  - 2.84 release
#
# Revision 1.45  2003/07/06 17:55:11  winter
#  - 2.82 release
#
# Revision 1.44  2003/04/20 21:44:08  winter
#  - 2.80 release
#
# Revision 1.43  2003/03/09 19:34:41  winter
#  - 2.79 release
#
# Revision 1.42  2003/02/08 05:29:24  winter
#  - 2.78 release
#
# Revision 1.41  2003/01/12 20:39:20  winter
#  - 2.76 release
#
# Revision 1.40  2002/12/24 03:05:08  winter
# - 2.75 release
#
# Revision 1.39  2002/03/31 18:50:39  winter
# - 2.66 release
#
# Revision 1.38  2002/03/02 02:36:51  winter
# - 2.65 release
#
# Revision 1.37  2002/01/23 01:50:33  winter
# - 2.64 release
#
# Revision 1.36  2002/01/19 21:11:12  winter
# - 2.63 release
#
# Revision 1.35  2001/12/16 21:48:41  winter
# - 2.62 release
#
# Revision 1.34  2001/11/18 22:51:43  winter
# - 2.61 release
#
# Revision 1.33  2001/10/21 01:22:32  winter
# - 2.60 release
#
# Revision 1.32  2001/05/28 21:14:38  winter
# - 2.52 release
#
# Revision 1.31  2001/04/15 16:17:21  winter
# - 2.49 release
#
# Revision 1.30  2001/03/24 18:08:38  winter
# - 2.47 release
#
# Revision 1.29  2001/02/04 20:31:31  winter
# - 2.43 release
#
# Revision 1.28  2001/01/20 17:47:50  winter
# - 2.41 release
#
# Revision 1.27  2000/12/21 18:54:15  winter
# - 2.38 release
#
# Revision 1.26  2000/12/03 19:38:55  winter
# - 2.36 release
#
# Revision 1.25  2000/10/22 16:48:29  winter
# - 2.32 release
#
# Revision 1.24  2000/09/09 21:19:11  winter
# - 2.28 release
#
# Revision 1.23  2000/08/19 01:22:36  winter
# - 2.27 release
#
# Revision 1.22  2000/06/24 22:10:54  winter
# - 2.22 release.  Changes to read_table, tk_*, tie_* functions, and hook_ code
#
# Revision 1.21  2000/04/09 18:03:19  winter
# - 2.13 release
#
# Revision 1.20  2000/03/10 04:09:01  winter
# - Add Ibutton support and more web changes
#
# Revision 1.19  2000/02/20 04:47:54  winter
# -2.01 release
#
# Revision 1.18  2000/02/12 06:11:37  winter
# - commit lots of changes, in preperation for mh release 2.0
#
# Revision 1.17  2000/01/27 13:43:46  winter
# - update version number
#
# Revision 1.17  2000/01/13 13:39:03  winter
# - add %STATE% option
#
# Revision 1.16  1999/12/13 00:02:05  winter
# - numerous changes for viavoice.  Add cmd_word_list.
#
# Revision 1.15  1999/11/08 02:21:06  winter
# - add viavoice option
#
# Revision 1.14  1999/07/21 21:14:50  winter
# - add state method
#
# Revision 1.13  1999/06/27 20:13:04  winter
# - make debug conditional on 'voice'
#
# Revision 1.12  1999/02/21 00:26:46  winter
# - add $OS_win
#
# Revision 1.11  1999/02/16 02:06:23  winter
# - add filename to cmd_list2
#
# Revision 1.10  1999/02/04 14:20:40  winter
# - switch to new OLE calls.  Start on  VR 'deactivae on speech' code
#
# Revision 1.9  1999/01/30 19:50:31  winter
# - fix bug with cmd_by_num
#
# Revision 1.8  1999/01/22 02:42:43  winter
# - allow for linux by loading Win32 conditionally.  Allow for blank states.
#
# Revision 1.7  1999/01/10 02:29:16  winter
# - allow for 'check for voice command' loop, even with no $Vcmd, so web works without VR.
#
# Revision 1.6  1999/01/09 21:42:24  winter
# - improve error messages when ole steps fail
#
# Revision 1.5  1999/01/08 14:23:56  winter
# - add _clean_text_string to allow for leading/trailing blanks
#
# Revision 1.4  1999/01/07 01:54:18  winter
# - add 'set' method
#
# Revision 1.3  1998/12/07 14:35:14  winter
# - change warn level so we do not die
#
# Revision 1.2  1998/09/12 22:14:19  winter
# - add voice_items and {texts}
#
#
