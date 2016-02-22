
=head1 B<Logger>

=head2 SYNOPSIS

  $kitchen_log = new Logger();

  $kitchen_log->set('warn');  # Can be set via web, telnet, voice, etc.

  $kitchen_log->fatal('print a fatal msg');     # prints
  $kitchen_log->error('print an error msg');    # prints
  $kitchen_log->warn('print a warning msg');    # prints
  $kitchen_log->info('print an info msg');      # does not print
  $kitchen_log->debug('print a debug msg');     # does not print
  $kitchen_log->trace('print a trace msg');     # does not print


If you would like you own custom output, then change print_expression.  The default print_expression is

  my $tmp = $self->get_object_name();
  $tmp =~ s/(_logger|_log)$//i;
  &main::print_log( $tmp . ' [' . $level . '] ' . $msg );

=head2 DESCRIPTION

A convenience class for logging messages.  To change the loggging level call set(...) on this object with one of the following possible states:  'fatal', 'error', 'warn', 'info', 'debug', and 'trace'.

=head2 INHERITS

B<Generic_Item>

=head2 METHODS

=over

=cut

use strict;

package Logger;

@Logger::ISA = ('Generic_Item');

=item C<new>

Creates a new Logger class.  $p_name - optional argument to easily set $$self{object_name}

=cut

sub new {
    my ( $class, $p_object_name ) = @_;
    my $self = $class->Generic_Item::new();
    bless $self, $class;

    $$self{object_name} = $p_object_name if ( defined $p_object_name );

    # STATES - info initially
    $self->set_states( 'fatal', 'error', 'warn', 'info', 'debug', 'trace' );
    $$self{state} = 'info';

    $self->print_expression( 'my $tmp = $self->get_object_name();'
          . '$tmp =~ s/(_logger|_log)$//i;'
          . '&main::print_log( $tmp . \' [\' . $level . \'] \' . $msg );' );

    return $self;
}

sub fatal {
    my ( $self, $p_string ) = @_;
    $self->log( $p_string, 'fatal' );
}

sub error {
    my ( $self, $p_string ) = @_;
    $self->log( $p_string, 'error' );
}

sub warn {
    my ( $self, $p_string ) = @_;
    $self->log( $p_string, 'warn' );
}

sub info {
    my ( $self, $p_string ) = @_;
    $self->log( $p_string, 'info' );
}

sub debug {
    my ( $self, $p_string ) = @_;
    $self->log( $p_string, 'debug' );
}

sub trace {
    my ( $self, $p_string ) = @_;
    $self->log( $p_string, 'trace' );
}

sub log {
    my ( $self, $p_string, $p_log_level ) = @_;

    if ( $self->isLoggable($p_log_level) ) {
        $self->_print_log( $p_string, $p_log_level );
    }
}

sub isLoggable {
    my ( $self, $p_log_level ) = @_;

    for my $level ( $self->get_states ) {
        if ( $level eq $p_log_level ) {
            return 1;
        }
        elsif ( $level eq $self->state ) {
            return 0;
        }
    }

    return 0;
}

sub _print_log {
    my ( $self, $msg, $level ) = @_;

    package main;
    return eval $self->print_expression;
}

=item C<print_expression>

This can be set to have your own custom expression to print.  This can include writing to a file or whatever you want.

Available Variables:

  $self - the logger
  $msg - the message to be printed
  $level - the logged message level of severity (error, debug, trace, etc)

Default Value:

  my $tmp = $self->get_object_name();
  $tmp =~ s/(_logger|_log)$//i;
  &main::print_log( $tmp . ' [' . $level . '] ' . $msg );

=cut

sub print_expression {
    my ( $self, $p_expr ) = @_;
    if ( defined $p_expr ) {
        $$self{print_expression} = $p_expr;
    }

    return $$self{print_expression};
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

