package DesignCreate::CmdRole::OligoRegionsConditional;
## no critic(RequireUseStrict,RequireUseWarnings)
{
    $DesignCreate::CmdRole::OligoRegionsConditional::VERSION = '0.014';
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
U_block_start
U_block_end
D_block_start
D_block_end
U_block_overlap
D_block_overlap
chr_name
chr_strand
species
assembly
region_length_G5
region_offset_G5
region_length_G3
region_offset_G3
design_method
target_genes
);

has design_method => (
    is      => 'ro',
    isa     => DesignMethod,
    traits  => [ 'NoGetopt' ],
    default => 'conditional'
);

has chr_name => (
    is            => 'ro',
    isa           => Chromosome,
    traits        => [ 'Getopt' ],
    documentation => 'Name of chromosome the design target lies within',
    required      => 1,
    cmd_flag      => 'chromosome'
);

has chr_strand => (
    is            => 'ro',
    isa           => Strand,
    traits        => [ 'Getopt' ],
    documentation => 'The strand the design target lies on',
    required      => 1,
    cmd_flag      => 'strand'
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

has U_block_length => (
    is         => 'ro',
    isa        => PositiveInt,
    traits     => [ 'NoGetopt' ],
    lazy_build => 1,
);

sub _build_U_block_length {
    my $self = shift;
    return ( $self->U_block_end - $self->U_block_start ) + 1;
}

has U_block_overlap => (
    is            => 'ro',
    isa           => NaturalNumber,
    traits        => [ 'Getopt' ],
    documentation => 'Block overlap for U region',
    default       => 0,
    cmd_flag      => 'u-block-overlap'
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

has D_block_length => (
    is         => 'ro',
    isa        => PositiveInt,
    traits     => [ 'NoGetopt' ],
    lazy_build => 1,
);

sub _build_D_block_length {
    my $self = shift;
    return ( $self->D_block_end - $self->D_block_start ) + 1;
}

has D_block_overlap => (
    is            => 'ro',
    isa           => NaturalNumber,
    traits        => [ 'Getopt' ],
    documentation => 'Block overlap for D region',
    default       => 0,
    cmd_flag      => 'd-block-overlap'
);

sub get_oligo_region_coordinates {
    my $self = shift;
    $self->add_design_parameters( \@DESIGN_PARAMETERS );
    $self->check_oligo_block_coordinates;

    for my $oligo ( $self->expected_oligos ) {
        $self->log->info( "Getting target region for $oligo oligo" );
        # coordinates_for_oligo sub will be defined within consuming role;
        my ( $start, $end ) = $self->coordinates_for_oligo( $oligo );
        next if !defined $start || !defined $end;

        $self->oligo_region_coordinates->{$oligo} = { start => $start, end => $end };
    }

    $self->create_oligo_region_coordinate_file;
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
    my $oligo_class = substr( $oligo, 0,1 );
    DesignCreate::Exception->throw( "Block oligo type must be U or D, not $oligo" )
        unless  $oligo_class =~ /^U|D$/;

    if ( $self->chr_strand == 1 ) {
        if ( $oligo =~ /5$/ ) {
            ( $start, $end ) = $self->get_oligo_block_left_half_coords( $oligo_class );
        }
        elsif ( $oligo =~ /3$/ ) {
            ( $start, $end ) = $self->get_oligo_block_right_half_coords( $oligo_class );
        }
    }
    else {
        if ( $oligo =~ /5$/ ) {
            ( $start, $end ) = $self->get_oligo_block_right_half_coords( $oligo_class );
        }
        elsif ( $oligo =~ /3$/ ) {
            ( $start, $end ) = $self->get_oligo_block_left_half_coords( $oligo_class );
        }
    }

    DesignCreate::Exception->throw( "Start $start, greater than or equal to end $end for oligo $oligo" )
        if $start >= $end;

    return( $start, $end );
}

sub get_oligo_block_left_half_coords {
    my ( $self, $oligo_class ) = @_;
    my $block_length = $self->get_oligo_block_attribute( $oligo_class, 'length' );
    my $block_overlap = $self->get_oligo_block_attribute( $oligo_class, 'overlap' );

    my $start = $self->get_oligo_block_attribute( $oligo_class, 'start' );
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
    my ( $self, $oligo_class ) = @_;
    my $block_length = $self->get_oligo_block_attribute( $oligo_class, 'length' );
    my $block_overlap = $self->get_oligo_block_attribute( $oligo_class, 'overlap' );
    my $block_start  = $self->get_oligo_block_attribute( $oligo_class, 'start' );

    my $end = $self->get_oligo_block_attribute( $oligo_class, 'end' );
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
    my $attribute_name = $oligo_class . '_block_';
    $attribute_name .= $attribute_type if $attribute_type;

    DesignCreate::Exception::NonExistantAttribute->throw(
        attribute_name => $attribute_name,
        class          => $self->meta->name
    ) unless $self->meta->has_attribute($attribute_name);

    return $self->$attribute_name;
}

1;

__END__
