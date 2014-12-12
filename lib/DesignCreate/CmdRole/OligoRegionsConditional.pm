package DesignCreate::CmdRole::OligoRegionsConditional;
## no critic(RequireUseStrict,RequireUseWarnings)
{
    $DesignCreate::CmdRole::OligoRegionsConditional::VERSION = '0.032';
}
## use critic


=head1 NAME

DesignCreate::CmdRole::OligoRegionsConditional -Create seq files for oligo region, block specified conditional designs

=head1 DESCRIPTION

For given target coordinates and a oligo region parameters produce target region coordinates file
for each oligo we must find for block specified conditional designs.

These attributes and code is specific to block specified conditional designs, code generic to all
design types is found in DesignCreate::Role::OligoRegionCoordinates.

=cut

use Moose::Role;
use DesignCreate::Exception;
use DesignCreate::Exception::NonExistantAttribute;
use DesignCreate::Types qw( DesignMethod PositiveInt NaturalNumber Chromosome Strand );
use Const::Fast;
use namespace::autoclean;

with qw(
DesignCreate::Role::OligoRegionCoordinates
DesignCreate::Role::GapOligoCoordinates
);

const my $MIN_BLOCK_LENGTH => 102;
const my @DESIGN_PARAMETERS => qw(
region_length_U_block
region_offset_U_block
region_overlap_U_block
region_length_D_block
region_offset_D_block
region_overlap_D_block
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
    default => 'conditional'
);

#
# Gap Oligo Parameter attributes in DesignCreate::Role::OligoTargetRegions
# We set the defaults below via builder methods
#
sub default_region_length_G5 { return 1000 };
sub default_region_offset_G5 { return 4000 };
sub default_region_length_G3 { return 1000 };
sub default_region_offset_G3 { return 4000 };

#
# Oligo Region Parameters
#

has region_length_U_block => (
    is            => 'ro',
    isa           => PositiveInt,
    traits        => [ 'Getopt' ],
    documentation => 'Length of U block',
    required      => 1,
    cmd_flag      => 'region-length-u-block'
);

has region_offset_U_block => (
    is            => 'ro',
    isa           => PositiveInt,
    traits        => [ 'Getopt' ],
    documentation => 'Offset from target region of U block',
    required      => 1,
    cmd_flag      => 'region-offset-u-block'
);

has region_overlap_U_block => (
    is            => 'ro',
    isa           => NaturalNumber,
    traits        => [ 'Getopt' ],
    documentation => 'Size of block overlap for U region',
    default       => 0,
    cmd_flag      => 'region-overlap-u-block'
);

has region_length_D_block => (
    is            => 'ro',
    isa           => PositiveInt,
    traits        => [ 'Getopt' ],
    documentation => 'Length of D block',
    required      => 1,
    cmd_flag      => 'region-length-d-block'
);

has region_offset_D_block => (
    is            => 'ro',
    isa           => PositiveInt,
    traits        => [ 'Getopt' ],
    documentation => 'Offset from target region of D block',
    required      => 1,
    cmd_flag      => 'region-offset-d-block'
);

has region_overlap_D_block => (
    is            => 'ro',
    isa           => NaturalNumber,
    traits        => [ 'Getopt' ],
    documentation => 'Size of block overlap for D region',
    default       => 0,
    cmd_flag      => 'region-overlap-d-block'
);

has [
    'region_start_G5',
    'region_end_G5',
    'region_start_G3',
    'region_end_G3',
    'region_start_U5',
    'region_end_U5',
    'region_start_U3',
    'region_end_U3',
    'region_start_D5',
    'region_end_D5',
    'region_start_D3',
    'region_end_D3',
] => (
    is     => 'rw',
    isa    => PositiveInt,
    traits => [ 'NoGetopt' ],
);

sub get_oligo_region_coordinates {
    my $self = shift;
    $self->add_design_parameters( \@DESIGN_PARAMETERS );

    # check target coordinate have been set, if not die
    for my $data_type ( qw( target_start target_end chr_name chr_strand ) ) {
        DesignCreate::Exception->throw( "No target value for: $data_type" )
            unless $self->have_target_data( $data_type );
    }

    $self->check_oligo_blocks;
    $self->calculate_oligo_region_coordinates;

    for my $oligo ( $self->expected_oligos ) {
        $self->log->info( "Getting target region for $oligo oligo" );
        my $start_attr_name = 'region_start_' . $oligo;
        my $end_attr_name = 'region_end_' . $oligo;

        $self->oligo_region_coordinates->{ $oligo } = {
            start => $self->$start_attr_name,
            end   => $self->$end_attr_name,
        };
    }

    $self->create_oligo_region_coordinate_file;
    return;
}

sub check_oligo_blocks {
    my $self = shift;

    for my $block_type ( qw( U D ) ) {
        my $block_length = $self->get_oligo_block_attribute( $block_type, 'length' );
        DesignCreate::Exception->throw(
            "$block_type block has only $block_length bases, must have minimum of $MIN_BLOCK_LENGTH bases"
        ) if $block_length < $MIN_BLOCK_LENGTH;
    }

    return;
}

sub calculate_oligo_region_coordinates {
    my ( $self ) = @_;

    my $target_start = $self->get_target_data( 'target_start' );
    my $target_end   = $self->get_target_data( 'target_end' );
    my $strand       = $self->get_target_data( 'chr_strand' );

    if ( $strand == 1 ) {
        $self->_coordinates_for_plus_strand( $target_start, $target_end );
    }
    else {
        $self->_coordinates_for_minus_strand( $target_start, $target_end );
    }

    return;
}

sub _coordinates_for_plus_strand {
    my ( $self, $target_start, $target_end ) = @_;

    # U Block
    my $u_block_start = $target_start - ( $self->region_offset_U_block + $self->region_length_U_block );
    my $u_block_end   = $target_start - $self->region_offset_U_block;
    my ( $u5_start, $u5_end ) = $self->get_oligo_block_left_half_coords( 'U', $u_block_start );
    $self->region_start_U5( $u5_start );
    $self->region_end_U5( $u5_end );

    my ( $u3_start, $u3_end ) = $self->get_oligo_block_right_half_coords( 'U', $u_block_start, $u_block_end );
    $self->region_start_U3( $u3_start );
    $self->region_end_U3( $u3_end  );

    # D Block
    my $d_block_start = $target_end + $self->region_offset_D_block;
    my $d_block_end   = $target_end + $self->region_offset_D_block + $self->region_length_D_block;
    my ( $d5_start, $d5_end ) = $self->get_oligo_block_left_half_coords( 'D', $d_block_start );
    $self->region_start_D5( $d5_start );
    $self->region_end_D5( $d5_end );

    my ( $d3_start, $d3_end ) = $self->get_oligo_block_right_half_coords( 'D', $d_block_start, $d_block_end );
    $self->region_start_D3( $d3_start );
    $self->region_end_D3( $d3_end  );

    # G oligos
    $self->region_start_G5( $self->region_start_U5 - ( $self->region_offset_G5 + $self->region_length_G5 ));
    $self->region_end_G5( $self->region_start_U5 - $self->region_offset_G5  );
    $self->region_start_G3( $self->region_end_D3 + $self->region_offset_G3 );
    $self->region_end_G3( $self->region_end_D3 + $self->region_offset_G3 + $self->region_length_G3 );

    return;
}

sub _coordinates_for_minus_strand {
    my ( $self, $target_start, $target_end ) = @_;

    # U Block
    my $u_block_start = $target_end + $self->region_offset_U_block;
    my $u_block_end   = $target_end + $self->region_offset_U_block + $self->region_length_U_block;
    my ( $u5_start, $u5_end ) = $self->get_oligo_block_right_half_coords( 'U', $u_block_start, $u_block_end );
    $self->region_start_U5( $u5_start );
    $self->region_end_U5( $u5_end );

    my ( $u3_start, $u3_end ) = $self->get_oligo_block_left_half_coords( 'U', $u_block_start );
    $self->region_start_U3( $u3_start );
    $self->region_end_U3( $u3_end  );

    # D Block
    my $d_block_start = $target_start - ( $self->region_offset_D_block + $self->region_length_D_block );
    my $d_block_end   = $target_start - $self->region_offset_D_block;
    my ( $d5_start, $d5_end ) = $self->get_oligo_block_right_half_coords( 'D', $d_block_start, $d_block_end );
    $self->region_start_D5( $d5_start );
    $self->region_end_D5( $d5_end );

    my ( $d3_start, $d3_end ) = $self->get_oligo_block_left_half_coords( 'D', $d_block_start );
    $self->region_start_D3( $d3_start );
    $self->region_end_D3( $d3_end  );

    # G oligos
    $self->region_start_G5( $self->region_end_U5 + $self->region_offset_G5  );
    $self->region_end_G5( $self->region_end_U5 + $self->region_offset_G5 + $self->region_length_G5 );
    $self->region_start_G3( $self->region_start_D3 - ( $self->region_offset_G3 + $self->region_length_G3 ));
    $self->region_end_G3( $self->region_start_D3 - $self->region_offset_G3 );

    return;
}

sub get_oligo_block_left_half_coords {
    my ( $self, $oligo_class, $block_start ) = @_;
    my $block_length = $self->get_oligo_block_attribute( $oligo_class, 'length' );
    my $block_overlap = $self->get_oligo_block_attribute( $oligo_class, 'overlap' );

    my $start = $block_start;
    my $end;
    if ( $block_length % 2 ) { # not divisible by 2
        $end = $start + ( ( $block_length - 1 ) / 2 );
    }
    else {
        $end = $start + ( ( $block_length / 2 ) - 1 );
    }
    $end += $block_overlap;

    return ( $start, $end );
}

sub get_oligo_block_right_half_coords {
    my ( $self, $oligo_class, $block_start, $block_end ) = @_;
    my $block_length = $self->get_oligo_block_attribute( $oligo_class, 'length' );
    my $block_overlap = $self->get_oligo_block_attribute( $oligo_class, 'overlap' );

    my $end = $block_end;
    my $start;
    if ( $block_length % 2 ) { # not divisible by 2
        $start = $block_start + ( ( $block_length + 1 ) / 2 );
    }
    else {
        $start = $block_start + ( $block_length / 2 );
    }
    $start -= $block_overlap;

    return ( $start, $end );
}

sub get_oligo_block_attribute {
    my ( $self, $oligo_class, $attribute_type ) = @_;
    my $attribute_name = 'region_' . $attribute_type . '_' . $oligo_class . '_block';

    DesignCreate::Exception::NonExistantAttribute->throw(
        attribute_name => $attribute_name,
        class          => $self->meta->name
    ) unless $self->meta->has_attribute($attribute_name);

    return $self->$attribute_name;
}

1;

__END__
