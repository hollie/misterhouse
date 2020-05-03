#Category=OpenSprinkler

#@Utility to run an external script and parse the result into updated runtimes

my $os_external_source = "";
$os_external_source = $config_parms{os_external_data_source} if ( defined $config_parms{os_external_data_source} );
my $os_external_output_file = "";
$os_external_output_file = $config_parms{os_external_data_output_file} if ( defined $config_parms{os_external_data_output_file} );
my $os_external_program_crontab = "";
$os_external_program_crontab = $config_parms{os_external_data_crontab} if ( defined $config_parms{os_external_data_crontab} );
my $os_program = "";
$os_program = $config_parms{os_external_data_program} if ( defined $config_parms{os_external_data_program} );

my $start;

$p_os_extprog = new Process_Item($os_external_source);
eval( $start = time_cron($os_external_program_crontab) );

if ( $start or $Startup ) {
    print_log "[OpenSprinkler] Get_ext_data: Starting external program...";
    start $p_os_extprog;
}

if ( file_changed $os_external_output_file ) {
    my $data = file_tail( $os_external_output_file, 1 );
    $data =~ s/\s//g;
    my ( $time, $runtimes ) = $data =~ /\[(\[[\-,0-9]+\]),\[([0-9,]+)\]\]/;
    print_log "[OpenSprinkler] get_ext_data: New Data, times=$time, runtimes=$runtimes";
    my $program_object = &get_object_by_name($os_program);
    $program_object->set_runtimes( $time, $runtimes );
}
