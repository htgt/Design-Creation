package DesignCreate::Cmd::Step::OligoPairRegionsGibson;
## no critic(RequireUseStrict,RequireUseWarnings)
{
    $DesignCreate::Cmd::Step::OligoPairRegionsGibson::VERSION = '0.043';
}
## use critic


=head1 NAME

DesignCreate::Cmd::Step::OligoPairRegionsGibson - Work out coordinate for oligo regions in gibson designs

=head1 DESCRIPTION

Generate a yaml file giving the start and end coordiantes for the oligo pair
regions in gibson designs: exon_region five_prime_region and three_prime_region

=cut

use strict;
use warnings FATAL => 'all';

use Moose;
use Try::Tiny;
use namespace::autoclean;

extends qw( DesignCreate::Cmd::Step );
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

__PACKAGE__->meta->make_immutable;

1;

__END__
