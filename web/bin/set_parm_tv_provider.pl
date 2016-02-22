
=begin comment

set_parm_tv_provider.pl - a CGIish script for editing tv listings configuration parameters

02/20/2003	Created by David Norwood

TODO

Add support for multiple listings databases
Modify get_tv_grid to list channel line-ups
Add support for the other tv listings parameters

=cut

$^W = 0;    # Avoid redefined sub msgs

# Process arguments
my %args;
foreach (@ARGV) {

    #print "$_\n";
    if ( my ( $key, $value ) = $_ =~ /([^=]+)=(.*)/ ) {
        $args{$key} = $value;
    }
}

return edit();

sub edit {

    # Create header
    my $html = &html_header('Configure TV Listings Settings');
    $html = qq|
	<HTML><HEAD><TITLE>TV Listings Configuration</TITLE></HEAD><BODY>\n<a name='Top'></a>$html
	Use this page to review or update your TV listings settings.
	A backup of your .ini file is made and comments and record order are preserved.<p>
    |;

    # Create zipcode form
    $args{zipcode} = $config_parms{zip_code} unless $args{zipcode};
    $html .= qq|
		<form name=zipfm>Zipcode <input type=text name="zipcode" value="$args{zipcode}" onChange="form.submit()">
		</form> <p><hr>
    |;

    # Get list of providers
    my $pgm = ($OS_win) ? 'get_tv_grid' : './get_tv_grid';
    my $output = `$pgm -zip $args{zipcode} -get_providers `;
    print "p=$pgm o=$output\n";
    my %providers;
    foreach ( split "\n", $output ) {
        if ( my ( $id, $name ) = /^Provider (\d+)\s+(.+)/ ) {
            $providers{$id} = $name;
        }
    }

    if ( $Authorized eq 'admin' ) {

        # Update zipcode if changed
        if ( $args{zipcode} and $args{zipcode} ne $config_parms{zip_code} ) {
            my %parms = ( 'zip_code', $args{zipcode} );
            &write_mh_opts( \%parms );
        }

        # Update tv_provider_name if changed
        if (    $args{provider}
            and $providers{ $args{provider} }
            and $providers{ $args{provider} } ne
            $config_parms{tv_provider_name} )
        {
            my %parms = (
                'tv_provider', '', 'tv_provider_name',
                $providers{ $args{provider} }
            );
            print "db writing out new parm: $config_parms{tv_provider_name}\n";
            &write_mh_opts( \%parms );
            &read_parms;    # Re-read parms
        }
    }
    else {
        $html .= "<br>Not authorized to make .ini parm updates<br>\n";
    }

    # Create provider form
    $html .= 'Pick a provider: <p>
		<form name=fm><select name="provider" size="15" onChange="form.submit()">';
    foreach ( split "\n", $output ) {
        next unless ( my ( $id, $name ) = /^Provider (\d+)\s+(.+)/ );
        $html .= '<option value="' . $id . '"';
        $html .= ' selected'
          if $id eq $config_parms{tv_provider}
          or $name eq $config_parms{tv_provider_name};
        $html .= '>'
          . $name
          . '&nbsp&nbsp&nbsp&nbsp&nbsp&nbsp&nbsp&nbsp&nbsp&nbsp' . "\n";
    }
    $html .= '</select></form></html>';

    #print $html;
    return $html;
}
