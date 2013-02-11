package DesignCreate::Action::PickGapOligos;

=head1 NAME

DesignCreate::Action::PickGapOligos - Pick the best Gap oligo pair, G5 & G3

=head1 DESCRIPTION

Pick the best pair of gap oligos ( one G5 and one G3 oligo ).
Look at the sequence similarity between each combination pair of G5 and G3
and pick the ones with no matching sections of sequence.

=cut

use strict;
use warnings FATAL => 'all';

use Moose;
use namespace::autoclean;

extends qw( DesignCreate::Action );
with 'DesignCreate::CmdRole::PickGapOligos';

sub execute {
    my ( $self, $opts, $args ) = @_;

    $self->pick_gap_oligos;

    return;
}

__PACKAGE__->meta->make_immutable;

1;

__END__
