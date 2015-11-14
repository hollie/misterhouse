
=begin comment

This code is used to list and manipulate your blocked caller list.

  http://localhost:8080/bin/rejectcall.pl

=cut

use strict;
$^W = 0;
my $phone_dir = "$config_parms{data_dir}/phone";    # Avoid redefined sub msgs

return &rejected_call_list();

sub rejected_call_list {
    my $html = &html_header('Rejected Call List');

    my $pos = 0;                                    # Add an index
    my $html_calls;
    my @calls = read_reject_call_list;
    for my $r (@calls) {
        my ( $number, $name, $sound, $type ) =
          $r =~ /number=(.+) name=(.+) sound=(.*) type=(.*)/;
        $html_calls .=
          "<tr id='resultrow' vAlign=center bgcolor='#EEEEEE' class='wvtrow'><td nowrap><a href=/SUB;rej_call_item_delete($pos)>Delete</a>   $number</td><td nowrap>$name</a></td><td nowrap>$sound</td><td nowrap>$type</td></tr>";
        $pos = $pos + 1;
    }

    my $html = "<html>
<head>
<style>
TR.wvtrow {font-family:Arial; font-size:11; color:#000000}
TR.wvtheader {font-family:Tahoma; font-size:11; color:#101010}
</style>
</head>
<body>\n" . &html_header('Rejected Call List') . "
<table width=100% cellspacing=2><tbody><font face=COURIER size=2>
<tr id='resultrow' bgcolor='#9999CC' class='wvtheader'>
<th align='left'>Number</th>
<th align='left'>Name</th>
<th align='left'>Sound File</th>
<th align='left'>Type</th>
$html_calls
</font></tbody></table>
</body>
";
    my $form_type =
      &html_form_select( 'type', 0, 'Friend', 'Friend', 'Business', 'reject',
        'Family' );

    #form action='/bin/items.pl?add' method=post>

    #list is created now lets try to edit the list
    $html .= qq|<tr>
<form action='/bin/set_func.pl' method=post><td>
<input type=submit value='Add'>
<input name='func' value="rej_call_item_add"  type='hidden'>
<input name='resp' value="/bin/rejectcall.pl" type='hidden'>

<input type=input name=Number  size=10 value='0123456789'>
<input type=input name=Name     size=10 value='John Doe'>
<input type=input name=SoundFile    size=10 value='*'>
$form_type
<td></form><tr>
| if $Authorized eq 'admin';
}

sub rej_call_item_add {
    my (@parms) = @_;

    # Allow un-authorized users to browse only (if listed in password_allow)
    return &html_page( '', 'Not authorized to make updates' )
      unless $Authorized eq 'admin';

    # Process form
    if (@parms) {
        my $record;
        for my $p (@parms) {
            $p =~ s/\s*$//;    #trim the fat off the end
            $record .= "$p\t\t";
        }

        #print "db r=$record\n";
        &rej_call_file_write( "$phone_dir/phone.caller_id.list", $record );
    }
    return 0;
}

sub rej_call_file_write {
    my ( $file, $data_ptr ) = @_;

    #print "Writing output $data_ptr to $file\n";
    $data_ptr = "$data_ptr\n";
    logit( $file, $data_ptr, 0 );
}

sub rej_call_item_delete {
    my ($deletepos) = @_;
    my $filePos = 0;
    my $line;
    my $writeparms;
    my ( $number, $name, $sound, $type );

    #print "And you thought i would delete something?$deletepos\n";
    my @ReadRejFile = read_reject_call_list;
    unlink "$phone_dir/phone.caller_id.list";
    for $line (@ReadRejFile) {
        ( $number, $name, $sound, $type ) =
          $line =~ /number=(.+) name=(.+) sound=(.*) type=(.*)/;

        $number =~ s/\s*$//;    #trim the fat off the end
        $name =~ s/\s*$//;      #trim the fat off the end
        $sound =~ s/\s*$//;     #trim the fat off the end
        $type =~ s/\s*$//;      #trim the fat off the end
        $writeparms = "$number\t\t$name\t\t$sound\t\t$type";
        if ( $filePos ne $deletepos ) {
            &rej_call_file_write( "$phone_dir/phone.caller_id.list",
                $writeparms );

        }

        $filePos = $filePos + 1;
    }

    #print "$filePos: is zero file check\n";
    $filePos = $filePos - 1;
    if ( $filePos == 0 ) {
        $writeparms = "0123456789\t\tTest\t\t*\t\treject";
        &rej_call_file_write( "$phone_dir/phone.caller_id.list", $writeparms );
    }

    return &http_redirect('/bin/rejectcall.pl');
}
