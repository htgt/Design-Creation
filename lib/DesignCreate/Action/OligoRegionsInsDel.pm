package DesignCreate::Action::OligoRegionsInsDel;
## no critic(RequireUseStrict,RequireUseWarnings)
{
    $DesignCreate::Action::OligoRegionsInsDel::VERSION = '0.022';
}
## use critic


=head1 NAME

DesignCreate::Action::OligoRegionsInsDel - Create seq files for oligo region, insertion or deletion designs 

=head1 DESCRIPTION

For given target coordinates and oligo region parameters produce target region coordinates file
for each oligo we must find for deletion or insertion designs.

=cut

use strict;
use warnings FATAL => 'all';

use Moose;
use Try::Tiny;
use namespace::autoclean;

extends qw( DesignCreate::Action );
with 'DesignCreate::CmdRole::OligoRegionsInsDel';

sub execute {
    my ( $self, $opts, $args ) = @_;

    try{
        $self->get_oligo_region_coordinates;
    }
    catch{
        $self->log->error( "Failed to generate oligo target regions:\n" . $_ );
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
