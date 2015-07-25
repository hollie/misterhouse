#Category=OpenSprinkler

#@Utility to run an external script and parse the result into updated runtimes

my $os_external_program 		= "/Users/howard/Scripts/ETOweather/get_et.sh";
$os_external_program 		= $config_parms{os_external_data_program} if (defined $config_parms{os_external_data_program}) ;
my $os_external_output_file 	= "/Users/howard/Scripts/ETOweather/weatherprograms/run";
#my $os_external_program_crontab = "1 22,23 * 5-10 *";
my $os_external_program_crontab = "* * * 5-10 *";
my $os_program					= "osp_program2";
my $start;

$p_os_extprog = new Process_Item($os_external_program);
eval ($start = time_cron($os_external_program_crontab));

if ($start) {
	print_log "[OpenSprinkler] Get_ext_data: Starting external program...";
#	start $p_os_extprog;
}

if (file_changed $os_external_output_file ) {
	my $data = file_tail($os_external_output_file, 1) ;
	$data =~ s/\s//g;
	my ($time, $runtimes) = $data =~ /\[(\[[\-,0-9]+\]),\[([0-9,]+)\]\]/;
	print_log "[OpenSprinkler] get_ext_data: New Data, times=$time, runtimes=$runtimes";
  	my $program_object = &get_object_by_name($os_program);
  	$program_object -> set_runtimes($time,$runtimes);
}

#display_table
#	can fetch data
#	need to parse &start=&records=
#	need next/prev buttons

#OS