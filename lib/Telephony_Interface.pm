use strict;

use Telephony_Item;

package Telephony_Interface;
@Telephony_Interface::ISA = ('Telephony_Item');

my ($hooks_added, @list_ports, %list_objects, %type_by_port, %caller_id_data);

# US Robotics 56k Voice model 0525 -> rockewell

my %table = (default     => ['ATE1V1X4&C1&D2S0=0+VCID=1',          38400, 'dtr'],
             motorola    => ['ATE1V1X4&C1&D2S0=0*ID1',             38400, 'dtr'],
             powerbit    => ['ATE1V1X4&C1&D2S0=0#CID=1',           38400, 'dtr'],
             rockwell    => ['ATE1V1X4&C1&D2S0=0#CID=1',           38400, 'dtr'],
             supra       => ['ats0=0#cid=1',                       38400, 'dtr'],
             cirruslogic => ['ats0=0+vcid=1',                      38400, 'dtr'],
             zyxel       => ['ATE1V1S40.2=1S41.6=1S42.2=1&L1M3N1', 38400, 'dtr'],
             netcallerid => ['', 4800, '']);

sub new {
    my ($class, $name, $port, $type)= @_;
    my $self={};
    bless $self, $class;

    unless ($port) {
#       print "\nTelephony_Interface error, no port specified: name=$name.\n";
    }

                                # Allow for a user defined type
                                # e.g.  'modem1:ATE1V1X4&C1&D2S0=0#CID=1,38400,dtr'
    if ($type and $type =~ /(\S+?):(.+)/) {
        $type = $1;
        @{$table{$type}} = split ',', $2;
    }

    $type = 'default' unless $type;
    $type = 'default' unless $table{$type}; # In case someone makes up a bad type

    $name = 'Line 1'  unless $name;

    $$self{name} = $name;
    $$self{type} = $type;
    $$self{port} = $port;
    &open_port($self) if $port;
    push(@{$list_objects{$name}}, $self);
    unless ($hooks_added++) {
        &::Reload_pre_add_hook(   \&Telephony_Interface::reload_reset,   1);
        &::MainLoop_pre_add_hook( \&Telephony_Interface::check_for_data, 1);
    }
    return $self;
}

sub open_port {
    my ($self) = @_;
    my $name =    $$self{name};
    my $type = lc $$self{type};
    my $port =    $$self{port};
    return if $main::Serial_Ports{$name}; # Already open
    push @list_ports, $name;
    $type_by_port{$name} = $type;
    my $baudrate  = 38400;
    my $handshake = 'dtr';
    if ($table{$type}) {
        $baudrate  = $table{$type}[1];
        $handshake = $table{$type}[2];
    }
    print "Telephony_Interface port open:  n=$name t=$type p=$port b=$baudrate h=$handshake\n"
      if $main::Debug{phone};
    if ($port) {
        &::serial_port_create($name, $port, $baudrate, $handshake);
        push(@::Generic_Serial_Ports, $name);
        &init unless $port =~ /proxy/;
    }
}

sub init {
    my ($self) = @_;
    my $name =    $$self{name};
    my $type = lc $$self{type};
    if ($table{$type} and my $init = $table{$type}[0]) {
        &Serial_Item::send_serial_data($name, $init);
        &::print_log("$name interface, type=$type, has been initialized with $init");
    }
}

sub reload_reset {
    undef %list_objects;
}

sub check_for_data {
    for my $port (@list_ports) {
        if (my $data = $main::Serial_Ports{$port}{data_record}) {
            $main::Serial_Ports{$port}{data_record} = undef;
                                # Ignore garbage data (ascii is between ! thru ~)
            $data = '' if $data !~ /^[\n\r\t !-~]+$/;
            $caller_id_data{$port} .= ' ' . $data;
            print "Phone data: $data.\n" if $main::Debug{phone};
            if (($caller_id_data{$port} =~ /NAME.+NU?MBE?R/s) or
                ($caller_id_data{$port} =~ /NU?MBE?R.+NAME/s) or
                ($caller_id_data{$port} =~ /NU?MBE?R.+MESG/s) or
                ($caller_id_data{$port} =~ /NU?MBE?R/ and $main::config_parms{caller_id_format} eq 'number only') or
                ($caller_id_data{$port} =~ /END MSG/s) or         # UK format
                ($caller_id_data{$port} =~ /FM:/)) {
                &::print_log("Callerid: $caller_id_data{$port}");
                &process_cid_data($port, $caller_id_data{$port});
                undef $caller_id_data{$port};
             }
            else {
                &process_phone_data($port, 'ring') if $data =~ /ring/i;
            }
        }
    }
}

                                # Process Other phone data
sub process_phone_data {
    my ($port, $data) = @_;
                                # Set all objects monitoring this port
    for my $object(@{$list_objects{$port}}) {
        print "Setting Telephony_Interface object $$object{name} to $data.\n";
        $object->SUPER::set('ring') if $data eq 'ring';
		$object->ring_count($object->ring_count()+1);  # Where/when does this get reset??
    }
}

                                # Process Caller ID data
sub process_cid_data {
    my ($port, $data)= @_;

    my ($number, $name, $time, $date);

    $data =~ s/[\n\r]//g; # Drop newlines

                                # Clean up Dock-N-Talk data
#   ###DATE...NMBR5071234567...NAMEDock-N-Talk+++
#   ###DATE...NMBR...NAME   -MSG OFF-+++
    return if $data =~ /-MSG OFF-/;
    $data =~ s/Dock-N-Talk//;

    my $type = $type_by_port{$port};
    if ($type eq 'weeder') {
        ($time, $number, $name) = unpack("A13A13A15", $data);
    }
    elsif ($type eq 'netcallerid') {
#  ###DATE12151248...NMBR2021230002...NAMEBUSH GEORGE +++
#  ###DATE01061252...NMBR...NAME-UNKNOWN CALLER-+++
#  ###DATE01061252...NMBR...NAME-PRIVATE CALLER-+++
#  ###DATE...NMBR...NAME MESSAGE WAITING+++
        ($date, $time, $number, $name) = $data =~ /DATE(\d{4})(\d{4})\.{3}NMBR(.*)\.{3}NAME(.*?)\++$/;
        ($name)                        = $data =~ /NAME(.*?)\++$/ unless $date;
        ($number)                      = $data =~ /NMBR(.+)\.{3}/ unless $name;
    }
# NCID data=CID:*DATE*10202003*TIME*0019*NMBR*2125551212*MESG*NONE*NAME*INFORMATION*
# http://ncid.sourceforge.net/
    elsif ($type eq 'ncid') {
        ($date, $time, $number, $name) = $data =~/CID:\*DATE\*(\d{8})\*TIME\*(\d{4})\*NMBR\*(\d{10})\*MESG\*.*\*NAME\*([^\*]+)\*$/;
    }
    elsif ($type eq 'zyxel'or $type eq 'motorola') {
        ($date)   = $data =~ /TIME: *(\S+)\s\S+/s;
        ($time)   = $data =~ /TIME: *\S+\s(\S+)/s;
        ($name)   = $data =~ /CALLER NAME: *([^\n]+)/s;
        ($name)   = $data =~ /REASON FOR NO CALLER NAME: *(\S+)/s   unless $name;
        ($number) = $data =~ /CALLER NUMBER: *(\S+)/s;
        ($number) = $data =~ /REASON FOR NO CALLER NUMBER: *(\S+)/s unless $number;
        if ($type eq 'motorola') {
           ($number) =~ s/\(//;
           ($number) =~ s/\)/-/;
        }
        $name = substr($name, 0, 15);
    }
    else {
        ($date)   = $data =~ /DATE *= *(\S+)/s;
        ($time)   = $data =~ /TIME *= *(\S+)/s;
        ($name)   = $data =~ /NAME *= *(.{1,15})/s;
        ($name)   = $data =~ /MESG *= *([^\n]+)/s unless $name;
        $name     = 'private'     if $name eq '080150';
        $name     = 'unavailable' if $name eq '08014F';
        ($number) = $data =~ /NU?M?BE?R *= *(\S+)/s;
        ($number) = $data =~ /FM:(\S+)/s unless $number;
    }

    $name   = '' unless $name;
    $number = '' unless $number;

    unless ($name or $number) {
        print "\nCallerid data not parsed: p=$port t=$type d=$data date=$date time=$time number=$number name=$name\n";
        return;
    }

    $number =~ s/[\(\)]//g;     # Drop () around area code

    $time = "$date $time" unless $time;

    my $cid_type = 'N';
    $cid_type = 'P' if $name =~ /private/i or uc $name eq 'P';
    $cid_type = 'U' if $name =~ /unknown/i or uc $name =~ /unavailable/i;
    if ($name =~ /-unknown name-/i) { #Netcallerid reports "-UNKNOWN NAME-"when it knows number, but not name
        $cid_type = 'N';
        $name='';
    }
    $cid_type = 'U' if uc $name eq 'O' or $number eq 'O';
    $cid_type = 'N' if $number =~ /^[\d\- ]+$/;	  # Override the type if the number is known


    print "Callerid data: port=$port type=$type cid_type=$cid_type name=$name number=$number date=$date time=$time\n   data=$data.\n"
      if $main::Debug{phone};

                                # Set all objects monitoring this port
    for my $object(@{$list_objects{$port}}) {
        $object->address($port);
        $object->cid_name($name);
        $object->cid_number($number);
        $object->cid_type($cid_type);
#       $object->ring_count('2');  # Need this??
        $object->SUPER::set('cid');
    }
}


sub set {
    my ($self, $p_state, $p_setby) = @_;
    if ($p_state =~ /^offhook/i) {
	&Serial_Item::send_serial_data($self->{name}, 'ATA');
    }
    elsif ($p_state =~ /^onhook/i) {
	&Serial_Item::send_serial_data($self->{name}, 'ATH');
    }
    $self->SUPER::set($p_state, $p_setby);
}

sub set_test {
    my ($self, $data) = @_;
    my $name = $$self{name};
    $main::Serial_Ports{$name}{data_record} = $data;
}

1;

__END__

UK callerid data:

CID RING
CALLING MSG
DATE TIME=10/05 11:39
NO MESSAGE REASON=SECRET
NAME=WITHHELD
WITHHELD
END MSG
RING

RING

RING

RING

CID RING

CID RING
CALLING MSG
DATE TIME=10/05 20:27
NBR=01231231234
END MSG

---
Supra modem:
 DATE = 1229 TIME = 1848 NAME = VANCOUVER    WA NMBR = 3601231234
