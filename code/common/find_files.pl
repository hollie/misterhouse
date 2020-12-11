# Category = Misc

#@ Searches for files on any Windows networked drive, using mh/bin/find_files

$find_files       = new Generic_Item;
$find_files_boxes = new Generic_Item;
&tk_entry( 'Find Files', $find_files );
&tk_entry( 'on boxes',   $find_files_boxes );

my $find_files_results = "$config_parms{data_dir}/find_program_results.txt";
$p_find_files = new Process_Item;
$p_find_files->set_output($find_files_results);

if ( state_now $find_files) {
    my $state = $find_files->{state};
    my $boxes = state $find_files_boxes;
    $boxes = 'all' unless $boxes;
    $state =~ s/"//g;    # kill double quotes
    $boxes =~ s/"//g;    # kill double quotes
    speak "app=pc Searching for $state on $boxes...";
    set $p_find_files qq[find_files -boxes "$boxes" "$state"];
    start $p_find_files;
}

if ( done_now $p_find_files) {
    speak "Find files search for $find_files->{state} is done.";
    my $results = file_read $find_files_results, 1, 1;
    display $results, 0, "Find Files Results for $find_files->{state}", 'fixed';
}

