use strict;

package Process_Item;

my (@active_processes, @done_processes);

sub new {
    my ($class, $cmd) = @_;
    my $self = {};
    &set($self, $cmd) if $cmd;  # Optional.  Can be specified later with set.
    bless $self, $class;
    return $self;
}

sub set {
    my ($self, $cmd) = @_;

    my($cmd_path, $cmd_args) = &main::find_pgm_path($cmd); # From handy functions

    $$self{cmd} = "$cmd_path $cmd_args";
    $$self{cmd_path} = $cmd_path;
    $$self{cmd_args} = $cmd_args;
}

sub start {
    my ($self, $run_mode) = @_;
    my $cmd = $$self{cmd};
    my ($cflag, $pid);
                                # Check to see if we have a previous 'start' to this object
                                # has not finished yet.
    if ($$self{pid}) {
        print "Warning, a previous 'start' on this process has not finished yet\n";
        print "  The process will not be restarted:  cmd=$cmd\n";
        return;
    }
    if ($main::OS_win) {
                                # A blank cflag will result in stdout to mh window. 
                                # Also, this runs beter, without as much problem with 'out ov env space' problems.
                                # Also, with DETACH, console window is generated and it does not close, so 'done' does not work.
                                #  ... unless we run with command /c pgm
                                # But, with a blank cflag, we can not Kill hung processes on exit :(
                                # UNLESS we run our process with perl, rather then command.com (perl get_url instead of get_url.bat)
                                # So, we make sure that cmd_path is not a bat file (done in find_pgm_path above)
                                # Got all that :)
#       use Win32::Process;
#       $cflag = CREATE_NEW_CONSOLE;
#       $cflag = DETACHED_PROCESS || CREATE_NEW_CONSOLE;
#       $cflag = DETACHED_PROCESS;
#       $cflag = NORMAL_PRIORITY_CLASS;

        print "Process start: pid=$pid cmd_path=$$self{cmd_path} cmd=$cmd\n" if $main::config_parms{debug};

        &Win32::Process::Create($pid, $$self{cmd_path}, $cmd, 0, $cflag , '.') or
            print "Warning, start Process error: cmd_path=$$self{cmd_path}\n -  cmd=$cmd   error=", Win32::FormatMessage( Win32::GetLastError() ), "\n";

        $$self{pid} = $pid;
        $pid->Wait(10000) if $run_mode eq 'inline'; # Wait for process
    }
    else {
        $pid = fork;
        if ($pid) {
            print "Process done: parent pid=$pid cmd=$cmd\n" if $main::config_parms{debug};
            $$self{pid} = $pid;
        }
        elsif (defined $pid) {
            print "Process start: cmd=$cmd\n" if $main::config_parms{debug};
            exec "$$self{cmd_path} $$self{cmd_args}";
            die "Error in start Process exec for cmd=$$self{cmd}\n";
        }
        else {
            print "Error in start Process fork for cmd=$$self{cmd}\n";
        }
    }
    push(@active_processes, $self);
    $$self{started} = time;
    undef $$self{done};
}    

sub done {
    my ($self) = @_;
    return ($$self{pid}) ? 0 : 1;
}    

sub done_now {
    return $_[0]->{done_now};
}    

                                # Check for processes that just finished
sub harvest {
                                # Unset done_now flag from previous pass
    my $process;
    while ($process = shift @done_processes) {
        undef $$process{done_now};
    }

    my @active_processes2;
    for $process (@active_processes) {
        my $pid = $$process{pid};
        next unless $pid;       # In case somehow we already harvested his pid
        if (($main::OS_win and $pid->Wait(0)) or 
            (!$main::OS_win and waitpid($pid, 1))) {
            push(@done_processes, $process);
            $$process{done_now}++;
            $$process{done} = time;
            delete $$process{pid};
            print "Process done_now process=$process pid=$pid cmd=$$process{cmd}\n" if $main::config_parms{debug};
        }
        else {
            push(@active_processes2, $process);
        }
    }
    @active_processes = @active_processes2;
}

sub stop {
    my @process_list  = @_;
                                # If none specified, kill em all!
    @process_list = @active_processes unless @process_list;
    
    for my $process (@active_processes) {
        my $pid = $$process{pid};
        next unless $pid;
        delete $$process{pid};
        print "\nKilling unfinished process id $pid for $process cmd $$process{cmd}\n";
        if ($main::OS_win) {
#           $pid->Suspend() or print "Warning 1, stop Process error:", Win32::FormatMessage( Win32::GetLastError() ), "\n";
#           $pid->Resume() or print "Warning 1a, stop Process error:", Win32::FormatMessage( Win32::GetLastError() ), "\n";
#           $pid->Wait(2) or print "Warning 1b, stop Process error:", Win32::FormatMessage( Win32::GetLastError() ), "\n";
            $pid->Kill(1) or print "Warning 2, stop Process error:", Win32::FormatMessage( Win32::GetLastError() ), "\n";
        }
        else {
            kill 9, $pid;
        }
    }
}

                                # Not implemented yet
sub results {
    my ($self) = @_;
}    


#
# $Log$
# Revision 1.10  2000/08/19 01:22:36  winter
# - 2.27 release
#
# Revision 1.9  2000/03/10 04:09:01  winter
# - Add Ibutton support and more web changes
#
# Revision 1.8  2000/01/27 13:42:24  winter
# - update version number
#
# Revision 1.7  1999/08/30 00:22:58  winter
# - add set method
#
# Revision 1.6  1999/04/29 12:26:05  winter
# - check for duplicate $pid on create, and existing pid on kill exit
#
# Revision 1.5  1999/03/28 00:33:16  winter
# - Do not use Win32 for process flags (not needed)
#
# Revision 1.4  1999/03/21 17:35:23  winter
# - add call to find_pgm_path, to fix kill on exit problem with .bat files.
#
# Revision 1.3  1999/03/12 04:29:45  winter
# - add warning about windows kill not working
#
# Revision 1.2  1999/02/21 02:15:55  winter
# - store cmd_args, so we can use cmd_path in unix fork
#
# Revision 1.1  1999/02/21 00:23:44  winter
# - created
#
#

1;
