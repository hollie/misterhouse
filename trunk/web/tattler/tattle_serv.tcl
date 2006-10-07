#!/usr/bin/wish

set t_chan -1

proc newsock { chan c_addr c_port } {
	global t_chan
	puts "Got a new connection from $c_addr:$c_port"
	set t_chan $chan
}

proc bcast {} {
	global t_chan
	puts $t_chan "Ping-a-ling"
	flush $t_chan
}

set tlistener [socket -server newsock 7000]

button .b -text "Pong" -command "bcast"
pack .b

