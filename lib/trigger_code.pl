
=pod

=head1 NAME

trigger_code.pl - Misterhouse's trigger code

=head1 DESCRIPTION

This file contains code that implements Misterhouse's trigger functionality.
Monitors trigger code, used by code like tv_grid and the web alarm page,
that specifies events that trigger actions.  View, add, modify, or
delete triggers with http://localhost:8080/bin/triggers.pl
(also under the ia5 MrHouse Home button).

You can create triggers to easily run mh code on specified events. 
When you create a trigger with trigger_set, mh will create or modify 
the code_dir/triggers.mhp file.

=cut

# $Date$
# $Revision$

use strict;

use vars '%triggers';    # use vars so we can use in the web server

my ( $trigger_write_code_flag, $prev_triggers, $prev_script );
my $trigger_file = "$::config_parms{data_dir}/triggers.current";
my $expired_file = "$::config_parms{data_dir}/triggers.expired";
my $script_file  = "$::Code_Dirs[0]/triggers.mhp";

&::MainLoop_pre_add_hook( \&_triggers_loop, 1 );
&::Exit_add_hook( \&_triggers_save, 1 );
$prev_triggers = &file_read($trigger_file) if -e $trigger_file;
$prev_script   = &file_read($script_file)  if -e $script_file;
&_triggers_read if -e $trigger_file;
&_trigger_write_code;

sub _triggers_loop {
    &_triggers_save if $trigger_write_code_flag or ( $New_Hour and %triggers );
    &_trigger_write_code if $trigger_write_code_flag;
}

# Read current triggers file at startup
sub _triggers_read {
    return unless -e $trigger_file;

    my $i = 0;
    undef %triggers;

    my ( $trigger, $code, $name, $type, $triggered );
    for my $record ( &file_read($trigger_file), '' ) {
        if ( $record =~ /\S/ ) {
            next if $record =~ /^ *#/;
            if ( $record =~ /^name=(.+?)\s+type=(\S+)\s+triggered=(\d*)/ ) {
                $name      = $1;
                $type      = $2;
                $triggered = $3;
            }
            elsif ( !$trigger ) {
                $trigger = $record;
            }
            else {
                # Old trigger format ... ignore
                next if $record =~ /^\d+ \d+$/;
                $code .= $record . "\n";
            }
        }

        # Assume there is always a blank line at end of file
        elsif ($trigger) {
            trigger_set( $trigger, $code, $type, $name, 1, $triggered );
            $trigger = $code = $name = $type = $triggered = '';
            $i++;
        }
    }
    print " - read $i trigger entries\n";
}

# Save and prune out week old expired triggers
sub _triggers_save {
    my ( $data, $data1, $data2, $i1, $i2 );
    $i1    = $i2    = 0;
    $data1 = $data2 = '';
    foreach my $name ( trigger_list() ) {
        my ( $trigger, $code, $type, $triggered ) = trigger_get($name);
        next unless $trigger;
        $data = "name=$name type=$type triggered=$triggered\n";
        $data .= $trigger . "\n";
        $data .= $code . ";\n";

        # Prune it out if it is expired and > 1 week old
        if ( trigger_expired($name)
            and ( $triggers{$name}{triggered} + 60 * 60 * 24 * 7 ) < $Time )
        {
            $data2 .= $data . "\n";
            $i2++;
            trigger_delete($name);
        }
        else {
            $data1 .= $data . "\n";
            $i1++;
        }
    }
    if ($data) {
        print_log "triggers_save: $i2 expired, $i1 saved"
          if $i2
          or $Debug{'trigger'};
        $data1 = '#
# Note: Do NOT edit this file while mh is running (edits will be lost).
# It is used by mh/lib/trigger_code.pl to auto-generate code_dir/triggers.mhp.
# It is updated by various trigger_ functions like trigger_set.
# If Misterhouse will not start because of a code error in this file, fix the
# error here, remove triggers.mhp, and restart Misterhouse.
#
# Syntax is:
#   name=trigger name  type=trigger_type  triggered=triggered_time
#   trigger_clause
#     code_to_run
#     code_to_run
#
# Expired triggers will be pruned to triggers.expired a week after they expire.
#
' . $data1;
        $data2 = "# Expired on $Time_Date\n" . $data2 if $data2;
        if ( $data1 eq $prev_triggers ) {
            print_log "triggers_save: no triggers changed" if $Debug{'trigger'};
        }
        else {
            &file_write( $trigger_file, $data1 );
            &logit( $expired_file, $data2, 0 ) if $data2;
            $trigger_write_code_flag++;
        }
        $prev_triggers = $data1;
    }
    else {
        print_log "triggers_save: no triggers to write" if $Debug{'trigger'};
        if ( -e $trigger_file ) {
            $trigger_write_code_flag = 1;
            unlink $trigger_file;
            $trigger_write_code_flag++;
        }
        $prev_triggers = "";
        return;
    }
}

# Write trigger code if changed
sub _trigger_write_code {
    $trigger_write_code_flag = 0;
    my $script;
    foreach my $name ( trigger_list() ) {
        my ( $trigger, $code, $type, $triggered, $trigger_error, $code_error ) =
          trigger_get($name);
        next unless $trigger;
        next if $trigger_error;

        # don't include expired or disabled triggers in script
        next unless $type eq 'NoExpire' or $type eq 'OneShot';
        $script .= "\n# name=$name type=$type\n";
        $script .= "if (($trigger) and &trigger_active('$name')) {\n";
        $script .= "    # FYI trigger code: $code;\n";
        $script .= "    &trigger_run('$name',1);\n}\n";
    }
    if ($script) {
        $script = "#
# You shouldn't edit this file.  This file is auto-generated by
# mh/lib/trigger_code.pl.
# If there are syntax errors here, you should delete this file and edit
# $::config_parms{data_dir}/triggers.current.  This file will be recreated 
# when Misterhouse is next started.
#
" . $script;
        print_log "trigger_write_code: this sub was called, but triggers"
          . " not changed", return
          if $script eq $prev_script;
        $prev_script = $script;
        &file_write( $script_file, $script );

        # Replace (faster) or reload (if there was no file previously)
        if ( $main::Run_Members{'triggers_table'} ) {
            print_log "trigger_write_code: trigger script $script_file"
              . " written, running do_user_file"
              if $Debug{'trigger'};
            &do_user_file("$::Code_Dirs[0]/triggers.mhp");
        }
        else {
            # Must be done before the user code eval
            print_log "trigger_write_code: trigger script $script_file"
              . " written, running read_code"
              if $Debug{'trigger'};
            push @Nextpass_Actions, \&read_code;
        }
    }
    else {
        print_log "trigger_write_code: no script to write" if $Debug{'trigger'};
        if ( -e $script_file ) {

            # reload on next pass if we remove trigger script
            push @Nextpass_Actions, \&read_code;
            unlink $script_file if -e $script_file;   # don't write empty script
        }
        $prev_script = "";
        return;
    }
}

=head1 SUBROUTINES

=over 4

=item C<trigger_set(event, code, type, name, replace, triggered, new_name)>

Creates or modified an existing trigger.  Only event and code are
required.  The code will run when event returns true.
The type defaults to OneShot (see below) and $name
will default to a unique auto-generated name.  If name is specified
and already exists, name will be incremented, unless replace=1.
triggered is the last time the trigger ran in epoch second.  

If new_name is specified, trigger name is renamed to new_name and the other
arguments are applied.

The event string is evaluated to check for errors and the trigger doesn't
run any are found.  The code is always run in an eval, so Misterhouse
won't crash if you type an error.

Examples:

      &trigger_set("time_now '$date $time - 00:02'",
        "speak 'Something cool happens in 2 minutes'");
  
      &trigger_set("time_now '$Save{wakeup_time}'",
        "speak 'Time to wake up'", "NoExpire", "Wakeup Trigger", 1);

Another example of using triggers is in mh/code/common/tv_grid.pl.

Here are the valid trigger types:

    OneShot  => The trigger will run once, then changed type to Expired
  
    Expired  => Will be pruned from the triggers.mhp file after one week
                and archived in data_dir/triggers.expired.
  
    NoExpire => Runs on every event and never expires.
  
    Disabled => Will stay in your triggers.mph file, but will not run.

=cut

# this routine does the heavy lifting re modifying, renaming, copying triggers
sub trigger_set {
    my ( $trigger, $code, $type, $name, $replace, $triggered, $new_name ) = @_;

    return unless $trigger and $code;
    $trigger =~ s/[;\s\r\n]*$//g;   # in case trigger file was edited on windows
    $code    =~ s/[;\s\r\n]*$//g;   # So we can consistenly add ;\n when used
    $triggered = 0         unless $triggered;
    $type      = 'OneShot' unless $type;

    # Give it a name if missing
    $name = time_date_stamp(12) unless $name;

    if ( exists $triggers{$name} and $replace ) {
        print_log "trigger $name already exists, modifying"
          if $Debug{'trigger'};
    }

    # Find a uniq name if copying
    elsif ( exists $triggers{$name} ) {
        $name =~ s/ \d+$//;
        my $i = 2;
        while ( exists $triggers{"$name $i"} ) { $i++; }
        print_log "trigger $name already exists, adding '$i' to name";
        $name = "$name $i";
    }
    print_log "trigger_set: trigger=$trigger code=$code type=$type name=$name
      replace=$replace triggered=$triggered new_name=$new_name"
      if $Debug{'trigger'};

    # Flag an error if trigger is bad, can't test code here without running it
    eval $trigger;
    if ($@) {
        $triggers{$name}{'trigger_error'} = $@;
        &print_log("Error: trigger '$name' has an error, disabling");
        &print_log("  Code = $trigger");
        &print_log("  Result = $@");
    }
    else {
        delete $triggers{$name}{'trigger_error'};
    }

    $triggers{$name}{trigger}   = $trigger;
    $triggers{$name}{code}      = $code;
    $triggers{$name}{triggered} = $triggered;
    $triggers{$name}{type}      = $type;

    if ( $new_name and $new_name ne $name ) {
        $triggers{$new_name} = $triggers{$name};
        delete $triggers{$name};
    }

    $trigger_write_code_flag++ unless $Reload;
    return;
}

=item C<trigger_get(name}>

Returns the event, code, type, last triggered time, event error (if any),
and code error (if any) of the specified trigger.

=cut

sub trigger_get {
    my $name = shift;
    return 0 unless exists $triggers{$name};
    return 1 unless wantarray;
    return $triggers{$name}{trigger}, $triggers{$name}{code},
      $triggers{$name}{type},          $triggers{$name}{triggered},
      $triggers{$name}{trigger_error}, $triggers{$name}{code_error};
}

=item C<trigger_delete(name}>

Deletes the specified trigger.

=cut

sub trigger_delete {
    my $name = shift;
    return unless exists $triggers{$name};
    delete $triggers{$name};
    $trigger_write_code_flag++;
    return;
}

=item C<trigger_copy(name}>

Copies the specified trigger, the new name has a sequential number appended
to the old name.

=cut

sub trigger_copy {
    my $name      = shift;
    my $trigger   = $triggers{$name}{trigger};
    my $code      = $triggers{$name}{code};
    my $type      = $triggers{$name}{type};
    my $replace   = 0;
    my $triggered = 0;
    trigger_set( $trigger, $code, $type, $name, $replace, $triggered );
    return;
}

sub trigger_rename {
    my ( $name, $new_name ) = @_;
    return unless exists $triggers{$name};
    my $trigger   = $triggers{$name}{trigger};
    my $code      = $triggers{$name}{code};
    my $type      = $triggers{$name}{type};
    my $replace   = 1;
    my $triggered = $triggers{$name}{triggerd};
    trigger_set( $trigger, $code, $type, $name, $replace, $triggered,
        $new_name );
    return;
}

sub trigger_set_trigger {
    my $name = shift;
    return unless exists $triggers{$name};
    my $trigger   = shift;
    my $code      = $triggers{$name}{code};
    my $type      = $triggers{$name}{type};
    my $replace   = 1;
    my $triggered = $triggers{$name}{triggered};
    trigger_set( $trigger, $code, $type, $name, $replace, $triggered );
    return;
}

sub trigger_set_code {
    my $name = shift;
    return unless exists $triggers{$name};
    my $trigger   = $triggers{$name}{trigger};
    my $code      = shift;
    my $type      = $triggers{$name}{type};
    my $replace   = 1;
    my $triggered = $triggers{$name}{triggered};
    trigger_set( $trigger, $code, $type, $name, $replace, $triggered );
    return;
}

sub trigger_set_type {
    my $name = shift;
    return unless exists $triggers{$name};
    my $trigger   = $triggers{$name}{trigger};
    my $code      = $triggers{$name}{code};
    my $type      = shift;
    my $replace   = 1;
    my $triggered = $triggers{$name}{triggered};
    trigger_set( $trigger, $code, $type, $name, $replace, $triggered );
    return;
}

sub trigger_expire {
    my $name = shift;
    return
      unless exists $triggers{$name} and $triggers{$name}{type} eq 'OneShot';
    my $trigger   = $triggers{$name}{trigger};
    my $code      = $triggers{$name}{code};
    my $type      = 'Expired';
    my $replace   = 1;
    my $triggered = $Time;
    trigger_set( $trigger, $code, $type, $name, $replace, $triggered );
    return;
}

sub trigger_run {
    my ( $name, $expire ) = @_;
    if ( !exists $triggers{$name} ) {
        &print_log("trigger_run: trigger '$name' does not exist");
        return;
    }
    my ( $trigger, $code, $type, $triggered ) = trigger_get($name);
    &print_log("trigger_run: running trigger code for: $name")
      if $Debug{trigger};
    trigger_set( $trigger, $code, $type, $name, 1, $Time );
    eval $code;
    if ($@) {
        &print_log("Error: trigger '$name' failed to run cleanly");
        &print_log("  Code = $code");
        &print_log("  Result = $@");

        # At this point we could opt to disable the trigger
        # but it is likely more useful to have a repeating error message
        # to let the user know that something is wrong
        # The following hash entry allows us to show the error in the
        #  web interface
        $triggers{$name}{code_error} = $@;
    }
    else {
        delete $triggers{$name}{code_error};
    }
    &print_log("trigger_run: finished running trigger code for: $name")
      if $Debug{trigger};
    &trigger_expire($name) if $expire;
    return;
}

=item C<trigger_list>

Returns a list of trigger names.

=cut

sub trigger_list {
    return sort keys %triggers;
}

=item C<trigger_active(name)>

Returns true if the trigger is active.

=cut

sub trigger_active {
    my $name = shift;
    return (
        exists $triggers{$name} and ( $triggers{$name}{type} eq 'NoExpire'
            or $triggers{$name}{type} eq 'OneShot' )
          and ( not exists $triggers{$name}{'trigger_error'} )
    );
}

=item C<trigger_expired(name)>

Returns true if the trigger is expired.

=cut

sub trigger_expired {
    my $name = shift;
    return ( exists $triggers{$name} and $triggers{$name}{type} eq 'Expired' );
}

1;
