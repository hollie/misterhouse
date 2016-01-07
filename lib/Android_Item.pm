
=head1 B<Android_Item>

=head2 SYNOPSIS

NONE

=head2 DESCRIPTION

This module allows MisterHouse to capture and send speech and played wav files to an Android unit.

=head2 INHERITS

B<Generic_Item>

=head2 METHODS

=item B<UnDoc>

=cut

use strict;

package Android_Item;

@Android_Item::ISA = ('Generic_Item');

use HTML::Entities;    # So we can encode characters like <>& etc

# Constructor
sub new {
    my ($class) = @_;
    my $self = {};
    bless $self, $class;

    #Tell MH to call our routine each time something is spoken
    #&::Speak_parms_add_hook(\&Andoid_Server::pre_speak_to_android, $self);
    #&::Play_parms_add_hook(\&Andoid_Server::pre_play_to_android, $self);
    &::MainLoop_pre_add_hook( \&Android_Item::state_machine,
        'persistent', $self );

    $self->{toggle_item} = new Generic_Item();
    $self->{toggle_item}->set_states( 'on', 'off' );
    $self->{toggle_item}->android_set_name("toggle_item");

    $self->{spinner_item} = new Generic_Item();
    $self->{spinner_item}->set_states( 'one', 'two', 'three' );
    $self->{spinner_item}->android_set_name("spinner_item");

    $self->{text_item} = "Simple Text";

    return $self;
}

sub state_machine {
    my ($self) = @_;
}

sub speech_log {
    my ($self) = @_;
    my @last_spoken =
      &main::speak_log_last( $main::config_parms{max_log_entries} );
    return @last_spoken;
}

sub print_log {
    my ($self) = @_;
    my @last_printed =
      &main::print_log_last( $main::config_parms{max_log_entries} );
    return @last_printed;
}

sub set {
    my ( $self, $value ) = @_;
    &main::print_log("set: $value");

    # Check for JSON command
    if ( $value =~ /^{/ ) {
        $value =~ s/\'/"/g;
        &main::print_log("Android_Item:: json: $value")
          if ( $::Debug{android} );
        my $json = JSON->new->allow_nonref;
        my $ref  = $json->decode($value);
        if ( ref $ref eq 'HASH' ) {
            if ( $ref->{"toggle_item"} ) {
                my $value = $ref->{"toggle_item"};
                &main::print_log("Android_Item:: toggle_item: $value")
                  if ( $::Debug{android} );
                $self->{toggle_item}->set($value);
            }
            if ( $ref->{"spinner_item"} ) {
                my $value = $ref->{"spinner_item"};
                &main::print_log("Android_Item:: spinner_item: $value")
                  if ( $::Debug{android} );
                $self->{spinner_item}->set($value);
            }
            if ( $ref->{"image_button"} eq "true" ) {
                &main::print_log("Android_Item:: image_button activated!")
                  if ( $::Debug{android} );
            }
        }
        else {
            &main::print_log("Android_Item:: json decode failed!")
              if ( $::Debug{android} );
        }
    }
}

sub get_array_example ( ) {
    my ($self) = @_;
    my @array;
    push @array, 'Array Value 1';
    push @array, 'Array Value 2';
    push @array, 'Array Value 3';
    push @array, 'Array Value N';
    return @array;
}

sub get_hash_example ( ) {
    my ($self) = @_;
    my %hash;
    $hash{"Key 1"} = "Data 1";
    $hash{"Key 2"} = "Data 2";
    $hash{"Key 3"} = "Data 3";
    $hash{"Key 4"} = "Data 4";
    $hash{"Key N"} = "Data N";
    return %hash;
}

sub android_xml {
    my ( $self, $depth, $fields, $num_tags, $attributes ) = @_;
    my @f =
      qw( speech_log print_log text_item toggle_item spinner_item image_button array_example hash_example);

    # Avoid filter due to no state
    $attributes->{noFilterState} = "true";

    my $xml_objects =
      $self->SUPER::android_xml( $depth, $fields, $num_tags + scalar(@f),
        $attributes );
    my $prefix = '  ' x $depth;

    foreach my $f (@f) {
        next unless $fields->{all} or $fields->{$f};

        my $method = $f;
        my $value;
        if (
            $self->can($method)
            or ( ( $method = 'get_' . $method )
                and $self->can($method) )
          )
        {
            if ( $f eq 'speech_log' ) {
                my @a = $self->$method;
                $value = \@a;
            }
            elsif ( $f eq 'print_log' ) {
                my @a = $self->$method;
                $value = \@a;
            }
            elsif ( $f eq 'array_example' ) {
                my @a = $self->$method;
                $value = \@a;
            }
            elsif ( $f eq 'hash_example' ) {
                my %a = $self->$method;
                $value = \%a;
            }
            else {
                $value = $self->$method;
                $value = encode_entities( $value, "\200-\377&<>" );
            }
        }
        elsif ( exists $self->{$f} ) {
            $value = $self->{$f};
            if ( ref $value ne 'REF' ) {
                $value = encode_entities( $value, "\200-\377&<>" );
            }
        }

        # Add alias to change display name on android list
        if ( $f eq 'text_item' ) {
            $attributes->{alias} = "Text Item";
        }

        # Display an example toggle
        if ( $f eq 'toggle_item' ) {
            $attributes->{alias} = "Toggle Item";
        }

        # Display an example spinner
        if ( $f eq 'spinner_item' ) {
            $attributes->{alias} = "Spinner Item";
        }

        # Display an example image button
        if ( $f eq 'image_button' ) {
            $attributes->{alias} = "Image Button";
            $attributes->{type}  = "image";
        }

        # Display an example array
        if ( $f eq 'array_example' ) {
            $attributes->{alias} = "Array Example";
        }

        # Display an example hash
        if ( $f eq 'hash_example' ) {
            $attributes->{alias} = "Hash Example";
        }

        # Insert the values for each key into xml structure
        if ( ref $value eq 'Generic_Item' ) {

            #my $attributes = {};
            $attributes->{object}       = $value->{object_name};
            $attributes->{type}         = ref $value;
            $attributes->{memberObject} = "true";
            $xml_objects .=
              $value->android_xml( $depth + 1, $fields, 0, $attributes );
            $xml_objects .= $prefix . "</$value->{object_name}>\n";
        }

        elsif ( ref $value eq 'ARRAY' ) {
            $attributes->{type} = "arrayList";
            $xml_objects .= $self->android_xml_tag( $prefix, $f, $attributes );
            $prefix = '  ' x ( $depth + 1 );
            foreach ( @{$value} ) {
                $_ = "" unless defined $_;
                my $val = $_;
                $val = encode_entities( $val, "\200-\377&<>" );
                $xml_objects .=
                  $self->android_xml_tag( $prefix, "value", $attributes, $val );
            }
            $prefix = '  ' x $depth;
            $xml_objects .= $prefix . "</$f>\n";
        }

        elsif ( ref $value eq 'HASH' ) {
            $attributes->{type} = "hashList";
            $xml_objects .= $self->android_xml_tag( $prefix, $f, $attributes );
            $prefix = '  ' x ( $depth + 1 );
            foreach my $key ( keys %{$value} ) {
                my $val = $value->{$key};
                $val = "" unless defined $val;
                $val = encode_entities( $val, "\200-\377&<>" );
                $key = encode_entities( $key, "\200-\377&<>" );
                $key =~ s/ /_/g;
                $key =~ s/[\[\]]/_/g;
                $xml_objects .=
                  $self->android_xml_tag( $prefix, $key, $attributes, $val );
            }
            $prefix = '  ' x $depth;
            $xml_objects .= $prefix . "</$f>\n";
        }

        else {
            $value = "" unless defined $value;
            $xml_objects .=
              $self->android_xml_tag( $prefix, $f, $attributes, $value );
        }
    }
    return $xml_objects;
}

1;

=back

=head2 INI PARAMETERS

Add "server_android_port" to your ini file.  The default port is 4444.  The port number assigned to server_android_port must match the port configured in the android client.  The ports must match in order for the android device to receive speech events and notifications.

  server_android_port=4444

By default, ALL speak and play events will be pushed to ALL android's regardless of the value in the speak/play "rooms" parameter.  If you want the android's to honor the rooms parameter, then you must define the android_use_rooms parameter in my.private.ini.  Each android declares a room name when the android registers with the server.

  android_use_rooms=1

=head2 AUTHOR

UNK

=head2 SEE ALSO

NONE

=head2 LICENSE

This program is free software; you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation; either version 2 of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more details.

You should have received a copy of the GNU General Public License along with this program; if not, write to the Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.

=cut

