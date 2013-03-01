package DesignCreate::CmdRole::OligoRegionsConditional;

=head1 NAME

DesignCreate::CmdRole::OligoRegionsConditional -Create seq files for oligo region, block specified conditional designs

=head1 DESCRIPTION

For given target coordinates and a oligo region parameters produce target region sequence file
for each oligo we must find for block specified  conditional designs.

These attributes and code is specific to block specified conditional designs, code generic to all
design types is found in DesignCreate::Role::OligoTargetRegions.

=cut

use Moose::Role;
use DesignCreate::Exception;
use DesignCreate::Types qw( PositiveInt NaturalNumber );
use namespace::autoclean;

with qw(
DesignCreate::Role::OligoTargetRegions
);

#
# Oligo Region Parameters
# Gap Oligo Parameter attributes in DesignCreate::Role::OligoTargetRegions
#

has U_block_start => (
    is            => 'ro',
    isa           => PositiveInt,
    traits        => [ 'Getopt' ],
    documentation => 'Start coordinate for U region',
    required      => 1,
    cmd_flag      => 'u-block-start'
);

has U_block_end => (
    is            => 'ro',
    isa           => PositiveInt,
    traits        => [ 'Getopt' ],
    documentation => 'End coordinate for U region',
    required      => 1,
    cmd_flag      => 'u-block-end'
);

has D_block_start => (
    is            => 'ro',
    isa           => PositiveInt,
    traits        => [ 'Getopt' ],
    documentation => 'Start coordinate for D region',
    required      => 1,
    cmd_flag      => 'd-block-start'
);

has D_block_end => (
    is            => 'ro',
    isa           => PositiveInt,
    traits        => [ 'Getopt' ],
    documentation => 'End coordinate for D region',
    required      => 1,
    cmd_flag      => 'd-block-end'
);

#TODO - check U and D block coordinates are valid ( min length, start before end, U before D etc )

# consider method overriding / renaming here
sub build_conditional_oligo_target_regions {
    my $self = shift;

    $self->build_oligo_target_regions;
}

use Smart::Comments;
# work out coordinates for block specified conditional designs
sub get_oligo_region_coordinates {
    my ( $self, $oligo ) = @_;

    if ( $oligo =~ /^G/ ) {
        return $self->get_oligo_region_gap_oligo( $oligo );
    }
    else {
        return $self->get_oligo_region_u_or_d_oligo( $oligo );
    }

    return;
}

sub get_oligo_region_gap_oligo {
    my ( $self, $oligo ) = @_;
    my ( $start, $end );

    my $offset = $self->get_oligo_region_offset( $oligo );
    my $length = $self->get_oligo_region_length( $oligo );

    if ( $self->chr_strand == 1 ) {
        if ( $oligo eq 'G5' ) {
            $start = $self->U_block_start - ( $offset + $length );
            $end   = $self->U_block_start - ( $offset + 1 );
        }
        elsif ( $oligo eq 'G3' ) {
            $start = $self->D_block_end + ( $offset + 1 );
            $end   = $self->D_block_end + ( $offset + $length );
        }
    }
    else {
        if ( $oligo eq 'G5' ) {
            $start = $self->U_block_end + ( $offset + 1 );
            $end   = $self->U_block_end + ( $offset + $length );
        }
        elsif ( $oligo eq 'G3' ) {
            $start = $self->D_block_start - ( $offset + $length );
            $end   = $self->D_block_start - ( $offset + 1 );
        }
    }

    DesignCreate::Exception->throw( "Start $start, greater than or equal to end $end for oligo $oligo" )
        if $start >= $end;

    return( $start, $end );

}

sub get_oligo_region_u_or_d_oligo {
    my ( $self, $oligo ) = @_;
    my ( $start, $end );

    my $block_start = $self->get_oligo_block_coordinate( $oligo, 'start' );
    my $block_end = $self->get_oligo_block_coordinate( $oligo, 'end' );

    if ( $self->chr_strand == 1 ) {
        if ( $oligo =~ /5$/ ) {
            ( $start, $end ) = $self->get_oligo_block_left_half_coords( $block_start, $block_end );
        }
        elsif ( $oligo =~ /3$/ ) {
            ( $start, $end ) = $self->get_oligo_block_right_half_coords( $block_start, $block_end );
        }
    }
    else {
        if ( $oligo =~ /5$/ ) {
            ( $start, $end ) = $self->get_oligo_block_right_half_coords( $block_start, $block_end );
        }
        elsif ( $oligo =~ /3$/ ) {
            ( $start, $end ) = $self->get_oligo_block_left_half_coords( $block_start, $block_end );
        }
    }

    DesignCreate::Exception->throw( "Start $start, greater than or equal to end $end for oligo $oligo" )
        if $start >= $end;

    return( $start, $end );
}

sub get_oligo_block_left_half_coords {
    my ( $self, $block_start, $block_end ) = @_;
    my $block_length = ( $block_end - $block_start ) + 1;
    my $start = $block_start;
    my $end;

    if ( $block_length % 2 ) { # divisible by 2
        $end = $start + ( ( $block_length - 1 ) / 2 );
    }
    else {
        $end = $start + ( ( $block_length / 2 ) - 1 );
    }

    return ( $start, $end );
}

sub get_oligo_block_right_half_coords {
    my ( $self, $block_start, $block_end ) = @_;
    my $block_length = ( $block_end - $block_start ) + 1;
    my $end = $block_end;
    my $start;

    if ( $block_length % 2 ) { # divisible by 2
        $start = $block_start + ( ( $block_length + 1 ) / 2 );
    }
    else {
        $start = $block_start + ( $block_length / 2 );
    }

    return ( $start, $end );
}

sub get_oligo_block_coordinate {
    my ( $self, $oligo, $start_or_end ) = @_;

    my $block_type = $oligo =~ /^U/ ? 'U' : 'D';
    my $attribute_name = $block_type . '_block_' . $start_or_end;

    DesignCreate::Exception->throw( "Attribute $attribute_name does not exist" )
        unless  $self->meta->has_attribute( $attribute_name );

    return $self->$attribute_name;
}

1;

__END__
