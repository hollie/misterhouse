# Category = MisterHouse

#@ Lists time idle for various types of items.  User configurable "other" option allows reporting on other items.

$_vc_display_item_status =
  new Voice_Cmd 'Show Idle Time [RF,Analog Sensor,Other]';

if ( defined( $state = said $_vc_display_item_status) ) {
    if ( $state eq 'RF' ) {
        &display_idle_item_status('X10_Sensor,RF_Item');
    }
    elsif ( $state eq 'Analog Sensor' ) {
        &display_idle_item_status('AnalogSensor_Item');
    }
    elsif ( $state eq 'Other' ) {

        # has the config parm for item idle been defined?
        my $idle_items_other = $main::config_parms{idle_items_other};
        if ($idle_items_other) {
            &display_idle_item_status($idle_items_other);
        }
        else {
            print
              "You must first define idle_items_other in your ini parms.  Separate multiple item class names with a comma.\n";
        }
    }
}

sub display_idle_item_status {
    my ($idle_types) = @_;
    my $output = "\n($idle_types) items and corresponding idle time";
    $output .= "\n------------------------------------------------------------";
    $output .=
      "\n  * warn - some items may report time since restart/reload\n\n";
    my @idle_items = &main::get_idle_item_data($idle_types);
    foreach my $idle_item_ptr (@idle_items) {
        if ($idle_item_ptr) {
            my %item_data = %$idle_item_ptr;
            my $name      = $item_data{name};
            $name = sprintf( "%-*s", 30, $name );
            $output .= $name . " | " . $item_data{idle_text} . "\n"
              if $item_data{idle_text};
        }
    }

    print $output;
}

sub web_all_idle_status {

    my @object_types = &main::list_object_types;
    my $all_objects = join( ",", @object_types );
    print $all_objects;
    &web_idle_status($all_objects);

}

sub web_idle_status {

    my ($idle_types) = @_;
    my $html_hdr = ();
    my %html_data;
    my $html_output;
    my %idleinfo;
    my $maxlength = 30;

    #remove incompatible objects;
    $idle_types =~ s/,File_Item,/,/g;
    $idle_types =~ s/,Process_Item,/,/g;
    $idle_types =~ s/,Timer,/,/g;

    my @idle_count = split( /,/, $idle_types );
    my @idle_items = &main::get_idle_item_data($idle_types);

    foreach my $idle_item_ptr (@idle_items) {
        if ($idle_item_ptr) {
            my %item_data = %$idle_item_ptr;
            my $name      = $item_data{name};
            next unless ($name);    #In case of bad data
            my $object = &get_object_by_name($name);
            $name =~ s/\$//g;
            my $type = $item_data{class};
            $html_data{$type} =
              "<tr id='resultrow' bgcolor='#9999CC' class='wvtheader'><th align='left' colspan=\"3\">"
              . $type
              . "</th></tr>"
              unless ( defined $html_data{$type} );
            $html_data{$type} .=
              "<tr id='resultrow' vAlign=center bgcolor='#EEEEEE' class='wvtrow'>\n";
            $html_data{$type} .= "<td nowrap>$name</td>";
            $html_data{$type} .= "<td ";

            if ( $object->state eq 'on' or $object->state eq 'up' ) {
                $html_data{$type} .= "bgcolor='#33FF00' ";
            }
            $html_data{$type} .= "nowrap>" . $object->state . "</td>";
            my $idle_text = "unknown";
            $idle_text = $item_data{idle_text}
              if ( defined $item_data{idle_text} );
            $html_data{$type} .= "<td nowrap>$idle_text</td>";
            $html_data{$type} .= "</tr>\n";
        }
    }
    $idle_types =~ s/,/, /g;    #add a space to break up long lists
    $html_hdr = &html_header("($idle_types) Idle Status ");
    $html_hdr .=
      "<table width=100% cellspacing=2><tbody><font face=COURIER size=2><tr id='resultrow' bgcolor='#9999CC' class='wvtheader'><th align='left'>Object</th>";
    $html_hdr .= "<th align='left'>Status</th><th align='left'>Idle</th>";

    my $html = "<html>
<head>
<style>
TR.wvtrow {font-family:Arial; font-size:11; color:#000000}
TR.wvtheader {font-family:Tahoma; font-size:11; color:#101010}
</style>
</head>
<body>";

    for my $key ( keys %html_data ) {
        $html_output .= $html_data{$key};
    }

    if ($html_output) {
        $html .= $html_hdr . $html_output;
    }
    else {
        $html .=
          &html_header("Error, no data to display for type: $idle_types!");
    }

    $html .= "</body>";

    my $html_page = &html_page( '', $html );
    return &html_page( '', $html );

}
