#$Id$

=head1 DESCRIPTION

Module to interface with the little froggy named Rita from the company FroggyHome.

This device shaped like a frog, will gather interior temperature, pressure and humidity.
The company is based in Europe (France), but do ship in North America, at least
they did ship in my little town in Canada

To see more information about it, please visit http://www.froggyhome.com

I like to thanks support people who were kind to send me the protocol
to write the module, especially Philippe Monceyron.

=head1 FACTS 

This device use serial port and operate at 300 bauds, the module
will provide new measurement every minute.  It can't produce at a faster rate.

Here's info from their website

Rita is very nice, but she is very hard working and full of fight, imagine,
every 6.5 seconds she measures the absolute pressure, air humidity and air
temperature, that 8 times one after the other and finally calculates the
average and (ouf ! ! !) waits for the request of your PC to transmit the
result, after what she restarts for 8 measurements of the 3 data.

It took about 2 minutes after mh is started to get the 1st data. the first minute
initialize the devices, and then we need 1 more minute to get the data

It is very easy to use. Just define 2 parameters in mh.ini.
See the examples on how to gather data

The device will return 4 value, from a call to GetData

Temperature, pressure, humidity and time.
The time value is the time when the data was retrieve from the frog not the
time you ask the data.

To get a good accuracy on pressure, you have to provide an altitude parameter.
This will need to be fine tune, to get a value similar to where you live.
Note, the value is in meter, so 1 feet is about .3048 meter.

=head1 .INI PARAMETERS

 FroggyRita_serial_port=/dev/ttyM7              # serial port
 FroggyRita_altitude=450                        # altitude in meters (feet*.3048)

=head1 EXAMPLES

 # Category = Froggy
 $v_Froggy = new FroggyRita;
 my ( $RitaTemp, $RitaPres, $RitaHum, $RitaTime );

 # get data every 5 minutes
 if ( new_minute 5 ) {
     my ( $RitaTemp, $RitaPres, $RitaHum, $RitaTime ) = $v_Froggy->GetData;
 }

=cut
use strict;

package FroggyRita;
use POSIX;

@FroggyRita::ISA = ('Generic_Item');

# variable definition
my $FroggyFD;    # port file descriptor
my ( $Word1, $Word2, $Word3, $Word4 );
my ( $C1, $C2, $C3, $C4, $C5, $C6 );
my ( $NbBits, $Rs, $Rp );
my ( $Temp, $Pres, $Hum, $TimeStamp );
my $HaveIdent = 0;
my $BadData;
my $Wait4Reply = 15;    #waiting time before fetching data on port after sending a command

# The only call from user space to get data
sub GetData {
   return ( $Temp, $Pres, $Hum, $TimeStamp );
}

sub AskData {

   # ask Froggy for new data (identication/sensor) every minute we send a command
   # G0047Z  Identification
   # G0046Z  data
   if ($main::New_Minute) {
      if ( $HaveIdent and $BadData < 3 ) {
         &main::print_log("FroggyRita.pm send G0146Z") if $main::Debug{froggyrita};
         $main::Serial_Ports{$FroggyFD}{object}->write("G0146Z");
      }
      else {
         &main::print_log("FroggyRita.pm send G0047Z") if $main::Debug{froggyrita};
         &main::print_log("FroggyRita.pm reinit froggy device  with G0047Z") if ( $BadData >= 3 );
         $BadData = 0;
         $main::Serial_Ports{$FroggyFD}{object}->write("G0047Z");
      }

   }

   # every minute and $Wait4Reply seconds, we read the answer back from froggy
   if ( $main::Second == $Wait4Reply & $main::New_Second ) {
      $::Serial_Ports{$FroggyFD}{data} = "";
      &::check_for_generic_serial_data($FroggyFD) if $::Serial_Ports{$FroggyFD}{object};
      my $Data = $::Serial_Ports{$FroggyFD}{data};

      if ( $Data =~ /^G.*Z/ ) {
         &main::print_log("FroggyRita.pm data received from device [$Data]") if $main::Debug{froggyrita};

         if ($HaveIdent) {    # deal with "01" command
            CalcData($Data);
         }
         else {    # deal with "00" command (identification)
            CheckIdentification($Data);
            &::logit( "$::config_parms{data_dir}/logs/$FroggyFD.$::Year_Month_Now.log", "Device $FroggyFD Initialized" ) if ($HaveIdent);
            &::logit( "$::config_parms{data_dir}/logs/$FroggyFD.$::Year_Month_Now.log", "Device $FroggyFD Reinitialized (bad data)" ) if ( $BadData > 0 );
         }

      }
      else {

         # bad data can occurs if we get data between 0 and 60 seconds after start
         my $timestamp = $main::Time_Date;
         $BadData++;
         &main::print_log( "FroggyRita.pm $timestamp : Invalid data received from Froggy [$Data] count=$BadData" ) if ( ( $Main::Time_Startup_time + 60 ) < time() );
         &::logit( "$::config_parms{data_dir}/logs/$FroggyFD.$::Year_Month_Now.log", "$timestamp : Invalid data received from Froggy device [$Data]" );
      }
   }

}

# initialize port
sub serial_startup {
   my ($instance) = @_;
   $FroggyFD = $instance;
   my $port = $::config_parms{ $FroggyFD . "_serial_port" };
   my $speed = 300;
   if ( &::serial_port_create( $FroggyFD, $port, $speed, 'none', 'raw' ) ) {
      init( $::Serial_Ports{$FroggyFD}{object} );
      &main::print_log("FroggyRita.pm initialized $FroggyFD on port $port at $speed baud") if $main::Debug{froggyrita};
      &::logit( "$::config_parms{data_dir}/logs/$FroggyFD.$::Year_Month_Now.log", "Initializing $FroggyFD on port $port at $speed baud" );
      &::MainLoop_pre_add_hook( \&FroggyRita::AskData, 1 );
   }
}

sub new {
   my ($class) = @_;
   my $self = {};
   $$self{state} = '';
   bless $self, $class;
   return $self;
}

# if we receive data from sensor, we calculate the value
sub CalcData {

   my ( $D1, $D2, $DT );
   my ($Hmeasure);
   my $Data = shift;
   &main::print_log("FroggyRita.pm CalcData Entering [$Data]") if $main::Debug{froggyrita};

   # validate identity string
   if ( CheckSum($Data) != 0 ) {
      &main::print_log( "FroggyRita.pm: checksum incorrect, probably invalid FroggyRita Data [$Data]" );
      return;
   }

   my $SensorStatus = substr( $Data, 3, 2 );
   if ( $SensorStatus ne "00" ) {
      &main::print_log("FroggyRita.pm: CalcData Error code sensor 0");
      return;
   }
   $SensorStatus = substr( $Data, 13, 2 );

   if ( $SensorStatus ne "00" ) {
      &main::print_log("FroggyRita.pm: CalcData Error code sensor 1");
      return;
   }

   # get rid of G00 at the beginning
   # $Data = substr( $Data, 3 );
   $D1       = Hex2Dec( substr( $Data, 5,  4 ) );
   $D2       = Hex2Dec( substr( $Data, 9,  4 ) );
   $Hmeasure = Hex2Dec( substr( $Data, 15, 4 ) );

   my $UT1 = 8 * $C5 + 20224;
   if ( $D2 >= $UT1 ) {
      $DT   = $D2 - $UT1;
      $Temp = ( 200 + $DT * ( $C6 + 50 ) / 1024 ) / 10;
   }
   else {
      $DT   = ( $D2 - $UT1 ) - ( ( ( $D2 - $UT1 ) / 128 ) * ( ( $D2 - $UT1 ) / 128 ) ) / 4;
      $Temp = ( 200 + $DT * ( $C6 + 50 ) / 1024 + $DT / 256 ) / 10;
   }
   $Temp = sprintf( "%.2f", $Temp );

   my $Off  = $C2 * 4 + ( ( $C4 - 512 ) * $DT ) / 4096;
   my $Sens = $C1 + ( $C3 * $DT ) / 1024 + 24576;
   my $X    = ( $Sens * ( $D1 - 7168 ) ) / 16384 - $Off;
   $Pres = $X * 10 / 32 + 2500;
   $Pres /= 10;
   if ( $::config_parms{FroggyRita_altitude} ) {
      $Pres = $Pres * 10**( $::config_parms{FroggyRita_altitude} / 19434 );
   }

   $Pres = sprintf( "%.2f", $Pres );
   $Pres /= 10;

   if ( $Hmeasure == 0 ) {
      $Hum = 0;
   }
   elsif ( $Rp == 0 ) {
      $Hum = 0;
   }
   elsif ( $Hmeasure > 507 ) {
      $Hum = 100;
   }
   else {
      my $Imped = ( $Rs / 1000 ) / ( ( ( 2**$NbBits ) / $Hmeasure ) - 1 - ( $Rs / $Rp ) );
      my $A     = 1.0;
      my $B     = log10($Imped);
      my $C     = $B**2;
      my $D     = $B**3;
      my $T2    = $Temp**2;
      my $T3    = $Temp**3;
      my ( $A1, $A2, $A3, $A4 );
      my ( $B1, $B2, $B3, $B4 );
      my ( $C1, $C2, $C3, $C4 );
      my ( $D1, $D2, $D3, $D4 );
      $A1 = 1.154564e2;
      $A2 = -2.557588e1;
      $A3 = 4.595314e-1;
      $A4 = 2.008904e-1;
      $B1 = -3.066346e-1;
      $B2 = -8.884106e-1;
      $B3 = 3.460639e-1;
      $B4 = -3.408861e-2;
      $C1 = -2.558339e-2;
      $C2 = 3.352567e-2;
      $C3 = -1.106885e-2;
      $C4 = 9.045758e-4;
      $D1 = 3.386586e-4;
      $D2 = -3.616346e-4;
      $D3 = 9.868339e-5;
      $D4 = -2.454383e-6;

      $Hum = ( $A * $A1 ) + ( $B * $A2 ) + ( $C * $A3 ) + ( $D * $A4 );
      $Hum += $Temp * $A * $B1 + $Temp * $B * $B2 + $Temp * $C * $B3 + $Temp * $D * $B4;
      $Hum += $T2 * $A * $C1 + $T2 * $B * $C2 + $T2 * $C * $C3 + $T2 * $D * $C4;
      $Hum += $T3 * $A * $D1 + $T3 * $B * $D2 + $T3 * $C * $D3 + $T3 * $D * $D4;

      if ( $Hum > 100.0 ) { $Hum = 100.0 }
      if ( $Hum < 0.0 ) { $Hum = 0.0 }

   }
   $Hum = sprintf( "%.2f", $Hum );
   $TimeStamp = Now();
   &main::print_log("FroggyRita.pm CalcData T:$Temp\tP:$Pres\tH:$Hum\tC:$TimeStamp") if $main::Debug{froggyrita};
}

sub Now {

   #my $Time=`date "+%m/%d/%Y %H:%M:%S"`;
   my $Time = `date "+%Y-%m-%d %H:%M:%S"`;
   chomp $Time;
   return $Time;
}

# we need to identify the device, in order to calculate sensor value later
sub CheckIdentification {

   my $Identity = shift;
   &main::print_log("FroggyRita.pm CheckIdentification Entering") if $main::Debug{froggyrita};

   # validate identity string
   if ( CheckSum($Identity) != 0 ) {
      &main::print_log( "FroggyRita.pm: Checksum incorrect, probably invalid identification [$Identity]" );
      return;
   }

   # get rid of G00 at the beginning
   $Identity = substr( $Identity, 3 );
   $Word1    = substr( $Identity, 22, 4 );
   $Word2    = substr( $Identity, 26, 4 );
   $Word3    = substr( $Identity, 30, 4 );
   $Word4    = substr( $Identity, 34, 4 );
   $NbBits = Hex2Dec( substr( $Identity, 46, 2 ) );
   $Rs     = Hex2Dec( substr( $Identity, 48, 6 ) );
   $Rp     = Hex2Dec( substr( $Identity, 54, 6 ) );

   GenCxData();
   &main::print_log("FroggyRita.pm CheckIdentification we have an identification") if $main::Debug{froggyrita};
   $HaveIdent = 1;
}

sub Hex2Dec {
   return unpack( "N", pack( "H*", substr( "0" x 8 . shift, -8 ) ) );
}

# port definition
sub init {
   my ($serial_port) = @_;

   #$serial_port->error_msg(0);
   #$serial_port->parity_enable(1);
   $serial_port->databits(8);
   $serial_port->parity("none");
   $serial_port->stopbits(2);
   $serial_port->handshake('none');
   $serial_port->datatype('raw');
   $serial_port->dtr_active(0);
   $serial_port->rts_active(1);
   select( undef, undef, undef, .100 );    # Sleep a bit

}

# every thing coming and sent to froggy 
# is checksummed
sub CheckSum {

   # we receive the whole string
   # we return 0 if checksum is OK
   my $Str = shift @_;

   return 1 if !$Str =~ /G/;
   return 2 if !$Str =~ /Z/;

   my $Data     = substr( $Str, 1,  -3 );    # start from second to 3rd last ..Z
   my $CkSumStr = substr( $Str, -3, 2 );     # start from second to 3rd last ..Z

   my $SLen = length($Str);
   return 3 if $SLen % 2 == 1;

   my @SplitData = split ( //, $Data );
   my $CkSum = pack( "a", "G" );
   while ( scalar(@SplitData) > 0 ) {
      my $H1 = shift @SplitData;
      my $H2 = shift @SplitData;
      $CkSum = $CkSum ^ pack( "H2", "$H1$H2" );
   }
   return 4 if uc( unpack( "H2", $CkSum ) ) ne $CkSumStr;

   &main::print_log("FroggyRita.pm Checksum OK") if $main::Debug{froggyrita};
   return 0;

}

sub Bin2Dec {

   # convert to unsigned short integer
   return unpack( "N", pack( "B32", substr( "0" x 32 . shift, -32 ) ) );
}

sub GenCxData {

   my $WordString = $Word1 . $Word2 . $Word3 . $Word4;
   my $WordBin = unpack( "B64", pack( "H16", $WordString ) );
   $C1 = Bin2Dec( substr( $WordBin, 0,  15 ) );
   $C2 = Bin2Dec( substr( $WordBin, 42, 6 ) . substr( $WordBin, 58, 6 ) );
   $C3 = Bin2Dec( substr( $WordBin, 48, 10 ) );
   $C4 = Bin2Dec( substr( $WordBin, 32, 10 ) );
   $C5 = Bin2Dec( substr( $WordBin, 15, 11 ) );
   $C6 = Bin2Dec( substr( $WordBin, 26, 6 ) );
   1;
}

1;

#$Log$
#Revision 1.2  2004/01/26 01:42:59  cwitte
#cwitte sync to 2.86 tarball (take2)
#
#Revision 1.4  2002/12/02 01:07:49  gaetan
#Ajout de la doc
#
#Revision 1.3  2002/12/02 00:00:46  gaetan
#Ajoute timestamp sur message d'erreur
#
#Revision 1.2  2002/10/20 01:37:21  gaetan
#If altitude is defined, then do compensation
#
#Revision 1.1  2002/10/20 00:38:06  gaetan
#Initial revision
#
