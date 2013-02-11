package DesignCreate::Action::OligoTargetRegions;

=head1 NAME

DesignCreate::Action::OligoTargetRegions - Produce fasta files of the oligo target region sequences

=head1 DESCRIPTION

For given target coordinates and a oligo region parameters produce target region sequence file
for each oligo we must find.

=cut

#
# Initial version will be setup for standard deletion design only
#
#TODO
# setup config files to set some values below, don't use defaults

use strict;
use warnings FATAL => 'all';

use Moose;

extends qw( DesignCreate::Action );
with 'DesignCreate::Role::OligoTargetRegions';

sub BUILD {
    my $self = shift;

    if ( $self->target_start > $self->target_end ) {
        $self->log->logdie( 'Target start ' . $self->target_start
                            .  ' is greater than target end '
                            . $self->target_end );
    }

}

sub execute {
    my ( $self, $opts, $args ) = @_;

    $self->build_oligo_target_regions;

    return;
}

__PACKAGE__->meta->make_immutable;

1;

__END__
