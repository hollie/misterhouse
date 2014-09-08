# Category=Automation

#@ This Code talks to a SitePlayer Processor
#Info on siteplayer available at http://www.siteplayer.com

#
# Many portions of this code stolen from /examples/*socket*
#

my @sendata;
my $sendstring;
my $sendstring2;
my $temp;
my @tempa;
my $tempb;
my @DData;
my $i;

#Info on the MisterHouse Computer
#This will be sent to the siteplayer to initialize it's UDP bytes
#You MUST ALSO enable UDP via either serial or http - write a 1 to 0xFF20

#my @Mac = (0x00,0x05,0x5D,0x51,0x0C,0xD9);
my @Mac = ( 0x0005, 0x5D51, 0x0CD9 );

#my @IP = 192.168.0.6 = (192,168,0,6)=(C0,A8,0,6)
my @IP = ( 0xC0A8, 0x0006 );

# Port 30001 = 0x7531 swapping endians..........0x3175
my @Port = (0x3175);

#What is the first register you want from the siteplayer
# 0xFF00 swapping endians.................0x00FF
#my @SPMem = (0x00FF);

# 0x0000 swapping endians.................0x0000
my @SPMem = (0x0000);

#How many registers?  for 10
#000A swapping endians.............0x0A00
my $SPCnt = 0x0A00;

#First Part There are 17 Registers in this packet, 8 bit 1's Compliment of 15 is 238
#17 = 11  238 = EE

#Last Part, the UDP packet MUST end with 2 00 bytes.

my @SP_UDP = ( 0x11EE, 0xD002, @Mac, @IP, @Port, @SPMem, $SPCnt, 0x00, 0x00 );
my $SP_UDP_Init = pack( 'n*', @SP_UDP );

#Define the IP and UPD port for siteplayer #1
#this is to allow sending data TO siteplayer
my $siteplayer1_address = '192.168.0.60:26482';
$to_siteplayer1 =
  new Socket_Item( undef, undef, $siteplayer1_address, 'siteplay', 'udp',
    'rawout' );

# Check for data FROM siteplayer #1
# Add this  mh.private.ini, so the server is created on startup:
# 	server_siteplayer1_port=30001
# 	server_siteplayer1_echo=0
# 	server_siteplayer1_protocol=udp
# 	server_siteplayer1_datatype=raw

$from_siteplayer1 = new Socket_Item( undef, undef, 'server_siteplayer1' );
if ( $temp = said $from_siteplayer1) {
    @DData = split "", $temp;

    for ( $i = 0; $i < 10; $i++ ) {
        @tempa[$i] = unpack( 'C*', @DData[$i] );
    }

    print_log
      "From Siteplayer1 @tempa[0] @tempa[1] @tempa[2] @tempa[3] @tempa[4] @tempa[5] @tempa[6] @tempa[7] @tempa[8] @tempa[9] @tempa[10]";

}

$SPb0 = new Generic_Item;
$SPb1 = new Generic_Item;
$SPb2 = new Generic_Item;
$SPb3 = new Generic_Item;
$SPb4 = new Generic_Item;
$SPb5 = new Generic_Item;
$SPb6 = new Generic_Item;
$SPb7 = new Generic_Item;

# Meddle with Site Player Bit 3
# This bit is the RED LED on the development board
#

$v_SPb3 = new Voice_Cmd("Site Player bit 3 [on,off]");

if ( $state = said $v_SPb3) {
    set $SPb3 'on'  if ( $state eq 'on' );
    set $SPb3 'off' if ( $state eq 'off' );
}

if ( $state = said $SPb3) {
    @sendata = ( 0x01FE, 0x14FF, 0x0000, 0x0000 ) if state $SPb3 eq "on";
    @sendata = ( 0x01FE, 0x14FF, 0x0100, 0x0000 ) if state $SPb3 eq "off";
    $sendstring = pack( 'n*', @sendata );
    set $to_siteplayer1 $sendstring;
    print_log "Sent to Bit3 $sendstring";
}

# Open the port, test drive it and such

# Write 0 to the I/O Register FF00
@sendata = ( 0x01FE, 0x00FF, 0x0000, 0x0000 );
$sendstring = pack( 'n*', @sendata );

# Write 255 to the I/O Register FF00
@sendata = ( 0x01FE, 0x00FF, 0xFF00, 0x0000 );
$sendstring2 = pack( 'n*', @sendata );

$v_siteplayer = new Voice_Cmd("Siteplayer UDP socket [start,stop,on,off,init]");

if ( $state = said $v_siteplayer) {
    print_log "Running client test $state";
    if ( $state eq 'start' ) {
        unless ( active $to_siteplayer1) {
            print_log "Start a connection to $siteplayer1_address";
            start $to_siteplayer1;
        }

    }
    elsif ( $state eq 'stop' ) {
        print_log "closing $to_siteplayer1";
        stop $to_siteplayer1;
    }
    elsif ( $state eq 'on' ) {
        set $to_siteplayer1 $sendstring;
        print_log "Sent $sendstring";
    }

    elsif ( $state eq 'off' ) {
        set $to_siteplayer1 $sendstring2;
        print_log "Sent $sendstring2";
    }

    elsif ( $state eq 'init' ) {
        set $to_siteplayer1 $SP_UDP_Init;
        print_log "Sent @SP_UDP";
    }

    else {
        print_log "socket test $state is not implemented";
    }
}

