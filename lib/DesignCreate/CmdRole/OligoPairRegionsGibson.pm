package DesignCreate::CmdRole::OligoPairRegionsGibson;

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
use DesignCreate::Types qw( PositiveInt DesignMethod );
use DesignCreate::Constants qw( %GIBSON_PRIMER_REGIONS );
use Const::Fast;
use Try::Tiny;
use namespace::autoclean;

with qw( DesignCreate::Role::OligoRegionCoordinates );

const my @DESIGN_PARAMETERS => qw(
design_method
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

has exon_region_start => (
    is         => 'rw',
    isa        => PositiveInt,
    traits     => [ 'NoGetopt' ],
);

has exon_region_end => (
    is         => 'rw',
    isa        => PositiveInt,
    traits     => [ 'NoGetopt' ],
);

has five_prime_region_start => (
    is         => 'rw',
    isa        => PositiveInt,
    traits     => [ 'NoGetopt' ],
);

has five_prime_region_end => (
    is         => 'rw',
    isa        => PositiveInt,
    traits     => [ 'NoGetopt' ],
);

has three_prime_region_start => (
    is         => 'rw',
    isa        => PositiveInt,
    traits     => [ 'NoGetopt' ],
);

has three_prime_region_end => (
    is         => 'rw',
    isa        => PositiveInt,
    traits     => [ 'NoGetopt' ],
);

=head2 get_oligo_pair_region_coordinates

Get coordinates for the three oligo pair regions:
exon
five_prime
three_prime

=cut
sub get_oligo_pair_region_coordinates {
    my ( $self, $opts, $args ) = @_;

    $self->add_design_parameters( \@DESIGN_PARAMETERS );

    # check target coordinate have been set, if not die
    for my $data_type ( qw( target_start target_end chr_name chr_strand ) ) {
        DesignCreate::Exception->throw( "No target value for: $data_type" )
            unless $self->have_target_data( $data_type );
    }

    $self->calculate_pair_region_coordinates();
    # In role DesignCreate::Role::OligoRegionCoodinatesGibson
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

    # In role DesignCreate::Role::OligoRegionCoodinatesGibson
    $self->create_oligo_region_coordinate_file;
    $self->update_design_attempt_record( { status => 'coordinates_calculated' } );

    return;
}

=head2 calculate_pair_region_coordinates

Calculate start and end coordinates of the oligo pair regions

=cut
sub calculate_pair_region_coordinates {
    my ( $self ) = @_;

    my $target_start = $self->get_target_data( 'target_start' );
    my $target_end   = $self->get_target_data( 'target_end' );
    my $strand       = $self->get_target_data( 'chr_strand' );
    if ( $strand == 1 ) {
        # exon region
        $self->exon_region_start( $target_start
                - ( $self->region_offset_5R_EF + int( $self->region_length_5R_EF / 2 ) ) );
        $self->exon_region_end( $target_end
                + ( $self->region_offset_ER_3F + int( $self->region_length_ER_3F / 2 ) ) );

        # five prime region
        $self->five_prime_region_start( $self->exon_region_start
                - ( $self->region_offset_5F + $self->region_length_5F + $self->region_length_5R ) );
        $self->five_prime_region_end( $self->exon_region_start - 1);

        # three prime region
        $self->three_prime_region_start( $self->exon_region_end + 1);
        $self->three_prime_region_end( $self->exon_region_end
                + ( $self->region_offset_3R + $self->region_length_3R + $self->region_length_3F ) );
    }
    else {
        # exon region
        $self->exon_region_start( $target_start
                - ( $self->region_offset_ER_3F + int( $self->region_length_ER_3F / 2 ) ) );
        $self->exon_region_end( $target_end
                + ( $self->region_offset_5R_EF + int( $self->region_length_5R_EF / 2 ) ) );

        # five prime region
        $self->five_prime_region_start( $self->exon_region_end + 1 );
        $self->five_prime_region_end( $self->exon_region_end
                + ( $self->region_offset_5F + $self->region_length_5F + $self->region_length_5R ) );

        # three prime region
        $self->three_prime_region_start( $self->exon_region_start
                - ( $self->region_offset_3R + $self->region_length_3R + $self->region_length_3F ) );
        $self->three_prime_region_end( $self->exon_region_start - 1 );
    }
    $self->log->info('Calculated oligo region coordinates for design');

    return;
}

1;

__END__
