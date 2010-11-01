=pod

=head1 NAME

IPC::Mutex::Flock - implemented IPC::Mutex by flock

=head1 SYNOPSIS

    use IPC::Mutex::Flock;
    
    my $im = IPC::Mutex::Flock->new;
    my @results = $im->critical( sub {
        # task for exclusive other processes
        # ...
        return @val;
    } );

=head1 DESCRIPTION

TODO

=head1 SEE ALSO

L<IPC::Mutex>
L<IPC::Mutex::ShareLite>

=head1 AUTHOR

WATANABE Hiroaki, E<lt>hwat@mac.comE<gt>

=head1 LICENSE

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

package IPC::Mutex::Flock;

use strict;
use base qw(IPC::Mutex);

use vars qw($VERSION $DEFAULT_PREFIX);
$VERSION = '0.01_01';
$DEFAULT_PREFIX = 'ipc_mutex_flock';

sub _init { # override
    my $self    = shift;
    my $args    = shift || {};
    $self->SUPER::_init($args);
    $self->_prefix( defined $args->{'prefix'} ? $args->{'prefix'} : $DEFAULT_PREFIX );
    return $self;
}

sub _prefix {
    my $self = shift;
    return @_ ? $self->{'prefix'} = shift : $self->{'prefix'};
}

sub _mk_lockfile_name {
    my $self = shift;
    sprintf '%s.%s', $self->_prefix, $self->key;
}

sub _lock_ { # implement
    my $self    = shift;

    my $lockfile = $self->_mk_lockfile_name;
    open  LK, ">>$lockfile" or die "cannot open lockfile: $!";
    flock LK, 2             or die "cannot flock lockfile: $!";
    return sub {
            close LK or die "cannot close lockfile: $!";
        };
}

sub cleanup { # override
    my $self = shift;

    my $lockfile = $self->_mk_lockfile_name;
    if( -e $lockfile ){
        unless( unlink $lockfile ){
            die "cannot unlink lockfile $lockfile: $!";
            return 0;
        }
        return 1;
    }
    return -1;
}

1;
