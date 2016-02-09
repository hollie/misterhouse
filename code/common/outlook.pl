# Category = Time

#@ Reads and announces Windows Outlook calendar entries.
#@ Set mh.ini parm outlook_file to your .pst file.  For example:
#@   outlook_file = c:/Documents and Settings/winter/Local Settings/Application Data/Microsoft/Outlook/OUTLOOK.PST

my $outlook_file = "$Code_Dirs[0]/outlook_programing.pl";

#p_outlook_read  = new Process_Item("outlook_read -version 98 -pl_file $outlook_file");
$p_outlook_read =
  new Process_Item("outlook_read             -pl_file $outlook_file");

#f_outlook_data  = new File_Item 'c:\WIN98\Application data\Microsoft\Outlook\outlook.pst';
$f_outlook_data = new File_Item $config_parms{outlook_file};
set_watch $f_outlook_data if $Reload;

# Run outlook_read if we asked for it or if
# the outlook.pst file has changed.  Lets only
# check this periodically, as it probably changes
# often when people are messing around with email
$v_outlook_read = new Voice_Cmd 'Check the Outlook calendar';
$v_outlook_read->set_info(
    'This will check create mh events to announce Outlook calendar entries');
if ( said $v_outlook_read or ( new_minute 15 and changed $f_outlook_data) ) {
    start $p_outlook_read;
    set_watch $f_outlook_data;    # Reset so changed function works
}

if ( done_now $p_outlook_read) {
    &do_user_file($outlook_file);    # This will pull in the new events
}

# Programing note:
#
# This code perodically calls outlook_read to create events based on
# MS Outlook calender entries.  We could call Outlook directly from mh,
# but unfortunatly, Outlook uses an older MAPI OLE interface, so we have
# to use "single threaded apartment" OLE.  If we do this from mh, it
# has unfortunate side effects (e.g. ghost DDE and OLE windows, and
# message que stalls).
#
# So, instead, we run outlook_read as a sperate process.
# This is better anyway, so we don't cause mh to hang if for some reason
# it takes a while to do the calendar search.
