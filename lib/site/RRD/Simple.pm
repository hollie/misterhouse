############################################################
#
#   $Id: Simple.pm 1100 2008-01-24 17:39:35Z nicolaw $
#   RRD::Simple - Simple interface to create and store data in RRD files
#
#   Copyright 2005,2006,2007,2008 Nicola Worthington
#
#   Licensed under the Apache License, Version 2.0 (the "License");
#   you may not use this file except in compliance with the License.
#   You may obtain a copy of the License at
#
#       http://www.apache.org/licenses/LICENSE-2.0
#
#   Unless required by applicable law or agreed to in writing, software
#   distributed under the License is distributed on an "AS IS" BASIS,
#   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#   See the License for the specific language governing permissions and
#   limitations under the License.
#
############################################################

package RRD::Simple;
# vim:ts=8:sw=8:tw=78

use strict;
require Exporter;
use RRDs;
use POSIX qw(strftime); # Used for strftime in graph() method
use Carp qw(croak cluck confess carp);
use File::Spec qw(); # catfile catdir updir path rootdir tmpdir
use File::Basename qw(fileparse dirname basename);

use vars qw($VERSION $DEBUG $DEFAULT_DSTYPE
	 @EXPORT @EXPORT_OK %EXPORT_TAGS @ISA);

$VERSION = '1.44' || sprintf('%d', q$Revision: 1100 $ =~ /(\d+)/g);

@ISA = qw(Exporter);
@EXPORT = qw();
@EXPORT_OK = qw(create update last_update graph info rename_source
		add_source sources retention_period last_values
		heartbeat);
#		delete_source minimum maximum
%EXPORT_TAGS = (all => \@EXPORT_OK);

$DEBUG ||= $ENV{DEBUG} ? 1 : 0;
$DEFAULT_DSTYPE ||= exists $ENV{DEFAULT_DSTYPE}
		? $ENV{DEFAULT_DSTYPE} : 'GAUGE';

my $objstore = {};



#
# Methods
#

# Create a new object
sub new {
	TRACE(">>> new()");
	ref(my $class = shift) && croak 'Class name required';
	croak 'Odd number of elements passed when even was expected' if @_ % 2;

	# Conjure up an invisible object 
	my $self = bless \(my $dummy), $class;
	$objstore->{_refaddr($self)} = {@_};
	my $stor = $objstore->{_refaddr($self)};
	#my $self = { @_ };

	# - Added "file" support in 1.42 - see sub _guess_filename.
	# - Added "on_missing_ds"/"on_missing_source" support in 1.44
	# - Added "tmpdir" support in 1.44
	my @validkeys = qw(rrdtool cf default_dstype default_dst tmpdir
			file on_missing_ds on_missing_source);
	my $validkeys = join('|', @validkeys);

	cluck('Unrecognised parameters passed: '.
		join(', ',grep(!/^$validkeys$/,keys %{$stor})))
		if (grep(!/^$validkeys$/,keys %{$stor}) && $^W);

	$stor->{rrdtool} = _find_binary(exists $stor->{rrdtool} ?
				$stor->{rrdtool} : 'rrdtool');

	# Check that "default_dstype" isn't complete rubbish (validation from v1.44+)
	# GAUGE | COUNTER | DERIVE | ABSOLUTE | COMPUTE 
	# http://oss.oetiker.ch/rrdtool/doc/rrdcreate.en.html
	$stor->{default_dstype} ||= $stor->{default_dst};
	croak "Invalid value passed in parameter default_dstype; '$stor->{default_dstype}'"
		if defined $stor->{default_dstype}
		&& $stor->{default_dstype} !~ /^(GAUGE|COUNTER|DERIVE|ABSOLUTE|COMPUTE|[A-Z]{1,10})$/i;

	# Check that "on_missing_ds" isn't complete rubbish.
	# Added "on_missing_ds"/"on_missing_source" support in 1.44
	$stor->{on_missing_ds} ||= $stor->{on_missing_source};
	if (defined $stor->{on_missing_ds}) {
		$stor->{on_missing_ds} = lc($stor->{on_missing_ds});
		croak "Invalid value passed in parameter on_missing_ds; '$stor->{on_missing_ds}'"
			if $stor->{on_missing_ds} !~ /^\s*(add|ignore|die|croak)\s*$/i;
	}
	$stor->{on_missing_ds} ||= 'add'; # default to add

	#$stor->{cf} ||= [ qw(AVERAGE MIN MAX LAST) ];
	# By default, now only create RRAs for AVERAGE and MAX, like
	# mrtg v2.13.2. This is to save disk space and processing time
	# during updates etc.
	$stor->{cf} ||= [ qw(AVERAGE MAX) ]; 
	$stor->{cf} = [ $stor->{cf} ] if !ref($stor->{cf});

	DUMP($class,$self);
	DUMP('$stor',$stor);
	return $self;
}


# Create a new RRD file
sub create {
	TRACE(">>> create()");
	my $self = shift;
	unless (ref $self && UNIVERSAL::isa($self, __PACKAGE__)) {
		unshift @_, $self unless $self eq __PACKAGE__;
		$self = new __PACKAGE__;
	}

	my $stor = $objstore->{_refaddr($self)};

#
#
#

	# Grab or guess the filename
	my $rrdfile = $stor->{file};

	# Odd number of values and first is not a valid scheme
	# then the first value is likely an RRD file name.
	if (@_ % 2 && !_valid_scheme($_[0])) {
		$rrdfile = shift;

	# Even number of values and the second value is a valid
	# scheme then the first value is likely an RRD file name.
	} elsif (!(@_ % 2) && _valid_scheme($_[1])) {
		$rrdfile = shift;

	# If we still don't have an RRD file name then try and
	# guess what it is
	} elsif (!defined $rrdfile) {
		$rrdfile = _guess_filename($stor);
	}

#
#
#

	# Barf if the rrd file already exists
	croak "RRD file '$rrdfile' already exists" if -f $rrdfile;
	TRACE("Using filename: $rrdfile");

	# We've been given a scheme specifier
	# Until v1.32 'year' was the default. As of v1.33 'mrtg'
	# is the new default scheme.
	#my $scheme = 'year';
	my $scheme = 'mrtg';
	if (@_ % 2 && _valid_scheme($_[0])) {
		$scheme = _valid_scheme($_[0]);
		shift @_;
	}
	TRACE("Using scheme: $scheme");

	croak 'Odd number of elements passed when even was expected' if @_ % 2;
	my %ds = @_;
	DUMP('%ds',\%ds);

	my $rrdDef = _rrd_def($scheme);
	my @def = ('-b', time - _seconds_in($scheme,120));
	push @def, '-s', ($rrdDef->{step} || 300);

	# Add data sources
	for my $ds (sort keys %ds) {
		$ds =~ s/[^a-zA-Z0-9_-]//g;
		push @def, sprintf('DS:%s:%s:%s:%s:%s',
				substr($ds,0,19),
				uc($ds{$ds}),
				($rrdDef->{heartbeat} || 600),
				'U','U'
			);
	}

	# Add RRA definitions
	my %cf;
	for my $cf (@{$stor->{cf}}) {
		$cf{$cf} = $rrdDef->{rra};
	}
	for my $cf (sort keys %cf) {
		for my $rra (@{$cf{$cf}}) {
			push @def, sprintf('RRA:%s:%s:%s:%s',
					$cf, 0.5, $rra->{step}, $rra->{rows}
				);
		}
	}

	DUMP('@def',\@def);

	# Pass to RRDs for execution
	my @rtn = RRDs::create($rrdfile, @def);
	my $error = RRDs::error();
	croak($error) if $error;
	DUMP('RRDs::info',RRDs::info($rrdfile));
	return wantarray ? @rtn : \@rtn;
}


# Update an RRD file with some data values
sub update {
	TRACE(">>> update()");
	my $self = shift;
	unless (ref $self && UNIVERSAL::isa($self, __PACKAGE__)) {
		unshift @_, $self unless $self eq __PACKAGE__;
		$self = new __PACKAGE__;
	}

	my $stor = $objstore->{_refaddr($self)};

#
#
#

	# Grab or guess the filename
	my $rrdfile = $stor->{file};

	# Odd number of values and first is does not look
	# like a recent unix time stamp then the first value
	# is likely to be an RRD file name.
	if (@_ % 2 && $_[0] !~ /^[1-9][0-9]{8,10}$/i) {
		$rrdfile = shift;

	# Even number of values and the second value looks like
	# a recent unix time stamp then the first value is
	# likely to be an RRD file name.
	} elsif (!(@_ % 2) && $_[1] =~ /^[1-9][0-9]{8,10}$/i) {
		$rrdfile = shift;

	# If we still don't have an RRD file name then try and
	# guess what it is
	} elsif (!defined $rrdfile) {
		$rrdfile = _guess_filename($stor);
	}

#
#
#

	# We've been given an update timestamp
	my $time = time();
	if (@_ % 2 && $_[0] =~ /^([1-9][0-9]{8,10})$/i) {
		$time = $1;
		shift @_;
	}
	TRACE("Using update time: $time");

	# Try to automatically create it
	unless (-f $rrdfile) {
		my $default_dstype = defined $stor->{default_dstype} ? $stor->{default_dstype} : $DEFAULT_DSTYPE;
		cluck("RRD file '$rrdfile' does not exist; attempting to create it ",
				"using default DS type of '$default_dstype'") if $^W;
		my @args;
		for (my $i = 0; $i < @_; $i++) {
			push @args, ($_[$i],$default_dstype) unless $i % 2;
		}
		$self->create($rrdfile,@args);
	}

	croak "RRD file '$rrdfile' does not exist" unless -f $rrdfile;
	TRACE("Using filename: $rrdfile");

	croak 'Odd number of elements passed when even was expected' if @_ % 2;

	my %ds;
	while (my $ds = shift(@_)) {
		$ds =~ s/[^a-zA-Z0-9_-]//g;
		$ds = substr($ds,0,19);
		$ds{$ds} = shift(@_);
		$ds{$ds} = 'U' if !defined($ds{$ds});
	}
	DUMP('%ds',\%ds);

	# Validate the data source names as we add them
	my @sources = $self->sources($rrdfile);
	for my $ds (sort keys %ds) {
		# Check the data source names
		if (!grep(/^$ds$/,@sources)) {
			TRACE("Supplied data source '$ds' does not exist in pre-existing ".
				"RRD data source list: ". join(', ',@sources));

			# If someone got the case wrong, remind and correct them
			if (grep(/^$ds$/i,@sources)) {
				cluck("Data source '$ds' does not exist; automatically ",
					"correcting it to '",(grep(/^$ds$/i,@sources))[0],
					"' instead") if $^W;
				$ds{(grep(/^$ds$/i,@sources))[0]} = $ds{$ds};
				delete $ds{$ds};

			# If it's not just a case sensitivity typo and the data source
			# name really doesn't exist in this RRD file at all, regardless
			# of case, then ...
			} else {
				# Ignore the offending missing data source name 
				if ($stor->{on_missing_ds} eq 'ignore') {
					TRACE("on_missing_ds = ignore; ignoring data supplied for missing data source '$ds'");

				# Fall on our bum and die horribly if requested to do so
				} elsif ($stor->{on_missing_ds} eq 'die' || $stor->{on_missing_ds} eq 'croak') {
					croak "Supplied data source '$ds' does not exist in RRD file '$rrdfile'";

				# Default behaviour is to automatically add the new data source
				# to the RRD file in order to preserve the existing default
				# functionality of RRD::Simple
				} else {			
					TRACE("on_missing_ds = add (or not set at all/default); ".
						"automatically adding new data source '$ds'");

					# Otherwise add any missing or new data sources on the fly
					# Decide what DS type and heartbeat to use
					my $info = RRDs::info($rrdfile);
					my $error = RRDs::error();
					croak($error) if $error;

					my %dsTypes;
					for my $key (grep(/^ds\[.+?\]\.type$/,keys %{$info})) {
						$dsTypes{$info->{$key}}++;
					}
					DUMP('%dsTypes',\%dsTypes);
					my $dstype = (sort { $dsTypes{$b} <=> $dsTypes{$a} }
								keys %dsTypes)[0];
					TRACE("\$dstype = $dstype");

					$self->add_source($rrdfile,$ds,$dstype);
				}
			}
		}
	}

	# Build the def
	my @def = ('--template');
	push @def, join(':',sort keys %ds);
	push @def, join(':',$time,map { $ds{$_} } sort keys %ds);
	DUMP('@def',\@def);

	# Pass to RRDs to execute the update
	my @rtn = RRDs::update($rrdfile, @def);
	my $error = RRDs::error();
	croak($error) if $error;
	return wantarray ? @rtn : \@rtn;
}


# Get the last time an RRD was updates
sub last_update { __PACKAGE__->last(@_); }
sub last {
	TRACE(">>> last()");
	my $self = shift;
	unless (ref $self && UNIVERSAL::isa($self, __PACKAGE__)) {
		unshift @_, $self unless $self eq __PACKAGE__;
		$self = new __PACKAGE__;
	}

	my $stor = $objstore->{_refaddr($self)};
	my $rrdfile = shift || _guess_filename($stor);
	croak "RRD file '$rrdfile' does not exist" unless -f $rrdfile;
	TRACE("Using filename: $rrdfile");

	my $last = RRDs::last($rrdfile);
	my $error = RRDs::error();
	croak($error) if $error;
	return $last;
}


# Get a list of data sources from an RRD file
sub sources {
	TRACE(">>> sources()");
	my $self = shift;
	unless (ref $self && UNIVERSAL::isa($self, __PACKAGE__)) {
		unshift @_, $self unless $self eq __PACKAGE__;
		$self = new __PACKAGE__;
	}

	my $stor = $objstore->{_refaddr($self)};
	my $rrdfile = shift || _guess_filename($stor);
	croak "RRD file '$rrdfile' does not exist" unless -f $rrdfile;
	TRACE("Using filename: $rrdfile");

	my $info = RRDs::info($rrdfile);
	my $error = RRDs::error();
	croak($error) if $error;

	my @ds;
	foreach (keys %{$info}) {
		if (/^ds\[(.+)?\]\.type$/) {
			push @ds, $1;
		}
	}
	return wantarray ? @ds : \@ds;
}


# Add a new data source to an RRD file
sub add_source {
	TRACE(">>> add_source()");
	my $self = shift;
	unless (ref $self && UNIVERSAL::isa($self, __PACKAGE__)) {
		unshift @_, $self unless $self eq __PACKAGE__;
		$self = new __PACKAGE__;
	}

	# Grab or guess the filename
	my $stor = $objstore->{_refaddr($self)};
	my $rrdfile = @_ % 2 ? shift : _guess_filename($stor);
	unless (-f $rrdfile) {
		cluck("RRD file '$rrdfile' does not exist; attempting to create it")
			if $^W;
		return $self->create($rrdfile,@_);
	}
	croak "RRD file '$rrdfile' does not exist" unless -f $rrdfile;
	TRACE("Using filename: $rrdfile");

	# Check that we will understand this RRD file version first
	my $info = $self->info($rrdfile);
#	croak "Unable to add a new data source to $rrdfile; ",
#		"RRD version $info->{rrd_version} is too new"
#		if ($info->{rrd_version}+1-1) > 1;

	my ($ds,$dstype) = @_;
	TRACE("\$ds = $ds");
	TRACE("\$dstype = $dstype");

	my $rrdfileBackup = "$rrdfile.bak";
	confess "$rrdfileBackup already exists; please investigate"
		if -e $rrdfileBackup;

	# Decide what heartbeat to use
	my $heartbeat = $info->{ds}->{(sort {
							$info->{ds}->{$b}->{minimal_heartbeat} <=>
							$info->{ds}->{$b}->{minimal_heartbeat}
					} keys %{$info->{ds}})[0]}->{minimal_heartbeat};
	TRACE("\$heartbeat = $heartbeat");

	# Make a list of expected sources after the addition
	my $TgtSources = join(',',sort(($self->sources($rrdfile),$ds)));

	# Add the data source
	my $new_rrdfile = '';
	eval {
		$new_rrdfile = _modify_source(
				$rrdfile,$stor,$ds,
				'add',$dstype,$heartbeat,
			);
	};

	# Barf if the eval{} got upset
	if ($@) {
		croak "Failed to add new data source '$ds' to RRD file '$rrdfile': $@";
	}

	# Barf of the new RRD file doesn't exist
	unless (-f $new_rrdfile) {
		croak "Failed to add new data source '$ds' to RRD file '$rrdfile': ",
			"new RRD file '$new_rrdfile' does not exist";
	}

	# Barf is the new data source isn't in our new RRD file
	unless ($TgtSources eq join(',',sort($self->sources($new_rrdfile)))) {
		croak "Failed to add new data source '$ds' to RRD file '$rrdfile': ",
			"new RRD file '$new_rrdfile' does not contain expected data ",
			"source names";
	}

	# Try and move the new RRD file in to place over the existing one
	# and then remove the backup RRD file if sucessfull
	if (File::Copy::move($rrdfile,$rrdfileBackup) &&
				File::Copy::move($new_rrdfile,$rrdfile)) {
		unless (unlink($rrdfileBackup)) {
			cluck("Failed to remove back RRD file '$rrdfileBackup': $!")
				if $^W;
		}
	} else {
		croak "Failed to move new RRD file in to place: $!";
	}
}


# Make a number of graphs for an RRD file
sub graph {
	TRACE(">>> graph()");
	my $self = shift;
	unless (ref $self && UNIVERSAL::isa($self, __PACKAGE__)) {
		unshift @_, $self unless $self eq __PACKAGE__;
		$self = new __PACKAGE__;
	}

	# Grab or guess the filename
	my $stor = $objstore->{_refaddr($self)};
	my $rrdfile = @_ % 2 ? shift : _guess_filename($stor);

	# How much data do we have to graph?
	my $period = $self->retention_period($rrdfile);

	# Check at RRA CFs are available and graph the best one
	my $info = $self->info($rrdfile);
	my $cf = 'AVERAGE';
	for my $rra (@{$info->{rra}}) {
		if ($rra->{cf} eq 'AVERAGE') {
			$cf = 'AVERAGE'; last;
		} elsif ($rra->{cf} eq 'MAX') {
			$cf = 'MAX';
		} elsif ($rra->{cf} eq 'MIN' && $cf ne 'MAX') {
			$cf = 'MIN';
		} elsif ($cf ne 'MAX' && $cf ne 'MIN') {
			$cf = $rra->{cf};
		}
	}
	TRACE("graph() - \$cf = $cf");

	# Create graphs which we have enough data to populate
	# Version 1.39 - Change the return from an array to a hash (semi backward compatible)
	# my @rtn;
	my %rtn;

##
## TODO
## 1.45 Only generate hour, 6hour and 12hour graphs if the
###     data resolution (stepping) is fine enough (sub minute)
##

	#i my @graph_periods = qw(hour 6hour 12hour day week month year 3years);
	my @graph_periods;
	my %param = @_;
	if (defined $param{'periods'}) {
		my %map = qw(daily day weekly week monthly month annual year 3years 3years);
		for my $period (_convert_to_array($param{'periods'})) {
			$period = lc($period);
			if (_valid_scheme($period)) {
				push @graph_periods, $period;
			} elsif (_valid_scheme($map{$period})) {
				push @graph_periods, $map{$period};
			} else {
				croak "Invalid period value passed in parameter periods; '$period'";
			}
		}
	}
 	push @graph_periods, qw(day week month year 3years) unless @graph_periods;

	for my $type (@graph_periods) {
		next if $period < _seconds_in($type);
		TRACE("graph() - \$type = $type");
		# push @rtn, [ ($self->_create_graph($rrdfile, $type, $cf, @_)) ];
		$rtn{_alt_graph_name($type)} = [ ($self->_create_graph($rrdfile, $type, $cf, @_)) ];
	}

	# return @rtn;
	return wantarray ? %rtn : \%rtn;
}


# Rename an existing data source
sub rename_source {
	TRACE(">>> rename_source()");
	my $self = shift;
	unless (ref $self && UNIVERSAL::isa($self, __PACKAGE__)) {
		unshift @_, $self unless $self eq __PACKAGE__;
		$self = new __PACKAGE__;
	}

	# Grab or guess the filename
	my $stor = $objstore->{_refaddr($self)};
	my $rrdfile = @_ % 2 ? shift : _guess_filename($stor);
	croak "RRD file '$rrdfile' does not exist" unless -f $rrdfile;
	TRACE("Using filename: $rrdfile");

	my ($old,$new) = @_;
	croak "No old data source name specified" unless defined $old && length($old);
	croak "No new data source name specified" unless defined $new && length($new);
	croak "Data source '$old' does not exist in RRD file '$rrdfile'"
		unless grep($_ eq $old, $self->sources($rrdfile));

	my @rtn = RRDs::tune($rrdfile,'-r',"$old:$new");
	my $error = RRDs::error();
	croak($error) if $error;
	return wantarray ? @rtn : \@rtn;
}


# Get or set a data source heartbeat
sub heartbeat {
	TRACE(">>> heartbeat()");
	my $self = shift;
	unless (ref $self && UNIVERSAL::isa($self, __PACKAGE__)) {
		unshift @_, $self unless $self eq __PACKAGE__;
		$self = new __PACKAGE__;
	}

	# Grab or guess the filename
	my $stor = $objstore->{_refaddr($self)};
	my $rrdfile = @_ >= 3 ? shift : 
			_isLegalDsName($_[0]) && $_[1] =~ /^[0-9]+$/ ?
			_guess_filename($stor) : shift;
	croak "RRD file '$rrdfile' does not exist" unless -f $rrdfile;
	TRACE("Using filename: $rrdfile");

	# Explode if we get no data source name
	my ($ds,$new_heartbeat) = @_;
	croak "No data source name was specified" unless defined $ds && length($ds);

	# Check the data source name exists
	my $info = $self->info($rrdfile);
	my $heartbeat = $info->{ds}->{$ds}->{minimal_heartbeat};
	croak "Data source '$ds' does not exist in RRD file '$rrdfile'"
		unless defined $heartbeat && $heartbeat;

	if (!defined $new_heartbeat) {
		return wantarray ? ($heartbeat) : $heartbeat;
	}

	my @rtn = !defined $new_heartbeat ? ($heartbeat) : ();
	# Redefine the data source heartbeat
	if (defined $new_heartbeat) {
		croak "New minimal heartbeat '$new_heartbeat' is not a valid positive integer"
			unless $new_heartbeat =~ /^[1-9][0-9]*$/;
		my @rtn = RRDs::tune($rrdfile,'-h',"$ds:$new_heartbeat");
		my $error = RRDs::error();
		croak($error) if $error;
	}

	return wantarray ? @rtn : \@rtn;
}


# Fetch data point information from an RRD file
sub fetch {
	TRACE(">>> fetch()");
	my $self = shift;
	unless (ref $self && UNIVERSAL::isa($self, __PACKAGE__)) {
		unshift @_, $self unless $self eq __PACKAGE__;
		$self = new __PACKAGE__;
	}

	# Grab or guess the filename
	my $stor = $objstore->{_refaddr($self)};
	my $rrdfile = @_ % 2 ? shift : _guess_filename($stor);

}


# Fetch the last values inserted in to an RRD file
sub last_values {
	TRACE(">>> last_values()");
	my $self = shift;
	unless (ref $self && UNIVERSAL::isa($self, __PACKAGE__)) {
		unshift @_, $self unless $self eq __PACKAGE__;
		$self = new __PACKAGE__;
	}

	# Grab or guess the filename
	my $stor = $objstore->{_refaddr($self)};
	my $rrdfile = @_ % 2 ? shift : _guess_filename($stor);

	# When was the RRD last updated?
	my $lastUpdated = $self->last($rrdfile);

	# Is there a LAST RRA?
	my $info = $self->info($rrdfile);
	my $hasLastRRA = 0;
	for my $rra (@{$info->{rra}}) {
		$hasLastRRA++ if $rra->{cf} eq 'LAST';
	}
	return if !$hasLastRRA;

	# What's the largest heartbeat in the RRD file data sources?
	my $largestHeartbeat = 1;
	for (map { $info->{ds}->{$_}->{'minimal_heartbeat'} } keys(%{$info->{ds}})) {
		$largestHeartbeat = $_ if $_ > $largestHeartbeat;
	}

	my @def = ('LAST',
				'-s', $lastUpdated - ($largestHeartbeat * 2),
				'-e', $lastUpdated
			);

	# Pass to RRDs to execute
	my ($time,$heartbeat,$ds,$data) = RRDs::fetch($rrdfile, @def);
	my $error = RRDs::error();
	croak($error) if $error;

	# Put it in to a nice easy format
	my %rtn = ();
	for my $rec (reverse @{$data}) {
		for (my $i = 0; $i < @{$rec}; $i++) {
			if (defined $rec->[$i] && !exists($rtn{$ds->[$i]})) {
				$rtn{$ds->[$i]} = $rec->[$i];
			}
		}
	}

	# Well, I'll be buggered if the LAST CF does what you'd think
	# it's meant to do. If anybody can give me some decent documentation
	# on what the LAST CF does, and/or how to get the last value put
	# in to an RRD, then I'll admit that this method exists and export
	# it too.

	return wantarray ? %rtn : \%rtn;
}


# Return how long this RRD retains data for
sub retention_period {
	TRACE(">>> retention_period()");
	my $self = shift;
	unless (ref $self && UNIVERSAL::isa($self, __PACKAGE__)) {
		unshift @_, $self unless $self eq __PACKAGE__;
		$self = new __PACKAGE__;
	}

	my $info = $self->info(@_);
	return if !defined($info);

	my $duration = $info->{step};
	for my $rra (@{$info->{rra}}) {
		my $secs = ($rra->{pdp_per_row} * $info->{step}) * $rra->{rows};
		$duration = $secs if $secs > $duration;
	}

	return wantarray ? ($duration) : $duration;
}


# Fetch information about an RRD file
sub info {
	TRACE(">>> info()");
	my $self = shift;
	unless (ref $self && UNIVERSAL::isa($self, __PACKAGE__)) {
		unshift @_, $self unless $self eq __PACKAGE__;
		$self = new __PACKAGE__;
	}

	# Grab or guess the filename
	my $stor = $objstore->{_refaddr($self)};
	my $rrdfile = @_ % 2 ? shift : _guess_filename($stor);

	my $info = RRDs::info($rrdfile);
	my $error = RRDs::error();
	croak($error) if $error;
	DUMP('$info',$info);

	my $rtn;
	for my $key (sort(keys(%{$info}))) {
		if ($key =~ /^rra\[(\d+)\]\.([a-z_]+)/) {
			$rtn->{rra}->[$1]->{$2} = $info->{$key};
		} elsif (my (@dsKey) = $key =~ /^ds\[([[A-Za-z0-9\_]+)?\]\.([a-z_]+)/) {
			$rtn->{ds}->{$1}->{$2} = $info->{$key};
		} elsif ($key !~ /\[[\d_a-z]+\]/i) {
			$rtn->{$key} = $info->{$key};
		}
	}

	# Return the information
	DUMP('$rtn',$rtn);
	return $rtn;
}


# Convert a string or an array reference to an array
sub _convert_to_array {
	return unless defined $_[0];
	if (!ref $_[0]) {
		$_[0] =~ /^\s+|\s+$/g;
		return split(/(?:\s+|\s*,\s*)/,$_[0]);
	} elsif (ref($_[0]) eq 'ARRAY') {
		return @{$_[0]};
	}
	return;
}


# Make a single graph image
sub _create_graph {
	TRACE(">>> _create_graph()");
	my $self = shift;
	my $rrdfile = shift;
	my $type = _valid_scheme(shift) || 'day';
	my $cf = shift || 'AVERAGE';

	my $command_regex = qr/^([VC]?DEF|G?PRINT|COMMENT|[HV]RULE\d*|LINE\d*|AREA|TICK|SHIFT|STACK):.+/;
	$command_regex = qr/^([VC]?DEF|G?PRINT|COMMENT|[HV]RULE\d*|LINE\d*|AREA|TICK|SHIFT|STACK|TEXTALIGN):.+/
		if $RRDs::VERSION >= 1.3; # http://oss.oetiker.ch/rrdtool-trac/wiki/RRDtool13

	my %param;
	my @command_param;
	while (my $k = shift) {
		if ($k =~ /$command_regex/) {
			push @command_param, $k;
			shift;
		} else {
			$k =~ s/_/-/g;
			$param{lc($k)} = shift;
		}
	}

	# If we get this custom  parameter then it would have already
	# been dealt with by the calling graph() method so we should
	# ditch it right here and now!
	delete $param{'periods'};

	# Specify some default values
	$param{'end'} ||= $self->last($rrdfile) || time();
	$param{'imgformat'} ||= 'PNG'; # RRDs >1.3 now support PDF, SVG and EPS
	# $param{'alt-autoscale'} ||= '';
	# $param{'alt-y-grid'} ||= '';

	# Define what to call the image
	my $basename = defined $param{'basename'} &&
			$param{'basename'} =~ /^[0-9a-z_\.-]+$/i ?
			$param{'basename'} :
			(fileparse($rrdfile,'\.[^\.]+'))[0];
	delete $param{'basename'};

	# Define where to write the image
	my $image = sprintf('%s-%s.%s',$basename,
		_alt_graph_name($type), lc($param{'imgformat'}));
	if ($param{'destination'}) {
		$image = File::Spec->catfile($param{'destination'},$image);
	}
	delete $param{'destination'};

	# Specify timestamps- new for version 1.41
	my $timestamp = !defined $param{'timestamp'} ||
			$param{'timestamp'} !~ /^(graph|rrd|both|none)$/i
				? 'graph'
				: lc($param{'timestamp'});
	delete $param{'timestamp'};

	# Specify extended legend - new for version 1.35
	my $extended_legend = defined $param{'extended-legend'} &&
				$param{'extended-legend'} ? 1 : 0;
	delete $param{'extended-legend'};

	# Define how thick the graph lines should be
	my $line_thickness = defined $param{'line-thickness'} &&
				$param{'line-thickness'} =~ /^[123]$/ ?
				$param{'line-thickness'} : 1;
	delete $param{'line-thickness'};

	# Colours is an alias to colors
	if (exists $param{'source-colours'} && !exists $param{'source-colors'}) {
		$param{'source-colors'} = $param{'source-colours'};
		delete $param{'source-colours'};
	}

	# Allow source line colors to be set
	my @source_colors = ();
	my %source_colors = ();
	if (defined $param{'source-colors'}) {
		#if (ref($param{'source-colors'}) eq 'ARRAY') {
		#	@source_colors = @{$param{'source-colors'}};
		if (ref($param{'source-colors'}) eq 'HASH') {
			%source_colors = %{$param{'source-colors'}};
		} else {
			@source_colors = _convert_to_array($param{'source-colors'});
		}
	}
	delete $param{'source-colors'};

	# Define which data sources we should plot
	my @rrd_sources = $self->sources($rrdfile);
	my @ds = !exists $param{'sources'}
			? @rrd_sources
			#: defined $param{'sources'} && ref($param{'sources'}) eq 'ARRAY'
				#? @{$param{'sources'}}
			: defined $param{'sources'}
				? _convert_to_array($param{'sources'})
				: ();

	# Allow source legend source_labels to be set
	my %source_labels = ();
	if (defined $param{'source-labels'}) {
		if (ref($param{'source-labels'}) eq 'HASH') {
			%source_labels = %{$param{'source-labels'}};
		} elsif (ref($param{'source-labels'}) eq 'ARRAY') {
			if (defined $param{'sources'} && ref($param{'sources'}) eq 'ARRAY') {
				for (my $i = 0; $i < @{$param{'source-labels'}}; $i++) {
					$source_labels{$ds[$i]} = $param{'source-labels'}->[$i]
						if defined $ds[$i];
				}
			} elsif ($^W) {
				carp "source_labels may only be an array if sources is also ".
					"an specified and valid array";
			}
		}
	}
	delete $param{'source-labels'};

	# Allow source legend source_drawtypes to be set
	#   ... "oops" ... yes, this is quite obviously
	#   copy and paste code from the chunk above. I'm
	#   sorry. I'll rationalise it some other day if
	#   it's necessary.
	my %source_drawtypes = ();
	if (defined $param{'source-drawtypes'}) {
		if (ref($param{'source-drawtypes'}) eq 'HASH') {
			%source_drawtypes = %{$param{'source-drawtypes'}};
		} elsif (ref($param{'source-drawtypes'}) eq 'ARRAY') {
			if (defined $param{'sources'} && ref($param{'sources'}) eq 'ARRAY') {
				for (my $i = 0; $i < @{$param{'source-drawtypes'}}; $i++) {
					$source_drawtypes{$ds[$i]} = $param{'source-drawtypes'}->[$i]
						if defined $ds[$i];
				}
			} elsif ($^W) {
				carp "source_drawtypes may only be an array if sources is ".
					"also an specified and valid array"
			}
		}

		# Validate the values we have and set default thickness
		while (my ($k,$v) = each %source_drawtypes) {
			if ($v !~ /^(LINE[1-9]?|STACK|AREA)$/) {
				delete $source_drawtypes{$k};
				carp "source_drawtypes may be LINE, LINEn, AREA or STACK ".
					"only; value '$v' is not valid" if $^W;
			}
			$source_drawtypes{$k} = uc($v);
			$source_drawtypes{$k} .= $line_thickness if $v eq 'LINE';
		}
	}
	delete $param{'source-drawtypes'};
	delete $param{'sources'};

	# Specify a default start time
	$param{'start'} ||= $param{'end'} - _seconds_in($type,115);

	# Suffix the title with the period information
	$param{'title'} ||= basename($rrdfile);
	$param{'title'} .= ' - [Hourly Graph]'  if $type eq 'hour';
	$param{'title'} .= ' - [6 Hour Graph]'  if $type eq '6hour'  || $type eq 'quarterday';
	$param{'title'} .= ' - [12 Hour Graph]' if $type eq '12hour' || $type eq 'halfday';
	$param{'title'} .= ' - [Daily Graph]'   if $type eq 'day';
	$param{'title'} .= ' - [Weekly Graph]'  if $type eq 'week';
	$param{'title'} .= ' - [Monthly Graph]' if $type eq 'month';
	$param{'title'} .= ' - [Annual Graph]'  if $type eq 'year';
	$param{'title'} .= ' - [3 Year Graph]'  if $type eq '3years';

	# Convert our parameters in to an RRDs friendly defenition
	my @def;
	while (my ($k,$v) = each %param) {
		if (length($k) == 1) { # Short single character options
			$k = '-'.uc($k);
		} else { # Long options
			$k = "--$k";
		}
		for my $v ((ref($v) eq 'ARRAY' ? @{$v} : ($v))) {
			if (!defined $v || !length($v)) {
				push @def, $k;
			} else {
				push @def, "$k=$v";
			}
		}
	}

	# Populate a cycling tied scalar for line colors
	@source_colors = qw(
			FF0000 00FF00 0000FF 00FFFF FF00FF FFFF00 000000
			990000 009900 000099 009999 990099 999900 999999
			552222 225522 222255 225555 552255 555522 555555
		) unless @source_colors > 0;
			# Pre 1.35 colours
			# FF0000 00FF00 0000FF FFFF00 00FFFF FF00FF 000000
			# 550000 005500 000055 555500 005555 550055 555555
			# AA0000 00AA00 0000AA AAAA00 00AAAA AA00AA AAAAAA
	tie my $colour, 'RRD::Simple::_Colour', \@source_colors;

	my $fmt = '%s:%s#%s:%s%s';
	my $longest_label = 1;
	if ($extended_legend) {
		for my $ds (@ds) {
			my $len = length( defined $source_labels{$ds} ?
					$source_labels{$ds} : $ds );
			$longest_label = $len if $len > $longest_label;
		}
		$fmt = "%s:%s#%s:%-${longest_label}s%s";
	}



##
##
##

	# Create the @cmd
	my @cmd = ($image,@def);

	# Add the data sources definitions to @cmd
	for my $ds (@rrd_sources) {
		# Add the data source definition
		push @cmd, sprintf('DEF:%s=%s:%s:%s',$ds,$rrdfile,$ds,$cf);
	}

	# Add the data source draw commands to the grap/@cmd
	for my $ds (@ds) {
		# Stack operates differently in RRD 1.2 or higher
		my $drawtype = defined $source_drawtypes{$ds} ? $source_drawtypes{$ds}
						: "LINE$line_thickness";
		my $stack = '';
		if ($RRDs::VERSION >= 1.2 && $drawtype eq 'STACK') {
			$drawtype = 'AREA';
			$stack = ':STACK';
		}

		# Draw the line (and add to the legend)
		push @cmd, sprintf($fmt,
				$drawtype,
				$ds,
				(defined $source_colors{$ds} ? $source_colors{$ds} : $colour),
				(defined $source_labels{$ds} ? $source_labels{$ds} : $ds),
				$stack
			);

		# New for version 1.39
		# Return the min,max,last information in the graph() return @rtn
		if ($RRDs::VERSION >= 1.2) {
			push @cmd, sprintf('VDEF:%sMIN=%s,MINIMUM',$ds,$ds);
			push @cmd, sprintf('VDEF:%sMAX=%s,MAXIMUM',$ds,$ds);
			push @cmd, sprintf('VDEF:%sLAST=%s,LAST',$ds,$ds);
			# Don't automatically add this unless we have to
			# push @cmd, sprintf('VDEF:%sAVERAGE=%s,AVERAGE',$ds,$ds);
			push @cmd, sprintf('PRINT:%sMIN:%s min %%1.2lf',$ds,$ds);
			push @cmd, sprintf('PRINT:%sMAX:%s max %%1.2lf',$ds,$ds);
			push @cmd, sprintf('PRINT:%sLAST:%s last %%1.2lf',$ds,$ds);
		} else {
			push @cmd, sprintf('PRINT:%s:MIN:%s min %%1.2lf',$ds,$ds);
			push @cmd, sprintf('PRINT:%s:MAX:%s max %%1.2lf',$ds,$ds);
			push @cmd, sprintf('PRINT:%s:LAST:%s last %%1.2lf',$ds,$ds);
		}

		# New for version 1.35
		if ($extended_legend) {
			if ($RRDs::VERSION >= 1.2) {
				# Moved the VDEFs to the block of code above which is
				# always run, regardless of the extended legend
				push @cmd, sprintf('GPRINT:%sMIN:   min\:%%10.2lf\g',$ds);
				push @cmd, sprintf('GPRINT:%sMAX:   max\:%%10.2lf\g',$ds);
				push @cmd, sprintf('GPRINT:%sLAST:   last\:%%10.2lf\l',$ds);
			} else {
				push @cmd, sprintf('GPRINT:%s:MIN:   min\:%%10.2lf\g',$ds);
				push @cmd, sprintf('GPRINT:%s:MAX:   max\:%%10.2lf\g',$ds);
				push @cmd, sprintf('GPRINT:%s:LAST:   last\:%%10.2lf\l',$ds);
			}
		}
	}






	# Push the post command defs on to the stack
	push @cmd, @command_param;

	# Add a comment stating when the graph was last updated
	if ($timestamp ne 'none') {
		#push @cmd, ('COMMENT:\s','COMMENT:\s','COMMENT:\s');
		push @cmd, ('COMMENT:\s','COMMENT:\s');
		push @cmd, 'COMMENT:\s' unless $extended_legend || !@ds;
		my $timefmt = '%a %d/%b/%Y %T %Z';

		if ($timestamp eq 'rrd' || $timestamp eq 'both') {
			my $time = sprintf('RRD last updated: %s\r',
							strftime($timefmt,localtime((stat($rrdfile))[9]))
						);
			$time =~ s/:/\\:/g if $RRDs::VERSION >= 1.2; # Only escape for 1.2
			push @cmd, "COMMENT:$time";
		}

		if ($timestamp eq 'graph' || $timestamp eq 'both') {
			my $time = sprintf('Graph last updated: %s\r',
							strftime($timefmt,localtime(time))
						);
			$time =~ s/:/\\:/g if $RRDs::VERSION >= 1.2; # Only escape for 1.2
			push @cmd, "COMMENT:$time";
		}
	}

	DUMP('@cmd',\@cmd);

	# Generate the graph
	my @rtn = RRDs::graph(@cmd);
	my $error = RRDs::error();
	croak($error) if $error;
	return ($image,@rtn);
}




#
# Private subroutines
#

no warnings 'redefine';
sub UNIVERSAL::a_sub_not_likely_to_be_here { ref($_[0]) }
use warnings 'redefine';


sub _blessed ($) {
	local($@, $SIG{__DIE__}, $SIG{__WARN__});
	return length(ref($_[0]))
			? eval { $_[0]->a_sub_not_likely_to_be_here }
			: undef
}


sub _refaddr($) {
	my $pkg = ref($_[0]) or return undef;
	if (_blessed($_[0])) {
		bless $_[0], 'Scalar::Util::Fake';
	} else {
		$pkg = undef;
	}
	"$_[0]" =~ /0x(\w+)/;
	my $i = do { local $^W; hex $1 };
	bless $_[0], $pkg if defined $pkg;
	return $i;
}


sub _isLegalDsName {
#rrdtool-1.0.49/src/rrd_format.h:#define DS_NAM_FMT    "%19[a-zA-Z0-9_-]"
#rrdtool-1.2.11/src/rrd_format.h:#define DS_NAM_FMT    "%19[a-zA-Z0-9_-]"

##
## TODO
## 1.45 - Double check this with the latest 1.3 version of RRDtool
##        to see if it has changed or not
##

	return $_[0] =~ /^[a-zA-Z0-9_-]{1,19}$/;
}


sub _rrd_def {
	croak('Pardon?!') if ref $_[0];
	my $type = _valid_scheme(shift);

	# This is calculated the same way as mrtg v2.13.2
	if ($type eq 'mrtg') {
		my $step = 5; # 5 minutes
		return {
				step => $step * 60,
				heartbeat => $step * 60 * 2,
				rra => [(
					{ step => 1, rows => int(4000 / $step) }, # 800
					{ step => int(  30 / $step), rows => 800 }, # if $step < 30
					{ step => int( 120 / $step), rows => 800 },
					{ step => int(1440 / $step), rows => 800 },
				)],
			};
	}

##
## TODO
## 1.45 Add higher resolution for hour, 6hour and 12 hour
##

	my $step = 1; # 1 minute highest resolution
	my $rra = {
			step => $step * 60,
			heartbeat => $step * 60 * 2,
			rra => [(
				# Actual $step resolution (for 1.25 days retention)
				{ step => 1, rows => int( _minutes_in('day',125) / $step) },
			)],
		};

	if ($type =~ /^(week|month|year|3years)$/i) {
		push @{$rra->{rra}}, {
				step => int(  30 / $step),
				rows => int( _minutes_in('week',125) / int(30/$step) )
			}; # 30 minute average

		push @{$rra->{rra}}, {
				step => int( 120 / $step),
				rows => int( _minutes_in($type eq 'week' ? 'week' : 'month',125)
						/ int(120/$step) )
			}; # 2 hour average
	}

	if ($type =~ /^(year|3years)$/i) {
		push @{$rra->{rra}}, {
				step => int(1440 / $step),
				rows => int( _minutes_in($type,125) / int(1440/$step) )
			}; # 1 day average
	}

	return $rra;
}


sub _odd {
	return $_[0] % 2;
}


sub _even {
	return !($_[0] % 2);
}


sub _valid_scheme {
	TRACE(">>> _valid_scheme()");
	croak('Pardon?!') if ref $_[0];
	#if ($_[0] =~ /^(day|week|month|year|3years|mrtg)$/i) {
	if ($_[0] =~ /^((?:6|12)?hour|(?:half)?day|week|month|year|3years|mrtg)$/i) {
		TRACE("'".lc($1)."' is a valid scheme.");
		return lc($1);
	}
	TRACE("'@_' is not a valid scheme.");
	return undef;
}


sub _hours_in { return int((_seconds_in(@_)/60)/60); }
sub _minutes_in { return int(_seconds_in(@_)/60); }
sub _seconds_in {
	croak('Pardon?!') if ref $_[0];
	my $str = lc(shift);
	my $scale = shift || 100;

	return undef if !defined(_valid_scheme($str));

	my %time = (
			# New for version 1.44 of RRD::Simple by
			# popular request
			'hour'       => 60 * 60,
			'6hour'      => 60 * 60 * 6,
			'quarterday' => 60 * 60 * 6,
 			'12hour'     => 60 * 60 * 12,
			'halfday'    => 60 * 60 * 12,

			'day'    => 60 * 60 * 24,
			'week'   => 60 * 60 * 24 * 7,
			'month'  => 60 * 60 * 24 * 31,
			'year'   => 60 * 60 * 24 * 365,
			'3years' => 60 * 60 * 24 * 365 * 3,
			'mrtg'   => ( int(( 1440 / 5 )) * 800 ) * 60, # mrtg v2.13.2
		);

	my $rtn = $time{$str} * ($scale / 100);
	return $rtn;
}


sub _alt_graph_name {
	croak('Pardon?!') if ref $_[0];
	my $type = _valid_scheme(shift);
	return unless defined $type;

	# New for version 1.44 of RRD::Simple by popular request
	return 'hourly'   if $type eq 'hour';
	return '6hourly'  if $type eq '6hour'  || $type eq 'quarterday';
	return '12hourly' if $type eq '12hour' || $type eq 'halfday';

	return 'daily'    if $type eq 'day';
	return 'weekly'   if $type eq 'week';
	return 'monthly'  if $type eq 'month';
	return 'annual'   if $type eq 'year';
	return '3years'   if $type eq '3years';
	return $type;
}


##
## TODO
## 1.45 - Check to see if there is now native support in RRDtool to
##        add, remove or change existing sources - and if there is
##        make this code only run for onler versions that do not have
##        native support.
##

sub _modify_source {
	croak('Pardon?!') if ref $_[0];
	my ($rrdfile,$stor,$ds,$action,$dstype,$heartbeat) = @_;
	my $rrdtool = $stor->{rrdtool};
	$rrdtool = '' unless defined $rrdtool;

	# Decide what action we should take
	if ($action !~ /^(add|del)$/) {
		my $caller = (caller(1))[3];
		$action = $caller =~ /\badd\b/i ? 'add' :
				$caller =~ /\bdel(ete)?\b/i ? 'del' : undef;
	}
	croak "Unknown or no action passed to method _modify_source()"
		unless defined $action && $action =~ /^(add|del)$/;

	require File::Copy;
	require File::Temp;

	# Generate an XML dump of the RRD file
	# - Added "tmpdir" support in 1.44
	my $tmpdir = defined $stor->{tmpdir} ? $stor->{tmpdir} : File::Spec->tmpdir();
	my ($tempXmlFileFH,$tempXmlFile) = File::Temp::tempfile(
			DIR      => $tmpdir,
			TEMPLATE => 'rrdXXXXX',
			SUFFIX   => '.tmp',
		);

	# Check that we managed to get a sane temporary filename
	croak "File::Temp::tempfile() failed to return a temporary filename"
		unless defined $tempXmlFile;
	TRACE("_modify_source(): \$tempXmlFile = $tempXmlFile");

	# Try the internal perl way first (portable)
	eval {
		# Patch to rrd_dump.c emailed to Tobi and developers
		# list by nicolaw/heds on 2006/01/08
		if ($RRDs::VERSION >= 1.2013) {
			my @rtn = RRDs::dump($rrdfile,$tempXmlFile);
			my $error = RRDs::error();
			croak($error) if $error;
		}
	};

	# Do it the old fashioned way
	if ($@ || !-f $tempXmlFile || (stat($tempXmlFile))[7] < 200) {
		croak "rrdtool binary '$rrdtool' does not exist or is not executable"
			if !defined $rrdtool || !-f $rrdtool || !-x $rrdtool;
		_safe_exec(sprintf('%s dump %s > %s',$rrdtool,$rrdfile,$tempXmlFile));
	}

	# Read in the new temporary XML dump file
	open(IN, "<$tempXmlFile") || croak "Unable to open '$tempXmlFile': $!";

	# Open XML output file
	# my $tempImportXmlFile = File::Temp::tmpnam();
	# - Added "tmpdir" support in 1.44
	my ($tempImportXmlFileFH,$tempImportXmlFile) = File::Temp::tempfile(
			DIR      => $tmpdir,
			TEMPLATE => 'rrdXXXXX',
			SUFFIX   => '.tmp',
		);
	open(OUT, ">$tempImportXmlFile")
		|| croak "Unable to open '$tempImportXmlFile': $!";

	# Create a marker hash ref to store temporary state
	my $marker = {
				currentDSIndex => 0,
				deleteDSIndex => undef,
				addedNewDS => 0,
				parse => 0,
				version => 1,
			};

	# Parse the input XML file
	while (local $_ = <IN>) {
		chomp;

		# Find out what index number the existing DS definition is in
		if ($action eq 'del' && /<name>\s*(\S+)\s*<\/name>/) {
			$marker->{deleteIndex} = $marker->{currentDSIndex} if $1 eq $ds;
			$marker->{currentDSIndex}++;
		}

		# Add the DS definition
		if ($action eq 'add' && !$marker->{addedNewDS} && /<rra>/) {
			print OUT <<EndDS;
	<ds>
		<name> $ds </name>
		<type> $dstype </type>
		<minimal_heartbeat> $heartbeat </minimal_heartbeat>
		<min> 0.0000000000e+00 </min>
		<max> NaN </max>

		<!-- PDP Status -->
		<last_ds> UNKN </last_ds>
		<value> 0.0000000000e+00 </value>
		<unknown_sec> 0 </unknown_sec>
	</ds>

EndDS
			$marker->{addedNewDS} = 1;
		}

		# Insert DS under CDP_PREP entity
		if ($action eq 'add' && /<\/cdp_prep>/) {
			# Version 0003 RRD from rrdtool 1.2x
			if ($marker->{version} >= 3) {
				print OUT "			<ds>\n";
				print OUT "			<primary_value> 0.0000000000e+00 </primary_value>\n";
				print OUT "			<secondary_value> 0.0000000000e+00 </secondary_value>\n";
				print OUT "			<value> NaN </value>\n";
				print OUT "			<unknown_datapoints> 0 </unknown_datapoints>\n";
				print OUT "			</ds>\n";

			# Version 0001 RRD from rrdtool 1.0x
			} else { 
				print OUT "			<ds><value> NaN </value>  <unknown_datapoints> 0 </unknown_datapoints></ds>\n";
			}
		}

		# Look for the end of an RRA
		if (/<\/database>/) {
			$marker->{parse} = 0;

		# Find the dumped RRD version (must take from the XML, not the RRD)
		} elsif (/<version>\s*([0-9\.]+)\s*<\/version>/) {
			$marker->{version} = ($1 + 1 - 1);
		}

		# Add the extra "<v> NaN </v>" under the RRAs. Just print normal lines
		if ($marker->{parse} == 1) {
			if ($_ =~ /^(.+ <row>.+)(<\/row>.*)/) {
				print OUT $1;
				print OUT "<v> NaN </v>" if $action eq 'add';
				print OUT $2;
				print OUT "\n";
			}
		} else {
			print OUT "$_\n";
		}

		# Look for the start of an RRA
		if (/<database>/) {
			$marker->{parse} = 1;
		}
	}

	# Close the files
	close(IN) || croak "Unable to close '$tempXmlFile': $!";
	close(OUT) || croak "Unable to close '$tempImportXmlFile': $!";

	# Import the new output file in to the old RRD filename
	my $new_rrdfile = File::Temp::tmpnam();
	TRACE("_modify_source(): \$new_rrdfile = $new_rrdfile");

	# Try the internal perl way first (portable)
	eval {
		if ($RRDs::VERSION >= 1.0049) {
			my @rtn = RRDs::restore($tempImportXmlFile,$new_rrdfile);
			my $error = RRDs::error();
			croak($error) if $error;
		}
	};

	# Do it the old fashioned way
	if ($@ || !-f $new_rrdfile || (stat($new_rrdfile))[7] < 200) {
		croak "rrdtool binary '$rrdtool' does not exist or is not executable"
			unless (-f $rrdtool && -x $rrdtool);
		my $cmd = sprintf('%s restore %s %s',$rrdtool,$tempImportXmlFile,$new_rrdfile);
		my $rtn = _safe_exec($cmd);

		# At least check the file is created
		unless (-f $new_rrdfile) {
			_nuke_tmp($tempXmlFile,$tempImportXmlFile);
			croak "Command '$cmd' failed to create the new RRD file '$new_rrdfile': $rtn";
		}
	}

	# Remove the temporary files
	_nuke_tmp($tempXmlFile,$tempImportXmlFile);
	sub _nuke_tmp {
		for (@_) {
			unlink($_) ||
				carp("Unable to unlink temporary file '$_': $!");
		}
	}

	# Return the new RRD filename
	return wantarray ? ($new_rrdfile) : $new_rrdfile;
}


##
## TODO
## 1.45 - Improve this _safe_exec function to see if it can be made
##        more robust and use any better CPAN modules if that happen
##        to already be installed on the users system (don't add any
##        new module dependancies though)
##

sub _safe_exec {
	croak('Pardon?!') if ref $_[0];
	my $cmd = shift;
	if ($cmd =~ /^([\/\.\_\-a-zA-Z0-9 >]+)$/) {
		$cmd = $1;
		TRACE($cmd);
		system($cmd);
		if ($? == -1) {
			croak "Failed to execute command '$cmd': $!\n";
		} elsif ($? & 127) {
			croak(sprintf("While executing command '%s', child died ".
				"with signal %d, %s coredump\n", $cmd,
				($? & 127),  ($? & 128) ? 'with' : 'without'));
		}
		my $exit_value = $? >> 8;
		croak "Error caught from '$cmd'" if $exit_value != 0;
		return $exit_value;
	} else {
		croak "Unexpected potentially unsafe command will not be executed: $cmd";
	}
}


sub _find_binary {
	croak('Pardon?!') if ref $_[0];
	my $binary = shift || 'rrdtool';
	return $binary if -f $binary && -x $binary;

	my @paths = File::Spec->path();
	my $rrds_path = dirname($INC{'RRDs.pm'});
	push @paths, $rrds_path;
	push @paths, File::Spec->catdir($rrds_path,
				File::Spec->updir(),File::Spec->updir(),'bin');

	for my $path (@paths) {
		my $filename = File::Spec->catfile($path,$binary);
		return $filename if -f $filename && -x $filename;
	}

	my $path = File::Spec->catdir(File::Spec->rootdir(),'usr','local');
	if (opendir(DH,$path)) {
		my @dirs = sort { $b cmp $a } grep(/^rrdtool/,readdir(DH));
		closedir(DH) || carp "Unable to close file handle: $!";
		for my $dir (@dirs) {
			my $filename = File::Spec->catfile($path,$dir,'bin',$binary);
			return $filename if -f $filename && -x $filename;
		}
	}
}


sub _guess_filename {
	croak('Pardon?!') if !defined $_[0] || ref($_[0]) ne 'HASH';
	my $stor = shift;
	if (defined $stor->{file}) {
		TRACE("_guess_filename = \$stor->{file} = $stor->{file}");
		return $stor->{file};
	}
	my ($basename, $dirname, $extension) = fileparse($0, '\.[^\.]+');
	TRACE("_guess_filename = calculated = $dirname$basename.rrd");
	return "$dirname$basename.rrd";
}


sub DESTROY {
	my $self = shift;
	delete $objstore->{_refaddr($self)};
}


sub TRACE {
	return unless $DEBUG;
	carp(shift());
}


sub DUMP {
	return unless $DEBUG;
	eval {
		require Data::Dumper;
		$Data::Dumper::Indent = 2;
		$Data::Dumper::Terse = 1;
		carp(shift().': '.Data::Dumper::Dumper(shift()));
	}
}

BEGIN {
	eval "use RRDs";
	if ($@) {
		carp qq{
+-----------------------------------------------------------------------------+
| ERROR! -- Could not load RRDs.pm                                            |
|                                                                             |
| RRD::Simple requires RRDs.pm (a part of RRDtool) in order to function. You  |
| can download a copy of RRDtool from http://www.rrdtool.org. See the INSTALL |
| document for more details.                                                  |
+-----------------------------------------------------------------------------+

} unless $ENV{AUTOMATED_TESTING};
	}
}


1;


###############################################################
# This tie code is from Tie::Cycle
# written by brian d foy, <bdfoy@cpan.org>

package RRD::Simple::_Colour;

sub TIESCALAR {
	my ($class,$list_ref) = @_;
	my @shallow_copy = map { $_ } @$list_ref;
	return unless UNIVERSAL::isa( $list_ref, 'ARRAY' );
	my $self = [ 0, scalar @shallow_copy, \@shallow_copy ];
	bless $self, $class;
}

sub FETCH {
	my $self = shift;
	my $index = $$self[0]++;
	$$self[0] %= $self->[1];
	return $self->[2]->[ $index ];
}

sub STORE {
	my ($self,$list_ref) = @_;
	return unless ref $list_ref eq ref [];
	return unless @$list_ref > 1;
	$self = [ 0, scalar @$list_ref, $list_ref ];
}

1;




=pod

=head1 NAME

RRD::Simple - Simple interface to create and store data in RRD files

=head1 SYNOPSIS

 use strict;
 use RRD::Simple ();
 
 # Create an interface object
 my $rrd = RRD::Simple->new( file => "myfile.rrd" );
 
 # Create a new RRD file with 3 data sources called
 # bytesIn, bytesOut and faultsPerSec.
 $rrd->create(
             bytesIn => "GAUGE",
             bytesOut => "GAUGE",
             faultsPerSec => "COUNTER"
         );
 
 # Put some arbitary data values in the RRD file for the same
 # 3 data sources called bytesIn, bytesOut and faultsPerSec.
 $rrd->update(
             bytesIn => 10039,
             bytesOut => 389,
             faultsPerSec => 0.4
         );
 
 # Generate graphs:
 # /var/tmp/myfile-daily.png, /var/tmp/myfile-weekly.png
 # /var/tmp/myfile-monthly.png, /var/tmp/myfile-annual.png
 my %rtn = $rrd->graph(
             destination => "/var/tmp",
             title => "Network Interface eth0",
             vertical_label => "Bytes/Faults",
             interlaced => ""
         );
 printf("Created %s\n",join(", ",map { $rtn{$_}->[0] } keys %rtn));

 # Return information about an RRD file
 my $info = $rrd->info;
 require Data::Dumper;
 print Data::Dumper::Dumper($info);

 # Get unixtime of when RRD file was last updated
 my $lastUpdated = $rrd->last;
 print "myfile.rrd was last updated at " .
       scalar(localtime($lastUpdated)) . "\n";
 
 # Get list of data source names from an RRD file
 my @dsnames = $rrd->sources;
 print "Available data sources: " . join(", ", @dsnames) . "\n";
 
 # And for the ultimately lazy, you could create and update
 # an RRD in one go using a one-liner like this:
 perl -MRRD::Simple=:all -e"update(@ARGV)" myfile.rrd bytesIn 99999 

=head1 DESCRIPTION

RRD::Simple provides a simple interface to RRDTool's RRDs module.
This module does not currently offer a C<fetch> method that is
available in the RRDs module.

It does however create RRD files with a sensible set of default RRA
(Round Robin Archive) definitions, and can dynamically add new
data source names to an existing RRD file.

This module is ideal for quick and simple storage of data within an
RRD file if you do not need to, nor want to, bother defining custom
RRA definitions.

=head1 METHODS

=head2 new

 my $rrd = RRD::Simple->new(
         file => "myfile.rrd",
         rrdtool => "/usr/local/rrdtool-1.2.11/bin/rrdtool",
         tmpdir => "/var/tmp",
         cf => [ qw(AVERAGE MAX) ],
         default_dstype => "GAUGE",
         on_missing_ds => "add",
     );

The C<file> parameter is currently optional but will become mandatory in
future releases, replacing the optional C<$rrdfile> parameters on subsequent
methods. This parameter specifies the RRD filename to be used.

The C<rrdtool> parameter is optional. It specifically defines where the
C<rrdtool> binary can be found. If not specified, the module will search for
the C<rrdtool> binary in your path, an additional location relative to where
the C<RRDs> module was loaded from, and in /usr/local/rrdtool*.

The C<tmpdir> parameter is option and is only used what automatically adding
a new data source to an existing RRD file. By default any temporary files
will be placed in your default system temp directory (typically /tmp on Linux,
or whatever your TMPDIR environment variable is set to). This parameter can
be used for force any temporary files to be created in a specific directory.

The C<rrdtool> binary is only used by the C<add_source> method, and only
under certain circumstances. The C<add_source> method may also be called
automatically by the C<update> method, if data point values for a previously
undefined data source are provided for insertion.

The C<cf> parameter is optional, but when specified expects an array
reference. The C<cf> parameter defines which consolidation functions are
used in round robin archives (RRAs) when creating new RRD files. Valid
values are AVERAGE, MIN, MAX and LAST. The default value is AVERAGE and
MAX.

The C<default_dstype> parameter is optional. Specifying the default data
source type (DST) through the new() method allows the DST to be localised
to the $rrd object instance rather than be global to the RRD::Simple package.
See L<$RRD::Simple::DEFAULT_DSTYPE>.

The C<on_missing_ds> parameter is optional and will default to "add" when
not defined. This parameter will determine what will happen if you try
to insert or update data for a data source name that does not exist in
the RRD file. Valid values are "add", "ignore" and "die".

=head2 create

 $rrd->create($rrdfile, $period,
         source_name => "TYPE",
         source_name => "TYPE",
         source_name => "TYPE"
     );

This method will create a new RRD file on disk.

C<$rrdfile> is optional and will default to using the RRD filename specified
by the C<new> constructor method, or C<$0.rrd>. (Script basename with the file
extension of .rrd).

C<$period> is optional and will default to C<year>. Valid options are C<hour>,
C<6hour>/C<quarterday>, C<12hour>/C<halfday>, C<day>, C<week>, C<month>,
C<year>, C<3years> and C<mrtg>. Specifying a data retention period value will
change how long data will be retained for within the RRD file. The C<mrtg>
scheme will try and mimic the data retention period used by MRTG v2.13.2
(L<http://people.ee.ethz.ch/~oetiker/webtools/mrtg/>.

The C<mrtg> data retention period uses a data stepping resolution of 300
seconds (5 minutes) and heartbeat of 600 seconds (10 minutes), whereas all the
other data retention periods use a data stepping resolution of 60 seconds
(1 minute) and heartbeat of 120 seconds (2 minutes).

Each data source name should specify the data source type. Valid data source
types (DSTs) are GAUGE, COUNTER, DERIVE and ABSOLUTE. See the section
regrading DSTs at L<http://oss.oetiker.ch/rrdtool/doc/rrdcreate.en.html>
for further information.

RRD::Simple will croak and die if you try to create an RRD file that already
exists.

=head2 update

 $rrd->update($rrdfile, $unixtime,
         source_name => "VALUE",
         source_name => "VALUE",
         source_name => "VALUE"
     );

This method will update an RRD file by inserting new data point values
in to the RRD file.

C<$rrdfile> is optional and will default to using the RRD filename specified
by the C<new> constructor method, or C<$0.rrd>. (Script basename with the file
extension of .rrd).

C<$unixtime> is optional and will default to C<time()> (the current unixtime).
Specifying this value will determine the date and time that your data point
values will be stored against in the RRD file.

If you try to update a value for a data source that does not exist, it will
automatically be added for you. The data source type will be set to whatever
is contained in the C<$RRD::Simple::DEFAULT_DSTYPE> variable. (See the
VARIABLES section below).

If you explicitly do not want this to happen, then you should check that you
are only updating pre-existing data source names using the C<sources> method.
You can manually add new data sources to an RRD file by using the C<add_source>
method, which requires you to explicitly set the data source type.

If you try to update an RRD file that does not exist, it will attept to create
the RRD file for you using the same behaviour as described above. A warning
message will be displayed indicating that the RRD file is being created for
you if have perl warnings turned on.

=head2 last

 my $unixtime = $rrd->last($rrdfile);

This method returns the last (most recent) data point entry time in the RRD
file in UNIX time (seconds since the epoch; Jan 1st 1970). This value should
not be confused with the last modified time of the RRD file.

C<$rrdfile> is optional and will default to using the RRD filename specified
by the C<new> constructor method, or C<$0.rrd>. (Script basename with the file
extension of .rrd).

=head2 sources

 my @sources = $rrd->sources($rrdfile);

This method returns a list of all of the data source names contained within
the RRD file.

C<$rrdfile> is optional and will default to using the RRD filename specified
by the C<new> constructor method, or C<$0.rrd>. (Script basename with the file
extension of .rrd).

=head2 add_source

 $rrd->add_source($rrdfile,
         source_name => "TYPE"
     );

You may add a new data source to an existing RRD file using this method. Only
one data source name can be added at a time. You must also specify the data
source type.

C<$rrdfile> is optional and will default to using the RRD filename specified
by the C<new> constructor method, or C<$0.rrd>. (Script basename with the file
extension of .rrd).

This method can be called internally by the C<update> method to automatically
add missing data sources.

=head2 rename_source

 $rrd->rename_source($rrdfile, "old_datasource", "new_datasource");

You may rename a data source in an existing RRD file using this method.

C<$rrdfile> is optional and will default to using the RRD filename specified
by the C<new> constructor method, or C<$0.rrd>. (Script basename with the file
extension of .rrd).

=head2 graph

 my %rtn = $rrd->graph($rrdfile,
         destination => "/path/to/write/graph/images",
         basename => "graph_basename",
         timestamp => "both", # graph, rrd, both or none
         periods => [ qw(week month) ], # omit to generate all graphs
         sources => [ qw(source_name1 source_name2 source_name3) ],
         source_colors => [ qw(ff0000 aa3333 000000) ],
         source_labels => [ ("My Source 1", "My Source Two", "Source 3") ],
         source_drawtypes => [ qw(LINE1 AREA LINE) ],
         line_thickness => 2,
         extended_legend => 1,
         rrd_graph_option => "value",
         rrd_graph_option => "value",
         rrd_graph_option => "value"
     );

This method will render one or more graph images that show the data in the 
RRD file.

The number of image files that are created depends on the retention period
of the RRD file. Hourly, 6 hourly, 12 hourly, daily, weekly, monthly, annual
and 3year graphs will be created if there is enough data in the RRD file to
accomodate them.

The image filenames will start with either the basename of the RRD
file, or whatever is specified by the C<basename> parameter. The second part
of the filename will be "-hourly", "-6hourly", "-12hourly", "-daily",
"-weekly", "-monthly", "-annual" or "-3year" depending on the period that
is being graphed.

C<$rrdfile> is optional and will default to using the RRD filename specified
by the C<new> constructor method, or C<$0.rrd>. (Script basename with the file
extension of .rrd).

Graph options specific to RRD::Simple are:

=over 4

=item destination

The C<destination> parameter is optional, and it will default to the same
path location as that of the RRD file specified by C<$rrdfile>. Specifying
this value will force the resulting graph images to be written to this path
location. (The specified path must be a valid directory with the sufficient
permissions to write the graph images).

=item basename

The C<basename> parameter is optional. This parameter specifies the basename
of the graph image files that will be created. If not specified, it will
default to the name of the RRD file. For example, if you specify a basename
name of C<mygraph>, the following graph image files will be created in the
C<destination> directory:

 mygraph-daily.png
 mygraph-weekly.png
 mygraph-monthly.png
 mygraph-annual.png

The default file format is C<png>, but this can be explicitly specified using
the standard RRDs options. (See below).

=item timestamp

 my %rtn = $rrd->graph($rrdfile,
         timestamp => "graph", # graph, rrd, both or none
     );

The C<timestamp> parameter is optional, but will default to "graph". This
parameter specifies which "last updated" timestamps should be added to the
bottom right hand corner of the graph.

Valid values are: "graph" - the timestamp of when the graph was last rendered
will be used, "rrd" - the timestamp of when the RRD file was last updated will
be used, "both" - both the timestamps of when the graph and RRD file were last
updated will be used, "none" - no timestamp will be used.

=item periods

The C<periods> parameter is an optional list of periods that graphs should
be generated for. If omitted, all possible graphs will be generated and not
restricted to any specific subset. See the L<create> method for a list of
valid time periods.

=item sources

The C<sources> parameter is optional. This parameter should be an array of
data source names that you want to be plotted. All data sources will be
plotted by default.

=item source_colors

 my %rtn = $rrd->graph($rrdfile,
         source_colors => [ qw(ff3333 ff00ff ffcc99) ],
     );
 
 %rtn = $rrd->graph($rrdfile,
         source_colors => { source_name1 => "ff3333",
                            source_name2 => "ff00ff",
                            source_name3 => "ffcc99", },
     );

The C<source_colors> parameter is optional. This parameter should be an
array or hash of hex triplet colors to be used for the plotted data source
lines. A selection of vivid primary colors will be set by default.

=item source_labels

 my %rtn = $rrd->graph($rrdfile,
         sources => [ qw(source_name1 source_name2 source_name3) ],
         source_labels => [ ("My Source 1","My Source Two","Source 3") ],
     );
 
 %rtn = $rrd->graph($rrdfile,
         source_labels => { source_name1 => "My Source 1",
                            source_name2 => "My Source Two",
                            source_name3 => "Source 3", },
     );

The C<source_labels> parameter is optional. The parameter should be an
array or hash of labels to be placed in the legend/key underneath the
graph. An array can only be used if the C<sources> parameter is also
specified, since the label index position in the array will directly
relate to the data source index position in the C<sources> array.

The data source names will be used in the legend/key by default if no
C<source_labels> parameter is specified.

=item source_drawtypes

 my %rtn = $rrd->graph($rrdfile,
         source_drawtypes => [ qw(LINE1 AREA LINE) ],
     );
 
 %rtn = $rrd->graph($rrdfile,
         source_colors => { source_name1 => "LINE1",
                            source_name2 => "AREA",
                            source_name3 => "LINE", },
     );
 
 %rtn = $rrd->graph($rrdfile,
         sources => [ qw(system user iowait idle) ]
         source_colors => [ qw(AREA STACK STACK STACK) ],
     );

The C<source_drawtypes> parameter is optional. This parameter should be an
array or hash of drawing/plotting types to be used for the plotted data source
lines. By default all data sources are drawn as lines (LINE), but data sources
may also be drawn as filled areas (AREA). Valid values are, LINE, LINEI<n>
(where I<n> represents the thickness of the line in pixels), AREA or STACK.

=item line_thickness

Specifies the thickness of the data lines drawn on the graphs for
any data sources that have not had a specific line thickness already
specified using the C<source_drawtypes> option.
Valid values are 1, 2 and 3 (pixels).

=item extended_legend

If set to boolean true, prints more detailed information in the graph legend
by adding the minimum, maximum and last values recorded on the graph for each
data source.

=back

Common RRD graph options are:

=over 4

=item title

A horizontal string at the top of the graph.

=item vertical_label

A vertically placed string at the left hand side of the graph.

=item width

The width of the canvas (the part of the graph with the actual data
and such). This defaults to 400 pixels.

=item height

The height of the canvas (the part of the graph with the actual data
and such). This defaults to 100 pixels.

=back

For examples on how to best use the C<graph> method, refer to the example
scripts that are bundled with this module in the examples/ directory. A
complete list of parameters can be found at
L<http://people.ee.ethz.ch/~oetiker/webtools/rrdtool/doc/index.en.html>.

=head2 retention_period

 my $seconds = $rrd->retention_period($rrdfile);

This method will return the maximum period of time (in seconds) that the RRD
file will store data for.

C<$rrdfile> is optional and will default to using the RRD filename specified
by the C<new> constructor method, or C<$0.rrd>. (Script basename with the file
extension of .rrd).

=head2 info

 my $info = $rrd->info($rrdfile);

This method will return a complex data structure containing details about
the RRD file, including RRA and data source information.

C<$rrdfile> is optional and will default to using the RRD filename specified
by the C<new> constructor method, or C<$0.rrd>. (Script basename with the file
extension of .rrd).

=head2 heartbeat

 my $heartbeat = $rrd->heartbeat($rrdfile, "dsname");
 my @rtn = $rrd->heartbeat($rrdfile, "dsname", 600);

This method will return the current heartbeat of a data source, or set a
new heartbeat of a data source.

C<$rrdfile> is optional and will default to using the RRD filename specified
by the C<new> constructor method, or C<$0.rrd>. (Script basename with the file
extension of .rrd).

=head1 VARIABLES

=head2 $RRD::Simple::DEBUG

Debug and trace information will be printed to STDERR if this variable
is set to 1 (boolean true).

This variable will take its value from C<$ENV{DEBUG}>, if it exists,
otherwise it will default to 0 (boolean false). This is a normal package
variable and may be safely modified at any time.

=head2 $RRD::Simple::DEFAULT_DSTYPE

This variable is used as the default data source type when creating or
adding new data sources, when no other data source type is explicitly
specified.

This variable will take its value from C<$ENV{DEFAULT_DSTYPE}>, if it
exists, otherwise it will default to C<GAUGE>. This is a normal package
variable and may be safely modified at any time.

=head1 EXPORTS

You can export the following functions if you do not wish to go through
the extra effort of using the OO interface:

 create
 update
 last_update (synonym for the last() method)
 sources
 add_source
 rename_source
 graph
 retention_period
 info
 heartbeat

The tag C<all> is available to easily export everything:

 use RRD::Simple qw(:all);

See the examples and unit tests in this distribution for more
details.

=head1 SEE ALSO

L<RRD::Simple::Examples>, L<RRDTool::OO>, L<RRDs>,
L<http://www.rrdtool.org>, examples/*.pl,
L<http://search.cpan.org/src/NICOLAW/RRD-Simple-1.44/examples/>,
L<http://rrd.me.uk>

=head1 VERSION

$Id: Simple.pm 1100 2008-01-24 17:39:35Z nicolaw $

=head1 AUTHOR

Nicola Worthington <nicolaw@cpan.org>

L<http://perlgirl.org.uk>

If you like this software, why not show your appreciation by sending the
author something nice from her
L<Amazon wishlist|http://www.amazon.co.uk/gp/registry/1VZXC59ESWYK0?sort=priority>? 
( http://www.amazon.co.uk/gp/registry/1VZXC59ESWYK0?sort=priority )

=head1 COPYRIGHT

Copyright 2005,2006,2007,2008 Nicola Worthington.

This software is licensed under The Apache Software License, Version 2.0.

L<http://www.apache.org/licenses/LICENSE-2.0>

=cut


__END__



