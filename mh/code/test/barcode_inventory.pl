# Category=Barcode
#
#   Takes data from barcode_scan.pl and updates an inventory
#

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
    print_log "Count after $mode for $scan is $count";
}

