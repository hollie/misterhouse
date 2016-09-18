
=begin comment

This code is used to list and manipulate the callerid list.

  http://mh/bin/callerid.pl


# config_parms: phone_auth_group = additional user to admin call records

=cut

use strict;
$^W = 0;    # Avoid redefined sub msgs
my $authorized = '';
$authorized = $::config_parms{phone_auth_group}
  if $::config_parms{phone_auth_group};

#$::Debug{Phone} = 1;

return &web_callerid_list();

my (@file_data);

sub web_callerid_list {

    # Create header and 'add a entry' form
    my $html = &html_header('CallerID Menu');
    $html = qq|
<HTML><HEAD><TITLE>CallerID Menu</TITLE>
<script>
function delconfirm(num) {
  if (!confirm('Are you sure you wish to delete the entry for \\''+num+'\\'?\\n\\nClick OK to delete\\nOtherwise, click CANCEL')) {return(false);}
}
</script>
</HEAD><BODY>\n<a name='Top'></a>$html
Use this page to review or update your $::config_parms{caller_id_file} file.|;
    $html .=
      qq|<br><font color=red><b>Read-Only</b>: <a href="/bin/SET_PASSWORD">Login as admin|
      unless ( ( $Authorized eq $authorized ) or ( $Authorized eq 'admin' ) );
    $html .= qq|or $authorized|
      if $authorized
      and ( ( $Authorized ne $authorized ) and ( $Authorized ne 'admin' ) );
    $html .= qq|</a> to edit</font>|
      unless ( ( $Authorized eq $authorized ) or ( $Authorized eq 'admin' ) );
    $html .= qq|A backup is made and comments and record order are preserved.
To update existing entries, enter/change the field and hit Enter.|

      if ( ( $Authorized eq $authorized ) or ( $Authorized eq 'admin' ) );

    # Get parameters, make available for processing
    my %request;
    for my $args (@ARGV) {
        my ( $arg1, $arg2 ) = $args =~ /^([^=]+)=(.*)$/;
        $request{$arg1} = $arg2;
    }

    # Decide how to populate create form
    my $c_number     = '1235551212';
    my $c_name       = 'John Doe';
    my $c_wav        = '*';
    my $c_group      = '*';
    my $display_help = "";

    $c_number = $request{cidnumber} if $request{cidnumber} ne '';
    $c_name   = $request{cidname}   if $request{cidname} ne '';
    $c_wav = $Caller_ID::wav_by_number{$c_number}
      if $Caller_ID::wav_by_number{$c_number} ne '';
    $c_group = $Caller_ID::group_by_number{$c_number}
      if $Caller_ID::group_by_number{$c_number} ne '';
    $display_help = $request{help} if $request{help} ne '';

    #use only the 'new format' tab delimited fields
    my @headers = ( "Number", "Name", "Wav", "Group" );
    my $headers = @headers;

    #display help on top, not pop-up to prevent audrey from dying
    if ($display_help) {

        $html .=
          "<br><br><font color=blue><b>HELP Information on $display_help field:</b><br><i>";
        $html .= &web_callerid_help($display_help);
        $html .= "</i><br>\n";

    }

    if ( ( $Authorized eq $authorized ) or ( $Authorized eq 'admin' ) ) {
        $html .= "<table border>\n";
        $html .= "<tr><td></td>";
        for my $header ( '', @headers ) {
            $html .=
              qq[<td><a href="/bin/callerid.pl?help=$header&cidnumber=$c_number&cidname=$c_name];
            $html .= "&showlist=0" if $request{showlist} eq '0';
            $html .= qq[">$header</a></td>];
        }
        $html .= "</tr>\n";

        $html .= qq|<tr><td>
<form action='/bin/set_func.pl' method=post>
<td><input type=submit value='Create'></td>
<input name='func' value="web_callerid_add"  type='hidden'>
<input name='resp' value="/bin/callerid.pl" type='hidden'>
<td><input type=input name=number   size=12 value='$c_number'></td>
<td><input type=input name=name     size=15 value="$c_name"></td>
<td><input type=input name=wav      size=20 value='$c_wav'></td>
<td><input type=input name=group    size=10 value='$c_group'></td>
</td></tr></form></table><br>
|;

    }

    # Parse table data
    undef @file_data;
    @file_data = &file_read( $::config_parms{caller_id_file} );
    my %cid_pos;
    my $pos = 0;
    for my $record (@file_data) {

        # Do not list comments
        unless ( $record =~ /^\s*\#/
            or $record =~ /^\s*$/
            or $record =~ /^Format *=/ )
        {
            my (@cid_info) = split( ',|\t+', $record );
            my ( $number, $name, $wavfile, $group ) = @cid_info;
            $group =~ s/\s*$//;
            push @{ $cid_pos{$group} }, $pos;
        }
        $pos++;
    }
    if ( $request{showlist} ne '0' ) {

        # Add an index
        $html .= "<tr><td><a href=/bin/callerid.pl>Refresh</a>\n";
        $html .= "<B>Group Index: <B>\n";
        for my $type ( sort keys %cid_pos ) {
            $html .= "<a href='#$type'>$type</a>&nbsp;\n";
        }
        $html .= "</td></tr></table>\n";

        # Sort in type order
        for my $type ( sort keys %cid_pos ) {

            my @headers = ( "Number", "Name", "Wav", "Group" );
            my $headers = @headers;

            $html .= "<table border><tr><td colspan=$headers><B>$type</B>\n";
            $html .=
              "(<a name='$type' href='#Top'>back to top</a>)</td></tr>\n";

            $html .= "<tr>";
            for my $header ( '', @headers ) {
                $html .=
                  qq[<td><a href="/bin/callerid.pl?help=$header">$header</a></td>];
            }
            $html .= "</tr>\n";

            for my $pos ( @{ $cid_pos{$type} } ) {
                my $record = $file_data[$pos];
                my @cid_info = split( ',|\t+', $record, $headers );

                $html .= "<tr>";
                $html .= "<td>";
                $html .=
                  "    <a href=\"/SUB;/bin/callerid.pl?web_callerid_delete($pos)\" onclick=\"return delconfirm('$cid_info[0]');\"><img border=0 src='/graphics/ico_recycle.gif' alt2='Delete'></a>&nbsp;"
                  if ( ( $Authorized eq $authorized )
                    or ( $Authorized eq 'admin' ) );
                $html .= "</td> ";
                for my $field ( 0 .. $headers - 1 ) {
                    $html .= &html_form_input_set_func(
                        'web_callerid_set_field', "/bin/callerid.pl",
                        "$pos,$field",            $cid_info[$field]
                    );
                }
                $html .= "</tr>\n";
            }
            $html .= "</table><br>\n";

        }
    }
    return &html_page( '', $html );
}

sub web_callerid_set_field {
    my ( $pos_field, $data ) = @_;
    my $sep = "\t";
    return &html_page( '', 'Not authorized to make updates' )
      unless ( ( $Authorized eq $authorized ) or ( $Authorized eq 'admin' ) );
    my ( $pos, $field ) = $pos_field =~ /(\d+),(\d+)/;

    my $record = @file_data[$pos];

    my @cid_info = split( ',|\t', $record );
    unless ( $record =~ /,|\t/ ) {
        @cid_info = split( '\s+', $record, 2 );
        $sep = " ";
    }
    $cid_info[$field] = $data;

    $record = '';
    while (@cid_info) {
        my $cid = shift @cid_info;
        $cid .= $sep if @cid_info;
        $record .= $cid;
    }

    $file_data[$pos] = $record;
    print_log "callerid.pl  p=$pos f=$field d=$data r=$record\n"
      if $::Debug{Phone};

    &cid_file_write( $::config_parms{caller_id_file}, \@file_data );
    return 0;
}

sub web_callerid_delete {
    my ($pos) = @_;
    return &html_page( '', 'Not authorized to make updates' )
      unless ( ( $Authorized eq $authorized ) or ( $Authorized eq 'admin' ) );
    my $pos2 = @file_data;
    $file_data[$pos] = '';
    &cid_file_write( $::config_parms{caller_id_file}, \@file_data );
    return &http_redirect('/bin/callerid.pl');
}

sub web_callerid_add {
    my (@parms) = @_;

    # Allow un-authorized users to browse only (if listed in password_allow)
    return &html_page( '', 'Not authorized to make updates' )
      unless ( ( $Authorized eq $authorized ) or ( $Authorized eq 'admin' ) );

    # Process form
    if (@parms) {
        my $record;
        print "db " if $::Debug{Phone};
        for my $p (@parms) {
            $record .= "$p\t";
            print "[$p]\\t";
        }
        chop $record;    # get rid of last tab
                         #$record .= "\n";
        print "\n"               if $::Debug{Phone};
        print "db [r=$record]\n" if $::Debug{Phone};
        push( @file_data, $record );
        &cid_file_write( $::config_parms{caller_id_file}, \@file_data );
    }
    return 0;
}

sub web_callerid_help {
    my ($field) = @_;

    my %help = (
        Number =>
          'Telephone number, without formatting or spaces. Older format may use dashes.',
        Name =>
          'The caller ID name of the entry (what will be announced and logged)',
        Group =>
          'The caller ID group this entry belongs to. Add to the "rejected" group for some special processing. :)',
        Wav =>
          'Location and name of a wav file to play over the PA, rather than announcing the callers name.',
        Data => 'Caller ID name or WAV file to play. (older format)'
    );

    my $help = $help{$field};

    return $help;

}

sub cid_file_write {
    my ( $file, $data_ptr ) = @_;
    print "Writing out to callerid file $file\n";
    &file_backup($file);
    &file_write( $file, join( "\n", @$data_ptr ) );

}

