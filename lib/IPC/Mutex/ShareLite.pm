=pod

=head1 NAME

IPC::Mutex::Flock - implemented IPC::Mutex by IPC::ShareLite

=head1 SYNOPSIS

    use IPC::Mutex::ShareLite;
    
    my $im = IPC::Mutex::ShareLite->new;
    my @results = $im->critical( sub {
        # task for exclusive other processes
        # ...
        return @val;
    } );

=head1 DESCRIPTION

TODO

=head1 SEE ALSO

L<IPC::Mutex>
L<IPC::Mutex::Flock>

=head1 AUTHOR

WATANABE Hiroaki, E<lt>hwat@mac.comE<gt>

=head1 LICENSE

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

package IPC::Mutex::ShareLite;

use strict;
use base qw(IPC::Mutex);

use vars qw($VERSION);
$VERSION = '0.01_01';

use IPC::ShareLite qw(:lock);

sub _lock_ { # implement
    my $self    = shift;
    my $share = IPC::ShareLite->new(
        -key     => $self->key,
        -create  => 1,
        -destroy => 0,
    ) or die "cannot create IPC::ShareLite: $!";
    $share->lock(LOCK_EX);
    return sub {
            $share->unlock;
        };
}

sub cleanup { # override
    my $self = shift;

    IPC::ShareLite->new(
        -key     => $self->key,
        -create  => 1,
        -destroy => 1,
        );
}

1;
