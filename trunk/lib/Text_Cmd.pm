use strict;

package Text_Cmd;

my ($hooks_added, @list_objects);

@Text_Cmd::ISA = ('Generic_Item');

sub new {
    my ($class, $text) = @_;
    my $self = {};
    $$self{state} = '';
    $$self{text} = $text;
    bless $self, $class;
    &::Reload_pre_add_hook(\&Text_Cmd::reload_reset, 1) unless $hooks_added++;
    push @list_objects, $self;
    return $self;
}

sub reload_reset {
    undef @list_objects;
}

sub set_matches {
    my ($text, $set_by, $no_log, $respond) = @_;
    $set_by  = 'unknown' unless $set_by;
    my @list_matches;
    for my $object (@list_objects) {
        my ($state) = &check_match($object, $text);
        next unless defined $state;
        set $object $state, $set_by, $respond;
        &main::print_log("Text_Cmd match: '$text' matches $object->{object_name} text '$object->{text}'") unless $no_log;
        push @list_matches, $object;
    }
    return @list_matches;
}

sub check_match {
    my ($self, $text) = @_;
    my $filter = $$self{text};
#   print "Testing $text against $filter\n";
    $text =~ s/^ *//;           # Drop leading         
    $text =~ s/ *$//;           # Drop trailing
    if ($text =~ /^$filter$/i) {
        my $state = $1;
        $state .= "|$2" if defined $2;
        $state .= "|$3" if defined $3;
        $state .= "|$4" if defined $4;
        $state = 1 unless defined $state;
#       print "Matched with $1,$2,$3. s=$state\n";
        return $state;
    }
    return undef;
}


#
# $Log: Text_Cmd.pm,v $
# Revision 1.3  2004/02/01 19:24:35  winter
#  - 2.87 release
#
#

1;
