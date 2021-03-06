package DesignCreate::Cmd::Step::OligoRegionsConditional;

=head1 NAME

DesignCreate::Cmd::Step::OligoRegionsConditional - Work out coordinate for oligo regions in conditional designs

=head1 DESCRIPTION

For given target coordinates and oligo region parameters produce target region coordinates file
for each oligo we must find for conditional designs.

=cut

use strict;
use warnings FATAL => 'all';

use Moose;
use Try::Tiny;
use namespace::autoclean;

extends qw( DesignCreate::Cmd::Step );
with 'DesignCreate::CmdRole::OligoRegionsConditional';

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
