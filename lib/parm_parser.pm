
=begin comment
    @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
    =head1 B<parm_parser>
    
    Dave Neudoerffer <dave@neudoerffer.com>
    Brian Martin <bmartin@silverflash.net>
    
    =head2 SYNOPSIS
    
    A package for parsing object definition parameters.
    The parameters can be coming from .mht files or passed directly to the item new function.
    POSITIONAL as well as NAMED parameters are supported.
    DEFAULTS for parameters can also be specified.
    
    =head2 DESCRIPTION

File:
    parm_parser.pm

Description:
    This module provides function for POSITIONAL as well as NAMED parameters and for providing DEFAULTS.
    
    ##########################################################################################################
    NOTE:  Not all item types use this module for parsing parameters.  This code has been designed generically
	   so that it can be used by most item types.  So far, the following item types have been modified to
	   use this code:
	       HA_SERVER
	       HA_ITEM
	       MQTT_BROKER
	       MQTT_ITEM (historic)
	       MQTT_LOCALITEM
	       MQTT_REMOTEITEM
	       MQTT_INSTMQTTITEM
	       MQTT_DISCOVERY
	       MQTT_DISCOVEREDITEM
	    Note also that not all of these support defaults.  That will be noted in the doc for those items.
    ##########################################################################################################

    ITEM types:
    -----------
    ITEM types using this package accept positional or named parameters.
    - Parameters with positions may be provide either by placing them in the specified position,
      or by using the indicated name in a name=>value format.
    - All positional parameters must come before any named parameters.
    - Parameters without a position must be specified using the name=>value format.
    - Positional parameters can be organized in a tabular format so that it is easy to
      figure out what is what -- examples provided below.
   
    ITEM types using this package will have a table of parameters in their documentation.  Here is an example.
    - There may be 2 columns for the position -- fA and new -- Format A .mht files and the sub new for the type
    - For historic reasons, the parms in the .mht file and the parms to the new sub are not necessarily the
      the same, nor necessarily in the same order
    - The 2 columns specify the order of positional parms for the 2 cases
    - In some cases, certain positional parms will be eliminated in the call to the new function.
      The will be marked with a '**' in the table of parameters.
      You can always specify those parms with named parm syntax after the positional parms.

	###################################################
	# SOMEITEMTYPE
	#    - description of item type
	#    - other notes
	#    - DEFAULTS <are/are not> supported
	###################################################
	#
	# Position | Name		    | Default	| Function
	#----------|------------------------|-----------|-------------------------------------------------------
	#     1	   | name		    | -none-	| name of the MH item
	#     2	   | **grouplist	    | -none-	| MH groups the item belongs to
	#     3	   | broker		    | -none-	| MH mqtt broker item -- object reference or name
	#     4	   | type		    | -none-    | mqtt type of the mqtt device
	#     5	   | topic_pattern	    | -none-	| pattern of the state and command messages for the device
	#     6	   | discoverable   	    | 0    	| determines if discovery information will be published
	#     7	   | friendly_name	    | -none-	| pretty name published as name of mqtt device
	#
	# Example .mht:
	#
	# SOMEITEMTYPE,     name,		groups,		broker, type,		topic_pattern,				    discoverable    [Area:]Friendly Name
	SOMEITEMTYPE,	    bootroom_switch,	Lights,		mqtt_1, switch,		insteon/bootroom/+,			    1,		    Bootroom Light
	SOMEITEMTYPE,	    bootroom_switch2,	Lights,		mqtt_1, switch,		insteon/bootroom2/+,
	     discoverable  => 1,
	     friendly_name => Bootroom Light2

        ##########################################################################################################
	# Using DEFAULT/DEFAULTS:
	# -----------------------
	#
	# If SOMEITEMTYPE is created in a FORMAT A .mht with a name of DEFAULT or DEFAULTS),
	# then an object is not created.
	# Instead all of the subsequent options are stored for future reference.
	# Subsequent lines in the .mht file for "SOMEITEMTYPE" will use the values provided in DEFAULTS for any
	# unsupplied values. This can greatly reduce the amount of repetitive information that needs to be provided.
	#
	# NOTE: DEFAULTS are processed in read_table_A.pl.
	#
	# NOTE: DEFAULTS can be supplied in the normal manner as positional or named parameters or some mix.
	#
	# NOTE: It is not possible to default the name parameters.
	#
	# NOTE: A defaults_action parameter may be specified with a DEFAULTS entry
	#       Multiple actions are separated by | (e.g. "update|display").
	#           Valid actions are:
	#          	reset: reset all defaults before applying
	#                      any new ones (default action)
	#    	        update: apply any new values over matching old values
	#                       leaving others untouched (opposite of "reset").
	#    	        display: display resulting defaults after any changes
	#
	# Substitution Variables:
	# In the DEFAULTS declaration, some variables are available. The variables are based on the
	# name, type and ref_name parameters if they exist. Replacement variables are as follows:
	#	%name%		- Replaced with the name of the object (parameter 1).
	#	%name_lc%	- Replaced with the name of the object converted to lowercase
	#	%name_lc%	- Replaced with the name of the object converted to uppercase
	#	%name_no_us%	- The name of the object after replacing underscores with spaces (for friendly_name).
	#	%name_no_pre%	- The name of the object after removing everything up to the first underscore (e.g:
	#			  "tas_outdoor_plug" becomes "outdoor_plug").
	#	%name_no_suf%	- The name of the object after removing the last underscore and everything after.
	#
	#	%type%		- Replaced with the type of the object (parameter 4).
	#	%type_lc%	- Replaced with the type of the object converted to lowercase
	#	%type_lc%	- Replaced with the type of the object converted to uppercase
	#
	#	%ref_name%'		- replaced with the name of the underlying object
	#	%ref_name_uc%'		- same as %ref_name%, but in uppercase
	#	%ref_name_lc%'		- same as %ref_name%, but in lowercase
	#	%ref_name_no_us%'	- same as %ref_name%, with underscores replaced with spaces
	#	%ref_name_no_pre%'	- same as %ref_name%, minus everything until the first underscore
	#	%ref_name_no_suf%'	- same as %ref_name%, minus everything from the last underscore on
	#
	# See "%name%" in the examples below.
	#
	# Later occurences of "DEFAULTS" declarations replace earlier ones, unless defaults_action=>update is specified, in
	# which case new options replace any prior ones, but unset option defaults retain their prior value.
	# If a default option is declared as the keyword %NONE% in an update operation, the associated default is deleted.
	#
	# Finally, the DEFAULT declaration also supports an "defaults_action" optional parameter that provides commands
	# directly to the DEFAULT processor. Any of the following commands may be supplied, separated by |:
	#        'reset'	=> Wipe any existing defaults before applying new defaults
	#        'display'	=> Print out the resulting defaults after applying any new defaults.
	# Examples of DEFAULTS:
	#  - Without DEFAULTS
	#     SOMEITEMTYPE,	name,		    groups, broker, type,	topic_pattern,			discoverable    [Area:]Friendly Name
	      SOMEITEMTYPE,	tas_outdoor_plug,   group1, mqtt_1, switch,	tasmota_outdoor_plug/+/+,	0		Outdoor Plug
	      SOMEITEMTYPE,	tas_porch_switch,   group1, mqtt_1, switch,	tasmota_porch_switch/+/+,	0		Porch Switch
	      SOMEITEMTYPE,	tas_kitchen_switch, group1, mqtt_1, switch,	tasmota_kitchen_switch/+/+,	0
	      SOMEITEMTYPE,	zooz_sensor1,	    group1, mqtt_1, sensor,	zooz_sensor1/+/+,		0
	      SOMEITEMTYPE,	zooz_sensor2,	    group1, mqtt_1, sensor,	zooz_sensor1/+/+,		0
	#  - With DEFAULTS
	      SOMEITEMTYPE,	DEFAULTS,	    group1, mqtt_1, switch,	%name%/+/+,			0
	      SOMEITEMTYPE,	tas_outdoor_plug, friendly_name => Outdoor Plug
	      SOMEITEMTYPE,	tas_porch_switch, friendly_name => Porch Switch
	      SOMEITEMTYPE,	tas_kitchen_switch
	      SOMEITEMTYPE,	DEFAULTS,		  type=>sensor, defaults_action=>update
	      SOMEITEMTYPE,	zooz_sensor1
	      SOMEITEMTYPE,	zooz_sensor2

        ##########################################################################################################


    =head2 INHERITS
    
    B<NONE>
    
    =head2 METHODS
    
    =over

=cut

use strict;

package parm_parser;

use Scalar::Util qw(looks_like_number);

sub error {
    my ($self, $str) = @_;
    my $errstr = '';

    if( $self->{context}->{filename} ) {
	$errstr .= "Error at $self->{context}->{filename} ";
	if( $self->{context}->{line_number} ) {
	    $errstr .= "line $self->{context}->{line_number} ";
	}
    }
    if( $self->{objname} ) {
	$errstr .= "for object $self->{objname} ";
    } else {
	$errstr .= "for object of type $self->{itemtype} ";
    }
    $errstr .= ": $str -- object not created";
    &main::print_log( "[PARMS ERROR]: $errstr" );
}

sub debug {
    my ($self, $level, $str) = @_;
    if( $level == 0  ||  (defined $main::Debug{parm_parser}  &&  $level <= $main::Debug{parm_parser} ) ) {
        &main::print_log( "[PARMS]: $str" );
    }
}

sub new {    # parm_parser
    my($class, $itemtype, $positional_parms_rta, $positional_parms_new, $optional_parms, $supports_defaults ) = @_;

    $supports_defaults //= 0;
    if( $supports_defaults ) {
	push @$optional_parms, 'defaults_action';
    }

    my $self = {};
    $self->{itemtype} = $itemtype;
    $self->{positional_parms_rta} = $positional_parms_rta;
    $self->{positional_parms_new} = $positional_parms_new;
    if( !$positional_parms_rta ) {
	$self->{positional_parms_rta} = $positional_parms_new;
    }
    $self->{optional_parms} = $optional_parms;
    $self->{all_parms} = [ @{$self->{positional_parms_rta}}, @{$self->{optional_parms}} ];
    $self->{defaults} = {};
    $self->{supports_defaults} = $supports_defaults;

    bless $self, $class;

    return $self;
}

sub parse_parms {
    my($self, $context, $args ) = @_;
    my $errstr;

    $self->{context} = $context;
    $self->{parms} = {};
    $self->{setting_defaults} = 0;

    $self->{objname} = $self->get_table_parm( $args, 'name', 1 );

    if( $self->{context}->{caller} eq 'rta' ) {
	$self->{positional_parms} = $self->{positional_parms_rta};
    } elsif( $self->{context}->{caller} eq 'new' ) {
	$self->{positional_parms} = $self->{positional_parms_new};
    } else {
	$self->error( "Invalid context caller '$self->{context}->{caller}' for parse_parms2" );
	return undef;
    }

    return undef if $self->process_args( $args );

    if( $self->{context}->{caller} eq 'rta' ) {
	# See if they're setting or updating default values
	return if $self->manage_defaults();
	return undef if $self->{setting_defaults};

	# Substitute values for variables if necessary.
	my $AdditionalSubs = {};
	return if $self->substitute_variables( $AdditionalSubs );
    }

    return if $self->check_parm_types();

    return $self->{parms};
}

#---------------------------------------------------------------------------
# This function finds the named parm in the @item_info list.
# It could be at the fixed position provided by the $position parameter (1 origin)
# or it could be a keyword parm.

sub get_table_parm{
    my ($self, $parmslist, $parmname, $position) = @_;
    my $keyword;
    my $value;
    my $quote;
    my $retval;
    my $i;

    if( defined $position  &&  $position <= scalar @{$parmslist}  &&  !($parmslist->[$position-1] =~ /^\s*[\'\"]?\s*[A-Za-z0-9_\-]+\s*=>/) ) {
	$retval = $parmslist->[$position-1];
    } else {
	for( $i=0; $i < scalar @{$parmslist}; ++$i ) {
	    ($quote,$keyword,$value) = $parmslist->[$i] =~ /^\s*([\'\"]?)\s*([A-Za-z0-9_\-]+)\s*=>\s*(.*)[\'\"]?\s*$/;
	    $value = $quote . $value;
	    if( $keyword eq $parmname ) {
		if( $quote ) {
		    # value string is quoted, so eval it to process the string quotes and any escapes
		    eval( "\$value = $value;" );
		    if( $@ ) {
			&parse_parms_debug( 0, "Error evaling parm $parmname value -- $@" );
		    }
		}
		$retval = $value;
		last;
	    }
	}
    }
    return $retval;
}



sub process_args {
    my($self, $args ) = @_;
    my $positional_count = scalar @{$self->{positional_parms}};
    my $parmstr;
    my $retval = 0;

    $parmstr = join ',',@{$args};
    $self->debug( 1, "Parsing parms:  $parmstr" );
    $self->debug( 1, "   Keywords_list:  " . join ',',@{$self->{all_parms}} );
    for( my $i=0; ; ++$i ) {
	my $parm;
	my $keyword;
	my $value;
	my $type;

	if( $i == scalar @{$args} ) {
	    last;
	}
	$parm = $args->[$i];

	# Process quoted string
	if( !ref $parm  &&  $parm =~ /^\s*[\'\"]/ ) {
	    eval( "\$parm = $parm;" );
	    if( $@ ) {
		$self->error( "error evaling parm value '$parm'" );
		next;
	    }
	}

	# Check each format, because initially read_table_A quotes, and later it doesn't.
	if( !$parm ) {
	    next;
	}
	($keyword,$value) = $parm =~ m/^\s*([^=\{\"\,\s]+)\s*=>\s*(.*)\s*$/;
	if( !$keyword ) {
	    if( $i >= $positional_count ) {
		$self->error( "too many positional parameters at parm '$parm'" );
		next;
	    }
	    ($keyword, $type) = split( /:/, $self->{positional_parms}->[$i] );
	    $value = $parm;
	    if( $type eq 'options' ) {
		my @option_list = split( '\|', $value );
		my $delay;
		foreach my $option (@option_list) {
		    if ($option =~ /=/) {
			($keyword,$value) = split(/\s*=\s*/,$option,2);
		    } else {
			$keyword = $option;
			$value = 1;
		    }
		    $retval |= $self->set_parm_value( $keyword, $value );
		}
		$keyword = undef;
	    }
	}
	if( $keyword ) {
	    $retval |= $self->set_parm_value( $keyword, $value );
	}
    }
    $self->debug( 2, "   Parsed table parms into:  " .  &main::parms_to_str( $self->{parms} ) );
    return $retval;
}

sub set_parm_value {
    my ($self, $keyword, $value ) = @_;
    my $type;
    my $key;
    my $keytype;

    foreach my $k ( @{$self->{all_parms}} ) {
	($key,$keytype) = split( /:/, $k );
        if( $key eq $keyword ) {
	    $type = $keytype || 'string';
	    last;
	}
    }
    if( !$type ) {
	$self->error( "unknown parameter '$keyword'" );
	return 1;
    }
    $type = lc( $type );

    $self->debug( 1, "   Setting parm '$keyword' to '$value' -- type: $type" );

    if( !ref $value ) {
	$value =~ s/\s*$//;
    }
    $self->{parms}->{$keyword} = $value;
    return 0;
}

sub check_parm_types {
    my ($self ) = @_;
    my $type;
    my $key;
    my $retval = 0;

    foreach my $k ( @{$self->{all_parms}} ) {
	($key,$type) = split( /:/, $k );
        $type ||= 'string';
	$type = lc( $type );
        if( $type eq 'objref' ) {
	    # do not process object refs in read_table_A
	    if( $self->{context}->{caller} eq 'new'  &&  $self->{parms}->{$key}  &&  ! ref $self->{parms}->{$key} ) {
		my $obj;
		my $objname = "\$main::$self->{parms}->{$key}";
		eval "\$obj = $objname";
		if( !$obj ) {
		    $self->error( "unable to find object '$self->{parms}->{$key}' for parameter '$key'" );
		    $retval = 1;
		}
		$self->{parms}->{$key} = $obj;
	    }
	} elsif( $type eq 'number' ) {
	    if( $self->{parms}->{$key}  &&  !looks_like_number( $self->{parms}->{$key} ) ) {
		$self->error( "'$key' parameter is not a number" );
		$retval = 1;
	    }
	} elsif( $type eq 'options' ) {
	} elsif( $type eq 'json' ) {
	} elsif( $type eq 'string' ) {
	} else {
	    $self->error( "'$key' parameter has unknown type '$type'" );
	    $retval = 1;
	}
    }
    return $retval;
}

#
# manage_defaults
#
sub manage_defaults {
    my($self) = @_;
    my $parms = $self->{parms};
    my $retval = 0;

    if( $self->{context}->{filename} ne $self->{defaults_filename} ) {
	# now processing a different file from when the defaults were set -- wipe them out
	$self->debug( 1, "mht file changed from '$self->{defaults_filename}' to '$self->{context}->{filename}' -- reseting defaults for $self->{itemtype}" );
	$self->{defaults} = {};
	$self->{defaults_filename} = $self->{context}->{filename};
    }
    if ($parms->{name} and $parms->{name} =~ /^DEFAULTS?$/) {
	$self->{setting_defaults} = 1;
	# The user is setting/updating the default values.
	if( !$self->{supports_defaults} ) {
	    $self->error( "setting up defaults but defaults not supported by item type $self->{itemtype}" );
	    return 1;
	}

	#  Set up actions hash.
	my %Actions = map { $_ => 1 } split('\|',$parms->{defaults_action});
	delete $parms->{defaults_action};

	#  Process the delete action if requested.
	$Actions{reset} = 1 unless $Actions{update};	# Reset is the default.
	if ($Actions{reset}) {
	    # They want a fresh start.
	    $self->{defaults} = {};
	    delete $Actions{reset};
	}
	delete $Actions{update};

	delete $parms->{name};			# Don't make DEFAULT or DEFAULTS the default name.

	#  Set new defaults.
	foreach my $key (keys %$parms ) {
	    if( $parms->{$key} eq '%NONE%' ) {
		delete $self->{defaults}->{$key};
	    } elsif( $parms->{$key} ) {
		$self->{defaults}->{$key} = $parms->{$key};
	    }
	}

	#  Process the display action if requested.
	if( $Actions{display}  ||   $main::Debug{parm_parser} ) {
	    # They want us to document the (now) current defaults.
	    $self->debug( 0, "Displaying current defaults for $self->{itemtype}: ");
	    if( (%{$self->{defaults}}) ) {
		foreach (sort(keys %{$self->{defaults}})) {
		    $self->debug( 0, sprintf("   default key => value: %-16s => %s",$_, $self->{defaults}->{$_}));
		}
	    }
	    else {
	    	$self->debug( 0, sprintf("   No defaults set.",$_, $self->{defaults}->{$_}));
	    }
	    delete $Actions{display};
	    $self->debug(0, "Invalid action(s) passed in $self->{itemtype} DEFAULTS definition: " . join(', ', sort(keys %Actions )))
		if %Actions;
	}

	delete $self->{parms};
    } else {
	# Ordinary definition. See if any of the parms need a default value set.
	foreach my $key (keys %{$self->{defaults}}) {
	    next if ($parms->{$key} || $parms->{$key} =~ /^[+-]?0(\.0*)?$/);	# Skip any set values, including set to 0.
	    next if ($key eq 'name');						# We never change the name parm. Should never happen.
	    # Parm is unassigned. Assign the default.
	    # It's OK if the the default is also unassigned. Maybe that's what they want. We're not one to judge. ;-)
	    $parms->{$key} = $self->{defaults}->{$key};
	}
    }
    return $retval;
}

#
# Examine parms and replace embedded variables with their values.
#
sub substitute_variables {
    my ($self,$AdditionalSubs) = @_;
    my $retval = 0;

    $AdditionalSubs //= {};			# Just in case they didn't supply a ref to even an empty hash.

    # Check for variable substitutions in parms (e.g. set friendly_name based on the name, set the topic based on the name and/or type).
    # Note this is independent of %Defaults. They don't have to use a default to use a substitution variable.
    #
    #   1. Build a table of substitution variable names and their associated values.
    my %Subs = ( %$AdditionalSubs );

    my $parms = $self->{parms};
    if( $parms->{name} ) {
	%Subs = (
	    %Subs,
	    '%name%'		=> $parms->{name},			# The name
	    '%name_uc%'		=> uc($parms->{name}),			# The name in uppercase
	    '%name_lc%'		=> lc($parms->{name}),			# The name in lowercase
	    '%name_no_us%'	=> ($parms->{name} =~ s/_/ /gr),	# The name with _ replaced by spaces
	    '%name_no_pre%'	=> ($parms->{name} =~ s/^[^_]*_//r),	# The name with prefix up thru first _ removed
	    '%name_no_suf%'	=> ($parms->{name} =~ s/_[^_]*$//r),	# The name with last _ and rest removed.
	);
    }
    if( $parms->{type} ) {
	%Subs = (
	    %Subs,
	    '%type%'		=> $parms->{type},			# The type, maybe for topic names (?)
	    '%type_uc%'		=> uc($parms->{type}),			# The type in uppercase
	    '%type_lc%'		=> lc($parms->{type}),			# The type in lowercase
	);
    }
    if( $parms->{ref_item_name}  &&  !($parms->{ref_item_name} =~ /%/) ) {
	# Not built from a var, so append new substitution keys built from it. "Append" in case
	# there's a future need to always add some subs outside this "unless" conditional.
	# "Additional", because Substitute_Variables has a fixed set it always uses, but we might want more.
	%Subs = (
	    %Subs,						# Keep old values, and append additional ones.
	    '%ref_name%'	=>	$parms->{ref_item_name},
	    '%ref_name_uc%'	=>	uc($parms->{ref_item_name}),
	    '%ref_name_lc%'	=>	lc($parms->{ref_item_name}),
	    '%ref_name_no_us%'	=>	($parms->{ref_item_name} =~ s/_/ /gr),
	    '%ref_name_no_pre%'	=>	($parms->{ref_item_name} =~ s/^.*?_//r),
	    '%ref_name_no_suf%'	=>	($parms->{ref_item_name} =~ s/_.*?$//r),
	);
    }

    #   2. Loop through the parms. If they have substitution variables, replace those with their values.
    foreach my $key (sort(keys %$parms )) {
	next if ($key eq 'name');		# No editing the name.
	next unless ($parms->{$key} =~ /%/);	# No variables, so no vars.
	# Replace any vars with their values.
	foreach my $var (keys %Subs) {
	    next unless ($parms->{$key} =~ /$var/);
	    $parms->{$key} =~ s/$var/$Subs{$var}/g;
	}
    }
    return $retval;
}


#---------------------------------------------------------------------------
# Some main package scoped helper functions

package main;

#---------------------------------------------------------------------------
#   Helper function for printing parms debug messages from package main::
#

sub parse_parms_debug {
    my ($level, $str) = @_;
    &parm_parser::debug( undef, $level, $str );
}


#---------------------------------------------------------------------------
#   Routine to convert a parms hash to a string
#
sub parms_to_str {
    my ($parms) = @_;
    my $str = '';
    for my $parm ( keys %$parms ) {
	if( $str ) {
	    $str .= ', ';
	}
	my $value = $parms->{$parm};
	$value =~ s/\'/\\'/g;
	$str .= "'${parm} => $value'";
    }
    return $str;
}

#--------------------------------------------------------------------------------------------
# A state based string scanner that splits a table row -- mostly on commas ','.
# It can scan a JSON parameter value and will find the end of it, even with embedded commas.
# It supports quoting of a value using backticks:
#       ITEM, name, `value`
#       ITEM, name, parm=>`value`

sub split_table_string {
    my ($str) = @_;
    my $parms = [];
    my $start_pos = 0;
    my $scan_state;
    my $prev_state;
    my $keywordstr;
    my $keyword_startpos;
    my $in_json_string;
    my $in_json_comment;
    my $json_escaped;
    my $json_depth;
    my $string_quote;
    my $string_escaped;
    my $strlen = length( $str );
    my $parmstr;
    # Scanner states
	my $NORMAL = 0;
	my $START_PARM = 1;
	my $KEYWORD_SEEN = 2;
	my $START_VALUE = 3;
	my $IN_COMMENT = 4;
	my $IN_STRING = 5;
	my $IN_JSON = 6;
	my $DONE = 7;

    &parse_parms_debug( 2, "Splitting table string <<$str>>" );

    # change newlines to carriage return so single char processing is easier
    $str =~ s/\n/\r/g;

    $scan_state = $START_PARM;
    # Iterate through the string character by character starting from the first {
    for (my $i = 0; ; $i++) {
        my $char = substr($str, $i, 1);

	if( $i == $strlen ) {
	    $scan_state = $DONE;
	}
	&parse_parms_debug( 5, "scanner processing char >$char< in state $scan_state" );
	if( $scan_state == $IN_JSON ) {
	    if( $in_json_comment ) {                              # handle comments in JSON to carriage return
		substr( $str, $i, 1, ' ' );
		if( $char eq "\r" ) {
		    $in_json_comment = 0;
		}
		next;
	    }
	    if( !$in_json_string  &&  $char eq '#' ) {
		substr( $str, $i, 1, ' ' );
		$in_json_comment = 1;
		next;
	    }
	    if( $char eq "\r" ) {
		substr( $str, $i, 1, ' ' );
		next;
	    }
	    if( $json_escaped ) {
		$json_escaped = 0;
		next;
	    }
	    if( $in_json_string  &&  $char eq '\\' ) {
		$json_escaped = 1;
		next;
	    }
	    if( $char eq '"') {
		$in_json_string = !$in_json_string;
		next;
	    }
	    if( !$in_json_string) {
		if ($char eq '{') {
		    $json_depth++;
		} elsif ($char eq '}') {
		    $json_depth--;
		    if ($json_depth < 0) {
			$scan_state = $NORMAL;
		    }
		}
		next;
	    }
	    next;
	} elsif( $scan_state == $IN_STRING ) {
	    if( $char eq "\r" ) {
		substr( $str, $i, 1, ' ' );
		next;
	    }
	    if( $string_escaped ) {
		$string_escaped = 0;
		next;
	    }
	    if( $char eq '\\' ) {
		$string_escaped = 1;
		next;
	    }
	    if( $char eq $string_quote ) {
		$scan_state = $NORMAL;
	    }
	    next;
	} elsif( $scan_state == $IN_COMMENT ) {
	    if( $char eq "\r" ) {
		$scan_state = $prev_state;
	    }
	    substr( $str, $i, 1, ' ' );
	    next;
	}
	if( $char eq '#' ) {
	    substr( $str, $i, 1, ' ' );
	    $prev_state = $scan_state;
	    $scan_state = $IN_COMMENT;
	    next;
	}
	if( $char eq "\r" ) {
	    substr( $str, $i, 1, ' ' );
	    next;
	}
	if( $char =~ /[ \t]/ ) {
	    next;
	}
	if( $char eq ',' ||  $scan_state == $DONE ) {
	    $parmstr = substr( $str, $start_pos, $i-$start_pos );
	    &parse_parms_debug( 5, "processing comma '$char' -- parmstr <<$parmstr>>" );
	    $parmstr =~ s/^\s*//;
	    $parmstr =~ s/\s*$//;
	    if( $parmstr  ||  $scan_state != $DONE ) {                # don't create parm from blanks after last comma
		push @{$parms}, $parmstr;
	    }
	    if( $i == $strlen ) {
		last;
	    }
	    $start_pos = $i + 1;
	    $scan_state = $START_PARM;
	    next;
	}

	# by this point, we have skipped white space and we are not inside a comment, string or JSON object
	if( $scan_state == $START_PARM ) {
	    ## Skip over possible keyword as in keyword =>
	    my $rest = substr( $str, $i );
            ($keywordstr) = $rest =~/^([a-zA-Z0-9\_\-]+)/;
	    if( $keywordstr ) {
		$keyword_startpos = $i;
		$i += length( $keywordstr ) - 1;
		$scan_state = $KEYWORD_SEEN;
		next;
	    } else {
		$scan_state = $START_VALUE;
	    }
	}
	if( $scan_state == $KEYWORD_SEEN ) {
	    ## Skip over '=>'
	    if( substr( $str, $i, 2 ) eq '=>' ) {
		$i += 1;
		$scan_state = $START_VALUE;
		next;
	    } else {
		$scan_state = $NORMAL;
		$keywordstr = '';
	    }
	}
	if( $scan_state == $START_VALUE ) {
	    if( $char eq '{' ) {
		$scan_state = $IN_JSON;
		$in_json_string = 0;
		$in_json_comment = 0;
		$json_depth = 0;
		$json_escaped = 0;
		next;
	    }
	    if( $char eq "'" or $char eq '"' ) {
		$scan_state = $IN_STRING;
		$string_quote = $char;
		$string_escaped = 0;
		## This is kind of gross, but works
		## We are going to move the quote to before the 'keyword =>' if there was one
		if( $keywordstr ) {
		    substr( $str, $keyword_startpos, $i-$keyword_startpos+1, $string_quote . substr( $str, $keyword_startpos, $i-$keyword_startpos) );
		}
		next;
	    }
	    $scan_state = $NORMAL;
	    next;
	}
	next;
    }
    parse_parms_debug( 2, "Split table string returning: " . join ",\n",map {">$_<"} @{$parms} );
    return (@$parms);
}

sub quote_list_data {
    my @list = map {
	# Check if it already starts and ends with quotes (single or double)
	if (/^(['"]).*\g{1}$/) {
	    $_;
	} else {
	    my $val = $_;
	    $val =~ s/\\/\\\\/g;  # Escape backslashes first
	    $val =~ s/'/\\'/g;   # Escape single quotes
	    "'$val'";            # Surround with single quotes
	}
    } @_;
    my $str = join ', ', @list;
    return $str;
}

sub make_parm_string {
    my ($parms) = @_;
    my $str = '';
    my $key;
    my $val;

    for $key (keys %$parms) {
	# Check if it already starts and ends with quotes (single or double)
	$val = $parms->{$key};
	$str .= ', ' if $str;
	if( $val =~ (/^(['"])/) ){
	    $str .= $val;
	} else {
	    $val =~ s/\\/\\\\/g; # Escape backslashes first
	    $val =~ s/'/\\'/g;   # Escape single quotes
	    $str .= "'$key => $val'";
	}
    };
    return $str;
}

#---------------------------------------------------------------------------
# This function finds the named parm in the @item_info list.
# It could be at the fixed position provided by the $position parameter (1 origin)
# or it could be a keyword parm.
# The callers list is **MODIFIED** by removing the named parm.

sub get_table_parm{
    my ($parmslist, $parmname, $position) = @_;
    my $keyword;
    my $value;
    my $quote;
    my $retval;
    my $i;

    if( defined $position  &&  $position <= scalar @{$parmslist}  &&  !($parmslist->[$position-1] =~ /^\s*[\'\"]?\s*[A-Za-z0-9_\-]+\s*=>/) ) {
	$retval = $parmslist->[$position-1];
	splice( @{$parmslist}, $position-1, 1 );
    } else {
	for( $i=0; $i < scalar @{$parmslist}; ++$i ) {
	    ($quote,$keyword,$value) = $parmslist->[$i] =~ /^\s*([\'\"]?)\s*([A-Za-z0-9_\-]+)\s*=>\s*(.*)[\'\"]?\s*$/;
	    $value = $quote . $value;
	    if( $keyword eq $parmname ) {
		if( $quote ) {
		    # value string is quoted, so eval it to process the string quotes and any escapes
		    eval( "\$value = $value;" );
		    if( $@ ) {
			&parse_parms_debug( 0, "Error evaling parm $parmname value -- $@" );
		    }
		}
		$retval = $value;
		splice( @{$parmslist}, $i, 1 );
		last;
	    }
	}
    }
    return $retval;
}


#------------------------------------------------------------------------

1;

