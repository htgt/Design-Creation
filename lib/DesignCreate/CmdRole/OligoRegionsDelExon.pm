package DesignCreate::CmdRole::OligoRegionsDelExon;
## no critic(RequireUseStrict,RequireUseWarnings)
{
    $DesignCreate::CmdRole::OligoRegionsDelExon::VERSION = '0.005';
}
## use critic


=head1 NAME

DesignCreate::CmdRole::OligoRegionsDelExon - Get coordinate for a Deletion design on a exon id

=head1 DESCRIPTION

TODO

=cut

use Moose::Role;
use DesignCreate::Exception;
use DesignCreate::Types qw( DesignMethod PositiveInt NaturalNumber Chromosome Strand );
use Const::Fast;
use Try::Tiny;
use namespace::autoclean;

with qw(
DesignCreate::Role::OligoRegionCoordinates
DesignCreate::Role::EnsEMBL
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
    my $exon;

    try {
        $exon = $self->exon_adaptor->fetch_by_stable_id( $self->target_exon );
    }
    catch{
        DesignCreate::Exception->throw( 'Unable to retrieve exon ' . $self->target_exon . ', error: ' . $_ );
    };

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
# Oligo Region Parameters
# Gap Oligo Parameter attributes in DesignCreate::Role::OligoTargetRegions
#

has U5_region_length => (
    is            => 'ro',
    isa           => PositiveInt,
    traits        => [ 'Getopt' ],
    default       => 200,
    documentation => 'Length of U5 oligo candidate region',
    cmd_flag      => 'u5-region-length'
);

has U5_region_offset => (
    is            => 'ro',
    isa           => NaturalNumber,
    traits        => [ 'Getopt' ],
    default       => 0,
    documentation => 'Offset from target region of U5 oligo candidate region',
    cmd_flag      => 'u5-region-offset'
);

has D3_region_length => (
    is            => 'ro',
    isa           => PositiveInt,
    traits        => [ 'Getopt' ],
    default       => 200,
    documentation => 'Length of D3 oligo candidate region',
    cmd_flag      => 'd3-region-length'
);

has D3_region_offset => (
    is            => 'ro',
    isa           => NaturalNumber,
    traits        => [ 'Getopt' ],
    default       => 0,
    documentation => 'Offset from target region of D3 oligo candidate region',
    cmd_flag      => 'd3-region-offset'
);

sub get_oligo_region_coordinates {
    my $self = shift;

    $self->add_design_parameters( \@DESIGN_PARAMETERS );
    DesignCreate::Exception->throw(
        "Target start " . $self->target_start . ", greater than target end " . $self->target_end
    ) if $self->target_start > $self->target_end;

    $self->_get_oligo_region_coordinates;
    return;
}

# work out coordinates for ins / del designs
sub coordinates_for_oligo {
    my ( $self, $oligo ) = @_;
    my ( $start, $end );

    my $offset = $self->get_oligo_region_offset( $oligo );
    my $length = $self->get_oligo_region_length( $oligo );

    if ( $self->chr_strand == 1 ) {
        if ( $oligo =~ /5$/ ) {
            $start = $self->target_start - ( $offset + $length );
            $end   = $self->target_start - ( $offset + 1 );
        }
        elsif ( $oligo =~ /3$/ ) {
            $start = $self->target_end + ( $offset + 1 );
            $end   = $self->target_end + ( $offset + $length );
        }
    }
    else {
        if ( $oligo =~ /5$/ ) {
            $start = $self->target_end + ( $offset + 1 );
            $end   = $self->target_end + ( $offset + $length );
        }
        elsif ( $oligo =~ /3$/ ) {
            $start = $self->target_start - ( $offset + $length );
            $end   = $self->target_start - ( $offset + 1 );
        }
    }

    DesignCreate::Exception->throw( "Start $start, greater than or equal to end $end for oligo $oligo" )
        if $start >= $end;

    return( $start, $end );
}

1;

__END__
