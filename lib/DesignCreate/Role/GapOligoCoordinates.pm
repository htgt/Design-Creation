package DesignCreate::Role::GapOligoCoordinates;
## no critic(RequireUseStrict,RequireUseWarnings)
{
    $DesignCreate::Role::GapOligoCoordinates::VERSION = '0.013';
}
## use critic


=head1 NAME

DesignCreate::Role::GapOligoCoordinates

=head1 DESCRIPTION

Gap oligo region parameters, common to most design types

=cut

use Moose::Role;
use DesignCreate::Types qw( PositiveInt );
use namespace::autoclean;

has region_length_G5 => (
    is            => 'ro',
    isa           => PositiveInt,
    traits        => [ 'Getopt' ],
    default       => 1000,
    documentation => 'Length of G5 oligo candidate region',
    cmd_flag      => 'region-length-g5'
);

has region_offset_G5 => (
    is            => 'ro',
    isa           => PositiveInt,
    traits        => [ 'Getopt' ],
    default       => 4000,
    documentation => 'Offset from target region of G5 oligo candidate region',
    cmd_flag      => 'region-offset-g5'
);

has region_length_G3 => (
    is            => 'ro',
    isa           => PositiveInt,
    traits        => [ 'Getopt' ],
    default       => 1000,
    documentation => 'Length of G3 oligo candidate region',
    cmd_flag      => 'region-length-g3'
);

has region_offset_G3 => (
    is            => 'ro',
    isa           => PositiveInt,
    traits        => [ 'Getopt' ],
    default       => 4000,
    documentation => 'Offset from target region of G3 oligo candidate region',
    cmd_flag      => 'region-offset-g3'
);

1;

__END__
