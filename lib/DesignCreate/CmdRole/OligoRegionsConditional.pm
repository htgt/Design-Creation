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
use DesignCreate::Exception::NonExistantAttribute;
use DesignCreate::Types qw( PositiveInt NaturalNumber );
use Const::Fast;
use namespace::autoclean;

with qw(
DesignCreate::Role::OligoRegionCoordinates
);

const my $MIN_BLOCK_LENGTH => 102;

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

#TODO consider method overriding / renaming here
sub get_oligo_region_coordinates {
    my $self = shift;

    $self->check_oligo_block_coordinates;
    $self->_get_oligo_region_coordinates;

    return;
}

sub check_oligo_block_coordinates {
    my $self = shift;

    for my $block_type ( qw( U D ) ) {
        my $start_attribute = $block_type . '_block_start';
        my $end_attribute = $block_type . '_block_end';

        my $start = $self->$start_attribute;
        my $end = $self->$end_attribute;
        DesignCreate::Exception->throw(
            "$block_type block start, $start, is greater than its end, $end"
        ) if $start > $end;

        my $length = ( $end - $start ) + 1;
        DesignCreate::Exception->throw(
            "$block_type block has only $length bases, must have minimum of $MIN_BLOCK_LENGTH bases"
        ) if $length < $MIN_BLOCK_LENGTH;
    }

    if ( $self->chr_strand == 1 ) {
        DesignCreate::Exception->throw(
            'U block end: ' . $self->U_block_end . ' can not be greater than D block start: '
            . $self->D_block_start . ' on designs on the +ve strand'
        ) if $self->U_block_end > $self->D_block_start;
    }
    else {
        DesignCreate::Exception->throw(
            'D block end: ' . $self->D_block_end . ' can not be greater than U block start: '
            . $self->U_block_start . ' on designs on the -ve strand'
        ) if $self->D_block_end > $self->U_block_start;
    }

    return;
}

# work out coordinates for block specified conditional designs
sub coordinates_for_oligo {
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

    if ( $block_length % 2 ) { # not divisible by 2
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

    if ( $block_length % 2 ) { # not divisible by 2
        $start = $block_start + ( ( $block_length + 1 ) / 2 );
    }
    else {
        $start = $block_start + ( $block_length / 2 );
    }

    return ( $start, $end );
}

sub get_oligo_block_coordinate {
    my ( $self, $oligo, $start_or_end ) = @_;
    DesignCreate::Exception->throw( "Must specify start or end block coordinate" )
        if !$start_or_end || $start_or_end !~ /start|end/;

    my $block_type = $oligo =~ /^U/ ? 'U' :
                     $oligo =~ /^D/ ? 'D' : undef;
    DesignCreate::Exception->throw( "Block oligo type must be U or D, not $oligo" )
        unless  $block_type;

    my $attribute_name = $block_type . '_block_' . $start_or_end;

    DesignCreate::Exception::NonExistantAttribute->throw(
        attribute_name => $attribute_name,
        class          => $self->meta->name
    ) unless $self->meta->has_attribute($attribute_name);

    return $self->$attribute_name;
}

1;

__END__
