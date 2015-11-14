# Category = iButtons

# Sample code for communicating with the DS2450 Quad A/D converter.
# Brian Rudy (brudyNO@SPAMpraecogito.com)

use iButton;

# Test iButton
$ib_test = new iButton '2000000001c9df';    # Change this to your DS2450's ID

$v_iButton_DS2450_list = new Voice_Cmd "List DS2450";
$v_iButton_DS2450_list->set_info('List all the DS2450 connected to the bus');

$v_iButton_DS2450_setup = new Voice_Cmd "Setup DS2450";
$v_iButton_DS2450_setup->set_info('Setup a specific DS2450');

$v_iButton_DS2450_convert = new Voice_Cmd "Convert [A,B,C,D,all,BDA]";
$v_iButton_DS2450_convert->set_info(
    'Start conversion on the selected AD channel of a specific DS2450');

$v_iButton_DS2450_read = new Voice_Cmd "Read [A,B,C,D,all]";
$v_iButton_DS2450_read->set_info('Read the conversion results from memory');

$v_iButton_DS2450_setswitch = new Voice_Cmd "Set switch A [on,off]";
$v_iButton_DS2450_setswitch->set_info('Set channel A switch on or off');

if ( $state = said $v_iButton_DS2450_list) {
    print_log "Searching for DS2450s";
    my @ib_2450_family_list = &iButton::scan('20');
    speak $#ib_2450_family_list + 1 . " DS2450 found";
    for my $ib (@ib_2450_family_list) {
        print_log "ID:" . $ib->serial . "  CRC:" . $ib->crc,
          ": " . $ib->model();
    }
}

if ( $state = said $v_iButton_DS2450_setup) {
    my $VCC = 0;    # Our device is paracitically powered
    my %A;
    my %B;
    my %C;
    my %D;

    #$A{type} = "AD";
    $A{type}       = "switch";    # These are all that's needed for switch mode
    $A{state}      = 1;           #
                                  #$A{resolution} = 12;
                                  #$A{range} = 2.56;
    $B{type}       = "AD";        # A/D mode
    $B{resolution} = 12;          # 12 bits of A/D resolution
    $B{range}      = 5.12;        # 5.12V maximum range
    $C{type}       = "AD";
    $C{resolution} = 12;
    $C{range}      = 2.56;        # 2.56V maximum range
    $D{type}       = "AD";
    $D{resolution} = 12;
    $D{range}      = 5.12;

    if (
        $ib_test->Hardware::iButton::Device::DS2450::setup(
            $VCC, \%A, \%B, \%C, \%D
        )
      )
    {
        print_log "Success!";
    }
    else {
        print_log "Failure!";
    }
}

if ( $state = said $v_iButton_DS2450_convert) {
    if ( $ib_test->Hardware::iButton::Device::DS2450::convert($state) ) {
        print_log "Success!";
    }
    else {
        print_log "Failure!";
    }
}

if ( $state = said $v_iButton_DS2450_read) {
    if ( $state =~ m/all/i ) {
        my ( $A, $B, $C, $D ) =
          $ib_test->Hardware::iButton::Device::DS2450::readAD($state);
        if ( defined $A ) {
            print_log "---Results---";
            print_log "A=$A V.";
            print_log "B=$B V.";
            print_log "C=$C V.";
            print_log "D=$D V.";
        }
        else {
            print_log "Read error!";
        }
    }
    else {
        my $result =
          $ib_test->Hardware::iButton::Device::DS2450::readAD($state);
        if ( defined $result ) {
            print_log "---Results---";
            print_log $state . "=" . $result . " V";
        }
        else {
            print_log "Read error!";
        }
    }
}

if ( $state = said $v_iButton_DS2450_setswitch) {
    my $channel = "A";
    if (
        $ib_test->Hardware::iButton::Device::DS2450::set_switch(
            $channel, $state
        )
      )
    {
        print_log "Success!";
    }
    else {
        print_log "Failure!";
    }
}
