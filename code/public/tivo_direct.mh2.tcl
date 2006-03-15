#!/bin/sh
# set nice value, if "setpri" found
# \
type setpri > /dev/null 2>&1 && setpri rr 1 $$

# exec tivosh, if found, else exec tclsh
# \
type tivosh > /dev/null 2>&1 && exec tivosh "$0" "$@" || exec tclsh "$0" "$@"

source $tcl_library/tv/sendkey.tcl

proc setOSD {line} {
  ##### LOCATION OF newtext2osd #####
  set OSDPROG "/hack/bin/newtext2osd"
        set SECS [getField SECS $line]
  set FGCL [getField FGCL $line]
  set BGCL [getField BGCL $line]
  set XPOS [getField XPOS $line]
        set YPOS [getField YPOS $line]
  set MXLEN [expr 39-$XPOS]
  set STRNG [getField TEXT $line]
  set LINEWRAP [getField LWRP $line]
  set CURRLINE 0
  set CLEARLINE [string range "                                         " 0 $MXLEN]


  if {$LINEWRAP == 0 } {
                set STRNG [string range $STRNG 0 $MXLEN]
        }

  while {[string length $STRNG]} {
                set TEXT [string range $STRNG 0 $MXLEN]
                set command "$OSDPROG -f $FGCL -b $BGCL -x $XPOS -y [expr $YPOS+$CURRLINE] -e -t \"$TEXT\""
        eval exec $command
    set STRNG [string range $STRNG [expr $MXLEN+1] end]
    set CURRLINE [expr $CURRLINE+1]
        }
  if {$SECS} {
     eval exec "$OSDPROG -s $SECS -t \"\""
     if {[catch {exec $OSDPROG -c > /dev/null 2>/dev/null "&"} result]} {
               puts "Can't launch newtext2osd"
     }
  }
}

proc getField {dataString dataBlock} {
    regsub .*$dataString. $dataBlock {} result
    regsub {([\w\s]*)\*.*} $result {\1} result
    return $result
}

proc toSendKey {line} {
   set trimmed [string trim [string trimleft $line SENDKEY:]]
   foreach k $trimmed {
      SendKey $k
   }
}


#set up listen socket
proc init_event_server {port} {
        global listen_socket
        #create global array of socets
        global sock_list
        global forever
        set forever start

        #register callback for when main socket is ready
        set listen_socket [socket -server event_accept $port]

}


#call back to accept connection to listen socket
proc event_accept {sock addr port} {
        global sock_list

        #puts "Accept $sock from $addr port $port"
        set sock_list($sock) [list $addr $port]

        #set socket to buffer line by line
        #(not readable until whole line present)
        fconfigure $sock -buffering line

        #register callback on socket when it is readable
        fileevent $sock readable [list connection_readable $sock]
}


#callback for when a socket is readable
proc connection_readable {sock} {
        global sock_list
        global listen_socket
        global forever

        #check to see if socket is eof
        #if not read a line
        #catch errors from read if any
        if {[eof $sock] || [catch {gets $sock line}]} {
                #socket was eof or error occured during read
                close_connection $sock
        } else {
                if {[string match OSD:* $line]} {
                        setOSD $line
                }
                if {[string match SENDKEY:* $line]} {
                        toSendKey $line
                }

                #not eof and no errors during read
                if {[string compare $line "shutdown server"] == 0} {
                        #stop new incomming connections
                        #shutdown main server
                        close_all_connections
                        #signal the program to terminate
                        set forever end
                }

                #echo text back out the socket
                #puts $line
        }
}

proc send_to_all_connections {line} {
        global sock_list
                #for test echo text back to all connected sockets
                foreach connection [array names sock_list] {
                        puts $connection $line
                }
}

#shut down all connected sockets
proc close_all_connections {} {
        global sock_list
        global listen_socket
        close $listen_socket
        foreach connection [array names sock_list] {
                close_connection $connection
        }
}

#shuts down a connected socket
proc close_connection {sock} {
        global sock_list

        close $sock
        #puts "Close $sock_list($sock)"
        unset sock_list($sock)
}


proc status_event_callback { type subtype } {
        set eventreturned "2 7 6 13 4 3 9 19"
        set eventenglish "TIVOCENTRAL NOWPLAYING LIVETV MENU TIVOMAGAZINE SHOWCASES PICKTORECORD MESSAGESANDSETUP"

        global EventData Context Serial
        binary scan $EventData II data Serial
        if { $type == $TmkEvent::EVT_MW_STATUS && $subtype != $TmkEventMwStatus::BONKED } {
                set Context $data
                set english [lindex $eventenglish [set foundit [lsearch $eventreturned $data]]]
                if { $foundit == -1 } {
                     set english $data
                }
                send_to_all_connections "event $english"
#                puts "event $english"

        }
}

proc remote_event_callback { type subtype } {
      set remotecommand "15 16 17 18 19 20 21 22 23 14 4 5 1 0 2 3 6 41 13 6 8 7 42 43 9 10 44 11 26 29 30 27 28 33 34
25 24"
      set remoteenglish "1 2 3 4 5 6 7 8 9 0 SELECT TIVO DOWN UP LEFT RIGHT GUIDE/LIVETV TVPOWER MENU DISPLAY THUMBDOWN
THUMBUP VOLUP VOLDOWN CHANNELUP CHANNELDOWN MUTE RECORD FWD BACK PAUSE SLOW LAST30 TOEND CLEAR ENTER/JUMP"

        global EventData Context Serial
        binary scan $EventData II data Serial

        #event is a remote event - check subtype == 0
        if { $subtype == 0 } {
                set english [lindex $remoteenglish [set foundit [lsearch $remotecommand $data]]]
                if { $foundit == -1 } {
                    set english $data
                }
                send_to_all_connections "remote $english"
 #               puts "remote $english"
        }
}

event register $TmkEvent::EVT_MW_STATUS status_event_callback
event register $TmkEvent::EVT_REMOTEEVENT remote_event_callback

init_event_server 4560
vwait forever


