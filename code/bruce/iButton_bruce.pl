# Category = iButtons

#@ Generic ibutton stuff is in mh/code/common ibutton.pl

=begin comment

 Ray Dzek created a nice 'how to get started with iButton guide' at
    http://www.solarbugs.com/home/ibutton.htm

 Enable iButton support by using these mh.ini parms:
   iButton_tweak         = 0      # Set to 1 to tweak timings if it appears not to work
   iButton_serial_port   = COM1
   iButton_2_serial_port = COM2   # If you have more than one ibutton port
   iButton_3_serial_port = COM2   # If you have more than one ibutton port
   weather_uom_temp = C         # If you want to change degress unit from F to C

 You can buy iButton stuff here:
    http://www.iButton.com/index.html
    http://www.pointsix.com
 
 More info on coding iButton_Item is in mh/docs/mh.html

 Specific iButton examples are in mh/code/bruce/iButton.pl

=cut

$v_iButton_readtemps = new Voice_Cmd "Read the iButton temperature buttons";
$v_iButton_readtemps->set_info(
    'This reads all all iButton temperature devices.  Takes a while (.6 s per device)'
);
$v_iButton_readtemp = new Voice_Cmd "Read the iButton temperature [1,2,3,4]";

$v_iButton_readtemp->set_info(
    'Read only the temperature from a specific button');
$v_iButton_readtemp->set_authority('anyone');

$v_iButton_relay1 = new Voice_Cmd "Turn on relay1 [on,off]";
$v_iButton_relay1->set_info('Controls a test relay');
$v_iButton_relay1->set_authority('anyone');

my @ib_temps = ( $ib_temp1, $ib_temp2, $ib_temp3, $ib_temp4 );

$ib_relay1 = new iButton '120000001187d206', undef, 'A';
$ib_relay2 = new iButton '120000001187d206', undef, 'B';

$remark_bad = new File_Item "$config_parms{data_dir}/remarks/personal_bad.txt",
  'Ok';
$remark_good =
  new File_Item "$config_parms{data_dir}/remarks/personal_good.txt", 'Ok';
$f_deep_thoughts_ib =
  new File_Item("$config_parms{data_dir}/remarks/deep_thoughts.txt");

speak
  voice => 'next',
  text  => read_random $remark_bad
  if ON eq state_now $ib_nick;
speak
  voice => 'next',
  text  => read_next $f_deep_thoughts_ib
  if ON eq state_now $ib_zack;
speak
  voice => 'next',
  text  => read_next $remark_good
  if ON eq state_now $ib_bruce;
play "fun/*.wav" if ON eq state_now $ib_laurie;

if ( $state = said $v_iButton_relay1) {
    print_log "Setting iButton relay1 to $state";
    set $ib_relay1 $state;
}

# Monitor state changes in temp buttons
for my $ib ( 0 .. $#ib_temps ) {
    if ( my $temp = $ib_temps[$ib]->state_now ) {
        my $ib_name = substr $ib_temps[$ib]->{object_name}, 1;
        print_log "Temp for sensor $ib_name: $temp degrees";
        update_rrd_ib_temp( $ib_name, $temp );
        logit( "$config_parms{data_dir}/iButton_temps.log", "$ib_name: $temp" );
    }
}

# Read one temp
if ( $state = said $v_iButton_readtemp) {
    my $ib   = $ib_temps[ $state - 1 ];
    my $temp = read_temp $ib;
    print "dbx temp=$temp\n";

    #    read_temp $ib;              # This will trigger a state change
}

# List all iButton temperatures.  This can take a while ... best us a proxy
if ( said $v_iButton_readtemps) {
    print_log "Reading iButton temperatures";

    #   my @ib_list = &iButton::scan('10'); # gets DS1920/DS1820 devices  22 for DS1822 devices
    #   for my $ib (@ib_list) {
    for my $ib (@ib_temps) {
        read_temp $ib;
    }
}

# Log temp sensor periodically ... not too often as this is slow
my $ibutton_temp_device = 0;
if ( new_minute 2 ) {
    $ibutton_temp_device = 1 if ++$ibutton_temp_device > 4;
    my $ib = $ib_temps[ $ibutton_temp_device - 1 ];

    #   my $temp = read_temp $ib;
    read_temp $ib;
}

sub update_rrd_ib_temp {

    my ( $sensor, $temp ) = @_;

    return
      unless $config_parms{rrd_dir} and -e "$config_parms{rrd_dir}/$sensor.rrd";

    my ( $rrd_file, $rrd_error );

    $rrd_file = "$config_parms{rrd_dir}/$sensor.rrd";
    print "Storing $sensor data=$temp in $rrd_file\n";

    #	RRDs::update $rrd_file, "$Time:$temp";
    print_log "RRD ERROR: $rrd_error\n" if $rrd_error = RRDs::error;
}

