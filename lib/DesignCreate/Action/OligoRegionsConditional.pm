package DesignCreate::Action::OligoRegionsConditional;

=head1 NAME

DesignCreate::Action::OligoRegionConditional - Create seq files for oligo region, insertion or deletion designs 

=head1 DESCRIPTION

For given target coordinates and oligo region parameters produce target region sequence file
for each oligo we must find for conditional designs.

=cut

use strict;
use warnings FATAL => 'all';

use Moose;
use Try::Tiny;
use namespace::autoclean;

extends qw( DesignCreate::Action );
with 'DesignCreate::CmdRole::OligoRegionsConditional';

sub execute {
    my ( $self, $opts, $args ) = @_;

    try{
        $self->build_conditional_oligo_target_regions;
    }
    catch{
        $self->log->error( "Failed to generate oligo target regions:\n" . $_ );
    };

    return;
}

__PACKAGE__->meta->make_immutable;

1;

__END__