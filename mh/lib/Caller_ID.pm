package Caller_ID;
use strict;

use vars '%name_by_number', '%state_by_areacode';
my ($my_areacode, @my_areacodes, $my_state);



sub make_speakable {
    my($data, $format,$local_area_code_language) = @_;


=cut begin

format=1: Weeder CID data looks like this:
I03/18 22:05 507-288-1030 WINTER BRUCE LA

Here are a couple of examples of data from callerid modems

DATE = 990305
TIME = 1351
NMBR = 5071234567
NAME = KLIER BRIAN J


RING

DATE=0119
TIME=2215
NAME=ARCHER L       NMBR=5071234567

RING

RING RING DATE=0224 NAME=ONMBR=5072884388 

***************************************
Canadian (Quebec - Bell Canada) format:

DATE = 0910
TIME = 0137
NAME = O
DDN_NMBR= 9932562

***************************************
Switzerland format:

RING
FM:07656283xx TO:86733xx

(Notes: 
- 'O' as a name means 'Unavailable'
- the phone# doesn'n include the area code if in the same area code than you.
- instead of 'NMBR', it's 'DDN_NMBR.'. don't ask me why...
)
***************************************

=cut end


# Switch name strings so first last, not last first.
# Use only the 1st two blank delimited fields, as the 3rd, 4th are usually just initials or incomplete

    my ($number,$numberTo, $name, $time, $date, $last, $first, $middle, $areacode, $local_number, $caller);

# Last First M
# Last M First


    if ($format == 2) {
        ($date)   = $data =~ /DATE *= *(\S+)/s;
        ($time)   = $data =~ /TIME *= *(\S+)/s;
        $time = "$date $time";
        ($number) = $data =~ /NMBR *= *(\S+)/s;

#       ($name)   = $data =~ /NAME *= *(.+)/s;
        ($name)   = $data =~ /NAME *= *([^\n]+)/s;

        ($number) = $data =~ /FM:(\S+)/s unless $number;
        ($numberTo) = $data =~ /TO:(\S+)/s;

        print "phone number=$number numberTo=$numberTo name=$name\n";


        $name = substr($name, 0, 15);
        $name = 'Unavailable' if $name =~ /^O$/; # Jay's & Chaz's exceptions
        $name = 'Private'     if $name =~ /^P$/; # Chaz's exception
        $name = 'Pay'         if $name =~ /^TEL PUBLIC BELL$/; # Chaz's exception
        ($last, $first, $middle) = split(/[\s,]+/, $name, 3);

		if ( $local_area_code_language =~ /swiss-german/gi )
		{
			# Switzerland's phone#s are reported without the area code if in the same area
	        substr($number, length($number)-2, 0) = '-' if length($number) > 6 ;
    	    substr($number, length($number)-5, 0) = '-' if length($number) > 6 ;
	        substr($number, length($number)-9, 0) = '-' if length($number) > 8 ;
		}
		else
		{
	        substr($number, 6, 0) = '-' if length $number > 7;
    	    substr($number, 3, 0) = '-' if length $number > 3;
		}


    }
    else {
        ($time, $number, $name) = unpack("A13A13A15", $data);
    }
    ($last, $first, $middle) = split(' ', $name);
    $first = ucfirst(lc($first));
    $first = ucfirst(lc($middle)) if length($first) == 1 and $middle; # Last M First format
    $last  = ucfirst(lc($last));


                                # Again, because of the area code not included.
    if (length $number > 8) {
        ($areacode, $local_number) = $number =~ /(\d+)-(\S+)/;
	}else{
        ($areacode, $local_number) = ($my_areacode,$number);
	}    

#I03/22 16:13 507-123-4567 OUT OF AREA
#I03/23 08:35 OUT OF AREA  OUT OF AREA  
#I03/22 16:17 PRIVATE      PRIVATE 
#I03/22 20:00 PAY PHONE

    if ($caller = $name_by_number{$number}) {
#        if ($caller =~ /\.wav$/) {
#            $caller = "phone_call.wav,$caller,phone_call.wav,$caller";  # Prefix 'phone call'
#       }
    }
    elsif ($last eq "Private"  or $number eq "P") {
        $caller = "a blocked phone number";
		$caller = "Nummer unterdrückt" if ($local_area_code_language =~ /swiss-german/gi);
    }
    elsif ($last eq "Unavailable" or $name eq '') {
        $caller = "number $local_number";
		$caller = "Nummer $local_number" if ($local_area_code_language =~ /swiss-german/gi);
    }
    elsif ($last eq "Out-of-area" or $last eq "Out" or $number eq "O") {
        $caller = "an out of area number";
		$caller = "Vorwahl nicht vorhanden" if ($local_area_code_language =~ /swiss-german/gi);
    }
    elsif ($last eq "Pay") {
        $caller = "a pay phone";
		$caller = "Telefonkabiene" if ($local_area_code_language =~ /swiss-german/gi)
    }
    elsif ($main::config_parms{caller_id_format} eq 'first last' and $name !~ /,/) {
                                # no comma from Ameritech means leave the caller ID string alone
                                # perform upper/lower-casing on all the words
	    $caller = join(" ", map { ucfirst(lc()) } split(/\s+/,$name));
    }
    else {
        $caller = "$first $last";
    }

    print "ac=$areacode state_by_area_code=$state_by_areacode{$areacode}\n";
#   unless ($areacode == $my_areacode or !$areacode or $caller =~ /\.wav/) {
    unless (!$areacode or (grep $_ == $areacode, @my_areacodes) or $caller =~ /\.wav/) {
        if ($state_by_areacode{$areacode}) 
		{
			if ($local_area_code_language =~ /swiss-german/gi)
			{
				$caller .= " aus $state_by_areacode{$areacode}" 
			}
			else
			{
				$caller .= " from $state_by_areacode{$areacode}";
			}
        }
        else 
		{
			if ($local_area_code_language =~ /swiss-german/gi)
			{
				$caller .= " aus Vorwahl $areacode";
			}
			else
			{
    	        $caller .= " from area code $areacode";
			}
        }
    }
#   $caller = "Call from $caller.  Phone call is from $caller.";
                                # Allow for scalar or array call
    return wantarray ? ($caller, $number, $name, $time) : $caller;
}

sub read_areacode_list {

    my %parms = @_;
    
#   &main::print_log("Reading area code table ... ");
#   print "Reading area code table ... ";

    my ($area_code_file, %city_by_areacode, $city, $state, $areacode, $areacode_cnt);
    open (AREACODE, $parms{area_code_file}) or 
        print "\nError, could not find the area code file $parms{area_code_file}: $!\n";

    while (<AREACODE>) {
        next if /^\#/;
        $areacode_cnt++;
        $_ =~ s/\(.+?\)//;      # Delete descriptors like (Southern) Texas ... too much to speak
                                #406 All parts of Montana

        ($areacode, $state) = $_ =~ /(\d\d\d) All parts of (.+)/;
        ($areacode, $city, $state) = $_ =~ /(\d\d\d)(.*), *(.+)/ unless $state;
        next unless $city;
        $city_by_areacode{$areacode}  = $city;
        $state_by_areacode{$areacode} = $state;
#       print "db code=$areacode state=$state city=$city\n";
    }
    close AREACODE;
#   &main::print_log("read in $areacode_cnt area codes from $parms{area_code_file}");
    print "Read $areacode_cnt codes from $parms{area_code_file}\n";
    # If in-state, store city name instead of state name.
    @my_areacodes = split /[, ]+/, $parms{local_area_code};
    $my_areacode  = $my_areacodes[0];
    $my_state = $state_by_areacode{$my_areacode};

                                # If withing state, use only city name.
    for $areacode (keys %state_by_areacode) {
        $state_by_areacode{$areacode} = $city_by_areacode{$areacode} if $city_by_areacode{$areacode} and 
            $my_state and $state_by_areacode{$areacode} eq $my_state;
    }
#   print "db ac=$state_by_areacode{'507'}\n";
#   print "db my_areacode=$my_areacode ms=$my_state\n";
#   print "db ac=$state_by_areacode{'612'}\n";
#   print "db ac=$state_by_areacode{'406'}\n";
}   

sub read_callerid_list {
    
    my($caller_id_file) = @_;

    my ($number, $name, $callerid_cnt);

#   &main::print_log("Reading override phone list ... ");
#   print "Reading override phone list ... \n";

    undef %name_by_number;
    open (CALLERID, $caller_id_file) or print "\nError, could not find the area code file $caller_id_file: $!\n";

    while (<CALLERID>) {
        next if /^\#/;
        ($number, $name) = $_ =~ /^(\S+) +(.+) *$/;
        next unless $name;
        $callerid_cnt++;
        $name_by_number{$number} = $name;
#   print "Callerid names: number=$number  name=$name\n";
    }
#   &main::print_log("read in $callerid_cnt caller ID override names/numbers from $caller_id_file");
    print "Read $callerid_cnt entries from $caller_id_file\n";
    close CALLERID;

}   

#
# $Log$
# Revision 1.21  2001/05/06 21:07:26  winter
# - 2.51 release
#
# Revision 1.20  2001/03/24 18:08:38  winter
# - 2.47 release
#
# Revision 1.19  2000/12/03 19:38:55  winter
# - 2.36 release
#
# Revision 1.18  2000/11/12 21:02:38  winter
# - 2.34 release
#
# Revision 1.17  2000/10/22 16:48:29  winter
# - 2.32 release
#
# Revision 1.16  2000/10/01 23:29:40  winter
# - 2.29 release
#
# Revision 1.15  2000/08/19 01:22:36  winter
# - 2.27 release
#
# Revision 1.14  2000/05/06 16:34:32  winter
# - 2.15 release
#
# Revision 1.13  2000/03/10 04:09:01  winter
# - Add Ibutton support and more web changes
#
# Revision 1.12  2000/02/20 04:47:54  winter
# -2.01 release
#
# Revision 1.11  2000/01/27 13:38:24  winter
# - update version number
#
# Revision 1.10  2000/01/02 23:42:27  winter
# - allow an array to be returned
#
# Revision 1.9  1999/10/02 22:40:27  winter
# - fix typo in use vars
#
# Revision 1.8  1999/09/28 23:38:26  winter
# - change from 'my' to 'use vars' on by_name and by_state arrays
#
# Revision 1.7  1999/03/28 00:32:07  winter
# *** empty log message ***
#
# Revision 1.6  1999/03/09 13:56:56  winter
# - added format=2 for modem callerid string
#
# Revision 1.5  1999/01/30 19:55:24  winter
# - fix typo in name length check
#
# Revision 1.4  1999/01/24 20:03:35  winter
# - Check for middle initial.  UnTabbify
#
# Revision 1.3  1998/12/08 02:09:13  winter
# - print, not die, if area code file is missing.
#
# Revision 1.2  1998/11/15 22:03:15  winter
# - add log
#
#

1;



