
=head1 B<Zmtrigger_Item>


=head2 SYNOPSIS

  use Zmtrigger_Item;

  $name_for_camera = new Zmtrigger_Item("Numeric_ID_of_monitor_in_ZoneMinder");
  $camera2 = new Zmtrigger_Item(2,10,200,"Second monitor triggered for 10s with a score of 200");

  set $name_for_camera ON;  # Starts alarm condition in ZoneMinder
  set $name_for_camera OFF;  # Cancells alarm condition in ZoneMinder

  $motionSensor->tie_items($camera2) if state_now $alarm ON;

=head2 DESCRIPTION

Object used to trigger ZoneMinder events

Creates an item based on the Generic_Item.  The item connects to your ZoneMinder server utalizing a Socket_Item and the zmtrigger package included in ZoneMinder.

=head2 SETUP

In ZoneMinder click "Options"

Select the "System" tab

Check the box to enable OPT_TRIGGERS

edit /opt/zm/bin/zmtrigger.pl

in the "Channel/Connection Modules" section comment all lines starting with push except the one referencing

  ZoneMinder::Trigger::Channel::Inet

Restart ZoneMinder

=head2 INHERITS

B<Generic_Item>

=head2 METHODS

=over

=cut

package Zmtrigger_Item;

@Zmtrigger_Item::ISA = ('Generic_Item');

=item C<new($monitor_id,$max_duration,$score,$description)>

Creates a new Zmtrigger_Item.

$monitor_id should be a valid numeric ZoneMinder monitor ID

$max_duration OPTIONAL Specifies the maximum duration of the trigger.  If not specified the value specified in mh.private.ini under zm_trigger_max_duration will be used.

$score OPTIONAL Specifies the default score of the trigger.  If not specified the value specified in mh.private.ini under zm_trigger_score will be used.

$description OPTIONAL Specifies the default description of the trigger to be displayed in Zoneminder.  If not specified the value specified in mh.private.ini under zm_trigger_description will be used

=cut

sub new {
    my ( $class, $monitor_id, $max_duration, $score, $description ) = @_;
    my $self = {};
    bless $self, $class;

    if ( defined $monitor_id ) {
        $self->{monitor_id} = $monitor_id;
    }
    else {
        &::print_log(
            "[Zmtrigger_Item] WARN You must specify a monitor_id when creating a new Zmtrigger_Item"
        );
        return;
    }
    if ( defined $max_duration ) {
        $self->{max_duration} = $max_duration;
    }
    else {
        $self->{max_duration} = $main::config_parms{zm_trigger_max_duration};
    }
    if ( defined $score ) {
        $self->{score} = $score;
    }
    else {
        $self->{score} = $main::config_parms{zm_trigger_score};
    }
    if ( defined $description ) {
        $self->{description} = $description;
    }
    else {
        $self->{description} = $main::config_parms{zm_trigger_description};
    }

    return $self;
}

=item C<set($state)>

The set method changes the state of an existing Zmtrigger_Item by creating a Socket_Item which connects via telnet to the zmtrigger.pl provided with
ZoneMinder.

$state: Should only be ON or OFF
- ON creates an event trigger with a maximum duration.  In case of a communication failure or MH crash the trigger will time out on the ZoneMinder end.
- OFF cancels the active trigger for the monitor.

=cut

sub set {
    my ( $self, $state, $max_duration, $score, $description ) = @_;

    #  Build the data stream
    my $data = $self->{monitor_id};
    if ( $state eq "on" ) {
        $data .= "|on+"
          . $self->{max_duration} . "|"
          . $self->{score} . "|"
          . $self->{description};
    }
    elsif ( $state eq "off" ) {
        $data .= "|cancel";
    }
    else {
        &::print_log(
            "[Zmtrigger_Item] WARN A valid state(on,off) must be specified when calling SET"
        );
        return;
    }

    if ( !defined $zm_connect ) {    # If not already, Create the Socket_Item
        my $address = $main::config_parms{zm_server_address} . ":"
          . $main::config_parms{zm_server_port};

        &::print_log(
            "[Zmtrigger_Item] Creating Socket_Item zm_connect at:-$address-");
        $zm_connect = new Socket_Item( undef, undef, $address );
    }

    start $zm_connect;               # Connect the telnet session
    if ( active $zm_connect)
    {    # send the data to the telnet session if it is active
        &::print_log(
            "[Zmtrigger_Item] Active connection found sending:-$data-");
        set $zm_connect $data;
    }
    stop $zm_connect;    # Disconnect the telnet session

}

1;

=back

=head2 INI PARAMETERS

Paste the following section into your mh.private.ini

  # Category = Zmtrigger
  #
  #
  # Socket_Item properties
  #
  # IP or Host name of server running ZoneMinder
  zm_server_address = localhost
  # Port assigned to ZoneMinder's zmtrigger
  zm_server_port = 6802
  #
  # Zmtrigger_Item Default Values
  #
  # Maximum duration of triggered state in seconds if not cancelled by an OFF
  zm_trigger_max_duration = 300
  # Score assigned to the trigger in ZoneMinder
  zm_trigger_score = 200
  # Description of trigger passed to ZoneMinder
  zm_trigger_description = MisterHouse

=head2 AUTHOR

Dustin Robinson

=head2 SEE ALSO

NONE

=head2 LICENSE

This program is free software; you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation; either version 2 of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more details.

You should have received a copy of the GNU General Public License along with this program; if not, write to the Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.

=cut

