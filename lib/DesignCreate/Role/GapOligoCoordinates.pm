package DesignCreate::Role::GapOligoCoordinates;

=head1 NAME

DesignCreate::Role::GapOligoCoordinates

=head1 DESCRIPTION

Gap oligo region parameters, common to most design types

=cut

use Moose::Role;
use DesignCreate::Types qw( PositiveInt );
use namespace::autoclean;

has G5_region_length => (
    is            => 'ro',
    isa           => PositiveInt,
    traits        => [ 'Getopt' ],
    default       => 1000,
    documentation => 'Length of G5 oligo candidate region',
    cmd_flag      => 'g5-region-length'
);

has G5_region_offset => (
    is            => 'ro',
    isa           => PositiveInt,
    traits        => [ 'Getopt' ],
    default       => 4000,
    documentation => 'Offset from target region of G5 oligo candidate region',
    cmd_flag      => 'g5-region-offset'
);

has G3_region_length => (
    is            => 'ro',
    isa           => PositiveInt,
    traits        => [ 'Getopt' ],
    default       => 1000,
    documentation => 'Length of G3 oligo candidate region',
    cmd_flag      => 'g3-region-length'
);

has G3_region_offset => (
    is            => 'ro',
    isa           => PositiveInt,
    traits        => [ 'Getopt' ],
    default       => 4000,
    documentation => 'Offset from target region of G3 oligo candidate region',
    cmd_flag      => 'g3-region-offset'
);

1;

__END__
