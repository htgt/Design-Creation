package DesignCreate::Role::OligoRegionCoordinatesInsDel;
## no critic(RequireUseStrict,RequireUseWarnings)
{
    $DesignCreate::Role::OligoRegionCoordinatesInsDel::VERSION = '0.013';
}
## use critic


=head1 NAME

DesignCreate::Role::OligoRegionCoordinatesInsDel

=head1 DESCRIPTION

Common code for finding oligo region coordinates for insertion
or deletion designs.

=cut

use Moose::Role;
use DesignCreate::Exception;
use DesignCreate::Types qw( PositiveInt NaturalNumber );
use namespace::autoclean;

has region_length_U5 => (
    is            => 'ro',
    isa           => PositiveInt,
    traits        => [ 'Getopt' ],
    default       => 200,
    documentation => 'Length of U5 oligo candidate region',
    cmd_flag      => 'region-length-u5'
);

has region_offset_U5 => (
    is            => 'ro',
    isa           => NaturalNumber,
    traits        => [ 'Getopt' ],
    default       => 0,
    documentation => 'Offset from target region of U5 oligo candidate region',
    cmd_flag      => 'region-offset-u5'
);

has region_length_D3 => (
    is            => 'ro',
    isa           => PositiveInt,
    traits        => [ 'Getopt' ],
    default       => 200,
    documentation => 'Length of D3 oligo candidate region',
    cmd_flag      => 'region-length-d3'
);

has region_offset_D3 => (
    is            => 'ro',
    isa           => NaturalNumber,
    traits        => [ 'Getopt' ],
    default       => 0,
    documentation => 'Offset from target region of D3 oligo candidate region',
    cmd_flag      => 'region-offset-d3'
);

## no critic(Subroutines::ProhibitUnusedPrivateSubroutine)
sub _get_oligo_region_coordinates {
    my $self = shift;

    DesignCreate::Exception->throw(
        "Target start " . $self->target_start . ", greater than target end " . $self->target_end
    ) if $self->target_start > $self->target_end;

    for my $oligo ( $self->expected_oligos ) {
        $self->log->info( "Getting target region for $oligo oligo" );
        my ( $start, $end ) = $self->coordinates_for_oligo( $oligo );
        next if !defined $start || !defined $end;

        $self->oligo_region_coordinates->{$oligo} = { start => $start, end => $end };
    }

    $self->create_oligo_region_coordinate_file;
    return;
}
## use critic

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
