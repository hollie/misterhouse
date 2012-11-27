=begin comment

Android_Item.pm

This module allows MisterHouse to capture and send speech and played
wav files to an Android unit.

- mh.private.ini requirements

Add "server_android_port" to your ini file.  The default port is 4444.
The port number assigned to server_android_port must match the port
configured in the android client.  The ports must match in order for
the android device to receive speech events and notifications.

server_android_port=4444

By default, ALL speak and play events will be pushed to ALL android's
regardless of the value in the speak/play "rooms" parameter.  If you
want the android's to honor the rooms parameter, then you must define
the android_use_rooms parameter in my.private.ini.  Each android declares
a room name when the android registers with the server.

android_use_rooms=1

=cut

use strict;

package Android_Item;

@Android_Item::ISA = ('Generic_Item');

use HTML::Entities;    # So we can encode characters like <>& etc

# Constructor
sub new {
    my ($class) = @_;
    my $self = { };
    bless $self, $class;

    #Tell MH to call our routine each time something is spoken
    #&::Speak_parms_add_hook(\&Andoid_Server::pre_speak_to_android, $self);
    #&::Play_parms_add_hook(\&Andoid_Server::pre_play_to_android, $self);
    &::MainLoop_pre_add_hook(\&Android_Item::state_machine, 'persistent', $self);

    $self->{toggle_item} = new Generic_Item( );
    $self->{toggle_item}->set_states('off','on');

    $self->{spinner_item} = new Generic_Item( );
    $self->{spinner_item}->set_states('one', 'two', 'three');

    return $self;
}

sub state_machine {
    my ($self) = @_;
}

sub speech_log {
    my ($self) = @_;
    my @last_spoken = &main::speak_log_last($main::config_parms{max_log_entries});
    return @last_spoken;
}

sub print_log {
    my ($self) = @_;
    my @last_printed = &main::print_log_last($main::config_parms{max_log_entries});
    return @last_printed;
}

sub android_xml {
    my ($self, $depth, $fields, $num_tags, $attributes) = @_;
    my @f = qw( speech_log print_log toggle_item spinner_item);

    # Avoid filter due to no state
    $attributes->{noFilterState} = "true";

    my $xml_objects = $self->SUPER::android_xml($depth, $fields, $num_tags + scalar(@f), $attributes);
    my $prefix = '  ' x $depth;

    foreach my $f ( @f ) {
        next unless $fields->{all} or $fields->{$f};

        my $method = $f;
	my $value;
        if ($self->can($method)
            or ( ( $method = 'get_' . $method )
                and $self->can($method) )
          ) {
            if ( $f eq 'speech_log' ) {
                my @a = $self->$method;
                $value = \@a;
            } elsif ( $f eq 'print_log' ) {
                my @a = $self->$method;
                $value = \@a;
	    } else {
		$value = $self->$method;
		$value = encode_entities( $value, "\200-\377&<>" );
	    }
	} elsif (exists $self->{$f}) {
	    $value = $self->{$f};
	    if ( ref $value ne 'REF' ) {
		$value = encode_entities( $value, "\200-\377&<>" );
	    }
	}

	# Add alias to change display name on android list
	if ($f eq 'toggle_item') {
	    $attributes->{alias} = "Toggle Item";
	}

	if ( ref $value eq 'Generic_Item') {
	    if ($value->can('android_xml')) {
		my $attributes = {};
		$attributes->{type} = ref $value;
		$xml_objects .= $value->android_xml($depth+1, $fields, 0, $attributes);
	    } else {
		$xml_objects .= $prefix . "<object>\n";
	    }
	    $xml_objects .= $prefix . "</object>\n";
	}

        elsif ( ref $value eq 'ARRAY' ) {
	    $attributes->{type} = "arrayList";
	    $xml_objects .= $self->android_xml_tag ( $prefix, $f, $attributes );
	    $prefix = '  ' x ($depth+1);
	    foreach (@{$value}) {
		$_ = 'undef' unless defined $_;
		$value = $_;
		$value = encode_entities( $value, "\200-\377&<>" );
		$xml_objects .= $prefix . "  <value>$value</value>\n";
	    }
	    $prefix = '  ' x $depth;
	    $xml_objects .= $prefix . "</$f>\n";
        }

	elsif ( ref $value eq 'HASH' ) {
	    $attributes->{type} = "hashList";
	    $xml_objects .= $self->android_xml_tag ( $prefix, $f, $attributes );
	    $prefix = '  ' x ($depth+1);
	    foreach my $key (keys %{$value}) {
		my $val = $value->{$key};
		$key = encode_entities( $key, "\200-\377&<>" );
		$key =~ s/ /_/g;
		$key =~ s/[\[\]]/_/g;
		$val = encode_entities( $val, "\200-\377&<>" );
		$xml_objects .= $prefix . "<$key>$val</$key>\n";
	    }
	    $prefix = '  ' x $depth;
	    $xml_objects .= $prefix . "</$f>\n";
	}

	else {
	    $xml_objects .= $self->android_xml_tag ( $prefix, $f, $attributes );
	}
    }
    return $xml_objects;
}

1;
