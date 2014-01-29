package DesignCreate::CmdRole::OligoPairRegionsGibson;
## no critic(RequireUseStrict,RequireUseWarnings)
{
    $DesignCreate::CmdRole::OligoPairRegionsGibson::VERSION = '0.017';
}
## use critic


=head1 NAME

DesignCreate::Action::OligoPairRegionsGibson - Coordinates for oligo regions in gibson designs

=head1 DESCRIPTION

For given exon id and a oligo region parameters produce target region coordinates file
for each oligo pair we must find for gibson designs.

These attributes and code is specific to gibson designs, code generic to all
design types is found in DesignCreate::Role::OligoRegionCoodinates.

=cut

use Moose::Role;
use DesignCreate::Exception;
use MooseX::Types::Path::Class::MoreCoercions qw/AbsFile/;
use DesignCreate::Types qw( PositiveInt Strand DesignMethod Chromosome );
use Const::Fast;
use Try::Tiny;
use namespace::autoclean;

with qw(
DesignCreate::Role::OligoRegionCoordinates
);

const my @DESIGN_PARAMETERS => qw(
design_method
species
assembly
target_genes
five_prime_exon
three_prime_exon
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

has five_prime_exon => (
    is            => 'ro',
    isa           => 'Str',
    traits        => [ 'Getopt' ],
    documentation => 'EnsEMBL exon id for five prime exon, if targeting only one exon use this',
    required      => 1,
    cmd_flag      => 'five-prime-exon',
    cmd_aliases   => 'target-exon', # keep old name as legacy
);

has three_prime_exon => (
    is            => 'ro',
    isa           => 'Str',
    traits        => [ 'Getopt' ],
    documentation => 'EnsEMBL exon id for last exon, only used if specifying range of exons to target',
    cmd_flag      => 'three-prime-exon',
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
    default       => 1000,
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
    default       => 1000,
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
    return int( shift->region_length_ER_3F / 2 );
}

has region_length_3F => (
    is         => 'ro',
    isa        => PositiveInt,
    traits     => [ 'NoGetopt' ],
    lazy_build => 1,
);

sub _build_region_length_3F {
    return int( shift->region_length_ER_3F / 2 );
}

has region_length_5R => (
    is         => 'ro',
    isa        => PositiveInt,
    traits     => [ 'NoGetopt' ],
    lazy_build => 1,
);

sub _build_region_length_5R {
    return int( shift->region_length_5R_EF / 2 );
}

has region_length_EF => (
    is         => 'ro',
    isa        => PositiveInt,
    traits     => [ 'NoGetopt' ],
    lazy_build => 1,
);

sub _build_region_length_EF {
    return int( shift->region_length_5R_EF / 2 );
}

has target_start => (
    is         => 'rw',
    isa        => PositiveInt,
    traits     => [ 'NoGetopt' ],
 );

has target_end => (
    is         => 'rw',
    isa        => PositiveInt,
    traits     => [ 'NoGetopt' ],
);

has chr_name => (
    is         => 'rw',
    isa        => Chromosome,
    traits     => [ 'NoGetopt' ],
);

has chr_strand => (
    is         => 'rw',
    isa        => Strand,
    traits     => [ 'NoGetopt' ],
);

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
        $start = $self->exon_region_start
            - ( $self->region_offset_5F + $self->region_length_5F + $self->region_length_5R );
    }
    else {
        $start = $self->exon_region_end + 1;
    }
    $self->log->debug( "Five_prime region start: $start" );

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
        $end = $self->exon_region_end
            + ( $self->region_offset_5F + $self->region_length_5F + $self->region_length_5R );
    }
    $self->log->debug( "Five prime region end: $end" );

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
        $start = $self->exon_region_start
            - ( $self->region_offset_3R + $self->region_length_3R + $self->region_length_3F );
    }
    $self->log->debug( "Three prime region start: $start" );

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
        $end = $self->exon_region_end + ( $self->region_offset_3R + $self->region_length_3R + $self->region_length_3F );
    }
    else {
        $end = $self->exon_region_start - 1;
    }
    $self->log->debug( "Three prime region end: $end" );

    return $end;
}

=head2 get_oligo_pair_region_coordinates

Calculate following values:
target_start
target_end
chr_strand
chr_name

=cut
sub BUILD {
    my $self = shift;

    my $five_prime_exon = $self->build_exon( $self->five_prime_exon );
    $self->chr_name( $five_prime_exon->seq_region_name ) unless $self->chr_name;
    $self->chr_strand( $five_prime_exon->strand ) unless $self->chr_strand;

    my $three_prime_exon
        = $self->three_prime_exon ? $self->build_exon( $self->three_prime_exon ) : undef;

    # if there is no three prime exon then just specify target start and end
    # as the start and end of the five prime exon
    unless ( $three_prime_exon ) {
        $self->target_start( $five_prime_exon->seq_region_start );
        $self->target_end( $five_prime_exon->seq_region_end );
        return;
    }

    $self->validate_exon_targets( $five_prime_exon, $three_prime_exon );

    if ( $self->chr_strand == 1 ) {
        $self->target_start( $five_prime_exon->seq_region_start );
        $self->target_end( $three_prime_exon->seq_region_end );
    }
    else {
        $self->target_start( $three_prime_exon->seq_region_start );
        $self->target_end( $five_prime_exon->seq_region_end );
    }

    return;
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
        my $start_attr_name = $region . '_region_start';
        my $end_attr_name = $region . '_region_end';
        $self->oligo_region_coordinates->{ $region } = {
            start => $self->$start_attr_name,
            end   => $self->$end_attr_name,
        };
    }

    # in Role::OligoRegionCoordinates
    $self->create_oligo_region_coordinate_file;
    $self->update_design_attempt_record( { status => 'coordinates_calculated' } );

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

        # currently 22 is the smallest oligo we allow from primer
        DesignCreate::Exception->throw( "$oligo_type region too small: $length" )
            if $length < 22;
    }

    return;
}

=head2 build_exon

Grab a Bio::Ensembl::Exon object given a exon stable id.
Make sure exon object is in teh chromosome coordinate system.

=cut
sub build_exon {
    my ( $self, $exon_id ) = @_;
    my $exon;

    try{
        $exon = $self->exon_adaptor->fetch_by_stable_id( $exon_id );
    };

    unless ( $exon ) {
        DesignCreate::Exception->throw(
            'Unable to retrieve exon: ' . $exon_id );
    }

    # check exon is on the chromosome coordinate system
    if ( $exon->coord_system_name ne 'chromosome' ) {
        $exon = $exon->transform( 'chromosome' );
    }

    return $exon;
}

=head2 validate_exon_targets

Check exons are both on the same gene.
Check the five prime exon is before the three prime exon.

=cut
sub validate_exon_targets {
    my ( $self, $five_prime_exon, $three_prime_exon ) = @_;

    my $five_prime_exon_gene  = $self->gene_adaptor->fetch_by_exon_stable_id( $five_prime_exon->stable_id );
    my $three_prime_exon_gene = $self->gene_adaptor->fetch_by_exon_stable_id( $three_prime_exon->stable_id );

    DesignCreate::Exception->throw(
        'Exon mismatch,'
        . ' five prime exon '      . $five_prime_exon->stable_id
        . ' is linked to gene '    . $five_prime_exon_gene->stable_id
        . ' BUT three prime exon ' . $three_prime_exon->stable_id
        . ' is linked to gene  '   . $three_prime_exon_gene->stable_id
    ) if $five_prime_exon_gene->stable_id ne $three_prime_exon_gene->stable_id;

    if ( $self->chr_strand == 1 ) {
        DesignCreate::Exception->throw(
            'On +ve strand, five prime exon ' . $five_prime_exon->stable_id
            . ' start ' . $five_prime_exon->seq_region_start
            . ' is after the three prime exon ' . $three_prime_exon->stable_id
            . ' start ' . $three_prime_exon->seq_region_start
        ) if $five_prime_exon->seq_region_start > $three_prime_exon->seq_region_start;
    }
    else {
        DesignCreate::Exception->throw(
            'On -ve strand, five prime exon ' . $five_prime_exon->stable_id
            . ' start ' . $five_prime_exon->seq_region_start
            . ' is before the three prime exon ' . $three_prime_exon->stable_id
            . ' start ' . $three_prime_exon->seq_region_start
        ) if $five_prime_exon->seq_region_start < $three_prime_exon->seq_region_start;
    }

    return;
}

1;

__END__
