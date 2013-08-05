package DesignCreate::CmdRole::OligoRegionsInsDel;

=head1 NAME

DesignCreate::CmdRole::OligoRegionsInsDel -Create seq files for oligo region, insertion or deletion designs

=head1 DESCRIPTION

For given target coordinates and a oligo region parameters produce target region sequence file
for each oligo we must find for deletion or insertion designs.

These attributes and code is specific to Insertion / Deletion designs, code generic to all
design types is found in DesignCreate::Role::OligoTargetRegions.

=cut

use Moose::Role;
use DesignCreate::Types qw( DesignMethod PositiveInt Chromosome Strand );
use Const::Fast;
use namespace::autoclean;

with qw(
DesignCreate::Role::OligoRegionCoordinates
DesignCreate::Role::OligoRegionCoordinatesInsDel
DesignCreate::Role::GapOligoCoordinates
);

const my @DESIGN_PARAMETERS => qw(
target_start
target_end
region_length_U5
region_offset_U5
region_length_D3
region_offset_D3
chr_name
chr_strand
species
assembly
region_length_G5
region_offset_G5
region_length_G3
region_offset_G3
design_method
target_genes
);

has design_method => (
    is            => 'ro',
    isa           => DesignMethod,
    traits        => [ 'Getopt' ],
    required      => 1,
    documentation => 'Design type, deletion or insertion',
    cmd_flag      => 'design-method',
);

has chr_name => (
    is            => 'ro',
    isa           => Chromosome,
    traits        => [ 'Getopt' ],
    documentation => 'Name of chromosome the design target lies within',
    required      => 1,
    cmd_flag      => 'chromosome'
);

has chr_strand => (
    is            => 'ro',
    isa           => Strand,
    traits        => [ 'Getopt' ],
    documentation => 'The strand the design target lies on',
    required      => 1,
    cmd_flag      => 'strand'
);

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

sub get_oligo_region_coordinates {
    my $self = shift;
    $self->add_design_parameters( \@DESIGN_PARAMETERS );

    # In DesignCreate::Role::OligoRegionCoordinatesInsDel
    $self->_get_oligo_region_coordinates;

    return;
}

1;

__END__
