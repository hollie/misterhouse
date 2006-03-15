# ============================================================================

package Insteon_Item;

# ============================================================================
# I don't know if I want to use Generic or Serial. Right now it's Serial as I
# am using the X10_Item and RCS_Item as an example.
#
# ============================================================================
#my (%items_by_house_code, %appliances_by_house_code, $sensorinit);
=begin comment
# ============================================================================
Use these mh.ini parameters to enable this code:

 example_interface_module = example_interface
 example_interface_port   = /dev/ttyM9


Here is an example of reading/writing using this object:

 $test_example1 = new example_interface('string_on',   ON);
 $test_example1 ->add                  ('string_off', OFF);

 print "Example 1 data received: $state\n" if $state = state_now $test_example1;
 set $test_example1 OFF if new_second 5;


Here is another example

 $interface = new example_interface;
 $interface ->add('out123', 'request_status');
 $interface ->add('in123',  'door_open');

 set $interface 'request_staus' if $New_Second;
 speak 'Door just opened' if 'door_open' eq state_now $interface;


You could also query the incoming serial data directly:

 if (my $data = said $interface) {
	print_log "Data from interface: $data";
 }


Methods (sub) 'startup' or 'serial_startup' are automatically
called by mh on startup.

# ============================================================================
=cut

sub reset {
#   print "\n\nRunning X10_Item reset\n\n\n";
}

# ============================================================================
#@Insteon_Item::ISA = ("Serial_Item");
@Insteon_Item::ISA = ("X10_Item");
@Insteon_Item::Inherit::ISA = @ISA;

=begin comment
#
# This code was taken directly from mh (I put it there ;-)
#
sub startup {
    require 'iplcs.pm';

    if (&serial_port_create('iplcs', $config_parms{iplcs_port}, 4800, 'none')) {
	#$iplcs_objects{timer} = new Timer;
	#$iplcs_objects{active} = new Generic_Item;
    }
    #&main::serial_port_create('BX24', $main::config_parms{BX24_port}, 19200, 'none', 'raw');

    # Add hook only if serial port was created ok
    #&::MainLoop_pre_add_hook(\&X10_BX24::check_for_data, 1) if $main::Serial_Ports{BX24}{object};
}
=cut

sub new {
    my ($class, $id, $interface, $type) = @_;

    my $self  = $class->Generic_Item::new();

    bless $self, $class;

    $id = "Z$id"; # This is just temporary, until I write a proper set routine
    $self->{insteon_id} = $id;

    $self->{type} = $type;

#   restore_data $self ('level'); # Save brightness level between restarts

    $self->set_interface($interface);

    return $self;
}
                                # Check for toggle data
sub set {
    my ($self, $state, $set_by) = @_;
    return if &main::check_for_tied_filters($self, $state);
 
    if ($state eq 'toggle') {
	if ($$self{state} eq 'on') {
	    $state = 'off';
	}
	else {
	    $state = 'on';
	}
	&main::print_log("Toggling X10_Item object $self->{object_name} from $$self{state} to $state");
    }

    # OK here is where the processing begins! We need the format I<abcdef><cmd> 
    #

    unless (defined $state) {
        print "Insteon_Item set with an empty state on $$self{object_name}\n";
        $state = 'default_state';
    }

    my $insteon_id;
    # Allow for upper/mixed case (e.g. treat ON the same as on ...
    # so Insteon_Items is simpler)
    if (defined $self->{id_by_state}{$state}) {
        $insteon_id = $self->{id_by_state}{$state};
    }
    elsif (defined $self->{id_by_state}{lc $state}) {
        $insteon_id = $self->{id_by_state}{lc $state};
    }
    else {
        $insteon_id = $state;
    }
    # uc since other mh processing can lc it to avoid state sensitivity
    my $insteon_data = $insteon_id;

=begin comment
    # ------------------------------------------------------------------------
    # Allow for Serial_Item's without states
    unless (defined $state) {
        print "Serial_Item set with an empty state on $$self{object_name}\n";
        $state = 'default_state';
    }

    my $serial_id;
                                # Allow for upper/mixed case (e.g. treat ON the same as on ... so X10_Items is simpler)
    if (defined $self->{id_by_state}{$state}) {
        $serial_id = $self->{id_by_state}{$state};
    }
    elsif (defined $self->{id_by_state}{lc $state}) {
        $serial_id = $self->{id_by_state}{lc $state};
    }
    else {
        $serial_id = $state;
    }
				# uc since other mh processing can lc it to avoid state sensitivity
    my $serial_data = $serial_id;
    $serial_data = uc $serial_data unless $self->{states_casesensitive};

    return if &set_prev_pass_check($self, $serial_id);

    &Generic_Item::set_states_for_next_pass($self, $state, $set_by);

    my $port_name = $self->{port_name};
    my $interface = $self->{interface};
    $interface = '' unless $interface;

    print "Serial_Item: port=$port_name self=$self state=$state data=$serial_data interface=$$self{interface}\n"
        if $main::Debug{serial};

    return if     $main::Save{mode} eq 'offline';
    return unless %main::Serial_Ports;


    # First deal with X10 strings.  Assume X10 capable if interface is set.
    # Ideally, we would test for specific X10 interfaces, but so far it only
    # gets set if it is an X10 interface.
    if (($serial_data =~ /^X/ and $interface ne '') or $self->isa('X10_Item')) {
    }

    # Check for X10 All-on All-off house codes
    #  - If found, set states of all X10_Items on that housecode
    if ($serial_data =~ /^X(\S)([OP])$/) {
        print "db l=$main::Loop_Count X10: mh set House code $1 set to $2\n" if $main::Debug{x10};
        my $state = ($2 eq 'O') ? 'on' : 'off';
        &X10_Item::set_by_housecode($1, $state);
    }

    # Check for other items with the same codes
    #  - If found, set them to the same state
    if ($serial_items_by_id{$serial_id} and my @refs = @{$serial_items_by_id{$serial_id}}) {
        for my $ref (@refs) {
            next if $ref eq $self;
                                # Only compare between items on the same port
            my $port_name1 = ($self->{port_name} or ' ');
            my $port_name2 = ($ref ->{port_name} or ' ');
            next unless $port_name1 eq $port_name2;

            print "Serial_Item: Setting duplicate state: id=$serial_id item1=$$self{object_name} item2=$$ref{object_name}\n"
                if $main::Debug{serial};
            if ($state = $$ref{state_by_id}{$serial_id}) {
                $ref->set_receive($state, $set_by);
            }
            else {
                $ref->set_receive($serial_id, $set_by);
            }
        }
    }
    # ------------------------------------------------------------------------
=cut
    print "\tSetting Insteon_Item to $state\n";
    $self->SUPER::set($state, $set_by); # <- the super set is what is messing me up and not adding the correct info
    #&send_x10_data($interface, 'X' . $serial_chunk, $self->{type});
    print "\tDone!\n";
}

package Insteon_Appliance;

@Insteon_Appliance::ISA = ('Insteon_Item');

sub new {
    my ($class, $id, $interface) = @_;
    my $self = {};
    $$self{state} = '';

    bless $self, $class;

#   print "\n\nWarning: duplicate ID codes on different X10_Appliance objects: id=$id\n\n" if $serial_item_by_id{$id};

    $id = "Z$id";
    $self->{x10_id} = $id;

    $self-> add ($id . 'J', 'on');
    $self-> add ($id . 'K', 'off');
    $self-> add ($id , 'manual');
    $self-> add ($id . 'STATUS', 'status');

    $self->set_interface($interface);

    return $self;
}

package Insteon_Lamp;

@Insteon_Lamp::ISA = ('Insteon_Item');

sub new {
    my ($class, $id, $interface) = @_;
    my $self = {};
    $$self{state} = '';

    bless $self, $class;

#   print "\n\nWarning: duplicate ID codes on different X10_Appliance objects: id=$id\n\n" if $serial_item_by_id{$id};

    $id = "Z$id";
    $self->{x10_id} = $id;

    $self-> add ($id . 'J', 'on');
    $self-> add ($id . 'K', 'off');
    $self-> add ($id . 'K', 'dim');
    $self-> add ($id . 'K', 'bri');
    $self-> add ($id . 'K', 'bright');
    $self-> add ($id , 'manual');
    $self-> add ($id . 'STATUS', 'status');

    $self->set_interface($interface);

    return $self;
}

# ============================================================================
=begin comment
#
# The following code is stolen directly from Serial_Item.pm
#
sub send_x10_data {
    my ($interface, $serial_data, $module_type) = @_;
    my ($isfunc);

    return if &main::proxy_send($interface, 'send_x10_data', $serial_data, $module_type);

    if ($serial_data =~ /^X[A-P][1-9A-G]$/) {
        $isfunc = 0;
        $x10_save_unit = $serial_data;
    }
    else {
        $isfunc = 1;
    }
    print "X10: interface=$interface isfunc=$isfunc save_unit=$x10_save_unit data=$serial_data\n" if $main::Debug{x10};

    if ($interface eq 'iplcs') {
	# ncpuxa wants individual codes with X
        &main::print_log("Using iplcs to send: $serial_data");
        &iplcs::send($main::Serial_Ports{iplcs}{object}, $serial_data);
    }
    elsif ($interface eq 'iplcu') {
	# ncpuxa wants individual codes with X
        &main::print_log("Using iplcu to send: $serial_data");
        &iplcs::send($main::config_parms{iplcu_port}, $serial_data);
    }


    else {
        print "\nError, X10 interface not found: interface=$interface, data=$serial_data\n";
    }

    &send_x10_data_hooks($serial_data);   # Created by &add_hooks
}

sub set_interface {
    my ($self, $interface) = @_;
                                # Set the default interface
    unless ($interface and $interface =~ /\S/) {

	if ($main::Serial_Ports{iplcs}{object}) {
	    $interface = 'iplcs';
	}
    }
    $$self{interface} = lc($interface) if $interface;
}
=cut
#
1;
