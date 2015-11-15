# Category = Interfaces

#@  iPhone/iPod Touch interface v0.2.
#@  Todo: AJAX dyanimc objects, some code cleanup

# noloop=start
my $list_name = "";
my $object    = "";

# noloop=stop

sub iphoneLog {
    my ( $log, $lines ) = @_;
    $lines = 10 if ( !$lines or $lines == 0 );
    my @lines;
    my $html = "";
    if ( $log eq "Speech" ) {
        @lines = &main::speak_log_last($lines);
    }
    elsif ( $log eq "Display" ) {
        @lines = &main::display_log_last($lines);
    }
    elsif ( $log eq "Print" ) {
        @lines = &main::print_log_last($lines);
    }
    elsif ( $log eq "Error" ) {
        @lines = &main::error_log_last($lines);
    }
    for my $l (@lines) {
        $html .= "          $l<br/>";
    }

    $html = '
          <div class="iLayer" id="wa' . $log . 'Log" title="' . $log . ' Log">
            <div class="iBlock">
              <p><small> ' . $html . '
              </small></p>
            </div>
          </div>
';
    return $html;
}

sub iphoneWebApp {
    my ( $list_name, $output ) = @_;
    my $nolinks = "";
    if ( $list_name =~ s/^:// ) {
        $nolinks = "yes";
    }
    else {
        $nolinks = "no";
    }

    my $html_refrate = $config_parms{html_refresh};
    $html_refrate = '60' unless $html_refrate;

    my ( $html, $html_group, $html_groups, $htm_hdr, $i, @objects );
    $html       = "";
    $html_group = "";

    # Request by type or by group name?

    @objects = &list_objects_by_type($list_name);

    @objects = &list_objects_by_group( $list_name, 1 ) unless @objects;

    for my $item (@objects) {
        next unless $item;
        my $object = &get_object_by_name($item);
        my $item2  = $item;
        $item2 =~ s/^\$//;

        next if $object->{hidden};

        my $state = undef;
        if ( $object->can('state_level') ) {
            $state = $object->state_level();
        }
        elsif ( $object->can('state') ) {
            $state = $object->state();
        }
        $state = 'unknown' unless $state;
        $state = 'unknown' if ( $state eq "" );

        my $state_new = ( !defined $state or $state eq 'off' ) ? 'on' : 'off';

        if ( $object->isa('Fan_Motor') ) {
            if ( $state eq 'off' ) {
                $state_new = 'low';
            }
            elsif ( $state eq 'low' ) {
                $state_new = 'med';
            }
            elsif ( $state eq 'med' ) {
                $state_new = 'high';
            }
            else {
                $state_new = 'off';
            }
        }

        my $name;
        my $unit;
        $name = $object->{label};

        if ( $name eq '' or $name eq undef ) {
            $name = &pretty_object_name($item);
        }
        else {
            $unit = $name;
            $unit =~ s/.*\[(.*)\].*/$1/;
            $name =~ s/(.*)\[.*/$1/;
            if ( $name eq $unit ) { $unit = "%s"; }
            if ( $name =~ m/(.*)_(.*)/ ) {
                $name = "$1 <small>[$2]</small>";
            }
        }
        if ( $nolinks eq "yes" ) { $name = ":" . $name; }

        my $icon;
        if (1) {
            ($icon) = &html_find_icon_image( $object, ref($object) );
            $icon = "<img src=\"$icon\" width=32 height=20 class=\"iFull\" />"
              if ( $icon ne "" );
            if ( $object->isa('EIB1_Item') || $object->isa('xPL_Plugwise') ) {
                $html .= "                <li>";
                $html .=
                    '<input type="checkbox" id="'
                  . $item2
                  . '" class="iToggle" title="I|O"';
                if ( $state eq 'on' ) { $html .= ' checked="checked" '; }
                if ( $name =~ s/^:// ) {
                }
                else {
                    $html .= " onclick=\"ChangeState('../SET?$item2=toggle')\"";
                }
                $html .=
                  '/>' . $icon . '<label>' . $name . ' </label></a></li>';
            }
            elsif ( $object->isa('EIB2_Item') ) {
                $html .= "
                <li>
                  <span>
                    <img src=\"/graphics/_0.png\" onclick=\"ChangeState(\'../SET?$item2=off\')\" />
                    <img src=\"/graphics/_down.png\" onclick=\"ChangeState(\'../SET?$item2=dim\')\" />
                    <img src=\"/graphics/_stop.png\" onclick=\"ChangeState(\'../SET?$item2=stop\')\" />
                    <img src=\"/graphics/_up.png\" onclick=\"ChangeState(\'../SET?$item2=brighten\')\" />
                    <img src=\"/graphics/_1.png\" onclick=\"ChangeState(\'../SET?$item2=on\')\" />
                  </span>
                  $icon$name
                </li>
";
            }
            elsif ( $object->isa('EIB5_Item') || $object->isa('EIB6_Item') ) {
                $name =~ s/^://;
                $html .=
                    "                <li><span>"
                  . sprintf( $unit, $state )
                  . "</span>$icon$name</li>";
            }
            elsif ( $object->isa('EIB3_Item') ) {
                $name =~ s/^://;
                $state =~ s/.*([0-9]{2}):([0-9]{2}):[0-9]{2}/$1:$2h/;
                $html .=
                    "                <li><span>"
                  . sprintf( $unit, $state )
                  . "</span>$icon$name</li>";
            }
            elsif ( $object->isa('EIB4_Item') ) {
                $name =~ s/^://;
                $state =~ s:([0-9]{2})/([0-9]{2})/([0-9]{2}):$2.$1.$3:;
                $html .=
                    "                <li><span>"
                  . sprintf( $unit, $state )
                  . "</span>$icon$name</li>";
            }
            elsif ( $object->isa('EIB10_Item') || $object->isa('EIB11_Item') ) {
                $name =~ s/^://;
                $html .=
                    "                <li><span>"
                  . sprintf( $unit, $state )
                  . "</span>$icon$name</li>";
            }
            elsif ( $object->isa('Network_Item') ) {
                $html .= "                <li";
                $html .= " style=\"background-color:#CCFF99\""
                  if ( $state eq "up" );
                $html .= ">$name<span>$state</span></li> "
                  if ( $state eq "up" );

                #	 $html .= "><input type=\"button\" class=\"iPush iBWarn\" value=\"Start $name\" style=\"width:100%\" onclick=\"ChangeState('../SET?$item2=start')\" /></li>" if ($state ne "up");
                $html .=
                  "><label>$name</label><input type=\"checkbox\" class=\"iToggle\" id=\"$name\" title=\"Start|down\" onclick=\"ChangeState('../SET?$item2=start')\" /></li>"
                  if ( $state ne "up" );

            }
            elsif ( $object->isa('AnalogSensor_Item') ) {
                $html .= "                <li";
                if ( $state eq "alert" ) {
                    $html .= " style=\"background-color:#FF0000\"";
                }
                elsif ( $state eq "high" ) {
                    $html .= " style=\"background-color:#CC3333\"";
                }
                elsif ( $state eq "low" ) {
                    $html .= " style=\"background-color:#6699CC\"";
                }
                my $temp = $object->measurement;
                $html .= ">$name<span>$temp</span></li> ";
            }
            elsif ( $object->isa('X10_Switchlinc') ) {
                $html .=
                  "                <li><a href='#_$item2'>$icon$name<span>$state</span></a></li> ";

                $html_groups = "                	<li>";
                $html_groups .=
                    '<input type="checkbox" id="'
                  . $item2
                  . '" class="iToggle" title="I|O"';
                if ( $state ne 'off' ) {
                    $html_groups .= ' checked="checked" ';
                }
                $html_groups .=
                  " onclick=\"ChangeState('../SET?$item2=toggle')\"";
                $html_groups .= '/><label>' . $name . ' </label></li>
';

                #  ------------------------------------------------
                #  A range control would look a lot more iphone-ish
                #  ------------------------------------------------
                #	$html_groups .= "			<li>";
                #	$html_groups .= '<form>0%<input type="range" name="' . $item2. '_dim" min="0" max="100" step="10"';
                #	if ($state eq 'on') {
                #	  $html_groups .=' value="100"';
                #	} elsif ($state eq 'off') {
                #	  $html_groups .= ' value="0"';
                #	} elsif ($state =~ m/\d*\%/ ) {
                #	  my ($value) = $state =~ /(\d*)\%/;
                #	  $html_groups .= ' value="$value"';
                #	}  #onformchange... instead of action
                #       $html_groups .= " action=\"ChangeState('../SET?$item2?\"form." . $item2 . "_dim.value\"%')\""; #need to figure out how to action it.
                #        $html_groups .= '>100%</form></li>
                #';
                #  ------------------------------------------------
                $html_groups .= "			<li>";
                $html_groups .=
                  "<form action=\"/SET;referer?\" method=\"get\">";
                $html_groups .=
                  "<INPUT type=\"hidden\" name=\"select_item\" value=\"$item\">";
                $html_groups .= "<label>Dim Level</label><span>";
                $html_groups .=
                  "<SELECT name=\"select_state\" onChange=\"form.submit()\">\n";
                my ($value) = $state =~ /(\d*)%/;
                $html_groups .= "\t\t\t<option value=\"\" ";
                $html_groups .= "SELECTED" if !$value;
                $html_groups .= "></option>\n";

                for (
                    my $dim_level = 10;
                    $dim_level < 100;
                    $dim_level = $dim_level + 10
                  )
                {
                    $html_groups .= "\t\t\t<option value=\"$dim_level%\"";
                    $html_groups .= " SELECTED"
                      if ( $value
                        && $value >= $dim_level - 10
                        && $value < $dim_level );
                    $html_groups .= ">    $dim_level%    </option>\n";
                }
                $html_groups .= "\t\t\t</SELECT></form></span></li>\n";

                $html_groups .=
                    "			</ul><ul class=\"iArrow\"><li><a href='#_"
                  . $item2
                  . "_advanced'>Advanced</a></li>";
                my $html_groups1    = "";
                my @advanced_states = @{ $object->{states} };
                for my $s1 (@advanced_states) {
                    next
                      if ( ( $s1 eq "on" )
                        or ( $s1 eq "off" )
                        or ( $s1 eq "dim" )
                        or ( $s1 =~ m/\d*%/ ) );
                    $html_groups1 .=
                      "                <li><a href='../SET;&referer(/iphone/index.shtml%23_$item2)?$item2=$s1'>$s1</a></li>
";
                }

                $html_group .= '
          <div class="iLayer" id="wa'
                  . $item2 . '_advanced" title="' . $name . ' Advanced">
            <div class="iMenu">
              <ul class="iArrow">
' . $html_groups1 . '
              </ul>
            </div>
          </div>
';
                $html_group .= '
          <div class="iLayer" id="wa' . $item2 . '" title="' . $name . '">
            <div class="iMenu">
              <ul class="iArrow">
' . $html_groups . '
              </ul>
            </div>
          </div>
';
            }
            elsif ( $object->isa('EIBW_Item') ) {
                $name =~ s/^://;
                $unit  = "%s";
                $state = "gekippt" if ( $state eq "tilt" );
                $state = "offen" if ( $state eq "open" );
                $state = "zu" if ( $state eq "closed" );
                $html .=
                    "                <li><span>"
                  . sprintf( $unit, $state )
                  . "</span>$icon$name</li>";
            }
            elsif ( $object->isa('EIBRB_Item') ) {
                $unit = "%i%%" if ( $unit eq "%s" || $unit eq "" );
                if ( $name =~ s/^:// ) {
                    $html .= "                <li>$icon$name</li>";
                }
                else {
                    $html .= "
                <li>
                  <span>
                    <img src=\"/graphics/_up.png\" onclick=\"ChangeState(\'../SET?$item2=up\')\" />
                    <img src=\"/graphics/_stop.png\" onclick=\"ChangeState(\'../SET?$item2=stop\')\" />
                    <img src=\"/graphics/_down.png\" onclick=\"ChangeState(\'../SET?$item2=down\')\" />
                  </span>
                  $icon$name
                </li>
";
                }
            }
            elsif ( $object->isa('Group') ) {
                $name =~ s/^://;
                $html .=
                  "                <li><a href='#_$item2'>$icon$name</a></li>";
                $html_group = "";
                for my $o ( &list_objects_by_group( $list_name, 1 ) ) {
                    next unless $o;
                    $html_group .= iphoneWebApp( $o, 'iLayer' );
                }
            }
            else {
                my @item_states = ();
                @item_states = @{ $object->{states} }
                  if ( defined $object->{states} );
                if ( $name =~ s/^:// || !@item_states ) {
                    $html .=
                      "                <li>$icon$name<span>$state</span></li> ";
                }
                else {
                    $html .=
                      "                <li><a href='#_$item2'>$icon$name<span>$state</span></a></li> ";
                    $html_groups = "";
                    my @item_states = @{ $object->{states} };
                    for my $s (@item_states) {
                        next if ( $s =~ m:\d*/\d*.*: );
                        $html_groups .=
                          "                <li><a href='../SET;&referer(/iphone/index.shtml%23_$item2)?$item2=$s'>$s</a></li>
";
                    }
                    my $r = ref $object;
                    $html_group .= '
          <div class="iLayer" id="wa' . $item2 . '" title="' . $name . '">
            <div class="iMenu">
              <ul class="iArrow">
' . $html_groups . '
              </ul>
              Sorry, ' . $r . ' currently not fully supported
            </div>
          </div>
';
                }
            }
            $html .= "\n";
        }

    }
    my $title;
    $object = &get_object_by_name($list_name);
    $title  = $object->{label};
    $title  = &pretty_object_name($list_name)
      if ( $title eq '' or $title eq undef );
    my $id = $list_name;
    $id =~ s/^\$//;
    if ( $output eq "iGroup" ) {
        $html = '
        <div id="iGroup">
          <div class="iLayer" id="wa' . $id . '" title="Home">
            <div class="iMenu">
              <ul class="iArrow">
' . $html . '
              </ul>
            </div>
          </div>
        </div>
' . $html_group;
        return $html;
    }
    elsif ( $output eq "iLayer" ) {
        $html = '
          <div class="iLayer" id="wa' . $id . '" title="' . $title . '">
            <div class="iMenu">
              <ul class="iArrow">
' . $html . '
              </ul>
            </div>
          </div>
' . $html_group;
        return $html;
    }
    elsif ( $output eq "iMenu" ) {
        $html = '
            <div class="iMenu">
              <h3>' . $title . '</h3>
              <ul class="iArrow">
' . $html . '
              </ul>
            </div>
';
        return $html;
    }
    else {
        $html = '
<html>
    <head>
        <title>MrHouse</title>
        <meta name="viewport" content="width=device-width; initial-scale=1.0; maximum-scale=1.0; user-scalable=0;" />
        <link rel="stylesheet" href="../WebApp/Design/Render.css" />
        <script type="text/javascript" src="../WebApp/Action/Logic.js"></script>
    </head>

    <body>

      <script type="text/javascript">
        function ChangeState(request) {
            WA.Request(request, null, null);
        }
        </script>

    <div id="WebApp">

        <div id="iHeader">
            <a href="#" id="waBackButton">Back</a>
            <span id="waHeadTitle">' . $title . '</span>
        </div>

        <div id="iGroup">
	  <div id="iLoader">Loading, please wait...</div>

          <div class="iLayer" id="waHome" title="Home">

            <div class="iMenu">
              <ul class="iArrow">
' . $html . '
              </ul>
            </div>
          </div>
        </div>
        <div class="iFooter">
          &copy;2008 RaK, all rights reserved.
	  <br><!--#include var="$Version"-->
        </div>
    </div>
    </body>
</html>';
    }

    return &html_page( '', $html );
}

