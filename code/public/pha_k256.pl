
=begin comment 

From Lincoln Foreman on 07/2003

I have been playing around with several kits I got from Peter Anderson
(http://www.phanderson.com) that will read upto 256 DS1820 1-wire devices in addition
to 16 analog/digital I/Os as well.  $50 from http://www.phanderson.com/t64.html
I finally get a bit of perl together to
log the dat within MH and save it to disk.  The code is a bit verbose and long
but I cannot always count on the call to the serial port to report back a
reading corresponding to the channel I requested (thus I have to check each
I/O write/read for the channel being returned).  From here, I would like to
use something like rrd to graph the data and post it on my website.  These
data are part of my attic temperature monitoring work to track improvements to
my overall electrical usage as I reduce the heat gain in the summer to my
attic.  -Lincoln

=cut

my @outData;
my $prntFlg;

$serial_out = new Serial_Item( undef, undef, 'serial1' );

set $serial_out "T000" if $New_Minute;
set $serial_out "A0"   if new_second 24;
set $serial_out "A1"   if new_second 28;
set $serial_out "A2"   if new_second 32;
set $serial_out "A3"   if new_second 36;
set $serial_out "A4"   if new_second 40;
set $serial_out "A5"   if new_second 44;

if ( my $temperature = said $serial_out) {
    if ( my ( $port, $temp ) = $temperature =~ /(\S+) (\S+)/ ) {

        #print_log "port is: $port\n";
        if ( $port =~ /T000/ ) {
            print_log "Emptying out outData array to accept new cycle of obs";
            $#outData = -1;    #empty array to get fresh data;
            $prntFlg  = 1;
            $temp =
              round( $temp * 9 / 5 + 32, 2 );    #DS1820 one wire temp sensor;
            @outData[0] = $temp;

            #print_log "Serial data T000 received from array outData[0] as $outData[0]";
        }
        elsif ( $port =~ /A0/ ) {
            $temp = round( $temp / 4096 * 5 * 2, 2 );    #board vdc supply
            @outData[1] = $temp;
        }
        elsif ( $port =~ /A1/ ) {
            $temp = round( $temp / 4096 * 5, 2 );        # CdS voltage;
            @outData[2] = $temp;
        }
        elsif ( $port =~ /A2/ ) {
            $temp = round( $temp / 4096 * 5 * 100, 2 );   # LM34 Temp sensor oF;
            @outData[3] = $temp;
        }
        elsif ( $port =~ /A3/ ) {
            $temp = round( $temp / 4096 * 5 * 100, 2 );   # LM34 Temp sensor oF;
            @outData[4] = $temp;
        }
        elsif ( $port =~ /A4/ ) {
            $temp = round( $temp / 4096 * 5 * 100, 2 );   # LM34 Temp sensor oF;
            @outData[5] = $temp;
        }
        elsif ( $port =~ /A5/ ) {
            $temp = round( $temp / 4096 * 5 * 100, 2 );   # LM34 Temp sensor oF;
            @outData[6] = $temp;
        }

        #logit("c:/misterhouse/mh/data/logs/pha_serial1.$Year_Month_Now.log","$port $temp");
        #print_log "Serial data temperature received as $port $temp";
        print_log "outData array contains following observations: @outData";
    }
}

if ( $#outData + 1 == 7 && $prntFlg == 1 ) {
    print_log "Printing all observations to file seria1_Obs";
    logit( "c:/misterhouse/mh/data/logs/serial1_Obs.$Year_Month_Now.log",
        "$Year_Month_Now @outData" );
    $prntFlg =
      0;   # prevents multiple writes to file with same array contents (a hack);
}

