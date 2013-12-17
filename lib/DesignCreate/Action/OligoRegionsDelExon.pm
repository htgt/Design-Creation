package DesignCreate::Action::OligoRegionsDelExon;
## no critic(RequireUseStrict,RequireUseWarnings)
{
    $DesignCreate::Action::OligoRegionsDelExon::VERSION = '0.014';
}
## use critic


=head1 NAME

DesignCreate::Action::OligoRegionsDelExon - Get coordinate for a Deletion design on a exon id

=head1 DESCRIPTION

For given target exon and oligo region parameters production target region coordinates file
for each oligo we need for a deletion design.

=cut

use strict;
use warnings FATAL => 'all';

use Moose;
use Try::Tiny;
use namespace::autoclean;

extends qw( DesignCreate::Action );
with 'DesignCreate::CmdRole::OligoRegionsDelExon';

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
