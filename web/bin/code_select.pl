
=begin comment

This script allows web access to select the mh/code/common files,
allowing on-the-fly activation of standardized MisterHouse code files.

Original version by Tim Doyle <tim@greenscourt.com> 9/23/2002
Modified by Steve Switzer on Dec 4, 2002 (Added EDIT / help links and color indicators to config parms. Added alternating bgcolors for table rows, removed table borders.)

=cut

$^W = 0;    # Avoid redefined sub msgs

my $search = shift;
$search =~ s/search=//;
my @parms = @ARGV;

return ( $search or !@parms ) ? &select_code_form : &select_code_update;

sub select_code_form {

    my $html = &html_header('Select Common Code');

    $html = qq|
<HTML><HEAD><TITLE>MisterHouse Common Code Activation</TITLE>
<script language="javascript">
function edit_parms(parmlist,filename) {
  window.open("/bin/iniedit.pl?edit_list="+parmlist+"&file="+filename,"select_iniedit","width=550,height=300,left=0,top=0,scrollbars=1,resizable=0")
}
function openparmhelp(parm1){
  window.open("/RUN;&iniedit_help('" + parm1 + "')","help","width=350,height=500,left=0,top=0,scrollbars=1,resizable=0")
}
</script>
</HEAD>
<BODY>
<a name='Top'></a>
$html
The following are standardized MisterHouse code files which need no
modifications, but which may require settings in your ini file to
activate properly.|;
    $html .= qq| Simply check those that you'd like to run and
they'll be automatically activated within MisterHouse.|
      if $Authorized eq 'admin';
    $html .=
      qq|<br><font color=red><b>Read-Only</b>: <a href="/bin/SET_PASSWORD">Login as admin</a> to edit</font>|
      unless $Authorized eq 'admin';
    $html .= qq|
<CENTER><FORM ACTION="/bin/code_select.pl" method=post>
<TABLE BORDER="0" cellspacing="0" cellpadding="0" width="100%">
<tr><td colspan="2"><B>Search</B> (file or description): <input  align='left' size='25' name='search'>&nbsp;<INPUT TYPE='submit' VALUE='Search'>
|;
    $html .= "&nbsp;Searching for: \"$search\"" if $search;
    $html .= "</td>";

    my %files_selected = map { $_, 1 }
      &file_read( "$config_parms{data_dir}/$config_parms{code_select}", 2 );
    my %standard_parms = map { $_, 1 }
      qw(html_dir code_dir code_dir_common data_dir http_port debug);
    opendir( MYDIR, $config_parms{code_dir_common} )
      or return
      "Error, can not open directory $config_parms{code_dir_common}.\n";
    my @files_read = readdir(MYDIR);
    close MYDIR;
    my ( %modules, %categories );

    # Parse code files for description, category, and config_parms
    for my $file (@files_read) {
        next unless $file =~ /.pl$/i;
        my $checked = ( $files_selected{$file} ) ? 'CHECKED' : '';
        $checked .= ' disabled' unless $Authorized eq 'admin';
        my $description = '';
        my %file_parms;
        my $parms_list;
        my $category = 'Other';    #Default
        for my $line ( &file_read("$config_parms{code_dir_common}/$file") ) {
            $description .= $1 if $line =~ /^\#\@(.*)/;
            $category = $1 if $line =~ /^#\s*Category\s*=\s*(.*)/i;
            $category =~ s/\s+$//;    # Drop trailing whitespace

            # Ignore $config_parm{$xyz} entries
            while ( $line =~ /config_parms{([^\$]+)}/g ) {
                $file_parms{$1}++ unless $standard_parms{$1};
            }
        }
        next
          if $search
          and !(
               $category =~ /$search/i
            or $file =~ /$search/i
            or $description =~ /$search/i
          );

        if (%file_parms) {
            my $description_part;
            for my $f_parm ( sort keys %file_parms ) {
                if ( $description_part ne '' ) {
                    $description_part .= ", ";
                    $parms_list       .= ',';
                }
                $description_part .=
                  "<a href='#' onclick=\"openparmhelp('$f_parm');return(false);\">";
                if ( $config_parms{$f_parm} ) {
                    $description_part .= "<font color=black>$f_parm</font>";
                }
                else {
                    $description_part .=
                      "<font color=red><i>$f_parm</i></font>";
                }
                $description_part .= "</a>";
                $parms_list .= $f_parm;
            }
            $description .=
              "<br><a href='#' onclick=\"edit_parms('$parms_list','$file');return(false);\">EDIT</a>"
              if ( $Authorized eq 'admin' );
            $description .= "&nbsp;<b>Config parms</b>: $description_part";
        }

        $categories{$category}++;
        $modules{"$category|$file"} =
            qq|<TR bgcolor="#rowbgcolor#"><TD valign=top nowrap> |
          . qq|<INPUT TYPE="HIDDEN" NAME="${file}_previous" VALUE="$files_selected{$file}"> |
          . qq|<INPUT TYPE="checkbox" NAME="$file" $checked> |
          . qq|<a href=/bin/browse.pl?/code/common/$file>$file</a></TD><TD>$description</TD></TR>|;
    }

    # Add Category index
    $html .= "<tr><td colspan=2><B>Category Index: <B>\n";
    for my $category ( sort { lc($a) cmp lc($b) } keys %categories ) {
        $html .= "<a href='#$category'>$category</a>\n";
    }
    $html .= "</tr></td>\n";

    # Create html
    my $lastcategory = '';
    my $submit_html  = "<INPUT TYPE='submit' VALUE='Process selected files'";
    $submit_html .= ' disabled' unless $Authorized eq 'admin';
    $submit_html .= ">";
    my $rowcount = 0;
    for my $module ( sort { lc($a) cmp lc($b) } keys %modules ) {
        my ($category) = $module =~ /(.*)\|.*/;
        if ( $category ne $lastcategory ) {
            $html .=
              "<TR bgcolor='#AAAAAA'><TD><B>$category</B> (<a name='$category' href='#Top'>back to top</a>)</TD><TD>$submit_html</TD></TR>";
            $lastcategory = $category;
            $rowcount     = 0;
        }
        $html .= "$modules{$module}\n";
        my $rowbgcolor = "#FFFFFF";
        if ( ( $rowcount % 2 ) == 1 ) { $rowbgcolor = "#DFDFDF"; }
        $html =~ s/#rowbgcolor#/$rowbgcolor/i;
        $rowcount++;
    }
    $html .= "</TABLE></FORM></CENTER></BODY></HTML>\n";

    # Load up inihelp function, if not loaded yet
    unless ( $main::{'iniedit_help'} ) {
        my $code = &file_read("../web/bin/iniedit.pl");
        eval $code;
        print "Loading iniedit help function. e=$@\n";
    }

    return &html_page( '', $html );
}

sub select_code_update {
    my ( $module, $module_data, $html );

    # Allow un-authorized users to browse, but only admin users to update
    return 'Not authorized to make updates' unless $Authorized eq 'admin';

    my %modules_selected = map { $_, 1 }
      &file_read( "$config_parms{data_dir}/$config_parms{code_select}", 2 );

    my ( %modules_added, %modules_dropped, %modules_deleted );

    # Look for deleted files
    for $module ( keys %modules_selected ) {
        unless ( -e "$config_parms{code_dir_common}/$module" ) {
            $modules_deleted{$module}++;
            delete $modules_selected{$module};
        }
    }

    for $module (@parms) {

        # Require _previous parm to show up first
        if ( $module =~ /(\S+)_previous=(.*)/ ) {
            if ($2) {
                $modules_dropped{$1}++;
                delete $modules_selected{$1};
            }
        }
        elsif ( $module =~ /(\S+)=on/ ) {
            if ( $modules_dropped{$1} ) {
                delete $modules_dropped{$1};
            }
            else {
                $modules_added{$1}++;
            }
            $modules_selected{$1}++;
        }
    }
    my $modules_added    = join "\n", sort keys %modules_added;
    my $modules_dropped  = join "\n", sort keys %modules_dropped;
    my $modules_deleted  = join "\n", sort keys %modules_deleted;
    my $modules_selected = join "\n", sort keys %modules_selected;

    my $file = "$config_parms{data_dir}/$config_parms{code_select}";
    &file_backup($file);
    &file_write( $file,
            "# This file is auto-generated by web code_select.pl.\n"
          . "# It lists all files you have selected from the common code dir\n"
          . $modules_selected );

    run_voice_cmd "reload code" if $modules_added or $modules_dropped;

    $html = "<H1>MisterHouse Code Activation Confirmation</H1>";
    $html .=
      "<b>The following code files are now      activated:</b><P><PRE>$modules_added</PRE>";
    $html .=
      "<b>The following code files are now   de-activated:</b><P><PRE>$modules_dropped</PRE>";
    $html .=
      "<b>The following code were deleted:  </b><P><PRE>$modules_deleted</PRE>"
      if $modules_deleted;
    $html .=
      "<b>Here are all your activated files:</b><P><PRE>$modules_selected</PRE>";

    return &html_page( '', $html );
}
