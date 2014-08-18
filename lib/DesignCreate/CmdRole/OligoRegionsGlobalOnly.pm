package DesignCreate::CmdRole::OligoRegionsGlobalOnly;
## no critic(RequireUseStrict,RequireUseWarnings)
{
    $DesignCreate::CmdRole::OligoRegionsGlobalOnly::VERSION = '0.028';
}
## use critic


=head1 NAME

DesignCreate::CmdRole::OligoRegionsGlobalOnly -Create seq files for global oligo regions

=head1 DESCRIPTION

For given target coordinates and a oligo region parameters produce target region coordinates file
for each global oligo we must find.

These attributes and code is specific to global oligo only designs, code generic to all
design types is found in DesignCreate::Role::OligoRegionCoodinates.

=cut

use Moose::Role;
use DesignCreate::Types qw( DesignMethod PositiveInt NaturalNumber Chromosome Strand );
use Const::Fast;
use namespace::autoclean;

with qw(
DesignCreate::Role::OligoRegionCoordinates
DesignCreate::Role::GapOligoCoordinates
);

const my @DESIGN_PARAMETERS => qw(
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
    default => 'global-only',
);

#
# Gap Oligo Parameter attributes in DesignCreate::Role::OligoTargetRegions
# We set the defaults below via builder methods
#
sub default_region_length_G5 { return 400 };
sub default_region_offset_G5 { return 800 };
sub default_region_length_G3 { return 400 };
sub default_region_offset_G3 { return 800 };

=head2 get_oligo_region_coordinates

Work out the G5 / G3 oligos region coordiantes, and write to a yaml file.

=cut
sub get_oligo_region_coordinates {
    my $self = shift;
    $self->add_design_parameters( \@DESIGN_PARAMETERS );

    # check target coordinate have been set, if not die
    for my $data_type ( qw( target_start target_end chr_name chr_strand ) ) {
        DesignCreate::Exception->throw( "No target value for: $data_type" )
            unless $self->have_target_data( $data_type );
    }

    for my $oligo ( $self->expected_oligos ) {
        $self->log->info( "Getting target region for $oligo oligo" );
        my ( $start, $end ) = $self->coordinates_for_oligo( $oligo );
        next if !defined $start || !defined $end;

        $self->oligo_region_coordinates->{$oligo} = { start => $start, end => $end };
    }

    $self->create_oligo_region_coordinate_file;

    return;
}


=head2 coordinates_for_oligo

Calculate the oligo region coordinates, taking into acount oligo type and design strand.

=cut
sub coordinates_for_oligo {
    my ( $self, $oligo ) = @_;
    my ( $start, $end );

    my $target_start = $self->get_target_data( 'target_start' );
    my $target_end   = $self->get_target_data( 'target_end' );
    my $strand       = $self->get_target_data( 'chr_strand' );

    my $offset = $self->get_oligo_region_offset( $oligo );
    my $length = $self->get_oligo_region_length( $oligo );

    if ( $strand == 1 ) {
        if ( $oligo eq 'G5' ) {
            $start = $target_start - ( $offset + $length );
            $end   = $target_start - ( $offset + 1 );
        }
        elsif ( $oligo eq 'G3' ) {
            $start = $target_end + ( $offset + 1 );
            $end   = $target_end + ( $offset + $length );
        }
    }
    else {
        if ( $oligo eq 'G5') {
            $start = $target_end + ( $offset + 1 );
            $end   = $target_end + ( $offset + $length );
        }
        elsif ( $oligo eq 'G3' ) {
            $start = $target_start - ( $offset + $length );
            $end   = $target_start - ( $offset + 1 );
        }
    }

    DesignCreate::Exception->throw( "Start $start, greater than or equal to end $end for oligo $oligo" )
        if $start >= $end;

    return( $start, $end );
}

1;

__END__
