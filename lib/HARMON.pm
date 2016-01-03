=head1 B<HARMON>

=head2 SYNOPSIS

---Example Code and Usage---

=head2 DESCRIPTION

Module for sending commands to and tracking the current settings of the Harmon 
Kardon x65 line of receivers (AVR3650, AVR365, AVR2650, AVR265). 

=head2 CONFIGURATION

At minimum, you must define the receiver.  In addition, this library provides
for the ability to define separate objects for Power, Volume, Mute, Input, and
Control for each Zone.  This allows for the display of these settings for each zone 
as separate items in the MH interface and allows users to interact directly with these 
objects using the basic Generic_Item functions such as tie_event.

=head3 Interface Configuration

There is a small difference in configuring the HARMON Interface for direct
connections Serial or IP Connections (Ser2Sock).

=head4 Direct Connections (USB or Serial)

INI file:

   HARMON_serial_port=/dev/ttyAMA0  @This is the serial device
   HARMON_baudrate=115200		  	@This must be 115200

Wherein the format for the parameter name is:

   HARMON_serial_port
   HARMON_baudrate
   
=head4 IP Connections (Ser2Sock)

INI file:

HARMON_server_ip=192.168.1.33 @IP address of the machine running ser2sock
HARMON_server_port=36000 	  @Port configured in the ser2sock config
HARMON_server_recon=10		  @Amount of time to wait before trying to reconnect

Wherein the format for the parameter name is:

   HARMON-Prefix_server_ip
   HARMON-Prefix_server_port

** In the ser2sock configuration you must enable "raw_device_mode = 1".

=head4 Defining the Interface Object (All Connection Types)

In addition to the above configuration, you must also define the interface
object.  The object can be defined in either an mht file or user code.

In user code:

   $HARMON = new HARMON('HARMON');

Wherein the format for the definition is:

   $HARMON = new HARMON('HARMON');

=head3 Power Configuration

	$HARMON_POWER_Z1 = new HARMON_Power('HARMON', 1);

Wherein the format for the definition is:

	<object_name> = new HARMON_Power(<receiver>, <zone_number>);


=head3 Volume Configuration

	$HARMON_VOLUME_Z1 = new HARMON_Volume('HARMON', 1);

Wherein the format for the definition is:

	<object_name> = new HARMON_Volume(<receiver>, <zone_number>);



=head3 Mute Configuration

	$HARMON_MUTE_Z1 = new HARMON_Mute('HARMON', 1);

Wherein the format for the definition is:

	<object_name> = new HARMON_Volume(<receiver>, <zone_number>);



=head3 Input Configuration

	$HARMON_INPUT_Z1 = new HARMON_Input('HARMON', 1);

Wherein the format for the definition is:

	<object_name> = new HARMON_Volume(<receiver>, <zone_number>);


=head3 Control Configuration

	$HARMON_CONTROL_Z1 = new HARMON_Control('HARMON', 1);

Wherein the format for the definition is:

	<object_name> = new HARMON_Volume(<receiver>, <zone_number>);
	
=head2 TODO

- Add the following commands and Acks:

Specification:
Discrete Volume  

When zone1 is on the Discrete volume command allows the user
to enter a specific volume e.go. -63dB. When
command received via RS232 –the AVR should
display the Volume OSD with the specified
volume and adjust to that specified volume.
50, 43, 53, 45, 4E, 44, 02, 04, 80, 70,
00, 00, 02, XX
XX means user setted a specific Volume
value. Top bit means minus
-90 : 5A + 80 = DA
+10 : 10

Specification:
Discrete Volume ACK 

When zone1 is on AVR return current volume value,
41, 56, 52, 41, 43, 4B, 02, 02, XX,
Checksum
XX means user set a specific Volume value.
Top bit means minus
-90 : 5A + 80 = DA
+10 : 10

Specification:
Discrete Bass

When zone1 is on the Discrete bass command allows the user to enter
a specific Bass value e.g. 1dB. When command
received via RS232 – the AVR adjusts to that
specified bass setting.
If Tone Control was set to ‘Off’ it should be turned
‘On’.
No OSD needs to be shown by the AVR when these
commands are received, however when the user
reviews the OSD menus that show the status they
should be updated to show the correct bass setting /
tone control on status.
50, 43, 53, 45, 4E, 44, 02, 04, 80, 70,
00, 00, 03, XX
XX means user setted a specific Bass Level.
Top bit means minus(-1dB = 0x81)

Specification:
Return Bass Value 

When zone1 is on AVR Return bass value.
41, 56, 52, 41, 43, 4B, 02, 12
XX,Checksum
XX means user setted a specific Treble
Level. Top bit means minus(-1dB = 0x81)

Specification:
Get Bass Value

When zone1 is on From RS-232
Device
query the bass value by sponsor.
50, 43, 53, 45, 4E, 44, 02, 04, 80, 70,
00, 00, 38, 00

Specification:
Return Bass Value 

When zone1 is on AVR Return bass value.
41, 56, 52, 41, 43, 4B, 02, 12
XX,Checksum
XX means user setted a specific Treble
Level. Top bit means minus(-1dB = 0x81)

Specification:
Bass Up/Down 

When zone1 is on From RS-232 Device
The bass up/down command allows the user to
turn the bass up/down. When command received
via RS232 – the AVR should turn the bass up/down
accordingly.
If Tone Control was set to ‘Off’ it should be turned
‘On’.
No OSD needs to be shown by the AVR when these
commands are received, however when the user
reviews the OSD menus that show the status they
should be updated to show the correct bass setting /
tone control on status.
50, 43, 53, 45, 4E, 44, 02, 04, 80, 70,
00, 00, 04, 00
50, 43, 53, 45, 4E, 44, 02, 04, 80, 70,
00, 00, 05, 00

Specification:
Return Bass Value 

When zone1 is on AVR Return bass value.
41, 56, 52, 41, 43, 4B, 02, 12
XX,Checksum
XX means user setted a specific Treble
Level. Top bit means minus(-1dB = 0x81)

Discrete Treble 
When zone1 is on From RS-232
Device
The Discrete treble command allows the user to
enter a specific treble value e.g. 1dB. When
command received via IP / RS232 – the AVR
adjusts to that specified treble setting.
If Tone Control was set to ‘Off’ it should be turned
‘On’.
No OSD needs to be shown by the AVR when these
commands are received, however when the user
reviews the OSD menus that show the status they
should be updated to show the correct treble setting
/ tone control on status.
50, 43, 53, 45, 4E, 44, 02, 04, 80, 70,
00, 00, 06, XX
XX means user setted a specific Treble
Level. Top bit means minus(-1dB = 0x81)

Specification:
Return Treble

Value When zone1 is on AVR Return Treble value.
41, 56, 52, 41, 43, 4B, 02, 13
XX,Checksum
XX means user setted a specific Treble
Level. Top bit means minus(-1dB = 0x81)

Specification:
Get Treble Value
all zones at any state From RS-232
Device
query the Treble value by sponsor.
50, 43, 53, 45, 4E, 44, 02, 04, 80, 70,
00, 00, 39, 00

Specification:
Return Treble

Value all zones at any state AVR Return Treble value.
41, 56, 52, 41, 43, 4B, 02, 13
XX,Checksum
XX means user setted a specific Treble
Level. Top bit means minus(-1dB = 0x81)

Specification:
TrebleUp/Down 

When zone1 is on From RS-232 Device
The treble up/down command allows the user
to turn the treble up/down. When command
received via RS232 – the AVR should turn the
treble up/down accordingly.
If Tone Control was set to ‘Off’ it should be
turned ‘On’.
No OSD needs to be shown by the AVR when
these commands are received, however when
the user reviews the OSD menus that show the
status they should be updated to show the
correct treble setting / tone control on status.
50, 43, 53, 45, 4E, 44, 02, 04, 80, 70,
00, 00, 07, 00
50, 43, 53, 45, 4E, 44, 02, 04, 80, 70,
00, 00, 08, 00

Specification:
Return Treble Value

When zone1 is on AVR Return Treble value.
41, 56, 52, 41, 43, 4B, 02, 13
XX,Checksum
XX means user setted a specific Treble
Level. Top bit means minus(-1dB = 0x81)

Specification:
RDS

zone1 is on From RS-232 Device
RDS info must be able to be communicated
from the AVR over RS232
50, 43, 53, 45, 4E, 44, 02, 04, 80, 70,
00, 00, 0D, 00

Return RDS
info zone1 is on AVR
return the RDS info to device under control
system
Long packet format :41, 56, 52, 41,
43, 4B, 00, Length1,Length2, 05,
XX,XX,…. Checksum
Short packet format:41, 56, 52, 41,
43, 4B, Length, 05,XX,XX,….
Checksum
00: Packet length marker of long payload
Length1:High byte of length
Length2:Low byte of length
XX: RDS hex format data
XX=0x20: No data(blank)
20

Specification:
iPod/USB MP3 Player Repeat

zone1 is on From RS-232 Device
This feature allows the user to control iPod /
MP3 (USB) over RS232. 50, 43, 53, 45, 4E, 44, 02, 04, 80, 70,
00, 00, 0E, XX
1: Repeat All
2: Repeat one
3: Repeat Off
21


Specification:
iPod/USB MP3 Player Shuffle

zone1 is on From RS-232 Device
This feature allows the user to control iPod /
MP3 (USB) over RS232. 50, 43, 53, 45, 4E, 44, 02, 04, 80, 70,
00, 01, 0E, XX
1: Shuffle On
2: Shuffle Off

Specification:
Get iPod/USB MP3 Metadata
zone1 is on From RS-232 Device
iPod & MP3 (via USB) metadata info must be
able to be communicated from the AVR over
RS232
50, 43, 53, 45, 4E, 44, 02, 04, 80, 70,
00, 00, 0F, XX
1: Title
2: Artist
3: Album

Specification:
Return iPod/USB MP3 Metadata

zone1 is on AVR
return iPod/USB MP3 Metadata to device
under control
Long packet format :41, 56, 52, 41,
43, 4B, 00, Length1,Length2, 06,NN,
XX,XX,…. Checksum
Short packet format:41, 56, 52, 41,
43, 4B, Length, 06,NN, XX,XX,….
Checksum
NN: stands for title-0x01, artist-0x02,
album-0x03.
00: Packet length marker of long payload
Length1:High byte of length
Length2:Low byte of length
XX: data
XX=0x20: No data(blank)

Specification:
Get Sirius Metadata 
zone1 is on From RS-232 Device
Sirius Metadata info must be able to be
communicated from the AVR over RS232
50, 43, 53, 45, 4E, 44, 02, 04, 80, 70,
00, 00, 11, XX
1: Song
2: Artist
3: Category

Specification:
Return Sirius metadata 

zone1 is on AVR return sirius Metadata to device under control
Long packet format :41, 56, 52, 41,
43, 4B, 00, Length1,Length2, 07,NN,
XX,XX,…. Checksum
Short packet format:41, 56, 52, 41,
43, 4B, Length, 07,NN, XX,XX,….
Checksum
NN: stands for title-0x01, artist-0x02,
category-0x03.
00: Packet length marker of long payload
Length1:High byte of length
Length2:Low byte of length
XX: data
XX=0x20: No data(blank)

Specification:
Get Sirius station name and station number

zone1 is on or zone2 on state From RS-232 Device
This request is send by device under control or
the other sponsor. The purpose is to fetch Sirius
station number and name that AVR playing.
50, 43, 53, 45, 4E, 44, 02, 04, 80, 70,
00, 00, 31, 00

Specification:
Return Sirius station name and station number

zone1 is on or zone2 on
state AVR return the information to sponsor.
41, 56, 52, 41, 43, 4B, Length, 10,
XX,XX,…. Checksum
XX,XX: the string should compose and
parsed by format: station name + ' '+
"No"+ station Number
when XX,XX=0x20,means blank no data.
Tune up/Down
--Sirius Radio
zone1 is on or zone2 on
state
When AVR received this request, it tunes up
or down the Sirius radio.
50, 43, 53, 45, 4E, 44, 02, 04, 80, 70,
00, 00, 32, 00
50, 43, 53, 45, 4E, 44, 02, 04, 80, 70,
00, 00, 33, 00

Specification:
Return Sirius station number and station number

zone1 is on or zone2 on state
return the information to sponsor.
41, 56, 52, 41, 43, 4B, Length, 10,
XX,XX,…. Checksum
XX,XX: the string should compose and
parsed by format: station name + ' '+
"No"+ station Number
when XX,XX=0x20,means blank no data.

Specification:
Direct Channel Selection-- Sirius Radio

zone1 is on or zone2 on state
Direct Channel Selection allows the user to
enter a specific frequency that they want the
AVR to tune to with Sirius radio.
When command received via RS232 – the AVR
should switch to the entered frequency and
update the Radio Now playing page to show the
correct now playing and metadata.
Note: If the AVR wasn’t in the Radio source
when this command is received it must switch
the the AVR source also.
50, 43, 53, 45, 4E, 44, 02, 04, 80, 70,
00, 00, 13, XX
1 ~ 255

Specification:
Return direct channel selection-- Sirius Radio

zone1 is on or zone2 on
state AVR Return the channel selected with Sirius radio.
41, 56, 52, 41, 43, 4B,
Length,0E,XX,Checksum


00: Packet length marker of long payload
0x0E: return command's sequence number.
XX: channel number.

Specification:
Search Up/Down

zone1 is on, or zone2 is on
When command received via RS232 – behaves
the same as up / down remote button when in
Radio source and ‘Mode’ is set to ‘Auto'. Effect
with FM and AM source.
50, 43, 53, 45, 4E, 44, 02, 04, 80, 70,
00, 00, 14, 00
50, 43, 53, 45, 4E, 44, 02, 04, 80, 70,
00, 00, 15, 00

Specification:
Return Station Frequency and Preset number

zone1 is on, or zone2 is on AVR
In Auto search mode, it should send back every
station and it's preset number when there is a
channel searched. Then the searching will be
stopped.
Long packet format :41, 56, 52, 41,
43, 4B, 00, Length1,Length2,
0B,NN, XX,XX,…. Checksum
Short packet format:41, 56, 52, 41,
43, 4B, Length, 0B,NN, XX,XX,….
Checksum
Searching End
41, 56, 52, 41, 43, 4B, 02, 0B ,20,1B
00: Packet length marker of long payload
Length1:High byte of length
Length2:Low byte of length
0x0B: return command's sequence number.
XX: data

Specification:
Tune Up/Down

zone1 is on, or zone2 is on
When command received via RS232 – behaves
the same as up / down remote button when in
Radio source and ‘Mode’ is set to ‘Manual',
Effect with FM and AM source.
50, 43, 53, 45, 4E, 44, 02, 04, 80, 70,
00, 00, 16, 00
50, 43, 53, 45, 4E, 44, 02, 04, 80, 70,
00, 00, 17, 00

Specification:
Return Current station Frequency-- AM,FM

zone1 is on, or zone2 is on AVR
Return the current frequency data when it's
changed
41, 56, 52, 41, 43, 4B, Length, 0C,
XX,XX,…. Checksum

Specification:
Direct Preset Selection

zone1 is on, or zone2 is on
Direct Preset Selection allows the user to enter
a specific preset number that they want the
AVR to tune to. FM,AM
50, 43, 53, 45, 4E, 44, 02, 04, 80, 70,
00, 00, 18, XX
1 ~ 255

Specification:
Return Station Frequency and Preset number

zone1 is on, or zone2 is on AVR
When preset station has changed ,it should be
send back automatic.
Long packet format :41, 56, 52, 41,
43, 4B, 00, Length1,Length2, 0B,
XX,XX,…. Checksum
Short packet format:41, 56, 52, 41,
43, 4B, Length, 0B,XX,XX,….
Checksum
00: Packet length marker of long payload
Length1:High byte of length
Length2:Low byte of length
0x0B: return command's sequence number.
XX: the string should compose and parse
by format: frequency data + "Preset"
Number
The preset number can picked up by
"Preset"
Like "FM 87.50MHz Preset01"

Specification:
Preset Toggle 

zone1 is on, or zone2 is on From RS-232 Device
When command received via RS232 – behaves
the same as Left / right remote button when in
Radio source, For FM,AM
50, 43, 53, 45, 4E, 44, 02, 04, 80, 70,
00, 00, 19, 00
50, 43, 53, 45, 4E, 44, 02, 04, 80, 70,
00, 00, 1A, 00
Preset Up/Down

Specification:
Return Station Frequency and Preset number

zone1 is on, or zone2 is on AVR
When preset station has changed ,it should be
send back automatic.
Long packet format :41, 56, 52, 41,
43, 4B, 00, Length1,Length2,
0B,XX,XX,…. Checksum
Short packet format:41, 56, 52, 41,
43, 4B, Length, 0B, XX,XX,….
Checksum
00: Packet length marker of long payload
Length1:High byte of length
Length2:Low byte of length
0x0B: return command's sequence number.
XX: the string should compose and parse
by format: frequency data + "Preset"
Number
The preset number can picked up by
"Preset"
Like "FM 87.50MHz Preset01"

Specification:
Get Current station Frequency-- FM,AM

zone1 is on, or zone2 is on
This request is send by device under control or
the other sponsor. The purpose is to fetch
current frequency that AVR playing
50, 43, 53, 45, 4E, 44, 02, 04, 80, 70,
00, 00, 34, 00


Specification:
Return Current station Frequency-- AM,FM

zone1 is on,or zone2 is
on AVR return current station frequency
41, 56, 52, 41, 43, 4B, Length, 0C,
XX,XX,…. Checksum
XX,…,XX: stands for frequency, it's should
in string format.

Specification:
Set Current station Frequency-- FM,AM

zone1 is on, or zone2 is on
This request is send by device under control or
the other sponsor. The purpose is to fetch
current frequency that AVR playing
50, 43, 53, 45, 4E, 44, 02, 04, 80, 70,
00, 00, 35, 01,
XX,XX,XX,'.',XX,XX
50, 43, 53, 45, 4E, 44, 02, 04, 80, 70,
00, 00, 35, 02,
XX,XX,XX,XX
XX,XX,XX,'.',XX,XX - 101.50
XX,XX,XX,'.',XX,XX - 087.50
XX,XX,XX,XX - 1710
XX,XX,XX,XX - 0520

Specification:
Return Current station Frequency--AM,FM

zone1 is on, or zone2 is on
return current station frequency after the setting
command have done
41, 56, 52, 41, 43, 4B, Length, 0C,
XX,XX,…. Checksum
XX,...XX: stands for frequency, it's should
in string format.

=head2 INHERITS

L<Generic_Item>

=head2 METHODS

=over

=cut


package HARMON;

@HARMON::ISA = ('Generic_Item');

#my %CmdMsg;

my %CmdMsg = (
"Z1_ON" => "8070C03F404F",
"Z1_OFF" => "80709F601F10",
"Z1_GET-PWR-STAT" => "807000003600",
"Z1_GET-VOL-STAT" => "807000003700",
"Z1_GET-BASS-STAT" => "807000003800",
"Z1_GET-MUTE-STAT" => "807000003A00",
"Z1_GET-FREQ" => "807000003400",
"Z1_SIRIUS-TUNE-UP" => "807000003200",
"Z1_SIRIUS-TUNE-DOWN" => "807000003300",
"Z1_AM-BAND" => "807000001201",
"Z1_FM-BAND" => "807000001202",
"Z1_SIRIUS-BAND" => "807000001203",
"Z1_VOL-UP" => "8070C7384748",
"Z1_VOL-DOWN" => "8070C8374847",
"Z1_MUTE" => "8070C13E414E",
"Z1_MENU" => "807000002100",
"Z1_UP" => "807000002200",
"Z1_DOWN" => "807000002300",
"Z1_LEFT" => "807000002400",
"Z1_RIGHT" => "807000002500",
"Z1_OK" => "807000002600",
"Z1_0" => "807000003C00",
"Z1_1" => "807000003D00",
"Z1_2" => "807000003E00",
"Z1_3" => "807000003F00",
"Z1_4" => "807000004000",
"Z1_5" => "807000004100",
"Z1_6" => "807000004200",
"Z1_7" => "807000004200",
"Z1_8" => "807000004400",
"Z1_9" => "807000004500",
"Z1_SAT" => "807000000901",
"Z1_BLURAY" => "807000000902",
"Z1_BRIDGE" => "807000000903",
"Z1_DVR" => "807000000904",
"Z1_SIRIUS" => "807000000906",
"Z1_FM" => "807000000907",
"Z1_AM" => "807000000908",
"Z1_TV" => "807000000909",
"Z1_GAME" => "80700000090A",
"Z1_MEDIA" => "80700000090B",
"Z1_AUX" => "80700000090C",
"Z1_INET-RADIO" => "80700000090D",
"Z1_NETWORK" => "80700000090E",
"Z1_SRC-A" => "80700000090F",
"Z1_SRC-B" => "807000000910",
"Z1_SRC-C" => "807000000911",
"Z1_SRC-D" => "807000000912",
"Z2_ON" => "807000000A00",
"Z2_OFF" => "807000001B00",
"Z2_GET-PWR-STAT" => "807000003600",
"Z2_GET-VOL-STAT" => "807000003700",
"Z2_GET-BASS-STAT" => "807000003800",
"Z2_GET-MUTE-STAT" => "807000003A00",
"Z2_GET-FREQ" => "807000003400",
"Z2_VOL-UP" => "86762BD4ADA2",
"Z2_VOL-DOWN" => "86762CD3AAA5",
"Z2_MUTE" => "86762AD5ACA3",
"Z2_MENU" => "807000002700",
"Z2_UP" => "807000002800",
"Z2_DOWN" => "807000002900",
"Z2_LEFT" => "807000002A00",
"Z2_RIGHT" => "807000002B00",
"Z2_OK" => "807000002C00",
"Z2_0" => "807000004600",
"Z2_1" => "807000004700",
"Z2_2" => "807000004800",
"Z2_3" => "807000004900",
"Z2_4" => "807000004A00",
"Z2_5" => "807000004B00",
"Z2_6" => "807000004C00",
"Z2_7" => "807000004D00",
"Z2_8" => "807000004E00",
"Z2_9" => "807000004F00",
"Z2_SAT" => "867600001B01",
"Z2_BLURAY" => "867600001B02",
"Z2_BRIDGE" => "867600001B03",
"Z2_DVR" => "867600001B04",
"Z2_SIRIUS" => "867600001B06",
"Z2_FM" => "867600001B07",
"Z2_AM" => "867600001B08",
"Z2_TV" => "867600001B09",
"Z2_GAME" => "867600001B0A",
"Z2_MEDIA" => "867600001B0B",
"Z2_AUX" => "867600001B0C",
"Z2_INET-RADIO" => "867600001B0D",
"Z2_NETWORK" => "867600001B0E",
"Z2_SRC-A" => "867600001B0F",
"Z2_SRC-B" => "867600001B10",
"Z2_SRC-C" => "867600001B11",
"Z2_SRC-D" => "867600001B12"
);

#    Starting a new object
sub new {
   my ($class, $instance) = @_;
   $instance = "HAROMN" if (!defined($instance));
   ::print_log("Starting $instance instance of HARMON interface module");

   my $self = new Generic_Item();
   
      # Initialize Variables
   $$self{instance}       = $instance;
   $$self{reconnect_time} = $::config_parms{$instance.'_server_recon'};
   $$self{reconnect_time} = 10 if !defined($$self{reconnect_time});
   my $year_mon           = &::time_date_stamp( 10, time );
   $$self{log_file}       = $::config_parms{'data_dir'}."/logs/HARMON.$year_mon.log";

   bless $self, $class;

   #Store Object with Instance Name
   $self->_set_object_instance($instance);
   return $self;
}

sub get_object_by_instance{
   my ($instance) = @_;
   return $Interfaces{$instance};
}

sub _set_object_instance{
   my ($self, $instance) = @_;
   $Interfaces{$instance} = $self;
}


#    serial port configuration
sub init {

   my ($serial_port) = @_;
   $serial_port->error_msg(1);
   $serial_port->databits(8);
   $serial_port->parity("none");
   $serial_port->stopbits(1);
   $serial_port->handshake('none');
   $serial_port->datatype('raw');
   $serial_port->dtr_active(1);
   $serial_port->rts_active(0);

   select( undef, undef, undef, .100 );    # Sleep a bit

}




sub serial_startup {
   my ($instance) = @_;
   my ($port, $BaudRate, $ip);

   if ($::config_parms{$instance . '_serial_port'}) {
      $port = $::config_parms{$instance .'_serial_port'};
      $BaudRate = ( defined $::config_parms{$instance . '_baudrate'} ) ? $::config_parms{"$instance" . '_baudrate'} : 115200;
      if ( &main::serial_port_create( $instance, $port, $BaudRate, 'none', 'raw' ) ) {
         init( $::Serial_Ports{$instance}{object}, $port );
         ::print_log("[HARMON] initializing $instance on port $port at $BaudRate baud") if $main::Debug{'HARMON'};
         ::MainLoop_pre_add_hook( sub {check_for_data($instance, 'serial');}, 1 ) if $main::Serial_Ports{"$instance"}{object};
      }
   }
}

sub server_startup {
   my ($instance) = @_;

   $Socket_Items{"$instance"}{recon_timer} = ::Timer::new();
   my $ip = $::config_parms{"$instance".'_server_ip'};
   my $port = $::config_parms{"$instance" . '_server_port'};
   ::print_log("  HARMON.pm initializing $instance TCP session with $ip on port $port") if $main::Debug{'HARMON'};
   $Socket_Items{"$instance"}{'socket'} = new Socket_Item($instance, undef, "$ip:$port", $instance, 'tcp', 'raw');
   $Socket_Items{"$instance" . '_sender'}{'socket'} = new Socket_Item($instance . '_sender', undef, "$ip:$port", $instance . '_sender', 'tcp', 'rawout');
   $Socket_Items{"$instance"}{'socket'}->start;
   $Socket_Items{"$instance" . '_sender'}{'socket'}->start;
   ::MainLoop_pre_add_hook( sub {HARMON::check_for_data($instance, 'tcp');}, 1 );
}


sub check_for_data {
   my ($instance, $connecttype) = @_;
   my $self = get_object_by_instance($instance);
   my $NewCmd;
   my $AckMsg;

   
my %CmdAck = (
"41565241434B020110" => "Z1_P_ON,Z2_P_OFF",
"41565241434B020111" => "Z1_P_ON,Z2_P_ON",
"41565241434B020100" => "Z1_P_OFF,Z2_P_OFF",
"41565241434B020101" => "Z1_P_OFF,Z2_P_ON",
"41565241434B0311" => "Z1_V_VOL-ACK",
"41565241434B0202" => "Z1_V_VOL-ACK-TOG",
"41565241434B0209" => "Z2_V_VOL-ACK",
"41565241434B020300" => "Z1_M_MUTE-OFF",
"41565241434B020301" => "Z1_M_MUTE-ON",
"41565241434B020A00" => "Z2_M_MUTE-OFF",
"41565241434B020A01" => "Z2_M_MUTE-ON",
"41565241434B03140100" => "Z1_M_MUTE-ON,Z2_M_MUTE-OFF",
"41565241434B03140101" => "Z1_M_MUTE-ON,Z2_M_MUTE-ON",
"41565241434B03140001" => "Z1_M_MUTE-OFF,Z2_M_MUTE-ON",
"41565241434B03140000" => "Z1_M_MUTE-OFF,Z2_M_MUTE-OFF",
"41565241434B020401" => "Z1_I_SAT",
"41565241434B020402" => "Z1_I_BLURAY",
"41565241434B020403" => "Z1_I_BRIDGE",
"41565241434B020404" => "Z1_I_DVR",
"41565241434B020406" => "Z1_I_SIRIUS",
"41565241434B020407" => "Z1_I_FM",
"41565241434B020408" => "Z1_I_AM",
"41565241434B020409" => "Z1_I_TV",
"41565241434B02040A" => "Z1_I_GAME",
"41565241434B02040B" => "Z1_I_MEDIA",
"41565241434B02040C" => "Z1_I_AUX",
"41565241434B02040D" => "Z1_I_INET-RADIO",
"41565241434B02040E" => "Z1_I_NETWORK",
"41565241434B02040F" => "Z1_I_SRC-A",
"41565241434B020410" => "Z1_I_SRC-B",
"41565241434B020411" => "Z1_I_SRC-C",
"41565241434B020412" => "Z1_I_SRC-D",
"41565241434B020801" => "Z2_I_SAT",
"41565241434B020802" => "Z2_I_BLURAY",
"41565241434B020803" => "Z2_I_BRIDGE",
"41565241434B020804" => "Z2_I_DVR",
"41565241434B020806" => "Z2_I_SIRIUS",
"41565241434B020807" => "Z2_I_FM",
"41565241434B020808" => "Z2_I_AM",
"41565241434B020809" => "Z2_I_TV",
"41565241434B02080A" => "Z2_I_GAME",
"41565241434B02080B" => "Z2_I_MEDIA",
"41565241434B02080C" => "Z2_I_AUX",
"41565241434B02080D" => "Z2_I_INET-RADIO",
"41565241434B02080E" => "Z2_I_NETWORK",
"41565241434B02080F" => "Z2_I_SRC-A",
"41565241434B020810" => "Z2_I_SRC-B",
"41565241434B020811" => "Z2_I_SRC-C",
"41565241434B020812" => "Z2_I_SRC-D"
);

   # Get the data from serial or tcp source
   if ($connecttype eq 'serial') {
      &main::check_for_generic_serial_data($instance);
      $NewCmd = $main::Serial_Ports{$instance}{data};
      $main::Serial_Ports{$instance}{data} = '';
   }

   if ($connecttype eq 'tcp') {
      if ($Socket_Items{$instance}{'socket'}->active) {
         $NewCmd = uc(unpack('H*', ($Socket_Items{$instance}{'socket'}->said)));
      } else {
         # restart the TCP connection if its lost.
         if ($Socket_Items{$instance}{recon_timer}->inactive) {
            ::print_log("Connection to $instance instance of HARMON was lost, I will try to reconnect in $$self{reconnect_time} seconds");
            $Socket_Items{$instance}{recon_timer}->set($$self{reconnect_time}, sub {
               $Socket_Items{$instance}{'socket'}->start;
            });
         }
      }
   }

   # Return if nothing received
   return if !$NewCmd;

   # Prepend any prior message fragment
   $NewCmd = $self->{IncompleteCmd} . $NewCmd if $self->{IncompleteCmd};
   $self->{IncompleteCmd} = '';
   my $msg;
   my $zone_num;
   &main::print_log("[HARMON] - Hex $NewCmd ");
     my @NewCmds;
     if ($NewCmd =~ /^(\w{20})..$/) { $NewCmd = $1 }
     if ($NewCmd =~ /(\w{20})(\w{20})/) { @NewCmds = ($1,$2) }
     else { push @NewCmds, $NewCmd } 
     foreach $NewCmd(@NewCmds) {
	&main::print_log("[HARMON] - Hex $NewCmd - Lenght " . (length($NewCmd)) );
       if ((length($NewCmd)) eq "20") {
             $AckMsg = ($CmdAck{"$NewCmd"});
             if ($AckMsg eq '') { $AckMsg = ($CmdAck{(substr ($NewCmd, 0, 18))});} # try stripping the checksum
             if ($AckMsg eq '') { $AckMsg = ($CmdAck{(substr ($NewCmd, 0, 16))});} # strip last 2 for vol caculations
	     &main::print_log("[HARMON] - Ack $AckMsg - Hex $NewCmd ");
             $AckMsg = &GetAckMsg($AckMsg,$NewCmd) if &GetAckMsg($AckMsg,$NewCmd);
	     my @AckMsgs;
	     if ($AckMsg =~ /,/) { @AckMsgs = split(',', $AckMsg) }
	     else { push @AckMsgs, $AckMsg  }
	     foreach (@AckMsgs) {
		  &main::print_log("[HARMON] - ACK MSG $_"); 
		  if ( $_ =~ /^Z(\d)_(\w)_VOL_(.*)/ ) { $zone_num = $1; $msg = $3; }
                  elsif ( $_ =~ /^Z(\d)_(\w)_MUTE-(.*)/ ) { $zone_num = $1; $msg = $3; }
		  elsif ( $_ =~ /^Z(\d)_(\w)_(.*)/ ) { $zone_num = $1; $msg = $3; } 
		  if ($2 eq 'P') { $object_type = 'power_object'; }
		  elsif ($2 eq 'V') { $object_type = 'volume_object'; }
		  elsif ($2 eq 'M') { $object_type = 'mute_object'; }
                  elsif ($2 eq 'I') { $object_type = 'input_object'; }
		  $self->set_child_state($object_type, $zone_num, $msg);
             	  &main::print_log("[HARMON] - ACK MSG ($msg) - Zone ($zone_num) - Object Type ($object_type)");
	     }	
        } 
        else {
         # Save partial command for next serial read
         $self->{IncompleteCmd} = $Cmd;
       }
     }
}





sub GetAckMsg {
 my $GAckMsg = $_[0];
 my $hex = $_[1];
 my $RetAckMsg;
        if ($GAckMsg =~ /(Z\d)_V_VOL-ACK/) {
                $RetAckMsg = "+".(hex((substr ((substr ($hex, 16)),0 , 2))));
              if ($RetAckMsg > 0 and $RetAckMsg < 10) {
                    } else {
                         $RetAckMsg = "-".($RetAckMsg - 128);
                    }
                  $RetAckMsg = $1."_V_VOL_".$RetAckMsg;
                 return $RetAckMsg;
               }
        return;
      }




sub set_child_state {
   my ($self, $object_type, $zone_num, $msg) = @_;
   my $child = $self->{$object_type}{$zone_num};
   $child->set_receive($msg) if defined $child;
     if ( $object_type eq 'mute_object' ) { 
     #&main::print_log("[HARMON] - ACK MSG ($msg) - Zone ($zone_num) - Object Type ($object_type) - MUTE_CMD ". $$child{mute_cmd}); 
        if ($$child{mute_cmd} eq 'ON' and $msg eq 'OFF' ) { $child->set('Z'.$zone_num.'_MUTE'); $$child{mute_cmd} = 0; }
        elsif ($$child{mute_cmd} eq 'OFF' and $msg eq 'ON' ) { $child->set('Z'.$zone_num.'_MUTE'); $$child{mute_cmd} = 0; }
     }	
}

=item C<register()>

Used to associate child objects with the interface.

=cut

sub register {
   my ($self, $object, $num) = @_;
   if ($object->isa('HARMON_Volume')) {
      ::print_log("Registering Child Object for Harmon volume zone $num");
      $self->{volume_object}{$num} = $object;
   }
   elsif ($object->isa('HARMON_Mute')) {
      ::print_log("Registering Child Object for Harmon mute zone $num");
      $self->{mute_object}{$num} = $object;
   }
   elsif ($object->isa('HARMON_Power')) {
      ::print_log("Registering Child Object for Harmon power zone $num");
      $self->{power_object}{$num} = $object;
   }
   elsif ($object->isa('HARMON_Input')) {
      ::print_log("Registering Child Object for Harmon input zone $num");
      $self->{input_object}{$num} = $object;
   }
}



sub set {
   my ($self, $p_state, $p_setby, $p_response) = @_;
   my $instance = $$self{instance};
   ::print_log("[HARMON] State: $p_state - Hex: $CmdMsg{$p_state}");
   my $cmd = ( exists $CmdMsg{$p_state} ) ? $CmdMsg{$p_state} : $p_state;
   $cmd = "504353454E440204$cmd";
   $cmd = pack('H*', $cmd);

   #$self->debug_log(">>> Sending to HARMON receiver $p_state ($cmd)");
   if (defined $Socket_Items{$instance}) {
      if ($Socket_Items{$instance . '_sender'}{'socket'}->active) {
         $Socket_Items{$instance . '_sender'}{'socket'}->set("$cmd");
      } else {
         # restart the TCP connection if its lost.
         if ($Socket_Items{$instance}{recon_timer}->inactive) {
            ::print_log("Connection to $instance sending instance of HARMON was lost, I will try to reconnect in $$self{reconnect_time} seconds");
            $Socket_Items{$instance}{recon_timer}->set($$self{reconnect_time}, sub {
               $Socket_Items{$instance . '_sender'}{'socket'}->start;
               $Socket_Items{$instance . '_sender'}{'socket'}->set("$cmd");
            });
         }
      }
   }
   else {
      $main::Serial_Ports{$instance}{'socket'}->write("$cmd");
   }
   return;
}



package HARMON_Power;
@HARMON_Power::ISA = ('Generic_Item');

=item C<new($receiver, $zone )>

Instantiates a new object.

$receiver = The Harmon-Prefix of the receiver that this zone is found on

$zone = The zone number, usually 1


=cut

sub new
{
   my ($class,$receiver,$zone ) = @_;
   my $self = new Generic_Item();
   bless $self,$class;
   $receiver = HARMON::get_object_by_instance($receiver);
   #$$receiver{receiver_zone} = $self;
   $receiver->register($self,$zone);
   $$self{receiver} = $receiver;
   $$self{zone} = $zone;
   @{$$self{states}} = ('ON', 'OFF', 'GET-PWR-STAT');
   return $self;
}

sub set {
    my ($self, $p_state, $p_setby, $p_response) = @_;
        ::print_log("[HARMON::power] Received request to "
           . $p_state . " for zone " . $self->get_object_name);
	$p_state =~ s/ /-/g;
        if ($p_state =~ /^GET-PWR-STAT/ ) {
	     $p_state = "Z".$$self{zone}."_".$p_state;
             $$self{receiver}->set($p_state)
         }
         elsif ($p_state =~ /^Z\d_/) {
             $$self{receiver}->set($p_state);
         }
         else {
	   $p_state = "Z".$$self{zone}."_".$p_state;
           $$self{receiver}->set($p_state);
         }
 # $self->SUPER::set($p_state,$p_setby);
}


sub set_receive {
    my ($self, $p_state, $p_setby, $p_response) = @_;
    return $self->SUPER::set($p_state, $p_setby, $p_response);
    ::print_log("[HARMON::power] set to $p_state");
}


package HARMON_Volume;
@HARMON_Volume::ISA = ('Generic_Item');

=item C<new($receiver, $zone )>

Instantiates a new object.

$receiver = The Harmon-Prefix of the receiver that this zone is found on

$zone = The zone number, usually 1


=cut

sub new
{
   my ($class,$receiver,$zone ) = @_;
   my $self = new Generic_Item();
   bless $self,$class;
   $receiver = HARMON::get_object_by_instance($receiver);
   $receiver->register($self,$zone);
   $$self{receiver} = $receiver;
   $$self{zone} = $zone;
   @{$$self{states}} = ('UP', 'DOWN', 'GET-VOL-STAT');
   return $self;
}

sub set {
    my ($self, $p_state, $p_setby, $p_response) = @_;
        ::print_log("[HARMON::Volume] Received request "
              . $p_state ." for ". $self->get_object_name ." for zone ".$$self{zone});
		if ($p_state =~ /^GET-VOL-STAT/ ) { 
		  $p_state = "Z".$$self{zone}."_".$p_state;
		  $$self{receiver}->set($p_state) 
		}
		elsif ($p_state =~ /^Z\d_VOL-/ or $p_state =~ /^Z\d_GET-VOL-STAT/) {
		  $$self{receiver}->set($p_state);
		}
		else {
          	  $p_state = "Z".$$self{zone}."_VOL-".$p_state;
           	  $$self{receiver}->set($p_state);
	        }
 }


sub set_receive {
    my ($self, $p_state, $p_setby, $p_response) = @_;
    return $self->SUPER::set($p_state, $p_setby, $p_response);
    ::print_log("[HARMON::power] set to $p_state");
}


package HARMON_Mute;
@HARMON_Mute::ISA = ('Generic_Item');

=item C<new($receiver, $zone )>

Instantiates a new object.

$receiver = The Harmon-Prefix of the receiver that this zone is found on

$zone = The zone number, usually 1


=cut

sub new
{
   my ($class,$receiver,$zone ) = @_;
   my $self = new Generic_Item();
   bless $self,$class;
   $receiver = HARMON::get_object_by_instance($receiver);
   $receiver->register($self,$zone);
   $$self{receiver} = $receiver;
   $$self{zone} = $zone;
   @{$$self{states}} = ('ON','OFF','MUTE','GET-MUTE-STAT');
   return $self;
}

sub set {
    my ($self, $p_state, $p_setby, $p_response) = @_;
        ::print_log("[HARMON::Mute] Received request "
              . $p_state ." for ". $self->get_object_name ." for zone ".$$self{zone});
		if ($p_state =~ /^Z\d_MUTE/) {
                  $$self{receiver}->set($p_state);
                }
		elsif ($p_state =~ /^MUTE/ or $p_state =~ /^GET-MUTE-STAT/) {
		  $p_state = "Z".$$self{zone}."_".$p_state;
                  $$self{receiver}->set($p_state);
		}
                elsif ($p_state eq 'ON' or $p_state eq 'OFF') {
                    $$self{mute_cmd} = $p_state;
                    $p_state = "Z".$$self{zone}."_GET-MUTE-STAT";
                    $$self{receiver}->set($p_state);
                 } 
 }


sub set_receive {
    my ($self, $p_state, $p_setby, $p_response) = @_;
    return $self->SUPER::set($p_state, $p_setby, $p_response);
    ::print_log("[HARMON::power] set to $p_state");
}



package HARMON_Input;
@HARMON_Input::ISA = ('Generic_Item');

=item C<new($receiver, $zone )>

Instantiates a new object.

$receiver = The Harmon-Prefix of the receiver that this zone is found on

$zone = The zone number, usually 1


=cut

sub new
{
   my ($class,$receiver,$zone ) = @_;
   my $self = new Generic_Item();
   bless $self,$class;
   $receiver = HARMON::get_object_by_instance($receiver);
   $receiver->register($self,$zone);
   $$self{receiver} = $receiver;
   $$self{zone} = $zone;
   @{$$self{states}} = ('SAT','BLURAY','BRIDGE','DVR','SIRIUS','FM','AM','TV','GAME','MEDIA','AUX','INET-RADIO','NETWORK','SRC-A','SRC-B','SRC-C','SRC-D');
   return $self;
}

sub set {
    my ($self, $p_state, $p_setby, $p_response) = @_;
        ::print_log("[HARMON::Input] Received request "
              . $p_state ." for ". $self->get_object_name ." for zone ".$$self{zone});
		if ($p_state =~ /^Z\d_/) {
                  $$self{receiver}->set($p_state);
                }
                else {
                  $p_state = "Z".$$self{zone}."_".$p_state;
                  $$self{receiver}->set($p_state);
                }
 }


sub set_receive {
    my ($self, $p_state, $p_setby, $p_response) = @_;
    return $self->SUPER::set($p_state, $p_setby, $p_response);
    ::print_log("[HARMON::power] set to $p_state");
}

package HARMON_Control;
@HARMON_Control::ISA = ('Generic_Item');

=item C<new($receiver, $zone )>

Instantiates a new object.

$receiver = The Harmon-Prefix of the receiver that this zone is found on

$zone = The zone number, usually 1


=cut

sub new
{
   my ($class,$receiver,$zone ) = @_;
   my $self = new Generic_Item();
   bless $self,$class;
   $receiver = HARMON::get_object_by_instance($receiver);
   $receiver->register($self,$zone);
   $$self{receiver} = $receiver;
   $$self{zone} = $zone;
   @{$$self{states}} = ('SIRIUS-TUNE-DOWN','SIRIUS-TUNE-UP','MENU','UP','DOWN','LEFT','RIGHT','OK','0','1','2','3','4','5','6','7','8','9');
   return $self;
}

sub set {
    my ($self, $p_state, $p_setby, $p_response) = @_;
        ::print_log("[HARMON::Control] Received request "
              . $p_state ." for ". $self->get_object_name ." for zone ".$$self{zone});
		if ($p_state =~ /^Z\d_(.*)/) {
                  $$self{receiver}->set($p_state);
		  $self->SUPER::set($1,$p_setby);
                }
                else {
		  $self->SUPER::set($p_state,$p_setby);
                  $p_state = "Z".$$self{zone}."_". $p_state;
                  $$self{receiver}->set($p_state);
                }
 }
