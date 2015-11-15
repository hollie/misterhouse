
=begin comment

This script allows web access to disable code files in your code_dir files.
Similar to code_select.pl, except of disabling code_dir_common files by default,
this code leaves code_dir files enabled by default.

Modified by Steve Switzer on Dec 4, 2002 (Added EDIT / help links and color indicators to config parms. Added alternating bgcolors for table rows, removed table borders.)

=cut

$^W = 0;    # Avoid redefined sub msgs

my $search = shift;
$search =~ s/search=//;
my @parms = @ARGV;

return ( $search or !@parms ) ? &select_code_form : &select_code_update;

sub select_code_form {

    my $html = &html_header('Select User Code');

    $html = qq|
<HTML><HEAD><TITLE>MisterHouse User Code Activation</TITLE>
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
The following fils are all the code files in you code_dir list:  $config_parms{code_dir}.|;
    $html .=
      qq|<br><font color=red><b>Read-Only</b>: <a href="/bin/SET_PASSWORD">Login as admin</a> to edit</font>|
      unless $Authorized eq 'admin';
    $html .= qq|Simply uncheck files you want to disable or check to re-enable.|
      if $Authorized eq 'admin';
    $html .= qq|
<CENTER><FORM ACTION="/bin/code_unselect.pl" method=post>
<TABLE BORDER="0" cellspacing="0" cellpadding="0" width="100%">
<tr><td colspan="2"><B>Search</B> (file or description): <input  align='left' size='25' name='search'>&nbsp;<INPUT TYPE='submit' VALUE='Search'>
|;
    $html .= "&nbsp;Searching for: \"$search\"" if $search;
    $html .= "</td>";

    my %files_deselected = map { $_, 1 }
      &file_read( "$config_parms{data_dir}/$config_parms{code_unselect}", 2 );
    my %standard_parms = map { $_, 1 }
      qw(html_dir code_dir code_dir_common data_dir http_port debug);

    my @files_read;
    for my $file_dir (@Code_Dirs) {
        opendir( MYDIR, $file_dir )
          or print "\n\nError, can not open directory $file_dir.\n\n";
        push @files_read, readdir(MYDIR)
          unless $file_dir eq $config_parms{code_dir_common};
        close MYDIR;
    }
    @files_read = grep( /^[a-z0-9].*\.(pl|mhp)$/i, @files_read )
      ; # Must start with alphanumeric ... emacs edited checkpoints can start with #

    my ( %modules, %categories );

    # Parse code files for description, category, and config_parms
    for my $file (@files_read) {
        next unless $file =~ /\.(pl|mhp)$/i;

        my $file_path;
        for my $code_dir (@Code_Dirs) {
            $file_path = "$code_dir/$file";
            last if -e $file_path;
        }
        unless ($file_path) {
            print "\nError, could not find file in Code_Dirs: $file\n\n";
            next;
        }

        my $checked = ( !$files_deselected{$file} ) ? 'CHECKED' : '';
        $checked .= ' disabled' unless $Authorized eq 'admin';
        my $description = '';
        my %file_parms;
        my $parms_list;
        my $category = 'Other';    #Default
        for my $line ( &file_read($file_path) ) {
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
              "<br><a href='#' onclick=\"edit_parms('$parms_list','$file');return(false);\">EDIT</a>&nbsp;<b>Config parms</b>: $description_part";
        }

        $categories{$category}++;
        my $selected = !$files_deselected{$file};
        $modules{"$category|$file"} =
            qq|<TR bgcolor="#rowbgcolor#"><TD valign=top nowrap> |
          . qq|<INPUT TYPE="HIDDEN" NAME="${file}_previous" VALUE="$selected"> |
          . qq|<INPUT TYPE="checkbox" NAME="$file" $checked> |
          . qq|<a href=/bin/browse.pl?/user_code/$file>$file</a></TD><TD>$description</TD></TR>|;
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
    $submit_html = $submit_html . ">";
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

    # Allow un-authorized users to browse only (if listed in password_allow)
    return 'Not authorized to make updates' unless $Authorized eq 'admin';

    my %modules_deselected = map { $_, 1 }
      &file_read( "$config_parms{data_dir}/$config_parms{code_unselect}", 2 );

    my ( %modules_added, %modules_dropped, %modules_selected );

    for $module (@parms) {

        # Require _previous parm to show up first
        #     print "db m=$module\n";

        if ( $module =~ /(\S+)_previous=(.*)/ ) {
            $modules_deselected{$1}++;
            if ($2) {
                $modules_dropped{$1}++;
            }
        }
        elsif ( $module =~ /(\S+)=on/ ) {
            delete $modules_deselected{$1};
            if ( $modules_dropped{$1} ) {
                delete $modules_dropped{$1};
            }
            else {
                $modules_added{$1}++;
            }
            $modules_selected{$1}++;
        }
    }

    my $modules_added      = join "\n", sort keys %modules_added;
    my $modules_dropped    = join "\n", sort keys %modules_dropped;
    my $modules_selected   = join "\n", sort keys %modules_selected;
    my $modules_deselected = join "\n", sort keys %modules_deselected;

    my $file = "$config_parms{data_dir}/$config_parms{code_unselect}";
    &file_backup($file);
    &file_write( $file,
            "# This file is auto-generated by web code_unselect.pl.\n"
          . "# It lists all files you have de-selected from the user code dirs\n"
          . $modules_deselected );

    run_voice_cmd "reload code" if $modules_added or $modules_dropped;

    $html = "<H1>MisterHouse Code Activation Confirmation</H1>";
    $html .=
      "<b>The following code files are now      activated:</b><P><PRE>$modules_added</PRE>";
    $html .=
      "<b>The following code files are now   de-activated:</b><P><PRE>$modules_dropped</PRE>";
    $html .=
      "<b>Here are all your deactivated files:</b><P><PRE>$modules_deselected</PRE>";
    $html .=
      "<b>Here are all your   activated files:</b><P><PRE>$modules_selected</PRE>";

    return &html_page( '', $html );
}
