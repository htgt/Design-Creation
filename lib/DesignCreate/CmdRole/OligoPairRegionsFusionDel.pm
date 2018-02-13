package DesignCreate::CmdRole::OligoPairRegionsFusionDel;
## no critic(RequireUseStrict,RequireUseWarnings)
{
    $DesignCreate::CmdRole::OligoPairRegionsFusionDel::VERSION = '0.046';
}
## use critic


=head1 NAME

DesignCreate::Action::OligoPairRegionsFusionDel - Coordinates for oligo regions in deletion fusion designs

=head1 DESCRIPTION

For given exon id and a oligo region parameters produce target region coordinates file
for each oligo pair we must find for deletion fusion designs.

These attributes and code is specific to deletion fusion designs, code generic to all
design types is found in DesignCreate::Role::OligoRegionCoodinates.

=cut

use Moose::Role;
use DesignCreate::Exception;
use DesignCreate::Types qw( PositiveInt DesignMethod );
use DesignCreate::Constants qw( %FUSION_PRIMER_REGIONS );
use Const::Fast;
use Try::Tiny;
use namespace::autoclean;

with qw( DesignCreate::Role::OligoRegionCoordinates );

const my @DESIGN_PARAMETERS => qw(
design_method
region_length_f5F
region_offset_f5F
region_length_U5
region_offset_U5
region_length_D3
region_offset_D3
region_length_f3R
region_offset_f3R
);

has design_method => (
    is      => 'ro',
    isa     => DesignMethod,
    traits  => [ 'NoGetopt' ],
    default => 'fusion-deletion'
);

has region_length_f5F => (
    is            => 'ro',
    isa           => PositiveInt,
    traits        => [ 'Getopt' ],
    default       => 500,
    documentation => 'Length of f5F oligo candidate region',
    cmd_flag      => 'region-length-f5f'
);

has region_offset_f5F => (
    is            => 'ro',
    isa           => PositiveInt,
    traits        => [ 'Getopt' ],
    default       => 1000,
    documentation => 'Offset from U5 oligo candidate region of f5F oligo candidate region',
    cmd_flag      => 'region-offset-f5f'
);

has region_length_U5 => (
    is            => 'ro',
    isa           => PositiveInt,
    traits        => [ 'Getopt' ],
    default       => 100,
    documentation => 'Length of U5 oligo candidate region',
    cmd_flag      => 'region-length-u5'
);

has region_offset_U5 => (
    is            => 'ro',
    isa           => PositiveInt,
    traits        => [ 'Getopt' ],
    default       => 1,
    documentation => 'Offset from exon of U5 oligo candidate region',
    cmd_flag      => 'region-offset-u5'
);

has region_length_f3R => (
    is            => 'ro',
    isa           => PositiveInt,
    traits        => [ 'Getopt' ],
    default       => 500,
    documentation => 'Length of f3R oligo candidate region',
    cmd_flag      => 'region-length-f3r'
);

has region_offset_f3R => (
    is            => 'ro',
    isa           => PositiveInt,
    traits        => [ 'Getopt' ],
    default       => 1000,
    documentation => 'Offset from D3 oligo candidate region of f3R oligo candidate region',
    cmd_flag      => 'region-offset-f3r'
);

has region_length_D3 => (
    is            => 'ro',
    isa           => PositiveInt,
    traits        => [ 'Getopt' ],
    default       => 100,
    documentation => 'Length of D3 oligo candidate region',
    cmd_flag      => 'region-length-d3'
);

has region_offset_D3 => (
    is            => 'ro',
    isa           => PositiveInt,
    traits        => [ 'Getopt' ],
    default       => 1,
    documentation => 'Offset from exon of D3 oligo candidate region',
    cmd_flag      => 'region-offset-d3'
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

Get coordinates for the two oligo pair regions:
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
    # In role DesignCreate::Role::OligoRegionCoodinatesFusion
    $self->check_oligo_region_sizes;

    my $design_method = $self->design_param( 'design_method' );

    for my $region ( keys %{ $FUSION_PRIMER_REGIONS{$design_method} } ) {
        my $start_attr_name = $region . '_region_start';
        my $end_attr_name = $region . '_region_end';
        $self->oligo_region_coordinates->{ $region } = {
            start => $self->$start_attr_name,
            end   => $self->$end_attr_name,
        };
    }

    # In role DesignCreate::Role::OligoRegionCoodinates
    $self->create_oligo_region_coordinate_file;
    $self->set_design_attempt_candidate_regions;
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
        # five prime region
        $self->five_prime_region_end( $target_start - $self->region_offset_U5 );
        $self->five_prime_region_start( $self->five_prime_region_end
               - ( $self->region_offset_f5F + $self->region_length_f5F + $self->region_length_U5 ) );

        # three prime region
        $self->three_prime_region_start( $target_end + $self->region_offset_D3 );
        $self->three_prime_region_end( $self->three_prime_region_start
             + ( $self->region_offset_f3R + $self->region_length_f3R + $self->region_length_D3 ) );
    }
    else {
        # five prime region
        $self->five_prime_region_start( $target_end + $self->region_offset_U5 );
        $self->five_prime_region_end( $self->five_prime_region_start
             + ( $self->region_offset_f5F + $self->region_length_f5F + $self->region_length_U5 ) );

        # three prime region
        $self->three_prime_region_end( $target_start - $self->region_offset_D3 );
        $self->three_prime_region_start( $self->three_prime_region_end
               - ( $self->region_offset_f3R + $self->region_length_f3R + $self->region_length_D3 ) );

    }

    $self->log->info('Calculated oligo region coordinates for design');

    return;
}

1;

__END__
