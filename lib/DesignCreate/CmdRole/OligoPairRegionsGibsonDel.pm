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
use DesignCreate::Types qw( PositiveInt DesignMethod );
use DesignCreate::Constants qw( %GIBSON_PRIMER_REGIONS );
use Const::Fast;
use Try::Tiny;
use namespace::autoclean;

with qw( DesignCreate::Role::OligoRegionCoordinatesGibson );

const my @DESIGN_PARAMETERS => qw(
design_method
region_length_5F
region_offset_5F
region_length_5R
region_offset_5R
region_length_3F
region_offset_3F
region_length_3R
region_offset_3R
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
        # five prime region
        $self->five_prime_region_end( $target_start - $self->region_offset_5R );
        $self->five_prime_region_start( $self->five_prime_region_end
               - ( $self->region_offset_5F + $self->region_length_5F + $self->region_length_5R ) );

        # three prime region
        $self->three_prime_region_start( $target_end + $self->region_offset_3F );
        $self->three_prime_region_end( $self->three_prime_region_start
             + ( $self->region_offset_3R + $self->region_length_3R + $self->region_length_3F ) );
    }
    else {
        # five prime region
        $self->five_prime_region_end( $self->five_prime_region_start
             + ( $self->region_offset_5F + $self->region_length_5F + $self->region_length_5R ) );
        $self->five_prime_region_start( $target_end + $self->region_offset_5R );

        # three prime region
        $self->three_prime_region_end( $target_start - $self->region_offset_3F );
        $self->three_prime_region_start( $self->three_prime_region_end
               - ( $self->region_offset_3R + $self->region_length_3R + $self->region_length_3F ) );
    }
    $self->log->info('Calculated oligo region coordinates for design');

    return;
}

1;

__END__
