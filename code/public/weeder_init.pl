
# Category=Startup

#########################################################################
# From Jeff Pagel on 01/2002
#
# Handle the init of the weeder board(s) when starting or restarting
#
# 12/06/01 jdp Add reading of the input ports so the internal states get
#               set correctly.  Outputs automattically get set via the
#               'init' command.  Again based on Bruces code, but does not
#               use the weeder 'read byte' command as that only allows for 8
#               inputs.  My weeder has 14.
# 11/15/01 jdp First code, based on Bruces startup.pl
#
#
#########################################################################
#
# Todo:
#
# Notes:
#  9600 Baud = .1041666 ms/bit
#  10 bits/byte = 1.04166 ms/byte
#  3 byte init = 3.125 ms
#  5 ms to let weeder react
#  Allow for 3 byte response to avoid collision = 3.125
#  = 11.25 ms.
#  Make it 25 ms for extra overhead since it's only a one time startup hit
#
#########################################################################

$v_init_weeder = new Voice_Cmd("Initialize the Weeder ports");
$v_init_weeder->set_info(
    'This will initialize the weeder digital
ports.  Automatically done on startup'
);

# This seems to be extraneous?
set $v_init_weeder 1 if $Startup;

#########################################################################
#
# Voice Commands
#
#########################################################################

# Init each bit on the weeder board
if ( said $v_init_weeder or $Startup ) {
    for my $ref (
        $WeedA_InC_DownFoyer_Motion, $WeedA_InD_Office_Motion,
        $WeedA_InE_Garage_Motion,    $WeedA_InF_Car_Sensor,
        $WeedA_OutG_RearBell,        $WeedA_InH_Pool_Mo,
        $WeedA_InI_Pantry_Door,      $WeedA_OutJ_Garage_DoorN
      )
    {
        set $ref 'init';

        # The init routines fail without this delay.  The newer weeders(model WTDIO-M??)
        # echo back the commands it gets.
        #
        # According to Terry Weeder of weedtech.com, These boards have to send the
        # response before they will accept another command.  Apparently the even newer
        # versions of the -M will allow you to disable this echo.
        #
        # So, delay 25ms
        select( undef, undef, undef, 0.025 );
    }

    for my $ref (
        $WeedA_InC_DownFoyer_Motion, $WeedA_InD_Office_Motion,
        $WeedA_InE_Garage_Motion,    $WeedA_InF_Car_Sensor,
        $WeedA_InH_Pool_Mo,          $WeedA_InI_Pantry_Door
      )
    {
        set $ref 'read';

        # This routine fails without this delay.
        select( undef, undef, undef, 0.025 );
    }
}
