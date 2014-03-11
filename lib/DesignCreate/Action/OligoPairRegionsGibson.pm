package DesignCreate::Action::OligoPairRegionsGibson;
## no critic(RequireUseStrict,RequireUseWarnings)
{
    $DesignCreate::Action::OligoPairRegionsGibson::VERSION = '0.022';
}
## use critic


=head1 NAME

DesignCreate::Action::OligoPairRegionsGibson - Work out coordinate for oligo regions in gibson designs

=head1 DESCRIPTION

Generate a yaml file giving the start and end coordiantes for the oligo pair
regions in gibson designs: exon_region five_prime_region and three_prime_region

=cut

use strict;
use warnings FATAL => 'all';

use Moose;
use Try::Tiny;
use namespace::autoclean;

extends qw( DesignCreate::Action );
with 'DesignCreate::CmdRole::OligoPairRegionsGibson';

sub execute {
    my ( $self, $opts, $args ) = @_;

    try{
        $self->get_oligo_pair_region_coordinates;
    }
    catch{
        $self->log->error( "Failed to generate oligo pair region coordinates for gibson designs:\n" . $_ );
    };

    return;
}

# if running command by itself we want to check the oligo target regions dir exists
# default is to delete and re-create folder
override _build_oligo_target_regions_dir => sub {
    my $self = shift;

    my $oligo_target_regions_dir = $self->dir->subdir( $self->oligo_target_regions_dir_name );
    unless ( $self->dir->contains( $oligo_target_regions_dir ) ) {
        $self->log->logdie( "Can't find oligo target region dir: "
                           . $oligo_target_regions_dir->stringify );
    }

    return $oligo_target_regions_dir->absolute;
};

__PACKAGE__->meta->make_immutable;

1;

__END__
