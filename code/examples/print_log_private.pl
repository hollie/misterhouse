#-----------------------------------------------------------------------
# example subroutine to be substituted in print_log instead of just
# printing the message to file
# it takes 3 parameters;
# message - the message
# severity - one of EMERGENCY, ALERT, CRITICAL, ERROR, WARNING, NOTICE, 
#            INFORMATIONAL, DEBUG or NONE 
#            if NONE is set, it just returns and not do anything
# source -  where the message originated, e.g. my_subroutine
# Edit this to enable MisterHouse to email/sms/twitter certain severities of message
# Author:   Giles Godart-Brown 14-jan-2020
#-----------------------------------------------------------------------

sub print_log_private {
	my ($message,$severity,$source) = @_;
	
	# WARNING	WARNING		WARNING		WARNING		WARNING		WARNING
	# DO NOT CALL print_log FROM HERE, it will LOOP, use print_log_simple
	
	# dont do anything if severity set to NONE
	if ($severity eq "NONE" ) {
		return;
	}
	
	# create formatted message to print/email/sms
	my $local_message = $message;	
	if (defined($severity)) {
		$local_message = $severity . " " . $local_message;
	}
	if (defined($source)) {
		$local_message = "[print_log_private-" . $source . "] ".  $local_message;
	} else {
		$local_message = "[print_log_private] ".  $local_message;
	}
	
	# decide what to do based on severity
	
	if ($severity eq "EMERGENCY" ) {			# code to manage emergency messages goes here
		print_log_simple($local_message);
		return;
	} elsif ($severity eq "ALERT" ) {			# code to manage alert messages goes here
		print_log_simple($local_message);
		return;
	} elsif ($severity eq "CRITICAL" ) {		# code to manage critical messages goes here
		print_log_simple($local_message);
		return;
	} elsif ($severity eq "ERROR" ) {			# code to manage error messages goes here
		print_log_simple($local_message);
		return;
	} elsif ($severity eq "WARNING" ) {			# code to manage warning messages goes here
		print_log_simple($local_message);
		return;
	} elsif ($severity eq "NOTICE" ) {			# code to manage notice messages goes here
		print_log_simple($local_message);
		return;
	} elsif ($severity eq "INFORMATIONAL" ) {	# code to manage info messages goes here
		print_log_simple($local_message);
		return;
	} elsif ($severity eq "DEBUG" ) {			# code to manage debug messages goes here
		print_log_simple($local_message);
		return;
	}
	
    print_log_simple("[print_log_private] WARNING invalid severity $severity");
    print_log_simple($local_message);
    return;   
	
}