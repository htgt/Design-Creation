package DesignCreate::CmdRole::OligoRegionsInsDel;

=head1 NAME

DesignCreate::CmdRole::OligoRegionsInsDel -Create seq files for oligo region, insertion or deletion designs

=head1 DESCRIPTION

For given target coordinates and a oligo region parameters produce target region sequence file
for each oligo we must find for deletion or insertion designs.

These attributes and code is specific to Insertion / Deletion designs, code generic to all
design types is found in DesignCreate::Role::OligoTargetRegions.

=cut

use Moose::Role;
use DesignCreate::Exception;
use DesignCreate::Types qw( PositiveInt NaturalNumber );
use namespace::autoclean;

with qw(
DesignCreate::Role::OligoRegionCoordinates
);

has target_start => (
    is            => 'ro',
    isa           => PositiveInt,
    traits        => [ 'Getopt' ],
    documentation => 'Start coordinate of target region',
    required      => 1,
    cmd_flag      => 'target-start'
);

has target_end => (
    is            => 'ro',
    isa           => PositiveInt,
    traits        => [ 'Getopt' ],
    documentation => 'End coordinate of target region',
    required      => 1,
    cmd_flag      => 'target-end'
);

#
# Oligo Region Parameters
# Gap Oligo Parameter attributes in DesignCreate::Role::OligoTargetRegions
#

has U5_region_length => (
    is            => 'ro',
    isa           => PositiveInt,
    traits        => [ 'Getopt' ],
    default       => 200,
    documentation => 'Length of U5 oligo candidate region',
    cmd_flag      => 'u5-region-length'
);

has U5_region_offset => (
    is            => 'ro',
    isa           => NaturalNumber,
    traits        => [ 'Getopt' ],
    default       => 0,
    documentation => 'Offset from target region of U5 oligo candidate region',
    cmd_flag      => 'u5-region-offset'
);

has D3_region_length => (
    is            => 'ro',
    isa           => PositiveInt,
    traits        => [ 'Getopt' ],
    default       => 200,
    documentation => 'Length of D3 oligo candidate region',
    cmd_flag      => 'd3-region-length'
);

has D3_region_offset => (
    is            => 'ro',
    isa           => NaturalNumber,
    traits        => [ 'Getopt' ],
    default       => 0,
    documentation => 'Offset from target region of D3 oligo candidate region',
    cmd_flag      => 'd3-region-offset'
);

sub get_oligo_region_coordinates {
    my $self = shift;

    DesignCreate::Exception->throw(
        "Target start " . $self->target_start . ", greater than target end " . $self->target_end
    ) if $self->target_start > $self->target_end;

    $self->_get_oligo_region_coordinates;
    return;
}

# work out coordinates for ins / del designs
sub coordinates_for_oligo {
    my ( $self, $oligo ) = @_;
    my ( $start, $end );

    my $offset = $self->get_oligo_region_offset( $oligo );
    my $length = $self->get_oligo_region_length( $oligo );

    if ( $self->chr_strand == 1 ) {
        if ( $oligo =~ /5$/ ) {
            $start = $self->target_start - ( $offset + $length );
            $end   = $self->target_start - ( $offset + 1 );
        }
        elsif ( $oligo =~ /3$/ ) {
            $start = $self->target_end + ( $offset + 1 );
            $end   = $self->target_end + ( $offset + $length );
        }
    }
    else {
        if ( $oligo =~ /5$/ ) {
            $start = $self->target_end + ( $offset + 1 );
            $end   = $self->target_end + ( $offset + $length );
        }
        elsif ( $oligo =~ /3$/ ) {
            $start = $self->target_start - ( $offset + $length );
            $end   = $self->target_start - ( $offset + 1 );
        }
    }

    DesignCreate::Exception->throw( "Start $start, greater than or equal to end $end for oligo $oligo" )
        if $start >= $end;

    return( $start, $end );
}

1;

__END__
