package DesignCreate::Action::FilterOligos;

=head1 NAME

DesignCreate::Action::FilterOligos - Filter out invalid oligos

=head1 DESCRIPTION

There will be multiple possible oligos of each type for a design.
This script validates the individual oligos and filters out the ones that do not
meet our requirments.

=cut

use strict;
use warnings FATAL => 'all';

use Moose;
use namespace::autoclean;

extends qw( DesignCreate::Action );
with 'DesignCreate::CmdRole::FilterOligos';

sub execute {
    my ( $self, $opts, $args ) = @_;

    $self->filter_oligos;

    return;
}

__PACKAGE__->meta->make_immutable;

1;

__END__
