# Category = Misc

#@ Searches for files on any Windows networked drive, using mh/bin/find_files

$find_files        = new Generic_Item;
$find_files_boxes  = new Generic_Item;
&tk_entry('Find Files', $find_files, 'on boxes', $find_files_boxes);

my $fild_files_results = "$config_parms{data_dir}/find_program_results.txt";
$fild_files_p  = new Process_Item;
$fild_files_p -> set_output($fild_files_results);

if ($state = state_now $find_files) {
    my $boxes = state $find_files_boxes;
    $boxes = 'all' unless $boxes;
    speak "Searching for $state on $boxes";
    set   $fild_files_p qq[find_files -boxes "$boxes" "$state"];
    start $fild_files_p;
}
if (done_now $fild_files_p) {
    speak "Find files search for $find_files->{state} is done";
    my $results = file_read $fild_files_results, 1, 1;
    display $results, 0, "Find Files Results for $find_files->{state}", 'fixed';
}

