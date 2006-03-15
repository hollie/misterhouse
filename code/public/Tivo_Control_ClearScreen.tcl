#
# Written by Kirk Bauer <kirk@kaybee.org>
#

proc ExecClear {sock} {
	if {[info exists connections($sock)]} {
  		set addr [lindex $connections($sock) 0]
  		puts "[CurrentTime] Request from $addr for screen clear"
	}
   ClearScreen
}

proc InitClearScreen {} {

global evrc

# Send the information necessary to fill the driver data structures

set periodicupdatefreq 0
set periodicupdatecommand "None"
set networkcall "ExecClear" 
set networkcommand "CLRS"

InstallNetworkCommand "ExecClear" \
  $networkcommand \
  $networkcall
}

global IamTivo

if {$IamTivo} {
	set moduleversion "1.1.0.1.1"
	set loaded [RegisterModuleVersion "ClearScreen" $moduleversion]

	if {$loaded} {
		InitClearScreen
	}
} else {
	puts "   ClearScreen can only run on a tivo"
}
