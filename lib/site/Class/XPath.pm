package Class::XPath;

use 5.006;
use strict;
use warnings;

our $VERSION = '1.4';
use Carp qw(croak);
use constant DEBUG => 0;

# regex fragment for names in XPath expressions
our $NAME = qr/[\w:]+/;

# declare prototypes
sub foreach_node (&@);

# handle request to build methods from 'use Class::XPath'.
sub import {
    my $pkg = shift;
    return unless @_;
    my $target = (caller())[0];
    # hand off to add_methods
    $pkg->add_methods(@_, target => $target, from_import => 1);
}

{
    # setup lists of required params
    my %required = map { ($_,1) } 
      qw(get_name get_parent get_children 
         get_attr_names get_attr_value get_content
         get_root call_match call_xpath);
    
# add the xpath and match methods to 
sub add_methods {
    my $pkg  = shift;
    my %args = (call_match => 'match',
                call_xpath => 'xpath',
                @_);
    my $from_import = delete $args{from_import};
    my $target      = delete $args{target};
    croak("Missing 'target' parameter to ${pkg}->add_methods()")
      unless defined $target;

    # check args
    local $_;
    for (keys %args) {
        croak("Unrecognized parameter '$_' " . 
              ($from_import ? " on 'use $pkg' line. " :
                              "passed to ${pkg}->add_methods()"))
          unless $required{$_};
    }
    for (keys %required) {
        croak("Missing required parameter '$_' " . 
              ($from_import ? " on 'use $pkg' line. " :
                              "in call to ${pkg}->add_methods()"))
          unless exists $args{$_};
    }

    # translate get_* method names to sub-refs
    for (grep { /^get_/ } keys %args) {
        next if ref $args{$_} and ref $args{$_} eq 'CODE';
        $args{$_} = eval "sub { shift->$args{$_}(\@_) };";
        croak("Unable to compile sub for '$_' : $@") if $@;
    }

    # install code into requested names to call real match/xpath with
    # supplied %args
    {
        no strict 'refs';
        *{"${target}::$args{call_match}"} = 
          sub { $pkg->match($_[0], \%args, $_[1]) };
        *{"${target}::$args{call_xpath}"} = 
          sub { $pkg->xpath($_[0], \%args) }
    }
}}

sub match {
    my ($pkg, $self, $args, $xpath) = @_;
    my ($get_root, $get_parent, $get_children, $get_name) = 
      @{$args}{qw(get_root get_parent get_children get_name)};

    croak("Bad call to $args->{call_match}: missing xpath argument.")
      unless defined $xpath;
    
    print STDERR "match('$xpath') called.\n" if DEBUG;

    # / is the root.  This should probably work as part of the
    # algorithm, but it doesn't.
    return $get_root->($self) if $xpath eq '/';
        
    # . is self.  This should also work as part of the algorithm,
    # but it doesn't.
    return $self if $xpath eq '.';

    # break up an incoming xpath into a set of @patterns to match
    # against a list of @target elements
    my (@patterns, @targets);    
        
    # target aquisition
    if ($xpath =~ m!^//(.*)$!) {
        $xpath = $1;
        # this is a match-anywhere pattern, which should be tried on
        # all nodes
        foreach_node { push(@targets, $_) } $get_root->($self), $get_children;
    } elsif ($xpath =~ m!^/(.*)$!) {
        $xpath = $1;
        # this match starts at the root
        @targets = ($get_root->($self));
    } elsif ($xpath =~ m!^\.\./(.*)$!) {
        $xpath = $1;
        # this match starts at the parent
        @targets = ($get_parent->($self));
    } elsif ($xpath =~ m!^\./(.*)$!) {
        $xpath = $1;
        @targets = ($self);
    } else {
        # this match starts here
        @targets = ($self);
    }
        
    # pattern breakdown
    my @parts = split('/', $xpath);
    my $count = 0;
    for (@parts) {
        $count++;
        if (/^$NAME$/) {
            # it's a straight name match
            push(@patterns, { name => $_ });
        } elsif (/^($NAME)\[(-?\d+)\]$/o) {
            # it's an indexed name
            push(@patterns, { name => $1, index => $2 });
        } elsif (/^($NAME)\[\@($NAME)\s*=\s*"([^"]+)"\]$/o or 
                 /^($NAME)\[\@($NAME)\s*=\s*'([^']+)'\]$/o) {
            # it's a string attribute match
            push(@patterns, { name => $1, attr => $2, value => $3 });
        } elsif (/^($NAME)\[\@($NAME)\s*(=|>|<|<=|>=|!=)\s*(\d+)\]$/o) {
            # it's a numeric attribute match
            push(@patterns, { name => $1, attr => $2, op => $3, value => $4 });
        } elsif (/^($NAME)\[($NAME|\.)\s*=\s*"([^"]+)"\]$/o or 
                 /^($NAME)\[($NAME|\.)\s*=\s*'([^']+)'\]$/o) {
            # it's a string child match
            push(@patterns, { name => $1, child => $2, value => $3 });
        } elsif (/^($NAME)\[($NAME|\.)\s*(=|>|<|<=|>=|!=)\s*(\d+)\]$/) {
            # it's a numeric child match
            push(@patterns, { name => $1, child => $2, op => $3, value => $4 });
        } elsif (/^\@($NAME)$/) {
            # it's an attribute name
            push(@patterns, { attr => $1 });

            # it better be last
            croak("Bad call to $args->{call_match}: '$xpath' contains an attribute selector in the middle of the expression.")
              if $count != @parts;
        } else {
            # unrecognized token
            croak("Bad call to $args->{call_match}: '$xpath' contains unknown token '$_'");
        }
    }

    croak("Bad call to $args->{call_match}: '$xpath' contains no search tokens.")
      unless @patterns;
    
    # apply the patterns to all available targets and collect results
    my @results = map { $pkg->_do_match($_, $args, @patterns) } @targets;
    
    return @results;
}
      
# the underlying match engine.  this takes a list of patterns and
# applies them to child elements
sub _do_match {    
    my ($pkg, $self, $args, @patterns) = @_;
    my ($get_parent, $get_children, $get_name, $get_attr_value, $get_attr_names, $get_content) = 
      @{$args}{qw(get_parent get_children get_name get_attr_value get_attr_names get_content)};
    local $_;

    print STDERR "_do_match(" . $get_name->($self) . " => " . 
      join(', ', map { '{' . join(',', %$_) . '}' } @patterns) . 
        ") called.\n" 
          if DEBUG;

    # get pattern to apply to direct descendants
    my $pat = shift @patterns;

    # find matches and put in @results
    my @results;
    my @kids;

    { no warnings 'uninitialized';
        @kids = grep { $get_name->($_) eq $pat->{name} } $get_children->($self);
    }

    if (defined $pat->{index}) {
        # get a child by index
        push @results, $kids[$pat->{index}]
          if (abs($pat->{index}) <= $#kids);
    } elsif (defined $pat->{attr}) {
        if (defined $pat->{name}) {
        # default op is 'eq' for string matching
        my $op = $pat->{op} || 'eq';

        # do attribute matching
        foreach my $kid (@kids) {
            my $value = $get_attr_value->($kid, $pat->{attr});
            push(@results, $kid)
              if ($op eq 'eq' and $value eq $pat->{value}) or 
                 ($op eq '='  and $value == $pat->{value}) or 
                 ($op eq '!=' and $value != $pat->{value}) or 
                 ($op eq '>'  and $value >  $pat->{value}) or 
                 ($op eq '<'  and $value <  $pat->{value}) or 
                 ($op eq '>=' and $value >= $pat->{value}) or 
                 ($op eq '<=' and $value <= $pat->{value});                 
        }
        }
        else {
            my $attr = $pat->{attr};
            push(@results, $get_attr_value->($self, $attr))
            if grep { $_ eq $attr } $get_attr_names->($self);
        }
    } elsif (defined $pat->{child}) {
        croak("Can't process child pattern without name")
        unless defined $pat->{name};
        # default op is 'eq' for string matching
        my $op = $pat->{op} || 'eq';
        # do attribute matching
        foreach my $kid (@kids) {
            foreach ( 
                $pat->{child} eq "." ? $kid
                : grep {$get_name->($_) eq $pat->{child}} $get_children->($kid)
            ) {
                my $value;
                foreach_node { 
                    my $txt = $get_content->($_);
                    $value .= $txt if defined $txt;
                } $_, $get_children;
                next unless defined $value;
                push(@results, $kid)
                  if ($op eq 'eq' and $value eq $pat->{value}) or 
                     ($op eq '='  and $value == $pat->{value}) or 
                     ($op eq '!=' and $value != $pat->{value}) or 
                     ($op eq '>'  and $value >  $pat->{value}) or 
                     ($op eq '<'  and $value <  $pat->{value}) or 
                     ($op eq '>=' and $value >= $pat->{value}) or 
                     ($op eq '<=' and $value <= $pat->{value});
            }
        }
    } else {
        push @results, @kids;
    }

    # all done?
    return @results unless @patterns;

    # apply remaining patterns on matching kids
    return map { $pkg->_do_match($_, $args, @patterns) } @results;
}


sub xpath {
    my ($pkg, $self, $args) = @_;
    my ($get_parent, $get_children, $get_name) = 
      @{$args}{qw(get_parent get_children get_name)};

    my $parent = $get_parent->($self);
    return '/' unless defined $parent; # root's xpath is /
    
    # get order within same-named nodes in the parent
    my $name = $get_name->($self);
    my $count = 0;
    for my $kid ($get_children->($parent)) {
        last if $kid == $self;
        $count++ if $get_name->($kid) eq $name;
    }

    # construct xpath using parent's xpath and our name and count
    return $pkg->xpath($parent, $args) . 
      ($get_parent->($parent) ? '/' : '') .
        $name . '[' . $count . ']';
}


# does a depth first traversal in a stack
sub foreach_node (&@) {
    my ($code, $node, $get_children) = @_;
    my @stack = ($node);
    while (@stack) {
        local $_ = shift(@stack);
        $code->();
        push(@stack, $get_children->($_));
    }
}

1;
__END__

=head1 NAME

Class::XPath - adds xpath matching to object trees

=head1 SYNOPSIS

In your node class, use Class::XPath:

  # generate xpath() and match() using Class::XPath
  use Class::XPath

     get_name => 'name',        # get the node name with the 'name' method

     get_parent => 'parent',    # get parent with the 'parent' method

     get_root   => \&get_root,  # call get_root($node) to get the root

     get_children => 'kids',    # get children with the 'kids' method

     get_attr_names => 'param', # get names and values of attributes
     get_attr_value => 'param', # from param
     
     get_content    => 'data',  # get content from the 'data' method
     
     ;

Now your objects support XPath-esque matching:

  # find all pages, anywhere in the tree
  @nodes = $node->match('//page');

  # returns an XPath like "/page[1]/paragraph[2]"
  $xpath = $node->xpath();

=head1 DESCRIPTION

This module adds XPath-style matching to your object trees.  This
means that you can find nodes using an XPath-esque query with
C<match()> from anywhere in the tree.  Also, the C<xpath()> method
returns a unique path to a given node which can be used as an
identifier.

To use this module you must already have an OO implementation of a
tree.  The tree must be a true tree - all nodes have a single parent
and the tree must have a single root node.  Also, the order of
children within a node must be stable.

B<NOTE:> This module is not yet a complete XPath implementation.  Over
time I expect the subset of XPath supported to grow.  See the SYNTAX
documentation for details on the current level of support.

=head1 USAGE

This module is used by providing it with information about how your
class works.  Class::XPath uses this information to build the
C<match()> and C<xpath()> methods for your class.  The parameters
passed to 'use Class::XPath' may be set with strings, indicating
method names, or subroutine references.  They are:

=over

=item get_name (required)

Returns the name of this node.  This will be used as the element name
when evaluating an XPath match.  The value returned must matches
/^[\w:]+$/.

=item get_parent (required)

Returns the parent of this node.  The root node must return undef from
the get_parent method.

=item get_children (required)

Returns a list of child nodes, in order.

=item get_attr_names (required)

Returns a list of available attribute names.  The values returned must
match /^[\w:]+$/).

=item get_attr_value (required)

Called with a single parameter, the name of the attribute.  Returns
the value associated with that attribute.  The value returned must be
C<undef> if no value exists for the attribute.

=item get_content (required)

Returns the contents of the node.  In XML this is text between start
and end tags.

=item get_root (required)

Returns the root node of this tree.

=item call_match (optional)

Set this to the name of the C<match()> method to generate.  Defaults
to 'match'.

=item call_xpath (optional)

Set this to the name of the C<xpath()> method to generate.  Defaults
to 'xpath'.

=back

=head2 ALTERNATE USAGE

If you're using someone else's OO tree module, and you don't want to
subclass it, you can still use Class::XPath to add XPath matching to
it.  This is done by calling C<Class::XPath->add_methods()> with all
the options usually passed to C<use> and one extra one, C<target>.
For example, to add xpath() and match() to HTML::Element (the node
class for HTML::TreeBuilder):

  # add Class::XPath routines to HTML::Element
  Class::XPath->add_methods(target         => 'HTML::Element',
                            get_parent     => 'parent',
                            get_name       => 'tag',
                            get_attr_names => 
                              sub { my %attr = shift->all_external_attr;
                                    return keys %attr; },
                            get_attr_value => 
                              sub { my %attr = shift->all_external_attr;
                                    return $attr{$_[0]}; },
                            get_children   =>
                              sub { grep { ref $_ } shift->content_list },
                            get_content    =>
                              sub { grep { not ref $_ } shift->content_list },
                            get_root       => 
                              sub { local $_=shift; 
                                    while($_->parent) { $_ = $_->parent }
                                    return $_; });


Now you can load up an HTML file and do XPath matching on it:

  my $root = HTML::TreeBuilder->new;
  $root->parse_file("foo.html");1

  # get a list of all paragraphs
  my @paragraphs = $root->match('//p');

  # get the title element
  my ($title) = $root->match('/head/title');

=head1 GENERATED METHODS

This module generates two public methods for your class:

=over

=item C<< @results = $node->match('/xpath/expression') >>

This method performs an XPath match against the tree to which this
node belongs.  See the SYNTAX documentation for the range of supported
expressions.  The return value is either a list of node objects, a list
of values (when retrieving specific attributes) or an empty list if no
matches could be found.  If your XPath expression cannot be parsed then
the method will die.

You can change the name of this method with the 'call_match' option
described above.

=item C<< $xpath = $node->xpath() >>

Get an xpath to uniquely identify this node.  Can be used with match()
to find the element later.  The xpath returned is guaranteed to be
unqiue within the element tree.  For example, the third node named
"paragraph" inside node named "page" has the xpath
"/page[1]/paragraph[2]".

You can change the name of this method with the 'call_xpath' option
described above.

=back

=head1 SYNTAX

This module supports a small subset of XPath at the moment.  Here is a
list of the type of expressions it knows about:

=over

=item .

Selects and returns the current node.

=item name

=item ./name

Selects a list of nodes called 'name' in the tree below the current
node.

=item /name

Selects a list of nodes called 'name' directly below the root of the
tree.

=item //name

Selects all nodes with a matching name, anywhere in the tree.

=item parent/child/grandchild

Selects a list of grandchildren for all children of all parents.

=item parent[1]/child[2]

Selects a single child by indexing into the children lists.

=item parent[-1]/child[0]

Selects the first child of the last parent.  In the real XPath they
spell this 'parent[last()]/child[0]' but supporting the Perl syntax is
practically free here.  Eventually I'll support the XPath style too.

=item ../child[2]

Selects the second child from the parent of the current node.
Currently .. only works at the start of an XPath, mostly because I
can't imagine using it anywhere else.

=item child[@id=10]

Selects the child node with an 'id' attribute of 10.

=item child[@id>10]

Selects all the child nodes with an 'id' attribute greater than 10.
Other supported operators are '<', '<=', '>=' and '!='.

=item child[@category="sports"]

Selects the child with an 'category' attribute of "sports".  The value
must be a quoted string (single or double) and no escaping is allowed.

=item child[title="Hello World"]

Selects the child with a 'title' child element whose content is "Hello World".
The value must be a quoted string (single or double) and no escaping is allowed.
e.g.

 <child>
   <title>Hello World</title>
 </child>

=item //title[.="Hello World"]

Selects all 'title' elements whose content is "Hello World".

=item child/@attr

Returns the list of values for all attributes "attr" within each child.

=item //@attr

Returns the list of values for all attributes "attr" within each node.

=back

B<NOTE:> this module has no support for Unicode.  If this is a problem
for you please consider sending me a patch.  I'm certain that I don't
know enough about Unicode to do it right myself.

=head1 BUGS

I know of no bugs in this module.  If you find one, please file a bug
report at:

  http://rt.cpan.org

Alternately you can email me directly at sam@tregar.com.  Please
include the version of the module and a complete test case that
demonstrates the bug.

=head1 TODO

Planned future work:

=over

=item *

Support more of XPath!

=item *

Do more to detect broken get_* functions.  Maybe use Carp::Assert and
a special mode for use during development?

=back

=head1 ACKNOWLEDGMENTS

I would like to thank the creators of XPath for their fine work and
the W3C for supporting them in their efforts.

The following people have sent me patches and/or suggestions:

  Tim Peoples
  Mark Addison
  Timothy Appnel

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2002 Sam Tregar

This program is free software; you can redistribute it and/or modify
it under the same terms as Perl 5 itself.

=head1 AUTHOR

Sam Tregar <sam@tregar.com>

=head1 SEE ALSO

The XPath W3C Recommendation: 

  http://www.w3.org/TR/xpath

=cut
