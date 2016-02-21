##################################################
##  This is a WIP (12/2003) version of the xml parser.
##  File:  read_table_xml.pl
##
##  Description:
##      XML parser to (hopefully) replace the read_table_A.pl
##      This code should remain as independent as possible from the
##      behavior of the objects.  Ideally, all object specific personality
##      should be defined inside the module that implements the module.
##
##
##  License:
##  This free software is licensed under the terms of the GNU public license.
##  Copyright 2003 Chris Witte  (Original author unknown).
##
##
##
##  Concerns that s/b addressed before it is released:
##   1) STILL NEED COMPOOL mht files!!!  (Is anyone using COMPOOL?)
##   2) should objects be allowed to have an "other" tag?
##      it might be more meaningful in the future if the tag
##      was more descriptive of the data for the object in question.
##      (we'll need smarter constructors before doing this, or this
##      initialization code will bloat).
##
##DONE) should the floorplan coordinates be converted from table_A
##      directly as part of the group data, or should they be broken out
##      as a separate attribute or as their own tag?
##      12/2003: generated separate attributes for these.
##
##DONE) PA objects still unconverted.  Received an 11th hour submission
##      from Steve S. that can be used to convert the PA objects.
##      12/2003:
##      (PA support is coded, appears to generate clean code. needs testing.)
##
##DONE) Neil Wrightson submitted an mht file for ibutton testing that generates
##      invalid perl (nested single quotes).  Sent separate message to the list
##      to attempt to resolve this. (11/21 msg subject: progress update)
##      12/2003:
##      (No follow up from Neil, but modified code to prevent redundant quotes)
##
##DONE) current conversion/install approach is to leave the *.mht files,
##      generate *.xml files (tagged with request to modify original mht file)
##      and ONLY process the xml files.  If anyone has trouble with this, they
##      will have to un-install these mods (aka, downgrade to prior version).
##      Is this OK with the core support team/approach?
##      12/2003:
##      (Bruce kindly added the necessary config code to bin/mh).
##
##DONE) The current *.xml file is not fully xml compliant.  (still has a
##      "format=" tag at the top of it in non-xml format.)  I would propose that
##      we completely decommission the format A file layout, and process ONLY
##      *.xml files.  If we can agree on that, we s/b able to purge the Format=
##      code.
##      12/2003:
##      (The generated .xml files use the config value instead of the Format=
##      tag to drive processing).
##
##DONE) Groups are now specified using multiple tags in the xml.
##################################################
use strict;
use Carp;
use XML::Twig;
use Time::HiRes;

#these two items could go into the ini file
#set to 1 to create generic items from unknown types
my $createunknown = 1;

#set to 1 to create groups even when they have the same name as items by suffixing _group
my $smartgroupfix = 0;   ###11/2003 cwitte dflt to zero. (table_A compatability)
my $twig_code_accum;

#set up the item types
#I missed the compool(?), as I couldn't see an example anywhere
my %itemtype;

# Insteon Items
$itemtype{"X10I"}  = { object => "X10_Item" };
$itemtype{"X10A"}  = { object => "X10_Appliance" };
$itemtype{"X10O"}  = { object => "X10_Ote" };
$itemtype{"X10SL"} = { object => "X10_Switchlinc" };
$itemtype{"X10G"}  = { object => "X10_Garage_Door" };
$itemtype{"X10MS"} = { object => "X10_Sensor", use_name => 1 };
$itemtype{"X10S"}  = { object => "X10_IrrigationController", use_other => 0 };
$itemtype{"X10T"}  = { object => "RCS_Item", use_other => 1 };
$itemtype{"X10TR"} = { object => "X10_Transmitter" };
$itemtype{"RF"} = {
    object    => "RF_Item",
    use_name  => 1,
    min_comma => 2
};
$itemtype{"COMPOOL"} = {
    object   => "COMPOOL_HAS_OPEN_ISSUES_UNCONVERTED",
    use_name => 1
};
$itemtype{"IBUTTON"}       = { object => "iButton" };
$itemtype{"SERIAL"}        = { object => "Serial_Item" };
$itemtype{"STARGATEDIN"}   = { object => "StargateDigitalInput" };
$itemtype{"STARGATEVAR"}   = { object => "StargateVariable" };
$itemtype{"STARGATEFLAG"}  = { object => "StargateFlag" };
$itemtype{"STARGATERELAY"} = { object => "StargateRelay" };
$itemtype{"STARGATETHERM"} = { object => "StargateThermostat" };
$itemtype{"STARGATEPHONE"} = { object => "StargateTelephone" };
$itemtype{"STARGATEIR"}    = { object => "StargateIR" };
$itemtype{"STARGATEASCII"} = { object => "StargateASCII" };
$itemtype{"SG485LCD"}      = { object => "StargateLCDKeypad" };
$itemtype{"SG485RCSTHRM"}  = { object => "StargateRCSThermostat" };
$itemtype{"XANTECH"}       = { object => "Xantech_Zone" };
$itemtype{"MP3PLAYER"}     = {
    object    => "Mp3Player",
    use_other => 0,
    init      => "require 'Mp3Player.pm';\n"
};
$itemtype{"AUDIOTRON"} = { object => "AudiotronPlayer", use_other => 0 };
$itemtype{"WEATHER"}   = { object => "Weather_Item",    use_other => 0 };
$itemtype{"GENERIC"} =
  { object => "Generic_Item", use_addr => 0, use_other => 0 };
$itemtype{"WAKEONLAN"} = {
    object => "WakeOnLan",
    "init" => "require 'WakeOnLan.pm';\n"
};
$itemtype{"YACCLIENT"} = {
    object => "CID_Server_YAC",
    "init" => "require 'CID_Server.pm';\n"
};
$itemtype{"ZONE"} = { object => "Sensor_Zone" };

$itemtype{"LIGHT"} = {
    object     => "Light_Item",
    "use_addr" => "obj_ref",
    "init"     => "require 'Light_Item.pm';\n"
};
$itemtype{"DOOR"} = {
    object     => "Door_Item",
    "use_addr" => "obj_ref",
    "init"     => "require 'Door_Item.pm';\n"
};
$itemtype{"MOTION"} = {
    object     => "Motion_Item",
    "use_addr" => "obj_ref",
    "init"     => "require 'Motion_Item.pm';\n"
};
$itemtype{"PHOTOCELL"} = {
    object     => "Photocell_Item",
    "use_addr" => "obj_ref",
    "init"     => "require 'Photocell_Item.pm';\n"
};
### not implemented, missing Temperature_Item.pm cwitte 11/2003
#$itemtype{"TEMP"} = {object=>"Temperature_Item",
#			"use_addr"=>"obj_ref",
#		   "init"=> "require 'Temperature_Item.pm';\n"};
### not implemented, missing Camera_Item.pm cwitte 11/2003
#$itemtype{"CAMERA"} = {object=>"Camera_Item",
#			"use_addr"=>"obj_ref",
#		   "init"=> "require 'Camera_Item.pm';\n"};
$itemtype{"OCCUPANCY"} = {
    object                 => "Occupancy_Monitor",
    "use_addr"             => 0,
    "trailing_space_count" => 1,
    "init"                 => "require 'Occupancy_Monitor.pm';\n"
};
$itemtype{"PRESENCE"} = {
    object                 => "Presence_Monitor",
    "use_addr"             => "obj_ref",
    "use_occupancy"        => "obj_ref",
    "use_name"             => 0,
    "trailing_space_count" => 0,
    min_comma              => 2,
    "init"                 => "require 'Presence_Monitor.pm';\n"
};

## a couple of these match multiple entries, so we'll initialize them here.
while ( my ( $key, $hash ) = each %itemtype ) {
    if ( uc($key) =~ /STARGATE/ ) {
        $hash->{"init"} .= "require 'Stargate.pm';\n";
    }
    if ( uc($key) =~ /SG485/ ) {
        $hash->{"init"} .= "require 'Stargate485.pm';\n";
    }
    if ( uc($key) =~ /XANTECH/ ) {
        $hash->{"init"} .= "require 'Xantech.pm';\n";
    }
    if ( uc($key) =~ /X10T/ ) {
        $hash->{"init"} .= "require 'RCS_Item.pm';\n";
    }
    if ( uc($key) =~ /^AUDIOTRON/ ) {
        $hash->{"init"} .= "require 'AudiotronPlayer.pm';\n";
    }
    if ( uc($key) eq "ZONE" ) {
        $hash->{"init"} .= "use caddx;\n";
    }
    if ( !defined $hash->{"use_other"} ) {    ## default is use_other allowed
        $hash->{"use_other"} = 1;
    }
    if ( !defined $hash->{"use_addr"} ) {     ## default is use_addr allowed
        $hash->{"use_addr"} = 1;
    }

    if ( uc($key) =~ /IPLC/ ) {

        # $hash->{"init"}.= "require 'IPLC.pm';\n";
    }
    if ( uc($key) =~ /INSTEON/ ) {

        #  $hash->{"init"}.= "require 'Insteon.pm';\n";
    }

    ## syntactical obfuscation to simplify comparison of pre/post xml
    ##   generated code.
    if (   $key eq "X10I"
        || $key eq "X10A"
        || $key eq "SERIAL"
        || $key eq "IBUTTON"
        || $key eq "X10SL"
        || $key eq "LIGHT"
        || $key eq "DOOR"
        || $key eq "MOTION"
        || $key eq "PHOTOCELL"
        || $key eq "TEMP"
        || $key eq "CAMERA"
        || uc $key =~ /^X10/
        || uc $key =~ /^IPLC/
        || uc $key =~ /^STARGATE/ )
    {
        $hash->{"min_comma"} = 1;
    }
}
my ( %groups, %objects, %packages );

#############################
##  Initialization/reset code  (called by bin/mh)
##
#############################
sub read_table_init_xml {

    # reset known groups
    print_log "Initialized read_table_xml.pl";
    print "Initialized read_table_xml.pl";
    %groups   = ();
    %objects  = ();
    %packages = ();
}

#############################
##  Main parse code (called by bin/mh)
##
#############################
sub read_table_xml {
    print "read_table_xml: begin \n";
    my $data = $_[0]; #perl complains about trying to fiddle directly with @_[0]
    if ( !$data ) { print "No data in sub read_table_xml"; next; }

    #do some mying
    my ( $code, $name, $object );

    $data =~ s/\s*(<items>.*<\/items>)\s*/$1/;    #some basic cleaning

    my $start_time = Time::HiRes::time();
    print "establishing twig exit: \n";
    $twig_code_accum = "";
    my $twig =
      XML::Twig->new( twig_handlers => { item => \&construct_object } );
    $twig->parse($data);
    print "twig parsed: $twig $data\n";
    my $twig_end = Time::HiRes::time();

    my $t3_time    = Time::HiRes::time();
    my $twig_time  = $twig_end - $start_time;
    my $path_time  = $t3_time - $twig_end;
    my $total_time = $t3_time - $start_time;
    printf "TIME: twig: %6.2f path: %6.2f total: %6.2f\n", $twig_time,
      $path_time, $total_time;

    &summarize_usage();    ## code to display conversion test effectiveness

    return $twig_code_accum;

}
#############################
##  Usage summary: provide effectiveness stats during conversion from
##    table_A.  should be deleted soon...
#############################
sub summarize_usage {
    while ( my ( $key, $hash ) = each %itemtype ) {
        print "usage: [$key] :: ", $hash->{use_count}, "\n";
    }
}

#############################
##  consolidate text from peer children with a common name into an
##    anonymous array.
#############################
sub build_twig_text_array {
    my ( $twig_item, $gi_lit ) = @_;
    my @gi_twigs = $twig_item->children($gi_lit);
    my @gi_text;
    foreach my $gi_twig (@gi_twigs) {
        push( @gi_text, $gi_twig->text );
    }
    \@gi_text;
}
#############################
##  Twig process handler invoked when an <item> tag is found.
##      this is the workhorse of the module that generates the code.
##
#############################
sub construct_object {
    my ( $twig, $item ) = @_;

    my $debug = 0;

    my $x_address = $item->first_child_text("address");   # get the address text
    my $x_name    = $item->first_child_text("name");      # get the name text
    my $x_type    = $item->first_child_text("type");      # get the type text
    my $x_occupancy = $item->first_child_text("occupancy");
    my $x_object    = $item->first_child_text("object");
    $debug && print "construct_object: $item has address: $x_address\n";
    $debug && print "construct_object: $item has name: $x_name\n";
    $debug && print "construct_object: $item has type: $x_type\n";

    ##my $x_group_array=build_twig_text_array($item,"group");
    my $x_other_array = build_twig_text_array( $item, "other" );

    my $object;
    my $code;

    ## PRESENCE uses a tag called object.  Positionally, it is equivalent
    ##  to address, so we'll equate them here.... (b4 quotes are added)
    ##  (hopefully we can junk the positional constructors at some point...)
    $x_address = $x_object unless $x_address;

    ### create single quoted versions of some of the data...
    foreach my $tag_element ( @{$x_other_array} ) {
        $tag_element = force_single_quotes($tag_element);
    }
    my $q_address = force_single_quotes($x_address);
    my $q_object  = force_single_quotes($x_address);

    #unquote those that don't need it

    $x_type =~ s/'//g;
    $x_name =~ s/'//g;

    $x_type = uc($x_type);    ## we always check using upper case

    my $q_other_string = join( ", ", @{$x_other_array} );

    if ( exists $itemtype{$x_type} ) {
        my $object_hash = $itemtype{$x_type};
        $itemtype{$x_type}{use_count}++;
        print "read_xml processing: $x_name ", $q_address, "\n";

        $object = $object_hash->{"object"} . "(";
        if (
            $object_hash->{"use_addr"}    ## if address allowed for objecttype
            && $q_address
          )
        {    ## if "address" data exists, tack it on.
            if ( $object_hash->{"use_addr"} eq "obj_ref" ) {
                $object .= '$' . $x_address;    ## non-quoted
            }
            else {
                $object .= $q_address;          ## quoted
            }
        }
        if (
            $object_hash->{"use_name"}    ## rf,x10ms have address:name:other
            && $x_name
          )
        {                                 ## tack on the name, and quote it.
            $object .= ", '" . $x_name . "'";
        }
        if (
            $object_hash->{"use_occupancy"}    ## Presence monitor
            && $x_occupancy
          )
        {    ## tack on the name, and quote it.
            if ( $object_hash->{"use_occupancy"} eq "obj_ref" ) {
                $object .= ', $' . $x_occupancy;
            }
        }

        if (
            $object_hash->{"use_other"}    ## if other allowed for objecttype
            && $q_other_string
          )
        {    ## if "other" data exists, tack it on.
            $object .= ", " . $q_other_string;
        }

        ## force extra commas in the parm list to fulfill min_comma
        if ( $object_hash->{"min_comma"} ) {
            my $comma_count = $object;
            $comma_count =~ s/[^,]//g;
            my $needed = $object_hash->{"min_comma"} - length($comma_count);

            ## print "min_comma object: [$object] ctest: [$comma_count] needed: [$needed]\n";
            $object .= ", " x $needed;
        }

        ## for exact compatability with read_table_A during conversion
        if ( exists $object_hash->{"trailing_space_count"} ) {
            $object =~ s/\s+$//;
            $object .= " " x $object_hash->{"trailing_space_count"};
        }

        $object .= ")";
        if ( !$packages{$x_type}++
            && exists $object_hash->{"init"} )
        {
            my $object_init = $object_hash->{"init"};

            # print "about to eval: $object_init\n";
            eval $object_init;
            confess "can't init $x_type [$object_init]\n$@" if ($@);
        }
    }

    elsif ( $x_type eq "GROUP" ) {    ### cjw port
        $object = "Group" unless $groups{$x_name};    ## once per group
              # print "Adding empty tag for group: [$x_name]\n";
        $groups{$x_name}{empty}++;
    }
    elsif ( $x_type eq "PA" ) {    ### hard-coded groups
        if ( !$packages{$x_type}++ ) {
            $code .= "require 'PAobj.pm';\n";
        }

        my $pa_type = $item->first_child_text("pa_type");
        if ( $config_parms{pa_type} ne $pa_type ) {
            print
              "ERROR! INI parm 'pa_type' = $config_parms{pa_type}, but PA item $x_name is of $pa_type.  Skipping.\n";
            return;
        }

        print "creating allspeakers \n";
        my $group_allspeakers = XML::Twig::Elt->new( 'group', 'allspeakers' );
        print "allspeakers gave: $group_allspeakers\n";
        $group_allspeakers->paste( 'last_child', $item );    ## add to twig

        foreach my $group_twig ( $item->children("group") ) {
            my $group = $group_twig->text();
            $group = "pa_" . $group;
            $group_twig->set_text($group);
        }
        my $group_hidden = XML::Twig::Elt->new( 'group', 'hidden' );
        $group_hidden->paste( 'last_child', $item );         ## add to twig

        # AHB/ALB or DBH/DBL
        if ( $pa_type =~ /^wdio/ ) {
            $x_address =~ s/^(\S)(\S)$/$1H$2/;
            $x_address = "D$x_address" if $pa_type eq 'wdio_old';
            $code .= sprintf "\n\$%-35s = new Serial_Item('%s','on',%s);\n",
              $x_name, $x_address, $q_other_string;
            $x_address =~ s/^(\S)H(\S)$/$1L$2/;
            $code .= sprintf "\n\$%-35s -> add ('%s','off');\n", $x_name,
              $x_address;
            $object = '';
        }
        elsif ( lc $pa_type eq 'x10' ) {
            $object = "X10_Appliance($q_address,$q_other_string)";
        }
        else {
            print "\nUnrecognized .mht entry for PA:\n";
            $item->print;
        }

    }

    elsif ( $x_type =~ /^VOICE/ ) {
        my $vcommand = $q_other_string;
        $vcommand =~ s/^'(.*)'$/$1/; ## no single quotes, voice cmds are doubleq

        my $fixedname = $x_name;
        $fixedname =~ s/_/ /g;
        if ( !( $vcommand =~ /.*\[.*/ ) ) {
            $vcommand .= " [ON,OFF]";
        }
        $code .= sprintf "\nmy \$v_%s_state;\n", $x_name;
        $code .= sprintf "\$v_%s = new Voice_Cmd(\"%s\");\n", $x_name,
          $vcommand;
        $code .= sprintf "if (\$v_%s_state = said \$v_%s) {\n", $x_name,
          $x_name;
        $code .= sprintf "  set \$%s \$v_%s_state;\n", $x_name, $x_name;
        $code .= sprintf "  respond \"Turning %s \$v_%s_state\";\n",
          $fixedname, $x_name;
        $code .= sprintf "}\n";

        ##undef $object;   ## we don't want any default code, need to proceed
    }
    else {
        if ( $createunknown == 1 ) {
            print "\nUnrecognized .mht item: type:", $x_type, " name:",
              $x_name, "\n";
            print "Creating as generic object\n";
            $object = $itemtype{"GENERIC"}{object};
        }
        else {
            print "\nUnrecognized .mht entry: $x_type\n";
        }
    }

    #if object exists then create some code for it
    if ($object) {
        print "debug: creating code2 object for [$x_name]\n";
        my $code2 = sprintf "\n\$%-35s =  new %s;\n", $x_name, $object;
        $code2 =~ s/= *new \S+ *\(/-> add \(/ if $objects{$x_name}++;
        $code .= $code2;
    }

    #Create and initialize any groups that were specified.

    ##   if there was more than one group, specify them separately...
    foreach my $group_twig ( $item->children("group") ) {
        my $group = $group_twig->text();
        $group =~ s/\'//g;
        $group =~ s/\s*$//g;
        if ( $x_name eq $group ) {
            if ( $smartgroupfix == 1 ) {
                $group .= "_group";
            }
            else {
                print_log
                  "mht object and group name are the same: $x_name  Bad idea!";
                next;

            }
        }

        # Allow for floorplan data:  Bedroom(5,15)|Lights
        my $fp_loc = $group_twig->att("fp_loc");
        if ( $fp_loc =~ /\d+/ ) {
            $fp_loc .= ',1,1' if ( $fp_loc =~ tr/,/,/ ) < 3;
            $code .= sprintf "\$%-35s -> set_fp_location($fp_loc);\n", $x_name;
        }

        #	print "testing for existence of group: [$group]\n";
        print "Adding new group: [$group]\n" unless $groups{$group};
        $code .= sprintf "\$%-35s =  new Group;\n", $group
          unless $groups{$group};
        $code .= sprintf "\$%-35s -> add(\$%s);\n", $group, $x_name
          unless $groups{$group}{$x_name};
        $groups{$group}{$x_name}++;

        if ( lc($group) eq 'hidden' ) {
            $code .= sprintf "\$%-35s -> hidden(1);\n", $x_name;
        }
    }

    $twig_code_accum .= $code;    ## accumulate code for eventual return
}

sub force_single_quotes {
    my ($tgt) = @_;
    $tgt =~ s/'//g;               ## kill any prior quotes
    $tgt = "'" . $tgt . "'";
}
1;
