#!/local/bin/perl

# See mh/code/public/bvac_brian.pl for more info

use strict;
use Schedule::Cron::Events;
use Time::Local;
use File::Spec;

#my $scriptname = "newhvac.pl";
my $codefile   = File::Spec->catfile( $config_parms{code_dir}, "hvac.mhp" );
my $scriptname = "/web/bin/newhvac.pl";
my $bgcolor    = "#9999CC";

my $hvac = {
    HeatingDefaults => {
        Unoccupied => 50,
        Occupied   => 71,
        Sleeping   => 68,
        Maximum    => 75,
    },
    CoolingDefaults => {
        Unoccupied => 90,
        Occupied   => 71,
        Sleeping   => 75,
        Maximum    => 67,
    },
    heatingzones => [],
    coolingzones => [],
};

$hvac = $Save{hvac_system} if $Save{hvac_system};

my %ARGS;
foreach my $i (@ARGV) {
    my ( $name, $val ) = split /\=/, $i;
    $ARGS{$name} = $val;
}

if ( !@{ $hvac->{heatingzones} } && !@{ $hvac->{coolingzones} } ) {
    $ARGS{SETUP} = 1;
}

if ($Authorized) {
    foreach my $i ( keys %ARGS ) {
        if ( $i =~ /^set_desired_heat_(.*)/ ) {
            my $name   = $1;
            my $desobj = get_object_by_name($name);
            if ($desobj) {
                set $desobj $ARGS{$i};
            }
        }

        if ( $i =~ /^set_heat_(.*)/ ) {
            my $name    = $1;
            my $roomobj = get_object_by_name($name);
            if ($roomobj) {
                set $roomobj $ARGS{$i};
                my $desired    = $name . "_desired";
                my $desiredobj = get_object_by_name($desired);
                if ($desiredobj) {
                    foreach my $zone ( @{ $hvac->{heatingzones} } ) {
                        next if $zone->{Name} ne $ARGS{ZONE};
                        foreach my $j ( @{ $zone->{Rooms} } ) {
                            my $tmpname = lc( $j->{Name} );
                            $tmpname =~ s/\W/_/g;
                            $tmpname = "\$hvac_" . $tmpname;
                            if ( $tmpname eq $name ) {
                                set $desiredobj $j->{ $ARGS{$i} };
                                last;
                            }
                        }
                    }
                }
            }
        }

        foreach
          my $j (qw( Name Controller Unoccupied Occupied Sleeping Maximum ))
        {
            if ( $i =~ /Heating_Zone_${j}_(\d+)/ ) {
                my $num = $1;
                $hvac->{heatingzones}->[ $num - 1 ]->{$j} = $ARGS{$i};
            }
        }

        foreach my $j (qw( Unoccupied Occupied Sleeping Maximum )) {
            if ( $i =~ /HeatingDefaults_$j/ ) {
                $hvac->{HeatingDefaults}->{$j} = $ARGS{$i};
            }
        }

        foreach my $j (qw( LowOffset LowOffset2 HighOffset )) {
            foreach my $k (qw( Unoccupied Occupied Sleeping Maximum )) {
                if ( $i =~ /${j}_$k/ ) {
                    $hvac->{$i} = $ARGS{$i};
                }
            }
        }

        foreach my $j (
            qw( Name Unoccupied Occupied Sleeping Maximum Sensor TimeToHeat ))
        {
            if ( $i =~ /Heating_Room_${j}_(\d+)_(\d+)/ ) {
                my ( $zone, $num ) = ( $1, $2 );
                $hvac->{heatingzones}->[ $zone - 1 ]->{Rooms}->[ $num - 1 ]
                  ->{$j} = $ARGS{$i};
            }
        }

        foreach my $j (qw( Room State Item Value )) {
            if ( $i =~ /Heating_Tie_${j}_(\d+)_(\d+)/ ) {
                my ( $zone, $num ) = ( $1, $2 );
                $hvac->{heatingzones}->[ $zone - 1 ]->{Ties}->[ $num - 1 ]->{$j}
                  = $ARGS{$i};
            }
        }
    }

    foreach my $i ( keys %ARGS ) {
        if ( $i =~ /MoveHeatingZoneDown_(\d+)/ ) {
            my $num = $1;
            @{ $hvac->{heatingzones} }[ $num - 1, $num ] =
              @{ $hvac->{heatingzones} }[ $num, $num - 1 ];
        }
        if ( $i =~ /MoveHeatingZoneUp_(\d+)/ ) {
            my $num = $1;
            @{ $hvac->{heatingzones} }[ $num - 2,   $num - 1 ] =
              @{ $hvac->{heatingzones} }[ $num - 1, $num - 2 ];
        }
    }

    if ( $ARGS{AddHeatingZone} ) {
        push @{ $hvac->{heatingzones} },
          {
            Name       => "Name this zone",
            Rooms      => [],
            Ties       => [],
            Controller => "No Controller",
            Thermostat => "No Thermostat",
            Unoccupied => $hvac->{HeatingDefaults}->{Unoccupied},
            Occupied   => $hvac->{HeatingDefaults}->{Occupied},
            Sleeping   => $hvac->{HeatingDefaults}->{Sleeping},
            Maximum    => $hvac->{HeatingDefaults}->{Maximum},
          };
    }

    if ( $ARGS{DeleteHeatingZone} ) {
        splice @{ $hvac->{heatingzones} }, $ARGS{DeleteHeatingZone} - 1, 1;
    }

    if ( $ARGS{DeleteHeatingRoom} ) {
        my ( $zone, $room ) = split /_/, $ARGS{DeleteHeatingRoom};
        splice @{ $hvac->{heatingzones}->[ $zone - 1 ]->{Rooms} }, $room - 1, 1;
    }

    if ( $ARGS{DeleteHeatingTie} ) {
        my ( $zone, $room ) = split /_/, $ARGS{DeleteHeatingTie};
        splice @{ $hvac->{heatingzones}->[ $zone - 1 ]->{Ties} }, $room - 1, 1;
    }

    if ( $ARGS{AddNewTie} ) {
        if ( $ARGS{SETUP} =~ /Heating_(\d+)/ ) {
            my $zone = $1 - 1;
            push @{ $hvac->{heatingzones}->[$zone]->{Ties} }, {};
        }
    }

    if ( $ARGS{AddNewRoom} ) {
        if ( $ARGS{SETUP} =~ /Heating_(\d+)/ ) {
            my $zone = $1 - 1;
            push @{ $hvac->{heatingzones}->[$zone]->{Rooms} },
              {
                Name       => "Name this room",
                Unoccupied => $hvac->{heatingzones}->[$zone]->{Unoccupied},
                Occupied   => $hvac->{heatingzones}->[$zone]->{Occupied},
                Occupied   => $hvac->{heatingzones}->[$zone]->{Occupied},
                Sleeping   => $hvac->{heatingzones}->[$zone]->{Sleeping},
                Maximum    => $hvac->{heatingzones}->[$zone]->{Maximum},
                Sensor     => "No Sensor",
              };
        }
    }

    writeHvacCode($hvac);
}

print "Content-Type: text/html\n\n";
print "<html>\n<body>\n";
print "<link REL=\"STYLESHEET\" HREF=\"/default.css\" TYPE=\"text/css\" />\n";
print
  "<div ID=\"overDiv\" STYLE=\"position:absolute; visibility:hide; z-index:1;\" />\n";

#print "<script LANGUAGE=\"JavaScript\" SRC=\"/lib/overlib.js\" />\n";
#print "<base TARGET='speech' />\n";

if ( !$ARGS{SETUP} && !$ARGS{ZONE} ) {
    $ARGS{ZONE} = $hvac->{heatingzones}->[0]->{Name};
}

print generateTabs( \%ARGS, $hvac );

if ( $ARGS{SETUP} == 1 ) {
    print showSetup( \%ARGS, $hvac );
}
elsif ( $ARGS{SETUP} =~ /Heating_(\d+)/ ) {
    my $zone = $1;
    print setupHeatingZone( \%ARGS, $hvac, $zone - 1 );
}
elsif ( $ARGS{SHOWALL} ) {
    print showAllHeatingZones( $hvac, \%ARGS );
}
elsif ( $ARGS{ZONE} ) {
    print showZone( $hvac, $ARGS{ZONE}, \%ARGS );
}

if (0) {
    print "<BR /><BR /><h3>DEBUG INFO</h3>", join( "<BR />", @ARGV );
}
print "</body></html>\n";

if ( $ARGS{SETUP} && $Authorized ) {
    $Save{hvac_system} = $hvac;
}

sub setupHeatingZone {
    my $ARGS  = shift;
    my $hvac  = shift;
    my $zone  = shift;
    my $setup = $zone + 1;

    my $name = $hvac->{heatingzones}->[$zone]->{Name};

    my $str =
      "<a href=\"$scriptname?SETUP=1\">Return to Main Setup Page</a><br /><br />\n";

    $str .= "<form>\n";
    $str .=
      "<input type=\"hidden\" name=\"SETUP\" value=\"Heating_$setup\" />\n";

    my $select;
    my $selected =
      $hvac->{heatingzones}->[$zone]->{Controller} || "No Controller";
    $select =
      "<select name=\"Heating_Zone_Controller_${setup}\" onchange=\"submit()\">\n";
    $select .= "<option ";
    $select .= "selected " if "No Controller" eq $selected;
    $select .= "value=\"No Controller\">No Controller</option>\n";
    for my $object_type (@Object_Types) {
        next if $object_type eq 'Voice_Cmd';
        foreach my $object ( list_objects_by_type($object_type) ) {
            my $label = $object;
            $label =~ s/^\$//;
            $select .= "<option ";
            $select .= "selected " if $object eq $selected;
            $select .= "value=\"$object\">$label</option>\n";
        }
    }
    $select .= "</select>\n";
    $str    .= "<b>Zone Heating Controller: </b> $select <br />\n";

    $str .= "<table cellspacing=\"0\" cellpadding=\"0\" border=\"1\">\n";
    $str .=
      "<tr><th bgcolor=\"$bgcolor\">$name (for Heating) Defaults</th></tr>\n";
    $str .= "<tr><td>\n";
    $str .= "<table cellspacing=\"0\" cellpadding=\"0\" border=\"0\">\n";
    $str .= "<tr>";
    $str .= "<td colspan=\"4\" align=\"center\"><b>Temperatures</b></td>";
    $str .= "<td /></tr>\n";
    $str .= "<tr>";
    $str .= "<td><b>Unoccupied&nbsp;&nbsp;</b></td>";
    $str .= "<td><b>Occupied&nbsp;&nbsp;</b></td>";
    $str .= "<td><b>Sleeping&nbsp;&nbsp;</b></td>";
    $str .= "<td><b>Maximum&nbsp;&nbsp;</b></td>";
    $str .= "<td /></tr>\n";

    $str .= "<tr>\n";
    $selected = $hvac->{heatingzones}->[$zone]->{Unoccupied} || 50;
    $select =
      "<select name=\"Heating_Zone_Unoccupied_${setup}\" onchange=\"submit()\">\n";
    foreach my $temp ( 45 .. 75 ) {
        $select .= "<option ";
        $select .= "selected " if $temp == $selected;
        $select .= "value=\"$temp\">$temp</option>\n";
    }
    $select .= "</select>\n";
    $str    .= "<td>$select</td>\n";

    $selected = $hvac->{heatingzones}->[$zone]->{Occupied} || 71;
    $select =
      "<select name=\"Heating_Zone_Occupied_${setup}\" onchange=\"submit()\">\n";
    for ( my $temp = 65; $temp <= 75; $temp += 0.5 ) {
        $select .= "<option ";
        $select .= "selected " if $temp == $selected;
        $select .= "value=\"$temp\">$temp</option>\n";
    }
    $select .= "</select>\n";
    $str    .= "<td>$select</td>\n";

    $selected = $hvac->{heatingzones}->[$zone]->{Sleeping} || 68;
    $select =
      "<select name=\"Heating_Zone_Sleeping_${setup}\" onchange=\"submit()\">\n";
    for ( my $temp = 45; $temp <= 75; $temp += 0.5 ) {
        $select .= "<option ";
        $select .= "selected " if $temp == $selected;
        $select .= "value=\"$temp\">$temp</option>\n";
    }
    $select .= "</select>\n";
    $str    .= "<td>$select</td>\n";

    $selected = $hvac->{heatingzones}->[$zone]->{Maximum} || 75;
    $select =
      "<select name=\"Heating_Zone_Maximum_${setup}\" onchange=\"submit()\">\n";
    foreach my $temp ( 60 .. 85 ) {
        $select .= "<option ";
        $select .= "selected " if $temp == $selected;
        $select .= "value=\"$temp\">$temp</option>\n";
    }
    $select .= "</select>\n";
    $str    .= "<td>$select</td>\n";
    $str    .= "</tr></table></td></tr></table><br />\n";

    $str .= "<table cellspacing=\"0\" cellpadding=\"0\" border=\"1\">\n";
    $str .=
      "<tr><th bgcolor=\"$bgcolor\">Rooms in $name (for Heating)</th></tr>\n";
    $str .= "<tr><td>\n";
    $str .= "<table cellspacing=\"0\" cellpadding=\"0\" border=\"0\">\n";

    if ( @{ $hvac->{heatingzones}->[$zone]->{Rooms} } > 0 ) {
        $str .= "<tr>";
        $str .= "<td />";
        $str .= "<td><b>Temperature</b></td>";
        $str .= "<td colspan=\"4\" align=\"center\"><b>Temperatures</b></td>";
        $str .= "<td align=\"center\"><b>Minutes To Heat</b></td>";
        $str .= "<td /></tr>\n";
        $str .= "<tr>";
        $str .= "<td>&nbsp;<b>Name</b></td>";
        $str .= "<td><b>Sensor Name&nbsp;&nbsp;</b></td>";
        $str .= "<td><b>Unoccupied&nbsp;&nbsp;</b></td>";
        $str .= "<td><b>Occupied&nbsp;&nbsp;</b></td>";
        $str .= "<td><b>Sleeping&nbsp;&nbsp;</b></td>";
        $str .= "<td><b>Maximum&nbsp;&nbsp;</b></td>";
        $str .= "<td align=\"center\"><b>One Degree</b></td>";
        $str .= "<td /></tr>\n";
    }

    my $count = 1;
    foreach my $i ( @{ $hvac->{heatingzones}->[$zone]->{Rooms} } ) {
        $str .= "<tr>";

        $str .=
          "<td>&nbsp;<input name=\"Heating_Room_Name_${setup}_$count\" value=\"$i->{ Name }\" onchange=\"submit()\">&nbsp;&nbsp;&nbsp;</td>\n";

        my $select;
        my $selected = $i->{Sensor} || "No Sensor";
        $select =
          "<select name=\"Heating_Room_Sensor_${setup}_$count\" onchange=\"submit()\">\n";
        $select .= "<option ";
        $select .= "selected " if "No Sensor" eq $selected;
        $select .= "value=\"No Sensor\">No Sensor</option>\n";
        for my $object_type (@Object_Types) {
            next if $object_type eq 'Voice_Cmd';
            foreach my $object ( list_objects_by_type($object_type) ) {
                my $label = $object;
                $label =~ s/^\$//;
                $select .= "<option ";
                $select .= "selected " if $object eq $selected;
                $select .= "value=\"$object\">$label</option>\n";
            }
        }
        $select .= "</select>\n";
        $str    .= "<td align=\"center\">$select</td>\n";

        $selected = $i->{Unoccupied};
        $select =
          "<select name=\"Heating_Room_Unoccupied_${setup}_$count\" onchange=\"submit()\">\n";
        foreach my $temp ( 45 .. 75 ) {
            $select .= "<option ";
            $select .= "selected " if $temp == $selected;
            $select .= "value=\"$temp\">$temp</option>\n";
        }
        $select .= "</select>\n";
        $str    .= "<td align=\"center\">$select</td>\n";

        $selected = $i->{Occupied};
        $select =
          "<select name=\"Heating_Room_Occupied_${setup}_$count\" onchange=\"submit()\">\n";
        for ( my $temp = 65; $temp <= 75; $temp += 0.5 ) {
            $select .= "<option ";
            $select .= "selected " if $temp == $selected;
            $select .= "value=\"$temp\">$temp</option>\n";
        }
        $select .= "</select>\n";
        $str    .= "<td align=\"center\">$select</td>\n";

        $selected = $i->{Sleeping};
        $select =
          "<select name=\"Heating_Room_Sleeping_${setup}_$count\" onchange=\"submit()\">\n";
        for ( my $temp = 45; $temp <= 75; $temp += 0.5 ) {
            $select .= "<option ";
            $select .= "selected " if $temp == $selected;
            $select .= "value=\"$temp\">$temp</option>\n";
        }
        $select .= "</select>\n";
        $str    .= "<td align=\"center\">$select</td>\n";

        $selected = $i->{Maximum};
        $select =
          "<select name=\"Heating_Room_Maximum_${setup}_$count\" onchange=\"submit()\">\n";
        foreach my $temp ( 60 .. 85 ) {
            $select .= "<option ";
            $select .= "selected " if $temp == $selected;
            $select .= "value=\"$temp\">$temp</option>\n";
        }
        $select .= "</select>\n";
        $str    .= "<td align=\"center\">$select</td>\n";

        $selected = $i->{TimeToHeat};
        $select =
          "<select name=\"Heating_Room_TimeToHeat_${setup}_$count\" onchange=\"submit()\">\n";
        foreach my $temp ( 1 .. 90 ) {
            $select .= "<option ";
            $select .= "selected " if $temp == $selected;
            $select .= "value=\"$temp\">$temp</option>\n";
        }
        $select .= "</select>\n";
        $str    .= "<td align=\"center\">$select</td>\n";

        $str .=
          "<td><a href=\"$scriptname?SETUP=Heating_$setup&DeleteHeatingRoom=${setup}_$count\">Delete</a>&nbsp;&nbsp;&nbsp;</td>\n";
        $str .= "</tr>\n";
        $count++;
    }

    my $offset = 8;
    $str .=
      "<tr height=\"$offset\"><td height=\"$offset\"><img src=\"/graphics/1pixel.gif\" border=\"0\" height=\"$offset\" /></td></tr>\n";
    $str .=
      "<tr><td colspan=\"5\">&nbsp;<a href=\"$scriptname?SETUP=Heating_$setup&AddNewRoom=1\">Add a New Room</a></td>\n";

    $str .= "</table>";
    $str .= "</tr></td></table>\n";

    $str .= "<br />\n";
    $str .= "<table cellspacing=\"0\" cellpadding=\"0\" border=\"1\">\n";
    $str .=
      "<tr><th bgcolor=\"$bgcolor\">Tie Temperature States to Items</th></tr>\n";
    $str .= "<tr><td>\n";
    $str .= "<table cellspacing=\"0\" cellpadding=\"0\" border=\"0\">\n";

    $hvac->{heatingzones}->[$zone]->{Ties} = [ {} ]
      if !$hvac->{heatingzones}->[$zone]->{Ties}
      || @{ $hvac->{heatingzones}->[$zone]->{Ties} } == 0;
    $count = 1;
    foreach my $i ( @{ $hvac->{heatingzones}->[$zone]->{Ties} } ) {
        $str .= "<tr>";

        my $select =
          "<select name=\"Heating_Tie_Room_${setup}_$count\" onchange=\"submit()\">\n";
        my $selected = $i->{Room};
        foreach my $room ( @{ $hvac->{heatingzones}->[$zone]->{Rooms} } ) {
            $select .= "<option ";
            $select .= "selected " if $room->{Name} eq $selected;
            $select .= "value=\"$room->{ Name }\">$room->{ Name }</option>\n";
        }
        $select .= "</select>\n";
        $str    .= "<td>&nbsp;Set $select to&nbsp;</td>\n";

        $select =
          "<select name=\"Heating_Tie_State_${setup}_$count\" onchange=\"submit()\">\n";
        $selected = $i->{State};
        foreach my $state (qw (Unoccupied Occupied Sleeping)) {
            $select .= "<option ";
            $select .= "selected " if $state eq $selected;
            $select .= "value=\"$state\">$state</option>\n";
        }
        $select .= "</select>\n";
        $str    .= "<td>$select if&nbsp;</td>\n";

        $select =
          "<select name=\"Heating_Tie_Item_${setup}_$count\" onchange=\"submit()\">\n";
        $selected = $i->{Item} || "Choose an Item";
        $select .= "<option ";
        $select .= "selected " if "Choose an Item" eq $selected;
        $select .= "value=\"Choose an Item\">Choose an Item</option>\n";
        for my $object_type (@Object_Types) {
            next if $object_type eq 'Voice_Cmd';
            foreach my $object ( list_objects_by_type($object_type) ) {
                my $label = $object;
                $label =~ s/^\$//;
                $select .= "<option ";
                $select .= "selected " if $object eq $selected;
                $select .= "value=\"$object\">$label</option>\n";
            }
        }
        $select .= "</select>\n";
        $str    .= "<td>$select equals&nbsp;</td>\n";

        $str .=
          "<td><input name=\"Heating_Tie_Value_${setup}_$count\" value=\"$i->{ Value }\" onchange=\"submit()\">&nbsp;&nbsp;&nbsp;</td>\n";

        $str .=
          "<td><a href=\"$scriptname?SETUP=Heating_$setup&DeleteHeatingTie=${setup}_$count\">Delete</a>&nbsp;&nbsp;&nbsp;</td>\n";

        $str .= "</tr>\n";
        $count++;
    }

    $str .=
      "<tr height=\"$offset\"><td height=\"$offset\"><img src=\"/graphics/1pixel.gif\" border=\"0\" height=\"$offset\" /></td></tr>\n";
    $str .=
      "<tr><td colspan=\"5\">&nbsp;<a href=\"$scriptname?SETUP=Heating_$setup&AddNewTie=1\">Add a New Rule</a></td>\n";

    $str .= "</table>";
    $str .= "</tr></td></table>\n";

    $str .= "</form>\n";

    my @matches = findTriggers( $hvac, $zone );

    $str .= "<br />\n";
    $str .= "<table cellspacing=\"0\" cellpadding=\"0\" border=\"1\">\n";
    $str .=
      "<tr><th bgcolor=\"$bgcolor\">Triggers That Match Rules from Tied Section</th></tr>\n";
    $str .= "<tr><td>\n";
    $str .= "<table cellspacing=\"0\" cellpadding=\"0\" border=\"0\">\n";

    $str .= "<tr>";
    $str .= "<td><b>Trigger Name&nbsp;&nbsp;</b></td>";
    $str .= "<td colspan=\"2\"><b>Trigger Action&nbsp;&nbsp;</b></td>";
    $str .= "</tr>\n";

    foreach my $i (@matches) {
        $str .= "<tr>";
        $str .= "<td>$i->{ Trigger }&nbsp;&nbsp;<td>";
        $str .= "<td>Set $i->{ Room }&nbsp;</td>";
        $str .= "<td>to $i->{ State }</td>";
        $str .= "</tr>\n";
    }

    $str .= "</table>";
    $str .= "</tr></td></table>\n";

    return $str;
}

sub showSetup {
    my $ARGS = shift;
    my $hvac = shift;

    my $str = "";
    $str .= "<form>\n";
    $str .= "<input type=\"hidden\" name=\"SETUP\" value=\"1\" />\n";

    #    $str = "<form method=\"GET\">\n";
    #    $str .= "<b>HVAC Control</b> is currently ";

    #    my $text = html_command_table( "\$v_hvac_control" );
    #    ( $text ) = $text =~ m{(<input type="radio".*?)</select>}sig;

    #    $str .= $text;
    #    print "</form>\n";

    $str .= "<br />\n";
    $str .= "<br />\n";
    $str .= "<table cellspacing=\"0\" cellpadding=\"0\" border=\"1\">\n";
    $str .= "<tr><th bgcolor=\"$bgcolor\">Heating Zones</th></tr>\n";
    $str .= "<tr><td>\n";
    $str .= "<table cellspacing=\"0\" cellpadding=\"0\" border=\"0\">\n";

    if ( @{ $hvac->{heatingzones} } > 0 ) {
        $str .= "<tr><td><b>#</b></td>";
        $str .=
          "<td><img src=\"/graphics/1pixel.gif\" border=\"0\" width=\"1\" /></td>";
        $str .=
          "<td><img src=\"/graphics/1pixel.gif\" border=\"0\" width=\"20\" /></td>";
        $str .= "<td><b>Name</b></td><td /></tr>\n";
    }

    my $count = 1;
    foreach my $i ( @{ $hvac->{heatingzones} } ) {
        $str .= "<tr>";
        $str .= "<td>$count)&nbsp;&nbsp;</td>";
        if ( $count > 1 ) {
            $str .=
              "<td><a href=\"$scriptname?SETUP=1&MoveHeatingZoneUp_$count\"><img src=\"/graphics/a1+.gif\" border=\"0\"></a></td>";
        }
        else {
            $str .=
              "<td><img src=\"/graphics/1pixel.gif\" border=\"0\" width=\"1\" /></td>";
        }

        if ( $count < @{ $hvac->{heatingzones} } ) {
            $str .=
              "<td><a href=\"$scriptname?SETUP=1&MoveHeatingZoneDown_$count\"><img src=\"/graphics/a1-.gif\" border=\"0\"></a></td>";
        }
        else {
            $str .=
              "<td><img src=\"/graphics/1pixel.gif\" border=\"0\" width=\"1\" /></td>";
        }
        $str .=
          "<td><input name=\"Heating_Zone_Name_$count\" value=\"$i->{ Name }\" / onchange=\"submit()\">&nbsp;&nbsp;&nbsp;</td>\n";
        $str .=
          "<td><a href=\"$scriptname?SETUP=Heating_$count\">Setup</a>&nbsp;&nbsp;&nbsp;</td>\n";
        $str .=
          "<td><a href=\"$scriptname?SETUP=1&DeleteHeatingZone=$count\">Delete</a>&nbsp;&nbsp;&nbsp;</td>\n";
        $str .= "</tr>\n";
        $count++;
    }
    my $offset = 8;
    $str .=
      "<tr height=\"$offset\"><td height=\"$offset\"><img src=\"/graphics/1pixel.gif\" border=\"0\" height=\"$offset\" /></td></tr>\n";
    $str .=
      "<tr><td colspan=\"5\"><a href=\"$scriptname?SETUP=1&AddHeatingZone=1\">Add a New Zone</a></td>\n";

    $str .= "</table>";
    $str .= "</tr></td></table>\n";

    $str .= "<br />\n";
    $str .= "<table cellspacing=\"0\" cellpadding=\"0\" border=\"1\">\n";
    $str .=
      "<tr><th bgcolor=\"$bgcolor\">Heating Temperature Defaults</th></tr>\n";
    $str .= "<tr><td>\n";
    $str .= "<table cellspacing=\"0\" cellpadding=\"0\" border=\"0\">\n";
    $str .= "<tr>";
    $str .= "<td />";
    $str .= "<td><b>Unoccupied&nbsp;&nbsp;</b></td>";
    $str .= "<td><b>Occupied&nbsp;&nbsp;</b></td>";
    $str .= "<td><b>Sleeping&nbsp;&nbsp;</b></td>";
    $str .= "<td><b>Maximum&nbsp;&nbsp;</b></td>";
    $str .= "</tr>\n";

    $str .= "<td><b>Temperatures&nbsp;&nbsp;</b></td>\n";
    my $selected = $hvac->{HeatingDefaults}->{Unoccupied} || 50;
    my $select =
      "<select name=\"HeatingDefaults_Unoccupied\" onchange=\"submit()\">\n";
    foreach my $temp ( 45 .. 75 ) {
        $select .= "<option ";
        $select .= "selected " if $temp == $selected;
        $select .= "value=\"$temp\">$temp</option>\n";
    }
    $select .= "</select>\n";
    $str    .= "<td align=\"right\">$select&nbsp;&nbsp;</td>\n";

    $selected = $hvac->{HeatingDefaults}->{Occupied} || 71;
    $select =
      "<select name=\"HeatingDefaults_Occupied\" onchange=\"submit()\">\n";
    for ( my $temp = 65; $temp <= 75; $temp += 0.5 ) {
        $select .= "<option ";
        $select .= "selected " if $temp == $selected;
        $select .= "value=\"$temp\">$temp</option>\n";
    }
    $select .= "</select>\n";
    $str    .= "<td align=\"right\">$select&nbsp;&nbsp;</td>\n";

    $selected = $hvac->{HeatingDefaults}->{Sleeping} || 68;
    $select =
      "<select name=\"HeatingDefaults_Sleeping\" onchange=\"submit()\">\n";
    for ( my $temp = 45; $temp <= 75; $temp += 0.5 ) {
        $select .= "<option ";
        $select .= "selected " if $temp == $selected;
        $select .= "value=\"$temp\">$temp</option>\n";
    }
    $select .= "</select>\n";
    $str    .= "<td align=\"right\">$select&nbsp;&nbsp;</td>\n";

    $selected = $hvac->{HeatingDefaults}->{Maximum} || 75;
    $select =
      "<select name=\"HeatingDefaults_Maximum\" onchange=\"submit()\">\n";
    foreach my $temp ( 60 .. 85 ) {
        $select .= "<option ";
        $select .= "selected " if $temp == $selected;
        $select .= "value=\"$temp\">$temp</option>\n";
    }
    $select .= "</select>\n";
    $str    .= "<td align=\"right\">$select&nbsp;&nbsp;</td>\n";
    $str    .= "</tr>";

    $str .= "<tr>\n";
    $str .= "<td><b>Low Offset (heat off)</b></td>\n";
    foreach my $i (qw( Unoccupied Occupied Sleeping Maximum )) {
        my $select = "<select name=\"LowOffset_$i\" onchange=\"submit()\">\n";
        my $selected = $hvac->{"LowOffset_$i"} || -0.5;
        for ( my $j = -0.25; $j >= -3; $j -= 0.25 ) {
            $select .= "<option ";
            $select .= "selected " if $j == $selected;
            $select .= "value=\"$j\">$j</option>\n";
        }
        $select .= "</select>\n";
        $str    .= "<td align=\"right\">$select&nbsp;&nbsp;</td>\n";
    }
    $str .= "</tr>\n";

    $str .= "<tr>\n";
    $str .= "<td><b>Low Offset (heat on)</b></td>\n";
    foreach my $i (qw( Unoccupied Occupied Sleeping )) {
        my $select = "<select name=\"LowOffset2_$i\" onchange=\"submit()\">\n";
        my $selected = $hvac->{"LowOffset2_$i"} || 0;
        for ( my $j = 3; $j >= -3; $j -= 0.25 ) {
            $select .= "<option ";
            $select .= "selected " if $j == $selected;
            $select .= "value=\"$j\">$j</option>\n";
        }
        $select .= "</select>\n";
        $str    .= "<td align=\"right\">$select&nbsp;&nbsp;</td>\n";
    }
    $str .= "</tr>\n";

    $str .= "<tr>\n";
    $str .= "<td><b>High Offset</b></td>\n";
    foreach my $i (qw( Unoccupied Occupied Sleeping )) {
        my $select = "<select name=\"HighOffset_$i\" onchange=\"submit()\">\n";
        my $selected = $hvac->{"HighOffset_$i"} || 0.5;
        for ( my $j = 3; $j > 0; $j -= 0.25 ) {
            $select .= "<option ";
            $select .= "selected " if $j == $selected;
            $select .= "value=\"$j\">$j</option>\n";
        }
        $select .= "</select>\n";
        $str    .= "<td align=\"right\">$select&nbsp;&nbsp;</td>\n";
    }
    $str .= "</tr>\n";

    $str .= "</table></td></tr></table><br />\n";

    $str .= "<br />\n";

    if (0) {
        $str .=
          "The temperature range settings allow you to specify when heat turns on and off.<br />\n";
        $str .=
          "For example, if you set the thermostat at 70 degrees, the heat may come on at 69 degrees<br />";
        $str .= "and turn off at 71 degrees.<br />\n";
        $str .=
          "The point where the heat turns on, I call the 'low offset' (in this example, the low offset<br />";
        $str .=
          "is -1 degrees)  I call the point where the heat turns off the 'high offset' (+1 degree in<br />";
        $str .=
          "this example)  I added another setting called 'low offset2'.  If the heat is already on, the<br />";
        $str .=
          "low offset changes to this number.  This encourages multiple zones to be heating at the same time.<br />";
    }

    $str .= "</form>";
    return $str;
}

sub generateTabs {
    my $ARGS = shift;
    my $hvac = shift;

    my $tabs =
      "<table cellpadding=\"0\" cellspacing=\"0\" border=\"0\">\n<tr>\n";

    foreach my $i ( @{ $hvac->{heatingzones} } ) {
        my $name = $i->{Name};
        my $text = "<a href=\"$scriptname?ZONE=$name\">$name</a>";
        $text = "<b>$name</b>" if $ARGS->{ZONE} eq $name;
        $tabs .= "<td bgcolor=\"$bgcolor\" nowrap>&nbsp;$text&nbsp;</td>";
        $tabs .=
          "<td width=\"1\"><img src=\"/graphics/1pixel.gif\" border=\"0\" width=\"1\" /></td>\n";
    }

    #    my $text = $Authorized ? "<a href=\"$scriptname?SETUP=1\">Setup</a>" : "";
    my $text = "<a href=\"$scriptname?SETUP=1\">Setup</a>";
    if ( $ARGS{SETUP} ) {
        $text = "<b>Setup</b>";
    }
    $tabs .=
      "<td width=\"100%\" bgcolor=\"$bgcolor\" align=\"right\">$text&nbsp;</td></tr>\n";

    my $offset = 5;
    $tabs .=
      "<tr height=\"$offset\"><td height=\"$offset\"><img src=\"/graphics/1pixel.gif\" border=\"0\" height=\"$offset\" /></td></tr>\n";
    $tabs .= "</table>\n";

    return $tabs;
}

sub findTriggers {
    my $hvac = shift;
    my $zone = shift;

    my @matches;
    foreach my $i (trigger_list) {
        next if !trigger_active($i);
        my ( $trigger, $code, $type, $triggered ) = trigger_get($i);

        #	print "'$i' '$trigger' '$code' '$type' '$triggered'<br />\n";

        foreach my $j ( @{ $hvac->{heatingzones}->[$zone]->{Ties} } ) {
            my $item = $j->{Item};
            my $val  = $j->{Value};
            next if !$val;
            $item =~ s/\$/\\\$/g;
            if ( $code =~ m{set\s+$item\s+([\'\"])$val\1}gi ) {
                push @matches,
                  {
                    Trigger => $i,
                    Event   => $trigger,
                    Room    => $j->{Room},
                    State   => $j->{State},
                  };
            }
        }

        #	print STDERR $code, "\n";
        foreach my $j ( @{ $hvac->{heatingzones}->[$zone]->{Rooms} } ) {
            my $name = lc( $j->{Name} );
            $name =~ s/\W/_/g;
            $name = '\$hvac_' . $name;

            if ( $code =~ m{set\s+$name\s+([\'\"])(\w+)\1} ) {
                push @matches,
                  {
                    Trigger => $i,
                    Event   => $trigger,
                    Room    => $j->{Name},
                    State   => $2,
                  };
            }
        }

    }

    return @matches;
}

sub showZone {
    my $hvac     = shift;
    my $zonename = shift;
    my $ARGS     = shift;

    my $zone;
    my $zonenum = 0;
    foreach my $i ( @{ $hvac->{heatingzones} } ) {
        if ( $zonename eq $i->{Name} ) {
            $zone = $i;
            last;
        }
        $zonenum++;
    }
    my $hidden =
      "<input type=\"hidden\" name=\"ZONE\" value=\"$zonename\" />\n";
    if ( $ARGS->{SHOWALL} ) {
        $hidden .= "<input type=\"hidden\" name=\"SHOWALL\" value=\"1\" />\n";
    }

    my @triggers = findTriggers( $hvac, $zonenum );

    my $str;
    if ( $zone->{Controller} ) {
        my $object = get_object_by_name( $zone->{Controller} );
        if ($object) {
            if ( $Save{hvac_statistics} && $Save{hvac_statistics}->[0] ) {
                my $info = "";
                if (   $Save{hvac_statistics}->[0]->{heattime}
                    && $Save{hvac_statistics}->[0]->{heattime}
                    ->{ $zone->{Name} } )
                {
                    my $time = showTime( $Save{hvac_statistics}->[0]->{heattime}
                          ->{ $zone->{Name} } );
                    $info .= "Zone was heated for $time today";
                }
                if (   $Save{hvac_statistics}->[0]->{heatcycle}
                    && $Save{hvac_statistics}->[0]->{heatcycle}
                    ->{ $zone->{Name} } )
                {
                    if ($info) {
                        $info .=
                          " and cycled $Save{ hvac_statistics }->[0]->{ heatcycle }->{ $zone->{ Name } } times";
                    }
                    else {
                        $info .=
                          "Zone cycled $Save{ hvac_statistics }->[0]->{ heatcycle }->{ $zone->{ Name } } times today";
                    }
                }
                if ($info) {
                    $str .= $info . "\n";
                    $str .= "<br />\n";
                }
            }
            $str .=
                "Zone is currently "
              . $object->state
              . " and has been since "
              . scalar( localtime( $Time - $object->get_idle_time ) );
            $str .= "<br />\n";
        }
    }

    $str .= "<table cellspacing=\"0\" cellpadding=\"0\" border=\"1\">\n";
    $str .= "<tr><th bgcolor=\"$bgcolor\">Rooms</th></tr>\n";
    $str .= "<tr><td>\n";
    $str .= "<table cellspacing=\"0\" cellpadding=\"0\" border=\"0\">\n";
    $str .= "<tr>\n";
    $str .= "  <td colspan=\"2\">&nbsp;</td>\n";
    $str .= "  <td colspan=\"2\" align=\"center\"><b>Temperatures</b></td>\n";
    $str .=
      "  <td colspan=\"2\" align=\"center\" nowrap><b>Upcoming Changes</b></td>\n";
    $str .= "</tr>\n";
    $str .= "<tr>\n";
    $str .= "  <td><b>Name&nbsp;&nbsp;</b></td>\n";
    $str .= "  <td><b>Status&nbsp;&nbsp;</b></td>\n";
    $str .= "  <td><b>Current&nbsp;&nbsp;</b></td>\n";
    $str .= "  <td><b>Desired&nbsp;&nbsp;</b></td>\n";
    $str .= "  <td><b>Status&nbsp;&nbsp;</b></td>\n";
    $str .= "  <td><b>Time&nbsp;&nbsp;</b></td>\n";
    $str .= "</tr>\n";

    foreach my $i ( @{ $zone->{Rooms} } ) {
        my $room = lc( $i->{Name} );
        my $roomobj;
        my $desiredobj;
        if ($room) {
            $room =~ s/\W/_/g;
            $roomobj    = get_object_by_name("\$hvac_$room");
            $desiredobj = get_object_by_name("\$hvac_${room}_desired");
        }

        #	my $state = $roomobj ? state $roomobj : "";
        my $state = $roomobj ? state_next_pass($roomobj) : "";

        #	$state = $ARGS->{ "set_\$hvac_$room" } if $ARGS->{ "set_\$hvac_$room" };

        $str .= "<tr>\n";
        $str .= "  <td nowrap>$i->{Name}&nbsp&nbsp;</td>\n";

        if ($roomobj) {
            my $select =
              "<select name=\"set_heat_\$hvac_$room\" onchange=\"submit()\">\n";
            foreach my $val (qw (Unoccupied Occupied Sleeping)) {
                $select .= "<option ";
                $select .= "selected " if lc($val) eq lc($state);
                $select .= "value=\"$val\">$val</option>\n";
            }
            $select .= "</select>\n";
            $str .=
              "  <form>$hidden<td nowrap>$select&nbsp;&nbsp;</td></form>\n";
        }
        else {
            $str .= "  <td>&nbsp;&nbsp;</td>\n";
        }

        $str .= "  <td>";
        my $object;
        $object = get_object_by_name( $i->{Sensor} ) if $i->{Sensor};
        if ($object) {
            $str .= $object->state;
        }
        else {
            $str .= "No Sensor";
        }
        $str .= "&nbsp;&nbsp;</td>\n";

        #	my $des = $i->{ $state } || "";

        my $des = state_next_pass($desiredobj);

        my $select =
          "<select name=\"set_desired_heat_\$hvac_${room}_desired\" onchange=\"submit()\">\n";
        for ( my $temp = 45; $temp <= 75; $temp += 0.5 ) {
            $select .= "<option ";
            $select .= "selected " if $temp == $des;
            $select .= "value=\"$temp\">$temp</option>\n";
        }
        $select .= "</select>\n";

        $str .= "  <form>$hidden<td nowrap>$select&nbsp;&nbsp;</td></form>\n";

        my $status   = "No Rules";
        my $nexttime = "";
        foreach my $j (@triggers) {
            next if $j->{Room} ne $i->{Name};
            next if lc($state) eq lc( $j->{State} );

            my $trigger  = $j->{Event};
            my $firetime = time_to_trigger_fire($trigger);
            if ( !$nexttime || $firetime < $nexttime ) {
                $status   = $j->{State};
                $nexttime = $firetime;
            }
        }
        $str .= "  <td nowrap>$status&nbsp;&nbsp;</td>\n";
        $nexttime = time_date_stamp( 12, $nexttime ) if $nexttime;

        $str .= "  <td nowrap>$nexttime</td>\n";

        $str .= "</tr>\n";
    }

    $str .= "</table>";
    $str .= "</tr></td></table>\n";
    return $str;
}

sub showAllHeatingZones {
    my $hvac = shift;
    my $ARGS = shift;

    my $str;

    if ( $Save{hvac_statistics} && $Save{hvac_statistics}->[0] ) {
        my $info = "";
        if (   $Save{hvac_statistics}->[0]->{heattime}
            && $Save{hvac_statistics}->[0]->{heattime}->{furnace} )
        {
            my $time =
              showTime( $Save{hvac_statistics}->[0]->{heattime}->{furnace} );
            $info .= "Furnace was on for $time today";
        }
        if (   $Save{hvac_statistics}->[0]->{heatcycle}
            && $Save{hvac_statistics}->[0]->{heatcycle}->{furnace} )
        {
            if ($info) {
                $info .=
                  " and cycled $Save{ hvac_statistics }->[0]->{ heatcycle }->{ furnace } times";
            }
            else {
                $info .=
                  "Furnace cycled $Save{ hvac_statistics }->[0]->{ heatcycle }->{ furnace } times today";
            }
        }
        if ($info) {
            $str .= $info . "\n";
            $str .= "<br />\n";
        }
    }

    my $object = get_object_by_name("\$furnace");
    if ($object) {
        $str .=
            "Furnace is currently "
          . $object->state
          . " and has been since "
          . scalar( localtime( $Time - $object->get_idle_time ) );
        $str .= "<br />\n";
    }

    foreach my $i ( @{ $hvac->{heatingzones} } ) {
        $str .= "<b>ZONE: $i->{ Name }</b><br />\n";
        $str .= showZone( $hvac, $i->{Name}, $ARGS );
    }

    return $str;
}

sub writeHvacCode {
    my $hvac = shift;

    my $code =
      'my $hvac = $Save{ hvac_system } if $Save{ hvac_system };' . "\n";

    my $zonenum = 0;
    foreach my $i ( @{ $hvac->{heatingzones} } ) {

        # set up rooms and valid states
        my $roomnum = 0;
        foreach my $j ( @{ $i->{Rooms} } ) {
            my $name = lc( $j->{Name} );
            $name =~ s/\W/_/g;
            $code .= "\$hvac_${name}_desired = new Generic_Item;\n";
            $code .= "\$hvac_$name = new Generic_Item;\n";
            $code .=
              "\$hvac_$name->set_states qw( Unoccupied Occupied Sleeping );\n";

            #	    $code .= "if ( 0 && !state \$hvac_$name ) {\n";
            #	    $code .= "    set \$hvac_$name 'Occupied';\n";
            #	    $code .= "    set \$hvac_${name}_desired $j->{ Occupied };\n";
            #	    $code .= "}\n";
            $code .= "\n";

            foreach my $k qw( Unoccupied Occupied Sleeping ) {
                $code .=
                    "if ( lc( state_changed \$hvac_$name ) eq '"
                  . lc($k)
                  . "' ) {\n";

                #		$code .= "   set \$hvac_${name}_desired $j->{ $k };\n";
                $code .=
                    "   set \$hvac_${name}_desired "
                  . '$hvac->{ heatingzones }->[ '
                  . $zonenum
                  . ' ]->{ Rooms }->[ '
                  . $roomnum
                  . ' ]->{ '
                  . $k . " };\n";
                $code .= "}\n";
                $code .= "\n";
            }
            $roomnum++;
        }

        # set up ties of objects
        foreach my $j ( @{ $i->{Ties} } ) {
            next if !$j->{Item};
            next if $j->{Item} eq "Choose an Item";

            my $value = $j->{Value};
            $value =~ s/^\s+//;
            $value =~ s/\s+$//;

            my $room = lc( $j->{Room} );
            $room =~ s/\W/_/g;

            my $state = $j->{State};
            $state =~ s/^\s+//;
            $state =~ s/\s+$//;

            my $roompointer;
            foreach my $k ( @{ $i->{Rooms} } ) {
                if ( $k->{Name} eq $j->{Room} ) {
                    $roompointer = $k;
                    last;
                }
            }

            $code .=
                "if ( lc( state_changed $j->{Item} ) eq '"
              . lc($value)
              . "' ) {\n";
            $code .= "   set \$hvac_$room '$state';\n";
            $code .=
              "   set \$hvac_${room}_desired $roompointer->{ $state };\n";
            $code .= "   print_log 'ok $j->{Room} changed to $j->{State}';\n";
            $code .= "}\n";
            $code .= "\n";
        }
        $zonenum++;
    }

    open( HVACFILE, "> $codefile" );
    print HVACFILE $code;
    close HVACFILE;
}

sub time_to_trigger_fire {
    my $trigger = shift;

    my $t;
    if ( $trigger =~ /time_random/ ) {
        return;
    }
    elsif ( $trigger =~ /time_now/ ) {

        # still need to handle if user passes in a 'Seconds' argument
        my ($timestr) = $trigger =~ /time_now\s\'(.*?)\'\s*$/;
        $t = &my_str2time($timestr);
        $t += 60 * 60 * 24 if $t - time < 0;
    }
    elsif ( $trigger =~ /^new_(\w+)/ ) {
        my $type = $1;

        my $interval = 1;
        if ( $trigger =~ /^new_\w+\s*\(?\s*\'?(\d+)\s*\'?\)?\s*$/ ) {
            $interval = $1;
        }
        if ( $type eq "second" ) {
            $interval = 1 if !$interval || $interval < 1;
            $interval = 59 if $interval && $interval > 59;

            $t = time + $interval - ( $Second % $interval ) - 1;
        }
        if ( $type eq "minute" ) {
            $interval = 1 if !$interval || $interval < 1;
            $interval = 59 if $interval && $interval > 59;

            $t =
              time - $Second + 60 * ( $interval - ( $Minute % $interval ) ) - 1;
        }
        if ( $type eq "hour" ) {
            $interval = 1 if !$interval || $interval < 1;
            $interval = 23 if $interval && $interval > 23;

            $t =
              time -
              $Second -
              60 * $Minute +
              3600 * ( $interval - ( $Hour % $interval ) ) - 1;
        }
    }
    else {
        my $faketrigger = $trigger;

        if ( $trigger eq "\$New_Hour" ) {
            $faketrigger = "time_cron '0 * * * *'";
        }
        elsif ( $trigger eq "\$New_Day" ) {
            $faketrigger = "time_cron '0 0 * * *'";
        }
        elsif ( $trigger eq "\$New_Week" ) {
            $faketrigger = "time_cron '0 0 * * 0'";
        }
        elsif ( $trigger eq "\$New_Month" ) {
            $faketrigger = "time_cron '0 0 1 * *'";
        }
        elsif ( $trigger eq "\$New_Year" ) {
            $faketrigger = "time_cron '0 0 1 1 *'";
        }

        if ( $faketrigger =~ /time_cron/ ) {

            # still need to handle if user passes in a 'Seconds' argument
            my ($timestr) = $faketrigger =~ /time_cron\s+\'(.*)\'/;
            my $cron = new Schedule::Cron::Events($timestr);
            $t = timelocal( $cron->nextEvent );
        }
    }

    return if !$t;

    return $t;
}

sub state_next_pass {
    my $obj = shift;

    if ( $obj->{state_next_pass} && $obj->{state_next_pass}->[0] ) {
        return $obj->{state_next_pass}->[0];
    }
    else {
        return $obj->state;
    }
}

sub showTime {
    my $time = shift;

    my $h = int( $time / 3600 );
    my $s = $time % 60;
    my $m = int( $time / 60 ) % 60;

    if ( !$m && !$h ) {
        $time = $s;
    }
    else {
        $time = sprintf( "%02d", $s );
        if ( !$h ) {
            $time = $m . ":" . $time;
        }
        else {
            $time = sprintf( "%d:%02d:%s", $h, $m, $time );
        }
    }

    return $time;
}

### TO DO
#
# Handle Thermostats as well as sensor/relay combos
# Add room controllers (for example, if vents can open and close)
# Allow temperatures to be specified as offsets of defaults
# Add recycle times (how long to wait between last off state and next on state)
# Add minimum number of rooms to want heat before zone turns on
# Add minimum number of zones to want heat before furnace turns on
# add help screens
# add some better intelligence to try to get heating zones to overlap
# add an overview page (put furnace on time in page)

