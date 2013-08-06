package DesignCreate::Action::OligoRegionsInsDel;

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

__PACKAGE__->meta->make_immutable;

1;

__END__
