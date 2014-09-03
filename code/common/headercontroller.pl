# Category = MisterHouse

#@ This code is used to generate a header control file that limits
#@ what type of password can access certain pages in the IA5 web directory.
#@ It allows you to set access based on family and or guest password.

use File::Find;
my $TmpData;
my $codedhtmlrootdir;
$v_Geat_Header_Files = new Voice_Cmd 'Get Header Files.';
if ( said $v_Geat_Header_Files) {
    my $rootdir = "$Pgm_Path";
    $rootdir =~ s/\/bin//;
    print "myroot:$rootdir\n";
    if ( $config_parms{html_dir} =~ /\.\/\.\./ ) {
        print "Non hardcoded web directory";
        my $roothtmldir = $config_parms{html_dir};
        $roothtmldir =~ s/\.\/\.\.//;

        $codedhtmlrootdir = "$rootdir$roothtmldir";
        print "$codedhtmlrootdir\n";
    }
    else {
        $codedhtmlrootdir = "$config_parms{html_dir}";
    }
    if ( -e "$config_parms{data_dir}/headerallow.tab" ) {

        #speak "Warning, Deleted header control file";
        print_log "Warning, Deleted header control file";
        unlink "$config_parms{data_dir}/headerallow.tab";
    }
    find( \&GenerateHeaderFiles, "$codedhtmlrootdir" );    #Need PGM ROOT!
    file_write( "$config_parms{data_dir}/headerallow.tab", $TmpData ) &
      main::speak "Header control file generation is complete";
}

sub Search_Header_Allow {
    my $AllowHeaderPassage = "";
    my ($Header_name)      = @_;
    my $header_file        = "$config_parms{data_dir}/headerallow.tab";

    #print_log "$header_file";
    if (   ( $Authorized eq 'admin' )
        or ( $config_parms{Use_Header_Control} = 0 ) )
    {
        $AllowHeaderPassage = 1;

        #print_log "$Authorized is authorized";
    }
    else {
        open( MYFILE, $header_file )
          or die "Error, could not open file $header_file: $!\n";
        while (<MYFILE>) {
            my ( $HeaderName, $family, $guest );
            ( $HeaderName, $family, $guest ) = $_ =~ /(.*)\t(.*)\t(.*)/;
            if ( $Header_name eq $HeaderName ) {

                #print "found header:$Header_name, $Authorized:Fam:$family - Guest:$guest\n";
                if ( ( $Authorized =~ /family/i ) and ( $family =~ /True/i ) ) {

                    #print_log "Allowing Passage";
                    $AllowHeaderPassage = 1;

                }
                elsif ( ( $Authorized =~ /guest/i ) and ( $guest =~ /True/i ) )
                {
                    #print_log "Allowing Passage";
                    $AllowHeaderPassage = 1;

                }
                else {
                    $AllowHeaderPassage = 0;

                    #print_log "NOT Allowing Passage:$AllowHeaderPassage";
                }
            }

        }
        close MYFILE;
    }
    if (    ( $AllowHeaderPassage eq "" )
        and ( $config_parms{Use_Header_Control} = 1 ) )
    {
        print_log
          "Could not find -$Header_name- in control file.$AllowHeaderPassage";
    }
    if ( $AllowHeaderPassage == 1 ) {

        #print_log "Header Returned Authorized:$AllowHeaderPassage";
    }
    else {
        #print_log "Header Returned Unathorized:$AllowHeaderPassage";
    }
    return $AllowHeaderPassage ? 1 : 0;

}

sub GenerateHeaderFiles {
    my $file           = $File::Find::name;
    my $search_pattern = "html_header";
    open F, $file or print "couldn't open $file\n";
    while (<F>) {
        if (m/($search_pattern)/o) {
            my ( $line, $Test ) = /html_header\('(.*)'\)/;
            if ( $line ne "" ) {    #HeaderName Family Guest
                $TmpData = $TmpData . "$line\ttrue\ttrue\n";
            }
            last;
        }
    }
    close F;
}

sub html_header {
    my ($text) = @_;
    if ( &Search_Header_Allow($text) ) {

        #print_log "ReturnedHTTPGood:" . &Search_Header_Allow($text);
        $text = 'Generic Header' unless $text;

        my $color = $config_parms{html_color_header};
        $color = '#9999cc' unless $color;

        return qq[
$config_parms{html_style}
<table width=100% bgcolor='$color'>
<td><center>
<font size=3 color="black"><b>
$text
</b></font></center>
</td>
</table><br>
];
    }
    else {
        #print_log "ReturnedHTTPNG:" . &Search_Header_Allow($text);
        my ($text) = @_;
        $text = 'Sorry Unauthorized to View This Function';

        my $color = $config_parms{html_color_header};
        $color = '#9999cc' unless $color;

        return qq[
$config_parms{html_style}
<table width=100% bgcolor='$color'>
<td><center><meta http-equiv="refresh" content="0;URL=/ia5/blank.html">
<font size=3 color="black"><b>
$text
</b></font></center>
</td>
</table><br>
];
    }
}
