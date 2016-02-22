
# Category = iButtons

#@ Use digitemp to read ibuttons, when the built in mh perl code has problems reading ibutton temps.
#@ Download linux or windows digitemp from: http://www.digitemp.com

$v_iButton_readtemps = new Voice_Cmd "Read the iButton temperature buttons";
$v_iButton_readtemps->set_info(
    'This reads all all iButton temperature devices.');
$ibutton_read = new Process_Item('digitemp.exe -c/bin/digitemp.cfg -a');

if ( new_minute 1 or said $v_iButton_readtemps) {
    set_output $ibutton_read '/misterhouse/data/ibutton.data';
    start $ibutton_read;
}

# Data looks like this:  Feb 28 22:44:16 Sensor 0 C: 3.01 F: 37.42

if ( done_now $ibutton_read) {
    for my $data ( file_read '/misterhouse/data/ibutton.data' ) {
        next unless $data =~ /Sensor (\d+) C: (\S+) F: (\S+)/;
        next if $3 > 180;    # False readings look like 185
        print "ibutton sensor==$1 temp=$3\n";
        $Weather{"TempSpare$1"} = $3;
    }
}
