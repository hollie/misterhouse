# Category=Alarm System
##################################################################
#  Interface to DSC alarm system via DSC PC5400 Printer Module   #
#                                                                #
#  The PC5400 works with: PC5010, PC1555, PC580, PC5015, and     #
#  PC1575 main panels.                                           #
#                                                                #
#  Add these entries to your mh.ini file:                        #
#                                                                #
#    DSC_Alarm_serial_port=COM2                                  #
#    DSC_Alarm_baudrate=4800                                     #
#                                                                #
#  and then create object in your script via:                    #
#    $my_obj = new DSC_Alarm;                                    #
#                                                                #
#  Multiple instances may be supported by adding instance        #
#  numbers to the parms as in:                                   #
#                                                                #
#    DSC_Alarm:1_serial_port=COMx                                #
#    DSC_Alarm:1_baudrate=4800                                   #
#    DSC_Alarm:2_serial_port=COMy                                #
#    DSC_Alarm:2_baudrate=4800                                   #
#                                                                #
#  and then create object(s)in your script(s) via:               #
#    $my_obj = new DSC_Alarm('DSC_Alarm:1');                     #
#    $other  = new DSC_Alarm('DSC_Alarm:2');                     #
#                                                                #
#   DSC programming location 801 subsection 01 set to:           #
#    1-3---78                                                    #
#    1        = Printer Enabled                                  #
#     2       = Handshake from printer (DTR)                     #
#      3      = 80 Column Printer (off = 40 Column)              #
#       4     = 300  Baud Enabled                                #
#        5    = 1200 Baud Enabled                                #
#         6   = 2400 Baud Enabled                                #
#          7  = 4800 Baud Enabled                                #
#           8 = Local clock displays 24hr time                   #
#   DSC programming location 801 subsection 02 set to:           #
#    01 = English                                                #
#                                                                #
#  By: Danal Estes, N5SVV                                        #
#  E-Mail: danal@earthling.net                                   #
#                                                                #
##################################################################

# Note: The original version of DSC_Alarm.pm (October 2000) exposes 
# only "new" & "said", where "said" contains the raw data
# from the printer module.
#
# It is my intent to expose object methods (such as 
# "state") in a future release.  This may lead to 
# incompatible changes in existing methods.
# Danal Estes, October 9, 2000


$DSC_Alarm = new DSC_Alarm;

if (my $log = said $DSC_Alarm) {
   print_log "DSC_Alarm.pl data = $log\n";
   $log =~ /(..\:.. ..\/..\/.. )(.+)/;  # Remove date/time stamp that contains forward slashes... they cause DOS processes heartburn
   &alarm_page("$2");
}


# Subroutine to send a page / pcs message, etc.
sub alarm_page {
return;
   my ($text) =@_;
   $text = $text . $Date_Now . $Time_Now;

   my $p1 = new Process_Item("alpha_page -pin 9999999 -message \"$text\" ");
   start $p1;      # Run externally so as not to hang MH process

   print_log "Alarm notification sent, text = $text";
   speak "Djeeni says: $text";
}