
# Send a startup note

if ($Startup) {

    my $msg = <<eof;

                                 Welcome to MisterHouse! 


This is Danal's custom code directory.

eof
    $msg =~ s/(\S)\n/$1 /g;    # Strip the cr, so it autowraps
    print $msg;
    display $msg;
}
