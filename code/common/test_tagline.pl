# Category=Test

#@ This module speaks an entry from the house tagline file once per minute.

$house_tagline_test = new File_Item("$Pgm_Root/data/remarks/1100tags.txt");
speak( read_random $house_tagline_test) if $New_Minute;

