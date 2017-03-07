
=head1 B<DOORBIRD>


=head2 DESCRIPTION

Module for interfacing with the Doorbird line of IP Doorbells.  Monitors events
sent by the doorbell such as doorbell button push, motion, built in door relay trigger.

=head2 CONFIGURATION

At minimum, you must define the Interface and one of the following objects
DOORBIRD_Bell, DOORBIRD_Motion, or DOORBIRD_Relay. This allows
for the display of these objects as separate items in the MH interface and allows
users to interact directly with these objects using the basic Generic_Item
functions such as tie_event.

The DOORBIRD_Bell and DOORBIRD_Motion objects are for tracking the state of the
doorbell bell button and the doorbell built in motion detector and are not for
controlling the doorbell from MH.

The DOORBIRD_Relay object is for tracking the state of the built-in "door relay"
in the doorbell and to control the door relay and the doorbell IR light. The relay
is a standard dry contact relay that could be used for any purpose.

Misterhouse receives the states of each object from the doorbell by configuring the
doorbell to send an HTTP get to MH when an action is realized, this method allows MH
to track the states even when they have been triggered by the android app. The
configuration of the doorbell happens when MH is started, so the doorbell must be
On and accessible by MH when MH is started.

=head2 Interface Configuration

mh.private.ini configuration:

In order to allow for multiple doorbells, instance names are used.
the following are prefixed with the instance name (DOORBIRD).

The IP of the misterhouse server:
	DOORBIRD_mh_ip=192.168.1.10

The port of the misterhouse server web:
	DOORBIRD_mh_port=8080

The IP of the doorbell:
	DOORBIRD_doorbell_ip=192.168.1.50

The username for the doorbell:
	DOORBIRD_user=doorbirduser

The password for the doorbell:
	DOORBIRD_password=doorbirdpass


=head2 Defining the Interface Object

In addition to the above configuration, you must also define the interface
object.  The object can be defined in the user code.

In user code:

   $DOORBIRD = new DOORBIRD('DOORBIRD');

Wherein the format for the definition is:

   $DOORBIRD = new DOORBIRD(INSTANCE);

=head2 Bell Object

	$DOORBIRD_Bell = new DOORBIRD_Bell('DOORBIRD', 1);

Wherein the format for the definition is:
	$DOORBIRD_Bell = new DOORBIRD_Bell(INSTANCE, ENABLECONFIG);

States:
ON
OFF

=head2 Motion Object

	$DOORBIRD_Motion = new DOORBIRD_Motion('DOORBIRD', 1);

Wherein the format for the definition is:
	$DOORBIRD_Motion = new DOORBIRD_Motion(INSTANCE, ENABLECONFIG);

States:
ON
OFF

=head2 Relay Object

	$DOORBIRD_Relay = new DOORBIRD_Relay('DOORBIRD', 1);

Wherein the format for the definition is:
	$DOORBIRD_Relay = new DOORBIRD_Relay(INSTANCE, ENABLECONFIG);

States:
ON
OFF

Control States:
TOGGLE (to trigger the relay)
LIGHT_ON  (to enable the IR light on the door bell)

=head2 NOTES

An example mh.private.ini:

	DOORBIRD_mh_ip=192.168.1.10
	DOORBIRD_mh_port=8080
	DOORBIRD_doorbell_ip=192.168.1.50
	DOORBIRD_user=doorbirduser
	DOORBIRD_password=doorbirdpass


An example user code:

	#noloop=start
	use DOORBIRD;
	$DOORBIRD = new DOORBIRD('DOORBIRD');
	$DOORBIRD_Bell = new DOORBIRD_Bell('DOORBIRD', 1);
	$DOORBIRD_Motion = new DOORBIRD_Motion('DOORBIRD', 1);
	$DOORBIRD_Relay = new DOORBIRD_Relay('DOORBIRD', 1);
	#noloop=stop

	if ($state = state_changed $DOORBIRD_Motion) {
    	 run_voice_cmd 'start cam 8' if ($state eq 'on');
    	 run_voice_cmd 'stop cam 8' if ($state eq 'off');
	}

=head2 INHERITS

L<Generic_Item>

=head2 METHODS

=over

=cut

package DOORBIRD;
@DOORBIRD::ISA = ('Generic_Item');

sub new {
    my ( $class, $instance ) = @_;
    $instance = "DOORBIRD" if ( !defined($instance) );
    ::print_log("Starting $instance instance of DOORBIRD interface module");

    my $self = new Generic_Item();

    # Initialize Variables
    $$self{instance}    = $instance;
    $$self{mh_ip}       = $::config_parms{ $instance . '_mh_ip' };
    $$self{mh_port}     = $::config_parms{ $instance . '_mh_port' };
    $$self{doorbell_ip} = $::config_parms{ $instance . '_doorbell_ip' };
    $$self{user}        = $::config_parms{ $instance . '_user' };
    $$self{password}    = $::config_parms{ $instance . '_password' };
    my $year_mon = &::time_date_stamp( 10, time );
    $$self{log_file} = $::config_parms{'data_dir'} . "/logs/DOORBIRD.$year_mon.log";

    bless $self, $class;

    #Store Object with Instance Name
    $self->_set_object_instance($instance);
    return $self;
}

sub get_object_by_instance {
    my ($instance) = @_;
    return $Interfaces{$instance};
}

sub _set_object_instance {
    my ( $self, $instance ) = @_;
    $Interfaces{$instance} = $self;
}

sub init {

}

=item C<register()>

Used to associate child objects with the interface.

=cut

sub register {
    my ( $self, $object, $config, $class ) = @_;
    if ( $object->isa('DOORBIRD_Bell') ) {
        ::print_log("Registering Child Object for Doorbird bell");
        $self->{bell_object} = $object;
        if ( defined( $self->{bell_object} ) ) { sleep 3 }
        $self->configure_bell( $object, 'doorbell', $class ) if ($config);
    }
    elsif ( $object->isa('DOORBIRD_Motion') ) {
        ::print_log("Registering Child Object for Doorbird motion");
        $self->{motion_object} = $object;
        if ( defined( $self->{motion_object} ) ) { sleep 3 }
        $self->configure_bell( $object, 'motionsensor', $class ) if ($config);
    }
    elsif ( $object->isa('DOORBIRD_Relay') ) {
        ::print_log("Registering Child Object for Doorbird relay");
        $self->{relay_object} = $object;
        if ( defined( $self->{relay_object} ) ) { sleep 3 }
        $self->configure_bell( $object, 'dooropen', $class ) if ($config);
    }
}

sub configure_bell {
    my ( $self, $object, $type, $class ) = @_;
    use LWP::UserAgent;
    my $ua = LWP::UserAgent->new();
    $ua->timeout($httptimeout);
    my $req =
      $ua->get( 'http://'
          . $$self{user} . ':'
          . $$self{password} . '@'
          . $$self{doorbell_ip}
          . '/bha-api/notification.cgi?url=http://'
          . $$self{mh_ip} . ':'
          . $$self{mh_port}
          . '/mh/set;no_response?$'
          . $class
          . '?ON&user=&password=&event='
          . $type
          . '&subscribe=1' );
}

sub send_command {
    my ( $self, $object, $type, $class ) = @_;
    use LWP::UserAgent;
    my $ua = LWP::UserAgent->new();
    $ua->timeout($httptimeout);
    ::print_log("[DOORBIRD] Sent request /bha-api/$type.cgi");
    my $req = $ua->get( 'http://' . $$self{user} . ':' . $$self{password} . '@' . $$self{doorbell_ip} . '/bha-api/' . $type . '.cgi' );
}

=back

=head1 B<DOORBIRD_Bell>

=head2 SYNOPSIS

User code:

    $DOORBIRD_Bell = new DOORBIRD_Bell('DOORBIRD', 1);

     Wherein the format for the definition is:
    $DOORBIRD_Bell = new DOORBIRD_Bell(INSTANCE, ENABLECONFIG);

See C<new()> for a more detailed description of the arguments.


=head2 DESCRIPTION

 Tracks doorbell button pushes in MH. 

=head2 INHERITS

L<Generic_Item>

=head2 METHODS

=over

=cut

package DOORBIRD_Bell;
@DOORBIRD_Bell::ISA = ('Generic_Item');

=item C<new($doorbell, $config )>

Instantiates a new object.

$doorbell = The DOORBIRD of the doorbell that this zone is found on

$config = If you want this module to configure the DOORBIRD doorbell
to post updates to MH, then this value should be a 1, else 0.
If you disable auto configure (0), you must manually configure
the doorbell using the API with the MH URL you want the doorbell
to post to.


=cut

sub new {
    my ( $class, $doorbell, $config ) = @_;
    my $self = new Generic_Item();
    bless $self, $class;
    $doorbell = DOORBIRD::get_object_by_instance($doorbell);
    $doorbell->register( $self, $config, $class );
    $$self{doorbell} = $doorbell;

    #@{$$self{states}} = ('ON','OFF');
    return $self;
}

sub set {
    my ( $self, $p_state, $p_setby, $p_response ) = @_;
    if ( $p_state eq 'ON' ) {
        ::print_log( "[DOORBIRD::Bell] Received request " . $p_state . " for " . $self->get_object_name );
        $self->SUPER::set( $p_state, $p_setby );
        $self->set_with_timer( 'TON', 2, 'TOFF' );
    }
    if ( $p_state eq 'TOFF' ) {
        ::print_log( "[DOORBIRD::Bell] Received request OFF" . " by timer for " . $self->get_object_name );
        $self->SUPER::set( 'OFF', 'TIMER' );
    }
    if ( $p_state eq 'OFF' ) {
        ::print_log( "[DOORBIRD::Bell] Received request " . $p_state . " for " . $self->get_object_name );
        $self->SUPER::set( 'OFF', 'TIMER' );
    }
}

=back

=head1 B<DOORBIRD_Motion>

=head2 SYNOPSIS

User code:

    $DOORBIRD_Motion = new DOORBIRD_Motion('DOORBIRD', 1);

    Wherein the format for the definition is:
    $DOORBIRD_Motion = new DOORBIRD_Motion(INSTANCE, ENABLECONFIG);

    States:
    ON
    OFF

See C<new()> for a more detailed description of the arguments.


=head2 DESCRIPTION

Tracks doorbell motion in MH. 

=head2 INHERITS

L<Generic_Item>

=head2 METHODS

=over

=cut

package DOORBIRD_Motion;
@DOORBIRD_Motion::ISA = ('Generic_Item');

=item C<new( $doorbell, $config )>

Instantiates a new object.

$doorbell = The DOORBIRD doorbell that this motion sensor is found on

$config = If you want this module to configure the DOORBIRD doorbell
to post updates to MH, then this value should be a 1, else 0.
If you disable auto configure (0), you must manually configure
the doorbell using the API with the MH URL you want the doorbell
to post to.


=cut

sub new {
    my ( $class, $doorbell, $config ) = @_;
    my $self = new Generic_Item();
    bless $self, $class;
    $doorbell = DOORBIRD::get_object_by_instance($doorbell);
    $doorbell->register( $self, $config, $class );
    $$self{doorbell} = $doorbell;

    #@{$$self{states}} = ('ON','OFF');
    return $self;
}

sub set {
    my ( $self, $p_state, $p_setby, $p_response ) = @_;
    if ( $p_state eq 'ON' ) {
        ::print_log( "[DOORBIRD::Motion] Received request " . $p_state . " for " . $self->get_object_name );
        $self->SUPER::set( $p_state, $p_setby );
        $self->set_with_timer( 'TON', 20, 'TOFF' );
    }
    if ( $p_state eq 'TOFF' ) {
        ::print_log( "[DOORBIRD::Motion] Received request OFF" . " by timer for " . $self->get_object_name );
        $self->SUPER::set( 'OFF', 'TIMER' );
    }
    if ( $p_state eq 'OFF' ) {
        ::print_log( "[DOORBIRD::Motion] Received request " . $p_state . " for " . $self->get_object_name );
        $self->SUPER::set( 'OFF', 'TIMER' );
    }
}

=back

=head1 B<DOORBIRD_Relay>

=head2 SYNOPSIS

User code:

   $DOORBIRD_Relay = new DOORBIRD_Relay('DOORBIRD', 1);

   Wherein the format for the definition is:
   $DOORBIRD_Relay = new DOORBIRD_Relay(INSTANCE, ENABLECONFIG);

States:
ON
OFF

  Control States:
  TOGGLE (to trigger the relay)
  LIGHT_ON  (to enable the IR light on the door bell)

See C<new()> for a more detailed description of the arguments.


=head2 DESCRIPTION

Tracks/controls doorbell relay in MH. 

=head2 INHERITS

L<Generic_Item>

=head2 METHODS

=over

=cut

package DOORBIRD_Relay;
@DOORBIRD_Relay::ISA = ('Generic_Item');

=item C<new( $doorbell, $config )>

Instantiates a new object.

$doorbell = The DOORBIRD doorbell that this door relay is found on

$config = If you want this module to configure the DOORBIRD doorbell
to post updates to MH, then this value should be a 1, else 0.
If you disable auto configure (0), you must manually configure
the doorbell using the API with the MH URL you want the doorbell
to post to.


=cut

sub new {
    my ( $class, $doorbell, $config ) = @_;
    my $self = new Generic_Item();
    bless $self, $class;
    $doorbell = DOORBIRD::get_object_by_instance($doorbell);
    $doorbell->register( $self, $config, $class );
    $$self{doorbell} = $doorbell;
    @{ $$self{states} } = ( 'TOGGLE', 'LIGHT_ON' );
    return $self;
}

sub set {
    my ( $self, $p_state, $p_setby, $p_response ) = @_;
    if ( $p_state eq 'ON' ) {
        ::print_log( "[DOORBIRD::Relay] Received request " . $p_state . " for " . $self->get_object_name );
        $self->SUPER::set( $p_state, $p_setby );
        $self->set_with_timer( 'TON', 2, 'TOFF' );
    }
    if ( $p_state eq 'TOFF' ) {
        ::print_log( "[DOORBIRD::Relay] Received request OFF" . " by timer for " . $self->get_object_name );
        $self->SUPER::set( 'OFF', 'TIMER' );
    }
    if ( $p_state eq 'OFF' ) {
        ::print_log( "[DOORBIRD::Relay] Received request " . $p_state . " for " . $self->get_object_name );
        $self->SUPER::set( 'OFF', 'TIMER' );
    }
    if ( $p_state eq 'TOGGLE' ) {
        ::print_log( "[DOORBIRD::Relay] Received request " . $p_state . " for " . $self->get_object_name );
        $$self{doorbell}->send_command( $object, 'open-door', $class );
    }
    if ( $p_state eq 'LIGHT_ON' ) {
        ::print_log( "[DOORBIRD::Relay] Received request " . $p_state . " for " . $self->get_object_name );
        $self->send_command( $object, 'light-on', $class );
    }
}

=back

=head2 INI PARAMETERS

=head2 NOTES

=head2 AUTHOR

Wayne Gatlin <wayne@razorcla.ws>

=head2 SEE ALSO

=head2 LICENSE

This program is free software; you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation; either version 2 of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more details.

You should have received a copy of the GNU General Public License along with this program; if not, write to the Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.

=cut
