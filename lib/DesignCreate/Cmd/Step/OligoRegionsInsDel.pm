package DesignCreate::Cmd::Step::OligoRegionsInsDel;
## no critic(RequireUseStrict,RequireUseWarnings)
{
    $DesignCreate::Cmd::Step::OligoRegionsInsDel::VERSION = '0.040';
}
## use critic


=head1 NAME

DesignCreate::Cmd::Step::OligoRegionsInsDel - Work out coordinate for oligo regions in indel designs

=head1 DESCRIPTION

For given target coordinates and oligo region parameters produce target region coordinates file
for each oligo we must find for deletion or insertion designs.

=cut

use strict;
use warnings FATAL => 'all';

use Moose;
use Try::Tiny;
use namespace::autoclean;

extends qw( DesignCreate::Cmd::Step );
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
