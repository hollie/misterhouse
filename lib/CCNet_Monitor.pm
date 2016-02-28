
=head1 B<CCNet_Monitor>

=head2 SYNOPSIS

Construct new Object of this type

 Constructor arguments:
   - instance name
   - CCNet project name
   - CCNet URL
   - Notification Object or Group
   - 1=>Announce suspects 0=>Do Not announce suspsects

Example initialization:

  $cont_build = new CCNet_Monitor('cont_build','ProgramSuite.Continuous.Build','http://dev-build1.development.programsuite.net/ccnet',$disco_light,1);
  $qa_build = new CCNet_Monitor('qa_build','ProgramSuite.QA.Build','http://dev-build1.development.programsuite.net/ccnet',undef,0);

=head2 DESCRIPTION

Gets ccnet status

Program will play sounds in the sound folder in the following format <ccnetProjectName>-<status>.wav and will set any object passed as the "Notification Object" to state "ON"

=head2 INHERITS

B<Base_Item>

=head2 METHODS

=over

=item B<UnDoc>

=cut

use strict;

package CCNet_Monitor;

@CCNet_Monitor::ISA = ('Base_Item');

sub new {
    my ( $class, $name, $project, $base_url, $indicator, $suspect_report ) = @_;
    my $self = {};

    bless $self, $class;

    $$self{base_url}        = $base_url;
    $$self{project}         = $project;
    $$self{process}         = "";
    $$self{name}            = $name;
    $$self{indicator}       = $indicator;
    $$self{suspect_report}  = $suspect_report;
    $$self{previous_status} = "";
    $$self{status}          = "UNKNOWN";

    $$self{data_file} =
        $main::config_parms{data_dir}
      . "/web/ccnet_status-"
      . $$self{project} . ".html";
    return $self;
}

sub current_status {
    my ( $self, $p_status ) = @_;
    $$self{status} = $p_status if defined $p_status;
    return $$self{status};
}

sub previous_status {
    my ( $self, $p_status ) = @_;
    $$self{previous_status} = $p_status if defined $p_status;
    return $$self{previous_status};
}

sub get_status {
    my ($self) = @_;
    my $cmd0 =
        "get_url "
      . $$self{base_url}
      . "/server/local/project/"
      . $$self{project}
      . "/ViewLatestBuildReport.aspx "
      . $$self{data_file};

    #	$$self{process} = new Process_Item("get_url " . $$self{base_url} . "/server/local/project/" . $$self{project} . "/ViewLatestBuildReport.aspx " . $$self{data_file});
    my $cmd1 = '$' . $$self{name} . "->parse_status()";

    #	$$self{process}->add($cmd1);
    #	$$self{process}->start();

    &::print_log(
        "Retrieving ccnet status for: $$self{project}, with " . $cmd1 . ":" );

    #	exec($cmd0);
    &::run( 'inline', $cmd0 );
    $self->parse_status();
    return;
}

sub parse_status {
    my ($self) = @_;
    my $l_file;
    my @l_data;
    my $found_status;
    my $found_section;
    my $section_no = 0;
    my $previous_suspect;
    my $line_no = 0;

    open( l_file, $$self{data_file} );
    while (<l_file>) {
        $line_no++;
#### Status
        #	<td class="header-title" colspan="2">BUILD SUCCESSFUL</td>
##########
        if (/.*class=\"header-title\"/) {
            $found_status = 1;
            $self->previous_status( $$self{status} );
            @l_data =
              $_ =~ /<td class=\"header-title\" colspan=\"2\">BUILD (.*)</;
            $self->current_status( $l_data[0] );

            #			$self->{status} = $l_data[0];
            if (
                $self->current_status() ne 'SUCCESSFUL'
                or (    $self->previous_status() ne 'SUCCESSFUL'
                    and $self->previous_status() ne ''
                    and $self->current_status() eq 'SUCCESSFUL' )
              )
            {
                $self->notification( $self->current_status() );
                if ( $$self{status} ne 'SUCCESSFUL' ) {
                    $$self{indicator}->set('ON') if defined $$self{indicator};
                }
                else {
                    $$self{indicator}->set('OFF') if defined $$self{indicator};
                }
            }
        }
#### Suspects
        #  <tr class="section-evenrow">
        #    <td class="section-data" valign="top">Modified</td>
        #    <td class="section-data" valign="top">banderson</td>
        #    <td class="section-data" valign="top">/Company/ProgramSuite/trunk/Class Libraries/Company.ProgramSuite.Model/VendorAccount.cs</td>
        #    <td class="section-data" valign="top">Added TermTypeID for handling value type in serialization</td>
        #    <td class="section-data" valign="top">2007-01-31 14:17:27</td>
        #  </tr>
#############
        if (    /.*Modifications since last build.*/
            and $found_status eq 1
            and $$self{suspect_report} eq 1 )
        {
            $$self{suspects} = undef;
            if ( $self->current_status() ne 'SUCCESSFUL' ) {
                &::play( mode => wait, file => "suspects.wav" );
            }
        }

        if (    /.*<tr class=\"section.*row\">/
            and $found_status eq 1
            and $found_section ne 1
            and $$self{suspect_report} eq 1 )
        {
            $found_section = 1;
            $section_no    = 0;
        }
        if ( /.*<td class=\"section-data\" valign=\"top\">/
            and $found_section eq 1 )
        {
            $section_no++;
            if ( $section_no eq 2 ) {
                $section_no    = 0;
                $found_section = 0;
                @l_data =
                  $_ =~ /<td class=\"section-data\" valign=\"top\">(.*)<\/td>/;
                if (    $self->current_status() ne 'SUCCESSFUL'
                    and $previous_suspect ne $l_data[0] )
                {
                    $$self{suspects} += $l_data[0] . ",";
                    if ( $l_data[0] ne "" ) {
                        $self->notification_suspect( $l_data[0] );
                    }
                    else {
                        $self->notification_suspect('kminder');
                    }
                    $previous_suspect = $l_data[0];
                }
            }
        }
        next;
    }
    close(l_file);
    &::print_log(
        "Build:$$self{project} Status:$$self{status} Suspects:$$self{suspects} Previous:$$self{previous_status}"
    );
    return $self;
}

sub notification {
    my ( $self, $p_status ) = @_;

    my $filen;

    $filen = $$self{project} . "-notification.wav";
    &::play( mode => wait, file => $filen );

    $filen = $$self{project} . "-" . lc($p_status) . '.wav';
    &::play( mode => wait, file => $filen );
    return $self;
}

sub notification_suspect {
    my ( $self, $suspect ) = @_;

    $suspect = lc($suspect);

    #	&::play(mode=>wait,file=>$$self{project} . "-$suspect.wav");
    &::play( mode => wait, file => "$suspect.wav" );
    return $self;
}

1;

=back

=head2 INI PARAMETERS

NONE

=head2 AUTHOR

Jason Sharpee
jason@sharpee.com

=head2 SEE ALSO

NONE

=head2 LICENSE

This program is free software; you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation; either version 2 of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more details.

You should have received a copy of the GNU General Public License along with this program; if not, write to the Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.

=cut

