# Category=Other
#
# This file interfaces to the irman box, available for $30 from
#    http://evation.com/irman/interface.txt
#
# The protocol is documented at:
#    http://evation.com/irman/interface.txt
#
# Add these entries to your mh.ini file:
#
#  serial_irman_port=COM2
#  serial_irman_baudrate=9600
#  serial_irman_handshake=none
#  serial_irman_datatype=raw
#
# To program the database:
#  - click/speak/run: "Start programming IRman codes"
#  - Enter the key name in the Tk "Test 2" field
#  - Push the IR key
#  - Repeat for all your keys
#  - click/speak/run: "Stop programming IRman codes"

# &tk_entry('Test 1 (a..z)', \$test_input1, "Test 2", \$Save{test_input2});

$irman = new Generic_Item();
$irman_port = new Serial_Item( undef, undef, 'serial_irman' );

# You can use state_now $irman queries in any
# of your events, like this:
#print_log "irman said: $state" if $state = state_now $irman;

my %DBM_IR;
if ( $Startup or $Reread ) {
    use Fcntl;

    # This is where the ir key programing is stored
    my $dbm_file = "$config_parms{data_dir}/irman.dbm";
    print_log "Opening irman database $dbm_file";

    my $tie_code =
      qq[tie (%DBM_IR, 'DB_File', '$dbm_file', O_RDWR|O_CREAT, 0666) or ];
    $tie_code .=
      qq[print "\n\nError, can not open irman dbm file $dbm_file: $!"];

    eval $tie_code;
    if ($@) {
        print_log "\n\nError in tieing to $dbm_file:\n  $@";
    }

    # Initilize the irman interface
    print_log "Initializing the IRman interface";

    set_dtr $irman_port 1;    # Power it up
    set_rts $irman_port 1;
    select( undef, undef, undef, .010 );    # Sleep a bit

    set $irman_port "I";                    # Initialized it
    select( undef, undef, undef, .010 );    # Sleep a bit
    set $irman_port "R";

    #    set_data $irman_port '';    # Throw away powerup garbage data
}

# Start/stop programming mode
$v_irman_program = new Voice_Cmd("[Start,Stop] programming IRman codes");
$v_irman_program->set_info(
    'To program, enter the key key into test_input2, then press the ir button');

speak "${state}ing irmain programming" if $state = said $v_irman_program;

# Process data received from irman
if ( my $data = said $irman_port) {
    if ( $data eq 'OK' ) {
        print_log "IRman interface sucessfully initialized";
    }
    else {
        if ( state $v_irman_program eq 'Start' ) {
            $DBM_IR{$data} = $Save{test_input2};
            speak $Save{test_input2};
            print "irman program data: $data...\n";
        }
        else {
            logit( "$config_parms{data_dir}/logs/tv_ir.$Year_Month_Now.log",
                $data );
            print "IR man data: ", unpack( 'H*', $data );

            if ( $DBM_IR{$data} ) {
                set $irman $DBM_IR{$data};
                print " -> $DBM_IR{$data}\n";
            }
            else {
                print " -> unknown\n";
            }
        }

    }
    set_data $irman_port '';
}

# List ir codes
$v_irman_list = new Voice_Cmd 'List IR codes';
if ( said $v_irman_list) {
    my %data = dbm_read("$config_parms{data_dir}/irman.dbm");
    my $data = "List of IR codes:\n";
    for my $key ( sort keys %data ) {
        $data .= "key=$key value=$data{$key}\n";
    }
    display $data;
}
