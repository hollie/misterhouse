# ----------------------------------------------------------------------------
# vsDB (verysimple database) Module
# Copyright (c) 2001 Jason M. Hinkle. All rights reserved. This module is
# free software; you may redistribute it and/or modify it under the same
# terms as Perl itself.
# For more information see: http://www.verysimple.com/scripts/
#
# LEGAL DISCLAIMER:
# This software is provided as-is.  Use it at your own risk.  The
# author takes no responsibility for any damages or losses directly
# or indirectly caused by this software.
# ----------------------------------------------------------------------------
package vsDB;
require 5.000;
$VERSION = "1.3.9";
$ID      = "vsDB.pm";

#_____________________________________________________________________________
sub new {
    my $class     = shift;
    my %keyValues = @_;
    my ( %fieldNames, @fileArray, @row, @filterArray );

    # if no delimiter is specified, then make it a tab char.
    $keyValues{'delimiter'} = "\t" unless defined( $keyValues{'delimiter'} );

    my $this = {
        fileName          => $keyValues{'file'},
        delimiter         => $keyValues{'delimiter'},
        fieldNames        => \%fieldNames,
        fileArray         => \@fileArray,
        filterArray       => \@filterArray,
        row               => \@row,
        recordCount       => 0,
        filterRecordCount => 0,
        absolutePosition  => 0,
        pageSize          => 10,
        EOF               => 1,
        isOpen            => 0,
        lastError         => '',
        appendOnly        => 1,
        isDirty           => 0,
        originalCount     => 0,
        CR                => '<CR>',
        LF                => '<LF>',
    };
    bless $this;
    return $this;
}

# ###########################################################################
# PUBLIC PROPERTIES

#_____________________________________________________________________________
sub Version {
    return $VERSION;
}

#_____________________________________________________________________________
sub ID {
    return $ID;
}

#_____________________________________________________________________________
sub LastError {
    my ($this) = shift;
    return $this->{'lastError'};
}

#_____________________________________________________________________________
sub AbsolutePosition {
    my ($this)     = shift;
    my ($newValue) = shift;
    if ( defined($newValue) ) {
        $this->{'absolutePosition'} = $newValue;
        $this->_RefreshRow;
    }
    else {
        return $this->{'absolutePosition'};
    }
}

#_____________________________________________________________________________
sub ActivePage {
    my ($this)     = shift;
    my ($newValue) = shift;
    if ( defined($newValue) ) {
        $newValue = $this->PageCount if ( $newValue > $this->PageCount );
        $this->{'absolutePosition'} =
          ( $this->{'pageSize'} * ( $newValue - 1 ) ) + 1;

        # make sure we are on the right page if filtered
        while ( $this->{'filterArray'}[ $this->{'absolutePosition'} ] ) {
            $this->{'absolutePosition'}++;
        }
        $this->_RefreshRow;
        return 1;
    }
    else {
        # BUG - when filtering, this returns the wrong value
        return 1 if ( $this->{'absolutePosition'} == 1 );
        my ($count) =
          ( ( $this->{'absolutePosition'} - 1 ) / $this->{'pageSize'} );    #/
        my ($activePage) = int($count) + 1;
        $activePage = $this->PageCount if ( $activePage > $this->PageCount );
        return $activePage;
    }

}

#_____________________________________________________________________________
sub PageSize {
    my ($this)     = shift;
    my ($newValue) = shift;
    if ( defined($newValue) ) {
        $this->{'pageSize'} = int($newValue) if ( int($newValue) > 0 );
        return 1;
    }
    else {
        return $this->{'pageSize'};
    }
}

#_____________________________________________________________________________
sub PageCount {
    my ($this)  = shift;
    my ($count) = ( $this->{'filterRecordCount'} / $this->{'pageSize'} );    #/
    if ( int($count) < $count ) { $count = int($count) + 1 }
    return $count;
}

#_____________________________________________________________________________
sub File {
    my ($this)   = shift;
    my ($newVal) = shift;

    # if the file has changed, then we can't just append...
    if ($newVal) { $this->{'appendOnly'} = 0 }
    return $this->_GetSetProperty( "fileName", $newVal );
}

#_____________________________________________________________________________
sub CR {
    return shift->_GetSetProperty( "CR", shift );
}

#_____________________________________________________________________________
sub LF {
    return shift->_GetSetProperty( "LF", shift );
}

#_____________________________________________________________________________
sub Delimiter {
    return shift->_GetSetProperty( "delimiter", shift );
}

#_____________________________________________________________________________
sub RecordCount {
    return shift->{'filterRecordCount'};
}

#_____________________________________________________________________________
sub EOF {
    my ($this) = shift;
    return 1 if ( $this->RecordCount < 1 );
    return $this->{'EOF'};
}

#_____________________________________________________________________________
sub FieldValue {
    my ($this) = shift;
    return "EOF" if ( $this->{'EOF'} );
    my ($fieldName) =
      shift || return "ERROR: FieldValue(): Field Name Required";
    my ($newValue)       = shift;
    my ($fieldNumber)    = $this->{'fieldNames'}{$fieldName};
    my ($lineFeed)       = chr(10);
    my ($carriageReturn) = chr(13);
    my ($crReplacement)  = $this->{'CR'};
    my ($lfReplacement)  = $this->{'LF'};
    return "ERROR: FieldValue('" . $fieldName . "') Field Not Found."
      if ( !defined($fieldNumber) );

    # if a new value is defined, update, otherwise return current value
    if ( defined($newValue) ) {
        $this->{'isDirty'} = 1;
        if ( $this->{'absolutePosition'} <= $this->{'originalCount'} ) {
            $this->{'appendOnly'} = 0;
        }

        # make sure we don't corrupt the file with a delimiter or
        # line break in the data.
        $newValue =~ s/$this->{'delimiter'}//g;
        $newValue =~ s/$carriageReturn/$crReplacement/g;
        $newValue =~ s/$lineFeed/$lfReplacement/g;

        # $newValue =~ s/\n//g; # (should already be dealt with)
        $this->{'row'}[$fieldNumber] = $newValue;

        # update the fileArray to match the current row.  originally used
        # a join on the row array, but that caused unititialize var errors
        # when there are blank fields.  this could probably be improved by
        # only updating when the cursor is moved or commit is called
        my ( $newRow, $newField );
        my ($colNum) = 0;
        foreach ( $this->FieldNames ) {
            $newField = $this->{'row'}[$colNum];
            if ( !defined($newField) ) { $newField = "" }
            $newRow .= $newField;
            $newRow .= $this->{'delimiter'};
            $colNum++;
        }

        # get rid of the last delimiter
        for ( my $x = 1; $x <= length( $this->{'delimiter'} ); $x++ ) {
            chop($newRow);
        }

        $this->{'fileArray'}[ $this->{'absolutePosition'} ] = $newRow . "\n";
        return 1;
    }
    else {
        # make sure we return a defined value || won't work because it doesn;t
        # differentiate between 0 and null
        if ( defined( $this->{'row'}[$fieldNumber] ) ) {
            my $returnVal = $this->{'row'}[$fieldNumber];
            $returnVal =~ s/$crReplacement/$carriageReturn/g;
            $returnVal =~ s/$lfReplacement/$lineFeed/g;
            return $returnVal;

        }
        else {
            return "";
        }
    }
}

#_____________________________________________________________________________
sub FieldNames {

    # returns all fieldnames as an array
    my ($this) = shift;
    return 0 unless ( $this->{'isOpen'} );
    my ($fieldRow) = $this->{'fileArray'}[0];
    chop($fieldRow);
    my (@tempfieldNames) = split( $this->{'delimiter'}, $fieldRow );
    return @tempfieldNames;
}

#_____________________________________________________________________________
sub Row {

    # returns current row values as an array
    my ($this) = shift;
    return 0 unless ( $this->{'isOpen'} );
    my ($tempRow) = $this->{'row'};
    return @$tempRow;
}

#_____________________________________________________________________________
sub xml {

    # returns current recordset as xml
    my ($this)           = shift;
    my ($strRootName)    = shift || "vsDB";
    my ($strElementName) = shift || "Record";
    my ($strXml);

    $strXml = "<?xml version=\"1.0\"?>\n";
    $strXml .= "<!DOCTYPE $strRootName>\n";
    $strXml .= "<$strRootName>\n";
    $this->MoveFirst;
    my (@fields) = $this->FieldNames;
    my ( $field, $fieldValue );
    until ( $this->EOF ) {
        $strXml .= "<$strElementName>\n";
        foreach $field (@fields) {
            $fieldValue = $this->FieldValue($field);
            $strXml .= "<$field>$fieldValue</$field>\n";
        }
        $strXml .= "</$strElementName>\n";
        $this->MoveNext;
    }
    $strXml .= "</$strRootName>\n";

    return $strXml;
}

#_____________________________________________________________________________
sub MoveNext {

    # moves the curser to the next row in the data file
    my ($this) = shift;
    return 0 unless ( $this->{'isOpen'} );
    return 0 if ( $this->{'EOF'} );
    $this->{'absolutePosition'}++;
    while ( $this->{'filterArray'}[ $this->{'absolutePosition'} ] ) {
        $this->{'absolutePosition'}++;
    }
    $this->_RefreshRow;
    return 1;
}

#_____________________________________________________________________________
sub MovePrevious {

    # moves the curser to the previous row in the data file
    my ($this) = shift;
    return 0 unless ( $this->{'isOpen'} );
    return 0 if ( $this->{'absolutePosition'} < 2 );
    $this->{'absolutePosition'}--;
    while ( $this->{'filterArray'}[ $this->{'absolutePosition'} ] ) {
        $this->{'absolutePosition'}--;
    }
    $this->_RefreshRow;
    return 1;
}

#_____________________________________________________________________________
sub MoveFirst {

    # moves the curser to the first row in the data file
    my ($this) = shift;
    return 0 unless ( $this->{'isOpen'} );
    $this->{'absolutePosition'} = 1;
    while ( $this->{'filterArray'}[ $this->{'absolutePosition'} ] ) {
        $this->{'absolutePosition'}++;
    }
    $this->_RefreshRow;
    return 1;
}

#_____________________________________________________________________________
sub MoveLast {

    # moves the curser to the last row in the data file
    my ($this) = shift;
    return 0 unless ( $this->{'isOpen'} );
    $this->{'absolutePosition'} = $this->{'recordCount'};
    while ( $this->{'filterArray'}[ $this->{'absolutePosition'} ] ) {
        $this->{'absolutePosition'}--;
    }
    $this->_RefreshRow;
    return 1;
}

#_____________________________________________________________________________
sub Delete {

    # delete the current row
    my ($this) = shift;
    return 0 unless ( $this->{'isOpen'} );
    return 0 if $this->{'recordCount'} < 1;
    return 0 if ( $this->{'EOF'} );
    $this->{'isDirty'} = 1;
    if ( $this->{'absolutePosition'} <= $this->{'originalCount'} ) {
        $this->{'appendOnly'} = 0;
    }
    my ($tempArray) = $this->{'fileArray'};
    splice( @$tempArray, $this->{'absolutePosition'}, 1 );
    $this->{'recordCount'}--;
    $this->{'filterRecordCount'}--;
    $this->_RefreshRow;
    return 1;
}

#_____________________________________________________________________________
sub AddNew {

    # add a new row to the end of the recordset
    my ($this) = shift;
    return 0 unless ( $this->{'isOpen'} );
    $this->{'isDirty'} = 1;
    $this->{'recordCount'}++;
    $this->{'absolutePosition'} = $this->{'recordCount'};
    $this->{'filterRecordCount'}++;

    # the number of delimiter chars is fieldCount - 1
    my ($delimiterCount) = 0;
    foreach ( $this->FieldNames ) {
        $delimiterCount++;
    }
    $delimiterCount--;

    # add the correct number of colums using the delimiterCount
    $this->{'fileArray'}[ $this->{'absolutePosition'} ] =
      ( $this->{'delimiter'} x $delimiterCount ) . "\n";

    $this->MoveLast;

    return 1;
}

#_____________________________________________________________________________
sub AddNewField {

    # add a new row to the end of the recordset
    my ($this)         = shift;
    my ($newFieldName) = shift || return 0;
    my ($defaultValue) = shift;
    $defaultValue = '' unless ( defined($defaultValue) );

    $this->{'isOpen'}     = 1;
    $this->{'appendOnly'} = 0;
    $this->{'isDirty'}    = 1;

    # update the fieldnames array
    my ($nextField) = 0;
    foreach ( $this->FieldNames ) {
        $nextField++;
    }
    $this->{'fieldNames'}{$newFieldName} = $nextField;

    chop( $this->{'fileArray'}[0] );

    # update the first row in the file array
    if ( $nextField > 0 ) {
        $this->{'fileArray'}[0] .= $this->{'delimiter'};
    }
    $this->{'fileArray'}[0] .= $newFieldName . "\n";

    return 1;
}

#_____________________________________________________________________________
sub Max {

    # returns the maximum value for the specified column
    my ($this)      = shift;
    my ($fieldName) = shift || return 0;
    my ($alpha)     = shift || 0;
    my ($curVal);
    my ($curPos) = $this->{'absolutePosition'};
    $this->MoveFirst;
    my ($maxVal) = $this->FieldValue($fieldName);
    while ( !$this->EOF ) {
        $curVal = $this->FieldValue($fieldName);
        if ( !$alpha ) {
            if ( $curVal ne "" ) {
                if ( int($curVal) > int($maxVal) ) { $maxVal = $curVal }
            }
        }
        else {
            if ( ( lc($curVal) cmp lc($maxVal) ) > 0 ) { $maxVal = $curVal }
        }
        $this->MoveNext;
    }
    $this->AbsolutePosition($curPos);
    return $maxVal;
}

#_____________________________________________________________________________
sub Min {

    # returns the maximum value for the specified column
    my ($this)      = shift;
    my ($fieldName) = shift || return 0;
    my ($alpha)     = shift || 0;
    my ($curVal);
    my ($curPos) = $this->{'absolutePosition'};
    $this->MoveFirst;
    my ($minVal) = $this->FieldValue($fieldName);
    while ( !$this->EOF ) {
        $curVal = $this->FieldValue($fieldName);
        if ($alpha) {
            if ( $curVal ne "" ) {
                if ( int($curVal) < int($minVal) ) { $minVal = $curVal }
            }
        }
        else {
            if ( ( lc($curVal) cmp lc($minVal) ) < 0 ) { $minVal = $curVal }
        }
        $this->MoveNext;
    }
    $this->AbsolutePosition($curPos);
    return $minVal;
}

#_____________________________________________________________________________
sub Filter {

    # $obj->Filter($fieldName,$operator,$criteria);

    # TODO: > and < are not working properly... maybe text comparison problem??
    my ($this)      = shift;
    my ($fieldName) = shift || return 0;
    my ($operator)  = shift || "eq";
    my ($criteria)  = shift;
    $criteria = "" unless defined($criteria);

    my ($filterSetting);

    $this->{'filterArray'}[0] = 0;
    $this->MoveFirst;

    while ( !$this->EOF ) {
        $filterSetting = 0;
        if ( $operator eq "eq" && $this->FieldValue($fieldName) ne $criteria ) {
            $filterSetting = 1;
        }
        elsif ( $operator eq "ne"
            && !( $this->FieldValue($fieldName) ne $criteria ) )
        {
            $filterSetting = 1;
        }
        elsif (
            $operator eq "like"
            && !(
                index( lc( $this->FieldValue($fieldName) ), lc($criteria), 0 )
                + 1
            )
          )
        {
            $filterSetting = 1;
        }
        elsif ( $operator eq ">"
            && !( $this->FieldValue($fieldName) > $criteria ) )
        {
            $filterSetting = 1;
        }
        elsif ( $operator eq "<"
            && !( $this->FieldValue($fieldName) < $criteria ) )
        {
            $filterSetting = 1;
        }

        # print "<p>" . $this->{'absolutePosition'} . ": " . $filterSetting . "<p>";
        $this->{'filterArray'}[ $this->{'absolutePosition'} ] = $filterSetting;

        $this->{'filterRecordCount'} -= 1 if ($filterSetting);
        $this->MoveNext;
    }
    $this->MoveFirst;
    return 1;
}

#_____________________________________________________________________________
sub RemoveFilter {
    my ($this) = shift;
    my (@newArray);
    $this->{'filterArray'}       = \@newArray;
    $this->{'filterRecordCount'} = $this->{'recordCount'};
    return 1;
}

#_____________________________________________________________________________
sub Commit {

    # update the file, saving all changes made
    my ($this)     = shift;
    my ($useFlock) = shift || 0;
    my ($fileName) = $this->{'fileName'};

    # if no changes were made, don't bother writing to the file
    if ( !$this->{'isDirty'} ) { return 1 }

    if ( $this->{'appendOnly'} ) {

        # if only new records were added, just append to the file
        my ($nCount);
        if ( !open( OUTPUTFILE, ">>$fileName" ) ) {
            $this->{'lastError'} =
              "Commit: Couldn't Open DataFile '$fileName' For Appending";
            return 0;
        }
        flock( OUTPUTFILE, 2 ) if ($useFlock);
        my ($tempArray) = $this->{'fileArray'};
        for (
            $nCount = $this->{'originalCount'} + 1;
            $nCount <= $this->{'recordCount'};
            $nCount++
          )
        {
            print OUTPUTFILE @$tempArray[$nCount];
        }
    }
    else {
        # if records were changed or deleted, we have to replace them all
        if ( !open( OUTPUTFILE, ">$fileName" ) ) {
            $this->{'lastError'} =
              "Commit: Couldn't Open DataFile '$fileName' For Writing";
            return 0;
        }
        flock( OUTPUTFILE, 2 ) if ($useFlock);
        my ($tempArray) = $this->{'fileArray'};
        print OUTPUTFILE join( '', @$tempArray );
    }
    close(OUTPUTFILE);
    flock( OUTPUTFILE, 8 ) if ($useFlock);
    return 1;
}

#_____________________________________________________________________________
sub Sort {

    # sorts the datafile on the given column
    # obj->Sort($field);
    # if $field is ommited, or an invalid fieldname is used, defaults to
    # the left-most column.

    my ($this)      = shift;
    my ($fieldName) = shift || '0';
    my ($desc)      = shift || '0';
    my ($delimiter) = $this->{'delimiter'};

    # can't append once we've changed the sort order
    $this->{'appendOnly'} = 0;

    # sorting will mess up filter, so lets remove it
    $this->RemoveFilter;

    # get the fieldnumber (or default to leftmost column)
    my ($fieldNumber) = $this->{'fieldNames'}{$fieldName} || 0;

    # make a copy of the unsorted array pointer
    my ($unsortedArray) = $this->{'fileArray'};

    # remove the column names from the array
    my ($fieldNames) = shift(@$unsortedArray);

    # now we sort the unsorted array
    my (@sortedArray) = sort {

        # custom sorting comparison routine
        my (@aVals) = split( $delimiter, $a );
        my (@bVals) = split( $delimiter, $b );
        if ($desc) {
            return $bVals[$fieldNumber] cmp $aVals[$fieldNumber];
        }
        else {
            return $aVals[$fieldNumber] cmp $bVals[$fieldNumber];
        }
        undef(@aVals);
        undef(@bVals);
    } @$unsortedArray;

    # get rid of the unsorted array
    undef($unsortedArray);

    # put the column names back in and update the array pointer
    unshift( @sortedArray, $fieldNames );
    $this->{'fileArray'} = \@sortedArray;

    $this->MoveFirst;
    return 1;
}

#_____________________________________________________________________________
sub Open {

    # open the file, store the contents as an array, get the number of
    # records and retreive the first row
    my $this      = shift;
    my $fileName  = $this->{'fileName'};
    my $delimiter = $this->{'delimiter'};
    my (@tempFileArray);

    # security check to make sure a command is not being attempted
    $fileName =~ s/;//g;
    $fileName =~ s/|//g;

    if ( !( -e $fileName ) ) {
        $this->{'lastError'} = "Open: Datafile '$fileName' Not Found";
        return 0;
    }
    elsif ( !( -r $fileName ) ) {
        $this->{'lastError'} =
          "Open: Couldn't Open DataFile '$fileName' For Reading";
        return 0;
    }

    # try to open the file
    if ( open( THISFILE, "$fileName" ) ) {
        @tempFileArray = <THISFILE>;
        close(THISFILE);
    }
    else {
        return 0;
    }

    # get the entire contents of the file
    $this->{'fileArray'} = \@tempFileArray;

    # get the number of rows
    $this->{'recordCount'} = @tempFileArray - 1;

    # get the top row, which should be fieldnames
    my $fileRow = $tempFileArray[0];
    chop($fileRow);

    # split the top row into fields
    my (@tempfieldNames) = split( $delimiter, $fileRow );
    my ($fieldName)      = "";
    my ($counter)        = 0;
    foreach $fieldName (@tempfieldNames) {
        $this->{'fieldNames'}{$fieldName} = $counter;
        $counter++;
    }

    $this->MoveFirst;
    $this->{'isOpen'} = 1;
    $this->_RefreshRow;
    $this->{'filterRecordCount'} = $this->{'recordCount'};
    $this->{'originalCount'}     = $this->{'recordCount'};
    return 1;
}

#_____________________________________________________________________________
sub Close {
    my ($this) = shift;
    $this->{'isOpen'} = 0;
    return 1;
}

# ###########################################################################
# PRIVATE METHODS

#_____________________________________________________________________________
sub DESTROY {
    my ($this) = shift;
    $this->Close;
}

#_____________________________________________________________________________
sub _RefreshRow {

    # sync the current row with the fileArray.  also do some validation to
    # make sure we haven't moved the curser out of range
    my ($this) = shift;
    return 0 unless ( $this->{'isOpen'} );

    # make sure absolutePosition is a legit value  and set EOF
    $this->{'EOF'} = 0;
    $this->{'absolutePosition'} = 1 if ( $this->{'absolutePosition'} < 1 );
    if ( $this->{'absolutePosition'} > $this->{'recordCount'} ) {
        $this->{'EOF'}              = 1;
        $this->{'absolutePosition'} = $this->{'recordCount'};
        return 1;
    }

    # now grab the next row
    my ($tempRow) = $this->{'fileArray'}[ $this->{'absolutePosition'} ];
    chop($tempRow);
    my (@row) = split( $this->{'delimiter'}, $tempRow );
    $this->{'row'} = \@row;
    return 1;
}

#_____________________________________________________________________________
sub _GetSetProperty {

    # private fuction that is used by properties to get/set values
    # if a parameter is sent in, then the property is set and true is returned.
    # if no parameter is sent, then the current value is returned
    my $this      = shift;
    my $fieldName = shift;
    my $newValue  = shift;
    if ( defined($newValue) ) {
        $this->{$fieldName} = $newValue;
    }
    else {
        return $this->{$fieldName};
    }
    return 1;
}

1;    # for require

__END__

=head1 NAME

vsDB - Simple interface to text-delimited data files

=head1 SYNOPSIS

	use vsDB;

	# create the object
	my (objDB) = new vsDB(filename=>'C:\\datafile.txt', delimiter=>'\t');

	# open the datafile	
	$objDB->Open;

	# add a new record
	$objDB->AddNew; 	

	# update the first name field for the new record 
	$objDB->FieldValue('FirstName','Jason');

	# commit the changes to disk
	$objDB->Commit;

	# move the cursor to the beginning of the resultset
	$objDB->MoveFirst;

	# print all of the first name fields
	while (!$objDB->EOF) {
		print $objDB->FieldValue('FirstName');
		$objDB->MoveNext;
	}

	# close the datafile (optional) 	
	$objDB->Close;

=head1 DESCRIPTION

vsDB provides a simple object-oriented interface for delimited
text files.  The object model is based off of Microsoft's
ADO RecordSet object, so anyone familiar with this will
find vsDB somewhat familiar.  vsDB has been tested on Win32 and
Linux.

=head1 OBJECT MODEL REFERENCE: PROPERTIES

=head2 AbsolutePosition([nNewPosition])

AbsolutePosition returns the current cursor position in the RecordSet.  If
[nNewPosition] is specified, then AbsolutePosition attempts to move the
cursor to that position.  If [nNewPosition] is out of range, AbsolutePosition
will be set to the closest valid position (usually the last record)

=head2 ActivePage([nNewPage])

ActivePage returns the current "Page" in the RecordSet.  If [nNewPage] is
specified, then ActivePage attempts to move the cursor to the first record
on the given page.  If [nNewPage] is out of range, The cursor will be
set to the closest valid position (usually the first record of the last page)

ActivePage is used along with PageSize.  See PageSize for more information.

=head2 CR([strCR])

CR is a character or string that vsDB uses to replace a Carriage Return
character that is inserted in the database.  Default is "<CR>".  The value
is used only during storage in the file and is converted back into
a Carriage Return when you request the field value.  See also: LF

=head2 Delimiter([strNewDelimiter])

Delimiter returns the delimiter character that is used to separate fields
in the datafile.  If strNewDelimiter is specified, then the delimiter is
changed.

Warning: changing the delimiter property after calling the Open method
is a very bad thing to do!  Your file may become corrupted.

=head2 EOF()

EOF (End Of File) indicates that there are no more records in the RecordSet.
If you have applied a filter, this indicates when you have reached the end
of the matching records.  This property is commonly used to loop through
a recordset, for example: while (!$objDB->EOF) { $objDB->MoveNext; }

Note: unlike the MS RecordSet object, FieldValue will not give an EOF error
if you try to access a FieldValue when the RecordSet is at EOF.  Instead
is will continue to return values for the last record in the RecordSet

=head2 FieldValue(FieldName,[NewValue])

If [NewValue] is NOT specified, then FieldValue returns the value of the
field specified (FieldName) for the record at the current cursor position.

If [NewValue] is specified, then the value of the field specified (FieldName)
for the record at the current cursor position is updated to [NewValue] and
1 is returned.

Note: any changes you make to the data will not be saved to disk until you call
the Commit method.

=head2 FieldNames()

FieldNames returns an array containing all of the field names in the datafile.
For example:

	my (@fieldNames) = $objDB->FieldNames;

=head2 File([strNewFilePath])

File specifies the full path to the datafile.  This can be specified when
the object is created or anytime before calling the Open method.  Once the
file has been opened the RecordSet will not change if you change the File
property.  However, if you change the File property and then call the
Commit method, this will save the current RecordSet to the new filepath.
In other words, it will copy the original file.

Warning: Changing the File property then calling Open again may produce
unexpected results.  If you need to access another datafile, it is recommended
that you create another vsDB object instead.

=head2 ID()

Returns module identification

=head2 LastError()

When a non-fatal error has occured, the LastError property may contain information
decribing the error.  Most methods will return 1 or 0 to indicate success or
failure.  You do not need to check these return values, but should in cases where
you suspect the method could fail.

=head2 LF([strLF])

LF is a character or string that vsDB uses to replace a Line Feed
character that is inserted in the database.  Default is "<LF>".  The value
is used only during storage in the file and is converted back into
a Line Feed when you request the field value.  See also: CR

=head2 Max(fieldName, [alpha])

Max returns the maximum value for he specified fieldName.  alpha is an optional
value that is set to 1 or 0 to indicate alphabetical characters.  By default, alpha
is set to 0, indicating that the field is numeric.

Warning: if your field contains non-numeric values, you must set alpha=1 or Max
will produce a type-mismatch error.

=head2 Min(fieldName, [alpha])

Min returns the minimum value for he specified fieldName.  alpha is an optional
value that is set to 1 or 0 to indicate alphabetical characters.  By default, alpha
is set to 0, indicating that the field is numeric.

Warning: if your field contains non-numeric values, you must set alpha=1 or Min
will produce a type-mismatch error.

=head2 PageCount()

PageCount returns the number of pages in the RecordSet.  This is essentially
the RecordCount devided by the PageSize.  If you have applied a
filter, the PageCount will indicate only matching records.

=head2 PageSize([nNewSize])

PageSize returns the current page size.  If [nNewSize] is specified, then
the PageSize is set to the new value.  PageSize is used along with ActivePage
to simplify displaying a subset of the total records.  For example, the
file contains 1,000 rows, but you want to display them to the user only
10 at a time.  The PageSize is set to 10 and you can navigate through the
results by changing the ActivePage.

=head2 RecordCount()

Returns the number of records in the RecordSet.  If you have applied a filter,
RecordCount will indicate the number of matching records.

=head2 Row()

Row returns an array containing all of the values of the current record.
For example:
	
	my (@row) = $objDB->Row;

=head2 Version()

Returns current version

=head2 xml([strRootName] [,strElementName])

Returns current recordset as xml.  strRootName and strElementName are
optional.  Default values are "vsDB" and "Record"


=head1 OBJECT MODEL REFERENCE: METHODS

=head2 AddNew()

Adds a new record to the RecordSet and moves the cursor to this new record.
The default values for all fields is an empty string.  After you add a new
record, you will want to change the FieldValues as needed.

If you are using one of the fields as a primary key, you can use the Max
property to obtain the highest ID number.

Note: any changes you make to the data will not be saved to disk until you call
the Commit method.

=head2 AddNewField(strFieldName [,strDefaultValue])

Adds a new field to the RecordSet.  strFieldName is the name of the new field.
The new field will be added to all records and set to strDefaultValue.  If
strDefaultValue is not specified, then the field will be empty.

Note: any changes you make to the data will not be saved to disk until you call
the Commit method.

=head2 Close()

In theory this would close the file, however vsDB does not keep the file handle
open.  Currently this method simply marks the object as closed.  This method
is also called automatically when the object is destroyed.

Although it is not necessary to call this method, it is recommended that you do
in case vsDB is later modified to keep the file handle open.  This might be
useful for a persistent connection to the file...?

=head2 Commit([blnUseFLock])

Commit writes the current RecordSet in memory to the filepath specified by
the File property.  This method should be called any time there have been data
modifications. blnUseFLock is an optional argument that should be 1 if flock
should be used while writing to the file.

Commit re-opens the datafile with the least amount of privledges required.  If you
have not made any changes to the RecordSet, calling Close will not access the
datafile at all.  If you have only added new records, Commit will open the datafile
for appending and append the new record.  If you have modified existing records,
the file will be opening for writing and the entire file will be updated.

=head2 Delete()

Deletes the current record in the RecordSet.

Note: any changes you make to the data will not be saved to disk until you call
the Commit method.

=head2 Filter(strFieldName,strOperator,strCriteria)

Filter provides a way to either search the RecordSet or to get a specific record
based on a primary key field.  strFieldName indicates the field that you want to
filter.  strOperator is one of the following "eq", "ne", "like", "<" or ">" to indicate
how the field is to be compared.  strCriteria indicates the search pattern that you
wish to find.

You can apply the Filter method more than once to further filter out records.  The
filters are applied as "AND."  Currently there is no support for "OR" filtering.

If you are using a primary key field, you can use the Filter method to locate
the row that you want.  For example:

	$objDB->Filter("ID","eq","25")

The Filter method moves the cursor to the first matching record in the recordset
as well as updates RecordCount and PageCount accordingly.

Note: calling Sort will remove any filters that you have applied.  Call Sort
first if you need to sort and filter the results.

=head2 MoveNext()

Advances the cursor to the next row in the RecordSet.  In other words,
it "moves" to the next record.

=head2 MovePrevious()

Moves the cursor to the previous row in the RecordSet.  In other words,
it "moves" to the previous record.

=head2 MoveFirst()

Moves the cursor to the first row in the RecordSet.

=head2 MoveLast()

Moves the cursor to the last row in the RecordSet.

=head2 Open()

Opens the datafile for reading and populates the RecordSet bases on the data in
the file.  The datafile handle is actually closed immediately after reading
the file, however the RecordSet is stored in memory.  (To sync the datafile up
with the RecordSet, refer to the Commit method.)

Warning: calling Open more than once may cause unexpected results.

=head2 RemoveFilter()

RemoveFilter removes any filtering that you have done using the Filter method
and moves the cursor to the first row in the RecordSet.

=head2 Sort(strFieldName [,Descending])

Sort sorts the RecordSet by the strFieldName.  You can sort by multiple fields
by calling the Sort method more than once with a different fieldname each time.

Descending should be 1 if you want the sort to be in descending order instead
of the default ascending order.

Note: Calling Sort will remove any Filters that you have applied.  If you want to
sort and filter, then call Sort first, then Filter.

Warning: If you call the Commit method after sorting, the records will be saved
to the datafile in the order in which they are sorted.  This may be desirable
if you always sort the same way, but proceed with caution.

=head1 VERSION HISTORY

	1.3.9: don't allow FieldValue or Delete if EOF is true
	1.3.8: added UseFLock argument to Commit method
	1.3.7: Updated error messages
	1.3.6: AddNew now moves to the last record properly
	1.3.5: fixed record jumbling bug in xml property
	1.3.4: filter "like" option made case-insensitive, updated ActivePage
	1.3.3: fixed EOF not being set properly when filtering
	1.3.2: added xml Property
	1.3.1: added Desc option to sort routine
	1.3.0: added AddNewField
	1.2.7: CR and LF properties added.  fixed bug with line breaks
	       in the data.  Added filename security check to ->Open
	1.2.6: resolved filter + sort problem.  cleaned up documentation
	1.2.5: added destructer, removed file locking code
	1.2.4: fixed PageCount and RecordCount bug when using filter
	1.2.3: optimized AddNew, fixed null field bug in FieldValue
	1.2.2: optimized file access, added more error checking
	1.2.1: Fixed ActivePage/Filter bug filtering out 1st record
	1.2.0: Added ActivePage, PageSize, PageCount properties
	1.1.4: Updated Max property to deal with numbers
	1.1.3: Added Filter method
	1.1.2: Added Sort, Min, Max methods
	1.0.1: Original Release

=head1 KNOWN ISSUES & LIMITATIONS

vsDB loads the entire datafile into an array which could cause performance
problems if your datafile grows large.  (largest test file was 17,000 records)

ActivePage and possibly other page-related properties may return unexpected
values when used in combination with filtering.

=head1 AUTHOR

Jason M. Hinkle

=head1 COPYRIGHT

Copyright (c) 2001 Jason M. Hinkle.  All rights reserved.
This module is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

