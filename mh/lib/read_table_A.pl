use strict;

# Format = A
#
# This is Bill Sobel's (bsobel@vipmail.com) table definition
#
# Type         Address/Info            Name                                    Groups                                      Other Info
#
#X10I,           J1,                     Outside_Front_Light_Coaches,            Outside|Front|Light|NightLighting

print_log "Using read_table_A.pl";

my %groups;
sub read_table_A {
    my ($record) = @_;

    my ($code, $address, $name, $object, $grouplist, $comparison, $limit, @other, $other);

    my(@item_info) = split(',\s*', $record);
    my $type = uc shift @item_info;

    if($type eq "X10A") {
        ($address, $name, $grouplist, @other) = @item_info;
        $other = join ', ', (map {"'$_'"} @other); # Quote data
        $object = "X10_Appliance('$address', $other)";
    }
    elsif($type eq "X10I") {
        ($address, $name, $grouplist, @other) = @item_info;
        $other = join ', ', (map {"'$_'"} @other); # Quote data
        $object = "X10_Item('$address', $other)";
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
    elsif($type eq "WEATHER") {
        ($address, $name, $grouplist) = @item_info;
        ($address, $comparison, $limit) = $address =~ /\s*(\w+)\s*(\<|\>|\=)*\s*(\d*)/;
        $object = "Weather_Item('$address', '$comparison', '$limit')" if $comparison ne undef;
        $object = "Weather_Item('$address')" if $comparison eq undef;
    }
    elsif($type eq "STARGATELCD") {
        ($address, $name, $grouplist, @other) = @item_info;
        $other = join ', ', (map {"'$_'"} @other); # Quote data
        $object = "StargateLCDKeypad('$address', $other)";
    }
    elsif($type eq "XANTECH") {
        ($address, $name, $grouplist, @other) = @item_info;
        $other = join ', ', (map {"'$_'"} @other); # Quote data
        $object = "Xantech_Zone('$address', $other)";
    }
    elsif($type eq "SERIAL") {
        ($address, $name, $grouplist, @other) = @item_info;
        $other = join ', ', (map {"'$_'"} @other); # Quote data
        $object = "Serial_Item('$address', $other)";
    }
    else {
        return;
    }
    
    $code .= sprintf "\n\$%-35s =  new %s;\n", $name, $object if $object;

    for my $group (split('\|', $grouplist)) {
        $code .= sprintf "\$%-35s =  new Group;\n", $group unless $groups{$group};
        $code .= sprintf "\$%-35s -> add(\$%s);\n", $group, $name;
        $groups{$group}++;

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
# Revision 1.3  2000/10/01 23:29:40  winter
# - 2.29 release
#
#

