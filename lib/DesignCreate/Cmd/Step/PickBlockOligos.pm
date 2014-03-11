package DesignCreate::Cmd::Step::PickBlockOligos;

=head1 NAME

DesignCreate::Cmd::Step::PickBlockOligos - Pick the best U and D block oligo pairs

=head1 DESCRIPTION

Pick the best pair of block oligos ( U5 & U3, D5 & D3 ).
Must have a minumum gap between the oligo pairs.
We prefer closer pairs of oligos.

=cut

use strict;
use warnings FATAL => 'all';

use Moose;
use Const::Fast;
use Try::Tiny;
use namespace::autoclean;

extends qw( DesignCreate::Cmd::Step );
with 'DesignCreate::CmdRole::PickBlockOligos';

sub execute {
    my ( $self, $opts, $args ) = @_;

    try{
        $self->pick_block_oligos;
    }
    catch{
        $self->log->error( "Error picking block oligos:\n" . $_ );
    };

    return;
}

__PACKAGE__->meta->make_immutable;

1;

__END__
