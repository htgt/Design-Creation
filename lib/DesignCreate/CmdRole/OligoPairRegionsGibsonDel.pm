package DesignCreate::CmdRole::OligoPairRegionsGibsonDel;

=head1 NAME

DesignCreate::Action::OligoPairRegionsGibsonDel - Coordinates for oligo regions in deletion gibson designs

=head1 DESCRIPTION

For given exon id and a oligo region parameters produce target region coordinates file
for each oligo pair we must find for deletion gibson designs.

These attributes and code is specific to deletion gibson designs, code generic to all
design types is found in DesignCreate::Role::OligoRegionCoodinates.

=cut

use Moose::Role;
use DesignCreate::Exception;
use MooseX::Types::Path::Class::MoreCoercions qw/AbsFile/;
use DesignCreate::Types qw( PositiveInt Strand DesignMethod Chromosome );
use DesignCreate::Constants qw( %GIBSON_PRIMER_REGIONS );
use Const::Fast;
use Try::Tiny;
use namespace::autoclean;

with qw(
DesignCreate::Role::OligoRegionCoordinates
DesignCreate::Role::OligoRegionCoordinatesGibson
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
region_length_5R
region_offset_5R
region_length_3F
region_offset_3F
region_length_3R
region_offset_3R
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
    default => 'gibson-deletion'
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
    documentation => 'Offset from 5R oligo candidate region of 5F oligo candidate region',
    cmd_flag      => 'region-offset-5f'
);

has region_length_5R => (
    is            => 'ro',
    isa           => PositiveInt,
    traits        => [ 'Getopt' ],
    default       => 100,
    documentation => 'Length of 5R oligo candidate region',
    cmd_flag      => 'region-length-5r'
);

has region_offset_5R => (
    is            => 'ro',
    isa           => PositiveInt,
    traits        => [ 'Getopt' ],
    default       => 200,
    documentation => 'Offset from exon of 5R oligo candidate region',
    cmd_flag      => 'region-offset-5r'
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
    documentation => 'Offset from 3F oligo candidate region of 3R oligo candidate region',
    cmd_flag      => 'region-offset-3r'
);

has region_length_3F => (
    is            => 'ro',
    isa           => PositiveInt,
    traits        => [ 'Getopt' ],
    default       => 100,
    documentation => 'Length of 3F oligo candidate region',
    cmd_flag      => 'region-length-3f'
);

has region_offset_3F => (
    is            => 'ro',
    isa           => PositiveInt,
    traits        => [ 'Getopt' ],
    default       => 100,
    documentation => 'Offset from exon of 3F oligo candidate region',
    cmd_flag      => 'region-offset-3f'
);

#
# Following values can be deduced from already given design parameters
#
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
        $start = $self->five_prime_region_end
               - ( $self->region_offset_5F + $self->region_length_5F + $self->region_length_5R );
    }
    else {
        $start = $self->target_end + $self->region_offset_5R;
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
        $end = $self->target_start - $self->region_offset_5R;
    }
    else {
        $end = $self->five_prime_region_start
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
        $start = $self->target_end + $self->region_offset_3F;
    }
    else {
        $start = $self->three_prime_region_end
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
        $end = $self->three_prime_region_start
             + ( $self->region_offset_3R + $self->region_length_3R + $self->region_length_3F );
    }
    else {
        $end = $self->target_start - $self->region_offset_3F;
    }
    $self->log->debug( "Three prime region end: $end" );

    return $end;
}

=head2 get_oligo_pair_region_coordinates

Get coordinates for the two oligo pair regions:
five_prime
three_prime

=cut
sub get_oligo_pair_region_coordinates {
    my ( $self, $opts, $args ) = @_;

    # in Role::OligoRegionCoordinatesGibson
    $self->calculate_target_region_coordinates;

    $self->add_design_parameters( \@DESIGN_PARAMETERS );

    # in Role::OligoRegionCoordinatesGibson
    $self->check_oligo_region_sizes;

    my $design_method = $self->design_param( 'design_method' );
    for my $region ( keys %{ $GIBSON_PRIMER_REGIONS{$design_method} } ) {
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


1;

__END__
