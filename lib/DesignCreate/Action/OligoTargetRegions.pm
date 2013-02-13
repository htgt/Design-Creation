package DesignCreate::Action::OligoTargetRegions;

=head1 NAME

DesignCreate::Action::OligoTargetRegions - Produce fasta files of the oligo target region sequences

=head1 DESCRIPTION

For given target coordinates and a oligo region parameters produce target region sequence file
for each oligo we must find.

=cut

use strict;
use warnings FATAL => 'all';

use Moose;
use namespace::autoclean;

extends qw( DesignCreate::Action );
with 'DesignCreate::CmdRole::OligoTargetRegions';

sub execute {
    my ( $self, $opts, $args ) = @_;

    $self->build_oligo_target_regions;

    return;
}

__PACKAGE__->meta->make_immutable;

1;

__END__
