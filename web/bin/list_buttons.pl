
# Called from shtml files to list buttons with icons.  For example:
#    <a href="/ia5/lights/list_lights.pl?X10_Item">

# Authority: anyone

my ($list_name) = @ARGV;

my $html_refrate = $config_parms{html_refresh};
$html_refrate = '' unless $html_refrate;

my ( $html, $htm_hdr, $i, @objects );

# Request by type or by group name?
@objects = &list_objects_by_type($list_name);
@objects = &list_objects_by_group($list_name) unless @objects;

for my $item ( sort @objects ) {
    next unless $item;
    my $object = &get_object_by_name($item);

    next if $object->{hidden};

    #    my $state = state_level $object if $object->isa('X10_Item');
    #    $state = state $object if $object->isa('Fan_Light') or $object->isa('Fan_Motor') or $object->isa('X10_Appliance') or $object->isa('Network_Item');
    #    $state = state $object if $object->isa('EIB1_Item');
    #    $state = state_level $object if $object->isa('EIB2_Item');

    my $state = undef;
    if ( $object->can('state_level') ) {
        $state = $object->state_level();
    }
    elsif ( $object->can('state') ) {
        $state = $object->state();
    }
    $state = 'unk' unless $state;

    #	print $state_new . "\n";

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

    if ( $object->isa('Network_Item') ) {
        if ( $state eq 'up' ) {
            $state_new = 'down';
        }
        elsif ( $state eq 'start' ) {
            $state = 'starting';
        }
        else {
            $state_new = 'start';
        }
    }

    my $name = &pretty_object_name($item);

    my $icon;
    if ( $Info{module_GD} ) {

        # Use custom icons if they exist
        $state = 'on'  if $state eq '100%';
        $state = 'off' if $state eq '0%';
        $icon  = $state;
        $icon  = 'dim' if $state =~ /d+/;
        my $image = "/graphics/light-" . lc $item . "_" . $icon . ".gif";
        $image =~ s/ /_/g;
        $image =~ s/\$//g;
        my ($file) = ( &http_get_local_file($image) );
        $image = "/bin/button.pl?$item&item&$state" unless -e $file;

        #       $image = "/bin/button.pl?$item&item&$state" unless -e "$config_parms{html_dir}$image";
        $icon =
          "<a href='/bin/button_action.pl?$list_name&$item&$state_new'><img src='$image' alt='$name $state' ISMAP border=0></a>";

        #       $icon = "<a href='/SET;&referer(/bin/list_buttons.pl|$list_name)?$item=$state_new'><img src='$image'       border=0></a>";
        $html .= "
  <td align='left'   width='12%'></td>
  <td align='right'  width='13%'>$icon</td>
  <td align='middle' width='20%'><a href='SET;&html_state_log($item)'><img src='/graphics/log.gif' alt='log' border=0></a></td>
";
    }
    else {
        $state = 'dim' if $state eq 'unk';
        $icon =
          "<a href='/SET;&referer(/bin/list_buttons.pl|$list_name)?$item=$state_new'><img src='/graphics/button_$state.gif' alt='$name $state' border=0></a>";
        $html .= "
  <td align='left'   width='12%'></td>
  <td align='right'  width='13%'>$icon</td>
  <td align='middle' width='20%' bgColor='#cccccc'><b>$name</b><br>
&nbsp<a href='SET;&html_state_log($item)'>Log</a></b></td>
";
    }

    $html .= "</tr><tr>\n" unless ++$i % 2;
}

#$html = "<html><body>\n<base target ='output'>\n" .
if ($html_refrate) {
    $htm_hdr =
        "<html><head><meta HTTP-EQUIV=\"refresh\" CONTENT=\""
      . $html_refrate
      . ";\"><\/head><body>\n";
}
else {
    $htm_hdr = "<html><body>\n";
}

$html = $htm_hdr . &html_header('Control Items') . "
<table width='100%' border='0'>
<center>
 <table cellSpacing=4 cellPadding=0 width='100%' border=0>
$html
</table>
</center>
</table>
</body>
</html>";

return &html_page( '', $html );
