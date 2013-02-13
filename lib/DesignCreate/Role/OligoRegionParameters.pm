package DesignCreate::Role::OligoRegionParameters;

=head1 NAME

DesignCreate::Role::Deletion

=head1 DESCRIPTION

Oligo Target Region attributes for deletion type designs

=cut

use Moose::Role;
use DesignCreate::Types qw( PositiveInt NaturalNumber );
use namespace::autoclean;

# TODO add cmd_alias and documentation

has target_start => (
    is            => 'ro',
    isa           => PositiveInt,
    traits        => [ 'Getopt' ],
    documentation => 'Start coordinate of target region',
    required      => 1,
    cmd_flag      => 'target-start'
);

has target_end => (
    is            => 'ro',
    isa           => PositiveInt,
    traits        => [ 'Getopt' ],
    documentation => 'End coordinate of target region',
    required      => 1,
    cmd_flag      => 'target-end'
);

has G5_region_length => (
    is      => 'ro',
    isa     => PositiveInt,
    traits  => [ 'Getopt' ],
    default => 1000,
);

has G5_region_offset => (
    is      => 'ro',
    isa     => PositiveInt,
    traits  => [ 'Getopt' ],
    default => 4000,
);

has U5_region_length => (
    is      => 'ro',
    isa     => PositiveInt,
    traits  => [ 'Getopt' ],
    default => 200,
);

has U5_region_offset => (
    is      => 'ro',
    isa     => NaturalNumber,
    traits  => [ 'Getopt' ],
    default => 0,
);

has U3_region_length => (
    is      => 'ro',
    isa     => PositiveInt,
    traits  => [ 'Getopt' ],
    default => 200,
);

has U3_region_offset => (
    is      => 'ro',
    isa     => NaturalNumber,
    traits  => [ 'Getopt' ],
    default => 0,
);

has D5_region_length => (
    is      => 'ro',
    isa     => PositiveInt,
    traits  => [ 'Getopt' ],
    default => 200,
);

has D5_region_offset => (
    is      => 'ro',
    isa     => NaturalNumber,
    traits  => [ 'Getopt' ],
    default => 0,
);

has D3_region_length => (
    is      => 'ro',
    isa     => PositiveInt,
    traits  => [ 'Getopt' ],
    default => 200,
);

has D3_region_offset => (
    is      => 'ro',
    isa     => NaturalNumber,
    traits  => [ 'Getopt' ],
    default => 0,
);

has G3_region_length => (
    is      => 'ro',
    isa     => PositiveInt,
    traits  => [ 'Getopt' ],
    default => 1000,
);

has G3_region_offset => (
    is      => 'ro',
    isa     => PositiveInt,
    traits  => [ 'Getopt' ],
    default => 4000,
);

1;

__END__
