use strict;

package Process_Item;

my (@active_processes, @done_processes);

sub new {
    my ($class, @cmds) = @_;
    my $self = {};
    &set($self, @cmds) if @cmds;  # Optional.  Can be specified later with set.
    bless $self, $class;
    return $self;
}

                                # Allow for multiple, serially executed, commands
sub set {
    my ($self, @cmds) = @_;
    @{$$self{cmds}} = @cmds;
}

                                # Allow for process STDOUT to go to a file
sub set_output {
    my ($self, $file) = @_;
    $$self{output} = $file;
}

sub add {
    my ($self, @cmds) = @_;
    push @{$$self{cmds}}, @cmds;
    print "\ndb add @cmds=@cmds.  total=@{$$self{cmds}}\n";
}

                                # This is called by mh on exit to save persistant data
sub restore_string {
    return;
}


sub start {
    my ($self) = @_;
    $$self{cmd_index} = 0;
    &start_next($self);
#   print "\ndb start total=@{$$self{cmds}}\n";
}

sub start_next {
    my ($self) = @_;

    my ($cmd) = @{$$self{cmds}}[$$self{cmd_index}];
    $$self{cmd_index}++;

                                # If $cmd starts with &, assume it is an internal function
                                # that requires an eval.  perl abends fails with the new win32 fork :(
    my $type = (substr($cmd, 0, 1) eq '&') ? 'eval' : 'external';

    my ($cmd_path, $cmd_args);

    if ($type eq 'eval') {
        if ($main::OS_win and ($ENV{sourceExe} or &Win32::BuildNumber() < 600)) {
            my $msg = "Sorry, Process_Item eval fork only supported with windows perl build 5.6 or later.\n   cmd=$cmd";
            print "$msg\n";
            &main::print_log($msg);
            return;
        }
    }
    else {
        ($cmd_path, $cmd_args) = &main::find_pgm_path($cmd); # From handy_utilities
        $cmd = "$cmd_path $cmd_args";
    }

    my ($cflag, $pid);
                                # Check to see if we have a previous 'start' to this object
                                # has not finished yet.
    if ($$self{pid}) {
        print "Warning, a previous 'start' on this process has not finished yet\n";
        print "  The process will not be restarted:  cmd=$cmd\n";
        return;
    }

    print "Process start: cmd_path=$cmd_path cmd=$cmd\n" if $main::config_parms{debug} eq 'process';

                                # Store STDOUT to a file
    if ($$self{output}) {
        open( STDOUT_REAL, ">&STDOUT" )        or print "Process_Item Warning, can not backup STDOUT: $!\n";
        open( STDOUT,      ">$$self{output}" ) or print "Process_Item Warning, can not open output file $$self{output}: $!\n";
        print STDOUT_REAL '';   # To avoid the "used only once" perl -w warning
    }

    if ($main::OS_win and $type ne 'eval') {
                                # A blank cflag will result in stdout to mh window. 
                                # Also, this runs beter, without as much problem with 'out ov env space' problems.
                                # Also, with DETACH, console window is generated and it does not close, so 'done' does not work.
                                #  ... unless we run with command /c pgm
                                # But, with a blank cflag, we can not Kill hung processes on exit :(
                                # UNLESS we run our process with perl, rather then command.com (perl get_url instead of get_url.bat)
                                # So, we make sure that cmd_path is not a bat file (done in find_pgm_path above)
                                # This also enables set_output to work ok (with a bat file that call perl, it comes up empty).
                                # Got all that :)
#       use Win32::Process;
#       $cflag = CREATE_NEW_CONSOLE;
#       $cflag = DETACHED_PROCESS || CREATE_NEW_CONSOLE;
#       $cflag = DETACHED_PROCESS;
#       $cflag = NORMAL_PRIORITY_CLASS;
        $cflag = 0;             # Avoid uninit warnings

        &Win32::Process::Create($pid, $cmd_path, $cmd, 0, $cflag , '.') or
            warn "Process_Item Warning, start Process error: cmd_path=$cmd_path\n -  cmd=$cmd   error=", Win32::FormatMessage( Win32::GetLastError() ), "\n";
        
        open( STDOUT, ">&STDOUT_REAL" ) if $$self{output};

        $$self{pid} = $pid;
#       $pid->Wait(10000) if $run_mode eq 'inline'; # Wait for process
    }
    else {
        $pid = fork;
        if ($pid) {
            print "Process start: parent pid=$pid type=$type cmd=$cmd\n" if $main::config_parms{debug} eq 'process';
            open( STDOUT, ">&STDOUT_REAL" ) if $$self{output};
            $$self{pid} = $pid;
        }
        elsif (defined $pid) {
            print "Process start: child type=$type cmd=$cmd\n" if $main::config_parms{debug} eq 'process';
            if ($type eq 'eval') {
                package main;   # Had to do this to get the 'speak' function recognized without having to &main::speak() it
                eval $cmd;
                print "Process Eval results: $@\n";
                                # Exit with a do nothing exec, rather than exit.
                                # If we call exit, objects DESTROY methods get called and might 
                                # mess up the parent process (e.g. CM11 Serial_Port objects
                                # have a DESTROY method that will close the port
                                # which will then revert to its pre-mh values).
#               exit;
                exec '';
            }
            else {
                exec "$cmd_path $cmd_args";
            }
            die "Error in start Process exec for cmd=$cmd\n";
        }
        else {
            print "Error in start Process fork for cmd=$cmd\n";
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

                                # Mark as done or start the next cmd?
            if ($$process{cmd_index} < @{$$process{cmds}}) {
                print "Process starting next cmd process=$process pid=$pid index=$$process{cmd_index}\n";
                delete $$process{pid};
                &start_next($process);
            }
            else {
                push(@done_processes, $process);
                $$process{done_now}++;
                $$process{done} = time;
                delete $$process{pid};
                print "Process done_now process=$process pid=$pid cmd=@{$$process{cmds}}\n" if $main::config_parms{debug} eq 'process';
            }
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
        print "\nKilling unfinished process id $pid for $process cmd @{$$process{cmds}}\n";
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
# Revision 1.16  2001/05/28 21:14:38  winter
# - 2.52 release
#
# Revision 1.15  2001/03/24 18:08:38  winter
# - 2.47 release
#
# Revision 1.14  2001/02/04 20:31:31  winter
# - 2.43 release
#
# Revision 1.13  2000/12/21 18:54:15  winter
# - 2.38 release
#
# Revision 1.12  2000/10/01 23:29:40  winter
# - 2.29 release
#
# Revision 1.11  2000/09/09 21:19:11  winter
# - 2.28 release
#
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
