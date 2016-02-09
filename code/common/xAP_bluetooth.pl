
# Category = xAP

#@ This code will monitor the xAP bluetooth client: mh/bin/xAP-bluetooth
#@ (that client must run on a linux box, requirements listed in the header).

$xap_bluetooth  = new xAP_Item('xap-bt.status');
$presence_phone = new Generic_Item;

if ( state_now $xap_bluetooth) {
    my $address = $$xap_bluetooth{'xap-bt.status'}{address};
    my $name    = $$xap_bluetooth{'xap-bt.status'}{name};
    my $status  = $$xap_bluetooth{'xap-bt.status'}{status};
    $name = $address unless $name;
    set $presence_phone "$name $status";
}

$presence_phone->tie_event('print_log "phone status: $state"');

if ( $state = state_now $presence_phone) {
    my ( $name, $status ) = split ' ', $state;
    my $greeting = ( $status eq 'near' ) ? 'Hello' : 'Goodbye';
    print_log "$greeting $name";

    #   speak "$greeting $name";
}
