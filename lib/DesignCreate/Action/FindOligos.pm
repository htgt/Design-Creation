package DesignCreate::Action::FindOligos;

=head1 NAME

DesignCreate::Action::FindOligos - Get oligos for a design

=head1 DESCRIPTION

Finds a selection of oligos for a design given the oligos target ( candidate ) regions.
This is a wrapper around RunAOS which does the real work.

=cut

use strict;
use warnings FATAL => 'all';

use Moose;
use namespace::autoclean;

extends qw( DesignCreate::Action );
with 'DesignCreate::CmdRole::FindOligos';


sub execute {
    my ( $self, $opts, $args ) = @_;

    $self->find_oligos;

    return;
}

__PACKAGE__->meta->make_immutable;

1;

__END__
