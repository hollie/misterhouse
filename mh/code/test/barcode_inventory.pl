# Category=Barcode
#
#   Takes data from barcode_scan.pl and updates an inventory
#

$v_barcode_inventory =  new Voice_Cmd 'List barcoded inventory';
$v_barcode_inventory -> set_authority('anyweb');
$v_barcode_inventory -> set_info('List the barcode inventory');

if (said $v_barcode_inventory) {
    my %data = dbm_read "$config_parms{data_dir}/barcode_inventory.dbm";
    my $results = "List of barcoded inventory:\n";
    for my $key (sort %data) {
        next unless $data{$key};
        $results .= "  count=$data{$key} code=$key\n";
    }
    display $results;
}

my $mode;
$mode = state $barcode_mode;
return unless $mode =~ /inventory/;

if (my $scan = state_now $barcode_data) {
    my ($type, $code, $isbn) = split ' ', $scan;

    my $dbm_file = "$config_parms{data_dir}/barcode_inventory.dbm";

    my $count = dbm_read($dbm_file, $scan);
    $count = 0 unless $count;
    $count-- if $mode eq 'delete inventory';
    $count++ if $mode eq 'add inventory';
    $count = 0 if $count < 0 or $mode eq 'clear inventory';
    dbm_write($dbm_file, $scan, $count);
    my $msg = "Count after $mode for $scan is $count";
    print_log $msg;
                                # Fill in the web search file also, in case we are in the wrong mode
    my $html_file = "$config_parms{html_dir}/barcode_search.html";
    file_write $html_file, $msg;
}


