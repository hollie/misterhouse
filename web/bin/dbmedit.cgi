#!/usr/bin/perl
#
#   DBMEdit 1.0
#
#     Add, edit, or delete records from a DBM file, via a Web interface.
#     The DBM records are assumed to be several fields concatenated into
#     one long string with some delimiting string (default is "\0").
#
#     This program displays a DBM database as a table, and provides
#     auto-sized forms to add or edit records.  It protects data reasonably
#     well in multi-user situations.
#
#
#   TO INSTALL/CONFIGURE:
#
#     1) Put this script where you want it.
#
#     2) Create a directory below that called "data/" (the name is
#        user-configurable, below).
#
#     3) Put your existing DBM files in the data/ directory, or make
#        symbolic links in there that point to the real DBM files.
#
#     4) Figure out how you want to handle permissions.  The Web server
#        must be able to write the files in data/, and the data/ directory
#        itself must be writable if you want to create new files in it
#        via this script.
#
#        Note that if data/ is writable by the Web server's user, then any
#        local hacker with CGI can overwrite your data.  If you work around
#        this with setgid or setuid, see the security note in the
#        USER CONFIGURATION section below.
#
#  !! 5) PASSWORD-PROTECT THE URL OF THIS SCRIPT!  Otherwise, anyone can
#        edit your DBM files-- probably not what you want.  Also, set
#        @ALLOWED_USERS in the USER CONFIGURATION section below.
#
#        Security within the script is limited at best; it relies on the
#        authentication of whoever's running the script.
#
#
#   TO USE:
#
#     You can create new DBM databases with this program, or edit existing
#     ones that follow the same field-delimiting scheme.
#
#     Define each database by the DBM filename, the list of column names,
#     and the delimiter between fields within each record.  This database
#     definition is saved in the URL, so you can bookmark it directly or
#     put it in an HTML link.
#
#       FILENAME:
#         Leave out the extension.  Don't point into another directory.
#
#       COLUMNS:
#         Comma-separated list of text strings, for display only.  Each
#         column name may be followed by a ':' and optional one-letter
#         flags.  Currently supported flags are:
#               r     read-only (for convenience only, NOT security)
#               t     textarea (multi-line) input instead of one-line input
#
#         Example column list:
#
#               Name, Birthdate:r, Favorite Quote:t
#
#       DELIMITER:
#         Any string of characters can be used.  Express it as a list of
#         ASCII codes, as decimal numbers.  For example, CRLF is "13 10".
#         The default is one null character, which is "0".
#
#         Note that the data in the database fields can't contain the
#         delimiter string, or the database will get messed up.  If you need
#         to put arbitrary binary data in a field, use a long sequence of
#         random bytes here, like "188 45 217 206 51".  Five bytes means
#         you'll mess it up about once for every terabyte (1000 GB) you
#         store.
#
#     Once you've defined and loaded your database, be sure to bookmark the
#     full URL or copy it to an HTML link.
#
#
#   Further comments are at the end of this file.
#
#   written by James Marshall, james@jmarshall.com
#   see http://www.jmarshall.com/tools/dbmedit/ for more info
#

#----- USER CONFIGURATION (NORMALLY UNNEEDED) ------------------------

# For security, only let this script modify DBMs in a certain directory.
# If you have DBMs all over the place, put symbolic links in this
#   directory to point to the actual locations.
# This directory must be accessible by the uid that the Web server runs as.

no strict;

#$DATA_DIR= 'data' ;
$DATA_DIR = $config_parms{data_dir};

print "db dd=$DATA_DIR\n";

# Set this to a list of allowed usernames, to restrict who REMOTE_USER can
#   be, or leave empty for no restrictions.  This guards against a few
#   potential security holes.  For example, someone could make a symbolic
#   link to your copy of this script, bypassing any password-protection.
@ALLOWED_USERS = qw( );

# If you run this setuid or setgid, there is a slight security risk
#   of someone running this from the command line in another directory
#   with certain symbolic links, and potentially modifying DBM files
#   in other directories of yours.  If you care about this, then set
#   one or both of the following two variables.

# Username or UID the Web server runs under (either will work).
# If you set this, the program will verify this is the real user running it.
$WEB_SERVER_USER = '';

# Directory where this program should be run, i.e. where it lives.
# If you set this, the program will chdir to the directory before running.
$HOME_DIRECTORY = '';

# The delimiter between fields in the DBM file, if none is specified.
$DEFAULT_DELIM = "\0";

#----- END OF (USEFUL) USER CONFIGURATION ----------------------------

use Fcntl qw(:DEFAULT :flock);

#use NDBM_File ;

# Where all the lock files go. This will be created if it doesn't exist.
$lockdir = "$DATA_DIR/locks";

# The default title for simple error responses
$errtitle = "$0 error";

# Guard against unauthorized access, if needed
if (@ALLOWED_USERS) {
    &HTMLdie("Sorry, you're not authorized to run this script.")
      unless grep( ( $_ eq $ENV{'REMOTE_USER'} ), @ALLOWED_USERS );
}

# Guard against a slim security hole
chdir($HOME_DIRECTORY) || &HTMLdie("Couldn't chdir: $!")
  if $HOME_DIRECTORY ne '';

# Guard against a slim security hole, take 2
if ( $WEB_SERVER_USER ne '' ) {

    # First, convert to numeric UID if needed
    $WEB_SERVER_USER = getpwnam($WEB_SERVER_USER) if $WEB_SERVER_USER =~ /\D/;
    &HTMLdie("Access forbidden.") unless ( $WEB_SERVER_USER == $< );
}

%in = &getcgivars;
$in{'file'} =~ s/(^\s*|\s*$)//g;    # standardize on no leading/trailing blanks
$in{'referer'} ||= $ENV{'HTTP_REFERER'};

&displaystartform unless $in{'file'};

# Only allow files with no paths.
# Heck, only allow word chars for now.
&HTMLdie("The filename '$in{'file'}' is not allowed.")
  if ( $in{'file'} =~ m#/|\.\.# ) || ( $in{'file'} =~ /[^\w.-]/ );

# Homespun lock mechanism-- can't figure out how to use flock() on DBM file :(
# Make a lock file to get a lock on-- safer for interruptable processes.
mkdir( $lockdir, 0777 ) || &HTMLdie("Couldn't create lock directory: $!")
  unless -e $lockdir;
chmod( 0777, $lockdir );    # otherwise, it's tough to get rid of
$lockfile = "$lockdir/$in{'file'}.lock";    # safe because $in{'file'} is safe
system( 'touch', $lockfile ) unless -e $lockfile;
open( DB_LOCK, ">$lockfile" ) || &HTMLdie("Couldn't open lockfile: $!");

# For some reason, LOCK_SH doesn't always work-- gets "Bad file number".  :P
#   So, we'll just do an exclusive lock for everything.  Best we can do.  :(
flock( DB_LOCK, LOCK_EX ) || &HTMLdie("Couldn't get lock: $!");

# $now is saved in the form, and is used for safe updates.
# Note that file will not be modified until at least the end of this script,
#   so $now is "equivalent" to the time the form will be generated.
$now = time;    # for (@goodmen)

#tie (%DBM,  'DB_File',  $dbm_file,  O_RDWR|O_CREAT, 0666) or print "\nError, can not open dbm file $dbm_file: $!";
#tie %dbdata, 'NDBM_File', "$DATA_DIR/$in{'file'}", O_RDWR|O_CREAT, 0664 ;
tie %dbdata, 'DB_File', "$DATA_DIR/$in{'file'}", O_RDWR | O_CREAT, 0664;

# Used to test modification time for safe updates.
# DBM filenames vary, so see which files exist.  Try .pag, else take .db.
# What other extensions are created with DBMs?
#$dbfilename= "$DATA_DIR/$in{'file'}.pag" unless -e $dbfilename;
#$dbfilename= "$DATA_DIR/$in{'file'}.png" unless -e $dbfilename;
#$dbfilename= "$DATA_DIR/$in{'file'}.db"  unless -e $dbfilename;
$dbfilename = "$DATA_DIR/$in{'file'}";

# Perhaps we should allow the user to read the file even if it's not
#   writable?  To do so, set $topmsg, and alter the flags on "tie", above.
&HTMLdie("Web server couldn't create DBM file: $dbfilename")
  unless -e $dbfilename;
&HTMLdie("DBM file isn't readable by Web server: $dbfilename")
  unless -r $dbfilename;
&HTMLdie("DBM file isn't writable by Web server: $dbfilename")
  unless -w $dbfilename;

&calcglobals;

#----- end of initialization, main block below -----------------------

# a catch-all way to cancel actions: show message and do default command
if ( $in{'noconfirm'} ) {
    $topmsg = "<h2><font color=red>\u$safein{'cmd'} cancelled.</font></h2>";
    $in{'cmd'} = $safein{'cmd'} = '';
}

# Main switch statement

if ( ( $in{'cmd'} eq 'show' ) || ( $in{'cmd'} eq '' ) ) {
    &displaymaintable;

}
elsif ( $in{'cmd'} eq 'edit' ) {
    &displayeditform;

}
elsif ( $in{'cmd'} eq 'add' ) {
    &addrecord;
    $topmsg = "<h2><font color=green>Record added.</font></h2>";
    &displaymaintable;

}
elsif ( $in{'cmd'} eq 'update' ) {
    &updaterecord;
    $topmsg = "<h2><font color=green>Record updated.</font></h2>";
    &displaymaintable;

}
elsif ( $in{'cmd'} eq 'delete' ) {
    &deleterecord;
    $topmsg = "<h2><font color=green>Record deleted.</font></h2>";
    &displaymaintable;

}
else {
    &HTMLdie( "The command <b>$safein{'cmd'}</b> is not supported.",
        "Command not supported" );

}

untie %dbdata;

close(DB_LOCK);

# unlink $lockfile ;   # not needed, but optional

return;

#----- blocks to perform the various commands ------------------------

# Add a new record to the DBM file
sub addrecord {

    unless ( $in{'confirm'} ) {
        if ( defined( $dbdata{ $in{'key'} } ) ) {
            &verifycmd( "A record with that key already exists.  You should "
                  . "normally use the Update function to change an existing "
                  . "record.  Would you like to overwrite the existing record "
                  . "with the values you just entered?" );
        }
    }

    # Generate sequential key if key was not entered
    if ( !length( $in{'key'} ) ) {
        $in{'key'} =
          sprintf( "%05d", int( ( sort { $b <=> $a } keys %dbdata )[0] ) + 1 );
    }

    &putfieldstodb;
}

# Update a record in the DBM file
sub updaterecord {

    unless ( $in{'confirm'} ) {

        unless ( defined( $dbdata{ $in{'key'} } ) ) {
            &verifycmd( "That record has apparently been deleted recently.  "
                  . "Would you like to add it back with the values you just "
                  . "entered?" );
        }

        if ( $in{'time'} && $in{'time'} < ( stat($dbfilename) )[9] ) {
            &verifycmd( "The database has changed since this record was "
                  . "presented to you for editing.  The record itself may or "
                  . "may not have changed.  Do you still want to update "
                  . "this record?" );
        }
    }

    &putfieldstodb;
}

# Delete a record from the DBM file
sub deleterecord {

    unless ( $in{'confirm'} ) {
        verifycmd("Are you sure you want to delete this record?");
    }

    delete( $dbdata{ $in{'key'} } );
}

# Require the user to verify a command
sub verifycmd {
    my ($msg) = @_;
    my ($userdata) =
      &hiddenvars( &subhash( *in, 'key', grep( /^in_\d\d\d$/, keys %in ) ) );
    &printheader;
    print <<EOF ;
<h3><font color=red>Warning:</font>  $msg</h3>

<form action="$ENV{'SCRIPT_NAME'}" method=post>
<input type=hidden name="cmd" value="$safein{'cmd'}">
<input type=hidden name="time" value="$safein{'time'}">
$dbdefnpost
$userdata
<input type=submit name="confirm" value="  Yes, continue  ">
<input type=submit name="noconfirm" value="No, cancel this request">
</form>

<p><i>Tip: Creative use of the forward and back browser buttons can be very
helpful here, to view current data or recover lost data.</i>

EOF

    &printfooter;

    #   exit ;   # hmm, not the cleanest
    return;
}

# Copy "in_nnn" fields into $dbdata{$in{'key'}} (used by add and update)
# Currently, this does NOT fill in gaps in data, e.g. (in_001, in_003) is
#   only two fields, not three with a blank one in the middle.
sub putfieldstodb {

    # create full data string, removing empty fields at the end
    my (@field) = sort grep( /^in_\d\d\d$/, keys %in );
    $#field-- while ( ( $#field > 0 ) && !length( $in{ $field[$#field] } ) );

    # Normalize raw CRLF into LF, to accommodate brain-dead OS's
    foreach (@field) { $in{$_} =~ s/\r\n/\n/g }

    $dbdata{ $in{'key'} } =
      join( $delim, map { &slashunescape($_) } @in{@field} );
}

#----- translation to/from slash-escaped string format ---------------

# unescape the user input into raw data
sub slashunescape {
    my ($s) = @_;
    $s =~ s/(\\(n|r|t|f|b|a|e|0(?!\d\d)|\d\d\d|x[0-9A-Fa-f]{2}|c.|\\))/
    eval qq(\"$1\") /ge;
    return $s;
}

# use backslashes to escape string, to make it suitable for input form
sub slashescape {
    my ($s) = @_;
    $s =~ s/\\/\\\\/g;
    $s =~ s/\n/\\n/g;
    $s =~ s/\r/\\r/g;
    $s =~ s/\t/\\t/g;
    $s =~ s/\f/\\f/g;
    $s =~ s/\x08/\\b/g;
    $s =~ s/\a/\\a/g;
    $s =~ s/\e/\\e/g;
    $s =~ s/\0(?!\d\d)/\\0/;
    $s =~ s/([\ca-\cz])/   "\\c" . chr(ord($1)+64) /ge;
    $s =~ s/([^\x20-\x7e])/ "\\x" . sprintf("%02x",ord($1)) /ge;
    return $s;
}

# Identical to &slashescape(), except doesn't escape \n
sub slashescapetextarea {
    my ($s) = @_;
    $s =~ s/\\/\\\\/g;
    $s =~ s/\r/\\r/g;
    $s =~ s/\t/\\t/g;
    $s =~ s/\f/\\f/g;
    $s =~ s/\x08/\\b/g;
    $s =~ s/\a/\\a/g;
    $s =~ s/\e/\\e/g;
    $s =~ s/\0(?!\d\d)/\\0/;
    $s =~ s/([\ca-\ci\ck-\cz])/   "\\c" . chr(ord($1)+64) /ge;
    $s =~ s/([^\x20-\x7e\n])/ "\\x" . sprintf("%02x",ord($1)) /ge;
    return $s;
}

#----- routines to calculate various globals and arrays --------------

# Calculate all global scalars and arrays, as part of initialization.
# Order is sometimes important here.
# None of these should need recalculating; they should all be constant.
sub calcglobals {
    @safein{ keys %in } = map { &HTMLescape($_) } values %in;

    # Save database definition to send to script again
    $dbdefnget =
      &urlencodelist( &subhash( *in, qw(file delim columns referer) ) );
    $dbdefnpost =
      &hiddenvars( &subhash( *in, qw(file delim columns referer) ) );

    $delim =
      ( $in{'delim'} =~ /\d/ )
      ? join( "", map { chr } ( $in{'delim'} =~ /(\d+)/g ) )
      : $DEFAULT_DELIM;
    $safedelim = &slashescape($delim);

    # Columns are "title:flags"; store in @title and @flags[]{flags}.
    # Flags are one char and may take numeric value, e.g. "title:a5b11cd".
    # Default flag value is 1.  Initial numeric value stored in 'preflag'. (?)
    # could be cleaner here...
    @column = ( split( /\s*,\s*/, $in{'columns'} ) );
    for ( 0 .. $#column ) {
        ( $title[$_], $flags[$_] ) = split( /:/, $column[$_], 2 );
    }
    @title = map { &HTMLescape($_) } @title;
    foreach ( 0 .. $#flags ) {
        ( $flags[$_] ) = { 'preflag', split( /([a-zA-Z])/, $flags[$_] ) };
        foreach $key ( keys %{ $flags[$_] } ) {
            $flags[$_]{$key} = '1' unless length( $flags[$_]{$key} );
        }
    }

}

# Find current parameters of table
# columns start with column 0
sub calctablesize {
    &findmaxwidths;
    $lastcol = ( $#column > $#maxwidth ) ? $#column : $#maxwidth;
}

# Find maximum widths of data in columns
# jsm-- field array could be saved to use later, for speed?
sub findmaxwidths {
    @maxwidth  = ();
    @maxheight = ();
    foreach $key ( keys %dbdata ) {
        my ( $i, $numlines );
        foreach ( split( /$delim/, $dbdata{$key} ) ) {

            # @maxheight() calc is only needed for textareas, but let's
            #   figure all of them, may come in handy.
            $numlines = s/\n/\n/g + 1;
            $maxheight[$i] = $numlines if $maxheight[$i] < $numlines;
            if ( $flags[$i]{'t'} ) {
                foreach my $l ( split(/\n/) ) {
                    $l = &slashescape($l);
                    $maxwidth[$i] = length($l) if $maxwidth[$i] < length($l);
                }
            }
            else {
                $_ = &slashescape($_);
                $maxwidth[$i] = length if $maxwidth[$i] < length;
            }
            $i++;
        }
    }
}

#-----  Main display routines  ---------------------------------------

# Print common header
sub printheader {

    print <<EOF ;
Content-type: text/html

<html>
<head>
<title>Editing "$safein{'file'}" database</title>
</head>
<body bgcolor=white vlink="#008080">

<a name="top"></a>
<h1>Editing "$safein{'file'}" database</h1>

$topmsg

EOF
}

# Print common footer
sub printfooter {
    print <<EOF ;

<p><hr>

<a href="http://www.jmarshall.com/tools/dbmedit/"><i>DBMEdit 1.0</i></a>

<p>

$debug
</body>
</html>
EOF
}

# Display the main table to the user
sub displaymaintable {
    my ($numrecs) = scalar( keys %dbdata );
    my ($plural) = ( $numrecs == 1 ) ? '' : 's';
    my ( $safekey, $safekeyurl, $safefield, $has_backslashes );
    &printheader;
    print <<EOF ;

<h2>$numrecs record$plural shown</h2>

<p>Edit a record by following the link in the "key" column.

<p><table width="100%" cellspacing=0 cellpadding=0><tr>
    <td><b><a href="#addrecord">Add new record</a></b></td>
    <td align=center><b><a href="$ENV{'SCRIPT_NAME'}?$dbdefnget">Refresh table</a></b></td>
    <td align=right><b><a href="$safein{'referer'}">Exit from database session</a></b></td>
</tr></table>

<hr>

<table border>
<tr>
    <th><font color=blue>key</font></th>
EOF

    for ( 0 .. $#column ) { print "    <th>$title[$_]</th>\n" }

    print "</tr>\n";

    foreach $key ( sort keys %dbdata ) {
        $safekey    = &HTMLescape( &slashescape($key) );
        $safekeyurl = &urlencode($key);
        print <<EOF ;
    <td><font color=blue>
        <a href="$ENV{'SCRIPT_NAME'}?$dbdefnget&cmd=edit&key=$safekeyurl">$safekey</a>
        </font></td>
EOF

        # show \n as line break, but show all other control codes as "\..."
        foreach ( split( /$delim/, $dbdata{$key} ) ) {
            $safefield = &HTMLescape( &slashescapetextarea($_) );
            $safefield =~ s/\n/<br>\n/g;
            print "    <td>", $safefield, "</td>\n";
            $has_backslashes ||= ( $safefield =~ /\\/ );
        }
        print "</tr>\n";
    }

    print "</table>\n\n";
    print
      "<p><b><i>* Backslashes indicate escaped characters, as in Perl.</i></b>\n\n"
      if $has_backslashes;

    print <<EOF ;
<p><hr>
<a name="addrecord"></a>
<h2>Add a record:</h2>

<ul>
<li>To add a record, fill in this form and press the button below.
<li>Fields marked with <b>*</b> become read-only after the record is added.
<li>If you leave the <b><font color=blue>key</font></b> field blank, a
unique numeric key will be generated.
<li>You may use backslash-escaped characters, as in Perl (e.g. \\n, \\x7f).
Note that using the delimiter string (currently "$safedelim") in a value
may cause problems.
</ul>

<form action="$ENV{'SCRIPT_NAME'}" method=post>
<input type=hidden name="cmd" value="add">
<input type=hidden name="time" value="$now">
$dbdefnpost

<table>
<tr><td><b><font color=blue>key:</font></b></td>
    <td><b><font color=blue><input name="key" size=20></font><b></td></tr>
EOF

    &calctablesize;
    my ( $fieldname, $width, $height, $rostar );
    for ( 0 .. $lastcol ) {
        $fieldname = sprintf( "in_%03d", $_ + 1 );    # max 999 fields
        $rostar = $flags[$_]{'r'} ? '*' : '';
        print "<tr valign=top><td><b>$title[$_]:$rostar</b></td>\n";
        if ( $flags[$_]{'t'} ) {
            $width  = $maxwidth[$_] > 20 ? $maxwidth[$_]      : 20;
            $width  = $width < 60        ? $width             : 60;
            $height = $maxheight[$_] > 1 ? $maxheight[$_] + 1 : 2;
            $height = $height < 10       ? $height            : 10;
            print
              qq(    <td><textarea name="$fieldname" rows=$height cols=$width></textarea></td></tr>\n);
        }
        else {
            $width = $maxwidth[$_] ? $maxwidth[$_] + 1 : 20;
            print qq(    <td><input name="$fieldname" size=$width></td></tr>\n);
        }
    }

    print <<EOF ;
</table>

<p>
<input type=submit value="Add this record">
<input type=reset value="Clear values">
</form>

<hr>

<table width="100%" cellspacing=0 cellpadding=0><tr>
    <td><b><a href="#top">Go to top of page</a></b></td>
    <td align=right><b><a href="$safein{'referer'}">Exit from database session</a></b></td>
</tr></table>

EOF

    &printfooter;

}    # sub displaymaintable()

# Display a form with a record to edit
sub displayeditform {
    my ( @field, @safefield, $fieldname, $width );
    my ($safekey) = &slashescape( $safein{'key'} );

    &HTMLdie("That record was just deleted.")
      unless defined( $dbdata{ $in{'key'} } );

    &printheader;

    print <<EOF ;

<table width="100%" cellspacing=0 cellpadding=0><tr>
    <td><b><a href="$ENV{'SCRIPT_NAME'}?$dbdefnget">Go to main table</a></b></td>
    <td align=right><b><a href="$safein{'referer'}">Exit from database session</a></b></td>
</tr></table>
<hr>

<form action="$ENV{'SCRIPT_NAME'}" method=post>
<input type=hidden name="cmd" value="update">
<input type=hidden name="key" value="$safekey">
<input type=hidden name="time" value="$now">
$dbdefnpost

<h2>Edit a record:</h2>

<ul>
<li>To edit this record, modify the values below and press the "Update" button.
<li>You may use backslash-escaped characters, as in Perl (e.g. \\n, \\x7f).
Note that using the delimiter string (currently "$safedelim") in a value
may cause problems.
</ul>

<table>
<tr><td><b><font color=blue>key:</font></b></td>
    <td><b><font color=blue>$safein{'key'}</font><b></td></tr>
EOF

    &calctablesize;
    @field = split( /$delim/, $dbdata{ $in{'key'} } );
    @safefield = map { &HTMLescape( &slashescape($_) ) } @field;
    for ( 0 .. $lastcol ) {
        $fieldname = sprintf( "in_%03d", $_ + 1 );    # max 999 fields
        print "<tr valign=top><td><b>$title[$_]:</b></td>\n";

        # text areas
        if ( $flags[$_]{'t'} ) {
            my ($safefieldta) =
              &HTMLescape( &slashescapetextarea( $field[$_] ) );
            if ( $flags[$_]{'r'} ) {
                $safefieldta =~ s/\n/<br>\n/g;
                print
                  qq(    <td><input type=hidden name="$fieldname" value="$safefield[$_]">$safefieldta</td></tr>\n);
            }
            else {
                $width  = $maxwidth[$_] > 20 ? $maxwidth[$_]      : 20;
                $width  = $width < 60        ? $width             : 60;
                $height = $maxheight[$_] > 1 ? $maxheight[$_] + 1 : 2;
                $height = $height < 10       ? $height            : 10;
                print
                  qq(    <td><textarea name="$fieldname" rows=$height cols=$width>$safefieldta</textarea></td></tr>\n);
            }

            # ordinary text fields
        }
        else {
            if ( $flags[$_]{'r'} ) {
                print
                  qq(    <td><input type=hidden name="$fieldname" value="$safefield[$_]">$safefield[$_]</td></tr>\n);
            }
            else {
                $width = $maxwidth[$_] ? $maxwidth[$_] + 1 : 20;
                print
                  qq(    <td><input name="$fieldname" value="$safefield[$_]" size="$width"></td></tr>\n);
            }
        }

    }

    print <<EOF ;
</table>

<p>
<input type=submit value="Update this record">
<input type=reset value="Reset values">
</form>

<hr>
<p><font color=red>

<form action="$ENV{'SCRIPT_NAME'}" method=post>
<input type=hidden name="cmd" value="delete">
<input type=hidden name="key" value="$safein{'key'}">
<input type=hidden name="time" value="$now">
$dbdefnpost

<input type=checkbox name="confirm">Delete this record
<input type=submit value="Delete this record">

</form>
</font>

<p>To delete this record, check the checkbox and press the button.

<hr>

<table width="100%" cellspacing=0 cellpadding=0><tr>
    <td><b><a href="$ENV{'SCRIPT_NAME'}?$dbdefnget">Go to main table</a></b></td>
    <td align=right><b><a href="$safein{'referer'}">Exit from database session</a></b></td>
</tr></table>

EOF

    &printfooter;

}    # sub displayeditform()

# Display a starting form to the user if no database has been named.
# jsm-- how could color improve this?
sub displaystartform {
    print <<EOF ;
Content-type: text/html

<html>
<head>
<title>Edit a DBM file</title>
</head>
<body bgcolor=white vlink="#008080">

<h1>Edit a DBM file</h1>

<h2>Define your DBM database:</h2>

<form action="$ENV{'SCRIPT_NAME'}" method=get>
<table>
<tr><td><b>File Name:</b></td>
    <td><input name="file"></td></tr>
<tr><td><b>Column Descriptions:</b></td>
    <td><input name="columns" size=50></td></tr>
<tr><td><b>ASCII Values of Delimiter:</b></td>
    <td><input name="delim"></td></tr>
</table>
<br><input type=submit value="Edit DBM file">
</form>

<hr>

<h2>How to enter the fields</h2>

<dl>
<p><dt><b>File Name:</b>
<dd>Enter the DBM filename with no extension.  Don't include any
    directory component.

<p><dt><b>Column Descriptions:</b>
<dd>Enter a comma-separated list of text strings.  Each column name may
    be followed by a ':' and optional one-letter flags. Currently
    supported flags are:
    <blockquote>
        <table border cellpadding=5>
        <tr><td><b><tt><font size="+1">r</font></tt></b></td>
            <td>Display field as read-only after it's first entered.
                This will protect against accidental erasure, but NOT
                against a malicious user.</td></tr>
        <tr><td><b><tt><font size="+1">t</font></tt></b></td>
            <td>Allow multi-line (textarea) input instead of a single-line
                entry field.</td></tr>
        </table>
    </blockquote>
    <p>An example of a list of column descriptions:
    <blockquote>
        <b><tt>Name, Birthdate:r, Favorite Quote:t</tt></b>
    </blockquote>

    <p>Column descriptions affect the display only.  Nothing about them is
    stored in the database.

<p><dt><b>ASCII Values of Delimiter:</b>
<dd>Enter a list of decimal numbers, representing the ASCII values of the
    characters in the delimiter (which may be multi-char).  For example,
    "13&nbsp;10" means CRLF.  The default is "0", which is one null
    character.

    <p>Note that the data in the database fields can't contain the
    delimiter string, or the database will get messed up.  If you need
    to put arbitrary binary data in a field, use a long sequence of
    random bytes for the delimiter, like
    "188&nbsp;45&nbsp;217&nbsp;206&nbsp;51".  Five bytes means you'll
    mess it up about once for every terabyte (1000&nbsp;GB) you store.


</dl>

EOF

    &printfooter;

    #   exit ;
    return;

}    # sub displaystartform()

#----- Utilities copied in from other places -------------------------

# Read all CGI vars into an associative array; return the array.
# Supports application/x-www-form-urlencoded and multipart/form-data.
# Does not distinguish between file-type input and user-entered input;
#   entire file contents are saved in a normal array element.
# When using multipart/form-data, cannot handle multiple files with same
#   name; cannot handle multipart/mixed type with several files.
sub getcgivars {
    local ( $in,   %in );
    local ( $name, $value );

    # First, read entire string of CGI vars into $in
    if ( $ENV{'REQUEST_METHOD'} eq 'GET' ) {
        $in = $ENV{'QUERY_STRING'};

    }
    elsif ( $ENV{'REQUEST_METHOD'} eq 'POST' ) {
        $env_ct = $ENV{'CONTENT_TYPE'};
        if ( $env_ct =~ m#^application/x-www-form-urlencoded\b#i ) {
            $ENV{'CONTENT_LENGTH'}
              || &HTMLdie("No Content-Length sent with the POST request.");
            read( STDIN, $in, $ENV{'CONTENT_LENGTH'} );
        }
        else {
            &HTMLdie("Unsupported Content-Type: $env_ct");
        }

    }
    else {
        &HTMLdie("Script was called with unsupported REQUEST_METHOD.");
    }

    # Resolve and unencode name/value pairs into %in
    foreach ( split( '&', $in ) ) {
        s/\+/ /g;
        ( $name, $value ) = split( '=', $_, 2 );
        $name =~ s/%(..)/sprintf("%c",hex($1))/ge;
        $value =~ s/%(..)/sprintf("%c",hex($1))/ge;
        $in{$name} .= "\0" if defined( $in{$name} ); # concatenate multiple vars
        $in{$name} .= $value;
    }

    return %in;

}

# Die, outputting HTML error page
# If no $title, use global $errtitle, or else default title
sub HTMLdie {
    local ( $msg, $title ) = @_;
    $title = ( $title || $errtitle || "CGI Error" );
    print <<EOF ;
Content-Type: text/html

<html>
<head>
<title>$title</title>
</head>
<body>
<h1>$title</h1>
<h3>$msg</h3>
</body>
</html>
EOF

    #    exit ;
    return;
}

# Returns the URL-encoded version of a string
sub urlencode {
    local ($s) = @_;
    $s =~ s/(\W)/ '%' . sprintf('%02x',ord($1)) /ge;
    return $s;
}

# create URL-encoded QUERY_STRING for an associative array
sub urlencodelist {
    local (%a) = @_;
    return join( '&',
        map { &urlencode($_) . '=' . &urlencode( $a{$_} ) }
        grep( defined( $a{$_} ), keys %a ) );
}

# returns a subset of associative array
sub subhash {
    local ( *a, @keys ) = @_;
    local (%ret);
    @ret{@keys} = @a{@keys};
    return %ret;
}

# Escape any &"<> chars to &xxx; and return resulting string
sub HTMLescape {
    local ($s) = @_;
    $s =~ s/&/&amp;/g;    # must be before all others
    $s =~ s/"/&quot;/g;
    $s =~ s/</&lt;/g;
    $s =~ s/>/&gt;/g;
    return $s;
}

# create hidden form variables for an associative array
sub hiddenvars {
    local (%a) = @_;
    local ($ret);

    foreach ( keys %a ) {
        if ( defined( $a{$_} ) ) {
            $ret .=
                '<input type=hidden name="'
              . &HTMLescape($_)
              . '" value="'
              . &HTMLescape( $a{$_} ) . "\">\n";
        }
    }
    return $ret;
}

#---------------------------------------------------------------------
#
#   SOME COMMENTS, AND MINOR DOCUMENTATION ON PROGRAM INTERNALS:
#
#---------------------------------------------------------------------
#
#   The goal of this script is to edit DBM files, not to be a
#   full-purpose database, and design decisions were made on this basis.
#   Many more powerful features could easily be added, but may place
#   constraints on the DBM file, or require auxilliary files, etc.
#
#   The data saved in the database is pretty flexible.  It can be any data,
#   even binary data; the only restriction is that the fields must not
#   contain the delimiter string.  The key is not as flexible, by design;
#   the user is not encouraged to use binary data in the key.
#
#   This program is made to be simple to use, so has some minor
#   limitations.  Examples:  the data cannot contain the delimiter string,
#   titles cannot contain commas or colons, etc.  All of these could be
#   overcome by adding complexity to the program, if there is demand.
#
#   This uses rudimentary file locking to protect against simultaneous
#   accesses.  A lock file is created, and an exclusive lock is held on
#   it for the duration of the script run.
#
#   NOTE THAT SECURITY IMPLEMENTED HERE IS LIMITED AT BEST.  It relies
#   on the authentication of whoever's running the script.  To add more
#   security would require implementing some scheme involving other files
#   (e.g. a password file) and I'm trying to keep this simple, relying
#   only on the DBM file.
#
#   CGI input fields:
#       file:      name of DBM file to edit
#       delim:     ASCII value of delimiter character to use (default is \0)
#       columns:   comma-separated list of column titles, followed by
#                      optional one-letter flags after a colon, e.g.
#                      "fullname:ru".  Flags may take non-alphabetic values,
#                      e.g. "fullname:rw30".
#       referer:   the URL to return to when finished
#
#       cmd:       command to perform; default is "show"
#       confirm:   used to confirm some commands
#       time:      time the page was loaded; used for careful updates
#
#       key:       key of record to be processed
#       in_001, in_002, ...: input values when a record is added or changed
#
#   Currently supported commands are:
#       show:    show the full table of all records (default)
#       edit:    present the user with a form to edit a record (needs "key")
#       add:     add a new record (needs "key" and "in_nnn" values)
#       update:  update the record (needs "key" and "in_nnn" values)
#       delete:  delete the record with the given key (needs "key")
#
#   Currently supported column flags are:
#       r:  read-only (for convenience only, NOT security)
#       t:  textarea field instead of one-line input field
#
#   Not supported; which of these would be useful?
#       w:  numeric width of column
#       u:  unique-- when adding records, a unique value is generated
#               for this column.
#       d:  date/timestamp, either for creation time or mod time of record
#       c:  calculated from other fields, maybe takes form ":c1+2*3", as
#               long as value is non-alphabetic.  Fancy; is it actually
#               useful?
#
#       Could also support __columns, possibly to pass db-wide flags (e.g.
#       alternate display style).
#
#   A lot of features would be relatively simple to add, if there is demand.
#
#
#   OTHER TO DO:
#     Accommodate C-style data (with no delimiters, possibly null-terminated).
#       This would require :w flag on every column.
#     Would a query function be useful?
#
#
#   BUGS:
#
#   If you bounce on the Add button, and you didn't enter a "key", you
#   may add the record multiple times.  I think this is a fact of life:
#   How do we know several users aren't submitting the records at the
#   same time?  To solve this would require something like keeping track
#   of some ID of the locking client, blech.  Maybe save such an ID in
#   the lock file itself?
#
#---------------------------------------------------------------------
