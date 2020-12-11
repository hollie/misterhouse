
=begin comment 

 Question:

  Anyone have a simple ibutton.pl for just reading temp from a few ibuttons
  and announcing when asked? I am not much of a code writer and I 
  have tried a
  few but they all have errors and the code is pretty involved so I can't
  figure what is the problem. I assume it is logging that is causing erros
  since I do not have any log files created. Thanks for any help.

 Answer:
  Create .mht entries like this:


IBUTTON, 100000003054c4,    ib_temp1
IBUTTON, 1000000029b992,    ib_temp2
IBUTTON, 100000002995aa,    ib_temp3
IBUTTON, 1000000029a364,    ib_temp4

 Then code like this:

=cut

$v_iButton_readtemp = new Voice_Cmd "Read the iButton temperature [1,2,3,4]";

my @ib_temps = ( $ib_temp1, $ib_temp2, $ib_temp3, $ib_temp4 );

# Read one temp
if ( $state = said $v_iButton_readtemp) {
    my $ib   = $ib_temps[ $state - 1 ];
    my $temp = read_temp $ib;
    speak "Temp from button 1 is $temp";
}

