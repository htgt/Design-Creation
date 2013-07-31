package DesignCreate::CmdRole::OligoPairRegionsGibson;

=head1 NAME

DesignCreate::Action::OligoPairRegionsGibson - Coordinates for oligo regions in gibson designs

=head1 DESCRIPTION


=cut

use Moose::Role;
use DesignCreate::Exception;
use MooseX::Types::Path::Class::MoreCoercions qw/AbsFile/;
use DesignCreate::Types qw( PositiveInt Strand DesignMethod Chromosome );
use Const::Fast;
use Try::Tiny;
use namespace::autoclean;

with qw(
DesignCreate::Role::EnsEMBL
DesignCreate::Role::OligoRegionCoordinates
);

const my @DESIGN_PARAMETERS => qw(
design_method
species
assembly
target_genes
target_exon
target_start
target_end
chr_name
chr_strand
region_length_5F
region_offset_5F
region_length_3R
region_offset_3R
region_length_5R_EF
region_offset_5R_EF
region_length_ER_3F
region_offset_ER_3F
region_length_5R
region_length_EF
region_length_ER
region_length_3F
);

has target_exon => (
    is            => 'ro',
    isa           => 'Str',
    traits        => [ 'Getopt' ],
    documentation => 'EnsEMBL exon id we are targeting',
    required      => 1,
    cmd_flag      => 'target-exon'
);

has design_method => (
    is      => 'ro',
    isa     => DesignMethod,
    traits  => [ 'NoGetopt' ],
    default => 'gibson'
);

has region_length_5F => (
    is            => 'ro',
    isa           => PositiveInt,
    traits        => [ 'Getopt' ],
    default       => 500,
    documentation => 'Length of 5F oligo candidate region',
    cmd_flag      => 'region-length-5f'
);

has region_offset_5F => (
    is            => 'ro',
    isa           => PositiveInt,
    traits        => [ 'Getopt' ],
    default       => 1400,
    documentation => 'Offset from target region of 5F oligo candidate region',
    cmd_flag      => 'region-offset-5f'
);

has region_length_3R => (
    is            => 'ro',
    isa           => PositiveInt,
    traits        => [ 'Getopt' ],
    default       => 500,
    documentation => 'Length of 3R oligo candidate region',
    cmd_flag      => 'region-length-3r'
);

has region_offset_3R => (
    is            => 'ro',
    isa           => PositiveInt,
    traits        => [ 'Getopt' ],
    default       => 1300,
    documentation => 'Offset from target region of 3R oligo candidate region',
    cmd_flag      => 'region-offset-3r'
);

has region_length_5R_EF => (
    is            => 'ro',
    isa           => PositiveInt,
    traits        => [ 'Getopt' ],
    default       => 200,
    documentation => 'Length of 5R / EF oligo candidate region block, will be split in two',
    cmd_flag      => 'region-length-5r-ef'
);

has region_offset_5R_EF => (
    is            => 'ro',
    isa           => PositiveInt,
    traits        => [ 'Getopt' ],
    default       => 200,
    documentation => 'Offset from target region of 5R / EF oligo candidate region block',
    cmd_flag      => 'region-offset-5r-ef'
);

has region_length_ER_3F => (
    is            => 'ro',
    isa           => PositiveInt,
    traits        => [ 'Getopt' ],
    default       => 200,
    documentation => 'Length of ER / 3F oligo candidate region block, will be split in two',
    cmd_flag      => 'region-length-er-3f'
);

has region_offset_ER_3F => (
    is            => 'ro',
    isa           => PositiveInt,
    traits        => [ 'Getopt' ],
    default       => 100,
    documentation => 'Offset from target region of ER / 3F oligo candidate region block',
    cmd_flag      => 'region-offset-er-3f'
);

#
# Following values can be deduced from already given design parameters
#
has region_length_ER => (
    is         => 'ro',
    isa        => PositiveInt,
    traits     => [ 'NoGetopt' ],
    lazy_build => 1,
);

sub _build_region_length_ER {
    int( shift->region_length_ER_3F / 2 );
}

has region_length_3F => (
    is         => 'ro',
    isa        => PositiveInt,
    traits     => [ 'NoGetopt' ],
    lazy_build => 1,
);

sub _build_region_length_3F {
    int( shift->region_length_ER_3F / 2 );
}

has region_length_5R => (
    is         => 'ro',
    isa        => PositiveInt,
    traits     => [ 'NoGetopt' ],
    lazy_build => 1,
);

sub _build_region_length_5R {
    int( shift->region_length_5R_EF / 2 );
}

has region_length_EF => (
    is         => 'ro',
    isa        => PositiveInt,
    traits     => [ 'NoGetopt' ],
    lazy_build => 1,
);

sub _build_region_length_EF {
    int( shift->region_length_5R_EF / 2 );
}

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
    shift->exon->seq_region_start;
}

has target_end => (
    is         => 'ro',
    isa        => PositiveInt,
    traits     => [ 'NoGetopt' ],
    lazy_build => 1,
);

sub _build_target_end {
    shift->exon->seq_region_end;
}

has chr_name => (
    is         => 'ro',
    isa        => Chromosome,
    traits     => [ 'NoGetopt' ],
    lazy_build => 1,
);

sub _build_chr_name {
    shift->exon->seq_region_name;
}

has chr_strand => (
    is         => 'ro',
    isa        => Strand,
    traits     => [ 'NoGetopt' ],
    lazy_build => 1,
);

sub _build_chr_strand {
    shift->exon->strand;
}

has exon_region_start => (
    is         => 'ro',
    isa        => PositiveInt,
    traits     => [ 'NoGetopt' ],
    lazy_build => 1,
);

sub _build_exon_region_start {
    my $self = shift;
    my $start;

    if ( $self->chr_strand == 1 ) {
        $start = $self->target_start
            - ( $self->region_offset_5R_EF + int( $self->region_length_5R_EF / 2 ) );
    }
    else {
        $start = $self->target_start
            - ( $self->region_offset_ER_3F + int( $self->region_length_ER_3F / 2 ) );
    }
    $self->log->debug( "Exon region start: $start" );

    return $start;
}

has exon_region_end => (
    is         => 'ro',
    isa        => PositiveInt,
    traits     => [ 'NoGetopt' ],
    lazy_build => 1,
);

sub _build_exon_region_end {
    my $self = shift;
    my $end;

    if ( $self->chr_strand == 1 ) {
        $end = $self->target_end + ( $self->region_offset_ER_3F + int( $self->region_length_ER_3F / 2 ) );
    }
    else {
        $end = $self->target_end + ( $self->region_offset_5R_EF + int( $self->region_length_5R_EF / 2 ) );
    }
    $self->log->debug( "Exon region end: $end" );

    return $end;
}

has five_prime_region_start => (
    is         => 'ro',
    isa        => PositiveInt,
    traits     => [ 'NoGetopt' ],
    lazy_build => 1,
);

sub _build_five_prime_region_start {
    my $self = shift;
    my $start;

    if ( $self->chr_strand == 1 ) {
        $start = $self->target_start - ( $self->region_offset_5F + $self->region_length_5F );
    }
    else {
        $start = $self->exon_region_end + 1;
    }
    $self->log->debug( "Exon region start: $start" );

    return $start;
}

has five_prime_region_end => (
    is         => 'ro',
    isa        => PositiveInt,
    traits     => [ 'NoGetopt' ],
    lazy_build => 1,
);

sub _build_five_prime_region_end {
    my $self = shift;
    my $end;

    if ( $self->chr_strand == 1 ) {
        $end = $self->exon_region_start - 1;
    }
    else {
        $end = $self->target_end + ( $self->region_offset_5F + $self->region_length_5F );
    }
    $self->log->debug( "Exon region end: $end" );

    return $end;
}

has three_prime_region_start => (
    is         => 'ro',
    isa        => PositiveInt,
    traits     => [ 'NoGetopt' ],
    lazy_build => 1,
);

sub _build_three_prime_region_start {
    my $self = shift;
    my $start;

    if ( $self->chr_strand == 1 ) {
        $start = $self->exon_region_end + 1;
    }
    else {
        $start = $self->target_start - ( $self->region_offset_3R + $self->region_length_3R );
    }
    $self->log->debug( "Exon region start: $start" );

    return $start;
}

has three_prime_region_end => (
    is         => 'ro',
    isa        => PositiveInt,
    traits     => [ 'NoGetopt' ],
    lazy_build => 1,
);

sub _build_three_prime_region_end {
    my $self = shift;
    my $end;

    if ( $self->chr_strand == 1 ) {
        $end = $self->target_end + ( $self->region_offset_3R + $self->region_length_3R );
    }
    else {
        $end = $self->exon_region_start - 1;
    }
    $self->log->debug( "Exon region end: $end" );

    return $end;
}

=head2 get_oligo_pair_region_coordinates

Get coordinates for the three oligo pair regions:
exon
five_prime
three_prime

=cut
sub get_oligo_pair_region_coordinates {
    my ( $self, $opts, $args ) = @_;

    $self->add_design_parameters( \@DESIGN_PARAMETERS );

    $self->check_oligo_region_sizes;

    for my $region ( qw( exon five_prime three_prime ) ) {
        my ( $start, $end ) = $self->check_region_coordinates( $region );
        $self->oligo_region_coordinates->{ $region } = {
            start => $start,
            end   => $end,
        };
    }

    # in Role::OligoRegionCoordinates
    $self->create_oligo_region_coordinate_file;

    return;
}

=head2 check_oligo_region_sizes

Check size of region we search for oligos in is big enough

=cut
sub check_oligo_region_sizes {
    my ( $self ) = @_;

    for my $oligo_type ( $self->expected_oligos ) {
        my $length_attr =  'region_length_' . $oligo_type;
        my $length = $self->$length_attr;

        # currently 22 is the smaller oligo we allow from primer
        DesignCreate::Exception->throw( "$oligo_type region too small: $length" )
            if $length < 22;
    }

    return;
}

=head2 check_region_coordinates

Check region coordinates and sizes.
Return start and end values

=cut
sub check_region_coordinates {
    my ( $self, $region ) = @_;

    my $start_attr_name = $region . '_region_start';
    my $end_attr_name = $region . '_region_end';
    my $start = $self->$start_attr_name;
    my $end = $self->$end_attr_name;

    DesignCreate::Exception->throw(
        "Start greater than or equal to end for $region region coordinates: $start - $end"
    ) if $start >= $end;

    return ( $start, $end );
}

1;

__END__
