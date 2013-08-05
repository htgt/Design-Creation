package DesignCreate::CmdRole::OligoRegionsDelExon;

=head1 NAME

DesignCreate::CmdRole::OligoRegionsDelExon - Get coordinate for a Deletion design on a exon id

=head1 DESCRIPTION

TODO

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
U5_region_length
U5_region_offset
D3_region_length
D3_region_offset
chr_name
chr_strand
species
assembly
G5_region_length
G5_region_offset
G3_region_length
G3_region_offset
design_method
);

has design_method => (
    is      => 'ro',
    isa     => DesignMethod,
    traits  => [ 'NoGetopt' ],
    default => 'deletion'
);

# TODO user still specifies target-gene
# should be find this ourselves, or maybe do some checks?
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
