
# Position=99            Load after all other members are done, so get_authority works ok

# 27823 and 46630

# Add help stuff

sub tellme_menu {
    my ($state, $result) = split ',', $_[0];
    if ($state eq '') {
        return vxml_page text => 'Welcome to Mister House', wav => 'tellme_welcome.wav',
               goto => "SET:&tellme_menu(main)";
    }
    elsif ($state eq 'main') {
        my @grammar = sort keys %tellme_objects;
        return vxml_page text => 'Speak a category', response => '',
               grammar => \@grammar, goto => "SET:&tellme_menu(cat,{session.result})";
    }
    elsif ($state eq 'cat') {
        my ($grammar, $help) = &tellme_menu_cmds($result);
        my $help_cnt = @{$help};
        return vxml_page text => "Speak a $result command", response => '',
               help => "Speak one of the following $help_cnt commands: " . join('.  ', @{$help}),
               grammar => $grammar, goto => "SET:&tellme_menu(cmd,{session.result})";
    }
    elsif ($state eq 'cmd') {
        my $text = $result;
        $text =~ s/_/ /g;       # Make is speakable 
        return vxml_page text => "Running $text", goto => "RUN:&vxml_last_response?$result";
    }
    else {
        return vxml_page text => 'Come again soon', goto => "SET:&tellme_menu(main)";
    }
}

sub tellme_menu_categories {
                                # Create a list of Voice Command Categories
    my ($vxml, $i);
    for my $category (sort keys %tellme_objects) {
        my $dtmf = "dtmf-$i" if ++$i < 10;
        $vxml .= qq|[$dtmf $category] {<option "$category">}\n|;
    }
    return $vxml;
}

sub tellme_menu_cmds {
    my ($category) = @_;
    my (@grammer, @help);
    for my $object (@{$tellme_objects{$category}}) {
        my $first = 1;
        for my $text (@{$object->{texts}}) {
            next unless $text;
            push @grammer, $text;
            push @help,    $text if $first;
            $first = 0;
        }
    }
    return \@grammer, \@help;
}


                                # Create list of tellme authorized objects
my (%tellme_objects);
if ($Reload) {
    for my $category (&list_code_webnames) {
        for my $object_name (sort &list_objects_by_webname($category)) {
            my $object = &get_object_by_name($object_name);
            next unless $object and $object->isa('Voice_Cmd');
                                # for now, only list set_authority('anyone') commands
            my $authority = $object->get_authority;
            next unless $authority =~ /anyone/;
            push @{$tellme_objects{lc $category}}, $object;
        }
    }
}    
