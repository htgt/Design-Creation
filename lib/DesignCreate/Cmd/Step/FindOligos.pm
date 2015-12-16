package DesignCreate::Cmd::Step::FindOligos;
## no critic(RequireUseStrict,RequireUseWarnings)
{
    $DesignCreate::Cmd::Step::FindOligos::VERSION = '0.039';
}
## use critic


=head1 NAME

DesignCreate::Cmd::Step::FindOligos - Get oligos for a design

=head1 DESCRIPTION

Finds a selection of oligos for a design given the oligos target ( candidate ) regions.
This is a wrapper around RunAOS which does the real work.

=cut

use strict;
use warnings FATAL => 'all';

use Moose;
use Const::Fast;
use Try::Tiny;
use Fcntl; # O_ constants
use namespace::autoclean;

extends qw( DesignCreate::Cmd::Step );
with 'DesignCreate::CmdRole::FindOligos';

sub execute {
    my ( $self, $opts, $args ) = @_;

    try{
        $self->find_oligos;
    }
    catch{
        $self->log->error( "Error finding oligos:\n" . $_ );
    };

    return;
}

__PACKAGE__->meta->make_immutable;

1;

__END__
