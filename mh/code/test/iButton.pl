# Category = iButtons

=begin comment

 Ray Dzek created a nice 'how to get started with iButton guide' at
    http://www.solarbugs.com/home/ibutton.htm

 Enable iButton support by using these mh.ini parms:
   iButton_tweak         = 0      # Set to 1 to tweak timings if it appears not to work
   iButton_serial_port   = COM1
   iButton_2_serial_port = COM2   # If you have more than one ibutton port
   iButton_3_serial_port = COM2   # If you have more than one ibutton port
   default_temp = Celsius         # If you want to change degress unit from F to C

 You can buy iButton stuff here:
    http://www.iButton.com/index.html
    http://www.pointsix.com
 
 More info on coding iButton_Item is in mh/docs/mh.html

=cut

$v_iButton_connect   = new Voice_Cmd "[Connect,Disconnect] to the iButton bus";
$v_iButton_connect  -> set_info('Use this to free up the serial port or test the iButton start/stop calls');
$v_iButton_readtemps = new Voice_Cmd "Read the iButton temperature buttons";
$v_iButton_readtemps-> set_info('This reads all all iButton temperature devices.  Takes a while (.6 s per device)');
$v_iButton_readtemp  = new Voice_Cmd "Read the iButton temperature [1,2,3,4]";
$v_iButton_readtemp -> set_info('Read only the temperature from a specific button');
$v_iButton_readtemp -> set_authority('anyone');
$v_iButton_list      = new Voice_Cmd "List all the iButton buttons";
$v_iButton_list     -> set_info('Lists the family and ID codes of all the buttons on the bus');
$v_iButton_list     -> set_authority('anyweb');
$v_iButton_relay1    = new Voice_Cmd "Turn on relay1 [on,off]";
$v_iButton_relay1   -> set_info('Controls a test relay');
$v_iButton_relay1   -> set_authority('anyone');


if ($state = said $v_iButton_connect) {
    print "$state the iButton bus";
    if ($state eq 'Connect') {
        print_log &iButton::connect($config_parms{iButton_serial_port});
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

$ib_relay1   = new iButton '120000001187d206';

$remark_nick = new File_Item "$config_parms{data_dir}/remarks/nick.txt";
$remark_zach = new File_Item "$config_parms{data_dir}/remarks/zack.txt";
$remark_bad  = new File_Item "$config_parms{data_dir}/remarks/personal_bad.txt", 'Ok';
$remark_good = new File_Item "$config_parms{data_dir}/remarks/personal_good.txt", 'Ok';

speak read_random $remark_nick if ON  eq state_now $ib_nick;
speak read_next   $remark_zach if ON  eq state_now $ib_zach;
speak voice => 'random', text => read_next $remark_bad  if ON  eq state_now $ib_bruce;
play "fun/*.wav"               if ON  eq state_now $ib_laurie;

if ($state = said $v_iButton_relay1) {
    print_log "Setting iButton relay1 to $state";
    set $ib_relay1 $state;
}

if ($state = said $v_iButton_readtemp) {
    my $ib = $ib_temps[$state - 1];
    my $temp = read_temp $ib;
    print_log "Temp for sensor $state: $temp degrees";
}

                                # List all iButton temperatures.  This can take a while
if (said $v_iButton_readtemps) {
    print_log "Reading iButton temperatures";
#   my @ib_list = &iButton::scan('10'); # gets DS1920/DS1820 devices  22 for DS1822 devices
#   for my $ib (@ib_list) {
    for my $ib (@ib_temps) {
#       my $temp = $ib->read_temperature_hires();
        my $temp = read_temp $ib;
        print_log "ID:" . $ib->serial() . "  Temp: $temp degrees" if defined $temp;
    }
}

                                # Log temp sensor periodically ... not too often as this is slow
my $ibutton_temp_device = 0;
if (new_minute 2) {
    $ibutton_temp_device = 1 if ++$ibutton_temp_device > 4;
    my $ib = $ib_temps[$ibutton_temp_device - 1];
    my $temp = read_temp $ib;
    my $ib_name = substr $$ib{object_name}, 1;
    update_rrd($ib_name, $temp);
    logit("$config_parms{data_dir}/iButton_temps.log",  "$state: $temp");
}

                                # List all iButton devices
if (said $v_iButton_list) {
    print_log "List of ibuttons:\n" . &iButton::scan_report;
    print_log "List of ibuttons on 2nd ibutton:\n" . &iButton::scan_report(undef, $config_parms{iButton_2_serial_port})
        if $config_parms{iButton_2_serial_port};
}

                                # Pick how often to check the bus ... it takes about 6 ms per device.
                                # You can use the 'start a by name speed benchmark' command
                                # to see how much time this is taking
&iButton::monitor('01') if $New_Second;
&iButton::monitor('01', $config_parms{iButton_2_serial_port} ) if $New_Second and $config_parms{iButton_2_serial_port};
#iButton::monitor if $New_Msecond_500;


sub update_rrd {
    return unless $config_parms{rrd_dir};

	my ($sensor, $temp) = @_;
    my ($rrd_file, $rrd_error);

	$rrd_file = "$config_parms{rrd_dir}/$sensor.rrd";
	print "Storing $sensor data=$temp in $rrd_file\n";
	RRDs::update $rrd_file, "$Time:$temp";
	print_log "RRD ERROR: $rrd_error\n" if $rrd_error = RRDs::error;
}


# Here are Brian Paulson's notes on how to connect an iButton weather station.

# Note:  In order for read_windspeed to work on Unix, you will need to
#        have Time::HiRes installed.   Not needed on Windows.

# Port is the port that your weather station is connected to.  If your
# weather station is connected to the rest of your 1-wire net, you don't
# need to specify a port because mh will use that by default
# The CHIPS are a listing of all of the chips that make up the weather
# station.  You can get this list by looking at the ini.txt file that
# is generated by the Dallas Semiconductor Weather Station software
# I believe that the first 01 chip should be north and then the rest are
# listed in clockwise order
# By the way, I currently have the Weather Station sitting on my floor
# in the home office because I'm waiting for springtime to mount it outside
# As such, I haven't had a chance to verify that the wind direction and
# wind speed are accurate.

=begin comment 

Since I do not have one of these, I have to leave this commented out

$weather = new iButton::Weather( CHIPS => [ qw( 01000002C77C1FFE
01000002C7681465 01000002C77C12B4 01000002C76CD4E5 01000002C77C1EC9
01000002C76724E7 01000002C761AF69 01000002C7798A76 1D000000010C46AA
1200000013571545 10000000364A826A ) ]);
#				 PORT => $port );
if ($New_Second) {
    if ( $Second == 29) {
	my $temp = $weather->read_temp;
	print "Weather Temp = $temp\n" if defined $temp;
    }
    if ( $Second % 5 == 0 ) {
	my $windspeed = $weather->read_windspeed;
	print "Speed = $windspeed MPH\n" if defined $windspeed;

	my $dir = $weather->read_dir;
	print "Direction = $dir\n" if defined $dir;
    }
}

=cut

