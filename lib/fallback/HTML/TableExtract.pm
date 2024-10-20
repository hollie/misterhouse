package HTML::TableExtract;

# This package extracts tables from HTML. Tables of interest may be
# specified using header information, depth, order in a depth, table tag
# attributes, or some combination of the four. See the POD for more
# information.
#
# Author: Matthew P. Sisk. See the POD for copyright information.

use strict;
use Carp;

use vars qw($VERSION @ISA);

$VERSION = '2.10';

use HTML::Parser;
@ISA = qw(HTML::Parser);

use HTML::Entities;

# trickery for subclassing from HTML::TreeBuilder rather than the
# default HTML::Parser. (use HTML::TableExtract qw(tree);) Also installs
# a mode constant TREE().

BEGIN { *TREE = sub { 0 } }

sub import {
    my $class = shift;
    no warnings;
    *TREE = @_ ? sub { 1 } : sub { 0 };
    return unless @_;
    my $mode = shift;
    croak "Unknown mode '$mode'\n" unless $mode eq 'tree';
    eval "use HTML::TreeBuilder";
    croak "Problem loading HTML::TreeBuilder : $@\n" if $@;
    eval "use HTML::ElementTable 1.17";
    croak "problem loading HTML::ElementTable : $@\n" if $@;
    @ISA = qw(HTML::TreeBuilder);
    $class;
}

# Backwards compatibility for deprecated methods
*table_state = *table;
*table_states = *tables;
*first_table_state_found = *first_table_found;

###

my %Defaults = (
                headers             => undef,
                depth               => undef,
                count               => undef,
                attribs             => undef,
                subtables           => undef,
                gridmap             => 1,
                decode              => 1,
                automap             => 1,
                slice_columns       => 1,
                keep_headers        => 0,
                br_translate        => 1,
                error_handle        => \*STDOUT,
                debug               => 0,
                keep_html           => 0,
                strip_html_on_match => 1,
               );
my $Dpat = join('|', sort keys %Defaults);

### Constructor

sub new {
  my $that = shift;
  my $class = ref($that) || $that;

  my(%pass, %parms, $k, $v);
  while (($k,$v) = splice(@_, 0, 2)) {
    if ($k eq 'headers') {
      ref $v eq 'ARRAY'
        or croak "Param '$k'  must be passed in ref to array\n";
      $parms{$k} = $v;
    }
    elsif ($k =~ /^$Dpat$/) {
      $parms{$k} = $v;
    }
    else {
      $pass{$k} = $v;
    }
  }

  my $self = $class->SUPER::new(%pass);
  bless $self, $class;
  foreach (keys %parms, keys %Defaults) {
    $self->{$_} = exists $parms{$_} && defined $parms{$_} ?
      $parms{$_} : $Defaults{$_};
  }
  if ($self->{headers}) {
    $self->_emsg("TE here, headers: ", join(',', @{$self->{headers}}), "\n")
      if $self->{debug};
    $self->{gridmap} = 1;
  }

  # Initialize counts and containers
  $self->_reset_state;

  $self;
}

### HTML::Parser overrides

sub start {
  my $self = shift;
  my @res;

  @res = $self->SUPER::start(@_) if TREE();

  # Create a new table state if entering a table.
  if ($_[0] eq 'table') {
    my $ts = $self->_enter_table(@_);
    $ts->tree($res[0]) if @res;
  }

  # Rows and cells are next.
  if ($self->{_in_a_table}) {
    my $ts = $self->current_table;
    my $skiptag = 0;
    if ($_[0] eq 'tr') {
      $ts->_enter_row;
      ++$skiptag;
    }
    elsif ($_[0] eq 'td' || $_[0] eq 'th') {
      $ts->_enter_cell(@_);
      my %attrs = ref $_[1] ? %{$_[1]} : {};
      my $rspan = $attrs{rowspan} || 1;
      my $cspan = $attrs{colspan} || 1;
      $ts->_rasterizer->($ts->row_count, $rspan, $cspan);
      $ts->_anchor_item(@res);
      ++$skiptag;
    }
    if ($self->{keep_html} && !$skiptag) {
      $self->text($_[3]);
    }
  }

  # Replace <br> with newlines if requested
  if ($_[0] eq 'br' && $self->{br_translate} && !$self->{keep_html}) {
    $self->text("\n");
  }

  @res;
} # end start

sub end {
  my $self = shift;
  my @res = $self->SUPER::end(@_) if TREE();
  if ($self->{_in_a_table}) {
    my $ts = $self->current_table;
    if ($_[0] eq 'td' || $_[0] eq 'th') {
      $ts->_exit_cell;
    }
    elsif ($_[0] eq 'tr') {
      $ts->_exit_row;
    }
    elsif ($_[0] eq 'table') {
      $self->_exit_table;
    }
    unless (TREE()) {
      $self->text($_[1]) if $self->{keep_html} && $ts->{in_cell};
    }
  }
  @res;
}

sub text {
  my $self = shift;
  my @res = $self->SUPER::text(@_) if TREE();
  if ($self->{_in_a_table} && !TREE()) {
    my $ts = $self->current_table;
    return unless $ts->{in_cell};
    if ($self->{decode} && !$self->{keep_html}) {
      $ts->_add_text(decode_entities($_[0]));
    }
    else {
      $ts->_add_text($_[0]);
    }
  }
  @res;
}

### End HTML::Parser overrides

### Report Methods

sub depths {
  # Return all depths where valid tables were located.
  my $self = shift;
  return () unless ref $self->{_tables};
  sort { $a <=> $b } keys %{$self->{_tables}};
}

sub counts {
  # Given a depth, return the counts of all valid tables found therein.
  my($self, $depth) = @_;
  defined $depth or croak "Depth required\n";
  return () unless exists $self->{_tables}{$depth};
  sort { $a <=> $b } keys %{$self->{_tables}{$depth}};
}

sub table {
  # Return the table state for a particular depth and count
  my($self, $depth, $count) = @_;
  defined $depth or croak "Depth required\n";
  defined $count or croak "Count required\n";
  if (! $self->{_tables}{$depth} || ! $self->{_tables}{$depth}{$count}) {
    return undef;
  }
  $self->{_tables}{$depth}{$count};
}

sub first_table_found {
  my $self = shift;
  ref $self->{_ts_sequential}[0] ? $self->{_ts_sequential}[0] : undef;
}

sub rows { shift->first_table_found->rows(@_) }

sub tables {
  # Return all valid table records found, in the order that they
  # were seen.
  my $self = shift;
  while ($self->{_in_a_table}) {
    my $ts = $self->current_table;
    $self->_emsg("Mangled HTML in table ($ts->{depth},$ts->{count}), inferring closing table tag.\n")
        if $self->{debug};
    $self->_exit_table;
  }
  @{$self->{_ts_sequential}};
}

# in tree mode, we already are an HTML::TreeBuilder, which is an
# HTML::Element structure after parsing...but we provide this for
# consistency with the table object method for accessing the tree
# structures.

sub tree { shift }

sub tables_report {
  # Print out a summary of extracted tables, including depth/count
  my $self = shift;
  my $str;
  foreach my $ts ($self->tables) {
    $str .= $ts->report(@_);
  }
  $str;
}

sub tables_dump {
  my $self = shift;
  $self->_emsg($self->tables_report(@_));
}

# for testing/debugging
sub _attribute_purge {
  my $self = shift;
  foreach (keys %Defaults) {
    delete $self->{$_};
  }
}

### Runtime

sub _enter_table {
  my($self, @args) = @_;

  ++$self->{_cdepth};
  ++$self->{_in_a_table};

  my $depth = $self->{_cdepth};

  # Table tag attributes, if present
  my $attribs = $args[1] || {};

  # Table states can come and go on the stack...here we retrieve the
  # table state for the table surrounding the current table tag (parent
  # table state). If the current table tag belongs to a top level table,
  # then this will be undef.
  my $pts = $self->current_table;

  # Counts are tracked for each depth.
  my $counts = $self->{_counts};
  $counts->[$depth] = -1 unless defined $counts->[$depth];
  ++$counts->[$depth];
  my $count = $counts->[$depth];

  $self->_emsg("TABLE: cdepth $depth, ccount $count, it: $self->{_in_a_table}\n")
    if $self->{debug} >= 2;

  # Umbrella status means that this current table and all of its
  # descendant tables will be harvested.
  my $umbrella = 0;
  if (! defined $self->{depth} && ! defined $self->{count} &&
      ! $self->{attribs}       && ! $self->{headers}) {
    ++$umbrella;
  }

  # Basic parameters for the soon-to-be-created table state.
  my %tsparms = (
                 depth               => $depth,
                 count               => $count,
                 attribs             => $attribs,
                 umbrella            => $umbrella,
                 automap             => $self->{automap},
                 slice_columns       => $self->{slice_columns},
                 keep_headers        => $self->{keep_headers},
                 counts              => $counts,
                 error_handle        => $self->{error_handle},
                 debug               => $self->{debug},
                 keep_html           => $self->{keep_html},
                 strip_html_on_match => $self->{strip_html_on_match},
                 parent_table        => $pts,
                );

  # Target constraints. There is no point in passing any of these along
  # if we are under an umbrella. Notice that with table states, "depth"
  # and "count" are absolute coordinates recording where this table was
  # created, whereas "tdepth" and "tcount" are the target constraints.
  # Headers have "absolute" meaning, therefore are passed by the
  # same name.
  if (!$umbrella) {
    $tsparms{tdepth}   = $self->{depth};
    $tsparms{tcount}   = $self->{count};
    $tsparms{tattribs} = $self->{attribs};
    $tsparms{headers}  = $self->{headers};
  }

  # Abracadabra
  my $ts = HTML::TableExtract::Table->new(%tsparms);

  # Push the newly created and configured table state onto the stack.
  # This will now be the current_table().
  push(@{$self->{_tablestack}}, $ts);

  $ts;
}

sub _exit_table {
  my $self = shift;
  my $ts = $self->current_table;

  # Last ditch fix for HTML mangle
  if ($ts->{in_cell}) {
    $self->_emsg("Mangled HTML in table ($self->{depth},$self->{count}), forcing exit of cell ($ts->{rc},$ts->{cc}) due to table exit\n") if $self->{debug};
    $ts->_exit_cell;
  }
  if ($ts->{in_row}) {
    $self->_emsg("Mangled HTML in table ($self->{depth},$self->{count}), forcing exit of row $ts->{rc} due to table exit\n") if $self->{debug};
    $ts->_exit_row;
  }

  # transform from tree to grid using our rasterized template
  $ts->_grid_map();

  $self->_capture_table($ts) if $ts->_check_triggers;

  # Restore last table state
  pop(@{$self->{_tablestack}});
  --$self->{_in_a_table};
  my $lts = $self->current_table;
  if (ref $lts) {
    $self->{_cdepth} = $lts->{depth};
  }
  else {
    # Back to the top level
    $self->{_cdepth} = -1;
  }
  $self->_emsg("LEAVE: cdepth: $self->{_cdepth}, ccount: $ts->{count}, it: $self->{_in_a_table}\n")
    if $self->{debug} >= 2;
}

sub _capture_table {
  my($self, $ts, $type) = @_;
  croak "Table state ref required\n" unless ref $ts;
  if ($self->{debug} >= 2) {
    my $msg = "Captured table (" . $ts->depth . ',' . $ts->count . ")";
    $msg .= " ($type)" if $type;
    $msg .= "\n";
    $self->_emsg($msg);
  }
  $ts->tree(HTML::ElementTable->new_from_tree($ts->tree)) if TREE();
  if ($self->{subtables}) {
    foreach my $child (@{$ts->{children}}) {
      next if $child->{captured};
      $self->_capture_table($child, 'subtable');
      $child->{slice_columns} = 0;
      $child->{keep_headers}  = 1;
      $child->{headers} = '';
    }
  }
  $ts->{captured} = 1;
  $self->{_tables}{$ts->{depth}}{$ts->{count}} = $ts;
  push(@{$self->{_ts_sequential}}, $ts);
}

sub current_table {
  my $self = shift;
  $self->{_tablestack}[$#{$self->{_tablestack}}];
}

sub _reset_state {
  my $self = shift;
  $self->{_cdepth}        = -1;
  $self->{_tablestack}    = [];
  $self->{_tables}        = {};
  $self->{_ts_sequential} = [];
  $self->{_counts}        = [];
  $self->{_in_a_table}    = 0;
}

sub _emsg {
  my $self = shift;
  my $fh = $self->{error_handle};
  return unless defined $_[0];
  print $fh @_;
}

##########

{

  package HTML::TableExtract::Table;

  use strict;
  use Carp;

  *TREE = *HTML::TableExtract::TREE;

  sub new {
    my $that  = shift;
    my $class = ref($that) || $that;
    # Note:
    #   - 'depth' and 'count' are where this table were found.
    #   - 'tdepth' and 'tcount' are target constraints on which to trigger.
    #   - 'headers' represent a target constraint, location independent.
    #   - 'attribs' represent target table tag constraints
    my $self  = {
                 umbrella    => 0,
                 in_row      => 0,
                 in_cell     => 0,
                 rc          => -1,
                 cc          => -1,
                 grid        => [],
                 translation => [],
                 hrow        => [],
                 order       => [],
                 children    => [],
                 captured    => 0,
                 debug       => 0,
                };

    $self->{_rastamon} = HTML::TableExtract::Rasterize->make_rasterizer();
    bless $self, $class;

    my %parms = @_;

    # Depth and Count -- this is the absolute address of the table.
    croak "Absolute depth required\n" unless defined $parms{depth};
    croak "Count required\n"          unless defined $parms{count};
    croak "Counts required\n"         unless defined $parms{counts};

    foreach (keys %parms) {
      $self->{$_} = $parms{$_};
    }

    # Register lineage
    my $pts = $self->{parent_table};
    $self->lineage($pts || undef);
    push(@{$pts->{children}}, $self) if ($pts);
    delete $self->{parent_table};

    $self;
  }

  sub _anchor_item {
    # anchor the reference to a cell in our grid -- in TREE mode this is
    # a reference to a data element, otherwise it's a reference to an
    # empty scalar in which we will collect our text.
    my($self, @res) = @_;
    my $row  = $self->{grid}[-1];
    my $item;
    if (@res && ref $res[0]) {
      $item = $res[0];
    }
    else {
      my $scalar_ref;
      $item = \$scalar_ref;
    }
    push(@$row, $item);
  }

  sub _gridalias {
    my $self = shift;
    $self->{gridalias} ||= $self->_make_gridalias;
  }

  sub _grid_map {
    # using our rasterized template, flesh out our captured items which
    # are still in 'tree' format
    my $self = shift;
    my $template = $self->_rasterizer->();
    my $grid = $self->{grid};
    # drop empty rows
    if ($self->{debug}) {
      foreach (0 .. $#$grid) {
        next if @{$grid->[$_]};
        $self->_emsg("Dropping empty row $_\n");
      }
    }
    @$grid = grep(@$_, @$grid);
    foreach my $r (0 .. $#$template) {
      my $row  = $grid->[$r];
      my $trow = $template->[$r];
      $self->_emsg("Flesh row $r ($#$row) to $#$trow\n") if $self->{debug} > 1;
      foreach my $c (0 .. $#$trow) {
        print STDERR $trow->[$c] ? '1' : '0' if $self->{debug} > 1;
        if ($trow->[$c]) {
          if (! defined $row->[$c]) {
            $row->[$c] = \undef;
          }
          next;
        }
        else {
          my $scalar;
          splice(@$row, $c, 0, \$scalar);
        }
      }
      print STDERR "\n" if $self->{debug} > 1;
      croak "row $r splice mismatch: $#$row vs $#$trow\n"
        unless $#$row == $#$trow;
    }
    $grid;
  }

  sub _make_gridalias {
    # our aliased grid will have references in masked cells to the same
    # cell that is covering it via spanning.
    my $self = shift;
    my $grid = $self->{grid};
    my $template = $self->_rasterizer->();
    my(@gridalias, @translation);
    $gridalias[$_] = [@{$grid->[$_]}] foreach 0 .. $#$grid;
    foreach my $r (0 .. $#gridalias) {
      my $row = $gridalias[$r];
      foreach my $c (0 .. $#$row) {
        my $tcell = $template->[$r][$c] || next;
        my($rspan, $cspan) = @$tcell;
        foreach my $rs (0 .. $rspan-1) {
          foreach my $cs (0 .. $cspan-1) {
            $gridalias[$r + $rs][$c + $cs] = $grid->[$r][$c];
            $translation[$r + $rs][$c + $cs] = "$r,$c";
          }
        }
      }
    }
    $self->{translation} = \@translation;
    $self->{gridalias}   = \@gridalias;
  }

  ### Constraint tests

  sub _check_dtrigger {
    # depth
    my $self = shift;
    return 1 unless defined $self->{tdepth};
    $self->{tdepth} == $self->{depth} ? 1 : 0;
  }

  sub _check_ctrigger {
    # count
    my $self = shift;
    return 1 unless defined $self->{tcount};
    return 1 if (exists $self->{counts}[$self->{depth}] &&
                 $self->{tcount} == $self->{counts}[$self->{depth}]);
    return 0;
  }

  sub _check_atrigger {
    # attributes
    my $self = shift;
    return 1 unless scalar keys %{$self->{tattribs}};
    return 0 unless scalar keys %{$self->{attribs}};
    my $a_hit = 1;
    foreach my $attrib (keys %{$self->{tattribs}}) {
      if (! defined $self->{attribs}{$attrib}) {
        $a_hit = 0; last;
      }
      if (! defined $self->{tattribs}{$attrib}) {
        # undefined, but existing, target attribs are wildcards
        next;
      }
      if ($self->{tattribs}{$attrib} ne $self->{attribs}{$attrib}) {
        $a_hit = 0; last;
      }
    }
    $self->_emsg("Matched attributes\n") if $self->{debug} > 3 && $a_hit;
    $a_hit;
  }

  sub _check_htrigger {
    # headers
    my $self = shift;
    return 1 if $self->{umbrella};
    return 1 unless $self->{headers};
    ROW: foreach my $r (0 .. $#{$self->{grid}}) {
      $self->_reset_hits;
      my $hpat = $self->_header_pattern;
      my @hits;
      foreach my $c (0 .. $#{$self->{grid}[$r]}) {
        my $ref = $self->{grid}[$r][$c];
        my $target = '';
        my $ref_type = ref $ref;
        if ($ref_type) {
          if ($ref_type eq 'SCALAR') {
            my $item = $$ref;
            if ($self->{keep_html} && $self->{strip_html_on_match}) {
              my $stripper = HTML::TableExtract::StripHTML->new;
              $target = $stripper->strip($item);
            }
            else {
              $target = $item;
            }
          }
          else  {
            if (($self->{keep_html} || TREE()) &&
                $self->{strip_html_on_match}) {
              $target = $ref->as_text;
            }
            else {
              $target = $ref->as_HTML;
            }
          }
        }
        $target = defined $target ? $target : '';
        $self->_emsg("attempt match on $target ($hpat): ")
          if $self->{debug} >= 5;
        if ($target =~ $hpat) {
          my $hit = $1;
          $self->_emsg("($hit)\n") if $self->{debug} >= 5;
          # Get rid of the header segment that matched so we can tell
          # when we're through with all header patterns.
          my $real_hit;
          foreach (sort _header_string_sort keys %{$self->{hits_left}}) {
            if ($hit =~ /$_/im) {
              delete $self->{hits_left}{$_};
              $real_hit = $_;
              $hpat = $self->_header_pattern;
              last;
            }
          }
          if (defined $real_hit) {
            if ($self->{debug} >= 4) {
              my $str = $ref_type eq 'SCALAR' ? $$ref : $ref->as_HTML;
              $self->_emsg("HIT on '$hit' ($real_hit) in $str ($r,$c)\n");
            }
            push(@hits, $hit);
            #
            $self->{hits}{$c} = $real_hit;
            push(@{$self->{order}}, $c);
            if (!%{$self->{hits_left}}) {
              # Successful header row match
              ++$self->{head_found};
              $self->{hrow_index} = $r;
              $self->{hrow} = $self->{grid}[$r];
              last ROW;
            }
          }
        }
        elsif ($self->{debug} >= 5) {
          $self->_emsg("0\n");
        }
      }
      if ($self->{debug} && @hits) {
        my $str = "Incomplete header match ";
        $str .= "(left: " . join(', ', sort keys %{$self->{hits_left}}) . ") ";
        $str .= "in row $r, resetting scan";
        $str .= "\n";
        $self->_emsg($str);
      }
    }
    $self->{head_found};
  }

  sub _check_triggers {
    my $self = shift;
    return 1 if $self->{umbrella};
    $self->_check_dtrigger &&
    $self->_check_ctrigger &&
    $self->_check_atrigger &&
    $self->_check_htrigger;
  }

  ### Maintain table context

  sub _enter_row {
    my $self = shift;
    if ($self->{in_row}) {
      $self->_emsg("Mangled HTML in table ($self->{depth},$self->{count}), forcing exit of row $self->{rc} due to new row\n") if $self->{debug};
      $self->_exit_row;
    }
    ++$self->{rc};
    ++$self->{in_row};
    push(@{$self->{grid}}, [])
  }

  sub _exit_row {
    my $self = shift;
    if ($self->{in_row}) {
      if ($self->{in_cell}) {
        $self->_emsg("Mangled HTML in table ($self->{depth},$self->{count}), forcing exit of cell ($self->{rc}, $self->{cc}) due to new row\n") if $self->{debug};
        $self->_exit_cell;
      }
      $self->{in_row} = 0;
      $self->{cc} = -1;
    }
    else {
      $self->_emsg("Mangled HTML in table ($self->{depth},$self->{count}), extraneous </TR> ignored after row $self->{rc}\n")
        if $self->{debug};
    }
  }

  sub _enter_cell {
    my $self = shift;
    if ($self->{in_cell}) {
      $self->_emsg("Mangled HTML in table ($self->{depth},$self->{count}), forcing exit of cell ($self->{rc},$self->{cc}) due to new cell\n") if $self->{debug};
      $self->_exit_cell;
    }
    if (!$self->{in_row}) {
      # Go ahead and try to recover from mangled HTML, because we care.
      $self->_emsg("Mangled HTML in table ($self->{depth},$self->{count}), inferring <TR> as row $self->{rc}\n")
        if $self->{debug};
      $self->_enter_row;
    }
    ++$self->{cc};
    ++$self->{in_cell};
    my %attrs = ref $_[1] ? %{$_[1]} : {};
    my $rspan = $attrs{rowspan} || 1;
    my $cspan = $attrs{colspan} || 1;
  }

  sub _exit_cell {
    my $self = shift;
    if ($self->{in_cell}) {
      $self->{in_cell} = 0;
    }
    else {
      $self->_emsg("Mangled HTML in table ($self->{depth},$self->{count}), extraneous </TD> ignored in row $self->{rc}\n")
        if $self->{debug};
    }
  }

  # Header stuff

  sub _header_pattern {
     my($self, @headers) = @_;
     my $str = join('|',
                map("($_)",
                 sort _header_string_sort keys %{$self->{hits_left}}
                ));
     my $hpat = qr/($str)/im;
     $self->_emsg("HPAT: /$hpat/\n") if $self->{debug} >= 2;
     $self->{hpat} = $hpat;
  }

  sub _header_string_sort {
    # this ensures that supersets appear before subsets in our header
    # search pattern, eg, '10' appears before '1' and 'hubbabubba'
    # appears before 'hubba'.
    if ($a =~ /^$b/) {
      return -1;
    }
    elsif ($b =~ /^$a/) {
      return 1;
    }
    else {
      return $b cmp $a;
    }
  }

  # Report methods

  sub depth { shift->{depth} }
  sub count { shift->{count} }
  sub coords {
    my $self = shift;
    ($self->depth, $self->count);
  }

  sub row_count { shift->{rc} }
  sub col_count { shift->{cc} }

  sub tree {
    my $self = shift;
    @_ ? $self->{_tree_ref} = shift : $self->{_tree_ref};
  }

  sub lineage {
    my $self = shift;
    $self->{lineage} ||= [];
    if (@_) {
      my $pts = shift;
      my(@lineage, $pcoords);
      if ($pts) {
        foreach my $pcoord ($pts->lineage) {
          push(@lineage, [@$pcoord]);
        }
        $pcoords = [$pts->depth, $pts->count, $pts->{rc}, $pts->{cc}];
        push(@lineage, $pcoords);
      }
      $self->{lineage} = \@lineage;
    }
    @{$self->{lineage}};
  }

  sub rows { shift->_rows(0) }

  sub space_rows {
    my $self = shift;
    $self->_rows(1);
  }

  sub _rows {
    my $self  = shift;
    my $alias = shift;
    my @ri = $self->row_indices;
    my @rows;
    my $grid = $alias ? $self->_gridalias : $self->{grid};
    foreach ($self->row_indices) {
      push(@rows, scalar $self->_slice_and_normalize_row($grid->[$_]));
    }
    wantarray ? @rows : \@rows;
  }

  sub columns {
    my $self = shift;
    my @cols;
    my @rows = $self->rows;
    foreach my $row (@rows) {
      foreach my $c (0 .. $#$row) {
        $cols[$c] ||= [];
        push(@{$cols[$c]}, $row->[$c]);
      }
    }
    @cols;
  }

  sub row_indices {
    my $self = shift;
    my $start_index = 0;
    if ($self->{headers}) {
      $start_index = $self->hrow_index;
      $start_index += 1 unless $self->{keep_headers};
    }
    $start_index .. $#{$self->{grid}};
  }

  sub col_indices {
    my $self = shift;
    my $row = $self->{grid}[0];
    0 .. $#$row;
  }

  sub row {
    my $self = shift;
    my $r = shift;
    $r <= $#{$self->{grid}}
      or croak "row $r out of range ($#{$self->{grid}})\n";
    my @ri = $self->row_indices;
    my @row = $self->_slice_and_normalize_row(
                $self->{grid}[($self->row_indices)[$r]]
              );
    wantarray ? @row : \@row;
  }

  sub _slice_and_normalize_row {
    my $self = shift;
    my $rowref = shift;
    my @row;
    if ($self->{automap} && $self->_map_makes_a_difference) {
      @row = @{$rowref}[$self->column_map];
    }
    else {
      @row = @$rowref;
    }
   @row = map($self->_cell_to_content($_), @row);
   wantarray ? @row : \@row;
  }

  sub column {
    my $self = shift;
    my $c = shift;
    my @column;
    foreach my $row ($self->rows) {
      push(@column, $self->cell($row, $c));
    }
    wantarray ? @column : \@column;
  }

  sub cell {
    my $self = shift;
    my($r, $c) = @_;
    my $row = $self->row($r);
    $c <= $#$row or croak "Column $c out of range ($#$row)\n";
    $self->_cell_to_content($row->[$c]);
  }

  sub _cell_to_content {
    my $self = shift;
    @_ or croak "cell item required\n";
    my $cell = shift;
    return $cell unless ref $cell;
    return $cell if TREE();
    return $$cell;
  }

  sub space {
    my $self = shift;
    my($r, $c) = @_;
    my $gridalias = $self->_gridalias;
    $r <= $#$gridalias
      or croak "row $r out of range ($#$gridalias)\n";
    my $row = $gridalias->[$r];
    $c <= $#$row or croak "Column $c out of range ($#$row)\n";
    $self->_cell_to_content($row->[$c]);
  }

  sub source_coords {
    my $self = shift;
    my($r, $c) = @_;
    $r <= $#{$self->{translation}}
      or croak "row $r out of range ($#{$self->{translation}})\n";
    my $row = $self->{translation}[$r];
    $c <= $#$row or croak "Column $c out of range ($#$row)\n";
    split(/,/, $self->{translation}[$r][$c]);
  }

  sub hrow_index {
    my $self = shift;
    $self->{hrow_index};
  }

  sub hrow {
    my $self = shift;
    if ($self->{automap} && $self->_map_makes_a_difference) {
      return map(ref $_ ? $$_ : $_, @{$self->{hrow}}[$self->column_map]);
    }
    else {
      return map(ref $_ ? $$_ : $_, @{$self->{hrow}});
    }
  }

  sub column_map {
    # Return the column numbers of this table in the same order as the
    # provided headers.
    my $self = shift;
    if ($self->{headers}) {
      # First we order the original column counts by taking a hash slice
      # based on the original header order. The resulting original
      # column numbers are mapped to the actual content indicies since
      # we could have a sparse slice.
      my %order;
      foreach (keys %{$self->{hits}}) {
        $order{$self->{hits}{$_}} = $_;
      }
      return @order{@{$self->{headers}}};
    }
    else {
      return 0 .. $#{$self->{grid}[0]};
    }
  }

  sub _map_makes_a_difference {
    my $self = shift;
    return 0 unless $self->{slice_columns};
    my $diff = 0;
    my @order  = $self->column_map;
    my @sorder = sort { $a <=> $b } @order;
    ++$diff if $#order != $#sorder;
    ++$diff if $#sorder != $#{$self->{grid}[0]};
    foreach (0 .. $#order) {
      if ($order[$_] != $sorder[$_]) {
        ++$diff;
        last;
      }
    }
    $diff;
  }

  sub _add_text {
    my($self, $txt) = @_;
    my $r = $self->{rc};
    my $c = $self->{cc};
    my $row = $self->{grid}[$r];
    ${$row->[$c]} .= $txt;
    $txt;
  }

  sub _reset_hits {
    my $self = shift;
    return unless $self->{headers};
    $self->{hits}     = {};
    $self->{order}    = [];
    foreach (@{$self->{headers}}) {
      ++$self->{hits_left}{$_};
    }
    1;
  }

  sub _rasterizer { shift->{_rastamon} }

  sub report {
    # Print out a summary of this table, including depth/count
    my($self, $include_content, $col_sep) = @_;
    $col_sep ||= ':';
    my $str;
    $str .= "TABLE(" . $self->depth . ", " . $self->count . ')';
    if ($include_content) {
      $str .= ":\n";
      foreach my $row ($self->rows) {
        $str .= join($col_sep, @$row) . "\n";
      }
    }
    else {
      $str .= "\n";
    }
    $str;
  }

  sub dump {
    my $self = shift;
    $self->_emsg($self->report(@_));
  }

  sub _emsg {
    my $self = shift;
    my $fh = $self->{error_handle};
    print $fh @_;
  }

}

##########

{

  package HTML::TableExtract::Rasterize;

  # Provide a closure that will rasterize (turn into a grid) a table
  # from a tree structure based on repeated data element calls with
  # rowspan and colspan information. Not as straight forward as it
  # seems...see test cases for an example bugaboo.

  my $DEBUG = 0;

  sub make_rasterizer {
    my $pkg = shift;
    my(@grid, @row_spinner, @col_spinner);
    my $empty_row_offset = 0;
    sub {
      return \@grid unless @_;
      my($row_num, $rspan, $cspan) = @_;
      $rspan = 1 unless $rspan > 1;
      $cspan = 1 unless $cspan > 1;
      my($rspin_propogate, $row_added);
      my $trigger = $#grid + $empty_row_offset;
      if ($row_num > $trigger) {
        # adjust for having been handed a row that skips a prior row,
        # otherwise the next cell will land in a wrong row. Hopefully
        # this doesn't happen too often but I've seen it in the wild!
        if ($row_num - $trigger > 1) {
          $empty_row_offset += $row_num - $trigger - 1;
        }
        # add new row
        $row_added = 1;
        my @new_row;
        # first add new row spinner
        if ($row_spinner[-1] && $col_spinner[-1]) {
          push(@row_spinner, $row_spinner[-1]);
          $rspin_propogate = 1;
        }
        else {
          push(@row_spinner, $cspan - 1);
        }
        # spin columns
        foreach (@col_spinner) {
          if ($_) {
            push(@new_row, 0);
            --$_;
          }
          else {
            push(@new_row, undef);
          }
        }
        @new_row = (undef) unless @new_row;
        push(@grid, \@new_row);
      }
      my $current_row = $grid[-1];
      # locate next available cell in row
      my $col;
      foreach my $ci (0 .. $#$current_row) {
        if (! defined $current_row->[$ci]) {
          $col = $ci;
          last;
        }
      }
      if (! defined $col) {
        ADDCOL: while (! defined $col) {
          # if no cells were available, add a column
          foreach my $ri (0 .. $#grid) {
            my $row = $grid[$ri];
            my $cspan_count = $row_spinner[$ri];
            if (!$cspan_count) {
              push(@$row, undef);
            }
            else {
              push(@$row, 0);
              --$row_spinner[$ri];
            }
          }
          push(@col_spinner, $col_spinner[-1]);
          foreach my $ci (0 .. $#$current_row) {
            if (! defined $current_row->[$ci]) {
              $col = $ci;
              last ADDCOL;
            }
          }
        }
        $col_spinner[-1] = $rspan - 1 if $col == $#$current_row;
        $row_spinner[$#grid] = $cspan - 1;
      }

      # we now have correct coordinates for this element
      $current_row->[$col] = [$rspan, $cspan];
      $col_spinner[$col] = $rspan - 1;

      # if this is an embedded placment (not a trailing element), use up
      # the cspan
      if ($col < $#$current_row) {
        my $offset = 1;
        my $row_span = $col_spinner[$col];
        if ($col + $row_spinner[-1] < $#$current_row &&
            $row_added && !$rspin_propogate) {
          # cell is spun out -- clear spinner unless it inherited cspan
          # from a cell above
          $row_spinner[-1] = 0;
        }
        while ($offset < $cspan) {
          my $cursor = $col + $offset;
          $current_row->[$cursor] = 0;
          $col_spinner[$cursor] = $row_span;
          ++$offset;
          if ($col + $offset > $#$current_row) {
            $row_spinner[-1] = $cspan - $offset;
            last;
          }
        }
      }

      if ($DEBUG) {
        foreach my $r (0 .. $#grid) {
          my $row = $grid[$r];
          foreach my $c (0 .. $#$row) {
            if (defined $row->[$c]) {
              print STDERR $row->[$c] ? 1 : 0;
            }
            else {
              print STDERR '?';
            }
          }
          print STDERR " $row_spinner[$r]\n";
        }
        print STDERR "\n";
        foreach (@col_spinner) {
          print STDERR defined $_ ? $_ : '?';
        }
        print STDERR "\n\n-----\n\n";
      }

      return \@grid;
    }
  }

}

##########

{

  package HTML::TableExtract::StripHTML;

  use vars qw(@ISA);

  use HTML::Parser;
  @ISA = qw(HTML::Parser);

  sub tag {
   my($self, $tag, $num) = @_;
   $self->{_htes_inside}{$tag} += $num;
  }

  sub text {
    my $self = shift;
    return if $self->{_htes_inside}{script} || $self->{_htes_inside}{style};
    $self->{_htes_tidbit} .= $_[0];
  }

  sub new {
    my $class = shift;
    my $self = HTML::Parser->new(
      api_version     => 3,
      handlers        => [start => [\&tag, "self, tagname, '+1'"],
                          end   => [\&tag, "self, tagname, '-1'"],
                          text  => [\&text, "self, dtext"],
                         ],
      marked_sections => 1,
    );
    bless $self, $class;
  }

  sub strip {
    my $self = shift;
    $self->parse(shift);
    $self->eof;
    $self->{_htes_tidbit};
  }

}

1;

__END__

=head1 NAME

HTML::TableExtract - Perl module for extracting the content contained in tables within an HTML document, either as text or encoded element trees.

=head1 SYNOPSIS

 # Matched tables are returned as table objects; tables can be matched
 # using column headers, depth, count within a depth, table tag
 # attributes, or some combination of the four.

 # Example: Using column header information.
 # Assume an HTML document with tables that have "Date", "Price", and
 # "Cost" somewhere in a row. The columns beneath those headings are
 # what you want to extract. They will be returned in the same order as
 # you specified the headers since 'automap' is enabled by default.

 use HTML::TableExtract;
 $te = HTML::TableExtract->new( headers => [qw(Date Price Cost)] );
 $te->parse($html_string);

 # Examine all matching tables
 foreach $ts ($te->tables) {
   print "Table (", join(',', $ts->coords), "):\n";
   foreach $row ($ts->rows) {
      print join(',', @$row), "\n";
   }
 }

 # Shorthand...top level rows() method assumes the first table found in
 # the document if no arguments are supplied.
 foreach $row ($te->rows) {
    print join(',', @$row), "\n";
 }

 # Example: Using depth and count information.
 # Every table in the document has a unique depth and count tuple, so
 # when both are specified it is a unique table. Depth and count both
 # begin with 0, so in this case we are looking for a table (depth 2)
 # within a table (depth 1) within a table (depth 0, which is the top
 # level HTML document). In addition, it must be the third (count 2)
 # such instance of a table at that depth.

 $te = HTML::TableExtract->new( depth => 2, count => 2 );
 $te->parse_file($html_file);
 foreach $ts ($te->tables) {
    print "Table found at ", join(',', $ts->coords), ":\n";
    foreach $row ($ts->rows) {
       print "   ", join(',', @$row), "\n";
    }
 }

 # Example: Using table tag attributes.
 # If multiple attributes are specified, all must be present and equal
 # for match to occur.

 $te = HTML::TableExtract->new( attribs => { border => 1 } );
 $te->parse($html_string);
 foreach $ts ($te->tables) {
   print "Table with border=1 found at ", join(',', $ts->coords), ":\n";
   foreach $row ($ts->rows) {
      print "   ", join(',', @$row), "\n";
   }
 }

 # Example: Extracting as an HTML::Element tree structure
 # Rather than extracting raw text, the html can be converted into a
 # tree of element objects. The HTML document is composed of
 # HTML::Element objects and the tables are HTML::ElementTable
 # structures. Using this, the contents of tables within a document can
 # be edited in-place.

 use HTML::TableExtract qw(tree);
 $te = HTML::TableExtract->new( headers => qw(Fee Fie Foe Fum) );
 $te->parse_file($html_file);
 $table = $te->first_table_found;
 $table_tree = $table->tree;
 $table_tree->cell(4,4)->replace_content('Golden Goose');
 $table_html = $table_tree->as_HTML;
 $table_text = $table_tree->as_text;
 $document_tree = $te->tree;
 $document_html = $document_tree->as_HTML;

=head1 DESCRIPTION

HTML::TableExtract is a subclass of HTML::Parser that serves to extract
the information from tables of interest contained within an HTML
document. The information from each extracted table is stored in table
objects. Tables can be extracted as text, HTML, or HTML::ElementTable
structures (for in-place editing or manipulation).

There are currently four constraints available to specify which tables
you would like to extract from a document: I<Headers>, I<Depth>,
I<Count>, and I<Attributes>.

I<Headers>, the most flexible and adaptive of the techniques, involves
specifying text in an array that you expect to appear above the data in
the tables of interest. Once all headers have been located in a row of
that table, all further cells beneath the columns that matched your
headers are extracted. All other columns are ignored: think of it as
vertical slices through a table. In addition, TableExtract automatically
rearranges each row in the same order as the headers you provided. If
you would like to disable this, set I<automap> to 0 during object
creation, and instead rely on the column_map() method to find out the
order in which the headers were found. Furthermore, TableExtract will
automatically compensate for cell span issues so that columns are really
the same columns as you would visually see in a browser. This behavior
can be disabled by setting the I<gridmap> parameter to 0. HTML is
stripped from the entire textual content of a cell before header matches
are attempted -- unless the I<keep_html> parameter was enabled.

I<Depth> and I<Count> are more specific ways to specify tables in
relation to one another. I<Depth> represents how deeply a table
resides in other tables. The depth of a top-level table in the
document is 0. A table within a top-level table has a depth of 1, and
so on. Each depth can be thought of as a layer; tables sharing the
same depth are on the same layer. Within each of these layers,
I<Count> represents the order in which a table was seen at that depth,
starting with 0. Providing both a I<depth> and a I<count> will
uniquely specify a table within a document.

I<Attributes> match based on the attributes of the html E<lt>tableE<gt>
tag, for example, boder widths or background color.

Each of the I<Headers>, I<Depth>, I<Count>, and I<Attributes>
specifications are cumulative in their effect on the overall extraction.
For instance, if you specify only a I<Depth>, then you get all tables at
that depth (note that these could very well reside in separate higher-
level tables throughout the document since depth extends across tables).
If you specify only a I<Count>, then the tables at that I<Count> from
all depths are returned (i.e., the I<n>th occurrence of a table at each
depth). If you only specify I<Headers>, then you get all tables in the
document containing those column headers. If you have specified multiple
constraints of I<Headers>, I<Depth>, I<Count>, and I<Attributes>, then
each constraint has veto power over whether a particular table is
extracted.

If no I<Headers>, I<Depth>, I<Count>, or I<Attributes> are specified,
then all tables match.

When extracting only text from tables, the text is decoded with
HTML::Entities by default; this can be disabled by setting the I<decode>
parameter to 0.

=head2 Extraction Modes

The default mode of extraction for HTML::TableExtract is raw text or
HTML. In this mode, embedded tables are completely decoupled from one
another. In this case, HTML::TableExtract is a subclass of HTML::Parser:

  use HTML::TableExtract;

Alternativevly, tables can be extracted as HTML::ElementTable
structures, which are in turn embedded in an HTML::Element tree
representing the entire HTML document. Embedded tables are not decoupled
from one another since this tree structure must be manitained. In this
case, HTML::TableExtract is a subclass of HTML::TreeBuilder (itself a
subclass of HTML:::Parser):

  use HTML::TableExtract qw(tree);

In either case, the basic interface for HTML::TableExtract and the
resulting table objects remains the same -- all that changes is what you
can do with the resulting data.

HTML::TableExtract is a subclass of HTML::Parser, and as such inherits
all of its basic methods such as C<parse()> and C<parse_file()>. During
scans, C<start()>, C<end()>, and C<text()> are utilized. Feel free to
override them, but if you do not eventually invoke them in the SUPER
class with some content, results are not guaranteed.

=head2 Advice

The main point of this module was to provide a flexible method of
extracting tabular information from HTML documents without relying to
heavily on the document layout. For that reason, I suggest using
I<Headers> whenever possible -- that way, you are anchoring your
extraction on what the document is trying to communicate rather than
some feature of the HTML comprising the document (other than the fact
that the data is contained in a table).

=head1 METHODS

The following are the top-level methods of the HTML::TableExtract
object. Tables that have matched a query are actually returned as
separate objects of type HTML::TableExtract::Table. These table objects
have their own methods, documented further below.

=head2 CONSTRUCTOR

=over

=item new()

Return a new HTML::TableExtract object. Valid attributes are:

=over

=item headers

Passed as an array reference, headers specify strings of interest at the
top of columns within targeted tables. They can be either strings or
regular expressions (qr//). If they are strings, they will eventually be
passed through a non-anchored, case-insensitive regular expression, so
regexp special characters are allowed.

The table row containing the headers is B<not> returned, unless
C<keep_headers> was specified or you are extracting into an element
tree. In either case the header row can be accessed via the hrow()
method from within the table object.

Columns that are not beneath one of the provided headers will be
ignored unless C<slice_columns> was set to 0. Columns will, by default,
be rearranged into the same order as the headers you provide (see the
I<automap> parameter for more information) I<unless> C<slice_columns> is
0.

Additionally, by default columns are considered what you would see
visually beneath that header when the table is rendered in a browser.
See the C<gridmap> parameter for more information.

HTML within a header is stripped before the match is attempted,
unless the C<keep_html> parameter was specified and
C<strip_html_on_match> is false.

=item depth

Specify how embedded in other tables your tables of interest should be.
Top-level tables in the HTML document have a depth of 0, tables within
top-level tables have a depth of 1, and so on.

=item count

Specify which table within each depth you are interested in,
beginning with 0.

=item attribs

Passed as a hash reference, attribs specify attributes of interest
within the HTML E<lt>tableE<gt> tag itself.

=item automap

Automatically applies the ordering reported by column_map() to the rows
returned by rows(). This only makes a difference if you have specified
I<Headers> and they turn out to be in a different order in the table
than what you specified. Automap will rearrange the columns in the same
order as the headers appear. To get the original ordering, you will need
to take another slice of each row using column_map(). I<automap> is
enabled by default.

=item slice_columns

Enabled by default, this option controls whether vertical slices are
returned from under headers that match. When disabled, all columns of
the matching table are retained, regardles of whether they had a
matching header above them. Disabling this also disables C<automap>.

=item keep_headers

Disabled by default, and only applicable when header constraints have
been specified, C<keep_headers> will retain the matching header row as
the first row of table data when enabled. This option has no effect if
extracting into an element tree tructure. In any case, the header row is
accessible from the table method C<hrow()>.

=item gridmap

Controls whether the table contents are returned as a grid or a tree.
ROWSPAN and COLSPAN issues are compensated for, and columns really are
columns. Empty phantom cells are created where they would have been
obscured by ROWSPAN or COLSPAN settings. This really becomes an issue
when extracting columns beneath headers. Enabled by default.

=item subtables

Extract all tables embedded within matched tables.

=item decode

Automatically decode retrieved text with
HTML::Entities::decode_entities(). Enabled by default. Has no effect if
C<keep_html> was specified or if extracting into an element tree
structure.

=item br_translate

Translate <br> tags into newlines. Sometimes the remaining text can be
hard to parse if the <br> tag is simply dropped. Enabled by default. Has
no effect if I<keep_html> is enabled or if extracting into an element
tree structure.

=item keep_html

Return the raw HTML contained in the cell, rather than just the visible
text. Embedded tables are B<not> retained in the HTML extracted from a
cell. Patterns for header matches must take into account HTML in the
string if this option is enabled. This option has no effect if
extracting into an elment tree structure.

=item strip_html_on_match

When C<keep_html> is enabled, HTML is stripped by default during
attempts at matching header strings (so if C<strip_html_on_match> is not
enabled and C<keep_html> is, you would have to include potential HTML
tags in the regexp for header matches). Stripped header tags are
replaced with an empty string, e.g. 'hot dE<lt>emE<gt>ogE<lt>/emE<gt>'
would become 'hot dog' before attempting a match.

=item error_handle

Filehandle where error messages are printed. STDERR by default.

=item debug

Prints some debugging information to STDERR, more for higher values.
If C<error_handle> was provided, messages are printed there rather
than STDERR.

=back

=back

=head2 REGULAR METHODS

The following methods are invoked directly from an
HTML::TableExtract object.

=over

=item depths()

Returns all depths that contained matched tables in the document.

=item counts($depth)

For a particular depth, returns all counts that contained matched
tables.

=item table($depth, $count)

For a particular depth and count, return the table object for the table
found, if any.

=item tables()

Return table objects for all tables that matched. Returns an empty list
if no tables matched.

=item first_table_found()

Return the table state object for the first table matched in the
document. Returns undef if no tables were matched.

=item current_table()

Returns the current table object while parsing the HTML. Only useful if
you're messing around with overriding HTML::Parser methods.

=item tree()

If the module was invoked in tree extraction mode, returns a reference
to the top node of the HTML::Element tree structure for the entire
document (which includes, ultimately, all tables within the document).

=item tables_report([$show_content, $col_sep])

Return a string summarizing extracted tables, along with their depth and
count. Optionally takes a C<$show_content> flag which will dump the
extracted contents of each table as well with columns separated by
C<$col_sep>. Default C<$col_sep> is ':'.

=item tables_dump([$show_content, $col_sep])

Same as C<tables_report()> except dump the information to STDOUT.

=item start

=item end

=item text

These are the hooks into HTML::Parser. If you want to subclass
this module and have things work, you must at some point call
these with content.

=back

=head2 DEPRECATED METHODS

Tables used to be called 'table states'. Accordingly, the following
methods still work but have been deprecated:

=over

=item table_state()

Is now table()

=item table_states()

Is now tables()

=item first_table_state_found()

Is now first_table_found()

=back

=head2 TABLE METHODS

The following methods are invoked from an HTML::TableExtract::Table
object, such as those returned from the C<tables()> method.

=over

=item rows()

Return all rows within a matched table. Each row returned is a reference
to an array containing the text, HTML, or reference to the HTML::Element
object of each cell depending the mode of extraction. Tables with
rowspan or colspan attributes will have some cells containing undef.
Returns a list or a reference to an array depending on context.

=item columns()

Return all columns within a matched table. Each column returned is a
reference to an array containing the text, HTML, or reference to
HTML::Element object of each cell depending on the mode of extraction.
Tables with rowspan or colspan attributes will have some cells
containing undef.

=item row($row)

Return a particular row from within a matched table either as a list or
an array reference, depending on context.

=item column($col)

Return a particular column from within a matched table as a list or an
array reference, depending on context.

=item cell($row,$col)

Return a particular item from within a matched table, whether it be the
text, HTML, or reference to the HTML::Element object of that cell,
depending on the mode of extraction. If the cell was covered due to
rowspan or colspan effects, will return undef.

=item space($row,$col)

The same as cell(), except in cases where the given coordinates were
covered due to rowspan or colspan issues, in which case the content of
the covering cell is returned rather than undef.

=item depth()

Return the depth at which this table was found.

=item count()

Return the count for this table within the depth it was found.

=item coords()

Return depth and count in a list.

=item tree()

If the module was invoked in tree extraction mode, this accessor
provides a reference to the HTML::ElementTable structure encompassing
the table.

=item hrow()

Returns the header row as a list when headers were specified as a
constraint. If C<keep_headers> was specified initially, this is
equivalent to the first row returned by the C<rows()> method.

=item column_map()

Return the order (via indices) in which the provided headers were found.
These indices can be used as slices on rows to either order the rows in
the same order as headers or restore the rows to their natural order,
depending on whether the rows have been pre-adjusted using the
I<automap> parameter.

=item lineage()

Returns the path of matched tables that led to matching this table. The
path is a list of array refs containing depth, count, row, and column
values for each ancestor table involved. Note that corresponding table
objects will not exist for ancestral tables that did not match specified
constraints.

=back

=head1 NOTES ON TREE EXTRACTION MODE

As mentioned above, HTML::TableExtract can be invoked in 'tree' mode
where the resulting HTML and extracted tables are encoded in
HTML::Element tree structures:

  use HTML::TableExtract 'tree';

There are a number of things to take note of while using this mode. The
entire HTML document is encoded into an HTML::Element tree. Each table
is part of this structure, but nevertheless is tracked separately via an
HTML::ElementTable structure, which is a specialized form of
HTML::Element tree.

The HTML::ElementTable objects are accessible by invoking the tree()
method from within each table object returned by HTML::TableExtract. The
HTML::ElementTable objects have their own row(), col(), and cell()
methods (among others). These are not to be confused with the row() and
column() methods provided by the HTML::TableExtract::Table objects.

For example, the row() method from HTML::ElementTable will provide a
reference to a 'glob' of all the elements in that row. Actions (such as
setting attributes) performed on that row reference will affect all
elements within that row. On the other hand, the row() method from the
HTML::TableExtract::Table object will return an array (either by
reference or list, depending on context) of the contents of each cell
within the row. In tree mode, the content is represented by individual
references to each cell -- these are references to the same
HTML::Element objects that reside in the HTML::Element tree.

The cell() methods provided in both cases will therefore return
references to the same object. The exception to this is when a 'cell' in
the table grid was originally 'covered' due to rowspan or colspan issues
-- in this case the cell content will be undef. Likewise, the row() or
column() methods from HTML::TableExtract::Table objects will return
arrays potentially containing a mixture of object references and undefs.
If you're going to be doing lots of manipulation of the table elements,
it might be more efficient to access them via the methods provided by
the HTML::ElementTable object instead. See L<HTML::ElementTable> for
more information on how to manipulate those objects.

An alternative to the cell() method in HTML::TableExtract::Table is the
space() method. It is largely similar to cell(), except when given
coordinates of a cell that was covered due to rowspan or colspan
effects, it will return the contents of the cell that was covering that
space rather than undef. So if, for example, cell (0,0) had a rowspan of
2 and colspan of 2, cell(1,1) would return undef and space(1,1) would
return the same content as cell(0,0) or space(0,0).

=head1 REQUIRES

HTML::Parser(3), HTML::Entities(3)

=head1 OPTIONALLY REQUIRES

HTML::TreeBuilder(3), HTML::ElementTable(3)

=head1 AUTHOR

Matthew P. Sisk, E<lt>F<sisk@mojotoad.com>E<gt>

=head1 COPYRIGHT

Copyright (c) 2000-2006 Matthew P. Sisk.
All rights reserved. All wrongs revenged. This program is free
software; you can redistribute it and/or modify it under the same terms
as Perl itself.

=head1 SEE ALSO

HTML::Parser(3), HTML::TreeBuilder(3), HTML::ElementTable(3), perl(1).

=cut

In honor of fragmented markup languages and sugar mining:

The Good and The Bad
Ted Hawkins (1936-1994)

Living is good
   when you have someone to share it with
Laughter is bad
   when there is no one there to share it with
Talking is sad 
   if you've got no one to talk to
Dying is good
   when the one you love grows tired of you

Sugar is no good
   once it's cast among the white sand
What the point
   in pulling the gray hairs from among the black strands
When you're old
   you shouldn't walk in the fast lane
Oh ain't it useless
   to keep trying to draw true love from that man

He'll hurt you,
   Yes just for the sake of hurting you
and he'll hate you
   if you try to love him just the same
He'll use you
   and everything you have to offer him
On your way girl
   Get out and find you someone new
