package DesignCreate::CmdRole::OligoRegionsDelExon;
## no critic(RequireUseStrict,RequireUseWarnings)
{
    $DesignCreate::CmdRole::OligoRegionsDelExon::VERSION = '0.015';
}
## use critic


=head1 NAME

DesignCreate::CmdRole::OligoRegionsDelExon - Get coordinate for a Deletion design on a exon id

=head1 DESCRIPTION

For a given EnsEMBL exon produce a oligo region coordiantes file for each oligo we want.

These attributes and code is specific to exon deletion designs, code generic to all
design types is found in DesignCreate::Role::OligoRegionCoordinates.

=cut

use Moose::Role;
use DesignCreate::Types qw( DesignMethod PositiveInt Chromosome Strand );
use Const::Fast;
use Try::Tiny;
use namespace::autoclean;

with qw(
DesignCreate::Role::OligoRegionCoordinates
DesignCreate::Role::GapOligoCoordinates
DesignCreate::Role::OligoRegionCoordinatesInsDel
);

const my @DESIGN_PARAMETERS => qw(
target_genes
target_exon
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
);

has design_method => (
    is      => 'ro',
    isa     => DesignMethod,
    traits  => [ 'NoGetopt' ],
    default => 'deletion'
);

has target_exon => (
    is            => 'ro',
    isa           => 'Str',
    traits        => [ 'Getopt' ],
    documentation => 'EnsEMBL exon id we are targeting',
    required      => 1,
    cmd_flag      => 'target-exon'
);

has exon => (
    is         => 'ro',
    isa        => 'Bio::EnsEMBL::Exon',
    traits     => [ 'NoGetopt' ],
    lazy_build => 1,
);

sub _build_exon {
    my $self = shift;

    my $exon = try{ $self->exon_adaptor->fetch_by_stable_id( $self->target_exon ) };
    unless ( $exon ) {
        DesignCreate::Exception->throw( 'Unable to retrieve exon ' . $self->target_exon);
    }

    # check exon is on the chromosome coordinate system
    if ( $exon->coord_system_name ne 'chromosome' ) {
        $exon = $exon->transform( 'chromosome' );
    }

    return $exon;
}

has target_start => (
    is         => 'ro',
    isa        => PositiveInt,
    traits     => [ 'NoGetopt' ],
    lazy_build => 1,
);

sub _build_target_start {
    my $self = shift;

    return $self->exon->start;
}

has target_end => (
    is         => 'ro',
    isa        => PositiveInt,
    traits     => [ 'NoGetopt' ],
    lazy_build => 1,
);

sub _build_target_end {
    my $self = shift;

    return $self->exon->end;
}

has chr_name => (
    is         => 'ro',
    isa        => Chromosome,
    traits     => [ 'NoGetopt' ],
    lazy_build => 1,
);

sub _build_chr_name {
    my $self = shift;

    return $self->exon->seq_region_name;
}

has chr_strand => (
    is         => 'ro',
    isa        => Strand,
    traits     => [ 'NoGetopt' ],
    lazy_build => 1,
);

sub _build_chr_strand {
    my $self = shift;

    return $self->exon->strand;
}

#
# Gap Oligo Parameter attributes in DesignCreate::Role::OligoRegionCoordinates
#

sub get_oligo_region_coordinates {
    my $self = shift;
    $self->add_design_parameters( \@DESIGN_PARAMETERS );

    # In DesignCreate::Role::OligoRegionCoordinatesInsDel
    $self->_get_oligo_region_coordinates;

    return;
}

1;

__END__
