
# Send a startup note


if ($Startup) {

    my $msg = <<eof;

                                 Welcome to MisterHouse! 

Installation instructions are in mh/docs/install.html ... in case you haven't read them yet ;-)

The rest of the mh documentation is in mh/docs/mh.html.  

You are currently running all the code in mh/code/test.
This messages comes from startup_message.pl.


See the 'Coding your own events' section at the end of 
mh/docs/install.html for instructions on what to do next.

eof

    $msg .= <<eof unless $config_parms{cm11_port} or $config_parms{cm17_port};

If you have an X10 interface, see the instructions at the top of the mh/bin/mh.ini file
on how to modify it, then change the CM11 (ActiveHome) or CM17 (Firecracker) entries
to point to the serial port you are using.

eof

    $msg =~ s/(\S)\n/$1 /g;            # Strip the cr, so it autowraps
#   print $msg;
    display $msg;
}
