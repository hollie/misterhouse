my $numDigitalInputPorts   = 5;
my $numAnalogueInputPorts  = 2;
my $numCounters            = 2;
my $numMaxInputPorts       = 5;
my $numDigitalOutputPorts  = 8;
my $numAnalogueOutputPorts = 2;
my $numMaxInputPorts       = 5;

my $myURL = '/bin/k8055.pl';

my $i;

my %param;
foreach my $param (@ARGV) {
    $param =~ /^(.+)=(.+)$/ && do { $param{$1} = $2 };
}

my $html = qq[
<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01//EN">
<html>
<head>
<title>K8055 Interface</title>
];

if ( $param{autorefresh} > 0 ) {
    $html .=
      qq[<meta http-equiv="refresh" content="$param{autorefresh}; URL=$myURL?autorefresh=$param{autorefresh}">\n];
}

$html .= qq[</head>
<h1>K8055 Interface</h1>
];

my @result;
if ( $param{action} =~ /d(\d)-(.+)/ ) {
    my $value = $2 eq 'on' ? 1 : 0;
    $k8055->writeDigital( $1, $value );
    push( @result, "Setting Digital Port $1 to $2" );
}
elsif ( $param{action} eq 'analogue' ) {
    for ( $i = 1; $i <= $numAnalogueOutputPorts; $i++ ) {
        if ( $param{"a$i"} ne '' ) {
            $k8055->writeAnalogue( $i, $param{"a$i"} );
            push( @result, "Setting Analogue Port $i to " . $param{"a$i"} );
        }
    }
}
elsif ( $param{action} eq 'counter' ) {
    for ( $i = 1; $i <= $numCounters; $i++ ) {
        if ( $param{"c$i"} ne '' ) {
            $k8055->setDebounce( $i, $param{"c$i"} );
            push( @result,
                "Setting Counter $i Debounce to " . $param{"c$i"} . " ms" );
        }
    }
}
elsif ( $param{action} =~ /reset-(\d)/ ) {
    $k8055->resetCounter($1);
    push( @result, "Resetting Counter $1" );
}
elsif ( $param{action} =~ /update-(.)(\d)/ ) {
    if ( $1 eq 'd' ) {
        $k8055->doUpdateDigital($2);
        push( @result, "Now updating digital port $2" );
    }
    elsif ( $1 eq 'a' ) {
        $k8055->doUpdateAnalogue($2);
        push( @result, "Now updating analogue port $2" );
    }
    if ( $1 eq 'c' ) {
        $k8055->doUpdateCounter($2);
        push( @result, "Now updating counter $2" );
    }
}
elsif ( $param{action} eq 'autoupdate' ) {
    $k8055->setUpdatePeriod( $param{autoupdatetime} );
    push( @result,
        "Setting auto-update period to $param{autoupdatetime} seconds" );
}
elsif ( $param{action} eq 'update' ) {
    $k8055->update();
    push( @result, "Requesting manual update" );
}

if ( $#result >= 0 ) {
    $html .= "<h2>Results</h2>\n";
    foreach my $result (@result) {
        $html .= "<p>$result</p>\n";
    }
}

$html .= qq[<h2>Inputs</h2>
<table border="1"><tr><th></th>];
for ( $i = 1; $i <= $numMaxInputPorts; $i++ ) {
    $html .= qq[<th>$i</th>];
}
$html .= qq[</tr><tr><th>Digital</th>];

for ( $i = 1; $i <= $numDigitalInputPorts; $i++ ) {
    $html .= qq[<td align="center">] . $k8055->readDigital($i) . "</td>\n";
}

$html .= qq[</tr><tr><th>Analogue</th>];

for ( $i = 1; $i <= $numAnalogueInputPorts; $i++ ) {
    $html .= qq[<td align="center">] . $k8055->readAnalogue($i) . "</td>\n";
}

$html .= qq[</tr><th>Counters</th>];

for ( $i = 1; $i <= $numCounters; $i++ ) {
    $html .= qq[<td align="center">] . $k8055->readCounter($i) . "</td>\n";
}

$html .= qq[</table>];

$html .= qq[<form name="main" action="$myURL" method="post">
<p><input type="submit" name="action" value="refresh">
<input type="submit" name="action" value="update"></p>
<p><input type="text" name="autorefresh" value="$param{autorefresh}" maxlength="2"><input type="submit" name="action" value="autorefresh"></p>
];

$html .= qq[<h2>Port Updates</h2>
<p>];

for ( $i = 1; $i <= $numDigitalInputPorts; $i++ ) {
    $html .= qq[<input type="submit" name="action" value="update-d$i">\n];
}
for ( $i = 1; $i <= $numAnalogueInputPorts; $i++ ) {
    $html .= qq[<input type="submit" name="action" value="update-a$i">\n];
}
for ( $i = 1; $i <= $numCounters; $i++ ) {
    $html .= qq[<input type="submit" name="action" value="update-c$i">\n];
}

$html .= qq[</p>
<h2>Digital Outputs</h2>
<p>];

for ( $i = 1; $i <= $numDigitalOutputPorts; $i++ ) {
    $html .= qq[<input type="submit" name="action" value="d$i-off">];
    $html .= qq[<input type="submit" name="action" value="d$i-on">];
}

$html .= qq[</p>
<h2>Analogue Outputs</h2>
];

for ( $i = 1; $i <= $numAnalogueOutputPorts; $i++ ) {
    $html .=
      qq[<p>Port $i: <input type="text" name="a$i" value="" maxlength=3></p>];
}
$html .= qq[<p><input type="submit" name="action" value="analogue"></p>\n];

$html .= qq[<h2>Counters</h2>
<p>];

for ( $i = 1; $i <= $numCounters; $i++ ) {
    $html .= qq[<input type="submit" name="action" value="reset-$i">\n];
}

$html .= "</p>";
for ( $i = 1; $i <= $numCounters; $i++ ) {
    $html .=
      qq[<p>Counter $i: <input type="text" name="c$i" value="" maxlength=4></p>];
}
$html .= qq[<p><input type="submit" name="action" value="counter"></p>\n];

$html .= qq[<h2>Miscellaneous</h2>
<p>Update Time: <input type="text" name="autoupdatetime" value="" maxlength=3></p>
<p><input type="submit" name="action" value="autoupdate"></p>
</form>];

$html .= "</body></html>";
return $html;
