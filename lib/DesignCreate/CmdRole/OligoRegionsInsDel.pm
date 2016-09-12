package DesignCreate::CmdRole::OligoRegionsInsDel;
## no critic(RequireUseStrict,RequireUseWarnings)
{
    $DesignCreate::CmdRole::OligoRegionsInsDel::VERSION = '0.042';
}
## use critic


=head1 NAME

DesignCreate::CmdRole::OligoRegionsInsDel -Create seq files for oligo region, insertion or deletion designs

=head1 DESCRIPTION

For given target coordinates and a oligo region parameters produce target region coordinates file
for each oligo we must find for deletion or insertion designs.

These attributes and code is specific to Insertion / Deletion designs, code generic to all
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
region_length_U5
region_offset_U5
region_length_D3
region_offset_D3
region_length_G5
region_offset_G5
region_length_G3
region_offset_G3
design_method
);

has design_method => (
    is            => 'ro',
    isa           => DesignMethod,
    traits        => [ 'Getopt' ],
    required      => 1,
    documentation => 'Design type, deletion or insertion',
    cmd_flag      => 'design-method',
);

#
# Gap Oligo Parameter attributes in DesignCreate::Role::OligoTargetRegions
# We set the defaults below via builder methods
#
sub default_region_length_G5 { return 1000 };
sub default_region_offset_G5 { return 4000 };
sub default_region_length_G3 { return 1000 };
sub default_region_offset_G3 { return 4000 };

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

#TODO all oligos coordinates are based from target start and end, unlike
# all the other DesignCreate::CmdRole::Oligo* modules, change this
sub coordinates_for_oligo {
    my ( $self, $oligo ) = @_;
    my ( $start, $end );

    my $target_start = $self->get_target_data( 'target_start' );
    my $target_end   = $self->get_target_data( 'target_end' );
    my $strand       = $self->get_target_data( 'chr_strand' );

    my $offset = $self->get_oligo_region_offset( $oligo );
    my $length = $self->get_oligo_region_length( $oligo );

    if ( $strand == 1 ) {
        if ( $oligo =~ /5$/ ) {
            $start = $target_start - ( $offset + $length );
            $end   = $target_start - ( $offset + 1 );
        }
        elsif ( $oligo =~ /3$/ ) {
            $start = $target_end + ( $offset + 1 );
            $end   = $target_end + ( $offset + $length );
        }
    }
    else {
        if ( $oligo =~ /5$/ ) {
            $start = $target_end + ( $offset + 1 );
            $end   = $target_end + ( $offset + $length );
        }
        elsif ( $oligo =~ /3$/ ) {
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
