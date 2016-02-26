                use strict;

                package caddx::parse;
                use vars qw/%laycode/;
                ##################################################
                ##  Dynamically generated code to parse layout [01H]
                ##  DO NOT MODIFY THIS FILE! (look at caddx_build_parse.pl)
                ##################################################
                sub parse_01H {
                    my ($msg) = @_;
                    my (@msgb) = split( //, $msg );    # msgbytes
                    unshift( @msgb, "\x7e" );    #placeholder for 1-based array
                    my (@msgdata);
                    my (%msghash);
                    my ($datum);
                    foreach my $byte (@msgb) {
                        printf( "[%02x]", ord($byte) );
                    }
                    print "\n";
                    $datum = $msgb[1];
                    push( @msgdata, [ '1:', 'Message number', $datum ] );
                    $datum = join( '', @msgb[ 2 .. 5 ] );
                    push(
                        @msgdata,
                        [
                            '2-5:', 'Firmware version (i.e. 1.00 (ASCII))',
                            $datum
                        ]
                    );
                    $datum = $msgb[6];
                    push(
                        @msgdata,
                        [
                            '6:', 'Supported transition message flags (1)',
                            $datum
                        ]
                    );
                    $datum = &caddx::parse::getbits( $msgb[6], '0' );
                    push( @msgdata, [ '6:0', '(00h) Reserved', $datum ] );
                    $datum = &caddx::parse::getbits( $msgb[6], '1' );
                    push(
                        @msgdata,
                        [
                            '6:1', '(01h) Interface Configuration Message',
                            $datum
                        ]
                    );
                    $datum = &caddx::parse::getbits( $msgb[6], '2' );
                    push( @msgdata, [ '6:2', '(02h) Reserved', $datum ] );
                    $datum = &caddx::parse::getbits( $msgb[6], '3' );
                    push( @msgdata, [ '6:3', '(03h) Reserved', $datum ] );
                    $datum = &caddx::parse::getbits( $msgb[6], '4' );
                    push( @msgdata,
                        [ '6:4', '(04h) Zone Status Message', $datum ] );
                    $datum = &caddx::parse::getbits( $msgb[6], '5' );
                    push( @msgdata,
                        [ '6:5', '(05h) Zones Snapshot Message', $datum ] );
                    $datum = &caddx::parse::getbits( $msgb[6], '6' );
                    push( @msgdata,
                        [ '6:6', '(06h) Partition Status Message', $datum ] );
                    $datum = &caddx::parse::getbits( $msgb[6], '7' );
                    push( @msgdata,
                        [ '6:7', '(07h) Partitions Snapshot Message', $datum ]
                    );
                    $datum = $msgb[7];
                    push(
                        @msgdata,
                        [
                            '7:', 'Supported transition message flags (2)',
                            $datum
                        ]
                    );
                    $datum = &caddx::parse::getbits( $msgb[7], '0' );
                    push( @msgdata,
                        [ '7:0', '(08h) System Status Message', $datum ] );
                    $datum = &caddx::parse::getbits( $msgb[7], '1' );
                    push( @msgdata,
                        [ '7:1', '(09h) X-10 Message Received', $datum ] );
                    $datum = &caddx::parse::getbits( $msgb[7], '2' );
                    push( @msgdata,
                        [ '7:2', '(0Ah) Log Event Message', $datum ] );
                    $datum = &caddx::parse::getbits( $msgb[7], '3' );
                    push( @msgdata,
                        [ '7:3', '(0Bh) Keypad Message Received', $datum ] );
                    $datum = &caddx::parse::getbits( $msgb[7], '4' );
                    push( @msgdata, [ '7:4', '(0Ch) Reserved', $datum ] );
                    $datum = &caddx::parse::getbits( $msgb[7], '5' );
                    push( @msgdata, [ '7:5', '(0Dh) Reserved', $datum ] );
                    $datum = &caddx::parse::getbits( $msgb[7], '6' );
                    push( @msgdata, [ '7:6', '(0Eh) Reserved', $datum ] );
                    $datum = &caddx::parse::getbits( $msgb[7], '7' );
                    push( @msgdata, [ '7:7', '(0Fh) Reserved', $datum ] );
                    $datum = $msgb[8];
                    push(
                        @msgdata,
                        [
                            '8:', 'Supported request / command flags (1)',
                            $datum
                        ]
                    );
                    $datum = &caddx::parse::getbits( $msgb[8], '0' );
                    push( @msgdata, [ '8:0', '(20h) Reserved', $datum ] );
                    $datum = &caddx::parse::getbits( $msgb[8], '1' );
                    push(
                        @msgdata,
                        [
                            '8:1', '(21h) Interface Configuration Request',
                            $datum
                        ]
                    );
                    $datum = &caddx::parse::getbits( $msgb[8], '2' );
                    push( @msgdata, [ '8:2', '(22h) Reserved', $datum ] );
                    $datum = &caddx::parse::getbits( $msgb[8], '3' );
                    push( @msgdata,
                        [ '8:3', '(23h) Zone Name Request', $datum ] );
                    $datum = &caddx::parse::getbits( $msgb[8], '4' );
                    push( @msgdata,
                        [ '8:4', '(24h) Zone Status Request', $datum ] );
                    $datum = &caddx::parse::getbits( $msgb[8], '5' );
                    push( @msgdata,
                        [ '8:5', '(25h) Zones Snapshot Request', $datum ] );
                    $datum = &caddx::parse::getbits( $msgb[8], '6' );
                    push( @msgdata,
                        [ '8:6', '(26h) Partition Status Request', $datum ] );
                    $datum = &caddx::parse::getbits( $msgb[8], '7' );
                    push( @msgdata,
                        [ '8:7', '(27h) Partitions Snapshot Request', $datum ]
                    );
                    $datum = $msgb[9];
                    push(
                        @msgdata,
                        [
                            '9:', 'Supported request / command flags (2)',
                            $datum
                        ]
                    );
                    $datum = &caddx::parse::getbits( $msgb[9], '0' );
                    push( @msgdata,
                        [ '9:0', '(28h) System Status Request', $datum ] );
                    $datum = &caddx::parse::getbits( $msgb[9], '1' );
                    push( @msgdata,
                        [ '9:1', '(29h) Send X-10 Message', $datum ] );
                    $datum = &caddx::parse::getbits( $msgb[9], '2' );
                    push( @msgdata,
                        [ '9:2', '(2Ah) Log Event Request', $datum ] );
                    $datum = &caddx::parse::getbits( $msgb[9], '3' );
                    push( @msgdata,
                        [ '9:3', '(2Bh) Send Keypad Text Message', $datum ] );
                    $datum = &caddx::parse::getbits( $msgb[9], '4' );
                    push( @msgdata,
                        [ '9:4', '(2Ch) Keypad Terminal Mode Request', $datum ]
                    );
                    $datum = &caddx::parse::getbits( $msgb[9], '5' );
                    push( @msgdata, [ '9:5', '(2Dh) Reserved', $datum ] );
                    $datum = &caddx::parse::getbits( $msgb[9], '6' );
                    push( @msgdata, [ '9:6', '(2Eh) Reserved', $datum ] );
                    $datum = &caddx::parse::getbits( $msgb[9], '7' );
                    push( @msgdata, [ '9:7', '(2Fh) Reserved', $datum ] );
                    $datum = $msgb[10];
                    push(
                        @msgdata,
                        [
                            '10:', 'Supported request / command flags (3)',
                            $datum
                        ]
                    );
                    $datum = &caddx::parse::getbits( $msgb[10], '0' );
                    push( @msgdata,
                        [ '10:0', '(30h) Program Data Request', $datum ] );
                    $datum = &caddx::parse::getbits( $msgb[10], '1' );
                    push( @msgdata,
                        [ '10:1', '(31h) Program Data Command', $datum ] );
                    $datum = &caddx::parse::getbits( $msgb[10], '2' );
                    push(
                        @msgdata,
                        [
                            '10:2', '(32h) User Information Request with PIN',
                            $datum
                        ]
                    );
                    $datum = &caddx::parse::getbits( $msgb[10], '3' );
                    push(
                        @msgdata,
                        [
                            '10:3',
                            '(33h) User Information Request without PIN',
                            $datum
                        ]
                    );
                    $datum = &caddx::parse::getbits( $msgb[10], '4' );
                    push(
                        @msgdata,
                        [
                            '10:4', '(34h) Set User Code Command with PIN',
                            $datum
                        ]
                    );
                    $datum = &caddx::parse::getbits( $msgb[10], '5' );
                    push(
                        @msgdata,
                        [
                            '10:5', '(35h) Set User Code Command without PIN',
                            $datum
                        ]
                    );
                    $datum = &caddx::parse::getbits( $msgb[10], '6' );
                    push(
                        @msgdata,
                        [
                            '10:6',
                            '(36h) Set User Authorization Command with PIN',
                            $datum
                        ]
                    );
                    $datum = &caddx::parse::getbits( $msgb[10], '7' );
                    push(
                        @msgdata,
                        [
                            '10:7',
                            '(37h) Set User Authorization Command without PIN',
                            $datum
                        ]
                    );
                    $datum = $msgb[11];
                    push(
                        @msgdata,
                        [
                            '11:', 'Supported request / command flags (4)',
                            $datum
                        ]
                    );
                    $datum = &caddx::parse::getbits( $msgb[11], '0' );
                    push( @msgdata, [ '11:0', '(38h) Reserved', $datum ] );
                    $datum = &caddx::parse::getbits( $msgb[11], '1' );
                    push( @msgdata, [ '11:1', '(39h) Reserved', $datum ] );
                    $datum = &caddx::parse::getbits( $msgb[11], '2' );
                    push(
                        @msgdata,
                        [
                            '11:2', '(3Ah) Store Communication Event Command',
                            $datum
                        ]
                    );
                    $datum = &caddx::parse::getbits( $msgb[11], '3' );
                    push(
                        @msgdata,
                        [
                            '11:3', '(3Bh) Set Clock / Calendar Command',
                            $datum
                        ]
                    );
                    $datum = &caddx::parse::getbits( $msgb[11], '4' );
                    push(
                        @msgdata,
                        [
                            '11:4', '(3Ch) Primary Keypad Function with PIN',
                            $datum
                        ]
                    );
                    $datum = &caddx::parse::getbits( $msgb[11], '5' );
                    push(
                        @msgdata,
                        [
                            '11:5',
                            '(3Dh) Primary Keypad Function without PIN', $datum
                        ]
                    );
                    $datum = &caddx::parse::getbits( $msgb[11], '6' );
                    push( @msgdata,
                        [ '11:6', '(3Eh) Secondary Keypad Function', $datum ] );
                    $datum = &caddx::parse::getbits( $msgb[11], '7' );
                    push( @msgdata,
                        [ '11:7', '(3Fh) Zone Bypass Toggle', $datum ] );
                    $msghash{_parsed_} = \@msgdata;    # stash verbose parse
                    return \%msghash;    # send back a hash ref to all
                }
                ##################################################
                ##  Dynamically generated code to parse layout [03H]
                ##  DO NOT MODIFY THIS FILE! (look at caddx_build_parse.pl)
                ##################################################
                sub parse_03H {
                    my ($msg) = @_;
                    my (@msgb) = split( //, $msg );    # msgbytes
                    unshift( @msgb, "\x7e" );    #placeholder for 1-based array
                    my (@msgdata);
                    my (%msghash);
                    my ($datum);
                    foreach my $byte (@msgb) {
                        printf( "[%02x]", ord($byte) );
                    }
                    print "\n";
                    $datum = $msgb[1];
                    push( @msgdata, [ '1:', 'Message number', $datum ] );
                    $datum = $msgb[2];
                    push( @msgdata,
                        [ '2:', '{zone} number (0= zone 1)', $datum ] );
                    $msghash{zone} = $datum;
                    $datum = $msgb[3];
                    push( @msgdata, [ '3:', 'Zone name character 1', $datum ] );
                    $datum = $msgb[4];
                    push( @msgdata, [ '4:', 'Zone name character 2', $datum ] );
                    $datum = $msgb[5];
                    push( @msgdata, [ '5:', 'Zone name character 3', $datum ] );
                    $datum = $msgb[6];
                    push( @msgdata, [ '6:', 'Zone name character 4', $datum ] );
                    $datum = $msgb[7];
                    push( @msgdata, [ '7:', 'Zone name character 5', $datum ] );
                    $datum = $msgb[8];
                    push( @msgdata, [ '8:', 'Zone name character 6', $datum ] );
                    $datum = $msgb[9];
                    push( @msgdata, [ '9:', 'Zone name character 7', $datum ] );
                    $datum = $msgb[10];
                    push( @msgdata,
                        [ '10:', 'Zone name character 8', $datum ] );
                    $datum = $msgb[11];
                    push( @msgdata,
                        [ '11:', 'Zone name character 9', $datum ] );
                    $datum = $msgb[12];
                    push( @msgdata,
                        [ '12:', 'Zone name character 10', $datum ] );
                    $datum = $msgb[13];
                    push( @msgdata,
                        [ '13:', 'Zone name character 11', $datum ] );
                    $datum = $msgb[14];
                    push( @msgdata,
                        [ '14:', 'Zone name character 12', $datum ] );
                    $datum = $msgb[15];
                    push( @msgdata,
                        [ '15:', 'Zone name character 13', $datum ] );
                    $datum = $msgb[16];
                    push( @msgdata,
                        [ '16:', 'Zone name character 14', $datum ] );
                    $datum = $msgb[17];
                    push( @msgdata,
                        [ '17:', 'Zone name character 15', $datum ] );
                    $datum = $msgb[18];
                    push( @msgdata,
                        [ '18:', 'Zone name character 16', $datum ] );
                    $datum = join( '', @msgb[ 3 .. 18 ] );
                    push( @msgdata, [ '3-18:', '{zone_name}', $datum ] );
                    $msghash{zone_name} = $datum;
                    $msghash{_parsed_}  = \@msgdata;    # stash verbose parse
                    return \%msghash;    # send back a hash ref to all
                }
                ##################################################
                ##  Dynamically generated code to parse layout [04H]
                ##  DO NOT MODIFY THIS FILE! (look at caddx_build_parse.pl)
                ##################################################
                sub parse_04H {
                    my ($msg) = @_;
                    my (@msgb) = split( //, $msg );    # msgbytes
                    unshift( @msgb, "\x7e" );    #placeholder for 1-based array
                    my (@msgdata);
                    my (%msghash);
                    my ($datum);
                    foreach my $byte (@msgb) {
                        printf( "[%02x]", ord($byte) );
                    }
                    print "\n";
                    $datum = $msgb[1];
                    push( @msgdata, [ '1:', 'Message number', $datum ] );
                    $datum = $msgb[2];
                    push( @msgdata,
                        [ '2:', '{zone} number (0= zone 1)', $datum ] );
                    $msghash{zone} = $datum;
                    $datum = $msgb[3];
                    push( @msgdata, [ '3:', 'Partition mask', $datum ] );
                    $datum = &caddx::parse::getbits( $msgb[3], '0' );
                    push( @msgdata, [ '3:0', 'Partition 1 enable', $datum ] );
                    $datum = &caddx::parse::getbits( $msgb[3], '1' );
                    push( @msgdata, [ '3:1', 'Partition 2 enable', $datum ] );
                    $datum = &caddx::parse::getbits( $msgb[3], '2' );
                    push( @msgdata, [ '3:2', 'Partition 3 enable', $datum ] );
                    $datum = &caddx::parse::getbits( $msgb[3], '3' );
                    push( @msgdata, [ '3:3', 'Partition 4 enable', $datum ] );
                    $datum = &caddx::parse::getbits( $msgb[3], '4' );
                    push( @msgdata, [ '3:4', 'Partition 5 enable', $datum ] );
                    $datum = &caddx::parse::getbits( $msgb[3], '5' );
                    push( @msgdata, [ '3:5', 'Partition 6 enable', $datum ] );
                    $datum = &caddx::parse::getbits( $msgb[3], '6' );
                    push( @msgdata, [ '3:6', 'Partition 7 enable', $datum ] );
                    $datum = &caddx::parse::getbits( $msgb[3], '7' );
                    push( @msgdata, [ '3:7', 'Partition 8 enable', $datum ] );
                    $datum = $msgb[4];
                    push( @msgdata, [ '4:', 'Zone type flags (1)', $datum ] );
                    $datum = &caddx::parse::getbits( $msgb[4], '0' );
                    push( @msgdata, [ '4:0', 'Fire', $datum ] );
                    $datum = &caddx::parse::getbits( $msgb[4], '1' );
                    push( @msgdata, [ '4:1', '24 Hour', $datum ] );
                    $datum = &caddx::parse::getbits( $msgb[4], '2' );
                    push( @msgdata, [ '4:2', 'Key-switch', $datum ] );
                    $datum = &caddx::parse::getbits( $msgb[4], '3' );
                    push( @msgdata, [ '4:3', 'Follower', $datum ] );
                    $datum = &caddx::parse::getbits( $msgb[4], '4' );
                    push( @msgdata,
                        [ '4:4', 'Entry / exit  delay 1', $datum ] );
                    $datum = &caddx::parse::getbits( $msgb[4], '5' );
                    push( @msgdata, [ '4:5', 'Entry / exit delay 2', $datum ] );
                    $datum = &caddx::parse::getbits( $msgb[4], '6' );
                    push( @msgdata, [ '4:6', 'Interior', $datum ] );
                    $datum = &caddx::parse::getbits( $msgb[4], '7' );
                    push( @msgdata, [ '4:7', 'Local only', $datum ] );
                    $datum = $msgb[5];
                    push( @msgdata, [ '5:', 'Zone type flags (2)', $datum ] );
                    $datum = &caddx::parse::getbits( $msgb[5], '0' );
                    push( @msgdata, [ '5:0', 'Keypad sounder', $datum ] );
                    $datum = &caddx::parse::getbits( $msgb[5], '1' );
                    push( @msgdata, [ '5:1', 'Yelping siren', $datum ] );
                    $datum = &caddx::parse::getbits( $msgb[5], '2' );
                    push( @msgdata, [ '5:2', 'Steady siren', $datum ] );
                    $datum = &caddx::parse::getbits( $msgb[5], '3' );
                    push( @msgdata, [ '5:3', 'Chime', $datum ] );
                    $datum = &caddx::parse::getbits( $msgb[5], '4' );
                    push( @msgdata, [ '5:4', 'Bypassable', $datum ] );
                    $datum = &caddx::parse::getbits( $msgb[5], '5' );
                    push( @msgdata, [ '5:5', 'Group bypassable', $datum ] );
                    $datum = &caddx::parse::getbits( $msgb[5], '6' );
                    push( @msgdata, [ '5:6', 'Force armable', $datum ] );
                    $datum = &caddx::parse::getbits( $msgb[5], '7' );
                    push( @msgdata, [ '5:7', 'Entry guard', $datum ] );
                    $datum = $msgb[6];
                    push( @msgdata, [ '6:', 'Zone type flags (3)', $datum ] );
                    $datum = &caddx::parse::getbits( $msgb[6], '0' );
                    push( @msgdata, [ '6:0', 'Fast loop response', $datum ] );
                    $datum = &caddx::parse::getbits( $msgb[6], '1' );
                    push( @msgdata, [ '6:1', 'Double EOL tamper', $datum ] );
                    $datum = &caddx::parse::getbits( $msgb[6], '2' );
                    push( @msgdata, [ '6:2', 'Trouble', $datum ] );
                    $datum = &caddx::parse::getbits( $msgb[6], '3' );
                    push( @msgdata, [ '6:3', 'Cross zone', $datum ] );
                    $datum = &caddx::parse::getbits( $msgb[6], '4' );
                    push( @msgdata, [ '6:4', 'Dialer delay', $datum ] );
                    $datum = &caddx::parse::getbits( $msgb[6], '5' );
                    push( @msgdata, [ '6:5', 'Swinger shutdown', $datum ] );
                    $datum = &caddx::parse::getbits( $msgb[6], '6' );
                    push( @msgdata, [ '6:6', 'Restorable', $datum ] );
                    $datum = &caddx::parse::getbits( $msgb[6], '7' );
                    push( @msgdata, [ '6:7', 'Listen in', $datum ] );
                    $datum = $msgb[7];
                    push( @msgdata,
                        [ '7:', 'Zone condition flags (1)', $datum ] );
                    $datum = &caddx::parse::getbits( $msgb[7], '0' );
                    push(
                        @msgdata,
                        [
                            '7:0', '{faulted} Faulted (or delayed trip)',
                            $datum
                        ]
                    );
                    $msghash{faulted} = $datum;
                    $datum = &caddx::parse::getbits( $msgb[7], '1' );
                    push( @msgdata, [ '7:1', '{tampered} Tampered', $datum ] );
                    $msghash{tampered} = $datum;
                    $datum = &caddx::parse::getbits( $msgb[7], '2' );
                    push( @msgdata, [ '7:2', '{trouble} Trouble', $datum ] );
                    $msghash{trouble} = $datum;
                    $datum = &caddx::parse::getbits( $msgb[7], '3' );
                    push( @msgdata, [ '7:3', '{bypassed} Bypassed', $datum ] );
                    $msghash{bypassed} = $datum;
                    $datum = &caddx::parse::getbits( $msgb[7], '4' );
                    push( @msgdata,
                        [ '7:4', 'Inhibited (force armed)', $datum ] );
                    $datum = &caddx::parse::getbits( $msgb[7], '5' );
                    push( @msgdata, [ '7:5', 'Low battery', $datum ] );
                    $datum = &caddx::parse::getbits( $msgb[7], '6' );
                    push( @msgdata, [ '7:6', 'Loss of supervision', $datum ] );
                    $datum = &caddx::parse::getbits( $msgb[7], '7' );
                    push( @msgdata, [ '7:7', 'Reserved', $datum ] );
                    $datum = $msgb[8];
                    push( @msgdata,
                        [ '8:', 'Zone condition flags (2)', $datum ] );
                    $datum = &caddx::parse::getbits( $msgb[8], '0' );
                    push( @msgdata,
                        [ '8:0', '{alarm_memory} Alarm memory', $datum ] );
                    $msghash{alarm_memory} = $datum;
                    $datum = &caddx::parse::getbits( $msgb[8], '1' );
                    push( @msgdata, [ '8:1', 'Bypass memory', $datum ] );
                    $datum = &caddx::parse::getbits( $msgb[8], '2' );
                    push( @msgdata, [ '8:2', 'Reserved', $datum ] );
                    $datum = &caddx::parse::getbits( $msgb[8], '3' );
                    push( @msgdata, [ '8:3', 'Reserved', $datum ] );
                    $datum = &caddx::parse::getbits( $msgb[8], '4' );
                    push( @msgdata, [ '8:4', 'Reserved', $datum ] );
                    $datum = &caddx::parse::getbits( $msgb[8], '5' );
                    push( @msgdata, [ '8:5', 'Reserved', $datum ] );
                    $datum = &caddx::parse::getbits( $msgb[8], '6' );
                    push( @msgdata, [ '8:6', 'Reserved', $datum ] );
                    $datum = &caddx::parse::getbits( $msgb[8], '7' );
                    push( @msgdata, [ '8:7', 'Reserved', $datum ] );
                    $msghash{_parsed_} = \@msgdata;    # stash verbose parse
                    return \%msghash;    # send back a hash ref to all
                }
                ##################################################
                ##  Dynamically generated code to parse layout [05H]
                ##  DO NOT MODIFY THIS FILE! (look at caddx_build_parse.pl)
                ##################################################
                sub parse_05H {
                    my ($msg) = @_;
                    my (@msgb) = split( //, $msg );    # msgbytes
                    unshift( @msgb, "\x7e" );    #placeholder for 1-based array
                    my (@msgdata);
                    my (%msghash);
                    my ($datum);
                    foreach my $byte (@msgb) {
                        printf( "[%02x]", ord($byte) );
                    }
                    print "\n";
                    $datum = $msgb[1];
                    push( @msgdata, [ '1:', 'Message number', $datum ] );
                    $datum = $msgb[2];
                    push( @msgdata,
                        [ '2:', '{zone_offset} (0= start at zone 1)', $datum ]
                    );
                    $msghash{zone_offset} = $datum;
                    $datum = $msgb[3];
                    push( @msgdata,
                        [ '3:', 'Zone 1 & 2 (+offset) status flags', $datum ] );
                    $datum = &caddx::parse::getbits( $msgb[3], '0' );
                    push( @msgdata,
                        [ '3:0', 'Zone 1 faulted (or delayed trip)', $datum ] );
                    $datum = &caddx::parse::getbits( $msgb[3], '1' );
                    push( @msgdata,
                        [ '3:1', 'Zone 1 bypass (or inhibited)', $datum ] );
                    $datum = &caddx::parse::getbits( $msgb[3], '2' );
                    push(
                        @msgdata,
                        [
                            '3:2',
                            'Zone 1 trouble (tamper, low battery, or lost)',
                            $datum
                        ]
                    );
                    $datum = &caddx::parse::getbits( $msgb[3], '3' );
                    push( @msgdata, [ '3:3', 'Zone 1 alarm memory', $datum ] );
                    $datum = &caddx::parse::getbits( $msgb[3], '4' );
                    push( @msgdata,
                        [ '3:4', 'Zone 2 faulted (or delayed trip)', $datum ] );
                    $datum = &caddx::parse::getbits( $msgb[3], '5' );
                    push( @msgdata,
                        [ '3:5', 'Zone 2 bypass (or inhibited)', $datum ] );
                    $datum = &caddx::parse::getbits( $msgb[3], '6' );
                    push(
                        @msgdata,
                        [
                            '3:6',
                            'Zone 2 trouble (tamper, low battery, or lost)',
                            $datum
                        ]
                    );
                    $datum = &caddx::parse::getbits( $msgb[3], '7' );
                    push( @msgdata, [ '3:7', 'Zone 2 alarm memory', $datum ] );
                    $datum = $msgb[4];
                    push( @msgdata,
                        [ '4:', 'Zone 3 & 4 (+offset) status flags', $datum ] );
                    $datum = &caddx::parse::getbits( $msgb[4], '0' );
                    push( @msgdata,
                        [ '4:0', 'Zone 3 faulted (or delayed trip)', $datum ] );
                    $datum = &caddx::parse::getbits( $msgb[4], '1' );
                    push( @msgdata,
                        [ '4:1', 'Zone 3 bypass (or inhibited)', $datum ] );
                    $datum = &caddx::parse::getbits( $msgb[4], '2' );
                    push(
                        @msgdata,
                        [
                            '4:2',
                            'Zone 3 trouble (tamper, low battery, or lost)',
                            $datum
                        ]
                    );
                    $datum = &caddx::parse::getbits( $msgb[4], '3' );
                    push( @msgdata, [ '4:3', 'Zone 3 alarm memory', $datum ] );
                    $datum = &caddx::parse::getbits( $msgb[4], '4' );
                    push( @msgdata,
                        [ '4:4', 'Zone 4 faulted (or delayed trip)', $datum ] );
                    $datum = &caddx::parse::getbits( $msgb[4], '5' );
                    push( @msgdata,
                        [ '4:5', 'Zone 4 bypass (or inhibited)', $datum ] );
                    $datum = &caddx::parse::getbits( $msgb[4], '6' );
                    push(
                        @msgdata,
                        [
                            '4:6',
                            'Zone 4 trouble (tamper, low battery, or lost)',
                            $datum
                        ]
                    );
                    $datum = &caddx::parse::getbits( $msgb[4], '7' );
                    push( @msgdata, [ '4:7', 'Zone 4 alarm memory', $datum ] );
                    $datum = $msgb[3];
                    push( @msgdata,
                        [ '3:', 'Zone 1 & 2 (+offset) status flags', $datum ] );
                    $datum = &caddx::parse::getbits( $msgb[3], '0-3' );
                    push( @msgdata, [ '3:0-3', '{Zone1} zsnap', $datum ] );
                    $msghash{Zone1} = $datum;
                    $datum = &caddx::parse::getbits( $msgb[3], '4-7' );
                    push( @msgdata, [ '3:4-7', '{Zone2} zsnap', $datum ] );
                    $msghash{Zone2} = $datum;
                    $datum = $msgb[4];
                    push( @msgdata,
                        [ '4:', 'Zone 3 & 4 (+offset) status flags', $datum ] );
                    $datum = &caddx::parse::getbits( $msgb[4], '0-3' );
                    push( @msgdata, [ '4:0-3', '{Zone3} zsnap', $datum ] );
                    $msghash{Zone3} = $datum;
                    $datum = &caddx::parse::getbits( $msgb[4], '4-7' );
                    push( @msgdata, [ '4:4-7', '{Zone4} zsnap', $datum ] );
                    $msghash{Zone4} = $datum;
                    $datum = $msgb[5];
                    push( @msgdata,
                        [ '5:', 'Zone 5 & 6 (+offset) status flags', $datum ] );
                    $datum = &caddx::parse::getbits( $msgb[5], '0-3' );
                    push( @msgdata, [ '5:0-3', '{Zone5} zsnap', $datum ] );
                    $msghash{Zone5} = $datum;
                    $datum = &caddx::parse::getbits( $msgb[5], '4-7' );
                    push( @msgdata, [ '5:4-7', '{Zone6} zsnap', $datum ] );
                    $msghash{Zone6} = $datum;
                    $datum = $msgb[6];
                    push( @msgdata,
                        [ '6:', 'Zone 7 & 8 (+offset) status flags', $datum ] );
                    $datum = &caddx::parse::getbits( $msgb[6], '0-3' );
                    push( @msgdata, [ '6:0-3', '{Zone7} zsnap', $datum ] );
                    $msghash{Zone7} = $datum;
                    $datum = &caddx::parse::getbits( $msgb[6], '4-7' );
                    push( @msgdata, [ '6:4-7', '{Zone8} zsnap', $datum ] );
                    $msghash{Zone8} = $datum;
                    $datum = $msgb[7];
                    push( @msgdata,
                        [ '7:', 'Zone 9 & 10 (+offset) status flags', $datum ]
                    );
                    $datum = &caddx::parse::getbits( $msgb[7], '0-3' );
                    push( @msgdata, [ '7:0-3', '{Zone9} zsnap', $datum ] );
                    $msghash{Zone9} = $datum;
                    $datum = &caddx::parse::getbits( $msgb[7], '4-7' );
                    push( @msgdata, [ '7:4-7', '{Zone10} zsnap', $datum ] );
                    $msghash{Zone10} = $datum;
                    $datum = $msgb[8];
                    push( @msgdata,
                        [ '8:', 'Zone 11 & 12 (+offset) status flags', $datum ]
                    );
                    $datum = &caddx::parse::getbits( $msgb[8], '0-3' );
                    push( @msgdata, [ '8:0-3', '{Zone11} zsnap', $datum ] );
                    $msghash{Zone11} = $datum;
                    $datum = &caddx::parse::getbits( $msgb[8], '4-7' );
                    push( @msgdata, [ '8:4-7', '{Zone12} zsnap', $datum ] );
                    $msghash{Zone12} = $datum;
                    $datum = $msgb[9];
                    push( @msgdata,
                        [ '9:', 'Zone 13 & 14 (+offset) status flags', $datum ]
                    );
                    $datum = &caddx::parse::getbits( $msgb[9], '0-3' );
                    push( @msgdata, [ '9:0-3', '{Zone13} zsnap', $datum ] );
                    $msghash{Zone13} = $datum;
                    $datum = &caddx::parse::getbits( $msgb[9], '4-7' );
                    push( @msgdata, [ '9:4-7', '{Zone14} zsnap', $datum ] );
                    $msghash{Zone14} = $datum;
                    $datum = $msgb[10];
                    push(
                        @msgdata,
                        [
                            '10:', 'Zone 15 & 16 (+offset) status flags',
                            $datum
                        ]
                    );
                    $datum = &caddx::parse::getbits( $msgb[10], '0-3' );
                    push( @msgdata, [ '10:0-3', '{Zone15} zsnap', $datum ] );
                    $msghash{Zone15} = $datum;
                    $datum = &caddx::parse::getbits( $msgb[10], '4-7' );
                    push( @msgdata, [ '10:4-7', '{Zone16} zsnap', $datum ] );
                    $msghash{Zone16}   = $datum;
                    $msghash{_parsed_} = \@msgdata;    # stash verbose parse
                    return \%msghash;    # send back a hash ref to all
                }
                ##################################################
                ##  Dynamically generated code to parse layout [06H]
                ##  DO NOT MODIFY THIS FILE! (look at caddx_build_parse.pl)
                ##################################################
                sub parse_06H {
                    my ($msg) = @_;
                    my (@msgb) = split( //, $msg );    # msgbytes
                    unshift( @msgb, "\x7e" );    #placeholder for 1-based array
                    my (@msgdata);
                    my (%msghash);
                    my ($datum);
                    foreach my $byte (@msgb) {
                        printf( "[%02x]", ord($byte) );
                    }
                    print "\n";
                    $datum = $msgb[1];
                    push( @msgdata, [ '1:', 'Message number', $datum ] );
                    $datum = $msgb[2];
                    push(
                        @msgdata,
                        [
                            '2:',
                            '{hex_partition} Partition number (0= partition 1)',
                            $datum
                        ]
                    );
                    $msghash{hex_partition} = $datum;
                    $datum = $msgb[3];
                    push( @msgdata,
                        [ '3:', 'Partition condition flags (1)', $datum ] );
                    $datum = &caddx::parse::getbits( $msgb[3], '0' );
                    push( @msgdata, [ '3:0', 'Bypass code required', $datum ] );
                    $datum = &caddx::parse::getbits( $msgb[3], '1' );
                    push( @msgdata, [ '3:1', 'Fire trouble', $datum ] );
                    $datum = &caddx::parse::getbits( $msgb[3], '2' );
                    push( @msgdata, [ '3:2', 'Fire', $datum ] );
                    $datum = &caddx::parse::getbits( $msgb[3], '3' );
                    push( @msgdata, [ '3:3', 'Pulsing Buzzer', $datum ] );
                    $datum = &caddx::parse::getbits( $msgb[3], '4' );
                    push( @msgdata, [ '3:4', 'TLM fault memory', $datum ] );
                    $datum = &caddx::parse::getbits( $msgb[3], '5' );
                    push( @msgdata, [ '3:5', 'reserved', $datum ] );
                    $datum = &caddx::parse::getbits( $msgb[3], '6' );
                    push( @msgdata, [ '3:6', '{armed}', $datum ] );
                    $msghash{armed} = $datum;
                    $datum = &caddx::parse::getbits( $msgb[3], '7' );
                    push( @msgdata, [ '3:7', 'Instant', $datum ] );
                    $datum = $msgb[4];
                    push( @msgdata,
                        [ '4:', 'Partition condition flags (2)', $datum ] );
                    $datum = &caddx::parse::getbits( $msgb[4], '0' );
                    push( @msgdata, [ '4:0', 'Previous Alarm', $datum ] );
                    $datum = &caddx::parse::getbits( $msgb[4], '1' );
                    push( @msgdata, [ '4:1', 'Siren on', $datum ] );
                    $datum = &caddx::parse::getbits( $msgb[4], '2' );
                    push( @msgdata, [ '4:2', 'Steady siren on', $datum ] );
                    $datum = &caddx::parse::getbits( $msgb[4], '3' );
                    push( @msgdata, [ '4:3', 'Alarm memory', $datum ] );
                    $datum = &caddx::parse::getbits( $msgb[4], '4' );
                    push( @msgdata, [ '4:4', 'Tamper', $datum ] );
                    $datum = &caddx::parse::getbits( $msgb[4], '5' );
                    push( @msgdata,
                        [ '4:5', 'Cancel command entered', $datum ] );
                    $datum = &caddx::parse::getbits( $msgb[4], '6' );
                    push( @msgdata, [ '4:6', 'Code entered', $datum ] );
                    $datum = &caddx::parse::getbits( $msgb[4], '7' );
                    push( @msgdata, [ '4:7', 'Cancel pending', $datum ] );
                    $datum = $msgb[5];
                    push( @msgdata,
                        [ '5:', 'Partition condition flags (3)', $datum ] );
                    $datum = &caddx::parse::getbits( $msgb[5], '0' );
                    push( @msgdata, [ '5:0', 'Reserved', $datum ] );
                    $datum = &caddx::parse::getbits( $msgb[5], '1' );
                    push( @msgdata, [ '5:1', 'Silent exit enabled', $datum ] );
                    $datum = &caddx::parse::getbits( $msgb[5], '2' );
                    push( @msgdata,
                        [ '5:2', 'Entryguard ({stay} mode)', $datum ] );
                    $msghash{stay} = $datum;
                    $datum = &caddx::parse::getbits( $msgb[5], '3' );
                    push( @msgdata, [ '5:3', '{chime} mode on', $datum ] );
                    $msghash{chime} = $datum;
                    $datum = &caddx::parse::getbits( $msgb[5], '4' );
                    push( @msgdata, [ '5:4', 'Entry', $datum ] );
                    $datum = &caddx::parse::getbits( $msgb[5], '5' );
                    push( @msgdata,
                        [ '5:5', 'Delay expiration warning', $datum ] );
                    $datum = &caddx::parse::getbits( $msgb[5], '6' );
                    push( @msgdata, [ '5:6', 'Exit1', $datum ] );
                    $datum = &caddx::parse::getbits( $msgb[5], '7' );
                    push( @msgdata, [ '5:7', 'Exit2', $datum ] );
                    $datum = $msgb[6];
                    push( @msgdata,
                        [ '6:', 'Partition condition flags (4)', $datum ] );
                    $datum = &caddx::parse::getbits( $msgb[6], '0' );
                    push( @msgdata, [ '6:0', 'LED extinguish', $datum ] );
                    $datum = &caddx::parse::getbits( $msgb[6], '1' );
                    push( @msgdata, [ '6:1', 'Cross timing', $datum ] );
                    $datum = &caddx::parse::getbits( $msgb[6], '2' );
                    push( @msgdata,
                        [ '6:2', 'Recent closing being timed', $datum ] );
                    $datum = &caddx::parse::getbits( $msgb[6], '3' );
                    push( @msgdata, [ '6:3', 'Reserved', $datum ] );
                    $datum = &caddx::parse::getbits( $msgb[6], '4' );
                    push( @msgdata, [ '6:4', 'Exit error triggered', $datum ] );
                    $datum = &caddx::parse::getbits( $msgb[6], '5' );
                    push( @msgdata, [ '6:5', 'Auto home inhibited', $datum ] );
                    $datum = &caddx::parse::getbits( $msgb[6], '6' );
                    push( @msgdata, [ '6:6', 'Sensor low battery', $datum ] );
                    $datum = &caddx::parse::getbits( $msgb[6], '7' );
                    push( @msgdata,
                        [ '6:7', 'Sensor lost supervision', $datum ] );
                    $datum = $msgb[7];
                    push( @msgdata, [ '7:', 'Last user number', $datum ] );
                    $datum = $msgb[8];
                    push( @msgdata,
                        [ '8:', 'Partition condition flags (5)', $datum ] );
                    $datum = &caddx::parse::getbits( $msgb[8], '0' );
                    push( @msgdata, [ '8:0', 'Re-exit active', $datum ] );
                    $datum = &caddx::parse::getbits( $msgb[8], '1' );
                    push( @msgdata,
                        [ '8:1', 'Force arm triggered by auto arm', $datum ] );
                    $datum = &caddx::parse::getbits( $msgb[8], '2' );
                    push( @msgdata, [ '8:2', '{ready} to arm', $datum ] );
                    $msghash{ready} = $datum;
                    $datum = &caddx::parse::getbits( $msgb[8], '3' );
                    push( @msgdata, [ '8:3', 'Ready to force arm', $datum ] );
                    $datum = &caddx::parse::getbits( $msgb[8], '4' );
                    push( @msgdata, [ '8:4', 'Valid PIN accepted', $datum ] );
                    $datum = &caddx::parse::getbits( $msgb[8], '5' );
                    push( @msgdata, [ '8:5', 'Chime on (sounding)', $datum ] );
                    $datum = &caddx::parse::getbits( $msgb[8], '6' );
                    push( @msgdata,
                        [ '8:6', 'Error beep (triple beep)', $datum ] );
                    $datum = &caddx::parse::getbits( $msgb[8], '7' );
                    push( @msgdata,
                        [ '8:7', 'Tone on (activation tone)', $datum ] );
                    $datum = $msgb[9];
                    push( @msgdata,
                        [ '9:', 'Partition condition flags (6)', $datum ] );
                    $datum = &caddx::parse::getbits( $msgb[9], '0' );
                    push( @msgdata, [ '9:0', 'Entry 1', $datum ] );
                    $datum = &caddx::parse::getbits( $msgb[9], '1' );
                    push( @msgdata, [ '9:1', 'Open period', $datum ] );
                    $datum = &caddx::parse::getbits( $msgb[9], '2' );
                    push( @msgdata,
                        [ '9:2', 'Alarm sent using phone number 1', $datum ] );
                    $datum = &caddx::parse::getbits( $msgb[9], '3' );
                    push( @msgdata,
                        [ '9:3', 'Alarm sent using phone number 2', $datum ] );
                    $datum = &caddx::parse::getbits( $msgb[9], '4' );
                    push( @msgdata,
                        [ '9:4', 'Alarm sent using phone number 3', $datum ] );
                    $datum = &caddx::parse::getbits( $msgb[9], '5' );
                    push( @msgdata, [ '9:5', 'Zone bypassed', $datum ] );
                    $datum = &caddx::parse::getbits( $msgb[9], '6' );
                    push( @msgdata, [ '9:6', 'Keyswitch armed', $datum ] );
                    $datum = &caddx::parse::getbits( $msgb[9], '7' );
                    push(
                        @msgdata,
                        [
                            '9:7', 'Delay Trip in progress (common zone)',
                            $datum
                        ]
                    );
                    $msghash{_parsed_} = \@msgdata;    # stash verbose parse
                    return \%msghash;    # send back a hash ref to all
                }
                ##################################################
                ##  Dynamically generated code to parse layout [07H]
                ##  DO NOT MODIFY THIS FILE! (look at caddx_build_parse.pl)
                ##################################################
                sub parse_07H {
                    my ($msg) = @_;
                    my (@msgb) = split( //, $msg );    # msgbytes
                    unshift( @msgb, "\x7e" );    #placeholder for 1-based array
                    my (@msgdata);
                    my (%msghash);
                    my ($datum);
                    foreach my $byte (@msgb) {
                        printf( "[%02x]", ord($byte) );
                    }
                    print "\n";
                    $datum = $msgb[1];
                    push( @msgdata, [ '1:', 'Message number', $datum ] );
                    $datum = $msgb[2];
                    push( @msgdata,
                        [ '2:', '{partition1} psnap condition flags', $datum ]
                    );
                    $msghash{partition1} = $datum;
                    $datum = $msgb[3];
                    push( @msgdata,
                        [ '3:', '{partition2} psnap condition flags', $datum ]
                    );
                    $msghash{partition2} = $datum;
                    $datum = $msgb[4];
                    push( @msgdata,
                        [ '4:', '{partition3} psnap condition flags', $datum ]
                    );
                    $msghash{partition3} = $datum;
                    $datum = $msgb[5];
                    push( @msgdata,
                        [ '5:', '{partition4} psnap condition flags', $datum ]
                    );
                    $msghash{partition4} = $datum;
                    $datum = $msgb[6];
                    push( @msgdata,
                        [ '6:', '{partition5} psnap condition flags', $datum ]
                    );
                    $msghash{partition5} = $datum;
                    $datum = $msgb[7];
                    push( @msgdata,
                        [ '7:', '{partition6} psnap condition flags', $datum ]
                    );
                    $msghash{partition6} = $datum;
                    $datum = $msgb[8];
                    push( @msgdata,
                        [ '8:', '{partition7} psnap condition flags', $datum ]
                    );
                    $msghash{partition7} = $datum;
                    $datum = $msgb[9];
                    push( @msgdata,
                        [ '9:', '{partition8} psnap condition flags', $datum ]
                    );
                    $msghash{partition8} = $datum;
                    $msghash{_parsed_}   = \@msgdata;    # stash verbose parse
                    return \%msghash;    # send back a hash ref to all
                }
                ##################################################
                ##  Dynamically generated code to parse layout [08H]
                ##  DO NOT MODIFY THIS FILE! (look at caddx_build_parse.pl)
                ##################################################
                sub parse_08H {
                    my ($msg) = @_;
                    my (@msgb) = split( //, $msg );    # msgbytes
                    unshift( @msgb, "\x7e" );    #placeholder for 1-based array
                    my (@msgdata);
                    my (%msghash);
                    my ($datum);
                    foreach my $byte (@msgb) {
                        printf( "[%02x]", ord($byte) );
                    }
                    print "\n";
                    $datum = $msgb[1];
                    push( @msgdata, [ '1:', 'Message number', $datum ] );
                    $datum = $msgb[2];
                    push( @msgdata, [ '2:', 'Panel ID number', $datum ] );
                    $datum = $msgb[3];
                    push( @msgdata, [ '3:', '', $datum ] );
                    $datum = &caddx::parse::getbits( $msgb[3], '0' );
                    push( @msgdata, [ '3:0', 'Line seizure', $datum ] );
                    $datum = &caddx::parse::getbits( $msgb[3], '1' );
                    push( @msgdata, [ '3:1', 'Off hook', $datum ] );
                    $datum = &caddx::parse::getbits( $msgb[3], '2' );
                    push( @msgdata,
                        [ '3:2', 'Initial handshake received', $datum ] );
                    $datum = &caddx::parse::getbits( $msgb[3], '3' );
                    push( @msgdata, [ '3:3', 'Download in progress', $datum ] );
                    $datum = &caddx::parse::getbits( $msgb[3], '4' );
                    push( @msgdata,
                        [ '3:4', 'Dialer delay in progress', $datum ] );
                    $datum = &caddx::parse::getbits( $msgb[3], '5' );
                    push( @msgdata, [ '3:5', 'Using backup phone', $datum ] );
                    $datum = &caddx::parse::getbits( $msgb[3], '6' );
                    push( @msgdata, [ '3:6', 'Listen in active', $datum ] );
                    $datum = &caddx::parse::getbits( $msgb[3], '7' );
                    push( @msgdata, [ '3:7', 'Two way lockout', $datum ] );
                    $datum = $msgb[4];
                    push( @msgdata, [ '4:', '', $datum ] );
                    $datum = &caddx::parse::getbits( $msgb[4], '0' );
                    push( @msgdata, [ '4:0', 'Ground fault', $datum ] );
                    $datum = &caddx::parse::getbits( $msgb[4], '1' );
                    push( @msgdata, [ '4:1', 'Phone fault', $datum ] );
                    $datum = &caddx::parse::getbits( $msgb[4], '2' );
                    push( @msgdata, [ '4:2', 'Fail to communicate', $datum ] );
                    $datum = &caddx::parse::getbits( $msgb[4], '3' );
                    push( @msgdata, [ '4:3', 'Fuse fault', $datum ] );
                    $datum = &caddx::parse::getbits( $msgb[4], '4' );
                    push( @msgdata, [ '4:4', 'Box tamper', $datum ] );
                    $datum = &caddx::parse::getbits( $msgb[4], '5' );
                    push( @msgdata,
                        [ '4:5', 'Siren tamper / trouble', $datum ] );
                    $datum = &caddx::parse::getbits( $msgb[4], '6' );
                    push( @msgdata, [ '4:6', 'Low Battery', $datum ] );
                    $datum = &caddx::parse::getbits( $msgb[4], '7' );
                    push( @msgdata, [ '4:7', 'AC fail', $datum ] );
                    $datum = $msgb[5];
                    push( @msgdata, [ '5:', '', $datum ] );
                    $datum = &caddx::parse::getbits( $msgb[5], '0' );
                    push( @msgdata, [ '5:0', 'Expander box tamper', $datum ] );
                    $datum = &caddx::parse::getbits( $msgb[5], '1' );
                    push( @msgdata, [ '5:1', 'Expander AC failure', $datum ] );
                    $datum = &caddx::parse::getbits( $msgb[5], '2' );
                    push( @msgdata, [ '5:2', 'Expander low battery', $datum ] );
                    $datum = &caddx::parse::getbits( $msgb[5], '3' );
                    push( @msgdata,
                        [ '5:3', 'Expander loss of supervision', $datum ] );
                    $datum = &caddx::parse::getbits( $msgb[5], '4' );
                    push(
                        @msgdata,
                        [
                            '5:4', 'Expander auxiliary output over current',
                            $datum
                        ]
                    );
                    $datum = &caddx::parse::getbits( $msgb[5], '5' );
                    push(
                        @msgdata,
                        [
                            '5:5', 'Auxiliary communication channel failure',
                            $datum
                        ]
                    );
                    $datum = &caddx::parse::getbits( $msgb[5], '6' );
                    push( @msgdata, [ '5:6', 'Expander bell fault', $datum ] );
                    $datum = &caddx::parse::getbits( $msgb[5], '7' );
                    push( @msgdata, [ '5:7', 'Reserved', $datum ] );
                    $datum = $msgb[6];
                    push( @msgdata, [ '6:', '', $datum ] );
                    $datum = &caddx::parse::getbits( $msgb[6], '0' );
                    push( @msgdata, [ '6:0', '6 digit PIN enabled', $datum ] );
                    $datum = &caddx::parse::getbits( $msgb[6], '1' );
                    push( @msgdata,
                        [ '6:1', 'Programming token in use', $datum ] );
                    $datum = &caddx::parse::getbits( $msgb[6], '2' );
                    push( @msgdata,
                        [ '6:2', 'PIN required for local download', $datum ] );
                    $datum = &caddx::parse::getbits( $msgb[6], '3' );
                    push( @msgdata,
                        [ '6:3', 'Global pulsing buzzer', $datum ] );
                    $datum = &caddx::parse::getbits( $msgb[6], '4' );
                    push( @msgdata, [ '6:4', 'Global Siren on', $datum ] );
                    $datum = &caddx::parse::getbits( $msgb[6], '5' );
                    push( @msgdata, [ '6:5', 'Global steady siren ', $datum ] );
                    $datum = &caddx::parse::getbits( $msgb[6], '6' );
                    push( @msgdata,
                        [ '6:6', 'Bus device has line seized', $datum ] );
                    $datum = &caddx::parse::getbits( $msgb[6], '7' );
                    push(
                        @msgdata,
                        [
                            '6:7', 'Bus device has requested sniff mode',
                            $datum
                        ]
                    );
                    $datum = $msgb[7];
                    push( @msgdata, [ '7:', '', $datum ] );
                    $datum = &caddx::parse::getbits( $msgb[7], '0' );
                    push( @msgdata, [ '7:0', 'Dynamic battery test', $datum ] );
                    $datum = &caddx::parse::getbits( $msgb[7], '1' );
                    push( @msgdata, [ '7:1', 'AC power on', $datum ] );
                    $datum = &caddx::parse::getbits( $msgb[7], '2' );
                    push( @msgdata, [ '7:2', 'Low battery memory', $datum ] );
                    $datum = &caddx::parse::getbits( $msgb[7], '3' );
                    push( @msgdata, [ '7:3', 'Ground fault memory', $datum ] );
                    $datum = &caddx::parse::getbits( $msgb[7], '4' );
                    push(
                        @msgdata,
                        [
                            '7:4', 'Fire alarm verification being timed',
                            $datum
                        ]
                    );
                    $datum = &caddx::parse::getbits( $msgb[7], '5' );
                    push( @msgdata, [ '7:5', 'Smoke power reset', $datum ] );
                    $datum = &caddx::parse::getbits( $msgb[7], '6' );
                    push( @msgdata,
                        [ '7:6', '50 Hz line power detected', $datum ] );
                    $datum = &caddx::parse::getbits( $msgb[7], '7' );
                    push(
                        @msgdata,
                        [
                            '7:7', 'Timing a high voltage battery charge',
                            $datum
                        ]
                    );
                    $datum = $msgb[8];
                    push( @msgdata, [ '8:', '', $datum ] );
                    $datum = &caddx::parse::getbits( $msgb[8], '0' );
                    push( @msgdata,
                        [ '8:0', 'Communication since last autotest', $datum ]
                    );
                    $datum = &caddx::parse::getbits( $msgb[8], '1' );
                    push( @msgdata,
                        [ '8:1', 'Power up delay in progress', $datum ] );
                    $datum = &caddx::parse::getbits( $msgb[8], '2' );
                    push( @msgdata, [ '8:2', 'Walk test mode', $datum ] );
                    $datum = &caddx::parse::getbits( $msgb[8], '3' );
                    push( @msgdata, [ '8:3', 'Loss of system time', $datum ] );
                    $datum = &caddx::parse::getbits( $msgb[8], '4' );
                    push( @msgdata, [ '8:4', 'Enroll requested', $datum ] );
                    $datum = &caddx::parse::getbits( $msgb[8], '5' );
                    push( @msgdata, [ '8:5', 'Test fixture mode', $datum ] );
                    $datum = &caddx::parse::getbits( $msgb[8], '6' );
                    push( @msgdata,
                        [ '8:6', 'Control shutdown mode', $datum ] );
                    $datum = &caddx::parse::getbits( $msgb[8], '7' );
                    push( @msgdata,
                        [ '8:7', 'Timing a cancel window', $datum ] );
                    $datum = $msgb[9];
                    push( @msgdata, [ '9:', '', $datum ] );
                    $datum = &caddx::parse::getbits( $msgb[9], '0' );
                    push( @msgdata, [ '9:0', 'reserved', $datum ] );
                    $datum = &caddx::parse::getbits( $msgb[9], '1' );
                    push( @msgdata, [ '9:1', 'reserved', $datum ] );
                    $datum = &caddx::parse::getbits( $msgb[9], '2' );
                    push( @msgdata, [ '9:2', 'reserved', $datum ] );
                    $datum = &caddx::parse::getbits( $msgb[9], '3' );
                    push( @msgdata, [ '9:3', 'reserved', $datum ] );
                    $datum = &caddx::parse::getbits( $msgb[9], '4' );
                    push( @msgdata, [ '9:4', 'reserved', $datum ] );
                    $datum = &caddx::parse::getbits( $msgb[9], '5' );
                    push( @msgdata, [ '9:5', 'reserved', $datum ] );
                    $datum = &caddx::parse::getbits( $msgb[9], '6' );
                    push( @msgdata, [ '9:6', 'reserved', $datum ] );
                    $datum = &caddx::parse::getbits( $msgb[9], '7' );
                    push( @msgdata,
                        [ '9:7', 'Call back in progress', $datum ] );
                    $datum = $msgb[10];
                    push( @msgdata, [ '10:', '', $datum ] );
                    $datum = &caddx::parse::getbits( $msgb[10], '0' );
                    push( @msgdata, [ '10:0', 'Phone line faulted', $datum ] );
                    $datum = &caddx::parse::getbits( $msgb[10], '1' );
                    push( @msgdata,
                        [ '10:1', 'Voltage present interrupt active', $datum ]
                    );
                    $datum = &caddx::parse::getbits( $msgb[10], '2' );
                    push( @msgdata,
                        [ '10:2', 'House phone off hook', $datum ] );
                    $datum = &caddx::parse::getbits( $msgb[10], '3' );
                    push( @msgdata,
                        [ '10:3', 'Phone line monitor enabled', $datum ] );
                    $datum = &caddx::parse::getbits( $msgb[10], '4' );
                    push( @msgdata, [ '10:4', 'Sniffing', $datum ] );
                    $datum = &caddx::parse::getbits( $msgb[10], '5' );
                    push( @msgdata,
                        [ '10:5', 'Last read was off hook', $datum ] );
                    $datum = &caddx::parse::getbits( $msgb[10], '6' );
                    push( @msgdata, [ '10:6', 'Listen in requested', $datum ] );
                    $datum = &caddx::parse::getbits( $msgb[10], '7' );
                    push( @msgdata, [ '10:7', 'Listen in trigger', $datum ] );
                    $datum = $msgb[11];
                    push( @msgdata, [ '11:', '', $datum ] );
                    $datum = &caddx::parse::getbits( $msgb[11], '0' );
                    push( @msgdata, [ '11:0', 'Valid partition 1', $datum ] );
                    $datum = &caddx::parse::getbits( $msgb[11], '1' );
                    push( @msgdata, [ '11:1', 'Valid partition 2', $datum ] );
                    $datum = &caddx::parse::getbits( $msgb[11], '2' );
                    push( @msgdata, [ '11:2', 'Valid partition 3', $datum ] );
                    $datum = &caddx::parse::getbits( $msgb[11], '3' );
                    push( @msgdata, [ '11:3', 'Valid partition 4', $datum ] );
                    $datum = &caddx::parse::getbits( $msgb[11], '4' );
                    push( @msgdata, [ '11:4', 'Valid partition 5', $datum ] );
                    $datum = &caddx::parse::getbits( $msgb[11], '5' );
                    push( @msgdata, [ '11:5', 'Valid partition 6', $datum ] );
                    $datum = &caddx::parse::getbits( $msgb[11], '6' );
                    push( @msgdata, [ '11:6', 'Valid partition 7', $datum ] );
                    $datum = &caddx::parse::getbits( $msgb[11], '7' );
                    push( @msgdata, [ '11:7', 'Valid partition 8', $datum ] );
                    $datum = $msgb[12];
                    push( @msgdata,
                        [ '12:', 'Communicator stack pointer', $datum ] );
                    $msghash{_parsed_} = \@msgdata;    # stash verbose parse
                    return \%msghash;    # send back a hash ref to all
                }
                ##################################################
                ##  Dynamically generated code to parse layout [09H]
                ##  DO NOT MODIFY THIS FILE! (look at caddx_build_parse.pl)
                ##################################################
                sub parse_09H {
                    my ($msg) = @_;
                    my (@msgb) = split( //, $msg );    # msgbytes
                    unshift( @msgb, "\x7e" );    #placeholder for 1-based array
                    my (@msgdata);
                    my (%msghash);
                    my ($datum);
                    foreach my $byte (@msgb) {
                        printf( "[%02x]", ord($byte) );
                    }
                    print "\n";
                    $datum = $msgb[1];
                    push( @msgdata, [ '1:', 'Message number', $datum ] );
                    $datum = $msgb[2];
                    push( @msgdata,
                        [ '2:', 'House code (0=house A)', $datum ] );
                    $datum = $msgb[3];
                    push( @msgdata, [ '3:', 'Unit code (0=unit 1)', $datum ] );
                    $datum = $msgb[4];
                    push(
                        @msgdata,
                        [
                            '4:', 'X-10 function code (see table that follows)',
                            $datum
                        ]
                    );
                    $msghash{_parsed_} = \@msgdata;    # stash verbose parse
                    return \%msghash;    # send back a hash ref to all
                }
                ##################################################
                ##  Dynamically generated code to parse layout [0AH]
                ##  DO NOT MODIFY THIS FILE! (look at caddx_build_parse.pl)
                ##################################################
                sub parse_0AH {
                    my ($msg) = @_;
                    my (@msgb) = split( //, $msg );    # msgbytes
                    unshift( @msgb, "\x7e" );    #placeholder for 1-based array
                    my (@msgdata);
                    my (%msghash);
                    my ($datum);
                    foreach my $byte (@msgb) {
                        printf( "[%02x]", ord($byte) );
                    }
                    print "\n";
                    $datum = $msgb[1];
                    push( @msgdata, [ '1:', 'Message number', $datum ] );
                    $datum = $msgb[2];
                    push( @msgdata,
                        [ '2:', 'Event number of this message', $datum ] );
                    $datum = $msgb[3];
                    push(
                        @msgdata,
                        [
                            '3:',
                            'Total log size (number of log entries allowed)',
                            $datum
                        ]
                    );
                    $datum = $msgb[4];
                    push( @msgdata, [ '4:', 'Event type', $datum ] );
                    $datum = &caddx::parse::getbits( $msgb[4], '0-6' );
                    push(
                        @msgdata,
                        [
                            '4:0-6',
                            'See type definitions in table that follows',
                            $datum
                        ]
                    );
                    $datum = &caddx::parse::getbits( $msgb[4], '7' );
                    push( @msgdata,
                        [ '4:7', 'Non-reporting event if not set', $datum ] );
                    $datum = $msgb[5];
                    push( @msgdata,
                        [ '5:', 'Zone / User / Device number', $datum ] );
                    $datum = $msgb[6];
                    push(
                        @msgdata,
                        [
                            '6:',
                            'Partition number (0=partition 1, if relevant)',
                            $datum
                        ]
                    );
                    $datum = $msgb[7];
                    push( @msgdata, [ '7:', 'Month (1-12)', $datum ] );
                    $datum = $msgb[8];
                    push( @msgdata, [ '8:', 'Day (1-31)', $datum ] );
                    $datum = $msgb[9];
                    push( @msgdata, [ '9:', 'Hour (0-23)', $datum ] );
                    $datum = $msgb[10];
                    push( @msgdata, [ '10:', 'Minute (0-59)', $datum ] );
                    $msghash{_parsed_} = \@msgdata;    # stash verbose parse
                    return \%msghash;    # send back a hash ref to all
                }
                ##################################################
                ##  Dynamically generated code to parse layout [0BH]
                ##  DO NOT MODIFY THIS FILE! (look at caddx_build_parse.pl)
                ##################################################
                sub parse_0BH {
                    my ($msg) = @_;
                    my (@msgb) = split( //, $msg );    # msgbytes
                    unshift( @msgb, "\x7e" );    #placeholder for 1-based array
                    my (@msgdata);
                    my (%msghash);
                    my ($datum);
                    foreach my $byte (@msgb) {
                        printf( "[%02x]", ord($byte) );
                    }
                    print "\n";
                    $datum = $msgb[1];
                    push( @msgdata, [ '1:', 'Message number', $datum ] );
                    $datum = $msgb[2];
                    push( @msgdata, [ '2:', 'Keypad address', $datum ] );
                    $datum = $msgb[3];
                    push( @msgdata, [ '3:', 'Key value', $datum ] );
                    $msghash{_parsed_} = \@msgdata;    # stash verbose parse
                    return \%msghash;    # send back a hash ref to all
                }
                ##################################################
                ##  Dynamically generated code to parse layout [10H]
                ##  DO NOT MODIFY THIS FILE! (look at caddx_build_parse.pl)
                ##################################################
                sub parse_10H {
                    my ($msg) = @_;
                    my (@msgb) = split( //, $msg );    # msgbytes
                    unshift( @msgb, "\x7e" );    #placeholder for 1-based array
                    my (@msgdata);
                    my (%msghash);
                    my ($datum);
                    foreach my $byte (@msgb) {
                        printf( "[%02x]", ord($byte) );
                    }
                    print "\n";
                    $datum = $msgb[1];
                    push( @msgdata, [ '1:', 'Message number', $datum ] );
                    $datum = $msgb[2];
                    push( @msgdata, [ '2:', 'Device’s buss address', $datum ] );
                    $datum = $msgb[3];
                    push( @msgdata,
                        [ '3:', 'Upper logical location / offset', $datum ] );
                    $datum = &caddx::parse::getbits( $msgb[3], '0-3' );
                    push( @msgdata,
                        [ '3:0-3', 'Bits 8-11 of logical location', $datum ] );
                    $datum = &caddx::parse::getbits( $msgb[3], '4' );
                    push( @msgdata,
                        [ '3:4', 'Segment size (0=byte, 1=nibble)', $datum ] );
                    $datum = &caddx::parse::getbits( $msgb[3], '5' );
                    push( @msgdata, [ '3:5', 'Must be 0', $datum ] );
                    $datum = &caddx::parse::getbits( $msgb[3], '6' );
                    push( @msgdata,
                        [ '3:6', 'Segment offset (0-none, 1=8 bytes)', $datum ]
                    );
                    $datum = &caddx::parse::getbits( $msgb[3], '7' );
                    push( @msgdata, [ '3:7', 'Must be 0', $datum ] );
                    $datum = $msgb[4];
                    push( @msgdata,
                        [ '4:', 'Bits 0-7 of logical location', $datum ] );
                    $datum = $msgb[5];
                    push( @msgdata,
                        [ '5:', 'Location length / data type', $datum ] );
                    $datum = &caddx::parse::getbits( $msgb[5], '0-4' );
                    push(
                        @msgdata,
                        [
                            '5:0-4',
                            'Number of segments in location (0=1 segment)',
                            $datum
                        ]
                    );
                    $datum = &caddx::parse::getbits( $msgb[5], '5-7' );
                    push(
                        @msgdata,
                        [
                            '5:5-7',
                            'Data type : 0=Binary,1=Decimal,2=Hex,3=Asc',
                            $datum
                        ]
                    );
                    $datum = $msgb[6];
                    push( @msgdata, [ '6:', 'Data byte ', $datum ] );
                    $datum = $msgb[7];
                    push( @msgdata, [ '7:', 'Data byte ', $datum ] );
                    $datum = $msgb[8];
                    push( @msgdata, [ '8:', 'Data byte ', $datum ] );
                    $datum = $msgb[9];
                    push( @msgdata, [ '9:', 'Data byte ', $datum ] );
                    $datum = $msgb[10];
                    push( @msgdata, [ '10:', 'Data byte ', $datum ] );
                    $datum = $msgb[11];
                    push( @msgdata, [ '11:', 'Data byte ', $datum ] );
                    $datum = $msgb[12];
                    push( @msgdata, [ '12:', 'Data byte ', $datum ] );
                    $datum = $msgb[13];
                    push( @msgdata, [ '13:', 'Data byte ', $datum ] );
                    $msghash{_parsed_} = \@msgdata;    # stash verbose parse
                    return \%msghash;    # send back a hash ref to all
                }
                ##################################################
                ##  Dynamically generated code to parse layout [12H]
                ##  DO NOT MODIFY THIS FILE! (look at caddx_build_parse.pl)
                ##################################################
                sub parse_12H {
                    my ($msg) = @_;
                    my (@msgb) = split( //, $msg );    # msgbytes
                    unshift( @msgb, "\x7e" );    #placeholder for 1-based array
                    my (@msgdata);
                    my (%msghash);
                    my ($datum);
                    foreach my $byte (@msgb) {
                        printf( "[%02x]", ord($byte) );
                    }
                    print "\n";
                    $datum = $msgb[1];
                    push( @msgdata, [ '1:', 'Message number', $datum ] );
                    $datum = $msgb[2];
                    push( @msgdata,
                        [ '2:', 'User Number (1=user 1)', $datum ] );
                    $datum = $msgb[3];
                    push( @msgdata, [ '3:', 'PIN digits 1 & 2', $datum ] );
                    $datum = &caddx::parse::getbits( $msgb[3], '0-3' );
                    push( @msgdata, [ '3:0-3', 'PIN digit 1', $datum ] );
                    $datum = &caddx::parse::getbits( $msgb[3], '4-7' );
                    push( @msgdata, [ '3:4-7', 'PIN digit 2', $datum ] );
                    $datum = $msgb[4];
                    push( @msgdata, [ '4:', 'PIN digits 3 & 4', $datum ] );
                    $datum = &caddx::parse::getbits( $msgb[4], '0-3' );
                    push( @msgdata, [ '4:0-3', 'PIN digit 3', $datum ] );
                    $datum = &caddx::parse::getbits( $msgb[4], '4-7' );
                    push( @msgdata, [ '4:4-7', 'PIN digit 4', $datum ] );
                    $datum = $msgb[5];
                    push( @msgdata, [ '5:', 'PIN digits 5 & 6', $datum ] );
                    $datum = &caddx::parse::getbits( $msgb[5], '0-3' );
                    push(
                        @msgdata,
                        [
                            '5:0-3', 'PIN digit 5 (pad with 0 if 4 digit PIN)',
                            $datum
                        ]
                    );
                    $datum = &caddx::parse::getbits( $msgb[5], '4-7' );
                    push(
                        @msgdata,
                        [
                            '5:4-7', 'PIN digit 6 (pad with 0 if 4 digit PIN)',
                            $datum
                        ]
                    );
                    $datum = $msgb[6];
                    push( @msgdata,
                        [ '6:', 'Authority flags (if bit 7 is clear)', $datum ]
                    );
                    $datum = &caddx::parse::getbits( $msgb[6], '0' );
                    push( @msgdata, [ '6:0', 'Reserved', $datum ] );
                    $datum = &caddx::parse::getbits( $msgb[6], '1' );
                    push( @msgdata, [ '6:1', 'Arm only', $datum ] );
                    $datum = &caddx::parse::getbits( $msgb[6], '2' );
                    push( @msgdata,
                        [ '6:2', 'Arm only (during close window) ', $datum ] );
                    $datum = &caddx::parse::getbits( $msgb[6], '3' );
                    push( @msgdata, [ '6:3', 'Master / program ', $datum ] );
                    $datum = &caddx::parse::getbits( $msgb[6], '4' );
                    push( @msgdata, [ '6:4', 'Arm / disarm', $datum ] );
                    $datum = &caddx::parse::getbits( $msgb[6], '5' );
                    push( @msgdata, [ '6:5', 'Bypass enable', $datum ] );
                    $datum = &caddx::parse::getbits( $msgb[6], '6' );
                    push( @msgdata,
                        [ '6:6', 'Open / close report enable', $datum ] );
                    $datum = &caddx::parse::getbits( $msgb[6], '7' );
                    push( @msgdata, [ '6:7', 'Must be a 0', $datum ] );
                    $datum = $msgb[6];
                    push( @msgdata,
                        [ '6:', 'Authority flags (if bit 7 is set)', $datum ] );
                    $datum = &caddx::parse::getbits( $msgb[6], '0' );
                    push( @msgdata, [ '6:0', 'Output 1 enable', $datum ] );
                    $datum = &caddx::parse::getbits( $msgb[6], '1' );
                    push( @msgdata, [ '6:1', 'Output 2 enable', $datum ] );
                    $datum = &caddx::parse::getbits( $msgb[6], '2' );
                    push( @msgdata, [ '6:2', 'Output 3 enable', $datum ] );
                    $datum = &caddx::parse::getbits( $msgb[6], '3' );
                    push( @msgdata, [ '6:3', 'Output 4 enable', $datum ] );
                    $datum = &caddx::parse::getbits( $msgb[6], '4' );
                    push( @msgdata, [ '6:4', 'Arm / disarm', $datum ] );
                    $datum = &caddx::parse::getbits( $msgb[6], '5' );
                    push( @msgdata, [ '6:5', 'Bypass enable', $datum ] );
                    $datum = &caddx::parse::getbits( $msgb[6], '6' );
                    push( @msgdata,
                        [ '6:6', 'Open / close report enable', $datum ] );
                    $datum = &caddx::parse::getbits( $msgb[6], '7' );
                    push( @msgdata, [ '6:7', 'Must be a 1', $datum ] );
                    $datum = $msgb[7];
                    push( @msgdata,
                        [ '7:', 'Authorized partition(s) mask', $datum ] );
                    $datum = &caddx::parse::getbits( $msgb[7], '0' );
                    push( @msgdata,
                        [ '7:0', 'Authorized for partition 1', $datum ] );
                    $datum = &caddx::parse::getbits( $msgb[7], '1' );
                    push( @msgdata,
                        [ '7:1', 'Authorized for partition 2', $datum ] );
                    $datum = &caddx::parse::getbits( $msgb[7], '2' );
                    push( @msgdata,
                        [ '7:2', 'Authorized for partition 3', $datum ] );
                    $datum = &caddx::parse::getbits( $msgb[7], '3' );
                    push( @msgdata,
                        [ '7:3', 'Authorized for partition 4', $datum ] );
                    $datum = &caddx::parse::getbits( $msgb[7], '4' );
                    push( @msgdata,
                        [ '7:4', 'Authorized for partition 5', $datum ] );
                    $datum = &caddx::parse::getbits( $msgb[7], '5' );
                    push( @msgdata,
                        [ '7:5', 'Authorized for partition 6', $datum ] );
                    $datum = &caddx::parse::getbits( $msgb[7], '6' );
                    push( @msgdata,
                        [ '7:6', 'Authorized for partition 7', $datum ] );
                    $datum = &caddx::parse::getbits( $msgb[7], '7' );
                    push( @msgdata,
                        [ '7:7', 'Authorized for partition 8', $datum ] );
                    $msghash{_parsed_} = \@msgdata;    # stash verbose parse
                    return \%msghash;    # send back a hash ref to all
                }
                ##################################################
                ##  Dynamically generated code to parse layout [1CH]
                ##  DO NOT MODIFY THIS FILE! (look at caddx_build_parse.pl)
                ##################################################
                sub parse_1CH {
                    my ($msg) = @_;
                    my (@msgb) = split( //, $msg );    # msgbytes
                    unshift( @msgb, "\x7e" );    #placeholder for 1-based array
                    my (@msgdata);
                    my (%msghash);
                    my ($datum);
                    foreach my $byte (@msgb) {
                        printf( "[%02x]", ord($byte) );
                    }
                    print "\n";
                    $datum = $msgb[1];
                    push( @msgdata, [ '1:', 'Message Number', $datum ] );
                    $msghash{_parsed_} = \@msgdata;    # stash verbose parse
                    return \%msghash;    # send back a hash ref to all
                }
                ##################################################
                ##  Dynamically generated code to parse layout [1DH]
                ##  DO NOT MODIFY THIS FILE! (look at caddx_build_parse.pl)
                ##################################################
                sub parse_1DH {
                    my ($msg) = @_;
                    my (@msgb) = split( //, $msg );    # msgbytes
                    unshift( @msgb, "\x7e" );    #placeholder for 1-based array
                    my (@msgdata);
                    my (%msghash);
                    my ($datum);
                    foreach my $byte (@msgb) {
                        printf( "[%02x]", ord($byte) );
                    }
                    print "\n";
                    $datum = $msgb[1];
                    push( @msgdata, [ '1:', 'Message Number', $datum ] );
                    $msghash{_parsed_} = \@msgdata;    # stash verbose parse
                    return \%msghash;    # send back a hash ref to all
                }
                ##################################################
                ##  Dynamically generated code to parse layout [1EH]
                ##  DO NOT MODIFY THIS FILE! (look at caddx_build_parse.pl)
                ##################################################
                sub parse_1EH {
                    my ($msg) = @_;
                    my (@msgb) = split( //, $msg );    # msgbytes
                    unshift( @msgb, "\x7e" );    #placeholder for 1-based array
                    my (@msgdata);
                    my (%msghash);
                    my ($datum);
                    foreach my $byte (@msgb) {
                        printf( "[%02x]", ord($byte) );
                    }
                    print "\n";
                    $datum = $msgb[1];
                    push( @msgdata, [ '1:', 'Message Number', $datum ] );
                    $msghash{_parsed_} = \@msgdata;    # stash verbose parse
                    return \%msghash;    # send back a hash ref to all
                }
                ##################################################
                ##  Dynamically generated code to parse layout [1FH]
                ##  DO NOT MODIFY THIS FILE! (look at caddx_build_parse.pl)
                ##################################################
                sub parse_1FH {
                    my ($msg) = @_;
                    my (@msgb) = split( //, $msg );    # msgbytes
                    unshift( @msgb, "\x7e" );    #placeholder for 1-based array
                    my (@msgdata);
                    my (%msghash);
                    my ($datum);
                    foreach my $byte (@msgb) {
                        printf( "[%02x]", ord($byte) );
                    }
                    print "\n";
                    $datum = $msgb[1];
                    push( @msgdata, [ '1:', 'Message Number', $datum ] );
                    $msghash{_parsed_} = \@msgdata;    # stash verbose parse
                    return \%msghash;    # send back a hash ref to all
                }
                ##################################################
                ##  Dynamically generated code to parse layout [PSNAP]
                ##  DO NOT MODIFY THIS FILE! (look at caddx_build_parse.pl)
                ##################################################
                sub parse_PSNAP {
                    my ($msg) = @_;
                    my (@msgb) = split( //, $msg );    # msgbytes
                    unshift( @msgb, "\x7e" );    #placeholder for 1-based array
                    my (@msgdata);
                    my (%msghash);
                    my ($datum);
                    foreach my $byte (@msgb) {
                        printf( "[%02x]", ord($byte) );
                    }
                    print "\n";
                    $datum = $msgb[1];
                    push(
                        @msgdata,
                        [
                            '1:', 'Partition snapshot layout (msg 07h detail)',
                            $datum
                        ]
                    );
                    $datum = &caddx::parse::getbits( $msgb[1], '0' );
                    push( @msgdata,
                        [ '1:0', 'Partition {valid} partition', $datum ] );
                    $msghash{valid} = $datum;
                    $datum = &caddx::parse::getbits( $msgb[1], '1' );
                    push( @msgdata, [ '1:1', 'Partition {ready}', $datum ] );
                    $msghash{ready} = $datum;
                    $datum = &caddx::parse::getbits( $msgb[1], '2' );
                    push( @msgdata, [ '1:2', 'Partition {armed}', $datum ] );
                    $msghash{armed} = $datum;
                    $datum = &caddx::parse::getbits( $msgb[1], '3' );
                    push( @msgdata,
                        [ '1:3', 'Partition {stay} mode', $datum ] );
                    $msghash{stay} = $datum;
                    $datum = &caddx::parse::getbits( $msgb[1], '4' );
                    push( @msgdata,
                        [ '1:4', 'Partition {chime} mode', $datum ] );
                    $msghash{chime} = $datum;
                    $datum = &caddx::parse::getbits( $msgb[1], '5' );
                    push( @msgdata,
                        [ '1:5', 'Partition  {any entry} delay', $datum ] );
                    $datum = &caddx::parse::getbits( $msgb[1], '6' );
                    push( @msgdata,
                        [ '1:6', 'Partition {any exit} delay', $datum ] );
                    $datum = &caddx::parse::getbits( $msgb[1], '7' );
                    push( @msgdata,
                        [ '1:7', 'Partition {previous alarm}', $datum ] );
                    $msghash{_parsed_} = \@msgdata;    # stash verbose parse
                    return \%msghash;    # send back a hash ref to all
                }
                ##################################################
                ##  Dynamically generated code to parse layout [ZSNAP]
                ##  DO NOT MODIFY THIS FILE! (look at caddx_build_parse.pl)
                ##################################################
                sub parse_ZSNAP {
                    my ($msg) = @_;
                    my (@msgb) = split( //, $msg );    # msgbytes
                    unshift( @msgb, "\x7e" );    #placeholder for 1-based array
                    my (@msgdata);
                    my (%msghash);
                    my ($datum);
                    foreach my $byte (@msgb) {
                        printf( "[%02x]", ord($byte) );
                    }
                    print "\n";
                    $datum = $msgb[1];
                    push(
                        @msgdata,
                        [
                            '1:', 'Zone snapshot nibble (msg 05h detail)',
                            $datum
                        ]
                    );
                    $datum = &caddx::parse::getbits( $msgb[1], '0' );
                    push( @msgdata,
                        [ '1:0', 'Zone {faulted} (or delayed trip)', $datum ] );
                    $msghash{faulted} = $datum;
                    $datum = &caddx::parse::getbits( $msgb[1], '1' );
                    push( @msgdata,
                        [ '1:1', 'Zone {bypassed} (or inhibited)', $datum ] );
                    $msghash{bypassed} = $datum;
                    $datum = &caddx::parse::getbits( $msgb[1], '2' );
                    push(
                        @msgdata,
                        [
                            '1:2',
                            'Zone {trouble} (tamper, low battery, or lost)',
                            $datum
                        ]
                    );
                    $msghash{trouble} = $datum;
                    $datum = &caddx::parse::getbits( $msgb[1], '3' );
                    push( @msgdata, [ '1:3', 'Zone {alarm_memory}', $datum ] );
                    $msghash{alarm_memory} = $datum;
                    $msghash{_parsed_}     = \@msgdata;    # stash verbose parse
                    return \%msghash;    # send back a hash ref to all
                }

                sub BEGIN {
                    $laycode{'01H'}   = \&parse_01H;
                    $laycode{'03H'}   = \&parse_03H;
                    $laycode{'04H'}   = \&parse_04H;
                    $laycode{'05H'}   = \&parse_05H;
                    $laycode{'06H'}   = \&parse_06H;
                    $laycode{'07H'}   = \&parse_07H;
                    $laycode{'08H'}   = \&parse_08H;
                    $laycode{'09H'}   = \&parse_09H;
                    $laycode{'0AH'}   = \&parse_0AH;
                    $laycode{'0BH'}   = \&parse_0BH;
                    $laycode{'10H'}   = \&parse_10H;
                    $laycode{'12H'}   = \&parse_12H;
                    $laycode{'1CH'}   = \&parse_1CH;
                    $laycode{'1DH'}   = \&parse_1DH;
                    $laycode{'1EH'}   = \&parse_1EH;
                    $laycode{'1FH'}   = \&parse_1FH;
                    $laycode{'PSNAP'} = \&parse_PSNAP;
                    $laycode{'ZSNAP'} = \&parse_ZSNAP;
                }

                sub getbits {
                    my ( $msg, $bits ) = @_;

                    my $debug = 0;
                    $msg = ord($msg);
                    my $orig_msg = $msg;
                    if ( $bits =~ /(\d+)-?(\d*)/ ) {
                        my $startb = $1;
                        my $endb   = $2;
                        $endb = $startb
                          unless $endb =~ /\d/;    # end is opt, dflt to start
                        $msg = $msg >> $startb;
                        my $bitcount = ( $endb - $startb ) + 1;
                        ## $debug && print "getbits: startb: $startb endb: $endb count:$bitcount\n";
                        my $mask;
                        while ( $bitcount-- > 0 ) {
                            $mask = $mask << 1;    # left shift prior mask
                            $mask = $mask | 1;     # turn on a new bit
                        }
                        my $rc = ( $msg & $mask );
                        $debug
                          && printf(
                            "getbits msg:[%02x] bits:[%s], gave:[%s]\n",
                            $orig_msg, $bits, $rc );
                        return ($rc);
                    }
                    return (-1);

                }
                1;
