# Category = Time

#@ Generate ical compatible holiday information every year
#@ Can be used with ical2vsdb to reimport holiday information back into MH

=begin comment

mh.ini parameters required

holiday_definition_file = path to filename that has holiday definitions
ie holiday_definition_file = $Pgm_Root/data/holidays.ca_ab for Alberta, Canada

optional

   holiday_ical_filename = filename of generated holiday information (defaults to $Pgm_Root/web/holical.ics)
   holiday_no_stats = 1 to not generate stat holidays (next business day if the holiday is on a weekend)

-------------------------------------------------------------------------------------
Note: $Pgm_Root/bin/holical (ical creator helper program) has several dependencies:

Date::Easter, Date::Manip, Date::ICal, Data::ICal, Data::ICal::Entry::Event
-------------------------------------------------------------------------------------

=cut

$p_holical = new Process_Item();

$v_generate_holidays =
  new Voice_Cmd('Generate holiday information for [1,2,3,4] year(s)');
$v_generate_holidays->set_info('Generate ical compatible holiday information');
$v_generate_holidays->set_authority('anyone');
my $holiday_output_filename = $config_parms{holiday_ical_filename};
$holiday_output_filename = "$Pgm_Root/web/holical.ics"
  if !$holiday_output_filename;

if (   ( said $v_generate_holidays)
    or ($New_Year)
    or ( ($Reload) and !( -e $holiday_output_filename ) ) )
{

    print_log "MH_Holidays: Starting holiday generation process...";
    my $options;
    $options = "-n" if $config_parms{holiday_no_stats};
    my $years;
    $years = said $v_generate_holidays;
    $years = "0" if !$years;

    if ( -e $config_parms{holiday_definition_file} ) {
        $p_holical->set(
            "holical -y +$years $options -f $holiday_output_filename $config_parms{holiday_definition_file} "
        );
        start $p_holical;
    }
    else {
        print_log "MH_Holidays: Error, cannot find holiday definition file!";
    }
}
