
# Position=3                    Load after tk_widget.pl, so we just to the left of the Help button

my $eye_pos = 0;
my $eye_dir = 1;

if ($eye_dir) {
    $eye_dir = 0 if ++$eye_pos >= 5;
}
else {
    $eye_dir = 1 if --$eye_pos == 0;
}

$Tk_objects{eye} = '      ';
substr($Tk_objects{eye}, $eye_pos, 1) = '=';
&tk_mlabel(\$Tk_objects{eye});



