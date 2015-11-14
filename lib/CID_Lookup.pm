
=head1 B<CID_Lookup>

=head2 SYNOPSIS

Example initialization:

  use CID_Lookup;
  $cid = new CID_Lookup($telephony_driver);

Constructor Parameters:

  $x = new CID_lookup($y);
  $x - Reference to the class
  $y - Telephony driver reference

Input states:

  "cid"           - Caller ID event
  "ring"          - Ring event 'to pass along to other consumers of this object'

Output states:

  "cid"           - Caller ID event
  "ring"          - Ring event 'to pass along to other consumers of this object'

=head2 DESCRIPTION

Translates a caller name and number to more information based on file data

=head2 INHERITS

B<Telephony_Item>

=head2 METHODS

=over

=item B<UnDoc>

=cut

use strict;

package CID_Lookup;

@CID_Lookup::ISA = ('Telephony_Item');

my $m_CIDAreaCode;
my $m_CIDCity;
my $m_CIDState;
my $m_CIDCategory;
my $m_CIDFile;
my $m_CIDFirst;
my $m_CIDMiddle;
my $m_CIDLast;
my $m_CIDPrefix;
my $m_CIDSuffix;
my $m_CIDExtension;
my $m_CIDTimeZone;
my $m_CIDFormatedNumber;
my $m_CIDSpeakableNumber;
my $m_datafile;

sub new {
    my ( $class, $p_telephony, $p_datafile ) = @_;
    my $self = {};

    bless $self, $class;

    $self->restore_data(
        qw(
          m_CIDName
          m_CIDNumber
          m_CIDType
          m_Address
          m_RingCount
          m_CallDuration
          m_Extension
          m_CallType
          set_time
          )
    );

    #	&::print_log("CID $self: Tel $p_telephony");
    $self->add($p_telephony) if defined $p_telephony;

    #	$m_datafile='/usr/local/mh/data/phone/phone.cid.list'; #default
    #	$m_datafile=$p_datafile if defined $p_datafile;
    return $self;
}

sub add {
    my ( $self, $p_telephony ) = @_;

    if ( defined $p_telephony ) {
        $p_telephony->tie_items( $self, "CID" );
        $p_telephony->tie_items( $self, "cid" );

        #$p_telephony->tie_items($self,"DIALED");
        $p_telephony->tie_items( $self, "dialed" );
        $p_telephony->tie_items( $self, "RING" );
        $p_telephony->tie_items( $self, "ring" );
        $p_telephony->tie_items( $self, "CALLCOMPLETE" );
        $p_telephony->tie_items( $self, "callcomplete" );
    }
}

sub set {
    my ( $self, $p_state, $p_setby ) = @_;

    #	&::print_log("CID state:$p_state:");
    $p_state = lc $p_state;
    if ( $p_state =~ /^(CID|DIALED|CALLCOMPLETE)/i ) {

        #reset values
        $self->cid_name( $p_setby->cid_name() );
        $self->cid_number( $p_setby->cid_number() );
        $self->cid_type( $p_setby->cid_type() );
        $self->address( $p_setby->address() );
        $self->category("");
        $self->cid_state("");
        $self->city("");
        $self->areacode("");
        $self->prefix("");
        $self->suffix("");
        $self->first("");
        $self->last("");
        $self->middle("");
        $self->file("");
        $self->time_zone("");
        $self->formated_number("");
        $self->speakable_number("");
        $self->ring_count( $p_setby->ring_count() );
        $self->parse_number($p_setby);
        $self->lookup_info( $::config_parms{caller_id_file} );
        $self->lookup_areacode( $::config_parms{area_code_file},
            $::config_parms{state_file} );
        $self->parse_name($p_setby);
        $self->call_duration( $p_setby->call_duration() )
          if $p_setby->isa('Telephony_Item');
        $self->call_type( $p_setby->call_type() )
          if $p_setby->isa('Telephony_Item');
        $self->extension( $p_setby->extension() )
          if $p_setby->isa('Telephony_Item');

        #	$self->
    }
    elsif ( $p_state =~ /^ring/i ) {
        $self->ring_count( $p_setby->ring_count() );
    }
    $self->SUPER::set($p_state);
}

sub name {
    my ( $self, $p_Name ) = @_;
    return $self->cid_name($p_Name);
}

sub number {
    my ( $self, $p_Number ) = @_;
    return $self->cid_number($p_Number);
}

sub formated_number {
    my ( $self, $p_CIDFormatedNumber ) = @_;
    $$self{m_CIDFormatedNumber} = $p_CIDFormatedNumber
      if defined $p_CIDFormatedNumber;
    return $$self{m_CIDFormatedNumber};
}

sub speakable_number {
    my ( $self, $p_CIDSpeakableNumber ) = @_;
    $$self{m_CIDSpeakableNumber} = $p_CIDSpeakableNumber
      if defined $p_CIDSpeakableNumber;
    return $$self{m_CIDSpeakableNumber};
}

sub type {
    my ( $self, $p_Type ) = @_;
    return $self->cid_type($p_Type);
}

sub areacode {
    my ( $self, $p_CIDAreaCode ) = @_;
    $$self{m_CIDAreaCode} = $p_CIDAreaCode if defined $p_CIDAreaCode;
    return $$self{m_CIDAreaCode};
}

sub prefix {
    my ( $self, $p_CIDPrefix ) = @_;
    $$self{m_CIDPrefix} = $p_CIDPrefix if defined $p_CIDPrefix;
    return $$self{m_CIDPrefix};
}

sub suffix {
    my ( $self, $p_CIDSuffix ) = @_;
    $$self{m_CIDSuffix} = $p_CIDSuffix if defined $p_CIDSuffix;
    return $$self{m_CIDSuffix};
}

sub category {
    my ( $self, $p_CIDCategory ) = @_;
    $$self{m_CIDCategory} = $p_CIDCategory if defined $p_CIDCategory;
    return $$self{m_CIDCategory};
}

sub city {
    my ( $self, $p_CIDCity ) = @_;
    $$self{m_CIDCity} = $p_CIDCity if defined $p_CIDCity;
    return $$self{m_CIDCity};
}

sub cid_state {
    my ( $self, $p_CIDState ) = @_;
    $$self{m_CIDState} = $p_CIDState if defined $p_CIDState;
    return $$self{m_CIDState};
}

sub time_zone {
    my ( $self, $p_CIDTimeZone ) = @_;
    $$self{m_CIDTimeZone} = $p_CIDTimeZone if defined $p_CIDTimeZone;
    return $$self{m_CIDTimeZone};
}

sub first {
    my ( $self, $p_CIDFirst ) = @_;
    $$self{m_CIDFirst} = $p_CIDFirst if defined $p_CIDFirst;
    return $$self{m_CIDFirst};
}

sub last {
    my ( $self, $p_CIDLast ) = @_;
    $$self{m_CIDLast} = $p_CIDLast if defined $p_CIDLast;
    return $$self{m_CIDLast};
}

sub middle {
    my ( $self, $p_CIDMiddle ) = @_;
    $$self{m_CIDMiddle} = $p_CIDMiddle if defined $p_CIDMiddle;
    return $$self{m_CIDMiddle};
}

sub file {
    my ( $self, $p_CIDFile ) = @_;
    $$self{m_CIDFile} = $p_CIDFile if defined $p_CIDFile;
    return $$self{m_CIDFile};
}

# Convert CID name to first, last, middle if possible
sub parse_name {
    my ( $self, $p_Telephony ) = @_;

    #	my $p_name = $p_Telephony->CIDName();
    my $p_name = $self->cid_name();
    $self->cid_name($p_name);

    my $l_first;
    my $l_last;
    my $l_middle;

    #first determine if "Last, First" or not (possibly company instead)
    #	&::print_log("CID H in loop :$p_name:");
    if ( $p_name =~ /,/g ) {

        #		&::print_log("CID L in loop :$p_name:");
        #put a space after a comma for scrunched CID names.
        $p_name =~ s/,(\S)/, $1/g;
        $self->cid_name($p_name);

        #		&::print_log("CID J in loop :$p_name:");

        ( $l_last, $l_first, $l_middle ) = split( ' ', $p_name );
        $l_last =~ s/,//g;    # remove commas
        if ( length($l_middle) > 1 ) {
            $l_middle = '';
        }

    }
    else {
        ( $l_first, $l_middle, $l_last ) = split( ' ', $p_name );
        if ( length($l_middle) > 1 ) {
            $l_last   = $l_middle;
            $l_middle = '';
            if ( $::config_parms{cid_reverse_names} ) {
                my $temp = $l_last;
                $l_last  = $l_first;
                $l_first = $temp;
            }
        }
    }

    $self->first($l_first);
    $self->middle($l_middle);
    $self->last($l_last);

}

sub parse_number {
    my ( $self, $p_Telephony ) = @_;

    my $l_Number = $p_Telephony->cid_number();

    if ( $::config_parms{country} =~ /US|CANADA|CA/i ) {

        #US Centric code (just dont use these parameters if you are not US)
        $l_Number =~ s/[\(,\),\-]//g;  #No Need for syntax take it out
        $self->number($l_Number);
        $l_Number =~ s/^1//;           #if 1 in the beginning of number, ice it.
        $l_Number =~ /(\d\d\d)(\d\d\d)(\d\d\d\d)$/;
        $self->areacode($1);
        $self->prefix($2);
        $self->suffix($3);

    }
    elsif ( $::config_parms{country} =~ /UK/i ) {

        #Variable Area codes, so we need to rely on file of area codes?
        #do this in the lookup area code instead.
    }

    #just in case we cant resolve area code format, set to number
    $self->formated_number( $p_Telephony->cid_number() );

}

sub lookup_info {
    my ( $self, $p_CIDFile ) = @_;

    my $l_name;
    my $l_number;
    my $l_type;
    my $l_file;
    my $l_category;
    my $l_CIDName;
    my $l_CIDNumber;
    my $l_CIDType;

    if ($p_CIDFile) {
        open( CALLERID, $p_CIDFile )
          or print
          "\nError, could not find the caller id file $p_CIDFile: $!\n";

        #find the matching rows
        $l_CIDNumber = $self->cid_number();
        $l_CIDName   = $self->cid_name();
        $l_CIDType   = $self->cid_type();

        &::print_log(
            "CID Lookup searching for: $l_CIDNumber, $l_CIDName, $l_CIDType");
        while (<CALLERID>) {

            #			print "CID1:$_\n";
            next if /^\#/ or !/\S+/;

            #clear prior fields
            $l_number   = undef;
            $l_name     = undef;
            $l_file     = undef;
            $l_category = undef;

            #Find number and name first
            $_ =~ /^([\w\*\-\)\(]+)([\s]+|[,])(.*)/;
            $l_number = $1;
            $l_name   = $3;
            $l_name =~ s/^\s*//;    #trim junk from beginning

            #			print "CID2:$l_number:$l_name:$l_file:$l_category\n";

            #If more parms are defined use file and category
            if ( $l_name =~ /,|\t/g )    #more parms
            {
                ( $l_name, $l_file, $l_category ) =
                  split( /\t+|,\s*/, $l_name );
            }

            #			print "CID2a:$l_number:$l_name:$l_file:$l_category\n";

            $l_name =~ s/\s*$//;         #trim the fat off the end
            $l_name     = '*'       unless $l_name;
            $l_file     = '*'       unless $l_file;
            $l_category = 'general' unless $l_category;

            $l_number =~ s/[\(,\),\-]//g;    #No Need for syntax take it out

            #			print "CID5: $l_number,$l_name,$l_file,$l_category\n";

            #translate * to regex
            $l_number =~ s/\*/.\*/g;
            $l_name =~ s/\*/.\*/g;
            $l_category =~ s/\*//g;
            $l_file =~ s/\*//g;

            #convert number to special type
            $l_type = 'N';
            if ( $l_number =~ /PRIVATE|P/i ) {
                $l_type = 'P';
            }
            if ( $l_number =~ /UNKNOWN|U|UNAVAILABLE/i ) {
                $l_type = 'U';
            }
            if ( $l_number =~ /I|INTERNATIONAL/i ) {
                $l_type = 'I';
            }

            #			print "CID RowT: $l_number,$l_name,$l_type,$l_file,$l_category";

            #If number matches or no-number types match
            if ( $l_CIDNumber =~ /$l_number/i
                or ( $l_CIDType ne 'N' and $l_CIDType eq $l_type ) )
            {
                #				&::print_log("Match CID number $l_number $l_type");
                #If name regex matches then get record
                if ( $l_CIDName =~ /$l_name/i ) {

                    #					&::print_log("Match CID name $l_name $l_type");
                    $self->file($l_file);
                    $self->category($l_category);
                    last;
                }

                #If name does not match (number does) and name is not a search then use this record and name
                elsif ( $l_name !~ /\.\*/g ) {

                    #					&::print_log("Match CID number alone $l_number $l_type");
                    $self->cid_name($l_name);
                    $self->file($l_file);
                    $self->category($l_category);
                    last;
                }
            }
        }
        close CALLERID;
    }
}

sub lookup_areacode {
    my ( $self, $p_area_code_file, $p_state_file ) = @_;

    my ( $areacode, $state, $city, $timeoffset );
    my ( %state_by_abbrv, $state_abbrv, $state_name );
    open( STATENAME, $p_state_file )
      or print "\nError, could not find the state file $p_state_file\n";
    while (<STATENAME>) {
        next if /^\#/;
        ( $state_abbrv, $state_name ) = $_ =~ /(\S+)\s+(.*)/;

        #		chop $state_name;
        $state_by_abbrv{$state_abbrv} = $state_name;
    }

    close STATENAME;

    open( AREACODE, $p_area_code_file )
      or print "\nError, could not find the area code file $p_area_code_file\n";

    while (<AREACODE>) {
        next if /^\#/;
        if ( $::config_parms{country} =~ /US|CANADA/i ) {

            # Delete descriptors like (Southern) Texas ... too much to speak
            $_ =~ s/\(.+?\)//;

            #406 All parts of Montana
            #			&::print_log("Line ". $_);
            #Old Format code
            #			($areacode, $state) = $_ =~ /(\d\d\d) All parts of (.+)/;
            #			($areacode, $city, $state) = $_ =~ /(\d\d\d)(.*), *(.+)/ unless $state;
            # 			New format Adapted from Tim Doyle's parsing code
            ( $areacode, $state, $timeoffset, $city ) =
              $_ =~ /(\S*)\s*(\S*)\s*(\S*)\s*(.*)/;

            if ( $city =~ /.*:.*/ ) {
                ($city) = $city =~ /.*:(.*)/;
            }
            if ( $city =~ /.*,.*/ ) {
                ($city) = $city =~ /(.*),.*/;
            }

            next unless $city;

            #			&::print_log($self->areacode() . ", $areacode, $city, $state");
            next unless $city;
            if ( $areacode eq $self->areacode() ) {
                $self->city($city);
                $self->cid_state($state);
                $self->cid_state( $state_by_abbrv{$state} )
                  if $state_by_abbrv{$state};
                $self->time_zone($timeoffset);

                #process the formated number
                $self->formated_number( $self->areacode() . "-"
                      . $self->prefix() . "-"
                      . $self->suffix() );

                last;
            }
        }
        elsif ( $::config_parms{country} =~ /UK/i ) {

            #UK area codes are variable in length.. Match the beginning
            #Adapted from Clive Freedman's code.
            # Ignore irrelevant lines
            next unless /^\d/;

            ($areacode) = $_ =~ /(\d+)_/;
            ($city)     = $_ =~ /_\s+(.+)$/;

            $city =~ s/   .+$//;
            $state = $city;
            print "Checking: areacode=$areacode city=$city\n"
              if $::config_parms{debug} eq 'phone';
            next unless $city;
            if ( $self->number() =~ /^$areacode/ ) {
                $self->city($city);
                $self->cid_state($state);
                $self->areacode($areacode);
                $self->prefix("");
                my $suffix = $self->number();

                #               $self->suffix($suffix =~ s/^$areacode//;
                $suffix =~ s/^$areacode//;
                $self->suffix($suffix);

                #process the formated number
## The next line is irrelevant in the UK.  There is no consistent formatting.
                #				$self->formated_number($self->areacode() . "-" . $self->suffix());
                $self->formated_number( $self->number );

                last;
            }
        }
    }
    close AREACODE;

    #Process the speakable number .. padded with spaces for TTS
    my $temp_speak = $self->cid_number();
    $temp_speak =~ s/([0-9])/$1 /g;
    $self->speakable_number($temp_speak);

}

1;

=back

=head2 INI PARAMETERS

NONE

=head2 AUTHOR

Jason Sharpee
jason@sharpee.com

Special Thanks to:
Bruce Winter - MH
Tim Doyle - New Area Code format
Clive Freeman

=head2 SEE ALSO

For example see g_phone.pl

=head2 LICENSE

This program is free software; you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation; either version 2 of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more details.

You should have received a copy of the GNU General Public License along with this program; if not, write to the Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.

=cut

