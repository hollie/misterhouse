package Insteon;

use strict;

# Category=Insteon

#@ This module creates voice commands for all insteon related items.

=head1 B<Insteon>

=head2 DESCRIPTION

Provides the basic infrastructure for the Insteon stack, contains many of the 
startup routines.

=head2 INHERITS

None

=head2 VOICE COMMANDS

=head3 PLM

=over

=item C<Complete Linking as Responder>

If a device is first placed into linking mode, calling this command will cause
the PLM to complete the link, thus making the PLM the responder.  The 
C<Link To Interface> device voice command is likely an easier way to do this, 
but this may be need for hard to reach devices or deaf devices.

=item C<Initiate Linking as Controller>

Call this first, then press and hold the set button on a device that you wish
to have the PLM control.  The C<Link To Interface> device voice command is 
likely an easier way to do this, but this may be need for hard to reach devices 
or deaf devices.  This is also needed for i2cs devices in which the first link
must currently be manually created this way.

=item C<Cancel Linking>

Cancel either of the above two commands without completing a link.

=item C<Delete Link with PLM>

This does nothing and shoudl be removed.

=item C<Scan Link Table>

This will scan and output to the log only the PLM link table.

=item C<Log Links>

This will output only the PLM link table to log.

=item C<Delete Orphan Links>

Misterhouse will review the state of all of the links in your system, as it knows
them without any additional scanning.  If any of these links are not defined in
your mht file or the links are only half links (controller with no responder or
vice versa) MisterHouse will delete these links.

It is usually best to:

1. Run C<Scan Changed Device Link Tables> first unless you know that the
information in MisterHouse is up-to-date.

2. Run C<AUDIT Sync All Links> and verify that what is being added is correct.

3. Run C<Sync All Links> to add the links

4. Run C<AUDIT Delete Orphan Links> first to see what will happen.

5. If everything looks right, run C<Delete Orphan Links> to clean up the old links

Deleting the orphan links will make your devices happier.  If you have unintended
links on your devices, they can run slower and may unnecessarily increase the 
number of messages sent on your network.

B<Note:> This command will not run on deaf devices such as motion sensors or
remotelincs.  These devices need to be "awake" to receive commands.  So please
run this same command on deaf devices directly.

=item C<AUDIT Delete Orphan Links>

Does the same thing as C<Delete Orphan Links> but doesn't actually delete anything
instead it just prints what it would have done to the log.

=item C<Scan All Device Link Tables>

Scans the link tables of the PLM and all devices on your network.  On a large
network this can take sometime.  You can generally run C<Scan Changed Device Link Tables>
which is much faster without any issue.

=item C<Scan Changed Device Link Tables>

Scans the link tables of the PLM and all devices whose link tables have changed
on your network.

=item C<Sync All Links>

Similar to C<Delete Orphan Links> exccept this adds any links that are missing.
This is helpful when adding a bunch of new devices, new scenes, or cleaning things
up.

See the workflow described in C<Delete Orphan Links>.

B<Note:> This command will not run on deaf devices such as motion sensors or
remotelincs.  These devices need to be "awake" to receive commands.  So please
run this same command on deaf devices directly.

=item C<AUDIT Sync All Links>

Same as C<Sync All Links> but prints what it would do to the log, without doing
anything else.

=item C<print all message stats>

Prints the message stats for all devices plus a summary of the entire network
stats.  For full details on what is contained in this printout please see
the description for the C<print message stats> voice command under the device
heading below.

=item C<reset all message stats>

Resets all the message stats for all devices including the Unk_Error stat.

=item C<stress test All devices>

Performs a 5 count stress test on all devices on the network.  See the description
of what a stress test is under the device voice commands.

=item C<ping test All devices>

Performs a 5 count ping test on all devices on the network.  See the description
of what a ping test is under the device voice commands.

=item C<Log All Device ALDB Status>

Logs some details about each device to the log.  See C<log_all_ADLB_status()>

=back

=item C<Enable Monitor Mode>

Places the PLM into "Monitor Mode."  The documentation is a little unclear on
what this does.  In practice, this enables the PLM to receive B<Broadcast> 
messages from devices which are in the PLM's link database.  So far, I have
encountered two important broadcast messages, 1) EZFlora (EZRain) can send
out broadcast messages whenever a valve changes state, 2) Each device will
send out a broadcast message whenever you hold down the set button for 10
seconds.  Within MisterHouse this message is used to mark a deaf device as
awake for 4 minutes.  If Monitor Mode is not enabled, MisterHouse will not
see either of these messages.

Please be warned, since the documentation is rather vague on what this setting
does, please consider this setting a B<Beta> feature.  Other users with other
setups or devices may discover problems with this setting, but at least for me
I do not see a downside to enabling this feature.

=back

=item C<Disable Monitor Mode>

Disables B<Monitor Mode> defined above.

=back

=head3 Devices

=over

=item C<on>

Turns the device on.

=item C<off>

Turns the device off.

=item C<Sync Links>

Similar to C<Sync All Links> above, but this will only add links that are related
to this device.  Useful when adding a new device.

On deaf devices, this command will perform its tasks the next time the device
is awake.  You can awaken a device temporarily by triggering it (walk in front
of a motion sensor, press a button on a remotelinc).  Or you can place the 
device in awake mode for a longer period of time.  See B<Mark as Manually Awake>

=item C<Link to Interface>

Will create the controller/responder links between the device and the PLM.

=item C<Unlink with Interface>

Will delete the controller/responder links between the device and the PLM.  
Useful if you are removing a device from your network.

=item C<Status>

Requests the status of the device.

=item C<Get Engine Version>

Requests the engine version of the device.  Generally you would not need to call
this, but every now and then it is needed when a new device is installed.

=item C<Scan Link Table>

This will scan and output to the log only the link table of this device.

=item C<Log Links>

Will output to the log only the link table of this device.

=item C<Initiate Linking as Controller>

Generally only available for PLM Scenes.  This places the PLM in linking mode
and adds any device which the set button is pressed for 4 seconds as a responder
to this scene.  Generally not needed.

=item C<Cancel Linking>

Cancels the above linking session without creating a link.

=item C<Run Stress Test>

Simulates a read of a 5 link addresses from the device.  This routine is meant to 
be used as a diagnostic tool.

This is also similar to the C<ping> test, however, rather than simply requesting
an ACK, this requests a full set of data equivalent to a link entry.  Similar to
C<ping> this should be used with C<print_message_log> to diagnose issues and try
different settings.

=item C<Run Ping Test>

Sends 5 ping messages to the device.  A ping message is a basic 
message that simply asks the device to respond with an ACKnowledgement.  For
i1 devices this will send a standard length command, for i2 and i2cs devices
this will send an extended ping command.  In both cases, the device responds
back with a standard length ACKnowledgement only.

Much like the ping command in IP networks, this command is useful for testing the
connectivity of a device on your network.  You likely want to use this in 
conjunction with the C<print_message_log> routine.  For example, you can use 
this to compare the message stats for a device when changing settings in 
MisterHouse.

=item C<Print Message Stats>

Prints message statistics for this device to the print log.  

=back

=over8

=item * 

In - The number of incoming messages received

=item * 

Corrupt - The number of incoming corrupt messages received

=item * 

%Corrpt - Of the incoming messages received, the percentage that were 
corrupt

=item *

Dupe - The number of duplicate messages that have been received from this 
device.

=item *

%Dupe - The percentage of duplilicate incoming messages received.

=item *

Hops_Left - The average hops left in the messages received from this device.

=item *

Max_Hops - The average maximum hops in the messages received from this device.

=item *

Act_Hops - Max_Hops - Hops_Left, this is the average number of hops that have
been required for a message sent from the device to reach MisterHouse.

=item * 

Out - The number of unique outgoing messages, without retries, sent. 

=item * 

Fail - The number times that all retries were exhausted without a successful
delivery of a message.

=item * 

%Fail - Of the outgoing messages sent, the percentage that failed.

=item * 

Retry - The number of retry attempts that have been made to deliver a message. 
Ideally this is 0, but Sends/Msg is a better indication of this parameter.

=item * 

AvgSend - The average number of send attempts that must be made in order to 
successfully deliver a message.  Ideally this would be 1.0.  

NOTE: If the number of retries exceeds the value set in the configuration file 
for Insteon_retry_count, MisterHouse will abandon sending the message.  As a 
result, as this number approaches Insteon_retry_count it becomes a less accurate 
representation of the number of retries needed to reach a device.

=item *

Avg_Hops - The average number of hops that have been used by MisterHouse when
sending messages to this device.

=item *

Hop_Count - The current hop count being used by MH.  This count is dynamically
controlled by MH and is not reset by calling C<reset_message_stats>

=back

=over

=item C<Reset Message Stats>

Resets the message stats back to 0 for this device.

=item C<Mark as Manually Awake>

Flags the device as being awake for 4 minutes.  Only applicable to deaf devices
such as motion sensors and remotelincs.  You must first press and hold the set
button for 10 seconds on the device to put it into awake mode.  Then tell
MisterHouse that you have done this by using this command.  Alternatively, if
you enable B<Monitor Mode> on the PLM, MisterHouse will see when you press the
set button of a device for ten seconds, and automatically mark it as awake for
you.

=item C<(AUDIT) Sync Links>

Only available on deaf devices such as motion sensors and remotelincs.  Similar 
to C<AUDIT Sync All Links> above in the PLM, but this will only report links
that B<would> be added to this device should you run B<Sync Links>.

=item C<(AUDIT) Delete Orphan Links>

Only available on deaf devices such as motion sensors and remotelincs.  Similar 
to C<AUDIT Delete Orphan Links> above in the PLM, but this will only report links
that B<would> be deleted from this device should you run B<Delete Orphan Links>.

=item C<Delete Orphan Links>

Only available on deaf devices such as motion sensors and remotelincs.  Similar 
to C<Delete Orphan Links> above in the PLM, but this will only delete links
from this device that are unnecessary or no longer used.

On deaf devices, this command will perform its tasks the next time the device
is awake.  You can awaken a device temporarily by triggering it (walk in front
of a motion sensor, press a button on a remotelinc).  Or you can place the 
device in awake mode for a longer period of time.  See B<Mark as Manually Awake>

=back

=head2 METHODS

=over

=cut

my ( @_insteon_plm, @_insteon_device, @_insteon_link, @_scannable_link,
    $_scan_cnt, $_sync_cnt, $_sync_failure_cnt );
my $init_complete;
my ( @_scan_devices,      @_scan_device_failures, $current_scan_device );
my ( @_sync_devices,      @_sync_device_failures, $current_sync_device );
my ( $_stress_test_count, $_stress_test_one_pass, @_stress_test_devices );
my ( $_ping_count,        @_ping_devices );

=item C<stress_test_all(count, [is_one_pass])>

Sequentially goes through every Insteon device and performs a stress_test on it.  
See L<Insteon::BaseDevice::stress_test|Insteon::BaseInsteon::BaseDevice::stress_test> 
for a more detailed description of stress_test.

Parameters:
	Count: defines the number of stress_tests to perform on each device.
	is_one_pass: if true, all stress_tests will be performed on a device
		before proceeding to the next device. if false, the routine 
		loops through all devices performing one stress_test on each 
		device before moving on to the next device.

=cut

sub stress_test_all {
    my ( $p_count, $is_one_pass ) = @_;
    if ( defined $p_count ) {
        $_stress_test_count    = $p_count;
        $_stress_test_one_pass = $is_one_pass;
        @_stress_test_devices  = undef;
        push @_stress_test_devices,
          Insteon::find_members("Insteon::BaseDevice");
        main::print_log(
            "[Insteon::Stress Test All Devices] Stress Testing All Devices $p_count times"
        );
    }
    if ( !@_stress_test_devices ) {

        #Iteration may be complete, start over from the beginning
        $_stress_test_count =
          ($_stress_test_one_pass) ? 0 : $_stress_test_count--;
        push @_stress_test_devices,
          Insteon::find_members("Insteon::BaseDevice");
    }
    if ( $_stress_test_count > 0 ) {
        my $current_stress_test_device;
        my $complete_callback = '&Insteon::stress_test_all()';
        while (@_stress_test_devices) {
            $current_stress_test_device = pop @_stress_test_devices;
            next unless $current_stress_test_device->is_root();
            next unless $current_stress_test_device->is_responder();
            last;
        }
        my $run_count = ($_stress_test_one_pass) ? $_stress_test_count : 1;
        if ( ref $current_stress_test_device
            && $current_stress_test_device->can('stress_test') )
        {
            $current_stress_test_device->stress_test( $run_count,
                $complete_callback );
        }
    }
    else {
        $_stress_test_one_pass = 0;
        main::print_log("[Insteon::Stress Test All Devices] Complete");
    }
}

=item C<scan_all_linktables()>

Walks through every Insteon device calling the device's scan links command.
Does not output anything but will recreate the device's aldb from the actual
entries in the device.

=cut

sub scan_all_linktables {
    my $skip_unchanged = pop(@_);
    $skip_unchanged = 0 if ( ref $skip_unchanged || !defined($skip_unchanged) );
    if ($current_scan_device) {
        &main::print_log(
            "[Scan all linktables] WARN: link already underway. Ignoring request for new scan ..."
        );
        return;
    }
    my @candidate_devices = ();

    # clear @_scan_devices
    @_scan_devices         = ();
    @_scan_device_failures = ();
    $current_scan_device   = undef;

    # alwayws include the active interface (e.g., plm)
    push @_scan_devices, &Insteon::active_interface;

    push @candidate_devices, &Insteon::find_members("Insteon::BaseDevice");

    # don't try to scan devices that are not responders
    if (@candidate_devices) {
        foreach (@candidate_devices) {
            my $candidate_object = $_;
            if ( $candidate_object->is_deaf ) {
                ::print_log( "[Scan all linktables] INFO: !!! "
                      . $candidate_object->get_object_name
                      . " is deaf. To scan this object you"
                      . " must run 'Scan Link Table' on it"
                      . " directly." );
            }
            elsif ( $candidate_object->is_root
                and !( $candidate_object->isa('Insteon::InterfaceController') )
              )
            {
                push @_scan_devices, $candidate_object;
                &main::print_log( "[Scan all linktables] INFO1: "
                      . $candidate_object->get_object_name
                      . " will be scanned." )
                  if $candidate_object->debuglevel( 1, 'insteon' );
            }
            else {
                &main::print_log( "[Scan all linktables] INFO: !!! "
                      . $candidate_object->get_object_name
                      . " is NOT a candidate for scanning." );
            }
        }
    }
    else {
        &main::print_log(
            "[Scan all linktables] WARN: No insteon devices could be found");
    }
    $_scan_cnt = scalar @_scan_devices;

    &_get_next_linkscan($skip_unchanged);
}

=item C<_get_next_linkscan_failure()>

Called if a the scanning of a device fails.  Logs the failure and proceeds to 
the next device.

=cut

sub _get_next_linkscan_failure {
    my ($skip_unchanged) = @_;
    push @_scan_device_failures, $current_scan_device;
    &main::print_log(
            "[Scan all link tables] WARN: failure occurred when scanning "
          . $current_scan_device->get_object_name
          . ".  Moving on..." );
    &_get_next_linkscan($skip_unchanged);

}

=item C<_get_next_linkscan()>

Gets the next device to scan.

=cut

sub _get_next_linkscan {
    my ( $skip_unchanged, $changed_device ) = @_;
    $current_scan_device = shift @_scan_devices;
    if ($current_scan_device) {
        ::print_log( "[Scan all link tables] Now scanning: "
              . $current_scan_device->get_object_name . " ("
              . ( $_scan_cnt - scalar @_scan_devices )
              . " of $_scan_cnt)" );

        # pass first the success callback followed by the failure callback
        $current_scan_device->scan_link_table(
            '&Insteon::_get_next_linkscan(' . $skip_unchanged . ')',
            '&Insteon::_get_next_linkscan_failure(' . $skip_unchanged . ')',
            $skip_unchanged
        );
    }
    else {
        ::print_log(
            "[Scan all link tables] Completed scanning of all regular items.");
        if ( scalar @_scan_device_failures ) {
            my $obj_list;
            for my $failed_obj (@_scan_device_failures) {
                $obj_list .= $failed_obj->get_object_name . ", ";
            }
            ::print_log( "[Scan all link tables] WARN, unable to "
                  . " complete a scan of the following devices: $obj_list" );
        }
    }
}

=item C<sync_all_links()>

Initiates a process that will walk through every device that is a Insteon::InterfaceController 
calling the device's sync_links() command.  sync_all_links() loads up the module
global variable @_sync_devices then kicks off the recursive call backs by calling
_get_next_linksync.

Paramter B<audit_mode> - Causes sync to walk through but not actually 
send any commands to the devices.  Useful with the insteon:3 debug setting for 
troubleshooting. 

=cut

sub sync_all_links {
    my ($audit_mode) = @_;
    &main::print_log("[Sync all links] Starting now!");
    @_sync_devices         = ();
    @_sync_device_failures = ();

    # iterate over all registered objects and compare whether the link tables match defined scene linkages in known Insteon_Links
    for my $obj ( &Insteon::find_members('Insteon::BaseController') ) {
        my %sync_req =
          ( 'sync_object' => $obj, 'audit_mode' => ($audit_mode) ? 1 : 0 );
        &main::print_log( "[Sync all links] Adding "
              . $obj->get_object_name
              . " to sync queue" );
        push @_sync_devices, \%sync_req;
    }

    $_sync_cnt = scalar @_sync_devices;

    &_get_next_linksync();
}

=item C<_get_next_linksync()>

Calls the sync_links() function for each device in the module global variable 
@_sync_devices.  This function will be called recursively since the callback 
passed to sync_links() is this function again.  Will also ask sync_links() to 
call _get_next_linksync_failure() if sync_links() fails. 

=cut

sub _get_next_linksync {
    my $sync_req_ptr = shift(@_sync_devices);
    my %sync_req = ($sync_req_ptr) ? %$sync_req_ptr : undef;
    if (%sync_req) {
        $current_sync_device = $sync_req{'sync_object'};
    }
    else {
        $current_sync_device = undef;
    }

    if ($current_sync_device) {
        &main::print_log( "[Sync all links] Now syncing: "
              . $current_sync_device->get_object_name . " ("
              . ( $_sync_cnt - scalar @_sync_devices )
              . " of $_sync_cnt)" );
        my $skip_deaf = 1;

        # pass first the success callback followed by the failure callback
        $current_sync_device->sync_links(
            $sync_req{'audit_mode'},
            '&Insteon::_get_next_linksync()',
            '&Insteon::_get_next_linksync_failure()', $skip_deaf
        );
    }
    else {
        &main::print_log("[Sync all links] All links have completed syncing");
        my $_sync_failure_cnt = scalar @_sync_device_failures;
        if ($_sync_failure_cnt) {
            my $obj_list;
            for my $failed_obj (@_sync_device_failures) {
                $obj_list .= $failed_obj->get_object_name . ", ";
            }
            ::print_log( "[Sync all links] WARN! Failures occured, "
                  . "some links involving the following objects "
                  . "remain out-of-sync: $obj_list" );
        }
    }

}

=item C<_get_next_linksync()>

Called by the failure callback in a device's sync_links() function.  Will add
the failed device to the module global variable @_sync_device_failures. 

=cut

sub _get_next_linksync_failure {
    push @_sync_device_failures, $current_sync_device
      unless ( grep { $current_sync_device == $_ } @_sync_device_failures );
    &main::print_log(
            "[Sync all links] WARN: failure occurred when syncing links for "
          . $current_sync_device->get_object_name
          . ". Resuming sync queue if it exists." );
    my $num_sync_queue = @{ $$current_sync_device{sync_queue} };
    if ($num_sync_queue) {
        $current_sync_device->_process_sync_queue();
    }
    else {    #No other pending links in the queue
        &_get_next_linksync();
    }

}

=item C<ping_all([count)>

Walks through every Insteon device and pings it as many times as defined by 
count.  See L<Insteon::BaseDevice::ping|Insteon::BaseInsteon::BaseDevice::ping> 
for a more detailed description of ping.

=cut

sub ping_all {
    my ($p_count) = @_;
    if ( defined $p_count ) {
        $_ping_count   = $p_count;
        @_ping_devices = ();
        push @_ping_devices, Insteon::find_members("Insteon::BaseDevice");
        main::print_log(
            "[Insteon::Ping All Devices] Ping All Devices $p_count times");
    }
    if (@_ping_devices) {
        my $current_ping_device;
        while (@_ping_devices) {
            $current_ping_device = pop @_ping_devices;
            next unless $current_ping_device->is_root();
            next unless $current_ping_device->is_responder();
            last;
        }
        $current_ping_device->ping( $_ping_count, '&Insteon::ping_all()' )
          if $current_ping_device->can('ping');
    }
    else {
        $_ping_count = 0;
        main::print_log("[Insteon::Ping All Devices] Ping All Complete");
    }
}

=item C<log_all_ADLB_status()>

Walks through every Insteon device and logs:

=back

=over8

=item * 

Hop Count

=item * 

Engine Version

=item * 

ALDB Type

=item * 

ALDB Health

=item * 

ALDB Scan Time

=back

=over

=cut

sub log_all_ADLB_status {
    my @_log_ALDB_devices = ();

    # alwayws include the active interface (e.g., plm)
    #	push @_log_ALDB_devices, &Insteon::active_interface;

    push @_log_ALDB_devices, Insteon::find_members("Insteon::BaseDevice");

    # don't try to scan devices that are not responders
    if (@_log_ALDB_devices) {
        my $log_ALDB_cnt = @_log_ALDB_devices;
        my $count        = 0;
        foreach my $current_log_ALDB_device (@_log_ALDB_devices) {
            $count++;
            if (
                $current_log_ALDB_device->is_root
                and !(
                    $current_log_ALDB_device->isa(
                        'Insteon::InterfaceController')
                )
              )
            {
                &main::print_log( "[log all device ALDB status] Now logging: "
                      . $current_log_ALDB_device->get_object_name()
                      . " ($count of $log_ALDB_cnt)" );
                $current_log_ALDB_device->log_aldb_status();
            }
            else {
                main::print_log( "[log all device ALDB status] INFO: !!! "
                      . $current_log_ALDB_device->get_object_name
                      . " is NOT a candidate for logging ($count of $log_ALDB_cnt)"
                );
            }
        }
        main::print_log(
            "[log all device ALDB status] All devices have completed logging");
    }
    else {
        main::print_log(
            "[log all device ALDB status] WARN: No insteon devices could be found"
        );
    }
}

=item C<print_all_message_stats>

Walks through every Insteon device and prints statistical information about
its message handling, as well as a summary average of the entire network.  See 
L<Insteon::BaseDevice::print_message_stats|Insteon::BaseInsteon::BaseDevice::print_message_stats> 
for more detailed information.

This command adds the following extra data points:

=back

=over8

=item * 

Unk_Error - The number of messages which have arrived at the PLM which cannot
be associated with any know device.

=back

=over

=cut

sub print_all_message_stats {
    my @_log_devices = ();
    push @_log_devices, Insteon::find_members("Insteon::BaseDevice");

    if (@_log_devices) {

        #Initialize all of the tracking variables
        my $retry_average      = 0;
        my $fail_percentage    = 0;
        my $corrupt_percentage = 0;
        my $dupe_percentage    = 0;
        my $avg_hops_left      = 0;
        my $avg_max_hops       = 0;
        my $avg_out_hops       = 0;
        my $curr_hops_avg      = 0;

        my $incoming_count_log = 0;
        my $corrupt_count_log  = 0;
        my $dupe_count_log     = 0;
        my $retry_count_log    = 0;
        my $outgoing_count_log = 0;
        my $fail_count_log     = 0;
        my $default_hop_count  = 0;
        my $hops_left_count    = 0;
        my $max_hops_count     = 0;
        my $outgoing_hop_count = 0;

        my $device_count = 0;

        foreach my $current_log_device (@_log_devices) {

            #Skip non-root items
            next unless $current_log_device->is_root;

            $device_count++;

            #Prints the Individual Message for the Device
            $current_log_device->print_message_stats;

            #Add values for each device to the master count
            $incoming_count_log += $current_log_device->incoming_count_log;
            $corrupt_count_log  += $current_log_device->corrupt_count_log;
            $dupe_count_log     += $current_log_device->dupe_count_log;
            $retry_count_log    += $current_log_device->retry_count_log;
            $outgoing_count_log += $current_log_device->outgoing_count_log;
            $fail_count_log     += $current_log_device->fail_count_log;
            $default_hop_count  += $current_log_device->default_hop_count;
            $hops_left_count    += $current_log_device->hops_left_count;
            $max_hops_count     += $current_log_device->max_hops_count;
            $outgoing_hop_count += $current_log_device->outgoing_hop_count;
        }

        #Calculate the averages
        $retry_average =
          sprintf( "%.1f", ( $retry_count_log / $outgoing_count_log ) + 1 )
          if ( $outgoing_count_log > 0 );
        $fail_percentage =
          sprintf( "%.1f", ( $fail_count_log / $outgoing_count_log ) * 100 )
          if ( $outgoing_count_log > 0 );
        $corrupt_percentage =
          sprintf( "%.1f", ( $corrupt_count_log / $incoming_count_log ) * 100 )
          if ( $incoming_count_log > 0 );
        $dupe_percentage =
          sprintf( "%.1f", ( $dupe_count_log / $incoming_count_log ) * 100 )
          if ( $incoming_count_log > 0 );
        $avg_hops_left =
          sprintf( "%.1f", ( $hops_left_count / $incoming_count_log ) )
          if ( $incoming_count_log > 0 );
        $avg_max_hops =
          sprintf( "%.1f", ( $max_hops_count / $incoming_count_log ) )
          if ( $incoming_count_log > 0 );
        $avg_out_hops =
          sprintf( "%.1f", ( $outgoing_hop_count / $outgoing_count_log ) )
          if ( $outgoing_count_log > 0 );
        $curr_hops_avg =
          sprintf( "%.1f", ( $default_hop_count / $device_count ) )
          if ( $device_count > 0 );
        ::print_log( "[Insteon] Average Network Statistics:\n"
              . "    In Corrupt %Corrpt  Dupe   %Dupe HopsLeft Max_Hops Act_Hops Unk_Error\n"
              . sprintf( "%6s",  $incoming_count_log )
              . sprintf( "%8s",  $corrupt_count_log )
              . sprintf( "%8s",  $corrupt_percentage . '%' )
              . sprintf( "%6s",  $dupe_count_log )
              . sprintf( "%8s",  $dupe_percentage . '%' )
              . sprintf( "%9s",  $avg_hops_left )
              . sprintf( "%9s",  $avg_max_hops )
              . sprintf( "%9s",  $avg_max_hops - $avg_hops_left )
              . sprintf( "%10s", &Insteon::active_interface->corrupt_count_log )
              . "\n"
              . "   Out    Fail   %Fail Retry AvgSend Avg_Hops CurrHops\n"
              . sprintf( "%6s", $outgoing_count_log )
              . sprintf( "%8s", $fail_count_log )
              . sprintf( "%8s", $fail_percentage . '%' )
              . sprintf( "%6s", $retry_count_log )
              . sprintf( "%8s", $retry_average )
              . sprintf( "%9s", $avg_out_hops )
              . sprintf( "%9s", $curr_hops_avg ) );
        main::print_log(
            "[Insteon::Print_All_Message_Stats] All devices have completed logging"
        );
    }
    else {
        main::print_log(
            "[Insteon::Print_All_Message_Stats] WARN: No insteon devices could be found"
        );
    }
}

=item C<reset_all_message_stats>

Walks through every Insteon device and resets the statistical information about
its message handling.

=cut

sub reset_all_message_stats {
    my @_log_devices = ();
    &Insteon::active_interface->reset_message_stats;
    push @_log_devices, Insteon::find_members("Insteon::BaseDevice");

    if (@_log_devices) {
        foreach my $current_log_device (@_log_devices) {
            $current_log_device->reset_message_stats
              if $current_log_device->can('reset_message_stats');
        }
        main::print_log(
            "[Insteon::Reset_All_Message_Stats] All devices have been reset");
    }
    else {
        main::print_log(
            "[Insteon::Reset_All_Message_Stats] WARN: No insteon devices could be found"
        );
    }
}

=item C<init()>

Initiates the insteon stack, mostly just sets the trigger. 

=cut

sub init {

    # only run once
    return if $init_complete;
    $init_complete = 1;

    # initialize scan and sync counters
    $_scan_cnt     = 0;
    $_sync_cnt     = 0;
    @_scan_devices = ();

    #################################################################
    ## Trigger creation
    #################################################################
    my ( $trigger_event, $trigger_code, $trigger_type );

    my @trigger_info = &main::trigger_get('scan insteon link tables');
    if (@trigger_info) {

        # Trigger exists; modify just the minimum so the trigger continues
        # to work if we change the trigger code, but respect everything
        # else (trigger type and time to run). This prevents unconditionally
        # re-enabling the trigger if the user has disabled it.
        $trigger_event = $trigger_info[0];
        $trigger_type  = $trigger_info[2];
    }
    else {
        # Trigger does not exist; create one with our default values.
        $trigger_event = "time_cron '00 02 * * *'";
        $trigger_type  = 'NoExpire';
    }

    $trigger_code = '&Insteon::scan_all_linktables()';

    # Create/update trigger for a nightly link table scan
    &main::trigger_set( $trigger_event, $trigger_code, $trigger_type,
        'scan insteon link tables', 1 );
    #################################################################

    @_insteon_plm    = ();
    @_insteon_device = ();
    @_insteon_link   = ();

}

=item C<generate_voice_commands()>

Generates and sets the voice commands for all Insteon devices.

Note: At some point, this function will be pushed out to the specific classes
so that each class can have its own unique set of voice commands.

=cut

sub generate_voice_commands {

    &main::print_log("Generating Voice commands for all Insteon objects");
    my $object_string;
    for my $object (&main::list_all_objects) {
        next unless ref $object;
        next
          unless $object->isa('Insteon::BaseInterface')
          or $object->isa('Insteon::BaseObject');

        #get object name to use as part of variable in voice command
        my $object_name   = $object->get_object_name;
        my $object_name_v = $object_name . '_v';
        $object_string .= "use vars '${object_name}_v';\n";

        #Convert object name into readable voice command words
        my $command = $object_name;
        $command =~ s/^\$//;
        $command =~ tr/_/ /;

        my $group = ( $object->isa('Insteon_PLM') ) ? '' : $object->group;

        #Get list of all voice commands from the object
        my $voice_cmds = $object->get_voice_cmds();

        #Initialize the voice command with all of the possible device commands
        $object_string .= "$object_name_v  = new Voice_Cmd '$command ["
          . join( ",", sort keys %$voice_cmds ) . "]';\n";

        #Tie the proper routine to each voice command
        foreach ( keys %$voice_cmds ) {
            $object_string .=
                "$object_name_v -> tie_event('"
              . $voice_cmds->{$_}
              . "', '$_');\n\n";
        }

        #Add this object to the list of Insteon Voice Commands on the Web Interface
        $object_string .=
          ::store_object_data( $object_name_v, 'Voice_Cmd', 'Insteon',
            'Insteon_PLM_commands' );
    }

    #Evaluate the resulting object generating string
    package main;
    eval $object_string;
    print "Error in insteon_item_commands: $@\n" if $@;

    package Insteon;
}

=item C<add(object)>

Adds object to the list of insteon objects that are managed by the stack.  Makes
the object eligible for linking, scanning, and global functions.

=cut

sub add {
    my ($object) = @_;

    my $insteon_manager = InsteonManager->instance();
    if ( $insteon_manager->remove_item($object) ) {

        # print out debug info
    }
    $insteon_manager->add_item($object);
}

=item C<find_members(name)>

Called as a non-object routine.  Returns the object named name.

=cut

sub find_members {
    my ($name) = @_;

    my $insteon_manager = InsteonManager->instance();
    return $insteon_manager->find_members($name);
}

=item C<get_object(p_id[, p_group])>

Returns the object identified by p_id and p_group.  Where p_id is the 6 digit
hexadecimal address of the object without periods and group is a two digit
representation of the group number of the device.

Insteon Scenes are identified by p_id=='000000', p_group==scene_id

Returns undef if there is no matching object

=cut

sub get_object {
    my ( $p_deviceid, $p_group ) = @_;

    my $retObj = undef;

    my $insteon_manager = InsteonManager->instance();
    my @search_objects  = ();
    push @search_objects, $insteon_manager->find_members('Insteon::BaseObject');
    for my $obj (@search_objects) {

        #Match on Insteon objects only
        #	if ($obj->isa("Insteon::Insteon_Device"))
        #	{
        if ( lc $obj->device_id() eq lc $p_deviceid ) {
            if ($p_group) {
                if ( lc $p_group eq lc $obj->group ) {
                    $retObj = $obj;
                    last;
                }
            }
            else {
                $retObj = $obj;
                last;
            }
        }

        #	}
    }

    return $retObj;
}

=item C<active_interface(p_interface)>

Sets p_interface as the new active interface.  Should likely only be called on
startup or reload.

=cut

sub active_interface {
    my ($interface) = @_;
    my $insteon_manager = InsteonManager->instance();

    $insteon_manager->_active_interface($interface)
      if $interface
      && ref $interface
      && $interface->isa('Insteon::BaseInterface');

    #print "############### active interface is: " . $insteon_manager->_active_interface->get_object_name . "\n";
    return $insteon_manager->_active_interface;

}

=item C<check_all_aldb_versions()>

Walks through every Insteon device and checks the aldb object version for I1 vs. I2

=cut

sub check_all_aldb_versions {
    main::print_log("[Insteon] DEBUG4 Checking aldb version of all devices")
      if ( $main::Debug{insteon} >= 4 );

    my @ALDB_devices = ();
    push @ALDB_devices, Insteon::find_members("Insteon::BaseDevice");
    my $ALDB_cnt = @ALDB_devices;
    my $count    = 0;
    foreach my $ALDB_device (@ALDB_devices) {
        $count++;
        if ( $ALDB_device->is_root
            and !( $ALDB_device->isa('Insteon::InterfaceController') ) )
        {
            main::print_log( "[Insteon] DEBUG4 Checking aldb version for "
                  . $ALDB_device->get_object_name()
                  . " ($count of $ALDB_cnt)" )
              if ( $ALDB_device->debuglevel( 4, 'insteon' ) );
            $ALDB_device->check_aldb_version();
        }
        else {
            main::print_log( "[Insteon] DEBUG4 "
                  . $ALDB_device->get_object_name
                  . " does not have its own aldb ($count of $ALDB_cnt)" )
              if ( $ALDB_device->debuglevel( 4, 'insteon' ) );
        }
    }
    main::print_log(
        "[Insteon] DEBUG4 Checking aldb version of all devices completed")
      if ( $main::Debug{insteon} >= 4 );
}

sub check_thermo_versions {
    main::print_log("[Insteon] DEBUG4 Initializing thermostat versions")
      if ( $main::Debug{insteon} >= 4 );

    my @thermo_devices = ();
    push @thermo_devices, Insteon::find_members("Insteon::Thermostat");
    foreach my $thermo_device (@thermo_devices) {
        if (   $thermo_device->isa('Insteon::Thermostat')
            && $thermo_device->get_root()->engine_version eq "I2CS" )
        {
            main::print_log( "[Insteon] DEBUG4 Setting thermostat "
                  . $thermo_device->get_object_name()
                  . " to i2CS" )
              if ( $thermo_device->debuglevel( 4, 'insteon' ) );
            bless $thermo_device, 'Insteon::Thermo_i2CS';
            $thermo_device->init();
        }
        else {
            main::print_log( "[Insteon] DEBUG4 Setting thermostat "
                  . $thermo_device->get_object_name()
                  . " to i1" )
              if ( $thermo_device->debuglevel( 4, 'insteon' ) );
            bless $thermo_device, 'Insteon::Thermo_i1';
        }
    }
}

=back

=head2 INI PARAMETERS

=over 

=item insteon_menu_states

A comma seperated list of states that will be added as voice commands to dimmable
devices.

=back

=head2 AUTHOR

Gregg Limming, Kevin Robert Keegan, Micheal Stovenour, many others

=head2 LICENSE

This program is free software; you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation; either version 2 of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more details.

You should have received a copy of the GNU General Public License along with this program; if not, write to the Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.

=head1 B<InsteonManager>

=head2 DESCRIPTION

Provides the basic infrastructure for the Insteon stack, contains many of the 
startup routines.

=head2 INHERITS

L<Class::Singleton|Class::Singleton>

=head2 METHODS

=over

=cut

package InsteonManager;

use strict;
use base 'Class::Singleton';

=item C<_new_instance()>

Defines a new instance of the class.

=cut

sub _new_instance {
    my $class = shift;
    my $self = bless {}, $class;

    return $self;
}

=item C<_active_interface()>

Sets and returns the active interface.  Likely should only be caled on startup
or reload.  It also sets all of the hooks for the Insteon stack.

=cut

sub _active_interface {
    my ( $self, $interface ) = @_;

    # setup hooks the first time that an interface is made active
    if ( !( $$self{active_interface} ) and $interface ) {
        &main::print_log("[Insteon] Setting up initialization hooks")
          if $main::Debug{insteon};
        &main::MainLoop_pre_add_hook( \&Insteon::BaseInterface::check_for_data,
            1 );
        &main::Reload_post_add_hook( \&Insteon::check_all_aldb_versions, 1 );
        &main::Reload_post_add_hook( \&Insteon::BaseInterface::poll_all, 1 );
        $init_complete = 0;
        &main::MainLoop_pre_add_hook( \&Insteon::init, 1 );
        &main::Reload_post_add_hook( \&Insteon::check_thermo_versions,   1 );
        &main::Reload_post_add_hook( \&Insteon::generate_voice_commands, 1 );
    }
    $$self{active_interface} = $interface if $interface;
    return $$self{active_interface};
}

=item C<add()>

Adds a list of objects to be tracked.

=cut

sub add {
    my ( $self, @p_objects ) = @_;

    my @l_objects;

    for my $l_object (@p_objects) {
        if ( $l_object->isa('Group_Item') ) {
            @l_objects = $$l_object{members};
            for my $obj (@l_objects) {
                $self->add($obj);
            }
        }
        else {
            $self->add_item($l_object);
        }
    }
}

=item C<add()>

Adds an object to be tracked.

=cut

sub add_item {
    my ( $self, $p_object ) = @_;

    push @{ $$self{objects} }, $p_object;
    if ( $p_object->isa('Insteon::BaseInterface') ) {
        $self->_active_interface($p_object);
    }
    return $p_object;
}

=item C<remove_all_items()>

Removes all of the Insteon objects.

=cut

sub remove_all_items {
    my ($self) = @_;

    if ( ref $$self{objects} ) {
        foreach ( @{ $$self{objects} } ) {

            #        $_->untie_items($self);
        }
    }
    delete $self->{objects};
}

=item C<add_item_if_not_present()>

Adds an item to be tracked if it is not already in the list.

=cut

sub add_item_if_not_present {
    my ( $self, $p_object ) = @_;

    if ( ref $$self{objects} ) {
        foreach ( @{ $$self{objects} } ) {
            if ( $_->equals($p_object) ) {
                return 0;
            }
        }
    }
    $self->add_item($p_object);
    return 1;
}

=item C<remove_item()>

Removes the Insteon object.

=cut

sub remove_item {
    my ( $self, $p_object ) = @_;
    return 0 unless $p_object and ref $p_object;
    if ( ref $$self{objects} ) {
        for ( my $i = 0; $i < scalar( @{ $$self{objects} } ); $i++ ) {
            if ( $p_object->equals( $$self{objects}->[$i] ) ) {
                splice @{ $$self{objects} }, $i, 1;
                return 1;
            }
        }
    }
    return 0;
}

=item C<is_member()>

Returns true if object is in the list.

=cut

sub is_member {
    my ( $self, $p_object ) = @_;

    my @l_objects = @{ $$self{objects} };
    for my $l_object (@l_objects) {
        if ( $l_object->equals($p_object) ) {
            return 1;
        }
    }
    return 0;
}

=item C<find_members(p_type)>

Find and return all tracked objects of type p_type where p_type is an object
class.

=cut

sub find_members {
    my ( $self, $p_type ) = @_;

    my @l_found;
    my @l_objects = @{ $$self{objects} };
    for my $l_object (@l_objects) {
        if ( $l_object->isa($p_type) ) {
            push @l_found, $l_object;
        }
    }
    return @l_found;
}

=back

=head2 INI PARAMETERS

=over

=item C<debug>

For debugging debug=insteon or debug=insteon:level where level is 1-4. 

=back

=head2 AUTHOR

Bruce Winter, Gregg Liming, Kevin Robert Keegan, Michael Stovenour, many others

=head2 SEE ALSO

None

=head2 LICENSE

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program; if not, write to the Free Software
Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, 
MA  02110-1301, USA.

=cut

1;
