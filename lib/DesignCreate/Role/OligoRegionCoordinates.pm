package DesignCreate::Role::OligoRegionCoordinates;

=head1 NAME

DesignCreate::Role::OligoRegionCoordinates

=head1 DESCRIPTION

Common code for oligo target ( candidate ) region coordinate finding commands.

=cut

use Moose::Role;
use DesignCreate::Exception;
use DesignCreate::Exception::NonExistantAttribute;
use DesignCreate::Types qw( PositiveInt NaturalNumber Chromosome Strand Species );
use Fcntl; # O_ constants
use Const::Fast;
use YAML::Any qw( DumpFile );
use namespace::autoclean;

const my $DEFAULT_OLIGO_COORD_FILE_NAME => 'oligo_region_coords.yaml';
const my %CURRENT_ASSEMBLY => (
    Mouse => 'GRCm38',
    Human => 'GRCh37',
 );

has target_genes => (
    is            => 'ro',
    isa           => 'ArrayRef',
    traits        => [ 'Getopt' ],
    documentation => 'Name of target gene(s) of design',
    required      => 1,
    cmd_flag      => 'target-gene',
);

has oligo_region_coordinates => (
    is      => 'rw',
    isa     => 'HashRef',
    traits  => [ 'NoGetopt' ],
    default => sub { {} },
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

has species => (
    is            => 'ro',
    isa           => Species,
    traits        => [ 'Getopt' ],
    documentation => 'The species of the design target ( default Mouse )',
    default       => 'Mouse',
);

has assembly => (
    is         => 'ro',
    isa        => 'Str',
    traits     => [ 'NoGetopt' ],
    lazy_build => 1,
);

sub _build_assembly {
    my $self = shift;

    return $CURRENT_ASSEMBLY{ $self->species };
}

#
# Gap oligo region parameters, common to all design types
# TODO: Think about moving these to seperate role, because there maybe more
#       than one way we will want to specify the G oligo regions
#

has G5_region_length => (
    is            => 'ro',
    isa           => PositiveInt,
    traits        => [ 'Getopt' ],
    default       => 1000,
    documentation => 'Length of G5 oligo candidate region',
    cmd_flag      => 'g5-region-length'
);

has G5_region_offset => (
    is            => 'ro',
    isa           => PositiveInt,
    traits        => [ 'Getopt' ],
    default       => 4000,
    documentation => 'Offset from target region of G5 oligo candidate region',
    cmd_flag      => 'g5-region-offset'
);

has G3_region_length => (
    is            => 'ro',
    isa           => PositiveInt,
    traits        => [ 'Getopt' ],
    default       => 1000,
    documentation => 'Length of G3 oligo candidate region',
    cmd_flag      => 'g3-region-length'
);

has G3_region_offset => (
    is            => 'ro',
    isa           => PositiveInt,
    traits        => [ 'Getopt' ],
    default       => 4000,
    documentation => 'Offset from target region of G3 oligo candidate region',
    cmd_flag      => 'g3-region-offset'
);

## no critic(Subroutines::ProhibitUnusedPrivateSubroutine)
sub _get_oligo_region_coordinates {
    my $self = shift;

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
## use critic

sub create_oligo_region_coordinate_file {
    my $self = shift;

    my $file = $self->oligo_target_regions_dir->file( $DEFAULT_OLIGO_COORD_FILE_NAME );
    DumpFile( $file, $self->oligo_region_coordinates );

    return;
}

sub get_oligo_region_offset {
    my ( $self, $oligo ) = @_;

    my $attribute_name = $oligo . '_region_offset';
    DesignCreate::Exception::NonExistantAttribute->throw(
        attribute_name => $attribute_name,
        class          => $self->meta->name
    ) unless $self->meta->has_attribute($attribute_name);

    return $self->$attribute_name;
}

sub get_oligo_region_length {
    my ( $self, $oligo ) = @_;

    my $attribute_name = $oligo . '_region_length';
    DesignCreate::Exception::NonExistantAttribute->throw(
        attribute_name => $attribute_name,
        class          => $self->meta->name
    ) unless $self->meta->has_attribute($attribute_name);

    return $self->$attribute_name;
}

1;

__END__
