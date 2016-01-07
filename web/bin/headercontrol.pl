
=begin comment

This code is used to list and manipulate your header control list.
	
  http://localhost:8080/bin/headercontrol.pl
	Larry Roudebush
=cut

use strict;
$^W = 0;
my ( $function, @parms ) = @ARGV;

if ( $function eq 'func=save_header_control_list' ) {

    #print "Funct:$function Parms:@parms\n";
    &save_header_control_list(@parms);
}

my $phone_dir =
  "$config_parms{data_dir}/headerallow.tab";    # Avoid redefined sub msgs
my $form_type = &html_form_select( 'type', 0, 'True', 'True', 'False', );
return &headercontrol_list();
my $GuestValueTrue;
my $familyValueTrue;
my $GuestValueFalse;
my $familyValueFalse;
my $HeaderTitleVariable;
my $AllowHeader;
my $data;
my $counter;
my $writedata;
my $TmpData;
my $codedhtmlrootdir;

sub headercontrol_list {

    my $pos = 0;    # Add an index
    my $html_calls;
    my @calls = &read_headercontrol_list;
    for my $r (@calls) {
        my ( $HeaderName, $family, $guest ) =
          $r =~ /Name=(.*) Family=(.*) Guest=(.*)/;

        #print "$HeaderName, $family, $guest\n";
        if ( $Authorized eq 'admin' ) {
            $AllowHeader = "";

            #print "Is Authorized";
        }
        else {
            $AllowHeader         = " DISABLED";
            $HeaderTitleVariable = "NOT LOGGED IN AS ADMIN!";

            #print "Is NOT Authorized";
        }
        if ( $guest =~ /True/i ) {
            $GuestValueTrue  = " SELECTED";
            $GuestValueFalse = "";

            #print "$HeaderName:Guest is $guest\n";
        }
        else {
            $GuestValueTrue  = "";
            $GuestValueFalse = " SELECTED";
        }
        if ( $family =~ /True/i ) {
            $familyValueTrue  = " SELECTED";
            $familyValueFalse = "";

            #print "$HeaderName:Fam is true\n";
        }
        else {
            $familyValueTrue  = "";
            $familyValueFalse = " SELECTED";

        }

        $html_calls .=
          "<tr id='resultrow' vAlign=center bgcolor='#EEEEEE' class='wvtrow'><td nowrap>$HeaderName</td><td><select name='$HeaderName'$AllowHeader><option value=True$familyValueTrue>True</option><option value=False$familyValueFalse>False</option></select></td><td><select name='$HeaderName'$AllowHeader><option value=True$GuestValueTrue>True</option><option value=False$GuestValueFalse>False</option></select></td>";
        $pos = $pos + 1;
    }

    my $html = "<html>
<head>
<style>
TR.wvtrow {font-family:Arial; font-size:11; color:#000000}
TR.wvtheader {font-family:Tahoma; font-size:11; color:#101010}
</style>
</head>
<body>\n" . &html_header('Header Controller') . "
<table width=100% cellspacing=2><tbody><font face=COURIER size=2>
<tr id='resultrow' bgcolor='#9999CC' class='wvtheader'>
<th align='left'>Header Name $HeaderTitleVariable</th>
<th align='left'>Allow Family? $AllowHeader</th>
<th align='left'>Allow Guest? $AllowHeader</th>
<form action='/bin/headercontrol.pl' method='post'>
<input name='func' value='save_header_control_list' type='hidden'>


$html_calls
<input type='submit' name='submitbutton' value='Submit'>

<td></form><tr>
</body>
";

}

sub header_file_write {

    my ($data_ptr) = @_;

    #print "Writing output $data_ptr to $file\n";
    $data_ptr = "$data_ptr\n";
    logit( "$config_parms{data_dir}/headerallow.tab", $data_ptr, 0 );
}

sub save_header_control_list {
    unlink "$config_parms{data_dir}/headerallow.tab";
    my (@headerinfo) = @_;
    $counter = 0;

    #print_log "PassedParms:@headerinfo";
    #@headerinfo = split(/true|false/, @headerinfo);
    for my $record (@headerinfo) {

        #$record =~ s/\=/\t/;
        #print_log "WRI:$writedata";
        if ( $counter >= 2 ) {

            #print_log "counter is $counter:$writedata";
            #now we need to write this to the file
            my ( $HeaderToWrite, $FamilyValue, $junk, $GuestValue ) =
              $writedata =~ /(.*)=(true|false)(.*)=(true|false)/i;

            #print_log "Header:$HeaderToWrite, $FamilyValue, $GuestValue";
            my $WritingData = "$HeaderToWrite\t$FamilyValue\t$GuestValue";
            &header_file_write($WritingData);
            $counter   = 1;
            $writedata = "";
            $writedata .= $record;

        }
        else {
            $writedata .= $record;
            $counter++;
        }

    }

}

sub read_headercontrol_list {

    my $rootdir = "$Pgm_Path";
    $rootdir =~ s/\/bin//;

    #print "myroot:$rootdir\n";
    if ( $config_parms{html_dir} =~ /.\/../ ) {

        #print "Non hardcoded web directory";
        my $roothtmldir = $config_parms{html_dir};
        $roothtmldir =~ s/.\/..//;
        $codedhtmlrootdir = "$rootdir$roothtmldir";

        #print "$codedhtmlrootdir\n";
    }
    else {
        $codedhtmlrootdir = "$config_parms{html_dir}";
    }

    if ( -e "$config_parms{data_dir}/headerallow.tab" ) {

    }
    else {
        print_log "Generating header allow file";
        find( \&GenerateHeaderFiles, "$codedhtmlrootdir" );    #Need PGM ROOT!
        file_write( "$config_parms{data_dir}/headerallow.tab", $TmpData );
    }

    #print "Reading Header Control File\n";
    my (@header);
    my $header_file = "$config_parms{data_dir}/headerallow.tab";

    #print_log "$header_file";
    open( MYFILE, $header_file )
      or die "Error, could not open file $header_file: $!\n";
    while (<MYFILE>) {
        my ( $HeaderName, $family, $guest );
        ( $HeaderName, $family, $guest ) = $_ =~ /(.*)\t(.*)\t(.*)/;
        $HeaderName =~ s/\s+$//;

        #ok, we have the number and name is filled with the rest, lets break up name a little

        #print_log "HeaderName;$HeaderName, Family;$family, Guest;$guest\n";
        push @header,
          sprintf( "Name=%s Family=%s Guest=%s", $HeaderName, $family, $guest );

    }
    close MYFILE;
    return @header;
}
