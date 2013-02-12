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
use Const::Fast;
use namespace::autoclean;

extends qw( DesignCreate::Action );
with 'DesignCreate::CmdRole::OligoTargetRegions';

#TODO move this
const my $DEFAULT_OLIGO_TARGET_REGIONS_DIR_NAME => 'oligo_target_regions';

sub execute {
    my ( $self, $opts, $args ) = @_;

    $self->build_oligo_target_regions;

    return;
}

# if running command by itself we want to check the target regions dir exists
# default is to delete and re-create folder
override _build_oligo_target_regions_dir => sub {
    my $self = shift;

    my $target_regions_dir = $self->dir->subdir( $DEFAULT_OLIGO_TARGET_REGIONS_DIR_NAME );
    unless ( $self->dir->contains( $target_regions_dir ) ) {
        $self->log->logdie( "Can't find aos output dir: "
                           . $self->target_regions_dir->stringify );
    }

    return $target_regions_dir->absolute;
};

__PACKAGE__->meta->make_immutable;

1;

__END__
