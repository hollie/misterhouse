package RRDTool::Rawish;
use strict;
use warnings;
use 5.008;

use Carp ();
use Capture::Tiny qw(capture);
use File::Which ();

our $VERSION = '0.032';

sub new {
    my ($class, @args) = @_;
    my %args = @args == 1 && ref $args[0] eq 'HASH' ? %{$args[0]} : @args;

    my $rrdtool_path = $args{rrdtool_path} || File::Which::which('rrdtool')
        or Carp::croak 'Not found rrdtool command';
    if (not -x $rrdtool_path) {
        Carp::croak "Cannot execute $rrdtool_path";
    }

    return bless {
        command  => $rrdtool_path,
        remote   => $args{remote},
        rrdfile  => $args{rrdfile},
        rrderror => "",
    }, $class;
}

sub version {
    my $self = shift;
    my ($ret, $exit_status) = $self->_readpipe($self->{command}, 'version');
    $ret =~ /^RRDtool (\d+)\.(\d+).(\d+)/;
    return "$1.$2$3";  # like "1.47"
}

sub errstr { $_[0]->{rrderror} }

sub create {
    my ($self, $params, $opts) = @_;
    Carp::croak 'Require rrdfile'             if not defined $self->{rrdfile};
    Carp::croak 'Not ARRAY reference: params' if ref($params) ne 'ARRAY';
    Carp::croak 'Not HASH reference: opts'    if defined $opts && ref($opts) ne 'HASH';

    $opts->{'--daemon'} = $self->{remote} if $self->{remote};

    my $exit_status = $self->_system($self->{command}, 'create', $self->{rrdfile}, _opt_array($opts), @$params);
    return $exit_status;
}

sub update {
    my ($self, $params, $opts) = @_;
    Carp::croak 'Require rrdfile'             if not defined $self->{rrdfile};
    Carp::croak 'Not ARRAY reference: params' if ref($params) ne 'ARRAY';
    Carp::croak 'Not HASH reference: opts'    if defined $opts && ref($opts) ne 'HASH';

    $opts->{'--daemon'} = $self->{remote} if $self->{remote};

    my $exit_status = $self->_system($self->{command}, 'update', $self->{rrdfile}, _opt_array($opts), @$params);
    return $exit_status;
}

sub graph {
    my ($self, $filename, $params, $opts) = @_;
    Carp::croak 'Require filename' unless $filename;
    Carp::croak 'Not ARRAY reference: $params' if ref($params) ne 'ARRAY';
    Carp::croak 'Not HASH reference: $opts'    if defined $opts && ref($opts) ne 'HASH';

    $opts->{'--daemon'} = $self->{remote} if $self->{remote};

    my ($img, $exit_status) = $self->_readpipe($self->{command}, 'graph', $filename, _opt_array($opts), @$params);
    return $img;
}

sub dump {
    my ($self, $opts) = @_;
    Carp::croak 'Require rrdfile'           if not defined $self->{rrdfile};
    Carp::croak 'Not HASH reference: $opts' if defined $opts && ref($opts) ne 'HASH';

    $opts->{'--daemon'} = $self->{remote} if $self->{remote};

    my ($xml, $exit_status) = $self->_readpipe($self->{command}, 'dump', $self->{rrdfile}, _opt_array($opts));
    return $xml;
}

sub restore {
    my ($self, $xmlfile, $opts) = @_;
    Carp::croak 'Require rrdfile'          if not defined $self->{rrdfile};
    Carp::croak 'Require xmlfile'          if not defined $xmlfile;
    Carp::croak 'Not HASH reference: opts' if defined $opts && ref($opts) ne 'HASH';

    my $ret = $self->_system($self->{command}, 'restore', $xmlfile, $self->{rrdfile}, _opt_array($opts));
    return $ret;
}

sub lastupdate {
    my ($self) = @_;
    Carp::croak 'Require rrdfile'    if not defined $self->{rrdfile};

    my $opts = {};
    $opts->{'--daemon'} = $self->{remote} if $self->{remote};

    my ($text, $exit_status) = $self->_readpipe($self->{command}, 'lastupdate', $self->{rrdfile}, _opt_array($opts));
    return $text if (!$text and $exit_status != 0);

    my $lines = [ split "\n", $text ];
    my ($timestamp, $tmp) = split ':', $lines->[2];
    return $timestamp;
}

sub fetch {
    my ($self, $CF, $opts) = @_;
    Carp::croak 'Require rrdfile'          if not defined $self->{rrdfile};
    Carp::croak 'Require CF'               if not defined $CF;
    Carp::croak 'Not HASH reference: opts' if defined $opts && ref($opts) ne 'HASH';

    $opts->{'--daemon'} = $self->{remote} if $self->{remote};

    my ($text, $exit_status) = $self->_readpipe($self->{command}, 'fetch', $self->{rrdfile}, $CF, _opt_array($opts));
    return $text if (!$text and $exit_status != 0);

    my $lines = [ split "\n", $text ];
    return $lines;
}

sub xport {
    my ($self, $params, $opts) = @_;
    Carp::croak 'Not ARRAY reference: params' if ref($params) ne 'ARRAY';
    Carp::croak 'Not HASH reference: opts'    if defined $opts && ref($opts) ne 'HASH';

    $opts->{'--daemon'} = $self->{remote} if $self->{remote};

    my ($xml, $exit_status) = $self->_readpipe($self->{command}, 'xport', _opt_array($opts), @$params);
    return $xml;
}

sub info {
    my ($self) = @_;
    Carp::croak 'Require rrdfile'    if not defined $self->{rrdfile};

    my $opts_str = $self->{remote} ? "--daemon" : "";

    my ($text, $exit_status) = $self->_readpipe($self->{command}, 'info', $self->{rrdfile}, $opts_str);
    return $text if (!$text and $exit_status != 0);

    my $value = {};
    my $lines = [ split "\n", $text ];
    for (@$lines) {
        my ($k, $v) = split ' = ', $_;
        $v =~ s/"(.+)"/$1/g;
        if ($k =~ /^rra\[(\d+)]\.(.+)\[(\d+)\]\.(.+)$/) { # rra[0].cdp_prep[0].value = NaN
            $value->{rra}->[$1]->{$2}->[$3]->{$4} = $v;
        }
        elsif ($k =~ /^rra\[(\d+)\]\.(.+)$/) { # rra[0].cf = "LAST"
            $value->{rra}->[$1]->{$2} = $v;
        }
        elsif ($k =~ /^ds\[(.+)\]\.(.+)$/) {   # ds[rx].type = "DERIVE"
            $value->{ds}->{$1}->{$2} = $v;
        }
        else {
            $value->{$k} = $v;
        }
    }
    return $value;
}

sub _system {
    my ($self, @expr) = @_;

    my ($stdout, $stderr, $exit_status) = capture {
        system(_sanitize(join(" ", @expr)));
    };
    chomp $stderr;
    $self->{rrderror} = $stderr if $exit_status != 0;
    return $exit_status;
}

sub _readpipe {
    my ($self, @expr) = @_;

    my ($stdout, $stderr, $exit_status) = capture {
        system(_sanitize(join(" ", @expr)));
    };
    chomp $stderr;
    $self->{rrderror} = $stderr if $exit_status != 0;
    return ($stdout, $exit_status);
}

sub _sanitize {
    my $command = shift;
    $command =~ s/[^a-z0-9#_@\s\-\.\,\:\/=\+\-\*\%]//gi;
    return $command;
}

sub _opt_array {
    my ($opts) = @_;

    return map {
        ($opts->{$_} eq 1) ? $_ : ($_, $opts->{$_})
    } sort(keys %$opts);
}

1;
__END__

1;
__END__

=head1 NAME

RRDTool::Rawish - A RRDtool command wrapper with rawish interface

=head1 SYNOPSIS

    use RRDTool::Rawish;

    my $rrd = RRDTool::Rawish->new(
        rrdfile => 'rrdtest.rrd',           # option
        remote  => 'rrdtest.com:11111',  # option for rrdcached
    );
    my $exit_status = $rrd->create(["DS:rx:DERIVE:40:0:U", "DS:tx:DERIVE:40:0:U", "RRA:LAST:0.5:1:240"], {
        '--start'        => '1350294000',
        '--step'         => '20',
        '--no-overwrite' => '1',
    });

    my $exit_status = $rrd->update([
        "1350294020:0:0",
        "1350294040:50:100",
        "1350294060:80:150",
        "1350294080:100:200",
        "1350294100:180:300",
        "1350294120:220:380",
        "1350294140:270:400"
    ]);

    my $img = $rrd->graph('-', [
        "DEF:rx=rrdtest2.rrd:rx:LAST",
        "DEF:tx=rrdtest2.rrd:tx:LAST",
        "LINE1:rx:rx#00F000",
        "LINE1:tx#0000F0",
    ]);

    # error message
    $rrd->errstr; # => "ERROR: hogehoge"

=head1 DESCRIPTION

RRDTool::Rawish is a RRDtool command wrapper class with rawish interface.
You can use the class like RRDtool command interface.
Almost all of modules with RRD prefix are RRDs module wrappers.
It's troublesome to use RRDs with variable environments because it's a XS module and moreover not a CPAN module.
In contrast, RRDTool::Rawish has less dependencies and it's easy to install it.

=head1 METHODS

=over 4

=item my $rrd = RRDTool::Rawish->new([%args])

Creates a new instance of RRDTool::Rawish.

=item $rrd->version()

Returns rrdtool's version like "1.47".

=item $rrd->errstr()

Returns rrdtool's stderr string. If no error occurs, it returns empty string.

=item $rrd->create($params, [\%opts])
Returns exit status

rrdtool create

=item $rrd->update($params, [\%opts])
Returns exit status

rrdtool update

=item $rrd->graph($filename, $params, [\%opts])
Returns exit status

rrdtool graph
Returns image binary.

=item $rrd->dump([\%opts])

rrdtool dump
Returns xml data.

=item $rrd->restore($xmlfile, [\%opts])

rrdtool restore
Returns exit status

=item $rrd->lastupdate

rrdtool lastupdate
Returns timestamp

=item $rrd->fetch

rrdtool fetch
Returns output lines as an ARRAY refarence

=item $rrd->xport

rrdtool xport
Returns xml data

=item $rrd->info

rrdtool info
Returns info as a HASH refarence

Examples:

    is $value->{filename}, "rrd_test.rrd";
    is $value->{rrd_version}, "0003";
    is $value->{step}, 20;
    is $value->{last_update}, 1350294000;
    is $value->{header_size}, 904;
    is $value->{ds}->{rx}->{index}, 0;
    is $value->{ds}->{rx}->{minimal_heartbeat}, 40;
    is $value->{ds}->{rx}->{min}, "0.0000000000e+00";
    is $value->{ds}->{rx}->{max}, "NaN";
    is $value->{ds}->{rx}->{last_ds}, "U";
    is $value->{ds}->{rx}->{value},  "0.0000000000e+00";
    is $value->{ds}->{rx}->{unknown_sec}, 0;
    is $value->{ds}->{tx}->{index}, 1;
    is $value->{ds}->{tx}->{type}, "DERIVE";
    is $value->{ds}->{tx}->{minimal_heartbeat}, 40;
    is $value->{ds}->{tx}->{min}, "0.0000000000e+00";
    is $value->{ds}->{tx}->{max}, "NaN";
    is $value->{ds}->{tx}->{last_ds}, "U";
    is $value->{ds}->{tx}->{value}, "0.0000000000e+00";
    is $value->{ds}->{tx}->{unknown_sec}, 0;
    is $value->{rra}->[0]->{cf}, "LAST";
    is $value->{rra}->[0]->{rows}, 240;
    is $value->{rra}->[0]->{cur_row}, 95;
    is $value->{rra}->[0]->{pdp_per_row}, 1;
    is $value->{rra}->[0]->{xff}, "5.0000000000e-01";
    is $value->{rra}->[0]->{cdp_prep}->[0]->{value}, "NaN";
    is $value->{rra}->[0]->{cdp_prep}->[0]->{unknown_datapoints}, 0;
    is $value->{rra}->[0]->{cdp_prep}->[1]->{value}, "NaN";
    is $value->{rra}->[0]->{cdp_prep}->[1]->{unknown_datapoints}, 0;

=back

=head1 AUTHOR

Yuuki Tsubouchi  C<< <yuuki@cpan.org> >>

=head1 THANKS TO

Shoichi Masuhara

=head1 SEE ALSO

L<RRDtool Documetation|http://oss.oetiker.ch/rrdtool/>

=head1 LICENCE AND COPYRIGHT

Copyright (c) 2013, Yuuki Tsubouchi C<< <yuuki@cpan.org> >>. All rights reserved.

This module is free software; you can redistribute it and/or
modify it under the same terms as Perl itself. See L<perlartistic>.

=cut
