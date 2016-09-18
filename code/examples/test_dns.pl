
# Set the mh.ini DNS_server parm to enable domain name lookups

#my $address = '64.208.37.54';  # Google
my $address = '204.146.18.33';    # IBM

#my $address = '192.168.0.2';
#my $address = 'misterhouse.net';

# This is the direct mode ... mh may pause
$v_test_dns1 = new Voice_Cmd 'Run the dns test1';
$v_test_dns1->tie_event("print 'domain=', net_domain_name '$address'");

# This is the background mode ... no mh pause here
$v_test_dns2 = new Voice_Cmd 'Run the dns test2';
$v_test_dns2->tie_event("net_domain_name_start 'test', '$address'");
print_log "Domain=$state" if $state = net_domain_name_done 'test';
