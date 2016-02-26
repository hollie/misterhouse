#$Id$
# This is based on Matthews Williams <mattrwilliams at users.sourceforge.net> original idea.
use strict;
use CGI::Carp qw(fatalsToBrowser);
use Data::Dumper;
my $shoppinglistdebug = 0;
my %param;     # hash containing data retrieve from post html form
my $html;      # html returned to browser
my %Config;    # configuration information
my $DirPath     = "$config_parms{data_dir}/ListManager";
my $ConfigFile  = "$DirPath/ListManager.cfg";
my $DefaultList = "$DirPath/shopping.lst";
my %CurrentItem;    # hash containing the whole content of shopping list.
my $Status                       = "";    # string containing the last status
my $DisplayCreateItem_Status     = "";    # status for create item window
my $DisplayCreateItem_Item       = "";
my $DisplayCreateItem_Category   = "";
my $DisplayCreateCategory_Status = "";
my $DisplayKeyboard              = 1;     # do we display the keyboard
my @Category;    # array containing category name, in file order
                 # this allow to get printed list in store aisle.
my $AtShopStatus = "";
my $NumColumns;
my $ColumnsWidth;

# read configuration file{{{
my $ConfigError = ReadConfig();
return $ConfigError if $ConfigError;
if ( $Config{'DisplayMode'} eq 'pda' ) {
    $NumColumns = $Config{'NumColumnsPDA'};
}
else {
    $NumColumns = $Config{'NumColumnsNormal'};
}
$ColumnsWidth    = 100 / $NumColumns . '%';
$DisplayKeyboard = $Config{'DisplayKeyboardPDA'}
  if $Config{'DisplayMode'} eq 'pda';
$DisplayKeyboard = $Config{'DisplayKeyboardNormal'}
  if $Config{'DisplayMode'} eq 'normal';

#}}}

my $ListFile = $Config{'CurrentList'};
my ($PrettyListName) = $ListFile =~ /.*\/(.*).lst$/;
print "I will use list $PrettyListName \n" if $shoppinglistdebug;

# parse received parameter {{{
my $Action;
foreach my $param (@ARGV) {
    $param =~ /^(.+)=(.+)$/ && do {
        $html .= "<p>$1 ** $2</p>\n" if $shoppinglistdebug;
        next if $2 eq 'Choose Action';
        $param{$1} = $2;

        #print "Param [$1] = [$2]\n";    #DEBUG
      }
}

# workaround for audrey browser
$param{'HomePageRemove'} = '' if ( exists $param{'HomePageAction'} );

#}}}
# read the shopping list from disk {{{
ReadList();

#}}}
# handle action{{{
if ( $param{'Cancel'} eq 'Cancel' ) {
    $Status = "Action canceled";

    # remove all element in %param hash
    %param = ();
}

if ( $param{'HomePageRemove'} eq 'Remove' ) {
    my $RemoveCount = 0;
    my $RemoveItem;
    foreach my $CatItem ( keys %param ) {
        if ( $param{$CatItem} eq 'uncheck' ) {
            my ( $Cat, $Item ) = split( /_/, $CatItem );
            $CurrentItem{$Cat}{$Item} = 0;
            $RemoveCount++;
            $RemoveItem = $Item;
        }
    }

    $Status = "No Item removed"                   if $RemoveCount == 0;
    $Status = "<i>$RemoveItem</i> removed"        if $RemoveCount == 1;
    $Status = "<i>$RemoveCount</i> items removed" if $RemoveCount > 1;
    WriteList();
    print "Status=[$Status]\n";
    1;
}

if ( exists $param{'DisplayManageList_ChangeList'} ) {
    $PrettyListName = $param{'DisplayManageList_ChangeList'};
    $ListFile = "$config_parms{'data_dir'}/ListManager/${PrettyListName}.lst";
    system("touch $ListFile") if ( !-f $ListFile );
    $Config{'CurrentList'} = $ListFile;
    WriteConfig();
    ReadList();
    $Status = "Using $PrettyListName";
    1;
}

if ( exists $param{'DisplayManageList_NewList'} ) {
    $PrettyListName = $param{'DisplayManageList_NewList'};
    $ListFile = "$config_parms{'data_dir'}/ListManager/${PrettyListName}.lst";
    system("touch $ListFile") if ( !-f $ListFile );
    $Config{'CurrentList'} = $ListFile;
    WriteConfig();
    ReadList();
    $Status = "Using $PrettyListName";
    1;
}

if ( exists $param{'DisplayCreateCategory_Action'} ) {
    $param{'DisplayCreateCategory_Name'} =~ s/(\w+)/\u\L$1/g;
    if (
        exists $CurrentItem{ $param{'DisplayCreateCategory_Name'} }{'DummyItem'}
      )
    {
        $DisplayCreateCategory_Status =
          "<font color=red><h3>Category $param{'DisplayCreateCategory_Name'} already exists</h3></font>";
        $param{'HomePage_Action'} = 'Create Category';
    }
    else {
        my @OldCategory = @Category;
        @Category = ();
        push @Category, $param{'DisplayCreateCategory_Name'}
          if ( $#OldCategory == -1 );
        foreach my $c (@OldCategory) {
            push @Category, $param{'DisplayCreateCategory_Name'}
              if ( $c eq $param{'DisplayCreateCategory_BeforeCategory'} );
            push @Category, $c;
        }
        $DisplayCreateCategory_Status =
          "<font color=red><h3>$param{'DisplayCreateCategory_Name'} created</h3></font>";
        $CurrentItem{ $param{'DisplayCreateCategory_Name'} }{'DummyItem'} = 1;
    }
    WriteList();
    $param{'HomePage_Action'} = 'Create Category'
      if exists $param{'DisplayCreateCategory_AddMultiple'};
}

if ( exists $param{'DisplayAtShop_Remove'} ) {
    my $num = 0;
    foreach my $CatItem ( keys %param ) {
        if ( $param{$CatItem} eq 'on' ) {
            my ( $Cat, $Item ) = split( /_/, $CatItem );
            $CurrentItem{$Cat}{$Item} = 0;
            $num++;
        }
    }
    WriteList();
    $param{'HomePage_Action'} = 'At Shop';
    $AtShopStatus = "$num items checkout" if ( $num > 0 );
    1;
}

if ( exists $param{'DisplayManageItem'} ) {
    if ( exists $param{'DisplayManageItem_submit'} )
    {    # we have change something
        my $Category = $param{'DisplayManageItem_Category'};
        foreach my $k (%param) {
            if ( $k =~ /DisplayManageItem_Ren/ ) {
                my ( $Category, $Item ) =
                  $k =~ /^DisplayManageItem_Ren_(.*)_(.*)$/;
                next if ( $Item eq $param{$k} );
                $CurrentItem{$Category}{ $param{$k} } =
                  $CurrentItem{$Category}{$Item};
                delete $CurrentItem{$Category}{$Item};
            }
            elsif ( $k =~ /DisplayManageItem_Del/ ) {
                my ( $Category, $Item ) =
                  $k =~ /^DisplayManageItem_Del_(.*)_(.*)$/;
                delete $CurrentItem{$Category}{$Item};
            }
        }
    }
    elsif ( exists $param{'DisplayManageItem_Category'} ) {
        $param{'HomePage_Action'} = 'Manage Item';
    }
    WriteList();
}

if ( exists $param{'DisplayManageCategory'} ) {
    if ( exists $param{'DisplayManageCategory_submit'} )
    {    # we have change something
        foreach my $k (%param) {
            if ( $k =~ /DisplayManageCategory_Ren/ ) {
                my ($Cat) = $k =~ /^DisplayManageCategory_Ren_(.*)$/;
                my $NewName = $param{"$k"};
                next if ( $Cat eq $NewName );
                my $i = -1;
                while ( $i++ < $#Category ) {
                    if ( $Category[$i] eq $Cat ) {
                        $Category[$i] = $param{$k};
                        foreach my $j ( keys %{ $CurrentItem{$Cat} } ) {
                            $CurrentItem{ $param{$k} }{$j} =
                              $CurrentItem{$Cat}{$j};
                            delete $CurrentItem{$Cat}{$j};
                        }
                    }
                }
            }
            elsif ( $k =~ /DisplayManageCategory_Del/ ) {
                my ($Cat) = $k =~ /^DisplayManageCategory_Del_(.*)$/;
                my @NewArray;
                foreach $k (@Category) {
                    next if $k eq $Cat;
                    push @NewArray, $k;
                }
                @Category = @NewArray;

                foreach my $Item ( keys %{ $CurrentItem{$Cat} } ) {
                    delete $CurrentItem{$Cat}{$Item};
                }
            }
        }
    }
    WriteList();
}

if ( exists $param{'DisplayCategoryItem_Submit'} ) {
    my $AddedCount    = 0;
    my $ChangedCount  = 0;
    my $DisabledCount = 0;
    my $AddedItem;
    my $ChangedItem;
    my $DisabledItem;
    my $DisplayCategory = $param{'DisplayCategoryItem_Category'};
    my $StatusA;
    my $StatusC;
    my $StatusD;

    foreach my $Cat ( keys %CurrentItem ) {
        next if ( $Cat ne $DisplayCategory && $DisplayCategory ne 'ALL' );
        foreach my $Item ( keys %{ $CurrentItem{$Cat} } ) {
            next if $Item eq "DummyItem";
            my $FormKey = "${Cat}";
            $FormKey =~
              s/ /XYZ/g;  # javascript workaround XYZ separate category and item
            $FormKey .= "_$Item";
            next if !$param{$FormKey};
            next if ( $param{$FormKey} == $CurrentItem{$Cat}{$Item} ); # already
            if ( $CurrentItem{$Cat}{$Item} == 0 && $param{$FormKey} > 0 ) {
                $AddedCount++;
                $AddedItem = $Item;
                $CurrentItem{$Cat}{$Item} = $param{$FormKey};
            }
            elsif ( $CurrentItem{$Cat}{$Item} > 0 && $param{$FormKey} == 0 ) {
                $DisabledCount++;
                $DisabledItem = $Item;
                $CurrentItem{$Cat}{$Item} = 0;
            }
            elsif ( $param{$FormKey} != $CurrentItem{$Cat}{$Item} ) {
                $ChangedCount++;
                $ChangedItem = $Item;
                $CurrentItem{$Cat}{$Item} = $param{$FormKey};
            }
        }
    }

    #print "Enable=$EnableCount Disable=$DisableCount\n";
    $StatusA = "<i>0</i> added, "               if $AddedCount == 0;
    $StatusA = "<i>$AddedItem</i> added, "      if $AddedCount == 1;
    $StatusA = "<i>$AddedCount</i> added, "     if $AddedCount > 1;
    $StatusC = "<i>0</i> changed, "             if $ChangedCount == 0;
    $StatusC = "<i>$ChangedItem</i> changed, "  if $ChangedCount == 1;
    $StatusC = "<i>$ChangedCount</i> changed, " if $ChangedCount > 1;
    $StatusD = "<i>0</i> removed"               if $DisabledCount == 0;
    $StatusD = "<i>$DisabledItem</i> removed"   if $DisabledCount == 1;
    $StatusD = "<i>$DisabledCount</i> removed"  if $DisabledCount > 1;

    if ( $AddedCount == 0 && $ChangedCount == 0 && $DisabledCount == 0 ) {
        $Status = "No new item selected";
    }
    else {
        $Status = $StatusA . $StatusC . $StatusD;
    }

    WriteList();
    1;
}

if ( exists $param{'SearchCategoryItem_Submit'} ) {
    my $AddedCount    = 0;
    my $ChangedCount  = 0;
    my $DisabledCount = 0;
    my $AddedItem;
    my $ChangedItem;
    my $DisabledItem;
    my $DisplayCategory = $param{'DisplayCategoryItem_Category'};
    my $StatusA;
    my $StatusC;
    my $StatusD;

    foreach my $Cat ( keys %CurrentItem ) {
        foreach my $Item ( keys %{ $CurrentItem{$Cat} } ) {
            next if $Item eq "DummyItem";
            my $FormKey = "${Cat}";
            $FormKey =~
              s/ /XYZ/g;  # javascript workaround XYZ separate category and item
            $FormKey .= "_$Item";
            next if !$param{$FormKey};
            next
              if ( $param{$FormKey} == $CurrentItem{$Cat}{$Item} ); # same value
            if ( $CurrentItem{$Cat}{$Item} == 0 && $param{$FormKey} > 0 ) {
                $AddedCount++;
                $AddedItem = $Item;
                $CurrentItem{$Cat}{$Item} = $param{$FormKey};
            }
            elsif ( $CurrentItem{$Cat}{$Item} > 0 && $param{$FormKey} == 0 ) {
                $DisabledCount++;
                $DisabledItem = $Item;
                $CurrentItem{$Cat}{$Item} = 0;
            }
            elsif ( $param{$FormKey} != $CurrentItem{$Cat}{$Item} ) {
                $ChangedCount++;
                $ChangedItem = $Item;
                $CurrentItem{$Cat}{$Item} = $param{$FormKey};
            }
        }
    }

    #print "Enable=$EnableCount Disable=$DisableCount\n";
    $StatusA = "<i>0</i> added, "               if $AddedCount == 0;
    $StatusA = "<i>$AddedItem</i> added, "      if $AddedCount == 1;
    $StatusA = "<i>$AddedCount</i> added, "     if $AddedCount > 1;
    $StatusC = "<i>0</i> changed, "             if $ChangedCount == 0;
    $StatusC = "<i>$ChangedItem</i> changed, "  if $ChangedCount == 1;
    $StatusC = "<i>$ChangedCount</i> changed, " if $ChangedCount > 1;
    $StatusD = "<i>0</i> removed"               if $DisabledCount == 0;
    $StatusD = "<i>$DisabledItem</i> removed"   if $DisabledCount == 1;
    $StatusD = "<i>$DisabledCount</i> removed"  if $DisabledCount > 1;

    if ( $AddedCount == 0 && $ChangedCount == 0 && $DisabledCount == 0 ) {
        $Status = "No new item selected";
    }
    else {
        $Status = $StatusA . $StatusC . $StatusD;
    }

    WriteList();
    1;
}

if ( exists $param{'DisplayCategoryItem_SelectAll'} ) {
    my $count = 0;
    foreach my $Category ( keys %CurrentItem ) {
        next
          if ( $param{'DisplayCategoryItem_Category'} ne $Category
            && $param{'DisplayCategoryItem_Category'} ne 'ALL' );
        foreach my $Item ( keys %{ $CurrentItem{$Category} } ) {
            next if $Item eq 'DummyItem';
            $count++ if $CurrentItem{$Category}{$Item} == 0;
            $CurrentItem{$Category}{$Item} = 1;
        }
    }
    WriteList();
    $Status = "$count items added";
    1;
}

if ( $param{'HomePage_Action'} eq 'Clear All' ) {
    my $count = 0;
    foreach my $Category ( keys %CurrentItem ) {
        foreach my $Item ( keys %{ $CurrentItem{$Category} } ) {
            $count++ if $CurrentItem{$Category}{$Item} == 1;
            $CurrentItem{$Category}{$Item} = 0;
        }
    }
    WriteList();
    $Status = "$count items cleared";
    1;
}

if ( exists $param{'DisplayCreateItem_Add_Item'} ) {
    $param{'DisplayCreateItem_Item'} =~ s/(\w+)/\u\L$1/g;

    # duplicate entry
    if (
        exists $CurrentItem{ $param{'DisplayCreateItem_Category'} }
        { $param{'DisplayCreateItem_Item'} } )
    {
        $DisplayCreateItem_Status =
          $param{'DisplayCreateItem_Item'} . " exists";
        $DisplayCreateItem_Item     = $param{'DisplayCreateItem_Item'};
        $DisplayCreateItem_Category = $param{'DisplayCreateItem_Category'};
        $param{'HomePage_Action'}   = 'Create Item';
    }
    else {
        $CurrentItem{ $param{'DisplayCreateItem_Category'} }
          { $param{'DisplayCreateItem_Item'} } =
          ( $param{'DisplayCreateItem_CurrentList'} ) ? 1 : 0;
        $Status =
          "<i>$param{'DisplayCreateItem_Item'}</i> added in $param{'DisplayCreateItem_Category'}";
        WriteList();
    }
    if ( exists $param{'DisplayCreateItem_AddMultiple'} ) {    # add more Item
        $DisplayCreateItem_Status   = "$param{'DisplayCreateItem_Item'} added";
        $DisplayCreateItem_Item     = '';
        $DisplayCreateItem_Category = $param{'DisplayCreateItem_Category'};
        $param{'HomePage_Action'}   = 'Create Item';
    }
    1;
}

if ( $param{'HomePage_Action'} eq "Display PDA" ) {
    $Config{'DisplayMode'} = 'pda';
    $Status                = "PDA display mode";
    $NumColumns            = $Config{'NumColumnsPDA'};
    $ColumnsWidth          = 100 / $NumColumns . '%';
}

if ( $param{'HomePage_Action'} eq "Display Normal" ) {
    $Config{'DisplayMode'} = 'normal';
    $Status                = "Regular display mode";
    $NumColumns            = $Config{'NumColumnsNormal'};
    $ColumnsWidth          = 100 / $NumColumns . '%';
}

if ( exists $param{'DisplayPreferences'} ) {
    foreach my $k ( keys %param ) {
        next if $k eq 'Preferences';
        $Config{$k} = $param{$k};
    }
    $Config{'DisplayKeyboardPDA'} = 0 if !exists $param{'DisplayKeyboardPDA'};
    $Config{'AddToListDefault'}   = 0 if !exists $param{'AddToListDefault'};
    $Config{'DisplayKeyboardNormal'} = 0
      if !exists $param{'DisplayKeyboardNormal'};
    $Config{'DisplayStatus'} = 0 if !exists $param{'DisplayStatus'};
    $Config{'PrintHtmlPipe'} = 0 if !exists $param{'PrintHtmlPipe'};
    1;
}

$Status = "The list is empty, create category and item" if ( $#Category == -1 );

# write the configuration parameter
WriteConfig();

#}}}
# <html><title><head><style> {{{
my $html = qq[
<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01//EN">
<html>
<head>
<title>List Manager</title>
];

InsertCSS();

#}}}
# web page display {{{
#TODO: <input type="hidden" name="listName" value="$listName">

$html .= qq[<body>];
$html .= qq[<form name="main" action="/bin/ListManager.pl" method="post">\n];

if ( $param{'HomePage_Action'} eq 'About' ) {
    DisplayAbout();
}
elsif ( $param{'HomePage_Action'} eq 'At Shop' ) {
    DisplayAtShop($AtShopStatus);
}
elsif ( $param{'HomePage_Action'} eq 'Create Category' ) {
    DisplayCreateCategory($DisplayCreateCategory_Status);
}
elsif ( $param{'HomePage_Action'} eq 'Create Item' ) {
    $DisplayCreateItem_Category = $param{'DisplayCategoryItem_Category'}
      if exists $param{'DisplayCategoryItem_Category'};
    DisplayCreateItem( $DisplayCreateItem_Status, $DisplayCreateItem_Item,
        $DisplayCreateItem_Category );
}
elsif ( $param{'HomePage_Action'} eq 'Man Page' ) {
    DisplayManPage();
}
elsif ( $param{'HomePage_Action'} eq 'Manage Category' ) {
    DisplayManageCategory();
}
elsif ( $param{'HomePage_Action'} eq 'Manage Item' ) {
    DisplayManageItem( $param{'DisplayManageItem_Category'} );
}
elsif ( $param{'HomePage_Action'} eq 'Manage List' ) {
    DisplayManageList();
}
elsif ( $param{'HomePage_Action'} eq 'Preferences' ) {
    DisplayPreferences();
}
elsif ( $param{'HomePage_Action'} eq 'Print' ) {
    PrintHtml();
}
elsif ( $param{'HomePage_Action'} eq 'Print Preview' ) {
    PrintPreview();
}
elsif ( $param{'HomePage_Action'} eq 'Print Text' ) {
    PrintText();
}
elsif ( $param{'HomePage_Action'} eq 'Quick Guide' ) {
    DisplayQuickGuide();
}
elsif ( $Config{'NewUser'} == 1 ) {
    DisplayNewUserInfo();
}
elsif ( $param{'DisplayCategoryItem'} ) {
    DisplayCategoryItem( $param{'DisplayCategoryItem'} );
}
elsif ( $param{'DisplaySearchItem'} ) {
    DisplaySearchItem( $param{'DisplaySearchItem'} );
}
else {
    DisplayHomePage();
}

#}}}
# close html file {{{
$html .= qq[</form>];
$html .= qq[</body>];
$html .= qq[</html>];

return &html_page( '', $html );

#}}}

# ============== Subroutine ================

#sub DisplayAbout {{{
sub DisplayAbout {
    $html .= qq [
  <CENTER>
  <H2>ListManager</H2>
  <p>Version '$Version'</p>
  <P>Managing list '$PrettyListName'<p>
  <br><br><br>
  Gaetan Lord
  <br>
  <input type="submit" name="action" value="OK">
];
    1;
}

#}}}
#sub DisplayAtShop{{{
sub DisplayAtShop {
    my $Msg = shift;
    $html .= qq[<p><center>$Msg</center></p>\n] if $Msg;
    foreach my $DisplayCategory (@Category)
    {    # no sort, to display in aisles way (shopping)
        my $HeaderPrint = 0;
        my $num         = 0;
        foreach my $Item ( sort keys %{ $CurrentItem{$DisplayCategory} } ) {
            next if $Item eq 'DummyItem';
            if ( $CurrentItem{$DisplayCategory}{$Item} > 0 ) {
                Header($DisplayCategory) if !$HeaderPrint++;
                $html .= qq[</tr>\n<tr>\n] if $num % $NumColumns == 0;
                my $Count = "($CurrentItem{$DisplayCategory}{$Item})"
                  if $CurrentItem{$DisplayCategory}{$Item} > 1;
                $html .=
                  qq[<td><input type="checkbox" name="${DisplayCategory}_$Item">$Item $Count</td>\n];
                $num++;
            }
        }
        $html .= qq[ </tr>\n</table><hr>\n] if $HeaderPrint;
    }

    sub Header {
        my $DisplayCategory = shift;
        $html .= qq[
<table width="100%" >
 <tr>
   <TD align=left><input type="submit" name="Cancel" value="Cancel" ></TD>
   <TD align=center><H3><center>$DisplayCategory</center><H3></TD>
   <TD align=right><input type="submit" name="DisplayAtShop_Remove" value="Remove" ></TD>
 </TR>
</table>
<table width="100%" ><colgroup span="$NumColumns" width="$ColumnsWidth">
<tr>
];

    }

    1;
}

#}}}
#sub DisplayCategoryItem {{{
sub DisplayCategoryItem {
    my $Category = shift;
    my $DisplayColumns;
    $DisplayColumns =
      ( $Config{'DisplayMode'} eq 'normal' ) ? ( $NumColumns - 1 ) : 1;
    my $SelectAll = '';

    $html .= qq[
   <SCRIPT Language = "JavaScript">

   function doPlus(checkbox,txt){
     document.forms[0][txt].value++;
     if ( document.forms[0][txt].value > 0 ) { 
       document.forms[0][checkbox].checked = true;
     }  
   }

   function doMinus(checkbox,txt){
     document.forms[0][txt].value--;
     if ( document.forms[0][txt].value < 1 ) { 
       document.forms[0][checkbox].checked = false;
       document.forms[0][txt].value=0;
     }  
   }

   </script>
   ];

    $html .=
      qq[<input type="hidden" name="DisplayCategoryItem_Category" value="$Category">\n];
    $html .= qq[<table width="100%">];
    $html .= qq[<tr>\n];
    $html .=
      qq[<td align=left><input type="submit" name="DisplayCategoryItem_SelectAll" value="Select All"></td>\n];
    $html .=
      qq[<td align=right><input type="submit" name="HomePage_Action" value="Create Item"></td>\n];
    $html .= qq[</tr>\n];
    $html .= qq[</table>];

    foreach my $DisplayCategory ( sort @Category ) {
        next if ( $Category ne $DisplayCategory && $Category ne 'ALL' );
        $html .= qq[
<table width="100%" >
<tr>
<TD align=left><H3>$DisplayCategory<H3></TD>
<TD align=right>$SelectAll<input type="submit" align="right" name="DisplayCategoryItem_Submit" value="Submit" ></TD>
</TR>
</table>
<hr>
<table width="100%" cellspacing=0 cellpadding=0>
<tr>
];
        my $num = 0;
        foreach my $Item ( sort keys %{ $CurrentItem{$DisplayCategory} } ) {
            my $JavaCat = $DisplayCategory;
            $JavaCat =~ s/\ /XYZ/g;
            next if $Item eq 'DummyItem';
            my $Checked =
              ( $CurrentItem{$DisplayCategory}{$Item} == 0 ) ? '' : 'checked';
            my $value =
              ( $CurrentItem{$DisplayCategory}{$Item} == 0 )
              ? 0
              : $CurrentItem{$DisplayCategory}{$Item};
            $html .= qq[</tr>\n<tr>\n] if $num % $DisplayColumns == 0;
            $html .= qq[<td><input type="button" name="plus" value="+" 
                     onClick="doPlus('${JavaCat}_${Item}_check','${JavaCat}_${Item}')">\n];
            $html .= qq[<input type="button" name="minus" value="-" 
                     onClick="doMinus('${JavaCat}_${Item}_check','${JavaCat}_${Item}')">\n];
            $html .=
              qq[<input type="checkbox" disabled name="${JavaCat}_${Item}_check" $Checked>\n];

            $html .=
              qq[$Item <input type="text"  value="$value" name="${JavaCat}_${Item}" size="1" style="border:solid 0 #fff; color:#630; background:#fff none;"></td>\n];
            $num++;
        }
        $html .= qq[</tr>];
        $html .= qq[</table>\n];
        $html .=
          qq[<p><center>No Item defined in category $DisplayCategory</center></p>]
          if !$num;
        $SelectAll = '';
    }
    1;
}

#}}}
#sub DisplayCreateCategory{{{
sub DisplayCreateCategory {
    my $Status = shift;

    # javascript {{{
    $html .= qq[

   <SCRIPT LANGUAGE="JavaScript">
   function CheckForm()  {
     var myindex=document.forms[0].DisplayCreateCategory_BeforeCategory.selectedIndex;
     if (document.forms[0].DisplayCreateCategory_Name.value=='') {
       alert("You must provide category name.");
       return false;
     } 
     if (myindex==0) {
       alert("You must make a selection from the category menu.");
       return false;
     } 
     var illegalChars = /\W/;
    // allow only letters, numbers, and underscores
    if (illegalChars.test(document.forms[0].DisplayCreateCategory_Name.value)) {
       alert("The username contains illegal characters.");
       return false;
    } 
     return true;
     }
     </SCRIPT>
   ];

    #}}}
    $html .= ( $Config{'DisplayMode'} eq 'normal' ) ? "<center>\n" : "<left>\n";
    $html .= qq[<p><font color=red size="2">$Status</font></p>]
      if ( $Status ne "" );
    $html .=
      qq[<p>Category:<input type="text" name="DisplayCreateCategory_Name" size="30"></p>\n];

    # display Category pull down if there is defined category{{{
    if ( $#Category >= 0 ) {
        $html .= qq[<p>Insert before:\n];
        $html .= qq[<select name="DisplayCreateCategory_BeforeCategory">\n];
        $html .= qq[  <option selected>Pick Category</option>\n];

        foreach my $Category ( keys %CurrentItem ) {
            $html .= qq[     <option>$Category</option>\n];
        }
        $html .= qq[
      </select>
      ];
    }

    #}}}

    # display keyboard
    InsertKeyboard('DisplayCreateCategory_Name') if $DisplayKeyboard;

    my $AddMultiple =
      ( exists $param{'DisplayCreateCategory_AddMultiple'} ) ? 'checked' : '';
    $html .= qq[
   <p>Create multiple: <input type="checkbox" name="DisplayCreateCategory_AddMultiple" $AddMultiple></p>
   <p>
    <input type="submit" name="DisplayCreateCategory_Action" value="Add Category" onClick="return CheckForm()">
    <input type="submit" name="Cancel" value="Cancel">
   </p>
   ];
    $html .=
      ( $Config{'DisplayMode'} eq 'normal' ) ? "</center>\n" : "</left>\n";
    1;
}

#}}}
#sub DisplayCreateItem{{{
sub DisplayCreateItem {
    my $Status           = shift;
    my $SelectedItem     = shift;
    my $SelectedCategory = shift;

    $Status = "" if !$Status;
    $Status = "You must define a category first" if $#Category == -1;

    # javascript {{{
    $html .= qq[

<SCRIPT LANGUAGE="JavaScript">
function CheckForm()  {
  var selectBox = document.forms[0].DisplayCreateItem_Category;
  var myindex=document.forms[0].DisplayCreateItem_Category.selectedIndex;
  if (myindex==0) {
     alert("You must make a selection from the category menu.");
  return false;
  } 
  if (document.forms[0].DisplayCreateItem_Item.value=='') {
     alert("You must put the item name.");
     return false;
  } 
  return true;
}
</SCRIPT>
];

    #}}}

    $html .= ( $Config{'DisplayMode'} eq 'normal' ) ? "<center>\n" : "<left>\n";

    if ( $#Category >= 0 ) {

        # display Category pull down {{{
        $html .= qq[<select name="DisplayCreateItem_Category">\n];
        $html .= qq[  <option selected>Pick Category</option>\n]
          if ( $SelectedCategory eq '' );
        $html .= qq[  <option>Pick Category</option>\n]
          if ( $SelectedCategory ne '' );

        foreach my $Category ( sort keys %CurrentItem ) {
            my $selected = ( $SelectedCategory eq $Category ) ? "selected" : '';
            $html .= qq[     <option $selected>$Category</option>\n];
        }
        $html .= qq[   
      </select>
      ];

        #}}}

        $html .=
          qq[<p>Item:<input type="text" name="DisplayCreateItem_Item" size=30 value="$SelectedItem"></p>\n];
    }
    $html .= qq[<p><font color=red size="2">$Status</font></p>]
      if ( $Status ne "" );

    # display keyboard
    InsertKeyboard('DisplayCreateItem_Item') if $DisplayKeyboard;

    # the submit button
    my $AddMultiple =
      ( exists $param{'DisplayCreateItem_AddMultiple'} ) ? 'checked' : '';
    my $AddToListDefault =
      ( $Config{'AddToListDefault'} == 1 ) ? 'checked' : '';
    $html .= qq[
      <p>Add item to selected: <input type="checkbox" name="DisplayCreateItem_CurrentList" $AddToListDefault></p>
      <p>Add multiple: <input type="checkbox" name="DisplayCreateItem_AddMultiple" $AddMultiple></p>
      <p>
      <input type="submit" name="DisplayCreateItem_Add_Item" value="Add Item" onClick="return CheckForm()">
      <input type="submit" name="Cancel" value="Cancel">
      </p>
      ];
    $html .=
      ( $Config{'DisplayMode'} eq 'normal' ) ? "</center>\n" : "</left>\n";

    1;
}

#}}}
#sub DisplayHomePage {{{
sub DisplayHomePage {

    #$Status = "Current list" if $Status eq '';
    my $DisplayType = 'Display Normal' if $Config{'DisplayMode'} eq 'pda';
    $DisplayType = 'Display PDA' if $Config{'DisplayMode'} eq 'normal';

    #<select name="action" onChange="main.submit();">
    $html .= qq[<p><left><h3>$PrettyListName list</h3></left></p>\n];
    $html .= qq[
     <SCRIPT LANGUAGE="JavaScript">
     function confirmation() {

       var theIndex = window.document.main.HomePage_Action.selectedIndex;
       var theValue = window.document.main.HomePage_Action.options[theIndex].value;
       var theObject = window.document.main.HomePage_Action;

       if (theValue == "Print Preview") {
         window.open("../bin/ListManager.pl?HomePage_Action=Print%20Preview"); 
         return true;
       }
       if (theObject.options[theIndex].text =="Clear All"){
         var answer = confirm("Clear all selected item")
         if (answer){
           document.main.submit();
         }else{
           return false
         } 
       }else{
         document.main.submit();
       }
     }
      </SCRIPT>

      <table width="100%"> 
      <tr>
       <TD align="left">
         <select name="HomePage_Action" onChange="confirmation();">
           <option selected>Choose Action</option>
           <option>At Shop</option> 
           <option>Clear All</option> 
           <option>$DisplayType</option>
           <option>Manage Category</option> 
           <option>Manage Item</option> 
           <option>Manage List</option> 
           <option>Print</option> 
           <option>Print Text</option> 
           <option>Print Preview</option> 
           <option>Preferences</option> 
           <option>Man Page</option> 
           <option>Quick Guide</option> 
           <option>About</option> 
         </select>
       </TD > 
      ];

    # normal mode status
    $Status = '' if !$Config{'DisplayStatus'};
    if ( $Config{'DisplayMode'} eq 'normal' ) {
        $html .= qq[           <TD><center><H3>$Status<H3><center></TD>\n];
    }

    $html .=
      qq[  <TD align="right"> <input type = "submit" name = "HomePageRemove" value = "Remove" > </TD>\n];
    $html .= qq[    </tr>\n];

    # pda status
    $html .=
      qq[     <tr><TD colspan="2"><center><H3>$Status<H3><center></TD></TR>\n]
      if ( $Config{'DisplayMode'} eq 'pda' );

    $html .= qq[   </table>\n];

    DisplayCurrentList();

    # we display all category
    my $num = 0;
    $html .=
      qq[   <input type="submit" name="DisplayCategoryItem" value="ALL"    style="border:solid 0 #000; color:#630; background:#FFFF80 none;">\n];
    $html .=
      qq[   <input type="submit" name="DisplaySearchItem" value="Search" style="border:solid 0 #000; color:#630; background:#FFFF80 none;">\n];
    foreach my $cat ( sort @Category ) {
        $html .=
          qq[   <input type="submit" name="DisplayCategoryItem" value="$cat" style="border:solid 0 #000; color:#630; background:#CCCCCC none;">&nbsp;\n];
        $num++;
    }

    1;
}

#}}}
#sub DisplayManageCategory{{{
sub DisplayManageCategory {
    my $DisplayColumns =
      ( $Config{'DisplayMode'} eq 'normal' ) ? ( $NumColumns - 1 ) : 1;
    my $DisplayWidth = 100 / $DisplayColumns . '%';

    $html .= qq[
   <SCRIPT LANGUAGE="JavaScript">
     //http://www.irt.org/script/1693.htm
     var nav = window.Event ? true : false;
     if (nav) {
        window.captureEvents(Event.KEYDOWN);
        window.onkeydown = NetscapeEventHandler_KeyDown;
     } else {
        document.onkeydown = MicrosoftEventHandler_KeyDown;
     }
     
     function NetscapeEventHandler_KeyDown(e) {
       if (e.which == 13 && e.target.type != 'textarea' && e.target.type != 'submit') { return false; }
       return true;
     }
     
     function MicrosoftEventHandler_KeyDown() {
       if (event.keyCode == 13 && event.srcElement.type != 'textarea' && event.srcElement.type != 'submit')
         return false;
       return true;
     }
   </script>
   ];

    $html .= qq[<input type="hidden" name="DisplayManageCategory" value="1">\n];
    $html .= qq[<table width="100%">\n];
    $html .=
      qq[  <TD align="left"> <input type="submit" name="Cancel" value="Cancel" > </TD>\n];
    $html .=
      qq[  <TD align="right"> <input type="submit" name="DisplayManageCategory_submit" value="Submit" > </TD>\n];
    $html .= qq[</table>\n];
    $html .= qq[<table width="100%">\n];
    $html .=
      qq[<td align=right><input type="submit" name="HomePage_Action" value="Create Category"></td>\n];
    $html .= qq[</table>\n];

    $html .=
      qq[<table width="100%" cellspacing=0 ><colgroup span="$DisplayColumns" >\n];

    # display delete header
    my $i    = 0;
    my @keys = keys %CurrentItem;
    my $imax = scalar @keys;
    $html .= qq[<tr>\n];
    while ( $i++ < ( $imax - 1 ) && $i < ( $DisplayColumns + 1 ) ) {
        $html .= qq[<td align="left">del&nbsp;&nbsp;rename</td>\n];
    }
    $html .= qq[</tr>\n];

    # display category
    my $num = 0;
    foreach my $Category ( keys %CurrentItem ) {
        next if $Category eq "Web_Functions";
        $html .= qq[ <tr>\n] if $num % $DisplayColumns == 0;
        $html .=
          qq[   <td><input type="checkbox" name="DisplayManageCategory_Del_${Category}" value="1">\n];
        $html .=
          qq[    <input type="text" name="DisplayManageCategory_Ren_${Category}" value="$Category" onkeypress="return noenter()"></td>\n];
        $num++;
        $html .= qq[ </tr>\n] if $num % $DisplayColumns == 0;
    }
    $html .= qq[     </tr>\n];
    $html .= qq[   </table>\n\n];

    $html .= qq[<hr>\n];
    1;
}

#}}}
#sub DisplayManageItem{{{
sub DisplayManageItem {
    my $Category = shift;
    my $DisplayColumns =
      ( $Config{'DisplayMode'} eq 'normal' ) ? ( $NumColumns - 1 ) : 1;
    my $DisplayWidth = 100 / $DisplayColumns . '%';

    $html .= qq[
   <SCRIPT LANGUAGE="JavaScript">
     //http://www.irt.org/script/1693.htm
     var nav = window.Event ? true : false;
     if (nav) {
        window.captureEvents(Event.KEYDOWN);
        window.onkeydown = NetscapeEventHandler_KeyDown;
     } else {
        document.onkeydown = MicrosoftEventHandler_KeyDown;
     }
     
     function NetscapeEventHandler_KeyDown(e) {
       if (e.which == 13 && e.target.type != 'textarea' && e.target.type != 'submit') { return false; }
       return true;
     }
     
     function MicrosoftEventHandler_KeyDown() {
       if (event.keyCode == 13 && event.srcElement.type != 'textarea' && event.srcElement.type != 'submit')
         return false;
       return true;
     }
   </script>
   ];
    $html .= qq[<input type="hidden" name="DisplayManageItem" value="1">\n];
    $html .=
      qq[<input type="hidden" name="DisplayCategoryItem_Category" value="$Category">\n];

    $html .= qq[<table width="100%">\n];
    $html .=
      qq[  <TD align="left"> <input type="submit" name="Cancel" value="Cancel" > </TD>\n];

    # normal mode status
    $Status = '' if !$Config{'DisplayStatus'};
    if ( $Config{'DisplayMode'} eq 'normal' ) {
        $html .= qq[ <TD align=center><H3>$Status<H3></TD>\n];
    }

    $html .=
      qq[  <TD align="right"> <input type="submit" name="DisplayManageItem_submit" value="Submit" > </TD>\n];
    $html .= qq[    </tr>\n];

    # pda status
    $html .=
      qq[     <tr><TD colspan="2"><center><H3>$Status<H3><center></TD></TR>\n]
      if ( $Config{'DisplayMode'} eq 'pda' );
    $html .= qq[   </table>\n];
    $html .= qq[<table width="100%">\n];
    $html .=
      qq[<td align=right><input type="submit" name="HomePage_Action" value="Create Item"></td>\n];
    $html .= qq[</table>\n];

    if ( $Category eq '' ) {
        $html .=
          qq[<p><h3><center>Please select a category</center></h3></p>\n];
    }
    else {
        $html .= qq[<p><h3><center>$Category</center></h3></p>\n];
    }

    $html .=
      qq[<table width="100%" cellspacing=0 ><colgroup span="$DisplayColumns" >\n];

    # display delete/rename header
    my $i    = 0;
    my @keys = keys %{ $CurrentItem{$Category} };
    my $imax = scalar @keys;
    $html .= qq[<tr>\n];
    while ( $i++ < ( $imax - 1 ) && $i < ( $DisplayColumns + 1 ) ) {
        $html .= qq[<td align="left">del&nbsp;&nbsp;rename</td>\n];
    }
    $html .= qq[</tr>\n];

    # display item
    my $num = 0;
    foreach my $Item ( keys %{ $CurrentItem{$Category} } ) {
        next if ( $Item eq 'DummyItem' );
        $html .= qq[     <tr>\n] if $num % $DisplayColumns == 0;
        $html .=
          qq[       <td><input type="checkbox" name="DisplayManageItem_Del_${Category}_${Item}" value="1">\n];
        $html .=
          qq[           <input type="text" name="DisplayManageItem_Ren_${Category}_${Item}" value="$Item" onkeypress="return noenter()"></td>\n];
        $num++;
        $html .= qq[     </tr>\n] if $num % $DisplayColumns == 0;
    }
    $html .= qq[     </tr>\n];
    $html .= qq[   </table>\n\n];

    $html .= qq[<hr>\n];

    # we display all category
    foreach my $cat ( sort keys %CurrentItem ) {
        next if $cat eq '';
        $html .=
          qq[   <input type="submit" name="DisplayManageItem_Category" value="$cat">\n];
    }

    1;
}

#}}}
#sub DisplayManageList{{{
sub DisplayManageList {
    my $cols = 3;
    my $num  = 0;

    # javascript {{{
    $html .= qq[

   <SCRIPT LANGUAGE="JavaScript">
   function CheckForm()  {
     if (document.forms[0].DisplayManageList_NewList.value=='') {
       alert("You must put the list name.");
       return false;
     } 
     return true;
   }
   </SCRIPT>
   ];

    #}}}
    $html .= ( $Config{'DisplayMode'} eq 'normal' ) ? "<center>\n" : "<left>\n";
    $html .=
      qq[<p>Select from the following list, or enter a new list name</p>\n];
    $html .= qq[<TABLE BORDER><TR>\n];

    my @Lists = <$config_parms{'data_dir'}/ListManager/*.lst>;
    foreach my $l (@Lists) {
        my ($PrettyName) = $l =~ /.*\/(.*).lst$/;
        $html .= qq[</tr>\n<TR>\n] if $num % $cols == 0;
        $html .=
          qq[<TD><center><input type="submit" name="DisplayManageList_ChangeList" value="$PrettyName"></center></TD>\n];
        $num++;
    }

    $html .= qq[</TR></TABLE>\n];
    $html .=
      qq[<p>New List:<input type="text" name="DisplayManageList_NewList" size=30></p>\n];

    # display keyboard
    InsertKeyboard('DisplayManageList_NewList') if $DisplayKeyboard;

    # the submit button
    $html .= qq[
   <p>
   <input type="submit" name="DisplayManageList_Action" value="Add List" onClick="return CheckForm()">
   <input type="submit" name="Cancel" value="Cancel">
   </p>
   ];

    $html .=
      ( $Config{'DisplayMode'} eq 'normal' ) ? "</center>\n" : "</left>\n";
    1;
}

#}}}
#sub DisplayManPage{{{
sub DisplayManPage {
    $html .= qq[<p><input type="submit" name="action" value="Exit"><p>\n];

    my $POD = qq[ 
# ====================== POD START ==============================
=pod

=head1 Overview

ListManager gives you the ability to create multiple lists.  You can add, remove and modify all items and categories in any list.  The selected items will be placed in a convenient list which when shopping will show only the items you need to buy.  Once you get the item, the item is easily removed making it easy to find what is left to get.  


=head1 List Manager Guide

=begin html
This guide will explain the basic functions of ListManager as well as give an explanation of the options.


=end html


=head1 First time use instructions

Some basics to know when first using ListManager.pl


=item

- The first time it is run, a simple shopping list will be created in <your data directory>/ListManager

=item

- You can manually edit the file

=item

- The category order in the file will be kept when using "Print" or "At Shop"

=item

- You can have multiple lists.

=item

- They need to be located in <your data directory>/ListManager and their names should end with ".lst"

=item

- You can switch lists from the pull-down menu "Manage List"

=item

Note: Category and Item name can only have letter, number or space


=head1 Basic use of this program

=head2 Select an item that is already in your list

=item

- Click on the Category of the item.

=item

- Click the + of - to change the quantity of the item

=item

- Click Submit

=head2 Add an item to the list

=item

- Click on the category where you want to add your item

=item

- Click create item (at the top right)

=item

- Enter the item name

=item

- Click Add Item

=item

- I<Optional: Add new item to selected>

           Checked (Default)-- Adds the item to the list as well as your shopping list
           Unchecked --Simply adds the item to your list of items

=item

- I<Optional: Add multiple items>

           Unchecked (Default)- Returns to the main screen
           Checked -- stays on this page and allows you to enter additional items


=head2 Create a new category

=item

- From the dropdown box, choose ``Manage Category''

=item

- click Create Category (at the top right) 

=item

- Enter the category name 

=item

- Choose where you want to insert the category 

=item

- Click Add Category 

=item

- I<Optional: Create multiple> 

           Unchecked (Default)- Returns to the main screen
           Checked -- stays on this page and allows you to create additional categories

=head2 Remove an item from your shopping list and "At Shop"

=item

- Check the item

=item

- Click Remove (at the top right)

=head1 Explanation of dropdown items

B<  At Shop>

   This will show what you need to get and allow you to remove items as you get them.
   Cancel returns to the Main screen
   Selecting an item and Clicking remove, Removes the item from the shopping list.

B<  Clear All>

   Removes all items from the list of items to get from the list you are currently working with.

B<  Display Normal/PDA>

   Changes the format displayed
   You can change display options using the Preferences drop down item.

B<  Manage Category>

   Select the category to be deleted and click Submit
   Rename a category and click Submit
   Click Create Category to Insert a new category

B<  Manage Item>

   Click the category where the item is:
   Select the item to be deleted and click Submit
   Rename an item and click Submit
   Click Create Item to Insert a new item

B<  Manage List>

   Choose which list you wish to work with
   Create a new list

B<  Print>

   Sends the list of selected items to the printer

B<  Print Preview>

   Displays the print preview

B<  Preferences>

   Change the display preferences
   Display the keyboard when adding items and categories, # of columns in PDA and normal mode)
   Number of columns for each mode
   Display status message .. (IE: 5 items added)

B<  Quick Guide>

   This page

B<  About>

   Version information
   Contact information

=head1 Syntax of listfile

 - Category are enclosed in squared bracket, ie:[Vegetables]
 - Items are following their respective category
 - Items enabled are set to >0, ie: broccoli=1

=head1 Printing the list
 

B<Print Preview: >If you have a printer directly attached to the computer, this is probably the easiest way to print the list, as it doesn't require any configuration. 


B<Print Html: >This will be useful if you are printing from a device that doesn't have a directly attached printer , like a PDA or an Audrey. In order to print you will have to define the print command in the preference window. The command specified will be the one you would use from the misterhouse system to print an html file to the printer. When you have to specify the html file in your command, use the keyword "FILE" to define it. On my linux system, my command is html2ps FILE | lpr


B<Print Text: >This is exactly the same as html, but for text file file.


=head1 Credits and contact information

Code created by Gaetan Lord

Rewritten from Matthew Williams original idea of ShoppingList.pl

Documentation by Tom Valdes

Please contact about any problems or suggestions via the misterhouse mailing list

=cut
#  ======================== POD END ==================================
];

    open DOC,
      "echo \"$POD\" | pod2html --cachedir=$config_parms{html_alias_cache} --flush 2>/dev/null |";
    my $content = 0;
    while (<DOC>) {
        $content = 1 if /<body/;
        next if /<body/;
        $content = 0 if /<\/body/;
        $html .= qq[$_] if $content;
    }
    close DOC;
    1;
}

#}}}
#sub DisplayNewUserInfo{{{
sub DisplayNewUserInfo {
    $html .= qq [
      <H2>ListManager</H2>
      <p> Welcome to ListManager </p>
      
      <p>
      You have been redirected to this page because this is the first time you are using ListManager.
      Here are a few things you need to know.
      </p>
      <UL>
        <li>A simple shopping list has been created in the directory $config_parms{data_dir}/ListManager.</li>
        <li>You can manually edit the file</li>
        <li>The category order in the file will be kept when using "Print" or "At Shop"</li>
        <li>You can have multiple lists.  They need to be located in $config_parms{data_dir}/ListManager and their names should end with ".lst"</li>
        <li>You can switch lists from the pull-down menu "Manage List"</li>
        <li>Note: Category and Item names can only have a letter, number or space</li> 
        <BR>
        <li><h4>Nothing is perfect and you may find bugs<h4></li> 
        <li>for any issues, please contact me, or send an email to the Misterhouse mailing list</li>
        <li>email: misterhouse at gaetanlord.ca</li>
      </UL>
        <center><input type="submit" name="action" value="OK"></center>
      ];
    $Config{'NewUser'} = 0;
    WriteConfig();
    1;
}

#}}}
#sub DisplayPreferences{{{
sub DisplayPreferences {
    my $CheckedPDA = ( $Config{'DisplayKeyboardPDA'} == 1 ) ? 'checked' : '';
    my $CheckedNormal =
      ( $Config{'DisplayKeyboardNormal'} == 1 ) ? 'checked' : '';
    my $CheckedPipe   = ( $Config{'PrintPipe'} == 1 )     ? 'checked' : '';
    my $StatusChecked = ( $Config{'DisplayStatus'} == 1 ) ? 'checked' : '';
    my $CheckedAddToListDefault =
      ( $Config{'AddToListDefault'} == 1 ) ? 'checked' : '';
    $html .= qq[<left>\n];
    $html .= qq[<h3>Please select your preferences</h3>\n];

    $html .=
      qq[<p>Add to List when Creating Item Selected by default: <input type="checkbox" name="AddToListDefault" $CheckedAddToListDefault></p>\n];
    $html .=
      qq[<p>Display keyboard in PDA mode: <input type="checkbox" name="DisplayKeyboardPDA" $CheckedPDA></p>\n];
    $html .=
      qq[<p>Display keyboard in Normal mode: <input type="checkbox" name="DisplayKeyboardNormal" $CheckedNormal></p>\n];
    $html .=
      qq[<p>Columns in PDA mode:<input type="text" name="NumColumnsPDA" size=2 align="center" value="$Config{'NumColumnsPDA'}"></p>\n];
    $html .=
      qq[<p>Columns in normal mode: <input type="text" name="NumColumnsNormal" size=2 value="$Config{'NumColumnsNormal'}"></p>\n];
    $html .=
      qq[<p>Display status message: <input type="checkbox" name="DisplayStatus" $StatusChecked></p>\n];
    $html .=
      qq[<hr><p>Please consult the man page about the print preference</p>];
    $html .=
      qq[<p>Print text cmd:<input type="text" name="PrintTextCommand" size=20 align="center" value="$Config{'PrintTextCommand'}"></p>\n];
    $html .=
      qq[<p>Print html cmd:<input type="text" name="PrintHtmlCommand" size=20 align="center" value="$Config{'PrintHtmlCommand'}"></p>\n];
    $html .=
      qq[<p><input type="submit" name="DisplayPreferences" value="OK"></p>\n];

    $html .= qq[</left>\n];

    1;
}

#}}}
#sub DisplayQuickGuide{{{
sub DisplayQuickGuide {

    $html .= qq [
     <H2>ListManager</H2>
     <p> Welcome to the ListManager quick guide</p>
     
     <UL>
       <li><b>At Shop</b> -- This will show what you need to get and allow you to remove items as you get them.</li>
       <li><b>Clear All</b> -- Removes all items from the list you are currently working with.  </li>
       <li><b>Create Category</b> -- Creates a new category and allows you to choose where it gets inserted  </li>
       <li><b>Display Normal/PDA</b> -- Changes the format displayed..You can change display options using the Preferences drop down item.  </li>
       <li><b>Manage Item</b> -- Delete or rename an item in the list </li>
       <li><b>Manage List</b> -- Here you can switch to a different list or create a new list  </li>
       <li><b>Print</b> -- Sends the list of selected items to the printer  </li>
       <li><b>Print Preview</b> -- Displays the print preview  </li>
       <li><b>Preferences</b> -- Change the display preferences (display the keyboard when adding items and categories, # of columns in PDA and normal mode)  </li>
       <li><b>Quick Guide</b> -- This page  </li>
       <li><b>Version</b> -- Version information   </li>
       
     </UL>
       <center><input type="submit" name="action" value="OK"></center>
   ];
    $Config{'NewUser'} = 0;
    WriteConfig();
    1;
}

#}}}
#sub DisplaySearchItem{{{
sub DisplaySearchItem {

    my $Item2Search = shift;
    my $loc = ( $Config{'DisplayMode'} eq 'pda' ) ? 'left' : 'center';
    if ( $Item2Search eq "Search" ) {

        $html .=
          qq[<p><$loc>Search:<input type="text" name="DisplaySearchItem" size=30 value="">
                 <input type="submit" align="right" name="SearchCategoryItem_Submit" value="Submit" >
                 </$loc></p>
                 ];

        # display keyboard
        InsertKeyboard('DisplaySearchItem') if $DisplayKeyboard;
        $html .=
          qq[<p><$loc><input type="submit" name="Cancel2" value="Cancel"></$loc></p>];
    }
    else {

        $html .= qq[
           <SCRIPT Language = "JavaScript">
        
           function doPlus(checkbox,txt){
             document.forms[0][txt].value++;
             if ( document.forms[0][txt].value > 0 ) { 
               document.forms[0][checkbox].checked = true;
             }  
           }
        
           function doMinus(checkbox,txt){
             document.forms[0][txt].value--;
             if ( document.forms[0][txt].value < 1 ) { 
               document.forms[0][checkbox].checked = false;
               document.forms[0][txt].value=0;
             }  
           }
        
           </script>
           ];

        $html .=
          qq[<p><input type="submit" align="right" name="SearchCategoryItem_Submit" value="Submit" ></p>
      <hr>
      <table width="100%" cellspacing=0 cellpadding=0>
      ];
        foreach my $DisplayCategory ( sort @Category ) {
            foreach my $Item ( sort keys %{ $CurrentItem{$DisplayCategory} } ) {
                my $JavaCat = $DisplayCategory;
                $JavaCat =~ s/\ /XYZ/g;
                next if $Item eq 'DummyItem';
                next if $Item !~ /$Item2Search/i;
                my $Checked =
                  ( $CurrentItem{$DisplayCategory}{$Item} == 0 )
                  ? ''
                  : 'checked';
                my $value =
                  ( $CurrentItem{$DisplayCategory}{$Item} == 0 )
                  ? 0
                  : $CurrentItem{$DisplayCategory}{$Item};
                $html .= qq[<tr>\n];
                $html .= qq[<td>\n];
                $html .=
                  qq[<input type="button" name="plus" value="+" onClick="doPlus('${JavaCat}_${Item}_check','${JavaCat}_${Item}')">\n];
                $html .=
                  qq[<input type="button" name="minus" value="-" onClick="doMinus('${JavaCat}_${Item}_check','${JavaCat}_${Item}')">\n];
                $html .=
                  qq[<input type="checkbox" disabled name="${JavaCat}_${Item}_check" $Checked>\n];
                $html .= qq[$DisplayCategory: $Item\n];
                $html .=
                  qq[<input type="text"  value="$value" name="${JavaCat}_${Item}" size="1" style="border:solid 0 #fff; color:#630; background:#fff none;">];
                $html .= qq[</td>\n];
                $html .= qq[</tr>];
            }
        }
        $html .= qq[</table>\n];
        1;

    }

    1;
}

#}}}
#sub InsertCSS {{{
sub InsertCSS {

    if ( $Config{'DisplayMode'} eq 'pda' ) {
        $html .= qq[
         <style type="text/css">
         
         td { font-family:monospace,serif,sans-serif,cursive,fantasy;
              font-size: 8pt;
            }
         input{
                 font-family:monospace,serif,sans-serif,cursive,fantasy;
                 font-size: 8pt;
                 border:1px solid;
                 padding-left:0;
                 padding-right:0; 
                 word-spacing:0;
                 letter-spacing:0;
               }
         
         p,a { 
               font-family: monospace,serif,sans-serif,cursive,fantasy;
               font-size: 8pt;
               margin-top : 1%;
               margin:0; 
             }
         
         a   { 
               text-decoration: none; 
             }
         
         h3 { 
              font-family: helvetica;
              font-size: 10pt;
              margin-top : 1%;
              margin:0;
            }
         h4 { 
              font-family: helvetica;
              font-size: 8pt;
              margin:0;
            }
         </style>
      ];
    }
    elsif ( $param{'HomePage_Action'} eq 'Man Page' ) {
        $html .= qq[
         <style type="text/css">

         pre,p,li {
               font-family: Courier New;
               font-size: 10pt;
               margin-top : 1%;
               margin:0;
             }

         h1 {
              font-family: Garamond, "Times New Roman", serif;
              font-size: 140%;
              margin-top : 1%;
              margin:0;
            }
         h2 {
              font-size: 110%;
              margin-top : 1%;
              margin:0;
            }
         </style>
   ];
    }
    else {

        #input:focus, textarea:focus, select:focus, input:hover
        #  { background : #ffd;
        #    color : black; }
        #style="border:solid 0 #fff; color:#630; background:#fff none;
        #input[type="submit"]:active { border-color: red;
        #                              border:solid 0;
        #                              color: red;
        #                              background: #ffc; }
        $html .= qq[
         <style type="text/css">
         
         td { font-family:monospace,serif,sans-serif,cursive,fantasy;
              font-size: 10pt;
            }
         
         input[type="submit"]:hover { border-color: #900; 
                                      background: #ffd;
                                      color: #600; } 
         input[type="submit"]:active { border-color: red;
                                       color: red;
                                       background: #ffc; } 
         
         input{
                 font-size: 10pt;
                 word-spacing:0;
                 letter-spacing:0;
               }
         
         p,a,li { 
               font-family: Courier New;
               font-size: 10pt;
               margin-top : 1%;
               margin:0; 
             }
         
         a   { 
               text-decoration: none; 
             }
         
         h1 { 
              font-family: monospace,serif,sans-serif,cursive,fantasy,helvetica;
              font-size: 18pt;
              margin-top : 1%;
              margin:0;
            }
         h2 { 
              font-family: monospace,serif,sans-serif,cursive,fantasy,helvetica;
              font-size: 16pt;
              margin-top : 1%;
              margin:0;
            }
         h3 { 
              font-family: helvetica;
              font-size: 12pt;
              margin-top : 1%;
              margin:0;
            }
         h4 { 
              font-family: helvetica;
              font-size: 10pt;
              margin:0;
            }
         </style>
      ];
    }
    1;
}

#}}}
#sub InsertKeyboard {{{
sub InsertKeyboard {
    my $name    = shift;
    my $Spacing = ( $Config{'DisplayMode'} eq 'pda' ) ? "0" : "2";
    my $Padding = ( $Config{'DisplayMode'} eq 'pda' ) ? "0" : "2";
    $html .= qq[

       <SCRIPT language="javascript" type="text/javascript">
       var string=new Array();
       var string_index=0;
       
       
       // parent.frame.location
       
       function BackSpace()
       { 
         document.main.$name.value='';
         for(j=0; j<=string_index-2; j++)
         { 
           //alert(j + "->" + string[j]);
           document.main.$name.value+=string[j];
         }
         string[string_index]='';
         string_index--;
       }
       
       function seek(letter)
       { 
         document.main.$name.value+=letter
         //string_index++;
         string[string_index++]=letter;
       }
       </SCRIPT>
   ];

    if ( $Config{'DisplayMode'} ne 'pda' ) {
        $html .= qq[
      <center>
      <TABLE  cellspacing=$Spacing cellpadding="$Padding">
        <TR>
          <TD><INPUT onclick="seek('!');" type="button" value="!" ></TD>
          <TD><INPUT onclick="seek('@');" type="button" value="@" ></TD>
          <TD><INPUT onclick="seek('#');" type="button" value="#" ></TD>
          <TD><INPUT onclick="seek('%');" type="button" value="%" ></TD>
          <TD><INPUT onclick="seek('^');" type="button" value="^" ></TD>
          <TD><INPUT onclick="seek('&');" type="button" value="&" ></TD>
          <TD><INPUT onclick="seek('*');" type="button" value="*" ></TD>
          <TD><INPUT onclick="seek('(');" type="button" value="(" ></TD>
          <TD><INPUT onclick="seek(')');" type="button" value=")" ></TD>
          <TD><INPUT onclick="seek('_');" type="button" value="_" ></TD>
          <TD><INPUT onclick="seek('+');" type="button" value="+" ></TD>
        </TR>
      </TABLE>
      <TABLE  cellspacing=$Spacing cellpadding="$Padding">
        <TR>
          <TD><INPUT onclick="seek('1');" type="button" value="1" ></TD>
          <TD><INPUT onclick="seek('2');" type="button" value="2" ></TD>
          <TD><INPUT onclick="seek('3');" type="button" value="3" ></TD>
          <TD><INPUT onclick="seek('4');" type="button" value="4" ></TD>
          <TD><INPUT onclick="seek('5');" type="button" value="5" ></TD>
          <TD><INPUT onclick="seek('6');" type="button" value="6" ></TD>
          <TD><INPUT onclick="seek('7');" type="button" value="7" ></TD>
          <TD><INPUT onclick="seek('8');" type="button" value="8" ></TD>
          <TD><INPUT onclick="seek('9');" type="button" value="9" ></TD>
          <TD><INPUT onclick="seek('0');" type="button" value="0" ></TD>
          <TD><INPUT onclick="seek('-');" type="button" value="-" ></TD>
          <TD><INPUT onclick="seek('=');" type="button" value="=" ></TD>
        </TR>
      </TABLE>
      <TABLE cellspacing=$Spacing cellpadding="$Padding">
        <TR>
          <TD><INPUT onclick="seek('q');" type="button" value="Q" ></TD>
          <TD><INPUT onclick="seek('w');" type="button" value="W" ></TD>
          <TD><INPUT onclick="seek('e');" type="button" value="E" ></TD>
          <TD><INPUT onclick="seek('r');" type="button" value="R" ></TD>
          <TD><INPUT onclick="seek('t');" type="button" value="T" ></TD>
          <TD><INPUT onclick="seek('y');" type="button" value="Y" ></TD>
          <TD><INPUT onclick="seek('u');" type="button" value="U" ></TD>
          <TD><INPUT onclick="seek('i');" type="button" value="I" ></TD>
          <TD><INPUT onclick="seek('o');" type="button" value="O" ></TD>
          <TD><INPUT onclick="seek('p');" type="button" value="P" ></TD>
        </TR>
      </TABLE>
      <TABLE cellspacing=$Spacing cellpadding="$Padding">
        <TR>
          <TD><INPUT onclick="seek('a');" type="button" value="A" ></TD>
          <TD><INPUT onclick="seek('s');" type="button" value="S" ></TD>
          <TD><INPUT onclick="seek('d');" type="button" value="D" ></TD>
          <TD><INPUT onclick="seek('f');" type="button" value="F" ></TD>
          <TD><INPUT onclick="seek('g');" type="button" value="G" ></TD>
          <TD><INPUT onclick="seek('h');" type="button" value="H" ></TD>
          <TD><INPUT onclick="seek('j');" type="button" value="J" ></TD>
          <TD><INPUT onclick="seek('k');" type="button" value="K" ></TD>
          <TD><INPUT onclick="seek('l');" type="button" value="L" ></TD>
        </TR>
      </TABLE>

      <TABLE cellspacing=$Spacing cellpadding="$Padding">
        <TR>
          <TD><INPUT onclick="seek('z');" type="button" value="Z" ></TD>
          <TD><INPUT onclick="seek('x');" type="button" value="X" ></TD>
          <TD><INPUT onclick="seek('c');" type="button" value="C" ></TD>
          <TD><INPUT onclick="seek('v');" type="button" value="V" ></TD>
          <TD><INPUT onclick="seek('b');" type="button" value="B" ></TD>
          <TD><INPUT onclick="seek('n');" type="button" value="N" ></TD>
          <TD><INPUT onclick="seek('m');" type="button" value="M" ></TD>
          <TD><INPUT onclick="seek(',');" type="button" value="," ></TD>
          <TD><INPUT onclick="seek('.');" type="button" value="." ></TD>
        </TR>
      </TABLE>

      <TABLE>
        <TR>
          <TD colspan="3"><INPUT onclick="seek(' ');" type="button" value="&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;SPACE&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;"></TD>
          <TD colspan="1"><INPUT onclick="BackSpace();" type="button" value="back"></TD>
        </TR>
      </TABLE>
      </center>
      ];

    }
    else {

        #<TD colspan="3"><INPUT onclick="seek(' ');" type="button" value="&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;SPACE&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;"></TD>

        $html .= qq[
      <left> 

      <TABLE cellspacing=$Spacing cellpadding="$Padding">
        <TR>
          <TD><INPUT onclick="seek('a');" type="button" value="a" ></TD>
          <TD><INPUT onclick="seek('b');" type="button" value="b" ></TD>
          <TD><INPUT onclick="seek('c');" type="button" value="c" ></TD>
          <TD><INPUT onclick="seek('d');" type="button" value="d" ></TD>
          <TD><INPUT onclick="seek('e');" type="button" value="e" ></TD>
          <TD><INPUT onclick="seek('f');" type="button" value="f" ></TD>
          <TD><INPUT onclick="seek('g');" type="button" value="g" ></TD>
          <TD><INPUT onclick="seek('h');" type="button" value="h" ></TD>
          <TD><INPUT onclick="seek('i');" type="button" value="i" ></TD>
          <TD><INPUT onclick="seek('j');" type="button" value="j" ></TD>
          <TD><INPUT onclick="seek('k');" type="button" value="k" ></TD>
          <TD><INPUT onclick="seek('l');" type="button" value="l" ></TD>
          <TD><INPUT onclick="seek('m');" type="button" value="m" ></TD>
          <TD><INPUT onclick="seek('n');" type="button" value="n" ></TD>
          <TD><INPUT onclick="seek('o');" type="button" value="o" ></TD>
          <TD><INPUT onclick="seek('p');" type="button" value="p" ></TD>
          <TD><INPUT onclick="seek('q');" type="button" value="q" ></TD>
          <TD><INPUT onclick="seek('r');" type="button" value="r" ></TD>
          <TD><INPUT onclick="seek('s');" type="button" value="s" ></TD>
          <TD><INPUT onclick="seek('t');" type="button" value="t" ></TD>
          <TD><INPUT onclick="seek('u');" type="button" value="u" ></TD>
          <TD><INPUT onclick="seek('v');" type="button" value="v" ></TD>
          <TD><INPUT onclick="seek('w');" type="button" value="w" ></TD>
          <TD><INPUT onclick="seek('x');" type="button" value="x" ></TD>
          <TD><INPUT onclick="seek('y');" type="button" value="y" ></TD>
          <TD><INPUT onclick="seek('z');" type="button" value="z" ></TD>
          <TD><INPUT onclick="seek('1');" type="button" value="1" ></TD>
          <TD><INPUT onclick="seek('2');" type="button" value="2" ></TD>
          <TD><INPUT onclick="seek('3');" type="button" value="3" ></TD>
          <TD><INPUT onclick="seek('4');" type="button" value="4" ></TD>
          <TD><INPUT onclick="seek('5');" type="button" value="5" ></TD>
          <TD><INPUT onclick="seek('6');" type="button" value="6" ></TD>
          <TD><INPUT onclick="seek('7');" type="button" value="7" ></TD>
          <TD><INPUT onclick="seek('8');" type="button" value="8" ></TD>
          <TD><INPUT onclick="seek('9');" type="button" value="9" ></TD>
          <TD><INPUT onclick="seek('0');" type="button" value="0" ></TD>
        </TR>
      </TABLE>

      <TABLE  cellspacing=$Spacing cellpadding="$Padding">
        <TR>
          <TD><INPUT onclick="seek('!');" type="button" value="!" ></TD>
          <TD><INPUT onclick="seek('@');" type="button" value="@" ></TD>
          <TD><INPUT onclick="seek('#');" type="button" value="#" ></TD>
          <TD><INPUT onclick="seek('%');" type="button" value="%" ></TD>
          <TD><INPUT onclick="seek('^');" type="button" value="^" ></TD>
          <TD><INPUT onclick="seek('&');" type="button" value="&" ></TD>
          <TD><INPUT onclick="seek('*');" type="button" value="*" ></TD>
          <TD><INPUT onclick="seek('(');" type="button" value="(" ></TD>
          <TD><INPUT onclick="seek(')');" type="button" value=")" ></TD>
          <TD><INPUT onclick="seek('_');" type="button" value="_" ></TD>
          <TD><INPUT onclick="seek('+');" type="button" value="+" ></TD>
          <TD><INPUT onclick="seek('-');" type="button" value="-" ></TD>
          <TD><INPUT onclick="seek('=');" type="button" value="=" ></TD>
          <TD><INPUT onclick="seek(',');" type="button" value="," ></TD>
          <TD><INPUT onclick="seek('.');" type="button" value="." ></TD>
        </TR>
      </TABLE>

      <TABLE cellspacing=$Spacing cellpadding="$Padding">
        <TR>
          <TD ><INPUT onclick="seek(' ');" type="button" value="__ SPACE __"></TD>
          <TD ><INPUT onclick="BackSpace();" type="button" value="back"></TD>
        </TR>
      </TABLE>

      </left>
      ];
    }
    1;
}

#}}}
#sub PrintText{{{
sub PrintText {
    my $txt;
    my $NumColumns = 3;
    my $HR         = '-' x 78 . "\n";
    $html .= qq[<input type="hidden" name="action" value="Print">\n];
    $html .= qq[<p><input type="submit" name="action" value="Exit"><p>\n];
    if ( $Config{'PrintTextCommand'} ne '' ) {
        foreach my $DisplayCategory (@Category)
        {    # no sort, to display in aisles way (shopping)
            my $HeaderPrint = 0;
            my $num         = 0;
            my @ITEM;
            foreach my $Item ( sort keys %{ $CurrentItem{$DisplayCategory} } ) {
                next if $Item eq 'DummyItem';
                if ( $CurrentItem{$DisplayCategory}{$Item} == 1 ) {
                    $txt .= "$HR" . uc($DisplayCategory) . "\n$HR"
                      if !$HeaderPrint++;
                    $ITEM[$num] = $Item;
                    $num++;
                }
                if ( $num == $NumColumns ) {
                    $txt .= sprintf( "%-25s %-25s %-25s\n\n", @ITEM );
                    foreach my $i (@ITEM) {
                        $i = '';
                    }
                    $num = 0;
                }
            }
            $txt .= sprintf( "%-25s %-25s %-25s\n", @ITEM ) if $num > 0;

            #$txt .= '-' x 78 . "\n\n\n" if ($HeaderPrint>0);
            $txt .= "\n\n" if ( $HeaderPrint > 0 );
        }
        my $temp = "$config_parms{'data_dir'}/ListManager/ListManager.prt";
        open( TMP, ">$temp" );
        print TMP $txt;
        close TMP;
        $Config{'PrintTextCommand'} =~ s/ FILE/ $temp/;
        system("$Config{'PrintTextCommand'}");
        unlink $temp;
        $html .=
          qq[<pre>$txt</pre>\n<p>The following page has been print with "$Config{'PrintTextCommand'}" <p>\n];
    }
    else {
        $html .=
          "<p>The print command hasn't been defined yet, please consult the Man page and then set the print preference</p>";
    }
    1;

}

#}}}
#sub PrintHtml{{{
sub PrintHtml {
    my $Msg = shift;
    $html .= qq[<input type="hidden" name="action" value="Print">\n];
    $html .= qq[<p><input type="submit" name="action" value="Exit"><p>\n];
    if ( $Config{'PrintHtmlCommand'} ne '' ) {
        $html .= qq[<p><center><h2>$PrettyListName</h2></center></p>\n];
        foreach my $DisplayCategory (@Category)
        {    # no sort, to display in aisles way (shopping)
            my $HeaderPrint = 0;
            my $num         = 0;
            foreach my $Item ( sort keys %{ $CurrentItem{$DisplayCategory} } ) {
                next if $Item eq 'DummyItem';
                if ( $CurrentItem{$DisplayCategory}{$Item} > 0 ) {
                    PrintHtmlHeader($DisplayCategory) if !$HeaderPrint++;
                    $html .= qq[</tr>\n<tr>\n] if $num % $NumColumns == 0;
                    my $Count = "($CurrentItem{$DisplayCategory}{$Item})"
                      if $CurrentItem{$DisplayCategory}{$Item} > 1;
                    $html .=
                      qq[<td><input type="checkbox" name="${DisplayCategory}_$Item">$Item $Count</td>\n];
                    $num++;
                }
            }
            $html .= qq[ <td></td>\n] while ( $num++ % $NumColumns != 0 );
            $html .= qq[ </tr>\n</table><hr>\n] if $HeaderPrint;
        }

        sub PrintHtmlHeader {
            my $DisplayCategory = shift;
            $html .= qq[
           <p><H3>$DisplayCategory<H3></p>
           <table width="100%" ><colgroup span="$NumColumns" width="$ColumnsWidth">
           <tr>
         ];
        }

        my $temp = "$config_parms{'data_dir'}/ListManager/ListManager.prt";
        open( TMP, ">$temp" );
        print TMP $html;
        close TMP;
        $Config{'PrintHtmlCommand'} =~ s/ FILE/ $temp/;
        system("$Config{'PrintHtmlCommand'}");
        unlink $temp;
        $html .=
          qq[<p>The following page has been print with "$Config{'PrintHtmlCommand'}" <p>\n];
    }
    else {
        $html .=
          "<p>The print command hasn't been defined yet, please consult the Man page and then set the print preference</p>";
    }
    1;
}

#}}}
#sub PrintPreview{{{
sub PrintPreview {
    my $Msg = shift;
    $html .= qq[<input type="hidden" name="action" value="PrintPreview">\n];
    $html .= qq[<p><center><h2>$PrettyListName</h2></center></p>\n];
    foreach my $DisplayCategory (@Category)
    {    # no sort, to display in aisles way (shopping)
        my $HeaderPrint = 0;
        my $num         = 0;
        foreach my $Item ( sort keys %{ $CurrentItem{$DisplayCategory} } ) {
            next if $Item eq 'DummyItem';
            if ( $CurrentItem{$DisplayCategory}{$Item} > 0 ) {
                PrintHeader($DisplayCategory) if !$HeaderPrint++;
                $html .= qq[</tr>\n<tr>\n] if $num % $NumColumns == 0;
                my $Count = "($CurrentItem{$DisplayCategory}{$Item})"
                  if $CurrentItem{$DisplayCategory}{$Item} > 1;
                $html .=
                  qq[<td><input type="checkbox" name="${DisplayCategory}_$Item">$Item $Count</td>\n];
                $num++;
            }
        }
        $html .= qq[ <td></td>\n] while ( $num++ % $NumColumns != 0 );
        $html .= qq[ </tr>\n</table>\n] if $HeaderPrint;
    }

    sub PrintHeader {
        my $DisplayCategory = shift;
        $html .= qq[
       <br><p><H3 style="font-size: 14pt; color:#630; background:#CCC none;">$DisplayCategory</H3></p>
   <table width="100%" ><colgroup span="$NumColumns" width="$ColumnsWidth">
   <tr>
   ];

    }

    1;
}

#}}}
#sub ReadConfig{{{
# this will read the configuration file, save across usage
# assume a directory ListManager in data_dir
sub ReadConfig {

    ReadDefault($DefaultList);

    # validate if directory exists
    if ( !-d $DirPath ) {
        print_log "Directory ListManager doesn't exist";
        print_log "  Creating $DirPath";
        mkdir( "$DirPath", 0755 )
          or return shoppingListError(
            "ReadConfig: Can't create directory $DirPath: $!");
    }

    # validate is we have a configuration file
    if ( !-f $ConfigFile ) {
        print_log "Creating basic configuration file $ConfigFile";
        open CONFIG, ">$ConfigFile"
          or return shoppingListError(
            "ReadConfig: Can't open config file $ConfigFile: $!");
        print CONFIG ConfigFileHeader();
        print CONFIG ConfigDefault($DefaultList);
        close CONFIG;
    }

    # do we have a list in the directory
    my @List = <$DirPath/*.lst>;

    if ( $#List < 0 ) {
        open LIST, ">$DefaultList"
          or return shoppingListError(
            "ReadConfig: Can't open new list $DefaultList: $!");
        print LIST DefaultList();
        close LIST;
    }

    # now we could read the configuration
    open CONFIG, "$ConfigFile"
      or return shoppingListError(
        "ReadConfig: Can't open config file $ConfigFile: $!");
    while (<CONFIG>) {
        chomp;
        s/^\s*(.*?)\s*$/$1/;
        next if /^#/;
        next if /^$/;
        /^(.+)=(.+)$/ && do {
            $Config{$1} = $2;
            $Config{$1} = 1 if $Config{$1} eq 'on';
            $Config{$1} = 0 if $Config{$1} eq 'off';
          }
    }
    close CONFIG;
    return 0;
}

# this need to be done, in case of upgrade/new parameter
# this contains all possible parameter
sub ReadDefault {
    $Config{'CurrentList'}           = "$DefaultList";
    $Config{'DisplayKeyboardPDA'}    = 1;
    $Config{'AddToListDefault'}      = 1;
    $Config{'DisplayKeyboardNormal'} = 1;
    $Config{'DisplayMode'}           = 'normal';
    $Config{'DisplayStatus'}         = 1;
    $Config{'NumColumnsPDA'}         = 2;
    $Config{'NumColumnsNormal'}      = 5;
    $Config{'NewUser'}               = 1;
    1;
}

sub ConfigDefault {
    return <<EndOfConfig
CurrentList=$DefaultList
DisplayKeyboardPDA=1
AddToListDefault=1
DisplayKeyboardNormal=1
DisplayMode=normal
DisplayStatus=1
NumColumnsPDA=2
NumColumnsNormal=5
NewUser=1
EndOfConfig
      ;
    1;
}

sub DefaultList {
    return <<EndOfConfig
#Category are enclosed in squared bracket, ie:[Vegetables]
#Items are following their respective category
#Items enabled are set to 1, ie: brocoli=1
[Baking]
[Breads]
   Bagels=0
   Baguette=0
   Bread Crumbs=0
   Danish=0
[Candy]
   Dark Chocolate=0
   Peanut Butter Cups=0
[Canned Fruit]
[Canned Vegetables]
[Cereal And Breakfast]
[Cleaners]
[Dairy]
[Deli]
[Dessert]
[Drinks]
[Fish And Seafood]
[Freezer Section]
[Fruits And Vegetables]
[Meat]
[Miscellaneous]
[Nuts]
[Pasta]
[Pharmacy]
[Rice]
[Sauces & Oils]
[Snacks]
[Soup]
[Tea And Coffee]
[Vegetarian]
EndOfConfig
      ;
    1;
}

sub ConfigFileHeader {
    return <<EndOfConfig
#Entry in this file are "config_parm=value"

#CurrentList define the current list in use, the list could be 
#changhe from the pull-down menu

#DisplayKeyboardPDA and DisplayKeyboardNormal control if we want to have a
#keyboard display for some input to be fill, this is usefull for keyboard
#less device, like PDA, Audrey

#DisplayMode could be "pda" or "normal". The main difference
#is in the keyboard presentation and font

#DisplayStatus will display status message about action done.

#NumColumnsPDA    define how many columns in PDA display
#NumColumnsNormal define how many columns in normal display

#PrintHtmlCommand define the command to print the list from an html format file
#                 the command is the same as you would type to send the file to the printer
#                 use the keyword "FILE" to specify the file.
#                 Consult the man page for more information
#PrintTextCommand same as Html but for a list in text format.

EndOfConfig
      ;
    1;
}

#}}}
#sub ReadList {{{
sub ReadList {
    my $CurrentCategory;
    @Category    = ();
    %CurrentItem = ();
    open( SHOPLISTFILE, "<$ListFile" )
      || return shoppingListError("ReadList $ListFile: $!");
    print "Reading file $ListFile\n" if $shoppinglistdebug;
    while (<SHOPLISTFILE>) {
        chomp;
        s/^\s*(.*?)\s*$/$1/;
        next if /^#/;
        next if /^$/;
        /^\[(.+)\]$/ && do {
            $CurrentCategory = $1;
            $CurrentCategory =~ s/(\w+)/\u\L$1/g;
            $CurrentItem{"$CurrentCategory"}{'DummyItem'} = 0;
            push @Category, $CurrentCategory;
            next;
        };
        /^(.+)=(.+)$/ && do {
            my $item = $1;
            my $val  = $2;
            $item =~ s/(\w+)/\u\L$1/g;
            $CurrentItem{"$CurrentCategory"}{"$item"} = $val;
            next;
        };
    }
    close(SHOPLISTFILE);

    #print Dumper %CurrentItem;
    1;
}

#}}}
#sub shoppingListError {{{
sub shoppingListError {
    my ($message) = @_;
    print "shoppingListError called\n   $message\n";
    return qq[
<html>
<head>
<title>List Manager Error</title>
</head>
<body>
<h3>Error in List Manager Script</h3>
<h3>$message</h3>
</body>
</html>
];
}

#}}}
#sub DisplayCurrentList {{{
sub DisplayCurrentList {
    my %ItemOn;
    my %ItemCount;
    foreach my $Category ( keys %CurrentItem ) {
        foreach my $Item ( keys %{ $CurrentItem{$Category} } ) {
            next if ( $Item eq 'DummyItem' );
            $ItemOn{"$Item"} = $Category if $CurrentItem{$Category}{$Item} > 0;
            $ItemCount{"$Item"} = "($CurrentItem{$Category}{$Item})"
              if $CurrentItem{$Category}{$Item} > 1;
        }
    }
    $html .=
      qq[<table width="100%"><colgroup span="$NumColumns" width="$ColumnsWidth">\n];
    my $num = 0;
    foreach my $Item ( sort keys %ItemOn ) {
        $html .= qq[     <tr>\n] if $num % $NumColumns == 0;
        $html .=
          qq[       <td><input type="checkbox" name="$ItemOn{$Item}_$Item" value="uncheck">$Item $ItemCount{"$Item"}</td>\n];
        $num++;
        $html .= qq[     </tr>\n] if $num % $NumColumns == 0;
    }
    $html .= qq[     </tr>\n];
    $html .= qq[   </table><hr>\n\n];
    1;
}

#}}}
#sub WriteConfig{{{
sub WriteConfig {
    open CONFIG, ">$ConfigFile"
      or return shoppingListError(
        "WriteConfig: Can't open config file $ConfigFile: $!");
    print CONFIG ConfigFileHeader();
    foreach my $k ( sort keys %Config ) {
        $Config{$k} = lc( $Config{$k} ) if $k != 'CurrentList';
        print CONFIG "$k=$Config{$k}\n";
    }
    close CONFIG;
    1;
}

#}}}
#sub WriteList {{{
sub WriteList {
    open( SHOPLISTFILE, ">$ListFile" )
      || return shoppingListError("WriteConfig: $ListFile: $!");
    print SHOPLISTFILE ListHeader();
    foreach my $Cat (@Category) {
        print SHOPLISTFILE "[$Cat]\n";
        foreach my $Item ( sort keys %{ $CurrentItem{$Cat} } ) {
            next if ( $Item eq 'DummyItem' );
            print SHOPLISTFILE "   $Item=$CurrentItem{$Cat}{$Item}\n";
        }
    }
    close SHOPLISTFILE;
    1;

    sub ListHeader {
        return <<EndOfHeader
#Category are enclosed in squared bracket, ie:[Vegetables]
#Items are following their respective category
#Items enabled are set to 1, ie: brocoli=1
EndOfHeader
          ;
        1;
    }
}

#}}}
__DATA__
__END__
#$Log: ListManager.pl,v $
#Revision 1.20  2006/03/25 06:23:14  gaetan
#finish print code
#add a submit button in search  window
#
#Revision 1.19  2006/03/21 15:30:04  gaetan
#fix window.open , but still don't like how I handle it
#add pod doc from Tom
#add keyboard to serach
#
#Revision 1.18  2006/03/21 05:30:30  gaetan
#basic search function
#
#Revision 1.17  2006/03/21 04:37:23  gaetan
#add Man page parser for POD document
#add man page in pull down menu
#
#Revision 1.16  2006/03/21 04:36:31  gaetan
#now print preview open in a new page
#remove border for ALL and Search, bad display on GCT
#
#Revision 1.15  2006/03/20 20:37:34  gaetan
#fix at shop count
#
#Revision 1.14  2006/03/20 20:05:41  gaetan
#change again columns display when we have the + - in the page
#change display in print preview
#
#Revision 1.13  2006/03/20 19:06:10  gaetan
#some test with css
#change test on pda/normal to define columns to display
#
#Revision 1.12  2006/03/19 07:54:08  gaetan
#many other change
#manage item (rename/delete)
#manage category ( rename/delete)
#add create item in item listing
#add a preference to display status message
#and many other small things.
#
#Revision 1.11  2006/03/15 18:07:52  gaetan
#check javascript, I haven't set the object to new name
#display message when category doesn't have item
#
#Revision 1.10  2006/03/15 14:39:37  gaetan
#problem when I do a "lc" in WriteConfig
#this change the name of the list , put an if condition on it
#
#Revision 1.9  2006/03/15 13:56:02  gaetan
#Lot of change in naming convention for input name
#add a quick guide
#add 2 keyboard (pda and normal)
#type in text
#
#Revision 1.8  2006/03/14 06:01:02  gaetan
#add list name at the top
#
#Revision 1.7  2006/03/14 05:51:50  gaetan
#many changes
#preferences
#manage list
#manage category
#etc.
#
#Revision 1.6  2006/03/13 22:35:29  gaetan
#test Revision number
#
#Revision 1.5  2006/03/13 22:34:58  gaetan
#workaround for audrey
#
