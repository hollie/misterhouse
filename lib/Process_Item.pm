
=head1 B<Process_Item>

=head2 SYNOPSIS

  my $slashdot_news = "$Pgm_Root/data/web/slashdot_news.txt";
  $p_slashdot_news = new Process_Item("get_slashdot_news > $slashdot_news");
  start $p_slashdot_news if time_now('6:30 AM');
  display $slashdot_news if done_now $p_slashdot_news;

  $p_report_weblog = new Process_Item;
  $p_report_weblog ->set_output("$config_parms{data_dir}/weblog_results.txt");
  if (time_now '2 AM') {
      set   $p_report_weblog "report_weblog /mh/data/logs/server.$Year_Month_Now.log";
      start $p_report_weblog;
  }

Example of multiple commands

  $test_process1 = new Process_Item;
  set $test_process1 'sleep 1', 'sleep 2';
  add $test_process1 'sleep 1';

Example of running an internal mh subroutine
  $v_test_ftp = new Voice_Cmd 'Test background ftp [get,put]';
  $p_test_ftp = new Process_Item;
  if ($state = said $v_test_ftp) {
    set $p_test_ftp "&main::net_ftp(file => '/tmp/junk1.txt', " . "file_remote => 'incoming/junk1.txt'," . "command => '$state')";
    set_timeout $p_test_ftpb 60*2;
    start $p_test_ftpb;
  }
  print_log "Ftp command done" if done_now $p_test_ftp;

More examples are in mh/code/examples/test_process.pl

=head2 DESCRIPTION

You can use this object to run external programs. On Win32 systems, the Win32::Process function is used. On Unix systems, the fork function is used. On either system, the following methods work in the same way:

=head2 INHERITS

B<>

=head2 METHODS

=over

=cut

use strict;

package Process_Item;

my ( @active_processes, @done_processes );

=item C<new('program1 arguments', 'program2 arguments', ...)>

=cut

sub new {
    my ( $class, @cmds ) = @_;
    my $self = {};
    &set( $self, @cmds ) if @cmds; # Optional.  Can be specified later with set.
    bless $self, $class;
    return $self;
}

=item C<set('program1 arguments', 'program2 arguments', ...)>

=cut

# Allow for multiple, serially executed, commands
sub set {
    my ( $self, @cmds ) = @_;
    @{ $$self{cmds} } = @cmds;
}

=item C<set_timeout($timeout)>

 Process will timeout after $timeout seconds

=cut

sub set_timeout {
    my ( $self, $timeout ) = @_;
    $$self{timeout} = $timeout;
}

=item C<set_output($output_file)>

Program STDOUT errata goes to $output_file

=cut

# Allow for process STDOUT to go to a file
sub set_output {
    my ( $self, $file ) = @_;
    $$self{output} = $file;
}

=item C<set_errlog($errlog_file)>

Program STDERR errata goes to $errlog_file

=cut

# Allow for process STDERR to go to a file
sub set_errlog {
    my ( $self, $file ) = @_;
    $$self{errlog} = $file;
}

sub set_killsig {
    my ( $self, $killsig ) = @_;
    $$self{killsig} = $killsig;
}

=item C<add('program3 arguments', 'program4 arguments', ...)>

If you specify more than one program, they are run sequentially.  done_now returns 1 after the last program is done.  If program starts with &, then 'program arguments' is eval-ed as an internal mh function.  Otherwise, 'program arguments' is run as an external command.  On Windows, the &-> eval trick is supposed to work with perl 5.6+ (which has fork), but unfortunately, it causes perl to crash often, so is probably not useful yet.

=cut

sub add {
    my ( $self, @cmds ) = @_;
    push @{ $$self{cmds} }, @cmds;
    print "\ndb add @cmds=@cmds.  total=@{$$self{cmds}}\n"
      if $main::Debug{process};
}

# This is called by mh on exit to save persistant data
sub restore_string {
    my ($self) = @_;

    return '' if $main::OS_win;    # we don't currently have a method to restore
                                   # Process_Item state in Windows

    my $restore_string = '';

    if ( $self->{cmds} and my $cmds = join( $;, @{ $self->{cmds} } ) ) {
        $cmds =~ s/\n/ /g;         # Avoid new-lines on restored vars
        $cmds =~ s/~/\\~/g;
        $restore_string .= '@{'
          . $self->{object_name}
          . "->{cmds}} = split(\$;, q~$cmds~) if (!exists("
          . $self->{object_name}
          . "->{cmds}));";
    }
    $restore_string .=
      $self->{object_name} . "->{cmd_index} = q~$self->{cmd_index}~;\n"
      if $self->{cmd_index};
    $restore_string .=
      $self->{object_name} . "->{timeout} = q~$self->{timeout}~;\n"
      if $self->{timeout};
    $restore_string .=
      $self->{object_name} . "->{output} = q~$self->{output}~;\n"
      if $self->{output};
    $restore_string .=
      $self->{object_name} . "->{errlog} = q~$self->{errlog}~;\n"
      if $self->{errlog};
    $restore_string .=
      $self->{object_name} . "->{killsig} = q~$self->{killsig}~;\n"
      if $self->{killsig};
    $restore_string .=
      $self->{object_name} . "->{started} = q~$self->{started}~;\n"
      if $self->{started};
    $restore_string .= $self->{object_name} . "->{pid} = q~$self->{pid}~;\n"
      if $self->{pid};
    $restore_string .= $self->{object_name} . "->restore_active();\n"
      if $self->{pid};
    return $restore_string;
}

sub get_set_by {
    return $_[0]->{set_by};
}

sub set_target {
    $_[0]->{target} = $_[1];
}

sub get_target {
    return $_[0]->{target};
}

=item C<start(OptionalArguements)>

Starts the process with optional program arguements

=cut

sub start {
    my ( $self, $cmd_override ) = @_;
    $$self{cmd_index} = 0;
    &start_next( $self, $cmd_override );
    $$self{target} = $main::Respond_Target
      if $main::Respond_Target;    # Pass default target along

    #   print "\ndb start total=@{$$self{cmds}}\n";
}

sub start_next {
    my ( $self, $cmd_override ) = @_;

    my ($cmd) = @{ $$self{cmds} }[ $$self{cmd_index} ];
    $$self{cmd_index}++;

    $cmd = $cmd_override if $cmd_override;

    # If $cmd starts with &, assume it is an internal function
    # that requires an eval.  perl abends fails with the new win32 fork :(
    my $type = ( substr( $cmd, 0, 1 ) eq '&' ) ? 'eval' : 'external';

    my ( $cmd_path, $cmd_args );

    if ( $type eq 'eval' ) {
        if ($main::OS_win) {
            my $msg =
              "Sorry, Process_Item eval fork only supported with linux.\n   cmd=$cmd";
            &main::print_log($msg);
            return;
        }
    }
    else {
        ( $cmd_path, $cmd_args ) =
          &main::find_pgm_path($cmd);    # From handy_utilities
        $cmd = "$cmd_path $cmd_args";
    }

    my ( $cflag, $pid );

    # Check to see if we have a previous 'start' to this object
    # has not finished yet.
    if ( $pid = $$self{pid} ) {
        print
          "Warning, a previous 'start' on this process has not finished yet\n";

        #        print "  The process will not be restarted:  cmd=$cmd\n";
        #        return;
        print "Killing unfinished process id $pid\n";
        &stop($self);
    }

    print "Process start: cmd_path=$cmd_path cmd=$cmd\n"
      if $main::Debug{process};

    # Store STDOUT to a file
    if ( $$self{output} ) {
        open( STDOUT_REAL, ">&STDOUT" )
          or print "Process_Item Warning, can not backup STDOUT: $!\n";
        open( STDOUT, ">$$self{output}" )
          or print
          "Process_Item Warning, can not open output file $$self{output}: $!\n";
        print STDOUT_REAL '';    # To avoid the "used only once" perl -w warning
    }

    # Store STDERR to a file
    if ( $$self{errlog} ) {
        open( STDERR_REAL, ">&STDERR" )
          or print "Process_Item Warning, can not backup STDERR: $!\n";
        open( STDERR, ">$$self{errlog}" )
          or print
          "Process_Item Warning, can not open errlog file $$self{errlog}: $!\n";
        print STDERR_REAL '';    # To avoid the "used only once" perl -w warning
    }

    if ( $main::OS_win and $type ne 'eval' ) {

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
        $cflag = 0;    # Avoid uninit warnings

        &Win32::Process::Create( $pid, $cmd_path, $cmd, 0, $cflag, '.' )
          or warn
          "Process_Item Warning, start Process error: cmd_path=$cmd_path\n -  cmd=$cmd   error=",
          Win32::FormatMessage( Win32::GetLastError() ), "\n";

        open( STDOUT, ">&STDOUT_REAL" ) if $$self{output};
        open( STDERR, ">&STDERR_REAL" ) if $$self{errlog};

        $$self{pid} = $pid;

        #       $pid->Wait(10000) if $run_mode eq 'inline'; # Wait for process
    }
    else {
        $pid = fork;
        if ($pid) {
            print "Process start: parent pid=$pid type=$type cmd=$cmd\n"
              if $main::Debug{process};
            open( STDOUT, ">&STDOUT_REAL" ) if $$self{output};
            open( STDERR, ">&STDERR_REAL" ) if $$self{errlog};
            $$self{pid} = $pid;
        }
        elsif ( defined $pid ) {
            print "Process start: child type=$type cmd=$cmd\n"
              if $main::Debug{process};
            if ( $type eq 'eval' ) {

                package main
                  ; # Had to do this to get the 'speak' function recognized without having to &main::speak() it
                eval $cmd;
                print "Process Eval results: $@\n";

                # Exit with a do nothing exec, rather than exit.
                # If we call exit, objects DESTROY methods get called and might
                # mess up the parent process (e.g. CM11 Serial_Port objects
                # have a DESTROY method that will close the port
                # which will then revert to its pre-mh values).
                # exec '' errors with 'do nothing exec failed' and the child
                # never dies, so use /bin/true.
                #               exit;
                #               exec '';
                #               exec '/bin/true';
                exec 'true';
                die "do nothing exec failed: $!";
            }
            else {
                # check if nice_level defined and if so, use it
                my $nice_level = $self->nice_level;
                if ( defined $nice_level ) {
                    print
                      "Process start: adjusting nice level to: $nice_level\n"
                      if $main::Debug{process};
                    exec "nice --adjustment=$nice_level $cmd_path $cmd_args";
                }
                else {
                    exec "$cmd_path $cmd_args";
                }
            }
            die "Error in start Process exec for cmd=$cmd\n";
        }
        else {
            print "Error in start Process fork for cmd=$cmd\n";
        }
    }
    push( @active_processes, $self );
    $$self{started} = time;
    $$self{runtime} = 0;
    undef $$self{timed_out};
    undef $$self{done};
}

sub restore_active {
    my ($self) = @_;
    push( @active_processes, $self );
}

=item C<done>

Returns the time (seconds since epoch) that the process finished.  If the process has been started, but has not yet finished, it returns 0.

=cut

sub done {
    my ($self) = @_;
    return ( $$self{pid} ) ? 0 : 1;
}

=item C<pid>

Returns the process id

=cut

sub pid {
    my ($self) = @_;
    return $$self{pid};
}

=item C<timed_out>

Returns the time when the process timed out.  done_now will still trigger for a timed_out process.

=cut

sub timed_out {
    my ($self) = @_;
    return ( $$self{timed_out} ) ? 1 : 0;
}

sub runtime {
    my ($self) = @_;
    return $$self{runtime};
}

=item C<done_now>

Is true for the pass that the process finished on.

=cut

sub done_now {
    $main::Respond_Target = $_[0]->{target};
    return $_[0]->{done_now};
}

# Check for processes that just finished
sub harvest {

    # Unset done_now flag from previous pass
    my $process;
    while ( $process = shift @done_processes ) {
        undef $$process{done_now};
    }

    my @active_processes2;
    my $time = time;
    for $process (@active_processes) {
        my $pid = $$process{pid};
        next unless $pid;    # In case somehow we already harvested his pid
                             # Check if process is done or timed out
        if ( defined $$process{timeout}
            and $time > ( $$process{timeout} + $$process{started} ) )
        {
            print
              "Process timed out process=$$process{object_name} pid=$pid cmd=@{$$process{cmds}} timeout=$$process{timeout}\n"
              if $main::Debug{process};
            $$process{timed_out} = $time;
            $process->stop();
        }
        $$process{runtime} = time - $$process{started};

        # For linux, we need to look in /proc/"pid" since if the process was started before the
        # last restart of misterhouse.  If the process was started before the last hard restart,
        # the process will not be a waiting child of misterhouse and will only appear in /proc.
        if (   ( $main::OS_win and $pid->Wait(0) )
            or
            ( !$main::OS_win and waitpid( $pid, 1 ) and !( -e "/proc/$pid" ) )
            or ( $$process{timed_out} ) )
        {
            # Mark as done or start the next cmd?
            if ( $$process{cmd_index} < @{ $$process{cmds} } ) {
                print
                  "Process starting next cmd process=$$process{object_name} pid=$pid index=$$process{cmd_index}\n"
                  if $main::Debug{process};
                delete $$process{pid};
                &start_next($process);
            }
            else {
                push( @done_processes, $process );
                $$process{done_now}++;
                $$process{done} = $time;
                delete $$process{pid};
                delete $$process{started};
                print
                  "Process done_now process=$$process{object_name} pid=$pid to=$$process{timed_out} cmd=@{$$process{cmds}}\n"
                  if $main::Debug{process};
            }
        }
        else {
            push( @active_processes2, $process );
        }
    }
    @active_processes = @active_processes2;
}

=item C<stop>

Stops the process. If called as a stand alone function (not as an object method), all active Process_Items are stopped.

=cut

sub stop {
    my @process_list = @_;

    # If none specified, kill em all!
    @process_list = @active_processes unless @process_list;

    for my $process (@process_list) {
        next if ref $process eq 'SCALAR';    # In case a non ref was passed in
        my $pid = $$process{pid};
        next unless $pid;
        $$process{runtime} = time - $$process{started};
        delete $$process{pid};
        delete $$process{started};
        print
          "\nKilling unfinished process id $pid for $process cmd @{$$process{cmds}}\n"
          if $main::Debug{process};
        if ($main::OS_win) {

            #           $pid->Suspend() or print "Warning 1, stop Process error:", Win32::FormatMessage( Win32::GetLastError() ), "\n";
            #           $pid->Resume() or print "Warning 1a, stop Process error:", Win32::FormatMessage( Win32::GetLastError() ), "\n";
            #           $pid->Wait(2) or print "Warning 1b, stop Process error:", Win32::FormatMessage( Win32::GetLastError() ), "\n";
            $pid->Kill(1)
              or print "Warning 2, stop Process error:",
              Win32::FormatMessage( Win32::GetLastError() ), "\n";
        }
        else {
            if ( defined $$process{killsig} ) {
                kill $$process{killsig}, $pid;
            }
            else {
                kill 9, $pid;
            }
        }
    }
}

# Not implemented yet
sub results {
    my ($self) = @_;
}

=item C<nice_level>

Support for setting "nice" level; only useful for *nix

=cut

sub nice_level {
    my ( $self, $nice_level ) = @_;
    $$self{nice_level} = $nice_level if defined $nice_level;
    if ( defined $$self{nice_level} ) {
        return $$self{nice_level};
    }
    elsif ( defined $main::config_parms{process_nice_level} ) {
        return $main::config_parms{process_nice_level};
    }
    else {
        return undef;
    }
}

=item C<get_type()>

Returns the class (or type, in Misterhouse terminology) of this item.

=cut

sub get_type {
    return ref $_[0];
}

#
# $Log: Process_Item.pm,v $
# Revision 1.30  2005/10/02 23:53:39  winter
# *** empty log message ***
#
# Revision 1.29  2005/01/23 23:21:45  winter
# *** empty log message ***
#
# Revision 1.28  2004/11/22 22:57:26  winter
# *** empty log message ***
#
# Revision 1.27  2004/04/25 18:19:57  winter
# *** empty log message ***
#
# Revision 1.26  2004/03/23 01:58:08  winter
# *** empty log message ***
#
# Revision 1.25  2003/11/23 20:26:01  winter
#  - 2.84 release
#
# Revision 1.24  2003/09/02 02:48:46  winter
#  - 2.83 release
#
# Revision 1.23  2003/07/06 17:55:11  winter
#  - 2.82 release
#
# Revision 1.22  2003/02/08 05:29:23  winter
#  - 2.78 release
#
# Revision 1.21  2003/01/12 20:39:20  winter
#  - 2.76 release
#
# Revision 1.20  2002/12/24 03:05:08  winter
# - 2.75 release
#
# Revision 1.19  2002/07/01 22:25:28  winter
# - 2.69 release
#
# Revision 1.18  2002/05/28 13:07:51  winter
# - 2.68 release
#
# Revision 1.17  2002/03/02 02:36:51  winter
# - 2.65 release
#
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

=back

=head2 INI PARAMETERS

NONE

=head2 AUTHOR

UNK

=head2 SEE ALSO

NONE

=head2 LICENSE

This program is free software; you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation; either version 2 of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more details.

You should have received a copy of the GNU General Public License along with this program; if not, write to the Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.

=cut
