
=head1 B<table_A2XML>

=head2 SYNOPSIS

NONE

=head2 DESCRIPTION

AGENDA:

the table_A and table_A_xml formats have grown quite divergent.
Basically, new items have been added to table_A that aren't being
kept in the xml counterpart.  Not many users (if any) are using the
xml format to specify item definitions.  Since it is potentially more
powerful and flexible, this code aims to decomission the table_A format,
installing the xml layout as the sole authority for item definitions.

Once EVERYONE is converted, this code should probably go away as well,
so that the xml format can continue to evolve.  IMHO, the "other" tag
is overused in the table A format, and should become obsolete with
xml properly deployed.  We can't really shoot the "other" tag, until the
table_A format is retired.

First things first...

ISSUES:

  1) PA unconverted, unimplemented  (no PA *.mht submitted for test)
  2) COMPOOL unconverted, unimplemented  (no COMPOOL *.mht submitted for test)
  4) Neil Wrightson single quote around Ibutton objects don't generate clean

=head2 INHERITS

B<NONE>

=head2 METHODS

=over

=item B<UnDoc>

=cut

use strict;

package table_A2XML;
use FileHandle;
use Carp;

sub convert {
    my ( $tgt, $dest ) = @_;
    my $xml_out;
    my $format  = 0;
    my $in_file = new FileHandle $tgt;
    confess "can't read [$tgt]\n" unless $in_file;
    while (<$in_file>) {
        if ( /Format\s*=\s*(\S+)/i && $1 eq "A" )
        {    ## we're hard-wired for tbl A
            $format  = $1;
            $xml_out = new FileHandle ">$dest";
            confess "can't write [$dest]\n" unless $xml_out;
            print $xml_out &warning_banner($tgt);
            print $xml_out "<items>\n";
            next;
        }
        next unless ($format);

        my (
            $code,      $address,    $name,      $object,
            $grouplist, $comparison, $limit,     @other,
            $other,     $vcommand,   $occupancy, $pa_type
        );
        my ($type);
        my ($comment);
        my (@item_info);

        chomp;
        s/\s+$//g;    ## try to consume any extra cf or lf from win32 files

        next if (/^\s*$/);
        &escape_xml_chars($_);
        if (s/^\s*(#+)/$1/g) {
            next if (/^[\s#]*$/);
            $comment = $_;
            s/#//g;
            print $xml_out "<user_comment>$_</user_comment>\n";
            next;
        }

        ( $type, @item_info ) = split( ',\s*', $_ );
        $type = uc $type;
        if ( $type eq "GROUP" || $type eq "GENERIC" || $type eq "OCCUPANCY" ) {
            ( $name, $grouplist, @other ) = @item_info;
        }
        elsif ( $type eq "VOICE" ) {
            ( $name, @other ) = @item_info;
            (@other) = join ',', @other;    ### VOICE commands aren't split.
        }
        elsif ( $type eq "PRESENCE" ) {
            ( $object, $occupancy, $name, $grouplist, @other ) = @item_info;
        }
        elsif ( $type eq "PA" ) {
            ( $address, $name, $grouplist, $other, $pa_type ) = @item_info;
        }

        else {
            ( $address, $name, $grouplist, @other ) = @item_info;
        }

        print $xml_out "\t<item>\n";
        print $xml_out "\t\t<type>$type</type>\n";
        print $xml_out "\t\t<address>$address</address>\n" if ($address);
        print $xml_out "\t\t<name>$name</name>\n";

        ### generate a separate group tag for each group.
        foreach my $group ( split( /\|/, $grouplist ) ) {
            my $fp_loc;    ## extract the floorplan attributes
            if ( $group =~ s/\((\S+?)\).*// ) {
                $fp_loc = ' fp_loc="' . $1 . '"';
                $fp_loc =~ s/;/,/g;
            }
            print $xml_out "\t\t<group$fp_loc>$group</group>\n";

        }

        ## the parse code expects the @other group to be positional dependant
        ##  tags.  we'll oblige by including individual "other" tags foreach
        ##  array element.
        foreach my $other ( @other, $other ) {
            print $xml_out "\t\t<other>$other</other>\n" if ($other);
        }

        ##  special tags for PRESENCE...
        print $xml_out "\t\t<object>$object</object>\n" if ($object);
        print $xml_out "\t\t<occupancy>$occupancy</occupancy>\n"
          if ($occupancy);

        ##  special tags for PA
        print $xml_out "\t\t<pa_type>$pa_type</pa_type>\n" if ($pa_type);

        print $xml_out "\t</item>\n";

    }
    &_cntrl_brk($xml_out);    ## final brk.
}

sub _cntrl_brk {
    my ($xml_out) = @_;
    $xml_out && print $xml_out "</items>\n";
}

sub warning_banner {
    my ($src_file) = @_;
    return <<END_BANNER;
<!--
###########################################################
###########################################################
##
##  This file has been auto generated based on the content
##    of [$src_file].  The mht files will
##    be phased out, if all goes well.  However, as long
##    as this banner is placed at the beginning of the xml
##    file, maintenance should continue to be performed 
##    through the original mht file!!!
## 
##  The file format for this file will evolve, and the
##    transition will be smoother if you do not switch
##    to this file format for your changes (yet).
## 
## 
##  YOU HAVE BEEN WARNED! DO NOT CHANGE THIS FILE!
## 
###########################################################
###########################################################
###########################################################
-->
END_BANNER
}

sub escape_xml_chars {
    ## modify the callers copy of the data directly thru @_
    foreach my $data (@_) {
        $data =~ s/&/&amp;/g;    ## amp first so we don't whack the &lt;
        $data =~ s/</&lt;/g;
        $data =~ s/>/&gt;/g;
    }
}
1;

=back

=head2 INI PARAMETERS

NONE

=head2 AUTHOR

UNK

=head2 SEE ALSO

NONE

=head2 LICENSE

This program is free software; you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation; either version 2 of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more details.

You should have received a copy of the GNU General Public License along with this program; if not, write to the Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.

=cut

