# Category=Calendar

# Watch for changes made to a Palm datebook.dat file

$axel_datebook_file =
  new File_Item "/home/axel/Palm/BrownA/datebook/datebook.dat";
set_watch $axel_datebook_file if $Reload;

$debbie_datebook_file =
  new File_Item "/home/debbie/Palm/Debbie/datebook/datebook.dat";
set_watch $debbie_datebook_file if $Reload;

my $calendarScript = "palm_calendar";

$p_palmdatebook = new Process_Item("$calendarScript 2>&1");

#$p_palmdatebook->add("&updateOrganizer");
$p_palmdatebook->set_output("pdb.txt");

if ($New_Minute) {
    my $text = "";
    if ( changed $axel_datebook_file) {
        $text = "Axel's";
        set_watch $axel_datebook_file;
    }
    elsif ( changed $debbie_datebook_file) {
        $text = "Debbie's";
        set_watch $debbie_datebook_file;
    }
    if ( $text ne "" ) {
        $text .= " Datebook info is being imported";
        speak $text;
        print_log $text;
        start $p_palmdatebook;
    }
}

speak "Calendar file updated" if done_now $p_palmdatebook;

$v_updateCalendar = new Voice_Cmd( "Please import the datebook data", 0 );
if ( said $v_updateCalendar) {
    speak "OK, updating the calendar files";
    start $p_palmdatebook;
}
