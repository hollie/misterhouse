
=begin comment

iniedit.pl - a CGIish script for editing Misterhouse configuration parameters

10/12/2001  Created by David Norwood and Bruce Winter
12/04/2002  Modified by Steve Switzer (edit_list sub added to support links from select_code*.pl. Added alternating bgcolors for table rows, removed table borders.)

=cut

my $testing = 0;    # Should be 0 for live version, and 1 while testing

#o warnings;                    # Avoid redefined sub msgs
$^W = 0;            # Avoid redefined sub msgs

my $header = &html_header('MisterHouse mh.ini editor');

my $head = qq|HTTP/1.0 200 OK
Server: MisterHouse
Content-Type: text/html
Cache-control: no-cache

<HTML>
<HEAD>
<TITLE>Misterhouse Configuration Parameters</TITLE>
</HEAD>
<LINK REL="STYLESHEET" HREF="/default.css" TYPE="text/css">
<BODY>

<DIV ID="overDiv" STYLE="position:absolute; visibility:hide; z-index:1;"></DIV>
<SCRIPT LANGUAGE="JavaScript" SRC="/lib/overlib.js"></SCRIPT>

<script>
function openparmhelp(parm1){
  window.open("/RUN;&iniedit_help('" + parm1 + "')","help","width=300,height=500,left=0,top=0,scrollbars=1,resizable=0")
}
</script>

$header
|;

my $tail = '
</BODY>
</HTML>
';

return localize() if $testing and !@ARGV;    # For testing only

my ( %dparms, %cparms, @order, %pparms, %categories, @catorder, %changed,
    %help );
my $private_parms = $Pgm_Path . "/mh.private.ini";
$private_parms = $ENV{mh_parms} if $ENV{mh_parms};

my_read_opts( \%dparms, \@order, \%categories, \@catorder, "./mh.ini",     0 );
my_read_opts( \%pparms, \@order, \%categories, \@catorder, $private_parms, 0 );

%cparms = ( %dparms, %pparms );

my %args;
foreach (@ARGV) {

    #print "$_\n";
    if ( my ( $key, $value ) = $_ =~ /([^=]+)=(.*)/ ) {
        $args{$key} = $value;
        next if $key eq "Category";
        next if $key eq "Commit";
        next if $key eq "Switch";
        next if $key eq "file";
        next if $key =~ /AddKey[1234]/;
        next if $key =~ /AddValue[1234]/;
        next if lc $key eq "edit_list";

        if ( !defined $cparms{$key} ) {
            push @order, $key;
            $categories{$key} = "Other";
        }
        if ( !defined $cparms{$key} or $cparms{$key} ne $value ) {
            $changed{$key} = $value;
            $cparms{$key}  = $value;
        }
    }
}

foreach ( 1 .. 4 ) {
    if ( $args{ "AddKey" . $_ } and $args{ "AddValue" . $_ } ) {
        my $key   = $args{ "AddKey" . $_ };
        my $value = $args{ "AddValue" . $_ };
        if ( !defined $cparms{$key} ) {
            push @order, $key;
            $categories{$key} = "Other";
        }
        if ( !defined $cparms{$key} or $cparms{$key} ne $value ) {
            $changed{$key} = $value;
            $cparms{$key}  = $value;
        }
    }
}
my $category = $catorder[0];
$category = $args{Category} if $args{Category};

if ( defined $args{Commit} and $args{Commit} eq "Commit" ) {
    return &html_page( '', 'Not authorized to make updates' )
      unless $Authorized eq 'admin';
    return commit();
}
elsif ( defined $args{MakeDoc} ) {
    return make_doc();
}
elsif ( defined $args{edit_list} ) {
    return edit_list();
}
elsif ( defined $args{Select} ) {
    &select;
    return advice();
}
elsif ( defined $args{Continue} ) {
    return edit();
}
elsif ( !-e "$Pgm_Path/mh.private.ini" and !-e $ENV{mh_parms} ) {
    return localize();
}
else {
    return edit();
}

sub commit {

    # Backup old parms file
    &file_backup($private_parms);

    #   rename $private_parms, "$private_parms.${Year_Month_Now}_${Hour}_${Minute}_${Second}"  or
    #     print_log "Error in backup up parms file $private_parms: $!";

    open( PRIVATE, ">$private_parms" )
      or return $head
      . "\nError, could not open $private_parms for writing.<p>\n"
      . $tail;
    print PRIVATE
      "# Misterhouse configuration file generated by iniedit.pl\n\n";
    my $data;
    if ( defined $args{edit_list} ) {
        $data =
          '<A HREF="/bin/iniedit.pl" onclick="self.close();return(false);">Close</A>';
    }
    else {
        $data = '<A HREF="/bin/iniedit.pl">Back</A>';
    }
    $data .= '
        <P>The following parameters were saved:<p>
        <PRE>' . "\n";

    foreach my $key (@order) {
        if ( ( !defined $dparms{$key} and $cparms{$key} )
            or $cparms{$key} ne $dparms{$key} )
        {
            print PRIVATE $key . '=' . $cparms{$key} . "\n";
            $data .= $key . '=' . $cparms{$key} . "\n";
        }
    }
    close PRIVATE;
    $data .= '</PRE>';

    #   run_after_delay 1, "run_voice_cmd 'Reload code'";
    #   print "dbx calling read_parms\n";
    &read_parms();
    return $head . $data . $tail;
}

sub edit {
    my $data = '
       <br>';
    $data .=
      '<font color=red><b>Read-Only</b>: <a href="/bin/SET_PASSWORD">Login as admin</a> to edit</font><br>'
      unless $Authorized eq 'admin';
    $data .= '
        Note: Commit will resort and filter out comments.'
      if $Authorized eq 'admin';
    $data .= '
        <FORM method=post>
    ';

    $data .= '
        <TABLE WIDTH="98%" CELLSPACING=0 CELLPADDING=0 BORDER=0>
        <tr bgcolor="#AAAAAA"><td colspan="2"><em><b>Category:</b></em> <select name="Category">
    ';

    foreach ( @catorder, 'Other' ) {
        $data .=
          '<option' . ( $_ eq $category ? ' selected' : '' ) . '> ' . $_ . "\n";
    }

    $data .= '
        </select>';
    $data .= '<input type=submit name="Switch" value="Switch">&nbsp;&nbsp;';
    $data .=
      '<input type=submit name="Commit" value="Commit"><input type=submit name="Reset Values" value="Reset Values">'
      if $Authorized eq 'admin';
    $data .= '
        </td></tr>
    ';
    my $rowcount     = 0;
    my $disabledhtml = '';
    $disabledhtml = ' disabled' unless $Authorized eq 'admin';

    foreach (@order) {
        next if $categories{$_} ne $category;
        my $rowbgcolor = "#FFFFFF";
        if ( ( $rowcount % 2 ) == 1 ) { $rowbgcolor = "#DFDFDF"; }
        $data .= "<tr bgcolor='$rowbgcolor'><td>";
        unless ( $Http{'User-Agent'} eq 'Audrey' ) {
            $data .= qq[<a href="javascript:openparmhelp('$_')"];

            #           $data .= qq[ onMouseOver="overlib('$help{$_}', RIGHT, ABOVE, HEIGHT, 1, WIDTH, 350, OFFSETX, 0)" onMouseOut="nd();"];
            $data .= '>Help</a>';
            $data .= '&nbsp;';
        }

        $data .= "<b>$_</b></td><td>";
        $data .=
            '<input'
          . $disabledhtml
          . ' type=text size=30 name="'
          . $_
          . '" value="';
        $data .= map_chars( $cparms{$_} ) . '">';
        $data .=
          '<input type=button value="Set Default" onClick="' . $_ . ".value='"
          if $Authorized eq 'admin';
        $data .=
          ( defined $dparms{$_} ? map_chars( $dparms{$_} ) : '' ) . "'\">"
          if $Authorized eq 'admin';
        $data .= "</td></tr>\n";
        $rowcount++;
    }

    foreach ( keys %changed ) {
        next if $categories{$_} eq $category;
        $data .= '<input type=hidden name="' . $_ . '" value="';
        $data .= map_chars( $changed{$_} ) . '">' . "\n";
    }

    $data .= '
        <tr><td>&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;User Defined
        <input type=text size=10 name="AddKey1" value="">
        </td><td><input type=text size=20 name="AddValue1" value=""></td></tr>
        <tr><td>&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;User Defined
        <input type=text size=10 name="AddKey2" value="">
        </td><td><input type=text size=20 name="AddValue2" value=""></td></tr>
        <tr><td>&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;User Defined
        <input type=text size=10 name="AddKey3" value="">
        </td><td><input type=text size=20 name="AddValue3" value=""></td></tr>
        <tr><td>&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;User Defined
        <input type=text size=10 name="AddKey4" value="">
        </td><td><input type=text size=20 name="AddValue4" value=""></td></tr>
        </table>
        <p><em>Note, user defined parameters will appear in the Other category.
        To remove a user defined parameter later, clear its value.'
      if $Authorized eq 'admin';
    $data .= '
        </form>
    ';

    return $head . $data . $tail;
}

sub edit_list {
    my $data = '
        <FORM method=post>
    ';
    $data .= '
        <TABLE WIDTH="98%" CELLSPACING=0 CELLPADDING=0 BORDER=0>
        <tr bgcolor="#AAAAAA"><td colspan="2"><b>INI Parms for: <em>';
    $data .= $args{file};
    $data .= '</b></em>
        <input type=submit name="Commit" value="Commit">
        <input type=reset name="Reset Values" value="Reset Values"></td></tr>
    ';
    my $rowcount = 0;

    foreach ( split /[,]+/, $args{edit_list} ) {
        my $rowbgcolor = "#FFFFFF";
        if ( ( $rowcount % 2 ) == 1 ) { $rowbgcolor = "#DFDFDF"; }
        $data .= "<tr bgcolor='$rowbgcolor'><td>";
        unless ( $Http{'User-Agent'} eq 'Audrey' ) {
            $data .= qq[<a href="javascript:openparmhelp('$_')"];

            #           $data .= qq[ onMouseOver="overlib('$help{$_}', RIGHT, ABOVE, HEIGHT, 1, WIDTH, 350, OFFSETX, 0)" onMouseOut="nd();"];
            $data .= '>Help</a>';
            $data .= '&nbsp;';
        }
        $data .= "<b>$_</b></td><td>";
        $data .= '<input type=text size=30 name="' . $_ . '" value="';
        $data .=
            map_chars( $cparms{$_} )
          . '"><input type=button value="Set Default" onClick="'
          . $_
          . ".value='";
        $data .=
          ( defined $dparms{$_} ? map_chars( $dparms{$_} ) : '' )
          . "'\"></td></tr>\n";
        $rowcount++;
    }

    $data .= '
        </table>
        </form>
    ';
    return $head . $data . $tail;
}

sub iniedit_help {
    my ($parm) = @_;
    my $help = $help{$parm};

    # Add breaks on blank lines
    $help =~ s/\n\s*\n/<br>/g;
    $help =~ s/\n/<br>/g;
    return "HTTP/1.0 200 OK
Server: MisterHouse
Content-Type: text/html
Cache-control: no-cache

<html>
<head>
<title>INIEdit Help: $parm</title>
<SCRIPT>
function ontop()
{self.focus(); //setTimeout('turnback()',200);
}
ontop();
</SCRIPT>
</head>
<body>
<b>$parm</b>
<p>$help
</body></html>"

}

# This function is not used
sub make_doc {
    my $data = '';
    foreach (@order) {
        next unless defined $dparms{$_};
        $data .= '<A NAME="' . $_ . '"><H3>' . $_ . '</H3></A><P>' . "\n";
        $data .= 'Insert description here.<P>' . "\n";
        $data .=
          '<B>Default value: </B>' . map_chars( $dparms{$_} ) . '<P><P>' . "\n";
    }

    return $head . $data . $tail;
}

sub map_chars {
    my ($string) = @_;
    $string =~ s/\&/&#38;/g;
    $string =~ s/\"/&#34;/g;
    $string =~ s/\'/&#39;/g;
    return $string;
}

# This is similar to handy_Utils read_opts ... maybe should merge or share code?
sub my_read_opts {
    my ( $ref_parms, $ref_order, $ref_cats, $ref_catorder, $config_file,
        $debug ) = @_;
    my ( $key, $value, $value_continued, $help, $help_flag );

    # If debug == 0 (instead of undef) this is disabled
    print "Reading config_file $config_file\n"
      unless defined $debug and $debug == 0;
    open( CONFIG, "$config_file" )
      or print "\nError, could not read config file: $config_file\n";
    my $category = "Other";
    while (<CONFIG>) {

        # Look for help text
        if (/^\@(.*)/) {
            $help = '' unless $help_flag++;
            $help .= $1 . "\n";
            next;
        }
        else {
            $help_flag = 0;
        }
        if (/ \@(.+)/) {
            $help = $1;
        }

        if ( $_ =~ /^#\s*Category\s*=\s*(.*?)\s*$/ ) {
            $category = $1;
            push @$ref_catorder, $category
              if !grep /^$category$/, @$ref_catorder;
        }

        next if /^\s*\#/;

        # Allow for multi-line values records
        # Allow for key => value continued data
        if (    $key
            and ($value) = $_ =~ /^\s+([^\#\@]+)/
            and $value !~ /^\s*\S+=[^\>]/ )
        {
            $value_continued = 1;
        }

        # Look for normal key=value records
        else {
            next unless ( $key, $value ) = $_ =~ /(\S+?)\s*=\s*(.*)/;
            if ($value) {
                $value =~ s/^[\#\@].*//;     # Delete end of line comments
                $value =~ s/\s+[\#\@].*//;
            }
            $value_continued = 0;
            next unless $key;
        }

        $value =~ s/\s+$//;                  # Delete end of value blanks

        # Last parm wins (in case we reload parm file)
        if ($value_continued) {
            $$ref_parms{$key} .= $value;
        }
        else {
            $help{$key} = $help if $help;

            # print_log "Same: $key $value <BR> " if $$ref_parms{$key} eq $value and $value;
            $$ref_parms{$key} = $value;
            if ( !grep /^$key$/, @$ref_order ) {
                push @$ref_order, $key;
                $$ref_cats{$key} = $category;
            }
        }
        print
          "parm key=$key value=$$ref_parms{$key} category=$$ref_cats{$key}\n"
          if $debug;
    }
    close CONFIG;
    return sort keys %{$ref_parms};
}

#  If no mh.private.ini is found, then offer a choice of mh.somewhere.ini files
# (contained in $Pgm_Root/data/ini)
sub localize {
    my ( $local_opts, $note );
    opendir( DIR, "$Pgm_Root/data/ini" );
    my @files = readdir(DIR);
    closedir(DIR);
    foreach my $file ( sort @files ) {
        next
          if $file =~ /location_specimen|example/
          ;    # Ignore mh.location_specimen.ini and mh.example.ini
        next if $file =~ /^\./;    # Ignore ./ and ../
        $file =~ s/(mh\.|\.ini)//i
          ;    # problem with this line (next line should not be needed)
        $file =~ s/\.ini//i;

        # $file = ucfirst($file);
        # print "File: $Pgm_Root/data/ini/$file\n";

        #  Look for notes in line beginning with @
        my @lines = file_read("$Pgm_Root/data/ini/mh.$file.ini");
        foreach my $line (@lines) {
            next unless $line =~ /^\@/;

            # print "Line: $line\n";
            $note = $line;
            last;
        }

        # print "Notes: $note\n";
        $note =~ s/\@\s*//s;
        $note =~ s/^for//is;
        $local_opts .= "     <option value='$file'>$note\n";
    }
    my $data = qq|

You currently have no file of ini settings.
If one of the options in the box below is appropriate for you,
you can use it to start a mh.private.ini file containing settings suitable
for your own location - you can amend this using the pages which follow.
Otherwise select 'None of the above'.<BR>

<form method=post>
<select name="Location">
$local_opts
     <option value='example'>None of the above
</select>
<input type=submit name="Select" value="Select">&nbsp;&nbsp;
</form>

|;

    return $head . $data . $tail;
}

# Write mh.somewhere.ini to mh.private.ini
sub select {
    my $location      = $args{Location};
    my $location_file = "$Pgm_Root/data/ini/mh.${location}.ini";
    print "Copying location file: $location_file\n";
    my $data = file_read($location_file);
    file_write( "$Pgm_Root/bin/mh.testing.ini", $data )
      if $testing;    # For testing only
    file_write( "$Pgm_Root/bin/mh.private.ini", $data ) unless $testing;
}

# Hints on what to do after clicking on 'Select'
sub advice {
    my $data = qq[
<table>
    <tr>
        <td>
           <form method=post>
           <input type=submit name="Continue" value="Continue">&nbsp;&nbsp;
           </form>
        </td>
        <td>
            A private .ini file has been created for you in /mh/bin, called mh.private.ini.
            You will need to modify this from time to time to customize your own
            configuration settings. <BR>
            It is recommended that you should move your mh.private.ini file to
            a folder outside the mh distribution folders, and point to it with
            an environment variable, mh_parms. This will make it easier
            when you come to install Misterhouse upgrades in the future.<BR>
        </td>
    </tr>
</table>
Further guidance on setting up your own customized version of Misterhouse
is given in 'Coding your own events', in
<A HREF='../docs/install.html#coding_your_own_events' TARGET='_blank'>
mh/docs/install.html</A>.<BR>
];
    return $head . $data . $tail;
}
