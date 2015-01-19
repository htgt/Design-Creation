package DesignCreate::Cmd::Step::OligoPairRegionsGibsonDel;
## no critic(RequireUseStrict,RequireUseWarnings)
{
    $DesignCreate::Cmd::Step::OligoPairRegionsGibsonDel::VERSION = '0.033';
}
## use critic


=head1 NAME

DesignCreate::Cmd::Step::OligoPairRegionsGibsonDel - Work out coordinate for oligo regions in gibson deletion designs

=head1 DESCRIPTION

Generate a yaml file giving the start and end coordiantes for the oligo pair
regions in gibson deletion designs: five_prime_region and three_prime_region

=cut

use strict;
use warnings FATAL => 'all';

use Moose;
use Try::Tiny;
use namespace::autoclean;

extends qw( DesignCreate::Cmd::Step );
with 'DesignCreate::CmdRole::OligoPairRegionsGibsonDel';

sub execute {
    my ( $self, $opts, $args ) = @_;

    try{
        $self->get_oligo_pair_region_coordinates;
    }
    catch{
        $self->log->error( "Failed to generate oligo pair region coordinates for gibson deletion designs:\n" . $_ );
    };

    return;
}

__PACKAGE__->meta->make_immutable;

1;

__END__
