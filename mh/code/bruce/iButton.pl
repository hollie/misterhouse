# Category = iButtons

# Fixes in modules
#  - use     $self->{s}->read_interval(20);          # Time to wait after last byte received

# Enable iButton support by changing the mh.ini ibutton_port parm.
# You can buy iButton stuff here:
#    http://www.iButton.com/index.html
#    http://www.pointsix.com
# 
# More info on coding iButton_Item is in mh/docs/mh.html
#



$v_iButton_connect   = new Voice_Cmd "[Connect,Disconnect] to the iButton bus";
$v_iButton_connect  -> set_info('Use this to free up the serial port or test the iButton start/stop calls');
$v_iButton_readtemps = new Voice_Cmd "Read the iButton temperature buttons";
$v_iButton_readtemps-> set_info('This reads all all iButton temperature devices.  Takes a while (.6 s per device)');
$v_iButton_readtemp  = new Voice_Cmd "Read the iButton temperature [1,2,3,4]";
$v_iButton_readtemp -> set_info('Read only the temperature from a specific button');
$v_iButton_list      = new Voice_Cmd "List all the iButton buttons";
$v_iButton_list     -> set_info('Lists the family and ID codes of all the buttons on the bus');
$v_iButton_relay1    = new Voice_Cmd "Turn on relay1 [on,off]";
$v_iButton_relay1   -> set_info('Controls a test relay');


if ($state = said $v_iButton_connect) {
    print "$state the iButton bus";
    if ($state eq 'Connect') {
        print_log &iButton::connect($config_parms{ibutton_port});
    }
    else {
        print_log &iButton::disconnect;
    }
}

                                # This is how to code the 16 character iButton id:
                                #  - Allow either any of the following formats (crc is optional):
                                #     type|serial|crc
                                #     type|serial
                                #  - type is:
                                #     01: For 1990 read only iButton
                                #     10: For 1820 temperature sensor
                                #     12: For 2406 input/output module (used in www.pointsix.com TR1 and D2 modules)
                                #  - The serial is sometimes printed on the iButton can, or can be copied from an 
                                #     mh log.  Serial is 12 hex digits, type and crc are both 2 hex digits
                                #  - If the 1990s were used for security, we would probably want to hide their IDs :)

$ib_bruce  = new iButton '0100000546e3fc7a';
$ib_laurie = new iButton '01000005498963';
$ib_zach   = new iButton '0100000546e566';
$ib_nick   = new iButton '0100000549919d';

$ib_temp1  = new iButton '1000000029a14f';
$ib_temp2  = new iButton '1000000029f5d6';
$ib_temp3  = new iButton '100000002995aa';
$ib_temp4  = new iButton '1000000029a364';
my @ib_temps = ($ib_temp1, $ib_temp2, $ib_temp3, $ib_temp4);

$ib_relay1 = new iButton '120000001187d206';

$remark_nick = new File_Item("$config_parms{data_dir}/remarks/nick.txt");
$remark_zach = new File_Item("$config_parms{data_dir}/remarks/zack.txt");

$remark_bad   = new File_Item("$config_parms{data_dir}/remarks/personal_bad.txt", 'Ok');
$remark_good  = new File_Item("$config_parms{data_dir}/remarks/personal_good.txt", 'Ok');

speak read_next $remark_nick if ON  eq state_now $ib_nick;
speak read_next $remark_zach if ON  eq state_now $ib_zach;
speak read_next $remark_bad  if ON  eq state_now $ib_bruce;
#peak 'bye'                  if OFF eq state_now $ib_bruce;
#peak read_next $remark_good if ON  eq state_now $ib_laurie;
play "fun/*.wav"             if ON  eq state_now $ib_laurie;

if ($state = said $v_iButton_relay1) {
    print_log "Setting iButton relay1 to $state";
    set $ib_relay1 $state;
}

if ($state = said $v_iButton_readtemp) {
    my $ib = $ib_temps[$state - 1];
    my $temp = read_temp $ib;
    print_log "Temp for sensor $state: $temp F";
}

if ($New_Second and !($Minute % 5)) {
    my $device;
#   run_voice_cmd 'Read the iButton temperature 1' if $Second == 11;
    $device = 1 if $Second == 11;
    $device = 2 if $Second == 22;
    $device = 3 if $Second == 33;
    $device = 4 if $Second == 44;
    if ($device) {
        my $ib = $ib_temps[$device - 1];
        my $temp = read_temp $ib;
        logit("$config_parms{data_dir}/iButton_temps.log",  "$state: $temp");
    }
}

                                # Pick how often to check the bus ... it takes about 6 ms per device.
#&iButton::monitor;
&iButton::monitor if $New_Second;


                                # List all iButton temperatures.  This can take a while
if (said $v_iButton_readtemps) {
    print_log "Reading iButton temperatures";
    my @ib_list = &iButton::scan('10'); # gets DS1920/DS1820 devices
    for my $ib (@ib_list) {
        my $temp = $ib->read_temperature_hires();
        print_log "ID:" . $ib->serial() . "  Temp: $temp C, " . ($temp*9/5 +32) . " F";
    }
    @ib_list = &iButton::scan('22'); # gets DS1822 devices
    for my $ib (@ib_list) {
        my $temp = $ib->read_temperature();
        print_log "ID:" . $ib->serial() . "  Temp: $temp C, " . ($temp*9/5 +32) . " F";
    }
}

                                # List all iButton devices
print_log "List of ibuttons:\n" . &iButton::scan_report if said $v_iButton_list;

