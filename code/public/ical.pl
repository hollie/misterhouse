# Category=Timed Events

my $ical_out_file = "$config_parms{code_dir}/ical_programing.pl";
$p_ical_read = new Process_Item(
    "ical_load -days 1 -calendar $config_parms{calendar_file} -pl_file $ical_out_file"
);

$f_ical_data = new File_Item( $config_parms{calendar_file} );
set_watch $f_ical_data if $Reload;

# Run ical_read if we asked for it or if
# the calendar file has changed.
$v_ical_read = new Voice_Cmd 'Load the ical calendar';
$v_ical_read->set_info(
    'This will check create mh events to announce calendar entries');
if ( said $v_ical_read
    or ( $New_Minute and !( $Minute % 5 ) and changed $f_ical_data) )
{
    start $p_ical_read;
    set_watch $f_ical_data;    # Reset so changed function works
}

if ( done_now $p_ical_read) {
    &do_user_file($ical_out_file);    # This will pull in the new events
}
