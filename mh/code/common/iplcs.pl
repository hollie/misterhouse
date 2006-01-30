# Category=Insteon

#@ Neil Cherry's Interface for sending Insteon and X10 commands. Replaces the CM11A.

use X10_iplcs ;

# noloop=start      This directive allows this code to be run on startup/reload
my $NJC = 10;
# noloop=stop

# How do I set this up so I only do this once?
#if(!defined($Insteon)) {
#    if ($config_parms{iplcs_port}) {
#        require 'ControlX10/iplcs.pm';
#        if (&serial_port_create('iplcs', $config_parms{iplcs_port}, 4800, 'none')) {
#	    # Initialize the PowerLinc V2 (serial verion)
#            #&ControlX10::iplcs::read($Serial_Ports{cm11}{object}, 1);
#            #&ControlX10::iplcs::setClock($Serial_Ports{cm11}{object});
#            $cm11_objects{timer} = new Timer;
#            $cm11_objects{active} = new Generic_Item;
#        }
#    }
#}

# sub startup {
#   &::MainLoop_pre_add_hook(\&X10_Wish::check_for_data, 1);
# }
#
# sub check_for_data {
# ...
# }

if($NJC == 10) {
    if(!defined($Serial_Ports{iplcs}{object})) {
	# I put this in the mh file
	#if ($config_parms{iplcs_port}) {
	#    require 'iplcs.pm';
	#    if (&serial_port_create('iplcs', $config_parms{iplcs_port}, 4800, 'none')) {
	#        #$iplcs_objects{timer} = new Timer;
	#        #$iplcs_objects{active} = new Generic_Item;
	#    }
	#}
	print "Serial_Ports now defined ($NJC we hope)\n";
    } else {
	&::MainLoop_pre_add_hook(  \&X10_iplcs::check_for_data, 1 ) if $main::Serial_Ports{iplcs}{object};
	&main::print_log ("iplcs adding X10_iplcs-check_for_data into pre_add_hook\n") if $main::Serial_Ports{iplcs}{object};
    
	print "Serial_Ports defined ($NJC)\n";
    }

    $NJC=1;
}
