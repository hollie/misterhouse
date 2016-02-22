# Test for Zantech functions
# This works for the ZPR68-10 and may work for other Xantech products
#
#  Lou Montulli lou@montulli.org
#  Sept 6, 2004

# The ZPR68 has 6 zones and 8 inputs

# Change these to the names of your rooms
my @zone_names =
  ( "ALL Zones", "Zone 1", "Zone 2", "Zone 3", "Zone 4", "Zone 5", "Zone 6" );

# Change these to the names of your input sources
my @input_names = ( "INVALID", "1", "2", "3", "4", "5", "6", "7", "8" );
my $number_of_inputs_in_use = 3;    # set this to your system

my $data;

$data .= "<table>\n";
$data .= "<tr align=center>\n";
$data .= "<td>Name\n";
$data .= "<td>Input\n";
$data .= "<td>Mute\n";
$data .= "<td>Volume\n";
$data .= "<td>Select new input\n";
$data .= "</tr>\n";

my $zone_name;
for ( $zone_name = 0; $zone_name < 7; $zone_name++ ) {
    my $zone_ptr = new Xantech_Zone($zone_name);

    # Zone name
    $data .= "<tr align=center>";
    $data .= "<td>";
    $data .= $zone_names[$zone_name] . ": ";

    # Input
    $data .= "<td>";
    if ( $zone_name != 0 ) {
        $data .= $input_names[ $zone_ptr->getstate_input ];
    }

    # Mute
    $data .= "<td>";
    if ( $zone_ptr->getstate_mute ) {
        $data .=
          "<A href='?set_mute=0&set_zone=$zone_name'> <font color='red'>ON</A>";
    }
    else {
        $data .=
          "<A href='?set_mute=1&set_zone=$zone_name'> <font color='green'>OFF</A>";
    }

    # Volume
    my $cur_vol = $zone_ptr->getstate_volume;
    $data .= "<td>";

    my $inc;
    for ( $inc = 1; $inc < 41; $inc++ ) {
        if ( $inc == $cur_vol ) {
            $data .= "||";
        }
        else {
            $data .= "<A href='?set_volume=$inc&set_zone=$zone_name'>.</A>";
        }
    }

    # Set a new zone
    $data .= "<td>";
    for ( my $i = 1; $i < $number_of_inputs_in_use + 1; $i++ ) {
        my $cur_input = $zone_ptr->getstate_input;
        if ( $i == $cur_input ) {
            $data .= $input_names[$i];
        }
        else {
            $data .= "<A href='?set_input=$i&set_zone=$zone_name'>";
            $data .= $input_names[$i] . "</A>";
        }

        $data .= " ";
    }

    $data .= "</tr>\n";
}

$data .= "<table>\n";

# Use this to get the HTTP GET query data
# there is probably an easier way in misterhouse but I didn't know it
my %queryStrings = ();
foreach my $part (@ARGV) {
    my $name;
    my $value;
    ( $name, $value ) = split( /\=/, $part );
    $queryStrings{"$name"} = $value;
}

my $set_zone_command = $queryStrings{"set_zone"};

# dont do any of this if we dont have a zone specified
if ( defined($set_zone_command) ) {

    # add a refresh to the document so it resets itself
    $data = "<META HTTP-EQUIV=Refresh CONTENT='3; URL=?'>\n" . $data;

    my $set_volume_command = $queryStrings{"set_volume"};
    my $set_mute_command   = $queryStrings{"set_mute"};
    my $set_input_command  = $queryStrings{"set_input"};

    if ($set_volume_command) {
        $data .= "<h3>Setting volume for " . $zone_names[$set_zone_command];
        $data .= " to " . $set_volume_command . "</h3>\n";

        my $zone_ptr = new Xantech_Zone($set_zone_command);

        $zone_ptr->setstate_volume($set_volume_command);
    }

    if ( defined($set_mute_command) ) {
        $data .= "<h3>Setting Mute for " . $zone_names[$set_zone_command];
        $data .= " to " . $set_mute_command . "</h3>\n";

        my $zone_ptr = new Xantech_Zone($set_zone_command);

        $zone_ptr->setstate_mute($set_mute_command);
    }

    if ($set_input_command) {
        $data .= "<h3>Setting Input for " . $zone_names[$set_zone_command];
        $data .= " to " . $set_input_command . "</h3>\n";

        my $zone_ptr = new Xantech_Zone($set_zone_command);

        $zone_ptr->setstate_input($set_input_command);
    }
}

return $data;
