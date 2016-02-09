
# This example 2 way of sending extended code preset dim commands
#  1: Send one of 64 preset dim commands directly using &P##
#  2: Use X10_Lamp ##% state
#
# - Note: extended codes only work with the CM11 interface and a compatable receiver
#   like the LM14A/PLM21 2 way X10 pro lamp modules.

$test_light1 =
  new X10_Item('O7');  # X10_Item supports relative brightness level states +-##
$test_light2 = new X10_Item( 'O7', 'CM11', 'LM14' )
  ;                    # X10_Lamp supports direct   brightness level states ##%

# All X10 items support direct preset dim commands &P## (1->64)
$v_test_light1 = new Voice_Cmd(
    "Set test light to [on,off,bright,dim,-10,-20,-30,-50,-70,+10,+20,+30,+50,+70,&P3,&P10,&P30,&P40,&P50,&P60]"
);
$v_test_light2 = new Voice_Cmd(
    "Set test light to [on,off,bright,dim,2%,4%,5%,10%,20%,30%,40%,50%,60%,70%,80%,90%,&P3,&P10,&P30,&P40,&P50,&P60]"
);

set $test_light1 $state if $state = said $v_test_light1;
set $test_light2 $state if $state = said $v_test_light2;

# There is another set of Preset Dim commands that are used by some modules (e.g. the RCS TX15 thermostate).
# These 32 non-extended Preset Dim codes can be coded directly, using the following table:

#  0  1  2  3  4  5  6  7  8  9 10 11 12 13 14 15   PRESET_DIM1
#  M  N  O  P  C  D  A  B  E  F  G  H  K  L  I  J

#  16 17 18 19 20 21 22 23 24 25 26 27 28 29 30 31  PRESET_DIM2
#  M  N  O  P  C  D  A  B  E  F  G  H  K  L  I  J

#For example:

$TX10 = new Serial_Item( 'XM4' . 'E' . 'PRESET_DIM1', 'Increase temp' )
  ;    #preset  8='E'
$TX10->add( 'XM4' . 'F' . 'PRESET_DIM1', 'Decrease temp' );    #preset  9='F'
$TX10->add( 'XM4' . 'O' . 'PRESET_DIM2', 'Preset on' );        #preset 18='O'
$TX10->add( 'XM4' . 'P' . 'PRESET_DIM2', 'Preset off' );       #preset 19='P'
