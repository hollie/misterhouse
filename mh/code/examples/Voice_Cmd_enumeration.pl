
# This example shows how you can mix 'phrase enumeration groups' 
# bounced by {} with  a 'state enumeration group' with [].

                                # Example of several phrase enumeration groups
$v_test1 = new Voice_Cmd("{turn,set} the {living,famliy} room {light,lights} [on,off]");

                                # Example of how to specify optional words
$v_test2 = new Voice_Cmd("{Please, } tell me the time");

                                # Example of how to specify multiple phrases for the same action
$v_test3 = new Voice_Cmd("{What time is it,Tell me the time}");


