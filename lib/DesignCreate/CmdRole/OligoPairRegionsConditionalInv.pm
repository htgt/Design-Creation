package DesignCreate::CmdRole::OligoPairRegionsConditionalInv;

=head1 NAME

DesignCreate::Action::OligoPairRegionsConditionalInv - Coordinates for oligo regions in deletion fusion designs

=head1 DESCRIPTION

For given exon id and a oligo region parameters produce target region coordinates file
for each oligo pair we must find for deletion fusion designs.

These attributes and code is specific to Conditional Inversion designs, code generic to all
design types is found in DesignCreate::Role::OligoRegionCoodinates.

=cut

use Moose::Role;
use DesignCreate::Exception;
use DesignCreate::Types qw( PositiveInt DesignMethod );
use DesignCreate::Constants qw( %COIN_PRIMER_REGIONS );
use Const::Fast;
use Try::Tiny;
use namespace::autoclean;

with qw( DesignCreate::Role::OligoRegionCoordinates );

const my @DESIGN_PARAMETERS => qw(
design_method
region_length_LFOligo
region_offset_LFOligo
region_length_LROligo
region_offset_LROligo
region_length_RFOligo
region_offset_RFOligo
region_length_RROligo
region_offset_RROligo
);

has design_method => (
    is      => 'ro',
    isa     => DesignMethod,
    traits  => [ 'NoGetopt' ],
    default => 'conditional-inversion'
);

has region_length_LFOligo => (
    is            => 'ro',
    isa           => PositiveInt,
    traits        => [ 'Getopt' ],
    default       => 500,
    documentation => 'Length of LFOligo oligo candidate region',
    cmd_flag      => 'region-length-LFOligo'
);

has region_offset_LFOligo => (
    is            => 'ro',
    isa           => PositiveInt,
    traits        => [ 'Getopt' ],
    default       => 1000,
    documentation => 'Offset from LROligo oligo candidate region of LFOligo oligo candidate region',
    cmd_flag      => 'region-offset-LFOligo'
);

has region_length_LROligo => (
    is            => 'ro',
    isa           => PositiveInt,
    traits        => [ 'Getopt' ],
    default       => 100,
    documentation => 'Length of LROligo oligo candidate region',
    cmd_flag      => 'region-length-LROligo'
);

has region_offset_LROligo => (
    is            => 'ro',
    isa           => PositiveInt,
    traits        => [ 'Getopt' ],
    default       => 1,
    documentation => 'Offset from exon of LROligo oligo candidate region',
    cmd_flag      => 'region-offset-LROligo'
);

has region_length_RROligo => (
    is            => 'ro',
    isa           => PositiveInt,
    traits        => [ 'Getopt' ],
    default       => 500,
    documentation => 'Length of RROligo oligo candidate region',
    cmd_flag      => 'region-length-RROligo'
);

has region_offset_RROligo => (
    is            => 'ro',
    isa           => PositiveInt,
    traits        => [ 'Getopt' ],
    default       => 1000,
    documentation => 'Offset from RLOligo oligo candidate region of RROligo oligo candidate region',
    cmd_flag      => 'region-offset-RROligo'
);

has region_length_RLOligo => (
    is            => 'ro',
    isa           => PositiveInt,
    traits        => [ 'Getopt' ],
    default       => 100,
    documentation => 'Length of RLOligo oligo candidate region',
    cmd_flag      => 'region-length-RLOligo'
);

has region_offset_RLOligo => (
    is            => 'ro',
    isa           => PositiveInt,
    traits        => [ 'Getopt' ],
    default       => 1,
    documentation => 'Offset from exon of RLOligo oligo candidate region',
    cmd_flag      => 'region-offset-RLOligo'
);

has left_arm_region_start => (
    is         => 'rw',
    isa        => PositiveInt,
    traits     => [ 'NoGetopt' ],
);

has left_arm_region_end => (
    is         => 'rw',
    isa        => PositiveInt,
    traits     => [ 'NoGetopt' ],
);

has right_arm_region_start => (
    is         => 'rw',
    isa        => PositiveInt,
    traits     => [ 'NoGetopt' ],
);

has right_arm_region_end => (
    is         => 'rw',
    isa        => PositiveInt,
    traits     => [ 'NoGetopt' ],
);


=head2 get_oligo_pair_region_coordinates

Get coordinates for the two oligo pair regions:
left_arm
right_arm

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
        # left arm
        $self->left_arm_region_end( $target_start - $self->region_offset_LROligo );
        $self->left_arm_region_start( $self->left_arm_region_end
               - ( $self->region_offset_LFOligo + $self->region_length_LFOligo + $self->region_length_LROligo ) );

        # right arm
        $self->right_arm_region_start( $target_end + $self->region_offset_RLOligo );
        $self->right_arm_region_end( $self->right_arm_region_start
             + ( $self->region_offset_RROligo + $self->region_length_RROligo + $self->region_length_RLOligo ) );
    }
    else {
        # left arm
        $self->left_arm_region_start( $target_end + $self->region_offset_LROligo );
        $self->left_arm_region_end( $self->left_arm_region_start
             + ( $self->region_offset_LFOligo + $self->region_length_LFOligo + $self->region_length_LROligo ) );

        # right arm
        $self->right_arm_region_end( $target_start - $self->region_offset_RLOligo );
        $self->right_arm_region_start( $self->right_arm_region_end
               - ( $self->region_offset_RROligo + $self->region_length_RROligo + $self->region_length_RLOligo ) );

    }

    $self->log->info('Calculated oligo region coordinates for design');

    return;
}

1;


