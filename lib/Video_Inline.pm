
=begin comment

Controls the Inline video scan doubler:
 http://www.inlineinc.com/tech/manuals/pdf/1424man.pdf

Use these mh.ini parameters to enable this code:

 Video_InLine_serial_port   = COM9
 Video_InLine_baudrate  = 19200

 in code use:

###################################
  #Category=Other
  $inline = new Video_InLine;

  $v_inline_ch = new Voice_Cmd('Set Inline to channel [1,2,3,4]');
  if ($state = said $v_inline_ch) {
	$inline->channel($state);
  }
  $v_inline_input = new Voice_Cmd('Set Inline input type to [SVideo,Composite]');
  if ($state = said $v_inline_input) {
	$inline->input($state);
  }
  $v_inline_screen = new Voice_Cmd('[Blank,Unblank] Inline screen');
  if ($state = said $v_inline_screen) {
	$inline->screen($state);
  }
  $v_inline_panel = new Voice_Cmd('[Enable,Disable] Inline Buttons');
  if ($state = said $v_inline_panel) {
	$inline->panel($state);
  }
  $v_inline_save = new Voice_Cmd('Save Inline Settings');
  if ($state = said $v_inline_save) {
	$inline->save;
  }
  $v_inline_sharp = new Voice_Cmd('[Increase,Decrease, Default] Inline Sharpness');
  if ($state = said $v_inline_sharp) {
	$inline->sharp($state);
  }
  $v_inline_brightp=new Voice_Cmd('[Increase,Decrease, Default] Inline Brightness');
  if ($state = said $v_inline_sharp) {
	$inline->bright($state);
  }
  $v_inline_hue=new Voice_Cmd('[Increase,Decrease, Default] Inline Hue');
  if ($state = said $v_inline_hue) {
	$inline->hue($state);
  }
  $v_inline_contrast=new Voice_Cmd('[Increase,Decrease, Default] Inline Contrast');
  if ($state = said $v_inline_contrast) {
	$inline->contrast($state);
  }
  $v_inline_saturation=new Voice_Cmd('[Increase,Decrease, Default] Inline Saturation');
  if ($state = said $v_inline_saturation) {
	$inline->saturation($state);
  }
  $v_inline_scan=new Voice_Cmd('Set Inline to [Single,Double] Scan');
  if ($state = said $v_inline_scan) {
	$inline->scan($state);
  }
  $v_inline_message=new Voice_Cmd('Send InLine Message');
  if ($state = said $v_inline_message) {
	$inline->message("This is a test");
  }
####################################################3

=cut

use strict;

package InLine;

@InLine::ISA = ('Serial_Item');

sub serial_startup {
    &main::serial_port_create(
        'InLine',
        $main::config_parms{InLine_serial_port},
        $main::config_parms{InLine_baudrate}, 'none'
    );
    &::MainLoop_pre_add_hook( \&InLine::check_for_data, 1 );
    &::print_log("InLine Serial Port Initialized");
}

sub check_for_data {
    &main::check_for_generic_serial_data('InLine');
}

sub channel {
    my ( $self, $state ) = @_;
    &Generic_Item::set_states_for_next_pass( $self, $state );
    my $serial_data;

    $serial_data = "[CH" . $state . "]";

    print "Setting InLine to channel $state\n";
    $main::Serial_Ports{InLine}{object}->write($serial_data);

}

sub input {
    my ( $self, $state ) = @_;
    &Generic_Item::set_states_for_next_pass( $self, $state );
    my $serial_data;

    if ( lc($state) eq "svideo" ) {
        $serial_data = "[SVIDEO1]";
    }
    elsif ( lc($state) eq "composite" ) {
        $serial_data = "[SVIDEO0]";
    }
    print "Setting InLine to input type $state\n";
    $main::Serial_Ports{InLine}{object}->write($serial_data);

}

sub screen {
    my ( $self, $state ) = @_;
    &Generic_Item::set_states_for_next_pass( $self, $state );
    my $serial_data;
    if ( lc($state) eq "blank" ) {
        $serial_data = "[BLANK1]";
    }
    elsif ( lc($state) eq "unblank" ) {
        $serial_data = "[BLANK0]";
    }
    print "Setting InLine screen $state\n";
    $main::Serial_Ports{InLine}{object}->write($serial_data);
}

sub panel {
    my ( $self, $state ) = @_;
    &Generic_Item::set_states_for_next_pass( $self, $state );
    my $serial_data;
    if ( lc($state) eq "enable" ) {
        $serial_data = "[FP1]";
    }
    elsif ( lc($state) eq "disable" ) {
        $serial_data = "[FP0]";
    }
    print "Setting InLine front panel to $state\n";
    $main::Serial_Ports{InLine}{object}->write($serial_data);
}

sub save {
    my ( $self, $state ) = @_;
    &Generic_Item::set_states_for_next_pass( $self, $state );
    my $serial_data;
    $serial_data = "[SAVE]";
    print "Saving InLine Settings\n";
    $main::Serial_Ports{InLine}{object}->write($serial_data);
}

sub sharp {
    my ( $self, $state ) = @_;
    &Generic_Item::set_states_for_next_pass( $self, $state );
    my $serial_data;
    if ( lc($state) eq "increase" ) {
        $serial_data = "[SHP+]";
    }
    elsif ( lc($state) eq "decrease" ) {
        $serial_data = "[SHP-]";
    }
    elsif ( lc($state) eq "default" ) {
        $serial_data = "[SHP@]";
    }
    print "Setting InLine sharp $state\n";
    $main::Serial_Ports{InLine}{object}->write($serial_data);
}

sub bright {
    my ( $self, $state ) = @_;
    &Generic_Item::set_states_for_next_pass( $self, $state );
    my $serial_data;
    if ( lc($state) eq "increase" ) {
        $serial_data = "[BRG+]";
    }
    elsif ( lc($state) eq "decrease" ) {
        $serial_data = "[BRG-]";
    }
    elsif ( lc($state) eq "default" ) {
        $serial_data = "[BRG@]";
    }
    print "Setting InLine brightness $state\n";
    $main::Serial_Ports{InLine}{object}->write($serial_data);
}

sub hue {
    my ( $self, $state ) = @_;
    &Generic_Item::set_states_for_next_pass( $self, $state );
    my $serial_data;
    if ( lc($state) eq "increase" ) {
        $serial_data = "[HUE+]";
    }
    elsif ( lc($state) eq "decrease" ) {
        $serial_data = "[HUE-]";
    }
    elsif ( lc($state) eq "default" ) {
        $serial_data = "[HUE@]";
    }
    print "Setting InLine hue $state\n";
    $main::Serial_Ports{InLine}{object}->write($serial_data);
}

sub contrast {
    my ( $self, $state ) = @_;
    &Generic_Item::set_states_for_next_pass( $self, $state );
    my $serial_data;
    if ( lc($state) eq "increase" ) {
        $serial_data = "[CON+]";
    }
    elsif ( lc($state) eq "decrease" ) {
        $serial_data = "[CON-]";
    }
    elsif ( lc($state) eq "default" ) {
        $serial_data = "[CON@]";
    }
    print "Setting InLine contrast $state\n";
    $main::Serial_Ports{InLine}{object}->write($serial_data);
}

sub saturation {
    my ( $self, $state ) = @_;
    &Generic_Item::set_states_for_next_pass( $self, $state );
    my $serial_data;
    if ( lc($state) eq "increase" ) {
        $serial_data = "[SAT+]";
    }
    elsif ( lc($state) eq "decrease" ) {
        $serial_data = "[SAT-]";
    }
    elsif ( lc($state) eq "default" ) {
        $serial_data = "[SAT@]";
    }
    print "Setting InLine contrast $state\n";
    $main::Serial_Ports{InLine}{object}->write($serial_data);
}

sub scan {
    my ( $self, $state ) = @_;
    &Generic_Item::set_states_for_next_pass( $self, $state );
    my $serial_data;
    if ( lc($state) eq "single" ) {
        $serial_data = "[HSCAN0]";
    }
    elsif ( lc($state) eq "double" ) {
        $serial_data = "[HSCAN1]";
    }
    print "Setting InLine scan mode to $state\n";
    $main::Serial_Ports{InLine}{object}->write($serial_data);
}

sub message {
    my ( $self, $state ) = @_;
    &Generic_Item::set_states_for_next_pass( $self, $state );
    my $serial_data = "[MSGL0101$state]";

    print "Sending Message to inline\n";
    $main::Serial_Ports{InLine}{object}->write($serial_data);
}
1;
