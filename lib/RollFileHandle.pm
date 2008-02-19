package RollFileHandle;

use 5.003_11;
use strict;
use Time::Local;
use POSIX;
use vars qw($VERSION @ISA @EXPORT @EXPORT_OK);

$VERSION = "2.00";

require IO::File;
@ISA = qw(IO::File);

@EXPORT = qw(_IOFBF _IOLBF _IONBF);

@EXPORT_OK = qw(

    autoflush
    output_field_separator
    output_record_separator
    input_record_separator
    input_line_number
    format_page_number
    format_lines_per_page
    format_lines_left
    format_name
    format_top_name
    format_line_break_characters
    format_formfeed

    print
    printf
    getline
    getlines
);
# Everything we're willing to export, we must first import.
#
import IO::Handle grep { !defined(&$_) } @EXPORT, @EXPORT_OK;


###################################################################
##  this package is intended to give the caller the ability to 
##  create a "rolling" log file of its output, so that a single
##  output log doesn't grow unrestricted.
##
##  if the process is dropped and restarted, the log file will be 
##    appended onto instead of truncated.
##
## example usage:
##   use RollFileHandle;
##   my $dl=new RollFileHandle(">> /tmp/$0.stdout.%m%d");
##   $dl->trap_stdxxx();    # install as default for stdout
##   while($event_loop){
##         $dl->roll_logfile();     # re-open log file when date rolls.
##         print("1","2","3\n");    # use vanilla print syntax.
##
##
###################################################################
my $sccs="@(#).RollFileHandle.pm         %I% %G% ";
my $cur_stdout_obj;
my $debug=0;
my %known_objects;
sub new{
	my ($class,$logbase)=@_;

	## put the logfiles in the "~/tmp" dir unless a 
	##  qualified path was requested
	##my $logdir;
	##$logdir="/tmp/" unless ($logbase=~/^\//);
	

	# default to program name .MonthDay if no logname requested
	##if( ! $logbase){
	##	$logbase= $0 . ".%m%d";   
	##}

	## default to append mode if not specified.
	if($logbase !~/^\s*[\<\>]/){
		$logbase = ">> $logbase";
	}

	my $newobj=new IO::File;    # this will give a typeglob (not a hashref)
	my $newref={};
	$newref->{"RLF.logskel"}=$logbase;
	bless $newobj;    #  IO::File blessed so it can call our functions()
	bless $newref;    #our hashref
	$known_objects{$newobj}=$newref;

	## open the first version of the requested logfile
	$newobj->roll_logfile();

	return $newobj;
}

########################################################
## Open the correct logfile for the current time.
##   if there is no work to do, exit without making any changes.
########################################################
sub roll_logfile{
	my ($self_obj)=@_;
	my $self=$known_objects{$self_obj};  ## look up the hashref

	my $now=time();

	# if the roll_time is expired, calc a new one
	if($self->{"RLF.next_roll_time"} <=  $now){
		$self->{"RLF.next_roll_time"}=&midnite_time($now);
	}
	else{
		return;
	}

	my $now_fname;
	$now_fname=POSIX::strftime($self->{"RLF.logskel"} ,localtime($now));
	## $now_fname=$self->{"RLF.logskel"} . join (".",localtime($now));
	return if ($self->{"RLF.cur_fname"} eq $now_fname);  # no change


	$debug && print STDERR "roll_logfile: new file will be [$now_fname]\n";
	
	
	$self->{"RLF.cur_fname"}= $now_fname; # install the new filename as current

	$self_obj->SUPER::open($self->{"RLF.cur_fname"}); # (re)-open the file
	
	## and if we were installed as a stdout trap, update the trap for the
	##   new file handle
	if($self->{"RLF.stdout_trapped"}){
		$self_obj->trap_stdxxx();
	}

}

sub trap_stdxxx{
	my ($self_obj)=@_;
	my $self=$known_objects{$self_obj};  ## look up the hashref
	

	if($cur_stdout_obj){
		if($self->{"RLF.stdout_trapped"}){
			# the previous trap was for this object,
			#  fall through and update the trap to the current fh
		}
		else{
			die "Can't steal stdout from a previous trap";
		}
	}
	else{
		## ok,  safe to use empty stdout_fh as the new trap
	}
	
	$self->{"RLF.stdout_trapped"}=1;

	$cur_stdout_obj=$self;
	my $cur_fname=$self->{"RLF.cur_fname"};

	print "re-opening stdout/stderr as $cur_fname\n";

	## Close open file descriptors
	foreach my $i (1 .. 2) { POSIX::close($i) || die "can't close $i"; }

	## Reopen stderr, stdout,  to poing to current logfile
	# open(STDOUT, ">> $cur_fname") || die "can't reopen stdout [$cur_fname]";
	# open(STDERR, ">>&STDOUT") || die "can't reopen stderr [$cur_fname]";
	open(STDOUT, "$cur_fname") || die "can't reopen stdout [$cur_fname]";
	open(STDERR, "$cur_fname") || die "can't reopen stderr [$cur_fname]";

	#Filter \*STDOUT, \&redir_stdout;
	# &Filter::Handle::Filter(\*STDOUT, \&redir_stdout);
	# &Filter::Handle::Filter(\*STDERR, \&redir_stdout);
}


########################################################
## Calculate the time for midnight tonight, when we'll need
##   to roll the log (again)
########################################################
sub midnite_time{
	my ($ref_time)=@_;
	
	# get breakdown for 24 hours from now.

	##my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) =
	##	localtime($ref_time + (24*3600));
	##$sec=$min=$hour=0;   # zap the time fields

	## test for roll each minute
	my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) =
		localtime($ref_time + (60));
	$sec=0;   # zap the time field
	
	return(Time::Local::timelocal($sec,$min,$hour,$mday,$mon,$year));
	
	

}
sub DESTROY{
	my($self)=shift;
## 	print "RollFileHandle DESTROY cleaning up $self\n";
	delete $known_objects{$self};
	
}
1;
