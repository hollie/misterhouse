#$Id$
=head1 DESCRIPTION


This is the second beta release of a module interfacing with the BX24-AHT
kit from Dave Houston and Peter Anderson . This device could replace 
all TM751 and a MR26a modules. It could receive and interpret all RF housecode.

http://www.laser.com/dhouston
http://www.phanderson.com

by Gaetan lord    email@gaetanlord.ca


This module is based on the example code example_interface.pm
and the MR26a modules (Many thanks to the authors).

On Dave Houston site, there is information on how to build a turnstyle 
antenna. This antenna is very cheap to produce, and give good result 

For now, the module receive all RF code, and convert them
to be compatible with misterhouse X10 device definition (A1 ON -> XA1AJ).

A CM11A device could be plug in one of the 3 serial output port of the BX24.
This allow the BX24 to receive RF signal and relay them to the CM11A, without
interfacing with a computer. 

If the CM11a is attached on one of the BX24 serial port, this module could send
X10 command through in the same was as we do with a directly attached CM11a

If we are adressing a single unit, then we could use On/Off Bright/Dim and extended command.
If we are adressing a whole house, then only on and off could be use

The interaction between the BX24 and the computer is done via a serial 
port (DB9) at 19200 Bauds.

The BX24 could have an optional barometer, and this code can handle the
information provided by the barometer. There is 2 way to trigger the Barometer data.
By programming a Parameter event via the BX24 computer interface, or by
sending a "B" command to the serial port of the computer. I choose the later, to 
get more flexibility. So, my misterhouse program, will have to send the command
on a regular basis. NOTE:, the response received from this event may take
up to 1 sec to get back.

When we receive an RF signal, we get this message
RF: [764] 30 50 (P6 On)

When the CM11a detect a command on the line we have the following 2 lines
note: the -3 represent the 3rd BX24 serial interface
RX: P6-3
RX: P On-3

When we receive a barometric signal, we get
Barometer: 868


=head1 .INI PARAMETERS

Use these mh.ini parameters to enable the code:

  BX24_module = X10_BX24
  BX24_port   = /dev/ttyS1
  BX24_BarometricFactor = 8.39  # this is the correction factor


=head2 EXAMPLES

Here is some example on how to use the module

 #This will create the BX24 object
 $v_BX24 = new X10_BX24;


 #this define a regular misterhouse X10 Device
 $Bathroom = new X10_Item('J2');

 # If the BX24 receive a J2 On command.
 # A regular X10 event will be set
 # and the application will see the event like it
 # came from a CM11a

 if ( state = state_now $Bathroom) {
    my $level = level $Bathroom
    print "J2 state is $state and level is $level\n";
 }


 # if we want to send X10 cmd via the BX24
 # Computer -> BX24 -> CM11a
 # we want to open the bathroom light
 set $Bathroom 'on';

 # if we want to dim the light by 40
 set $Bathroom '-40';

 # if we want to bright the light by 20
 set $Bathroom '+40';


 # If the optional barometer is installed
 if ($New_Minute) {
    $v_BX24->Query_Barometer;
 }

 if (my $Pressure = state_now $v_BX24) {
     # we should get somethings like    Barometer: 867
     $Pressure =~ s/Barometer: //;
     chomp $Pressure;
     return if $Pressure =~ /^$/;

     $Pressure = int( $Pressure * 100 / $config_parms{BX24_BarometricFactor} ) / 100;
     print "The pressure is $Pressure\n";
 }
 
=cut

use strict;

package X10_BX24;

@X10_BX24::ISA = ('Generic_Item');

sub startup {
    &main::serial_port_create('BX24', $main::config_parms{BX24_port}, 19200, 'none', 'raw');
                                # Add hook only if serial port was created ok
    &::MainLoop_pre_add_hook(  \&X10_BX24::check_for_data, 1 ) if $main::Serial_Ports{BX24}{object};
}


sub Query_Barometer {
   # clean object list 
   for my $name (&main::list_objects_by_type('X10_BX24')) {
       my $object = &main::get_object_by_name($name);
       $object -> set("",'Barometer');
   }
   return if &main::proxy_send('bx24', 'BX24_Query_Barometer', $serial_data);
   $main::Serial_Ports{BX24}{object}->write("B");
   1;
}

my $prev_X10='';
my %X10Unit= ( "1" => "01",
               "2" => "02",
               "3" => "03",
               "4" => "04",
               "5" => "05",
               "6" => "06",
               "7" => "07",
               "8" => "08",
               "9" => "09",
               "A" => "10",
               "B" => "11",
               "C" => "12",
               "D" => "13",
               "E" => "14",
               "F" => "15",
               "G" => "16"
            );
               
sub SendX10 {
   # this will receive command to be sent to the CM11a via a regular X10_Item call
   # this subroutine could be call twice before sending the command
   # the first call will be the house code/Unit if non "all unit" 
   # the second call will be the command
   # doesn't support all unit preset/dim/bright

   # The BX24 is expecting the following code to drive the CM11A
   # XHUUFLL
   # X    Tell the system it's a X10 Command
   # H  = Housecode A-P
   # UU = Unit 01-16 
   # F  = FUNCTION  (only on/off for now)
   #      N = On
   #      F = Off 
   #      D = Dim 
   #      B = Bright 
   #      X = Extended Dim
   # LL = Level (always 00 for On/off)
   # LL = Level (+-00/99 for Bright/Dim)
   # LL = Level (00/63 for Extended Dim)
   
 
   my $HouseUnit; 
   if ( scalar(@_) != 1 ) { 
     &main::print_log("BX24 call to CM11a Invalid parameter [@_]");
     return;
   }
   
   my $NewX10 = shift @_;
   $NewX10=uc($NewX10);
  
   if ( $NewX10 !~ /^X/ ) {
     &main::print_log("BX24 Invalid CM11a call doesn't start by X");
     return;
   }

   # print "DEBUG BX24 Received X10 cmd [$NewX10]\n";
   # did we receive a House/Unit code, or an action
   # The house/Unix will have a second charater 1-9 A-G 
   my ($XChar,$House,$X10Type,@X10Value) = split(//,$NewX10);
   my $Cmd;
   if ( uc($House) !~ /[A-P]/ ) {
      print "BX24 invalid house code [$House]\n";
      $prev_X10='';
      return;
   }
   if ( $X10Type =~/[1-9A-GOP]/ ) {
      if ( $X10Type eq "O" ) {
         $Cmd = "X".$House."00L00";      # All light On   mh=XAO
      } elsif ( $X10Type eq "P" ) {
         $Cmd = "X".$House."00U00";      # All light off  mh=XAP
      } else {
      $prev_X10="X".$House.$X10Unit{$X10Type};
      # print "DEBUG BX24 sub SendX10 Preserving X10 house/unit $prev_X10\n";
      return;
      }
   } elsif ( $X10Type =~/[JKLM\-\+\&]/ ) {
      if ( $prev_X10 eq '') {
         print "BX24 invalid CM11a command, no housecode defined  [@_]\n";
         return;
      }
      if ( $X10Type eq "J") {                   # ON
         $Cmd = $prev_X10 . "N00";
      } elsif ( $X10Type eq "K") {              # Off
         $Cmd = $prev_X10 . "F00";
      } elsif ( $X10Type eq "+") {              # Bright with Value (+20)
         my $Bright = (join('',@X10Value) eq '') ? 33 : join('',@X10Value);
         my $Bright = ( $Bright < 10 ) ? "0".$Bright : $Bright;
         $Cmd = $prev_X10 . "B" . $Bright;
      } elsif ( $X10Type eq "-") {              # Dim with value    (-20)
         my $Dim = (join('',@X10Value) eq '') ? 33 : join('',@X10Value);
         my $Dim = ( $Dim < 10 ) ? "0".$Dim : $Dim;
         $Cmd = $prev_X10 . "D" . $Dim;
      } elsif ( $X10Type eq "&") {              # Preset (1-63)
         my $Preset = join('',@X10Value);
         $Preset =~s/P//;
         $Cmd = $prev_X10 . "X$Preset";
      } elsif ( $X10Type eq "L") {              # Brighten as per Misterhouse way (+40) 
         $Cmd = $prev_X10 . "B40";
      } elsif ( $X10Type eq "M") {              # Dimmer as per Misterhouse way (-40) 
         $Cmd = $prev_X10 . "D40";
      }
      # print "DEBUG BX24 sub SendX10 Complete X10 command received [$Cmd]\n";
      $prev_X10='';
   } else {
      print "BX24 invalid CM11a command [@_]\n";
      $prev_X10='';
      return;
   }
    
  
   # print "BX24 Sending CM11a command [$Cmd]\n"; 
   $main::Serial_Ports{BX24}{object}->write("$Cmd");

   return;

}

my ($prev_data, $prev_time, $prev_loop, $prev_rx);
$prev_data = "";
$prev_time = 0;
$prev_rx="";

sub check_for_data {
    my ($self) = @_;
    &main::check_for_generic_serial_data('BX24');
    my $RcvStr = "$prev_data" . $main::Serial_Ports{BX24}{data};
    
    $main::Serial_Ports{BX24}{data} = '';
    return unless $RcvStr;

    # Return string Hex value (to debug received data)
    # my @HexStr = unpack ("C*",$RcvStr);
    # print "Hex Data = [@HexStr]\n";

    # sometimes, it's too quick to get the whole line
    # or we get more than 1 line if the received line is short
    # the line end with a carriage return following by a linefeed (DOS style)
    # we have to test different scenario
    my @CharStr = split (//,$RcvStr);
    my @PrevStr = split (//,$RcvStr);
    my $GotCR=0;
    my $LineOK=0;
    my $data;

    foreach (@CharStr) {
       # my $chr=unpack("C",$_);
       # print "DEBUG BX24 Deal with [$chr]\n";
       shift @PrevStr;
       if ($_ eq "\r") { 
          $GotCR=1 ; 
          $data .= $_ ; 
          # print "DEBUG BX24 OK CR\n";
          next; 
       }
       if ($_ eq "\n" && $GotCR) {
          # print "DEBUG BX24 OK LF\n";
          $prev_data=join('',@PrevStr);
          $data .= $_;
          $LineOK=1;
          last;
       }
       $data.=$_;
    }

    # print "DEBUG BX24 GotCR=$GotCR LineOK=$LineOK [$data] EOF\n";
    if ( ! $LineOK ) { 
       $prev_data = $data;
       # print "DEBUG BX24 Imcomplete line [$data]\n";
       return;
    }   
  
    # remove the CR-LF from the data received
    $data=~s/\r\n//;
    # print "DEBUG BX24 Received cmd [$data]\n";

    # we discard the timeout message
    return if $data =~ /Timeout/; 

    # we discard the TX signal
    return if $data =~ /TX/; 

    # we discard the RS signal
    return if $data =~ /RS/; 

    # we discard the tilda message
    return if $data =~ /^~/; 

    # when the BX24 rcv something from the CM11a,
    # it display the value with 2 RX command if On/Off, here the "-3" 
    # represent which serial port it came from
    # RX: B7-3
    # RX: B Off-3
    # or one single command (bright/Dim)
    # RX: P Bright 16%-3
    if ( $data =~ /RX:/ ) {
       my ($rx)=$data=~/RX: (.*)\-./;                    # remove the RX message
       # print "DEBUG BX24 RX=[$data] -> $rx\n";

       # we could receive a unit cmd or an action command
       # if we get the unit , we save the value and wait for action
       $rx =~ s/\s*/ /;
       my @RX = split (" ",$rx);
       if ( scalar (@RX) == 1 ) {      # Only unit command 
          $prev_rx = $rx;
          # print "DEBUG BX24 Preserving RX Unit [$prev_rx]\n";
          return;                      # we need to wait for action before processing
       } else  {
          if ( $prev_rx eq '' ) {       # it's a bright/dim, never rcv unit command
             $RX[1] = join (' ' , @RX);   # we rcv bright, keep housecode
          }
          $data = "($prev_rx $RX[1] )";   # this will reproduce a similar RF cmd
          # print "DEBUG BX24 Received RX action -> ($prev_rx $RX[1])\n";
          $prev_rx = '';
       }
    }       
       
    # we keep RF (received code)
    # RF: [426] 60 18 (A4 On)
    # &main::main::print_log("BX24 Data: $data");
    &main::print_log("BX24 Data: $data") if $main::Debug{bx24};

    my @UnitCode=qw(0 1 2 3 4 5 6 7 8 9 A B C D E F G);

    #RF: [727] 30 98 (P Dim 12%)
    #RF: [705] 30 00 (P1 On)
    #RF: [706] 30 20 (P1 Off)
    if (my ($X10BX24) = $data =~ /.*\((.*)\)/)  {
        
        # print "DEBUG BX24 X10BX24=$X10BX24\n";
        $X10BX24=~s/\s*/ /;
        my @Tmp = split(' ',$X10BX24);
        my $HouseUnit=shift @Tmp;
        my $Status = shift @Tmp;
        $Status=lc($Status);

	my $House = substr($HouseUnit,0,1);
	my $Unit = @UnitCode[substr($HouseUnit,1,2)];

        # There is 4 status return from a RF signal (On Off Bright Dim)
        my $X10Code;
        if ( $Status eq 'on' ) {
             $X10Code = "X$House$Unit$House"."J";
        } elsif ($Status eq 'off') {
             $X10Code = "X$House$Unit$House"."K";
        } elsif ($Status =~ /bright/) {
             my $DimBri=shift @Tmp;
             $DimBri =~ s/\%//;
             $X10Code = "X${House}\+$DimBri";
        } elsif ($Status eq 'dim') {
             my $DimBri=shift @Tmp;
             $DimBri =~ s/\%//;
             $X10Code = "X${House}\-$DimBri";
        } elsif ( $X10BX24 =~ /All Lights On/ ) {
             $X10Code = "X${House}O";
        } elsif ( $X10BX24 =~ /All Units Off/ ) {       # sound like the On and Off message are different
             $X10Code = "X${House}P";
        } else {
             print "Bad status\n";
        }

        &main::process_serial_data($X10Code) if $X10Code;   # This will act like the CM11a and declare a X10 action
        &main::print_log("BX24 Code: $X10BX24   X10 Code:$X10Code") if $main::Debug{bx24};
        # print("BX24 Code: $X10BX24   X10 Code:$X10Code\n");

    }
    elsif (my ($X10BX24) = $data =~ /Barometer/) {
        # Set state of BX24 objects
        for my $name (&main::list_objects_by_type('X10_BX24')) {
            my $object = &main::get_object_by_name($name);
            $object -> set($data);
        }
    } else {
       print "Bad data [$data] received from BX24\n";
    }


}

1;
