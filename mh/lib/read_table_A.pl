use strict;

# Format = A
#
# This is Bill Sobel's (bsobel@vipmail.com) table definition
#
# Type         Address/Info            Name                                    Groups                                      Other Info
#
#X10I,           J1,                     Outside_Front_Light_Coaches,            Outside|Front|Light|NightLighting

#print_log "Using read_table_A.pl";

my (%groups, %objects, %packages);

sub read_table_init_A {
                                # reset known groups
	print_log "Initialized read_table_A.pl";
	%groups=();
	%objects=();
	%packages=();
}

sub read_table_A {
    my ($record) = @_;

    my ($code, $address, $name, $object, $grouplist, $comparison, $limit, @other, $other, $vcommand);
    
    my(@item_info) = split(',\s*', $record);
    my $type = uc shift @item_info;

    if($record =~ /^#/ or $record =~ /^\s*$/) {
       return;
    }
    elsif($type eq "X10A") {
        ($address, $name, $grouplist, @other) = @item_info;
        $other = join ', ', (map {"'$_'"} @other); # Quote data
        $object = "X10_Appliance('$address', $other)";
    }
    elsif($type eq "X10I") {
        ($address, $name, $grouplist, @other) = @item_info;
        $other = join ', ', (map {"'$_'"} @other); # Quote data
        $object = "X10_Item('$address', $other)";
    }
    elsif($type eq "X10O") {
        ($address, $name, $grouplist, @other) = @item_info;
        $other = join ', ', (map {"'$_'"} @other); # Quote data
        $object = "X10_Ote('$address', $other)";
    }
    elsif($type eq "X10SL") {
        ($address, $name, $grouplist, @other) = @item_info;
        $other = join ', ', (map {"'$_'"} @other); 
        $object = "X10_Switchlinc('$address', $other)";
    }
    elsif($type eq "X10G") {
        ($address, $name, $grouplist, @other) = @item_info;
        $other = join ', ', (map {"'$_'"} @other); # Quote data
        $object = "X10_Garage_Door('$address', $other)";
    }
    elsif($type eq "X10S") {
        ($address, $name, $grouplist) = @item_info;
        $object = "X10_IrrigationController('$address')";
    }
    elsif($type eq "X10T") {
        require 'RCS_Item.pm';
        ($address, $name, $grouplist) = @item_info;
        $object = "RCS_Item('$address')";
    }
    elsif($type eq "X10MS") {
        ($address, $name, $grouplist, @other) = @item_info;
        $other = join ', ', (map {"'$_'"} @other); # Quote data
        $object = "X10_Sensor('$address', '$name', $other)";
    }
    elsif($type eq "COMPOOL") {
        ($address, $name, $grouplist) = @item_info;
        ($address, $comparison, $limit) = $address =~ /\s*(\w+)\s*(\<|\>|\=)*\s*(\d*)/;
        $object = "Compool_Item('$address', '$comparison', '$limit')" if $comparison ne undef;
        $object = "Compool_Item('$address')" if $comparison eq undef;
    }
    elsif($type eq "GENERIC") {
        ($name, $grouplist) = @item_info;
        $object = "Generic_Item";
    }
    elsif($type eq "MP3PLAYER") {
        require 'Mp3Player.pm';
        ($address, $name, $grouplist) = @item_info;
        $object = "Mp3Player('$address')";
    }
    elsif($type eq "AUDIOTRON") {
        require 'AudiotronPlayer.pm';
        ($address, $name, $grouplist) = @item_info;
        $object = "AudiotronPlayer('$address')";
    }
    elsif($type eq "WEATHER") {
        ($address, $name, $grouplist) = @item_info;
#       ($address, $comparison, $limit) = $address =~ /\s*(\w+)\s*(\<|\>|\=)*\s*(\d*)/;
#       $object = "Weather_Item('$address', '$comparison', '$limit')" if $comparison ne undef;
        $object = "Weather_Item('$address')";
    }
    elsif($type eq "SG485LCD") {
        require 'Stargate485.pm';
        ($address, $name, $grouplist, @other) = @item_info;
        $other = join ', ', (map {"'$_'"} @other); # Quote data
        $object = "StargateLCDKeypad('$address', $other)";
    }
    elsif($type eq "SG485RCSTHRM") {
        require 'Stargate485.pm';
        ($address, $name, $grouplist, @other) = @item_info;
        $other = join ', ', (map {"'$_'"} @other); # Quote data
        $object = "StargateRCSThermostat('$address', $other)";
    }
    elsif($type eq "STARGATEDIN") {
        require 'Stargate.pm';
        ($address, $name, $grouplist, @other) = @item_info;
        $other = join ', ', (map {"'$_'"} @other); # Quote data
        $object = "StargateDigitalInput('$address', $other)";
    }
    elsif($type eq "STARGATEVAR") {
        require 'Stargate.pm';
        ($address, $name, $grouplist, @other) = @item_info;
        $other = join ', ', (map {"'$_'"} @other); # Quote data
        $object = "StargateVariable('$address', $other)";
    }
    elsif($type eq "STARGATEFLAG") {
        require 'Stargate.pm';
        ($address, $name, $grouplist, @other) = @item_info;
        $other = join ', ', (map {"'$_'"} @other); # Quote data
        $object = "StargateFlag('$address', $other)";
    }
    elsif($type eq "STARGATERELAY") {
        require 'Stargate.pm';
        ($address, $name, $grouplist, @other) = @item_info;
        $other = join ', ', (map {"'$_'"} @other); # Quote data
        $object = "StargateRelay('$address', $other)";
    }
    elsif($type eq "STARGATETHERM") {
        require 'Stargate.pm';
        ($address, $name, $grouplist, @other) = @item_info;
        $other = join ', ', (map {"'$_'"} @other); # Quote data
        $object = "StargateThermostat('$address', $other)";
    }
    elsif($type eq "STARGATEPHONE") {
        require 'Stargate.pm';
        ($address, $name, $grouplist, @other) = @item_info;
        $other = join ', ', (map {"'$_'"} @other); # Quote data
        $object = "StargateTelephone('$address', $other)";
    }
    elsif($type eq "XANTECH") {
        require 'Xantech.pm';
        ($address, $name, $grouplist, @other) = @item_info;
        $other = join ', ', (map {"'$_'"} @other); # Quote data
        $object = "Xantech_Zone('$address', $other)";
    }
    elsif($type eq "SERIAL") {
        ($address, $name, $grouplist, @other) = @item_info;
        $other = join ', ', (map {"'$_'"} @other); # Quote data
        $object = "Serial_Item('$address', $other)";
    }
    elsif($type eq "VOICE") {
        ($name, @other) = @item_info;
        $vcommand = join ',', @other;
        my $fixedname = $name;
        $fixedname =~ s/_/ /g;
        if (!($vcommand =~ /.*\[.*/)) {
            $vcommand .= " [ON,OFF]";
        }
        $code .= sprintf "\nmy \$v_%s_state;\n", $name;
        $code .= sprintf "\$v_%s = new Voice_Cmd(\"%s\");\n", $name, $vcommand;
        $code .= sprintf "if (\$v_%s_state = said \$v_%s) {\n", $name, $name;
        $code .= sprintf "  set \$%s \$v_%s_state;\n", $name, $name;
        $code .= sprintf "  respond \"Turning %s \$v_%s_state\";\n", $fixedname, $name;
        $code .= sprintf "}\n";
        return $code;
    }
    elsif($type eq "IBUTTON") {
        ($address, $name, $grouplist, @other) = @item_info;
        $other = join ', ', (map {"'$_'"} @other); # Quote data
        $object = "iButton('$address', $other)";
    }

    ##ZONE,      4,     Stairway_motion,            Inside|Hall|Sensors
    elsif($type eq "ZONE") {
        ($address, $name, $grouplist, @other) = @item_info;
        $other = join ', ', (map {"'$_'"} @other); # Quote data
        if($other){
            $object = "Sensor_Zone('$address',$other)";
        }
        else{
            $object = "Sensor_Zone('$address')";
        }
        if( ! $packages{caddx}++ ) {   # first time for this object type?
            $code .= "use caddx;\n";
        }
    }
    else {
        print "\nUnrecognized .mht entry: $record\n";
        return;
    }
    
    if ($object) {
        my $code2 = sprintf "\n\$%-35s =  new %s;\n", $name, $object;
        $code2 =~ s/= *new \S+ *\(/-> add \(/ if $objects{$name}++;
        $code .= $code2;
    }

    $grouplist = '' unless $grouplist; # Avoid -w uninialized errors
    for my $group (split('\|', $grouplist)) {
        $group =~ s/ *$//;
        if ($name eq $group) {
            print_log "mht object and group name are the same: $name  Bad idea!";
        }
        else {
            $code .= sprintf "\$%-35s =  new Group;\n", $group unless $groups{$group};
            $code .= sprintf "\$%-35s -> add(\$%s);\n", $group, $name unless $groups{$group}{$name};
            $groups{$group}{$name}++;
        }

        if(lc($group) eq 'hidden')
        {
            $code .= sprintf "\$%-35s -> hidden(1);\n", $name;
        }
    }

    return $code;
}   

1;

#
# $Log$
# Revision 1.16  2002/12/24 03:05:08  winter
# - 2.75 release
#
# Revision 1.15  2002/11/10 01:59:57  winter
# - 2.73 release
#
# Revision 1.14  2002/08/22 13:45:50  winter
# - 2.70 release
#
# Revision 1.13  2002/08/22 04:33:20  winter
# - 2.70 release
#
# Revision 1.12  2002/05/28 13:07:52  winter
# - 2.68 release
#
# Revision 1.11  2001/11/18 22:51:43  winter
# - 2.61 release
#
# Revision 1.10  2001/10/21 01:22:33  winter
# - 2.60 release
#
# Revision 1.9  2001/08/12 04:02:58  winter
# - 2.57 update
#
# Revision 1.8  2001/03/24 18:08:38  winter
# - 2.47 release
#
# Revision 1.7  2001/02/04 20:31:31  winter
# - 2.43 release
#
# Revision 1.6  2000/12/21 18:54:15  winter
# - 2.38 release
#
# Revision 1.5  2000/12/03 19:38:55  winter
# - 2.36 release
#
# Revision 1.4  2000/10/22 16:48:29  winter
# - 2.32 release
#
# Revision 1.3  2000/10/01 23:29:40  winter
# - 2.29 release
#
#

