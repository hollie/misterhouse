#!/usr/bin/perl 
##############################################################################

=begin COMMENT

FILE
    terminalmenu-client.pl

    
DESCRIPTION
    A console application that connects to Misterhouse, allowing to navigate
    Misterhouse menus (using Terminal_Menu within Misterhouse).
    
    For a description of the protocol please refer to Terminal_Menu.pm
    
    terminalmenu-client.pl was tested on 
        Debian GNU/Linux
        Microsoft Windows 2000
        Mac OS X 10.3.9.

    
USAGE
    terminalmenu-client.pl  [--server <server>] [--port <port>]
                            [--command "<COMMAND1[,COMMAND2[...]]>"]
                            [--help] [--debug]

    -h, --help       => Show usage information.
    -s, --server     => DNS name or IP of the computer to connect to.
                        Default: 127.0.0.1
    -p, --port       => TCP/IP port that the terminal_menu.pl is running on.
                        Default: 29974
    -c, --command    => Commands that are sent to the Terminal_Menu right
                        after startup. Allows configuration of colors, etc. 
                        If more than one command is given, seperate them 
                        with [,]. Note: don't forget to quote the command 
                        string properly!
                        See terminal_menu.pl (supplied with Misterhouse) for 
                        available commands.                      
    -d, --debug      => Prints received commands instead of executing them.

    
REQUIREMENTS    
    The following Perl modules are needed:
        
        IO::Socket 
        IO::Select 
        Term::ReadKey 
        Term::ANSIScreen
        Win32::Console (Microsoft Windows only) 

    IO::Socket and IO::Select are already installed by any modern Perl 
    distribution.
    
    Term::ReadKey should be available from your Perl distribution as seperate
    install (e.g. use 'ppm install termreadkey' for ActiveState's Perl on 
    Windows; or 'apt-get install libterm-readkey-perl' on Debian GNU/Linux).
    On Mac OS X this module can be installed via the CPAN method described
    below.
    
    Term::ANSIScreen can be installed from CPAN (install while having 
    administrator rights):
        
        perl -MCPAN -e shell
        cpan> install Term::ANSIScreen
    
    Win32::Console is only needed on Microsoft Windows platforms and usually
    supplied with the Perl installation already.
            
                            
AUTHOR
    Werner Lane
    wl-opensource@gmx.net

    
LICENSE
    This free software is licensed under the terms of the GNU public license.

=cut

##############################################################################

use strict;
use warnings;

use IO::Socket;
use IO::Select;
use Term::ReadKey;
use Term::ANSIScreen;

use constant BUFSIZE => 1024;

# The following color values are exported by Term::ANSIScreen
use vars qw( $ATTR_NORMAL $ATTR_INVERSE $FG_BLACK $FG_CYAN $FG_BLUE $FG_RED
  $FG_GREEN $FG_MAGENTA $FG_YELLOW $FG_WHITE $FG_LIGHTCYAN $FG_LIGHTBLUE
  $FG_LIGHTRED $FG_LIGHTGREEN $FG_LIGHTMAGENTA $FG_LIGHTYELLOW $FG_LIGHTWHITE
  $BG_BLACK $BG_CYAN $BG_BLUE $BG_RED $BG_GREEN $BG_MAGENTA $BG_YELLOW
  $BG_WHITE);

my $host     = "127.0.0.1";
my $port     = 29974;
my $commands = undef;
my $w        = 0;
my $h        = 0;
my $usecolor = 1;
my $sendsize = 1;
my $data     = '';
my $terminal = undef;
my $server   = undef;
my $select;
my $debug = 0;

##############################################################################
# END
#
# Clean up when the program exits (even if it 'dies').
##############################################################################
END {
    # Reset the terminal to it's normal behaviour
    ReadMode('normal');
    $terminal->Attr($ATTR_NORMAL) if defined $terminal;
}

##############################################################################
# main()
##############################################################################
ParseCommandLine();
PrepareTerminal();
ConnectToServer();
SendCommands();

while (1) {
    HandleTerminalResize();
    HandleServer();
    HandleKeys();
}

##############################################################################
# ParseCommandLine
#
# Processes command line arguments.
##############################################################################
sub ParseCommandLine {
    while ( my $param = shift @ARGV ) {
        if ( $param =~ m/^(-h|--help)$/ ) {
            ShowUsage();
            exit;
        }
        elsif ( $param =~ m/^(-s|--server)$/ ) {
            $host = GetValue($1);
        }
        elsif ( $param =~ m/^(-p|--port)$/ ) {
            $port = GetValue($1);
        }
        elsif ( $param =~ m/^(-c|--command)$/ ) {
            $commands = GetValue($1);
        }
        elsif ( $param =~ m/^(-d|--debug)$/ ) {
            $debug++;
        }
    }
}

##############################################################################
# PrepareTerminal
#
# Just some housekeeping to make the terminal behave as we need.
##############################################################################
sub PrepareTerminal {

    # Open a terminal object through which we can perform settings on the
    # terminal we are running in
    $terminal = new Term::ANSIScreen;

    # Make stdout not buffered
    my $old_fh = select(STDOUT);
    $| = 1;
    select($old_fh);

    # Change to 'cbreak' mode (no echo, but CTRL+C still operational)
    ReadMode('cbreak');
}

##############################################################################
# ConnectToServer
#
# Opens a connection to the Misterhouse server port.
##############################################################################
sub ConnectToServer {

    # Create a tcp connection to the specified host and port
    $server = IO::Socket::INET->new(
        Proto    => "tcp",
        PeerAddr => $host,
        PeerPort => $port
    );
    unless ($server) {
        print STDERR "Can't connect to port $port on $host: $!\n";
        exit;
    }

    $server->autoflush(1);

    $select = IO::Select->new($server);

    print STDERR "[Connected to $host:$port]\n";
}

##############################################################################
# SendCommands
#
# Sends commands passed to the program on the command line to the server.
# If the SIZE command is given then this size is taken as constant and no
# further SIZE updates are sent to the server, even when the terminal window
# is being resized.
##############################################################################
sub SendCommands {
    return unless defined $commands;

    foreach my $cmd ( split( /,/, $commands ) ) {
        $cmd =~ s/^\s+//;
        $cmd =~ s/\s+$//;

        if ( $cmd =~ m/^SIZE\s+(\d+)\s+(\d+)\s*$/i ) {
            ( $w, $h ) = ( $1, $2 );
            $sendsize = 0;
        }

        print $server "$cmd\n";
    }
}

##############################################################################
# HandleTerminalResize
#
# Updates the server whenever the terminal window has been resized.
##############################################################################
sub HandleTerminalResize {
    return unless $sendsize;

    my ( $new_w, $new_h ) = GetTerminalSize(*STDOUT);
    if ( defined $new_w and defined $new_h ) {
        if ( $new_w != $w or $new_h != $h ) {
            $w = $new_w;
            $h = $new_h;
            print $server "SIZE $w $h\n";
        }
    }
}

##############################################################################
# HandleServer
#
# Checks whether new commands have been received from the server. If so,
# they are processed immediately.
##############################################################################
sub HandleServer {
    foreach my $client ( $select->can_read(0.1) ) {
        my $newdata = '';

        my $rv = $client->recv( $newdata, BUFSIZE, 0 );
        $data .= $newdata;

        unless ( defined($rv) && length $newdata ) {
            close $server;
            exit;
        }

        while ( $data =~ s/(.*)\n// ) {
            ParseServerCommand($1);
        }

        # Flush the buffer if someone spams us with extra long lines...
        $data = '' if ( length($data) > BUFSIZE );
    }
}

##############################################################################
# HandleKeys
#
# Checks for pending keys and sends them to Misterhouse's terminal_menu.pl.
##############################################################################
sub HandleKeys {
    my $char;
    while ( defined( $char = GetChar() ) ) {
        if ( ord($char) == 27 && defined( $char = GetChar() ) ) {
            if ( $char eq '[' && defined( $char = GetChar() ) ) {
                my $ret = '';
                $ret = 'UP'    if $char eq 'A';
                $ret = 'DOWN'  if $char eq 'B';
                $ret = 'RIGHT' if $char eq 'C';
                $ret = 'LEFT'  if $char eq 'D';
                while ( defined( $char = GetChar() ) ) { }
                $char = $ret;
            }
            else {
                while ( defined( $char = GetChar() ) ) { }
            }
        }
        elsif ( ord($char) == 10 ) {
            $char = "ENTER";
        }

        $char =~ s/[^[:print:]]//g if defined $char;
        if ( defined $char ) {
            print $server "$char\n";
        }
    }
}

##############################################################################
# GetValue
#
# Retrieves a value for a command line parameter from the command line.
# Exits with an error message if no value is pending.
##############################################################################
sub GetValue {
    my $param = shift;

    my $value = shift @ARGV;
    if ( not defined $value ) {
        print STDERR "\n*** ERROR: Missing parameter for $param\n\n";
        ShowUsage();
        exit;
    }
    return $value;
}

##############################################################################
# ParseServerCommand
#
# Processes commands received from Misterhouse's terminal_menu.pl
##############################################################################
sub ParseServerCommand {
    my ($cmd) = @_;

    if ($debug) {
        printc( "$cmd\n", "" );
    }
    elsif ( $cmd =~ m/^getsize$/i ) {
        print $server "SIZE $w $h\n";
    }
    elsif ( $cmd =~ m/^clearscreen$/i ) {
        ClearScreen();
    }
    elsif ( $cmd =~ m/^cursorpos\s+(\d+)\s+(\d+)$/i ) {
        CursorPos( $1, $2 );
    }
    elsif ( $cmd =~ m/^print\s+\"(.*?)\"\s+\"(.*?)\"$/i ) {
        printc( $1, $2 );
    }
    elsif ( $cmd =~ m/^newline$/i ) {
        printc( "\n", "" );
    }
    elsif ( $cmd =~ m/^exit$/i ) {
        print STDERR "\n";
        exit;
    }

    # Better ignore wrong commands than polluting the terminal.
    # Can be enabled any time during debugging...

    #     else {
    #         print STDERR "\nUnknown command: \"$cmd\"\n";
    #     }
}

##############################################################################
# GetChar
#
# Gets a key in nonblocking mode
##############################################################################
sub GetChar {
    return ReadKey(-1);
}

##############################################################################
# ClearScreen
#
# Clears the screen. Duh...
##############################################################################
sub ClearScreen {
    $terminal->Attr($main::FG_WHITE);
    $terminal->Cls();
    $terminal->Cursor( 0, 0 );
}

##############################################################################
# CursorPos
#
# Positions the cursor at x,y.
##############################################################################
sub CursorPos {
    my ( $x, $y ) = @_;
    $terminal->Cursor( $x, $y );
}

##############################################################################
# printc
#
# Prints a given string in color
##############################################################################
sub printc {
    my ( $string, $color ) = @_;

    if ( $^O eq 'MSWin32' ) {
        $terminal->Attr( color2attr($color) );
    }
    else {
        $terminal->Attr($FG_WHITE);
        $terminal->Attr( color($color) );
    }
    $terminal->Write($string);
    $terminal->Display();
}

##############################################################################
# color2attr
#
# Converts a string conforming to the color specification of Term::ANSIColor
# into an attribute value understood by Win32::Console (which is indirectly
# loaded by Term::ANSIScreen).
# This is needed on Win32 platforms.
##############################################################################
sub color2attr {
    my ($colorstring) = @_;

    my $attr = $ATTR_NORMAL;

    my $fgcolor = undef;
    my $bgcolor = undef;
    my $reverse = 0;
    my $bold    = 0;

    foreach my $element ( split( /\s/, $colorstring ) ) {
        $fgcolor = $1
          if $element =~ m/^(black|cyan|blue|red|green|magenta|yellow|white)$/i;
        $bgcolor = $1
          if $element =~
          m/^on_(black|cyan|blue|red|green|magenta|yellow|white)$/i;
        $bold    = 1 if $element =~ m/^bold$/i;
        $reverse = 1 if $element =~ m/^reverse$/i;
    }

    if ( defined $fgcolor ) {
        $attr = $FG_BLACK if $fgcolor =~ m/^black$/i;
        $attr = ( $bold ? $FG_LIGHTCYAN : $FG_CYAN ) if $fgcolor =~ m/^cyan$/i;
        $attr = ( $bold ? $FG_LIGHTBLUE : $FG_BLUE ) if $fgcolor =~ m/^blue$/i;
        $attr = ( $bold ? $FG_LIGHTRED  : $FG_RED )  if $fgcolor =~ m/^red$/i;
        $attr = ( $bold ? $FG_LIGHTGREEN : $FG_GREEN )
          if $fgcolor =~ m/^green$/i;
        $attr = ( $bold ? $FG_LIGHTMAGENTA : $FG_MAGENTA )
          if $fgcolor =~ m/^magenta$/i;
        $attr = ( $bold ? $FG_LIGHTYELLOW : $FG_YELLOW )
          if $fgcolor =~ m/^yellow$/i;
        $attr = ( $bold ? $FG_LIGHTWHITE : $FG_WHITE )
          if $fgcolor =~ m/^white/i;
    }

    if ( defined $bgcolor ) {
        $attr += $BG_BLACK   if $bgcolor =~ m/^black$/i;
        $attr += $BG_CYAN    if $bgcolor =~ m/^cyan$/i;
        $attr += $BG_BLUE    if $bgcolor =~ m/^blue$/i;
        $attr += $BG_RED     if $bgcolor =~ m/^red$/i;
        $attr += $BG_GREEN   if $bgcolor =~ m/^green$/i;
        $attr += $BG_MAGENTA if $bgcolor =~ m/^magenta$/i;
        $attr += $BG_YELLOW  if $bgcolor =~ m/^yellow$/i;
        $attr += $BG_WHITE   if $bgcolor =~ m/^white/i;
    }

    $attr += $ATTR_INVERSE if ($reverse);

    return $attr;
}

##############################################################################
# ShowUsage
#
# Prints a brief explaination of how to use this program.
##############################################################################
sub ShowUsage {
    print STDERR <<EOT;
Client for Misterhouse's Terminal_Menu.
    
Usage: $0 [--server <server>] [--port <port>]
          [--command "<COMMAND1[,COMMAND2[...]]>"]
          [--help]

    --help           => Show this usage information.
    --server         => DNS name or IP of the computer to connect to.
                        Default: 127.0.0.1
    --port           => TCP/IP port that the terminal_menu.pl is running on.
                        Default: 29974
    --command        => Commands that are sent to the Terminal_Menu right
                        after startup. Allows configuration of colors, etc. 
                        If more than one command is given, seperate them 
                        with [,]. Note: don't forget to quote the command 
                        string properly!
                        See terminal_menu.pl for available commands.                      

EOT
}
